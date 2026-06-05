#!/bin/bash

# Nhận tên branch đích từ tham số truyền vào, mặc định là "develop"
TARGET_BRANCH="${1:-develop}"

# Kiểm tra xem có đang ở trong một git repository không
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Lỗi: Thư mục hiện tại không phải là một git repository."
    exit 1
fi

# Kiểm tra xem branch đích có tồn tại không
if ! git rev-parse --verify "$TARGET_BRANCH" > /dev/null 2>&1; then
    # Thử tìm origin/$TARGET_BRANCH nếu nhánh local không tồn tại
    if git rev-parse --verify "origin/$TARGET_BRANCH" > /dev/null 2>&1; then
        TARGET_BRANCH="origin/$TARGET_BRANCH"
    else
        echo "Lỗi: Branch '$TARGET_BRANCH' không tồn tại."
        exit 1
    fi
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "Line of Code (LOC) giữa '$TARGET_BRANCH' và '$CURRENT_BRANCH' (hiện tại)..."
echo ""

# Dùng git log để lấy các commit từ TARGET_BRANCH đến HEAD
# --numstat xuất ra số dòng thêm/xóa
# --format='commit_author:%an' in ra tên tác giả của commit
git log "${TARGET_BRANCH}..HEAD" --numstat --format='commit_author:%an' --no-merges | awk '
/^commit_author:/ {
    # Lấy tên tác giả (bỏ qua chuỗi "commit_author:")
    author = substr($0, 15)
    next
}
# Bỏ qua các file binary (numstat hiển thị dấu "-")
NF == 3 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
    # Ước lượng số dòng "sửa": là phần giao (nhỏ nhất) giữa số dòng thêm và xóa
    # Khi sửa 1 dòng, Git ghi nhận là 1 dòng xóa và 1 dòng thêm.
    modified_lines = ($1 < $2) ? $1 : $2
    
    modified[author] += modified_lines
    added[author] += ($1 - modified_lines)
    deleted[author] += ($2 - modified_lines)
}
END {
    print "| Thành viên | Thêm (+) | Sửa (~) | Xóa (-) | Tổng ròng |"
    print "|---|---|---|---|---|"
    total_added = 0
    total_modified = 0
    total_deleted = 0
    for (a in added) {
        total_net = added[a] + modified[a] + deleted[a]
        printf "| %s | %d | %d | %d | %d |\n", a, added[a], modified[a], deleted[a], total_net
        total_added += added[a]
        total_modified += modified[a]
        total_deleted += deleted[a]
    }
    printf "| %s | %d | %d | %d | %d |\n", "**TỔNG CỘNG**", total_added, total_modified, total_deleted, total_added + total_modified + total_deleted
}
' | column -t -s '|' -o '|' | sed '2s/ /-/g'
