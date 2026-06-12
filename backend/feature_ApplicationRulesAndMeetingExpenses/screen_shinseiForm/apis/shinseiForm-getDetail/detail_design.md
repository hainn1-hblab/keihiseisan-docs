---
version: 1.0.0
status: draft
last_updated: 2026-06-10
api_name: getByShinseiFormId
http_method: GET
endpoint: /api/v1/shinsei-form/{shinseiFormId}
based_on_final_spec_version: 1.0.0
mode: EXTEND
based_on_current_analysis_version: 1.0.0
---

> 📘 **Detail design cho API `getByShinseiFormId` — EXTEND phase.**
> - API ĐÃ TỒN TẠI. File này CHỈ mô tả phần **THÊM / ĐỔI**.
> - Baseline: [`current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.5 (`viewDetailById`), §4 (API).
> - Cross-reference cấp màn: [`final_spec.md`](../../final_spec.md) (v1.0.0) §3, §4.2, §6.
> - Ký hiệu: 🆕 NEW · ✏️ MODIFIED · ↔️ UNCHANGED.

# Detail Design — API getByShinseiFormId (申請フォーム詳細取得)

## 1. Tổng quan API

| Item | Value |
|---|---|
| API name | `getByShinseiFormId` |
| HTTP method | GET |
| Endpoint | `/api/v1/shinsei-form/{shinseiFormId}` (query optional `shinseiFormVersion`) |
| Mục đích | Lấy chi tiết 1 申請フォーム (1 version) để hiển thị màn 申請フォーム保存 (edit/view) |
| Caller | Màn 申請フォーム保存 (マスタ設定) khi mở 1 form từ list / chọn バージョン選択 |
| Role được phép | `SUPER_ADMIN`(6), `DEPARTMENT_MANAGEMENT`(5) — ↔️ (qua `findByShinseiFormIdAndShinseiFormVersion(..., isRole=true)`) |
| Service method | `findByShinseiFormIdAndShinseiFormVersion(shinseiFormId, shinseiFormVersion, true)` → `viewDetailById()` |
| Mode | EXTEND |
| Success | 200 + `ShinseiForm` (1 object) |

**Scope thay đổi (EXTEND)**:
- 🆕 Response `ShinseiForm` bổ sung **4 list con đã enrich tên**: `keihiKamokuList`, `bushoList`, `yakushokuList`, `jugyoinList` (cho đúng version của form trả về).
- 🆕 13 flag 申請ルール tự động trả (BeanUtil copy entity→dto) — chỉ cần đảm bảo load đúng entity (đã có).
- ↔️ Workflow name, customizeKomoku + formatHyoji, jugyoinShozokuBusho enrich, versioning, role check — giữ nguyên.

> Delegate `convertDtoToShinseiForm` và model `ShinseiForm` **đã** map 4 list con (làm ở API add). API này chỉ cần **populate + enrich** 4 list ở tầng Service.

---

## 2. Request

### 2.1 HTTP Request
```
GET /api/v1/shinsei-form/{shinseiFormId}?shinseiFormVersion={version} HTTP/1.1
Authorization: Bearer <JWT>
```

### 2.2 Params
| Param | Vị trí | Type | Required | Mô tả | Marker |
|---|---|---|---|---|---|
| `shinseiFormId` | path | String | Có | 申請フォームID | ↔️ |
| `shinseiFormVersion` | query | Long | Không | Version cụ thể. Null → lấy latest (qua `resolveVersion` + `tm_mster_saiban`) | ↔️ |

> ↔️ Không đổi chữ ký endpoint. Không thêm param mới.

---

## 3. Response

### 3.1 Success — HTTP 200 (`ShinseiForm`)
Object 1 form. So với baseline, bổ sung:
- 🆕 13 flag 申請ルール (`ryoshushoMeisaiTempuKanou` ... `jugyoinSeigenFlag`, `shinseiGokeiKingakuJogen`, `shinseiGokeiJogenCheckKubun`).
- 🆕 4 list con (mỗi item kèm tên enrich):
  - `keihiKamokuList[]`: `{ shinseiFormKeihiKamokuId, keihiKamokuId, keihiKamokuCode, keihiKamokuName, hyojiJun }`
  - `bushoList[]`: `{ shinseiFormBushoId, bushoId, bushoMei, hyojiJun }`
  - `yakushokuList[]`: `{ shinseiFormYakushokuId, yakushokuId, yakushokuName, hyojiJun }`
  - `jugyoinList[]`: `{ shinseiFormJugyoinId, jugyoinId, jugyoinBango, jugyoinShimei, hyojiJun }`
- ↔️ `workflowName`, `customizeKomokus` (+ `formatHyojis`), `customizeNames`, `jugyoinShozokuBushos` giữ nguyên.

Xem [`response_examples.json`](./response_examples.json).

### 3.2 Error responses
| HTTP | Exception | Message key | Khi nào | Marker |
|---|---|---|---|---|
| 404 | `NotFoundException` | `E041` (id, ShinseiFormDto.shinseiFormId) | Không tìm thấy form theo id/version/bushokaisoPtnId | ↔️ |
| 403 | `ForbiddenException` | `forbidden` | Sai role | ↔️ |

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal call order)

```
Controller -> Delegate.getByShinseiFormId(id, version, auth)
  -> UseCase.findByShinseiFormIdAndShinseiFormVersion(id, version, isRole=true)
       RoleUtil.check(SUPER_ADMIN, DEPARTMENT_MANAGEMENT)                          [↔️]
       -> viewDetailById(id, version):
            1. dto = crud.findByShinseiFormIdAndShinseiFormVersion(
                       hojinCode, id, deleteFlag=null, bushokaisoPtnId, version)    [↔️]  (null→E041)
            2. setForeignKeyName([dto])      // workflowName                        [↔️]
            3. setCustomizeName(dto)         // customizeNames + bunki suchi ids    [↔️]
            4. customizeKomokuDtos = crud.findCustomizeKomokuByShinseiFormIdAndShinseiFormVersion(
                                       hojinCode, dto.id, dto.version)              [↔️]
               + setFormatHyojiDtoInCustomize(each)                                 [↔️]
               dto.setCustomizeKomokuDtos(...)                                      [↔️]
            5. 🆕 setApplicationRuleChildren(dto)   // load + enrich 4 list con     [NEW]
            6. setRelatedData(dto, null)     // jugyoinShozokuBusho + jugyoin info  [↔️]
            return dto
  -> Delegate.convertDtoToShinseiForm(dto)   // ĐÃ map 4 list dto→model            [↔️ đã làm ở add]
  -> ApiUtil.responseEntity
```

**Điểm dễ sai**:
- 🔴 **Dùng đúng version của form đã load** (`dto.getShinseiFormVersion()`) khi query 4 list con — KHÔNG dùng `shinseiFormVersion` request (có thể null). Giống cách load `customizeKomoku` ở step 4 (current_analysis §5.5).
- ↔️ `viewDetailById` cho phép đọc cả form đã xóa (`deleteFlag=null`) để hiển thị — giữ nguyên, 4 list con cũng theo version đó.

### 4.2 🆕 `setApplicationRuleChildren(dto)` — load + enrich (pseudo-code)

```
hojinCode = getHojinCode(); id = dto.getShinseiFormId(); ver = dto.getShinseiFormVersion();

// 1) Load child lists (port methods đã có — thêm khi làm API add)
keihiKamokuList = crud.findShinseiFormKeihiKamoku(hojinCode, id, ver);   // delete_flag=0, order hyoji_jun
bushoList       = crud.findShinseiFormBusho(hojinCode, id, ver);
yakushokuList   = crud.findShinseiFormYakushoku(hojinCode, id, ver);
jugyoinList     = crud.findShinseiFormJugyoin(hojinCode, id, ver);

// 2) Enrich tên (batch query, tránh N+1)
if (!keihiKamokuList.isEmpty()) {
   kamokuMap = keihiKamokuCrud.findKeihiKamokuByIds(hojinCode, ids(keihiKamokuList)).toMap(by keihiKamokuId);
   each item: item.keihiKamokuCode = map.code; item.keihiKamokuName = map.name;
}
if (!bushoList.isEmpty())     { enrich bushoMei      via BushoCrud (batch by ids nếu có, else per-id) }
if (!yakushokuList.isEmpty()) { enrich yakushokuName via YakushokuCrud }
if (!jugyoinList.isEmpty())   { enrich jugyoinBango/jugyoinShimei via JugyoinCrud }

dto.setKeihiKamokuList(keihiKamokuList);
dto.setBushoList(bushoList);
dto.setYakushokuList(yakushokuList);
dto.setJugyoinList(jugyoinList);
```

- Item bị xóa ở master (tên không tìm thấy) → để tên null (vẫn giữ id), KHÔNG throw.
- 4 port method `findShinseiForm*` đã tồn tại từ API add (ShinseiFormCrud/Adapter/Repository) → **tái dùng**.

### 4.3 Validation
- Không có validation đầu vào mới (chỉ đọc). Role check như baseline.

---

## 5. Database Operations

### 5.1 Bảng đụng tới
| Bảng | Operation | Marker |
|---|---|---|
| `tm_shinsei_form` | SELECT (id+version+bushokaisoPtnId) | ↔️ |
| `tm_customize_komoku` / `tm_format_hyoji` | SELECT | ↔️ |
| `tm_shinsei_form_keihi_kamoku` / `_busho` / `_yakushoku` / `_jugyoin` | SELECT (id+version, delete_flag=0) | 🆕 |
| `tm_keihi_kamoku` | SELECT batch (enrich) | 🆕 |
| `tm_busho` / 役職 master / `tm_jugyoin` | SELECT (enrich) | 🆕 |
| `tm_jugyoin_shozoku_busho` | SELECT (setRelatedData) | ↔️ |

### 5.2 Transaction
- Read-only. Không cần `@Transactional` write (baseline cũng vậy).

---

## 6. Class & File Structure (UPDATE)

| Layer | Class | Thay đổi |
|---|---|---|
| Service | `ShinseiFormService` | ✏️ `viewDetailById`: thêm step 5; 🆕 helper `setApplicationRuleChildren` + enrich helpers |
| Output port | `ShinseiFormCrud` | ↔️ đã có `findShinseiFormKeihiKamoku/Busho/Yakushoku/Jugyoin` (từ API add) |
| Adapter | `ShinseiFormAdapter` | ↔️ đã implement 4 find method |
| DTO | `ShinseiFormDto` + 4 child DTO | ↔️ đã có 4 list + field enrich (code/name/mei/bango/shimei) |
| API model | `ShinseiForm` + 4 sub-model | ↔️ đã có field (từ API add) |
| Delegate | `ShinseiFormApiDelegateImpl` | ↔️ `convertDtoToShinseiForm` đã map 4 list |

**Dependency**: `ShinseiFormService` đã có `keihiKamokuCrud` (thêm ở API add), `bushoAdapter` (BushoCrud), `yakushokuAdapter` (YakushokuCrud), `jugyoinAdapter` (JugyoinCrud) — **đều có sẵn**, không cần inject mới.

> ⚠️ API này gần như chỉ cần sửa **1 method Service** (`viewDetailById`) + helper enrich. Hầu hết hạ tầng đã xong khi làm API add.

---

## 7. OpenAPI Definition
↔️ Không đổi — schema `ShinseiForm` + 4 sub-schema (`ShinseiFormKeihiKamoku/Busho/Yakushoku/JugyoinSeigen`) đã thêm ở API add. Response GET tự dùng.

---

## 8. Test Cases

| # | Test case | Expected | Marker |
|---|---|---|---|
| 1 | Get form cũ (chưa có 申請ルール data) | 200, 13 flag = default, 4 list rỗng; phần cũ (customize/workflow) đúng | Regression |
| 2 | Get form có đủ 4 list con | 200, 4 list trả đúng + enrich tên (code/name/mei/bango/shimei) | New |
| 3 | Get với `shinseiFormVersion` cụ thể | 4 list con thuộc **đúng version** đó (không lẫn version khác) | New (versioning) |
| 4 | Get không truyền version (latest) | Lấy version mới nhất + 4 list của version đó | New |
| 5 | 1 keihiKamoku/busho... đã bị xóa ở master | item vẫn trả (id giữ), tên = null, không throw | Edge |
| 6 | Form không tồn tại | 404 E041 | Error |
| 7 | Role READ/REGISTRATION gọi getByShinseiFormId | 403 (vì endpoint này check 5,6) | Role |
| 8 | Form đã soft-delete | vẫn đọc được (deleteFlag=null cho display) + 4 list theo version | Regression |

### Integration
- Verify enrich dùng **batch query** (1 query/loại master), không N+1.
- Verify regression: form cũ trả nguyên vẹn như trước.

---

## 9. Open Issues / TBD

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| 1 | Batch accessor cho busho/yakushoku/jugyoin (enrich tên) có sẵn chưa | Dùng batch nếu có (`findAllBy...In`), else per-id loop (list nhỏ) | 🟢 Low | BushoCrud/YakushokuCrud/JugyoinCrud |
| 2 | getByShinseiFormId chỉ cho role 5,6; màn tạo申請 dùng API khác (`getByShinseiFormIdFromAnotherScreen`/`getShinseiFormAndJugyoin`) | API get-detail này chỉ phục vụ màn master; nếu màn khác cần 4 list con → extend riêng | 🟢 Low | current_analysis §4 |

✅ Không có TBD High/Medium.

---

## 10. References
- final_spec: [`../../final_spec.md`](../../final_spec.md) (v1.0.0) §3, §4.2, §6
- clarifications: [`../../clarifications.md`](../../clarifications.md) — 6.1, 6.2
- baseline: [`../../current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.5
- Reference impl: `ShinseiFormService#viewDetailById` (pattern load customizeKomoku theo version), `#setForeignKeyName`, `#setRelatedData`
- Reuse port (đã có từ API add): `ShinseiFormCrud#findShinseiForm{KeihiKamoku,Busho,Yakushoku,Jugyoin}`
- Enrich: `KeihiKamokuCrud#findKeihiKamokuByIds`, `BushoCrud`, `YakushokuCrud`, `JugyoinCrud`
- API liên quan: [`../shinseiForm-add/detail_design.md`](../shinseiForm-add/detail_design.md) (nguồn tạo data 4 list)

---

## Version History
### [1.0.0] - 2026-06-10
- Initial detail design cho `getByShinseiFormId` (EXTEND).
- Scope: response +13 flag +4 list con (enrich tên) theo đúng version; chủ yếu sửa `viewDetailById` + helper enrich (hạ tầng đã có từ API add).
- 2 TBD (0 High, 0 Medium, 2 Low).
</content>
