---
version: 1.0.0
status: draft
api_name: SankashaTemplateUpdate
http_method: PUT
endpoint: /api/v1/sankasha-template/{id}
last_updated: 2026-06-02
based_on_final_spec_version: 1.2.1
based_on_clarifications_version: 1.1.0
---

> 📘 **Detail design cho API update Sankasha Template.**
> - Đọc file này là đủ để implement endpoint này.
> - Cross-reference cấp màn hình: [`final_spec.md`](../../final_spec.md)
> - Q&A: [`clarifications.md`](../../clarifications.md)
> - API tạo mới (pattern gốc, dùng chung phần lớn rule): [`../sankasha-template-create/detail_design.md`](../sankasha-template-create/detail_design.md)
> - Lịch sử thay đổi: section cuối.
>
> 🔁 **API này reuse phần lớn rule từ create.** Chỉ những điểm **KHÁC create** được expand chi tiết; phần chung (conditional kubun, đếm theo kubun, employee validation, ownership) chỉ tóm tắt + link sang create. Các điểm khác biệt được đánh dấu **🆕 DIFF**.

# Detail Design — API Update Sankasha Template

## 1. Tổng quan API

| Item | Value |
|---|---|
| **API name** | SankashaTemplateUpdate |
| **HTTP method** | PUT |
| **Endpoint** | `/api/v1/sankasha-template/{id}` |
| **Mục đích** | Cập nhật 1 template người tham gia: update header + **thay thế toàn bộ** shosai cũ bằng list mới |
| **Caller** | Màn 参加者テンプレート詳細 (menu マスタ設定), nút `保存` ở chế độ **chỉnh sửa** (mở từ nút `編集` trên list). |
| **Role được phép gọi** | `Roles.DEPARTMENT_MANAGEMENT` (5) + `Roles.SUPER_ADMIN` (6) — theo final_spec §4.7 entry point B. |
| **Ownership** | 🆕 **DIFF**: chỉ update được template do **chính user** tạo. Read tồn tại kèm `jugyoin_id = super.getLoginJugyoinId()`; không thuộc owner → **404** (final_spec §4.7). `jugyoin_id` **KHÔNG** đổi qua update. |
| **Success message code** | 🆕 **DIFF**: `I002` (create dùng `I001`) |

---

## 2. Request

### 2.1 HTTP Request

```
PUT /api/v1/sankasha-template/{id} HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT access token (Keycloak, bearer-only)>
```

🆕 **DIFF — Path param**:

| Param | Type | Required | Mô tả |
|---|---|---|---|
| `id` | string (path) | ✅ | `sankasha_template_id` của template cần update (29 ký tự). Đây là nguồn ID chính. Nếu body cũng có `sankashaTemplateId` thì lấy theo **path** (xem §4.1 step 0). |

### 2.2 Request Body schema

⚠️ **QUAN TRỌNG** (giống create): Request body **KHÔNG** nhận `jugyoinId` (server không cho đổi owner). Mọi `jugyoinId` client gửi lên đều bị bỏ qua.

🆕 **DIFF — thêm field `updateVersion`** cho optimistic lock (create không có).

**Header level** (`SankashaTemplate`):

| Field (JSON) | Type | Required | Constraint | Mô tả | Map → DB column |
|---|---|---|---|---|---|
| `sankashaTemplateName` | string | ✅ | `@NotBlank`, `@Size(max=250)` | Tên template (参加者テンプレート名) | `sankasha_template_name` |
| `sankaNinzu` | integer | ❌ | nullable; nếu != null và != 0 → range `[1, 999]` | Số người tham gia (参加人数). Cho phép `0` | `sanka_ninzu` |
| `memo` | string | ❌ | không giới hạn length cứng (DB type `text`) | Memo (自社参加者メモ) | `memo` |
| `hyojiJun` | integer | ❌ | range `[1, 9999]`; default `100` nếu không truyền | Thứ tự hiển thị (表示順) | `hyoji_jun` |
| `updateVersion` | integer | ✅ 🆕 | `@NotNull` | **Optimistic lock** — version client đang giữ. Phải khớp version DB hiện tại, không thì 409/conflict (xem §4.5) | `update_version` (`@Version`) |
| `shosaiList` | array<SankashaTemplateShosai> | ✅ | `@NotEmpty`; ràng buộc count theo kubun (§4.2 create) | Danh sách người tham gia **MỚI** — thay thế toàn bộ list cũ (§4.6) | → `tm_sankasha_template_shosai` |

**Detail level** (`SankashaTemplateShosai`): **giống hệt create** — xem [create §2.2](../sankasha-template-create/detail_design.md#22-request-body-schema).

🆕 **DIFF — shosai KHÔNG mang ID cũ**: Vì strategy = **replace toàn bộ** (§4.6), client **không cần** gửi `sankashaTemplateShosaiId`. Mọi `sankashaTemplateShosaiId` client gửi lên đều bị **bỏ qua** — backend xoá hết shosai cũ và sinh ID mới cho từng row. (Tránh nhầm lẫn "merge by id".)

> **Không nhận từ body** (server tự set / không cho đổi): `sankashaTemplateId` (lấy từ path), `jugyoinId`, `hojinCode`, `deleteFlag`, `addDate`, `addUserid`, `updDate`, `updUserid`, mọi `sankashaTemplateShosaiId`.

### 2.3 Example Request (happy case)

Xem file [`request_examples.json`](./request_examples.json) — phần tử `happy_case`. Tóm tắt:

```json
{
  "sankashaTemplateName": "○○社用（改）",
  "sankaNinzu": 3,
  "memo": "メンバー差し替え",
  "hyojiJun": 100,
  "updateVersion": 1,
  "shosaiList": [
    { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 太郎", "hyojiJun": 1 },
    { "sankashaKubun": 2, "jishaSankashaJugyoinId": "TM00700001202401010900xxAB", "hyojiJun": 2 }
  ]
}
```

---

## 3. Response

### 3.1 Success — HTTP 200

🆕 **DIFF** — message `I002`:

```json
{
  "code": 0,
  "message": "更新が完了しました。",
  "type": "success"
}
```

> Body theo `ModelApiResponse` chuẩn (`ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I002"))`). Tham khảo [`response_examples.json`](./response_examples.json) → `success`.

### 3.2 Error responses

> ⚠️ **Căn theo convention THỰC TẾ dự án** (giống create §3.2): validation/duplicate → `BadRequestException` (**400**); role → `ForbiddenException` (**403**); không tồn tại / không thuộc owner → `NotFoundException` (**404**); system → `InternalServerErrorException` (**500**).

| HTTP | Exception | Message key | Khi nào | Ghi chú |
|---|---|---|---|---|
| 400 | `BadRequestException` | (error map từ `BeanUtil.getAllValidationMessageMap`) | Bean validation fail: `sankashaTemplateName` rỗng/quá 250; `shosaiList` rỗng; `sankashaKubun` null/ngoài {1,2}; 🆕 `updateVersion` null | field-level errors trong `error{}` |
| 400 | `BadRequestException` | `E005` (param: fieldName) | Thiếu field bắt buộc theo kubun (conditional, create §4.3) | Có thể gộp vào error map |
| 400 | `BadRequestException` | (msg `参加人数` range) ⚠️ key TBD | `sankaNinzu` > 999 (khi > 0) | xem create §9 TBD #C2 |
| 400 | `BadRequestException` | (msg max 99) ⚠️ key TBD | `count(kubun=1) > 99` HOẶC `count(kubun=2) > 99` | Đếm riêng từng kubun |
| 400 | `BadRequestException` | (msg invalid employee) ⚠️ key TBD | 🆕 **DIFF**: kubun=2 có `jishaSankashaJugyoinId` không tồn tại / `delete_flag=1` / role = `NO_RIGHT` — **bắt buộc chặn ở update** (final_spec §4.8) | §4.4 |
| 400 | `BadRequestException` | `E040` (param: name, fieldName) | 🆕 **DIFF**: Trùng tên template trong scope owner — **nhưng bỏ qua nếu trùng với chính row đang update** (§4.3) | 400, KHÔNG 409 |
| 404 | `NotFoundException` | `E041` (param: id, fieldName) | 🆕 **DIFF**: `id` không tồn tại, đã xoá (`delete_flag=1`), hoặc **không thuộc owner** (template của user khác) | Read owner-scoped trả null |
| 409 / 400 | `OptimisticLockException` → map | (msg conflict) ⚠️ key TBD | 🆕 **DIFF**: `updateVersion` client gửi ≠ version DB (record đã bị sửa bởi request khác) | xem §4.5 + §9 TBD #U2 |
| 403 | `ForbiddenException` | (`ResponseErrorType.FORBIDDEN`) | Role gọi API ∉ {DEPARTMENT_MANAGEMENT, SUPER_ADMIN} | Ném từ `RoleUtil.check(...)` |
| 401 | `UnAuthorizedException` | — | Token thiếu/không hợp lệ | Tầng security filter |
| 500 | `InternalServerErrorException` | (`ResponseErrorType.INTERNAL_SERVER_ERROR`) | Lỗi hệ thống / DB | Rollback transaction |

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal layer call order)

```
SankashaTemplateApiController.updateSankashaTemplate(id, SankashaTemplate)
  └─> SankashaTemplateApiDelegateImpl.updateSankashaTemplate(id, req)   [adapter/in/api/delegate]
        - BeanUtil.copyProperties(dto, req)  (header, gồm updateVersion)
        - dto.setSankashaTemplateId(id)   ★ lấy ID từ PATH, không từ body  (step 0)
        - map shosaiList thủ công → List<SankashaTemplateShosaiDto>  (bỏ qua mọi shosaiId client gửi)
        - gọi useCase
        └─> SankashaTemplateCrudUseCase.update(dto)                   [port/in]
              └─> SankashaTemplateService.update(dto)  @Transactional  [application/service]
                    1. RoleUtil.check(getLoginUserDto(),
                         Roles.DEPARTMENT_MANAGEMENT, Roles.SUPER_ADMIN)   → 403 nếu fail
                    2. ★ read owner-scoped: crud.read(hojinCode, id, loginJugyoinId, delete_flag=0)
                       → NotFoundException (E041/404) nếu null               ★ DIFF
                    3. validate(dto) — Bean Validation (header + updateVersion + từng shosai) → 400
                    4. validate business: count kubun=1 ≤ 99, count kubun=2 ≤ 99, kubun ∈ {1,2}
                    5. validate conditional theo kubun (create §4.3),
                       với kubun=2: kiểm tra employee hợp lệ (final_spec §4.8 — bắt buộc)  ★ DIFF
                    6. ★ checkUnique bỏ qua chính mình:
                       getByName(hojinCode, loginJugyoinId, name, delete_flag=0);
                       nếu found && found.id != id → E040/400                  ★ DIFF
                    7. ★ copy field header MỚI vào record đã đọc (existing):
                       existing.setSankashaTemplateName / sankaNinzu / memo / hyojiJun(default 100)
                       existing.setUpdateVersion(dto.updateVersion)  ← optimistic lock ★ DIFF
                       (KHÔNG đổi jugyoin_id, hojin_code, delete_flag, sankasha_template_id)
                    8. ★ REPLACE shosai (final_spec §4.6, §4.4):                ★ DIFF
                       a. crud.deleteShosaiByTemplateId(hojinCode, id)  ← xoá toàn bộ shosai cũ
                       b. cho từng shosai mới:
                          - setSankashaTemplateShosaiId(generateId(TableCode.TM066, hojinCode))
                          - setSankashaTemplateId(id)
                          - setHojinCode(super.getHojinCode())
                          - if hyojiJun == null → 1
                       c. crud.saveShosaiList(shosaiListMoi)
                    9. crud.save(existing)   ← UPDATE header (JPA @Version check) → conflict nếu version lệch
                    10. addLogDataOwnerId(getLoginJugyoinId())  (audit operation log)
                  ┌──────────────────────────────────────────────┐
                  │ upd_date / upd_userid set tự động qua          │
                  │ AuditingEntityListener khi flush UPDATE         │
                  │ (add_date / add_userid GIỮ NGUYÊN)              │
                  └──────────────────────────────────────────────┘
        - ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I002"))
        - return ApiUtil.responseEntity(body, request)
```

**Nhấn mạnh các điểm KHÁC create (dễ sai)**:
- **Step 0 (delegate)**: `sankashaTemplateId` lấy từ **path `{id}`**, KHÔNG từ body. Body có thể không chứa field này.
- **Step 2**: read **owner-scoped** trước khi làm gì khác → user không thấy/không sửa được template của người khác (kể cả role 5/6). Không tồn tại → **404**, KHÔNG 403.
- **Step 6**: unique check **bỏ qua chính row đang update** (`found.id != id`) — mirror `MeisaiTemplateService.validation()`.
- **Step 7**: copy field lên **record đã đọc từ DB** (pattern `blindData` của `MeisaiTemplateService`), set `updateVersion` từ body để JPA `@Version` so sánh. **KHÔNG** đổi `jugyoin_id` / `hojin_code` / `delete_flag` / `add_*`.
- **Step 8**: **xoá hết shosai cũ rồi insert lại** — không merge theo id. Toàn bộ trong **1 transaction** cùng update header.

### 4.2 Validation chi tiết

**Cấp field (Bean Validation)** — giống create, **thêm**:
- 🆕 `updateVersion`: `@NotNull`.

Phần còn lại (`sankashaTemplateName`, `sankaNinzu`, `hyojiJun`, `memo`, `shosaiList`, `sankashaKubun`) — **giống hệt create** (xem [create §4.2](../sankasha-template-create/detail_design.md#42-validation-chi-tiết)).

**Cấp business (Service layer)** — giống create:
- Đếm riêng theo kubun: `count(kubun==1) ≤ 99` **VÀ** `count(kubun==2) ≤ 99` (KHÔNG check tổng 198).
- `sankashaKubun` ∈ `{1, 2}`.
- Conditional theo kubun (create §4.3).
- Unique name (§4.3 dưới — **có khác biệt**).
- 🆕 **DIFF — employee validation bắt buộc** (§4.4 dưới + final_spec §4.8).

### 4.3 Unique check 🆕 DIFF — bỏ qua chính mình

Trước khi save, query owner-scoped (giống create):

```sql
SELECT * FROM keihi_com.tm_sankasha_template
WHERE hojin_code = :hojinCode
  AND jugyoin_id = :jugyoinId          -- từ super.getLoginJugyoinId()
  AND sankasha_template_name = :name
  AND delete_flag = 0
```

Xử lý kết quả:
- Không có row → OK (tên chưa dùng).
- Có row **VÀ** `row.sankashaTemplateId == :id` (path param) → OK — **đây chính là record đang update, tên không đổi hoặc trùng chính nó** (không báo lỗi).
- Có row **VÀ** `row.sankashaTemplateId != :id` → trùng với template khác của cùng user → `throw new BadRequestException(MessageUtil.getMessage("E040", name, fieldName))` (HTTP 400).

> Mirror đúng `MeisaiTemplateService.validation()`:
> ```java
> if (existing == null) return;
> if (StringUtils.hasText(dto.getId()) && existing.getId().equals(dto.getId())) return; // chính mình
> throw new BadRequestException(MessageUtil.getMessage("E040", name, fieldname));
> ```
> Scope unique theo **owner** (clarifications #6.18): user A và user B cùng `hojin_code` được phép trùng tên.

### 4.4 Employee validation (kubun=2) 🆕 DIFF — bắt buộc khi update

Theo **final_spec §4.8**: với template đã lưu, nếu một `自社参加者` (kubun=2) sau đó bị xoá (`delete_flag=1`) hoặc đổi role thành `NO_RIGHT`, dòng đó được hiển thị **invalid** ở màn Detail. **Khi update**, hệ thống **bắt buộc** chặn nếu còn dòng invalid — user phải chọn lại hoặc xoá dòng đó trước khi lưu.

→ Với **mỗi** shosai `kubun=2` trong `shosaiList` mới, kiểm tra `jishaSankashaJugyoinId` qua `JugyoinCrud` thoả **tất cả** (giống create §4.3):
- cùng `hojin_code` với user hiện tại,
- `delete_flag = 0`,
- **role ≠ `Roles.NO_RIGHT`** (dùng enum `jp.co.keihi.application.enums.Roles.NO_RIGHT`, KHÔNG hardcode `1`).

Nếu fail bất kỳ điều kiện nào → 400 (cùng nhóm conditional). Đây là điểm bắt buộc cho luồng update (khác create ở chỗ create chỉ ngăn nhập mới invalid; update phải ngăn cả dữ liệu invalid tồn dư từ trước).

### 4.5 Optimistic lock (updateVersion) 🆕 DIFF

- `tm_sankasha_template.update_version` map tới field `@Version` trên entity `TmSankashaTemplate`.
- Service đọc record hiện tại (step 2), sau đó `existing.setUpdateVersion(dto.getUpdateVersion())` (step 7) — ép version client gửi vào entity trước khi save.
- Khi flush UPDATE, Hibernate sinh `UPDATE ... WHERE sankasha_template_id = ? AND update_version = ?`. Nếu client giữ version cũ (record đã bị request khác sửa) → 0 row updated → `OptimisticLockException`.
- `OptimisticLockException` được map ở `CustomGlobalExceptionHandler`. ⚠️ **Cần verify** project map status nào (409 hay 400) + message key — xem §9 TBD #U2.

> Mirror `MeisaiTemplateService.blindData()`: `existenceDto.setUpdateVersion(dto.getUpdateVersion())` rồi `crud.save(existenceDto)`.

### 4.6 Save strategy — Replace toàn bộ shosai 🆕 DIFF (final_spec §4.4, §4.6)

```
1. UPDATE header tm_sankasha_template (giữ id / jugyoin_id / hojin_code / add_*; cập nhật field nghiệp vụ + update_version).
2. DELETE toàn bộ shosai cũ của sankasha_template_id (xem note hard vs soft delete dưới).
3. INSERT lại toàn bộ shosai mới (ID mới sinh từ TableCode.TM066, hyoji_jun default 1 nếu null).
```

🔎 **Hard delete vs soft delete shosai** — final_spec §4.4 cho phép cả hai; TBD #6 final_spec ghi "soft delete shosai có thể bỏ qua vì save = replace all".
- **Đề xuất**: **HARD DELETE** (physical `DELETE FROM ... WHERE sankasha_template_id = :id [AND hojin_code = :hojinCode]`) cho shosai cũ, vì:
  - shosai chỉ là **định nghĩa** của template (không phải dữ liệu giao dịch đã áp dụng — dữ liệu áp dụng nằm ở `tr_meisai_sankasha`, là bản copy riêng).
  - replace-all + soft delete sẽ làm bảng phình rất nhanh và mọi SELECT phải kèm `delete_flag=0`.
- Quyết định cuối ảnh hưởng tới việc shosai có cần cột `delete_flag` hay không → xem §9 TBD #U1 (Medium).

Thứ tự **DELETE trước, INSERT sau** trong cùng transaction; nếu insert shosai mới fail → rollback cả delete + update header (không mất dữ liệu cũ).

---

## 5. Database Operations

### 5.1 Bảng được update / delete / insert

| Bảng | Schema | Thao tác | Số rows | Note |
|---|---|---|---|---|
| `tm_sankasha_template` | `keihi_com` | UPDATE | 1 | Header. Giữ `jugyoin_id`, `hojin_code`, `add_*`; tăng `update_version` qua `@Version` |
| `tm_sankasha_template_shosai` | `keihi_com` | DELETE | M (cũ) | 🆕 Xoá toàn bộ shosai cũ của `sankasha_template_id` (hard delete — TBD #U1) |
| `tm_sankasha_template_shosai` | `keihi_com` | INSERT | N (mới) | N = `shosaiList.size()`. ID mới; mỗi row set `hojin_code = super.getHojinCode()` (multi-tenant — final_spec §5.2) |

### 5.2 Transaction
- Toàn bộ (read → update header → delete shosai cũ → insert shosai mới) trong **1 transaction** (`@Transactional` trên `update`).
- Rollback nếu bất kỳ bước nào fail (gồm cả `OptimisticLockException`).
- Isolation: mặc định của dự án.

### 5.3 ID Generation
- Header `sankasha_template_id`: **KHÔNG sinh mới** — giữ nguyên `id` từ path.
- 🆕 Shosai mới `sankasha_template_shosai_id`: sinh mới qua `SqlUtil.generateId(TableCode.TM066, super.getHojinCode())` cho **từng** row (vì replace-all). ⚠️ `TM066` cần thêm vào enum `TableCode` — xem create §9 TBD #C3.

### 5.4 Audit fields khi UPDATE

| Field | Value | Cơ chế |
|---|---|---|
| `add_date` | **giữ nguyên** | Không đụng (chỉ set lúc create) |
| `add_userid` | **giữ nguyên** | Không đụng |
| `upd_date` | now() | `@LastModifiedDate` (AuditingEntityListener) khi flush UPDATE |
| `upd_userid` | login user id | `@LastModifiedBy` |
| `update_version` | client version → JPA tự tăng sau update | `@Version` (set từ body trước save) |
| `delete_flag` | **giữ nguyên** (`0`) | Update không đổi |

> Shosai mới insert: `add_date/add_userid/upd_date/upd_userid` set tự động như create.

---

## 6. Class & File Structure (Hexagonal)

> **Dùng chung toàn bộ class với API create** — xem [create §6](../sankasha-template-create/detail_design.md#6-class--file-structure-hexagonal). API update **không tạo class mới**, chỉ **thêm method** vào các class đã có.

Các bổ sung cần thiết cho update:

| Layer | Class | Bổ sung |
|---|---|---|
| Delegate | `SankashaTemplateApiDelegateImpl` | method `updateSankashaTemplate(String id, SankashaTemplate req)` |
| Input port | `SankashaTemplateCrudUseCase` | `void update(SankashaTemplateDto dto)` (hoặc trả DTO tuỳ convention) |
| Service | `SankashaTemplateService` | `@Transactional public void update(@LogOperation SankashaTemplateDto dto)` |
| Output port | `SankashaTemplateCrud` | `SankashaTemplateDto read(hojinCode, id, jugyoinId, deleteFlag)`; `void deleteShosaiByTemplateId(hojinCode, templateId)`; `void saveShosaiList(List<...>)` (nếu chưa có từ create) |
| Adapter | `SankashaTemplateAdapter` | impl `read(owner-scoped)`, `deleteShosaiByTemplateId`, reuse `saveShosaiList` |
| Repository (header) | `TmSankashaTemplateRepository` | `findByHojinCodeAndIdAndJugyoinIdAndDeleteFlag(...)` |
| Repository (detail) | `TmSankashaTemplateShosaiRepository` | `deleteBySankashaTemplateId(hojinCode, templateId)` (hard delete) hoặc soft-delete update — theo TBD #U1 |

> Reference impl update (read owner-scoped + skip-self unique + set version + copy field): `MeisaiTemplateService.update()` / `.validation()` / `.blindData()`
> (`backend/src/main/java/jp/co/keihi/application/service/MeisaiTemplateService.java`).

---

## 7. OpenAPI Definition

> Schema `SankashaTemplate` / `SankashaTemplateShosai` **dùng chung với create** (đã định nghĩa ở [create §7](../sankasha-template-create/detail_design.md#7-openapi-definition)). 🆕 **DIFF**: thêm property `updateVersion` vào schema `SankashaTemplate` (header) để dùng cho update (create bỏ qua field này).

Thêm **path** vào `api_interface_generate_tool/specification/openapi.yml`:

```yaml
  /sankasha-template/{id}:
    put:
      tags:
        - sankasha-template
      parameters:
        - name: id
          in: path
          required: true
          description: Participant template ID
          schema:
            type: string
      requestBody:
        description: Update an existing participant template (replace all shosai)
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
          description: Invalid input / validation error / duplicate name / version conflict
        '403':
          description: Forbidden (role không hợp lệ)
        '404':
          description: Template không tồn tại / không thuộc owner
      operationId: updateSankashaTemplate
      summary: Update a participant template
      description: >
        Cập nhật template người tham gia (header + thay thế toàn bộ shosai).
        jugyoinId không đổi; updateVersion dùng cho optimistic lock.
```

🆕 Bổ sung property vào schema `SankashaTemplate` (nếu chưa có từ create):

```yaml
        updateVersion:
          type: integer
          format: int32
          description: Optimistic lock version (bắt buộc khi update)
          example: 1
```

---

## 8. Test Cases

### 8.1 Unit test (Service layer)

| # | Test case | Expected |
|---|---|---|
| 1 | Happy: update header + thay shosai (1 ext + 1 int) | Success, header updated, shosai cũ bị xoá hết, insert N mới, return **I002** |
| 2 | `id` không tồn tại | **404** (E041) |
| 3 | 🆕 `id` của template **user khác** (cùng hojin) | **404** (owner-scoped read trả null) |
| 4 | 🆕 `id` đã bị soft delete (`delete_flag=1`) | **404** |
| 5 | 🆕 `updateVersion` lệch version DB (record bị sửa song song) | Conflict (409/400 — TBD #U2), rollback |
| 6 | 🆕 `updateVersion` = null | 400 (`@NotNull`) |
| 7 | 🆕 Đổi tên thành tên **chưa dùng** | Success |
| 8 | 🆕 Giữ **nguyên tên cũ** (trùng chính row đang update) | Success (skip-self unique) |
| 9 | 🆕 Đổi tên thành tên **template KHÁC của chính user** | 400 (E040) |
| 10 | Đổi tên trùng template của **user khác** cùng hojin | Success (owner-scoped unique) |
| 11 | `sankaNinzu = 1000` | 400 (range) |
| 12 | `sankaNinzu = 0` / null | Success |
| 13 | `shosaiList` rỗng | 400 (`@NotEmpty`) |
| 14 | shosai kubun=1 thiếu `aitesakiKaishaName` | 400 (conditional) |
| 15 | shosai kubun=2 thiếu `jishaSankashaJugyoinId` | 400 (conditional) |
| 16 | 🆕 shosai kubun=2 trỏ employee `delete_flag=1` (invalid tồn dư §4.8) | 400 (invalid employee — bắt buộc chặn ở update) |
| 17 | 🆕 shosai kubun=2 trỏ employee role=`NO_RIGHT` | 400 (invalid employee) |
| 18 | 100 phần tử kubun=1 (vượt 99) | 400 (max external) |
| 19 | 100 phần tử kubun=2 (vượt 99) | 400 (max internal) |
| 20 | 99 ext + 99 int = 198 | Success (đúng max mỗi kubun) |
| 21 | Role gọi API = `REGISTRATION` (3) | 403 |
| 22 | 🆕 body gửi `jugyoinId` khác → verify owner KHÔNG đổi | DB giữ owner gốc |
| 23 | 🆕 body gửi `sankashaTemplateShosaiId` cũ → verify bị bỏ qua, sinh ID mới | Shosai có ID mới, không merge theo id |
| 24 | `hyojiJun` không truyền | Success, header=100, shosai=1 |

### 8.2 Integration test
- Full flow Controller → DB: PUT happy_case, verify HTTP 200 + I002; query DB thấy header updated, **đúng N shosai mới** (không còn shosai cũ).
- 🆕 Verify **replace**: template ban đầu có 5 shosai, update gửi 2 shosai → sau update chỉ còn 2 (3 cũ biến mất).
- 🆕 Verify **transaction rollback**: giả lập lỗi khi insert shosai mới thứ k → header + shosai cũ giữ nguyên (không mất).
- 🆕 Verify **optimistic lock**: 2 request update song song cùng `updateVersion` → 1 thành công, 1 conflict.
- 🆕 Verify **owner isolation**: user B update template của user A → 404.
- Verify **audit**: `upd_date/upd_userid` đổi, `add_date/add_userid` giữ nguyên.

---

## 9. Open Issues / TBD

> Chỉ liệt kê TBD trực tiếp ảnh hưởng API update. Các TBD chung với create (C1 error convention, C2 message key, C3 TableCode, C4 schema shosai, C5 model package) **vẫn áp dụng** — xem [create §9](../sankasha-template-create/detail_design.md#9-open-issues--tbd).

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| U1 | Shosai cũ xoá kiểu **hard** hay **soft** khi replace-all? | Đề xuất **hard delete** (`DELETE FROM ... WHERE sankasha_template_id`), vì shosai là định nghĩa template, không phải dữ liệu giao dịch. Quyết định ảnh hưởng việc shosai có cần cột `delete_flag` (liên quan create #C4) | **Medium** | final_spec §4.4, §4.6, §5.2, TBD #6 |
| U2 | `OptimisticLockException` được `CustomGlobalExceptionHandler` map sang HTTP status nào (409 vs 400) + message key | Verify handler hiện tại của dự án; mirror cách các API update khác (vd `MeisaiTemplateService`) trả conflict. Tạm coi là 400 nếu chưa có 409 | **Medium** | `CustomGlobalExceptionHandler`, `MeisaiTemplateService.update` |
| U3 | UseCase `update` trả `void` hay trả lại DTO đã update? | Theo pattern `MeisaiTemplateService.update` → `void` + delegate trả `ModelApiResponse` (I002). Nếu FE cần data mới → đổi sang trả DTO (Low) | **Low** | api-conventions.md §3, `MeisaiTemplateService` |
| U4 | Khi update có cần ghi `koshinRireki` (lịch sử thay đổi) như `MeisaiTemplateService` không? | `MeisaiTemplateService.update` có gọi `koshinRirekiUseCase.addKoshinRireki`. Template người tham gia **chưa có** yêu cầu này trong spec → tạm **không** ghi koshin rireki. Confirm với Lead | **Low** | `MeisaiTemplateService.update`, final_spec (không đề cập) |

**Severity legend**: High = ảnh hưởng schema/API contract; Medium = sửa handler/logic; Low = chỉnh constant/config/message.

> Không có TBD **High** → API update **sẵn sàng implement** sau khi chốt U1 (hard/soft delete shosai) và U2 (mapping optimistic lock), cùng các TBD chung với create (#C1, #C3).

---

## 10. References
- final_spec: `../../final_spec.md` (v1.2.1) — đặc biệt §4.4 (save strategy), §4.6 (replace shosai), §4.7 (ownership), §4.8 (invalid employee), §6 API #4
- clarifications: `../../clarifications.md` (v1.1.0)
- API create (pattern gốc): [`../sankasha-template-create/detail_design.md`](../sankasha-template-create/detail_design.md)
- DB design: `../../../db_tables_application_rules_meeting_expenses.xlsx`
- API convention: `.claude/rules/api-conventions.md`
- DB convention: `.claude/rules/database.md`
- Roles enum: `backend/src/main/java/jp/co/keihi/application/enums/Roles.java`
- **Reference impl update** (read owner-scoped + skip-self unique + optimistic lock + copy field): `backend/src/main/java/jp/co/keihi/application/service/MeisaiTemplateService.java` (`update`, `validation`, `blindData`)
- ID gen: `SqlUtil.generateId`; `TableCode` enum

---

## Version History

### [1.0.0] - 2026-06-02
- Initial detail design cho API update.
- Reuse pattern từ API create; expand chi tiết các điểm KHÁC: PUT + path param `{id}`, `updateVersion` (optimistic lock), read owner-scoped → 404, skip-self unique check, replace-all shosai (§4.6), employee validation bắt buộc (§4.8), success message `I002`.
- Verify pattern với `MeisaiTemplateService.update/validation/blindData` (read owner-scoped + skip-self unique + set version + copy field lên record đã đọc).
- Dựa trên final_spec v1.2.1 và clarifications v1.1.0.
- 4 điểm TBD riêng cho update (0 High, 2 Medium #U1/#U2, 2 Low #U3/#U4) + kế thừa TBD chung của create — xem section 9.
