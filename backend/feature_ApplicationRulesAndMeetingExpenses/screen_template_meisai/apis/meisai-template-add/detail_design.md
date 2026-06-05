---
version: 1.0.1
status: ready-for-implementation
api_name: AddMeisaiTemplate
http_method: POST
endpoint: /api/v1/meisaiTemplate
last_updated: 2026-06-04
based_on_final_spec_version: 1.1.0
based_on_clarifications_version: 1.1.0
mode: EXTEND
---

> 📘 **Detail design cho API ADD MeisaiTemplate (POST /meisaiTemplate).**
> - Đây là API **ĐÃ TỒN TẠI** — file này CHỈ mô tả phần THÊM/ĐỔI cho phase ngoại tệ + người tham gia.
> - Baseline behaviour: [`current_state/current_analysis.md` §5.2](../../current_state/current_analysis.md).
> - Cross-reference cấp màn: [`final_spec.md`](../../final_spec.md) (v1.0.0).
> - Q&A: [`clarifications.md`](../../clarifications.md) (12/12 🟢).
> - Ký hiệu: 🆕 NEW · ✏️ MODIFIED · ↔️ UNCHANGED.

# Detail Design — API ADD MeisaiTemplate

## 1. Tổng quan API

| Item | Value |
|---|---|
| **API name** | AddMeisaiTemplate |
| **HTTP method** | POST |
| **Endpoint** | `/api/v1/meisaiTemplate` |
| **Mục đích** | Tạo mới 1 明細テンプレート (per-user). ✏️ Mở rộng để hỗ trợ mode ngoại tệ (5/6) + áp dụng 参加者テンプレート |
| **Caller** | 明細テンプレート一覧 → 新規登録 → modal 明細テンプレート設定画面 → 保存 |
| **Role được phép gọi** | ↔️ `DEPARTMENT_MANAGEMENT`, `SUPER_ADMIN`, `APPROVED`, `REGISTRATION` (final_spec §4.7, clarification 6.11) |
| **Ownership** | Per-user — `jugyoinId` = login user, không nhận từ body (↔️) |
| **Success message code** | `I001` |

---

## 2. Request

### 2.1 HTTP Request
```
POST /api/v1/meisaiTemplate HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT>
```

### 2.2 Request Body schema (`MeisaiTemplate`)

> ↔️ Các field hiện hành (`meisaiTemplateMei`, `naiyo`, `bushoId`, `projectId`, `keihiKamokuId`, `zeiKubunId`,
> `kashikataKanjoKamokuId`, `kashikataHojoKamokuId`, `memo`, `hyojiJun`, field keiro...) giữ nguyên — xem
> [current_analysis §3](../../current_state/current_analysis.md). Dưới đây CHỈ liệt kê field 🆕/✏️.

| Field (JSON) | Type | Required | Constraint | Mô tả | Map → DB |
|---|---|---|---|---|---|
| ✏️ `torokuHoho` | string | ✅ | `@Pattern(REGEX_NUMERIC)`, `@Size(max=1)`, `@EnumNamePattern("1\|2\|4\|5\|6")` | Mode template. **Đổi từ `1\|2\|4`** | `toroku_hoho` |
| 🆕 `gaikaShuruiId` | string | conditional (mode 5) | `@Size(max=29)`, `@Pattern(ALPHANUMERIC_ALLOW_BLANK)` | 外貨種類ID (master GaikaShurui/TM057) | `gaika_shurui_id` |
| ✏️ `kingaku` | number | conditional | `BigDecimal` | mode 5 = số tiền **ngoại tệ**; mode 1/6 = số tiền **yên** | `kingaku` |
| 🆕 `rate` | number | conditional (mode 5) | `BigDecimal` (không `@Digits` — theo `MeisaiJohoDto`) | レート, default 1.0 | `rate` |
| 🆕 `enKansanKingaku` | number | conditional (mode 5) | `BigDecimal` | 円換算金額 = FE tự tính `kingaku × rate` | `en_kansan_kingaku` |
| 🆕 `sankashaTemplateId` | string | ✗ (mode 1/5 mới cho phép) | `@Size(max=29)`, `@Pattern(ALPHANUMERIC_ALLOW_BLANK)` | 参加者テンプレートID (reference only) | `sankasha_template_id` |

> **Không nhận từ body** (server tự set — ↔️): `hojinCode`, `jugyoinId`, `meisaiTemplateId`, `deleteFlag`,
> `updateVersion`, audit fields. (current_analysis §5.2 bước 3.)
> ⚠️ `gaikaShurui` (tên loại ngoại tệ) là field **read-only enrich** (TM057), không phải input.

### 2.3 Example Request
Xem [`request_examples.json`](./request_examples.json). Happy case mode 5 (領収書外貨):
```json
{
  "torokuHoho": "5",
  "meisaiTemplateMei": "USD出張テンプレート",
  "gaikaShuruiId": "GAIKA0000000000000000000000USD",
  "kingaku": 100.00,
  "rate": 150.0000,
  "enKansanKingaku": 15000,
  "sankashaTemplateId": "SANKASHA00000000000000000001",
  "hyojiJun": 100
}
```

---

## 3. Response

### 3.1 Success — HTTP 200
```json
{ "code": 0, "type": "success", "message": "<I001 i18n>" }
```

### 3.2 Error responses

| HTTP | Exception | Message key | Khi nào | Marker |
|---|---|---|---|---|
| 400 | `BadRequestException` | (validation map) | Bean validation fail (field-level) | ↔️ |
| 400 | `BadRequestException` | `E157` | mode 1/5: keihiKamoku có `ryoshushoSentakuKanousei=0` | ↔️ |
| 400 | `BadRequestException` | `E040` | trùng tên template (scope per-user) | ↔️ |
| 400 | `BadRequestException` | 🆕 `<gaika_disabled>` | mode 5/6 mà `TmKaisha.gaikaRiyoUmu != 1` | 🆕 ⚠️ TBD-C2 |
| 404/400 | `NotFoundException`/`BadRequestException` | `E041` | FK không tồn tại (project/busho/kamoku/zeikubun/jugyoin) | ↔️ |
| 400 | `BadRequestException` | (validation) | 🆕 mode 5 thiếu field ngoại tệ; hoặc mode 1/2/4/6 gửi field ngoại tệ ≠ null | 🆕 |
| 403 | `ForbiddenException` | — | Role không hợp lệ | ↔️ |
| 401 | `UnAuthorizedException` | — | Token thiếu/invalid | ↔️ |
| 500 | `InternalServerErrorException` | — | System error → rollback | ↔️ |

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal call order)

```
MeisaiTemplateApiController.addMeisaiTemplate(MeisaiTemplate)
  └─> MeisaiTemplateApiDelegateImpl.addMeisaiTemplate(req)   ↔️
        - BeanUtil.copyProperties(dto, req)                  (+4 field tự copy theo tên)
        └─> MeisaiTemplateUseCase.add(dto)
              └─> MeisaiTemplateService.add(dto)  @Transactional
                    1. checkRolesAllow()                      → 403          ↔️
                    2. super.validate(dto)  [Default]         → 400          ↔️
                    3. 🆕 checkGaikaSettingIfNeeded(dto)       → 400 (mode 5/6 & gaikaRiyoUmu≠1)
                    4. branch theo torokuHoho:
                       - "1" RECEIPT_RYOSYUSHO → addForRyoshusho (E157 check + seigen) ↔️
                       - "4" ROUTE_KEIRO_API   → addForKeiroApi   ↔️
                       - "2" ROUTE_KEIRO       → validateKeiro    ↔️
                       - 🆕 "5" RECEIPT_GAIKA  → addForGaikaRyoshusho (validate GroupRyoshusho+GroupGaika; seigen RYOSHUSHO)
                       - 🆕 "6" GAIKA_RATE_SHOMEISHO → addForRateShomeisho (validate giống Ryoshusho; KHÔNG gaika/sankasha; seigen?)
                       - else → return (no-op)               ↔️ (giữ behaviour cũ)
                    5. set context: hojinCode, jugyoinId(login), generateId(TM055),
                       deleteFlag=0, updateVersion=DEFAULT, default hyojiJun/teikiKukanKojo/keiroApiFlag  ↔️
                    6. 🆕 normalize field theo mode (clear field không thuộc mode — §4.3)
                    7. addLogDataOwnerId + koshinRireki (TM031)  ↔️
                    8. meisaiTemplateCrud.save(dto)             ↔️
        - ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I001"))
```

**Nhấn mạnh điểm dễ sai**:
- ✏️ Hiện `add()` chỉ rẽ nhánh `{1,2,4}`; mode `{5,6}` đang rơi vào `else → return` (no-op, **không tạo gì**). **Bắt buộc** thêm case 5, 6 — nếu quên, FE gửi mode 5/6 sẽ "thành công giả" mà không lưu.
- 🆕 `sankashaTemplateId` chỉ lưu khi mode ∈ {1,5}; mode {2,4,6} phải set NULL (clarification 6.7).
- 🆕 `enKansanKingaku` **BE không tính** — lưu nguyên giá trị FE gửi (clarification 6.3).

### 4.2 Validation chi tiết

**Cấp field** (Bean Validation trên `MeisaiTemplateDto`):
- ✏️ `torokuHoho`: `@EnumNamePattern("1|2|4|5|6")` (đổi từ `1|2|4`).
- 🆕 `gaikaShuruiId`: `@Size(max=29)` + `@Pattern(ALPHANUMERIC_ALLOW_BLANK)` (giống `MeisaiJohoDto`).
- 🆕 `rate`, `enKansanKingaku`, `kingaku`: `BigDecimal`, **không** `@Digits` (theo `MeisaiJohoDto` — đã verify).
- 🆕 `sankashaTemplateId`: `@Size(max=29)` + `@Pattern(ALPHANUMERIC_ALLOW_BLANK)`.

**Cấp business** (Service layer):
- 🆕 **Group ngoại tệ** (đề xuất `GroupGaika`, áp khi `torokuHoho=5`): `gaikaShuruiId`, `kingaku`, `rate`,
  `enKansanKingaku` đều REQUIRED (`@NotNull`/`@NotBlank` theo group). Triển khai như cách `GroupKeiroApi` hiện có.
- 🆕 Setting check: mode {5,6} → `TmKaisha.gaikaRiyoUmu` phải = `1` (利用する). (⚠️ TBD-C2: exception type + message key.)
- ↔️ E157 (keihiKamoku `ryoshushoSentakuKanousei=0`) áp cho mode 1 và 🆕 mode 5 (cùng họ 領収書).
- ↔️ checkExistenceOfIds (project/busho/keihiKamoku/kanjo/hojo/jugyoin/zeikubun).
- ↔️ Seigen (制限値): mode 1/5/6 đếm theo nhóm phù hợp (xem §4.3 / TBD-C3).
- ↔️ Trùng tên: scope `(hojinCode, jugyoinId)` → E040.

### 4.3 Conditional rule theo mode (🆕)

| torokuHoho | Field REQUIRED | Field PHẢI NULL | sankashaTemplateId | enKansanKingaku |
|---|---|---|---|---|
| `1` 領収書 | (như current) | gaika fields (4) | cho phép | NULL |
| `5` 領収書(外貨) | `gaikaShuruiId`, `kingaku`(外貨), `rate`, `enKansanKingaku` | — | cho phép | = FE gửi (yên) |
| `6` レート証明書 | (như 領収書 1) | `gaikaShuruiId`,`rate`,`enKansanKingaku`, `sankashaTemplateId` | NULL | NULL |
| `2`/`4` keiro | (như current) | gaika + sankasha | NULL | NULL |

> Mode 6 ≈ mode 1 về dữ liệu (`kingaku`=yên, `enKansanKingaku`=NULL) — clarification 6.8.

### 4.4 Unique check (↔️ giữ nguyên)
```sql
SELECT 1 FROM keihi_com.tm_meisai_template
WHERE hojin_code = ? AND jugyoin_id = ? AND meisai_template_mei = ? AND delete_flag = 0
```
→ trùng (khác `meisaiTemplateId`) → `BadRequestException("E040", ...)`. Scope **per-user**.

---

## 5. Database Operations

### 5.1 Bảng insert
| Bảng | Schema | Số rows | Note |
|---|---|---|---|
| `tm_meisai_template` | `keihi_com` | 1 | +4 cột mới (final_spec §5.1) |
| `tr_keiro_*` (mode 4) | — | ↔️ | chỉ mode keiro API (current) |

> 🆕 Mode 5 KHÔNG tạo keiro info (khác mode 4). Chỉ insert 1 row template.

### 5.2 Transaction
- ↔️ Toàn bộ trong 1 `@Transactional` (method `add`). Rollback nếu fail.

### 5.3 ID Generation
- ↔️ `SqlUtil.generateId(TableCode.TM055, hojinCode)` (29 chars). *(Lưu ý current_analysis §9.6: koshinRireki dùng tableName `TM031` — giữ nguyên, không sửa trong scope này.)*

### 5.4 Audit fields (↔️ tự động)
| Field | Value | Cơ chế |
|---|---|---|
| `add_date`/`upd_date` | now() | AuditingEntityListener |
| `add_userid`/`upd_userid` | login user | `@CreatedBy`/`@LastModifiedBy` |
| `update_version` | `1` (DEFAULT_VERSION) | set thủ công |
| `delete_flag` | `0` | set thủ công |
| 🆕 `rate` | nếu null & mode 5 → (FE gửi); DB default `1.0` | — |

---

## 6. Class & File Structure (đã tồn tại — chỉ EXTEND)

| Layer | Class | Path | Thay đổi |
|---|---|---|---|
| Delegate | `MeisaiTemplateApiDelegateImpl` | `adapter/in/api/delegate/` | ↔️ (BeanUtil tự copy 4 field mới) |
| API model | `MeisaiTemplate` | `adapter/in/api/model/` | 🆕 +4 field (xem §7) |
| Input port | `MeisaiTemplateUseCase` | `application/port/in/` | ↔️ signature `add` không đổi |
| Service | `MeisaiTemplateService` | `application/service/` | ✏️ +branch 5/6, +setting check, +group gaika |
| Output port | `MeisaiTemplateCrud` | `application/port/out/` | ↔️ |
| Adapter | `MeisaiTemplateAdapter` | `adapter/out/persistence/db/` | ↔️ (BeanUtil copy) |
| Entity | `TmMeisaiTemplate` | `.../entity/` | 🆕 +4 field |
| Repository | `TmMeisaiTemplateRepository` | `.../repository/` | ↔️ |
| Domain DTO | `MeisaiTemplateDto` | `application/domain/` | 🆕 +4 field, ✏️ regex torokuHoho, 🆕 GroupGaika |
| Bean config | `BeanConfiguration` (method `meisaiTemplateUseCase()`) | `adapter/out/configuration/` | ↔️ (nếu thêm `KaishaCrud` dep cho setting check → ✏️ constructor) |

> ⚠️ Setting check cần đọc `TmKaisha.gaikaRiyoUmu` → service cần inject thêm `KaishaCrud`/UseCase. Sẽ ✏️ constructor + bean config. (TBD-C2.)

---

## 7. OpenAPI Definition (🆕 thêm field vào schema `MeisaiTemplate`)

> ⚠️ Endpoint `MeisaiTemplate` KHÔNG nằm trong `api_interface_generate_tool/specification/openapi.yml` đang track
> (final_spec TBD-2 / clarification 6.12a). Xác định nguồn gen thật khi implement; nếu là model gen tay → sửa trực tiếp model.

Field bổ sung cho schema `MeisaiTemplate`:
```yaml
    MeisaiTemplate:
      type: object
      properties:
        # ... field hiện có giữ nguyên ...
        gaikaShuruiId:
          type: string
          maxLength: 29
          example: "GAIKA0000000000000000000000USD"
        rate:
          type: number
          example: 150.0000
        enKansanKingaku:
          type: number
          example: 15000
        sankashaTemplateId:
          type: string
          maxLength: 29
          example: "SANKASHA00000000000000000001"
```
(`torokuHoho` enum mô tả nới `1|2|4|5|6` — nếu spec có khai báo enum.)

---

## 8. Test Cases

### 8.1 Unit test (Service.add)

| # | Test case | Expected | Marker |
|---|---|---|---|
| 1 | mode 1 happy (như current) | 200, I001 | ↔️ |
| 2 | 🆕 mode 5 happy (đủ 4 field gaika + sankasha) | 200, lưu kingaku=ngoại tệ, enKansanKingaku=yên, sankashaTemplateId set | 🆕 |
| 3 | 🆕 mode 5 thiếu `gaikaShuruiId`/`rate`/`enKansanKingaku` | 400 (group gaika) | 🆕 |
| 4 | 🆕 mode 5 nhưng `gaikaRiyoUmu=0` | 400 (gaika disabled) | 🆕 ⚠️C2 |
| 5 | 🆕 mode 6 happy (kingaku=yên, gaika fields null, sankasha null) | 200, enKansanKingaku=NULL | 🆕 |
| 6 | 🆕 mode 6 gửi kèm `gaikaShuruiId` ≠ null | 400 hoặc clear (theo §4.3) | 🆕 |
| 7 | 🆕 mode 6 gửi `sankashaTemplateId` ≠ null | bị clear về NULL (clarification 6.7) | 🆕 |
| 8 | ✏️ torokuHoho="3" (日当) | 400 (regex không nhận) | ✏️ (giữ "chết") |
| 9 | trùng tên template (per-user) | 400 E040 | ↔️ |
| 10 | role không hợp lệ | 403 | ↔️ |
| 11 | keihiKamoku ryoshushoSentakuKanousei=0 (mode 1/5) | 400 E157 | ↔️ |
| 12 | FK project/busho không tồn tại | 404/400 E041 | ↔️ |

### 8.2 Integration test
- Full flow Controller → DB; verify 4 cột mới persist đúng theo mode.
- Verify `jugyoinId`/`hojinCode` set từ login, KHÔNG nhận từ body.
- Verify mode 5/6 bị chặn khi `gaikaRiyoUmu=0`.
- Verify transaction rollback khi lỗi giữa chừng.

---

## 9. Open Issues / TBD

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| C1 | Precision/scale `rate`/`enKansanKingaku` | Plain `BigDecimal`/`NUMERIC` (no `@Digits`, đã verify `MeisaiJohoDto`); FE handle TP | Low (resolved tầng DB) | final_spec TBD-1 |
| C2 | Setting check ngoại tệ: exception type + message key + inject `KaishaCrud` ở đâu | `BadRequestException` + message key mới (vd `Exxx`); inject `KaishaCrud` vào `MeisaiTemplateService` | Medium | final_spec §4.2 / clarification 6.2 |
| C3 | Seigen (制限値) cho mode 5/6 đếm theo nhóm nào | mode 5 → nhóm RYOSHUSHO; mode 6 → cần xác nhận có giới hạn riêng không (assume dùng RYOSHUSHO hoặc bỏ qua) | Medium | current_analysis §5.2 / final_spec |
| C4 | ✅ **RESOLVED 2026-06-04** — cascade khi xóa sankasha_template | **Chốt phương án BLOCK** (không set NULL): block xóa sankasha nếu còn ≥1 meisai (`delete_flag=0`) tham chiếu, throw `E180`. Implement ở API **sankasha-template-delete/bulk-delete** (xem [`../../../screen_detail_template_nguoi_tham_gia/final_spec.md` §4.9](../../../screen_detail_template_nguoi_tham_gia/final_spec.md) + 2 detail_design delete/bulk-delete). **API add này KHÔNG bị ảnh hưởng.** | ~~Medium~~ RESOLVED | final_spec TBD-3 / clarification 6.6 |

**Severity legend**: High = schema/contract; Medium = handler/logic; Low = constant/config.

---

## 10. References
- final_spec: [`../../final_spec.md`](../../final_spec.md) (v1.0.0) — §3 (fields), §4 (rules), §5 (schema), §6 (API)
- clarifications: [`../../clarifications.md`](../../clarifications.md) (v1.0.0) — 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8
- baseline: [`../../current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.2
- DB design: `db_tables_application_rules_meeting_expenses.xlsx`, sheet `tm_meisai_template`
- Reference impl (cùng pattern, đã đọc): `application/service/MeisaiTemplateService.java` (method `add`),
  `application/domain/MeisaiJohoDto.java` (validation gaika), `application/enums/TorokuHoho.java` (mode 5/6)
- ID gen: `SqlUtil.generateId(TableCode.TM055, hojinCode)`
- Setting: `TmKaisha.gaikaRiyoUmu` (0/1) · GaikaShurui master: `TableCode.TM057`

---

## Version History

### [1.0.1] - 2026-06-04
- **§9 TBD-C4 RESOLVED** — cascade khi xóa sankasha_template: chốt phương án **BLOCK** (không set NULL),
  implement ở API sankasha-template-delete/bulk-delete; **API add này KHÔNG bị ảnh hưởng**.
- Cập nhật `based_on_final_spec_version` 1.0.0 → 1.1.0, `based_on_clarifications_version` 1.0.0 → 1.1.0.
- Patch bump (chỉ cập nhật reference/TBD; không đổi logic API add).

### [1.0.0] - 2026-06-04
- Initial detail design cho API ADD MeisaiTemplate (phase EXTEND).
- Dựa trên final_spec v1.0.0 + clarifications v1.0.0 (12/12 answered) + current_analysis v1.0.0.
- Verify pattern với `MeisaiTemplateService.add()` thực tế + `MeisaiJohoDto` (validation gaika) + `TorokuHoho` enum.
- Scope: +branch mode 5/6, +4 field, +setting check gaikaRiyoUmu, +GroupGaika, sankashaTemplateId reference.
- 4 TBD (0 High, 3 Medium, 1 Low) — xem §9.
