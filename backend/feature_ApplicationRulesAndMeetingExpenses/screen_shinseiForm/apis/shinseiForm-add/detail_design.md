---
version: 1.0.0
status: draft
last_updated: 2026-06-10
api_name: addShinseiForm
http_method: POST
endpoint: /api/v1/shinsei-form
based_on_final_spec_version: 1.0.0
mode: EXTEND
based_on_current_analysis_version: 1.0.0
---

> 📘 **Detail design cho API `addShinseiForm` — EXTEND phase.**
> - API NÀY ĐÃ TỒN TẠI. File này CHỈ mô tả phần **THÊM / ĐỔI**.
> - Baseline: xem [`current_state/current_analysis.md`](../../current_state/current_analysis.md) §4 (API), §5.2 (add flow).
> - Cross-reference cấp màn: [`final_spec.md`](../../final_spec.md) (v1.0.0).
> - Ký hiệu: 🆕 NEW · ✏️ MODIFIED · ↔️ UNCHANGED.
> - ⚠️ Lưu ý: cả **POST** (tạo mới) và **PUT** (cập nhật) đều route qua `ShinseiFormUseCase.addShinseiForm` (PO xác nhận: update = tạo version mới). Detail design này áp dụng cho **cả 2** endpoint.

# Detail Design — API addShinseiForm (申請フォーム保存)

## 1. Tổng quan API

| Item | Value |
|---|---|
| API name | `addShinseiForm` |
| HTTP method | POST (và PUT `updateShinseiForm` cùng dùng chung logic) |
| Endpoint | `/api/v1/shinsei-form` |
| Mục đích | Tạo / cập nhật申請フォーム (luôn INSERT version mới). 🆕 Bổ sung lưu 7 nhóm「申請ルールの設定」 |
| Caller | Màn 申請フォーム保存 (マスタ設定 > 経費機能設定 > 申請フォーム設定) |
| Role được phép | `SUPER_ADMIN` (6), `DEPARTMENT_MANAGEMENT` (5) — ↔️ giữ nguyên |
| Mode | **EXTEND** |
| Success message | `I001` (delegate POST trả detail; PUT trả `I002`) — ↔️ giữ nguyên |

**Scope thay đổi (EXTEND)**:
- 🆕 Request/response `ShinseiForm` + `ShinseiFormDto`: +13 field flag + 4 list con (`keihiKamokuList`, `bushoList`, `yakushokuList`, `jugyoinList`).
- ✏️ `ShinseiFormService.addShinseiForm`: thêm bước lưu 4 list con theo version mới + validation nhóm 2/3 + consistency check + defensive set flag 外貨.
- 🆕 4 adapter/repository CRUD bảng con.
- ↔️ Cơ chế versioning, ID gen form, role check, unique check name/code, customize komoku, koshin rireki — giữ nguyên.

---

## 2. Request

### 2.1 HTTP Request
```
POST /api/v1/shinsei-form HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT>
```

### 2.2 Request Body schema

> ↔️ Field hiện hành giữ nguyên — xem [current_analysis §3 (DTO)](../../current_state/current_analysis.md). Dưới đây CHỈ liệt kê field 🆕.

#### 2.2.1 ↔️ Field UNCHANGED
`shinseiFormId` (rỗng=tạo mới / có giá trị=tạo version mới), `shinseiFormName`, `shinseiFormCode`, `shinseiTitle`, `kijunHi`, `keihiMeisaiTempu`, `keihiMeisaiShoninTokiToriatsukai`, `formRiyo`, `formShurui`, `workflowId`, `hyojiJun`, `shinseiFormSetsumei`, 4 flag quyền edit, `updateVersion`, `customizeKomokuDtos`, `updateAllShinseiTitleFlag`, `updateAllShinseiWorkflowFlag` — giữ nguyên validation hiện tại.

#### 2.2.2 ✏️ Field MODIFIED
| Field | Hiện tại | Đổi thành | Lý do |
|---|---|---|---|
| (không có field cũ bị đổi semantic) | — | — | Nhóm 1 độc lập với `keihiMeisaiTempu` (clar 6.3) → KHÔNG đổi nghĩa `keihiMeisaiTempu` |

#### 2.2.3 🆕 Field NEW

**Flag trên header (map → cột `tm_shinsei_form`)**
| Field (JSON) | Type | Required | Constraint | Map → DB |
|---|---|---|---|---|
| `ryoshushoMeisaiTempuKanou` | Integer | No | `@EnumNamePattern(^(0|1)$)` | `ryoshusho_meisai_tempu_kanou` |
| `keiroMeisaiTempuKanou` | Integer | No | `^(0|1)$` | `keiro_meisai_tempu_kanou` |
| `nittouMeisaiTempuKanou` | Integer | No | `^(0|1)$` | `nittou_meisai_tempu_kanou` |
| `ryoshushoGaikaMeisaiTempuKanou` | Integer | No | `^(0|1)$` | `ryoshusho_gaika_meisai_tempu_kanou` |
| `gaikaRateShomeishoTempuKanou` | Integer | No | `^(0|1)$` | `gaika_rate_shomeisho_tempu_kanou` |
| `keihiKamokuSeigenFlag` | Integer | No | `^(0|1)$` | `keihi_kamoku_seigen_flag` |
| `shinseiGokeiKingakuJogen` | Long | No (nullable) | `@Range(min=1, max=99999999999)` (null hợp lệ) | `shinsei_gokei_kingaku_jogen` |
| `shinseiGokeiJogenCheckKubun` | Integer | No | `^(1|2)$` (default 1) | `shinsei_gokei_jogen_check_kubun` |
| `workflowHenkoKanouFlag` | Integer | No | `^(0|1)$` | `workflow_henko_kanou_flag` |
| `bushoSeigenFlag` | Integer | No | `^(0|1)$` | `busho_seigen_flag` |
| `bushoKaiKaisoFukumuFlag` | Integer | No | `^(0|1)$` | `busho_kai_kaiso_fukumu_flag` |
| `yakushokuSeigenFlag` | Integer | No | `^(0|1)$` | `yakushoku_seigen_flag` |
| `jugyoinSeigenFlag` | Integer | No | `^(0|1)$` | `jugyoin_seigen_flag` |

**Nested list con** (map → 4 bảng con; phần tử chỉ cần `*Id` + optional `hyojiJun`)
| Field (JSON) | Type | Required | Element schema | Map → bảng |
|---|---|---|---|---|
| `keihiKamokuList` | array | **Có khi `keihiKamokuSeigenFlag=1`** (clar 6.8) | `{ keihiKamokuId: String, hyojiJun?: Integer }` | `tm_shinsei_form_keihi_kamoku` |
| `bushoList` | array | No (cho rỗng dù seigen=1) | `{ bushoId: String, hyojiJun?: Integer }` | `tm_shinsei_form_busho` |
| `yakushokuList` | array | No | `{ yakushokuId: String, hyojiJun?: Integer }` | `tm_shinsei_form_yakushoku` |
| `jugyoinList` | array | No | `{ jugyoinId: String, hyojiJun?: Integer }` | `tm_shinsei_form_jugyoin` |

> Tên field con cuối cùng theo OpenAPI model — verify khi gen (§7). DTO mới: `ShinseiFormKeihiKamokuDto`, `ShinseiFormBushoDto`, `ShinseiFormYakushokuDto`, `ShinseiFormJugyoinDto`.

### 2.3 Example request
Xem [`request_examples.json`](./request_examples.json).

---

## 3. Response

### 3.1 Success — HTTP 200
- ↔️ POST: trả về `ShinseiForm` (detail bản version mới nhất, qua `findByShinseiFormIdAndShinseiFormVersion(id, null, true)`), 🆕 kèm 13 flag + 4 list con (enrich tên経費科目/部署/役職/従業員 — xem getByShinseiFormId detail design riêng).
- ↔️ PUT: trả `ModelApiResponse { message: I002 }`.

### 3.2 Error responses

| HTTP | Exception | Message key | Khi nào | Marker |
|---|---|---|---|---|
| 400 | `BadRequestException` | `bad_request` + errorDetail | Bean Validation fail (flag sai range, `shinseiGokeiKingakuJogen` ngoài 1..99999999999) | ✏️ (thêm field) |
| 400 | `BadRequestException` | `error.shinseiForm.keihiKamoku.required` | `keihiKamokuSeigenFlag=1` nhưng `keihiKamokuList` rỗng | 🆕 |
| 400 | `BadRequestException` | `error.shinseiForm.keihiKamoku.meisaiTypeMismatch` | `keihiKamokuSeigenFlag=1` và 1 経費科目 có loại meisai 選択可能 không khớp nhóm 1 | 🆕 |
| 400 | `BadRequestException` | `E066` | Trùng tên form (↔️ existing) | ↔️ |
| 400 | `BadRequestException` | `E040` | Trùng `shinseiFormCode` (↔️ existing) | ↔️ |
| 403 | `ForbiddenException` | `forbidden` | Sai role (↔️ existing) | ↔️ |
| 404 | `NotFoundException` | `E041` | `workflowId` không tồn tại (↔️ existing) | ↔️ |

> Message key mới `error.shinseiForm.keihiKamoku.required` / `error.shinseiForm.keihiKamoku.meisaiTypeMismatch` cần đăng ký vào `messages*.properties` (ja/en/vi) — xem §9.

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal call order)

```
Controller -> Delegate(convertModelToShinseiFormDto: +map 4 list con) -> UseCase -> ShinseiFormService.addShinseiForm @Transactional
  1. checkRolesUserLogin()                                  [↔️ existing]
  2. Check trùng shinseiFormName theo bushokaisoPtnId       [↔️ existing] (E066)
  3. Resolve shinseiFormId (gen mới / dùng id có sẵn)       [↔️ existing]
  4. Set system fields + setDefaultSomeFields()            [↔️ existing]
  4b. 🆕 setDefaultApplicationRuleFields(dto)               [NEW] (default flag null + defensive 外貨)
  5. validator.validate(dto)                                [✏️ existing + 13 field mới]
  6. Check trùng shinseiFormCode                            [↔️ existing] (E040)
  7. Verify workflowId tồn tại                              [↔️ existing] (E041)
  7b. 🆕 validateApplicationRules(dto)                      [NEW] (nhóm 2 required + consistency meisai type)
  8. saveShinseiForm(dto)  -> INSERT version mới (trigger)  [↔️ existing]
  9. cascade updateAllShinseiTitle/Workflow (nếu existed)   [↔️ existing]
  10. shinseiFormCurrent = findByShinseiFormId(latest)      [↔️ existing] (có version mới)
  11. checkConstitutionOfCustozizeKomoku + save komoku      [↔️ existing]
  11b. 🆕 saveApplicationRuleChildren(shinseiFormCurrent, dto) [NEW]
       -> insert keihiKamokuList/bushoList/yakushokuList/jugyoinList
          theo (shinseiFormId, shinseiFormVersion mới)
  12. SosaRireki + addLogDataOwnerId + koshinRireki         [↔️ existing]
  return shinseiFormCurrent
```

**Nhấn mạnh điểm dễ sai**:
- 🔴 **Lưu list con theo version MỚI**: dùng `shinseiFormCurrent.getShinseiFormVersion()` (sau save), KHÔNG dùng version từ request. Giống `createCustomizeKomoku` (current_analysis §5.2 step 10). Nếu dùng version cũ → list con của version mới rỗng.
- 🔴 Mỗi save = re-insert TOÀN BỘ list con cho version mới (immutable history), KHÔNG update tại chỗ.
- 🟡 Consistency check (step 7b) chỉ chạy khi `keihiKamokuSeigenFlag=1`.
- 🟡 Defensive 外貨 (step 4b) chạy TRƯỚC validate để client không ép giá trị 1 khi 外貨機能 tắt.

### 4.2 Validation chi tiết

**Cấp field** (Bean Validation trên `ShinseiFormDto`):
- 12 flag (`*Kanou`, `*SeigenFlag`, `*Kubun`, `workflowHenkoKanouFlag`, `bushoKaiKaisoFukumuFlag`): `@EnumNamePattern` đúng tập giá trị (xem §2.2.3).
- `shinseiGokeiKingakuJogen`: `@Range(min = 1, max = 99999999999, message = "{E004}")` — **Long**. `null` pass (không nhập = bỏ qua). `0` fail (clar 6.5).

**Cấp business** (Service layer — `validateApplicationRules`):
1. **Nhóm 2 required** (clar 6.8): `if keihiKamokuSeigenFlag == 1 && CollectionUtils.isEmpty(keihiKamokuList)` → `BadRequestException("error.shinseiForm.keihiKamoku.required")`.
2. **Consistency meisai type** (clar 6.4, A197–A202): `if keihiKamokuSeigenFlag == 1`:
   - Load các `KeihiKamokuDto` theo `keihiKamokuId` trong list (qua `KeihiKamokuCrud`).
   - Với mỗi科目, các loại meisai mà科目 đó **選択可能 (= 有, `AriNashiUmu`)** phải nằm trong tập loại meisai mà form cho phép đính kèm (nhóm 1 flag = 1). Mapping 1:1:
     | KeihiKamoku field (選択可能性) | ShinseiForm flag (添付可能) |
     |---|---|
     | `ryoshushoSentakuKanousei` | `ryoshushoMeisaiTempuKanou` |
     | `keiroSentakuKanousei` | `keiroMeisaiTempuKanou` |
     | `nittouSentakuKanousei` | `nittouMeisaiTempuKanou` |
     | `ryoshushoGaikaSentakuKanousei` | `ryoshushoGaikaMeisaiTempuKanou` |
     | `gaikaRateShomeishoSentakuKanousei` | `gaikaRateShomeishoTempuKanou` |
   - Nếu tồn tại 1科目 có `xxxSentakuKanousei = 有` mà flag tương ứng của form = 0 → `BadRequestException("error.shinseiForm.keihiKamoku.meisaiTypeMismatch")`.
3. **Nhóm 5/6/7 cho rỗng** (clar 6.8): KHÔNG validate empty — `seigen_flag=1` + list rỗng vẫn hợp lệ.

> ⚠️ Quy tắc "subset" (選択可能 ⊆ 添付可能) là cách hiểu hợp lý nhất từ clar 6.4 + FE filter. Confirm subset vs overlap → §9 TBD-1.

### 4.3 Conditional rule (defensive theo điều kiện 外貨 — clar 6.6/6.10)

| Điều kiện setting Kaisha | `ryoshushoGaikaMeisaiTempuKanou` (1.4) | `gaikaRateShomeishoTempuKanou` (1.5) |
|---|---|---|
| `gaikaRiyoUmu = OFF` | **force 0** | **force 0** |
| `gaikaRiyoUmu = ON` & `shinseishaRateNyuryoku = OFF` | giữ giá trị client | **force 0** |
| `gaikaRiyoUmu = ON` & `shinseishaRateNyuryoku = ON` | giữ giá trị client | giữ giá trị client |

### 4.4 Unique check
- ↔️ `shinseiFormName` (theo bushokaisoPtnId), `shinseiFormCode` (theo hojinCode) — giữ nguyên.
- 🆕 List con: unique DB `(hojin_code, shinsei_form_id, shinsei_form_version, <entity>_id, delete_flag)` — service nên dedupe theo `*Id` trước khi insert để tránh vi phạm unique (nếu client gửi trùng).

### 4.5 Defensive coding (EXTEND)
```
// setDefaultApplicationRuleFields(dto) — chạy ở step 4b, TRƯỚC validate
if (dto.getRyoshushoMeisaiTempuKanou() == null) dto.setRyoshushoMeisaiTempuKanou(1);
if (dto.getKeiroMeisaiTempuKanou()     == null) dto.setKeiroMeisaiTempuKanou(1);
if (dto.getNittouMeisaiTempuKanou()    == null) dto.setNittouMeisaiTempuKanou(1);
if (dto.getKeihiKamokuSeigenFlag()     == null) dto.setKeihiKamokuSeigenFlag(0);
if (dto.getShinseiGokeiJogenCheckKubun() == null) dto.setShinseiGokeiJogenCheckKubun(1);
if (dto.getWorkflowHenkoKanouFlag()    == null) dto.setWorkflowHenkoKanouFlag(0);
if (dto.getBushoSeigenFlag()           == null) dto.setBushoSeigenFlag(0);
if (dto.getBushoKaiKaisoFukumuFlag()   == null) dto.setBushoKaiKaisoFukumuFlag(0);
if (dto.getYakushokuSeigenFlag()       == null) dto.setYakushokuSeigenFlag(0);
if (dto.getJugyoinSeigenFlag()         == null) dto.setJugyoinSeigenFlag(0);

// defensive 外貨 (clar 6.6) — đọc setting Kaisha
boolean gaikaOn = kaishaSetting.gaikaRiyoUmu == ON;
boolean rateOn  = kaishaSetting.shinseishaRateNyuryoku == ON;
if (!gaikaOn) { dto.setRyoshushoGaikaMeisaiTempuKanou(0); dto.setGaikaRateShomeishoTempuKanou(0); }
else if (!rateOn) { dto.setGaikaRateShomeishoTempuKanou(0);
                    if (dto.getRyoshushoGaikaMeisaiTempuKanou()==null) dto.setRyoshushoGaikaMeisaiTempuKanou(0); }
else { if (dto.getRyoshushoGaikaMeisaiTempuKanou()==null) dto.setRyoshushoGaikaMeisaiTempuKanou(0);
       if (dto.getGaikaRateShomeishoTempuKanou()==null) dto.setGaikaRateShomeishoTempuKanou(0); }

// clear list con khi seigen_flag = 0 (không trust client)
if (dto.getKeihiKamokuSeigenFlag()==0) dto.setKeihiKamokuList(new ArrayList<>());
if (dto.getBushoSeigenFlag()==0)       dto.setBushoList(new ArrayList<>());
if (dto.getYakushokuSeigenFlag()==0)   dto.setYakushokuList(new ArrayList<>());
if (dto.getJugyoinSeigenFlag()==0)     dto.setJugyoinList(new ArrayList<>());
```

> Nguồn `gaikaRiyoUmu` / `shinseishaRateNyuryoku` (setting Kaisha) — verify đúng adapter/flag khi implement (clar 6.6, §9 TBD-2).

---

## 5. Database Operations

### 5.1 Bảng đụng tới
| Bảng | Schema | Operation | Số rows | Note |
|---|---|---|---|---|
| `tm_shinsei_form` | keihi_com | INSERT (version mới) | 1 | ↔️ existing + 13 cột mới |
| `tm_customize_komoku` / `tm_format_hyoji` | keihi_com | INSERT | N | ↔️ existing |
| `tm_shinsei_form_keihi_kamoku` | keihi_com | INSERT | N | 🆕 theo version mới |
| `tm_shinsei_form_busho` | keihi_com | INSERT | N | 🆕 |
| `tm_shinsei_form_yakushoku` | keihi_com | INSERT | N | 🆕 |
| `tm_shinsei_form_jugyoin` | keihi_com | INSERT | N | 🆕 |
| `tm_keihi_kamoku` | keihi_com | SELECT | N | 🆕 đọc 選択可能性 cho consistency check |
| `tm_mster_saiban` | keihi_com | UPSERT (trigger) | 1 | ↔️ existing |

### 5.2 Transaction
- ↔️ `@Transactional` trên `addShinseiForm` — span toàn bộ insert header + komoku + 4 list con. Lỗi consistency/unique → rollback all.

### 5.3 ID Generation
- ↔️ Form: `SqlUtil.generateId(TableCode.TM023, hojinCode)`.
- 🆕 4 bảng con: `SqlUtil.generateId(TableCode.<NEW>, hojinCode)` — cần cấp 4 TableCode mới (§9 TBD-3).

### 5.4 Audit fields
- ↔️ Tự động qua `AuditingEntityListener` trên 4 entity con mới.

### 5.5 Cross-resource DB operation
| Bảng | Resource khác | Operation | Lý do |
|---|---|---|---|
| `tm_keihi_kamoku` | KeihiKamoku (sheet 02) | SELECT 選択可能性 | Consistency check meisai type (4.2 #2) |

---

## 6. Class & File Structure

| Layer | Class | Path | Thay đổi |
|---|---|---|---|
| Delegate | `ShinseiFormApiDelegateImpl` | `adapter/in/api/delegate/` | ✏️ `convertModelToShinseiFormDto` / `convertDtoToShinseiForm`: map 4 list con |
| API model | `ShinseiForm` + 4 sub-model | `adapter/in/api/model/` | 🆕 +13 field + 4 list (gen từ OpenAPI) |
| DTO | `ShinseiFormDto` | `application/domain/` | 🆕 +13 field + 4 list (`@Valid`) |
| DTO con | `ShinseiFormKeihiKamokuDto`, `ShinseiFormBushoDto`, `ShinseiFormYakushokuDto`, `ShinseiFormJugyoinDto` | `application/domain/` | 🆕 CREATE |
| Service | `ShinseiFormService` | `application/service/` | ✏️ `addShinseiForm`: step 4b/7b/11b; 🆕 helper `setDefaultApplicationRuleFields`, `validateApplicationRules`, `saveApplicationRuleChildren` |
| Entity | `TmShinseiForm` | `adapter/out/persistence/db/entity/` | 🆕 +13 field |
| Entity con | `TmShinseiFormKeihiKamoku`, `TmShinseiFormBusho`, `TmShinseiFormYakushoku`, `TmShinseiFormJugyoin` | `adapter/out/persistence/db/entity/` | 🆕 CREATE |
| Repository con | `TmShinseiFormKeihiKamokuRepository` + 3 | `adapter/out/persistence/db/repository/` | 🆕 CREATE |
| Output port | `ShinseiFormCrud` | `application/port/out/` | ✏️ thêm method save/find list con |
| Adapter | `ShinseiFormAdapter` | `adapter/out/persistence/db/` | ✏️ implement CRUD 4 bảng con |

**Dependency mới**:
- `ShinseiFormService` cần đọc 選択可能性 của経費科目: inject `KeihiKamokuCrud` (hoặc thêm method vào `ShinseiFormCrud` để query `tm_keihi_kamoku`). → cập nhật constructor + `BeanConfiguration.shinseiFormUseCase(...)`.
- Đọc setting Kaisha (`gaikaRiyoUmu`, `shinseishaRateNyuryoku`): tái dùng adapter setting Kaisha hiện có (verify §9 TBD-2).

---

## 7. OpenAPI Definition

> Nguồn: `api_interface_generate_tool/specification/openapi.yml` — schema `ShinseiForm` (dòng ~4148). Thêm 13 field + 4 list + sub-schema → regen model.

```yaml
ShinseiForm:
  type: object
  properties:
    # ... (field hiện có giữ nguyên) ...
    ryoshushoMeisaiTempuKanou: { type: integer, example: 1 }
    keiroMeisaiTempuKanou: { type: integer, example: 1 }
    nittouMeisaiTempuKanou: { type: integer, example: 1 }
    ryoshushoGaikaMeisaiTempuKanou: { type: integer, example: 0 }
    gaikaRateShomeishoTempuKanou: { type: integer, example: 0 }
    keihiKamokuSeigenFlag: { type: integer, example: 0 }
    shinseiGokeiKingakuJogen: { type: integer, format: int64, nullable: true, example: 1000000 }
    shinseiGokeiJogenCheckKubun: { type: integer, example: 1 }
    workflowHenkoKanouFlag: { type: integer, example: 0 }
    bushoSeigenFlag: { type: integer, example: 0 }
    bushoKaiKaisoFukumuFlag: { type: integer, example: 0 }
    yakushokuSeigenFlag: { type: integer, example: 0 }
    jugyoinSeigenFlag: { type: integer, example: 0 }
    keihiKamokuList:
      type: array
      items: { $ref: '#/components/schemas/ShinseiFormKeihiKamoku' }
    bushoList:
      type: array
      items: { $ref: '#/components/schemas/ShinseiFormBusho' }
    yakushokuList:
      type: array
      items: { $ref: '#/components/schemas/ShinseiFormYakushoku' }
    jugyoinList:
      type: array
      items: { $ref: '#/components/schemas/ShinseiFormJugyoin' }

ShinseiFormKeihiKamoku:
  type: object
  properties:
    keihiKamokuId: { type: string }
    keihiKamokuName: { type: string }   # enrich response
    keihiKamokuCode: { type: string }   # enrich response
    hyojiJun: { type: integer }
# ShinseiFormBusho / ShinseiFormYakushoku / ShinseiFormJugyoin: tương tự (bushoId/yakushokuId/jugyoinId + tên + hyojiJun)
```

---

## 8. Test Cases

### 8.1 Unit test

| # | Test case | Expected | Marker |
|---|---|---|---|
| 1 | Tạo form không bật seigen nào, không list con | 200, header lưu flag default, 4 bảng con rỗng | Regression |
| 2 | Tạo form như hiện tại (chỉ basic + customize komoku) | 200, behaviour cũ không đổi | Regression |
| 3 | `keihiKamokuSeigenFlag=1` + list 経費科目 hợp lệ | 200, insert `tm_shinsei_form_keihi_kamoku` theo version mới | New |
| 4 | `keihiKamokuSeigenFlag=1` + list rỗng | 400 `error.shinseiForm.keihiKamoku.required` | New |
| 5 | `keihiKamokuSeigenFlag=1` + 1科目 có 選択可能 meisai không khớp nhóm 1 | 400 `error.shinseiForm.keihiKamoku.meisaiTypeMismatch` | New |
| 6 | `bushoSeigenFlag=1` + bushoList rỗng | 200 (cho phép rỗng) | New |
| 7 | Update (id có sẵn) + list con | 200, list con gắn version MỚI, version cũ giữ list cũ | New (versioning) |
| 8 | `shinseiGokeiKingakuJogen = 0` | 400 validation (E004) | Validation fail |
| 9 | `shinseiGokeiKingakuJogen = null` | 200, lưu null | New |
| 10 | `shinseiGokeiKingakuJogen = 99999999999` / `100000000000` | 200 / 400 | Validation boundary |
| 11 | Client gửi `ryoshushoGaikaMeisaiTempuKanou=1` khi `gaikaRiyoUmu=OFF` | 200, server force lưu 0 | Defensive |
| 12 | Client gửi list con nhưng `seigenFlag=0` | 200, server clear list (không insert) | Defensive |
| 13 | Role NO_RIGHT / READ | 403 forbidden | Role fail |
| 14 | Consistency check khi `keihiKamokuSeigenFlag=0` | bỏ qua check, 200 dù科目 không khớp | New (scope) |

### 8.2 Integration test
- Full flow POST → DB: verify 1 row `tm_shinsei_form` version mới + N row mỗi bảng con đúng `shinsei_form_version`.
- Regression: form không có application rules vẫn save + customize komoku đúng.
- Versioning: update lần 2 → version=3, list con version 2 giữ nguyên, version 3 có list mới.
- Cross-resource: consistency check đọc `tm_keihi_kamoku` đúng; mismatch → rollback toàn transaction (không sót row con).

---

## 9. Open Issues / TBD

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| 1 | Quy tắc khớp meisai type: subset (選択可能 ⊆ 添付可能) hay overlap | Dùng **subset** | 🟢 Low | clar 6.4 / final_spec §4.1 |
| 2 | Adapter/flag chính xác đọc `gaikaRiyoUmu` & `shinseishaRateNyuryoku` (setting Kaisha) | Tái dùng adapter setting Kaisha hiện có | 🟢 Low | clar 6.6 / final_spec §8 |
| 3 | TableCode để gen ID 4 bảng con | Cấp 4 TableCode mới | 🟢 Low | final_spec §7 TBD-1 |
| 4 | `AriNashiUmu` giá trị "有" cụ thể dùng so sánh | So với `AriNashiUmu.ARI` (theo enum) | 🟢 Low | KeihiKamokuDto |

✅ Không có TBD High/Medium — API ready để implement.

---

## 10. References

- final_spec: [`../../final_spec.md`](../../final_spec.md) (v1.0.0) §3, §4, §5, §6
- clarifications: [`../../clarifications.md`](../../clarifications.md) (v1.0.0) — câu 6.3, 6.4, 6.5, 6.6, 6.8
- baseline: [`../../current_state/current_analysis.md`](../../current_state/current_analysis.md) §4, §5.2
- Reference impl hiện tại: `application/service/ShinseiFormService.java` method `addShinseiForm` (+ `createCustomizeKomoku` cho pattern lưu list con versioned)
- Reference cross-resource: `KeihiKamokuDto` (5 field `*SentakuKanousei`)
- Convention: `.claude/rules/api-conventions.md`, `.claude/rules/database.md`

---

## Version History

### [1.0.0] - 2026-06-10
- Initial detail design cho API `addShinseiForm` (EXTEND).
- Dựa trên final_spec v1.0.0 + current_analysis v1.0.0 + clarifications v1.0.0.
- Scope: +13 flag + 4 list con; thêm validate nhóm 2 + consistency meisai type + defensive 外貨; lưu list con versioned.
- 4 TBD (0 High, 0 Medium, 4 Low).
</content>
