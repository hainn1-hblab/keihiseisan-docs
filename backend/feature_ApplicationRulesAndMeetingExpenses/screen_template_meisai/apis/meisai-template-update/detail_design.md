---
version: 1.0.0
status: ready-for-implementation
api_name: UpdateMeisaiTemplate
http_method: PUT
endpoint: /api/v1/meisaiTemplate
last_updated: 2026-06-05
based_on_final_spec_version: 1.1.0
based_on_clarifications_version: 1.1.0
mode: EXTEND
---

> 📘 **Detail design cho API UPDATE MeisaiTemplate (PUT /meisaiTemplate).**
> - Đây là API **ĐÃ TỒN TẠI** — file này CHỈ mô tả phần THÊM/ĐỔI cho phase ngoại tệ + người tham gia.
> - Baseline behaviour: [`current_state/current_analysis.md` §5.3](../../current_state/current_analysis.md).
> - Cross-reference cấp màn: [`final_spec.md`](../../final_spec.md) (v1.1.0).
> - Q&A: [`clarifications.md`](../../clarifications.md) (12/12 🟢).
> - Anh em với API ADD: [`../meisai-template-add/detail_design.md`](../meisai-template-add/detail_design.md) (v1.0.1).
> - Ký hiệu: 🆕 NEW · ✏️ MODIFIED · ↔️ UNCHANGED.

# Detail Design — API UPDATE MeisaiTemplate

## 1. Tổng quan API

| Item | Value |
|---|---|
| **API name** | UpdateMeisaiTemplate |
| **HTTP method** | PUT |
| **Endpoint** | `/api/v1/meisaiTemplate` |
| **Mục đích** | Cập nhật 1 明細テンプレート (per-user). ✏️ Mở rộng để hỗ trợ mode ngoại tệ (5/6) + áp dụng 参加者テンプレート |
| **Caller** | 明細テンプレート一覧 → 編集 → modal 明細テンプレート設定画面 → 保存 (chọn template có sẵn) |
| **Role được phép gọi** | ↔️ `DEPARTMENT_MANAGEMENT`, `SUPER_ADMIN`, `APPROVED`, `REGISTRATION` (final_spec §4.7, clarification 6.11) |
| **Ownership** | Per-user — chỉ update được template mà `jugyoinId` = login user (check qua query existence) |
| **Optimistic lock** | `updateVersion` (`@Version`) — sai version → lỗi optimistic lock |
| **Success message code** | `I002` |

> ⚠️ **Khác API ADD**: endpoint dùng **PUT** trên cùng path `/meisaiTemplate`, `meisaiTemplateId` truyền trong **request body** (KHÔNG phải path param `{id}`) — theo pattern thực tế codebase (current_analysis §4). Bắt buộc thêm `meisaiTemplateId` + `updateVersion` (group `GroupUpdate`).

---

## 2. Request

### 2.1 HTTP Request
```
PUT /api/v1/meisaiTemplate HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT>
```

### 2.2 Request Body schema (`MeisaiTemplate`)

> ↔️ Các field hiện hành giữ nguyên — xem [current_analysis §3](../../current_state/current_analysis.md) +
> [API ADD §2.2](../meisai-template-add/detail_design.md). Dưới đây liệt kê field bắt buộc cho UPDATE + field 🆕/✏️.

| Field (JSON) | Type | Required | Constraint | Mô tả | Map → DB |
|---|---|---|---|---|---|
| ✏️ `meisaiTemplateId` | string | ✅ (update) | `@NotNull(GroupUpdate)`, `@StringEmptyOrExactSize(29)`, `@Pattern(ALPHANUMERIC)` | ID bản ghi cần update | `meisai_template_id` |
| ✏️ `updateVersion` | integer | ✅ (update) | `@NotNull(GroupUpdate)` | Optimistic lock version (lấy từ bản ghi đang sửa) | `update_version` |
| ✏️ `torokuHoho` | string | ✅ | `@Pattern(REGEX_NUMERIC)`, `@Size(max=1)`, `@EnumNamePattern("1\|2\|4\|5\|6")` | Mode template. **Đổi từ `1\|2\|4`** | `toroku_hoho` |
| 🆕 `gaikaShuruiId` | string | conditional (mode 5) | `@Size(max=29)`, `@Pattern(ALPHANUMERIC_ALLOW_BLANK)`, `@NotBlank(GroupGaika)` | 外貨種類ID (master GaikaShurui/TM057) | `gaika_shurui_id` |
| ✏️ `kingaku` | number | conditional | `BigDecimal`, `@NotNull(GroupGaika)` | mode 5 = số tiền **ngoại tệ**; mode 1/6 = số tiền **yên** | `kingaku` |
| 🆕 `rate` | number | conditional (mode 5) | `BigDecimal`, `@NotNull(GroupGaika)` | レート, default 1.0 | `rate` |
| 🆕 `enKansanKingaku` | number | conditional (mode 5) | `BigDecimal`, `@NotNull(GroupGaika)` | 円換算金額 = FE tự tính `kingaku × rate` | `en_kansan_kingaku` |
| 🆕 `sankashaTemplateId` | string | ✗ (mode 1/5 mới cho phép) | `@Size(max=29)`, `@Pattern(ALPHANUMERIC_ALLOW_BLANK)` | 参加者テンプレートID (reference only) | `sankasha_template_id` |

> **Không nhận từ body / không cho đổi** (server giữ nguyên từ bản ghi cũ — ↔️): `hojinCode`, `jugyoinId`,
> `deleteFlag`, audit fields. (current_analysis §5.3 — `blindData()` whitelist field được phép update.)
> ⚠️ `gaikaShurui` (tên loại ngoại tệ) là field **read-only enrich**, không phải input.

### 2.3 Example Request
Xem [`request_examples.json`](./request_examples.json). Happy case mode 5 (領収書外貨):
```json
{
  "meisaiTemplateId": "MEISAITEMPLATE0000000000000001",
  "updateVersion": 1,
  "torokuHoho": "5",
  "meisaiTemplateMei": "USD出張テンプレート（更新）",
  "gaikaShuruiId": "GAIKA0000000000000000000000USD",
  "kingaku": 120.00,
  "rate": 152.0000,
  "enKansanKingaku": 18240,
  "sankashaTemplateId": "SANKASHA00000000000000000001",
  "hyojiJun": 100
}
```

---

## 3. Response

### 3.1 Success — HTTP 200
```json
{ "code": 0, "type": "success", "message": "<I002 i18n>" }
```

### 3.2 Error responses

| HTTP | Exception | Message key | Khi nào | Marker |
|---|---|---|---|---|
| 400 | `BadRequestException` | (validation map) | Bean validation fail (field-level, gồm thiếu `meisaiTemplateId`/`updateVersion`) | ↔️ |
| 404 | `NotFoundException` | `E041` | Bản ghi không tồn tại / không phải owner / đã xóa | ↔️ |
| 400 | `BadRequestException` | `E157` | mode 1/5: keihiKamoku có `ryoshushoSentakuKanousei=0` | ↔️ |
| 400 | `BadRequestException` | `E040` | trùng tên template (scope per-user, khác chính nó) | ↔️ |
| 400 | `BadRequestException` | 🆕 `bad_request` | mode 5/6 mà `TmKaisha.gaikaRiyoUmu != 1` | 🆕 (TBD-U2 RESOLVED) |
| 404/400 | `NotFoundException`/`BadRequestException` | `E041` | FK không tồn tại (project/busho/kamoku/zeikubun/jugyoin) | ↔️ |
| 400 | `BadRequestException` | (validation) | 🆕 mode 5 thiếu field ngoại tệ; hoặc mode 1/2/4/6 gửi field ngoại tệ ≠ null | 🆕 |
| 409/400 | optimistic lock (`ObjectOptimisticLockingFailureException`) | — | `updateVersion` không khớp DB (`@Version`) | ↔️ |
| 403 | `ForbiddenException` | — | Role không hợp lệ | ↔️ |
| 401 | `UnAuthorizedException` | — | Token thiếu/invalid | ↔️ |
| 500 | `InternalServerErrorException` | — | System error → rollback | ↔️ |

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal call order)

```
MeisaiTemplateApiController.updateMeisaiTemplate(MeisaiTemplate)
  └─> MeisaiTemplateApiDelegateImpl.updateMeisaiTemplate(req)   ↔️
        - BeanUtil.copyProperties(dto, req)                     (+4 field tự copy theo tên)
        └─> MeisaiTemplateUseCase.update(dto)
              └─> MeisaiTemplateService.update(dto)  @Transactional
                    1. checkRolesAllow()                        → 403          ↔️
                    2. findMeisaiTemplate...(hojinCode, id, loginJugyoinId, deleteFlag=0)
                       existence == null → NotFoundException E041 → 404         ↔️
                    3. 🆕 checkGaikaSettingIfNeeded(dto)          → 400 (mode 5/6 & gaikaRiyoUmu≠1)
                    4. branch theo torokuHoho CỦA BẢN GHI CŨ (existence):
                       - "1" RECEIPT_RYOSYUSHO → (E157 check) updateForRyoshusho  ↔️
                       - "4" ROUTE_KEIRO_API   → updateForKeiroApi                ↔️
                       - "2" ROUTE_KEIRO       → nếu dto đổi sang "4" thì updateForKeiroApi; else validate GroupKeiro ↔️
                       - 🆕 "5" RECEIPT_GAIKA  → (E157 check) updateForGaikaRyoshusho (validate GroupRyoshusho+GroupGaika+GroupUpdate)
                       - 🆕 "6" GAIKA_RATE_SHOMEISHO → updateForRateShomeisho (validate GroupRyoshusho+GroupUpdate; KHÔNG gaika/sankasha)
                       - else → return (no-op)                  ↔️ (giữ behaviour cũ)
                    5. addLogDataOwnerId + koshinRireki (TM031, diff existence↔dto)  ↔️
                    6. blindData(dto, existence)  ✏️ +copy 4 field mới (gaika + sankasha)
                    7. 🆕 normalizeFieldsByMode(existence) (clear field không thuộc mode — §4.3)
                    8. meisaiTemplateCrud.save(existence)        ↔️ (@Version tự kiểm tra updateVersion)
        - ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I002"))
```

**Nhấn mạnh điểm dễ sai**:
- ✏️ Branch update rẽ theo **mode của BẢN GHI CŨ** (`existence.getTorokuHoho()`), KHÁC với `add()` (rẽ theo dto). Vì vậy
  case 5/6 phải thêm vào nhánh đọc `existence.getTorokuHoho()`. Nếu chỉ thêm vào `add()` mà quên `update()` → sửa template mode 5/6 sẽ rơi vào `else → return` (no-op, "thành công giả", không lưu thay đổi).
- ✏️ **`blindData()` whitelist field** — phải bổ sung copy `gaikaShuruiId`, `rate`, `enKansanKingaku`, `sankashaTemplateId`
  từ dto sang `existence`. Nếu quên → 4 field mới KHÔNG bao giờ được update (giữ giá trị cũ).
- 🆕 `sankashaTemplateId` chỉ giữ khi mode ∈ {1,5}; mode {2,4,6} phải set NULL (clarification 6.7) → `normalizeFieldsByMode`.
- 🆕 `enKansanKingaku` **BE không tính** — lưu nguyên giá trị FE gửi (clarification 6.3).
- ↔️ **Update KHÔNG check 制限値 (seigen)** — khác `add()`. Update không làm tăng số lượng template nên bỏ qua đếm giới hạn (giữ đúng pattern `updateForRyoshusho` hiện tại).

### 4.2 Validation chi tiết

**Cấp field** (Bean Validation trên `MeisaiTemplateDto`):
- ✏️ `torokuHoho`: `@EnumNamePattern("1|2|4|5|6")` (đổi từ `1|2|4`) — **dùng chung DTO với ADD, đã sửa ở phase ADD**.
- ✏️ `meisaiTemplateId`, `updateVersion`: `@NotNull(groups = GroupUpdate.class)`.
- 🆕 `gaikaShuruiId`/`rate`/`enKansanKingaku`/`sankashaTemplateId`: như [API ADD §4.2](../meisai-template-add/detail_design.md) — **dùng chung DTO, đã thêm ở phase ADD**.

**Cấp business** (Service layer):
- 🆕 **Group ngoại tệ** (`GroupGaika`, áp khi mode 5 + `GroupUpdate`): `gaikaShuruiId`, `kingaku`, `rate`, `enKansanKingaku` đều REQUIRED.
- 🆕 Setting check: mode {5,6} → `TmKaisha.gaikaRiyoUmu` phải = `1`. (Reuse helper `checkGaikaSettingIfNeeded` từ phase ADD — TBD-U2 RESOLVED.)
- ↔️ E157 (keihiKamoku `ryoshushoSentakuKanousei=0`) áp cho mode 1 và 🆕 mode 5 (cùng họ 領収書). Reuse helper `checkRyoshushoKeihiKamoku`.
- ↔️ checkExistenceOfIds (project/busho/keihiKamoku/kanjo/hojo/jugyoin/zeikubun) — qua `bussinessValidation`.
- ↔️ Trùng tên: scope `(hojinCode, jugyoinId)`, **bỏ qua chính nó** (cùng `meisaiTemplateId`) → E040.

### 4.3 Conditional rule theo mode (🆕 — giống ADD §4.3)

| torokuHoho | Field REQUIRED | Field PHẢI NULL (clear trước save) | sankashaTemplateId | enKansanKingaku |
|---|---|---|---|---|
| `1` 領収書 | (như current) | gaika fields (gaikaShuruiId, rate, enKansanKingaku) | cho phép | NULL |
| `5` 領収書(外貨) | `gaikaShuruiId`, `kingaku`(外貨), `rate`, `enKansanKingaku` | — | cho phép | = FE gửi (yên) |
| `6` レート証明書 | (như 領収書 1) | `gaikaShuruiId`,`rate`,`enKansanKingaku`, `sankashaTemplateId` | NULL | NULL |
| `2`/`4` keiro | (như current) | gaika + sankasha | NULL | NULL |

> `normalizeFieldsByMode()` (đã viết ở phase ADD) áp y nguyên cho `existence` dto sau `blindData()`.

### 4.4 Unique check (↔️ giữ nguyên — bỏ qua chính nó)
```sql
SELECT 1 FROM keihi_com.tm_meisai_template
WHERE hojin_code = ? AND jugyoin_id = ? AND meisai_template_mei = ? AND delete_flag = 0
```
→ Tìm thấy row có `meisai_template_id` **KHÁC** dto → `BadRequestException("E040", ...)`.
→ Tìm thấy row trùng `meisai_template_id` (chính nó) → OK. Scope **per-user**. (Hàm `validation()` hiện có đã xử lý.)

### 4.5 Optimistic lock (↔️)
- `existence.setUpdateVersion(dto.getUpdateVersion())` trong `blindData()`; khi `save()`, `@Version` của JPA so sánh với DB.
- Version không khớp → `ObjectOptimisticLockingFailureException` → rollback toàn transaction.

---

## 5. Database Operations

### 5.1 Bảng update
| Bảng | Schema | Số rows | Note |
|---|---|---|---|
| `tm_meisai_template` | `keihi_com` | 1 | UPDATE 1 row theo `meisai_template_id`; +4 cột mới (final_spec §5.1) |
| `tr_keiro_*` (mode 4) | — | ↔️ | chỉ mode keiro API: xóa keiro cũ + tạo keiro mới (current) |

> 🆕 Mode 5/6 KHÔNG tạo/sửa keiro info. Chỉ UPDATE 1 row template.

### 5.2 Transaction
- ↔️ Toàn bộ trong 1 `@Transactional` (method `update`). Rollback nếu fail (gồm cả optimistic lock).

### 5.3 ID Generation
- ↔️ **Không generate ID mới** (update bản ghi sẵn có). koshin rireki dùng tableName `TM031` (current_analysis §9.6 — giữ nguyên).

### 5.4 Audit fields (↔️ tự động)
| Field | Value | Cơ chế |
|---|---|---|
| `upd_date` | now() | `@LastModifiedDate` (AuditingEntityListener) |
| `upd_userid` | login user | `@LastModifiedBy` |
| `add_date`/`add_userid` | giữ nguyên | không động tới khi update |
| `update_version` | += 1 (tự động qua `@Version` sau khi match) | JPA |
| 🆕 `rate` | nếu null & mode 5 → (FE gửi); DB default `1.0` | — |

---

## 6. Class & File Structure (đã tồn tại — chỉ EXTEND)

| Layer | Class | Path | Thay đổi |
|---|---|---|---|
| Delegate | `MeisaiTemplateApiDelegateImpl` | `adapter/in/api/delegate/` | ↔️ (BeanUtil tự copy 4 field mới) |
| API model | `MeisaiTemplate` | `adapter/in/api/model/` | ↔️ (đã +4 field ở phase ADD) |
| Input port | `MeisaiTemplateUseCase` | `application/port/in/` | ↔️ signature `update` không đổi |
| Service | `MeisaiTemplateService` | `application/service/` | ✏️ `update()` +branch 5/6, +setting check; ✏️ `blindData()` +4 field; +`updateForGaikaRyoshusho`/`updateForRateShomeisho` |
| Output port | `MeisaiTemplateCrud` | `application/port/out/` | ↔️ |
| Adapter | `MeisaiTemplateAdapter` | `adapter/out/persistence/db/` | ↔️ (BeanUtil copy entity↔dto đã gồm 4 field) |
| Entity | `TmMeisaiTemplate` | `.../entity/` | ↔️ (đã +4 field ở phase ADD) |
| Repository | `TmMeisaiTemplateRepository` | `.../repository/` | ↔️ |
| Domain DTO | `MeisaiTemplateDto` | `application/domain/` | ↔️ (đã +4 field, regex, GroupGaika ở phase ADD) |
| Bean config | `BeanConfiguration` (method `meisaiTemplateUseCase()`) | `adapter/out/configuration/` | ↔️ (`KaishaCrud` đã inject ở phase ADD) |

> ✅ Phần lớn hạ tầng (DTO, Entity, API model, GroupGaika, KaishaCrud inject, helper `checkGaikaSettingIfNeeded`/
> `checkRyoshushoKeihiKamoku`/`normalizeFieldsByMode`) **đã làm xong ở phase ADD**. Phase UPDATE chỉ EXTEND `update()` + `blindData()`.

### 6.1 Sửa cụ thể trong `MeisaiTemplateService` (phase UPDATE)

```java
// update(): thêm setting check + 2 branch mới (đọc existence.getTorokuHoho())
checkGaikaSettingIfNeeded(meisaiTemplateDto);          // 🆕 reuse từ ADD
...
} else if (TorokuHoho.RECEIPT_GAIKA.getValue().equals(existenceMeisaiTemplateDto.getTorokuHoho())) {
  checkRyoshushoKeihiKamoku(meisaiTemplateDto);        // 🆕 reuse từ ADD (E157)
  updateForGaikaRyoshusho(meisaiTemplateDto);
} else if (TorokuHoho.GAIKA_RATE_SHOMEISHO.getValue().equals(existenceMeisaiTemplateDto.getTorokuHoho())) {
  updateForRateShomeisho(meisaiTemplateDto);
}

// 🆕 method mới
private void updateForGaikaRyoshusho(final MeisaiTemplateDto dto) {
  bussinessValidation(dto, Default.class, GroupRyoshusho.class, GroupGaika.class, GroupUpdate.class);
}
private void updateForRateShomeisho(final MeisaiTemplateDto dto) {
  bussinessValidation(dto, Default.class, GroupRyoshusho.class, GroupUpdate.class);
}

// blindData(): bổ sung copy 4 field + normalize cuối hàm
existence.setGaikaShuruiId(dto.getGaikaShuruiId());
existence.setRate(dto.getRate());
existence.setEnKansanKingaku(dto.getEnKansanKingaku());
existence.setSankashaTemplateId(dto.getSankashaTemplateId());
// ... (cuối update(), sau blindData) ...
normalizeFieldsByMode(existenceMeisaiTemplateDto);    // 🆕 reuse từ ADD
```

---

## 7. OpenAPI Definition

> ↔️ Schema `MeisaiTemplate` đã được bổ sung 4 field ở phase ADD ([API ADD §7](../meisai-template-add/detail_design.md)).
> Endpoint UPDATE (`PUT /meisaiTemplate`) đã tồn tại — KHÔNG đổi contract path/response.
> ⚠️ Endpoint `MeisaiTemplate` KHÔNG nằm trong `openapi.yml` đang track (TBD chung) — nếu là model gen tay thì không cần re-gen.

Không có thay đổi OpenAPI riêng cho phase UPDATE (chỉ reuse schema đã mở rộng).

---

## 8. Test Cases

### 8.1 Unit test (Service.update)

| # | Test case | Expected | Marker |
|---|---|---|---|
| 1 | mode 1 update happy (như current) | 200, I002 | ↔️ |
| 2 | 🆕 mode 5 update happy (đủ 4 field gaika + sankasha) | 200, lưu kingaku=ngoại tệ, enKansanKingaku=yên, sankashaTemplateId set | 🆕 |
| 3 | 🆕 mode 5 update thiếu `gaikaShuruiId`/`rate`/`enKansanKingaku` | 400 (group gaika) | 🆕 |
| 4 | 🆕 mode 5/6 update nhưng `gaikaRiyoUmu=0` | 400 (gaika disabled) | 🆕 |
| 5 | 🆕 mode 6 update happy (kingaku=yên, gaika fields null, sankasha null) | 200, enKansanKingaku=NULL | 🆕 |
| 6 | 🆕 mode 6 update gửi kèm `gaikaShuruiId`/`sankashaTemplateId` ≠ null | 200, bị clear về NULL (normalize) | 🆕 |
| 7 | mode 5: bản ghi không tồn tại / không phải owner | 404 E041 | ↔️ |
| 8 | `updateVersion` sai (optimistic lock) | 409/400 (lock conflict) | ↔️ |
| 9 | thiếu `meisaiTemplateId`/`updateVersion` | 400 (GroupUpdate) | ↔️ |
| 10 | đổi tên trùng template khác (per-user) | 400 E040 | ↔️ |
| 11 | đổi tên giữ nguyên / trùng chính nó | 200 (OK) | ↔️ |
| 12 | role không hợp lệ | 403 | ↔️ |
| 13 | keihiKamoku ryoshushoSentakuKanousei=0 (mode 1/5) | 400 E157 | ↔️ |
| 14 | ✏️ torokuHoho="3" (日当) | 400 (regex không nhận) | ✏️ |

### 8.2 Integration test
- Full flow Controller → DB; verify 4 cột mới persist đúng theo mode sau update.
- Verify `jugyoinId`/`hojinCode` KHÔNG bị đổi qua update (blindData whitelist).
- Verify mode 5/6 bị chặn khi `gaikaRiyoUmu=0`.
- Verify optimistic lock: 2 request đồng thời cùng version → 1 thành công, 1 fail rollback.
- Verify chuyển field cũ→mới khi đổi giá trị (vd mode 5 đổi rate → enKansanKingaku update theo FE gửi).

---

## 9. Open Issues / TBD

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| U1 | Cho phép **đổi `torokuHoho`** khi update giữa các họ mode không? (vd 1→5, 5→6) | **Giữ pattern hiện tại**: branch theo mode BẢN GHI CŨ (`existence`). Giả định FE KHÔNG đổi loại template khi edit trong họ ngoại tệ (mode 5/6 cố định khi tạo). Nếu cho đổi → cần xử lý migrate field (như keiro→keiroApi) — out of scope phase này | Medium | current_analysis §5.3 / clarification 6.x |
| U2 | ✅ **RESOLVED** — Setting check exception/message | Reuse `checkGaikaSettingIfNeeded` (phase ADD) → `BadRequestException(MessageUtil.getMessage("bad_request"))`, mirror `MeisaiJohoService` | ~~Medium~~ RESOLVED | API ADD §9 C2 |
| U3 | E157 cho mode 6 (レート証明書)? | **Không áp** (chỉ mode 1/5 — cùng họ 領収書 chọn được). Mode 6 ≈ 領収書 về data nhưng không check ryoshushoSentakuKanousei (theo final_spec §4.2) | Low | API ADD §4.2 |
| U4 | C4 cascade BLOCK xóa sankasha | **KHÔNG ảnh hưởng API update** (chỉ ảnh hưởng sankasha-template-delete/bulk-delete). Update chỉ tham chiếu `sankashaTemplateId`, không validate tồn tại sankasha (reference only) | Low (resolved scope) | API ADD §9 C4 |

**Severity legend**: High = schema/contract; Medium = handler/logic; Low = constant/config.

---

## 10. References
- API ADD (anh em, đã implement): [`../meisai-template-add/detail_design.md`](../meisai-template-add/detail_design.md) (v1.0.1)
- final_spec: [`../../final_spec.md`](../../final_spec.md) (v1.1.0) — §3 (fields), §4 (rules), §5 (schema), §6 (API)
- clarifications: [`../../clarifications.md`](../../clarifications.md) (v1.1.0) — 6.2, 6.3, 6.6, 6.7, 6.8, 6.11
- baseline: [`../../current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.3 (update flow), §5.6 (unique), §9 (limitation)
- DB design: `db_tables_application_rules_meeting_expenses.xlsx`, sheet `tm_meisai_template`
- Reference impl (đã đọc): `application/service/MeisaiTemplateService.java` (method `update`, `blindData`, `updateForRyoshusho`),
  helper phase ADD (`checkGaikaSettingIfNeeded`, `checkRyoshushoKeihiKamoku`, `normalizeFieldsByMode`)
- Setting: `TmKaisha.gaikaRiyoUmu` (0/1) · GaikaShurui master: `TableCode.TM057`

---

## Version History

### [1.0.0] - 2026-06-05
- Initial detail design cho API UPDATE MeisaiTemplate (phase EXTEND).
- Dựa trên final_spec v1.1.0 + clarifications v1.1.0 (12/12 answered) + current_analysis v1.0.0 §5.3.
- Dựa trên API ADD detail_design v1.0.1 (đã implement) — reuse helper + DTO/Entity/model đã mở rộng.
- Scope: `update()` +branch mode 5/6 (đọc existence mode), +setting check, `blindData()` +4 field, +normalize.
- Nhấn mạnh: update branch theo mode BẢN GHI CŨ; KHÔNG check seigen; optimistic lock qua `@Version`.
- 4 TBD (0 High, 1 Medium, 3 Low/resolved) — xem §9.
