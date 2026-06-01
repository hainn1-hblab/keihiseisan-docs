# Quản lý phiên bản tài liệu AI tách biệt khỏi GitHub của khách hàng

> Tài liệu vận hành cho đội dev. **CHỈ tồn tại trong repo private của đội dev**, không bao giờ push lên GitHub của khách hàng.

## 1. Vấn đề

Repo `keihiseisan_backend` dùng chung 1 remote với khách hàng (KH):
`origin → git@github.com:SoftwareAgencySystem/keihiseisan_backend.git`.

Đội dev dùng AI (Claude Code, Cursor, Kiro...) sinh tài liệu (spec, detail design...) và code. Cần:
1. **KHÔNG** lộ dấu vết dùng AI lên GitHub của KH.
2. **VẪN** version-control được tài liệu AI để theo dõi thay đổi / review diff / accept-reject sửa đổi.

## 2. Giải pháp: "Nested private repo"

```
keihiseisan_backend/                  ← Repo CHÍNH (origin = GitHub của KH)
├── .git/
├── .gitignore                        ← ignore TẤT CẢ path AI (lớp phòng vệ chính)
├── backend/  src/ ...                ← chỉ code, push cho KH
├── CLAUDE.md, .claude/, .cursor/...  ← cấu hình AI: giữ tại chỗ nhưng bị gitignore
└── documents/                        ← Repo PRIVATE LỒNG NHAU (nested repo)
    ├── .git/                         ← origin = GitHub private RIÊNG của đội dev
    ├── .githooks/pre-commit          ← hook chặn push nhầm
    ├── plans/                        ← tài liệu (file này nằm đây)
    └── backend/                      ← gom từ backend/documents/ cũ
```

**Nguyên lý:** Git không đệ quy vào thư mục con có `.git` riêng. `documents/` vừa bị repo chính gitignore, vừa là repo độc lập → commit code và commit tài liệu nằm ở 2 repo / 2 remote khác nhau, không thể lẫn.

**Vì sao không dùng "1 repo + 2 remote / orphan branch":** `.gitignore` dùng chung mọi nhánh, không thể vừa track (đẩy dev) vừa ignore (giấu KH) cùng một file trong cùng repo → rất dễ push nhầm. Nested repo tách bạch vật lý nên an toàn hơn.

**File cấu hình AI** (`CLAUDE.md`, `.claude/`, `.cursor/`...) phải nằm đúng vị trí tool yêu cầu (root), không gom được vào `documents/` → chỉ cần **ẩn bằng `.gitignore`**, không version-control. Nhóm **tài liệu** mới được version-control trong repo private.

## 3. Cấu hình `.gitignore` repo chính

Đã thêm vào `.gitignore`:
```gitignore
# === AI tooling & generated docs — KHÔNG push lên remote của khách hàng ===
/documents/
/backend/documents/
/CLAUDE.md
/.claude/
/AGENTS.md
/GEMINI.md
/.mcp.json
/.opencode.json
/.cursor/
/.cursorrules
/backend/.cursorrules
/.windsurfrules
/.kiro/
```
> Dùng `/` neo ở root để không vô tình ẩn code thật.

## 4. Setup lần đầu (đã/đang thực hiện)

1. **Gỡ file AI khỏi staging:** `git restore --staged CLAUDE.md .claude/rules/*.md`
2. **Cập nhật `.gitignore`** (mục 3).
3. **Gom tài liệu:** `backend/documents/` → `documents/backend/`.
4. **Tạo repo GitHub PRIVATE riêng** (vd `keihiseisan-docs`) dưới tài khoản/tổ chức RIÊNG của đội dev — KHÔNG dùng org `SoftwareAgencySystem`, KH không được thêm vào.
5. **Khởi tạo nested repo & push:**
   ```bash
   cd documents
   git init -b main
   git remote add origin git@github.com:<DEV_PRIVATE_ORG>/keihiseisan-docs.git
   git add .
   git commit -m "Initial: AI-generated documents"
   git push -u origin main
   ```
6. **Bật hook chặn push nhầm** ở repo chính:
   ```bash
   cd ..                 # về root repo chính
   git config core.hooksPath documents/.githooks
   chmod +x documents/.githooks/pre-commit   # macOS/Linux/Git Bash
   ```

## 5. Onboarding dev mới

```bash
git clone git@github.com:SoftwareAgencySystem/keihiseisan_backend.git
cd keihiseisan_backend
git clone git@github.com:<DEV_PRIVATE_ORG>/keihiseisan-docs.git documents
git config core.hooksPath documents/.githooks
```

## 6. Quy trình làm việc hằng ngày

- **Sửa code** → commit/push ở repo chính như bình thường (tài liệu đã bị ignore, không lẫn).
- **Sửa/sinh tài liệu** → `cd documents` rồi commit/push lên repo private. Xem lịch sử & diff, review accept/reject thay đổi qua diff/PR ở repo private.

## 7. Kiểm chứng an toàn

```bash
# Không lộ AI:
git check-ignore -v CLAUDE.md documents/ .cursor/        # phải báo bị ignore
git status                                                # untracked không còn path AI

# Code thật không bị ẩn nhầm (in ra rỗng, exit 1):
git check-ignore backend/src/test/java/.../SomeTest.java

# Hook hoạt động:
git add -f CLAUDE.md && git commit -m test                # phải bị chặn, exit 1
git restore --staged CLAUDE.md

# Docs có version riêng:
git -C documents log --oneline
git -C documents remote -v                                # trỏ repo private
```
