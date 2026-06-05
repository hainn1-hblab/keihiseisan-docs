# 📊 Hướng dẫn Setup & Sử dụng GitHub Action Báo cáo Line of Code (LOC)

Tài liệu này hướng dẫn bạn cách thiết lập và sử dụng hệ thống tự động tính toán số dòng code thay đổi (Line of Code - LOC) trong các Pull Request (PR) trên GitHub.

Hệ thống này được chuyển đổi tương đương từ luồng công việc của GitLab CI (`.gitlab/ci/pr_loc.yml`), giúp duy trì quy trình làm việc đồng bộ khi chuyển đổi giữa GitLab và GitHub.

---

## 🚀 Tính năng nổi bật
* **Tự động hóa hoàn toàn**: Kích hoạt mỗi khi một Pull Request được **mở**, **cập nhật code mới (push thêm commit)**, hoặc **mở lại**.
* **Báo cáo chi tiết**: Hiển thị bảng thống kê trực quan số dòng code **Thêm (+)**, **Sửa (~)**, **Xóa (-)** và **Tổng ròng** của từng thành viên đóng góp.
* **Tự động dọn dẹp**: Xóa các comment báo cáo LOC cũ của chính nó trước đó khi có code mới được đẩy lên, giúp PR luôn gọn gàng và dễ theo dõi.
* **Bảo mật & Tối ưu**: Sử dụng trực tiếp GitHub CLI (`gh`) và token mặc định (`GITHUB_TOKEN`), không cần cài đặt thêm bên thứ ba.

---

## 🛠️ Hướng dẫn Setup

### Bước 1: Kiểm tra File tính toán LOC
Đảm bảo file script `calc_loc.sh` đang nằm ở thư mục gốc của dự án. File này chứa logic phân tích Git Log và xuất ra bảng định dạng Markdown.
*(Workflow GitHub Actions đã được tích hợp sẵn lệnh `chmod +x ./calc_loc.sh` để cấp quyền chạy).*

### Bước 2: Tạo File Workflow
Chúng tôi đã tạo sẵn file cấu hình GitHub Actions tại đường dẫn sau trong dự án của bạn:
📂 `.github/workflows/pr_loc.yml`

Nội dung cấu hình chi tiết của Workflow:
```yaml
name: Pull Request Line of Code (LOC) Report

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  pull-requests: write
  contents: read

jobs:
  pr_loc:
    name: Calculate LOC
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0 # Lấy toàn bộ lịch sử commit để so sánh chính xác

      - name: Fetch target branch
        run: |
          git fetch origin ${{ github.event.pull_request.base.ref }}

      - name: Calculate LOC and Prepare Comment
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          echo "Calculating LOC and preparing comment..."
          
          # Cấp quyền chạy script
          chmod +x ./calc_loc.sh
          
          # Thực thi script tính toán LOC
          OUTPUT=$(./calc_loc.sh "origin/${{ github.event.pull_request.base.ref }}")
          
          COMMENT_MARKER="<!-- PR_LOC_COMMENT_MARKER -->"
          
          # Ghi nội dung comment vào file tạm
          echo "$COMMENT_MARKER" > pr_loc_comment.md
          echo "### 📊 Báo cáo Line of Code (LOC)" >> pr_loc_comment.md
          echo "" >> pr_loc_comment.md
          echo "$OUTPUT" >> pr_loc_comment.md
          
          echo "Finding old LOC comments..."
          # Lấy danh sách comment trên PR hiện tại
          COMMENTS=$(gh api repos/${{ github.repository }}/issues/${{ github.event.pull_request.number }}/comments --paginate)
          
          # Lọc ra các comment ID có chứa marker của chúng ta
          COMMENT_IDS=$(echo "$COMMENTS" | jq -r ".[] | select(.body | contains(\"$COMMENT_MARKER\")) | .id")
          
          # Xóa các comment LOC cũ để tránh loãng PR
          for COMMENT_ID in $COMMENT_IDS; do
            if [ "$COMMENT_ID" != "null" ] && [ -n "$COMMENT_ID" ]; then
              echo "Deleting old comment ID: $COMMENT_ID"
              gh api -X DELETE repos/${{ github.repository }}/issues/comments/$COMMENT_ID
            fi
          done
          
          echo "Creating new LOC comment..."
          # Đăng comment mới lên PR
          gh pr comment ${{ github.event.pull_request.number }} --body-file pr_loc_comment.md
```

### Bước 3: Cấu hình Quyền hạn trên GitHub (Rất quan trọng ⚠️)
Để GitHub Actions có quyền viết bình luận (Write comments) vào Pull Request, bạn cần cấu hình trên Repository GitHub của mình:

1. Truy cập vào kho chứa (Repository) trên trang web GitHub.
2. Chọn **Settings** (Cài đặt) -> Cột bên trái chọn **Actions** -> Chọn **General**.
3. Cuộn xuống phần **Workflow permissions**.
4. Chọn **Read and write permissions** (như hình minh họa bên dưới).
5. Nhấn **Save** để lưu lại.

> [!NOTE]
> Khai báo `permissions: pull-requests: write` đã được cấu hình trực tiếp trong file `.github/workflows/pr_loc.yml`, tuy nhiên cài đặt tổng thể của Repository vẫn cần cho phép quyền Write để hoạt động trơn tru.

---

## 📖 Hướng dẫn Sử dụng

Quy trình hoạt động hoàn toàn tự động, bạn chỉ cần làm theo các bước sau để kiểm tra:

1. **Tạo nhánh mới và phát triển**:
   ```bash
   git checkout -b feature/awesome-feature
   # Thực hiện chỉnh sửa code...
   git add .
   git commit -m "feat: add awesome feature"
   ```
2. **Push nhánh lên GitHub**:
   ```bash
   git push origin feature/awesome-feature
   ```
3. **Mở Pull Request**:
   * Tạo một PR từ nhánh `feature/awesome-feature` vào nhánh đích (ví dụ: `develop` hoặc `main`).
4. **Theo dõi kết quả**:
   * GitHub Actions sẽ tự động kích hoạt job **Calculate LOC**.
   * Sau khi hoàn thành (thường mất 10-15 giây), một bình luận sẽ xuất hiện ở cuối PR với nội dung dạng:

| Thành viên | Thêm (+) | Sửa (~) | Xóa (-) | Tổng ròng |
|---|---|---|---|---|
| Nguyen Van A | 120 | 15 | 5 | 140 |
| Tran Van B | 45 | 0 | 12 | 57 |
| **TỔNG CỘNG** | **165** | **15** | **17** | **197** |

5. **Đẩy thêm commit mới**:
   * Nếu bạn tiếp tục sửa code và push lên, Action sẽ tự động chạy lại, xóa comment LOC cũ đi và đăng một comment LOC mới phản ánh chính xác trạng thái hiện tại.

---

## 🔍 Khắc phục Sự cố (Troubleshooting)

* **Lỗi: `Resource not accessible by integration` khi đăng comment**
  * *Nguyên nhân*: Bạn chưa cấp quyền ghi cho workflow.
  * *Khắc phục*: Thực hiện lại **Bước 3** trong hướng dẫn Setup để chọn "Read and write permissions".
* **Lỗi: `Lỗi: Branch 'origin/xxx' không tồn tại.`**
  * *Nguyên nhân*: Nhánh đích của Pull Request chưa được fetch đầy đủ về runner.
  * *Khắc phục*: Workflow đã có bước `git fetch origin ${{ github.event.pull_request.base.ref }}` để đảm bảo nhánh đích luôn được đồng bộ.
