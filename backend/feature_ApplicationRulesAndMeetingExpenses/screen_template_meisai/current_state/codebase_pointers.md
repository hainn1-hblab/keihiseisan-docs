# Codebase Pointers — Màn Template Meisai (current state)

> File này CHỈ trỏ đường dẫn, KHÔNG copy nội dung file. Claude sẽ tự đọc các file được trỏ tới.
> Cập nhật ngày: `<2026-06-04>`

## Hướng dẫn dùng

- Điền đường dẫn THỰC TẾ vào các mục dưới (xoá `<...>` đi).
- Mục nào KHÔNG có trong codebase hiện tại → ghi `(không có)`.
- Mục nào KHÔNG CHẮC → ghi `(uncertain - Claude tự search bằng từ khoá: <keyword>)`.
- KHÔNG đoán đường dẫn. Đường dẫn sai sẽ làm Claude đọc nhầm file.

## Cách tìm nhanh đường dẫn

```bash
# Tìm theo tên class
find backend/src -name "*MeisaiTemplate*" -type f

# Tìm theo nội dung
grep -r "tm_meisai_template" backend/src --include="*.java" -l
grep -r "meisai-template" api_interface_generate_tool/ -l
```

---

## 1. Database Layer

### Liquibase changesets (lịch sử migration của các bảng meisai template)
path: backend/src/main/resources/liquibase/init/keihi_com/tm_meisai_template.xml


---

## 2. Entity Layer (`adapter/out/persistence/db/entity/`)

### Entity chính
- backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/entity/TmMeisaiTemplate.java

### Entity phụ (nếu header+detail pattern)
- `<path/to/TmMeisaiTemplateShosai.java hoặc tương tự>` — (không có)

### Entity liên quan (FK)
- `<path/to/entity khác mà MeisaiTemplate có FK trỏ tới>`

---

## 3. Repository Layer (`adapter/out/persistence/db/repository/`)

backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/repository/TmMeisaiTemplateRepository.java

---

## 4. Domain DTO (`application/domain/`)

- backend/src/main/java/jp/co/keihi/application/domain/MeisaiTemplateDto.java
- backend/src/main/java/jp/co/keihi/application/domain/MeisaiTemplateSearchParamDto.java

---

## 5. Application Layer

### Use case interfaces (`application/port/in/`)
- backend/src/main/java/jp/co/keihi/application/port/in/MeisaiTemplateUseCase.java

### Output port interfaces (`application/port/out/`)
- backend/src/main/java/jp/co/keihi/application/port/out/MeisaiTemplateCrud.java

### Service implementations (`application/service/`)
- backend/src/main/java/jp/co/keihi/application/service/MeisaiTemplateService.java

### Validator (nếu có)
- `<path/to/ShosaiValidator.java hoặc tương tự>`

---

## 6. Adapter Layer

### Output adapter (`adapter/out/persistence/db/`)
- backend/src/main/java/jp/co/keihi/adapter/out/persistence/db/MeisaiTemplateAdapter.java

### Configuration (`adapter/out/configuration/`)
- `<path/to/MeisaiTemplateConfiguration.java>`

### Input delegate (`adapter/in/api/delegate/`)
- backend/src/main/java/jp/co/keihi/adapter/in/api/delegate/MeisaiTemplateApiDelegateImpl.java

---

## 7. OpenAPI Specification(không có thì thôi)

- `<path/to/openapi.yml>` — search trong file với từ khoá `meisai-template` để tìm:
    - Paths: vd `/meisai-template`, `/meisai-template/{id}`, `/meisai-template/search`
    - Schemas: `MeisaiTemplate`, `MeisaiTemplateShosai`, `MeisaiTemplateSearchParameter`, `ListMeisaiTemplate`

---

## 8. Tests (nếu có)

- `<path/to/MeisaiTemplateServiceTest.java>` — (không có)
- `<path/to/MeisaiTemplateIntegrationTest.java>` — (không có)

---

## 9. Frontend (skip)

- `<path/to/FE folder/component liên quan màn meisai template>` — (không có)

---

## 10. Related screens / dependencies

Các màn/feature khác liên quan tới template meisai (sẽ giúp Claude hiểu boundary):

- **`tm_sankasha_template`** (template người tham gia) — đã implement xong tuần trước.
    - Trỏ: `documents/.../screen_detail_template_nguoi_tham_gia/final_spec.md`
    - Quan hệ: `tm_meisai_template.sankasha_template_id` → FK trỏ tới `tm_sankasha_template.sankasha_template_id`

- **<Module/feature khác liên quan, nếu có>**: <đường dẫn>

---

## 11. Special notes về current implementation

> Phần này QUAN TRỌNG — note bất cứ điều gì "không nằm trong code chính" mà ảnh hưởng đến extend:
"Không có".

---

## 12. Version snapshot

- Branch hiện tại: `develop_new_feature`
- Commit hash gần nhất khi tạo file này: `<git rev-parse HEAD>`
- Last deploy DEV: `<2026-06-04>`
- Người tạo: DucNA1

> Quan trọng vì: nếu tuần sau Claude đọc lại codebase, codebase đã thay đổi → file này là snapshot lúc analyze.
