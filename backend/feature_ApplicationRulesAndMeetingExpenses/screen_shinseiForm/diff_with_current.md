---
version: 1.0.0
last_updated: 2026-06-09
based_on_current_analysis_version: 1.0.0
based_on_spec_analysis_version: 1.0.0
---

# Diff Analysis — 申請フォーム (ShinseiForm) Extend: 申請ルールの設定

## 0. Tóm tắt

- Field NEW (🆕): **13 cột** trên `tm_shinsei_form` + **4 bảng con mới**
- Field MODIFIED (✏️): 2 (quan hệ `keihiMeisaiTempu` ↔ nhóm 1; request/response model save form)
- Field REMOVED/DEPRECATED (❌): 0
- Field UNCHANGED (↔️): toàn bộ field基本項目 + customize komoku + cơ chế versioning/delete
- Breaking impact (🔴 High): 3 (version FK bảng con, cột thiếu bảng con, quan hệ keihiMeisaiTempu)
- Non-breaking, FE-affecting (🟡 Medium): 6
- BE-only / config (🟢 Low): 2

**Quick verdict**: **Pure extend (additive)** về mặt schema (ALTER add nullable/defaulted + tạo bảng con mới), KHÔNG phá data cũ. Nhưng có **cross-screen impact lớn** (màn tạo申請 phải lọc form) và vài điểm schema cần chốt trước khi code (🔴).

---

## 1. Field NEW (chưa có trong current state)

### 1.1 Cột thêm vào `tm_shinsei_form` (13 cột)

| # | Field (JP) | Cột DB | Type | Required | Default | Mô tả | Impact |
|---|---|---|---|---|---|---|---|
| 1 | 領収書明細添付可能 | `ryoshusho_meisai_tempu_kanou` | numeric(1) | No | 1 | 0:không/1:có | 🟢 |
| 2 | 経路明細添付可能 | `keiro_meisai_tempu_kanou` | numeric(1) | No | 1 | | 🟢 |
| 3 | 日当明細添付可能 | `nittou_meisai_tempu_kanou` | numeric(1) | No | 1 | | 🟢 |
| 4 | 領収書（外貨）明細添付可能 | `ryoshusho_gaika_meisai_tempu_kanou` | numeric(1) | No | 0 | bật khi 外貨機能 ON | 🟡 |
| 5 | 外貨レート証明書添付可能 | `gaika_rate_shomeisho_tempu_kanou` | numeric(1) | No | 0 | bật khi 外貨機能 + rate変更可能 | 🟡 |
| 6 | 申請可能な経費科目を設定する | `keihi_kamoku_seigen_flag` | numeric(1) | No | 0 | 0:không giới hạn/1:giới hạn | 🟡 |
| 7 | 申請合計金額の上限 | `shinsei_gokei_kingaku_jogen` | numeric(11) | Yes (nullable) | (rỗng) | trần tổng tiền | 🟡 |
| 8 | 上限超過時の種別 | `shinsei_gokei_jogen_check_kubun` | numeric(1) | No | 1 | 1:Error/2:Alert | 🟡 |
| 9 | 申請者がワークフローを変更可能 | `workflow_henko_kanou_flag` | numeric(1) | No | 0 | | 🟡 |
| 10 | 申請可能な部署を設定する | `busho_seigen_flag` | numeric(1) | No | 0 | | 🟡 |
| 11 | 下位階層を含む | `busho_kai_kaiso_fukumu_flag` | numeric(1) | No | 0 | dùng kèm #10 | 🟡 |
| 12 | 申請可能な役職を設定する | `yakushoku_seigen_flag` | numeric(1) | No | 0 | | 🟡 |
| 13 | 申請可能な従業員を設定する | `jugyoin_seigen_flag` | numeric(1) | No | 0 | | 🟡 |

> Tất cả NOT NULL + có default → **backward compatible** (data row cũ nhận default khi ALTER).

### 1.2 Bảng con mới (4 bảng — đều schema `keihi_com`)

| Bảng | Mục đích | PK | FK → tm_shinsei_form | Cột nghiệp vụ | Ghi chú spec |
|---|---|---|---|---|---|
| `tm_shinsei_form_keihi_kamoku` | giới hạn経費科目 | `shinsei_form_keihi_kamoku_id` | (shinsei_form_id, version⚠) | `keihi_kamoku_id`, `hyoji_jun` | có đủ audit + hyoji_jun |
| `tm_shinsei_form_busho` | giới hạn部署 | `shinsei_form_busho_id` | (shinsei_form_id, version⚠) | `busho_id` | ⚠ thiếu hyoji_jun + audit |
| `tm_shinsei_form_yakushoku` | giới hạn役職 | `shinsei_form_yakushoku_id` | (shinsei_form_id, version⚠) | `yakushoku_id` | ⚠ thiếu hyoji_jun + audit |
| `tm_shinsei_form_jugyoin` | giới hạn従業員 | `shinsei_form_jugyoin_id` | (shinsei_form_id, version⚠) | `jugyoin_id` | ⚠ thiếu hyoji_jun + audit |

> ⚠ Cột version FK: sheet ghi `update_version` nhưng BA note "**shinsei_form_version** chứ kp update_version" → xem §6 + clarifications 6.1.
> Unique key (sheet): `(hojin_code, shinsei_form_id, <version>, <entity>_id, delete_flag)`.

---

## 2. Field MODIFIED (đã có nhưng spec đổi behaviour)

| # | Field | Current | Spec mới | Loại thay đổi | Impact |
|---|---|---|---|---|---|
| 1 | `keihiMeisaiTempu` (経費明細の添付 0/1) | flag đơn có/không đính kèm | Khi =1 mở ra nhóm 1 (5 flag chi tiết theo loại meisai) | thêm sub-detail phụ thuộc | 🔴 (cần chốt quan hệ — clar 6.3) |
| 2 | Request/Response model `ShinseiForm` + `ShinseiFormDto` | không có 7 nhóm luật | thêm 13 field + 4 list con | mở rộng contract | 🟡 (FE phải gửi/nhận thêm) |

> Lưu ý: `workflowId` (デフォルトワークフロー) ↔️ giữ nguyên; nhóm 4 (`workflow_henko_kanou_flag`) chỉ là flag MỚI bổ sung "người申請 có được đổi workflow không", không đụng workflow mặc định.

---

## 3. Field REMOVED/DEPRECATED

Không có. (Spec thuần additive — không bỏ field/cột nào.)

---

## 4. Field UNCHANGED (verify không miss)

- 基本項目: `shinseiFormName`, `shinseiFormCode`, `shinseiTitle`, `kijunHi`, `keihiMeisaiShoninTokiToriatsukai`, `formRiyo`, `formShurui`, `workflowId`, `hyojiJun`, `shinseiFormSetsumei`, 4 flag quyền edit (承認/管理権限...), `hyojunKamokuUmu`, `updateAllShinseiTitleFlag`, `updateAllShinseiWorkflowFlag`.
- `customizeKomokuDtos` (+ format hyoji) — card カスタマイズ項目 giữ nguyên.
- Cơ chế **versioning** (trigger `set_shinsei_form_version`, `tm_mster_saiban`), **soft delete**, **optimistic lock**, **scope bushokaisoPtnId** — ↔️ giữ nguyên.
- ✅ **Update = tạo version mới gọi `addShinseiForm`** (PO xác nhận) — giữ nguyên, 7 nhóm luật mới đi cùng version mới.
- ✅ **Delete: comment chặn xóa khi còn申請 chưa duyệt giữ nguyên** (PO xác nhận).

---

## 5. Business rule changes

| # | Rule | Current behaviour | Spec mới | Impact |
|---|---|---|---|---|
| 1 | Loại meisai đính kèm | chỉ có/không (`keihiMeisaiTempu`) | giới hạn theo 5 loại (領収書/経路/日当/領収書外貨/レート証明書) | 🔴 (clar 6.3) |
| 2 | 経費科目 dùng được trong form | không giới hạn | nếu `keihi_kamoku_seigen_flag=1` → chỉ科目 trong `tm_shinsei_form_keihi_kamoku` | 🟡 |
| 3 | Trần tổng tiền申請 | không có | nếu set `shinsei_gokei_kingaku_jogen` → check khi tạo申請 (Error/Alert) | 🟡 (logic ở màn申請) |
| 4 | Ai được dùng form | mọi user trong bushokaisoPtnId | lọc thêm theo部署/役職/従業員 (nhóm 5/6/7) | 🔴 cross-screen |
| 5 | Người申請 đổi workflow | (theo logic hiện tại) | cho phép nếu `workflow_henko_kanou_flag=1` & 制限設定 ON | 🟡 |
| 6 | Consistency 経費科目 ↔ meisai type | không có | check khi save form (A197–A202) | 🟡 (clar 6.4) |

---

## 6. Schema impact analysis

### 6.1 Bảng cần ALTER / CREATE
- **ALTER `tm_shinsei_form`**: ADD 13 cột (numeric, NOT NULL + DEFAULT, riêng `shinsei_gokei_kingaku_jogen` nullable). 1 changeset `addColumn`.
- **CREATE 4 bảng con**: theo convention §15 `database.md` (audit đầu, PK varchar(29), hojin_code, FK, hyoji_jun, delete_flag). FK version dùng `shinsei_form_version` BIGINT (clar 6.1).
- **Index**: mỗi bảng con cần index `(hojin_code, shinsei_form_id, shinsei_form_version)`; unique theo sheet `(hojin_code, shinsei_form_id, version, <entity>_id, delete_flag)`.
- **Migration data row cũ**: KHÔNG cần (default đảm nhiệm). Bảng con rỗng cho form cũ → nghĩa là "không giới hạn" (khớp các seigen_flag default 0).
- ⚠ Cần thêm vào `keihi_com_changelog.xml` (explicit include) cho 4 file bảng con mới + 1 file ALTER.

### 6.2 Backward compatibility
- Cột mới NOT NULL nhưng có DEFAULT → row cũ tự nhận default → **không break**.
- Bảng con mới, query cũ không đụng → **không break**.
- Versioning: vì mỗi save sinh version mới, cần đảm bảo logic save mới INSERT list con theo (id, version) mới (giống customize komoku) — nếu quên, form version mới sẽ mất list con.

---

## 7. API impact analysis

| Endpoint | Đổi request? | Đổi response? | Endpoint mới? | FE break? |
|---|---|---|---|---|
| POST `/shinsei-form` (add) | Yes (+13 field, +4 list) | Yes | No | Không (field mới optional/có default) |
| PUT `/shinsei-form` (update→add) | Yes | Yes (I002) | No | Không |
| GET `/shinsei-form/{id}` | No | Yes (+13 field, +4 list, +tên科目/部署/役職/従業員 enrich) | No | Không |
| POST `/shinsei-form/search` | (option thêm filter?) | có thể +field | No | Không |
| GET form list cho màn tạo申請 (`viewListShinseiForm`/ShinseiJoho) | — | — | (có thể) lọc theo 5/6/7 | 🔴 cross-screen |
| Modal search 経費科目/部署/役職/従業員 | — | — | **Có thể cần 4 endpoint search** (clar 6.7) | — |

---

## 8. Verification của các discrepancy đã catch ở Phase 1

### 8.1 PUT `/shinsei-form` gọi `addShinseiForm`
- Phase 1 catch: PUT không gọi `updateShinseiForm` mà gọi `addShinseiForm`.
- Spec mới + PO: **CỐ Ý** — update = tạo version mới.
- Kết luận: ✅ **Resolved (confirmed intended)**. Khi extend, sửa logic save trong nhánh `existed != null` của `addShinseiForm`.

### 8.2 Comment-out check xóa khi còn申請 chưa duyệt
- Phase 1 catch: đoạn check bị comment out.
- PO: **giữ nguyên** logic hiện tại.
- Kết luận: ✅ **Resolved (keep as-is)**. Không khôi phục.

### 8.3 Bean config + branch + OpenAPI (inconsistency pointer)
- Phase 1 catch: bean ở `BeanConfiguration` (không phải `ShinseiFormConfiguration`); branch thật `milestone_v1_57.1`; OpenAPI nằm trong `openapi.yml`.
- Spec mới: không đụng tới.
- Kết luận: ↔️ Không ảnh hưởng spec; chỉ là note cho dev khi implement (sửa BeanConfiguration + openapi.yml).

### 8.4 TableCode TM023 (gen ID) vs TM018 (log) cho shinsei form
- Phase 1 catch: mâu thuẫn TableCode.
- Spec mới: không đụng. Vẫn cần verify khi thêm gen ID cho 4 bảng con (clar — chọn TableCode mới cho từng bảng con).

---

## 9. Cross-screen impact analysis (BẮT BUỘC)

### 9.1 Relation/dependency phát sinh
- Spec thêm FK trỏ tới `tm_keihi_kamoku`, master部署, master役職, master従業員 (`tm_jugyoin`). → Khi xóa/sửa các master này, cần cân nhắc ảnh hưởng tới cấu hình form (vd: 経費科目 đã bị xóa nhưng còn trong `tm_shinsei_form_keihi_kamoku`).
- Spec đổi behaviour "ai được dùng form" → màn **tạo申請 (shinsei create)** và mọi nơi liệt kê form khả dụng cho người nộp bị ảnh hưởng.
- Nhóm 3 (trần tiền) → logic **tạo/validate申請** (màn meisai/shinsei) phải check tổng tiền vs `shinsei_gokei_kingaku_jogen`.
- Nhóm 1 (loại meisai) → màn đính kèm meisai khi tạo申請 phải lọc loại meisai cho phép; liên đới **màn detail 経費科目** (KeihiKamoku — consistency check A197).

### 9.2 Affected screens
| Màn | Lý do impact | Severity | File cần update (dự kiến) |
|---|---|---|---|
| Màn tạo申請 / list form khả dụng | Lọc form theo部署/役職/従業員 (5/6/7) | 🔴 | `ShinseiJohoService`, `viewListShinseiForm`, repository search |
| Màn tạo/validate申請 (meisai) | Check trần tổng tiền + lọc loại meisai đính kèm | 🔴 | logic validate shinsei tổng tiền + meisai type |
| Màn detail 経費科目 (KeihiKamoku) | Consistency check 選択可能 meisai type ↔ form (A197) | 🟡 | `KeihiKamoku*` (đang có thay đổi gần đây — xem git log) + `ShinseiFormService` |
| Setting Kaisha / 制限設定 | Nguồn flag 外貨機能 / rate / ワークフロー変更ON,OFF | 🟡 | đọc flag (không sửa) |
| Màn chọn workflow khi tạo申請 | Cho phép đổi workflow nếu `workflow_henko_kanou_flag=1` | 🟡 | logic màn申請 |

> 📌 Lưu ý: git log gần đây có nhiều commit về `KeihiKamoku` (participant flags) và sheet DB cũng kèm `tm_keihi_kamoku`, `tr_meisai_sankasha`, `tm_sankasha_template*`, `tm_meisai_template`... → đây là **feature lớn "ApplicationRulesAndMeetingExpenses"**, màn shinsei form chỉ là 1 phần. Các sheet khác (02_経費科目, 03_hóa đơn, 04/05 template người tham gia...) sẽ phân tích ở màn riêng.

### 9.3 Cross-screen TBD
- Q: Logic filter form ở màn tạo申請 kết hợp 5/6/7 theo OR hay AND? (clar 6.9)
- Q: Trần tiền check ở thời điểm nào của flow tạo申請 (lúc submit? lúc save draft?) và so với tổng tiền nào (gồm thuế?)? → thuộc spec màn申請/meisai, cần đối chiếu sheet khác.
- Q: Consistency check A197 có chặn cả phía màn 経費科目 (khi sửa科目 đang được form giới hạn dùng) không?

---

## 10. Recommended implementation strategy

- ☑ **Pure extend (additive) + cross-screen wiring** — schema thuần thêm; logic mới chủ yếu ở save form + lan sang màn tạo申請.

### Detailed plan
1. **Clarify trước** các điểm 🔴 (clar 6.1, 6.2, 6.3) — chốt cột version + cột thiếu + quan hệ keihiMeisaiTempu. KHÔNG code schema trước khi chốt.
2. **Liquibase**: 1 changeset ALTER `tm_shinsei_form` (+13 cột); 4 file tạo bảng con + index + include vào `keihi_com_changelog.xml`. Cấp TableCode mới cho 4 bảng con (gen ID).
3. **Entity**: thêm 13 field vào `TmShinseiForm`; tạo 4 entity con (versioned theo shinsei_form_id+version, IdClass nếu cần).
4. **DTO**: thêm 13 field + 4 list con vào `ShinseiFormDto`; tạo DTO con (KeihiKamoku/Busho/Yakushoku/Jugyoin restriction).
5. **Port/Adapter/Repository**: CRUD 4 bảng con; mở rộng `ShinseiFormCrud`/`ShinseiFormAdapter`.
6. **Service `addShinseiForm`**: lưu 13 field + insert list con theo version mới; consistency check (6.4); validate trần tiền/seigen list (6.8). Đảm bảo re-insert list con mỗi version.
7. **Model OpenAPI**: cập nhật `openapi.yml` (`ShinseiForm`, `ListShinseiForm` + sub-models) → regen.
8. **Cross-screen**: filter form ở màn tạo申請 (5/6/7); check trần tiền + loại meisai; consistency với KeihiKamoku.
9. **Modal search APIs** (nếu thiếu): 経費科目/部署/役職/従業員.
10. **Test**: unit save/get versioned + child tables; cross-screen filter; backward-compat data cũ.

### Effort estimate (sơ bộ — chốt sau clarifications)
- DB migration (ALTER + 4 bảng): ~0.5 ngày
- Backend (entity/dto/port/adapter/service + OpenAPI): ~2.5–3 ngày
- Cross-screen (lọc form + trần tiền + consistency): ~2–3 ngày (phụ thuộc sheet khác)
- Modal search APIs: ~0.5–1 ngày (nếu phải tạo mới)
- Testing: ~1.5 ngày
- **Total**: ~7–9 ngày (chưa gồm các sheet/màn khác của feature)
</content>
