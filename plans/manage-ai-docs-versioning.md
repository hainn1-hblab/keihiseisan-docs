# Quản lý phiên bản tài liệu AI tách biệt khỏi GitHub của khách hàng

> Tài liệu vận hành cho đội dev. **CHỈ tồn tại trong repo private của đội dev**, không bao giờ push lên GitHub của khách hàng.
>
> Trạng thái: ✅ **Đã triển khai & verify thành công** (2026-06-01). Tài liệu đã được đẩy lên repo private.

---

## 1. Vấn đề

Repo `keihiseisan_backend` dùng chung 1 remote với khách hàng (KH):
`origin → git@github.com:SoftwareAgencySystem/keihiseisan_backend.git`.

Đội dev dùng AI (Claude Code, Cursor, Kiro...) sinh tài liệu (spec, detail design...) và code. Cần:
1. **KHÔNG** lộ dấu vết dùng AI lên GitHub của KH.
2. **VẪN** version-control được tài liệu AI để theo dõi thay đổi / review diff / accept-reject sửa đổi.

---

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

---

## 3. Thông tin cấu hình thực tế (đã triển khai)

| Hạng mục | Giá trị |
|---|---|
| Repo chính (chung với KH) | `git@github.com:SoftwareAgencySystem/keihiseisan_backend.git` |
| **Repo docs private** | `git@github.com-hainn1:hainn1-hblab/keihiseisan-docs.git` |
| Tài khoản sở hữu repo docs | `hainn1-hblab` |
| Nhánh docs | `main` |
| Hook chặn push nhầm | `documents/.githooks/pre-commit` + `core.hooksPath=documents/.githooks` (repo chính) |
| Thư mục tài liệu đã gom | `backend/documents/` → `documents/backend/` |

### Cấu hình `.gitignore` repo chính (đã thêm)
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
> Dùng `/` neo ở root để không vô tình ẩn code thật (vd file test hợp lệ trong `backend/src/...` vẫn commit bình thường).

---

## 4. Cấu hình SSH đa tài khoản (QUAN TRỌNG)

Máy dev có thể đang dùng SSH key ánh xạ sang **tài khoản GitHub khác** với tài khoản sở hữu repo docs. SSH xác thực bằng **KEY trên máy**, KHÔNG phải tài khoản đăng nhập web → phải dùng đúng key của tài khoản sở hữu repo docs.

**Tình huống đã gặp trên máy `ducna1`:** key mặc định `~/.ssh/id_rsa` ánh xạ sang `longdq1-hblab` (key dùng cho repo source của KH) → push repo docs (thuộc `hainn1-hblab`) bị từ chối: `Permission ... denied to longdq1-hblab`.

**Cách xử lý:** tạo SSH key RIÊNG cho `hainn1-hblab` + host alias riêng, **không đụng tới 2 key cũ**.

### Bảng SSH key trên máy
| Alias trong `~/.ssh/config` | Key | Tài khoản GitHub | Dùng cho |
|---|---|---|---|
| `github.com` (mặc định) | `id_rsa` | longdq1-hblab | repo source của KH |
| `github.com-shikamii` | `id_rsa_shikamii` | Shikamii | cá nhân (không liên quan) |
| **`github.com-hainn1`** | `id_ed25519_hainn1` | **hainn1-hblab** | **repo docs private** |

### Các bước tạo key cho hainn1 (đã làm)
```bash
# 1. Tạo keypair mới (giữ nguyên key cũ)
ssh-keygen -t ed25519 -C "hainn1-hblab keihiseisan-docs" -f "$HOME/.ssh/id_ed25519_hainn1" -N ""

# 2. Lấy public key rồi thêm vào GitHub tài khoản hainn1-hblab:
#    Settings → SSH and GPG keys → New SSH key (Authentication Key)
cat "$HOME/.ssh/id_ed25519_hainn1.pub"
```

### Host alias trong `~/.ssh/config` (đã thêm)
```sshconfig
# SSH key hainn1 (repo tài liệu private: keihiseisan-docs)
Host github.com-hainn1
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_hainn1
    IdentitiesOnly yes
```
> `IdentitiesOnly yes` bắt buộc — để SSH chỉ dùng đúng key hainn1, không fallback sang `id_rsa` (longdq1).

> Vì alias là `github.com-hainn1`, **remote của repo docs phải dùng dạng** `git@github.com-hainn1:hainn1-hblab/keihiseisan-docs.git` (thay `github.com` bằng `github.com-hainn1`).

---

## 5. Quy trình setup lần đầu (đã hoàn tất — ghi lại để tham khảo)

```bash
# Bước 1 — Gỡ file AI đang staged (giữ nguyên trên đĩa, KHÔNG xoá)
git restore --staged CLAUDE.md .claude/rules/api-conventions.md .claude/rules/database.md

# Bước 2 — Cập nhật .gitignore repo chính (xem mục 3)

# Bước 3 — Gom tài liệu về 1 thư mục
mv backend/documents documents/backend

# Bước 4 — Tạo repo PRIVATE trên GitHub (đã tạo: hainn1-hblab/keihiseisan-docs)

# Bước 5 — Tạo SSH key cho hainn1 + thêm vào GitHub + host alias (xem mục 4)

# Bước 6 — Khởi tạo nested repo & push
cd documents
git init -b main
git add .
git commit -m "Initial: AI-generated documents"
git remote add origin git@github.com-hainn1:hainn1-hblab/keihiseisan-docs.git
git push -u origin main

# Bước 7 — Bật hook chặn push nhầm ở repo chính
cd ..
git config core.hooksPath documents/.githooks
chmod +x documents/.githooks/pre-commit   # macOS/Linux/Git Bash
```

> Lưu ý đã gặp: GitHub **không hỗ trợ mật khẩu qua HTTPS** (`Password authentication is not supported`). Dùng SSH (mục 4) hoặc Personal Access Token. Tài liệu này dùng SSH.

---

## 6. Onboarding dev mới

```bash
# 1. Clone repo chính (chưa có documents/)
git clone git@github.com:SoftwareAgencySystem/keihiseisan_backend.git
cd keihiseisan_backend

# 2. Thiết lập SSH key cho hainn1 (mục 4) NẾU máy chưa có key truy cập được repo docs

# 3. Clone repo docs vào thư mục documents/ (đã bị repo chính gitignore)
git clone git@github.com-hainn1:hainn1-hblab/keihiseisan-docs.git documents

# 4. Bật hook chặn push nhầm
git config core.hooksPath documents/.githooks
chmod +x documents/.githooks/pre-commit   # macOS/Linux/Git Bash
```

> `core.hooksPath` là config local (trong `.git/config` của repo chính), không bị đẩy lên GitHub của KH → an toàn, nhưng mỗi dev phải tự chạy lệnh này.

---

## 7. Quy trình làm việc hằng ngày

- **Sửa code** → commit/push ở repo chính như bình thường (tài liệu đã bị ignore, không lẫn).
- **Sửa/sinh tài liệu** → `cd documents` rồi commit/push lên repo private. Xem lịch sử & diff, review accept/reject thay đổi qua diff/PR ở repo private trên GitHub.

---

## 8. Kiểm chứng an toàn (kết quả thực tế ✅)

```bash
# (A) Không lộ AI — tất cả path AI bị ignore:
git check-ignore CLAUDE.md .claude/ .cursor/ documents/ AGENTS.md GEMINI.md .mcp.json .kiro/
#   → in ra tất cả path trên = đã bị ignore ✅

# (B) git status repo chính KHÔNG còn path AI ở phần untracked ✅
git status -sb

# (C) Code thật KHÔNG bị ẩn nhầm (in ra rỗng, exit 1) ✅
git check-ignore backend/src/test/java/jp/co/keihi/application/util/NumericDigitsOrMaxLengthValidatorTest.java

# (D) Hook hoạt động — commit có file AI bị chặn (exit 1) ✅
git add -f CLAUDE.md && git commit -m test       # → bị hook chặn
git restore --staged CLAUDE.md                    # dọn dẹp

# (E) Danh tính SSH đúng là hainn1 ✅
ssh -T git@github.com-hainn1                       # → "Hi hainn1-hblab!"

# (F) Repo docs có version & remote đúng ✅
git -C documents log --oneline                     # → 7810618 Initial: AI-generated documents
git -C documents remote -v                         # → git@github.com-hainn1:hainn1-hblab/keihiseisan-docs.git
git -C documents status -sb                        # → ## main...origin/main (đã sync)
```

---

## 9. Lưu ý & cảnh báo

- **Không bao giờ** dùng `git add -f` để ép thêm file AI vào repo chính. Hook chỉ là lớp phòng vệ cuối; lớp chính là `.gitignore`.
- File `.tlp`, `bastion_*` trong `~/.ssh` là cấu hình hạ tầng khác, không liên quan tới setup này.
- Mỗi public key chỉ gắn được vào **1 tài khoản GitHub**. Nếu key đã thuộc tài khoản khác, phải tạo keypair MỚI cho hainn1 (như mục 4).
- Tài liệu này (và cả thư mục `documents/`) **tuyệt đối không** được đưa vào repo chính của KH.
- Nếu sau này thêm tool AI mới sinh file ở vị trí khác, nhớ bổ sung vào `.gitignore` repo chính và vào denylist của `documents/.githooks/pre-commit`.
