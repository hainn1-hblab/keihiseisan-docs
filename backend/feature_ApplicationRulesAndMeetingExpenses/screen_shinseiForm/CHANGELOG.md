# CHANGELOG — 申請フォーム (ShinseiForm) — feature ApplicationRulesAndMeetingExpenses

Theo Semantic Versioning (xem `.claude/rules/spec-versioning.md`).

---

## [liquibase v1.0.0] — 2026-06-09
### Added
- Tạo các Liquibase changeset cho phase EXTEND (chạy trước khi implement API):
  - ALTER `keihi_com.tm_shinsei_form` — thêm 13 cột (changeset `20260514_tm_shinsei_form_add_application_rules`) + rollback.
  - Tạo 4 bảng con versioned (PK đơn + `shinsei_form_id` + `shinsei_form_version`, giống `tm_customize_komoku`):
    - `init/keihi_com/tm_shinsei_form_keihi_kamoku.xml`
    - `init/keihi_com/tm_shinsei_form_busho.xml`
    - `init/keihi_com/tm_shinsei_form_yakushoku.xml`
    - `init/keihi_com/tm_shinsei_form_jugyoin.xml`
  - Mỗi bảng con: audit + `hyoji_jun` (default 100) + index `(hojin_code, shinsei_form_id, shinsei_form_version)` + unique `(hojin_code, shinsei_form_id, shinsei_form_version, <entity>_id, delete_flag)`.
  - Include 4 file vào `keihi_com_changelog.xml`.
- Áp dụng quyết định clarification 6.1 (`shinsei_form_version` BIGINT) + 6.2 (audit + hyoji_jun cho cả 4 bảng con).

---

## [final_spec v1.0.0] — 2026-06-09
### Added
- Sinh `final_spec.md` (status `ready-for-implementation`) merge spec_analysis v1.0.0 + clarifications v1.0.0 (11/11 🟢) + current_analysis v1.0.0 + diff v1.0.0.
- Scope: card 「申請ルールの設定」 (7 nhóm) — 13 cột mới + 4 bảng con versioned.
- 1 TBD Low (TableCode gen ID cho 4 bảng con). Cross-screen §8: màn tạo申請 (lọc form theo jugyoinId, OR + 下位階層動的), check trần tiền, consistency check 経費科目.
- 2 message key mới cần đăng ký: `error.shinseiForm.keihiKamoku.required`, `error.shinseiForm.keihiKamoku.meisaiTypeMismatch`.

---

## [current_analysis v1.0.0] — 2026-06-09
### Added
- Phase 1 (EXTEND): Sinh `current_state/current_analysis.md` — snapshot trạng thái hiện tại màn 申請フォーム từ 11 file source + 3 screenshots.
- Ghi nhận pattern versioning immutable, header/detail 2 tầng, scope hojin_code+bushokaisoPtnId, 8 assumption/limitation.

### Confirmed (PO/BA — 2026-06-09)
- Update申請フォーム = tạo version mới, gọi `addShinseiForm` (CỐ Ý, không phải bug).
- Comment chặn xóa khi còn申請 chưa duyệt trong `deleteShinseiForm` = giữ nguyên logic hiện tại.

---

## [spec_analysis v1.0.0] — 2026-06-09
### Added
- Phase 2 (EXTEND): Sinh `spec_analysis.md`, `diff_with_current.md`, `clarifications.md` từ:
  - Spec: `ApplicationRulesAndMeetingExpenses_20260514 _VN.xlsx` › sheet `01_Setting detail shinsei form` (1 ảnh: image_A4.png).
  - DB: `db_tables_application_rules_meeting_expenses.xlsx` › 5 sheet `tm_shinsei_form*`.
- Card mới 「申請ルールの設定」 với 7 nhóm setting:
  1. 添付可能な明細の種類 (5 flag loại meisai)
  2. 申請可能な経費科目を設定する (+ bảng con `tm_shinsei_form_keihi_kamoku`)
  3. 申請合計金額の上限 (+ kubun Error/Alert)
  4. 申請者がワークフローを変更可能
  5. 申請可能な部署を設定する (+ 下位階層を含む, bảng con `tm_shinsei_form_busho`)
  6. 申請可能な役職を設定する (+ bảng con `tm_shinsei_form_yakushoku`)
  7. 申請可能な従業員を設定する (+ bảng con `tm_shinsei_form_jugyoin`)
- Diff: 13 cột NEW trên `tm_shinsei_form` + 4 bảng con NEW; verdict = Pure extend (additive) + cross-screen impact.
- 11 câu hỏi clarification (🔴×3, 🟡×6, 🟢×2).

### Notes
- 3 điểm 🔴 BLOCK code DB: (6.1) cột version FK bảng con, (6.2) cột thiếu 3 bảng con, (6.3) quan hệ keihiMeisaiTempu↔nhóm 1.
- Cross-screen alert: màn tạo申請 phải lọc form theo 5/6/7; check trần tiền; consistency với KeihiKamoku.

### Pending
- Chờ PO/BA trả lời `clarifications.md` → tạo `final_spec.md` (skill `final-spec-merger`).
</content>
