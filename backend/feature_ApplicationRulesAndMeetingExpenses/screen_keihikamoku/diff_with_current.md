---
version: 1.0.0
last_updated: 2026-06-05
based_on_current_analysis_version: 1.0.0
based_on_spec_analysis_version: 1.0.0
---

# Diff Analysis — 経費科目 (KeihiKamoku) Extend "参加者入力 / 会議費"

## 0. Tóm tắt

- Field NEW (🆕): **8** (8 cột mới trên `tm_keihi_kamoku`)
- Field MODIFIED (✏️): **0** field dữ liệu (chỉ 1 label section UI đổi tên)
- Field REMOVED/DEPRECATED (❌): **0**
- Field UNCHANGED (↔️): toàn bộ field hiện tại của màn (xem §4)
- Breaking impact (🔴 High): **3** (maxlength conflict, quan hệ field 出席者 cũ, regenerate API model)
- Non-breaking, FE-affecting (🟡 Medium): **5**
- BE-only / config (🟢 Low): **2**

**Quick verdict**: ✅ **Pure extend** ở tầng màn 経費科目 (chỉ addColumn + mở rộng payload, backward compatible). ⚠️ **NHƯNG cross-screen impact RẤT LỚN** — đây là master table, 8 cờ này drive behaviour ở màn tạo meisai, list meisai, CSV, shiwake export + kéo theo 3 bảng mới (`tr_meisai_sankasha`, `tm_sankasha_template`, `tm_sankasha_template_shosai`). Xem §9.

---

## 1. Field NEW (chưa có trong current state)

| # | Field (JP) | DB column | Type | Null | Default | Mô tả | Source | Impact |
|---|---|---|---|---|---|---|---|---|
| 1 | 参加者の入力が必要な経費科目 | `sankasha_nyuryoku_hitsuyo_flag` | numeric(1) | No | 0 | Master toggle: 0=không cần, 1=cần nhập người tham gia | sheet02 R69 / DB R2 | 🟡 |
| 2 | 一人当たり上限金額 | `hitori_atari_jogen_kingaku` | numeric(11)* | Yes | null | Số tiền tối đa/người (*spec R77 ghi maxlength 5) | R76-R80 / DB R3 | 🔴 |
| 3 | 一人当たり上限金額超過時の種別 | `hitori_atari_jogen_check_kubun` | numeric(1) | No | 0 | 0:無し,1:エラー,2:アラート | R73 / DB R4 | 🟡 |
| 4 | 超過時メッセージ | `hitori_atari_jogen_message` | varchar(1000) | Yes | null | Message khi vượt limit (optional) | R81-R84 / DB R5 | 🟢 |
| 5 | 相手先会社名・参加者氏名の入力を行う | `tasha_sankasha_nyuryoku_flag` | numeric(1) | No | 0 | 0=ẩn, 1=hiển thị field đối tác trên meisai | R94-R98 / DB R6 | 🟡 |
| 6 | 相手先…を必須とする | `tasha_sankasha_hissu_flag` | numeric(1) | No | 0 | 0=optional, 1=required (phụ thuộc #5) | R99-R101 / DB R7 | 🟡 |
| 7 | 自社参加者の選択を行う | `jisha_sankasha_sentaku_flag` | numeric(1) | No | 0 | 0=ẩn, 1=hiển thị chọn NV nội bộ | R104-R106 / DB R8 | 🟡 |
| 8 | 自社参加者の選択を必須とする | `jisha_sankasha_hissu_flag` | numeric(1) | No | 0 | 0=optional, 1=required (phụ thuộc #7) | R107-R112 / DB R9 | 🟡 |

> Quan hệ enable: #1 master → bật #2/#3/#4. #6 phụ thuộc #5. #8 phụ thuộc #7.

---

## 2. Field MODIFIED (đã có nhưng spec đổi behaviour)

| # | Field | Current | Spec mới | Loại thay đổi | Impact |
|---|---|---|---|---|---|
| 1 | (label) section cờ check | Tiêu đề `アクション・カラー設定` | `アラート・エラー設定` | UI label only | 🟢 |

> Không có field dữ liệu nào đổi behaviour. Logic 7 cờ check cũ (領収書/メモ/費用負担/プロジェクト/金額上限/申請過去日) giữ nguyên.

---

## 3. Field REMOVED/DEPRECATED

Không có field nào bị bỏ bởi spec này.

⚠️ **Lưu ý điểm nghi vấn (xem §8.1)**: 3 field "出席者登録" đã chết (`shussekisha_toroku_umu`, `shussekisha_toroku_check`, `jizen_shinsei_bango_check`) KHÔNG được spec mới nhắc tới và KHÔNG được tái dùng — vẫn nằm im (dead). Có nên cleanup không → Q6.5.

---

## 4. Field UNCHANGED (verify không miss)

Toàn bộ field hiện có của 経費科目 giữ nguyên — spec 02 chỉ THÊM section, không sửa:
- 基本情報: keihiKamokuName, code, karikataKanjokamoku, hojoKamoku, kashikataKanjoKamoku, kashikataHojoKamoku, tokureiKubunFlag, zeikubun, tekikakuIgaiZeikubun, tokureiZeikubun, riyoJotai, hyojiJun.
- 選択可能な明細: ryoshushoSentakuKanousei, keiroSentakuKanousei, nittouSentakuKanousei, ryoshushoGaikaSentakuKanousei, gaikaRateShomeishoSentakuKanousei.
- 申請者が…選択できる項目: kashikataKamokuSentakuKanousei, zeikubunSentakuKanousei.
- アラート・エラー設定: ryoshushoTempuCheck, memoCheck, hiyoFutanBushoCheck, projectCheck, kingakuJogenCheck (+jogenKingaku), shinseiKakobiCheck (+kakoNissu), rateNyuryokuCheck.
- Hệ thống: id, hojinCode, deleteFlag, updateVersion, hyojunKamokuUmu, kanjoKamokuDokiUmu, hojoKamokuDokiUmu, audit.

---

## 5. Business rule changes

| # | Rule | Current behaviour | Spec mới | Impact |
|---|---|---|---|---|
| 1 | Per-person limit check | Không tồn tại | Thêm check số tiền/người (Error/Alert) + message khi vượt | 🟡 |
| 2 | Default value trong add/update | Set default cho cờ Gaika/sentaku... | Cần thêm default cho 8 field mới (theo pattern `checkJogenKingaku`/`checkKakoNissu`) | 🟡 |
| 3 | Conditional required | (n/a) | `*_hissu_flag` chỉ áp khi `*_nyuryoku/sentaku_flag`=1 (Q6.4) | 🟡 |
| 4 | Reset value khi tắt master | (n/a) | TBD: tắt master → reset field con? (Q6.3) | 🟡 |
| 5 | Guard tắt cờ khi đang dùng meisai | E152 cho cờ 選択可能性 | TBD: có guard tương tự cho sankasha flag? (Q6.6) | 🟡 |

---

## 6. Schema impact analysis

### 6.1 Bảng cần ALTER
- **`keihi_com.tm_keihi_kamoku`**: `ALTER TABLE` thêm **8 cột** (changeset mới, pattern giống `20252107_..._add_column_ForeignCurrency`).
  - 6 cột numeric(1) NOT NULL default 0: sankasha_nyuryoku_hitsuyo_flag, hitori_atari_jogen_check_kubun, tasha_sankasha_nyuryoku_flag, tasha_sankasha_hissu_flag, jisha_sankasha_sentaku_flag, jisha_sankasha_hissu_flag.
  - 1 cột numeric(11 hoặc theo Q6.1) nullable: hitori_atari_jogen_kingaku.
  - 1 cột varchar(1000) nullable: hitori_atari_jogen_message.
- Default 0 / null → **không cần migrate data row cũ** (row cũ tự nhận default = behaviour "không phải会議費").
- Không cần index/unique mới cho màn này.

### 6.2 Backward compatibility
- Tất cả cột mới có default/null → **backward compatible**. Row 経費科目 cũ vẫn hoạt động (sankasha flag=0).
- Không break query `search` hiện tại (không filter theo cột mới — trừ khi Q6.7 yêu cầu thêm điều kiện search).

---

## 7. API impact analysis

| Endpoint | Đổi request? | Đổi response? | Endpoint mới? | FE break? |
|---|---|---|---|---|
| POST /keihi-kamoku (add) | Y (+8 field) | N | N | N (field optional) |
| PUT /keihi-kamoku (update) | Y (+8 field) | N | N | N |
| GET /keihi-kamoku/{id} | N | Y (+8 field) | N | N |
| POST /keihi-kamoku/search | N* | Y (+8 field) | N | N |
| POST /keihi-kamoku/view-list | N | Y (+8 field) | N | N |
| CSV import/export | TBD (Q6.7) | TBD | N | TBD |
| (cross-screen meisai endpoints) | **Y — xem §9** | **Y** | **Y (tr_meisai_sankasha)** | **Y** |

> ⚠️ Phải thêm 8 field vào API model `KeihiKamoku` (generated legacy 2021) → Q6.9 về quy trình regenerate.

---

## 8. Verification của các discrepancy đã catch ở Phase 1

### 8.1 Field "出席者登録" đã chết (baseline §9.2)
- **Phase 1 catch**: 3 field `shussekisha_toroku_umu/check`, `jizen_shinsei_bango_check` còn trong DB+Entity nhưng bị ép = 0; nghi ngờ spec会議費 sẽ hồi sinh chúng (出席者 ≈ 参加者).
- **Spec mới**: dùng **cột HOÀN TOÀN MỚI** prefix `sankasha_*`, KHÔNG đụng tới field cũ.
- **Kết luận**: ⚠️ **Refuted một phần** — PO chọn thêm cột mới thay vì hồi sinh. Nhưng vẫn để ngỏ: 3 field cũ có cleanup không, và 種別/参加者 có thực sự độc lập với 出席者 cũ → **Q6.5 (🔴)**.

### 8.2 OpenAPI spec không đồng bộ (baseline §9.3)
- **Phase 1 catch**: model `KeihiKamoku` generated 2021, KHÔNG nằm trong `api_interface_generate_tool/specification/openapi.yml`.
- **Spec mới**: yêu cầu thêm 8 field vào request/response.
- **Kết luận**: 🔴 **Still pending** — cần xác nhận quy trình thêm field vào model legacy → **Q6.9**.

### 8.3 Pattern Gaika 2025 làm tiền lệ (baseline §9.8)
- **Phase 1 catch**: changeset Gaika (ducna1, 2025) là mẫu gần nhất cho EXTEND field cờ.
- **Spec mới**: 8 field mới fit hoàn toàn pattern này.
- **Kết luận**: ✅ **Confirmed** — implement theo pattern Gaika (addColumn + default + update data + enum + default trong add/update service).

---

## 9. Cross-screen impact analysis (BẮT BUỘC — TRỌNG TÂM)

> `tm_keihi_kamoku` là **master table dùng chung**. 8 cờ này chỉ **lưu** ở màn 経費科目, nhưng **được đọc & drive behaviour** ở nhiều màn khác. Nguồn: sheet `06_màn ảnh hưởng`, `db.Overview`, `db.Relations`, + các sheet 03/04/05/07/08 của file spec.

### 9.1 Relation/dependency phát sinh
- 8 cờ trên `tm_keihi_kamoku` → **điều khiển UI + validation màn tạo 明細 (Receipt Detail)**: khi申請者 chọn mục chi phí có `sankasha_nyuryoku_hitsuyo_flag=1`, màn meisai phải:
  - Hiển thị UI nhập người tham gia.
  - Check số tiền/người theo `hitori_atari_jogen_kingaku` + `hitori_atari_jogen_check_kubun` (Error chặn申請 / Alert cảnh báo) + hiển thị `hitori_atari_jogen_message`.
  - Hiển thị / bắt buộc field đối tác (相手先会社名/氏名) theo cờ #5/#6.
  - Hiển thị / bắt buộc chọn NV nội bộ theo cờ #7/#8.
- Dữ liệu người tham gia ghi vào **bảng MỚI `tr_meisai_sankasha`** (1 meisai_id → N participant: external/internal, sankasha_kubun 1/2). `hitori_atari_kingaku` (số tiền/người) lưu thêm trong `tr_meisai_joho` (db sheet R21).
- Liên kết template: `tm_meisai_template.sankasha_template_id` → `tm_sankasha_template` → `tm_sankasha_template_shosai` (3 bảng mới cho "template người tham gia").

### 9.2 Affected screens

| Màn | Lý do impact | Severity | File / scope dự kiến |
|---|---|---|---|
| **Màn tạo 明細 / Receipt Detail** (sheet 03) | Đọc 8 cờ để render UI người tham gia + check 一人当たり; ghi `tr_meisai_sankasha` | 🔴 High | MeisaiJoho service/adapter, entity mới TrMeisaiSankasha, màn 領収書明細 |
| **Detail Template** (sheet 05, tm_meisai_template) | Thêm `sankasha_template_id`; template áp dụng cấu hình người tham gia | 🟡 Medium | screen_template_meisai (đã có trong feature này) |
| **Participant Template** (sheet 04, tm_sankasha_template/_shosai) | Bảng mới — màn quản lý template người tham gia | 🟡 Medium | screen_detail_template_nguoi_tham_gia (đã có trong feature này) |
| **Màn list 明細** (sheet 06 R13-22, R42-44) | Thêm cột 参加人数/一人当たり金額/他社参加者会社名/氏名/自社参加者 vào config cột hiển thị; áp theo role shinsei/shonin/keiri | 🟡 Medium | màn list meisai |
| **Shiwake export** (sheet 06 R28-36, tm_shutsuryoku_komoku_shurui) | Thêm output item người tham gia, map từ `tr_meisai_sankasha` | 🟡 Medium | ShiwakeExport, tm_shutsuryoku_komoku_shurui |
| **CSV meisai** (sheet 06 R2-10) | Thêm field người tham gia vào CSV import/export của meisai | 🟡 Medium | MeisaiJoho CSV |
| **申請確認 / Application Confirmation** (db.Overview R10) | Hiển thị người tham gia đã nhập | 🟢 Low | màn xác nhận申請 |
| **Màn 経費科目一覧 (chính màn này, list)** | Có thể cần thêm cột/search/CSV cho 8 field (sheet06 R37-39, chưa rõ) | 🟢 Low | KeihiKamoku list — Q6.7 |
| **shinsei form** (sheet 01/06 R48-49) | Liên quan tm_shinsei_form_keihi_kamoku (giới hạn mục chi phí theo form) — gián tiếp | 🟡 Medium | screen shinsei form (sheet 01 — ngoài scope màn này) |

### 9.3 Cross-screen TBD
- **CS-1 🔴**: Field `hitori_atari_kingaku` lưu ở `tr_meisai_joho` hay tính runtime? (db sheet R21 nói "lưu thêm trong tr_meisai_joho"). → ảnh hưởng schema meisai (ngoài scope màn keihikamoku nhưng cần đồng bộ).
- **CS-2 🟡**: Bảng mới `tr_meisai_sankasha` unique key `(hojin_code, meisai_id, sankasha_kubun, hyoji_jun, delete_flag)` — confirm với team làm màn meisai.
- **CS-3 🟡**: Khi mục chi phí đã có meisai chứa participant mà admin tắt `sankasha_nyuryoku_hitsuyo_flag` → xử lý meisai cũ thế nào (giữ data, ẩn UI)? (liên quan Q6.6).
- **CS-4 🟡**: Thứ tự implement giữa 4 màn cùng feature (keihikamoku → meisai → template → list/export) — cần điều phối vì keihikamoku là "nguồn cấu hình".

> ✅ **Tin tốt**: 3 màn liên quan trọng (`screen_template_meisai`, `screen_detail_template_nguoi_tham_gia`) ĐÃ có trong cùng feature folder và đang được làm — cross-screen được điều phối trong cùng đợt, giảm rủi ro.

---

## 10. Recommended implementation strategy

- ☑ **Pure extend** cho RIÊNG màn 経費科目 — chỉ Add 8 cột + mở rộng DTO/Service/model, không breaking, backward compatible.
- ⚠️ Nhưng phải coi đây là **1 mảnh của feature lớn** — phối hợp với màn meisai/template/export.

### Detailed plan (scope màn keihikamoku)
1. **Liquibase**: changeset `YYYYMMDD_tm_keihi_kamoku_add_column_sankasha` — addColumn 8 cột (theo pattern Gaika). Default 0/null.
2. **Entity** `TmKeihiKamoku`: thêm 8 field (+ remarks JP).
3. **DTO** `KeihiKamokuDto`: thêm 8 field + `@LogOperation` + validation (`@Range`/`@EnumNamePattern`). Resolve Q6.1 (maxlength).
4. **API model** `KeihiKamoku` (+ search/list nếu cần): thêm 8 field — theo Q6.9.
5. **Service** `addKeihiKamoku`/`updateKeihiKamoku`: thêm default + `checkSankashaSetting()` (default reset theo Q6.3, conditional required Q6.4, guard Q6.6).
6. **Enum**: tái dùng `CheckFlag` (0/1/2) cho check_kubun, `AriNashiUmu` cho các cờ; cân nhắc enum riêng nếu nhãn khác.
7. **CSV** (nếu Q6.7 = có): thêm 8 cột vào `KeihiKamokuCsvDto`.
8. **Test**: unit test add/update với các tổ hợp cờ; verify backward compat row cũ.

### Effort estimate (chỉ màn keihikamoku, chưa gồm cross-screen)
- DB migration: ~1h
- Backend (entity/DTO/service/model): ~5-7h
- CSV (nếu cần): ~2h
- Testing: ~3h
- **Total (màn này)**: ~1.5-2 ngày
- **Cross-screen (meisai/template/export)**: tracked riêng theo từng màn — KHÔNG nằm trong estimate này.
