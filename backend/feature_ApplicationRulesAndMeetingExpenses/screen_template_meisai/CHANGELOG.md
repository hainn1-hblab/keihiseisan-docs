# Changelog — Template Meisai (mở rộng) (明細テンプレート)

Theo dõi mọi thay đổi của tài liệu spec cho màn hình này.

Format dựa trên [Keep a Changelog](https://keepachangelog.com/), versioning theo [Semantic Versioning](https://semver.org/):

- **Major (x.0.0)** — Spec gốc thay đổi lớn: đổi flow, đổi business rule cốt lõi, thêm/bỏ màn hình.
- **Minor (1.x.0)** — Bổ sung field mới, thêm validation, design update, PO trả lời câu hỏi clarification.
- **Patch (1.0.x)** — Fix typo, làm rõ wording, không đổi behaviour.

---

## [1.0.0] - 2026-06-04

### Added
- **Phase 1** — `current_state/current_analysis.md` (v1.0.0): snapshot trạng thái HIỆN TẠI của màn
  (schema, API, service logic, UI) làm baseline cho việc extend.
- **Phase 2** — Spec analysis sinh từ sheet `05_Template chức năng mở rộng`:
  - `spec_analysis.md` — phân tích spec extend (đối chiếu baseline).
  - `clarifications.md` — 12 câu hỏi (status 🔴), đã lọc theo current state.
  - `diff_with_current.md` — phân tích diff: 4 field NEW, 3 MODIFIED, 0 REMOVED.
  - Extract 5 ảnh nhúng từ sheet ra `images/` + `raw_dump.txt`.
- Đối chiếu thêm DB design sheet `tm_meisai_template` (db_tables xlsx): xác nhận 4 cột mới
  (`sankasha_template_id`, `gaika_shurui_id`, `en_kansan_kingaku`, `rate`).

### Source
- Spec file: `ApplicationRulesAndMeetingExpenses_20260226_VN.xlsx` (ngày 2026-02-26), sheet `05_Template chức năng mở rộng`.
- DB design: `db_tables_application_rules_meeting_expenses.xlsx`, sheet `tm_meisai_template`.

### Note
- Là màn **EXTEND** — chưa tạo `final_spec.md`. Bước tiếp: gửi `clarifications.md` cho PO/Tech Lead
  (ưu tiên 6.1 và 6.5 — BLOCKER 🔴), sau đó dùng skill `final-spec-merger`.
- Phát hiện 2 sheet liên quan chưa phân tích: `07_Bổ sung màn hình list meisai`, `08_Bổ sung modal` (xem 6.12b).
