---
version: 1.0.0
status: draft
last_updated: 2026-06-10
api_name: searchShinseiForm + viewListShinseiForm
http_method: POST
endpoint: /api/v1/shinsei-form/search (search) ・ /api/v1/shinsei-form/view-list (viewList)
based_on_final_spec_version: 1.0.0
mode: EXTEND
based_on_current_analysis_version: 1.0.0
---

> 📘 **Detail design cho 2 API `searchShinseiForm` + `viewListShinseiForm` — EXTEND phase.**
> - Gộp 1 folder vì **cùng gọi `ShinseiFormService.search()`**; chỉ khác **role được phép call**.
> - API ĐÃ TỒN TẠI. File này CHỈ mô tả phần **THÊM / ĐỔI**.
> - Baseline: [`current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.5 (search flow), §6 (repository).
> - Cross-reference cấp màn: [`final_spec.md`](../../final_spec.md) (v1.0.0) §2.3, §4.3, §8.
> - Ký hiệu: 🆕 NEW · ✏️ MODIFIED · ↔️ UNCHANGED.

# Detail Design — searchShinseiForm / viewListShinseiForm (申請フォーム検索・利用可能一覧)

## 1. Tổng quan API

| Item | searchShinseiForm | viewListShinseiForm |
|---|---|---|
| HTTP method | POST | POST |
| Endpoint | `/api/v1/shinsei-form/search` | `/api/v1/shinsei-form/view-list` |
| Mục đích | Tìm申請フォーム ở màn quản lý master | Lấy danh sách申請フォーム **người nộp được phép dùng** để tạo申請 |
| Caller | Màn 申請フォーム一覧 (マスタ設定) | Màn tạo申請 (経費申請) |
| Role được phép | `SUPER_ADMIN`(6), `DEPARTMENT_MANAGEMENT`(5) — ↔️ | `READ`,`REGISTRATION`,`APPROVED`,`DEPARTMENT_MANAGEMENT`,`SUPER_ADMIN` — ↔️ |
| Service method | `searchShinseiForm()` → `search()` | `viewListShinseiForm()` → `search()` |
| Mode | EXTEND | EXTEND |

**Scope thay đổi (EXTEND)** — áp cho cả 2 (vì share `search()`):
- 🆕 Thêm param `jugyoinId` vào request → khi có, BE lọc chỉ trả các form mà nhân viên đó **được phép dùng** theo luật nhóm 5/6/7 (busho / yakushoku / jugyoin), ghép **OR**.
- ↔️ Các filter hiện có (`formRiyo`, `shinseiFormName`, `shinseiFormCode`, `shinseiTitle`, `workflowId`, scope `bushokaisoPtnId`, nhánh `isSearchFollowRole`/super-admin), paging, sort `hyojiJun asc` — **giữ nguyên**.
- ↔️ Role check 2 method giữ nguyên (chỉ khác nhau như bảng trên).

---

## 2. Request

### 2.1 HTTP Request
```
POST /api/v1/shinsei-form/search   (hoặc /view-list) HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT>
```

### 2.2 Request Body schema (`ShinseiFormSearchParameter`)

#### 2.2.1 ↔️ Field UNCHANGED
`formRiyo`, `shinseiFormName`, `workflowId`, `keihiMeisaiTempu`, `shinseiFormId`, `shinseiFormCode`, `shinseiTitle`, `isSearchFollowRole`, `page`, `size`, `sortParameters` — giữ nguyên (xem [current_analysis §3](../../current_state/current_analysis.md)).

#### 2.2.2 🆕 Field NEW
| Field (JSON) | Type | Required | Constraint | Mô tả | Map → DTO |
|---|---|---|---|---|---|
| `jugyoinId` | String | No | `@StringEmptyOrExactSize(29)` + alphanumeric (theo pattern các id khác) | 従業員ID. Khi có → lọc form theo quyền dùng của nhân viên này. Null/rỗng → KHÔNG lọc theo quyền (hành vi cũ) | `ShinseiFormSearchParamDto.jugyoinId` |

> Ý nghĩa cặp đôi: màn **tạo申請** (viewList) truyền `jugyoinId` = người nộp đang chọn để lọc form khả dụng. Màn **quản lý master** (search) thường KHÔNG truyền → admin thấy toàn bộ theo `bushokaisoPtnId` như cũ.

### 2.3 Example request
Xem [`request_examples.json`](./request_examples.json).

---

## 3. Response

### 3.1 Success — HTTP 200 (`ListShinseiForm`)
- ↔️ Shape giữ nguyên: `currentPage`, `pageSize`, `totalPage`, `totalElement`, `list[]`.
- 🆕 Mỗi phần tử `ShinseiForm` tự động kèm 13 flag 申請ルール (BeanUtil copy entity→dto). **KHÔNG** load 4 list con (`keihiKamokuList`...) trong search/list để tránh N+1 — 4 list con chỉ trả ở `getByShinseiFormId`. (Xác nhận với FE — §9 TBD.)
- ↔️ `customizeKomokuDtos` / `customizeNames` enrich như hành vi hiện tại.

### 3.2 Error responses
| HTTP | Exception | Message key | Khi nào | Marker |
|---|---|---|---|---|
| 400 | `BadRequestException` | `bad_request` + errorDetail | Bean Validation search param fail (gồm `jugyoinId` sai format) | ✏️ |
| 403 | `ForbiddenException` | `forbidden` | Sai role | ↔️ |

> Lưu ý: khi `jugyoinId` không match nhân viên nào / nhân viên không thuộc busho-yakushoku nào → trả **list rỗng**, KHÔNG throw (đây là kết quả hợp lệ "không có form khả dụng").

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal call order)

```
Controller -> Delegate(convertSearchParamDto: +set jugyoinId) -> UseCase
  searchShinseiForm()    : RoleUtil.check(SUPER_ADMIN, DEPARTMENT_MANAGEMENT)   [↔️]
  viewListShinseiForm()  : RoleUtil.check(READ, REGISTRATION, APPROVED, DEPARTMENT_MANAGEMENT, SUPER_ADMIN) [↔️]
  -> private search(paramDto)
       1. set default size/page/sort hyojiJun asc                              [↔️]
       2. validate(paramDto)                                                   [↔️ + jugyoinId field]
       3. 🆕 if (hasText(paramDto.jugyoinId)) resolveJugyoinAccessContext()    [NEW]
       4. shinseiFormCrud.search(hojinCode, paramDto, UNDELETED, bushokaisoPtnId, kengenCode) [✏️ truyền context]
       5. setForeignKeyName / setCustomizeNameForList                          [↔️]
       return ListShinseiFormDto
```

### 4.2 🆕 Access filter — lọc form theo quyền dùng (clarifications 6.7, 6.9)

**Quy tắc (final_spec §4.3)** — một form khả dụng cho nhân viên J khi **bất kỳ** điều kiện sau đúng (OR):
1. **Không giới hạn**: `bushoSeigenFlag = 0` AND `yakushokuSeigenFlag = 0` AND `jugyoinSeigenFlag = 0` → mọi người dùng được.
2. **Theo部署**: `bushoSeigenFlag = 1` AND J thuộc một busho trong `tm_shinsei_form_busho` của form. Nếu `bushoKaiKaisoFukumuFlag = 1` → match cả khi busho cấu hình là **tổ tiên (cấp trên)** của busho của J (tức busho của J nằm trong cây con của busho cấu hình).
3. **Theo役職**: `yakushokuSeigenFlag = 1` AND J có một yakushoku trong `tm_shinsei_form_yakushoku` của form.
4. **Theo従業員**: `jugyoinSeigenFlag = 1` AND J nằm trong `tm_shinsei_form_jugyoin` của form.

> J có thể thuộc **nhiều** busho/yakushoku (`tm_jugyoin_shozoku_busho`) → so khớp theo tập hợp.

**Phase 1 — `resolveJugyoinAccessContext(jugyoinId)`** (service):
```
jsbList   = jugyoinShozokuBushoAdapter.findJugyoinShozokuBushoByJugyoinId(hojinCode, jugyoinId)
jBushoIds = distinct jsbList.bushoId        (busho trực tiếp của J)
jYakushokuIds = distinct jsbList.yakushokuId
// Mở rộng cho 下位階層: tập busho "cấp trên-hoặc-bằng" của J để so với form có fukumu=1
jBushoIdsWithAncestors = jBushoIds ∪ ancestorsOf(jBushoIds, bushokaisoPtnId)   // dùng cây tm_bushokaiso_ptn_shosai
```
- `ancestorsOf`: build cây từ `BushokaisoPtnShosaiCrud.getListBushokaisoPtnShosai(hojinCode, bushokaisoPtnId)` rồi leo lên gốc. (Helper mới — §9 TBD-1.)
- Lý do dùng "ancestors của J" thay vì "descendants của form": rẻ hơn (tính 1 lần cho J, không phải mở rộng từng form). Tương đương logic: *busho của J là con-cháu của busho cấu hình* ⟺ *busho cấu hình là tổ tiên của busho của J*.

**Phase 2 — filter (đẩy vào repository, giữ paging đúng)**:
Thêm query repository `searchUsableByJugyoin(...)` (hoặc mở rộng `searchComplex`) với điều kiện:
```sql
( sf.busho_seigen_flag = 0 AND sf.yakushoku_seigen_flag = 0 AND sf.jugyoin_seigen_flag = 0 )
OR EXISTS ( SELECT 1 FROM tm_shinsei_form_busho b
            WHERE b.shinsei_form_id = sf.shinsei_form_id AND b.shinsei_form_version = sf.shinsei_form_version
              AND b.delete_flag = 0 AND sf.busho_seigen_flag = 1
              AND ( b.busho_id IN (:jBushoIds)
                    OR ( sf.busho_kai_kaiso_fukumu_flag = 1 AND b.busho_id IN (:jBushoIdsWithAncestors) ) ) )
OR EXISTS ( SELECT 1 FROM tm_shinsei_form_yakushoku y
            WHERE y.shinsei_form_id = sf.shinsei_form_id AND y.shinsei_form_version = sf.shinsei_form_version
              AND y.delete_flag = 0 AND sf.yakushoku_seigen_flag = 1 AND y.yakushoku_id IN (:jYakushokuIds) )
OR EXISTS ( SELECT 1 FROM tm_shinsei_form_jugyoin j
            WHERE j.shinsei_form_id = sf.shinsei_form_id AND j.shinsei_form_version = sf.shinsei_form_version
              AND j.delete_flag = 0 AND sf.jugyoin_seigen_flag = 1 AND j.jugyoin_id = :jugyoinId )
```
- Áp **thêm** vào điều kiện max-version + scope hiện có (KHÔNG thay thế).
- Lọc trong query → **pagination chính xác** (`totalElement` đúng số form khả dụng).
- ⚠️ Khi `jBushoIds`/`jYakushokuIds` rỗng → tránh `IN ()` lỗi SQL: truyền 1 giá trị sentinel hoặc dùng `COALESCE`/guard `(:list IS NULL OR ... IN :list)` theo pattern repository hiện có.

### 4.3 Defensive / edge
- `jugyoinId` null/blank → **bỏ qua toàn bộ Phase 1/2**, chạy đúng search cũ (backward compatible).
- J không thuộc busho/yakushoku nào và không nằm trong jugyoinList nào, mà form đều bật seigen → list rỗng (đúng nghiệp vụ).
- Form có seigen ON nhưng list con rỗng (clar 6.8 cho phép với 5/6/7) → điều kiện EXISTS tương ứng = false; vẫn có thể khả dụng nếu rơi vào nhánh "không giới hạn" hoặc nhánh khác. *Lưu ý*: nếu chỉ bật `bushoSeigenFlag=1` mà bushoList rỗng và 2 cờ kia = 0 → form KHÔNG khả dụng cho ai (không thuộc nhánh "không giới hạn" vì có 1 cờ ON). Xác nhận đây là ý đồ — §9 TBD-2.

### 4.4 Validation
- **Field**: `jugyoinId` — `@StringEmptyOrExactSize(size = 29)` + `@Pattern` alphanumeric (giống `workflowId`/`shinseiFormId` trong `ShinseiFormSearchParamDto`).
- **Business**: không thêm (chỉ filter).

---

## 5. Database Operations

### 5.1 Bảng đụng tới
| Bảng | Operation | Note |
|---|---|---|
| `tm_shinsei_form` | SELECT (max version + scope) | ↔️ existing `searchComplex` |
| `tm_shinsei_form_busho` / `_yakushoku` / `_jugyoin` | SELECT (EXISTS subquery) | 🆕 access filter |
| `tm_jugyoin_shozoku_busho` | SELECT | 🆕 lấy busho/yakushoku của J (Phase 1) |
| `tm_bushokaiso_ptn_shosai` | SELECT | 🆕 build cây để tính ancestors (Phase 1, khi có form fukumu=1) |

### 5.2 Transaction
- Read-only. Không cần `@Transactional` write. (search hiện tại cũng không.)

### 5.3 Performance
- Phase 1 chạy 1 lần / request (không loop theo form).
- `ancestorsOf` chỉ cần khi tồn tại form `bushoKaiKaisoFukumuFlag=1`; có thể lazy/cache theo `bushokaisoPtnId`.

---

## 6. Class & File Structure (UPDATE)

| Layer | Class | Thay đổi |
|---|---|---|
| API model | `ShinseiFormSearchParameter` | 🆕 thêm field `jugyoinId` (committed model + openapi.yml) |
| DTO | `ShinseiFormSearchParamDto` | 🆕 thêm `jugyoinId` + validation |
| Delegate | `ShinseiFormApiDelegateImpl` | ✏️ `convertSearchParamDto`: set `jugyoinId` (ApiUtil.toSearchParamDto tự copy nếu cùng tên — verify) |
| Service | `ShinseiFormService` | ✏️ `search()`: gọi `resolveJugyoinAccessContext` + truyền context; 🆕 helper `resolveJugyoinAccessContext`, `ancestorsOf` |
| Output port | `ShinseiFormCrud` | ✏️ `search(...)` thêm tham số context **hoặc** thêm method `searchUsableByJugyoin(...)` |
| Adapter | `ShinseiFormAdapter` | ✏️ truyền context xuống repository |
| Repository | `TmShinseiFormRepository` | 🆕 query/điều kiện EXISTS access filter |

**Dependency mới**:
- `ShinseiFormService` đã có sẵn `jugyoinShozokuBushoAdapter` (JugyoinShozokuBushoCrud) → tái dùng cho Phase 1.
- Cần `BushokaisoPtnShosaiCrud` (đã có) để tính ancestors → inject `@Autowired` nếu chưa có.

> `searchShinseiForm` và `viewListShinseiForm` (cả 2 delegate method) KHÔNG đổi chữ ký — chỉ luồng `search()` chung được mở rộng. KHÔNG thêm endpoint mới.

---

## 7. OpenAPI Definition

```yaml
ShinseiFormSearchParameter:
  type: object
  properties:
    # ... (field hiện có giữ nguyên) ...
    jugyoinId:
      type: string
      example: TM0101000120210402124723001aZ
```
> Cập nhật cả `api_interface_generate_tool/specification/openapi.yml` **và** model committed `ShinseiFormSearchParameter.java` (generator NPE trong env hiện tại — sửa tay model như đã làm cho `addShinseiForm`).

---

## 8. Test Cases

| # | Test case | Expected | Marker |
|---|---|---|---|
| 1 | search (admin) KHÔNG truyền jugyoinId | Behaviour cũ: trả theo bushokaisoPtnId/super-admin branch | Regression |
| 2 | viewList KHÔNG truyền jugyoinId | Behaviour cũ | Regression |
| 3 | viewList + jugyoinId, tất cả form seigen=0 | Trả tất cả form (không giới hạn) | New |
| 4 | jugyoinId, form bật bushoSeigen=1, J thuộc đúng busho | Form xuất hiện | New |
| 5 | jugyoinId, form bushoSeigen=1 + fukumu=1, J thuộc busho **con** của busho cấu hình | Form xuất hiện | New (hierarchy) |
| 6 | jugyoinId, form bushoSeigen=1 + fukumu=0, J thuộc busho **con** (không đúng busho cấu hình) | Form KHÔNG xuất hiện | New (hierarchy) |
| 7 | jugyoinId, form yakushokuSeigen=1, J có đúng yakushoku | Form xuất hiện | New |
| 8 | jugyoinId, form jugyoinSeigen=1, J nằm trong jugyoinList | Form xuất hiện | New |
| 9 | jugyoinId, form bật cả 3 seigen, J chỉ match 1 (役職) | Form xuất hiện (OR) | New |
| 10 | jugyoinId, form bật seigen nhưng J không match gì | Form KHÔNG xuất hiện | New |
| 11 | jugyoinId không thuộc busho/yakushoku nào + mọi form seigen ON | List rỗng (không throw) | Edge |
| 12 | Paging: tổng form khả dụng = 25, size=10 | totalElement=25, 3 trang, sort hyojiJun asc | New (paging-correct) |
| 13 | Role NO_RIGHT gọi search | 403 | Role fail |

### Integration
- Verify `totalElement` = đúng số form khả dụng (filter trong query, không post-filter sau paging).
- Verify regression: 2 API không truyền jugyoinId → kết quả y hệt trước.

---

## 9. Open Issues / TBD

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| 1 | Helper `ancestorsOf` (cây busho) chưa có method sẵn — phải build từ `getListBushokaisoPtnShosai` | Tự build tree + leo ancestor; cache theo bushokaisoPtnId | 🟡 Medium | clar 6.9 / BushokaisoPtnShosaiCrud |
| 2 | Form chỉ bật 1 seigen (vd bushoSeigen=1) + list rỗng → khả dụng cho ai? | Coi như KHÔNG khả dụng cho ai (không rơi vào nhánh "không giới hạn") | 🟡 Medium | clar 6.8/6.9 |
| 3 | search/viewList có cần trả 4 list con (keihiKamoku/busho/...) không | KHÔNG trả ở list (chỉ ở getByShinseiFormId) để tránh N+1 | 🟢 Low | final_spec §2.3 |
| 4 | Endpoint path `viewListShinseiForm` chính xác (`/view-list`?) | Theo openapi hiện có — verify khi impl | 🟢 Low | current_analysis §4 |
| 5 | Khi `jugyoinId` truyền ở màn admin (searchShinseiForm) có áp filter không | Áp đồng nhất (jugyoinId có → luôn filter) | 🟢 Low | clar 6.7 |

---

## 10. Cross-screen Impact

| Màn | Lý do | Severity | File |
|---|---|---|---|
| Màn tạo申請 (経費申請) | Nguồn gọi `viewListShinseiForm` + truyền `jugyoinId` | 🔴 | FE + logic chọn form |
| Master 部署階層 (bushokaiso ptn) | Nguồn cây để tính 下位階層 | 🟡 | đọc `tm_bushokaiso_ptn_shosai` (không sửa) |

---

## 11. References
- final_spec: [`../../final_spec.md`](../../final_spec.md) (v1.0.0) §2.3, §4.3, §8
- clarifications: [`../../clarifications.md`](../../clarifications.md) — 6.7, 6.9, 6.8
- baseline: [`../../current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.5, §6
- Reference impl: `ShinseiFormService#search`, `ShinseiFormAdapter#search`, `TmShinseiFormRepository#searchComplex/searchComplexBySuperAdmin`
- Reuse: `JugyoinShozokuBushoCrud#findJugyoinShozokuBushoByJugyoinId`, `BushokaisoPtnShosaiCrud#getListBushokaisoPtnShosai`
- Convention: `.claude/rules/api-conventions.md`

---

## Version History
### [1.0.0] - 2026-06-10
- Initial detail design cho `searchShinseiForm` + `viewListShinseiForm` (EXTEND, gộp folder).
- Scope: +param `jugyoinId` → access filter theo busho/yakushoku/jugyoin (OR) + 下位階層 (ancestor expansion); pagination-correct (filter trong query).
- 5 TBD (0 High, 2 Medium, 3 Low).
</content>
