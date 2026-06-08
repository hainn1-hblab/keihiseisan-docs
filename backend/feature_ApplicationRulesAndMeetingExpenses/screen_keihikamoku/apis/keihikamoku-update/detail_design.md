---
version: 1.0.0
status: draft
last_updated: 2026-06-08
api_name: updateKeihiKamoku
http_method: PUT
endpoint: /keihi-kamoku
based_on_final_spec_version: 1.0.0
mode: EXTEND
based_on_current_analysis_version: 1.0.0
---

> 📘 **EXTEND** — Detail design cho API `updateKeihiKamoku` (PUT /keihi-kamoku).
> - API NÀY ĐÃ TỒN TẠI (`KeihiKamokuApiDelegateImp.updateKeihiKamoku` → `KeihiKamokuService.updateKeihiKamoku`). File này CHỈ mô tả phần thay đổi.
> - Baseline: [`current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.3.
> - Reference API cùng resource: [`../keihikamoku-add/detail_design.md`](../keihikamoku-add/detail_design.md) (8 field + checkHitoriAtariJogen dùng chung).
> - Cross-reference cấp màn: [`final_spec.md`](../../final_spec.md) (v1.0.0).
> - Ký hiệu: 🆕 NEW · ✏️ MODIFIED · ↔️ UNCHANGED.

# Detail Design — API updateKeihiKamoku (経費科目 更新)

## 1. Tổng quan API

| Item | Value |
|---|---|
| API name | updateKeihiKamoku |
| HTTP method | PUT |
| Endpoint | /keihi-kamoku |
| Mục đích | Cập nhật 1 mục chi phí (経費科目) |
| Caller | FE màn 経費科目詳細 (modal 編集) |
| Role được phép | `DEPARTMENT_MANAGEMENT (5)`, `SUPER_ADMIN (6)` ↔️ |
| Mode | EXTEND |
| Success message | `I002` ↔️ |

**Scope thay đổi (EXTEND)**:
- 🆕 Request nhận thêm **8 field** "参加者入力 / 会議費" (giống add).
- 🆕 Default + business validation `checkHitoriAtariJogen` (tái dùng method tạo ở API add).
- ✏️ Merge logic: 8 field mới từ request đè lên record hiện tại.
- ↔️ Toàn bộ guard update hiện tại (標準科目 đổi tên E084, đã xoá E041, E152 cho cờ 選択可能性, FK check, jogenKingaku/kakoNissu) **giữ nguyên**.

---

## 2. Request

### 2.1 HTTP Request
```
PUT /api/v1/keihi-kamoku HTTP/1.1
Content-Type: application/json
Authorization: Bearer <JWT>
```

### 2.2 Request Body schema

> ↔️ Field hiện hành giữ nguyên — xem [current_analysis §3](../../current_state/current_analysis.md). Khác với add: request PHẢI có `id` + `updateVersion` để xác định record.

#### 2.2.1 ↔️ Field UNCHANGED (tổng kết)
Giữ nguyên toàn bộ field cũ (gồm `id`, `updateVersion`) — như add. Xem [keihikamoku-add §2.2.1](../keihikamoku-add/detail_design.md).

#### 2.2.2 ✏️ Field MODIFIED
Không có field request nào đổi behaviour.

#### 2.2.3 🆕 Field NEW
**Giống hệt API add** — 8 field, cùng type/constraint/map DB. Xem [keihikamoku-add §2.2.3](../keihikamoku-add/detail_design.md):
`sankashaNyuryokuHitsuyoFlag`, `hitoriAtariJogenKingaku`, `hitoriAtariJogenCheckKubun`, `hitoriAtariJogenMessage`, `tashaSankashaNyuryokuFlag`, `tashaSankashaHissuFlag`, `jishaSankashaSentakuFlag`, `jishaSankashaHissuFlag`.

### 2.3 Example request
Xem [`request_examples.json`](./request_examples.json).

---

## 3. Response

### 3.1 Success — HTTP 200
```json
{ "code": 0, "message": "<I002 message>" }
```
↔️ `ModelApiResponse` qua `ApiUtil.makeSimpleResponse(MessageUtil.getMessage("I002"))`.

### 3.2 Error responses

| HTTP | Exception | Message key | Khi nào | Marker |
|---|---|---|---|---|
| 403 | `ForbiddenException` | (role) | Role không phải 5/6 | ↔️ |
| 400 | `BadRequestException` | `E084` | 標準科目 + đổi `keihiKamokuName` | ↔️ |
| 404/400 | `NotFoundException`/`BadRequestException` | `E041` | Record không tồn tại / đã xoá | ↔️ |
| 400 | `BadRequestException` | `E040` | Trùng tên (bỏ qua chính mình) | ↔️ |
| 400 | `BadRequestException` | `E152` | Tắt cờ 選択可能性 (YES→NO) khi đang dùng meisai | ↔️ |
| 400 | `BadRequestException` | `E037` | FK không tồn tại / sai loại | ↔️ |
| 400 | `BadRequestException` | `E005` | 🆕 `hitoriAtariJogenKingaku` thiếu/≤0 khi `checkKubun` ∈ {1,2} | 🆕 |
| 400 | `BadRequestException` | `bad_request` | Bean Validation fail (gồm 8 field mới) | ✏️ (mở rộng) |
| 400 | `BadRequestException` | `E152` (?) | ⚠️ TBD C1: tắt cờ `sankasha*` khi đang dùng meisai | ⚠️ TBD |

---

## 4. Business Logic Flow

### 4.1 Sequence (Hexagonal call order)

```
Controller -> KeihiKamokuApiDelegateImp.updateKeihiKamoku -> UseCase.updateKeihiKamoku
  -> KeihiKamokuService.updateKeihiKamoku  @Transactional
   1. RoleUtil.check(DEPARTMENT_MANAGEMENT, SUPER_ADMIN)                 [↔️]
   2. existed = keihiKamokuCrud.read(hojinCode, id)                     [↔️]
   3. if 標準科目 && name đổi -> E084                                    [↔️]
   4. if existed.deleteFlag == DELETED -> E041                          [↔️]
   5. dto = copy(existed); copy(request) đè lên                         [↔️ — request 8 field đè vào dto]
   6. giữ id/hojinCode/deleteFlag/addDate/addUserid/hyojunKamokuUmu/
      kanjoKamokuDokiUmu/hojoKamokuDokiUmu từ existed                    [↔️]
   7. default null các cờ 選択可能性 + guard E152 (YES->NO + used)       [↔️]
   7b. 🆕 default null 6 cờ sankasha (= 0)                              [🆕]
   8. checkDuplicateName(name, id)                                      [↔️]
   9. checkFlagKeihiKamoku / checkForeignKey                            [↔️]
  10. checkJogenKingaku / checkKakoNissu                                [↔️]
  10b. 🆕 checkHitoriAtariJogen(dto, checkKubun, kingaku)               [🆕 — tái dùng method từ add]
  11. validator.validate(dto)                                          [↔️ gồm 8 field mới]
  12. keihiKamokuCrud.saveKeihiKamoku(dto)                             [↔️]
  13. addLogDataOwnerId + koshinRirekiUseCase.addKoshinRireki(existed, dto) [↔️]
```

**Pseudo-code step 7b + 10b (🆕)**:
```java
// 7b. Default 6 cờ sankasha nếu null (đặt cùng chỗ với default cờ 選択可能性 của update)
if (dto.getSankashaNyuryokuHitsuyoFlag() == null) {
    dto.setSankashaNyuryokuHitsuyoFlag(AriNashiUmu.NO.getValue());
}
if (dto.getHitoriAtariJogenCheckKubun() == null) {
    dto.setHitoriAtariJogenCheckKubun(CheckFlag.NONE.getValue());
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

// 10b. Reuse method đã tạo ở API add (đọc checkKubun/kingaku từ request keihiKamokuDto)
checkHitoriAtariJogen(dto, keihiKamokuDto.getHitoriAtariJogenCheckKubun(),
    keihiKamokuDto.getHitoriAtariJogenKingaku());
```

**Nhấn mạnh điểm dễ sai**:
- ✏️ `checkHitoriAtariJogen` đã tồn tại (tạo ở API add) → **KHÔNG viết lại**, chỉ gọi thêm trong `updateKeihiKamoku`.
- 🆕 Đặt step 10b SAU `checkKakoNissu`, TRƯỚC `validator.validate(dto)`.
- ↔️ Adapter vẫn ép 3 field 出席者 cũ = 0 (Q6.5) — không đụng.
- ⚠️ **KHÔNG** thêm guard E152 cho cờ `sankasha*` ở phiên bản này (assumption TBD C1 — xem §9).
- 🆕 KHÔNG reset 8 field khi master off (Q6.3) — chỉ `checkHitoriAtariJogen` clear `kingaku` khi `checkKubun=0`.

### 4.2 Validation chi tiết
Giống add (§4.2): Bean Validation `@Range(0,99999)` / `@Size(1000)` / `@EnumNamePattern`; business: checkKubun ∈ {1,2} ⇒ kingaku > 0.

### 4.3 Conditional rule theo flag (🆕)
Giống [keihikamoku-add §4.3](../keihikamoku-add/detail_design.md). `sankashaNyuryokuHitsuyoFlag` không ép field con ở BE (Q6.3).

### 4.4 Unique check
↔️ `checkDuplicateName(name, id)` — bỏ qua chính mình. Không đổi.

### 4.5 Defensive coding (🆕)
```java
// checkHitoriAtariJogen tự clear kingaku khi checkKubun=0.
// KHÔNG auto-clear cờ con theo master flag (Q6.3 giữ giá trị).
// 8 field: null từ client -> default 0 (step 7b), không để null xuống cột NOT NULL.
```

---

## 5. Database Operations

### 5.1 Bảng đụng tới
| Bảng | Schema | Operation | Note |
|---|---|---|---|
| `tm_keihi_kamoku` | keihi_com | SELECT (read existed) + UPDATE | ✏️ +8 cột |
| `tm_kanjo_kamoku`/`tm_hojo_kamoku`/`tm_zeikubun` | keihi_com | SELECT | ↔️ FK check |
| `tr_meisai_joho` | (default) | SELECT (exists) | ↔️ guard E152 cờ 選択可能性 |

### 5.2 Transaction
↔️ `@Transactional` — không đổi.

### 5.3 Optimistic lock
↔️ `updateVersion` từ request → `@Version`.

### 5.4 Audit fields
↔️ `upd_date`/`upd_userid` tự động; `add_date`/`add_userid` giữ từ existed.

### 5.5 Cross-resource DB operation
↔️ Không phát sinh mới. Guard E152 hiện tại đã đọc `tr_meisai_joho` (existing). 8 field mới KHÔNG thêm cross-resource ở phiên bản này (TBD C1).

---

## 6. Class & File Structure (UPDATE — API đã tồn tại)

| Layer | Class | Path | Thay đổi |
|---|---|---|---|
| Entity | `TmKeihiKamoku` | entity/ | ✅ ĐÃ +8 field (làm ở API add) |
| DTO | `KeihiKamokuDto` | domain/ | ✅ ĐÃ +8 field + validation (API add) |
| API model | `KeihiKamoku` | api/model/ | ✅ ĐÃ +8 field (API add) |
| Service | `KeihiKamokuService` | service/ | ✏️ UPDATE `updateKeihiKamoku`: step 7b default + 10b gọi `checkHitoriAtariJogen` (method ĐÃ có) |
| Adapter | `KeihiKamokuAdapter` | persistence/db/ | ↔️ `saveKeihiKamoku` không đổi (BeanUtil copy + ép 3 field cũ = 0) |
| Delegate | `KeihiKamokuApiDelegateImp` | delegate/ | ↔️ `updateKeihiKamoku` không đổi (BeanUtil map) |
| i18n | `messages*.properties` | resources/ | ✅ ĐÃ thêm `KeihiKamokuDto.hitoriAtariJogenKingaku` (API add) |

**Dependency mới**: KHÔNG (trừ khi TBD C1 quyết định thêm guard → cần dùng `existsByHojinCodeAndKeihiKamokuId...` đã có sẵn trong adapter).

> Phần lớn artefact (Entity/DTO/model/method `checkHitoriAtariJogen`/message key) **đã được tạo khi implement API add**. API update chỉ còn thêm **2 block** vào method `updateKeihiKamoku`.

---

## 7. OpenAPI Definition
↔️ Dùng chung model `KeihiKamoku` (đã +8 field ở API add). Không thêm gì.

---

## 8. Test Cases

### 8.1 Unit test

| # | Test case | Expected | Marker |
|---|---|---|---|
| 1 | Update record cũ KHÔNG gửi 8 field mới | Success; 8 cột giữ/về default | Regression |
| 2 | Update bật `sankashaNyuryokuHitsuyoFlag=1` + kingaku + checkKubun=1 | Success | New |
| 3 | `checkKubun=1` + kingaku null | 400 `E005` | New |
| 4 | `checkKubun=0` + kingaku=8000 | Success; kingaku reset null | Defensive |
| 5 | Update tắt master (1→0) nhưng giữ kingaku cũ | Success; KHÔNG reset cờ con (Q6.3) | Defensive |
| 6 | `tashaSankashaHissuFlag=1` khi `tashaSankashaNyuryokuFlag=0` | Success (BE không chặn — Q6.4) | New |
| 7 | kingaku 6 chữ số | 400 `E004` | Validation |
| 8 | 標準科目 + đổi tên | 400 `E084` | Regression |
| 9 | Tắt cờ `ryoshushoSentakuKanousei` (YES→NO) khi dùng meisai | 400 `E152` | Regression |
| 10 | Record đã xoá | `E041` | Regression |
| 11 | Trùng tên với record khác | 400 `E040` | Regression |
| 12 | ⚠️ Tắt `sankashaNyuryokuHitsuyoFlag` khi meisai đang dùng | **Success** (assumption TBD C1 — không chặn) | New (TBD) |

### 8.2 Integration test
- Full flow PUT → UPDATE `tm_keihi_kamoku` + verify KoshinRireki diff 8 field mới.
- Regression: verify guard E152 cũ + E084/E041 vẫn hoạt động.

---

## 9. Open Issues / TBD

| # | Điểm TBD | Assumption | Severity | Reference |
|---|---|---|---|---|
| C1 | Guard khi tắt cờ `sankasha_nyuryoku_hitsuyo_flag` (hoặc cờ con) mà meisai đang dùng người tham gia | **Phiên bản này KHÔNG chặn** (cho tắt, data participant cũ giữ nguyên, ẩn UI). Nếu PO yêu cầu chặn → thêm guard giống E152 (đọc `tr_meisai_sankasha` qua method mới) | 🟡 Medium | final_spec §7 C1 / clarifications #6.6 |
| C2 | Label section `アクション・カラー設定` → `アラート・エラー設定` | Chỉ FE label, BE không liên quan | 🟢 Low | clarifications #6.8 |

> ⚠️ **TBD C1 là điểm khác biệt chính giữa update và add.** Nếu sau này PO chốt "chặn" → cần: thêm method `existsByHojinCodeAndKeihiKamokuIdAndSankasha...` ở `MeisaiJoho`/`tr_meisai_sankasha` (cross-resource), inject vào service, thêm guard trong `updateKeihiKamoku`. Hiện chưa làm → tránh block code.

---

## 10. References

- final_spec: [`../../final_spec.md`](../../final_spec.md) (v1.0.0) §4.1, §4.8
- clarifications: [`../../clarifications.md`](../../clarifications.md) (v1.0.0) — 6.1, 6.2, 6.3, 6.4, 6.6
- baseline: [`../../current_state/current_analysis.md`](../../current_state/current_analysis.md) §5.3 (update flow hiện tại)
- API add (reference cùng resource): [`../keihikamoku-add/detail_design.md`](../keihikamoku-add/detail_design.md)
- Reference impl: `backend/.../service/KeihiKamokuService.java` method `updateKeihiKamoku`, `checkHitoriAtariJogen`, `checkIsUsedInMeisai`
- Convention: `.claude/rules/api-conventions.md`

---

## Version History

### [1.0.0] - 2026-06-08

- Initial detail design cho API updateKeihiKamoku (EXTEND).
- Dựa trên final_spec v1.0.0 + current_analysis v1.0.0; reuse API add.
- Scope: +8 field; +default step 7b; +gọi `checkHitoriAtariJogen` (10b).
- 2 TBD (0 High, 1 Medium C1, 1 Low C2).
