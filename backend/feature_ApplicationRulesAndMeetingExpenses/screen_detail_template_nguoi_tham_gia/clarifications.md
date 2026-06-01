---
version: 1.1.0
status: draft
last_updated: 2026-06-01
related_spec: ./spec_analysis.md
related_spec_version: 1.1.0
changelog_file: ./CHANGELOG.md
---

# Clarifications — Template người tham gia (参加者テンプレート)

File này chứa câu trả lời / quyết định cho các câu hỏi nêu trong [`spec_analysis.md` mục 6](./spec_analysis.md).

## Hướng dẫn sử dụng

- **Mỗi câu hỏi** giữ đúng số thứ tự khớp với `spec_analysis.md` mục 6.x để dễ tra cứu.
- **Người trả lời**: ghi rõ tên + vai trò (PO / BA / Tech Lead / QA).
- **Nguồn**: link Slack thread, file meeting note, email, hoặc commit nếu có — để sau này audit được.
- **Status mỗi câu**: `🔴 PENDING` (chưa trả lời) / `🟡 IN-DISCUSSION` (đang bàn) / `🟢 ANSWERED` (đã chốt) / `⚫ DEFERRED` (hoãn sang sprint sau).
- Sau khi tất cả status chuyển sang 🟢 hoặc ⚫ → bump version `spec_analysis.md` lên `1.1.0`, tạo `final_spec.md`, ghi vào `CHANGELOG.md`.

## Tổng quan tiến độ

| Status | Số lượng |
|---|---|
| 🔴 Pending | 14 |
| 🟡 In-discussion | 0 |
| 🟢 Answered | 0 |
| ⚫ Deferred | 0 |
| **Tổng** | **14** |

---

## 6.1 Tên màn hình không nhất quán

**Status**: 🟢 Answered

**Câu hỏi**:
List dùng `参加者テンプレート一覧`; detail dùng `参加人数テンプレート詳細`. Hai cách gọi khác nhau ("**参加者**" vs "**参加人数**") — dùng tên nào là chuẩn? Tên class/API/bảng nên dùng `sankasha` (参加者) hay `sankaninzu` (参加人数)?

**Trả lời**:
dùng tên này nhé 参加者テンプレート詳細画面

**Người trả lời**: DuongDV2(FPM)
**Ngày trả lời**: 28/5/2026
**Nguồn**:https://docs.google.com/spreadsheets/d/1CZFyUKEIbrYgelB_Jc9gfntP0_AkdlCisIdI0TV1kRg/edit?gid=2052317540#gid=2052317540&range=67:67

---

## 6.2 Default 参加人数 = 0 vs validation 1~999

**Status**: 🟢 Answered

**Câu hỏi**:
Spec ghi:
- "Có thể nhập từ 1 đến 999."
- "Giá trị Default là 0"

Nếu default = 0 thì khi submit mà user không sửa thì sẽ fail validation. → Default có nên là `1`? Hay khi submit `0` được tự động hiểu là "không nhập" và bỏ qua validation? Hay validation chỉ kích hoạt khi giá trị ≠ 0?

**Trả lời**:
default = 0, cho phép số người tham gia = 0, validation chỉ kích hoạt khi số người tham gia > 0 (tức là nếu user nhập 0 hoặc để mặc định 0 thì đều hợp lệ, chỉ khi nhập số > 0 mới cần validate max 999)

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.3 "Role 1" là role nào?

**Status**: 🟢 Answered

**Câu hỏi**:
Spec: "Có thể chọn tất cả nhân viên có quyền hạn khác **role 1**". Cần map `role 1` về enum cụ thể trong `Roles` (`SUPER_ADMIN` / `DEPARTMENT_MANAGEMENT` / `KEIRI_MANAGEMENT` / `EMPLOYEE`...). Có khả năng là `SUPER_ADMIN` hoặc `EMPLOYEE` — cần xác nhận.

**Trả lời**:
tìm trong Trong source BE, class Enums Roles để hiểu rõ hơn(backend/src/main/java/jp/co/keihi/application/enums/Roles.java)

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.4 Default 表示順 = 0 (mâu thuẫn convention)

**Status**: 🟢 Answered

**Câu hỏi**:
Spec ghi default `0` nhưng convention dự án (`.claude/rules/database.md`) ghi `hyoji_jun NUMBER(4) defaultValueNumeric="100"`. Áp default nào?

**Trả lời**:
áp dụng default convention của dự án là 100, vì nếu để 0 thì sẽ bị mâu thuẫn với các master

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:không có

---

## 6.5 Đánh số mục trong spec bị lỗi

**Status**: 🟢 Answered

**Câu hỏi**:
Trong text spec, số mục lần lượt là: `1. 参加者テンプレート名`, `2. 参加人数`, `3 他社参加会社名`, `4. Nút cộng`, `5. 自社参加者`, `6. Nút cộng`, `6. 自社参加者メモ` (trùng số 6), `8. 表示順` (nhảy số 7). → Có mục nào bị thiếu (mục 7?) hay chỉ là typo?

**Trả lời**:
chỉ là typo đánh số thôi, không có mục nào bị thiếu. Đúng là 7.自社参加者メモ　　Memo người tham gia thuộc công ty mình

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.6 Quyền truy cập màn hình

**Status**: 🟢 Answered

**Câu hỏi**:
Spec không nêu rõ **role nào** được phép truy cập màn list/detail (tạo, sửa, xoá template). Áp dụng `DEPARTMENT_MANAGEMENT` + `SUPER_ADMIN` như các master khác? Hay riêng `KEIRI_MANAGEMENT` (vì liên quan đến chi phí giao tế)?

**Trả lời**:
áp dụng `DEPARTMENT_MANAGEMENT` + `SUPER_ADMIN` được phép(backend/src/main/java/jp/co/keihi/application/enums/Roles.java)

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.7 Validation chi tiết của các text field

**Status**: 🟢 Answered

**Câu hỏi**:
- `参加者テンプレート名`: max length?
- `他社参加会社名` / tên người tham gia bên ngoài: max length?
- `自社参加者メモ`: max length, có cho xuống dòng không?

Tất cả đều **không** có trong spec — phải tự quyết định hoặc hỏi.

**Trả lời**:
theo file database đã thiết kế tm_sankasha_template & tm_sankasha_template_shosai (backend/documents/feature_ApplicationRulesAndMeetingExpenses/db_tables_application_rules_meeting_expenses.xlsx)

| Field | Max length đề xuất | Cho xuống dòng | Confirm |
|---|---|---|---|
| 参加者テンプレート名 | ? | ❌ | |
| 他社参加会社名 | ? | ❌ | |
| Tên người ngoài | ? | ❌ | |
| 自社参加者メモ | ? | ? | |

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.8 Trùng tên template?

**Status**: 🟢 Answered

**Câu hỏi**:
Có cho phép 2 template trùng `参加者テンプレート名` không? Master pattern của dự án thường cấm trùng `*_code` — nhưng spec không khai báo `code` riêng, chỉ có `name`.

**Trả lời**:
参加者テンプレート名 được require và unique, không cho phép trùng tên template

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.9 Quan hệ với 自社参加者 đã chọn

**Status**: 🟢 Answered

**Câu hỏi**:
Khi nhân viên được chọn vào template sau đó bị **xoá** (delete_flag = 1) hoặc **đổi role thành role 1** thì template phải xử lý thế nào?
- (a) Ẩn dòng đó khi hiển thị?
- (b) Cảnh báo cho user khi mở template?
- (c) Vẫn giữ nguyên trong DB nhưng hiển thị "(Đã xoá)"?
- (d) Tự động xoá dòng đó khỏi template?

**Trả lời**:
Trường hợp người tham gia thuộc công ty mình đã được lưu trong template người tham gia, sau đó người đó bị xóa (delete_flag = 1) hoặc bị thay đổi thành không có quyền (role = 1), thì không tự động xóa dữ liệu template.

Thay vào đó, tại màn hình chi tiết, dữ liệu đó sẽ được hiển thị như dữ liệu không hợp lệ.

Khi người dùng cập nhật hoặc áp dụng template, hệ thống sẽ báo lỗi và yêu cầu người dùng chọn lại hoặc xóa người tham gia đó khỏi template.



**Người trả lời**: DuongDV2(FPM)
**Ngày trả lời**: 01/6/2026
**Nguồn**:https://docs.google.com/spreadsheets/d/1CZFyUKEIbrYgelB_Jc9gfntP0_AkdlCisIdI0TV1kRg/edit?gid=2052317540#gid=2052317540&range=67:67

---

## 6.10 Cặp "他社参加会社名" + tên người ngoài

**Status**: 🟢 Answered

**Câu hỏi**:
Trong mockup 2 ô đứng cạnh nhau như 1 cặp, nhưng spec text gọi là "Tên công ty bên ngoài" + "Tên người tham gia bên ngoài" → mỗi cặp lưu **2 cột** trong DB (`aitesaki_kaisha_mei`, `aitesaki_shimei`). Tuy nhiên label chính trên UI chỉ ghi `他社参加会社名` → người dùng có hiểu được ô thứ 2 là dành cho tên người không? Cần xác nhận label/placeholder của ô thứ 2.

**Trả lời**:
placeholder của ô thứ 2 là "Tên người tham gia bên ngoài" để làm rõ hơn cho user, vì label chính chỉ ghi "Tên công ty bên ngoài

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.11 Mâu thuẫn số ảnh

**Status**: 🟢 Answered

**Câu hỏi**:
Yêu cầu nói "Sheet này có 2 ảnh nhúng" nhưng thực tế extract được **3 ảnh** (`image_B5.png`, `image_A10.png`, `image_A45.png`) tương ứng 3 drawing anchor riêng biệt. Có thể spec coi cụm 2 nút (`image_B5.png`) là "icon" không tính, hoặc thực sự có 3 ảnh.

**Trả lời**:
coi coi cụm 2 nút (image_B5.png) là "icon" không tính

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.12 Bulk delete behaviour

**Status**: 🟢 Answered

**Câu hỏi**:
- Khi click `選択した参加テンプレートを削除` mà không tick row nào → hiển thị warning hay disable nút?
- Có cần confirm dialog trước khi xoá không?
- Single delete (`削除`) có confirm dialog không?

**Trả lời**:
Xác nhận với convention dự án + hệ thống hiện tại

| Hành động | Behaviour đề xuất | Confirm |
|---|---|---------|
| Bulk delete khi không tick gì | Disable nút | đúng    |
| Bulk delete khi có tick | Hiện confirm dialog | đúng    |
| Single delete | Hiện confirm dialog | đúng    |

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.13 Pagination

**Status**: 🟢 Answered

**Câu hỏi**:
Page size mặc định trong screenshot là `20件`. Có cho phép user đổi không? Các option page size?

**Trả lời**:
_ hệ thống FE hiện tại đang dùng page size truyền lên là 50


**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet

---

## 6.14 Sort

**Status**: 🟢 Answered

**Câu hỏi**:
Cột nào trong list được phép sort? Default sort theo `表示順` ASC?

**Trả lời**:
default FE sẽ truyền lên sort theo cột 表示順, direction ASC

| Cột | Cho sort | Default sort | Direction |
|---|---|---|---|
| 参加者テンプレート名 | ? | | |
| 参加人数 | ? | | |
| 表示順 | ? | ✓ (gợi ý) | ASC (gợi ý) |

**Người trả lời**: DucNA1(Lead BE)
**Ngày trả lời**: 28/5/2026
**Nguồn**:Đã trao đổi trong meet
---


## 6.15 Access control vs Ownership (mâu thuẫn schema)

**Status**: 🟢 ANSWERED

**Câu hỏi**:
Schema có `tm_sankasha_template.jugyoin_id` (owner per-employee) nhưng clarification 6.6 chỉ cho phép `DEPARTMENT_MANAGEMENT` + `SUPER_ADMIN` truy cập màn quản lý. Vậy:
- Admin có sửa template của nhân viên khác không?
- Nhân viên thường có vào màn quản lý template của chính mình không?

**Trả lời**:
Techlead BE confirm: tm_sankasha_template.jugyoin_id sẽ được set bằng `super.getLoginJugyoinId()` . User không phải role 5, 6 vẫn có thể tạo template người tham gia(thông qua màn tạo meisai && chọn lưu template(đã có đính kèm thông tin người tham gia)) nhưng chỉ thấy template của chính mình đã tạo(thông qua khi tạo meisai chọn template meisai muốn chọn). 

User role 5, 6 không có thể thấy/sửa template của nhân viên trong công ty(chỉ view được của chính mình)
User role 5, 6 có thể tạo template meisai master và có thể tạo template người tham gia master để tham chiếu vào template meisai master nhưng không thể thấy/sửa template người tham gia của nhân viên trong công ty(chỉ view được của chính mình)

**Người trả lời**: Lead BE (DucNA1)
**Ngày trả lời**: 2026-06-01
**Impact**:
- Đã update final_spec.md section 4.7, 5.1 unique constraint.
- final_spec bump v1.0.0 → v1.1.0.

## 6.16 Template lưu chung 1 bảng hay tách bảng?

**Status**: 🟢 ANSWERED

**Câu hỏi**:
Template tạo từ luồng A (qua màn meisai) và luồng B (qua menu Setting, role 5/6) lưu chung 1 bảng `tm_sankasha_template` hay riêng?
Có cần thêm cột `template_kubun` (1=cá nhân, 2=master) để phân biệt không?

**Trả lời**: Lưu CHUNG 1 bảng `tm_sankasha_template`. KHÔNG cần thêm cột `template_kubun`. "Template master" và "template cá nhân" giống hệt nhau về data, chỉ khác entry point UI (màn meisai vs menu Setting).

**Người trả lời**: Lead BE (DucNA1)
**Ngày trả lời**: 2026-06-01
**Impact**: final_spec.md section 5.1 giữ nguyên schema, không phát sinh column mới.

---

## 6.17 Master template có share giữa các user không?

**Status**: 🟢 ANSWERED

**Câu hỏi**:
Template do role 5, 6 tạo từ menu Setting có được dùng làm master tham chiếu cho `tm_meisai_template` của user khác không?

**Trả lời**: KHÔNG. Mọi user (kể cả role 5, 6) chỉ thấy/dùng được template do CHÍNH MÌNH tạo. Filter cố định: `WHERE jugyoin_id = current_user`. Khi insert: `jugyoin_id = super.getLoginJugyoinId()`.

Nghĩa là không có khái niệm "shared template" giữa các user trong cùng công ty. Master và cá nhân giống nhau về data.

**Người trả lời**: Lead BE (DucNA1)
**Ngày trả lời**: 2026-06-01
**Impact**:
- API search: backend luôn add filter `jugyoin_id = current_user`, không cho FE override.
- API create: `jugyoin_id` set tự động từ context, không nhận từ request body.

---

## 6.18 Unique constraint scope

**Status**: 🟢 ANSWERED

**Câu hỏi**:
Unique scope là `(hojin_code, jugyoin_id, sankasha_template_name, delete_flag)`? Nghĩa là user A và user B có thể cùng đặt tên `○○社用`?

**Trả lời**: Đúng. Unique scope = `(hojin_code, jugyoin_id, sankasha_template_name, delete_flag)`. User A và user B trong cùng `hojin_code` có thể cùng đặt tên template `○○社用` mà không bị conflict.

**Người trả lời**: Lead BE (DucNA1)
**Ngày trả lời**: 2026-06-01
**Impact**: Liquibase changeset tạo unique index với đúng scope này. API create check E040 với điều kiện `WHERE hojin_code = ? AND jugyoin_id = ? AND name = ? AND delete_flag = 0`.

## Sign-off

Khi tất cả 14 câu hỏi đã chuyển sang status 🟢 hoặc ⚫:

- [ ] PO sign-off: __________________ Ngày: __________
- [ ] BA sign-off: __________________ Ngày: __________
- [ ] Tech Lead sign-off: __________________ Ngày: __________
- [ ] Bump `spec_analysis.md` version lên 1.1.0
- [ ] Tạo `final_spec.md`
- [ ] Ghi entry vào `CHANGELOG.md`
