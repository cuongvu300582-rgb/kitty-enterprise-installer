#!/bin/bash
# ============================================================================
# Kitty Enterprise Agent SSH Bootstrap Installer (Unix/macOS)
# ============================================================================

set -Eeuo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

printf "\n"
printf "${CYAN}🐈 Kitty Enterprise SSH Installer${NC}\n"
printf "==========================================\n"

# Biến mặc định
DEFAULT_REPO="git@github.com:cuongvu300582-rgb/Kitty.git"
DEFAULT_TARGET_DIR="$HOME/Kitty"
DEFAULT_KEY_PATH="$HOME/.ssh/id_ed25519_kitty_enterprise"

# Sử dụng biến môi trường hoặc mặc định
REPO_URL="${KITTY_ENTERPRISE_REPO_URL:-$DEFAULT_REPO}"
TARGET_DIR="${KITTY_ENTERPRISE_TARGET_DIR:-$DEFAULT_TARGET_DIR}"
KEY_PATH="${KITTY_ENTERPRISE_KEY_PATH:-$DEFAULT_KEY_PATH}"
SKIP_SETUP="${KITTY_ENTERPRISE_SKIP_SETUP:-}"

# --- 1. Kiểm tra Tiền Điều Kiện ------------------------------------------------
printf "${CYAN}→${NC} Đang kiểm tra công cụ hệ thống...\n"
MISSING_TOOLS=0

if ! command -v git &>/dev/null; then
    printf "${RED}✗ Lỗi: Chưa cài đặt Git hoặc Git chưa được cấu hình trong PATH.${NC}\n"
    printf "  Vui lòng tải Git từ https://git-scm.com/downloads\n"
    MISSING_TOOLS=1
fi

if ! command -v ssh &>/dev/null; then
    printf "${RED}✗ Lỗi: Chưa cài đặt OpenSSH Client (ssh).${NC}\n"
    MISSING_TOOLS=1
fi

if ! command -v ssh-keygen &>/dev/null; then
    printf "${RED}✗ Lỗi: Chưa cài đặt công cụ ssh-keygen.${NC}\n"
    MISSING_TOOLS=1
fi

if [ "$MISSING_TOOLS" -ne 0 ]; then
    printf "${RED}Vui lòng cài đặt các công cụ thiếu phía trên và thử lại.${NC}\n"
    exit 1
fi
printf "${GREEN}✓ Các công cụ hệ thống hợp lệ.${NC}\n"

# --- 2. Tạo SSH Key Riêng Biệt ------------------------------------------------
PUBLIC_KEY="${KEY_PATH}.pub"

if [ ! -f "$KEY_PATH" ]; then
    printf "${CYAN}→${NC} Đang khởi tạo SSH Key riêng biệt...\n"
    mkdir -p "$(dirname "$KEY_PATH")"
    chmod 700 "$(dirname "$KEY_PATH")"
    
    # Tạo SSH key ed25519 không mật khẩu bảo vệ
    ssh-keygen -t ed25519 -C "kitty-enterprise-bootstrap" -N "" -f "$KEY_PATH"
    chmod 600 "$KEY_PATH"
    printf "${GREEN}✓ Đã tạo thành công SSH Key tại: %s${NC}\n" "$KEY_PATH"
else
    printf "${GREEN}✓ Đã tìm thấy SSH Key hiện có tại: %s${NC}\n" "$KEY_PATH"
fi

# --- 3. Hướng dẫn Deploy Key trên GitHub --------------------------------------
printf "\n"
printf "${YELLOW}========================================================================${NC}\n"
printf "${YELLOW}KHÓA SSH PUBLIC KEY CỦA BẠN:${NC}\n"
printf "${GREEN}%s${NC}\n" "$(cat "$PUBLIC_KEY")"
printf "${YELLOW}========================================================================${NC}\n"
printf "\n"
printf "${CYAN}Vui lòng sao chép khóa SSH Public Key trên và thêm vào GitHub:${NC}\n"
printf "  1. Truy cập vào cài đặt Deploy Keys của Repository private.\n"
printf "  2. Nhấp chọn ${GREEN}'Add deploy key'${NC}.\n"
printf "  3. Đặt tên gợi nhớ (ví dụ: 'Kitty Enterprise Installer').\n"
printf "  4. Dán khóa vào ô Key và nhấn ${GREEN}'Add key'${NC} (KHÔNG cần tích chọn quyền Write access).\n"
printf "\n"

# --- 4. Xác Thực Kết Nối Với GitHub -----------------------------------------
while true; do
    if ! read -p "Sau khi đã thêm key vào GitHub, nhấn [ENTER] để tiếp tục..." -r; then
        printf "\n${YELLOW}Đã đóng đầu vào. Đang thoát trình cài đặt.${NC}\n"
        exit 0
    fi
    
    printf "${CYAN}→${NC} Đang kiểm tra quyền truy cập kho lưu trữ GitHub...\n"
    
    set +e
    # Sử dụng git ls-remote để kiểm tra quyền đọc kho lưu trữ
    VERIFY_CMD=$(GIT_SSH_COMMAND="ssh -i \"$KEY_PATH\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" git ls-remote "$REPO_URL" 2>&1)
    VERIFY_STATUS=$?
    set -e
    
    if [ "$VERIFY_STATUS" -eq 0 ]; then
        printf "${GREEN}✓ Kết nối thành công! Đã xác thực quyền đọc kho lưu trữ Kitty.${NC}\n"
        break
    else
        printf "${RED}✗ Xác thực thất bại.${NC}\n"
        printf "Phản hồi lỗi từ Git: \n%s\n" "$VERIFY_CMD"
        printf "${YELLOW}Vui lòng kiểm tra lại xem bạn đã thêm Deploy Key đúng kho lưu trữ chưa và thử lại.${NC}\n"
        printf "\n"
    fi
done

# --- 5. Clone và Setup Kho Lưu Trữ ------------------------------------------
printf "\n"
printf "${CYAN}→${NC} Đang chuẩn bị tải mã nguồn về: %s...\n" "$TARGET_DIR"

CLONE_REQUIRED=1

if [ -d "$TARGET_DIR" ]; then
    printf "${YELLOW}⚠ Thư mục '%s' đã tồn tại.${NC}\n" "$TARGET_DIR"
    
    # Kiểm tra xem có phải là git repository đúng không
    if [ -d "$TARGET_DIR/.git" ]; then
        set +e
        CURRENT_REMOTE=$(cd "$TARGET_DIR" && git remote get-url origin 2>/dev/null)
        set -e
        
        if [ "$CURRENT_REMOTE" = "$REPO_URL" ]; then
            printf "Thư mục hiện tại là repository hợp lệ.\n"
            printf "Bạn muốn thực hiện thao tác nào tiếp theo?\n"
            printf "  1) Cập nhật mã nguồn mới (git pull)\n"
            printf "  2) Giữ nguyên thư mục hiện tại và chạy tiếp setup\n"
            printf "  3) Xóa đi và clone lại toàn bộ (Re-clone)\n"
            printf "  4) Hủy bỏ cài đặt\n"
            
            read -p "Vui lòng nhập lựa chọn của bạn [1-4]: " -r OPTION
            case "$OPTION" in
                1)
                    printf "${CYAN}→${NC} Đang cập nhật mã nguồn...\n"
                    (cd "$TARGET_DIR" && GIT_SSH_COMMAND="ssh -i \"$KEY_PATH\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" git pull)
                    CLONE_REQUIRED=0
                    ;;
                2)
                    printf "${GREEN}✓ Giữ nguyên thư mục.${NC}\n"
                    CLONE_REQUIRED=0
                    ;;
                3)
                    printf "${CYAN}→${NC} Đang xóa thư mục cũ để clone lại...\n"
                    rm -rf "$TARGET_DIR"
                    CLONE_REQUIRED=1
                    ;;
                *)
                    printf "Đã hủy bỏ cài đặt.\n"
                    exit 0
                    ;;
            esac
        else
            printf "${RED}⚠ Thư mục đã tồn tại nhưng trỏ tới remote Git khác: %s${NC}\n" "$CURRENT_REMOTE"
            read -p "Bạn có muốn xóa thư mục này và clone mới từ đầu không? [y/N]: " -r CONFIRM
            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
                rm -rf "$TARGET_DIR"
                CLONE_REQUIRED=1
            else
                printf "Đã hủy bỏ cài đặt.\n"
                exit 0
            fi
        fi
    else
        printf "${RED}⚠ Thư mục đã tồn tại nhưng không phải là một Git repository.${NC}\n"
        read -p "Bạn có muốn xóa thư mục này và clone mới từ đầu không? [y/N]: " -r CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            rm -rf "$TARGET_DIR"
            CLONE_REQUIRED=1
        else
            printf "Đã hủy bỏ cài đặt.\n"
            exit 0
        fi
    fi
fi

if [ "$CLONE_REQUIRED" -eq 1 ]; then
    printf "${CYAN}→${NC} Đang tiến hành clone mã nguồn...\n"
    GIT_SSH_COMMAND="ssh -i \"$KEY_PATH\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" git clone "$REPO_URL" "$TARGET_DIR"
    printf "${GREEN}✓ Clone mã nguồn thành công.${NC}\n"
fi

# Cấu hình SSH Command cục bộ cho repository
printf "${CYAN}→${NC} Đang cấu hình SSH Command cho repository...\n"
(cd "$TARGET_DIR" && git config core.sshCommand "ssh -i \"$KEY_PATH\" -o IdentitiesOnly=yes")
printf "${GREEN}✓ Đã cấu hình core.sshCommand cục bộ.${NC}\n"

# Chạy kịch bản cài đặt chính
if [ "$SKIP_SETUP" = "1" ]; then
    printf "\n"
    printf "${YELLOW}⚠ Biến KITTY_ENTERPRISE_SKIP_SETUP được bật. Bỏ qua chạy kịch bản setup chính.${NC}\n"
    printf "${GREEN}✓ Quy trình chuẩn bị mã nguồn hoàn tất.${NC}\n"
else
    printf "\n"
    printf "${CYAN}→${NC} Đang chuyển vào thư mục và khởi chạy setup-kitty.sh...\n"
    cd "$TARGET_DIR"
    if [ -f "setup-kitty.sh" ]; then
        chmod +x setup-kitty.sh
        ./setup-kitty.sh
    else
        printf "${RED}✗ Lỗi: Không tìm thấy kịch bản setup-kitty.sh trong kho lưu trữ.${NC}\n"
        exit 1
    fi
fi
