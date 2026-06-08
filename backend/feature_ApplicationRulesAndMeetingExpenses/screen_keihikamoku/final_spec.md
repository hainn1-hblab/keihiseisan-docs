---
version: 1.0.0
status: ready-for-implementation
last_updated: 2026-06-08
mode: EXTEND
based_on_spec_analysis_version: 1.0.0
based_on_clarifications_version: 1.0.0
based_on_current_analysis_version: 1.0.0
based_on_diff_version: 1.0.0
unresolved_questions_count: 2
---

> 📘 **EXTEND** — Đây là file spec chốt cho phase EXTEND màn 経費科目 (KeihiKamoku), feature "参加者入力 / 会議費".
> - Đây là màn ĐÃ CÓ SẴN. File này CHỈ mô tả phần THÊM/ĐỔI/ẢNH HƯỞNG.
> - Baseline (đang chạy): xem [`current_state/current_analysis.md`](./current_state/current_analysis.md). KHÔNG lặp lại.
> - Ký hiệu — 🆕 NEW · ✏️ MODIFIED · ↔️ UNCHANGED.
> - 2 điểm còn ⚠️ **TBD** (đều Medium/Low, có assumption tạm để code) — xem §7.

# Final Spec — Màn 経費科目 (KeihiKamoku) — EXTEND "参加者入力 / 会議費"

## 1. Tổng quan

Bổ sung 1 section mới **"参加者入力（会議費／接待交際費）"** vào modal `経費科目詳細`, cho phép cấu hình mục chi phí kiểu **会議費 / 接待交際費** yêu cầu nhập **người tham gia (参加者)** và giới hạn **số tiền/người (一人当たり上限金額)**.

8 cờ cấu hình này **lưu** ở `tm_keihi_kamoku` nhưng **drive behaviour** ở màn tạo 明細 và nhiều màn khác (xem §8).

### Scope (EXTEND)
- 🆕 8 cột mới trên `tm_keihi_kamoku` (participant settings + per-person limit).
- 🆕 1 section UI mới trong modal 経費科目詳細.
- ✏️ Màn list: thêm cột hiển thị 8 field + CSV import/export thêm 8 cột (Q6.7).
- ✏️ 1 label section UI: `アクション・カラー設定` → `アラート・エラー設定` (⚠️ TBD-2).
- ↔️ Toàn bộ field/logic còn lại theo [current_analysis](./current_state/current_analysis.md).

| # | Tên màn | Mô tả |
|---|---|---|
| 1 | 経費科目詳細 (modal create/edit) | Thêm section 参加者入力 |
| 2 | 経費科目一覧 (list) | Thêm cột hiển thị + cột CSV (không thêm điều kiện search) |

---

## 2. Màn hình List — 経費科目一覧

> ↔️ Paging, sort, button, **điều kiện search giữ nguyên** theo [current_analysis §8](./current_state/current_analysis.md). Q6.7: **KHÔNG** thêm điều kiện search.

### 2.1 ✏️ Search fields
↔️ UNCHANGED — không thêm điều kiện search cho 8 field mới.

### 2.2 ✏️ Table columns
🆕 Thêm cột hiển thị cho 8 field mới (read-only) vào bảng list, đồng bộ với modal detail. (Thứ tự/nhãn cột: theo FE, dùng nhãn JP ở §3.2.)

### 2.3 Action buttons
↔️ UNCHANGED (CSV出力 / CSV取込 / 新規登録 / 勘定科目最新化).

### 2.4 Pagination & Sort
↔️ UNCHANGED — sort fields giữ nguyên (không sort theo 8 field mới).

---

## 3. Màn hình Detail — modal 経費科目詳細

### 3.1 ↔️ Field UNCHANGED
Toàn bộ section cũ (基本情報 / 選択可能な明細 / 申請者が…選択できる項目 / nhóm cờ check) giữ nguyên — xem [current_analysis §8](./current_state/current_analysis.md). Chỉ THÊM 1 section mới + đổi 1 label (§3.3).

### 3.2 🆕 Field mới — Section "参加者入力（会議費／接待交際費）"

| # | Label (JP) | Tiếng Việt | Kiểu UI | DB column | Required |
|---|---|---|---|---|---|
| 1 | 参加者の入力が必要な経費科目 | Mục chi phí cần nhập người tham gia | Checkbox | `sankasha_nyuryoku_hitsuyo_flag` | Không (default 0) |
| 2 | 一人当たり上限金額 | Số tiền tối đa / người | Number input | `hitori_atari_jogen_kingaku` | Không (xem §4.1) |
| 3 | 一人当たり上限金額超過時の種別 | Loại xử lý khi vượt limit | Radio: エラー / アラート | `hitori_atari_jogen_check_kubun` | Không (cho phép 無し=0) |
| 4 | 超過時メッセージ | Message khi vượt limit | Textarea | `hitori_atari_jogen_message` | Không (optional) |
| 5 | 明細作成時、相手先会社名・相手先参加者氏名の入力を行う | Bật field người tham gia đối tác | Checkbox | `tasha_sankasha_nyuryoku_flag` | Không (default 0) |
| 6 | …の入力を必須とする | Bắt buộc nhập field đối tác | Checkbox | `tasha_sankasha_hissu_flag` | Không (default 0) |
| 7 | 明細作成時、自社参加者の選択を行う | Bật chọn người tham gia nội bộ | Checkbox | `jisha_sankasha_sentaku_flag` | Không (default 0) |
| 8 | …の選択を必須とする | Bắt buộc chọn người tham gia nội bộ | Checkbox | `jisha_sankasha_hissu_flag` | Không (default 0) |

### 3.3 ✏️ Field MODIFIED

| Field | Hiện tại | Đổi thành | Lý do |
|---|---|---|---|
| (label section cờ check) | `アクション・カラー設定` | `アラート・エラー設定` | Theo ảnh spec. ⚠️ TBD-2 (chờ confirm 6.8) |

### 3.4 Action buttons
↔️ UNCHANGED (`キャンセル` / `保存`).

### 3.5 Layout & UI behavior
- Section "参加者入力" đặt giữa "申請者が…選択できる項目" và "アラート・エラー設定". Xem ảnh: [`images/image_A4.png`](./images/image_A4.png).
- Field #2/#3/#4 **enable khi #1 = checked**; disable khi #1 = unchecked (chỉ disable UI, **không reset giá trị** — §4.2).
- Checkbox #6 disable nếu #5 chưa check; #8 disable nếu #7 chưa check (FE-only — §4.2).

---

## 4. Business Rules

### 4.1 🆕 Validation rules (Q6.1, Q6.2)
- `hitori_atari_jogen_kingaku`: **maxlength = 5 chữ số → `@Range(0, 99999)`** (theo spec, dù cột DB là NUMBER(11) dự phòng). Cho phép trống (= không giới hạn).
- `hitori_atari_jogen_check_kubun`: cho phép `0=無し` (KHÔNG bắt buộc chọn エラー/アラート kể cả khi master ON). Giá trị hợp lệ ∈ {0,1,2} (tái dùng `CheckFlag`).
- **Nếu `hitori_atari_jogen_check_kubun` ∈ {1=エラー, 2=アラート}** → `hitori_atari_jogen_kingaku` **bắt buộc > 0** (ném `BadRequestException`, theo đúng pattern `checkJogenKingaku` hiện có). Nếu = 0 → reset kingaku về null/0.
- `hitori_atari_jogen_message`: **optional**, max 1000 ký tự (`@Size(max=1000)`).
- 6 cờ còn lại (`sankasha_nyuryoku_hitsuyo_flag`, `tasha_*`, `jisha_*`): `@EnumNamePattern("^(0|1)$")`, default 0.

### 4.2 🆕 Field visibility & dependency (Q6.3, Q6.4)
- **#1 master**: khi unchecked → FE disable #2/#3/#4. **BE giữ nguyên giá trị đã nhập** (KHÔNG reset) — chỉ ẩn/disable trên UI. (Assumption tạm, Q6.3 — có thể đổi sau.)
- **#6 phụ thuộc #5 / #8 phụ thuộc #7**: **chỉ FE disable checkbox**; **BE KHÔNG validate ràng buộc này** (để tránh lỗi với data cũ — backward compatibility, Q6.4).

### 4.3 🆕 Quy tắc đặc biệt
- 種別 (check_kubun) dùng cùng khái niệm Alert/Error của 明細: **エラー** = không cho申請; **アラート** = cảnh báo nhưng vẫn申請 được.
- Message chỉ hiển thị gợi ý; hệ thống KHÔNG tự đổi mục chi phí (user tự quyết định).

### 4.4 Save strategy
↔️ UNCHANGED — single-table save (`saveKeihiKamoku`), không header+detail. Thêm 8 field vào payload add/update.

### 4.5 Delete behavior
↔️ UNCHANGED — soft delete; guard 標準科目 (E082) + đang dùng meisai (E065) giữ nguyên.

### 4.6 Display & sort
↔️ UNCHANGED.

### 4.7 Access control (role-based)
↔️ UNCHANGED — add/update/delete/search: `DEPARTMENT_MANAGEMENT (5)`, `SUPER_ADMIN (6)`.

### 4.8 ✏️ Update guard khi tắt cờ sankasha (⚠️ TBD-1, Q6.6)
- **Assumption tạm để code**: KHÔNG thêm guard E152 cho `sankasha_nyuryoku_hitsuyo_flag` — cho phép tắt, data participant cũ trong meisai giữ nguyên, chỉ ẩn UI lần sau. (Nhất quán với hướng "giữ nguyên data cũ" của Q6.3/Q6.4.)
- ⚠️ Cần PO confirm trước UAT — nếu cần chặn (giống E152) thì bổ sung check `existsByHojinCodeAndKeihiKamokuIdAndTorokuHoho...` mở rộng.

### 4.9 ✏️ Relationship với field "出席者登録" cũ (Q6.5 — RESOLVED)
- 3 field cũ (`shussekisha_toroku_umu`, `shussekisha_toroku_check`, `jizen_shinsei_bango_check`) **giữ nguyên dead, KHÔNG cleanup** (backward compatibility). Adapter vẫn ép = 0 như hiện tại.
- Khái niệm 出席者(attendee) cũ và 参加者(participant) mới **độc lập** — không liên quan nghiệp vụ.

---

## 5. Database Schema

> Nguồn: `db_tables_application_rules_meeting_expenses.xlsx`, sheet `tm_keihi_kamoku`.
> ALTER bảng đã tồn tại — KHÔNG tạo bảng mới, KHÔNG đổi cột cũ.

### 5.1 🆕 Cột thêm vào `keihi_com.tm_keihi_kamoku`

| Column | Data Type | Length | Nullable | Default | Description (remarks JP) | Dùng khi |
|---|---|---|---|---|---|---|
| `sankasha_nyuryoku_hitsuyo_flag` | NUMBER | 1 | No | 0 | 参加者入力必要フラグ: 0:不要、1:必要 | Master toggle |
| `hitori_atari_jogen_kingaku` | NUMBER | 11* | Yes | null | 一人当たり上限金額 | Limit/người (*validate max 5 digits) |
| `hitori_atari_jogen_check_kubun` | NUMBER | 1 | No | 0 | 一人当たり上限超過時種別: 0:無し、1:エラー、2:アラート | Loại check |
| `hitori_atari_jogen_message` | VARCHAR | 1000 | Yes | null | 一人当たり上限超過時メッセージ | Message khi vượt |
| `tasha_sankasha_nyuryoku_flag` | NUMBER | 1 | No | 0 | 相手先会社名・参加者氏名入力フラグ: 0:無し、1:有り | Bật field đối tác |
| `tasha_sankasha_hissu_flag` | NUMBER | 1 | No | 0 | 相手先会社名・参加者氏名必須フラグ: 0:任意、1:必須 | Bắt buộc đối tác |
| `jisha_sankasha_sentaku_flag` | NUMBER | 1 | No | 0 | 自社参加者選択フラグ: 0:無し、1:有り | Bật chọn NV nội bộ |
| `jisha_sankasha_hissu_flag` | NUMBER | 1 | No | 0 | 自社参加者選択必須フラグ: 0:任意、1:必須 | Bắt buộc NV nội bộ |

> *DB design ghi numeric(11) (dự phòng), nhưng validation chính thức = 5 chữ số (Q6.1). Cột để NUMBER(11) cho buffer; ràng buộc max ở tầng DTO.
> Tất cả default 0/null → **không cần migrate data row cũ** (row cũ tự nhận = "không phải会議費"), backward compatible.

### 5.2 ↔️ Cột hiện có
Giữ nguyên toàn bộ. Xem [current_analysis §1.2](./current_state/current_analysis.md).

### 5.3 Quan hệ
Không phát sinh FK mới trên `tm_keihi_kamoku`. (Quan hệ cross-table — `tr_meisai_sankasha`, `tm_sankasha_template` — thuộc scope màn meisai/template, xem §8.)

### 5.4 Skeleton Liquibase ALTER (tham khảo)

```xml
<changeSet id="20260608_tm_keihi_kamoku_add_column_sankasha" author="ducna1">
  <addColumn schemaName="keihi_com" tableName="tm_keihi_kamoku">
    <column name="sankasha_nyuryoku_hitsuyo_flag" type="NUMBER(1)" defaultValueNumeric="0"
            remarks="参加者入力必要フラグ: 0:不要、1:必要">
      <constraints nullable="false"/>
    </column>
    <column name="hitori_atari_jogen_kingaku" type="NUMBER(11)"
            remarks="一人当たり上限金額">
      <constraints nullable="true"/>
    </column>
    <column name="hitori_atari_jogen_check_kubun" type="NUMBER(1)" defaultValueNumeric="0"
            remarks="一人当たり上限超過時種別: 0:無し、1:エラー、2:アラート">
      <constraints nullable="false"/>
    </column>
    <column name="hitori_atari_jogen_message" type="VARCHAR(1000)"
            remarks="一人当たり上限超過時メッセージ">
      <constraints nullable="true"/>
    </column>
    <column name="tasha_sankasha_nyuryoku_flag" type="NUMBER(1)" defaultValueNumeric="0"
            remarks="相手先会社名・参加者氏名入力フラグ: 0:無し、1:有り">
      <constraints nullable="false"/>
    </column>
    <column name="tasha_sankasha_hissu_flag" type="NUMBER(1)" defaultValueNumeric="0"
            remarks="相手先会社名・参加者氏名必須フラグ: 0:任意、1:必須">
      <constraints nullable="false"/>
    </column>
    <column name="jisha_sankasha_sentaku_flag" type="NUMBER(1)" defaultValueNumeric="0"
            remarks="自社参加者選択フラグ: 0:無し、1:有り">
      <constraints nullable="false"/>
    </column>
    <column name="jisha_sankasha_hissu_flag" type="NUMBER(1)" defaultValueNumeric="0"
            remarks="自社参加者選択必須フラグ: 0:任意、1:必須">
      <constraints nullable="false"/>
    </column>
  </addColumn>
  <rollback>
    <dropColumn schemaName="keihi_com" tableName="tm_keihi_kamoku" columnName="sankasha_nyuryoku_hitsuyo_flag"/>
    <dropColumn schemaName="keihi_com" tableName="tm_keihi_kamoku" columnName="hitori_atari_jogen_kingaku"/>
    <dropColumn schemaName="keihi_com" tableName="tm_keihi_kamoku" columnName="hitori_atari_jogen_check_kubun"/>
    <dropColumn schemaName="keihi_com" tableName="tm_keihi_kamoku" columnName="hitori_atari_jogen_message"/>
    <dropColumn schemaName="keihi_com" tableName="tm_keihi_kamoku" columnName="tasha_sankasha_nyuryoku_flag"/>
    <dropColumn schemaName="keihi_com" tableName="tm_keihi_kamoku" columnName="tasha_sankasha_hissu_flag"/>
    <dropColumn schemaName="keihi_com" tableName="tm_keihi_kamoku" columnName="jisha_sankasha_sentaku_flag"/>
    <dropColumn schemaName="keihi_com" tableName="tm_keihi_kamoku" columnName="jisha_sankasha_hissu_flag"/>
  </rollback>
</changeSet>
```

> Thêm `<include file="tm_keihi_kamoku.xml" .../>` đã có sẵn — chỉ append changeset vào file `tm_keihi_kamoku.xml`. Verify precision trước khi finalize.

---

## 6. API Endpoints

> ↔️ KHÔNG thêm endpoint mới. Mở rộng request/response các endpoint hiện có với 8 field.

| # | Method | Path | Thay đổi |
|---|---|---|---|
| 1 | POST | /keihi-kamoku (add) | Request +8 field |
| 2 | PUT | /keihi-kamoku (update) | Request +8 field |
| 3 | GET | /keihi-kamoku/{id} | Response +8 field |
| 4 | POST | /keihi-kamoku/search | Response (list) +8 field |
| 5 | POST | /keihi-kamoku/view-list | Response (list) +8 field |
| 6 | GET/POST | csv sample / download / import | +8 cột CSV (Q6.7) |

**Class liên quan (extend, KHÔNG tạo mới)**:
- Entity `TmKeihiKamoku` (+8 field).
- DTO `KeihiKamokuDto` (+8 field + validation + `@LogOperation`).
- API model `KeihiKamoku` — ✏️ **sửa class bằng tay** (Q6.9).
- `KeihiKamokuCsvDto` (+8 cột) — Q6.7.
- `KeihiKamokuService.addKeihiKamoku/updateKeihiKamoku` (+default + `checkHitoriAtariJogen()` theo pattern `checkJogenKingaku`).
- `KeihiKamokuAdapter.saveKeihiKamoku` (copy 8 field; giữ nguyên việc ép 3 field 出席者 cũ = 0).

**OpenAPI source**: ⚠️ Không tồn tại trong `api_interface_generate_tool/specification/openapi.yml` (model legacy gen 2021) → **sửa model bằng tay** (Q6.9 RESOLVED).

---

## 7. Open Issues / TBD

| # | Điểm TBD | Assumption tạm | Severity | Câu hỏi gốc | Cần xử lý trước |
|---|---|---|---|---|---|
| C1 | Guard khi tắt `sankasha_nyuryoku_hitsuyo_flag` mà meisai đang dùng | KHÔNG chặn, giữ data cũ, chỉ ẩn UI | 🟡 Medium | clarifications #6.6 | Trước UAT |
| C2 | Label section: `アクション・カラー設定` → `アラート・エラー設定` | Đổi label theo ảnh spec (chỉ UI) | 🟢 Low | clarifications #6.8 | Trước release |

**Severity legend**: High = sửa schema/contract · Medium = sửa logic vài giờ · Low = chỉnh constant/config.

✅ **Không có TBD High** → `status: ready-for-implementation` (code được với assumption; C1/C2 chỉ block UAT/release).

---

## 8. Cross-screen Impact (EXTEND)

> `tm_keihi_kamoku` là master config — 8 cờ này drive behaviour nhiều màn. Chi tiết: [`diff_with_current.md §9`](./diff_with_current.md).

### Affected screens
| Màn | Lý do impact | Severity | Files cần update |
|---|---|---|---|
| Màn tạo 明細 / Receipt Detail | Đọc 8 cờ → render UI người tham gia + check 一人当たり; ghi `tr_meisai_sankasha` + `hitori_atari_kingaku` (tr_meisai_joho) | 🔴 High | MeisaiJoho service/adapter, entity mới `TrMeisaiSankasha`, màn 領収書明細 |
| Detail Template | tm_meisai_template +`sankasha_template_id` | 🟡 Medium | [`../screen_template_meisai/`](../screen_template_meisai/final_spec.md) |
| Participant Template | Bảng mới tm_sankasha_template(_shosai) | 🟡 Medium | [`../screen_detail_template_nguoi_tham_gia/`](../screen_detail_template_nguoi_tham_gia/final_spec.md) |
| Màn list 明細 | Thêm cột 参加人数/一人当たり金額/他社参加者会社名・氏名/自社参加者 | 🟡 Medium | màn list meisai |
| Shiwake export | Output item người tham gia (tm_shutsuryoku_komoku_shurui) | 🟡 Medium | ShiwakeExport |
| CSV meisai | Thêm field người tham gia | 🟡 Medium | MeisaiJoho CSV |
| 申請確認 | Hiển thị người tham gia | 🟢 Low | màn xác nhận申請 |

### Action items
- [ ] Đồng bộ với team màn meisai: `tr_meisai_sankasha` (unique key `hojin_code, meisai_id, sankasha_kubun, hyoji_jun, delete_flag`) + `hitori_atari_kingaku` ở `tr_meisai_joho` (CS-1/CS-2).
- [ ] Confirm xử lý meisai cũ khi tắt cờ sankasha (gắn với TBD C1 / Q6.6).
- [ ] Điều phối thứ tự implement: **keihikamoku (nguồn config) trước** → meisai → template → list/export.
- [ ] Đồng bộ marker tới final_spec `screen_template_meisai` & `screen_detail_template_nguoi_tham_gia` (cùng feature).

---

## 9. References

- Baseline: [`current_state/current_analysis.md`](./current_state/current_analysis.md) (v1.0.0)
- Spec analysis: [`spec_analysis.md`](./spec_analysis.md) (v1.0.0)
- Clarifications: [`clarifications.md`](./clarifications.md) (v1.0.0 — 7/9 answered, 2 pending C1/C2)
- Diff: [`diff_with_current.md`](./diff_with_current.md) (v1.0.0)
- DB design: `documents/backend/feature_ApplicationRulesAndMeetingExpenses/db_tables_application_rules_meeting_expenses.xlsx` (sheet `tm_keihi_kamoku`)
- Convention: `.claude/rules/api-conventions.md`, `.claude/rules/database.md`
- Màn liên quan: [`../screen_template_meisai/final_spec.md`](../screen_template_meisai/final_spec.md), [`../screen_detail_template_nguoi_tham_gia/final_spec.md`](../screen_detail_template_nguoi_tham_gia/final_spec.md)
- Ảnh: [`images/image_A4.png`](./images/image_A4.png)

---

## Version History

### [1.0.0] - 2026-06-08

- Initial final spec (EXTEND).
- Dựa trên current_analysis v1.0.0 + spec_analysis v1.0.0 + clarifications v1.0.0 + diff v1.0.0.
- Scope: thêm 8 cột "参加者入力/会議費" vào `tm_keihi_kamoku` + section UI mới trong modal + cột list/CSV.
- 2 TBD (0 High, 1 Medium C1, 1 Low C2).
- Status: ready-for-implementation.
