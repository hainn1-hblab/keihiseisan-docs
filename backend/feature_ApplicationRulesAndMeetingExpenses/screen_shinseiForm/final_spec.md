---
version: 1.0.0
status: ready-for-implementation
last_updated: 2026-06-09
mode: EXTEND
based_on_spec_analysis_version: 1.0.0
based_on_clarifications_version: 1.0.0
based_on_current_analysis_version: 1.0.0
based_on_diff_version: 1.0.0
unresolved_questions_count: 1
feature: ApplicationRulesAndMeetingExpenses
screen: screen_shinseiForm
---

> 📘 **Đây là file spec chốt cho phase EXTEND màn 申請フォーム (ShinseiForm).**
> - Màn ĐÃ CÓ SẴN. File này CHỈ mô tả phần **THÊM / ĐỔI / ẢNH HƯỞNG**.
> - Baseline (đang chạy): xem [`current_state/current_analysis.md`](./current_state/current_analysis.md). KHÔNG lặp lại.
> - Ký hiệu: 🆕 NEW · ✏️ MODIFIED · ↔️ UNCHANGED.
> - 1 điểm ⚠️ TBD còn lại (Low — TableCode gen ID): xem §7. KHÔNG block code.

# Final Spec — 申請フォーム詳細設定 (ShinseiForm — Application Rules Setting)

## 1. Tổng quan

Bổ sung 1 card mới **「申請ルールの設定」** (Application Rules Setting) vào màn `申請フォーム保存`, đặt **giữa** card `基本項目` và các card `カスタマイズ項目`. Card gồm **7 nhóm luật** quy định cách form được dùng khi nhân viên tạo申請.

### Scope (EXTEND)
- 🆕 **13 cột mới** trên `tm_shinsei_form` (nhóm 1, 2, 3, 4, 5, 6, 7).
- 🆕 **4 bảng con mới** (versioned theo `shinsei_form_id` + `shinsei_form_version`): `tm_shinsei_form_keihi_kamoku`, `tm_shinsei_form_busho`, `tm_shinsei_form_yakushoku`, `tm_shinsei_form_jugyoin`.
- ✏️ Mở rộng request/response model `ShinseiForm` + DTO + entity + adapter + service (qua endpoint hiện có).
- ✏️ API search/view-list shinsei form: thêm param `jugyoinId` để lọc form theo quyền truy cập (cross-screen màn tạo申請).
- ↔️ Toàn bộ `基本項目`, `カスタマイズ項目`, versioning, soft delete, optimistic lock, scope `bushokaisoPtnId` — giữ nguyên theo current_analysis.

| # | Tên màn | Mô tả |
|---|---|---|
| 1 | 申請フォーム保存 (create/edit/view) | ↔️ Màn cũ + 🆕 card 「申請ルールの設定」 (7 nhóm) |

---

## 2. Màn hình List — 申請フォーム一覧

> ↔️ Cột table, search, paging, sort, button giữ nguyên theo [current_analysis §8](./current_state/current_analysis.md).

### 2.3 ✏️ Thay đổi API list/search (cross-screen)
- API `searchShinseiForm` / `viewListShinseiForm` nhận thêm tham số **`jugyoinId`** (FE truyền lên). Khi có `jugyoinId`, BE lọc chỉ trả các form mà nhân viên đó được phép dùng theo luật nhóm 5/6/7 (xem §4.3, §8). Khi không truyền `jugyoinId` → giữ hành vi list hiện tại (màn quản lý master).

---

## 3. Màn hình Detail — 申請フォーム保存 (card 「申請ルールの設定」)

### 3.1 ↔️ Field UNCHANGED
Toàn bộ field card `基本項目` (種類/名/コード/申請タイトル/基準日/経費明細の添付/承認時の取扱い/フォームの利用/表示優先順/デフォルトワークフロー/説明) và card `カスタマイズ項目` giữ nguyên — xem [current_analysis §2.2](./current_state/current_analysis.md).

### 3.2 🆕 Field mới — card 「申請ルールの設定」

**Nhóm 1 — 添付可能な明細の種類 (Loại meisai được phép đính kèm)** — độc lập với `keihiMeisaiTempu` (xem §4.2)
| # | Label | Tiếng Việt | Kiểu UI | DB column | Required | Hiển thị khi |
|---|---|---|---|---|---|---|
| 1.1 | 領収書 | Hóa đơn | checkbox | `ryoshusho_meisai_tempu_kanou` | No | Luôn |
| 1.2 | 経路 | Lộ trình | checkbox | `keiro_meisai_tempu_kanou` | No | Luôn |
| 1.3 | 日当 | Phụ cấp ngày | checkbox | `nittou_meisai_tempu_kanou` | No | Luôn |
| 1.4 | 領収書（外貨） | Hóa đơn (ngoại tệ) | checkbox | `ryoshusho_gaika_meisai_tempu_kanou` | No | `gaikaRiyoUmu` = ON |
| 1.5 | 外貨レート証明書 | Chứng từ tỷ giá | checkbox | `gaika_rate_shomeisho_tempu_kanou` | No | `gaikaRiyoUmu` = ON **và** `shinseishaRateNyuryoku` = ON |

**Nhóm 2 — 申請可能な経費科目を設定する (Giới hạn経費科目)**
| # | Label | Kiểu UI | DB column / bảng | Required |
|---|---|---|---|---|
| 2.1 | 申請可能な経費科目を設定する | checkbox | `keihi_kamoku_seigen_flag` (0/1) | No |
| 2.2 | List経費科目 + 「＋経費科目追加」 + modal | list + modal | `tm_shinsei_form_keihi_kamoku` | **Có** (nếu 2.1=1, xem §4.1) |

**Nhóm 3 — 申請合計金額の上限 (Trần tổng tiền申請)**
| # | Label | Kiểu UI | DB column | Required |
|---|---|---|---|---|
| 3.1 | 申請合計金額の上限 | input số | `shinsei_gokei_kingaku_jogen` numeric(11) | No (null=bỏ qua) |
| 3.2 | 超過時の種別 | radio エラー/アラート | `shinsei_gokei_jogen_check_kubun` (1:Error/2:Alert) | No (default 1) |

**Nhóm 4 — 申請者がワークフローを変更可能**
| # | Label | Kiểu UI | DB column | Hiển thị khi |
|---|---|---|---|---|
| 4.1 | 申請者がワークフローを変更可能 | checkbox | `workflow_henko_kanou_flag` (0/1, default 0) | Setting「ワークフロー変更をON,OFFできる」(制限設定) = ON |

**Nhóm 5 — 申請可能な部署を設定する (Giới hạn部署)**
| # | Label | Kiểu UI | DB column / bảng | Enable khi |
|---|---|---|---|---|
| 5.1 | 申請可能な部署を設定する | checkbox | `busho_seigen_flag` (0/1) | — |
| 5.2 | 下位階層を含む | checkbox | `busho_kai_kaiso_fukumu_flag` (0/1) | 5.1=1 |
| 5.3 | List部署 + 「＋部署追加」 + modal | list + modal | `tm_shinsei_form_busho` | 5.1=1 (cho phép rỗng) |

**Nhóm 6 — 申請可能な役職を設定する (Giới hạn役職)**
| # | Label | Kiểu UI | DB column / bảng | Enable khi |
|---|---|---|---|---|
| 6.1 | 申請可能な役職を設定する | checkbox | `yakushoku_seigen_flag` (0/1) | — |
| 6.2 | List役職 + 「＋役職追加」 + modal (search code/name) | list + modal | `tm_shinsei_form_yakushoku` | 6.1=1 (cho phép rỗng) |

**Nhóm 7 — 申請可能な従業員を設定する (Giới hạn従業員)**
| # | Label | Kiểu UI | DB column / bảng | Enable khi |
|---|---|---|---|---|
| 7.1 | 申請可能な従業員を設定する | checkbox | `jugyoin_seigen_flag` (0/1) | — |
| 7.2 | List従業員 + 「＋従業員追加」 + modal | list + modal | `tm_shinsei_form_jugyoin` | 7.1=1 (cho phép rỗng) |

### 3.3 ✏️ Field MODIFIED
| Field | Hiện tại | Đổi thành | Lý do |
|---|---|---|---|
| `ShinseiForm` model / `ShinseiFormDto` | Không có 7 nhóm luật | Thêm 13 field + 4 list con (`keihiKamokuList`, `bushoList`, `yakushokuList`, `jugyoinList`) | Card mới đi qua endpoint save/get hiện có |

### 3.4 Action buttons
↔️ `戻る` (Cancel) / `保存` (Save) — giữ nguyên. `保存` lưu thêm 13 field + 4 list con (xem §4.4).

### 3.5 Layout & UI behavior
- Card「申請ルールの設定」đặt giữa `基本項目` và `カスタマイズ項目名1`. Đánh số badge 1→7. Xem ảnh `images/image_A4.png`.
- Nhóm 2/5/6/7: checkbox seigen_flag OFF → button「＋…追加」 + khung list **disabled**; ON → enabled.
- Nhóm 1: checkbox đang hiển thị được **check mặc định** khi tạo mới (xem §4.2).

---

## 4. Business Rules

### 4.1 Validation rules 🆕
- **`shinsei_gokei_kingaku_jogen`**: số nguyên dương, tối đa 11 chữ số (max 99,999,999,999 ¥). Không cho `0`. Không hỗ trợ thập phân / ngoại tệ. Để trống → lưu `null` → bỏ qua check trần tiền khi tạo申請.
- **Nhóm 2 (経費科目) required**: nếu `keihi_kamoku_seigen_flag = 1` mà list rỗng → **chặn save**, message key `error.shinseiForm.keihiKamoku.required`.
- **Nhóm 5/6/7 (部署/役職/従業員)**: cho phép `seigen_flag = 1` nhưng list **rỗng** → vẫn save được; nghĩa nghiệp vụ = "không giới hạn theo busho/yakushoku/jugyoin nào".
- **Consistency check 経費科目 ↔ 添付可能な明細の種類 (A197–A202)**: chỉ áp khi `keihi_kamoku_seigen_flag = 1`. Khi save, nếu một経費科目 đã chọn có "loại meisai được phép chọn" (cấu hình ở màn detail KeihiKamoku) KHÔNG khớp với loại meisai được tick ở nhóm 1 → **chặn save**, message key `error.shinseiForm.keihiKamoku.meisaiTypeMismatch`.
  - (FE đã lọc sẵn list trong modal để chỉ hiển thị経費科目 khớp meisai type nhóm 1; BE vẫn check lại khi save để đảm bảo.)

### 4.2 Field visibility (dependency) 🆕
- **Nhóm 1 độc lập với `keihiMeisaiTempu`** (xác nhận PO): 2 phần KHÔNG phụ thuộc nhau, để tránh ảnh hưởng logic hiện tại của `keihiMeisaiTempu`.
- Hiển thị nhóm 1 theo `gaikaRiyoUmu` (外貨機能) + `shinseishaRateNyuryoku` (申請者レート変更可能 — setting Kaisha):
  | gaikaRiyoUmu | shinseishaRateNyuryoku | 1.1/1.2/1.3 | 1.4 (領収書外貨) | 1.5 (外貨レート証明書) |
  |---|---|---|---|---|
  | OFF | (bất kỳ) | hiển thị | **ẩn, lưu 0** | **ẩn, lưu 0** |
  | ON | ON | hiển thị | hiển thị | hiển thị |
  | ON | OFF | hiển thị | hiển thị | **ẩn, lưu 0** |
- **Default khi tạo mới**: checkbox đang **hiển thị** được check (lưu 1). Checkbox bị ẩn (1.4/1.5 khi điều kiện không thỏa) lưu `0`.
- **Nhóm 4** chỉ hiển thị khi setting「ワークフロー変更をON,OFFできる」(制限設定) = ON.

### 4.3 Quy tắc đặc biệt — lọc form theo quyền (cross-screen, xem §8) 🆕
- Ở màn **tạo申請**, người nộp chỉ thấy form mà mình được phép dùng theo nhóm 5/6/7, ghép theo **OR**:
  - Form available nếu: thỏa điều kiện部署 **HOẶC** 役職 **HOẶC** 従業員 đang bật & match.
  - Nếu **tất cả** `busho_seigen_flag = yakushoku_seigen_flag = jugyoin_seigen_flag = 0` → form available cho **mọi** user (như hiện tại).
- **`下位階層を含む` (5.2 = 1)**: tính **động** lúc tạo申請 — lấy busho được chọn rồi truy vấn cấu trúc tổ chức hiện tại để lấy toàn bộ busho con, mở rộng điều kiện lọc theo danh sách busho con này. KHÔNG lưu sẵn danh sách mở rộng.

### 4.4 Save strategy (header + 4 detail) — versioned 🆕
- ↔️ Vẫn theo cơ chế **versioning hiện tại**: mỗi lần `保存` (cả tạo mới lẫn cập nhật) đi qua `addShinseiForm` → INSERT một `shinsei_form_version` mới (trigger `set_shinsei_form_version`).
- 🆕 13 field mới lưu trên row version mới của `tm_shinsei_form`.
- 🆕 4 list con lưu vào bảng con theo **`(shinsei_form_id, shinsei_form_version)` mới** — re-insert toàn bộ list cho mỗi version (giống `tm_customize_komoku`). Lưu ý: KHÔNG được dùng version cũ, nếu không list con của version mới sẽ rỗng.

### 4.5 Delete behavior
↔️ Giữ nguyên: soft delete tất cả version (`updateAllByShinseiFormId`). Comment chặn xóa khi còn申請 chưa duyệt **giữ nguyên** (PO xác nhận). 4 bảng con: theo logic delete hiện hành (soft delete theo `shinsei_form_id`) — xem §7 TBD nếu cần dọn list con khi xóa form.

### 4.6 Display & sort
↔️ Default sort `hyojiJun asc` giữ nguyên. Bảng con dùng `hyoji_jun` (default 100) để sắp xếp hiển thị item trong list.

### 4.7 Access control (role-based)
↔️ Giữ nguyên: CRUD master = role 5 (DEPARTMENT_MANAGEMENT), 6 (SUPER_ADMIN). View/list (cross-screen tạo申請) = 5 role.

---

## 5. Database Schema

> Nguồn: `db_tables_application_rules_meeting_expenses.xlsx`, sheets `tm_shinsei_form`, `tm_shinsei_form_keihi_kamoku`, `tm_shinsei_form_busho`, `tm_shinsei_form_yakushoku`, `tm_shinsei_form_jugyoin`.
> Đã áp dụng 2 quyết định clarification: **(6.1)** dùng `shinsei_form_version` (BIGINT) cho FK 4 bảng con; **(6.2)** bổ sung `hyoji_jun` + 4 audit field cho 3 bảng `busho/yakushoku/jugyoin`.

### 5.1 🆕 Cột thêm vào `keihi_com.tm_shinsei_form` (ALTER — 13 cột)

| Column | Type | Len | Nullable | Default | Description |
|---|---|---|---|---|---|
| `ryoshusho_meisai_tempu_kanou` | NUMBER | 1 | No | 1 | 領収書明細添付可能 0:不可/1:可 |
| `keiro_meisai_tempu_kanou` | NUMBER | 1 | No | 1 | 経路明細添付可能 |
| `nittou_meisai_tempu_kanou` | NUMBER | 1 | No | 1 | 日当明細添付可能 |
| `ryoshusho_gaika_meisai_tempu_kanou` | NUMBER | 1 | No | 0 | 領収書（外貨）明細添付可能 (外貨機能ON時) |
| `gaika_rate_shomeisho_tempu_kanou` | NUMBER | 1 | No | 0 | 外貨レート証明書添付可能 (外貨+レート変更可能時) |
| `keihi_kamoku_seigen_flag` | NUMBER | 1 | No | 0 | 申請可能な経費科目を設定する 0:制限なし/1:制限 |
| `shinsei_gokei_kingaku_jogen` | NUMBER | 11 | Yes | (null) | 申請合計金額の上限 (正整数; null=未チェック) |
| `shinsei_gokei_jogen_check_kubun` | NUMBER | 1 | No | 1 | 上限超過時の種別 1:エラー/2:アラート |
| `workflow_henko_kanou_flag` | NUMBER | 1 | No | 0 | 申請者がワークフローを変更可能 0:不可/1:可 |
| `busho_seigen_flag` | NUMBER | 1 | No | 0 | 申請可能な部署を設定する 0:制限なし/1:制限 |
| `busho_kai_kaiso_fukumu_flag` | NUMBER | 1 | No | 0 | 下位階層を含む 0:含まない/1:含む |
| `yakushoku_seigen_flag` | NUMBER | 1 | No | 0 | 申請可能な役職を設定する 0:制限なし/1:制限 |
| `jugyoin_seigen_flag` | NUMBER | 1 | No | 0 | 申請可能な従業員を設定する 0:制限なし/1:制限 |

> Tất cả NOT NULL + DEFAULT → row cũ tự nhận default khi ALTER → **backward compatible**. `shinsei_gokei_kingaku_jogen` nullable.

### 5.2 🆕 Bảng con mới (4 bảng — schema `keihi_com`, versioned)

Cấu trúc chung (mỗi bảng): audit (add_date/upd_date/add_userid/upd_userid) + PK `<table>_id` VARCHAR(29) + `hojin_code` VARCHAR(5) + `shinsei_form_id` VARCHAR(29) + **`shinsei_form_version` BIGINT** + `<entity>_id` VARCHAR(29) + `hyoji_jun` NUMBER(4) default 100 + `delete_flag` NUMBER(1) default 0.

| Bảng | PK | Entity FK | Tham chiếu |
|---|---|---|---|
| `tm_shinsei_form_keihi_kamoku` | `shinsei_form_keihi_kamoku_id` | `keihi_kamoku_id` | `tm_keihi_kamoku` |
| `tm_shinsei_form_busho` | `shinsei_form_busho_id` | `busho_id` | master部署 |
| `tm_shinsei_form_yakushoku` | `shinsei_form_yakushoku_id` | `yakushoku_id` | master役職 |
| `tm_shinsei_form_jugyoin` | `shinsei_form_jugyoin_id` | `jugyoin_id` | `tm_jugyoin` |

- **Unique constraint** mỗi bảng: `(hojin_code, shinsei_form_id, shinsei_form_version, <entity>_id, delete_flag)`.
- **Index**: `(hojin_code, shinsei_form_id, shinsei_form_version)`.

### 5.3 Quan hệ
| From | Field | To | Cardinality | Mục đích |
|---|---|---|---|---|
| `tm_shinsei_form_keihi_kamoku` | (shinsei_form_id, shinsei_form_version) | `tm_shinsei_form` | N:1 | Giới hạn経費科目 theo version |
| `tm_shinsei_form_busho` | (shinsei_form_id, shinsei_form_version) | `tm_shinsei_form` | N:1 | Giới hạn部署 |
| `tm_shinsei_form_yakushoku` | (shinsei_form_id, shinsei_form_version) | `tm_shinsei_form` | N:1 | Giới hạn役職 |
| `tm_shinsei_form_jugyoin` | (shinsei_form_id, shinsei_form_version) | `tm_shinsei_form` | N:1 | Giới hạn従業員 |

### 5.4 Skeleton Liquibase (tham khảo)

**ALTER `tm_shinsei_form`** (file: `init/keihi_com/tm_shinsei_form.xml`, thêm changeset mới):
```xml
<changeSet author="ducna1" id="20260514_tm_shinsei_form_add_application_rules">
  <addColumn schemaName="keihi_com" tableName="tm_shinsei_form">
    <column name="ryoshusho_meisai_tempu_kanou" type="NUMBER(1)" defaultValueNumeric="1" remarks="領収書明細添付可能">
      <constraints nullable="false"/>
    </column>
    <column name="keiro_meisai_tempu_kanou" type="NUMBER(1)" defaultValueNumeric="1" remarks="経路明細添付可能">
      <constraints nullable="false"/>
    </column>
    <column name="nittou_meisai_tempu_kanou" type="NUMBER(1)" defaultValueNumeric="1" remarks="日当明細添付可能">
      <constraints nullable="false"/>
    </column>
    <column name="ryoshusho_gaika_meisai_tempu_kanou" type="NUMBER(1)" defaultValueNumeric="0" remarks="領収書（外貨）明細添付可能">
      <constraints nullable="false"/>
    </column>
    <column name="gaika_rate_shomeisho_tempu_kanou" type="NUMBER(1)" defaultValueNumeric="0" remarks="外貨レート証明書添付可能">
      <constraints nullable="false"/>
    </column>
    <column name="keihi_kamoku_seigen_flag" type="NUMBER(1)" defaultValueNumeric="0" remarks="申請可能な経費科目を設定する 0:制限なし、1:制限">
      <constraints nullable="false"/>
    </column>
    <column name="shinsei_gokei_kingaku_jogen" type="NUMBER(11)" remarks="申請合計金額の上限">
      <constraints nullable="true"/>
    </column>
    <column name="shinsei_gokei_jogen_check_kubun" type="NUMBER(1)" defaultValueNumeric="1" remarks="上限超過時の種別 1:エラー、2:アラート">
      <constraints nullable="false"/>
    </column>
    <column name="workflow_henko_kanou_flag" type="NUMBER(1)" defaultValueNumeric="0" remarks="申請者がワークフローを変更可能">
      <constraints nullable="false"/>
    </column>
    <column name="busho_seigen_flag" type="NUMBER(1)" defaultValueNumeric="0" remarks="申請可能な部署を設定する 0:制限なし、1:制限">
      <constraints nullable="false"/>
    </column>
    <column name="busho_kai_kaiso_fukumu_flag" type="NUMBER(1)" defaultValueNumeric="0" remarks="下位階層を含む 0:含まない、1:含む">
      <constraints nullable="false"/>
    </column>
    <column name="yakushoku_seigen_flag" type="NUMBER(1)" defaultValueNumeric="0" remarks="申請可能な役職を設定する 0:制限なし、1:制限">
      <constraints nullable="false"/>
    </column>
    <column name="jugyoin_seigen_flag" type="NUMBER(1)" defaultValueNumeric="0" remarks="申請可能な従業員を設定する 0:制限なし、1:制限">
      <constraints nullable="false"/>
    </column>
  </addColumn>
  <rollback>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="ryoshusho_meisai_tempu_kanou"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="keiro_meisai_tempu_kanou"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="nittou_meisai_tempu_kanou"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="ryoshusho_gaika_meisai_tempu_kanou"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="gaika_rate_shomeisho_tempu_kanou"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="keihi_kamoku_seigen_flag"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="shinsei_gokei_kingaku_jogen"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="shinsei_gokei_jogen_check_kubun"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="workflow_henko_kanou_flag"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="busho_seigen_flag"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="busho_kai_kaiso_fukumu_flag"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="yakushoku_seigen_flag"/>
    <dropColumn schemaName="keihi_com" tableName="tm_shinsei_form" columnName="jugyoin_seigen_flag"/>
  </rollback>
</changeSet>
```

**CREATE bảng con** (mẫu cho `tm_shinsei_form_keihi_kamoku`; 3 bảng còn lại tương tự, đổi PK + entity_id + đã bổ sung hyoji_jun/audit):
```xml
<changeSet author="ducna1" id="20260514_tm_shinsei_form_keihi_kamoku_init_table">
  <createTable tableName="tm_shinsei_form_keihi_kamoku" schemaName="keihi_com">
    <column name="add_date" type="TIMESTAMP" remarks="データの作成日時"><constraints nullable="true"/></column>
    <column name="upd_date" type="TIMESTAMP" remarks="データの更新日時"><constraints nullable="true"/></column>
    <column name="add_userid" type="VARCHAR(29)" remarks="データの作成ユーザーID"><constraints nullable="true"/></column>
    <column name="upd_userid" type="VARCHAR(29)" remarks="データの更新ユーザーID"><constraints nullable="true"/></column>
    <column name="shinsei_form_keihi_kamoku_id" type="VARCHAR(29)" remarks="申請フォーム別経費科目ID">
      <constraints primaryKey="true" nullable="false"/>
    </column>
    <column name="hojin_code" type="VARCHAR(5)" remarks="法人コード"><constraints nullable="false"/></column>
    <column name="shinsei_form_id" type="VARCHAR(29)" remarks="申請フォームID"><constraints nullable="false"/></column>
    <column name="shinsei_form_version" type="BIGINT" defaultValueNumeric="1" remarks="申請フォームバージョン"><constraints nullable="false"/></column>
    <column name="keihi_kamoku_id" type="VARCHAR(29)" remarks="経費科目ID"><constraints nullable="false"/></column>
    <column name="hyoji_jun" type="NUMBER(4)" defaultValueNumeric="100" remarks="表示順"><constraints nullable="true"/></column>
    <column name="delete_flag" type="NUMBER(1)" defaultValueNumeric="0" remarks="削除フラグ: 0:使用中、1:削除済"><constraints nullable="true"/></column>
  </createTable>
  <createIndex indexName="tm_shinsei_form_keihi_kamoku_index_key" tableName="tm_shinsei_form_keihi_kamoku" schemaName="keihi_com">
    <column name="hojin_code"/><column name="shinsei_form_id"/><column name="shinsei_form_version"/>
  </createIndex>
  <addUniqueConstraint schemaName="keihi_com" tableName="tm_shinsei_form_keihi_kamoku"
    columnNames="hojin_code, shinsei_form_id, shinsei_form_version, keihi_kamoku_id, delete_flag"
    constraintName="uk_tm_shinsei_form_keihi_kamoku"/>
</changeSet>
```
> 4 file bảng con phải `<include>` vào `keihi_com_changelog.xml`. Verify precision NUMBER(11) trước khi finalize.

---

## 6. API Endpoints

> ↔️ KHÔNG thêm endpoint CRUD mới cho shinsei form. Mở rộng request/response endpoint hiện có + thêm 1 param cho search.

| # | Method | Path | Thay đổi |
|---|---|---|---|
| 1 | POST | `/shinsei-form` (add) | ✏️ Request/response `ShinseiForm` +13 field +4 list con; service lưu list con theo version mới + validate §4.1 |
| 2 | PUT | `/shinsei-form` (update→add) | ✏️ Như trên (đi qua `addShinseiForm`) |
| 3 | GET | `/shinsei-form/{shinseiFormId}` | ✏️ Response +13 field +4 list con (kèm enrich tên経費科目/部署/役職/従業員) |
| 4 | POST | `/shinsei-form/search` | ✏️ Thêm param `jugyoinId` (optional) để lọc form theo quyền (§4.3) |
| 5 | (view list cho màn tạo申請) `viewListShinseiForm` | ✏️ Thêm param `jugyoinId` → lọc theo busho/yakushoku/jugyoin (OR) |

**Class liên quan (extend, không tạo mới)**:
- `TmShinseiForm` (entity, +13 field) + 4 entity con mới.
- `ShinseiFormDto` (+13 field +4 list con) + 4 DTO con mới.
- `ShinseiFormCrud` / `ShinseiFormAdapter` (CRUD 4 bảng con).
- `TmShinseiFormRepository` + 4 repository con mới.
- `ShinseiFormService` (`addShinseiForm`: lưu list con + validate §4.1; search/viewList: filter theo jugyoinId).
- `ShinseiFormApiDelegateImpl` (map list con).
- `BeanConfiguration` (nếu thêm bean adapter mới).

**OpenAPI source**: `api_interface_generate_tool/specification/openapi.yml` — cập nhật model `ShinseiForm` (thêm field + sub-models `ShinseiFormKeihiKamoku`, `ShinseiFormBusho`, `ShinseiFormYakushoku`, `ShinseiFormJugyoin`) + param `jugyoinId` cho search/viewList → regen.

**Modal search masters**: ✅ tái dùng API search hiện có (経費科目/部署/役職/従業員) — FE đã tích hợp, KHÔNG cần endpoint mới (clar 6.7).

---

## 7. Open Issues / TBD

| # | Điểm TBD | Assumption tạm | Severity | Câu hỏi gốc | Cần xử lý trước |
|---|---|---|---|---|---|
| 1 | TableCode để gen ID cho 4 bảng con (`SqlUtil.generateId`) | Cấp 4 TableCode mới (vd: TMxxx) cho từng bảng; theo dõi mâu thuẫn TM023/TM018 ở current_analysis §9.8 | 🟢 Low | (mới phát sinh khi merge) | Trước khi code adapter |

**Severity legend**: High = sửa schema/contract · Medium = sửa logic vài giờ · Low = chỉnh constant/config.

✅ **Không còn TBD High/Medium** (11/11 clarification đã 🟢 Answered) → `status: ready-for-implementation`.

---

## 8. Cross-screen Impact (EXTEND)

### Affected screens
| Màn | Lý do impact | Severity | Files cần update (dự kiến) |
|---|---|---|---|
| Màn tạo申請 / list form khả dụng | Lọc form theo `jugyoinId` (busho/yakushoku/jugyoin, OR) + `下位階層を含む` động | 🔴 | `ShinseiFormService.searchShinseiForm/viewListShinseiForm`, `TmShinseiFormRepository`, `ShinseiJoho*` (nơi list form cho người nộp) |
| Màn tạo/validate申請 (meisai) | Check trần tổng tiền (`shinsei_gokei_kingaku_jogen`, Error/Alert) khi submit申請 | 🔴 | logic validate tổng tiền shinsei |
| Màn detail 経費科目 (KeihiKamoku) | Consistency check loại meisai科目 ↔ nhóm 1 (A197); FE lọc list trong modal | 🟡 | `ShinseiFormService` (check khi save), tham chiếu cấu hình meisai của `tm_keihi_kamoku` |
| Setting Kaisha / 制限設定 | Đọc flag `gaikaRiyoUmu`, `shinseishaRateNyuryoku`, 「ワークフロー変更ON,OFF」 để hiển thị nhóm 1 & 4 | 🟡 | đọc flag (không sửa) |
| Màn chọn workflow khi tạo申請 | Cho phép người申請 đổi workflow nếu `workflow_henko_kanou_flag=1` | 🟡 | logic màn申請 |

### Action items
- [ ] BE: `searchShinseiForm`/`viewListShinseiForm` nhận `jugyoinId`, lọc form theo busho/yakushoku/jugyoin (OR), busho mở rộng động khi `下位階層を含む=1`.
- [ ] BE: logic check trần tổng tiền khi tạo/submit申請 (Error chặn / Alert cảnh báo theo `shinsei_gokei_jogen_check_kubun`).
- [ ] BE: consistency check `error.shinseiForm.keihiKamoku.meisaiTypeMismatch` khi save form (chỉ khi `keihi_kamoku_seigen_flag=1`).
- [ ] BE: lọc loại meisai đính kèm khi tạo申請 theo nhóm 1 (độc lập `keihiMeisaiTempu`).
- [ ] Đăng ký message key mới: `error.shinseiForm.keihiKamoku.required`, `error.shinseiForm.keihiKamoku.meisaiTypeMismatch`.
- [ ] Các sheet/màn khác của feature (02_経費科目, 03_hóa đơn, 04/05 template người tham gia, 06 màn ảnh hưởng, 07 list meisai) — phân tích riêng; trần tiền & loại meisai có thể đối chiếu thêm ở các sheet này.

---

## 9. References

- Baseline: [`current_state/current_analysis.md`](./current_state/current_analysis.md) (v1.0.0)
- Spec analysis: [`spec_analysis.md`](./spec_analysis.md) (v1.0.0)
- Clarifications: [`clarifications.md`](./clarifications.md) (v1.0.0 — 11/11 🟢)
- Diff: [`diff_with_current.md`](./diff_with_current.md) (v1.0.0)
- Spec gốc: `documents/backend/feature_ApplicationRulesAndMeetingExpenses/ApplicationRulesAndMeetingExpenses_20260514 _VN.xlsx` › sheet `01_Setting detail shinsei form`
- DB design: `documents/backend/feature_ApplicationRulesAndMeetingExpenses/db_tables_application_rules_meeting_expenses.xlsx` › 5 sheet `tm_shinsei_form*`
- Convention: `.claude/rules/api-conventions.md`, `.claude/rules/database.md`
- Ảnh: `images/image_A4.png`

---

## Version History

### [1.0.0] - 2026-06-09
- Initial final spec (EXTEND).
- Dựa trên current_analysis v1.0.0 + spec_analysis v1.0.0 + clarifications v1.0.0 (11/11 🟢) + diff v1.0.0.
- Scope: thêm card 「申請ルールの設定」 (7 nhóm) — 13 cột mới trên `tm_shinsei_form` + 4 bảng con versioned.
- 1 TBD (0 High, 0 Medium, 1 Low — TableCode gen ID).
- Status: ready-for-implementation.
</content>
