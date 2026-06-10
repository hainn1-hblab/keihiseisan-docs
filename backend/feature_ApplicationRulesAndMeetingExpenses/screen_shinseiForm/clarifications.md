---
version: 1.0.0
status: pending
last_updated: 2026-06-09
related_spec: ./spec_analysis.md
related_spec_version: 1.0.0
changelog_file: ./CHANGELOG.md
mode: EXTEND
based_on_current_analysis_version: 1.0.0
---

# Clarifications — 申請フォーム詳細設定 (ShinseiForm Application Rules)

File này chứa câu trả lời cho các câu hỏi trong [`spec_analysis.md` mục 6](./spec_analysis.md).
Khi tất cả câu trả lời → tạo `final_spec.md` (dùng skill `final-spec-merger`).

## Tổng quan tiến độ

| Status | Số lượng |
|---|---|
| 🔴 Pending | 11 |
| 🟡 In-discussion | 0 |
| 🟢 Answered | 0 |
| ⚫ Deferred | 0 |
| **Tổng** | **11** |

**Severity**: 🔴 High = 3 · 🟡 Medium = 6 · 🟢 Low = 2

> EXTEND mode: chỉ hỏi về phần THAY ĐỔI. 2 điểm Phase 1 (PUT→add, comment delete) đã được PO xác nhận → KHÔNG hỏi lại.

---

## 6.1 Cột version FK của 4 bảng con — `shinsei_form_version` hay `update_version`? — [🔴 High]

**Status**:🟢 Answered

**Câu hỏi**:
DB sheet ghi cột FK + unique key của 4 bảng con là `update_version` (numeric 4), nhưng BA đã note ngay trong sheet "*shinsei_form_version chứ kp update_version*". `tm_shinsei_form` dùng PK composite `(shinsei_form_id, shinsei_form_version BIGINT)`. Để versioning hoạt động đúng (giống `tm_customize_komoku`), 4 bảng con phải tham chiếu `shinsei_form_version`. Xác nhận dùng `shinsei_form_version` (BIGINT) cho cả 4 bảng?

**Trả lời**:
Cần đồng bộ với `tm_shinsei_form` để versioning hoạt động đúng. Dùng `shinsei_form_version` cho 4 bảng con giống `tm_customize_komoku` để đảm bảo consistency. 

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Schema 4 bảng con (cột FK + unique key) + entity + JPA mapping. BLOCK code DB.

---

## 6.2 3 bảng con thiếu cột chuẩn (audit + hyoji_jun) — [🔴 High]

**Status**: 🟢 Answered

**Câu hỏi**:
`tm_shinsei_form_busho / _yakushoku / _jugyoin` trong sheet thiếu `hyoji_jun` và 4 audit field (`add_date/upd_date/add_userid/upd_userid`) — BA đã note "Thiếu các cột sau". `tm_shinsei_form_keihi_kamoku` có đủ. Bổ sung `hyoji_jun` (numeric 4, default 100) + 4 audit field cho cả 3 bảng theo convention dự án (`database.md`)?

**Trả lời**:
Cần bổ sung hyoji_jun để đảm bảo thứ tự hiển thị có thể điều chỉnh được. 4 audit field gần như bắt buộc theo convention để tracking lịch sử thay đổi. Cần bổ sung cho cả 3 bảng con để đảm bảo consistency.

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Schema 3 bảng con. BLOCK code DB. (Audit field gần như bắt buộc theo convention.)

---

## 6.3 Quan hệ `keihiMeisaiTempu` (hiện có) ↔ nhóm 1 添付可能な明細の種類 (mới) — [🔴 High]

**Status**: 🟢 Answered

**Câu hỏi**:
Hiện `keihiMeisaiTempu` chỉ 0/1 (có/không đính kèm). Nhóm 1 thêm 5 flag chi tiết theo loại meisai. Khi `keihiMeisaiTempu = 0` (không đính kèm) thì 5 flag mới mang giá trị gì (vẫn lưu default? ẩn UI?)? Nhóm 1 là **sub-detail** phụ thuộc `keihiMeisaiTempu=1`, hay thay thế ý nghĩa của `keihiMeisaiTempu`?

**Trả lời**:
Hiện tại chưa rõ spec, logic của keihiMeisaiTempu trong hệ thống như thế nào. Tạm thời coi 2 phần này là độc lập (không phụ thuộc nhau) để tránh ảnh hưởng logic hiện tại. 

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Logic hiển thị + validate nhóm 1; quan hệ field cũ-mới. Ảnh hưởng cả màn tạo申請 (loại meisai đính kèm).

---

## 6.4 Consistency check 経費科目 ↔ 添付可能な明細の種類 (A197–A202) — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Khi save form, nếu một 経費科目 đã chọn (nhóm 2) có "loại meisai được chọn" (cấu hình ở màn detail KeihiKamoku) KHÔNG khớp 添付可能な明細の種類 (nhóm 1) → xử lý ra sao? Chặn save (error) hay chỉ cảnh báo? Message key? Phạm vi check (chỉ khi `keihi_kamoku_seigen_flag=1`?). Có check ngược ở màn 経費科目 khi sửa科目 đang bị form giới hạn không?

**Trả lời**: phần đấy phía FE sẽ tự lọc xem việc tích chọn các meisai ở mục 1 có trùng với việc setting meisai ở trong detail shinseiform không thì sẽ hiện thị trong list cho user chọn. 
Còn khi save form mà có một 経費科目 đã chọn mà loại meisai của nó không khớp với loại meisai được chọn ở mục 1 thì sẽ chặn save, hiện message key "error.shinseiForm.keihiKamoku.meisaiTypeMismatch". Phạm vi check sẽ là khi `keihi_kamoku_seigen_flag=1` vì chỉ khi đó mới có giới hạn về 経費科目.

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Validate khi save form + cross-screen với KeihiKamoku. BLOCK UAT.

---

## 6.5 `shinsei_gokei_kingaku_jogen` — kiểu, đơn vị, kubun khi rỗng — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
"length 11 ký tự", numeric(11). Là số nguyên (yên, không thập phân) tối đa 11 chữ số? Có hỗ trợ ngoại tệ/thập phân không? Khi `上限` rỗng (null) thì `shinsei_gokei_jogen_check_kubun` lưu giá trị gì (vẫn default 1 dù không dùng)?

**Trả lời**:
Để numeric(11) FE validate đầu vào là số nguyên dương tối đa 11 chữ số (tương đương max 99,999,999,999 yên). Không hỗ trợ thập phân hay ngoại tệ khác. default không nhập gì thì lưu null, sẽ không check giới hạn tổng tiền.

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Type cột DB + validate input + logic check ở màn tạo申請.

---

## 6.6 Nguồn setting điều kiện hiển thị nhóm 1 & nhóm 4 — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
- 外貨機能 / 申請者レート変更可能 (`shinseishaRateNyuryoku`, note N131): nằm ở bảng/flag nào trong setting Kaisha để BE biết bật 1.4/1.5?
- 「ワークフロー変更をON,OFFできる」(制限設定): nằm ở đâu (table/flag) để biết hiển thị nhóm 4?

**Trả lời**:
Nếu gaikaRiyoUmu được bật & shinseishaRateNyuryoku được bật → hiển thị cho chọn 1.4/1.5.
Nếu gaikaRiyoUmu được bật nhưng shinseishaRateNyuryoku tắt → /1.5, mặc định lưu 0.
Nếu gaikaRiyoUmu tắt → ẩn cả 2 cột 1.4/1.5, mặc định lưu 0.

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Logic hiển thị có điều kiện (FE) + có thể BE trả flag điều kiện kèm response.

---

## 6.7 Modal search 経費科目/部署/役職/従業員 — tái dùng API có sẵn? — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Spec yêu cầu modal "giống modal chọn người approve của 承認ルート詳細画面". Có sẵn endpoint search cho từng master (keihi_kamoku/busho/yakushoku/jugyoin) để tái dùng, hay cần tạo endpoint mới cho mỗi modal? Tham số search cụ thể (経費科目: name/code/借方勘定/借方補助/貸方勘定/貸方補助; 役職: code/name).

**Trả lời**: Dùng API search hiện có cho từng master để tái dùng. Hiện tại đã có rồi, FE đã call done rồi. sau mình chỉ cần sửa lại api search/view list, FE sẽ truyền lên thêm tham số jugyoinId để mình sẽ lọc danh sách các shinseiform mà jugyoin đó có quyền truy cập (theo logic busho/yakushoku/jugyoin).

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Số lượng endpoint mới cần tạo. Effort backend.

---

## 6.8 Validate "list rỗng" khi seigen_flag = ON — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Khi checkbox giới hạn (nhóm 2/5/6/7) = ON nhưng danh sách rỗng → có bắt buộc chọn ≥1 item không? Nếu bắt buộc, dùng message key nào? Nếu cho phép rỗng thì nghĩa nghiệp vụ là gì (không ai dùng được form?)?

**Trả lời**: chỉ require với nhóm 2 (経費科目), nhóm 5/6/7 có thể để rỗng (để không giới hạn theo busho/yakushoku/jugyoin nào cả, tức form available cho mọi user dù bật seigen_flag). Nếu nhóm 2 seigen_flag=1 nhưng không chọn item nào → chặn save, message key "error.shinseiForm.keihiKamoku.required". Nếu nhóm 5/6/7 seigen_flag=1 nhưng không chọn item nào → vẫn cho save, interpret là "không giới hạn theo busho/yakushoku/jugyoin nào cả".

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Validate khi save form.

---

## 6.9 Logic lọc form ở màn tạo申請 — kết hợp điều kiện 5/6/7 (OR/AND) — [🟡 Medium]

**Status**: 🟢 Answered

**Câu hỏi**:
Khi nhiều điều kiện (部署/役職/従業員) cùng bật, user được dùng form nếu thỏa **bất kỳ** (OR) hay **tất cả** (AND)? Khi tất cả seigen_flag=0 → form available cho mọi user (như hiện tại)? `下位階層を含む` mở rộng busho động lúc tạo申請 hay expand & lưu sẵn?

**Trả lời**:
Khi điều kiện nào cũng bật → user được dùng form nếu thỏa **bất kỳ** điều kiện nào (OR). Khi tất cả seigen_flag=0 → form available cho mọi user. `下位階層を含む` sẽ mở rộng busho động lúc tạo申請 dựa trên cấu trúc busho hiện tại, không cần lưu sẵn.
`下位階層を含む` tức là khi tạo申請, hệ thống sẽ lấy busho được chọn, sau đó truy vấn cấu trúc tổ chức để tìm tất cả busho con của busho đó và mở rộng điều kiện lọc form dựa trên danh sách busho con này.

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Cross-screen — logic filter form ở màn tạo申請. BLOCK UAT cross-screen.

---

## 6.10 Default checkbox nhóm 1 khi tạo mới vs khi 外貨機能 tắt — [🟢 Low]

**Status**: 🟢 Answered

**Câu hỏi**:
Spec ghi "tất cả checkbox đều check" khi tạo mới, nhưng default DB của 2 mục外貨 (1.4, 1.5) = 0. Khi 外貨機能 tắt (chỉ hiện 3 checkbox 領収書/経路/日当) thì 2 cột外貨 lưu 0 đúng chứ? "tất cả check" chỉ áp cho các checkbox đang hiển thị?

**Trả lời**:
1.4,1.5 phụ thuộc vào việc setting gaikaRiyoUmu bật hay tắt. Khi gaikaRiyoUmu tắt → ẩn cả 2 cột 1.4/1.5, mặc định lưu 0. "tất cả check" chỉ áp cho các checkbox đang hiển thị, nên khi 外貨機能 tắt thì chỉ có 3 checkbox 領収書/経路/日当 được check, còn 2 checkbox 外貨 (1.4, 1.5) sẽ không hiển thị và lưu giá trị 0.

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Default value khi create (low — chỉnh được bằng logic).

---

## 6.11 Anomaly đánh số "6.0"/"7.0" trong sheet — [🟢 Low]

**Status**: 🟢 Answered

**Câu hỏi**:
Cột A của sheet đánh "6.0" (A178), "7.0" (A188) trong khi mục 1–5 đánh số trơn ("2.", "3."...). Xác nhận chỉ là format, không có ý nghĩa nghiệp vụ (vd: sub-version của mục)?

**Trả lời**: chỉ là format để phân biệt nhóm câu hỏi, không có ý nghĩa nghiệp vụ hay sub-version nào cả.

**Người trả lời**:
**Ngày trả lời**:
**Nguồn**:
**Impact**: Không (chỉ wording).

---

## Quy tắc cập nhật

1. KHÔNG xóa câu hỏi đã trả lời.
2. Update status: 🔴 → 🟡 → 🟢 hoặc 🔴 → ⚫ (deferred).
3. Nếu câu trả lời ĐỔI sau khi đã 🟢 → ghi rõ "UPDATED <date>" + lý do, KHÔNG xóa câu cũ.
4. Khi câu trả lời đổi → cascade update final_spec.md.
5. Bump version: Patch (clarification nhỏ) / Minor (3+ câu mới) / Major (scope đổi).

## Sign-off

Khi tất cả câu hỏi đã chuyển sang status 🟢 hoặc ⚫:

- [ ] PO sign-off: __________________ Ngày: __________
- [ ] BA sign-off: __________________ Ngày: __________
- [ ] Tech Lead sign-off: __________________ Ngày: __________
- [ ] Bump `spec_analysis.md` version
- [ ] Tạo / Update `final_spec.md`
- [ ] Ghi entry vào `CHANGELOG.md`
</content>
