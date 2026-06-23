# Kitty Enterprise Installer (`kitty-enterprise`)

Trình khởi dựng và cài đặt tự động tác tử private Kitty trên các hệ thống Linux, macOS và Windows.

> [!IMPORTANT]
> Gói npm công khai này hoàn toàn **không** chứa mã nguồn private, SSH private key, token hay bất kỳ thông tin nhạy cảm nào khác của Kitty. Nó chỉ đóng vai trò là một trình khởi dựng (bootstrapper) để hướng dẫn người dùng kết nối an toàn với GitHub và cài đặt dự án.

---

## Tính năng
- Tự động kiểm tra điều kiện tiên quyết (`git`, `ssh`, `ssh-keygen`).
- Tạo SSH key riêng biệt (`~/.ssh/id_ed25519_kitty_enterprise`) để tránh ảnh hưởng đến các cấu hình SSH cá nhân khác.
- Hướng dẫn thiết lập GitHub Deploy Key từng bước.
- Kiểm tra quyền truy cập repository private thông qua SSH một cách an toàn.
- Tải mã nguồn private từ kho lưu trữ về và khởi chạy chương trình cài đặt chính phù hợp với hệ điều hành đang sử dụng.

---

## Yêu cầu hệ thống trước khi cài đặt

Đảm bảo hệ thống của bạn đã cài đặt các công cụ sau và chúng có sẵn trong biến môi trường `PATH`:
- **Node.js**: Phiên bản `>= 16.x`
- **Git**: [Tải về tại đây](https://git-scm.com/downloads)
- **OpenSSH Client**:
  - Trên Windows: Đi kèm sẵn khi cài đặt Git for Windows, hoặc có thể sử dụng OpenSSH Client tích hợp sẵn của Windows.
  - Trên Linux/macOS: Đã được cài đặt sẵn mặc định ở hầu hết các bản phân phối.

---

## Hướng dẫn sử dụng

### 1. Cài đặt gói (Installation)

Bạn có thể cài đặt toàn cục (Global) hoặc chạy trực tiếp mà không cần cài đặt:

* **Trên Windows:**
  ```bash
  npm install -g kitty-enterprise
  ```

* **Trên Linux / macOS (nếu gặp lỗi phân quyền EACCES):**
  Sử dụng `sudo` để có quyền cài đặt vào thư mục hệ thống:
  ```bash
  sudo npm install -g kitty-enterprise
  ```
  *(Lưu ý: Gói cài đặt này hoàn toàn không chạy ngầm hay thực thi mã nguồn tự động khi cài đặt, nên việc chạy với `sudo` là an toàn).*

* **Hoặc chạy trực tiếp không cần cài đặt (Mọi hệ điều hành):**
  Bạn có thể bỏ qua bước cài đặt toàn cục và khởi chạy trực tiếp thông qua công cụ `npx` đi kèm sẵn với Node.js:
  ```bash
  npx kitty-enterprise
  ```

### 2. Chạy trình cài đặt
Sau khi cài đặt xong, chạy lệnh sau ở bất kỳ đâu trong terminal:
```bash
kitty-enterprise
```

### 3. Các bước chương trình sẽ thực hiện:
1. **Kiểm tra môi trường:** Phát hiện hệ điều hành hiện tại và các công cụ bắt buộc.
2. **Khởi tạo SSH Key:** Nếu chưa có, chương trình tạo khóa `~/.ssh/id_ed25519_kitty_enterprise`.
3. **Liên kết GitHub:** Chương trình sẽ in ra khóa công khai (Public Key). Hãy sao chép khóa này, truy cập vào phần quản lý Deploy Keys của repository và thêm khóa làm **Deploy Key** (chọn chế độ chỉ đọc - Read-only).
4. **Xác thực kết nối:** Bấm Enter để xác thực kết nối đến GitHub.
5. **Clone & Cài đặt:** Sau khi kết nối thành công, chương trình tải mã nguồn private về thư mục `~/Kitty` và tự động kích hoạt kịch bản cài đặt chính (`setup-kitty.sh` trên Unix hoặc `setup-kitty.ps1` trên Windows).

---

## Biến môi trường cấu hình (Dành cho Quản trị viên/Nhà phát triển)

Bạn có thể thay đổi hành vi mặc định của chương trình bằng cách định nghĩa trước các biến môi trường sau trước khi chạy lệnh:

- `KITTY_ENTERPRISE_REPO_URL`: URL SSH của repository đích (Mặc định: `git@github.com:cuongvu300582-rgb/Kitty.git`).
- `KITTY_ENTERPRISE_TARGET_DIR`: Đường dẫn thư mục đích để clone mã nguồn (Mặc định: `~/Kitty`).
- `KITTY_ENTERPRISE_KEY_PATH`: Đường dẫn lưu trữ SSH Key (Mặc định: `~/.ssh/id_ed25519_kitty_enterprise`).
- `KITTY_ENTERPRISE_SKIP_SETUP`: Đặt giá trị bằng `1` để chỉ thực hiện clone/cập nhật và bỏ qua bước tự động kích hoạt script setup chính (Dùng khi kiểm thử).

---

## Gỡ bỏ (Uninstall)

Để gỡ cài đặt gói CLI khỏi hệ thống:
```bash
npm uninstall -g kitty-enterprise
```

*Lưu ý:* Việc gỡ cài đặt gói npm này **không** tự động xóa thư mục dự án đã clone (`~/Kitty`) hay SSH key riêng biệt đã tạo (`~/.ssh/id_ed25519_kitty_enterprise`) trên thiết bị của bạn.
