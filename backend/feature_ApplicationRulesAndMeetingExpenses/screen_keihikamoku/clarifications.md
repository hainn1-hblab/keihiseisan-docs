---
version: 1.0.0
status: pending
last_updated: 2026-06-05
related_spec: ./spec_analysis.md
related_spec_version: 1.0.0
changelog_file: ./CHANGELOG.md
---

# Clarifications — Màn 経費科目 (KeihiKamoku) EXTEND "参加者入力 / 会議費"

File này chứa câu trả lời cho các câu hỏi trong [`spec_analysis.md` mục 6](./spec_analysis.md).
Khi tất cả câu trả lời → tạo `final_spec.md` (dùng skill `final-spec-merger`).

## Tổng quan tiến độ

| Status | Số lượng |
|---|---|
| 🔴 Pending | 9 |
| 🟡 In-discussion | 0 |
| 🟢 Answered | 0 |
| ⚫ Deferred | 0 |
| **Tổng** | **9** |

**Severity**: 🔴 High = 3 (6.1, 6.5, 6.9) · 🟡 Medium = 4 (6.2, 6.3, 6.4, 6.6) · 🟢 Low = 2 (6.7, 6.8)

---

## 6.1 maxlength `一人当たり上限金額` — 5 hay 11? — 🔴 High

**Status**: 🟢 Answered

**Câu hỏi**:
Spec sheet 02 R77 ghi `maxlength: 5` (tối đa 99,999円) nhưng file DB design `tm_keihi_kamoku.hitori_atari_jogen_kingaku` = numeric(11). Lấy giá trị nào? (Ví dụ 会議費=10,000円 thì cả 2 đều fit, nhưng quyết định ảnh hưởng `@Range` của DTO + độ rộng cột schema.)

**Trả lời**:
Lấy theo spec maxlength = 5 (tối đa 99,999円). DB có thể để numeric(11) để dự phòng các trường hợp đặc biệt (vd tiếp khách cao cấp), nhưng spec chính thức là 5 chữ số. Nếu sau này có thay đổi → update spec + DB schema.

**Người trả lời**: DucNA1
**Ngày trả lời**: 8/6/2026
**Nguồn**: 
**Impact**: Schema (column length) + validation DTO (`@Range`/`@Size`).

---

## 6.2 Khi master checkbox ON, field con có bắt buộc không? — 🟡 Medium

**Status**: 🟢 Answered

**Câu hỏi**:
Khi `sankasha_nyuryoku_hitsuyo_flag` = 1:
- `hitori_atari_jogen_check_kubun` có buộc ≠ 0 (phải chọn エラー hoặc アラート) không, hay được phép để 無し(0)?
- Nếu chọn エラー/アラート thì `hitori_atari_jogen_kingaku` có buộc > 0 không (giống pattern `checkJogenKingaku` hiện tại)?
- `hitori_atari_jogen_message` xác nhận optional (R81 "có thể để trống")?

**Trả lời**:
khi master checkbox ON (1) → `hitori_atari_jogen_check_kubun` có thể là 0 (無し), không bắt buộc phải chọn エラー/アラート. Nếu chọn エラー/アラート thì `hitori_atari_jogen_kingaku` phải > 0. `hitori_atari_jogen_message` optional, có thể để trống.

**Người trả lời**: DucNA1
**Ngày trả lời**: 8/6/2026
**Nguồn**: 
**Impact**: Validation logic trong `addKeihiKamoku`/`updateKeihiKamoku`.

---

## 6.3 Reset value khi tắt master checkbox — 🟡 Medium

**Status**: 🟢 Answered

**Câu hỏi**:
Khi `sankasha_nyuryoku_hitsuyo_flag` chuyển 1→0 (hoặc tắt các cờ con), BE có reset `hitori_atari_jogen_kingaku`/`check_kubun`/`message` và 4 cờ con về default (0/null) — giống cách `checkJogenKingaku`/`checkKakoNissu` reset hiện tại — hay giữ nguyên giá trị đã nhập?

**Trả lời**:
Tạm thời expect giữ nguyên giá trị cũ khi tắt master checkbox, chỉ disable UI trên FE. Nếu sau này có thay đổi → update spec + cascade update final_spec.md.

**Người trả lời**: DucNA1
**Ngày trả lời**: 8/6/2026
**Nguồn**: 
**Impact**: Service logic + dữ liệu lưu.

---

## 6.4 Ràng buộc phụ thuộc giữa các cờ (hissu vs nyuryoku/sentaku) — 🟡 Medium

**Status**: 🟢 Answered

**Câu hỏi**:
- `tasha_sankasha_hissu_flag` (#6) có được phép = 1 khi `tasha_sankasha_nyuryoku_flag` (#5) = 0 không?
- `jisha_sankasha_hissu_flag` (#8) có được phép = 1 khi `jisha_sankasha_sentaku_flag` (#7) = 0 không?
- BE có cần validate ràng buộc này (ném BadRequest) hay chỉ FE disable checkbox?

**Trả lời**:
chỉ FE disable checkbox #6 nếu #5 chưa check, disable checkbox #8 nếu #7 chưa check. BE không validate ràng buộc này để tránh lỗi khi có data cũ (backward compatibility). Nếu sau này có thay đổi → update spec + cascade update final_spec.md.

**Người trả lời**: DucNA1
**Ngày trả lời**: 8/6/2026
**Nguồn**: 
**Impact**: Validation rule (BE + FE).

---

## 6.5 Quan hệ với 3 field "出席者登録" đã chết — 🔴 High

**Status**: 🟢 Answered

**Câu hỏi**:
Baseline hiện tại có 3 field đang bị ép = 0 (dead): `shussekisha_toroku_umu` (出席者登録有無), `shussekisha_toroku_check` (出席者登録チェック), `jizen_shinsei_bango_check` (事前申請番号チェック). Spec mới thêm cột MỚI prefix `sankasha_*` (participant) thay vì tái dùng. Xác nhận:
1. Đúng là KHÔNG tái dùng cột cũ, thêm 8 cột mới?
2. 3 field cũ (出席者) giữ nguyên dead hay cần cleanup/migrate?
3. Khái niệm 出席者(attendee) cũ và 参加者(participant) mới có liên quan/đụng nhau ở màn nào không?

**Trả lời**:
Không tái dùng 3 cột cũ, thêm 8 cột mới. 3 field cũ giữ nguyên (dead) để tránh ảnh hưởng data/meisai cũ, không cleanup để đảm bảo backward compatibility. Khái niệm 出席者(attendee) cũ và 参加者(participant) mới không liên quan

**Người trả lời**: DucNA1
**Ngày trả lời**: 8/6/2026
**Nguồn**: 
**Impact**: Schema (cleanup?), tránh nhầm lẫn nghiệp vụ.

---

## 6.6 Guard "đang dùng trong meisai" khi tắt cờ sankasha — 🟡 Medium

**Status**: 🔴 Pending

**Câu hỏi**:
Hiện tại update có guard `E152`: không cho tắt cờ 選択可能性 nếu mục chi phí đang được dùng trong meisai. Với `sankasha_nyuryoku_hitsuyo_flag` (hoặc các cờ con): nếu mục chi phí đã có meisai chứa thông tin người tham gia, admin tắt cờ → có chặn (giống E152) hay cho phép tắt (data participant cũ giữ nguyên, chỉ ẩn UI lần sau)?

**Trả lời**:
<Để trống>

**Người trả lời**: 
**Ngày trả lời**: 
**Nguồn**: 
**Impact**: Validation update + xử lý data meisai cũ (cross-screen CS-3).

---

## 6.7 Scope màn list 経費科目一覧 (table/search/CSV) — 🟢 Low

**Status**: 🟢 Answered

**Câu hỏi**:
Sheet `06_màn ảnh hưởng` (R37-39) note "keihikomoku: table list hiển thị / điều kiện search / import-download csv". Với 8 field mới:
- Màn list 経費科目一覧 có cần thêm cột hiển thị / điều kiện search không?
- CSV import/export của 経費科目 (`KeihiKamokuCsvDto`) có cần thêm 8 cột không?
- Hay spec 02 chỉ giới hạn ở modal detail?

**Trả lời**:
- màn list không thêm điều kiện search nhưng sẽ thêm cột hiển thị 8 field mới.
- CSV import/export sẽ thêm 8 cột mới để đồng bộ với modal detail (đảm bảo consistency

**Người trả lời**: DucNA1
**Ngày trả lời**: 8/6/2026
**Nguồn**: 
**Impact**: Scope FE list + CSV DTO.

---

## 6.8 Đổi label section `アクション・カラー設定` → `アラート・エラー設定` — 🟢 Low

**Status**: 🔴 Pending

**Câu hỏi**:
Ảnh spec dùng tiêu đề `アラート・エラー設定` cho nhóm cờ check (hiện tại UI/code gọi `アクション・カラー設定`). Đây chỉ là đổi label hiển thị, không đổi logic/field — xác nhận đúng?

**Trả lời**:
<Để trống>

**Người trả lời**: 
**Ngày trả lời**: 
**Nguồn**: 
**Impact**: UI label (FE).

---

## 6.9 Quy trình regenerate API model `KeihiKamoku` — 🔴 High

**Status**: 🟢 Answered

**Câu hỏi**:
Baseline §9.3: model `KeihiKamoku` (+ `ListKeihiKamoku`, `KeihiKamokuSearchParameter`) được generate bởi SpringCodegen ngày 2021-04-22 từ 1 spec KHÔNG nằm trong `api_interface_generate_tool/specification/openapi.yml` (grep `keihi-kamoku` → no match). Để thêm 8 field vào request/response:
- Có file OpenAPI spec nguồn (cũ) cho keihi-kamoku ở đâu để regenerate?
- Hay được phép sửa class model `KeihiKamoku.java` bằng tay?

**Trả lời**:
- Không tìm thấy file OpenAPI spec nguồn cho keihi-kamoku, có thể do spec cũ đã bị mất hoặc chưa được version control tốt. Cần xác nhận lại với team về quy trình generate API model để tránh mất đồng bộ trong tương lai.
- Cho phép sửa class model `KeihiKamoku.java` bằng tay để thêm 8 field mới

**Người trả lời**: DucNA1
**Ngày trả lời**: 8/6/2026
**Nguồn**: 
**Impact**: Cách triển khai tầng API model.

---

## Quy tắc cập nhật

1. KHÔNG xóa câu hỏi đã trả lời.
2. Update status: 🔴 → 🟡 → 🟢 hoặc 🔴 → ⚫ (deferred).
3. Nếu câu trả lời ĐỔI sau khi đã 🟢 → ghi rõ "UPDATED <date>" + lý do, KHÔNG xóa câu cũ.
4. Khi câu trả lời đổi → cascade update final_spec.md (skill final-spec-merger).
5. Bump version: Patch=clarification nhỏ · Minor=3+ câu mới · Major=scope đổi.

## Sign-off

Khi tất cả câu hỏi đã chuyển sang status 🟢 hoặc ⚫:

- [ ] PO sign-off: __________________ Ngày: __________
- [ ] BA sign-off: __________________ Ngày: __________
- [ ] Tech Lead sign-off: __________________ Ngày: __________
- [ ] Bump `spec_analysis.md` version
- [ ] Tạo / Update `final_spec.md`
- [ ] Ghi entry vào `CHANGELOG.md`
