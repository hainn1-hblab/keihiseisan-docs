---
version: 1.1.0
status: implemented
api_name: SankashaTemplateCreate
http_method: POST
endpoint: /api/v1/sankasha-template
last_updated: 2026-06-02
based_on_final_spec_version: 1.2.1
based_on_clarifications_version: 1.1.0
---

> 📘 **Detail design cho API create Sankasha Template.**
> - Đọc file này là đủ để implement endpoint này.
> - Cross-reference cấp màn hình: [`final_spec.md`](../../final_spec.md)
> - Q&A: [`clarifications.md`](../../clarifications.md)
> - Lịch sử thay đổi: section cuối.
>
> ⚠️ **Lưu ý version**: Task khởi tạo tham chiếu final_spec **v1.1.0**, nhưng file thực tế đã ở **v1.2.0**
> (formalize resolution TBD #4 qua clarifications #6.15–#6.18 — cùng quyết định ownership, chỉ chi tiết hơn).
> Detail design này dựa trên nội dung **v1.2.0** (mới nhất). Xem section 9.

# Detail Design — API Create Sankasha Template

## 1. Tổng quan API

| Item | Value |
|---|---|
| **API name** | SankashaTemplateCreate |
| **HTTP method** | POST |
| **Endpoint** | `/api/v1/sankasha-template` |
| **Mục đích** | Tạo mới 1 template người tham gia (1 header + N shosai) |
| **Caller** | Màn 参加者テンプレート詳細 (menu マスタ設定), nút `保存` ở chế độ tạo mới. Lưu ý: template cũng có thể được tạo từ entry point luồng meisai (mọi role), nhưng đó là API khác — **KHÔNG thuộc scope API này**. |
| **Role được phép gọi** | `Roles.DEPARTMENT_MANAGEMENT` (5) + `Roles.SUPER_ADMIN` (6) — theo final_spec §4.7 entry point B (màn Setting). |
| **Ownership** | `jugyoin_id` luôn = `super.getLoginJugyoinId()`; owner-scoped, không share giữa user (final_spec §4.7, clarifications #6.17). |
| **Success message code** | `I001` |

---

## 2. Request

### 2.1 HTTP Request

```
POST /api/v1/sankasha-template HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT access token (Keycloak, bearer-only)>
```

### 2.2 Request Body schema

⚠️ **QUAN TRỌNG**: Request body **KHÔNG** có field `jugyoinId`. Backend tự set bằng `super.getLoginJugyoinId()` từ login context (clarifications #6.17). Mọi `jugyoinId` client gửi lên đều bị bỏ qua.

**Header level** (`SankashaTemplate`):

| Field (JSON) | Type | Required | Constraint | Mô tả | Map → DB column |
|---|---|---|---|---|---|
| `sankashaTemplateName` | string | ✅ | `@NotBlank`, `@Size(max=250)` | Tên template (参加者テンプレート名) | `sankasha_template_name` |
| `sankaNinzu` | integer | ❌ | nullable; nếu != null và != 0 → range `[1, 999]` | Số người tham gia (参加人数). Cho phép `0` (= không nhập) | `sanka_ninzu` |
| `memo` | string | ❌ | không giới hạn length cứng (DB type `text`) | Memo (自社参加者メモ) | `memo` |
| `hyojiJun` | integer | ❌ | range `[0, 9999]` (cho phép 0); default `100` nếu không truyền | Thứ tự hiển thị (表示順) | `hyoji_jun` |
| `shosaiList` | array<SankashaTemplateShosai> | ❌ | **KHÔNG bắt buộc** (cho phép rỗng/null); ràng buộc count theo kubun khi có (xem §4.2) | Danh sách người tham gia (external + internal) | → `tm_sankasha_template_shosai` |

**Detail level** (`SankashaTemplateShosai` — phần tử trong `shosaiList`):

| Field (JSON) | Type | Required | Constraint | Mô tả | Map → DB column |
|---|---|---|---|---|---|
| `sankashaKubun` | integer | ✅ | `@NotNull`; phải ∈ `{1, 2}` | Loại người tham gia: `1`=external (他社), `2`=internal (自社) | `sankasha_kubun` |
| `aitesakiKaishaName` | string | conditional | `@Size(max=250)`; bắt buộc khi kubun=1, PHẢI null khi kubun=2 | Tên công ty bên ngoài (相手先会社名) | `aitesaki_kaisha_name` |
| `aitesakiSankashaName` | string | conditional | `@Size(max=250)`; bắt buộc khi kubun=1, PHẢI null khi kubun=2 | Tên người tham gia bên ngoài (相手先参加者名) | `aitesaki_sankasha_name` |
| `jishaSankashaJugyoinId` | string | conditional | `@Size(max=29)`; bắt buộc khi kubun=2, PHẢI null khi kubun=1; phải tồn tại & hợp lệ (xem §4.3) | ID nhân viên nội bộ (自社参加者従業員ID) | `jisha_sankasha_jugyoin_id` |
| `hyojiJun` | integer | ❌ | range `[0, 9999]` (cho phép 0); default `1` nếu không truyền (final_spec §4.4) | Thứ tự trong template | `hyoji_jun` |

> **Không nhận từ body** (server tự set): `sankashaTemplateId`, `sankashaTemplateShosaiId`, `sankashaTemplateId` (FK), `hojinCode`, `jugyoinId`, `deleteFlag`, `updateVersion`, `addDate`, `updDate`, `addUserid`, `updUserid`.

### 2.3 Example Request (happy case)

Xem file [`request_examples.json`](./request_examples.json) — phần tử `happy_case`. Tóm tắt:

```json
{
  "sankashaTemplateName": "○○社用",
  "sankaNinzu": 4,
  "memo": "他2名",
  "hyojiJun": 100,
  "shosaiList": [
    { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 太郎", "hyojiJun": 1 },
    { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 四志夫", "hyojiJun": 2 },
    { "sankashaKubun": 2, "jishaSankashaJugyoinId": "TM00700001202401010900xxAB", "hyojiJun": 3 }
  ]
}
```

---

## 3. Response

### 3.1 Success — HTTP 200

```json
{
  "code": 0,
  "message": "登録が完了しました。",
  "type": "success"
}
```

> Body theo `ModelApiResponse` chuẩn (`ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I001"))`). Tham khảo [`response_examples.json`](./response_examples.json) → `success`.

### 3.2 Error responses

> ⚠️ **Đã căn chỉnh theo convention THỰC TẾ của dự án** (khác bảng error-code placeholder trong task — xem §9 TBD #C1).
> Dự án: validation/duplicate → `BadRequestException` (**400**); role → `ForbiddenException` (**403**); system → `InternalServerErrorException` (**500**). **Không dùng 409** cho trùng tên.

| HTTP | Exception | Message key | Khi nào | Ghi chú |
|---|---|---|---|---|
| 400 | `BadRequestException` | (error map từ `BeanUtil.getAllValidationMessageMap`) | Bean validation fail: `sankashaTemplateName` rỗng/quá 250; `shosaiList` rỗng; `sankashaKubun` null/ngoài {1,2} | `type = bad_request`, field-level errors trong `error{}` |
| 400 | `BadRequestException` | `E005` (param: fieldName) | Thiếu field bắt buộc theo kubun (conditional, §4.3) | Có thể gộp vào error map |
| 400 | `BadRequestException` | (msg `参加人数` range) ⚠️ key TBD | `sankaNinzu` > 999 (khi > 0) | Cần thêm message key — xem §9 TBD #C2 |
| 400 | `BadRequestException` | (msg max 100) ⚠️ key TBD | `count(kubun=1) > 100` HOẶC `count(kubun=2) > 100` | Đếm riêng từng kubun (§4.2) |
| 400 | `BadRequestException` | (msg invalid employee) ⚠️ key TBD | kubun=2 nhưng `jishaSankashaJugyoinId` không tồn tại / `delete_flag=1` / role = `NO_RIGHT` | §4.3 |
| 400 | `BadRequestException` | `E040` (param: name, fieldName) | Trùng tên template trong scope `(hojin_code, jugyoin_id, name, delete_flag=0)` | **400, KHÔNG 409** (theo `MeisaiTemplateService`) |
| 403 | `ForbiddenException` | (`ResponseErrorType.FORBIDDEN`) | Role gọi API ∉ {DEPARTMENT_MANAGEMENT, SUPER_ADMIN} | Ném từ `RoleUtil.check(...)` |
| 401 | `UnAuthorizedException` | — | Token thiếu/không hợp lệ | Xử lý ở tầng security filter |
| 500 | `InternalServerErrorException` | (`ResponseErrorType.INTERNAL_SERVER_ERROR`) | Lỗi hệ thống / DB | Rollback transaction |

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal layer call order)

```
SankashaTemplateApiController.addSankashaTemplate(SankashaTemplate)
  └─> SankashaTemplateApiDelegateImpl.addSankashaTemplate(req)        [adapter/in/api/delegate]
        - BeanUtil.copyProperties(dto, req)  (header)
        - map shosaiList thủ công (nested list KHÔNG tự copy) → List<SankashaTemplateShosaiDto>
        - gọi useCase
        └─> SankashaTemplateCrudUseCase.add(dto)                     [port/in]
              └─> SankashaTemplateService.add(dto)  @Transactional    [application/service]
                    1. RoleUtil.check(getLoginUserDto(),
                         Roles.DEPARTMENT_MANAGEMENT, Roles.SUPER_ADMIN)   → 403 nếu fail
                    2. validate(dto) — Bean Validation (header + từng shosai)   → 400 nếu fail
                    3. validate business: count kubun=1 ≤ 100, count kubun=2 ≤ 100, kubun ∈ {1,2} (shosaiList rỗng → bỏ qua)
                    4. validate conditional theo kubun (§4.3),
                       với kubun=2: kiểm tra employee hợp lệ qua JugyoinCrud
                    5. dto.setHojinCode(super.getHojinCode())
                    6. dto.setJugyoinId(super.getLoginJugyoinId())   ★ KHÔNG lấy từ body
                    7. checkUnique(hojinCode, jugyoinId, name, delete_flag=0)   → E040/400 nếu trùng
                    8. dto.setSankashaTemplateId(SqlUtil.generateId(TableCode.TM065, hojinCode))
                       dto.setDeleteFlag(DeleteFlag.UNDELETED)         (0)
                       dto.setUpdateVersion(SqlUtil.DEFAULT_VERSION)   (1)
                       if hyojiJun == null → SqlUtil.DEFAULT_HYOJIJUN  (100)
                    9. cho từng shosai:
                       - setSankashaTemplateShosaiId(generateId(TableCode.TM066, hojinCode))
                       - setSankashaTemplateId(header.id)
                       - setHojinCode(super.getHojinCode())   ★ multi-tenant (final_spec §5.2)
                       - if hyojiJun == null → 1
                    10. crud.save(header) + crud.saveShosaiList(shosaiList)  (cùng 1 transaction)
                    11. addLogDataOwnerId(getLoginJugyoinId())  (audit operation log)
                  ┌──────────────────────────────────────────────┐
                  │ @CreatedDate/@CreatedBy/... set tự động qua    │
                  │ AuditingEntityListener khi persist entity      │
                  └──────────────────────────────────────────────┘
        - ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I001"))
        - return ApiUtil.responseEntity(body, request)
```

**Nhấn mạnh** (bắt buộc đúng):
- **Step 6**: `jugyoin_id = super.getLoginJugyoinId()` — KHÔNG lấy từ request body.
- **Step 7**: unique check scope = `(hojin_code, jugyoin_id, sankasha_template_name, delete_flag = 0)`.
- **Step 8 & audit**: `add_date / upd_date / add_userid / upd_userid` set tự động qua `@EntityListeners(AuditingEntityListener.class)`; `delete_flag = 0`, `update_version = 1`.
- Toàn bộ trong **1 transaction** (`@Transactional`).

### 4.2 Validation chi tiết

**Cấp field (Bean Validation annotation trên DTO)**:
- `sankashaTemplateName`: `@NotBlank`, `@Size(max = 250)`.
- `sankaNinzu`: nullable. Nếu != null và != 0 → range `[1, 999]` (validate ở business layer vì là conditional — `@Min/@Max` không biểu diễn được điều kiện "0 được phép"; xem note dưới).
- `hyojiJun` (header & shosai): range `[0, 9999]` (cho phép 0); default 100 (header) / 1 (shosai) nếu null.
- `memo`: KHÔNG validate length cứng (DB `text`).
- `shosaiList`: **KHÔNG bắt buộc** (bỏ `@NotEmpty`) — cho phép rỗng/null. Service normalize null → empty list.
- `shosaiList[].sankashaKubun`: `@NotNull` (chỉ áp khi có phần tử).

> Note về `sankaNinzu`: vì "0 hợp lệ, 1–999 hợp lệ, nhưng KHÔNG dùng `@Min(1)`" → đặt validation này ở **business layer**: `if (sankaNinzu != null && sankaNinzu != 0 && (sankaNinzu < 1 || sankaNinzu > 999)) → error`. (final_spec §4.1)

**Cấp business (Service layer)**:
- **Đếm riêng theo kubun** (clarifications #6.16, final_spec §3.1 F4/F6): `count(shosai.kubun == 1) ≤ 100` **VÀ** `count(shosai.kubun == 2) ≤ 100`. **KHÔNG** check tổng `≤ 200`, **KHÔNG** dùng `@Size(max=200)` trên cả list. `shosaiList` rỗng → cả 2 count = 0 → hợp lệ.
- `sankashaKubun` ∈ `{1, 2}`.
- Conditional theo kubun (§4.3).
- Unique name (§4.4).

### 4.3 Conditional rule theo `sankashaKubun`

| Trường hợp | Field bắt buộc | Field PHẢI null |
|---|---|---|
| `kubun = 1` (external / 他社) | `aitesakiKaishaName`, `aitesakiSankashaName` | `jishaSankashaJugyoinId` |
| `kubun = 2` (internal / 自社) | `jishaSankashaJugyoinId` | `aitesakiKaishaName`, `aitesakiSankashaName` |

Với `kubun = 2`, `jishaSankashaJugyoinId` phải trỏ tới nhân viên trong `tm_jugyoin` thoả **tất cả**:
- cùng `hojin_code` với user hiện tại,
- `delete_flag = 0`,
- **role ≠ `Roles.NO_RIGHT`** — dùng enum `jp.co.keihi.application.enums.Roles.NO_RIGHT`, **KHÔNG** hardcode số `1` trong code (final_spec §4.3).

> Nếu một trong các điều kiện trên fail → validation error 400 (cùng nhóm với conditional). Đây là rule áp dụng lúc create; với template đã lưu rồi mới phát sinh invalid → xem final_spec §4.8 (xử lý ở update/apply, ngoài scope create).

### 4.4 Unique check

Trước khi insert, query (qua repository, owner-scoped):

```sql
SELECT 1 FROM keihi_com.tm_sankasha_template
WHERE hojin_code = :hojinCode
  AND jugyoin_id = :jugyoinId          -- từ super.getLoginJugyoinId()
  AND sankasha_template_name = :name
  AND delete_flag = 0
```

Nếu có row → `throw new BadRequestException(MessageUtil.getMessage("E040", name, fieldName))` (HTTP 400).

> Scope unique theo **owner** (clarifications #6.18): user A và user B trong cùng `hojin_code` được phép cùng đặt tên `○○社用`. Mirror đúng pattern `MeisaiTemplateService.checkDuplicateName` (`getByMeisaiTemplateName(hojinCode, loginJugyoinId, name, UNDELETED)`).

---

## 5. Database Operations

### 5.1 Bảng được insert

| Bảng | Schema | Số rows | Note |
|---|---|---|---|
| `tm_sankasha_template` | `keihi_com` | 1 | Header. `jugyoin_id` từ login context |
| `tm_sankasha_template_shosai` | `keihi_com` | N | N = `shosaiList.size()`. Mỗi row set `hojin_code = super.getHojinCode()` (multi-tenant — final_spec §5.2) |

### 5.2 Transaction
- Toàn bộ trong **1 transaction** (`@Transactional` trên method `add`).
- Rollback nếu bất kỳ insert nào fail (header hoặc shosai).
- Isolation: mặc định của dự án (không override).

### 5.3 ID Generation
- Pattern: `SqlUtil.generateId(TableCode.<code>, super.getHojinCode())` → chuỗi **29 ký tự** = TableCode(5) + hojinCode(5) + datetime(17) + random(2).
- `sankasha_template_id`: dùng `TableCode.TM065` ⚠️ **cần thêm** (TableCode hiện tại max = `TM064`) — xem §9 TBD #C3.
- `sankasha_template_shosai_id`: dùng `TableCode.TM066` ⚠️ **cần thêm**.

### 5.4 Audit fields tự động set

| Field | Value | Cơ chế |
|---|---|---|
| `add_date` | now() | `@CreatedDate` (AuditingEntityListener) |
| `upd_date` | now() | `@LastModifiedDate` |
| `add_userid` | login user id | `@CreatedBy` |
| `upd_userid` | login user id | `@LastModifiedBy` |
| `update_version` | `1` | `SqlUtil.DEFAULT_VERSION` set thủ công trong service |
| `delete_flag` | `0` | `DeleteFlag.UNDELETED` set thủ công |

> ⚠️ Lưu ý schema: file thiết kế DB **chưa liệt kê** `delete_flag` / `update_version` cho bảng `tm_sankasha_template_shosai` (final_spec §5.2 note). Liquibase changeset cần bổ sung theo convention — xem §9 TBD #C4.

---

## 6. Class & File Structure (Hexagonal)

> Naming lấy từ final_spec §6, đã verify với pattern thực tế `MeisaiTemplate*` trong source (cùng kiểu master header+detail, owner-scoped).

| Layer | Class | Path |
|---|---|---|
| API interface (generated) | `SankashaTemplateApi` | `adapter/in/api/SankashaTemplateApi.java` |
| Controller (generated) | `SankashaTemplateApiController` | `adapter/in/api/SankashaTemplateApiController.java` |
| Delegate | `SankashaTemplateApiDelegateImpl` | `adapter/in/api/delegate/SankashaTemplateApiDelegateImpl.java` |
| API model (generated) | `SankashaTemplate`, `SankashaTemplateShosai` | `adapter/in/api/model/` (hoặc `jp.co.keihi.openapi` theo cấu hình generator) |
| Input port | `SankashaTemplateCrudUseCase` | `application/port/in/SankashaTemplateCrudUseCase.java` |
| Service | `SankashaTemplateService extends AbstractService` | `application/service/SankashaTemplateService.java` |
| Output port | `SankashaTemplateCrud` | `application/port/out/SankashaTemplateCrud.java` |
| Adapter | `SankashaTemplateAdapter` | `adapter/out/persistence/db/SankashaTemplateAdapter.java` |
| Entity (header) | `TmSankashaTemplate` | `adapter/out/persistence/db/entity/TmSankashaTemplate.java` |
| Entity (detail) | `TmSankashaTemplateShosai` | `adapter/out/persistence/db/entity/TmSankashaTemplateShosai.java` |
| Repository (header) | `TmSankashaTemplateRepository` | `adapter/out/persistence/db/repository/TmSankashaTemplateRepository.java` |
| Repository (detail) | `TmSankashaTemplateShosaiRepository` | `adapter/out/persistence/db/repository/TmSankashaTemplateShosaiRepository.java` |
| Domain DTO | `SankashaTemplateDto`, `SankashaTemplateShosaiDto` | `application/domain/` |
| Bean config | `SankashaTemplateConfiguration` | `adapter/out/configuration/SankashaTemplateConfiguration.java` |

**Bean registration** (service không dùng `@Service` — đăng ký qua `@Configuration`):
```java
@Bean
public SankashaTemplateCrudUseCase sankashaTemplateService(
    final SankashaTemplateCrud sankashaTemplateCrud,
    final JugyoinCrud jugyoinCrud) {
  return new SankashaTemplateService(sankashaTemplateCrud, jugyoinCrud);
}
```

> Reference convention: `MeisaiTemplateService` dùng `@RequiredArgsConstructor` + `extends AbstractService` + `@Slf4j`; có thể áp dụng tương tự.

---

## 7. OpenAPI Definition

Thêm vào `api_interface_generate_tool/specification/openapi.yml`.

**Path** (`paths:`):
```yaml
  /sankasha-template:
    post:
      tags:
        - sankasha-template
      requestBody:
        description: Create a new participant template
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/SankashaTemplate'
        required: true
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ModelApiResponse'
          description: Successful operation
        '400':
          description: Invalid input / validation error / duplicate name
        '403':
          description: Forbidden (role không hợp lệ)
      operationId: addSankashaTemplate
      summary: Add a new participant template
      description: Tạo mới template người tham gia (header + shosai). jugyoinId set từ login context.
```

**Schema** (`components/schemas:`):
```yaml
    SankashaTemplate:
      required:
        - sankashaTemplateName
        - shosaiList
      type: object
      properties:
        sankashaTemplateName:
          type: string
          maxLength: 250
          example: ○○社用
        sankaNinzu:
          type: integer
          format: int32
          example: 4
        memo:
          type: string
          example: 他2名
        hyojiJun:
          type: integer
          format: int32
          example: 100
        shosaiList:
          type: array
          items:
            $ref: '#/components/schemas/SankashaTemplateShosai'
      xml:
        name: sankashaTemplate
    SankashaTemplateShosai:
      required:
        - sankashaKubun
      type: object
      properties:
        sankashaKubun:
          type: integer
          format: int32
          description: '1: external (他社), 2: internal (自社)'
          example: 1
        aitesakiKaishaName:
          type: string
          maxLength: 250
          example: HBLAB株式会社
        aitesakiSankashaName:
          type: string
          maxLength: 250
          example: 経費 太郎
        jishaSankashaJugyoinId:
          type: string
          maxLength: 29
        hyojiJun:
          type: integer
          format: int32
          example: 1
      xml:
        name: sankashaTemplateShosai
```

> `ModelApiResponse` đã tồn tại trong spec (dùng chung cho các API trả message). Không định nghĩa lại.

---

## 8. Test Cases

### 8.1 Unit test (Service layer)

| # | Test case | Expected |
|---|---|---|
| 1 | Happy: 1 external + 1 internal | Success, persist 1 header + 2 shosai, return I001 |
| 2 | `sankaNinzu = 1000` | 400 (range error) |
| 3 | `sankaNinzu = 0` | Success (cho phép 0) |
| 4 | `sankaNinzu = null` | Success |
| 5 | `shosaiList` rỗng / null | **Success** (cho phép template không có người tham gia) |
| 6 | shosai kubun=1 thiếu `aitesakiKaishaName` | 400 (conditional) |
| 7 | shosai kubun=2 thiếu `jishaSankashaJugyoinId` | 400 (conditional) |
| 8 | shosai kubun=2, employee có role = `NO_RIGHT` | 400 (invalid employee) |
| 9 | shosai kubun=2, employee `delete_flag = 1` | 400 (invalid employee) |
| 10 | 101 phần tử kubun=1 (vượt 100 external) | 400 (max external) |
| 11 | 101 phần tử kubun=2 (vượt 100 internal) | 400 (max internal) |
| 12 | 100 external + 100 internal = 200 phần tử | Success (đúng max mỗi kubun) |
| 12b | `hyojiJun = 0` (header & shosai) | Success (cho phép 0) |
| 13 | Tên trùng template đã có của CHÍNH user | 400 (E040) |
| 14 | Tên trùng template của user KHÁC cùng hojin | Success (owner-scoped unique) |
| 15 | Role gọi API = `REGISTRATION` (3) | 403 (ForbiddenException) |
| 16 | Sau insert: verify `jugyoin_id == super.getLoginJugyoinId()` (dù body gửi jugyoinId khác) | DB lưu login user id, bỏ qua body |
| 17 | shosai kubun=1 nhưng có `jishaSankashaJugyoinId` != null | 400 (field phải null) |
| 18 | `sankashaKubun = 3` (ngoài {1,2}) | 400 |
| 19 | `hyojiJun` không truyền | Success, header=100, shosai=1 |

### 8.2 Integration test
- Full flow Controller → DB: gửi happy_case, verify HTTP 200 + I001, query DB thấy đúng 1 header + N shosai.
- Verify **transaction rollback**: giả lập lỗi khi insert shosai thứ k → toàn bộ rollback, không còn header mồ côi.
- Verify **audit fields** (`add_date/upd_date/add_userid/upd_userid`) set đúng từ login context.
- Verify **jugyoin_id** = login user id ngay cả khi body cố tình gửi jugyoinId khác.

---

## 9. Open Issues / TBD

> Chỉ liệt kê TBD trực tiếp ảnh hưởng API create này.

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| C1 | Bảng error-code mẫu trong task (E001/E002/E003/E004/E010/E999, dùng 409 cho trùng tên) **không khớp** convention thực tế dự án | Theo convention dự án: validation/duplicate → `BadRequestException` (400); role → `ForbiddenException` (403); system → `InternalServerErrorException` (500). E040 dùng **400** (mirror `MeisaiTemplateService`), KHÔNG 409 | **Medium** | CLAUDE.md §7, `MeisaiTemplateService` |
| C2 | Chưa có message key cho: `sankaNinzu` range, max-100-per-kubun, invalid-employee | Tạm dùng error map field-level (pattern Bean Validation). Cần PO/Lead duyệt text + thêm key vào `messages*.properties` | **Low** | final_spec §4.1/§4.3 |
| C3 | `TableCode` chưa có entry cho 2 bảng mới (max hiện tại = `TM064`) | Thêm `TM065 = tm_sankasha_template`, `TM066 = tm_sankasha_template_shosai` vào enum `TableCode.java` | **Low** | `TableCode.java` |
| C4 | Schema thiết kế chưa có `delete_flag` / `update_version` cho `tm_sankasha_template_shosai` | Bổ sung trong Liquibase theo convention (final_spec §5.2). Với create không bắt buộc dùng tới, nhưng nên có sẵn | **Low** | final_spec §5.2, §7 (#6) |
| C5 | API model `SankashaTemplate`/`SankashaTemplateShosai` được sinh ở package nào (`adapter/in/api/model` vs `jp.co.keihi.openapi`) tuỳ cấu hình generator | Theo cấu hình `api_interface_generate_tool` hiện hành; verify lại lúc generate | **Low** | api-conventions.md §2 |

**Severity legend**: High = ảnh hưởng schema/API contract; Medium = sửa handler/logic; Low = chỉnh constant/config/message.

> Không có TBD **High** → API create **sẵn sàng implement** sau khi chốt C1 (error convention) và thêm C3 (TableCode).

---

## 10. References
- final_spec: `../../final_spec.md` (thực tế **v1.2.0**; task tham chiếu v1.1.0 — xem callout đầu file)
- clarifications: `../../clarifications.md` (v1.1.0)
- DB design: `../../../db_tables_application_rules_meeting_expenses.xlsx`
- API convention: `.claude/rules/api-conventions.md`
- DB convention: `.claude/rules/database.md`
- Roles enum: `backend/src/main/java/jp/co/keihi/application/enums/Roles.java`
- Reference impl (pattern owner-scoped header+detail): `backend/src/main/java/jp/co/keihi/application/service/MeisaiTemplateService.java`
- ID gen: `SqlUtil.generateId` (`backend/src/main/java/jp/co/keihi/application/util/SqlUtil.java`); `TableCode` enum

---

## Version History

### [1.1.0] - 2026-06-03
- **Đồng bộ 3 thay đổi nghiệp vụ** (final_spec v1.3.0) vào code + design:
  - `hyojiJun` (header & shosai) cho phép từ **0** (`[0, 9999]`).
  - Max per kubun = **100** (trước 99); check `count > 100`.
  - `shosaiList` **KHÔNG bắt buộc** (bỏ `@NotEmpty`); service normalize null → empty list.
- Cập nhật §2.2, §3.2, §4.1, §4.2, §8 (test cases). Status → `implemented`.

### [1.0.1] - 2026-06-02
- Đồng bộ với final_spec **v1.2.1**: bổ sung set `hojin_code = super.getHojinCode()` cho từng shosai (§4.1 step 9, §5.1) — phản ánh cột `hojin_code` (multi-tenant) đã thêm vào `tm_sankasha_template_shosai` (đã có trong Liquibase changeset). Patch — không đổi API contract.

### [1.0.0] - 2026-29-05
- Initial detail design cho API create.
- Dựa trên final_spec (thực tế v1.2.0, task tham chiếu v1.1.0) và clarifications v1.1.0.
- Verify pattern với `MeisaiTemplateService` (owner-scoped header+detail) và `SqlUtil.generateId`/`TableCode`.
- Còn 5 điểm TBD (0 High, 1 Medium #C1, 4 Low) — xem section 9.
