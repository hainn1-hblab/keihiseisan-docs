---
version: 1.0.0
last_updated: 2026-06-04
based_on_current_analysis_version: 1.0.0
based_on_spec_analysis_version: 1.0.0
---

# Diff Analysis — Template Meisai Extend

## 0. Tóm tắt
- Field NEW: **4** (DB columns) + 1 UI control (button điều hướng, không phải field DB)
- Field MODIFIED: **3** (`torokuHoho`, `kingaku` ngữ nghĩa, `searchParam.torokuHohos`)
- Field REMOVED/DEPRECATED: **0**
- Field UNCHANGED: ~30 (toàn bộ field hiện hành giữ nguyên)
- Breaking changes (🔴): **2** (giá trị `torokuHoho` mới → validation; đổi ngữ nghĩa `kingaku` theo mode)
- Non-breaking, FE-affecting (🟡): **6**
- BE-only (🟢): **1**

---

## 1. Field NEW (chưa có trong current state)

Nguồn: sheet DB `tm_meisai_template` (db_tables xlsx) + sheet spec `05`.

| # | Field (JP) | Field (JSON/DB) | Type | Mô tả | Source spec | Impact |
|---|---|---|---|---|---|---|
| 1 | 参加者テンプレートID | `sankashaTemplateId` / `sankasha_template_id` | VARCHAR(29), null, def NULL | FK tham chiếu `tm_sankasha_template`. Lưu khi chọn "参加者テンプレートを適用する" | db row2; spec Q73–Q83, A41 | 🟡 |
| 2 | 外貨種類ID | `gaikaShuruiId` / `gaika_shurui_id` | VARCHAR(29), null, def NULL | Loại ngoại tệ (master GaikaShurui) | db row3; spec K119, A101/102 | 🟡 |
| 3 | 円換算金額 | `enKansanKingaku` / `en_kansan_kingaku` | NUMERIC, null | Số tiền quy đổi yên = kingaku × rate | db row4; spec R112/S113 | 🟡 |
| 4 | レート | `rate` | NUMERIC, null, **def 1.0** | Tỷ giá ngoại tệ | db row5; spec K121, J125 | 🟡 |

> ✅ Tên field 1–4 **khớp 100%** với field đã tồn tại ở `TrMeisaiJoho` (`gaikaShuruiId`, `rate`, `enKansanKingaku` kiểu `BigDecimal`) → reuse pattern, ít rủi ro mapping.

**UI control mới (không phải cột DB)**:
- Pulldown `参加者テンプレートを適用する` (bind tới `sankashaTemplateId`).
- Button `参加者をテンプレート一覧` — chỉ điều hướng FE sang màn sankasha template list.

---

## 2. Field MODIFIED (đã có nhưng spec đổi behaviour)

| # | Field | Current | Spec mới | Loại thay đổi | Impact |
|---|---|---|---|---|---|
| 1 | `torokuHoho` | Giá trị `1\|2\|4` (validation chặn 3); 2 mode UI (領収書/経路) | Thêm 2 mode `領収書(外貨)` + `外貨レート証明書` → cần giá trị mới (TBD 6.1) | Validation + branch logic + filter | 🔴 |
| 2 | `kingaku` (金額) | Số tiền **yên** ở 領収書 | Ở mode ngoại tệ = **外貨金額** (số tiền ngoại tệ); yên nằm ở `enKansanKingaku` | Đổi ngữ nghĩa theo mode | 🔴 |
| 3 | `MeisaiTemplateSearchParamDto.torokuHohos` | Mỗi phần tử regex `1\|2\|4\|` | Phải chấp nhận giá trị mode mới | Validation search | 🟡 |

---

## 3. Field REMOVED/DEPRECATED

| # | Field | Lý do bỏ trong spec mới | Migration plan |
|---|---|---|---|
| — | (không có) | Spec chỉ ADD, không bỏ field nào | — |

> `torokuHoho = 3 (日当)` vẫn ở trạng thái "chết ở tầng app" như current — spec mới **không** nhắc tới (không resurrect, không bỏ hẳn).

---

## 4. Field UNCHANGED (verify không miss)

Toàn bộ field hiện hành giữ nguyên: `meisaiTemplateMei`, `naiyo`, `bushoId`, `projectId`, `keihiKamokuId`,
`zeiKubunId`, `kashikataKanjoKamokuId`, `kashikataHojoKamokuId`, `hyojiJun`, `memo`, `hizuke`, các field keiro
(`shuppatsuchi`, `tochakuchi`, `shiharaiHoho`, `unchinShubetsu`, `keiroId`, `keiyu1..3`, `teikiKukanKojo`,
`keiroApiFlag`...), `deleteFlag`, `updateVersion`, audit fields. Modal 領収書 thường chỉ thêm đúng 1 control
(参加者テンプレート); các field cũ y nguyên (mockup A41).

---

## 5. Business rule changes

| # | Rule | Current behaviour | Spec mới | Impact |
|---|---|---|---|---|
| R1 | Mode ngoại tệ | Không có | `領収書(外貨)` + `外貨レート証明書` chỉ hiển thị/CRUD khi setting ngoại tệ công ty BẬT | 🟡 |
| R2 | Tính 円換算金額 | Không có | `enKansanKingaku = kingaku × rate`, field read-only | 🟢 (BE compute) / TBD 6.3 |
| R3 | Áp dụng 参加者テンプレート | Không có | 領収書 + 領収書(外貨) có; 外貨レート証明書 KHÔNG (A162) | 🟡 |
| R4 | rate default | Không có | default `1.0` | 🟢 |
| R5 | Role check | 4 role (DEPT_MGMT, SUPER_ADMIN, APPROVED, REGISTRATION) | Spec không nhắc → giả định GIỮ NGUYÊN | 🟢 (TBD 6.11) |
| R6 | Delete/soft-delete | Soft delete | Spec không đổi → giữ nguyên | — |

---

## 6. Schema impact analysis

**Cần ALTER TABLE**: `keihi_com.tm_meisai_template` — ADD 4 cột (1 changeset Liquibase `addColumn`):

| Cột | Type | Nullable | Default | Ghi chú |
|---|---|---|---|---|
| `sankasha_template_id` | VARCHAR(29) | YES | NULL | — |
| `gaika_shurui_id` | VARCHAR(29) | YES | NULL | — |
| `en_kansan_kingaku` | NUMERIC | YES | NULL | giống `kingaku` |
| `rate` | NUMERIC | YES | (def 1.0?) | giống `tr_meisai_joho.rate` — xác nhận default ở 6.4 |

- **Migration data cho row cũ**: KHÔNG cần (4 cột nullable; row cũ = NULL, hợp lệ).
- **Index/Unique mới**: KHÔNG (spec không yêu cầu). Lưu ý: bảng hiện **chưa có** index/unique nào ngoài PK.
- **Cột `toroku_hoho`** (VARCHAR(1)): nếu mode mới dùng giá trị 1 ký tự (vd `5`,`6`) thì **không cần** đổi type. Nếu cần >9 mode → mới phải mở rộng. → phụ thuộc 6.1.
- **KHÔNG cần cột "mode/gaika flag" mới** (DB sheet không liệt kê) → củng cố giả định mode mới = giá trị `toroku_hoho` mới.

→ **Schema thay đổi mang tính ADDITIVE, non-breaking ở tầng DB.** Phần "breaking" nằm ở validation/logic (`torokuHoho`, ngữ nghĩa `kingaku`), không ở schema.

---

## 7. API impact analysis

| Endpoint | Đổi request/response? | Endpoint mới? | Backward compatible với FE? |
|---|---|---|---|
| POST `/meisaiTemplate` (add) | + 4 field, + giá trị torokuHoho mới, logic ngoại tệ | Không | Có (field optional) |
| PUT `/meisaiTemplate` (update) | Như add | Không | Có |
| DELETE `/meisaiTemplate` | Không | Không | Có |
| GET `/meisaiTemplate/{id}` | Response + 4 field | Không | Có (additive) |
| POST `/meisaiTemplate/search` | + giá trị torokuHohos mới; response + 4 field | Không | Có |
| POST `/meisaiTemplate/view-list` | Như search | Không | Có |

- **Không cần endpoint mới.** Button `参加者をテンプレート一覧` chỉ điều hướng FE → dùng API sankasha-template đã build.
- Model `MeisaiTemplate` (OpenAPI) + `MeisaiTemplateDto` + `MeisaiTemplateSearchParamDto`: thêm 4 field + nới regex `torokuHoho`.
- ⚠️ **Cần xác định file OpenAPI spec gốc** (endpoint không có trong `openapi.yml` đang track — xem 8.2 / 6.12).

---

## 8. Verification của 3 discrepancy đã catch ở Phase 1

### 8.1 sankasha_template_id — ✅ CONFIRMED (khả năng A đúng)
DB sheet `tm_meisai_template` row 2: `sankasha_template_id varchar(29) nullable` = `参加者テンプレートID`.
→ Đúng như Phase 1 dự đoán: **spec mới THÊM cột này**. `codebase_pointers.md` mục 10 ghi trước phần spec sẽ làm.
→ Kế hoạch: thêm cột + field DTO + pulldown UI + logic "áp dụng template người tham gia" (chi tiết hành vi cần chốt 6.6).

### 8.2 OpenAPI spec file — ⚠️ CHƯA RESOLVE, cần action
Sheet 05 KHÔNG đề cập file API contract. Nhưng 4 field mới + torokuHoho mới **bắt buộc** sửa model `MeisaiTemplate`.
Endpoint không nằm trong `api_interface_generate_tool/specification/openapi.yml` (grep Phase 2 = no match).
→ **Action**: trước khi code phải tìm đúng nguồn sinh `MeisaiTemplateApi`/model (file yml/json khác, hoặc model đã gen tay). Đã đưa vào câu hỏi 6.12(a).

### 8.3 Loại 3日当 (torokuHoho = 3) — ✅ KHÔNG phải blocker
Spec sheet 05 **không hề nhắc** 日当. → Giữ nguyên trạng thái "chết" như current, ghi note.
⚠️ **NHƯNG** phát sinh vấn đề khác cùng họ: 2 mode ngoại tệ mới cần **giá trị torokuHoho mới** (6.1) — đây mới là blocker, không phải 日当.

---

## 9. Recommended implementation strategy

- ☑ **Add field + change behaviour (some breaking) — cần FE update đồng bộ**

Lý do:
- Phần lớn là **pure extend additive** (4 cột nullable, +field DTO, +pulldown) → không breaking ở DB.
- NHƯNG có 2 điểm breaking ở tầng logic cần FE/BE đồng bộ:
  1. Giá trị `torokuHoho` mới (6.1) → cả FE filter/tab lẫn BE validation phải cùng định nghĩa.
  2. Ngữ nghĩa `kingaku` đổi theo mode ngoại tệ (6.5) → FE gửi đúng, BE hiểu đúng.
- **Không** cần versioned API / major refactor.

Trình tự đề xuất sau khi chốt TBD High:
1. Liquibase changeset ADD 4 cột (sau khi chốt 6.1 về type `toroku_hoho`).
2. Entity + DTO + SearchParamDto (thêm field, nới validation group cho mode ngoại tệ).
3. Service: branch theo mode mới + tính enKansanKingaku + lưu sankashaTemplateId.
4. OpenAPI model update (sau khi xác định file — 8.2).
5. Repository/Adapter: bổ sung cột vào JOIN nếu cần hiển thị (gaika type name...).

---

## 10. Open Issues from diff

Câu hỏi PHÁT SINH từ việc đối chiếu (đều đã đưa vào `clarifications.md`, đánh số khớp `spec_analysis.md` mục 6):

| # | Câu hỏi | Lý do (từ diff) | Cần ai trả lời | Severity |
|---|---|---|---|---|
| 6.1 | Giá trị `torokuHoho` cho 2 mode mới | Đụng validation + schema type `toroku_hoho` | PO + Tech Lead | 🔴 High |
| 6.2 | Setting bật/tắt ngoại tệ (key nào) | Quyết định điều kiện hiển thị + chặn CRUD | PO + BA | 🟡 Medium |
| 6.3 | Ai tính 円換算金額 + làm tròn | Logic service + an toàn dữ liệu | BA + Tech Lead | 🟡 Medium |
| 6.5 | Ngữ nghĩa `kingaku` ở mode ngoại tệ | Breaking semantic, FE/BE phải thống nhất | PO + FE | 🔴 High |
| 6.6 | Hành vi "áp dụng 参加者テンプレート" (reference vs snapshot) | Quyết định lưu gì + xử lý khi sankasha bị xóa | PO + BA | 🟡 Medium |
| 6.8 | 外貨レート証明書 có dùng 4 cột ngoại tệ không | Mockup mâu thuẫn tên loại | BA | 🟡 Medium |
| 6.12 | OpenAPI source + sheet 07/08 | Tránh sửa nhầm spec & sót yêu cầu | Tech Lead | 🟡 Medium |

> Các câu 6.4, 6.7, 6.9, 6.10, 6.11 mức Low/Medium — không chặn việc bắt đầu code phần additive.
