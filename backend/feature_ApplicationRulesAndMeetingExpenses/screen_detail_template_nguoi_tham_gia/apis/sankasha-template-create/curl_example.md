---
version: 1.0.0
status: draft
last_updated: 2026-06-02
based_on_final_spec_version: 1.2.1
---

# cURL Examples — Create Sankasha Template

> Tập hợp lệnh `curl` để smoke-test endpoint **`POST /api/v1/sankasha-template`** bằng Postman / terminal.
> Endpoint là owner-scoped: `jugyoin_id` lấy từ JWT (login user), **KHÔNG** truyền trong body.

---

## 0. Chuẩn bị

| Mục | Giá trị |
|---|---|
| Method | `POST` |
| URL | `http://localhost:8080/api/v1/sankasha-template` |
| Header | `Content-Type: application/json` |
| Header | `Authorization: Bearer <JWT>` |
| Role yêu cầu | `5` (DEPARTMENT_MANAGEMENT) hoặc `6` (SUPER_ADMIN) — role khác → 403 |

**Trước khi test:**
1. Chạy migration: `cd backend && ./mvnw liquibase:update` (tạo `tm_sankasha_template` + `tm_sankasha_template_shosai`).
2. Lấy JWT hợp lệ của user role 5/6 (login qua Keycloak / endpoint auth của hệ thống).
3. Với case có `jishaSankashaJugyoinId` (kubun=2): thay placeholder bằng **employee ID thật** đang tồn tại (`delete_flag=0`) và role ≠ NO_RIGHT, nếu không sẽ nhận 400 (E037).

> ⚠️ Các `jishaSankashaJugyoinId` bên dưới (`TM00700001202401010900xxAB`...) chỉ là placeholder minh hoạ. Phải thay bằng ID thật trong DB của bạn.

---

## 1. Happy case — 2 external + 1 internal

### Bash / macOS / Linux
```bash
curl -X POST "http://localhost:8080/api/v1/sankasha-template" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT>" \
  -d '{
    "sankashaTemplateName": "○○社用",
    "sankaNinzu": 4,
    "memoSankasha": "他2名",
    "hyojiJun": 100,
    "shosaiList": [
      { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 太郎", "hyojiJun": 1 },
      { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 四志夫", "hyojiJun": 2 },
      { "sankashaKubun": 2, "jishaSankashaJugyoinId": "TM00700001202401010900xxAB", "hyojiJun": 3 }
    ]
  }'
```

### PowerShell (Windows) — dùng `curl.exe`
```powershell
curl.exe -X POST "http://localhost:8080/api/v1/sankasha-template" `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer <JWT>" `
  --data-raw '{
    "sankashaTemplateName": "○○社用",
    "sankaNinzu": 4,
    "memoSankasha": "他2名",
    "hyojiJun": 100,
    "shosaiList": [
      { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 太郎", "hyojiJun": 1 },
      { "sankashaKubun": 1, "aitesakiKaishaName": "HBLAB株式会社", "aitesakiSankashaName": "経費 四志夫", "hyojiJun": 2 },
      { "sankashaKubun": 2, "jishaSankashaJugyoinId": "TM00700001202401010900xxAB", "hyojiJun": 3 }
    ]
  }'
```

**Kỳ vọng:** `200 OK`
```json
{ "code": 0, "type": "success", "message": "登録が完了しました。" }
```
Kiểm tra DB: `tm_sankasha_template` có 1 row (`jugyoin_id` = login user), `tm_sankasha_template_shosai` có 3 row cùng `sankasha_template_id`.

---

## 2. Internal only — chỉ nhân viên nội bộ
```bash
curl -X POST "http://localhost:8080/api/v1/sankasha-template" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT>" \
  -d '{
    "sankashaTemplateName": "社内会議テンプレート",
    "sankaNinzu": 3,
    "memoSankasha": null,
    "hyojiJun": 50,
    "shosaiList": [
      { "sankashaKubun": 2, "jishaSankashaJugyoinId": "TM00700001202401010900xxAB", "hyojiJun": 1 },
      { "sankashaKubun": 2, "jishaSankashaJugyoinId": "TM00700001202401010900xxCD", "hyojiJun": 2 },
      { "sankashaKubun": 2, "jishaSankashaJugyoinId": "TM00700001202401010900xxEF", "hyojiJun": 3 }
    ]
  }'
```
**Kỳ vọng:** `200 OK` (nếu cả 3 employee ID hợp lệ).

---

## 3. Min required — chỉ field bắt buộc (default hyojiJun/sankaNinzu/memoSankasha)
```bash
curl -X POST "http://localhost:8080/api/v1/sankasha-template" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT>" \
  -d '{
    "sankashaTemplateName": "最小テンプレート",
    "shosaiList": [
      { "sankashaKubun": 1, "aitesakiKaishaName": "取引先A", "aitesakiSankashaName": "担当 一郎" }
    ]
  }'
```
**Kỳ vọng:** `200 OK` — header `hyoji_jun` = default (`SqlUtil.DEFAULT_HYOJIJUN`), shosai `hyoji_jun` = 1.

---

## 4. Các case lỗi (negative test)

### 4.1 Thiếu field bắt buộc → 400
```bash
curl -X POST "http://localhost:8080/api/v1/sankasha-template" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT>" \
  -d '{ "sankashaTemplateName": "", "shosaiList": [] }'
```
→ `400` với `error.sankashaTemplateName` + `error.shosaiList`.

### 4.2 Conditional fail — kubun=1 nhưng truyền jishaSankashaJugyoinId → 400
```bash
curl -X POST "http://localhost:8080/api/v1/sankasha-template" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT>" \
  -d '{
    "sankashaTemplateName": "条件NGテンプレート",
    "shosaiList": [
      { "sankashaKubun": 1, "jishaSankashaJugyoinId": "TM00700001202401010900xxAB" }
    ]
  }'
```
→ `400` (kubun=1 cần `aitesakiKaishaName` + `aitesakiSankashaName`, cấm `jishaSankashaJugyoinId`).

### 4.3 Trùng tên template → 400 (E040)
Gửi lại **case 1** lần thứ hai với cùng `sankashaTemplateName` ("○○社用").
→ `400`, message: `「○○社用」は既に登録されている参加者テンプレート名です。`

### 4.4 Sai role → 403
Dùng JWT của user role 1–4.
→ `403`, message: `アクセス権限がありません。`

---

## 5. Ghi chú Postman

- Tạo Environment variable `{{baseUrl}}` = `http://localhost:8080/api/v1` và `{{token}}` = JWT.
- URL: `{{baseUrl}}/sankasha-template`; Header `Authorization: Bearer {{token}}`.
- Body → raw → JSON: dán phần JSON trong `-d` ở case bất kỳ.
- Ký tự tiếng Nhật (`○○社用`...): Postman gửi UTF-8 mặc định nên không cần encode thêm.
