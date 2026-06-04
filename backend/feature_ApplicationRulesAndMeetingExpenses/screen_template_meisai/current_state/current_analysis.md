---
version: 1.0.0
status: draft
last_updated: 2026-06-04
screen: template_meisai (明細テンプレート)
purpose: Snapshot current state TRƯỚC khi phân tích spec mở rộng
source_branch: milestone_v1_57.1
---

# Current State Analysis — Màn Template Meisai (明細テンプレート)

> Tài liệu này mô tả **trạng thái HIỆN TẠI** của màn `template-meisai` (đã có sẵn trong hệ thống),
> tổng hợp từ codebase + screenshots. Dùng làm baseline để đối chiếu khi làm spec EXTEND.
> **Chưa** đụng tới spec mới.

---

## 0. Tóm tắt nhanh

- Màn quản lý **明細テンプレート** (template dòng chi tiết chi phí) theo **từng user (jugyoin)**, không share toàn công ty.
- Mỗi template thuộc 1 trong các **loại đăng ký (登録方法 / `torokuHoho`)**:
  - `1` = 領収書 (receipt / ryoshusho)
  - `2` = 経路 (route / keiro)
  - `3` = 日当 (daily allowance) — **có trong DB nhưng đã bị loại khỏi validation hiện hành**
  - `4` = 経路API (route via external API / keiro API)
- Pattern: **single-table, KHÔNG có header+detail**. Mỗi template = 1 row trong `keihi_com.tm_meisai_template`.
- Soft delete (`delete_flag`), optimistic lock (`update_version` + `@Version`).
- **Không versioning lịch sử** (1 PK đơn `meisai_template_id`, update ghi đè).

---

## 1. Schema DB hiện tại

**Bảng**: `keihi_com.tm_meisai_template`
**PK**: `meisai_template_id` (single, `VARCHAR(29)`)
**File Liquibase**: `backend/src/main/resources/liquibase/init/keihi_com/tm_meisai_template.xml`

### 1.1 Lịch sử migration (3 changeset)

| ID | Author | Nội dung |
|---|---|---|
| `20230406_tm_meisai_template_init_table` | loihn | Tạo bảng gốc |
| `20240603_tm_meisai_template_add_keiyu` | hainn1 | Thêm 6 cột 経由 (keiyu1/2/3 + code) |
| `20241010_tm_meisai_template_add_keiro_api_flag` | hblab_tamnd | Thêm `keiro_api_flag` |

### 1.2 Danh sách cột

| Cột | Type | Null | Default | Ý nghĩa (remarks) |
|---|---|---|---|---|
| `add_date` | TIMESTAMP | ✓ | | 作成日時 |
| `upd_date` | TIMESTAMP | ✓ | | 更新日時 |
| `add_userid` | VARCHAR(29) | ✓ | | 作成ユーザーID |
| `upd_userid` | VARCHAR(29) | ✓ | | 更新ユーザーID |
| `hojin_code` | VARCHAR(5) | ✗ | | 法人コード |
| **`meisai_template_id`** | VARCHAR(29) | ✗ (PK) | | 明細テンプレートID |
| `meisai_template_mei` | VARCHAR(250) | ✗ | | テンプレート名 |
| `jugyoin_id` | VARCHAR(29) | ✗ | | 従業員ID (chủ sở hữu template) |
| `toroku_hoho` | VARCHAR(1) | ✗ | | 1:領収書, 2:経路, 3:日当, 4:経路API |
| `hizuke` | VARCHAR(8) | ✓ | | 日付 (yyyyMMdd) |
| `naiyo` | VARCHAR(250) | ✓ | | 内容 |
| `shuppatsuchi` | VARCHAR(250) | ✓ | | 出発地 (経路) |
| `tochakuchi` | VARCHAR(250) | ✓ | | 到着地 (経路) |
| `shiharai_hoho` | VARCHAR(1) | ✓ | | 支払方法 1:IC, 2:現金 (経路) |
| `unchin_shubetsu` | VARCHAR(1) | ✓ | | 運賃種別 1:片道, 2:往復 (経路) |
| `keihi_kamoku_id` | VARCHAR(29) | ✓ | | 経費科目ID |
| `zei_kubun_id` | VARCHAR(29) | ✓ | | 税区分ID |
| `busho_id` | VARCHAR(29) | ✓ | | 部署ID (費用負担部署) |
| `project_id` | VARCHAR(29) | ✓ | | プロジェクトID |
| `memo` | TEXT | ✓ | | メモ |
| `kingaku` | NUMERIC | ✓ | | 金額 |
| `kashikata_kanjo_kamoku_id` | VARCHAR(29) | ✓ | | 貸方勘定科目ID |
| `kashikata_hojo_kamoku_id` | VARCHAR(29) | ✓ | | 貸方補助科目ID |
| `update_version` | NUMBER(4) | ✗ | 1 | 更新バージョン (@Version) |
| `teiki_kukan_kojo` | NUMBER(1) | ✓ | 0 | 定期区間控除 0/1 (経路) |
| `keiro_id` | VARCHAR(29) | ✓ | | 経路ID (FK tới thông tin keiro) |
| `shuppatsu_code` | VARCHAR(250) | ✓ | | 出発コード |
| `tochaku_code` | VARCHAR(250) | ✓ | | 到着コード |
| `keiyu1` / `keiyu1_code` | VARCHAR(200) | ✓ | | 経由 1 + code |
| `keiyu2` / `keiyu2_code` | VARCHAR(200) | ✓ | | 経由 2 + code |
| `keiyu3` / `keiyu3_code` | VARCHAR(200) | ✓ | | 経由 3 + code |
| `delete_flag` | NUMBER(1) | ✗ | 0 | 0:利用中, 1:削除済 |
| `hyoji_jun` | NUMBER(4) | ✓ | 100 | 表示順 |
| `keiro_api_flag` | NUMERIC(1) | ✗ | 0 | 経路API検索フラグ |

### 1.3 Index / Constraint
- **KHÔNG có index riêng** được khai báo trong changeset (chỉ có PK).
- **KHÔNG có unique constraint vật lý** cho `(hojin_code, jugyoin_id, meisai_template_mei)`.
  Việc check trùng tên template được làm **ở tầng Service** (logic), không phải DB constraint.

---

## 2. Entity Layer

**File**: `adapter/out/persistence/db/entity/TmMeisaiTemplate.java`

- Chuẩn entity: `@Entity @Data @NoArgsConstructor @Table(name="tm_meisai_template", schema="keihi_com")`,
  `@EntityListeners(AuditingEntityListener.class)`, `@SuppressFBWarnings`.
- `@Id` đơn trên `meisaiTemplateId`. `@Version` trên `updateVersion`.
- `kingaku` là `BigDecimal`.
- `keiyu1Code/keiyu2Code/keiyu3Code` cần `@Column(name="keiyuN_code")` (vì camelCase không tự map snake_case có số).
- **KHÔNG có FK/relation JPA** tới bảng khác — tất cả là ID dạng String, resolve bằng JOIN trong query hoặc query phụ.

---

## 3. Domain DTO

**File chính**: `application/domain/MeisaiTemplateDto.java`

DTO này **rộng hơn entity** — chứa cả field nghiệp vụ lẫn field "enrich" (tên hiển thị) và field phục vụ keiro API:

- **Field map trực tiếp với entity**: như bảng mục 1.2.
- **Field enrich (chỉ đọc, set khi search/get)**: `shimei`, `keihiKamokuName`, `zeikubunName`, `bushoMei`,
  `projectName`, `kanjoKamokuName`, `hojoKamokuName`, `displayRoute`.
- **Field phục vụ Keiro/Keiro-API (không lưu DB trực tiếp)**: `serializeData`, `assignTeikiSerializeData`,
  `limitedExpressCharge`, `teikiKukanId`, `searchResultDisplay`, `kotsuShudan`, `keiroInfoDto` (object lồng).
- Implements `Diffable<MeisaiTemplateDto>` → phục vụ ghi **更新履歴 (koshin rireki)** qua `@LogOperation`.

### Validation groups (quan trọng cho EXTEND)
DTO dùng **validation theo group** để áp rule khác nhau theo `torokuHoho`:
- `Default` — luôn áp.
- `GroupRyoshusho` — loại 領収書.
- `GroupKeiro` — loại 経路.
- `GroupKeiroApi` — loại 経路API (bắt buộc 出発地/到着地/出発コード/到着コード/支払方法/運賃種別).
- `GroupUpdate` — khi update (bắt buộc `meisaiTemplateId`, `updateVersion`).

Ràng buộc đáng chú ý:
- `meisaiTemplateMei`: `@NotBlank`, max 250.
- `torokuHoho`: `@NotBlank`, `@EnumNamePattern(regexp = "1|2|4")` → **chỉ chấp nhận 1, 2, 4** (KHÔNG có 3:日当).
- ID fields: `@StringEmptyOrExactSize(size=29)` + regex alphanumeric.
- `hyojiJun`: `@Range(0..9999)`.

**File phụ**: `application/domain/MeisaiTemplateSearchParamDto.java` (extends `SearchParamDto` — có page/size/sort)
- `torokuHohos`: `List<String>`, `@NotNull`, mỗi phần tử regex `1|2|4|`.
- `meisaiTemplateId`: max 29.
- `meisaiTemplateMei`: max 250.

---

## 4. API hiện tại

**Base path**: `/api/v1`
**Interface gen OpenAPI**: `adapter/in/api/MeisaiTemplateApi.java` + `MeisaiTemplateApiDelegate.java`
**Delegate impl**: `adapter/in/api/delegate/MeisaiTemplateApiDelegateImpl.java`
**Model**: `adapter/in/api/model/MeisaiTemplate`, `MeisaiTemplateSearchParameter`, `ListResponse`, `ModelApiResponse`

> ⚠️ Các endpoint này KHÔNG nằm trong `api_interface_generate_tool/specification/openapi.yml`
> (grep không khớp) — có thể được gen từ spec file khác/cũ. Cần xác nhận khi extend phải sửa spec nào.

| # | Method | Path | Delegate method | UseCase method | Response | Message |
|---|---|---|---|---|---|---|
| 1 | POST | `/meisaiTemplate` | `addMeisaiTemplate` | `add` | `ModelApiResponse` | I001 |
| 2 | PUT | `/meisaiTemplate` | `updateMeisaiTemplate` | `update` | `ModelApiResponse` | I002 |
| 3 | DELETE | `/meisaiTemplate` | `deleteListMeisaiTemplate` (nhận `List<MeisaiTemplate>`) | `deleteList` | `ModelApiResponse` | I003 |
| 4 | GET | `/meisaiTemplate/{meisaiTemplateId}` | `getMeisaiTemplateById` | `findByMeisaiTemplateId` | `MeisaiTemplate` | — |
| 5 | POST | `/meisaiTemplate/search` | `searchMeisaiTemplate` | `search` | `ListResponse<MeisaiTemplate>` | — |
| 6 | POST | `/meisaiTemplate/view-list` | `viewListMeisaiTemplate` | `viewListMeisaiTemplate` | `ListResponse<MeisaiTemplate>` | — |

**Lưu ý API**:
- DELETE nhận **List** (bulk delete) — không có single-delete riêng.
- `search` vs `viewListMeisaiTemplate`: cả 2 đều list, nhưng:
  - `search` = JOIN đầy đủ master (trả tên hiển thị), dùng cho màn list quản lý (ảnh 01).
  - `viewListMeisaiTemplate` = `searchSimple`, dùng cho dropdown "明細テンプレートを適用する" trong màn tạo meisai (ảnh 04). Có thêm logic ẩn `keihiKamokuId` nếu kamoku không còn dùng.
- Có 1 entry point KHÔNG qua API: `addFromMeisai(MeisaiJohoDto)` — gọi nội bộ từ flow tạo meisai khi user bấm "テンプレートとして保存" (ảnh 04/05).

---

## 5. Business logic chính trong Service

**File**: `application/service/MeisaiTemplateService.java`
- Extends `AbstractService` implements `MeisaiTemplateUseCase`. Đăng ký bean tại
  `adapter/out/configuration/BeanConfiguration.java` (method `meisaiTemplateUseCase()`, dòng ~1942) — **không dùng `@Service`**.
- Inject 9 Crud qua constructor (`@RequiredArgsConstructor`): MeisaiTemplate, Project, Busho, KeihiKamoku,
  Jugyoin, Zeikubun, KanjoKamoku, HojoKamoku, Keiro.
- Inject `@Autowired`: `KeiroUseCase`, `MeisaiJohoUseCase`, `SeigenchiCrudUseCase`, `KoshinRirekiUseCase`.

### 5.1 Phân quyền
`checkRolesAllow()` gọi đầu MỌI method public:
`RoleUtil.check(..., DEPARTMENT_MANAGEMENT, SUPER_ADMIN, APPROVED, REGISTRATION)`
→ 4 role được phép. (Ghi chú: README screenshot ghi "chỉ role 5,6" cho màn list — nhưng code cho phép rộng hơn).

### 5.2 `add()`
1. Check role → validate `Default`.
2. Rẽ nhánh theo `torokuHoho`:
   - `1 領収書`: nếu có `keihiKamokuId` mà `ryoshushoSentakuKanousei == 0` → lỗi E157. Sau đó `addForRyoshusho` (validate `GroupRyoshusho` + check giới hạn số lượng `MEISAI_RYOSHUSHO_SEIGEN`).
   - `4 経路API`: `addForKeiroApi` (validate `GroupKeiroApi`, check giới hạn `MEISAI_KEIRO_SEIGEN`, gọi external API lấy keiro info → lưu, set `kingaku` + `keiroId`).
   - `2 経路`: `validateKeiro` (validate `GroupKeiro`, check giới hạn keiro).
   - khác → return (no-op).
3. Set hệ thống: `hojinCode`, `jugyoinId = loginJugyoinId`, generate ID (`SqlUtil.generateId(TableCode.TM055, hojinCode)`), `deleteFlag=0`, `updateVersion=DEFAULT`, default `hyojiJun=100`, default `teikiKukanKojo`, default `keiroApiFlag`.
4. Ghi log owner + **更新履歴** (koshin rireki, tableName = `TableCode.TM031`).
5. `meisaiTemplateCrud.save()`.

### 5.3 `update()`
1. Check role → tìm bản ghi tồn tại theo `(hojinCode, meisaiTemplateId, loginJugyoinId, deleteFlag=0)`; không có → `NotFoundException` E041.
2. Rẽ nhánh theo `torokuHoho` **của bản ghi cũ** (existence):
   - 領収書 → `updateForRyoshusho`.
   - 経路API → `updateForKeiroApi` (xoá keiro cũ, search + lưu keiro mới).
   - 経路 → nếu DTO mới đổi sang 経路API thì xử lý như keiro API; ngược lại validate `GroupKeiro`.
3. Ghi log + koshin rireki.
4. `blindData()` — **copy thủ công** từng field từ DTO mới sang entity cũ (whitelist field được phép update), rồi save. (Không cho đổi `jugyoinId`, `hojinCode`...).

### 5.4 `deleteList()`
- Loop từng item → `delete()`: validate `GroupUpdate`, tìm bản ghi, set `deleteFlag=1` + `updateVersion`, save (soft delete). Có TODO "delete all when delete jugyoin".

### 5.5 `findByMeisaiTemplateId()`
- Tìm tồn tại → build search param theo id + torokuHoho → gọi `search()` để lấy bản đã enrich tên. Nếu loại 経路API thì set thêm keiro info.

### 5.6 Validate trùng tên (`validation()`)
- Tìm theo `(hojinCode, loginJugyoinId, meisaiTemplateMei, deleteFlag=0)`.
- Trùng tên + khác ID → lỗi E040. Cùng ID (chính nó) → OK.
- **Scope unique = theo từng user (jugyoinId), không phải toàn công ty.**

### 5.7 Check tồn tại các FK ID (`checkExistenceOfIds`)
Verify từng ID nếu có giá trị: project, busho, keihiKamoku, kanjoKamoku, hojoKamoku, jugyoin, zeikubun.
Không tồn tại → `NotFoundException`/`BadRequestException` E041.

---

## 6. Repository

**File**: `adapter/out/persistence/db/repository/TmMeisaiTemplateRepository.java`
(extends `PagingAndSortingRepository<TmMeisaiTemplate, String>`)

| Method | Mục đích |
|---|---|
| `findByHojinCodeAndMeisaiTemplateIdAndJugyoinIdAndDeleteFlag` | Lấy 1 bản ghi theo id + owner |
| `findByHojinCodeAndJugyoinIdAndMeisaiTemplateMeiAndDeleteFlag` | Check trùng tên |
| `search(...)` (JPQL, `Page<Object[]>`) | Search có JOIN 7 master (project, keihiKamoku, busho, zeikubun, jugyoin, kanjoKamoku, hojoKamoku) → trả entity + 7 tên. Filter `jugyoinId IN :loginJugyoinId`, optional `meisaiTemplateId`, optional `torokuHohos` |
| `searchSimple(...)` (JPQL, `Page<TmMeisaiTemplate>`) | Search nhẹ cho dropdown, filter torokuHohos + LIKE tên |
| `countByHojinCodeAndJugyoinIdAndTorokuHohoInAndDeleteFlag` | Đếm phục vụ check giới hạn (制限値) |
| `findAllByHojinCodeAndProjectId` | Lấy tất cả template theo project |

> `search` truyền `jugyoinId` vào `IN :loginJugyoinId` — hiện chỉ 1 user (chính mình).

---

## 7. Adapter (Output)

**File**: `adapter/out/persistence/db/MeisaiTemplateAdapter.java` (`@Component implements MeisaiTemplateCrud`)
- Map DTO ↔ Entity bằng `BeanUtil`.
- `toMeisaiTemplateDto(Object[])`: parse kết quả JOIN, gán tên hiển thị theo index cố định (1..7).
- `viewListMeisaiTemplate`: bọc tên template bằng `getConditionContainLower` để LIKE.

---

## 8. Mô tả UI (từ screenshots)

### Ảnh 01 — 明細テンプレート一覧 (list)
- URL: `/kojin/meisaiTemplate/meisaiTemplateList`. Mặc định load = search all của user login.
- 2 tab filter: **領収書登録用** (đang chọn, xanh) / **経路登録用** → tương ứng filter `torokuHohos`.
- Button **新規登録** (tạo mới), paging "1-20/20".
- Cột bảng: checkbox | 編集/削除 | **テンプレート名** (sort) | 内容 | 費用負担部署 | プロジェクト | 金額 | 経費科目 | 税区分 | 貸方勘定科目 | 貸方補助科目 | **表示優先順** (sort).
- Footer: **選択したデータを削除** (bulk delete các checkbox đã chọn).

### Ảnh 02/03 — Modal 明細テンプレート設定画面 (tạo/sửa loại 領収書)
Fields: テンプレート名 (必須) | 内容 | 費用負担部署 (dropdown) | プロジェクト | 金額 | 経費科目 | 税区分 (auto theo kamoku, disabled) | 貸方勘定科目 | 貸方補助科目 | 表示優先順 (default 100). Button キャンセル / 保存.

### Ảnh 04 — Màn tạo meisai 領収書 (shinsei/meisai/ryoshusho)
- Có dropdown góc phải **明細テンプレートを適用する** (apply template → gọi `view-list`).
- Button **テンプレートとして保存** → mở modal lưu template (entry `addFromMeisai`).

### Ảnh 05 — Modal テンプレート保存
- Ghi chú: nội dung nhập sẽ lưu thành template; **発生日 (ngày) và file đính kèm KHÔNG lưu**; tên lưu theo 明細テンプレート名.
- Có dropdown **明細テンプレート** (chọn template có sẵn → hiểu là UPDATE) + textbox **明細テンプレート名**.
- Nếu chọn 1 template + nhập tên → **update** template đó; không chọn → **tạo mới**.

---

## 9. Assumption / Limitation hiện tại (QUAN TRỌNG cho EXTEND)

1. **`torokuHoho = 3 (日当)` đã chết ở tầng app**: DB cho phép giá trị 3, nhưng validation DTO chỉ nhận `1|2|4`.
   Nếu spec mới đụng tới 日当 cần xác nhận.
2. **Không có unique constraint vật lý** cho tên template — chỉ check ở Service theo scope `(hojinCode, jugyoinId)`.
   Nếu spec mới đổi scope unique (vd theo toàn công ty / theo nhóm) → ảnh hưởng cả logic lẫn có thể cần index.
3. **Template thuộc về cá nhân (`jugyoinId`)** — không có khái niệm template dùng chung công ty/phòng ban.
4. **Single-table, không header+detail, không versioning lịch sử** — mỗi template là 1 dòng meisai đơn.
   (Khác với `tm_sankasha_template` vừa làm có header+detail.)
5. **Discrepancy với `codebase_pointers.md` mục 10**: pointer ghi *"`tm_meisai_template.sankasha_template_id` → FK trỏ tới `tm_sankasha_template`"*, **nhưng schema hiện tại KHÔNG có cột `sankasha_template_id`** và entity cũng không có field này. → Nhiều khả năng đây chính là **phần spec mới sẽ thêm** (cần xác nhận ở Phase 2).
6. **Inconsistency TableCode**: generate ID dùng `TableCode.TM055`, nhưng koshin rireki ghi tableName `TableCode.TM031`. Cần để ý khi đụng audit/log.
7. **Endpoint không nằm trong `openapi.yml` đang track** — phải xác định file spec OpenAPI thực sự để extend (tránh sửa nhầm).
8. **`keihiKamokuId` bị ẩn** trong `viewListMeisaiTemplate` nếu kamoku đã `riyoJotai = NOT_USE` (logic làm sạch dropdown).
9. Không có file **test** nào cho service/adapter này (pointer mục 8 = không có).
10. Endpoint `add` rẽ nhánh: nếu `torokuHoho` không thuộc {1,2,4} thì **return im lặng** (không tạo, không báo lỗi) — hành vi cần lưu ý nếu spec mới thêm loại mới.

---

## 10. Danh sách file nguồn đã đọc (snapshot)

| Layer | File |
|---|---|
| Liquibase | `liquibase/init/keihi_com/tm_meisai_template.xml` |
| Entity | `adapter/out/persistence/db/entity/TmMeisaiTemplate.java` |
| Repository | `adapter/out/persistence/db/repository/TmMeisaiTemplateRepository.java` |
| DTO | `application/domain/MeisaiTemplateDto.java`, `MeisaiTemplateSearchParamDto.java` |
| Input Port | `application/port/in/MeisaiTemplateUseCase.java` |
| Output Port | `application/port/out/MeisaiTemplateCrud.java` |
| Service | `application/service/MeisaiTemplateService.java` |
| Adapter | `adapter/out/persistence/db/MeisaiTemplateAdapter.java` |
| Delegate | `adapter/in/api/delegate/MeisaiTemplateApiDelegateImpl.java` |
| API IF | `adapter/in/api/MeisaiTemplateApi.java`, `MeisaiTemplateApiDelegate.java` |
| Bean config | `adapter/out/configuration/BeanConfiguration.java` (method `meisaiTemplateUseCase()`) |

> Screenshots: 5 ảnh trong `current_state/screenshots/` (đã mô tả ở mục 8).
