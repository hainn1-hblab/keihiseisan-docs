---
version: 1.1.0
status: implemented
api_name: SankashaTemplateBulkDelete
http_method: DELETE
endpoint: /api/v1/sankasha-template
last_updated: 2026-06-03
based_on_final_spec_version: 1.2.1
based_on_clarifications_version: 1.1.0
---

> 📘 **Detail design cho API bulk-delete (xoá nhiều template) Sankasha Template.**
> - Đọc file này là đủ để implement endpoint này.
> - Cross-reference cấp màn hình: [`final_spec.md`](../../final_spec.md) — §2.3, §4.5 (bulk delete).
> - API delete (1 record, dùng chung logic xoá): [`../sankasha-template-delete/detail_design.md`](../sankasha-template-delete/detail_design.md)
> - Lịch sử thay đổi: section cuối.
>
> 🔁 **Bulk soft delete owner-scoped.** Lặp logic của delete đơn cho từng phần tử, trong **1 transaction**.

# Detail Design — API Bulk Delete Sankasha Template

## 1. Tổng quan API

| Item | Value |
|---|---|
| **API name** | SankashaTemplateBulkDelete |
| **HTTP method** | DELETE |
| **Endpoint** | `/api/v1/sankasha-template` |
| **Mục đích** | Xoá (soft) nhiều template người tham gia cùng lúc |
| **Caller** | Màn 参加者テンプレート一覧, nút `選択した参加テンプレートを削除` (sau confirm dialog — final_spec §2.3, §4.5). Nút disable khi không tick row nào. |
| **Role được phép gọi** | `Roles.DEPARTMENT_MANAGEMENT` (5) + `Roles.SUPER_ADMIN` (6) — final_spec §4.7 entry point B. |
| **Ownership** | 🆕 **DIFF**: chỉ xoá được template do **chính user** tạo. Mỗi phần tử read owner-scoped; không thuộc owner → **404** (final_spec §4.7). |
| **Kiểu xoá** | **Soft delete** từng record: `delete_flag = 1` + optimistic lock. **1 transaction** (all-or-nothing). |
| **Success message code** | `I006` (xoá nhiều record) |

---

## 2. Request

### 2.1 HTTP Request

```
DELETE /api/v1/sankasha-template HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT access token (Keycloak, bearer-only)>
```

### 2.2 Request Body schema

🆕 **DIFF — list các phần tử cần xoá** (mỗi phần tử = `id` + `updateVersion`):

```json
[
  { "sankashaTemplateId": "TM06500001202601010900xxAB", "updateVersion": 1 },
  { "sankashaTemplateId": "TM06500001202601010900xxCD", "updateVersion": 2 }
]
```

| Field (mỗi phần tử) | Type | Required | Mô tả |
|---|---|---|---|
| `sankashaTemplateId` | string | ✅ | ID template cần xoá |
| `updateVersion` | integer | ✅ | Optimistic lock của record đó |

> **Model**: dùng lại `SankashaTemplate` (đã có `sankashaTemplateId` + `updateVersion`) — list `List<SankashaTemplate>`, mirror `MeisaiTemplate` (`deleteListMeisaiTemplate(List<MeisaiTemplate>)`). Chỉ `sankashaTemplateId` + `updateVersion` được dùng; field khác bỏ qua (xem #BD1).
> List **không rỗng** (FE đã disable nút khi 0 tick) — backend phòng thủ: list rỗng/null → 400 hoặc trả I006 no-op (xem #BD2).

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

> Body `ModelApiResponse` (`ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I006"))`).

### 3.2 Error responses

| HTTP | Exception | Message key | Khi nào | Ghi chú |
|---|---|---|---|---|
| 400 | `BadRequestException` | `E005` | Phần tử thiếu `sankashaTemplateId` / `updateVersion` | per-element validate (GroupUpdate) |
| 404 | `NotFoundException` | `E041` (param: id, fieldName) | 🆕 Một phần tử có `id` không tồn tại / đã xoá / **không thuộc owner** → **rollback toàn bộ** | Read owner-scoped trả null |
| 409 / 400 | `OptimisticLockException` → map | (msg conflict) ⚠️ key TBD | `updateVersion` của 1 phần tử lệch version DB → **rollback toàn bộ** | chung #D2/#U2 |
| 403 | `ForbiddenException` | (`ResponseErrorType.FORBIDDEN`) | Role ∉ {DEPARTMENT_MANAGEMENT, SUPER_ADMIN} | `RoleUtil.check(...)` |
| 401 | `UnAuthorizedException` | — | Token thiếu/không hợp lệ | security filter |
| 500 | `InternalServerErrorException` | (`ResponseErrorType.INTERNAL_SERVER_ERROR`) | Lỗi hệ thống / DB | — |

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal layer call order)

```
SankashaTemplateApiController.deleteListSankashaTemplate(List<SankashaTemplate>)
  └─> SankashaTemplateApiDelegateImpl.deleteListSankashaTemplate(list)  [adapter/in/api/delegate]
        - List<SankashaTemplateDto> dtoList = BeanUtil.convertList(list, SankashaTemplateDto.class)
        - useCase.deleteList(dtoList)
        └─> SankashaTemplateCrudUseCase.deleteList(dtoList)             [port/in]
              └─> SankashaTemplateService.deleteList(dtoList) @Transactional  [application/service]
                    1. RoleUtil.check(getLoginUserDto(),
                         Roles.DEPARTMENT_MANAGEMENT, Roles.SUPER_ADMIN)   → 403
                    2. (phòng thủ) list null/empty → xử lý theo #BD2
                    3. for each dto → deleteOne(dto):
                         a. validate(dto, GroupUpdate.class)  (id + updateVersion) → 400
                         b. read owner-scoped (hojinCode, id, loginJugyoinId, delete_flag=0)
                            → NotFoundException (E041/404) nếu null
                         c. existing.setUpdateVersion(dto.updateVersion)
                            existing.setDeleteFlag(DeleteFlag.DELETED)  (1)
                         d. crud.save(existing)   (JPA @Version check)
                    4. addLogDataOwnerId(getLoginJugyoinId())
        - ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I006"))
        - return ApiUtil.responseEntity(body, request)
```

> Mirror `MeisaiTemplateService.deleteList` (loop gọi `delete` từng phần tử). **Tái sử dụng** logic xoá đơn của [API delete §4.1](../sankasha-template-delete/detail_design.md#41-sequence-hexagonal-layer-call-order) (có thể refactor thành private `deleteOne(dto)` dùng chung cho cả delete và deleteList).

### 4.2 Transaction (all-or-nothing) 🆕 DIFF
- Toàn bộ vòng lặp trong **1 `@Transactional`**.
- Nếu **bất kỳ** phần tử nào fail (404 / conflict / validation) → **rollback toàn bộ**, không xoá phần tử nào.
- Lý do: bulk action mong đợi atomic; tránh trạng thái "xoá được 3/5".

### 4.3 Owner-scoped & soft delete
- Giống delete đơn: mỗi phần tử read owner-scoped → set `delete_flag=1` + `update_version`.
- Không đụng shosai (xem delete §4.4, #D1).

---

## 5. Database Operations

| Bảng | Schema | Thao tác | Note |
|---|---|---|---|
| `tm_sankasha_template` | `keihi_com` | UPDATE (N) | Mỗi record: `delete_flag=1`, `update_version` (@Version). Owner-scoped |
| `tm_sankasha_template_shosai` | `keihi_com` | — | Không đụng |

- `@Transactional` trên `deleteList`. Rollback toàn bộ nếu 1 phần tử fail.

---

## 6. Class & File Structure (Hexagonal)

| Layer | Class | Bổ sung |
|---|---|---|
| Delegate | `SankashaTemplateApiDelegateImpl` | `deleteListSankashaTemplate(List<SankashaTemplate> list)` |
| Input port | `SankashaTemplateCrudUseCase` | `void deleteList(List<SankashaTemplateDto> dtoList)` |
| Service | `SankashaTemplateService` | `@Transactional public void deleteList(...)` + reuse private `deleteOne(dto)` (refactor chung với delete đơn) |
| Output port / Adapter / Repository | — | reuse `read` + `save` (đã có từ update) |

> ✅ Không thêm hạ tầng DB mới — chỉ thêm service method + delegate + endpoint. Nên refactor logic xoá 1 record thành private `deleteOne(SankashaTemplateDto)` để cả `delete` và `deleteList` dùng chung.

---

## 7. OpenAPI Definition

Thêm `delete` vào path `/sankasha-template` (gộp chung với `post` của create):

```yaml
  /sankasha-template:
    post:   # (xem API create)
    delete:
      tags:
        - sankasha-template
      requestBody:
        description: List of templates to delete (id + updateVersion)
        content:
          application/json:
            schema:
              type: array
              items:
                $ref: '#/components/schemas/SankashaTemplate'
        required: true
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ModelApiResponse'
          description: Successful operation
        '404':
          description: Một template không tồn tại / không thuộc owner
      operationId: deleteListSankashaTemplate
      summary: Bulk delete participant templates (soft)
      description: 選択した参加者テンプレートを一括論理削除する（owner-scoped、1トランザクション）。
```

---

## 8. Test Cases

### 8.1 Unit test (Service layer)

| # | Test case | Expected |
|---|---|---|
| 1 | Happy: xoá 3 template của mình (version đúng) | 200 I006, cả 3 `delete_flag=1` |
| 2 | List 1 phần tử | 200 I006 (xoá 1) |
| 3 | 🆕 1 trong N phần tử `id` không tồn tại | 404, **rollback toàn bộ** (không xoá phần tử nào) |
| 4 | 🆕 1 phần tử thuộc **user khác** | 404, rollback toàn bộ |
| 5 | 🆕 1 phần tử `updateVersion` lệch | conflict (409/400), rollback toàn bộ |
| 6 | Phần tử thiếu `updateVersion` | 400 (E005), rollback |
| 7 | List rỗng `[]` / null | theo #BD2 (tạm 400 hoặc no-op I006) |
| 8 | Role gọi API = `REGISTRATION` (3) | 403 |
| 9 | Sau xoá: search list không còn các template đó | Không xuất hiện |

### 8.2 Integration test
- DELETE bulk happy (3 id) → 200 I006; query DB cả 3 `delete_flag=1`.
- 🆕 Atomic rollback: list gồm 2 hợp lệ + 1 sai version → 0 record bị xoá.
- 🆕 Owner isolation: list gồm template user khác → 404, rollback.

---

## 9. Open Issues / TBD

> TBD chung create (#C1, #C2, #C5) vẫn áp dụng. #D2 (optimistic lock mapping) dùng chung với delete đơn.

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| BD1 | Model request: reuse `SankashaTemplate` hay tạo model nhẹ riêng (`{id, updateVersion}`)? | **Reuse `List<SankashaTemplate>`** — mirror `MeisaiTemplate` (`deleteListMeisaiTemplate`). Chỉ dùng `sankashaTemplateId` + `updateVersion`. | **Low** | `MeisaiTemplateApi`, final_spec §6 #6 |
| BD2 | List rỗng / null xử lý thế nào? | FE đã disable nút khi 0 tick. Backend phòng thủ: tạm coi list rỗng → **no-op trả I006** (hoặc 400). Chốt với FE/Lead. | **Low** | final_spec §2.3 |
| BD3 | Bulk fail 1 phần tử → rollback toàn bộ hay best-effort (xoá được phần nào hay phần đó)? | **Rollback toàn bộ** (atomic, `@Transactional`). An toàn & dễ hiểu cho user. | **Medium** | final_spec §4.5 (không nêu rõ) |
| D2 | `OptimisticLockException` map HTTP status nào | Chung với delete #D2 / update #U2. Verify `CustomGlobalExceptionHandler`. | **Medium** | `CustomGlobalExceptionHandler` |

**Severity legend**: High = schema/contract; Medium = handler/logic; Low = constant/config.

> Không có TBD **High** → API bulk-delete **sẵn sàng implement**. Cần xác nhận #BD3 (atomic vs best-effort) với Lead trước UAT — tôi mặc định **atomic**.

---

## 10. References
- final_spec: `../../final_spec.md` (v1.2.1) — §2.3 (action buttons), §4.5 (bulk delete), §4.7 (ownership), §6 API #6
- API delete (1 record): [`../sankasha-template-delete/detail_design.md`](../sankasha-template-delete/detail_design.md)
- **Reference impl**: `backend/src/main/java/jp/co/keihi/application/service/MeisaiTemplateService.java` (`deleteList` → loop `delete`)
- `MeisaiTemplateApi.deleteListMeisaiTemplate` (DELETE với body `List<...>`)
- DeleteFlag enum: `jp.co.keihi.application.enums.DeleteFlag` (`DELETED = 1`)

---

## Version History

### [1.1.0] - 2026-06-03
- **ĐÃ IMPLEMENT** (BUILD SUCCESS), status → `implemented`.
- Quyết định chốt khi implement: **#BD3 = atomic rollback** (`@Transactional`, lặp `deleteOne`); **#BD1 = reuse `List<SankashaTemplate>`**; **#BD2 = list rỗng/null → no-op** (return, không xoá). Message I006.
- Reuse private `deleteOne` dùng chung với delete đơn; reuse `read`/`save`.

### [1.0.0] - 2026-06-03
- Initial detail design cho API bulk-delete (soft delete nhiều template).
- Lặp logic xoá đơn (reuse `deleteOne`) trong 1 `@Transactional` (atomic rollback).
- Reuse hạ tầng read owner-scoped + save từ update; không thêm DB layer mới.
- Verify pattern với `MeisaiTemplateService.deleteList` + `MeisaiTemplateApi.deleteListMeisaiTemplate`.
- Success message `I006`.
- 4 TBD (0 High, 2 Medium #BD3/#D2, 2 Low #BD1/#BD2) + kế thừa TBD chung create.
