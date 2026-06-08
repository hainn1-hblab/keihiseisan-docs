---
version: 1.0.0
status: draft
last_updated: 2026-06-05
screen: keihikamoku (経費科目 / Expense Item)
purpose: Snapshot current state TRƯỚC khi phân tích spec mở rộng (ApplicationRulesAndMeetingExpenses sheet 02)
source_branch: milestone_v1_57.1
---

# Current State Analysis — Màn 経費科目 (KeihiKamoku / Expense Item)

> Mô tả TRẠNG THÁI HIỆN TẠI của màn (đã có sẵn), tổng hợp từ codebase + screenshots.
> Dùng làm baseline để đối chiếu khi làm spec EXTEND (sheet `02_Setting detail mục chi phí`).
> **Chưa** đụng tới spec mới.

---

## 0. Tóm tắt nhanh

- Màn **master data quản lý "経費科目" (mục chi phí)** dùng chung cho toàn công ty (multi-tenant theo `hojin_code`). Là màn thuộc nhóm `マスタ設定` (master setting), chỉ user role 経理 (5) / SUPER_ADMIN (6) mới quản lý được.
- Pattern lưu trữ: **single-table** (`keihi_com.tm_keihi_kamoku`), **KHÔNG versioning** (không có composite PK version, không có trigger sinh version). PK là `id` đơn (`VARCHAR(29)`).
- **Soft delete** qua `delete_flag` (0=使用中, 1=削除済). **Optimistic lock** qua `@Version update_version`.
- Mỗi record là 1 cấu hình mục chi phí gồm: tên/code, cặp 勘定科目/補助科目 借方(debit)+貸方(credit), nhiều loại 税区分 (適格/適格以外/特例), 1 nhóm cờ "チェック" (kiểm tra khi申請), và 1 nhóm cờ "選択可能性" (mục chi phí này dùng được ở loại minh tế nào).
- Có chức năng đặc biệt: **CSV import/export**, **đồng bộ từ 勘定科目 (synchronizeKanjoHojo)**, và phân biệt **標準科目 (standard, hyojunKamokuUmu=1)** vs **追加科目 (added, =0)** — standard không cho sửa tên/xoá.

---

## 1. Schema DB hiện tại

**Bảng**: `keihi_com.tm_keihi_kamoku`
**PK**: `id` (VARCHAR(29), single PK)
**File Liquibase**: `backend/src/main/resources/liquibase/init/keihi_com/tm_keihi_kamoku.xml`

### 1.1 Lịch sử migration

| ID | Author | Nội dung |
|---|---|---|
| `20210602_tm_keihi_kamoku_init_table` | hoangnh1 | Tạo bảng gốc |
| `20210602_tm_keihi_kamoku_init_index` | hoangnh1 | Index `tm_keihi_kamoku_index_key` (hojin_code, keihi_kamoku_name, riyo_jotai, code, karikata_kanjokamoku) |
| `20210703_..._update_column` | longdv1 | `code` → VARCHAR(250) |
| `20210706_..._update_column` | anhv | `jogen_kingaku` → NUMBER(8) |
| `20210706_..._dropNotNullConstraint` | anhv | `hojo_kamoku` cho null |
| `20210708_..._update_logical_name` | longdv1 | Cập nhật remarks cho hàng loạt cờ |
| `20210709_update_riyo_jotai_notnull` | anhdq | Drop NOT NULL: riyo_jotai, delete_flag, hyoji_jun |
| `20210708_..._update_column` | anhv | Thêm `kanjo_kamoku_doki_umu`, `hojo_kamoku_doki_umu` |
| `20211020 / 20211029` | tiendv | Drop rồi add lại NOT NULL cho jizen_shinsei_bango_check, shussekisha_toroku_check, shussekisha_toroku_umu |
| `20231017_..._add_column` | loihn | Thêm 3 cờ 選択可能性: `ryoshusho_sentaku_kanousei`, `keiro_sentaku_kanousei`, `nittou_sentaku_kanousei` (default 1) |
| `20231128_..._add_column` | loihn | Thêm 貸方 + 特例区分 + 税区分選択可能性: `kashikata_kanjo_kamoku`, `kashikata_hojo_kamoku`, `tokurei_kubun_flag`, `tekikaku_igai_zeikubun`, `tokurei_zeikubun`, `kashikata_kamoku_sentaku_kanousei`, `zeikubun_sentaku_kanousei` |
| `20252107_..._add_column_ForeignCurrency` | ducna1 | **(外貨/Gaika)** Thêm `rate_nyuryoku_check`, `ryoshusho_gaika_sentaku_kanousei`, `gaika_rate_shomeisho_sentaku_kanousei` |
| `20250723_..._update_rate_nyuryoku_check_default` | ducna1 | `rate_nyuryoku_check` default 2 → 0 |
| `20250723_..._update_existing_rate_nyuryoku_check_to_zero` | ducna1 | UPDATE data rate_nyuryoku_check 2 → 0 |

### 1.2 Danh sách cột

| Cột | Type | Null | Default | Ý nghĩa |
|---|---|---|---|---|
| add_date / upd_date | TIMESTAMP | Y | | Audit thời gian |
| add_userid / upd_userid | VARCHAR(29) | Y | | Audit user |
| `id` | VARCHAR(29) | N | | **PK** — 経費科目ID |
| `hojin_code` | VARCHAR(5) | N | | 法人コード (tenant) |
| `keihi_kamoku_name` | VARCHAR(250) | N | | 経費科目名 |
| `code` | VARCHAR(250) | Y | | 経費科目コード (ban đầu 10, nới lên 250) |
| `riyo_jotai` | NUMBER(1) | Y | 0 | 利用状態: 0=未使用,1=使用中 |
| `karikata_kanjokamoku` | VARCHAR(29) | Y | | 借方勘定科目 (FK → tm_kanjo_kamoku) |
| `hojo_kamoku` | VARCHAR(29) | Y | | 借方補助科目 (FK → tm_hojo_kamoku) |
| `kashikata_kanjo_kamoku` | VARCHAR(29) | Y | | 貸方勘定科目 (FK) |
| `kashikata_hojo_kamoku` | VARCHAR(29) | Y | | 貸方補助科目 (FK) |
| `zeikubun` | VARCHAR(29) | Y | | 適格請求書の税区分 (FK → tm_zeikubun) |
| `tekikaku_igai_zeikubun` | VARCHAR(29) | Y | | 適格以外の税区分 (FK) |
| `tokurei_zeikubun` | VARCHAR(29) | Y | | 特例区分の税区分 (FK) |
| `tokurei_kubun_flag` | NUMBER(1) | N | 0 | 特例区分フラグ 0=uncheck,1=check |
| `shussekisha_toroku_umu` | NUMBER(1) | N | 0 | 出席者登録有無 — **(ẩn, phase 2)** |
| `ryoshusho_tempu_check` | NUMBER(1) | N | 0 | 領収書添付チェック: 0=無,1=エラー,2=アラート |
| `shussekisha_toroku_check` | NUMBER(1) | Y | 0 | 出席者登録チェック — **(ẩn, phase 2)** |
| `jizen_shinsei_bango_check` | NUMBER(1) | N | 0 | 事前申請番号チェック — **(ẩn, phase 2)** |
| `memo_check` | NUMBER(1) | N | 0 | メモチェック |
| `hiyo_futan_busho_check` | NUMBER(1) | N | 0 | 費用負担部署チェック |
| `project_check` | NUMBER(1) | N | 0 | プロジェクトチェック |
| `kingaku_jogen_check` | NUMBER(1) | N | 0 | 金額上限チェック |
| `jogen_kingaku` | NUMBER(8) | N | 0 | 上限金額（一人当たり） |
| `shinsei_kakobi_check` | NUMBER(1) | N | 0 | 申請過去日チェック |
| `kako_nissu` | NUMBER(2) | N | 0 | 過去日数 |
| `rate_nyuryoku_check` | NUMBER(1) | N | 0 | **(外貨)** レート入力チェック |
| `ryoshusho_sentaku_kanousei` | NUMBER(1) | N | 1 | 領収書明細で選択可能 0/1 |
| `keiro_sentaku_kanousei` | NUMBER(1) | N | 1 | 経路明細で選択可能 0/1 |
| `nittou_sentaku_kanousei` | NUMBER(1) | N | 1 | 日当明細で選択可能 0/1 |
| `ryoshusho_gaika_sentaku_kanousei` | NUMBER(1) | N | 0 | **(外貨)** 領収書（外貨）明細で選択可能 0/1 |
| `gaika_rate_shomeisho_sentaku_kanousei` | NUMBER(1) | N | 0 | **(外貨)** レート証明書明細で選択可能 0/1 |
| `kashikata_kamoku_sentaku_kanousei` | NUMBER(1) | N | 1 | 貸方勘定/補助科目選択可能 0/1 |
| `zeikubun_sentaku_kanousei` | NUMBER(1) | N | 1 | 税区分選択可能 0/1 |
| `hyoji_jun` | NUMBER(4) | Y | 100 | 表示順 |
| `hyojun_kamoku_umu` | NUMBER(1) | Y | 0 | 0=追加科目, 1=標準科目 |
| `kanjo_kamoku_doki_umu` | NUMBER(1) | Y | 0 | 勘定科目同期有無 |
| `hojo_kamoku_doki_umu` | NUMBER(1) | Y | 0 | 補助科目同期有無 |
| `delete_flag` | NUMBER(1) | Y | 0 | 0=使用中,1=削除済 |
| `update_version` | NUMBER(4) | Y | 1 | 更新バージョン (@Version) |

### 1.3 Index / Constraint
- PK trên `id`.
- 1 non-unique index `tm_keihi_kamoku_index_key` (hojin_code, keihi_kamoku_name, riyo_jotai, code, karikata_kanjokamoku).
- **KHÔNG có unique constraint DB** trên (hojin_code, keihi_kamoku_name) — uniqueness của tên được enforce ở tầng Service (`checkDuplicateName`), không phải DB.

---

## 2. Entity Layer

**File**: `backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/entity/TmKeihiKamoku.java`

- Annotation chuẩn: `@Entity @Data @NoArgsConstructor @Table(name="tm_keihi_kamoku", schema="keihi_com") @SuppressFBWarnings(...) @EntityListeners(AuditingEntityListener.class)`.
- `@Id private String id;` (single PK). `@Version private Integer updateVersion;`.
- Audit fields có annotation `@CreatedDate/@LastModifiedDate/@CreatedBy/@LastModifiedBy`.
- **KHÔNG có JPA relation** (`@ManyToOne`...): mọi FK là String ID thuần (karikataKanjokamoku, hojoKamoku, kashikata*, zeikubun, tekikakuIgaiZeikubun, tokureiZeikubun). Tên FK được resolve thủ công ở Adapter/Repository.
- `jogenKingaku` kiểu **`BigInteger`** (không phải BigDecimal — số nguyên yên).
- Field naming camelCase map ngầm sang snake_case (Spring physical naming). Lưu ý: entity field `karikataKanjokamoku` (k thường ở "kamoku") ↔ cột `karikata_kanjokamoku`.
- Entity vẫn còn đủ 3 field "phase 2": `shussekishaTorokuUmu`, `shussekishaTorokuCheck`, `jizenShinseiBangoCheck` (dù DTO đã comment out).

---

## 3. Domain DTO

**File chính**: `backend/src/main/java/jp/co/keihi/application/domain/KeihiKamokuDto.java`

- `@Data @Component @NoArgsConstructor`, **implements `Diffable<KeihiKamokuDto>`** (dùng cho audit/log diff — `KoshinRireki`).
- Có annotation `@LogOperation` trên hầu hết field (phục vụ ghi 操作履歴 / 更新履歴), nhiều field map enum hiển thị qua `valueDefineEnum` hoặc `idOfTable` (TM035=勘定科目, TM034=補助科目, TM030=税区分).
- **Field map trực tiếp entity**: như mục 1.2.
- **Field enrich (chỉ đọc, set khi search/get)**: `karikataKanjokamokuName`, `karikataKanjokamokuCode`, `kashikataKanjoKamokuName`, `kashikataHojoKamokuName`, `hojoKamokuName`, `zeikubunName`, `zeikubunShortName`, `tekikakuIgaiZeikubunShortName`, `tokureiZeikubunShortName`.
- **Field "phase 2" đã comment out trong DTO** (không nhận từ API, không validate): `shussekishaTorokuUmu`, `shussekishaTorokuCheck`, `jizenShinseiBangoCheck`. Xem mục 9.
- `jogenKingaku` default `BigInteger.ZERO`; `kakoNissu` default `0`.

### Validation (JSR-303, group `Default`)
- `keihiKamokuName`: `@NotBlank {E005}`, `@Size(max=250) {E002}`.
- `riyoJotai`, `ryoshushoTempuCheck`, `memoCheck`, `hiyoFutanBushoCheck`, `projectCheck`, `shinseiKakobiCheck`: `@NotNull {E005}`.
- `karikataKanjokamoku`: `@NotBlank {E005}` + `@StringEmptyOrExactSize(29) {E050}` → **借方勘定科目 là bắt buộc**.
- Các ID FK khác (`zeikubun`, `tekikakuIgaiZeikubun`, `tokureiZeikubun`, `kashikataKanjoKamoku`, `kashikataHojoKamoku`, `hojoKamoku`): `@StringEmptyOrExactSize(29) {E050}` (cho rỗng hoặc đúng 29).
- `hyojiJun`: `@Range(0..9999) {E004}`. `jogenKingaku`: `@Range(0..99999999) {E004}`. `kakoNissu`: `@Range(0..99) {E004}`.
- Các cờ 選択可能性 + `tokureiKubunFlag`: `@EnumNamePattern(regexp="^(0|1)$")`.
- ⚠️ Validation group: **chỉ dùng `Default`**, KHÔNG có validation group con riêng cho add/update.

**File phụ**: `KeihiKamokuSearchParamDto.java`
- Search params: `keihiKamokuName`, `keihiKamokuCode`, `riyoJotai`, `torokuHohos` (List<String>, regex `1|2|3|5|6`), `karikataKanjokamoku`, `kanjoKamokuCode`, `hojoKamoku`, `kashikataKanjoKamoku`, `kashikataHojoKamoku`, `zeikubunId`, + `hojinCode`, `deleteFlag`, `page`, `size`, `sortParameters`.
- Getter có `StringUtil.trim()` cho name/code/karikata/kanjoCode/hojo.
- ⚠️ Note: `ListKeihiKamokuDto` (file chưa đọc trong phase này) — wrapper paging cho list.

---

## 4. API hiện tại

**Base path**: `/api/v1`
**Delegate impl**: `backend/.../adapter/in/api/delegate/KeihiKamokuApiDelegateImp.java` (⚠️ tên file thiếu chữ `l` — `Imp`, không phải `Impl`)
**Delegate IF (generated)**: `backend/.../adapter/in/api/KeihiKamokuApiDelegate.java`
**API model**: `backend/.../adapter/in/api/model/{KeihiKamoku, KeihiKamokuSearchParameter, ListKeihiKamoku}.java`

> ⚠️ **Verify nguồn OpenAPI spec**: endpoint `keihi-kamoku` **KHÔNG có trong** `api_interface_generate_tool/specification/openapi.yml` (grep `keihi-kamoku` → no match). Interface được sinh bởi `org.openapitools.codegen.languages.SpringCodegen` ngày **2021-04-22** từ 1 spec cũ/khác (legacy). ⇒ Khi EXTEND thêm field, **phải xác nhận flow regenerate API model** (có thể phải sửa model bằng tay hoặc tìm spec source cũ).

| # | Method | Path | Delegate method | UseCase method | Response | Message |
|---|---|---|---|---|---|---|
| 1 | GET | /keihi-kamoku/{keihiKamokuId} | getKeihiKamokuById | getKeihiKamokuById | `KeihiKamoku` | — |
| 2 | POST | /keihi-kamoku/search | searchKeihiKamoku | search | `ListKeihiKamoku` | — |
| 3 | POST | /keihi-kamoku/view-list | viewListKeihiKamoku | viewListKeihiKamoku | `ListKeihiKamoku` | — |
| 4 | DELETE | /keihi-kamoku/{keihiKamokuId} | deleteKeihiKamoku | delete | Void | — |
| 5 | DELETE | /keihi-kamoku | deleteKeihiKamokuList | deleteList | `ModelApiResponse` | I006 |
| 6 | POST | /keihi-kamoku | addKeihiKamoku | addKeihiKamoku | `ModelApiResponse` | I001 |
| 7 | PUT | /keihi-kamoku | updateKeihiKamoku | updateKeihiKamoku | `ModelApiResponse` | I002 |
| 8 | POST | /keihi-kamoku/import | importKeihiKamoku | importCsv (async) | `Uketsuke` | — |
| 9 | GET | (csv sample) | downloadCsvSample | getCsvSample/getCsvFilename | CSV file | — |
| 10 | (csv) | downloadCsv | downloadCsv | getCsv | CSV file | — |
| 11 | PATCH | /keihi-kamoku/synchronize-kanjo | synchronizeKanjo | synchronizeKanjoHojo | `ModelApiResponse` | I025 |

**Lưu ý API**:
- `search` (#2) check role chặt (経理/SUPER_ADMIN); `viewListKeihiKamoku` (#3) cho thêm role 承認/登録/閲覧 (APPROVED, REGISTRATION, READ) — dùng cho màn 申請 chọn mục chi phí.
- `importKeihiKamoku` (#8) chạy **async** qua `KeihiKamokuAsyncUseCase.executeCsvImportAsync` (service riêng `KeihiKamokuAsyncService`), trả `Uketsuke` (受付番号) để FE polling.
- `synchronizeKanjo` (#11) là entry point đặc biệt: đồng bộ mục chi phí từ 勘定科目.
- `addKeihiKamoku` ở delegate bắt `IOException` → ném `InternalServerErrorException`.

---

## 5. Business logic trong Service

**File**: `backend/.../application/service/KeihiKamokuService.java` (~1580 dòng)
- `extends AbstractService implements KeihiKamokuUseCase`, `@Slf4j`.
- **Đăng ký bean qua `@Configuration`** (`BeanConfiguration.keihiKamokuUseCase(...)`), KHÔNG dùng `@Service`.
- Constructor inject: `KeihiKamokuCrud`, `KanjoKamokuCrud`, `HojoKamokuCrud`, `ZeikubunCrud`.
- `@Autowired` secondary: `UketsukeCrud`, `TemporaryFileCrud (fileCrud)`, `Validator`, `MeisaiJohoUseCase`, `KoshinRirekiUseCase`.

### 5.1 Phân quyền
- `RoleUtil.check(getLoginUserDto(), Roles.DEPARTMENT_MANAGEMENT, Roles.SUPER_ADMIN)` gọi đầu các method ghi (add/update/delete/deleteList/search/getCsv/importCsv).
- `viewListKeihiKamoku` mở rộng thêm: `APPROVED`, `REGISTRATION`, `READ`.
- `getKeihiKamokuById` **KHÔNG check role**.

### 5.2 `addKeihiKamoku()` flow
1. Check role.
2. Copy request → dto mới; set `hojinCode`, `deleteFlag=0`, `updateVersion=DEFAULT_VERSION`, `id = SqlUtil.generateId(TableCode.TM028, hojinCode)`.
3. Set default nếu null: `hyojiJun=DEFAULT_HYOJIJUN(100)`, `hyojunKamokuUmu=ADDED(0)`, `kanjoKamokuDokiUmu/hojoKamokuDokiUmu=UNSYNCHRONIZED(0)`, 3 cờ sentaku nội địa (ryoshusho/keiro/nittou)=YES, 2 cờ Gaika (ryoshushoGaika/gaikaRateShomeisho)=NO, `rateNyuryokuCheck=NO`, `tokureiKubunFlag=非特例(0)`, `kashikataKamokuSentakuKanousei/zeikubunSentakuKanousei=YES`.
4. `checkDuplicateName(name, null)` — không cho trùng tên.
5. `checkFlagKeihiKamoku()` — validate giá trị các cờ check ∈ CheckFlag.
6. `checkForeignKey()` — validate sự tồn tại + đúng loại của zeikubun/igai/tokurei + 借方/貸方 勘定/補助科目.
7. `checkJogenKingaku()` / `checkKakoNissu()` — nếu cờ check = ERROR/ALERT thì bắt buộc giá trị > 0, else reset về 0.
8. `validator.validate(dto)` → BadRequestException nếu lỗi.
9. `keihiKamokuCrud.saveKeihiKamoku(dto)`.
10. `addLogDataOwnerId` + `koshinRirekiUseCase.addKoshinRireki(empty, afterSave, ...)`.

### 5.3 `updateKeihiKamoku()` flow
1. Check role. `read(hojinCode, id)` lấy bản hiện tại (`existedKeihiKamoku`).
2. Nếu là **標準科目 (DEFAULT=1)** và đổi tên → ném `E084` (không cho đổi tên standard).
3. Nếu record đã `DELETED` → ném `E041`.
4. Merge: copy existed → dto, rồi copy request đè lên; **giữ nguyên** id, hojinCode, deleteFlag, addDate, addUserid, hyojunKamokuUmu, kanjoKamokuDokiUmu, hojoKamokuDokiUmu.
5. **Guard "đang dùng trong meisai"**: với mỗi cờ sentaku (ryoshusho/keiro+keiroApi/nittou/ryoshushoGaika/gaikaRateShomeisho) — nếu chuyển từ YES→NO mà đang được dùng trong minh tế (`checkIsUsedInMeisai`) → ném `E152` kèm label loại minh tế.
6. Default null các cờ (tương tự add).
7. `checkDuplicateName`, `checkFlagKeihiKamoku`, `checkForeignKey`, `checkJogenKingaku`, `checkKakoNissu`, `validator.validate`.
8. `saveKeihiKamoku(dto)` + log KoshinRireki (old=existed, new=dto).

### 5.4 `delete()` / `deleteList()` flow (soft delete)
- `delete(id, updateVersion)`: check role → required id+updateVersion → `read()` → nếu **標準科目** ném `E082` (không xoá standard) → nếu đang dùng trong meisai (`meisaiJohoService.getListMeisaiByKeihiKamokuId`) ném `E065` → set `deleteFlag=DELETED`, `updateVersion`, save. Return 1.
- `deleteList(list)`: validate từng phần tử (id/updateVersion required, không standard, tồn tại trong DB), gom lỗi vào 1 message; nếu OK gọi `delete()` cho từng item + ghi KoshinRireki.

### 5.5 `getKeihiKamokuById()` / `search()` / `viewListKeihiKamoku()` flow
- `getKeihiKamokuById`: `crud.findById(id)` (enrich tên FK), null → `E041`.
- `search`/`viewListKeihiKamoku` → `searchByParam`: default size/page, set hojinCode + deleteFlag=UNDELETED, validate param, gọi `crud.search`.

### 5.6 Validate trùng (checkDuplicateName)
- Scope: theo `hojinCode` + `keihiKamokuName` (qua `findKeihiKamokuByName`). Bỏ qua chính mình khi update (so id). Lỗi `E040`.

### 5.7 Check FK existence (checkForeignKey)
- `zeikubun` → phải tồn tại & `jigyoshaKubun = 適格請求書発行事業者`.
- `tekikakuIgaiZeikubun` → phải `= 適格請求書発行事業者以外`.
- `tokureiZeikubun` → phải `= 特例区分`.
- `karikataKanjokamoku`, `hojoKamoku`, `kashikataKanjoKamoku`, `kashikataHojoKamoku` → phải tồn tại (lỗi `E037`).

### 5.8 synchronizeKanjoHojo() (đặc biệt)
- Lấy toàn bộ 勘定科目 đang dùng → tạo/update bản 経費科目 đồng bộ (`kanjoKamokuDokiUmu=SYNCHRONIZED`). Trùng tên nhưng khác record → cảnh báo `E077`. Không đồng bộ từ 補助科目.

### 5.9 CSV
- `getCsvSample`, `getCsv` (size=CSV_SIZE), `importCsv` (async, lưu file + sinh uketsukeId). DTO CSV: `KeihiKamokuCsvDto` (map label tiếng Nhật cho mọi cờ).

---

## 6. Repository

**File**: `backend/.../repository/TmKeihiKamokuRepository.java` (extends `CrudRepository<TmKeihiKamoku, String>`)

| Method | Mục đích |
|---|---|
| `search(params, pageable)` | JPQL phức hợp: LEFT JOIN TmKanjoKamoku; filter name/code LIKE, riyoJotai, kanjoKamokuCode, 借方/貸方 勘定/補助科目, zeikubunId, **torokuHohos** (1/2/3/5/6 map sang 5 cờ sentaku_kanousei) |
| `getById(hojinCode, id, deleteFlag)` | Lấy 1 bản theo id + deleteFlag |
| `getByName(hojinCode, name, deleteFlag)` | Tìm theo tên (check trùng) |
| `countZeikubunUsedByKeihiKamoku(...)` | Đếm số kamoku dùng 1 zeikubun |
| `getByKarikataKanjokamokuAndHyojunKamokuUmu(...)` | Tìm standard kamoku theo 勘定科目 |
| `getByKarikataKanjokamokuAndKanjoKamokuDokiUmu(...)` | Tìm bản đồng bộ từ kanjo |
| `getByHojokamokuAndKanjoKamokuDokiUmu(...)` | Tìm bản đồng bộ từ hojo |
| `findAllByIdIn(hojinCode, ids, deleteFlag)` | Lấy nhiều theo id |
| `findByIdAndHojinCodeAndDeleteFlag(...)` | Optional 1 bản |
| `findByHojinCodeAndId(...)` | Lấy 1 bản (không quan tâm deleteFlag) |
| `findAllByHojinCode(hojinCode)` | Toàn bộ theo tenant (batch) |
| `getKeihiKamokuIdSpecialInList(...)` | **native SQL** — lọc id có `tokurei_kubun_flag=1` |

- ⚠️ Query `search` dùng SpEL `:#{#params.xxx}`. Điều kiện `torokuHohos` hiện hỗ trợ giá trị **1,2,3,5,6** (KHÔNG có 4 = 経路API).

---

## 7. Adapter (Output)

**File**: `backend/.../adapter/out/persistence/db/KeihiKamokuAdapter.java`
- `@Component @Slf4j implements KeihiKamokuCrud`. Inject: TmKeihiKamoku/TmKanjoKamoku/TmZeikubun/TmHojoKamoku/TrMeisaiJoho repository.
- DTO↔Entity qua `BeanUtil.copyProperties` / `convertList`.
- `findById` + `search` **enrich tên** FK (zeikubun name/shortname, kanjo name+code, hojo name) — `search` batch-load tránh N+1.
- ⚠️ **`saveKeihiKamoku()` ép cứng 3 field "phase 2" = 0**: `shussekishaTorokuUmu=0`, `jizenShinseiBangoCheck=0`, `shussekishaTorokuCheck=0` (hằng số `SHUSSEKISHA_TOROKU_UMU/JIZEN_SHINSEI_BANGO_CHECK/SHUSSEKISHA_TOROKU_CHECK`). Đây là behaviour "đã chết" — xem mục 9.
- `SORT_FIELDS` cho phép sort: `hyojiJun, code, kanjoKamokuCode, jogenKingaku, kakoNissu, keihiKamokuName` (kanjoKamokuCode map sang `kanjo.kanjoKamokuCode`).

---

## 8. Mô tả UI (từ screenshots)

### Ảnh 01 + 02 — 経費科目一覧 (list) `/setting/keihiKamoku/keihiKamokuChiran`
- **検索条件** (panel filter): 経費科目名, 経費科目コード, 借方勘定科目 (dropdown), 借方勘定科目コード, 借方補助科目 (dropdown), 貸方勘定科目 (dropdown), 貸方補助科目 (dropdown), 適格税区分 (dropdown), 利用状態 (dropdown), **明細区分 (dropdown)** → nút 検索.
- **Action bar**: `CSV出力`, `CSV取込`, `新規登録` (cam), `勘定科目最新化` (đồng bộ kanjo).
- **Bảng** (rất nhiều cột): 経費科目名 (kèm nút 編集/削除), 利用状態, 経費科目コード, 借方勘定科目, 借方勘定科目コード, 借方補助科目, 貸方勘定科目, 貸方補助科目, 明細区分 (liệt kê: 領収書/経路/日当/領収書(外貨)/外貨レート証明書), 適格税区分, 適格以外の税区分, 特例区分の税区分, 表示優先順, 領収書添付チェック, メモチェック, 費用負担...(cắt). Phân trang server-side (vd 1-50 / 5476, 110 trang).

### Ảnh 03 + 04 — モーダル 経費科目詳細 (create/edit)
- **基本情報**: 経費科目名 (必須), 経費科目コード, 借方勘定科目 (必須, dropdown), 借方補助科目 (dropdown), 貸方勘定科目 (dropdown), 貸方補助科目 (dropdown), checkbox **特例区分**, 適格請求書の税区分 (dropdown), 適格請求書以外の税区分 (dropdown), 利用状態 (radio 利用しない/利用中), 表示優先順 (default 100).
- **選択可能な明細** ("この経費科目が選択可能な明細の種類"): checkbox `領収書明細`, `経路明細`, `日当明細`, `領収書明細（外貨）`, `レート証明書明細` → map 5 cờ `*_sentaku_kanousei`.
- **申請者が明細作成または更新時、選択できる項目**: checkbox cho 貸方勘定/補助科目選択 (`kashikataKamokuSentakuKanousei`) và 税区分選択 (`zeikubunSentakuKanousei`).
- **アクション・カラー設定** (mỗi dòng = nhóm radio 無し/エラー/アラート): 領収書添付チェック, 費用負担部署チェック, プロジェクトチェック, 金額上限チェック (+ ô 上限金額/円), 外貨レート入力チェック, 申請過去日チェック (+ ô 過去日数/日), メモチェック.
- Footer: nút キャンセル / 登録(保存).

> ⚠️ 3 mục "phase 2" (出席者登録有無/出席者登録チェック/事前申請番号チェック) **KHÔNG xuất hiện** trên UI hiện tại.

---

## 9. Assumption / Limitation hiện tại (QUAN TRỌNG cho EXTEND)

1. **Pattern lưu trữ**: single-table `keihi_com.tm_keihi_kamoku`, PK đơn `id`, **không versioning**, soft delete (`delete_flag`) + optimistic lock (`update_version`). Master share theo `hojin_code`. ⇒ EXTEND thêm field = `addColumn` đơn giản, không đụng PK.

2. **3 field "phase 2" còn sống trong DB+Entity nhưng đã chết ở tầng nghiệp vụ**: `shussekisha_toroku_umu`, `shussekisha_toroku_check`, `jizen_shinsei_bango_check`. DTO comment out, validation/checkFlag bỏ qua, **Adapter ép cứng = 0 khi save**, UI không hiển thị. ⚠️ Nếu spec mới (会議費/meeting expense) yêu cầu "出席者登録" (đăng ký người tham dự) → **rất có thể đây chính là các field này được hồi sinh** — cần kiểm tra kỹ ở Phase 2 thay vì tạo cột mới.

3. **OpenAPI spec không đồng bộ**: endpoint `keihi-kamoku` KHÔNG nằm trong `api_interface_generate_tool/specification/openapi.yml`; interface sinh từ SpringCodegen 2021-04-22 (legacy). ⇒ Khi EXTEND thêm field vào request/response `KeihiKamoku` model, phải xác nhận quy trình regenerate (có thể sửa model bằng tay). 🔴 Cần làm rõ ở Phase 2.

4. **Uniqueness tên enforce ở Service, không phải DB**: `checkDuplicateName` (E040) theo (hojinCode, keihiKamokuName). Không có unique index DB ⇒ vẫn có khả năng trùng nếu bypass service.

5. **Guard "đang dùng trong minh tế" (E152) khi tắt cờ 選択可能性**: chỉ áp khi chuyển YES→NO. EXTEND thêm loại minh tế mới (vd 会議費) → cần thêm guard tương tự + giá trị `TorokuHoho` mới (hiện có 1,2,3,4,5,6; query search chỉ xử lý 1,2,3,5,6).

6. **標準科目 (hyojunKamokuUmu=1) bị khoá**: không đổi tên (E084), không xoá (E082); sinh ra qua `synchronizeKanjoHojo`. EXTEND cần lưu ý nghiệp vụ standard vs added.

7. **Naming/Convention**: `TableCode.TM028` = 経費科目; ID sinh bởi `SqlUtil.generateId(TableCode.TM028, hojinCode)`. Delegate file đặt tên sai chính tả (`KeihiKamokuApiDelegateImp`, thiếu `l`) — giữ nguyên khi sửa.

8. **Quirk Gaika (外貨) vừa thêm 2025 (author ducna1)**: `rate_nyuryoku_check`, `ryoshusho_gaika_sentaku_kanousei`, `gaika_rate_shomeisho_sentaku_kanousei` + TorokuHoho 5,6. Đây là tiền lệ gần nhất cho việc EXTEND field cờ — Phase 2 nên theo đúng pattern này (addColumn + default + update existing data + thêm enum + thêm điều kiện vào query search + default trong add/update service).

9. **`getKeihiKamokuById` không check role** (khác các method còn lại) — lưu ý nếu spec mới đụng tới bảo mật.

---

## 10. Files đã đọc (snapshot)

| Layer | File |
|---|---|
| Liquibase | `liquibase/init/keihi_com/tm_keihi_kamoku.xml` |
| Entity | `adapter/out/persistence/db/entity/TmKeihiKamoku.java` |
| Repository | `adapter/out/persistence/db/repository/TmKeihiKamokuRepository.java` |
| DTO | `application/domain/KeihiKamokuDto.java`, `KeihiKamokuSearchParamDto.java` |
| UseCase (port in) | `application/port/in/KeihiKamokuUseCase.java` |
| Output port | `application/port/out/KeihiKamokuCrud.java` |
| Service | `application/service/KeihiKamokuService.java` (1580 dòng) |
| Adapter (out) | `adapter/out/persistence/db/KeihiKamokuAdapter.java` |
| Delegate impl | `adapter/in/api/delegate/KeihiKamokuApiDelegateImp.java` |
| Delegate IF (gen) | `adapter/in/api/KeihiKamokuApiDelegate.java` |
| Bean config | `adapter/out/configuration/BeanConfiguration.java` (bean `keihiKamokuUseCase`, `keihiKamokuAsyncService`) |
| Enums | CheckFlag, AriNashiUmu, RiyoJotai, TorokuHoho, HyojunKamokuUmu, KamokuDokiUmu, TokureiKubun |

> Screenshots: 4 ảnh trong `current_state/screenshots/` (01,02 list; 03,04 modal create — đã mô tả ở mục 8).
> ⚠️ Chưa đọc (chưa cần cho baseline, có thể cần ở Phase 2): `ListKeihiKamokuDto`, `KeihiKamokuCsvDto`, `KeihiKamokuAsyncService`, API model `KeihiKamoku/ListKeihiKamoku/KeihiKamokuSearchParameter`.
