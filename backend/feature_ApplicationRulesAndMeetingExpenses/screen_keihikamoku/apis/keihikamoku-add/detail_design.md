---
version: 1.0.0
status: draft
last_updated: 2026-06-08
api_name: addKeihiKamoku
http_method: POST
endpoint: /keihi-kamoku
based_on_final_spec_version: 1.0.0
mode: EXTEND
based_on_current_analysis_version: 1.0.0
---

> 📘 **EXTEND** — Detail design cho API `addKeihiKamoku` (POST /keihi-kamoku).
> - API NÀY ĐÃ TỒN TẠI (`KeihiKamokuApiDelegateImp.addKeihiKamoku` → `KeihiKamokuService.addKeihiKamoku`). File này CHỈ mô tả phần thay đổi.
> - Baseline: [`current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.2.
> - Cross-reference cấp màn: [`final_spec.md`](../../final_spec.md) (v1.0.0).
> - Ký hiệu: 🆕 NEW · ✏️ MODIFIED · ↔️ UNCHANGED.

# Detail Design — API addKeihiKamoku (経費科目 登録)

## 1. Tổng quan API

| Item | Value |
|---|---|
| API name | addKeihiKamoku |
| HTTP method | POST |
| Endpoint | /keihi-kamoku |
| Mục đích | Thêm mới 1 mục chi phí (経費科目) |
| Caller | FE màn 経費科目詳細 (modal 新規登録) |
| Role được phép | `DEPARTMENT_MANAGEMENT (5)`, `SUPER_ADMIN (6)` ↔️ |
| Mode | EXTEND |
| Success message | `I001` ↔️ |

**Scope thay đổi (EXTEND)**:
- 🆕 Request nhận thêm **8 field** "参加者入力 / 会議費".
- 🆕 Thêm default + 1 business validation mới (`checkHitoriAtariJogen`) cho cờ 一人当たり上限.
- ↔️ Toàn bộ flow add hiện tại (role check, duplicate name, FK check, jogenKingaku/kakoNissu check, log KoshinRireki) **giữ nguyên**.

---

## 2. Request

### 2.1 HTTP Request
```
POST /api/v1/keihi-kamoku HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT>
```

### 2.2 Request Body schema

> ↔️ Field hiện hành giữ nguyên — xem [current_analysis §3](../../current_state/current_analysis.md).
> Dưới đây CHỈ liệt kê field 🆕/✏️.

#### 2.2.1 ↔️ Field UNCHANGED (tổng kết)
Giữ nguyên toàn bộ field cũ: `keihiKamokuName`, `code`, `karikataKanjokamoku`, `hojoKamoku`, `kashikataKanjoKamoku`, `kashikataHojoKamoku`, `tokureiKubunFlag`, `zeikubun`, `tekikakuIgaiZeikubun`, `tokureiZeikubun`, `riyoJotai`, `hyojiJun`, 5 cờ `*SentakuKanousei`, `kashikataKamokuSentakuKanousei`, `zeikubunSentakuKanousei`, 7 cờ check (`ryoshushoTempuCheck`, `memoCheck`, `hiyoFutanBushoCheck`, `projectCheck`, `kingakuJogenCheck`+`jogenKingaku`, `shinseiKakobiCheck`+`kakoNissu`, `rateNyuryokuCheck`).

#### 2.2.2 ✏️ Field MODIFIED
Không có field request nào đổi behaviour.

#### 2.2.3 🆕 Field NEW

| Field (JSON) | Type | Required | Constraint | Mô tả | Map → DB |
|---|---|---|---|---|---|
| `sankashaNyuryokuHitsuyoFlag` | Integer | No (default 0) | `@EnumNamePattern("^(0\|1)$")` | Mục chi phí cần nhập người tham gia (master toggle) | `sankasha_nyuryoku_hitsuyo_flag` |
| `hitoriAtariJogenKingaku` | BigInteger | No (xem §4.2) | `@Range(min=0, max=99999)` (5 chữ số — Q6.1) | Số tiền tối đa/người. Trống = không limit | `hitori_atari_jogen_kingaku` |
| `hitoriAtariJogenCheckKubun` | Integer | No (default 0) | giá trị ∈ `CheckFlag` {0,1,2} | Loại xử lý khi vượt: 0:無し,1:エラー,2:アラート | `hitori_atari_jogen_check_kubun` |
| `hitoriAtariJogenMessage` | String | No | `@Size(max=1000)` | Message khi vượt limit (optional) | `hitori_atari_jogen_message` |
| `tashaSankashaNyuryokuFlag` | Integer | No (default 0) | `@EnumNamePattern("^(0\|1)$")` | Bật field người tham gia đối tác | `tasha_sankasha_nyuryoku_flag` |
| `tashaSankashaHissuFlag` | Integer | No (default 0) | `@EnumNamePattern("^(0\|1)$")` | Bắt buộc nhập field đối tác | `tasha_sankasha_hissu_flag` |
| `jishaSankashaSentakuFlag` | Integer | No (default 0) | `@EnumNamePattern("^(0\|1)$")` | Bật chọn người tham gia nội bộ | `jisha_sankasha_sentaku_flag` |
| `jishaSankashaHissuFlag` | Integer | No (default 0) | `@EnumNamePattern("^(0\|1)$")` | Bắt buộc chọn người tham gia nội bộ | `jisha_sankasha_hissu_flag` |

> Annotation áp dụng nhất quán với các cờ hiện có trong `KeihiKamokuDto` (vd `tokureiKubunFlag` dùng `@EnumNamePattern("^(0|1)$")`; `kingakuJogenCheck` validate giá trị business). Tất cả thêm `@LogOperation` (audit) theo pattern các field cũ.

### 2.3 Example request
Xem [`request_examples.json`](./request_examples.json).

---

## 3. Response

### 3.1 Success — HTTP 200
```json
{
  "code": 0,
  "message": "<I001 message>"
}
```
↔️ Response shape giữ nguyên (`ModelApiResponse` qua `ApiUtil.makeSimpleResponse`). KHÔNG trả về body record.

### 3.2 Error responses

| HTTP | Exception | Message key | Khi nào | Marker |
|---|---|---|---|---|
| 403 | `ForbiddenException` | (role) | Role không phải 5/6 | ↔️ |
| 400 | `BadRequestException` | `E040` | Trùng `keihiKamokuName` | ↔️ |
| 400 | `BadRequestException` | `E037` | FK (zeikubun/勘定科目/補助科目) không tồn tại hoặc sai loại | ↔️ |
| 400 | `BadRequestException` | `E053` | Giá trị cờ check không ∈ CheckFlag | ↔️ |
| 400 | `BadRequestException` | `E005` | `jogenKingaku`/`kakoNissu` thiếu khi check=Error/Alert | ↔️ |
| 400 | `BadRequestException` | `E005` | 🆕 `hitoriAtariJogenKingaku` thiếu/≤0 khi `hitoriAtariJogenCheckKubun` ∈ {1,2} | 🆕 |
| 400 | `BadRequestException` | `bad_request` (E002/E004/E050...) | Bean Validation fail (gồm 8 field mới) | ✏️ (mở rộng) |
| 500 | `InternalServerErrorException` | (internal) | `IOException` khi save | ↔️ |

> 🆕 Reuse key `E005` (field required) cho `hitoriAtariJogenKingaku` — nhất quán với `checkJogenKingaku` hiện tại. Field name message key: cần thêm `KeihiKamokuDto.hitoriAtariJogenKingaku` (xem §9 TBD-A).

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal call order)

```
Controller -> KeihiKamokuApiDelegateImp.addKeihiKamoku -> KeihiKamokuUseCase.addKeihiKamoku
  -> KeihiKamokuService.addKeihiKamoku  @Transactional
   1. RoleUtil.check(DEPARTMENT_MANAGEMENT, SUPER_ADMIN)            [↔️ existing]
   2. copy request -> dto; set hojinCode, deleteFlag=0,
      updateVersion=DEFAULT, id=generateId(TM028)                  [↔️ existing]
   3. set default field cũ (hyojiJun, hyojunKamokuUmu, doki, 5 cờ
      sentaku, rateNyuryokuCheck, tokureiKubunFlag, ...)            [↔️ existing]
   3b. 🆕 set default 8 field mới nếu null (= 0)                    [🆕 NEW]
   4. checkDuplicateName(name, null)                               [↔️ existing]
   5. checkFlagKeihiKamoku(dto)                                    [↔️ existing]
   6. checkForeignKey(dto)                                         [↔️ existing]
   7. checkJogenKingaku(dto, kingakuJogenCheck, jogenKingaku)      [↔️ existing]
   8. checkKakoNissu(dto, shinseiKakobiCheck, kakoNissu)           [↔️ existing]
   8b. 🆕 checkHitoriAtariJogen(dto, checkKubun, kingaku)          [🆕 NEW]
   9. validator.validate(dto) -> BadRequest nếu lỗi               [↔️ existing, gồm 8 field mới]
  10. keihiKamokuCrud.saveKeihiKamoku(dto)                         [↔️ existing]
  11. addLogDataOwnerId + koshinRirekiUseCase.addKoshinRireki      [↔️ existing]
```

**Pseudo-code step 3b + 8b (🆕)**:
```java
// 3b. Default 8 field mới (theo final_spec §4.1, default 0)
if (dto.getSankashaNyuryokuHitsuyoFlag() == null) {
    dto.setSankashaNyuryokuHitsuyoFlag(AriNashiUmu.NO.getValue());      // 0
}
if (dto.getHitoriAtariJogenCheckKubun() == null) {
    dto.setHitoriAtariJogenCheckKubun(CheckFlag.NONE.getValue());       // 0
}
if (dto.getTashaSankashaNyuryokuFlag() == null) {
    dto.setTashaSankashaNyuryokuFlag(AriNashiUmu.NO.getValue());
}
if (dto.getTashaSankashaHissuFlag() == null) {
    dto.setTashaSankashaHissuFlag(AriNashiUmu.NO.getValue());
}
if (dto.getJishaSankashaSentakuFlag() == null) {
    dto.setJishaSankashaSentakuFlag(AriNashiUmu.NO.getValue());
}
if (dto.getJishaSankashaHissuFlag() == null) {
    dto.setJishaSankashaHissuFlag(AriNashiUmu.NO.getValue());
}

// 8b. Validate 一人当たり上限 (pattern giống checkJogenKingaku)
private void checkHitoriAtariJogen(final KeihiKamokuDto dto,
        final Integer checkKubun, final BigInteger kingaku) {
    if (CheckFlag.ERROR.getValue().equals(checkKubun)
            || CheckFlag.ALERT.getValue().equals(checkKubun)) {
        // Error/Alert -> kingaku bắt buộc > 0
        if (kingaku == null || kingaku.compareTo(BigInteger.ZERO) <= 0) {
            throw new BadRequestException(MessageFormat.format(
                MessageUtil.getMessage("E005"),
                MessageUtil.getMessage("KeihiKamokuDto.hitoriAtariJogenKingaku")));
        }
        dto.setHitoriAtariJogenKingaku(kingaku);
    } else {
        // 無し(0) -> reset kingaku về null (message giữ theo client, optional)
        dto.setHitoriAtariJogenKingaku(null);
    }
}
```

**Nhấn mạnh điểm dễ sai**:
- 🆕 `checkHitoriAtariJogen` đặt SAU `checkKakoNissu`, TRƯỚC `validator.validate`.
- ↔️ Adapter `saveKeihiKamoku` vẫn ép 3 field 出席者 cũ = 0 — KHÔNG đụng (Q6.5). 8 field mới copy bình thường qua `BeanUtil.copyProperties`.
- 🆕 KHÔNG validate ràng buộc `hissu` phụ thuộc `nyuryoku/sentaku` ở BE (Q6.4 — chỉ FE disable).

### 4.2 Validation chi tiết

**Cấp field (Bean Validation trên `KeihiKamokuDto`)** — 🆕:
- `hitoriAtariJogenKingaku`: `@Range(min=0, max=99999)` message `{E004}` (Q6.1 — 5 chữ số).
- `hitoriAtariJogenMessage`: `@Size(max=1000)` message `{E002}`.
- 6 cờ flag: `@EnumNamePattern("^(0|1)$")` message `{bad_request}`.
- `hitoriAtariJogenCheckKubun`: không Bean Validation cứng (cho 0/1/2) — kiểm ở business nếu cần (hiện reuse logic checkKubun).

**Cấp business (Service)** — 🆕:
- Nếu `hitoriAtariJogenCheckKubun` ∈ {1=エラー, 2=アラート} → `hitoriAtariJogenKingaku` phải > 0 (E005). Ngược lại reset kingaku=null.
- `hitoriAtariJogenCheckKubun` cho phép = 0 kể cả khi `sankashaNyuryokuHitsuyoFlag`=1 (Q6.2 — KHÔNG ép chọn Error/Alert).

### 4.3 Conditional rule theo flag (🆕)

| `hitoriAtariJogenCheckKubun` | `hitoriAtariJogenKingaku` | `hitoriAtariJogenMessage` |
|---|---|---|
| 0 (無し) | reset null (không bắt buộc) | optional |
| 1 (エラー) | **bắt buộc > 0** | optional |
| 2 (アラート) | **bắt buộc > 0** | optional |

> `sankashaNyuryokuHitsuyoFlag`=0/1 KHÔNG ép buộc các field con ở BE khi ADD (Q6.3 — giữ giá trị client gửi). FE chịu trách nhiệm disable.

### 4.4 Unique check
↔️ `checkDuplicateName` — scope `(hojinCode, keihiKamokuName)` qua `findKeihiKamokuByName`, lỗi `E040`. Không đổi.

### 4.5 Defensive coding (🆕)
```java
// Chỉ clear kingaku khi check_kubun = 0 (xem checkHitoriAtariJogen).
// KHÔNG auto-clear các cờ con dựa trên master flag (Q6.3 giữ nguyên giá trị client).
// 8 field mới: nếu client KHÔNG gửi -> default 0 (step 3b), không để null xuống DB
// (cột NOT NULL trừ kingaku & message).
```

---

## 5. Database Operations

### 5.1 Bảng đụng tới
| Bảng | Schema | Operation | Số rows | Note |
|---|---|---|---|---|
| `tm_keihi_kamoku` | keihi_com | INSERT | 1 | ✏️ +8 cột mới |
| `tm_kanjo_kamoku`, `tm_hojo_kamoku`, `tm_zeikubun` | keihi_com | SELECT | n | ↔️ FK existence check |
| (KoshinRireki log) | — | INSERT | 1 | ↔️ audit log |

### 5.2 Transaction
↔️ `@Transactional` trên `addKeihiKamoku` — không đổi.

### 5.3 ID Generation
↔️ `SqlUtil.generateId(TableCode.TM028, hojinCode)`.

### 5.4 Audit fields
↔️ Tự động qua `AuditingEntityListener`.

### 5.5 Cross-resource DB operation
**Không có** — API add chỉ ghi `tm_keihi_kamoku` (đọc FK master). Behaviour cross-screen chỉ phát sinh ở phía màn meisai (đọc cờ này khi tạo明細 — xem final_spec §8), KHÔNG ở API này.

---

## 6. Class & File Structure (UPDATE — API đã tồn tại)

| Layer | Class | Path | Thay đổi |
|---|---|---|---|
| Liquibase | `tm_keihi_kamoku.xml` | `backend/.../liquibase/init/keihi_com/` | ✅ ĐÃ thêm changeset `20260608_..._add_column_sankasha` (8 cột) |
| Entity | `TmKeihiKamoku` | `adapter/out/persistence/db/entity/` | 🆕 Thêm 8 field (camelCase + comment JP) |
| DTO | `KeihiKamokuDto` | `application/domain/` | 🆕 Thêm 8 field + validation + `@LogOperation` |
| API model | `KeihiKamoku` | `adapter/in/api/model/` | 🆕 Thêm 8 field **bằng tay** (Q6.9) |
| Service | `KeihiKamokuService` | `application/service/` | ✏️ UPDATE `addKeihiKamoku`: step 3b default + 8b `checkHitoriAtariJogen`. 🆕 thêm private method `checkHitoriAtariJogen` |
| Adapter | `KeihiKamokuAdapter` | `adapter/out/persistence/db/` | ↔️ `saveKeihiKamoku` không đổi logic (BeanUtil copy tự bắt 8 field; vẫn ép 3 field 出席者 cũ = 0) |
| Delegate | `KeihiKamokuApiDelegateImp` | `adapter/in/api/delegate/` | ↔️ `addKeihiKamoku` không đổi (BeanUtil.copyProperties tự map 8 field) |

**Dependency mới**: KHÔNG. Service giữ nguyên constructor inject (`KeihiKamokuCrud`, `KanjoKamokuCrud`, `HojoKamokuCrud`, `ZeikubunCrud`). `BeanConfiguration` KHÔNG đổi.

**Enum tái dùng**: `CheckFlag` (0/1/2) cho `hitoriAtariJogenCheckKubun`; `AriNashiUmu` (0/1) cho 6 cờ flag. KHÔNG cần enum mới.

---

## 7. OpenAPI Definition

> ⚠️ Endpoint `keihi-kamoku` KHÔNG nằm trong `api_interface_generate_tool/specification/openapi.yml` (model legacy gen 2021). Theo Q6.9 → **sửa class `KeihiKamoku.java` bằng tay**, không regenerate.

Field thêm vào model `KeihiKamoku` (tham khảo, dạng schema):
```yaml
KeihiKamoku:
  type: object
  properties:
    # ... field cũ giữ nguyên ...
    sankashaNyuryokuHitsuyoFlag: { type: integer, format: int32, default: 0 }
    hitoriAtariJogenKingaku:     { type: integer, format: int64 }   # BigInteger
    hitoriAtariJogenCheckKubun:  { type: integer, format: int32, default: 0 }
    hitoriAtariJogenMessage:     { type: string, maxLength: 1000 }
    tashaSankashaNyuryokuFlag:   { type: integer, format: int32, default: 0 }
    tashaSankashaHissuFlag:      { type: integer, format: int32, default: 0 }
    jishaSankashaSentakuFlag:    { type: integer, format: int32, default: 0 }
    jishaSankashaHissuFlag:      { type: integer, format: int32, default: 0 }
```

---

## 8. Test Cases

### 8.1 Unit test

| # | Test case | Expected | Marker |
|---|---|---|---|
| 1 | Add đầy đủ field cũ, KHÔNG gửi 8 field mới | Success; 8 cột = 0/null default | Regression |
| 2 | Add với `sankashaNyuryokuHitsuyoFlag=1`, các cờ con hợp lệ | Success, lưu đúng | New |
| 3 | `hitoriAtariJogenCheckKubun=1` + `hitoriAtariJogenKingaku=10000` | Success | New |
| 4 | `hitoriAtariJogenCheckKubun=1` + kingaku null/0 | 400 `E005` | New |
| 5 | `hitoriAtariJogenCheckKubun=2` + kingaku=5000 | Success | New |
| 6 | `hitoriAtariJogenCheckKubun=0` + kingaku=8000 | Success; kingaku **reset null** | Defensive |
| 7 | `hitoriAtariJogenKingaku=100000` (6 chữ số) | 400 `E004` (max 99999) | Validation fail |
| 8 | `hitoriAtariJogenMessage` > 1000 ký tự | 400 `E002` | Validation fail |
| 9 | Cờ flag gửi giá trị `2` (ngoài 0/1) | 400 `bad_request` | Validation fail |
| 10 | `tashaSankashaHissuFlag=1` nhưng `tashaSankashaNyuryokuFlag=0` | **Success** (BE không chặn — Q6.4) | New (backward) |
| 11 | Role = REGISTRATION (3) | 403 Forbidden | Role fail |
| 12 | Trùng `keihiKamokuName` | 400 `E040` | Regression |
| 13 | `karikataKanjokamoku` không tồn tại | 400 `E037` | Regression |
| 14 | Client gửi 8 field mới với mục chi phí thường (sankasha flag=0) | Success; lưu nguyên giá trị (Q6.3 không clear) | Defensive |

### 8.2 Integration test
- Full flow POST /keihi-kamoku → INSERT `tm_keihi_kamoku` với 8 cột; verify default cho row không gửi field mới (regression).
- Verify KoshinRireki ghi log đủ 8 field mới (Diffable).

---

## 9. Open Issues / TBD

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| A | Message key cho field `hitoriAtariJogenKingaku` (E005 cần `KeihiKamokuDto.hitoriAtariJogenKingaku`) | Thêm key vào messages properties theo pattern field cũ | 🟢 Low | convention §10 (i18n) |
| B | Có cần i18n label cho 8 field mới khi log KoshinRireki / CSV? | Thêm key `KeihiKamokuDto.<field>` cho mỗi field mới | 🟢 Low | final_spec §6 (CSV Q6.7) |
| C1 | Guard E152 khi tắt cờ sankasha (chủ yếu ở **update**, ít ảnh hưởng add) | Add không cần guard này | 🟡 Medium | final_spec §7 C1 / clarifications #6.6 |

> TBD C1 chủ yếu thuộc API update; với add không phát sinh (record mới chưa có meisai). Liệt kê để tracking.

---

## 10. References

- final_spec: [`../../final_spec.md`](../../final_spec.md) (v1.0.0) §3.2, §4.1, §4.2, §5
- clarifications: [`../../clarifications.md`](../../clarifications.md) (v1.0.0) — 6.1, 6.2, 6.3, 6.4, 6.5, 6.9
- baseline: [`../../current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.2 (add flow hiện tại)
- Reference impl hiện tại: `backend/.../application/service/KeihiKamokuService.java` method `addKeihiKamoku`, `checkJogenKingaku`, `checkKakoNissu`
- Convention: `.claude/rules/api-conventions.md`, `.claude/rules/database.md`

---

## Version History

### [1.0.0] - 2026-06-08

- Initial detail design cho API addKeihiKamoku (EXTEND).
- Dựa trên final_spec v1.0.0 + current_analysis v1.0.0.
- Scope: +8 field 参加者入力/会議費; +default step 3b; +business check `checkHitoriAtariJogen`.
- 3 TBD (0 High, 1 Medium, 2 Low).
