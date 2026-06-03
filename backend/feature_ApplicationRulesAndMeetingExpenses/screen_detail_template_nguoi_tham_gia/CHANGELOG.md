# Changelog — Template người tham gia (参加者テンプレート)

Theo dõi mọi thay đổi của tài liệu spec cho màn hình "Template người tham gia".

Format dựa trên [Keep a Changelog](https://keepachangelog.com/), versioning theo [Semantic Versioning](https://semver.org/):

- **Major (x.0.0)** — Spec gốc thay đổi lớn: đổi flow, đổi business rule cốt lõi, thêm/bỏ màn hình.
- **Minor (1.x.0)** — Bổ sung field mới, thêm validation, design update, PO trả lời câu hỏi clarification.
- **Patch (1.0.x)** — Fix typo, làm rõ wording, không đổi behaviour.

---

## [Unreleased] - 2026-06-03

### Fixed
- **Lỗi `SQLState 23505` (duplicate key `tm_sankasha_template_unique_key`) khi xóa template trùng tên với một bản đã xóa trước đó.** Nguyên nhân: unique index gồm cả `delete_flag` → chỉ cho phép đúng 1 bản `delete_flag=1` trùng tên; xóa bản active thứ 2 trùng tên gây vi phạm unique lúc UPDATE.
  - **Fix DB**: changeset mới forward-only `20260605_tm_sankasha_template_partial_unique_index` — thay index 4 cột bằng **partial unique index** `(hojin_code, jugyoin_id, sankasha_template_name) WHERE delete_flag = 0`. Áp bằng `liquibase:update`, không cần reset DB local.
  - **Không đổi service** (`checkDuplicateName`/update đã lọc `delete_flag=0`, vốn nhất quán với partial index).
  - **Docs sync**: `final_spec.md` v1.3.0 → v1.3.1 (§3.1 F1, §4.1, §5.1 + Version History); `clarifications.md` #6.18 v1.1.0 → v1.1.1 (hiệu chỉnh implementation, intent không đổi).

### Changed (thay đổi nghiệp vụ — PO/Lead chốt, đã sync code + docs, BUILD SUCCESS)
- **`hyojiJun` cho phép bắt đầu từ 0** (`[0, 9999]`, trước min=1) — header & shosai. Code: `SankashaTemplateDto`/`SankashaTemplateShosaiDto` `@Range(min=0)`.
- **Max per kubun = 100** (trước 99) — `SankashaTemplateService.MAX_SHOSAI_PER_KUBUN = 100`.
- **`shosaiList` KHÔNG bắt buộc** (cho phép rỗng/null) — bỏ `@NotEmpty` ở DTO; service normalize null → empty list ở `add`/`update`.
- Bump: `final_spec.md` → v1.3.0; `create/detail_design` → v1.1.0; `update/detail_design` → v1.1.0. Cập nhật `fe_integration_guide.md` + example JSON (create).



- **ĐÃ IMPLEMENT (BUILD SUCCESS)** 3 API: get-by-id, delete, bulk-delete (cùng với update + search trước đó → **toàn bộ 6 API đã có code**).
  - **get-by-id** (`GET /sankasha-template/{id}`): reuse `read` + `findShosaiByTemplateIds` + `enrichShosaiList`; trả `SankashaTemplate` (header + shosai enrich). detail_design → v1.2.0 `implemented`.
  - **delete** (`DELETE /sankasha-template/{id}`): soft delete header, optimistic lock, I003. detail_design → v1.1.0 `implemented`.
  - **bulk-delete** (`DELETE /sankasha-template`): atomic rollback (`@Transactional` lặp `deleteOne`), I006; list rỗng → no-op. detail_design → v1.1.0 `implemented`.
  - Refactor `deleteOne(dto)` dùng chung delete + bulk-delete. Thêm endpoint GET/DELETE/DELETE vào Api/Delegate/DelegateImpl + openapi.yml. Không thêm DB layer mới (reuse `read`/`save`/`findShosaiByTemplateIds`).
- `apis/sankasha-template-delete/detail_design.md` v1.0.0 — detail design API delete 1 record (`DELETE /sankasha-template/{id}`), kèm examples. Soft delete owner-scoped (`delete_flag=1`), optimistic lock, không đụng shosai, message I003. Reuse hạ tầng `read`/`save` từ update. 3 TBD (1 Medium #D2, 2 Low).
- `apis/sankasha-template-bulk-delete/detail_design.md` v1.0.0 — detail design API bulk delete (`DELETE /sankasha-template`), kèm examples. Lặp logic xoá đơn trong 1 `@Transactional` (atomic rollback), owner-scoped, message I006. Reuse `List<SankashaTemplate>` model. 4 TBD (2 Medium #BD3/#D2, 2 Low).
- `apis/sankasha-template-search/detail_design.md` v1.0.0 — detail design API search (`POST /sankasha-template/search`), kèm `request_examples.json` + `response_examples.json`. Owner-scoped filter cố định `jugyoin_id`; search xuyên bảng con `shosai` qua EXISTS subquery (S2 kubun=1 OR 2 cột, S3 kubun=2 join jugyoin); aggregate shosai per template để hiển thị multi-line (cột 5/6); enrich `jishaSankashaName` batch (tránh N+1); default size 50 + sort hyoji_jun ASC. DTO mới: `SankashaTemplateSearchParamDto`; API model mới: `SankashaTemplateSearchParameter`. → v1.1.0: **resolve #S1** — chốt trả nguyên `shosaiList` per template. → **v1.2.0: ĐÃ IMPLEMENT (BUILD SUCCESS)** — response dùng `ListResponse<SankashaTemplate>` generic (#S6, không tạo `ListSankashaTemplate`); enrich tên qua `getShimei()`; default size 50 (#S5). Code: thêm method `search`+`enrichShosaiList` vào Service, `search`+`findShosaiByTemplateIds` vào Crud/Adapter, `@Query` EXISTS subquery vào repository, endpoint vào Api/Delegate; field response additive vào API model `SankashaTemplate`/`SankashaTemplateShosai` + `SankashaTemplateShosaiDto.jishaSankashaInvalid`; openapi.yml.
- `apis/sankasha-template-get-by-id/detail_design.md` v1.0.0 → v1.1.0 — detail design API get-by-id (`GET /sankasha-template/{id}`), kèm `request_examples.json` + `response_examples.json`. Read owner-scoped → 404, enrich `jishaSankashaName` (batch query), đánh dấu dòng invalid (§4.8) — logic ngược create/update (giữ & hiển thị thay vì chặn).
- `apis/sankasha-template-update/detail_design.md` v1.0.0 — detail design API update (`PUT /sankasha-template/{id}`), kèm `request_examples.json` + `response_examples.json`.

### Resolved (get-by-id)
- **#G1**: cách báo dòng invalid cho FE — CHỐT dùng `boolean jishaSankashaInvalid` (`true` = không hợp lệ) trên `SankashaTemplateShosaiDto` + API model. Field additive vào response contract.
- **#G2**: verified `findMapByJugyoinIds(hojinCode, ids)` (→ `findAllByHojinCodeAndJugyoinIdIn`, không lọc `delete_flag`) trả cả nhân viên đã xoá; `JugyoinDto` có `deleteFlag` + `kengenCode`. Lấy cả nhân viên bị xoá để xác định hợp lệ.

### Changed
- `apis/sankasha-template-create/detail_design.md` → v1.0.1 (patch): đồng bộ final_spec v1.2.1 — bổ sung set `hojin_code = super.getHojinCode()` cho từng shosai (§4.1 step 9, §5.1); bump `based_on_final_spec_version` 1.2.0 → 1.2.1. Không đổi API contract.

### Notes
- Reuse pattern từ API create; expand các điểm khác: path param `{id}`, `updateVersion` (optimistic lock), read owner-scoped → 404, skip-self unique check, replace-all shosai (final_spec §4.4/§4.6), employee validation bắt buộc (§4.8), success message `I002`.
- Verify pattern với `MeisaiTemplateService.update/validation/blindData`.
- 4 TBD riêng cho update (0 High, 2 Medium: #U1 hard/soft delete shosai, #U2 mapping OptimisticLockException; 2 Low: #U3, #U4) + kế thừa TBD chung của create.

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
