---
version: 1.0.0
status: draft
last_updated: 2026-06-09
screen: screen_shinseiForm
purpose: Snapshot current state TRƯỚC khi phân tích spec mở rộng
source_branch: milestone_v1_57.1
---

# Current State Analysis — Màn 申請フォーム (ShinseiForm / Application Form)

> Mô tả TRẠNG THÁI HIỆN TẠI của màn (đã có sẵn), tổng hợp từ codebase + screenshots.
> Dùng làm baseline để đối chiếu khi làm spec EXTEND.
> **Chưa** đụng tới spec mới.

---

## 0. Tóm tắt nhanh

- Màn quản lý **申請フォーム** (template form mà nhân viên dùng để tạo申請/expense application). Là **master data** trong schema `keihi_com`, multi-tenant theo `hojin_code` và scope thêm theo `bushokaiso_ptn_id` (mẫu phân cấp phòng ban của user login).
- **Pattern lưu trữ = Versioning (immutable history)**: PK composite `(shinsei_form_id, shinsei_form_version)`. Mỗi lần INSERT, DB trigger `trg_set_shinsei_form_version` tự sinh version = `MAX(version)+1` và đồng bộ bảng `tm_mster_saiban`. Cập nhật KHÔNG overwrite — luôn tạo bản version mới.
- Cấu trúc **header + detail 2 tầng**: `tm_shinsei_form` (header) → `tm_customize_komoku` (カスタマイズ項目, detail) → `tm_format_hyoji` (giá trị hiển thị của radio/checkbox/pulldown).
- **Soft delete** (`delete_flag`) + **Optimistic lock** (`update_version` với `@Version`).
- Roles được phép: list/view = 5 role (READ, REGISTRATION, APPROVED, DEPARTMENT_MANAGEMENT, SUPER_ADMIN); thao tác CRUD master = chỉ **DEPARTMENT_MANAGEMENT (5)** + **SUPER_ADMIN (6)** (khớp README screenshot "chỉ user role 5,6").

---

## 1. Schema DB hiện tại

**Bảng**: `keihi_com.tm_shinsei_form`
**PK**: composite `(shinsei_form_id, shinsei_form_version)` — constraint `pk_tm_shinsei_form`
**File Liquibase**: `backend/src/main/resources/liquibase/init/keihi_com/tm_shinsei_form.xml`

### 1.1 Lịch sử migration

| ID | Author | Nội dung |
|---|---|---|
| `20210705tm_shinsei_form` | loihn | Tạo bảng ban đầu (PK đơn `shinsei_fuomu_id`) |
| `20210720_tm_shinsei_form_change_columns_name` | sonhv1 | Rename: `shinsei_fuomu_id`→`shinsei_form_id`, `shinsei_fuomu_name`→`shinsei_form_name`, `fuomu_riyo`→`form_riyo` |
| `2021_add_column_bushokaiso_ptn_id` | DaiPD | Thêm `bushokaiso_ptn_id` |
| `20211108_addColumn` | DaiPD | Thêm `hyojun_kamoku_umu` (0:追加科目, 1:標準科目) |
| `20211108_tm_shinsei_form_add_default_value` | DaiPD | Default cho `keihi_meisai_tempu`, `keihi_meisai_shonin_toki_toriatsukai`, `form_riyo` (=1), `delete_flag` (=0) |
| `tm_shinsei_form_createIndex` | DaiPD | Index `tm_shinsei_form_search_index_key` (hojin_code, shinsei_form_name, workflow_id) |
| `20211118_..._add_column` | anhdq | Thêm `shinsei_form_setsumei` VARCHAR(2000) |
| `20211119_..._add_column` | anhdq | Thêm `shinsei_form_type` VARCHAR(1) (sau bị drop) |
| `20211123_..._workflow_id_not null` | anhdq | `workflow_id` NOT NULL |
| `20211229_..._add_collumn_form_shurui` | anhdq | Thêm `form_shurui` VARCHAR(1) default '0' NOT NULL |
| `20220118_..._delete_column_shinsei_form_type` | anhdq | Drop `shinsei_form_type` |
| `20250307_add_columns_..._code_and_version_and_title_and_kijun_hi` | ducna1 | **Thêm `shinsei_form_code`, `shinsei_form_version` (BIGINT), `shinsei_title`, `kijun_hi`; chuyển PK sang composite (id, version)** |
| `20250317_remove_default_value_shinsei_form_code` | ducna1 | Bỏ default `shinsei_form_code` |
| `20250327_update_function_set_shinsei_form_version` | ducna1 | Tạo/cập nhật function `set_shinsei_form_version()` (auto MAX+1 + upsert `tm_mster_saiban`) |
| `20250406_update_trigger_set_shinsei_form_version` | ducna1 | Tạo trigger `trg_set_shinsei_form_version` BEFORE INSERT |
| `20250416_change_size_shinsei_form_code` | tamnd | `shinsei_form_code` VARCHAR(4)→VARCHAR(10) |

### 1.2 Danh sách cột

| Cột | Type | Null | Default | Ý nghĩa |
|---|---|---|---|---|
| `shinsei_form_id` | VARCHAR(29) | N | — | 申請フォームID (PK part 1) |
| `shinsei_form_version` | BIGINT | N | 1 | 申請フォームバージョン (PK part 2, auto trigger) |
| `hojin_code` | VARCHAR(5) | N | — | 法人コード |
| `shinsei_form_name` | VARCHAR(250) | N | — | 申請フォーム名 |
| `shinsei_form_code` | VARCHAR(10) | Y | — | 申請フォームコード (unique theo hojin) |
| `shinsei_title` | VARCHAR(250) | Y | — | デフォルトの申請タイトル |
| `kijun_hi` | NUMERIC(2) | N | 10 | 基準日 (1-31) |
| `keihi_meisai_tempu` | NUMBER(1) | Y | 1 | 経費明細添付 (0:なし, 1:あり) |
| `keihi_meisai_shonin_toki_toriatsukai` | NUMBER(1) | Y | 1 | 経費明細承認時取扱 (0/1/2) |
| `form_riyo` | NUMBER(1) | Y | 1 | フォーム利用 (0:しない, 1:する) |
| `form_shurui` | VARCHAR(1) | N | '0' | 申請フォームの種類 (通常申請 등) |
| `workflow_id` | VARCHAR(29) | N | — | ワークフローID (default workflow, FK→tm_workflow) |
| `bushokaiso_ptn_id` | VARCHAR(29) | Y | — | 部署階層パターンID (scope phân cấp phòng ban) |
| `hyoji_jun` | NUMBER(4) | Y | 100 | 表示順 |
| `shoninkengen_shinseigo_saishu_shonimmae_henshu_fuka` | NUMBER(1) | Y | 0 | 承認権限申請後最終承認前編集不可 (0/1/2) |
| `kanrikengen_shinseigo_saishu_shonimmae_henshu_fuka` | NUMBER(1) | Y | 0 | 管理権限申請後最終承認前編集不可 (0/1/2) |
| `kanrikengen_saishu_shoningo_henshu_fuka` | NUMBER(1) | Y | 0 | 管理権限最終承認後編集不可 (0/1/2) |
| `kanrikengen_saishu_shoningo_sakujo_kabi` | NUMBER(1) | Y | 0 | 管理権限最終承認後削除可否 (0/1) |
| `shinsei_form_setsumei` | VARCHAR(2000) | Y | — | 申請フォーム説明 |
| `hyojun_kamoku_umu` | NUMBER(1) | Y | 0 | 標準科目有無 (0:追加科目, 1:標準科目) |
| `delete_flag` | NUMBER(1) | Y | 0 | 削除フラグ |
| `update_version` | NUMBER(4) | Y | 1 | 更新バージョン (optimistic lock `@Version`) |
| `add_date`/`upd_date`/`add_userid`/`upd_userid` | TIMESTAMP/VARCHAR(29) | Y | — | Audit |

### 1.3 Index / Constraint
- PK composite `(shinsei_form_id, shinsei_form_version)`.
- Index `tm_shinsei_form_search_index_key` trên `(hojin_code, shinsei_form_name, workflow_id)`.
- Trigger `trg_set_shinsei_form_version` BEFORE INSERT → gọi function `set_shinsei_form_version()`.
- Bảng phụ trợ `tm_mster_saiban (master_id, version_bango)` lưu version mới nhất per form.

---

## 2. Entity Layer

**File**: `backend/.../adapter/out/persistence/db/entity/TmShinseiForm.java`

- Annotation chuẩn: `@Entity @Data @NoArgsConstructor @IdClass(TmShinseiFormId.class) @Table(name="tm_shinsei_form", schema="keihi_com") @SuppressFBWarnings @EntityListeners(AuditingEntityListener.class)`.
- **Composite ID dùng `@IdClass(TmShinseiFormId.class)`** (KHÔNG `@EmbeddedId`): 2 field `@Id` là `shinseiFormId` (String) + `shinseiFormVersion` (Long).
- `@Version private Integer updateVersion` — optimistic lock, độc lập với `shinseiFormVersion`.
- FK đều là **String ID thuần** (workflowId, bushokaisoPtnId), KHÔNG có JPA relation.
- **Quirk comment sai**: `private Integer keihiMeisaiTempu` có Javadoc `/** 更新バージョン. */` (copy-paste nhầm, đáng lẽ 経費明細添付).

---

## 3. Domain DTO

**File chính**: `backend/.../application/domain/ShinseiFormDto.java`

- **Bất thường**: DTO này được annotate `@RequestScope @Component @Data @NoArgsConstructor @SuppressFBWarnings` và **implements `Diffable<ShinseiFormDto>`** (để log 更新履歴 koshin rireki) — KHÁC convention "DTO là POJO thuần" trong CLAUDE.md.
- **Field map trực tiếp entity**: id/version/code/name/title/kijunHi/các flag quyền/setsumei/workflowId/hyojiJun/formShurui/deleteFlag/updateVersion + audit.
- **Field enrich (chỉ đọc, set khi get/search)**: `workflowName`, `customizeNames`, `customizeIdsTypeBunkiYouNoSuchi`, `customizeKomokuDtos` (nested list), `jugyoinShozokuBushoDtos`, `jugyoinBango`, `jugyoinShimei`.
- **Field phục vụ logic phụ (không lưu trực tiếp)**: `updateAllShinseiTitleFlag`, `updateAllShinseiWorkflowFlag` (0/1 — có cascade update申請 title/workflow đã tạo hay không), `hyojunKamokuUmu` (server tự tính).

### Validation groups
- Chỉ dùng group `Default` (không thấy nhóm validation tùy biến). Validate gọi qua `validator.validate(dto)` / `super.validate(dto)`.

**Ràng buộc đáng chú ý**:
- `shinseiFormName`: `@NotBlank` + max 250.
- `workflowId`: `@NotBlank` + `@StringEmptyOrExactSize(29)` + alphanumeric.
- `bushokaisoPtnId`: `@NotBlank` + max 29.
- `keihiMeisaiTempu`: `^(0|1)$`; `keihiMeisaiShoninTokiToriatsukai`/3 flag quyền edit: `^(0|1|2)$`; `kanrikengenSaishuShoningoSakujoKabi`: `^(0|1)$`; `formShurui`: `^(0|1|2)$`.
- `kijunHi`: `@Range(1,31)`; `hyojiJun`: `@Range(0,9999)`; `shinseiFormCode`: max 10; `shinseiTitle`: max 250.

**File phụ**: `ShinseiFormSearchParamDto.java` extends `SearchParamDto` (page/size/sort).
- Search fields: `formRiyo` (0/1), `shinseiFormName`, `workflowId`, `keihiMeisaiTempu` (String→Integer qua `getKeihiMeisaiTempu()`), `shinseiFormId`, `shinseiFormCode`, `shinseiTitle`, `isSearchFollowRole` (Boolean — quyết định nhánh search super-admin).

---

## 4. API hiện tại

**Base path**: `/api/v1`
**Delegate impl**: `backend/.../adapter/in/api/delegate/ShinseiFormApiDelegateImpl.java`
**API model**: `jp.co.keihi.adapter.in.api.model.ShinseiForm`, `ListShinseiForm`, `ShinseiFormSearchParameter`, `CustomizeKomoku`, `FormatHyoji`, `ShinseiFormJugyoin`

> ⚠️ **Nguồn OpenAPI**: `api_interface_generate_tool/specification/openapi.yml` (dòng 1906~2093) chỉ định nghĩa 5 operation: `updateShinseiForm` (PUT), `addShinseiForm` (POST), `deleteListShinseiForm` (DELETE), `getByShinseiFormId` (GET), `searchShinseiForm` (POST /search). Tuy nhiên delegate impl có **NHIỀU method hơn** spec này (xem bảng) — các endpoint `viewListShinseiForm`, `getByShinseiFormIdFromAnotherScreen`, `getShinseiFormAndJugyoin`, `getAllVerSionShinseiForm` đến từ ApiDelegate interface generate ở chỗ khác / openapi đang được sửa (file `openapi.yml` đang ở trạng thái `M` trong git). **TBD cần verify khi extend.**

| # | Method | Path (suy ra) | Delegate method | UseCase method | Response | Ghi chú |
|---|---|---|---|---|---|---|
| 1 | POST | `/shinsei-form` | `addShinseiForm` | `addShinseiForm` → rồi `findByShinseiFormIdAndShinseiFormVersion` | `ShinseiForm` | Trả về detail bản vừa tạo (latest version) |
| 2 | PUT | `/shinsei-form` | `updateShinseiForm` | **`addShinseiForm`** (⚠ KHÔNG gọi `updateShinseiForm`) | `ModelApiResponse` (I002) | Xem Quirk §9.3 |
| 3 | DELETE | `/shinsei-form` | `deleteShinseiForm` | `deleteShinseiForm` | `ModelApiResponse` (I003) | operationId spec = `deleteListShinseiForm` |
| 4 | GET | `/shinsei-form/{shinseiFormId}` | `getByShinseiFormId` (có thêm `shinseiFormVersion`) | `findByShinseiFormIdAndShinseiFormVersion(id, version, true)` | `ShinseiForm` | Spec chỉ khai báo path param `shinseiFormId`, nhưng impl nhận thêm `shinseiFormVersion` |
| 5 | POST | `/shinsei-form/search` | `searchShinseiForm` | `searchShinseiForm` | `ListShinseiForm` | role 5,6 |
| 6 | POST/GET? | (ngoài spec trên) | `viewListShinseiForm` | `viewListShinseiForm` | `ListShinseiForm` | Cho 5 role (màn khác) |
| 7 | GET? | (ngoài spec trên) | `getByShinseiFormIdFromAnotherScreen` | `findByShinseiFormIdFromAnotherScreen` | `ShinseiForm` | Cho 5 role |
| 8 | GET? | (ngoài spec trên) | `getShinseiFormAndJugyoin` | `getShinseiFormAndJugyoin` | `ShinseiFormJugyoin` | Lấy form + thông tin nhân viên |
| 9 | GET? | (ngoài spec trên) | `getAllVerSionShinseiForm` | `getAllVerSionShinseiForm` | `ListShinseiForm` | Lấy tất cả version của 1 form |

**Lưu ý API** (quirks/business meaning):
- Delegate KHÔNG có business logic, đúng convention (chỉ convert + call useCase). Nested list `customizeKomokus`/`formatHyojis` được map thủ công qua `convertModelToShinseiFormDto` / `convertDtoToShinseiForm`.
- Cả POST và PUT đều đi qua `addShinseiForm` của service → mọi "save" đều sinh **version mới** (immutable history).

---

## 5. Business logic trong Service

**File**: `backend/.../application/service/ShinseiFormService.java` (1708 dòng)
- Extends `AbstractService` implements `ShinseiFormUseCase`.
- Đăng ký bean qua **`adapter/out/configuration/BeanConfiguration.java`** (method `shinseiFormUseCase(...)`), KHÔNG có `ShinseiFormConfiguration` riêng và KHÔNG có `@Service`.
- **Constructor injection** (5 port): `ShinseiFormCrud`, `WorkflowWariateCrud`, `ShinseiJohoCrud`, `WorkflowCrud`, `ShinseiTitleSetteiCrud`.
- **`@Autowired` (nhiều — khá nặng)**: `ShinseiJohoUseCase`, `ShinseiTitleSetteiCrudUseCase`, `WorkflowKanriUseCase`, `JugyoinShozokuBushoCrud`, `BushoCrud`, `YakushokuCrud`, `JugyoinCrud`, `Validator`, `TmMsterSaibanRepository`, `KoshinRirekiUseCase`, `EntityManager`, `TmShinseiFormRepository` (inject thẳng repository vào service — phá layer, dùng cho delete).

### 5.1 Phân quyền
- `checkRolesUserLogin()` = `RoleUtil.check(SUPER_ADMIN, DEPARTMENT_MANAGEMENT)` — gọi đầu `addShinseiForm`, `updateShinseiForm`, `deleteShinseiForm`, `searchShinseiForm`.
- `viewListShinseiForm`, `getAllVerSionShinseiForm`, `findByShinseiFormIdFromAnotherScreen` = 5 role (READ, REGISTRATION, APPROVED, DEPARTMENT_MANAGEMENT, SUPER_ADMIN).

### 5.2 `addShinseiForm()` flow (vừa add vừa "update-as-new-version")
1. Check role 5,6.
2. Check trùng `shinseiFormName` theo `bushokaisoPtnId` → `E066` nếu trùng.
3. Sinh `shinseiFormId` mới qua `SqlUtil.generateId(TableCode.TM023, ...)`. **Nếu request có sẵn `shinseiFormId`** → coi như cập nhật: giữ id cũ, load bản `existed` (để cascade + log diff).
4. Set system fields: hojinCode, deleteFlag=UNDELETED, updateVersion=DEFAULT, bushokaisoPtnId = của user login; `setDefaultSomeFields()` điền default cho các flag null + tính `hyojunKamokuUmu`.
5. Validate JSR-303 → `BAD_REQUEST` + errorDetail.
6. Check trùng `shinseiFormCode` (`existsByHojinCodeAndShinseiFormCodeAndShinseiFormId`) → `E040`.
7. Verify `workflowId` tồn tại → `E041` nếu không.
8. `saveShinseiForm` (set version=null → trigger sinh version mới).
9. Nếu `existed != null` và `updateAllShinseiTitleFlag=1` → cascade `updateShinseiTitleAfterUpdateShinseiForm`; nếu `updateAllShinseiWorkflowFlag=1` → cascade `updateWorkflowWariateAfterUpdateShinseiForm`.
10. Đọc lại bản hiện tại, validate cấu trúc customize komoku (`checkConstitutionOfCustozizeKomoku`), lưu từng customize komoku + format hyoji.
11. Cập nhật `SosaRireki` (audit thao tác) + `addLogDataOwnerId` + `koshinRireki` (TM018).

### 5.3 `updateShinseiForm()` flow — ⚠ **KHÔNG được PUT endpoint gọi** (xem §9.3)
1. Check role 5,6; check tồn tại → `E041`.
2. `checkUpdateShinseiFormDefault` (form mặc định 経費精算申請 không cho đổi tên / không cho có customize / không cho đổi flag quyền).
3. `checkUniqueShinseiFormNameWhenUpdate` → `E066`.
4. Validate; nếu form đang có customize komoku → `checkCanModifyFieldOfShinseiFormWhenShinseiFormHasCustomizeKomoku` (nếu đã được người申請 dùng thì cấm đổi formShurui/keihiMeisaiTempu/keihiMeisaiShoninTokiToriatsukai/workflowId → `E102`).
5. `tranferInfoFromRequestToExistedDto` → `saveShinseiForm` → `updateCustomizedKomoku`.
6. Nếu form đang dùng làm 分岐条件 trong workflow → `checkIsUsedInWorkflowBunkiJokenShosai` (`E134`).
7. `updateShinseiJohoWhenUpdateShinseiFrom` cascade.

### 5.4 `deleteShinseiForm()` flow (soft delete toàn bộ version)
1. Check role 5,6; check tồn tại (latest, UNDELETED) → `E041`.
2. **Cấm xóa form mặc định**: name ∈ {KEIHI_SEISAN_SHINSEI, KAKIBARA_SHINSEI, SHUTCHO_KAKIBARA_SHINSEI, SETSUBI_KONYU_JIZEN_SHINSEI} → `E118`.
3. Nếu workflow wariate đang dùng form + default workflow → `E065`.
4. ⚠ **Check chặn xóa khi còn申請 chưa duyệt đã bị COMMENT OUT** — hiện cho phép xóa kể cả còn申請 pending (xem §9.5).
5. `updateAllByShinseiFormId(...DELETED)` set `delete_flag=1` cho **TẤT CẢ version** của form (native @Modifying update).
6. `entityManager.flush()/clear()`; xóa 申請タイトル設定 (`deleteAllByShinseiFormId`); ghi `SosaRireki` + `koshinRireki`.

### 5.5 `findByShinseiFormIdAndShinseiFormVersion()` / `search()` flow
- View detail: load form (cho phép cả deleted — `deleteFlag=null`) theo (hojinCode, id, bushokaisoPtnId, version). Version null → `resolveVersion` lấy từ `tm_mster_saiban` (latest). Enrich workflowName, customizeNames, customizeKomokuDtos + formatHyoji, related data (phòng ban/役職/nhân viên login).
- Search: default sort `hyojiJun asc`; 2 nhánh — `searchComplexBySuperAdmin` (khi `isSearchFollowRole=true` và role SUPER_ADMIN: KHÔNG lọc `formRiyo`/`deleteFlag`, thấy cả deleted) vs `searchComplex` (lọc `deleteFlag=UNDELETED` + `formRiyo`). Cả 2 đều lấy **MAX(version)** per form và lọc theo `bushokaisoPtnId`.

### 5.6 Validate trùng (unique)
- `shinseiFormName`: unique theo `(hojinCode, bushokaisoPtnId)`, lấy max version → `E066`.
- `shinseiFormCode`: unique theo `hojinCode` (loại trừ chính form đó), lấy max version → `E040`.
- `customizeName`: unique trong cùng 1 form → `E066`.

### 5.7 Check FK existence
- `workflowId` → `getWorkflowByWorkflowId` (E041 nếu không thấy).
- Validate cấu trúc カスタマイズ項目: bắt buộc (KOMOKU_MUST_LIST: 金額/日付/経費科目/経費負担部署/税区分) khi `keihiMeisaiTempu=なし`, max 2 mỗi loại (E128), cặp 勘定科目↔補助科目 phải đi đôi (E126), tối đa 1 "分岐用数値".

---

## 6. Repository

**File**: `backend/.../adapter/out/persistence/db/repository/TmShinseiFormRepository.java`
extends `PagingAndSortingRepository<TmShinseiForm, TmShinseiFormId>` — chủ yếu **native query** (`distinct on (shinsei_form_id) ... order by version desc` để lấy max version).

| Method | Mục đích |
|---|---|
| `findAllByHojinCodeAndDeleteFlagAndShinseiFormIdIn` | List max-version theo nhiều id + deleteFlag |
| `findAllMaxVersionByHojinCodeAndShinseiFormIdIn` | List max-version theo nhiều id (không lọc deleteFlag) |
| `findAllByHojinCodeAndShinseiIdIn` | Join `tr_shinsei_joho` lấy form theo申請 id |
| `findAllByHojinCodeAndShinseiFormId` | Tất cả version của 1 form |
| `findAllByHojinCodeAndDeleteFlagAndWorkflowIdIn` | Form theo workflow (max version) |
| `searchComplex` / `searchComplexBySuperAdmin` | Search phân trang JPQL (2 nhánh quyền) |
| `findByHojinCodeAndShinseiFormIdAnd...AndShinseiFormVersion` (3 biến thể) | Lấy 1 bản theo version cụ thể (±deleteFlag, ±bushokaisoPtnId) |
| `findByHojinCodeAndShinseiFormIdAndDeleteFlag` / `findByHojinCodeAndDeleteFlagAndShinseiFormId` | Lấy max-version theo id + deleteFlag |
| `findFirstByNameAndMaxVersion` / `findFirstByNameAndIdAndMaxVersion` (overload) | Check trùng name |
| `findByHojinCodeAndShinseiFormId` | Lấy max-version bỏ qua deleteFlag |
| `findAllByHojinCode` | Hojin Create Task |
| `existsByHojinCodeAndShinseiFormCodeAndDeleteFlag` / `...IdNotAndShinseiFormCodeAndDeleteFlag` | Check trùng code |
| `existsByHojinCodeAndShinseiFormIdAndBushokaisoPtnIdAndDeleteFlag` | Check tồn tại |
| `updateAllByShinseiFormId` (`@Modifying`) | Soft delete tất cả version |

---

## 7. Adapter (Output)

**File**: `backend/.../adapter/out/persistence/db/ShinseiFormAdapter.java`
- `@Slf4j @Component implements ShinseiFormCrud`. Inject 6 repository (shinseiForm, msterSaiban, workflow, customizeKomoku + custom, formatHyoji).
- Convert DTO↔Entity bằng `BeanUtil.copyProperties` / `convert` / `convertList`.
- **`saveShinseiForm` set `entity.setShinseiFormVersion(null)` trước khi save** → để DB trigger tự sinh version (đây là cơ chế versioning then chốt).
- `resolveVersion`: version null → lấy `versionBango` từ `tm_mster_saiban` (default 1L).
- Adapter này gánh cả CRUD của 3 bảng (shinsei_form, customize_komoku, format_hyoji) + workflow lookup → "fat adapter".

---

## 8. Mô tả UI (từ screenshots)

### Ảnh 01 — 申請フォーム一覧 (list)
- Chỉ role 5,6 vào được; mặc định load = search all form của user login.
- Khu vực search phía trên + bảng list nhiều cột (form名, code, workflow, 経費明細添付, các flag, カスタマイズ項目 names...), phân trang.
- Button "フォーム新規作成" → sang màn detail tạo mới.

### Ảnh 02 — 申請フォーム保存 (create)
- Section **基本項目**: バージョン選択 (dropdown, disabled khi tạo mới), 申請フォームの種類 (必須, default 通常申請), 申請フォーム名 (必須), 申請フォームコード, デフォルトの申請タイトル + 申請タイトルの反映例 + 基準日 (default 10日), 経費明細の添付 (radio 添付なし/あり), 経費明細の承認時の取扱い (dropdown), フォームの利用 (radio する/しない), 表示優先順 (default 100), デフォルトワークフロー (必須, dropdown), 申請フォームの説明 (textarea).
- Section **カスタマイズ項目** (lặp lại N block): カスタマイズ項目名 (必須), フォーマットの種類 (dropdown: 短文/日付/分岐条件用数値/小数/数値/金額...), 必須にする (checkbox), デフォルト値, 注釈. Button "項目を追加" + "項目削除" per block.
- Footer: 戻る / 保存.

### Ảnh 03 — 申請フォーム保存 (view/edit old data)
- Giống ảnh 02 nhưng có dữ liệu cũ: バージョン選択 = 最新, có checkbox "入力した申請タイトルで個人毎の申請タイトル設定も更新する" (= `updateAllShinseiTitleFlag`) và "選択したワークフローで個人毎のワークフロー割当設定も更新する" (= `updateAllShinseiWorkflowFlag`).
- 5 カスタマイズ項目 mẫu: 日付, 分岐 (分岐条件用数値), 小数, 数値, 金額.

---

## 9. Assumption / Limitation hiện tại (QUAN TRỌNG cho EXTEND)

> Section này BẮT BUỘC liệt kê ít nhất 5 điểm.

1. **Pattern lưu trữ = Versioning immutable + header/detail 2 tầng**: mỗi "save" (cả POST lẫn PUT) INSERT bản mới với `shinsei_form_version = MAX+1` (DB trigger). KHÔNG có UPDATE in-place dữ liệu nghiệp vụ. Khi extend thêm field, phải nhớ trigger + `tm_mster_saiban` + 3 bảng liên đới (customize_komoku, format_hyoji cũng versioned theo formId+version).

2. **Inconsistency với `codebase_pointers.md`**:
   - Pointer ghi `<path/to/ShinseiFormConfiguration.java>` nhưng thực tế bean đăng ký trong **`BeanConfiguration.java`** (file config chung, dòng ~1030). KHÔNG có file `ShinseiFormConfiguration` riêng.
   - Pointer ghi OpenAPI "không có thì thôi", nhưng thực tế endpoint nằm trong `api_interface_generate_tool/specification/openapi.yml` (đang ở trạng thái `M` git — có thể đang sửa).
   - Pointer ghi `source_branch = develop_new_feature`, nhưng branch hiện tại là **`milestone_v1_57.1`**.

3. **✅ DESIGN xác nhận — Update = tạo version mới, gọi luôn `addShinseiForm`**: `ShinseiFormApiDelegateImpl.updateShinseiForm()` (dòng 88-103) gọi `shinseiFormUseCase.addShinseiForm(dto)` là **CỐ Ý theo thiết kế versioning** (PO đã xác nhận 2026-06-09): khi update một申請フォーム, hệ thống INSERT một version mới chứ KHÔNG edit record cũ → tái dùng `addShinseiForm` (branch "có sẵn shinseiFormId" trong §5.2). Method `updateShinseiForm` của service (với check `checkCanModifyFieldOfShinseiFormWhenShinseiFormHasCustomizeKomoku`, `E102`, `E134`...) hiện KHÔNG được REST API gọi — chỉ giữ lại làm tham chiếu/nội bộ. → Khi extend logic "update", phải sửa trong nhánh `existed != null` của `addShinseiForm`, KHÔNG sửa `updateShinseiForm`.

4. **✅ Behaviour xác nhận — giữ nguyên comment trong delete**: trong `deleteShinseiForm`, đoạn chặn xóa khi `existsUsingShinseiFormAndNotApprovedShinsei` được **comment out có chủ đích** ("Allow deletion even when there are unapproved shinsei") và **GIỮ NGUYÊN logic hiện tại** (PO xác nhận 2026-06-09): cho phép xóa form ngay cả khi còn申請 chưa duyệt. Khi extend, KHÔNG khôi phục lại đoạn check này trừ khi spec mới yêu cầu rõ.

5. **Scope kép `hojin_code` + `bushokaiso_ptn_id`**: mọi truy vấn (read/search/unique-check) đều lọc theo `bushokaisoPtnId` của user login. Form được tách theo mẫu phân cấp phòng ban — 2 user khác `bushokaisoPtnId` không thấy form của nhau. Unique của `shinseiFormName` cũng theo cặp này, còn `shinseiFormCode` unique theo `hojinCode` toàn cục.

6. **Form mặc định bất khả xâm phạm**: 4 form hệ thống (KEIHI_SEISAN_SHINSEI / KAKIBARA_SHINSEI / SHUTCHO_KAKIBARA_SHINSEI / SETSUBI_KONYU_JIZEN_SHINSEI — nhận diện theo `shinseiFormName` match enum `ShinseiFormType`) KHÔNG cho xóa (E118), KHÔNG cho đổi tên, và set `hyojunKamokuUmu=1` (標準科目).

7. **Vi phạm layer & convention**:
   - `ShinseiFormDto` annotate `@RequestScope @Component` + implements `Diffable` — không phải POJO thuần.
   - Service inject thẳng `TmShinseiFormRepository` + `EntityManager` (bỏ qua port/adapter) cho thao tác delete + flush/clear.
   - "Fat adapter" `ShinseiFormAdapter` ôm CRUD của 3 bảng.

8. **Convention naming / ID generation**: ID sinh qua `SqlUtil.generateId(TableCode.XXX, hojinCode)` — form=`TM023`, customize komoku=`TM017`, format hyoji=`TM013`. **Lưu ý mâu thuẫn**: `koshinRireki`/`addLogDataOwnerId` log với `TableCode.TM018.getTableName()` (không khớp TM023) — cần verify khi extend logic log.

---

## 10. Files đã đọc (snapshot)

| Layer | File |
|---|---|
| Liquibase | `liquibase/init/keihi_com/tm_shinsei_form.xml` |
| Entity | `entity/TmShinseiForm.java` (+ `TmShinseiFormId` qua @IdClass) |
| Repository | `repository/TmShinseiFormRepository.java` |
| DTO | `domain/ShinseiFormDto.java`, `domain/ShinseiFormSearchParamDto.java` |
| UseCase (in port) | `port/in/ShinseiFormUseCase.java` |
| Output port | `port/out/ShinseiFormCrud.java` |
| Service | `service/ShinseiFormService.java` (1708 dòng) |
| Adapter | `persistence/db/ShinseiFormAdapter.java` |
| Delegate | `delegate/ShinseiFormApiDelegateImpl.java` |
| API spec | `api_interface_generate_tool/specification/openapi.yml` (dòng 1906~2093) |
| Bean config | `adapter/out/configuration/BeanConfiguration.java` (dòng ~1029) |

> Screenshots: 3 ảnh trong `current_state/screenshots/` (đã mô tả ở mục 8).
</content>
</invoke>
