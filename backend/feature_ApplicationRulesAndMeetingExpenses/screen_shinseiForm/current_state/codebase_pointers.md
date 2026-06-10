# Codebase Pointers — Màn ShinseiForm (current state)

> File này CHỈ trỏ đường dẫn, KHÔNG copy nội dung file. Claude sẽ tự đọc các file được trỏ tới.
> Cập nhật ngày: `<2026-06-09>`

## Hướng dẫn dùng

- Điền đường dẫn THỰC TẾ vào các mục dưới (xoá `<...>` đi).
- Mục nào KHÔNG có trong codebase hiện tại → ghi `(không có)`.
- Mục nào KHÔNG CHẮC → ghi `(uncertain - Claude tự search bằng từ khoá: <keyword>)`.
- KHÔNG đoán đường dẫn. Đường dẫn sai sẽ làm Claude đọc nhầm file.

## Cách tìm nhanh đường dẫn


```bash
# Tìm theo tên class
find backend/src -name "_ShinseiForm_" -type f


# Tìm theo nội dung
grep -r "tm_shinsei_form " backend/src --include="*.java" -l grep -r "ShinseiForm" api_interface_generate_tool/ -l

```


---

## 1. Database Layer

### Liquibase changesets (lịch sử migration của các bảng shinsei form)
path: backend/src/main/resources/liquibase/init/keihi_com/tm_shinsei_form.xml


---

## 2. Entity Layer (`adapter/out/persistence/db/entity/`)

### Entity chính
- backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/entity/TmShinseiForm.java

### Entity liên quan (FK)
- `<path/to/entity khác mà ShinseiForm có FK trỏ tới>`

---

## 3. Repository Layer (`adapter/out/persistence/db/repository/`)

backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/repository/TmShinseiFormRepository.java

---

## 4. Domain DTO (`application/domain/`)

- backend/src/main/java/jp/co/keihi/application/domain/ShinseiFormDto.java
- backend/src/main/java/jp/co/keihi/application/domain/ShinseiFormSearchParamDto.java

---

## 5. Application Layer

### Use case interfaces (`application/port/in/`)
- backend/src/main/java/jp/co/keihi/application/port/in/ShinseiFormUseCase.java

### Output port interfaces (`application/port/out/`)
- backend/src/main/java/jp/co/keihi/application/port/out/ShinseiFormCrud.java

### Service implementations (`application/service/`)
- backend/src/main/java/jp/co/keihi/application/service/ShinseiFormService.java

### Validator (nếu có)
- `<path/to/ShosaiValidator.java hoặc tương tự>`

---

## 6. Adapter Layer

### Output adapter (`adapter/out/persistence/db/`)
- backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/ShinseiFormAdapter.java

### Configuration (`adapter/out/configuration/`)
- `<path/to/ShinseiFormConfiguration.java>`

### Input delegate (`adapter/in/api/delegate/`)
- backend/src/main/java/jp/co/keihi/adapter/in/api/delegate/ShinseiFormApiDelegateImpl.java

---

## 7. OpenAPI Specification(không có thì thôi)

- `<path/to/openapi.yml>` — search trong file với từ khoá `shinsei-form` để tìm:
  - Paths: vd `/shinsei-form`, `/shinsei-form/{id}`, `/shinsei-form/search`
  - Schemas: `ShinseiForm`, `ShinseiFormShosai`, `ShinseiFormSearchParameter`, `ListShinseiForm`

---

## 8. Tests (nếu có)

- `<path/to/ShinseiFormServiceTest.java>` — (không có)
- `<path/to/ShinseiFormIntegrationTest.java>` — (không có)

---

## 9. Frontend (skip)

- `<path/to/FE folder/component liên quan màn shinsei form>` — (không có)

---

## 10. Related screens / dependencies

Các màn/feature khác liên quan tới shinsei form (sẽ giúp Claude hiểu boundary):


---

## 11. Special notes về current implementation

> Phần này QUAN TRỌNG — note bất cứ điều gì "không nằm trong code chính" mà ảnh hưởng đến extend:
"Không có".

---

## 12. Version snapshot

- Branch hiện tại: `develop_new_feature`
- Commit hash gần nhất khi tạo file này: `<git rev-parse HEAD>`
- Last deploy DEV: `<2026-06-09>`
- Người tạo: DucNA1

> Quan trọng vì: nếu tuần sau Claude đọc lại codebase, codebase đã thay đổi → file này là snapshot lúc analyze.