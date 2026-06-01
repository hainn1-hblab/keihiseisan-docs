# Tổng quan Nghiệp vụ Dự án KEIHISEISAN (経費精算)

> **Mục đích file này**: Tổng hợp nghiệp vụ dự án từ phân tích cấu trúc database + các ghi chú bổ sung theo thời gian.
> Cập nhật lần cuối: 2026-05-15

---

## Giới thiệu chung

**Keihiseisan** (経費精算) là **hệ thống quản lý và thanh quyết toán chi phí** dành cho doanh nghiệp Nhật Bản.
Hệ thống hỗ trợ toàn bộ vòng đời chi phí: ghi nhận → phê duyệt → thanh toán → kiểm toán.

**Tech stack chính**: Spring Boot 2.5, PostgreSQL, Hexagonal Architecture, Keycloak (auth), LINE Clova (OCR), AWS S3.

**Hỗ trợ đa pháp nhân (multi-tenancy)**: Mỗi công ty được phân biệt bằng `hojin_code`.

---

## Quy trình Nghiệp vụ Chính

```
[Nhân viên] Tạo đơn đề nghị (shinsei_joho)
    │
    ├── Thêm chi tiết chi phí (meisai_joho)
    │     ├── Loại 1: Hóa đơn (ryoshusho)         — đính kèm ảnh, OCR tự động nhận dạng
    │     ├── Loại 2: Tuyến đường (keiro)          — tra cứu & chọn tuyến giao thông
    │     └── Loại 3: Phụ cấp ngày (nittou)        — tính theo số ngày
    ├── Hỗ trợ ngoại tệ (gaika) với quy đổi JPY
    ├── Lưu nháp hoặc Gửi phê duyệt
    │
    ▼
[Workflow] Phê duyệt theo tuyến cấu hình sẵn
    │
    ├── Tuần tự (sequential): bước 1 → bước 2 → ...
    ├── Song song (parallel): tất cả bước cùng lúc
    ├── Điều kiện rẽ nhánh (bunki joken): chọn workflow theo điều kiện
    ├── Hỗ trợ phê duyệt thay thế (dairi shonin)
    ├── Cho phép từ chối → gửi lại nhiều vòng (round)
    │
    ▼
[Kế toán] Tổng hợp & Thanh toán
    │
    ├── Gom nhiều đơn → 1 đợt thanh toán (shukei_joho)
    ├── Tạo nhật ký kế toán (shiwake) tự động
    ├── Xuất file kế toán (shiwake_export)
    └── Thanh toán: chuyển khoản ngân hàng hoặc tiền mặt
    │
    ▼
[Quyết toán] Ghi nhận hoàn tất (seisan_joho)
    └── Toàn bộ lịch sử lưu vào keihi_log
```

---

## Cấu trúc Database theo Schema

### Schema: `keihi_com` — Master Data (Danh mục dùng chung)

#### Nhân sự & Tổ chức

| Bảng | Tên tiếng Việt | Mô tả |
|------|----------------|-------|
| `tm_jugyoin` | Nhân viên | Thông tin cá nhân, quyền hạn (level 1-6), tài khoản ngân hàng, cấu hình phê duyệt thay thế |
| `tm_bushokaiso_ptn` | Mẫu phân cấp phòng ban | Cấu trúc tổ chức công ty, hỗ trợ nhiều mẫu phân cấp |
| `tm_bushokaiso_ptn_shosai` | Chi tiết phân cấp phòng ban | Từng nút phòng ban trong cây tổ chức |

#### Danh mục Chi phí & Kế toán

| Bảng | Tên tiếng Việt                   | Mô tả |
|------|----------------------------------|-------|
| `tm_keihi_kamoku` | Danh mục chi phí                 | Loại chi phí, kiểm tra bắt buộc/cảnh báo, giới hạn số tiền, cấu hình validation |
| `tm_hojo_kamoku` | Khoản mục hỗ trợ                 | Sub-account, liên kết với khoa mục tính toán |
| `tm_kanjo_kamoku` | Khoản mục tính toán               | GL account, kết nối với sổ quyết toán, phân loại thuế |
| `tm_zeikubun` | Phân loại thuế                   | Định nghĩa các mức thuế (10%, 8%, 0%, v.v.) |
| `tm_zeiritsu` | Tỷ lệ thuế                       | Tỷ lệ thuế theo thời kỳ |
| `tm_kessansho_kamoku` | Khoa mục sổ quyết toán           | Financial statement account |
| `tm_kessansho_kamoku_bunrui` | Phân loại khoa mục sổ quyết toán | Nhóm phân loại báo cáo tài chính |
| `tm_consumption_tax_deduction` | Khấu trừ thuế tiêu thụ           | Cấu hình khấu trừ thuế tiêu thụ |

#### Workflow & Phê duyệt

| Bảng | Tên tiếng Việt | Mô tả |
|------|----------------|-------|
| `tm_workflow` | Quy trình công việc | Định nghĩa workflow phê duyệt, **có versioning** |
| `tm_workflow_bunki_joken` | Điều kiện rẽ nhánh | Quy tắc chọn workflow theo điều kiện |
| `tm_workflow_wariate` | Phân công workflow | Gán workflow cho từng trường hợp |
| `tm_shonin_route` | Đường dẫn phê duyệt | Tuyến phê duyệt (tuần tự/song song), **có versioning** |
| `tm_shonin_step` | Bước phê duyệt | Chi tiết từng step: số người tối thiểu, điều kiện hoàn thành |
| `tm_shonin_step_uchi_shoninsha` | Người phê duyệt trong step | Danh sách người phê duyệt cho từng bước |
| `tm_bunki_joken_shosai` | Chi tiết điều kiện rẽ nhánh | Giá trị cụ thể của điều kiện |
| `tm_bunki_joken_shosai_chi` | Giá trị điều kiện | Dữ liệu chi tiết cho điều kiện rẽ nhánh |

#### Biểu mẫu & Tùy chỉnh

| Bảng | Tên tiếng Việt | Mô tả |
|------|----------------|-------|
| `tm_shinsei_form` | Biểu mẫu đơn đề nghị | Cấu hình form, liên kết workflow, **có versioning** |
| `tm_shinsei_title_settei` | Cài đặt tiêu đề đơn | Cấu hình tiêu đề mặc định cho đơn đề nghị |
| `tm_customize_komoku` | Trường tùy chỉnh | Cho phép công ty thêm trường riêng vào form |
| `tm_meisai_template` | Template chi tiết | Mẫu chi tiết chi phí tái sử dụng |
| `tm_format_hyoji` | Cấu hình hiển thị | Định dạng hiển thị màn hình |
| `tm_shutsuryoku_komoku` | Mục xuất dữ liệu | Cấu hình các trường xuất báo cáo |
| `tm_shutsuryoku_komoku_shurui` | Loại mục xuất | Phân loại mục xuất dữ liệu |

#### Tài chính & Thanh toán

| Bảng | Tên tiếng Việt | Mô tả |
|------|----------------|-------|
| `tm_ginkou` | Ngân hàng | Danh mục ngân hàng và chi nhánh |
| `tm_shiharai` | Phương thức thanh toán | Cấu hình thanh toán |
| `tm_gaika_shurui` | Loại ngoại tệ | Danh sách tiền tệ hỗ trợ (USD, EUR, v.v.) |
| `tm_gaika_rate` | Tỷ giá ngoại tệ | Lịch sử tỷ giá hối đoái |
| `tm_toroku_bango` | Mã đăng ký hóa đơn | Hỗ trợ Qualified Invoice System (インボイス制度) |
| `tm_shiwake_export` | Cấu hình xuất kế toán | Template xuất file nhật ký kế toán |
| `tm_shiwake_export_sample` | Mẫu xuất kế toán | Dữ liệu mẫu cho xuất kế toán |

#### Giao thông & Tuyến đường

| Bảng | Tên tiếng Việt | Mô tả |
|------|----------------|-------|
| `tm_teiki_kukan` | Tuyến đường định kỳ | Tuyến tàu/xe buýt đăng ký của nhân viên để khấu trừ |
| `tm_keiro_info` | Thông tin tuyến đường | Dữ liệu tra cứu tuyến đường giao thông |
| `tm_keiyu_info` | Thông tin điểm trung gian | Điểm trung gian trên tuyến đường |
| `tm_shiten` | Chi nhánh/Địa điểm | Danh sách địa điểm của công ty |

#### Hệ thống

| Bảng | Tên tiếng Việt | Mô tả |
|------|----------------|-------|
| `tm_mail_template` | Mẫu email | Thông báo qua email cho các sự kiện hệ thống |
| `tm_seigenchi` | Giới hạn hệ thống | Cấu hình giới hạn nghiệp vụ |
| `tm_sso_info` | Thông tin SSO | Cấu hình Single Sign-On |
| `tm_mster_saiban` | Kiểm soát version master | Theo dõi version mới nhất của các master có versioning |

---

### Schema: `keihi_trn` — Transaction Data (Dữ liệu giao dịch)

| Bảng | Tên tiếng Việt | Mô tả |
|------|----------------|-------|
| `tr_shinsei_joho` | Đơn đề nghị | **Đầu não hệ thống**: status (nháp/chờ/từ chối/hoàn thành), liên kết workflow, người đề nghị |
| `tr_shinsei_saiban` | Bộ đếm số đơn | Quản lý số thứ tự tự động cho đơn đề nghị |
| `tr_meisai_joho` | Chi tiết chi phí | Từng dòng chi phí: loại, số tiền, ngoại tệ, mã thuế, khoa mục kế toán |
| `tr_meisai_saiban` | Bộ đếm số chi tiết | Quản lý số thứ tự tự động cho chi tiết |
| `tr_shonin_jokyo` | Trạng thái phê duyệt | Theo dõi tiến trình phê duyệt từng bước |
| `tr_shonin_rogu` | Nhật ký phê duyệt | Lịch sử phê duyệt/từ chối, người phê duyệt, bình luận |
| `tr_shonin_step_uchi_shoninsha_hozon` | Snapshot người phê duyệt | Danh sách người phê duyệt tại thời điểm gửi đơn |
| `tr_shukei_joho` | Tổng hợp thanh toán | Gom nhiều đơn → 1 đợt chi trả, theo dõi tổng tiền |
| `tr_shukei_saiban` | Bộ đếm đợt thanh toán | Số thứ tự tự động cho đợt thanh toán |
| `tr_seisan_joho` | Quyết toán | Ghi nhận hoàn tất thanh toán |
| `tr_shiwake_joho` | Nhật ký kế toán | Journal Entry tự động tạo từ chi tiết chi phí |
| `tr_jizen_shinsei_joho` | Liên kết đơn trước | Liên kết pre-approval với đơn thực tế |
| `tr_ocr_cache` | Cache OCR | Kết quả nhận dạng hóa đơn từ LINE Clova API |
| `tr_ryoshusho_gazo` | Hình ảnh hóa đơn | File ảnh hóa đơn đính kèm (lưu trên S3) |
| `tr_shinsei_kasutamaizu_joho` | Dữ liệu trường tùy chỉnh | Giá trị các trường tùy chỉnh của đơn |
| `tr_shinsei_kasutamaizu_fuairu` | File tùy chỉnh | File đính kèm theo trường tùy chỉnh |
| `tr_shinsei_meisai_relationship` | Quan hệ đơn-chi tiết | Liên kết nhiều-nhiều giữa đơn và chi tiết |
| `tr_kakinshukeiyou_jyugyoin_joho` | Thông tin nhân viên hợp đồng | Quản lý nhân viên theo hợp đồng khấu trừ |

---

### Schema: `keihi_log` — Log/History (Lịch sử & Kiểm toán)

| Bảng | Tên tiếng Việt | Mô tả |
|------|----------------|-------|
| `tl_shinsei_joho_hozon` | Lịch sử đơn đề nghị | Snapshot mọi phiên bản của đơn đề nghị |
| `tl_meisai_joho_hozon` | Lịch sử chi tiết | Snapshot mọi phiên bản của chi tiết chi phí |
| `tl_shinsei_kasutamaizu_joho_hozon` | Lịch sử trường tùy chỉnh | Snapshot trường tùy chỉnh |
| `tl_shinsei_kasutamaizu_fuairu_hozon` | Lịch sử file tùy chỉnh | Snapshot file tùy chỉnh |
| `tl_koshin_rireki` | Nhật ký cập nhật | Audit trail: field nào, giá trị trước/sau, ai, khi nào |
| `tl_sosa_rireki` | Nhật ký thao tác | Mọi hành động người dùng (màn hình, nút bấm) |
| `tl_tsuchi` | Thông báo | Inbox thông báo cho nhân viên (đọc/chưa đọc) |
| `tl_fuairu` | Lịch sử tệp | File đã upload (hóa đơn, tài liệu) |
| `tl_fuairu_shosai` | Chi tiết tệp | Metadata của file upload |
| `tl_uketsuke` | Nhật ký tiếp nhận | Ghi nhận tiếp nhận đơn |
| `tl_syusei_flag` | Cờ chỉnh sửa | Theo dõi chỉnh sửa sau phê duyệt |
| `tl_kakinshukeiyou_jyugyoin_joho_rireki` | Lịch sử nhân viên hợp đồng | Audit cho bảng nhân viên hợp đồng |

---

### Schema: `keihi_ctr` — Connection (Kết nối đa công ty)

| Bảng | Tên tiếng Việt | Mô tả |
|------|----------------|-------|
| `tm_connect` | Kết nối DB | Mapping `hojin_code` → nhóm database (multi-tenancy routing) |

---

## Các Tính năng & Khái niệm Quan trọng

### Version Control cho Master Data
Các bảng sau có **versioning** — thay đổi tạo version mới, không ghi đè:
- `tm_workflow` → `workflow_version`
- `tm_shinsei_form` → `shinsei_form_version`
- `tm_shonin_route` → `shonin_route_version`

Bảng `tm_mster_saiban` theo dõi version mới nhất. Trigger PostgreSQL tự động tăng version khi INSERT.
> Mục đích: Đơn đang xử lý không bị ảnh hưởng khi admin chỉnh sửa cấu hình.

### Soft Delete
Tất cả xóa là **logical delete**: `delete_flag = 1`. Mọi SELECT phải filter `delete_flag = 0`.

### 3 Loại Chi tiết Chi phí (meisai)
| Loại | `toroku_hoho` | Mô tả |
|------|--------------|-------|
| Hóa đơn | 1 | Nhập tay hoặc OCR từ ảnh hóa đơn |
| Tuyến đường | 2 | Chọn từ dữ liệu giao thông, khấu trừ tuyến định kỳ |
| Phụ cấp ngày | 3 | Tính theo số ngày (nittou) |

### Cấu hình Validation Danh mục Chi phí
Mỗi `tm_keihi_kamoku` có thể cấu hình:
- `ryoshusho_tempu_check`: kiểm tra hóa đơn (0=không, 1=lỗi, 2=cảnh báo)
- `jizen_shinsei_bango_check`: kiểm tra số đơn trước
- `memo_check`: kiểm tra ghi chú
- `project_check`: kiểm tra dự án
- `kingaku_jogen_check`: kiểm tra giới hạn tiền
- `kingaku_jogen`: số tiền giới hạn tối đa

### Qualified Invoice System (インボイス制度)
Hỗ trợ hệ thống hóa đơn điện tử của Nhật Bản từ 2023:
- `tm_toroku_bango`: mã đăng ký của nhà cung cấp
- `tr_meisai_joho.toroku_bango`: ghi nhận mã trên từng chi tiết
- Ảnh hưởng đến khả năng khấu trừ thuế đầu vào

### OCR tự động (LINE Clova)
- Upload ảnh hóa đơn → `tr_ryoshusho_gazo`
- LINE Clova phân tích → kết quả cache ở `tr_ocr_cache`
- Tự động điền ngày, số tiền, tên nhà cung cấp vào chi tiết

### Phê duyệt Thay thế (代理承認)
- Nhân viên có thể cấu hình `dairi_shoninsha1/2/3_id` tại `tm_jugyoin`
- Người thay thế có thể phê duyệt khi người phụ trách vắng mặt
- Ghi nhận tại `tr_shonin_rogu.dairi_shonin_umu`

### Pre-approval (事前申請)
- Đơn đề nghị trước (`jizen_shinsei`) được tạo và duyệt trước
- Sau khi chi phí phát sinh, đơn thực tế liên kết qua `tr_jizen_shinsei_joho`
- Dùng cho chi phí lớn cần phê duyệt ngân sách trước

---

## Ghi chú Nghiệp vụ Chi tiết

> Phần này dành để bổ sung các nghiệp vụ phức tạp, edge case, hoặc quy tắc đặc biệt theo thời gian.

<!-- Thêm ghi chú nghiệp vụ tại đây -->

---

## Liên kết Tham khảo

- **API Conventions**: `.claude/rules/api-conventions.md`
- **Database Conventions**: `.claude/rules/database.md`
- **Plans**: `documents/plans/`
