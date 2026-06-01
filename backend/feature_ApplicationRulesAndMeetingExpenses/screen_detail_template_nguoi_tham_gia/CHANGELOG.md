# Changelog — Template người tham gia (参加者テンプレート)

Theo dõi mọi thay đổi của tài liệu spec cho màn hình "Template người tham gia".

Format dựa trên [Keep a Changelog](https://keepachangelog.com/), versioning theo [Semantic Versioning](https://semver.org/):

- **Major (x.0.0)** — Spec gốc thay đổi lớn: đổi flow, đổi business rule cốt lõi, thêm/bỏ màn hình.
- **Minor (1.x.0)** — Bổ sung field mới, thêm validation, design update, PO trả lời câu hỏi clarification.
- **Patch (1.0.x)** — Fix typo, làm rõ wording, không đổi behaviour.

---

## [1.2.0] - 2026-06-01

### Changed
- `final_spec.md` bumped to v1.1.0 — resolved TBD #4 (access control vs ownership).
- `clarifications.md` bumped to v1.1.0 — added 3 new Q&A entries (6.16, 6.17, 6.18) làm rõ access model.

### Resolved
- Mô hình 2 entry point tạo template (qua màn meisai + qua menu Setting) đã được Tech Lead confirm.
- Schema KHÔNG cần thêm cột `template_kubun`.
- Filter cố định `jugyoin_id = current_user`, không có shared template.
- Unique constraint scope = `(hojin_code, jugyoin_id, sankasha_template_name, delete_flag)`.

### Notes
- final_spec.md status đổi từ `partial-ready` → [`ready-for-implementation` hoặc `partial-ready`] (tuỳ kết quả Việc 2).
- Sẵn sàng tiến hành: viết Liquibase changeset → Entity → Repository.

## [1.1.0] - 2026-06-01

### Added
- File `final_spec.md` — spec chốt để implement (merge spec_analysis + clarifications + DB design xlsx).

### Changed
- `final_spec.md` v1.1.0: resolve TBD #4 (High) theo Tech Lead BE — template owner-scoped (`jugyoin_id = loginJugyoinId`); nâng status lên ready-for-implementation.

### Source
- Tech Lead BE confirm (owner-scoped access control).
- PO/BA trả lời 13/14 câu clarifications (meeting 2026-05-28); mục 6.9 còn pending.
- Schema từ `db_tables_application_rules_meeting_expenses.xlsx`.


## [1.1.0] - 2026-05-28

### Added
- File `final_spec.md` v1.0.0 — merge `spec_analysis.md` + `clarifications.md` + DB design xlsx.
### Source
    - Câu hỏi cần PO trả lời:
        - Admin có sửa template của user khác không?
        - Nhân viên thường (REGISTRATION / APPROVED) có quản lý template cá nhân không?
        - Khi admin tạo, jugyoin_id set = chính admin hay set theo user nào?
    - Quyết định sai sẽ phải sửa: unique constraint scope, owner logic ở service, dropdown filter user — ảnh hưởng schema + API contract.

### Source
- PO/BA trả lời 13/14 câu clarifications trong meeting 2026-05-28.
- Schema từ `db_tables_application_rules_meeting_expenses.xlsx`.


## [1.0.0] - 2026-05-28

### Added
- Initial spec analysis sinh tự động bằng Claude Code CLI từ sheet `Detail template nguoi tham gia` trong file `ApplicationRulesAndMeetingExpenses_20260226_VN.xlsx`.
- File `spec_analysis.md` — phân tích đầy đủ 2 màn hình (List + Detail), business rule, validation, 14 câu hỏi cần làm rõ.
- File `clarifications.md` — template trống để PO/BA trả lời 14 câu hỏi.
- Extract 3 ảnh nhúng từ sheet ra `images/` (action buttons, mockup Detail, screenshot List).

### Source
- Spec file: `ApplicationRulesAndMeetingExpenses_20260226_VN.xlsx` (ngày 2026-02-26)
- Sheet: `Detail template nguoi tham gia`

---

<!--
HƯỚNG DẪN GHI ENTRY MỚI:

Khi cập nhật spec, copy template dưới đây vào trên cùng (dưới dòng "---" gần nhất):

## [x.y.z] - YYYY-MM-DD

### Added
- (Tính năng/field/section mới được thêm vào)

### Changed
- (Thay đổi behaviour hoặc nội dung đã có)

### Fixed
- (Sửa lỗi/typo/mâu thuẫn trong spec)

### Removed
- (Bỏ field/section khỏi spec)

### Source
- (Nguồn của thay đổi: PO confirm tại Slack/Meeting/Email/Update file xlsx mới...)
-->
