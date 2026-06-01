# Fix: Thứ tự chức vụ trong khu vực công tác không phản ánh thay đổi hyojiJun từ master

## 1. Mô tả vấn đề

### Triệu chứng
- Tạo khu vực công tác (`tm_shucchou_area`) → lưu thành công, danh sách chức vụ đính kèm được lưu vào `tm_shucchou_area_yakushoku`.
- Sau đó thay đổi `hyoji_jun` ở màn quản lý Chức vụ (`tm_yakushoku`) → thứ tự master thay đổi.
- Gọi `POST /shucchou-area/search` (hoặc view lại khu vực công tác đã tạo) → danh sách chức vụ vẫn hiển thị theo **thứ tự cũ** (creation time) thay vì thứ tự master hiện tại.

### Root cause

**File:** `ShucchouAreaAdapter.java`

Cả hai method `search()` và `read()` đều truy vấn children bằng:
```java
findByShucchouAreaIdInAndDeleteFlagOrderByAddDateAsc(...)
// hoặc
findByShucchouAreaIdAndDeleteFlagOrderByAddDateAsc(...)
```

→ Children được sắp xếp theo **`add_date` (thời điểm tạo)**, không phải theo `hyoji_jun` + `yakushoku_code` của bảng master `tm_yakushoku`.

Khi enrich data, code chỉ set `yakushokuName` và `yakushokuCode`, **không sort lại** theo master order.

---

## 2. Phân tích code chi tiết

### File cần sửa
```
backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/ShucchouAreaAdapter.java
```

### Method `search()` (line 172–280)
- Line 216–218: Batch fetch children → sorted by `addDate ASC` ✗
- Line 258–271: Enrich với yakushoku master → set name/code nhưng **không sort** ✗
- `yakushokuMap` (Map<yakushokuId, TmYakushoku>) đã có sẵn và chứa `hyojiJun`

### Method `read()` (line 124–163)
- Line 136–137: Fetch children → sorted by `addDate ASC` ✗
- Line 146–154: **N+1 query** – fetch từng yakushoku riêng lẻ trong vòng lặp stream ✗
- Không có sort sau enrichment ✗

---

## 3. Giải pháp

### Nguyên tắc
Không cần thay đổi schema DB. Sau khi enrich children với dữ liệu từ yakushoku master map, **sort list bằng Java** theo `hyojiJun ASC` → `yakushokuCode ASC` (đúng thứ tự mà FE call `yakushoku/getviewlist`).

### Thay đổi trong `search()`

Sau khi map children → DTO có enrich, thêm bước `.sorted()` sử dụng `yakushokuMap`:

```java
List<ShucchouAreaYakushokuDto> childrenDtos = myChildrenEntities.stream()
    .map(childEntity -> {
        ShucchouAreaYakushokuDto childDto = new ShucchouAreaYakushokuDto();
        BeanUtil.copyProperties(childDto, childEntity);
        TmYakushoku yakushoku = yakushokuMap.get(childEntity.getYakushokuId());
        if (yakushoku != null) {
            childDto.setYakushokuName(yakushoku.getYakushokuName());
            childDto.setYakushokuCode(yakushoku.getYakushokuCode());
        }
        return childDto;
    })
    // Sort by master yakushoku order: hyojiJun ASC, yakushokuCode ASC
    .sorted(Comparator
        .comparingInt((ShucchouAreaYakushokuDto d) -> {
            TmYakushoku y = yakushokuMap.get(d.getYakushokuId());
            return (y != null && y.getHyojiJun() != null) ? y.getHyojiJun() : Integer.MAX_VALUE;
        })
        .thenComparing(d -> {
            TmYakushoku y = yakushokuMap.get(d.getYakushokuId());
            return (y != null && y.getYakushokuCode() != null) ? y.getYakushokuCode() : "";
        }))
    .collect(Collectors.toList());
```

### Thay đổi trong `read()`

Refactor từ N+1 sang batch fetch, sau đó sort:

```java
// Thay thế đoạn N+1 cũ bằng batch fetch
List<String> childYakushokuIds = childrenEntities.stream()
    .map(TmShucchouAreaYakushoku::getYakushokuId)
    .collect(Collectors.toList());

List<TmYakushoku> yakushokuMasterList = tmYakushokuRepository
    .findByHojinCodeAndYakushokuIdInAndDeleteFlag(
        hojinCode, childYakushokuIds, DeleteFlag.UNDELETED.getValue());

Map<String, TmYakushoku> yakushokuMasterMap = yakushokuMasterList.stream()
    .collect(Collectors.toMap(
        TmYakushoku::getYakushokuId,
        Function.identity(),
        (existing, replacement) -> existing));

List<ShucchouAreaYakushokuDto> childrenDtos = childrenEntities.stream()
    .map(childEntity -> {
        ShucchouAreaYakushokuDto childDto = new ShucchouAreaYakushokuDto();
        BeanUtil.copyProperties(childDto, childEntity);
        TmYakushoku yakushoku = yakushokuMasterMap.get(childEntity.getYakushokuId());
        if (yakushoku != null) {
            childDto.setYakushokuName(yakushoku.getYakushokuName());
            childDto.setYakushokuCode(yakushoku.getYakushokuCode());
        }
        return childDto;
    })
    // Sort by master yakushoku order: hyojiJun ASC, yakushokuCode ASC
    .sorted(Comparator
        .comparingInt((ShucchouAreaYakushokuDto d) -> {
            TmYakushoku y = yakushokuMasterMap.get(d.getYakushokuId());
            return (y != null && y.getHyojiJun() != null) ? y.getHyojiJun() : Integer.MAX_VALUE;
        })
        .thenComparing(d -> {
            TmYakushoku y = yakushokuMasterMap.get(d.getYakushokuId());
            return (y != null && y.getYakushokuCode() != null) ? y.getYakushokuCode() : "";
        }))
    .collect(Collectors.toList());

dto.setYakushokuKoteichiList(childrenDtos);
```

---

## 4. Các file cần sửa

| File | Thay đổi |
|------|----------|
| `adapter/out/persistence/db/ShucchouAreaAdapter.java` | Sửa method `search()` và `read()` |

**Không cần:**
- Thay đổi schema DB (không cần migration Liquibase)
- Thay đổi DTO, entity, repository, service, delegate
- Thay đổi API spec

---

## 5. Import cần thêm vào `ShucchouAreaAdapter.java`

Kiểm tra, có thể cần thêm:
```java
import java.util.Comparator;
import java.util.function.Function;
```
(Kiểm tra xem `Function` đã được import chưa ở line 35 — đã có. `Comparator` cần thêm nếu chưa có.)

---

## 6. Kiểm tra / Verification

### Test thủ công
1. Tạo một khu vực công tác mới với `yakushokuKoteichiType = 2` (INDIVIDUAL), thêm nhiều chức vụ.
2. Ghi nhớ thứ tự chức vụ hiện tại (ví dụ: A=hyojiJun 100, B=hyojiJun 200).
3. Thay đổi `hyojiJun` ở màn Chức vụ sao cho thứ tự đảo lại (ví dụ: B=hyojiJun 50).
4. Gọi `POST /shucchou-area/search` → danh sách chức vụ phải hiển thị B trước A.
5. Gọi `GET` hoặc read lại khu vực công tác cụ thể → cũng phải hiển thị đúng thứ tự.

### Edge cases
- Yakushoku trong master đã bị xóa (delete_flag=1): child DTO sẽ không có name/code, và `Integer.MAX_VALUE` / `""` sẽ đẩy về cuối list → hành vi chấp nhận được.
- Nhiều yakushoku có cùng `hyojiJun`: sort tie-break bằng `yakushokuCode ASC` → đúng với behavior của `yakushoku/getviewlist`.
- `yakushokuKoteichiType = 1` (ALL): không có children, không ảnh hưởng.

---

## 7. Phụ lục — Luồng đầy đủ (để tham khảo)

```
POST /shucchou-area/search
  → ShucchouAreaApiDelegateImpl.searchShucchouArea()
    → ShucchouAreaService.search()
      → ShucchouAreaAdapter.search()
          1. searchComplex() → Page<TmShucchouArea>
          2. Batch fetch TmShucchouAreaYakushoku (ordered by add_date)
          3. Batch fetch TmYakushoku master map
          4. For each parent: map children → DTO → [FIX: sort by hyojiJun, yakushokuCode]
          5. Return ListShucchouAreaDto
```
