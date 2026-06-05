---
version: 1.1.0
status: draft
last_updated: 2026-06-04
related_spec: ./spec_analysis.md
related_spec_version: 1.0.0
changelog_file: ./CHANGELOG.md
---

# Clarifications — Template Meisai (mở rộng)

File này chứa câu trả lời / quyết định cho các câu hỏi nêu trong [`spec_analysis.md` mục 6](./spec_analysis.md).
Đây là màn EXTEND — câu hỏi đã được lọc dựa trên baseline [`current_analysis.md`](./current_state/current_analysis.md)
(loại bỏ những gì code hiện tại đã trả lời).

## Tổng quan tiến độ

| Status | Số lượng |
|---|---|
| 🔴 Pending | 12 |
| 🟡 In-discussion | 0 |
| 🟢 Answered | 0 |
| ⚫ Deferred | 0 |
| **Tổng** | **12** |

Severity: 🔴 High = 2 (6.1, 6.5) · 🟡 Medium = 8 · 🟢 Low = 2 (6.4, 6.9)

---

## 6.1 Giá trị `torokuHoho` cho 2 mode mới  — [BLOCKER 🔴 High]

**Status**: 🟢 Answered

**Câu hỏi**:
Hiện `toroku_hoho` = `1:領収書, 2:経路, 3:日当, 4:経路API`, validation chỉ nhận `1|2|4`. 2 mode mới
`領収書（外貨）明細登録用` và `外貨レート証明書登録用` mã hóa thế nào?
(A) Thêm giá trị mới (vd `5`, `6`) vào `toroku_hoho`; hoặc
(B) Tái dùng `torokuHoho=1` + 1 cờ phân biệt (DB sheet KHÔNG có cột cờ → nghiêng A).
Em nghiêng (A). Anh/chị confirm + cho giá trị cụ thể giúp em.

**Trả lời**: Trong class enum trong source(backend/src/main/java/jp/co/keihi/application/enums/TorokuHoho.java) đã định nghĩa cho 2 loại meisai liên quan đến ngoại tệ đã đánh mã là 5 và 6. Cụ thể:
-   /** The receipt (foreign currency)：領収書（外貨）. */
    RECEIPT_GAIKA("5", "領収書明細（外貨）"),

- /** The foreign exchange rate certificate：外貨レート証明書. */
GAIKA_RATE_SHOMEISHO("6", "レート証明書明細");

→ Validation regex DTO phải đổi từ 1|2|4 → 1|2|4|5|6.
→ SearchParamDto.torokuHohos regex cũng phải đổi.
→ Branch logic trong Service phải thêm case xử lý 5 và 6.

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: schema (type `toroku_hoho`), validation regex DTO + SearchParamDto, branch logic add/update, filter list. Phải chốt TRƯỚC khi viết Liquibase + validation.

---

## 6.2 Setting bật/tắt chức năng ngoại tệ — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Field/setting nào của công ty quyết định bật ngoại tệ (ẩn/hiện 2 mode + 4 field)? Có sẵn trong
`TmKaisha`/`KaishaDto` không, key là gì? BE có cần chặn create/update/delete khi setting tắt không (A88/A160)?

**Trả lời**: field gaikaRiyoUmu trong TmKaisha đã quy định công ty có sử dụng chức năng ngoại tệ hay không. BE cần check xem trường đó có được bật không, chặn create/update/delete khi setting tắt không

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: điều kiện hiển thị (FE) + có thể thêm guard ở service (BE).

---

## 6.3 `円換算金額` — ai tính & quy tắc làm tròn — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
BE tự tính `enKansanKingaku = kingaku × rate` (bỏ qua giá trị FE) hay tin FE? Quy tắc làm tròn
(round/floor/ceil) và số chữ số (mockup hiển thị `15,000` = số nguyên yên)?

**Trả lời**: FE sẽ tự tính và gửi cả `enKansanKingaku` lên BE. Các quy tắc làm tròn FE quyết định và tự handle

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: logic service (mục 4.1 spec_analysis).

---

## 6.4 Bắt buộc & định dạng các field ngoại tệ — [🟢 Low]

**Status**: 🟢 Answered

**Câu hỏi**:
`外貨の種類`, `外貨金額`, `レート` có required khi ở mode ngoại tệ không? Số thập phân: 外貨金額 = 2
(`100.00`), rate = 4 (`150.0000`) — đúng không? Range hợp lệ của rate?

**Trả lời**: phần validate dto lấy giống trong MeisaiJohoDto

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: `@Size`/`@Digits`/validation group trong DTO.

---

## 6.5 Ngữ nghĩa `kingaku` ở mode ngoại tệ — [BLOCKER 🔴 High]

**Status**: 🟢 Answered

**Câu hỏi**:
Xác nhận: ở mode ngoại tệ, cột `kingaku` lưu **số tiền ngoại tệ** (外貨金額), `enKansanKingaku` lưu số tiền yên.
Hiện `kingaku` ở 領収書 thường đang là số tiền yên → đây là **đổi ngữ nghĩa theo mode**. FE/BE phải thống nhất
để không lưu nhầm. Đúng không?

**Trả lời**:
ở mode ngoại tệ(dùng cho template 領収書（外貨）torokuhoho = 5), cột kingaku sẽ lưu số tiền ngoại tệ, còn cột enKansanKingaku sẽ lưu số tiền yên đã được quy đổi. 

ở mode thường (dùng cho template 領収書 torokuhoho = 1), cột kingaku sẽ lưu số tiền yên, còn cột enKansanKingaku sẽ để null. áp dụng điều này cho template 外貨レート証明書 (torokuhoho = 6), cột kingaku sẽ lưu số tiền yên, còn cột enKansanKingaku sẽ để null. (có thể hiểu loại 1 vs loại 6 coi như giống nhau)

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: breaking semantic — mapping FE↔BE, logic save, hiển thị list (cột 金額).

---

## 6.6 Hành vi "áp dụng 参加者テンプレート" — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Khi chọn `参加者テンプレートを適用する`, BE lưu gì vào template meisai? Chỉ lưu `sankashaTemplateId` (reference)
hay copy snapshot danh sách người tham gia? Khi sankasha template bị xóa → meisai template xử lý thế nào
(set null / giữ / báo lỗi)?

**Trả lời**: xác nhận:  Khi chọn 参加者テンプレートを適用する, BE Chỉ lưu sankashaTemplateId vào template meisai.

> ⚠️ **CHANGED 2026-06-04 (FPM revise)** — phương án cascade khi xóa sankasha_template:
> - ~~Phương án CŨ: set NULL `sankashaTemplateId` ở các meisai template tham chiếu.~~
> - **Phương án MỚI (chốt): BLOCK xóa** `sankasha_template` nếu còn ≥1 `tm_meisai_template` (`delete_flag=0`) đang tham chiếu.
>
> **6.6.Q1 — Error message**: hiển thị dạng "{tên sankasha} đang được sử dụng trong meisai template, không xóa được".
>   → Cần message key MỚI. **Lưu ý: E158 ĐÃ BỊ DÙNG** (`messages.properties:188`) → dùng **E180** (key trống tiếp theo).
>   Đề xuất: `E180={0}は明細テンプレートで使用されているため、削除できません。` (PO/FE tinh chỉnh wording).
> **6.6.Q2 — Scope**: áp cho **cả single delete VÀ bulk delete**. Bulk: nếu có ≥1 cái bị block → **fail toàn bộ** (atomic, không xóa cái nào).
> **6.6.Q3 — Đếm**: chỉ count meisai template có `delete_flag=0` (đã soft delete = không tính).
>
> Impact: `SankashaTemplateService.deleteOne()`/`deleteList()` thêm pre-check; meisai-template final_spec §4.4 (TBD#3 RESOLVED); sankasha final_spec §4.9 (mới).

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04 (revise cascade behaviour)
**Nguồn**:
**Impact**: logic delete sankasha (BLOCK) + FK behaviour (cột `sankasha_template_id`).

---

## 6.7 Scope áp dụng 参加者テンプレート — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Xác nhận 参加者テンプレート áp dụng cho 領収書 + 領収書（外貨）, KHÔNG cho 外貨レート証明書 (A162). Có áp dụng cho
経路/経路API không (current không có field này ở 経路)?

**Trả lời**: xác nhận không áp dụng cho 外貨レート証明書 (A162). 参加者テンプレート chỉ áp dụng cho 領収書 + 領収書（外貨）, KHÔNG áp dụng cho 経路/経路API.

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: hiển thị pulldown theo mode + validation.

---

## 6.8 Loại `外貨レート証明書` có dùng 4 cột ngoại tệ không? — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Mockup A168 chỉ có `金額` (yên), không có field ngoại tệ — dù tên loại là "外貨レート証明書". Xác nhận loại này
**KHÔNG** ghi `gaikaShuruiId/rate/enKansanKingaku` và `kingaku` = số tiền yên?

**Trả lời**: xác nhận loại 外貨レート証明書 không ghi gaikaShuruiId/rate/enKansanKingaku, cột kingaku sẽ lưu số tiền yên, còn cột enKansanKingaku sẽ để null. (có thể hiểu loại 外貨レート証明書 coi như giống loại 領収書 về mặt dữ liệu, chỉ khác về mặt hiển thị và mục đích sử dụng).

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: branch logic + validation theo mode.

---

## 6.9 Nguồn dropdown `外貨の種類` — [🟢 Low]

**Status**: 🟢 Answered

**Câu hỏi**:
Dropdown lấy từ master GaikaShurui hiện có (theo công ty)? Lưu `gaikaShuruiId` (VARCHAR 29) — đúng kiểu?
(Hệ thống đã có `GaikaShuruiService`/`GaikaShuruiApi`.)

**Trả lời**:
Dropdown sẽ lấy từ master GaikaShurui theo công ty(hojinCode rồi). BE sẽ lưu gaikaShuruiId (VARCHAR 29) vào cột gaika_shurui_id của bảng tm_meisai_template.

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: chỉ confirm nguồn dữ liệu, không đổi schema.

---

## 6.10 Tabs/filter ở màn list khi bật ngoại tệ — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Khi bật ngoại tệ, list có bao nhiêu tab (領収書 / 経路 / 領収書(外貨) / 外貨レート証明書)? Giá trị `torokuHohos`
filter cho mỗi tab (liên quan 6.1)?

**Trả lời**: xác nhận khi bật ngoại tệ, list sẽ có 4 tab: 領収書 (filter torokuHoho = 1), 経路 (filter torokuHoho = 2 hoặc 4), 領収書(外貨) (filter torokuHoho = 5), 外貨レート証明書 (filter torokuHoho = 6).

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: search behaviour + validation `torokuHohos`.

---

## 6.11 Role check — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Spec không nhắc role. Xác nhận giữ nguyên 4 role hiện tại (DEPARTMENT_MANAGEMENT, SUPER_ADMIN, APPROVED,
REGISTRATION) cho cả mode mới?

**Trả lời**: oke xác nhận giữ nguyên 4 role hiện tại (DEPARTMENT_MANAGEMENT, SUPER_ADMIN, APPROVED, REGISTRATION) cho cả mode mới. BE sẽ check role ở service layer bằng method `RoleUtil.checkRolesAllow(...)` như hiện tại, không đổi.

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: `checkRolesAllow()` — nếu đổi thì sửa 1 chỗ.

---

## 6.12 OpenAPI spec source & sheet 07/08 — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
(a) Endpoint `MeisaiTemplate` KHÔNG nằm trong `api_interface_generate_tool/specification/openapi.yml` đang track.
Cần xác định file spec nào để thêm 4 field + giá trị torokuHoho mới (hay model đã gen tay)?
(b) Sheet `07_Bổ sung màn hình list meisai` và `08_Bổ sung modal` có bổ sung gì cho màn này ngoài sheet 05 không?
Có cần phân tích tiếp 2 sheet đó để không sót yêu cầu?

**Trả lời**: a, nếu không tìm thấy thì thôi, hiện swagger ui vẫn hiển thị endpoint đó, có thể là file openapi khác hoặc model gen tay. b, 2 sheet đó KHÔNG bổ sung gì ngoài sheet 05, không cần phân tích tiếp.

**Người trả lời**: DucNA1
**Ngày trả lời**: 2026-06-04
**Nguồn**:
**Impact**: xác định nguồn để extend API contract + tránh sót scope.

---

## Sign-off

Khi tất cả 12 câu hỏi đã chuyển sang status 🟢 hoặc ⚫:

- [ ] PO sign-off: __________________ Ngày: __________
- [ ] BA sign-off: __________________ Ngày: __________
- [ ] Tech Lead sign-off: __________________ Ngày: __________
- [ ] Bump `spec_analysis.md` version lên 1.1.0
- [ ] Tạo / Update `final_spec.md`
- [ ] Ghi entry vào `CHANGELOG.md`
