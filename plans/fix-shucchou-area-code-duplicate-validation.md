# Plan: Fix Duplicate shucchouAreaCode Validation — Scoped to shucchouKubunId

## Context

API `POST /shucchou-area` (và `PUT /shucchou-area`, CSV import) hiện tại validate trùng `shucchouAreaCode` ở phạm vi toàn bộ công ty (`hojinCode`). Khách hàng yêu cầu: chỉ validate trùng code **trong cùng một loại công tác (`shucchouKubunId`)**. Nếu hai khu vực công tác khác `shucchouKubunId` thì được phép dùng cùng một code.

---

## Vị trí vấn đề

File chính: `backend/src/main/java/jp/co/keihi/application/service/ShucchouAreaService.java`

Có **4 chỗ** gọi `shucchouAreaCrudAdapter.getByShucchouAreaCode(hojinCode, code)` để check trùng:

| Method | Dòng (trước fix) | Mục đích |
|--------|-----------------|----------|
| `add()` | 233–241 | Kiểm tra code đã tồn tại trước khi thêm mới |
| `update()` | 467–477 | Kiểm tra code trùng với area khác khi cập nhật |
| `addByCsvRow()` | 1001–1007 | Kiểm tra code khi import CSV (thêm mới) |
| `updateByCsvRow()` | 1090–1097 | Kiểm tra code khi import CSV (cập nhật) |

Query cũ chỉ lọc theo `hojinCode + shucchouAreaCode + deleteFlag`, **bỏ qua `shucchouKubunId`** → sai yêu cầu.

---

## Các file đã thay đổi

### 1. Output Port Interface
**File:** `backend/src/main/java/jp/co/keihi/application/port/out/ShucchouAreaCrud.java`

Thêm method mới:
```java
ShucchouAreaDto getByShucchouKubunIdAndAreaCode(
        String hojinCode, String shucchouKubunId, String shucchouAreaCode);
```

### 2. Repository
**File:** `backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/repository/TmShucchouAreaRepository.java`

Thêm Spring Data method:
```java
TmShucchouArea findByHojinCodeAndShucchouKubunIdAndShucchouAreaCodeAndDeleteFlag(
        String hojinCode, String shucchouKubunId, String shucchouAreaCode, Integer deleteFlag);
```

### 3. Persistence Adapter
**File:** `backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/ShucchouAreaAdapter.java`

Implement method mới `getByShucchouKubunIdAndAreaCode()` gọi repository method trên.

### 4. Service — 4 chỗ được sửa
**File:** `backend/src/main/java/jp/co/keihi/application/service/ShucchouAreaService.java`

Tất cả 4 chỗ đều đổi từ:
```java
shucchouAreaCrudAdapter.getByShucchouAreaCode(hojinCode, dto.getShucchouAreaCode())
```
sang:
```java
shucchouAreaCrudAdapter.getByShucchouKubunIdAndAreaCode(
        hojinCode, dto.getShucchouKubunId(), dto.getShucchouAreaCode())
```

---

## Verification

- Build: `cd backend && ./mvnw clean install`
- Test thủ công:
  1. Tạo 2 shucchouKubun khác nhau (kubun A, kubun B)
  2. Tạo shucchouArea với code `C001` thuộc kubun A → thành công
  3. Tạo shucchouArea với code `C001` thuộc kubun A → lỗi E040 (trùng code trong cùng kubun) ✅
  4. Tạo shucchouArea với code `C001` thuộc kubun B → thành công (khác kubun, không bị chặn) ✅
  5. Kiểm tra tương tự cho update và CSV import

---

## Vấn đề bổ sung: ShucchouAreaAsyncService.processCsvData

### Mô tả

Sau khi cho phép cùng `shucchouAreaCode` tồn tại ở nhiều `shucchouKubunId` khác nhau,
hàm `processCsvData` trong `ShucchouAreaAsyncService` bị ảnh hưởng vì vẫn dùng
`getByShucchouAreaCode()` (scope toàn hojin) để quyết định INSERT hay UPDATE:

- Nếu `shucchouAreaExit != null` → lấy ID cũ, gọi `updateByCsvRow()`
- Nếu `shucchouAreaExit == null` → gọi `addByCsvRow()`

**Hậu quả:**
1. CSV nhập kubunB+codeC001, DB đã có kubunA+codeC001 → query trả kubunA's record
   → **UPDATE nhầm record của kubunA** thay vì INSERT record mới cho kubunB.
2. DB có cả kubunA+codeC001 và kubunB+codeC001 → repository `findBy...` (single-result)
   nhận nhiều row khớp → **`IncorrectResultSizeDataAccessException`** (runtime exception).

### File đã sửa

`backend/src/main/java/jp/co/keihi/application/service/ShucchouAreaAsyncService.java`

### Fix (1 dòng)

Đổi từ:
```java
ShucchouAreaDto shucchouAreaExit = shucchouAreaCrudAdapter.getByShucchouAreaCode(
        super.getHojinCode(),
        csvParam.getShucchouAreaCode());
```
Sang:
```java
ShucchouAreaDto shucchouAreaExit = shucchouAreaCrudAdapter.getByShucchouKubunIdAndAreaCode(
        super.getHojinCode(),
        csvParam.getShucchouKubunId(),
        csvParam.getShucchouAreaCode());
```

`csvParam.getShucchouKubunId()` đã có giá trị vì `convertCsvToRecord()` set nó từ
`shucchouKubun` object (đã lookup ở bước trước).
Không cần thêm method mới — `getByShucchouKubunIdAndAreaCode()` đã có từ fix trước.

### Verification bổ sung

6. Chuẩn bị CSV có 2 dòng: `kubunA + codeC001` và `kubunB + codeC001`
7. Import CSV → cả 2 dòng đều INSERT thành công (khác kubun) ✅
8. Import CSV lần 2 (cùng file) → cả 2 dòng đều UPDATE đúng record của mình ✅
9. Import CSV với dòng `kubunA + codeC001` (kubunA+C001 đã tồn tại) → UPDATE đúng record kubunA ✅
