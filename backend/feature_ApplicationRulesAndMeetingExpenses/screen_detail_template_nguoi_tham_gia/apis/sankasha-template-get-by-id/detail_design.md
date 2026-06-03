---
version: 1.2.0
status: implemented
api_name: SankashaTemplateGetById
http_method: GET
endpoint: /api/v1/sankasha-template/{id}
last_updated: 2026-06-02
based_on_final_spec_version: 1.2.1
based_on_clarifications_version: 1.1.0
---

> 📘 **Detail design cho API get-by-id Sankasha Template.**
> - Đọc file này là đủ để implement endpoint này.
> - Cross-reference cấp màn hình: [`final_spec.md`](../../final_spec.md)
> - Q&A: [`clarifications.md`](../../clarifications.md)
> - API tạo mới (pattern gốc, dùng chung class): [`../sankasha-template-create/detail_design.md`](../sankasha-template-create/detail_design.md)
> - API update (cùng path `{id}`, cùng response model): [`../sankasha-template-update/detail_design.md`](../sankasha-template-update/detail_design.md)
> - Lịch sử thay đổi: section cuối.
>
> 🔁 **API này reuse class & schema từ create/update.** Đây là API **read-only** (không ghi DB). Các điểm **riêng của get-by-id** được đánh dấu **🆕 DIFF**: read owner-scoped → 404, enrich tên 自社参加者, đánh dấu dòng invalid (§4.8).

# Detail Design — API Get-By-Id Sankasha Template

## 1. Tổng quan API

| Item | Value |
|---|---|
| **API name** | SankashaTemplateGetById |
| **HTTP method** | GET |
| **Endpoint** | `/api/v1/sankasha-template/{id}` |
| **Mục đích** | Lấy chi tiết 1 template người tham gia (header + toàn bộ shosai) để **đổ vào màn Detail ở chế độ chỉnh sửa** |
| **Caller** | Màn 参加者テンプレート詳細 (menu マスタ設定), mở từ nút `編集` trên list. |
| **Role được phép gọi** | `Roles.DEPARTMENT_MANAGEMENT` (5) + `Roles.SUPER_ADMIN` (6) — theo final_spec §4.7 entry point B. |
| **Ownership** | 🆕 **DIFF**: chỉ đọc được template do **chính user** tạo. Read kèm `jugyoin_id = super.getLoginJugyoinId()`; không thuộc owner → **404** (final_spec §4.7). |
| **Ghi DB** | ❌ Không (read-only, không cần `@Transactional` ghi; chỉ đọc) |
| **Success message code** | (không có message — trả thẳng object `SankashaTemplate`) |

---

## 2. Request

### 2.1 HTTP Request

```
GET /api/v1/sankasha-template/{id} HTTP/1.1
Authorization: Bearer <JWT access token (Keycloak, bearer-only)>
```

🆕 **DIFF — chỉ có path param, KHÔNG có request body**:

| Param | Type | Required | Mô tả |
|---|---|---|---|
| `id` | string (path) | ✅ | `sankasha_template_id` của template cần lấy (29 ký tự). |

### 2.2 Request Body

Không có (GET).

---

## 3. Response

### 3.1 Success — HTTP 200

🆕 **DIFF** — trả thẳng object `SankashaTemplate` (header + `shosaiList`), **không** bọc `ModelApiResponse`.

```json
{
  "sankashaTemplateId": "TM06500001202601010900xxAB",
  "sankashaTemplateName": "○○社用",
  "sankaNinzu": 4,
  "memo": "他2名",
  "hyojiJun": 100,
  "updateVersion": 1,
  "shosaiList": [
    {
      "sankashaTemplateShosaiId": "TM06600001202601010900xxAC",
      "sankashaKubun": 1,
      "aitesakiKaishaName": "HBLAB株式会社",
      "aitesakiSankashaName": "経費 太郎",
      "hyojiJun": 1
    },
    {
      "sankashaTemplateShosaiId": "TM06600001202601010900xxAD",
      "sankashaKubun": 2,
      "jishaSankashaJugyoinId": "TM00700001202401010900xxAB",
      "jishaSankashaName": "経費 花子",
      "hyojiJun": 2
    }
  ]
}
```

🆕 **DIFF — các field CHỈ có ở response (enrich, không có ở request)**:

| Field | Type | Mô tả | Nguồn |
|---|---|---|---|
| `sankashaTemplateId` | string | ID template (trả về để FE giữ cho lần update) | DB |
| `updateVersion` | integer | Version optimistic lock hiện tại (FE giữ để gửi lại lúc PUT update) | DB |
| `shosaiList[].sankashaTemplateShosaiId` | string | ID từng shosai | DB |
| `shosaiList[].jishaSankashaName` | string | 🆕 **Enrich**: tên nhân viên nội bộ (自社参加者氏名), join từ `tm_jugyoin` cho kubun=2 (§4.3). DTO đã có sẵn field này. | enrich |
| `shosaiList[].jishaSankashaInvalid` | boolean | 🆕 **Đánh dấu invalid (§4.8)** — `true` khi nhân viên kubun=2 đã bị xoá hoặc role=`NO_RIGHT`; `false`/không set khi hợp lệ. **CHỐT #G1**: dùng `boolean jishaSankashaInvalid` (cần thêm field này vào DTO + API model — additive) | enrich |

> Map sang API model: delegate copy header `SankashaTemplateDto` → `SankashaTemplate`, và **map thủ công** `shosaiList` (nested list — `BeanUtil.copyProperties` không tự copy list, theo api-conventions §3).

### 3.2 Error responses

> ⚠️ **Theo convention THỰC TẾ dự án** (giống create/update §3.2). Pattern read owner-scoped mirror `MeisaiTemplateService.findByMeisaiTemplateId`.

| HTTP | Exception | Message key | Khi nào | Ghi chú |
|---|---|---|---|---|
| 404 | `NotFoundException` | `E041` (param: id, fieldName) | 🆕 **DIFF**: `id` không tồn tại, đã xoá (`delete_flag=1`), hoặc **không thuộc owner** (template của user khác) | Read owner-scoped trả null. Mirror `findByMeisaiTemplateId` |
| 403 | `ForbiddenException` | (`ResponseErrorType.FORBIDDEN`) | Role gọi API ∉ {DEPARTMENT_MANAGEMENT, SUPER_ADMIN} | Ném từ `RoleUtil.check(...)` |
| 401 | `UnAuthorizedException` | — | Token thiếu/không hợp lệ | Tầng security filter |
| 500 | `InternalServerErrorException` | (`ResponseErrorType.INTERNAL_SERVER_ERROR`) | Lỗi hệ thống / DB | — |

> **Không có 400** đặc thù — GET không có body validate. (Nếu `id` sai format chuỗi cũng coi như không tìm thấy → 404.)

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal layer call order)

```
SankashaTemplateApiController.getSankashaTemplate(id)
  └─> SankashaTemplateApiDelegateImpl.getSankashaTemplate(id)         [adapter/in/api/delegate]
        - SankashaTemplateDto dto = useCase.getById(id)
        - SankashaTemplate body = new SankashaTemplate()
        - BeanUtil.copyProperties(body, dto)            (header)
        - map shosaiList thủ công → List<SankashaTemplateShosai>  (gồm jishaSankashaName + invalidFlag)
        - return ApiUtil.responseEntity(body, request)
        └─> SankashaTemplateCrudUseCase.getById(id)                  [port/in]
              └─> SankashaTemplateService.getById(id)                 [application/service]
                    1. RoleUtil.check(getLoginUserDto(),
                         Roles.DEPARTMENT_MANAGEMENT, Roles.SUPER_ADMIN)   → 403 nếu fail
                    2. ★ read header owner-scoped:
                       crud.read(hojinCode, id, loginJugyoinId, delete_flag=0)
                       → NotFoundException (E041/404) nếu null               ★ DIFF
                    3. ★ read toàn bộ shosai của template:
                       crud.findShosaiByTemplateId(hojinCode, id, delete_flag=0)
                       (sort theo hyoji_jun ASC, rồi sankasha_kubun)         ★ DIFF
                    4. set dto.setShosaiList(shosaiList)
                    5. ★ enrich + đánh dấu invalid cho kubun=2 (§4.3, §4.8): ★ DIFF
                       a. gom các jishaSankashaJugyoinId (kubun=2, hasText)
                       b. batch query jugyoin (1 query): jugyoinCrud.findMapByJugyoinIds(hojinCode, ids)
                          → Map<jugyoinId, JugyoinDto>
                          ★ VERIFIED #G2: method này dùng findAllByHojinCodeAndJugyoinIdIn (KHÔNG filter delete_flag)
                            → trả CẢ nhân viên đã xoá → check được invalid
                       c. cho từng shosai kubun=2:
                          - jugyoin = map.get(jishaSankashaJugyoinId)
                          - jugyoin != null → setJishaSankashaName(jugyoin.getJugyoinName())
                          - boolean invalid = (jugyoin == null)
                                          || DeleteFlag.DELETED.getValue().equals(jugyoin.getDeleteFlag())
                                          || Roles.NO_RIGHT.getValue().equals(jugyoin.getKengenCode());
                          - shosai.setJishaSankashaInvalid(invalid)   ★ CHỐT #G1: boolean jishaSankashaInvalid
                    6. return dto
```

**Nhấn mạnh các điểm KHÁC create/update**:
- **Step 2**: read **owner-scoped** → không tồn tại / không thuộc owner đều ra **404** (KHÔNG 403). Kể cả role 5/6 cũng không xem được template của user khác.
- **Step 3**: shosai đọc riêng theo `sankasha_template_id` (header + detail là 2 bảng). Sort `hyoji_jun ASC` để FE render đúng thứ tự đã lưu.
- **Step 5**: enrich tên + đánh dấu invalid là **đặc thù read**. Dùng **1 batch query** (`findMapByJugyoinIds`), KHÔNG loop query từng nhân viên.

### 4.2 Owner-scoped read (§4.7)

```sql
-- Header
SELECT * FROM keihi_com.tm_sankasha_template
WHERE hojin_code = :hojinCode
  AND sankasha_template_id = :id
  AND jugyoin_id = :loginJugyoinId      -- super.getLoginJugyoinId()
  AND delete_flag = 0
```

- Trả null (404) khi: id không tồn tại / đã soft delete / `jugyoin_id` khác login user.
- Mirror `MeisaiTemplateService.findByMeisaiTemplateId` →
  `findMeisaiTemplateByHojinCodeAndMeisaiTemplateIdAndJugyoinIdIdAndDeleteFlag(...)` + `NotFoundException(E041)`.

```sql
-- Detail (toàn bộ shosai của template)
SELECT * FROM keihi_com.tm_sankasha_template_shosai
WHERE hojin_code = :hojinCode
  AND sankasha_template_id = :id
  AND delete_flag = 0
ORDER BY hyoji_jun ASC, sankasha_kubun ASC
```

### 4.3 Enrich tên 自社参加者 (kubun=2)

- Field đích: `SankashaTemplateShosaiDto.jishaSankashaName` (**đã có sẵn** trên DTO — comment `自社参加者氏名（表示用・enrich）`).
- Nguồn: `tm_jugyoin.jugyoin_name` qua `jishaSankashaJugyoinId`.
- Thực hiện **batch** 1 query cho tất cả id kubun=2: `jugyoinCrud.findMapByJugyoinIds(hojinCode, ids)` → `Map<String, JugyoinDto>`.
- Shosai kubun=1 (他社) **không** enrich (đã có sẵn `aitesakiKaishaName` / `aitesakiSankashaName`).

### 4.4 Đánh dấu dòng invalid (§4.8) 🆕 DIFF

Theo **final_spec §4.8**: nhân viên kubun=2 đã lưu trong template, sau đó bị **xoá** (`delete_flag=1`) hoặc đổi **role thành `NO_RIGHT`** → ở màn Detail dòng đó hiển thị như **dữ liệu không hợp lệ** (để user nhận biết, **không tự xoá**).

**CHỐT #G1**: kết quả ghi vào field `boolean jishaSankashaInvalid` trên `SankashaTemplateShosaiDto` (`true` = dữ liệu không hợp lệ, `false` = hợp lệ).

→ Với mỗi shosai kubun=2, `jishaSankashaInvalid = true` khi **bất kỳ** điều kiện sau đúng:
- `jugyoin == null` (không còn trong bảng, hoặc khác hojin), HOẶC
- nhân viên có `delete_flag == 1` (đã xoá) — dùng `DeleteFlag.DELETED.getValue()`, HOẶC
- `Roles.NO_RIGHT.getValue().equals(jugyoin.getKengenCode())` (role bị hạ xuống không quyền).

> ✅ **VERIFIED #G2**: batch query **KHÔNG filter `delete_flag`** để giữ được nhân viên đã xoá (nếu filter, nhân viên đã xoá biến mất khỏi map → không phân biệt "đã xoá" với "không tồn tại"). Dùng `findMapByJugyoinIds(hojinCode, ids)` — đã xác nhận impl gọi `findAllByHojinCodeAndJugyoinIdIn(hojinCode, ids)` (chỉ scope theo `hojin_code`, **không** lọc `delete_flag`), trả cả nhân viên `delete_flag=1`. `JugyoinDto` đã expose `deleteFlag` + `kengenCode`.

> 🔁 So với create/update: ở đó nhân viên invalid bị **chặn** (throw 400, dùng `findJugyoinByIds(..., DeleteFlag.UNDELETED)`). Ở get-by-id thì **ngược lại** — phải **giữ và hiển thị** dòng invalid, không chặn. Đây là điểm dễ nhầm.

---

## 5. Database Operations

### 5.1 Bảng được đọc

| Bảng | Schema | Thao tác | Note |
|---|---|---|---|
| `tm_sankasha_template` | `keihi_com` | SELECT (1 row) | Owner-scoped: `hojin_code + id + jugyoin_id + delete_flag=0` |
| `tm_sankasha_template_shosai` | `keihi_com` | SELECT (N rows) | Theo `sankasha_template_id + delete_flag=0`, sort `hyoji_jun ASC` |
| `tm_jugyoin` | `keihi_com` | SELECT (batch) | Enrich tên + xác định invalid cho kubun=2 (1 query qua `findMapByJugyoinIds`) |

### 5.2 Transaction
- Read-only. Không bắt buộc `@Transactional` ghi. Nếu cần đồng nhất read có thể dùng `@Transactional(readOnly = true)` (tuỳ convention; các read khác trong dự án phần lớn không annotate — verify pattern khi code).

### 5.3 ID Generation
- Không sinh ID (read-only).

### 5.4 Audit fields
- Không đụng.

---

## 6. Class & File Structure (Hexagonal)

> **Dùng chung class với create/update** — xem [create §6](../sankasha-template-create/detail_design.md#6-class--file-structure-hexagonal). API get-by-id **không tạo class mới**, chỉ **thêm method** + 1 query repository.

| Layer | Class | Bổ sung cho get-by-id |
|---|---|---|
| Delegate | `SankashaTemplateApiDelegateImpl` | method `getSankashaTemplate(String id)` → map header + shosaiList (gồm `jishaSankashaName`, invalidFlag) → `SankashaTemplate` |
| Input port | `SankashaTemplateCrudUseCase` | `SankashaTemplateDto getById(String id)` |
| Service | `SankashaTemplateService` | `public SankashaTemplateDto getById(final String id)` — role check + read owner-scoped + read shosai + enrich/invalid |
| Output port | `SankashaTemplateCrud` | `SankashaTemplateDto read(hojinCode, id, jugyoinId, deleteFlag)`; `List<SankashaTemplateShosaiDto> findShosaiByTemplateId(hojinCode, templateId, deleteFlag)` |
| Adapter | `SankashaTemplateAdapter` | impl 2 method trên (entity → DTO qua `BeanUtil`) |
| Repository (header) | `TmSankashaTemplateRepository` | 🆕 `findByHojinCodeAndSankashaTemplateIdAndJugyoinIdAndDeleteFlag(...)` (hiện chỉ có query theo name) |
| Repository (detail) | `TmSankashaTemplateShosaiRepository` | 🆕 `findByHojinCodeAndSankashaTemplateIdAndDeleteFlagOrderByHyojiJunAsc(...)` (hiện trống — chỉ extends `PagingAndSortingRepository`) |

> ⚠️ `SankashaTemplateShosaiDto` **đã có** field `jishaSankashaName`. **Cần bổ sung** `boolean jishaSankashaInvalid` (CHỐT #G1) vào DTO + API model `SankashaTemplateShosai`.
> Reference impl read owner-scoped + 404: `MeisaiTemplateService.findByMeisaiTemplateId`
> (`backend/src/main/java/jp/co/keihi/application/service/MeisaiTemplateService.java:664`).

---

## 7. OpenAPI Definition

> Schema `SankashaTemplate` / `SankashaTemplateShosai` **dùng chung** (đã định nghĩa ở [create §7](../sankasha-template-create/detail_design.md#7-openapi-definition); update đã thêm `updateVersion`).
> 🆕 **DIFF**: get-by-id dùng `SankashaTemplate` làm **response** (create/update dùng làm request). Cần đảm bảo schema có các property enrich: `sankashaTemplateId`, `updateVersion`, `shosaiList[].sankashaTemplateShosaiId`, `shosaiList[].jishaSankashaName`, và (nếu chốt #G1) `jishaSankashaInvalidFlag`.

Thêm **path** vào `api_interface_generate_tool/specification/openapi.yml` (gộp chung với `put` đã định nghĩa ở update — cùng `/sankasha-template/{id}`):

```yaml
  /sankasha-template/{id}:
    get:
      tags:
        - sankasha-template
      parameters:
        - name: id
          in: path
          required: true
          description: Participant template ID
          schema:
            type: string
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SankashaTemplate'
          description: Successful operation
        '403':
          description: Forbidden (role không hợp lệ)
        '404':
          description: Template không tồn tại / không thuộc owner
      operationId: getSankashaTemplate
      summary: Get a participant template by id
      description: >
        Lấy chi tiết 1 template người tham gia (header + shosai).
        Owner-scoped; enrich tên 自社参加者; đánh dấu dòng invalid (§4.8).
    # put: (xem detail_design API update)
```

🆕 Bổ sung property enrich vào schema `SankashaTemplateShosai` (nếu chưa có):

```yaml
        jishaSankashaName:
          type: string
          description: 自社参加者氏名 (enrich, chỉ có ở response get-by-id)
          example: 経費 花子
        jishaSankashaInvalid:
          type: boolean
          description: '§4.8 — true: nhân viên kubun=2 đã xoá hoặc role=NO_RIGHT (dữ liệu không hợp lệ); false: hợp lệ'
          example: false
```

---

## 8. Test Cases

### 8.1 Unit test (Service layer)

| # | Test case | Expected |
|---|---|---|
| 1 | Happy: template có 1 ext + 1 int (nhân viên hợp lệ) | 200, trả header + 2 shosai, `jishaSankashaName` được điền, không có dòng invalid |
| 2 | `id` không tồn tại | **404** (E041) |
| 3 | 🆕 `id` của template **user khác** (cùng hojin) | **404** (owner-scoped read trả null) |
| 4 | 🆕 `id` đã bị soft delete (`delete_flag=1`) | **404** |
| 5 | Template không có shosai nào (edge) | 200, `shosaiList` rỗng (hoặc theo dữ liệu) |
| 6 | 🆕 shosai kubun=2 trỏ nhân viên đã xoá (`delete_flag=1`) | 200, dòng đó **đánh dấu invalid** (§4.8), KHÔNG bị loại bỏ |
| 7 | 🆕 shosai kubun=2 trỏ nhân viên role=`NO_RIGHT` | 200, dòng đó **đánh dấu invalid** |
| 8 | 🆕 shosai kubun=2 trỏ nhân viên không còn tồn tại | 200, dòng invalid, `jishaSankashaName` null |
| 9 | shosai kubun=1 (他社) | 200, không enrich, không đánh dấu invalid |
| 10 | Nhiều kubun=2 → verify **chỉ 1 batch query** jugyoin (không N+1) | 1 lần gọi `findMapByJugyoinIds` |
| 11 | Sort: shosai trả về theo `hyoji_jun ASC` | thứ tự đúng |
| 12 | Role gọi API = `REGISTRATION` (3) | 403 |

### 8.2 Integration test
- Full flow Controller → DB: GET `/sankasha-template/{id}` của chính user → 200, body đúng header + shosai + tên enrich.
- 🆕 Owner isolation: user B GET template của user A → 404.
- 🆕 Invalid display: tạo template với 1 nhân viên hợp lệ, sau đó set nhân viên đó `delete_flag=1` → GET lại thấy dòng đánh dấu invalid (vẫn còn trong list).
- Verify không N+1 query khi nhiều kubun=2.

---

## 9. Open Issues / TBD

> Chỉ liệt kê TBD trực tiếp ảnh hưởng API get-by-id. TBD chung với create (#C1 error convention, #C2 message key, #C4 schema shosai, #C5 model package) **vẫn áp dụng** — xem [create §9](../sankasha-template-create/detail_design.md#9-open-issues--tbd). (TBD #C3 TableCode đã resolved — code đã dùng `TableCode.TM065/TM066`.)

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| G3 | Response trả về có cần kèm các field 他社 visibility (theo setting `tm_keihi_kamoku`, final_spec §4.2) hay FE tự xử lý? | get-by-id chỉ trả dữ liệu đã lưu; visibility do FE/setting quyết định. Tạm **không** kèm flag visibility trong response này. | **Low** | final_spec §4.2; TBD #7 (cross-sheet) |
| G4 | `@Transactional(readOnly=true)` cho method read hay không annotate? | Theo pattern dự án (các read như `MeisaiTemplateService.findByMeisaiTemplateId` không annotate) → tạm **không** annotate. | **Low** | `MeisaiTemplateService` |

> **Đã resolved (gỡ khỏi bảng trên)**:
> - ~~#G1~~ — **CHỐT**: dùng `boolean jishaSankashaInvalid` trên `SankashaTemplateShosaiDto` + API model (`true` = không hợp lệ). Đã phản ánh §3.1, §4.4, §6, §7.
> - ~~#G2~~ — **VERIFIED**: `findMapByJugyoinIds(hojinCode, ids)` gọi `findAllByHojinCodeAndJugyoinIdIn` (không lọc `delete_flag`) → trả cả nhân viên đã xoá. `JugyoinDto` đã có `deleteFlag` + `kengenCode`. Lấy cả nhân viên bị xoá để check hợp lệ.

**Giữ nguyên ID gốc** (#G3, #G4) để không phá vỡ tham chiếu chéo.

**Severity legend**: High = ảnh hưởng schema/API contract; Medium = sửa handler/logic; Low = chỉnh constant/config/message.

> Không còn TBD **High/Medium** → API get-by-id **sẵn sàng implement**. Khi gen code: nhớ thêm field `jishaSankashaInvalid` vào DTO + API model.

---

## 10. References
- final_spec: `../../final_spec.md` (v1.2.1) — đặc biệt §2.2 (table columns), §4.3 (employee rules), §4.7 (ownership), §4.8 (invalid employee), §6 API #2
- clarifications: `../../clarifications.md` (v1.1.0)
- API create (pattern gốc, dùng chung class): [`../sankasha-template-create/detail_design.md`](../sankasha-template-create/detail_design.md)
- API update (cùng path `{id}`, cùng response model): [`../sankasha-template-update/detail_design.md`](../sankasha-template-update/detail_design.md)
- DB design: `../../../db_tables_application_rules_meeting_expenses.xlsx`
- API convention: `.claude/rules/api-conventions.md`
- DB convention: `.claude/rules/database.md`
- Roles enum: `backend/src/main/java/jp/co/keihi/application/enums/Roles.java`
- **Reference impl read owner-scoped + 404 + enrich**: `backend/src/main/java/jp/co/keihi/application/service/MeisaiTemplateService.java` (`findByMeisaiTemplateId`, `:664`)
- Code thực tế đã có (create): `SankashaTemplateService`, `SankashaTemplateAdapter`, `SankashaTemplateCrud`, `SankashaTemplateShosaiDto` (field `jishaSankashaName`)

---

## Version History

### [1.2.0] - 2026-06-03
- **ĐÃ IMPLEMENT** (BUILD SUCCESS), status → `implemented`.
- Reuse `SankashaTemplateCrud.read` (header owner-scoped) + `findShosaiByTemplateIds` + `enrichShosaiList` (dùng chung với search) — **không thêm port/adapter method mới**.
- Enrich qua `JugyoinDto.getShimei()`; `jishaSankashaInvalid` set theo §4.4 (#G2 verified).
- Response model `SankashaTemplate` (đã có `sankashaTemplateId`/`updateVersion`/shosai enrich field từ search). #G4: không annotate `@Transactional` cho read.

### [1.1.0] - 2026-06-02
- **Resolve #G1**: chốt cách báo dòng invalid cho FE — dùng `boolean jishaSankashaInvalid` (`true` = không hợp lệ) trên `SankashaTemplateShosaiDto` + API model `SankashaTemplateShosai`. Cập nhật §3.1, §4.4, §6, §7 (OpenAPI thêm property `jishaSankashaInvalid`).
- **Resolve #G2**: verified `findMapByJugyoinIds(hojinCode, ids)` → `findAllByHojinCodeAndJugyoinIdIn` (không lọc `delete_flag`) trả cả nhân viên đã xoá; `JugyoinDto` có `deleteFlag` + `kengenCode`. Lấy cả nhân viên bị xoá để xác định hợp lệ.
- Status nâng lên `ready-for-implementation` — không còn TBD High/Medium (còn 2 Low #G3, #G4).
- Minor bump: thêm field response mới (additive contract) theo quyết định #G1.

### [1.0.0] - 2026-06-02
- Initial detail design cho API get-by-id.
- Reuse class & schema từ create/update; expand chi tiết các điểm KHÁC: GET + path param `{id}`, read owner-scoped → 404, đọc shosai theo `sankasha_template_id` (sort `hyoji_jun ASC`), enrich `jishaSankashaName` qua batch query, đánh dấu dòng invalid (§4.8) — ngược logic với create/update (giữ & hiển thị thay vì chặn).
- Verify pattern với `MeisaiTemplateService.findByMeisaiTemplateId` (read owner-scoped + `NotFoundException` E041).
- Verify code thực tế đã có: `SankashaTemplateShosaiDto.jishaSankashaName` (sẵn), repository shosai chưa có query find-by-templateId (cần bổ sung), `JugyoinDto.getKengenCode()` (đã dùng ở create cho NO_RIGHT).
- Dựa trên final_spec v1.2.1 và clarifications v1.1.0.
- 4 điểm TBD riêng cho get-by-id (0 High, 2 Medium #G1/#G2, 2 Low #G3/#G4) + kế thừa TBD chung create — xem section 9.
