---
version: 1.2.0
status: implemented
api_name: SankashaTemplateSearch
http_method: POST
endpoint: /api/v1/sankasha-template/search
last_updated: 2026-06-02
based_on_final_spec_version: 1.2.1
based_on_clarifications_version: 1.1.0
---

> ✅ **ĐÃ IMPLEMENT** (BUILD SUCCESS). File này đã được đồng bộ với code thực tế (v1.2.0):
> - Response dùng **`ListResponse<SankashaTemplate>`** generic (pattern codebase `MeisaiTemplate`), KHÔNG tạo model `ListSankashaTemplate` riêng (#S6).
> - Enrich tên nhân viên qua `JugyoinDto.getShimei()` (field tên thực tế), không phải `jugyoinName`.
> - Default `size = 50` set trong service khi null (`SqlUtil.DEFAULT_SIZE` thực tế = 10).

> 📘 **Detail design cho API search Sankasha Template (list màn 参加者テンプレート一覧).**
> - Đọc file này là đủ để implement endpoint này.
> - Cross-reference cấp màn hình: [`final_spec.md`](../../final_spec.md) — đặc biệt §2 (màn List).
> - Q&A: [`clarifications.md`](../../clarifications.md)
> - API create (pattern gốc, dùng chung class): [`../sankasha-template-create/detail_design.md`](../sankasha-template-create/detail_design.md)
> - API get-by-id (cùng enrich `jishaSankashaName`): [`../sankasha-template-get-by-id/detail_design.md`](../sankasha-template-get-by-id/detail_design.md)
> - Lịch sử thay đổi: section cuối.
>
> 🔁 **API này read-only, có paging.** Điểm phức tạp riêng (đánh dấu **🆕 DIFF**): search **xuyên bảng con** `shosai` (S2/S3), aggregate shosai per template để hiển thị multi-line, owner-scoped filter cố định.

# Detail Design — API Search Sankasha Template

## 1. Tổng quan API

| Item | Value |
|---|---|
| **API name** | SankashaTemplateSearch |
| **HTTP method** | POST |
| **Endpoint** | `/api/v1/sankasha-template/search` |
| **Mục đích** | Search list template người tham gia của user (có paging + sort), phục vụ màn 参加者テンプレート一覧 |
| **Caller** | Màn 参加者テンプレート一覧 (menu マスタ設定), khi load list / bấm `検索`. |
| **Role được phép gọi** | `Roles.DEPARTMENT_MANAGEMENT` (5) + `Roles.SUPER_ADMIN` (6) — theo final_spec §4.7 entry point B. |
| **Ownership** | 🆕 **DIFF**: list **CHỈ** trả template do **chính user** tạo. Backend **luôn** add filter cố định `jugyoin_id = super.getLoginJugyoinId()`, **KHÔNG** nhận `jugyoinId` từ body (final_spec §4.7, clarifications #6.17). |
| **Ghi DB** | ❌ Không (read-only) |
| **Success message code** | (không có message — trả thẳng object `ListSankashaTemplate`) |

---

## 2. Request

### 2.1 HTTP Request

```
POST /api/v1/sankasha-template/search HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT access token (Keycloak, bearer-only)>
```

### 2.2 Request Body schema (`SankashaTemplateSearchParameter`)

⚠️ **QUAN TRỌNG**: Body **KHÔNG** có field `jugyoinId`. Owner filter set server-side. Mọi `jugyoinId` client gửi đều bị bỏ qua.

| Field (JSON) | Type | Required | Constraint | Mô tả | Search target |
|---|---|---|---|---|---|
| `sankashaTemplateName` | string | ❌ | `@Size(max=250)` | S1 — tên template (LIKE, case-insensitive) | `tm_sankasha_template.sankasha_template_name` |
| `aitesakiName` | string | ❌ | `@Size(max=250)` | S2 — tên công ty **hoặc** tên người tham gia bên ngoài (LIKE) | `tm_sankasha_template_shosai.aitesaki_kaisha_name` **OR** `aitesaki_sankasha_name` (kubun=1) — **EXISTS subquery** |
| `jishaSankashaName` | string | ❌ | `@Size(max=250)` | S3 — tên nhân viên nội bộ (LIKE) | join `shosai.jisha_sankasha_jugyoin_id` → `tm_jugyoin.jugyoin_name` (kubun=2) — **EXISTS subquery** |
| `page` | integer | ❌ | nullable; default `SqlUtil.DEFAULT_PAGE` | Trang (1-based) | — |
| `size` | integer | ❌ | nullable; default `50` (final_spec §2.4) | Page size | — |
| `sortParameters` | array<SortParameter> | ❌ | — | Sort fields. Default `hyoji_jun ASC` (final_spec §2.4/§4.6) | qua `ApiUtil.getSortList` |

> Domain DTO: `SankashaTemplateSearchParamDto extends SearchParamDto` (kế thừa `page`, `size`, `sortParameters`). **KHÔNG** có field `jugyoinId`. Mirror `MeisaiTemplateSearchParamDto extends SearchParamDto`.

### 2.3 Example Request (happy case)

Xem [`request_examples.json`](./request_examples.json). Tóm tắt:

```json
{
  "sankashaTemplateName": "社用",
  "aitesakiName": "HBLAB",
  "jishaSankashaName": "経費",
  "page": 1,
  "size": 50,
  "sortParameters": [
    { "sortField": "hyojiJun", "sortDirection": "ASC" }
  ]
}
```

> Tất cả field search optional — body rỗng `{}` cũng hợp lệ (trả toàn bộ template của user, default paging/sort).

---

## 3. Response

### 3.1 Success — HTTP 200 (`ListResponse<SankashaTemplate>`)

> ✅ Response model thực tế là **`ListResponse<SankashaTemplate>`** generic (build qua `ApiUtil.toListResponse`), không phải model `ListSankashaTemplate` riêng. Cấu trúc JSON giống hệt bên dưới (pagination + list).

```json
{
  "currentPage": 1,
  "pageSize": 50,
  "totalPage": 1,
  "totalElement": 2,
  "list": [
    {
      "sankashaTemplateId": "TM06500001202601010900xxAB",
      "sankashaTemplateName": "○○社用",
      "sankaNinzu": 4,
      "memo": "他2名",
      "hyojiJun": 100,
      "updateVersion": 1,
      "shosaiList": [
        { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 太郎", "hyojiJun": 1 },
        { "sankashaKubun": 2, "jishaSankashaJugyoinId": "TM00700001...", "jishaSankashaName": "経費 花子", "jishaSankashaInvalid": false, "hyojiJun": 2 }
      ]
    }
  ]
}
```

🆕 **DIFF — chiến lược hiển thị cột multi-line** (final_spec §2.2 cột 5/6):

- Cột **相手先会社名・氏名** = ghép `aitesakiKaishaName + " " + aitesakiSankashaName` cho mỗi shosai `kubun=1`.
- Cột **自社参加者名** = `jishaSankashaName` cho mỗi shosai `kubun=2`.
- **✅ CHỐT #S1**: trả nguyên `shosaiList` per template (đã enrich `jishaSankashaName`), **FE tự lọc theo kubun** và render multi-line — **nhất quán với model get-by-id**, dùng lại `SankashaTemplate`. (Không trả 2 list string riêng.)

| Field (pagination) | Type | Nguồn |
|---|---|---|
| `currentPage` | integer | `ListDto.currentPage` (page.getNumber()+1) |
| `pageSize` | integer | `ListDto.pageSize` |
| `totalPage` | integer | `ListDto.totalPage` |
| `totalElement` | integer (long) | `ListDto.totalElement` |
| `list` | array<SankashaTemplate> | header + shosaiList (enrich) |

### 3.2 Error responses

| HTTP | Exception | Message key | Khi nào | Ghi chú |
|---|---|---|---|---|
| 400 | `BadRequestException` | (error map / `E002`) | Bean validation fail: field search vượt `@Size(max=250)`, sort field không hợp lệ | `super.validate(param)` |
| 403 | `ForbiddenException` | (`ResponseErrorType.FORBIDDEN`) | Role gọi API ∉ {DEPARTMENT_MANAGEMENT, SUPER_ADMIN} | `RoleUtil.check(...)` |
| 401 | `UnAuthorizedException` | — | Token thiếu/không hợp lệ | Tầng security filter |
| 500 | `InternalServerErrorException` | (`ResponseErrorType.INTERNAL_SERVER_ERROR`) | Lỗi hệ thống / DB | — |

> **Không có 404** — search trả list rỗng (`list: []`, `totalElement: 0`) khi không match, KHÔNG ném 404.

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal layer call order)

```
SankashaTemplateApiController.searchSankashaTemplate(SankashaTemplateSearchParameter)
  └─> SankashaTemplateApiDelegateImpl.searchSankashaTemplate(param)   [adapter/in/api/delegate]
        - SankashaTemplateSearchParamDto paramDto = convertSearchParam(param)
          (set name, aitesakiName, jishaSankashaName, page, size,
           sortParameters = ApiUtil.getSortList(param.getSortParameters()))   ← KHÔNG set jugyoinId
        - ListDto<SankashaTemplateDto> result = useCase.search(paramDto)
        - map → ListSankashaTemplate (copy pagination + map từng SankashaTemplateDto → SankashaTemplate, gồm shosaiList)
        - return ApiUtil.responseEntity(body, request)
        └─> SankashaTemplateCrudUseCase.search(paramDto)              [port/in]
              └─> SankashaTemplateService.search(paramDto)            [application/service]
                    1. RoleUtil.check(getLoginUserDto(),
                         Roles.DEPARTMENT_MANAGEMENT, Roles.SUPER_ADMIN)   → 403 nếu fail
                    2. super.validate(paramDto)                           → 400 nếu fail
                    3. default paging/sort: nếu size==null → 50; page==null → DEFAULT_PAGE
                       paramDto.setSortDefault(hyojiJun ASC)               (final_spec §2.4)
                    4. ★ search owner-scoped:
                       crud.search(hojinCode, loginJugyoinId, paramDto)    ★ DIFF (jugyoinId từ context)
                       → ListDto<SankashaTemplateDto> (page các HEADER, paging đúng nhờ EXISTS subquery)
                    5. ★ enrich shosai cho list (tránh N+1):              ★ DIFF
                       a. gom templateIds của page hiện tại
                       b. 1 query: crud.findShosaiByTemplateIds(hojinCode, templateIds, delete_flag=0)
                          → group theo sankashaTemplateId
                       c. gom toàn bộ jishaSankashaJugyoinId (kubun=2) → 1 batch query
                          jugyoinCrud.findMapByJugyoinIds(hojinCode, ids) → enrich jishaSankashaName
                          (+ jishaSankashaInvalid theo §4.8 — tùy chọn, xem #S3)
                       d. gắn shosaiList vào từng SankashaTemplateDto
                    6. return ListDto
```

**Nhấn mạnh các điểm KHÁC**:
- **Step 4**: `jugyoinId = super.getLoginJugyoinId()` truyền vào query — **filter cố định**, FE không override được (mirror `MeisaiTemplateService.search` → `meisaiTemplateCrud.search(hojinCode, loginJugyoinId, param)`).
- **Step 5**: enrich theo **batch** (1 query shosai cho cả page + 1 query jugyoin) — **KHÔNG** query per-row (tránh N+1).

### 4.2 Search query strategy 🆕 DIFF

Search trên **header** (`tm_sankasha_template`) để paging đúng (1 row/template), điều kiện con (`shosai`) đưa vào **EXISTS subquery**:

```sql
SELECT t FROM TmSankashaTemplate t
WHERE t.hojinCode = :hojinCode
  AND t.jugyoinId = :loginJugyoinId          -- owner-scoped cố định
  AND t.deleteFlag = 0
  -- S1: tên template (LIKE)
  AND (:name IS NULL OR LOWER(t.sankashaTemplateName) LIKE :name)
  -- S2: tên 他社 (công ty HOẶC người ngoài) — EXISTS shosai kubun=1
  AND (:aitesakiName IS NULL OR EXISTS (
        SELECT 1 FROM TmSankashaTemplateShosai s1
        WHERE s1.sankashaTemplateId = t.sankashaTemplateId
          AND s1.hojinCode = :hojinCode AND s1.deleteFlag = 0
          AND s1.sankashaKubun = 1
          AND (LOWER(s1.aitesakiKaishaName) LIKE :aitesakiName
               OR LOWER(s1.aitesakiSankashaName) LIKE :aitesakiName)))
  -- S3: tên 自社参加者 — EXISTS shosai kubun=2 JOIN jugyoin
  AND (:jishaSankashaName IS NULL OR EXISTS (
        SELECT 1 FROM TmSankashaTemplateShosai s2
        JOIN TmJugyoin j ON j.hojinCode = :hojinCode
             AND j.jugyoinId = s2.jishaSankashaJugyoinId AND j.deleteFlag = 0
        WHERE s2.sankashaTemplateId = t.sankashaTemplateId
          AND s2.hojinCode = :hojinCode AND s2.deleteFlag = 0
          AND s2.sankashaKubun = 2
          AND LOWER(j.jugyoinName) LIKE :jishaSankashaName))
```

- LIKE: dùng `SqlUtil.getConditionContainLower(...)` (wrap `%...%` + lower) cho cả 3 field, theo pattern `MeisaiTemplateAdapter.viewListMeisaiTemplate`.
- `EXISTS` (thay vì JOIN trực tiếp) → tránh nhân dòng header, paging `totalElement` chính xác.
- ⚠️ S3 dùng `j.deleteFlag = 0` trong EXISTS: nhân viên đã xoá sẽ **không match** S3 (search theo tên hiện hành). Đây là hành vi hợp lý cho ô search; khác với enrich/đánh dấu invalid (§4.8) ở bước hiển thị. Verify lúc code (xem #S2).

### 4.3 Owner-scoped (§4.7)
- `jugyoin_id = super.getLoginJugyoinId()` **bắt buộc** trong WHERE — kể cả role 5/6 chỉ thấy template của chính mình.
- Không có entry nào trong request cho phép đổi filter này.

### 4.4 Default paging & sort (final_spec §2.4, §4.6)
- `size` default **50** (FE thường truyền lên; backend phòng thủ khi null).
- `page` default `SqlUtil.DEFAULT_PAGE`.
- Sort default `hyoji_jun ASC` qua `paramDto.setSortDefault(...)`.
- Cột sortable: ⚠️ **TBD** (final_spec #3) — tạm support sort theo cột physical header (`sankashaTemplateName`, `sankaNinzu`, `hyojiJun`). Sort theo cột derived (S2/S3) **không** support ở v1 (xem #S4).

---

## 5. Database Operations

### 5.1 Bảng được đọc

| Bảng | Schema | Thao tác | Note |
|---|---|---|---|
| `tm_sankasha_template` | `keihi_com` | SELECT (page) | Header — owner-scoped + LIKE name + EXISTS(shosai) |
| `tm_sankasha_template_shosai` | `keihi_com` | SELECT (EXISTS + batch enrich) | Trong EXISTS (S2/S3) + 1 query batch lấy shosai cho cả page (display) |
| `tm_jugyoin` | `keihi_com` | SELECT (JOIN trong EXISTS + batch enrich) | S3 join + enrich `jishaSankashaName` (batch) |

### 5.2 Transaction
- Read-only. Không annotate `@Transactional` ghi (theo pattern `MeisaiTemplateService.search`).

### 5.3 Paging
- `SqlUtil.getPageable(paramDto)` → `Pageable` (page-1, size, sort).
- `ListDto.of(page, SankashaTemplateAdapter::toDto)` để build pagination + list.

---

## 6. Class & File Structure (Hexagonal)

> **Dùng chung class với create/update/get-by-id** — xem [create §6](../sankasha-template-create/detail_design.md#6-class--file-structure-hexagonal). Search thêm method + **DTO search/list mới**.

| Layer | Class | Bổ sung cho search |
|---|---|---|
| Delegate | `SankashaTemplateApiDelegateImpl` | `searchSankashaTemplate(SankashaTemplateSearchParameter)`: `ApiUtil.toSearchParamDto(...)` (KHÔNG set jugyoinId, convert sort) → `ApiUtil.toListResponse(result, this::toApiModel)` (map header + nested shosaiList thủ công) |
| Input port | `SankashaTemplateCrudUseCase` | `ListDto<SankashaTemplateDto> search(SankashaTemplateSearchParamDto param)` |
| Service | `SankashaTemplateService` | `public ListDto<SankashaTemplateDto> search(...)` — role + validate + default sort + search owner-scoped + enrich batch |
| Output port | `SankashaTemplateCrud` | `ListDto<SankashaTemplateDto> search(hojinCode, jugyoinId, param)`; `List<SankashaTemplateShosaiDto> findShosaiByTemplateIds(hojinCode, templateIds, deleteFlag)` |
| Adapter | `SankashaTemplateAdapter` | impl search (`getPageable` + `ListDto.of`); impl `findShosaiByTemplateIds` |
| Repository (header) | `TmSankashaTemplateRepository` | 🆕 `@Query` `search(hojinCode, loginJugyoinId, searchParam, pageable)` với EXISTS subquery (§4.2) |
| Repository (detail) | `TmSankashaTemplateShosaiRepository` | 🆕 `findByHojinCodeAndSankashaTemplateIdInAndDeleteFlag(...)` (batch enrich; dùng chung get-by-id nếu gộp) |
| Domain DTO | 🆕 `SankashaTemplateSearchParamDto extends SearchParamDto` (`sankashaTemplateName`, `aitesakiName`, `jishaSankashaName`) | ✅ đã tạo |
| API model | 🆕 `SankashaTemplateSearchParameter extends SearchParameter` | ✅ đã tạo. Response dùng **`ListResponse<SankashaTemplate>`** generic có sẵn (KHÔNG tạo `ListSankashaTemplate`) — #S6 |
| API model (response field bổ sung) | `SankashaTemplate` (+`sankashaTemplateId`, `updateVersion`), `SankashaTemplateShosai` (+`sankashaTemplateShosaiId`, `jishaSankashaName`, `jishaSankashaInvalid`) | ✅ thêm field additive |

> Reference impl search owner-scoped + paging + Object[]/JOIN: `MeisaiTemplateService.search`, `MeisaiTemplateAdapter.search` / `.viewListMeisaiTemplate`, `TmMeisaiTemplateRepository.search` / `.searchSimple`.

---

## 7. OpenAPI Definition

Thêm vào `api_interface_generate_tool/specification/openapi.yml`.

**Path**:
```yaml
  /sankasha-template/search:
    post:
      tags:
        - sankasha-template
      requestBody:
        description: Search participant templates (owner-scoped, paging)
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/SankashaTemplateSearchParameter'
        required: false
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ListResponse'   # generic — list chứa SankashaTemplate
          description: Successful operation
        '400':
          description: Invalid input / validation error
        '403':
          description: Forbidden (role không hợp lệ)
      operationId: searchSankashaTemplate
      summary: Search participant templates
      description: >
        Search list template người tham gia của user (owner-scoped, paging).
        jugyoinId set từ login context; S2/S3 search xuyên bảng shosai.
```

**Schema**:
```yaml
    SankashaTemplateSearchParameter:
      type: object
      properties:
        sankashaTemplateName:
          type: string
          maxLength: 250
          example: 社用
        aitesakiName:
          type: string
          maxLength: 250
          description: 相手先会社名 hoặc 相手先参加者名 (LIKE, kubun=1)
          example: HBLAB
        jishaSankashaName:
          type: string
          maxLength: 250
          description: 自社参加者名 (LIKE, kubun=2)
          example: 経費
        page:
          type: integer
          format: int32
          example: 1
        size:
          type: integer
          format: int32
          example: 50
        sortParameters:
          type: array
          items:
            $ref: '#/components/schemas/SortParameter'
      xml:
        name: sankashaTemplateSearchParameter
```

> ✅ **Response KHÔNG tạo schema mới** — dùng `ListResponse` generic đã có sẵn trong spec (giống `searchMeisaiTemplate`). Các field response đã được thêm additive vào schema `SankashaTemplate` (`sankashaTemplateId`, `updateVersion`) và `SankashaTemplateShosai` (`sankashaTemplateShosaiId`, `jishaSankashaName`, `jishaSankashaInvalid`).
>
> `SortParameter` đã tồn tại trong spec (dùng chung các API search). `SankashaTemplate` / `SankashaTemplateShosai` dùng chung create/get-by-id.

---

## 8. Test Cases

### 8.1 Unit test (Service layer)

| # | Test case | Expected |
|---|---|---|
| 1 | Body rỗng `{}` | 200, trả toàn bộ template của user, default size 50, sort hyoji_jun ASC |
| 2 | S1 `sankashaTemplateName="社用"` | Chỉ template có tên chứa "社用" (LIKE, owner) |
| 3 | 🆕 S2 `aitesakiName="HBLAB"` | Template có ≥1 shosai kubun=1 với công ty/người ngoài chứa "HBLAB" |
| 4 | 🆕 S2 match theo **tên người ngoài** (không phải công ty) | Vẫn match (OR 2 cột) |
| 5 | 🆕 S3 `jishaSankashaName="経費"` | Template có ≥1 shosai kubun=2 join jugyoin tên chứa "経費" |
| 6 | Kết hợp S1 + S2 + S3 | AND tất cả điều kiện |
| 7 | Không match | 200, `list: []`, `totalElement: 0` |
| 8 | 🆕 Owner isolation: chỉ trả template của login user (dù DB có template user khác trùng tên) | Không lẫn template user khác |
| 9 | 🆕 Paging: 120 template, size=50, page=2 | 50 phần tử, currentPage=2, totalPage=3 |
| 10 | Sort `sankaNinzu DESC` | Đúng thứ tự |
| 11 | 🆕 Verify enrich `jishaSankashaName` đúng cho kubun=2 trong list | Tên điền đúng |
| 12 | 🆕 Verify **không N+1**: 50 template → 1 query shosai + 1 query jugyoin | Số query cố định |
| 13 | `sankashaTemplateName` dài > 250 | 400 (`@Size`) |
| 14 | Role gọi API = `REGISTRATION` (3) | 403 |
| 15 | 🆕 Paging đúng khi có EXISTS (totalElement đếm header, không nhân theo shosai) | totalElement = số template, không phải số shosai |

### 8.2 Integration test
- Full flow Controller → DB: POST search happy_case → 200, body đúng pagination + list.
- 🆕 Owner isolation: 2 user cùng hojin, mỗi người 1 template trùng tên → mỗi user search chỉ thấy của mình.
- 🆕 S2/S3 cross-table: tạo template có shosai ngoại + nội, search theo tên công ty / tên nhân viên → match.
- 🆕 Paging + EXISTS: template có nhiều shosai khớp S2 → vẫn đếm 1 lần (không trùng row).

---

## 9. Open Issues / TBD

> TBD chung với create (#C1 error convention, #C2 message key, #C4 schema shosai, #C5 model package) **vẫn áp dụng** — xem [create §9](../sankasha-template-create/detail_design.md#9-open-issues--tbd). (#C3 TableCode đã resolved.)

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| S2 | Trong EXISTS S3, có loại nhân viên `delete_flag=1` khỏi kết quả search không? | Tạm `j.deleteFlag = 0` (search theo nhân viên hiện hành). Khác với enrich/đánh dấu invalid ở bước hiển thị (§4.8 — vẫn show dòng invalid). | **Low** | final_spec §2.1, §4.8 |
| S3 | List có cần set `jishaSankashaInvalid` (§4.8) cho từng shosai như get-by-id không? | final_spec §2.2 (list) không nêu invalid (đó là màn Detail §4.8). Tạm **vẫn enrich** `jishaSankashaInvalid` để FE nhất quán (cùng dùng `SankashaTemplate`). Nếu list không cần → bỏ để nhẹ. | **Low** | final_spec §2.2, §4.8 |
| S4 | Danh sách cột list được phép sort (kế thừa final_spec TBD #3) | Backend support sort theo cột physical header (`sankashaTemplateName`, `sankaNinzu`, `hyojiJun`). Sort theo cột derived (S2/S3) **không** support v1. FE chốt sort UI sau. | **Low** | final_spec §2.4, §7 TBD #3 |
| S5 | Default `size` = 50 (final_spec §2.4 FE truyền) hay `SqlUtil.DEFAULT_SIZE`? | Backend phòng thủ: nếu null → 50 (khớp final_spec §2.4). Verify `SqlUtil.DEFAULT_SIZE` trùng 50 lúc code; nếu khác → set hằng 50. | **Low** | final_spec §2.4; `SqlUtil` |

> **Đã resolved (gỡ khỏi bảng trên)**:
> - ~~#S1~~ — **CHỐT**: trả nguyên `shosaiList` per template (nhất quán get-by-id), không trả 2 list string. Đã phản ánh §3.1, §7.
> - ~~#S5~~ — **CHỐT khi implement**: default `size = 50` set trong service khi null (`SqlUtil.DEFAULT_SIZE` thực tế = 10, không dùng).
> - **#S6 (mới, đã resolved)** — Response model: dùng **`ListResponse<SankashaTemplate>`** generic (pattern codebase `MeisaiTemplate`), KHÔNG tạo model `ListSankashaTemplate`. Enrich tên dùng `JugyoinDto.getShimei()`.

**Giữ nguyên ID gốc** (#S2–#S4) để không phá vỡ tham chiếu chéo.

**Severity legend**: High = ảnh hưởng schema/API contract; Medium = sửa handler/logic; Low = chỉnh constant/config/message.

> Không còn TBD **High/Medium** → API search **sẵn sàng implement** (còn 4 Low #S2–#S5, không chặn).

---

## 10. References
- final_spec: `../../final_spec.md` (v1.2.1) — §2 (màn List: search fields S1/S2/S3, table columns, paging/sort), §4.6 (sort), §4.7 (ownership), §6 API #1
- clarifications: `../../clarifications.md` (v1.1.0)
- API create / get-by-id / update: cùng thư mục `apis/`
- DB design: `../../../db_tables_application_rules_meeting_expenses.xlsx`
- API convention: `.claude/rules/api-conventions.md`
- DB convention: `.claude/rules/database.md`
- **Reference impl search owner-scoped + paging + cross-table**:
  - `backend/src/main/java/jp/co/keihi/application/service/MeisaiTemplateService.java` (`search`)
  - `backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/MeisaiTemplateAdapter.java` (`search`, `viewListMeisaiTemplate`)
  - `backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/repository/TmMeisaiTemplateRepository.java` (`search`, `searchSimple`)
- `ListDto`, `SearchParamDto`, `SqlUtil.getPageable` / `getConditionContainLower`, `ApiUtil.getSortList`

---

## Version History

### [1.2.0] - 2026-06-02
- **Đồng bộ với code đã implement** (BUILD SUCCESS), status → `implemented`.
- **#S6 (mới, resolved)**: response dùng `ListResponse<SankashaTemplate>` generic (pattern codebase `MeisaiTemplate`) thay vì model `ListSankashaTemplate` riêng. Cập nhật §3.1, §6, §7.
- **#S5 resolved**: default `size = 50` set trong service khi null.
- Enrich tên nhân viên qua `JugyoinDto.getShimei()` (không phải `jugyoinName`).
- Field response thêm additive: `SankashaTemplate` (`sankashaTemplateId`, `updateVersion`), `SankashaTemplateShosai` (`sankashaTemplateShosaiId`, `jishaSankashaName`, `jishaSankashaInvalid`).

### [1.1.0] - 2026-06-02
- **Resolve #S1**: chốt trả nguyên `shosaiList` per template (nhất quán get-by-id), không trả 2 list string. Cập nhật §3.1, §7, §9.
- Status nâng lên `ready-for-implementation` — không còn TBD High/Medium (còn 4 Low #S2–#S5).

### [1.0.0] - 2026-06-02
- Initial detail design cho API search.
- Reuse class & model từ create/get-by-id; expand chi tiết: owner-scoped filter cố định `jugyoin_id` (không nhận từ body), search xuyên bảng con `shosai` qua EXISTS subquery (S2 kubun=1 OR 2 cột, S3 kubun=2 join jugyoin), aggregate shosai per template để hiển thị multi-line (cột 5/6), enrich `jishaSankashaName` batch (tránh N+1), default size 50 + sort hyoji_jun ASC.
- Verify pattern với `MeisaiTemplateService.search` + `MeisaiTemplateAdapter` + `TmMeisaiTemplateRepository.search/searchSimple` (`ListDto.of`, `SearchParamDto`, `SqlUtil.getPageable/getConditionContainLower`).
- DTO mới cần tạo: `SankashaTemplateSearchParamDto extends SearchParamDto`; API model mới: `SankashaTemplateSearchParameter`, `ListSankashaTemplate`.
- Dựa trên final_spec v1.2.1 và clarifications v1.1.0.
- 5 điểm TBD riêng cho search (0 High, 1 Medium #S1, 4 Low) + kế thừa TBD chung create — xem section 9.
