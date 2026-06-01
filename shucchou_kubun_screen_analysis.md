# 出張区分マスタ — Phân tích nghiệp vụ màn hình Loại công tác

> **Nguồn**: Google Sheets `1TeuB5beyWCKeOWnZ4oXRB5P3OFTkrBQFT3JOAmCtZJk` — Sheet: `Screen loại công tác`
> **Ngày đọc**: 2026-05-19
> **Người phân tích**: ducna1

---

## 1. Tổng quan màn hình

| Thuộc tính | Giá trị |
|---|---|
| Tên màn hình | 出張区分マスタ (Master Loại công tác) |
| Mục đích | Quản lý danh mục các loại công tác (出張区分) phục vụ tính toán chi phí công tác |
| Điều hướng | マスタ設定 → 日当設定 → 出張区分マスタ |
| Màn hình hiển thị | 出張区分一覧 (Danh sách loại công tác) |

### Luồng điều hướng
```
Menu: マスタ設定
  └── 日当設定
        └── 出張区分マスタ
              └── 出張区分一覧 (màn hình chính - danh sách)
                    ├── [新規登録] → Modal thêm mới
                    └── [編集]    → Modal chỉnh sửa
```

---

## 2. Màn hình Danh sách (出張区分一覧)

### 2.1 Khu vực tìm kiếm (検索条件)

| Field DB | Tiếng Nhật | Tiếng Việt | Ghi chú |
|---|---|---|---|
| `shucchou_kubun_code` | 出張区分コード | Code loại công tác | Tìm kiếm tương đối (LIKE) |
| `shucchou_kubun_name` | 出張区分名 | Tên loại công tác | Tìm kiếm tương đối (LIKE) |
| `koteichi` | 固定値 | Giá trị cố định | Nhập tay (không dùng pulldown) |
| `hyoji_jun` | 表示順 | Thứ tự hiển thị | Tìm kiếm theo số |

> **Lưu ý nghiệp vụ**: Trường `koteichi` (固定値) được ghi chú là "bỏ pulldown, nhập tay" — tức là ban đầu thiết kế là dropdown nhưng đã thay đổi sang free-text input.

### 2.2 Các cột hiển thị danh sách (dự kiến)

Dựa vào search param và modal fields, danh sách hiển thị các cột:

| Cột | Field DB | Mô tả |
|---|---|---|
| Code loại công tác | `shucchou_kubun_code` | Mã định danh loại công tác |
| Tên loại công tác | `shucchou_kubun_name` | Tên hiển thị |
| Giá trị cố định | `koteichi` | Giá trị dùng trong tính toán |
| Thứ tự hiển thị | `hyoji_jun` | Thứ tự sắp xếp |
| [編集] | — | Button mở modal chỉnh sửa |
| Checkbox | — | Chọn để xóa hàng loạt |

### 2.3 Buttons danh sách

| Button | Nhãn | Chức năng |
|---|---|---|
| 新規登録 | Thêm mới | Mở modal thêm loại công tác mới |
| 削除 | Xóa | Xóa các loại công tác đã chọn (bulk delete) |
| CSV取込 | Import CSV | Import dữ liệu từ file CSV |

> **Nghiệp vụ xóa**: Nút xóa tác động lên **nhiều record** được chọn (bulk delete). Khi bấm xóa sẽ hiện confirm dialog.

---

## 3. Modal Thêm mới / Chỉnh sửa

### 3.1 Các field trong modal

| Field | Tiếng Nhật | Bắt buộc | Độ dài | Hành vi Thêm mới | Hành vi Chỉnh sửa |
|---|---|---|---|---|---|
| `shucchou_kubun_name` | 出張区分名 | **Có** | — | Nhập tay giá trị mới | Prefill từ giá trị hàng được chọn |
| `shucchou_kubun_code` | 出張区分コード | Có | Tối đa 5 ký tự | Nhập tay giá trị mới | Prefill từ giá trị hàng được chọn |
| `koteichi` | 固定値 | Có | — | Giá trị mặc định = **1** | Prefill từ giá trị hàng được chọn |

### 3.2 Buttons modal

| Button | Nhãn | Hành vi |
|---|---|---|
| キャンセル | Cancel | Đóng modal, không lưu |
| 保存 | Save | Lưu vào DB → đóng modal → cập nhật lại danh sách |

---

## 4. Chức năng CSV Import (出張区分CSV取込)

- **CSV Title hiển thị**: `出張区分CSV取込`
- Chức năng cho phép import hàng loạt loại công tác từ file CSV.
- Cần xác nhận thêm về format cột CSV (chưa có thông tin chi tiết trong sheet).

---

## 5. Thông báo hệ thống

| Tình huống | Nội dung thông báo (JP) | Dịch |
|---|---|---|
| Confirm xóa | 出張区分を削除します。よろしいですか？ | Bạn có chắc chắn muốn xóa loại công tác này không? |

---

## 6. Phân tích nghiệp vụ chuyên sâu

### 6.1 Mục đích của `koteichi` (固定値 — Giá trị cố định)

- Đây là **hệ số nhân** hoặc **giá trị định mức** gắn với từng loại công tác.
- Được dùng trong công thức **tính toán chi phí công tác** (日当計算 — tính nhật lương công tác).
- Giá trị mặc định khởi tạo là **1**, tức là không có hệ số điều chỉnh.
- Ví dụ nghiệp vụ: Loại "Công tác nước ngoài" có thể có `koteichi = 2` (gấp đôi) so với "Công tác trong nước".

### 6.2 Soft Delete pattern

- Màn hình xóa là **logical delete** (soft delete): set `delete_flag = 1`, không xóa vật lý.
- Danh sách chỉ hiển thị records có `delete_flag = 0`.
- Hỗ trợ **bulk delete** (xóa nhiều record cùng lúc qua checkbox).

### 6.3 Multi-tenant

- Dữ liệu phân tách theo `hojin_code` (法人コード — mã công ty).
- Mỗi công ty quản lý danh mục loại công tác riêng.

### 6.4 Thứ tự hiển thị (`hyoji_jun`)

- Danh sách được sắp xếp theo `hyoji_jun` ASC.
- Giá trị mặc định = 100, admin có thể tùy chỉnh thứ tự hiển thị.

### 6.5 Unique constraint

- `shucchou_kubun_code` phải **unique** trong phạm vi `hojin_code`.
- Khi thêm mới hoặc chỉnh sửa, cần validate trùng code.

### 6.6 Optimistic Locking

- `update_version` đảm bảo không có conflict khi nhiều user cùng chỉnh sửa.

---

## 7. Mapping API dự kiến

| Action | HTTP Method | Endpoint | Mô tả |
|---|---|---|---|
| Tìm kiếm | `GET` | `/api/v1/shucchou-kubun` | Lấy danh sách có phân trang + filter |
| Thêm mới | `POST` | `/api/v1/shucchou-kubun` | Tạo loại công tác mới |
| Chỉnh sửa | `PUT` | `/api/v1/shucchou-kubun/{id}` | Cập nhật loại công tác |
| Xóa (bulk) | `DELETE` | `/api/v1/shucchou-kubun` | Xóa nhiều loại công tác |
| Import CSV | `POST` | `/api/v1/shucchou-kubun/csv` | Import từ CSV |

---

## 8. Database Table — `tm_shucchou_kubun`

```
Schema: keihi_com
Table:  tm_shucchou_kubun
```

| Column | Type | Mô tả |
|---|---|---|
| `add_date` | TIMESTAMP | Ngày tạo (audit) |
| `upd_date` | TIMESTAMP | Ngày cập nhật (audit) |
| `add_userid` | VARCHAR(29) | User tạo (audit) |
| `upd_userid` | VARCHAR(29) | User cập nhật (audit) |
| `shucchou_kubun_id` | VARCHAR(29) | PK — ID loại công tác |
| `hojin_code` | VARCHAR(5) | Mã công ty (multi-tenant) |
| `shucchou_kubun_code` | VARCHAR(10) | Mã loại công tác (unique per hojin) — tối đa 5 ký tự theo UI |
| `shucchou_kubun_name` | VARCHAR(250) | Tên loại công tác |
| `koteichi` | NUMBER | Giá trị cố định dùng tính toán, default = 1 |
| `hyoji_jun` | NUMBER(4) | Thứ tự hiển thị, default = 100 |
| `delete_flag` | NUMBER(1) | 0: đang dùng, 1: đã xóa |
| `update_version` | NUMBER(4) | Optimistic locking |

---

## 9. Câu hỏi / Điểm cần làm rõ

- [ ] Format cột CSV cho chức năng 出張区分CSV取込 là gì?
- [ ] `shucchou_kubun_code` max 5 ký tự (UI) nhưng DB column là VARCHAR(10) — cần xác nhận constraint ở tầng nào?
- [ ] `koteichi` là kiểu NUMBER hay VARCHAR? Có cho phép số thập phân không?
- [ ] Khi bulk delete, nếu loại công tác đang được sử dụng trong shinsei thì có block xóa không?
- [ ] Phân quyền: Roles nào được phép thêm/sửa/xóa loại công tác?
