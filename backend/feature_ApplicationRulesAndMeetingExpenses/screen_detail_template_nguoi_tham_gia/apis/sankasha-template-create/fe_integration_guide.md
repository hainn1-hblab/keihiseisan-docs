---
version: 1.0.0
status: draft
audience: frontend
api_name: SankashaTemplateCreate
http_method: POST
endpoint: /api/v1/sankasha-template
last_updated: 2026-06-02
based_on_detail_design_version: 1.0.1
---

# FE Integration Guide — Create Sankasha Template (参加者テンプレート登録)

> 📘 Tài liệu này dành cho **Frontend**. Đọc xong là ghép được request/response của API tạo template người tham gia mà không cần đọc code backend.
> Nguồn gốc: [`detail_design.md`](./detail_design.md), [`request_examples.json`](./request_examples.json), [`response_examples.json`](./response_examples.json).

---

## 1. Endpoint

| Item | Value |
|---|---|
| **Method** | `POST` |
| **URL** | `/api/v1/sankasha-template` |
| **Content-Type** | `application/json` |
| **Authorization** | `Bearer <JWT access token>` (bắt buộc) |
| **Role được phép gọi** | `5` (DEPARTMENT_MANAGEMENT) hoặc `6` (SUPER_ADMIN). Role khác → `403`. |

> ⚠️ Màn hình tạo template này (menu マスタ設定) chỉ mở cho role 5/6. FE nên ẩn nút lưu / màn hình với role thấp hơn để tránh user gọi rồi nhận 403.

---

## 2. Request Body

### 2.1 Cấu trúc tổng thể

Request gồm **1 header** + **1 mảng `shosaiList`** (danh sách người tham gia). Mỗi phần tử trong `shosaiList` là 1 trong 2 loại:
- **他社参加者 (external)** → `sankashaKubun = 1`
- **自社参加者 (internal)** → `sankashaKubun = 2`

```jsonc
{
  "sankashaTemplateName": "○○社用",   // bắt buộc
  "sankaNinzu": 4,                      // optional
  "memo": "他2名",                      // optional
  "hyojiJun": 100,                      // optional
  "shosaiList": [ /* >= 1 phần tử */ ]  // bắt buộc
}
```

### 2.2 Header fields

| Field | Kiểu | Bắt buộc | Ràng buộc | Ý nghĩa |
|---|---|---|---|---|
| `sankashaTemplateName` | string | ✅ | không rỗng, **tối đa 250 ký tự** | Tên template (参加者テンプレート名) |
| `sankaNinzu` | integer | ❌ | `0` (= chưa nhập) **hoặc** `1`–`999`. **KHÔNG** chấp nhận số âm / > 999 | Số người tham gia (参加人数) |
| `memo` | string | ❌ | không giới hạn độ dài | Ghi chú (自社参加者メモ) |
| `hyojiJun` | integer | ❌ | `1`–`9999`. Bỏ trống → server set `100` | Thứ tự hiển thị (表示順) |
| `shosaiList` | array | ✅ | **≥ 1 phần tử**. Xem ràng buộc số lượng ở §2.4 | Danh sách người tham gia |

> ❗ **KHÔNG gửi** field `jugyoinId` (chủ sở hữu). Backend tự gán theo user đang đăng nhập từ JWT. Nếu FE có gửi, backend **bỏ qua**.
> Tương tự KHÔNG cần gửi: `sankashaTemplateId`, `hojinCode`, `deleteFlag`, `updateVersion`, các field `add*/upd*`.

### 2.3 `shosaiList[]` fields

| Field | Kiểu | Bắt buộc | Ràng buộc | Ý nghĩa |
|---|---|---|---|---|
| `sankashaKubun` | integer | ✅ | chỉ `1` hoặc `2` | `1`=external (他社), `2`=internal (自社) |
| `aitesakiKaishaName` | string | ⚠️ điều kiện | ≤ 250 ký tự | Tên công ty đối tác. **Bắt buộc khi `kubun=1`**, phải bỏ trống khi `kubun=2` |
| `aitesakiSankashaName` | string | ⚠️ điều kiện | ≤ 250 ký tự | Tên người tham gia đối tác. **Bắt buộc khi `kubun=1`**, phải bỏ trống khi `kubun=2` |
| `jishaSankashaJugyoinId` | string | ⚠️ điều kiện | đúng 29 ký tự | ID nhân viên nội bộ. **Bắt buộc khi `kubun=2`**, phải bỏ trống khi `kubun=1` |
| `hyojiJun` | integer | ❌ | `1`–`9999`. Bỏ trống → server set `1` | Thứ tự trong template |

> `jishaSankashaName` (tên nhân viên) là field **chỉ để hiển thị** — FE không cần gửi khi tạo; backend sẽ trả về ở các API đọc.

### 2.4 Quy tắc số lượng `shosaiList` (RẤT QUAN TRỌNG)

Backend **đếm RIÊNG từng loại kubun**, KHÔNG đếm tổng:

- Số phần tử có `kubun = 1` (external) **≤ 99**
- Số phần tử có `kubun = 2` (internal) **≤ 99**

→ Tổng tối đa có thể lên tới **198** (99 + 99) vẫn hợp lệ. FE nên validate theo từng nhóm kubun, **đừng** chặn ở mốc tổng 100.

### 2.5 Conditional theo `sankashaKubun`

| Khi | Phải CÓ | Phải BỎ TRỐNG (null/không gửi) |
|---|---|---|
| `kubun = 1` (他社) | `aitesakiKaishaName`, `aitesakiSankashaName` | `jishaSankashaJugyoinId` |
| `kubun = 2` (自社) | `jishaSankashaJugyoinId` | `aitesakiKaishaName`, `aitesakiSankashaName` |

Với `kubun = 2`: `jishaSankashaJugyoinId` phải là nhân viên **đang hoạt động** (chưa bị xoá) và **có quyền** (role ≠ "không quyền"). Nếu chọn nhân viên không hợp lệ → backend trả `400`. FE nên chỉ cho chọn nhân viên từ danh sách hợp lệ (picker), tránh nhập tay.

---

## 3. Ví dụ Request

### 3.1 Đầy đủ (2 external + 1 internal)
```json
{
  "sankashaTemplateName": "○○社用",
  "sankaNinzu": 4,
  "memo": "他2名",
  "hyojiJun": 100,
  "shosaiList": [
    { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 太郎", "hyojiJun": 1 },
    { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 四志夫", "hyojiJun": 2 },
    { "sankashaKubun": 2, "jishaSankashaJugyoinId": "TM00700001202401010900xxAB", "hyojiJun": 3 }
  ]
}
```

### 3.2 Tối thiểu (chỉ field bắt buộc)
```json
{
  "sankashaTemplateName": "最小テンプレート",
  "shosaiList": [
    { "sankashaKubun": 1, "aitesakiKaishaName": "取引先A", "aitesakiSankashaName": "担当 一郎" }
  ]
}
```
→ Server tự set `hyojiJun` header = `100`, shosai `hyojiJun` = `1`, `sankaNinzu` = null.

---

## 4. Response

### 4.1 Thành công — HTTP 200
```json
{
  "code": 0,
  "type": "success",
  "message": "登録が完了しました。"
}
```
FE chỉ cần kiểm tra HTTP status `200` → hiển thị toast `message` rồi đóng màn / refresh list.

### 4.2 Cấu trúc lỗi chung

Mọi lỗi đều trả về body dạng `BodyErrorResponse`:
```jsonc
{
  "code": 1,                       // mã số nội bộ (xem bảng §4.4)
  "type": "bad_request",           // chuỗi loại lỗi
  "message": "リクエストが不正です。", // message tổng để hiển thị
  "status": 400,                   // = HTTP status
  "path": "/api/v1/sankasha-template",
  "timestamp": "2026-06-05 10:00:00",
  "error": {                       // CÓ THỂ có hoặc không — map field → message
    "sankashaTemplateName": "参加者テンプレート名は必須です。",
    "shosaiList": "参加者を1件以上指定してください。"
  }
}
```

> 📌 Cách FE nên xử lý:
> - Nếu có object `error` → đây là **lỗi validation theo field**. Map từng key vào field tương ứng trên form để hiển thị inline.
> - Key của `error` có thể là **đường dẫn tới phần tử trong list**, ví dụ `shosaiList[2].jishaSankashaJugyoinId` → FE highlight đúng dòng thứ 3 (index 2) trong bảng shosai.
> - Nếu **không có** `error` (vd trùng tên, sai role) → chỉ hiển thị `message` tổng.

### 4.3 Các tình huống lỗi cụ thể

| Tình huống | HTTP | Có `error{}`? | Gợi ý FE |
|---|---|---|---|
| Thiếu field bắt buộc (`sankashaTemplateName` rỗng, `shosaiList` rỗng) | 400 | ✅ | Hiển thị inline theo field |
| `sankaNinzu` > 999 | 400 | ✅ (`sankaNinzu`) | Inline ở ô số người |
| `count(kubun=1) > 99` | 400 | ✅ (`shosaiList`) | Banner "他社参加者は最大99件" |
| `count(kubun=2) > 99` | 400 | ✅ (`shosaiList`) | Banner "自社参加者は最大99件" |
| Conditional fail (thiếu/thừa field theo kubun, hoặc nhân viên không hợp lệ) | 400 | ✅ (key dạng `shosaiList[i].field`) | Highlight đúng dòng |
| **Trùng tên template** (của chính user) | 400 | ❌ | Toast `message`: `「○○社用」は既に登録されている参加者テンプレート名です。` |
| Sai role | 403 | ❌ | Toast quyền truy cập |
| Token thiếu/hết hạn | 401 | ❌ | Redirect login |
| Lỗi hệ thống | 500 | ❌ | Toast lỗi chung + cho retry |

> ⚠️ Lưu ý: **trùng tên trả về 400** (không phải 409). Đừng code FE bắt riêng 409.

### 4.4 Bảng `code` / `type`

| `code` | `type` | HTTP |
|---|---|---|
| 0 | `success` | 200 |
| 1 | `bad_request` | 400 |
| 2 | `unauthorized_token` | 401 |
| 3 | `forbidden` | 403 |
| 6 | `internal_server_error` | 500 |

---

## 5. Validate phía FE (nên làm trước khi gọi API)

Để UX tốt và giảm round-trip, FE nên pre-validate đúng theo ràng buộc backend:

1. `sankashaTemplateName`: không rỗng, ≤ 250 ký tự.
2. `sankaNinzu`: để trống được; nếu nhập thì là `0` hoặc số nguyên `1`–`999`.
3. `hyojiJun`: nếu nhập, `1`–`9999`.
4. `shosaiList`: ≥ 1 dòng.
5. Đếm riêng: `kubun=1` ≤ 99 dòng **và** `kubun=2` ≤ 99 dòng.
6. Mỗi dòng:
   - `kubun=1`: bắt buộc `aitesakiKaishaName` + `aitesakiSankashaName` (≤ 250), không gửi `jishaSankashaJugyoinId`.
   - `kubun=2`: bắt buộc `jishaSankashaJugyoinId` (chọn từ picker nhân viên hợp lệ), không gửi 2 field aitesaki.

> Validation backend vẫn là chốt chặn cuối — FE validate chỉ để UX. Luôn xử lý nhánh lỗi 400 trả về.

---

## 6. TypeScript interface gợi ý

```typescript
/** 1 dòng người tham gia trong template */
export interface SankashaTemplateShosai {
  /** 1 = external (他社), 2 = internal (自社) */
  sankashaKubun: 1 | 2;
  /** Bắt buộc khi kubun=1 */
  aitesakiKaishaName?: string;
  /** Bắt buộc khi kubun=1 */
  aitesakiSankashaName?: string;
  /** Bắt buộc khi kubun=2 (29 ký tự) */
  jishaSankashaJugyoinId?: string;
  /** 1–9999, optional (default 1) */
  hyojiJun?: number;
}

/** Body của POST /api/v1/sankasha-template */
export interface CreateSankashaTemplateRequest {
  sankashaTemplateName: string;         // <= 250
  sankaNinzu?: number;                  // 0 hoặc 1–999
  memo?: string;
  hyojiJun?: number;                    // 1–9999 (default 100)
  shosaiList: SankashaTemplateShosai[]; // >= 1
}

/** Response thành công */
export interface ModelApiResponse {
  code: number;     // 0 khi success
  type: string;     // "success"
  message: string;
}

/** Response lỗi */
export interface BodyErrorResponse {
  code: number;
  type: string;
  message: string;
  status: number;
  path: string;
  timestamp: string;
  error?: Record<string, string>; // field-level errors (có thể không có)
}
```

### Ví dụ gọi (fetch)
```typescript
async function createSankashaTemplate(
  body: CreateSankashaTemplateRequest,
  token: string,
): Promise<ModelApiResponse> {
  const res = await fetch('/api/v1/sankasha-template', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });

  const data = await res.json();
  if (!res.ok) {
    // data là BodyErrorResponse — map data.error vào form nếu có
    throw data as BodyErrorResponse;
  }
  return data as ModelApiResponse;
}
```

---

## 7. Checklist nhanh cho FE

- [ ] Gắn header `Authorization: Bearer <token>`.
- [ ] KHÔNG gửi `jugyoinId` / `hojinCode` / các field hệ thống.
- [ ] `sankashaTemplateName` không rỗng, ≤ 250.
- [ ] `shosaiList` ≥ 1 dòng; đếm riêng kubun=1 ≤ 99 và kubun=2 ≤ 99.
- [ ] Mỗi dòng điền đúng field theo kubun (xem §2.5).
- [ ] `kubun=2` chọn nhân viên từ picker hợp lệ (không nhập tay).
- [ ] Xử lý 200 (success toast) + 400 (map `error{}` inline) + 403/401/500.
- [ ] Trùng tên là **400** (không phải 409).
