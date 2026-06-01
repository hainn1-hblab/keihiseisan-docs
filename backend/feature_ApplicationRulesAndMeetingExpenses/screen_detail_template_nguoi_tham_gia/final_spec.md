---
version: 1.2.0
status: ready-for-implementation
last_updated: 2026-06-05
based_on_spec_analysis_version: 1.0.0
based_on_clarifications_version: 1.1.0
unresolved_questions_count: 0
---

> 📘 **Đây là file spec chốt để implement.**
> - Đọc file này là đủ — không cần mở `spec_analysis.md` hay `clarifications.md`.
> - Các điểm còn ⚠️ **TBD**: đã có giá trị tạm để code, nhưng cần revisit khi PO trả lời.
> - Lịch sử thay đổi của file này: xem section cuối (`Version History`).

# Final Spec — Template người tham gia (参加者テンプレート)

## 1. Tổng quan

Tính năng "**Template người tham gia**" thuộc cụm "Application Rules and Meeting Expenses" — cho phép **mỗi nhân viên** đăng ký sẵn các danh sách người tham gia (kết hợp giữa người trong công ty và người ngoài) để khi lập đơn chi phí giao tế (会議費 / 接待費) có thể chọn template thay vì nhập tay từng người.

Có 2 màn hình:

| # | Tên màn hình | Mô tả |
|---|---|---|
| 1 | 参加者テンプレート一覧 | List các template của user — search, tạo mới, sửa, xoá, xoá hàng loạt |
| 2 | 参加者テンプレート詳細 | Form tạo mới / sửa 1 template (đặt theo tên đã được PO chốt — xem mục 4.6) |

**Bối cảnh sử dụng**:
- Template được tham chiếu bởi `tm_meisai_template.sankasha_template_id` (template chi tiết hoá đơn / hoá đơn ngoại tệ) và bởi luồng nhập chi tiết hoá đơn / 申請確認 thông qua `tr_meisai_sankasha`.
- Truy cập qua menu **マスタ設定**; breadcrumb mẫu: `ホーム画面 > 申請テンプレート一覧 > 参加者テンプレート詳細`.

---

## 2. Màn hình List — 参加者テンプレート一覧

### 2.1 Search fields (phía trên bảng)

| # | Label JP | Mô tả | Kiểu | Áp dụng vào cột DB |
|---|---|---|---|---|
| S1 | 参加者テンプレート名 | Tên template | Text — LIKE | `tm_sankasha_template.sankasha_template_name` |
| S2 | 相手先会社名・氏名 | Tên công ty hoặc tên người tham gia bên ngoài | Text — LIKE | `tm_sankasha_template_shosai.aitesaki_kaisha_name` OR `aitesaki_sankasha_name` (sankasha_kubun = 1) |
| S3 | 自社参加者名 | Tên nhân viên thuộc công ty mình | Text — LIKE | Join `tm_sankasha_template_shosai.jisha_sankasha_jugyoin_id` → `tm_jugyoin.jugyoin_name` (sankasha_kubun = 2) |

- Search button: `検索` — submit để filter list.
- LIKE search → chuẩn convention dự án: dùng `SqlUtil.getConditionContain(...)` (case-insensitive).
- **Scope bắt buộc**: list chỉ trả về template của chính user đang đăng nhập — mọi query thêm điều kiện `jugyoin_id = super.getLoginJugyoinId()` (xem 4.7).

### 2.2 Table columns

| # | Cột | Label JP | Nguồn dữ liệu |
|---|---|---|---|
| 1 | Checkbox | □ | Dùng để bulk delete |
| 2 | 操作 | — | 2 nút inline: **編集** (mở Detail edit), **削除** (xoá row, có confirm dialog) — xem `images/image_B5.png` |
| 3 | 参加者テンプレート名 | Tên template | `sankasha_template_name` |
| 4 | 参加人数 | Số người tham gia | `sanka_ninzu` |
| 5 | 相手先会社名・氏名 | DS multi-line: `相手先会社名 + " " + 相手先参加者名` cho mỗi shosai có `sankasha_kubun = 1` | Join shosai |
| 6 | 自社参加者名 | DS multi-line: `jugyoin_name` cho mỗi shosai có `sankasha_kubun = 2` | Join shosai → 従業員 |
| 7 | 自社参加者メモ | Memo template-level | `tm_sankasha_template.memo` |
| 8 | 表示順 | Số thứ tự hiển thị | `tm_sankasha_template.hyoji_jun` |

### 2.3 Action buttons

- `新規登録` (trên bảng): mở Detail ở chế độ tạo mới.
- `編集` (per row): mở Detail ở chế độ chỉnh sửa.
- `削除` (per row): hiện **confirm dialog** → soft delete (set `delete_flag = 1`).
- `選択した参加テンプレートを削除` (dưới bảng):
  - Khi **không tick** row nào → **disable nút**.
  - Khi có ít nhất 1 row tick → enable, click hiện **confirm dialog** → bulk soft delete.

### 2.4 Pagination & Sort

- **Page size**: FE truyền lên `size = 50` (theo convention hệ thống hiện tại).
- **Sort mặc định**: `hyoji_jun ASC` (FE truyền lên).
- **Cột sortable**: ⚠️ **TBD** — FE chưa confirm danh sách cột cho phép sort. Backend tạm support sort theo tất cả cột physical của bảng `tm_sankasha_template` (tên, ninzu, hyoji_jun) thông qua `SqlUtil.getPageableAndSort(...)`.

---

## 3. Màn hình Detail — 参加者テンプレート詳細

Layout & UI behavior: xem mockup `images/image_A10.png`.

### 3.1 Form fields

| # | Label JP | Tiếng Việt | Kiểu UI | Required | Default | Validation / Rule | DB column |
|---|---|---|---|---|---|---|---|
| F1 | 参加者テンプレート名 | Tên template | Text input | **✓ Required** | (trống) | Max 250 ký tự; **unique** trong scope `(hojin_code, jugyoin_id, sankasha_template_name, delete_flag)` — unique theo từng owner (xem 4.7) | `sankasha_template_name` (varchar 250) |
| F2 | 参加人数 | Số người tham gia | Number input | — | `0` | Cho phép `0`. Khi nhập **> 0** → bắt buộc nằm trong **[1, 999]**. Khi = 0 hoặc bỏ trống → coi như không nhập, **không** chạy validation max | `sanka_ninzu` (numeric 3) |
| F3 | 他社参加会社名 | Tên công ty bên ngoài | Text input | Tuỳ setting | (trống) | Max 250 ký tự. **Chỉ hiện** khi setting "hiển thị trường nhập người tham gia bên ngoài" của loại chi phí (`tm_keihi_kamoku`) đang BẬT — xem 4.2 | `aitesaki_kaisha_name` (varchar 250) |
| F3b | (không có label) | Tên người tham gia bên ngoài | Text input | Tuỳ setting | (trống) | Max 250 ký tự. **Placeholder**: "Tên người tham gia bên ngoài". Đi kèm cặp với F3, cùng visibility | `aitesaki_sankasha_name` (varchar 250) |
| F4 | `+` | Nút cộng cho cặp (F3, F3b) | Button | — | — | Thêm cặp input mới. **Max 99 cặp**. Đạt giới hạn → disable nút | — |
| F5 | 自社参加者 | Người tham gia thuộc công ty | Dropdown (chỉ tên nhân viên) | — | (trống) | Danh sách = tất cả `tm_jugyoin` của `hojin_code` hiện tại, **không filter theo phòng ban** của user lập đơn, **trừ** những nhân viên có `Roles.NO_RIGHT` (value = 1) — xem 4.3 | `jisha_sankasha_jugyoin_id` (FK → `tm_jugyoin`) |
| F6 | `+` | Nút cộng cho F5 | Button | — | — | Thêm 1 dropdown mới. **Max 99 dòng**. Đạt giới hạn → disable nút | — |
| F7 | 自社参加者メモ | Memo template | Text input | — | (trống) | Kiểu `text` (không giới hạn ký tự cứng ở DB). ⚠️ **TBD** việc cho xuống dòng (xem section 7) | `tm_sankasha_template.memo` (text) |
| F8 | 表示順 | Số thứ tự hiển thị | Number input | — | `100` | Numeric 4 chữ số. Áp default `100` theo convention dự án | `hyoji_jun` (numeric 4) |

### 3.2 Action buttons

- `キャンセル` — đóng màn hình/modal, không lưu.
- `保存` — submit form:
  1. Validate (gồm unique check F1, range check F2 khi > 0).
  2. Save header `tm_sankasha_template` + thay thế toàn bộ rows trong `tm_sankasha_template_shosai` (xem 4.4 cho strategy).
  3. Redirect về list, hiển thị message `I001` (add) hoặc `I002` (update).

### 3.3 Layout & UI behavior

Theo wireframe `images/image_A10.png`:

```
┌─────────────────────────────────────────────────────────────┐
│                   参加者テンプレート詳細                       │
│                                                             │
│  参加者テンプレート名                                          │
│  ┌─────────────────────────────────┐                        │
│  │                                 │                        │
│  └─────────────────────────────────┘                        │
│                                                             │
│  参加人数                                                    │
│  ┌──────────┐                                               │
│  │ 0        │                                               │
│  └──────────┘                                               │
│                                                             │
│  他社参加会社名             (placeholder: "Tên người ngoài")   │
│  ┌────────────────┐  ┌──────────────────┐  [ + ]            │
│  │                │  │                  │                   │
│  └────────────────┘  └──────────────────┘                   │
│                                                             │
│  自社参加者              自社参加者メモ                        │
│  ┌──────────────┐ [+]  ┌──────────────────────┐             │
│  │      ▼       │      │                      │             │
│  └──────────────┘      └──────────────────────┘             │
│                                                             │
│  表示順                                                      │
│  ┌──────┐                                                   │
│  │ 100  │                                                   │
│  └──────┘                                                   │
│                                                             │
│                     [ キャンセル ]  [   保存   ]                │
└─────────────────────────────────────────────────────────────┘
```

- 自社参加者 và 自社参加者メモ render **cùng hàng** (2-column).
- Cặp 他社参加会社名 / tên người ngoài render cùng hàng + nút `+` ngoài cùng phải.
- Khi setting loại chi phí tắt option hiển thị người ngoài → cả khối F3+F3b+F4 ẩn đi.

---

## 4. Business Rules

### 4.1 Validation rules

- **F1 `sankasha_template_name`** — required, không trống, max 250.
- **F1 Unique** — không cho phép insert/update tạo ra cặp `(hojin_code, jugyoin_id, sankasha_template_name, delete_flag)` đã tồn tại. Trên DB có **unique constraint** đảm bảo điều này; service phải check trước khi save để trả lỗi nghiệp vụ rõ ràng (error code `E040`).
- **F2 `sanka_ninzu`** — cho phép `0` (không nhập). Nếu > 0 → phải `<= 999`. Nếu < 0 → invalid.
- **F3/F3b** — max 250. Validate **chỉ khi** visibility được bật.
- **F4 / F6** — UI enforce max 99; backend cũng check để defend (trả 400 nếu vượt).
- **F5 `jisha_sankasha_jugyoin_id`** — phải là employee tồn tại trong `tm_jugyoin` cùng `hojin_code`, `delete_flag = 0`, và `role != NO_RIGHT (1)` — xem 4.3.
- **F8 `hyoji_jun`** — numeric 4 (≤ 9999), default 100.

### 4.2 Field visibility — dependency với Setting detail mục chi phí

- Khối F3 + F3b + F4 (他社参加 inputs) **chỉ hiển thị/cho nhập** khi trong setting của **loại chi phí** liên kết (`tm_keihi_kamoku`) có bật option "hiển thị trường nhập người tham gia bên ngoài".
- → FE: render conditional theo setting.
- → BE: validate phù hợp (không bắt buộc field rỗng nếu visibility off).
- ⚠️ Spec sheet này không định nghĩa exact column nào trong `tm_keihi_kamoku` điều khiển — tham chiếu sheet `Setting detail mục chi phí` (out of scope file này, không suy đoán).

### 4.3 Employee selection rules (F5 — 自社参加者)

- Dropdown 自社参加者 lấy danh sách `tm_jugyoin` thoả:
  - `hojin_code = current user's hojin_code`
  - `delete_flag = 0`
  - **Role của nhân viên ≠ `Roles.NO_RIGHT` (value = 1)** — tức loại bỏ nhân viên không có quyền.
  - **Không filter theo phòng ban** của user lập đơn.
- Reference enum: `jp.co.keihi.application.enums.Roles.NO_RIGHT` (`backend/src/main/java/jp/co/keihi/application/enums/Roles.java`).

### 4.4 Save strategy (header + detail)

- Khi save 1 template, dữ liệu được chia làm 2 phần:
  - Header: 1 row trong `tm_sankasha_template`.
  - Detail: N rows trong `tm_sankasha_template_shosai`, mỗi row đại diện 1 người ngoài (kubun=1) hoặc 1 nhân viên trong công ty (kubun=2).
- Khi tạo mới: `jugyoin_id` = `super.getLoginJugyoinId()`; khi update: chỉ cho phép nếu record hiện tại thuộc về user đang đăng nhập (xem 4.7).
- Strategy đề xuất khi update (theo pattern các master "header + detail" hiện có trong dự án):
  1. UPSERT header.
  2. Soft delete (hoặc hard delete) toàn bộ shosai cũ của `sankasha_template_id`.
  3. Insert lại toàn bộ shosai mới với `hyoji_jun` mới (default 1 cho từng row, hoặc theo thứ tự FE đẩy lên).
- ⚠️ Schema xlsx ghi `hyoji_jun` của shosai default `100 -> 1` (default mới = **1**). Áp default `1` cho shosai khi FE không truyền `hyoji_jun`.

### 4.5 Delete behavior (single + bulk)

| Hành động | UX | DB |
|---|---|---|
| `削除` (per row) | Hiện confirm dialog | Soft delete: `delete_flag = 1`, `update_version += 1` |
| `選択した参加テンプレートを削除` không tick | Nút **disabled** | — |
| `選択した参加テンプレートを削除` có tick | Hiện confirm dialog | Soft delete tất cả row được chọn |

### 4.6 Display & sort rules

- Tên màn hình chính thức (PO chốt): **参加者テンプレート詳細画面** (statement: list dùng `参加者テンプレート一覧`, detail dùng `参加者テンプレート詳細` — không dùng `参加人数テンプレート詳細`).
- Naming sang tiếng Anh / class / API: `**sankasha_template**` (tiền tố "sankasha", không phải "sankaninzu").
- Default sort list: `hyoji_jun ASC` (FE truyền lên).
- `hyoji_jun` của header default `100`. `hyoji_jun` của shosai default `1`.

### 4.7 Access control & ownership (chốt theo clarifications #6.15, #6.16, #6.17, #6.18)

**Nguyên tắc cốt lõi: template người tham gia là dữ liệu owner-scoped. Mọi user — kể cả admin role 5/6 — CHỈ thấy/dùng/sửa template do CHÍNH MÌNH tạo. KHÔNG có khái niệm "shared template" giữa các user trong cùng công ty.**

**Hai entry point tạo template** (cùng ghi vào 1 bảng `tm_sankasha_template`, không phân biệt loại — xem #6.16):

| Entry point | Màn hình | Role được phép | Ghi chú |
|---|---|---|---|
| (A) Từ luồng meisai | Màn tạo meisai → chọn "lưu template" (đã đính kèm thông tin người tham gia) | **Mọi role** | User thường tạo template gián tiếp; chỉ thấy lại template của mình khi chọn template lúc tạo meisai |
| (B) Từ menu Setting | Màn list/detail mô tả trong spec này (`マスタ設定`) | **Chỉ role 5, 6** (`DEPARTMENT_MANAGEMENT`, `SUPER_ADMIN`) | Role 5/6 tạo template người tham gia "master" để tham chiếu vào template meisai master |

- **Truy cập màn này (entry point B)**: chặn bằng `RoleUtil.check(super.getLoginUserDto(), Roles.DEPARTMENT_MANAGEMENT, Roles.SUPER_ADMIN)` ở đầu mỗi service method của các API thuộc màn Setting.
- **Owner khi insert**: `tm_sankasha_template.jugyoin_id` **luôn** set = `super.getLoginJugyoinId()`. **KHÔNG** nhận `jugyoin_id` từ request body (tránh giả mạo owner) — xem #6.17.
- **Scope view/sửa/xoá ở MỌI nơi**: mọi truy vấn list / read / update / delete / search **bắt buộc** kèm điều kiện cố định `jugyoin_id = super.getLoginJugyoinId()` (ngoài `hojin_code` + `delete_flag`). Backend không cho FE override filter này. Kể cả role 5/6 cũng không thấy/sửa template của nhân viên khác.
- **Unique constraint** (xem #6.18): scope `(hojin_code, jugyoin_id, sankasha_template_name, delete_flag)` — user A và user B trong cùng `hojin_code` được phép trùng tên template (vd cùng đặt `○○社用`); cùng 1 user thì không được trùng.

### 4.8 Xử lý 自社参加者 không còn hợp lệ (chốt theo clarification #6.9)

Khi một nhân viên đã được lưu trong template (`tm_sankasha_template_shosai`, `sankasha_kubun = 2`) sau đó bị **xoá** (`delete_flag = 1`) hoặc bị **đổi role thành `NO_RIGHT` (1)**:

- **Không tự động xoá** dòng đó khỏi template (giữ nguyên dữ liệu trong DB).
- Tại màn **Detail**, dòng đó được hiển thị như **dữ liệu không hợp lệ** (invalid) để user nhận biết.
- Khi user **cập nhật** template hoặc **áp dụng** template (chọn vào meisai), hệ thống **báo lỗi** và **bắt buộc** user chọn lại nhân viên khác hoặc xoá nhân viên không hợp lệ khỏi template trước khi tiếp tục (không cho lưu/áp dụng khi còn dòng invalid).
---

## 5. Database Schema

> **Nguồn**: `backend/documents/feature_ApplicationRulesAndMeetingExpenses/db_tables_application_rules_meeting_expenses.xlsx`, sheet `tm_sankasha_template` và `tm_sankasha_template_shosai`.

### 5.1 Bảng `tm_sankasha_template`

**Tên hiển thị**: Participant Template
**Schema dự kiến**: `keihi_com` (theo convention master `tm_*`)
**Unique constraint**: `(hojin_code, jugyoin_id, sankasha_template_name, delete_flag)` — đã CONFIRM theo clarification #6.18 (Liquibase tạo unique index đúng scope này).

> 📌 **Không thêm cột `template_kubun`** (chốt theo #6.16): template tạo từ cả 2 entry point — màn tạo meisai (mọi role) và menu Setting (role 5/6) — đều lưu chung vào bảng này, **không** phân biệt "master" vs "cá nhân" qua bất kỳ cột nào. Data hai loại giống hệt nhau, chỉ khác entry point UI.

| Column | Data Type | Length | Nullable | Default | Key | Description |
|---|---|---|---|---|---|---|
| `sankasha_template_id` | varchar | 29 | No | — | **PK** | Primary key — Participant template ID (参加者テンプレートID) |
| `hojin_code` | varchar | 5 | No | — | — | Company/tenant code (法人コード) |
| `jugyoin_id` | varchar | 29 | No | — | **FK** → `tm_jugyoin` | Owner employee ID (従業員ID) — nhân viên sở hữu template |
| `sankasha_template_name` | varchar | 250 | No | — | — | Template name displayed to user (参加者テンプレート名) |
| `sanka_ninzu` | numeric | 3 | Yes | `0.0` | — | Number of participants (参加人数). Allowed value: 1–999 khi > 0 |
| `hyoji_jun` | numeric | 4 | Yes | `100` | — | Display/sort order (表示順) |
| `delete_flag` | numeric | 1 | Yes | (không có trong file thiết kế) | — | Logical delete flag (削除フラグ) |
| `memo` | text | — | Yes | (không có trong file thiết kế) | — | 自社参加者メモ — **bổ sung spec mới** theo ghi chú trong file thiết kế |

**Cột audit bắt buộc thêm (file thiết kế ghi rõ "Thiếu các cột sau"):**

| Column | Data Type | Description |
|---|---|---|
| `add_date` | TIMESTAMP | データの作成日時 |
| `upd_date` | TIMESTAMP | データの更新日時 |
| `add_userid` | VARCHAR(29) | データの作成ユーザーID |
| `upd_userid` | VARCHAR(29) | データの更新ユーザーID |

**Note dev** (không từ file thiết kế — convention dự án): theo `.claude/rules/database.md` cần thêm `update_version NUMBER(4) defaultValueNumeric="1"` cho optimistic locking. Đề xuất bổ sung trong Liquibase changeset, đánh dấu ở section 7.

### 5.2 Bảng `tm_sankasha_template_shosai`

**Tên hiển thị**: Participant Template Detail
**Schema dự kiến**: `keihi_com`
**Index**: `(sankasha_template_id, sankasha_kubun, hyoji_jun)`

| Column | Data Type | Length | Nullable | Default | Key | Description |
|---|---|---|---|---|---|---|
| `sankasha_template_shosai_id` | varchar | 29 | No | — | **PK** | Primary key — Participant template detail ID (参加者テンプレート詳細ID) |
| `sankasha_template_id` | varchar | 29 | No | — | **FK** → `tm_sankasha_template` | Reference to parent template (参加者テンプレートID) |
| `sankasha_kubun` | numeric | 1 | No | — | — | Participant type (参加者区分): `1` = External, `2` = Internal |
| `aitesaki_kaisha_name` | varchar | 250 | Yes | — | — | External company name (相手先会社名) — dùng khi kubun=1 |
| `aitesaki_sankasha_name` | varchar | 250 | Yes | — | — | External participant name (相手先参加者名) — dùng khi kubun=1 |
| `jisha_sankasha_jugyoin_id` | varchar | 29 | Yes | — | **FK** → `tm_jugyoin` | Internal participant employee ID (自社参加者従業員ID) — dùng khi kubun=2 |
| `hyoji_jun` | numeric | 4 | Yes | `1` (note: ban đầu `100`, đổi thành `1`) | — | Sort order inside template (表示順) |

**Cột audit bắt buộc thêm (file thiết kế ghi rõ "Thiếu các cột sau"):**

| Column | Data Type | Description |
|---|---|---|
| `add_date` | TIMESTAMP | データの作成日時 |
| `upd_date` | TIMESTAMP | データの更新日時 |
| `add_userid` | VARCHAR(29) | データの作成ユーザーID |
| `upd_userid` | VARCHAR(29) | データの更新ユーザーID |

**Note dev**: cũng nên có `delete_flag` + `update_version` theo convention (hiện file thiết kế không liệt kê — đánh dấu vào section 7 để confirm).

### 5.3 Quan hệ giữa các bảng

> Trích từ sheet `Relations` trong file thiết kế.

| From | Field | To | Cardinality | Mục đích |
|---|---|---|---|---|
| `tm_sankasha_template` | `jugyoin_id` | `tm_jugyoin` | N : 1 | Mỗi template thuộc về 1 nhân viên (owner) |
| `tm_sankasha_template_shosai` | `sankasha_template_id` | `tm_sankasha_template` | N : 1 | Mỗi shosai row thuộc về 1 template (1 template có N shosai) |
| `tm_sankasha_template_shosai` | `jisha_sankasha_jugyoin_id` | `tm_jugyoin` | N : 1 (nullable) | Trỏ tới nhân viên trong công ty (khi `sankasha_kubun = 2`) |
| `tm_meisai_template` | `sankasha_template_id` | `tm_sankasha_template` | N : 1 | Template chi tiết hoá đơn / hoá đơn ngoại tệ tham chiếu participant template |

**On-delete behavior**: file thiết kế **không nêu rõ** ON DELETE cho FK. Áp dụng soft-delete pattern (`delete_flag`), không tạo FK constraint hard ở DB (theo convention dự án) — service phải tự đảm bảo integrity.

---

## 6. API Endpoints (đề xuất, theo convention Hexagonal)

> Tất cả endpoint dưới base path `/api/v1`. Tuân theo `.claude/rules/api-conventions.md`: Delegate → UseCase → Service → Crud Adapter → Repository.

| # | Method | Path | Mô tả | Request body | Response |
|---|---|---|---|---|---|
| 1 | `POST` | `/sankasha-template/search` | Search list có paging. **Backend luôn add filter cố định `jugyoin_id = super.getLoginJugyoinId()`, KHÔNG cho FE override** (xem #6.17) | `SankashaTemplateSearchParameter` (gồm `sankashaTemplateName`, `aitesakiName`, `jishaSankashaName`, `page`, `size`, `sortParameters`) — **không** có field `jugyoinId` | `ListSankashaTemplate` |
| 2 | `GET` | `/sankasha-template/{id}` | Lấy chi tiết 1 template + tất cả shosai. Read kèm điều kiện `jugyoin_id = current_user` (404 nếu không thuộc owner) | — | `SankashaTemplate` (gồm header + danh sách shosai) |
| 3 | `POST` | `/sankasha-template` | Tạo mới template. **`jugyoin_id` set tự động từ login context (`super.getLoginJugyoinId()`), KHÔNG nhận từ request body** (xem #6.17) | `SankashaTemplate` (header + shosai list) — bỏ qua mọi `jugyoinId` client gửi lên | `ModelApiResponse` (message `I001`) |
| 4 | `PUT` | `/sankasha-template/{id}` | Cập nhật template | `SankashaTemplate` (header + shosai list mới — thay thế toàn bộ shosai cũ) | `ModelApiResponse` (message `I002`) |
| 5 | `DELETE` | `/sankasha-template/{id}` | Xoá 1 template (soft) | Query/body chứa `updateVersion` | `ModelApiResponse` (message `I003`) |
| 6 | `DELETE` | `/sankasha-template` | Bulk xoá (soft) | List `{id, updateVersion}` | `ModelApiResponse` (message `I006`) |

**Class naming (theo convention)**:
- API: `SankashaTemplateApi`, `SankashaTemplateApiController`, `SankashaTemplateApiDelegateImpl`
- Use case: `SankashaTemplateCrudUseCase`
- Service: `SankashaTemplateService extends AbstractService`
- Output port: `SankashaTemplateCrud`
- Adapter: `SankashaTemplateAdapter`
- Domain DTO: `SankashaTemplateDto`, `SankashaTemplateShosaiDto`, `SankashaTemplateSearchParamDto`, `ListSankashaTemplateDto`
- Entity: `TmSankashaTemplate`, `TmSankashaTemplateShosai`
- Repository: `TmSankashaTemplateRepository`, `TmSankashaTemplateShosaiRepository`
- Bean config: `SankashaTemplateConfiguration`

**Phân quyền (xem 4.7)**: các endpoint của **màn Setting này (entry point B)** chặn bằng `RoleUtil.check(super.getLoginUserDto(), Roles.DEPARTMENT_MANAGEMENT, Roles.SUPER_ADMIN)` — chỉ role 5/6 vào được. Đồng thời **owner-scoped**: mọi method CRUD/search lọc cố định theo `jugyoin_id = super.getLoginJugyoinId()`, user chỉ thao tác template của chính mình (kể cả role 5/6 cũng không thấy template của user khác). (API tạo template từ luồng meisai — entry point A, mọi role — là API khác, ngoài phạm vi màn này.)

---

## 7. Open Issues / TBD

| # | Điểm TBD | Assumption tạm | Severity | Câu hỏi gốc | Cần PO trả lời trước |
|---|---|---|---|---|---|
| 2 | **(6.7)** `自社参加者メモ` (`tm_sankasha_template.memo`) có cho xuống dòng (multi-line) không? | Cho phép xuống dòng vì DB kiểu `text`. FE render `<textarea>` thay vì `<input>`. | **Low** | `clarifications.md` mục 6.7 (cột "Cho xuống dòng" của hàng `自社参加者メモ` còn `?`) | Trước UAT |
| 3 | **(6.14)** Danh sách cột list được phép sort | Backend support sort theo mọi cột physical của `tm_sankasha_template` (`sankasha_template_name`, `sanka_ninzu`, `hyoji_jun`). FE chốt sort UI sau. | **Low** | `clarifications.md` mục 6.14 (table bên trong còn `?`) | Trước UAT |
| 5 | (mới) `tm_sankasha_template` cần thêm `update_version` (optimistic lock) theo convention dự án — file thiết kế xlsx không có. | Bổ sung `update_version NUMBER(4) defaultValueNumeric="1"` trong Liquibase changeset. | **Low** | (phát sinh từ convention) | Trước khi merge changeset đầu tiên |
| 6 | (mới) `tm_sankasha_template_shosai` cần thêm `delete_flag` + `update_version` theo convention — file thiết kế không có. | Soft delete shosai có thể bỏ qua (vì save = replace all shosai). Nhưng vẫn nên có 2 cột này theo convention. Bổ sung trong Liquibase. | **Low** | (phát sinh từ convention) | Trước khi merge changeset đầu tiên |
| 7 | (mới) Cột nào trong `tm_keihi_kamoku` điều khiển visibility của khối 他社参加者 (xem 4.2)? | Sẽ xác định khi implement sheet `Setting detail mục chi phí`. Backend service nhận flag dạng boolean qua API hoặc đọc trực tiếp từ `tm_keihi_kamoku` — quyết định khi review chéo 2 sheet. | **Medium** | (cross-sheet dependency — không thuộc spec sheet này) | Trước khi implement validation conditional |

> **Đã resolved (gỡ khỏi bảng trên)**:
> - ~~#1 (6.9)~~ — Xử lý 自社参加者 không hợp lệ: đã chốt, chuyển thành business rule **mục 4.8**.
> - ~~#4~~ — Access control vs ownership: đã chốt qua clarifications #6.15–#6.18, chuyển thành **mục 4.7**.

**Giữ nguyên ID gốc** (#2, #3, #5, #6, #7) để không phá vỡ tham chiếu chéo từ các tài liệu khác.

**Severity legend**:
- **High** — Sai assumption phải sửa schema/API contract.
- **Medium** — Sai assumption sửa được trong vài giờ (đổi handler / logic).
- **Low** — Sai assumption chỉ chỉnh constant / config / Liquibase patch.

---

## 8. References

- Spec analysis: [`spec_analysis.md`](./spec_analysis.md) (v1.0.0)
- Clarifications: [`clarifications.md`](./clarifications.md) (v1.1.0 — đã trả lời toàn bộ, gồm cả 6.9 và 6.15–6.18; 0 câu pending)
- DB design: `backend/documents/feature_ApplicationRulesAndMeetingExpenses/db_tables_application_rules_meeting_expenses.xlsx` (sheets: `tm_sankasha_template`, `tm_sankasha_template_shosai`, `Relations`, `Overview`)
- Roles enum: `backend/src/main/java/jp/co/keihi/application/enums/Roles.java`
- Convention rules:
  - API: `.claude/rules/api-conventions.md`
  - Database / Liquibase: `.claude/rules/database.md`
- Ảnh mockup (extract từ sheet spec gốc):
  - `images/image_B5.png` — Action buttons row (`編集` / `削除`)
  - `images/image_A10.png` — Wireframe màn hình Detail
  - `images/image_A45.png` — Screenshot mockup màn hình List

---

## Version History

### [1.2.0] - 2026-06-02

- **Formalize & resolve TBD #4 (access control vs ownership)** qua clarifications #6.15, #6.16, #6.17, #6.18 (thay cho note inline của Tech Lead ở v1.1.0).
- **Section 4.7** refine: làm rõ **2 entry point** tạo template — (A) màn meisai (mọi role), (B) menu Setting màn này (chỉ role 5/6); filter cố định `jugyoin_id = current_user`; insert set `jugyoin_id` từ login context, không nhận từ request body; không share template giữa user.
- **Section 5.1**: CONFIRM unique scope `(hojin_code, jugyoin_id, sankasha_template_name, delete_flag)`; CONFIRM **không** thêm cột `template_kubun` (2 entry point lưu chung 1 bảng).
- **Section 6**: API search add filter cố định `jugyoin_id = current_user` (FE không override); API create set `jugyoin_id` tự động; khôi phục `RoleUtil.check` role 5/6 cho các endpoint màn Setting.
- **Section 3.1**: sửa unique scope của F1 cho đầy đủ (thêm `sankasha_template_name`).
- **Section 4.8 (mới)**: chốt theo #6.9 — 自社参加者 không hợp lệ (bị xoá/đổi role NO_RIGHT) giữ nguyên trong DB, hiển thị invalid ở Detail, báo lỗi & bắt chọn lại khi update/áp dụng. Resolve TBD #1.
- **Section 7**: gỡ TBD #1 (→ 4.8) và #4 (→ 4.7). Còn **5 điểm TBD** — 0 High, 1 Medium (#7), 4 Low (#2, #3, #5, #6).
- Note: version nhảy `1.1.0 → 1.2.0` vì entry `[1.1.0]` đã tồn tại (interim resolution ngày 2026-06-01).

### [1.1.0] - 2026-06-01

- **Resolved TBD #4 (High)**: Tech Lead BE chốt template là **owner-scoped** — `jugyoin_id = super.getLoginJugyoinId()`, mọi user (kể cả role 5/6) chỉ thấy/sửa template của chính mình; không phân quyền cứng theo role.
- Viết lại section **4.7** (Access control & ownership) theo confirmation.
- Cập nhật **section 2.1** (list filter `jugyoin_id`), **4.4** (set owner khi tạo/sửa), **section 6** (bỏ `RoleUtil.check` cứng, chuyển sang owner-scoped).
- Còn **6 điểm TBD** (giảm từ 7) — **0 High**, 2 Medium (#1, #7), 4 Low (#2, #3, #5, #6).
- Status nâng lên `ready-for-implementation` (không còn High blocker).

### [1.0.0] - 2026-05-28

- Initial final spec.
- Dựa trên `spec_analysis.md` v1.0.0 và `clarifications.md` v1.0.0 (đã trả lời 13/14 câu — mục 6.9 còn 🔴 PENDING).
- DB schema lấy từ `db_tables_application_rules_meeting_expenses.xlsx` (sheets `tm_sankasha_template`, `tm_sankasha_template_shosai`, `Relations`).
- Còn 7 điểm TBD — xem section 7. Trong đó **1 High** (#4 — bất nhất schema vs access control), **2 Medium** (#1, #7), **4 Low** (#2, #3, #5, #6).
- Status `partial-ready` vì còn 1 High-severity TBD cần PO confirm trước khi code.

