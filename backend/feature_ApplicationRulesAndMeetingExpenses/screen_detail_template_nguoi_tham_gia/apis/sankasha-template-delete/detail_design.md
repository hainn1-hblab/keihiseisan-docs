---
version: 1.2.0
status: implemented
api_name: SankashaTemplateDelete
http_method: DELETE
endpoint: /api/v1/sankasha-template/{id}
last_updated: 2026-06-04
based_on_final_spec_version: 1.4.0
based_on_clarifications_version: 1.1.0
---

> 📘 **Detail design cho API delete (xoá 1 template) Sankasha Template.**
> - Đọc file này là đủ để implement endpoint này.
> - Cross-reference cấp màn hình: [`final_spec.md`](../../final_spec.md) — §4.5 (delete behavior).
> - API create (pattern gốc, dùng chung class): [`../sankasha-template-create/detail_design.md`](../sankasha-template-create/detail_design.md)
> - API update (cùng path `{id}`, cùng read owner-scoped): [`../sankasha-template-update/detail_design.md`](../sankasha-template-update/detail_design.md)
> - Lịch sử thay đổi: section cuối.
>
> 🔁 **Soft delete owner-scoped.** Điểm riêng (đánh dấu **🆕 DIFF**): read owner-scoped → 404, set `delete_flag=1` + optimistic lock, không đụng shosai.

# Detail Design — API Delete Sankasha Template

## 1. Tổng quan API

| Item | Value |
|---|---|
| **API name** | SankashaTemplateDelete |
| **HTTP method** | DELETE |
| **Endpoint** | `/api/v1/sankasha-template/{id}` |
| **Mục đích** | Xoá (soft) 1 template người tham gia |
| **Caller** | Màn 参加者テンプレート一覧, nút `削除` per row (sau confirm dialog — final_spec §2.3, §4.5). |
| **Role được phép gọi** | `Roles.DEPARTMENT_MANAGEMENT` (5) + `Roles.SUPER_ADMIN` (6) — final_spec §4.7 entry point B. |
| **Ownership** | 🆕 **DIFF**: chỉ xoá được template do **chính user** tạo. Read kèm `jugyoin_id = super.getLoginJugyoinId()`; không thuộc owner → **404** (final_spec §4.7). |
| **Kiểu xoá** | **Soft delete**: `delete_flag = 1`, `update_version` theo optimistic lock (final_spec §4.5). |
| **Success message code** | `I003` (xoá 1 record) |

---

## 2. Request

### 2.1 HTTP Request

```
DELETE /api/v1/sankasha-template/{id} HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT access token (Keycloak, bearer-only)>
```

🆕 **DIFF — path param + updateVersion**:

| Param | Type | Required | Mô tả |
|---|---|---|---|
| `id` | string (path) | ✅ | `sankasha_template_id` cần xoá (29 ký tự). Nguồn ID chính. |
| `updateVersion` | integer | ✅ | **Optimistic lock** — version client đang giữ. Truyền qua **request body** (`SankashaTemplate.updateVersion`) hoặc query param. Phải khớp version DB hiện tại. |

### 2.2 Request Body schema

Dùng lại API model `SankashaTemplate` (chỉ cần `updateVersion`; các field khác bỏ qua). `id` lấy từ **path**.

```json
{ "updateVersion": 1 }
```

> ⚠️ Body **KHÔNG** validate `@NotEmpty shosaiList` cho delete — service chỉ validate `sankashaTemplateId` + `updateVersion` (group `GroupUpdate`, xem §4.2).

### 2.3 Example Request

Xem [`request_examples.json`](./request_examples.json).

---

## 3. Response

### 3.1 Success — HTTP 200

```json
{
  "code": 0,
  "message": "削除が完了しました。",
  "type": "success"
}
```

> Body `ModelApiResponse` (`ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I003"))`).

### 3.2 Error responses

| HTTP | Exception | Message key | Khi nào | Ghi chú |
|---|---|---|---|---|
| 400 | `BadRequestException` | `E005` | `updateVersion` null (required — `GroupUpdate`) | field-level |
| 404 | `NotFoundException` | `E041` (param: id, fieldName) | 🆕 `id` không tồn tại, đã xoá (`delete_flag=1`), hoặc **không thuộc owner** | Read owner-scoped trả null |
| 400 | `BadRequestException` | 🆕 `E180` | 🆕 sankasha đang được dùng bởi ≥1 `tm_meisai_template` (`delete_flag=0`) → BLOCK | param {0} = tên template; ⚠️ E158 đã dùng → E180 |
| 409 / 400 | `OptimisticLockException` → map | (msg conflict) ⚠️ key TBD | `updateVersion` lệch version DB | xem §9 TBD #D2 (chung với update #U2) |
| 403 | `ForbiddenException` | (`ResponseErrorType.FORBIDDEN`) | Role ∉ {DEPARTMENT_MANAGEMENT, SUPER_ADMIN} | `RoleUtil.check(...)` |
| 401 | `UnAuthorizedException` | — | Token thiếu/không hợp lệ | security filter |
| 500 | `InternalServerErrorException` | (`ResponseErrorType.INTERNAL_SERVER_ERROR`) | Lỗi hệ thống / DB | — |

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal layer call order)

```
SankashaTemplateApiController.deleteSankashaTemplate(id, SankashaTemplate)
  └─> SankashaTemplateApiDelegateImpl.deleteSankashaTemplate(id, req)   [adapter/in/api/delegate]
        - dto.setSankashaTemplateId(id)   ★ từ PATH
        - dto.setUpdateVersion(req.getUpdateVersion())
        - useCase.delete(dto)  (hoặc delete(id, updateVersion))
        └─> SankashaTemplateCrudUseCase.delete(dto)                    [port/in]
              └─> SankashaTemplateService.delete(dto)  @Transactional   [application/service]
                    1. RoleUtil.check(getLoginUserDto(),
                         Roles.DEPARTMENT_MANAGEMENT, Roles.SUPER_ADMIN)   → 403
                    2. validate(dto, GroupUpdate.class)  (id + updateVersion @NotNull) → 400
                    3. ★ read owner-scoped:
                       crud.read(hojinCode, id, loginJugyoinId, delete_flag=0)
                       → NotFoundException (E041/404) nếu null               ★ DIFF
                    3.5 🆕 PRE-CHECK USAGE (BLOCK delete khi đang dùng — final_spec §4.9):
                       count = meisaiTemplateCrud.countBySankashaTemplateIdAndDeleteFlag(id, 0)
                       if (count > 0):
                         throw new BadRequestException(
                             MessageUtil.getMessage("E180", existing.getSankashaTemplateName()))
                    4. existing.setUpdateVersion(dto.updateVersion)  ← optimistic lock
                       existing.setDeleteFlag(DeleteFlag.DELETED)     (1)
                    5. crud.save(existing)   ← UPDATE delete_flag (JPA @Version check)
                    6. addLogDataOwnerId(getLoginJugyoinId())
        - ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I003"))
        - return ApiUtil.responseEntity(body, request)
```

> Mirror `MeisaiTemplateService.delete()` (read owner-scoped → set updateVersion → set delete_flag=1 → save).

### 4.2 Validation
- `validate(dto, GroupUpdate.class)`: `sankashaTemplateId` + `updateVersion` `@NotNull` (group `GroupUpdate`).
- Không validate shosai (delete không cần body chi tiết).

### 4.3 Owner-scoped read (§4.7)
Giống update §4.2 — `read(hojinCode, id, loginJugyoinId, delete_flag=0)` → null thì **404** (E041). Reuse method `SankashaTemplateCrud.read` đã thêm ở API update.

### 4.4 Xử lý shosai khi xoá header
- 🆕 **Chỉ soft delete header** (`delete_flag=1`). **KHÔNG** đụng tới shosai (final_spec §4.5 chỉ nêu xoá template; search lọc header `delete_flag=0` nên template đã xoá không xuất hiện bất kể shosai).
- Mirror `MeisaiTemplateService.delete` (chỉ set header `delete_flag=1`). Xem §9 TBD #D1.

---

## 5. Database Operations

| Bảng | Schema | Thao tác | Note |
|---|---|---|---|
| `tm_sankasha_template` | `keihi_com` | UPDATE (1) | `delete_flag = 1`, `update_version` (@Version). Giữ `jugyoin_id`/`hojin_code`/`add_*` |
| `tm_sankasha_template_shosai` | `keihi_com` | — | Không đụng (xem §4.4, #D1) |
| 🆕 `tm_meisai_template` | `keihi_com` | **READ (count)** | Pre-check usage trước delete: `COUNT WHERE sankasha_template_id=? AND delete_flag=0` (final_spec §4.9) |

- `@Transactional` trên `delete`. Rollback nếu `OptimisticLockException`.
- Không sinh ID. Audit `upd_date`/`upd_userid` tự động.

---

## 6. Class & File Structure (Hexagonal)

> **Dùng chung class** với create/update — chỉ thêm method.

| Layer | Class | Bổ sung |
|---|---|---|
| Delegate | `SankashaTemplateApiDelegateImpl` | `deleteSankashaTemplate(String id, SankashaTemplate req)` |
| Input port | `SankashaTemplateCrudUseCase` | `void delete(SankashaTemplateDto dto)` |
| Service | `SankashaTemplateService` | `@Transactional public void delete(...)` |
| Output port | `SankashaTemplateCrud` | reuse `read(...)` + `save(...)` (đã có từ update) |
| Adapter | `SankashaTemplateAdapter` | reuse `read` + `save` (không thêm mới) |
| Repository | `TmSankashaTemplateRepository` | reuse `findByHojinCodeAndSankashaTemplateIdAndJugyoinIdAndDeleteFlag` (đã có từ update) |

> ✅ Hầu hết hạ tầng đã sẵn từ API update — delete chỉ thêm 1 method service + 1 delegate + 1 endpoint.

> 🆕 **Dependency mới (cross-screen BLOCK — final_spec §4.9, requires code update)**:
> | Layer | Class | Bổ sung |
> |---|---|---|
> | Service | `SankashaTemplateService` | Inject `MeisaiTemplateCrud`; thêm pre-check trong `deleteOne` (count > 0 → throw `E180`) |
> | Output port | `MeisaiTemplateCrud` | 🆕 `int countBySankashaTemplateIdAndDeleteFlag(String sankashaTemplateId, Integer deleteFlag)` |
> | Adapter | `MeisaiTemplateAdapter` | 🆕 impl method trên qua repository |
> | Repository | `TmMeisaiTemplateRepository` | 🆕 `countBySankashaTemplateIdAndDeleteFlag(...)` (Spring Data derived query) |
> | Bean config | `BeanConfiguration.sankashaTemplate*` | ✏️ thêm `MeisaiTemplateCrud` vào constructor `SankashaTemplateService` |
>
> Phụ thuộc: entity `TmMeisaiTemplate` phải đã có field `sankashaTemplateId` (phase meisai-template extend).

---

## 7. OpenAPI Definition

Thêm `delete` vào path `/sankasha-template/{id}` (gộp chung với `put` của update):

```yaml
  /sankasha-template/{id}:
    delete:
      tags:
        - sankasha-template
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      requestBody:
        description: updateVersion for optimistic lock
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/SankashaTemplate'
        required: false
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ModelApiResponse'
          description: Successful operation
        '404':
          description: Template không tồn tại / không thuộc owner
      operationId: deleteSankashaTemplate
      summary: Delete a participant template (soft)
      description: 1件の参加者テンプレートを論理削除する（owner-scoped、楽観的ロック）。
    # put: (xem API update)
```

---

## 8. Test Cases

### 8.1 Unit test (Service layer)

| # | Test case | Expected |
|---|---|---|
| 1 | Happy: xoá template của mình | 200 I003, `delete_flag=1` trong DB |
| 2 | `id` không tồn tại | 404 (E041) |
| 3 | 🆕 `id` của template **user khác** | 404 (owner-scoped) |
| 4 | `id` đã bị xoá (`delete_flag=1`) | 404 |
| 5 | `updateVersion` = null | 400 (`@NotNull` GroupUpdate) |
| 6 | `updateVersion` lệch version DB | conflict (409/400 — #D2), rollback |
| 7 | Role gọi API = `REGISTRATION` (3) | 403 |
| 8 | Sau xoá: search list không còn template đó | Không xuất hiện |
| 9 | 🆕 Xoá sankasha **không** có meisai_template tham chiếu | 200 I003 (success) |
| 10 | 🆕 Xoá sankasha có 1 meisai (`delete_flag=0`) tham chiếu | 400 **E180**, không xoá |
| 11 | 🆕 Xoá sankasha có 3 meisai (2 `delete_flag=0` + 1 `delete_flag=1`) tham chiếu | 400 **E180** (chỉ count active) |
| 12 | 🆕 Xoá sankasha có meisai nhưng **tất cả** `delete_flag=1` | 200 I003 (không block) |

### 8.2 Integration test
- DELETE happy → 200 I003; query DB `delete_flag=1`.
- 🆕 Owner isolation: user B xoá template user A → 404.
- 🆕 Optimistic lock: 2 request xoá/sửa song song → 1 thành công, 1 conflict.

---

## 9. Open Issues / TBD

> TBD chung create (#C1 error convention, #C2 message key, #C5 model package) vẫn áp dụng.

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| D1 | Khi soft delete header, có cần xoá/đánh dấu shosai không? | **Không** đụng shosai (chỉ header `delete_flag=1`). Search lọc header nên đủ. Mirror `MeisaiTemplateService.delete`. | **Low** | final_spec §4.5; `MeisaiTemplateService.delete` |
| D2 | `OptimisticLockException` map HTTP status nào (409 vs 400) + message key | Theo `CustomGlobalExceptionHandler` hiện có (chung với update #U2). Verify khi test. | **Medium** | `CustomGlobalExceptionHandler` |
| D3 | `updateVersion` truyền qua body (`SankashaTemplate`) hay query param? | **Body** (`SankashaTemplate.updateVersion`) — nhất quán DELETE-with-body pattern dự án (`MeisaiTemplate`). | **Low** | final_spec §6 #5; `MeisaiTemplateApi` |
| D4 | 🆕 Message key cho BLOCK delete | **`E180`** (⚠️ E158 đã dùng — `messages.properties:188`). Cần ADD `E180={0}は明細テンプレートで使用されているため、削除できません。` vào `messages.properties` + `messages_ja.properties` khi implement. | **Low** | final_spec §4.9; clarification meisai #6.6.Q1 |

**Severity legend**: High = schema/contract; Medium = handler/logic; Low = constant/config.

> Không có TBD **High** → API delete **sẵn sàng implement** (hạ tầng read/save đã có từ update).

---

## 10. References
- final_spec: `../../final_spec.md` (v1.2.1) — §2.3, §4.5 (delete behavior), §4.7 (ownership), §6 API #5
- API update (read owner-scoped + optimistic lock): [`../sankasha-template-update/detail_design.md`](../sankasha-template-update/detail_design.md)
- API bulk-delete (cùng pattern, nhiều record): [`../sankasha-template-bulk-delete/detail_design.md`](../sankasha-template-bulk-delete/detail_design.md)
- **Reference impl**: `backend/src/main/java/jp/co/keihi/application/service/MeisaiTemplateService.java` (`delete`)
- DeleteFlag enum: `jp.co.keihi.application.enums.DeleteFlag` (`DELETED = 1`)
- 🆕 Cross-screen BLOCK (final_spec §4.9): [`../../final_spec.md` §4.9](../../final_spec.md) + [`screen_template_meisai/final_spec.md` §4.4 / TBD-3 RESOLVED](../../../screen_template_meisai/final_spec.md)

---

## Version History

### [1.2.0] - 2026-06-04
- **🆕 Cross-screen BLOCK delete** (final_spec §4.9, clarification meisai #6.6 revise 2026-06-04):
  - §4.1: thêm step **3.5 PRE-CHECK USAGE** — count meisai (`delete_flag=0`) tham chiếu, > 0 → throw **E180** kèm tên.
  - §3.2: thêm error 400 E180. §5: thêm READ count `tm_meisai_template`. §8: thêm 4 test case (#9–#12).
  - §6: dependency mới — inject `MeisaiTemplateCrud`, thêm `countBySankashaTemplateIdAndDeleteFlag`. #D4: message key E180.
- ⚠️ **Requires code update**: phần delete cũ đã `implemented`; pre-check BLOCK là code MỚI cần thêm (Service + MeisaiTemplateCrud/Adapter/Repository + message E180). Status giữ `implemented` cho phần cơ bản, delta pre-check pending code.
- Minor bump (thêm business rule cross-screen).

### [1.1.0] - 2026-06-03
- **ĐÃ IMPLEMENT** (BUILD SUCCESS), status → `implemented`.
- Logic xoá refactor thành private `deleteOne(dto, hojinCode, loginJugyoinId)` dùng chung với bulk-delete.
- #D1 confirmed: chỉ soft delete header (`delete_flag=1`), không đụng shosai. Reuse `read`/`save`. Message I003.

### [1.0.0] - 2026-06-03
- Initial detail design cho API delete (soft delete 1 template).
- Reuse hạ tầng read owner-scoped + save (@Version) từ API update; chỉ thêm method `delete` service + delegate + endpoint.
- Verify pattern với `MeisaiTemplateService.delete` (read owner-scoped → set updateVersion → delete_flag=1 → save).
- Success message `I003`.
- 3 TBD (0 High, 1 Medium #D2 optimistic lock mapping, 2 Low #D1/#D3) + kế thừa TBD chung create.
