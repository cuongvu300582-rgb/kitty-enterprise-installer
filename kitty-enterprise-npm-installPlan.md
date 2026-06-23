# Kế hoạch triển khai gói npm toàn cục `kitty-enterprise`

## Mục tiêu

Tạo một gói npm public tên `kitty-enterprise` để người dùng có thể cài và chạy:

```bash
npm install -g kitty-enterprise
kitty-enterprise
```

Gói npm này chỉ là bootstrapper. Nó không chứa mã nguồn private, token, SSH private key, hay secret của Kitty. Sau khi chạy lệnh `kitty-enterprise`, bootstrapper sẽ hướng dẫn người dùng tạo/thêm SSH Deploy Key vào GitHub, kiểm tra quyền truy cập repository private, clone mã nguồn về máy và chạy script cài đặt chính theo hệ điều hành.

## Quyết định sau review

- Sửa lỗi mã hóa tiếng Việt trong tài liệu để nội dung đọc được và dễ bảo trì.
- Không dùng `postinstall` hoặc lifecycle script của npm để clone/cài đặt tự động. Cài npm chỉ cài CLI; mọi thao tác mạng và thay đổi máy người dùng chỉ xảy ra khi họ chạy `kitty-enterprise`.
- Không đưa mã nguồn private vào package public. Dùng trường `files` trong `package.json` và kiểm tra bằng `npm pack --dry-run` trước khi publish.
- Không ghi đè SSH key mặc định `~/.ssh/id_ed25519`. Mặc định tạo key riêng `~/.ssh/id_ed25519_kitty_enterprise` để tránh ảnh hưởng key cá nhân hoặc cấu hình SSH sẵn có của người dùng.
- Không phụ thuộc vào `ssh-agent`, đặc biệt trên Windows nơi dịch vụ này có thể bị tắt và cần quyền Administrator. Các lệnh `git` sẽ dùng key riêng thông qua `GIT_SSH_COMMAND` và lưu `core.sshCommand` ở mức repository sau khi clone.
- Không chỉ dựa vào `ssh -T git@github.com` để xác minh. Với GitHub, lệnh này có thể trả exit code không trực quan dù xác thực thành công. Kiểm tra chính nên là `git ls-remote <repo>` với đúng SSH key cần dùng.
- Đồng bộ hành vi Bash và PowerShell: cùng biến cấu hình, cùng cách xử lý thiếu công cụ, thiếu quyền truy cập, thư mục đích đã tồn tại, lỗi clone và lỗi script cài đặt chính.

## Phạm vi

### Trong phạm vi

- Tạo package npm public `kitty-enterprise`.
- Tạo CLI Node.js global command `kitty-enterprise`.
- Tạo bootstrap script cho Linux/macOS bằng Bash.
- Tạo bootstrap script cho Windows bằng PowerShell.
- Kiểm tra điều kiện tiên quyết: `git`, `ssh`, `ssh-keygen`, `bash` trên Unix, PowerShell trên Windows.
- Tạo SSH key riêng nếu chưa có.
- Hướng dẫn người dùng thêm public key làm GitHub Deploy Key dạng read-only.
- Clone hoặc cập nhật repository private về `~/Kitty` theo lựa chọn của người dùng.
- Chạy script cài đặt chính trong repository vừa clone.

### Ngoài phạm vi

- Không tự động thêm Deploy Key bằng GitHub API.
- Không dùng GitHub PAT, npm token, hoặc bất kỳ secret nào trong package.
- Không tự động xóa dữ liệu cũ nếu người dùng chưa xác nhận.
- Không xử lý toàn bộ logic cài đặt sản phẩm Kitty trong package npm. Package này chỉ gọi script cài đặt chính có sẵn trong repository private.

## Cấu trúc package đề xuất

```text
kitty-enterprise-installer/
  package.json
  README.md
  bin/
    kitty-enterprise.js
  scripts/
    bootstrap-ssh-install.sh
    bootstrap-ssh-install.ps1
```

## Cấu hình `package.json`

`package.json` cần có các phần chính:

```json
{
  "name": "kitty-enterprise",
  "version": "0.1.0",
  "description": "Bootstrap installer for Kitty Enterprise",
  "bin": {
    "kitty-enterprise": "bin/kitty-enterprise.js"
  },
  "files": [
    "bin",
    "scripts",
    "README.md"
  ],
  "engines": {
    "node": ">=16"
  },
  "license": "UNLICENSED"
}
```

Ghi chú:

- Không cần thêm dependency nếu wrapper chỉ dùng module built-in của Node.js.
- Không thêm `postinstall`.
- `preferGlobal` không nên là yêu cầu bắt buộc; CLI global đã được thể hiện qua trường `bin` và README.
- Trước khi publish cần kiểm tra tên package trên npm. Nếu `kitty-enterprise` đã được dùng, cần đổi tên hoặc publish dưới scope phù hợp.

## CLI Node.js `bin/kitty-enterprise.js`

Yêu cầu triển khai:

- Có shebang `#!/usr/bin/env node`.
- Dùng `path`, `fs` và `child_process.spawnSync`.
- Xác định hệ điều hành bằng `process.platform`.
- Trên Windows, chạy:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-ssh-install.ps1
```

- Trên Linux/macOS, chạy:

```text
bash scripts/bootstrap-ssh-install.sh
```

- Gọi child process bằng mảng tham số, không ghép chuỗi shell command.
- Dùng `{ stdio: "inherit" }` để hỗ trợ prompt tương tác.
- Truyền tiếp exit code của script con về process chính.
- Kiểm tra file script tồn tại trước khi chạy và hiển thị lỗi rõ ràng nếu package bị đóng gói thiếu file.
- Có `--help` ngắn để người dùng biết lệnh này sẽ làm gì trước khi chạy cài đặt.

## Biến cấu hình chung

Cả Bash và PowerShell nên hỗ trợ các biến môi trường sau để dễ kiểm thử và triển khai nội bộ:

| Biến | Mặc định | Mục đích |
| --- | --- | --- |
| `KITTY_ENTERPRISE_REPO_URL` | `git@github.com:<org>/<private-repo>.git` | SSH URL của repository private cần clone. |
| `KITTY_ENTERPRISE_TARGET_DIR` | `~/Kitty` | Thư mục đích trên máy người dùng. |
| `KITTY_ENTERPRISE_KEY_PATH` | `~/.ssh/id_ed25519_kitty_enterprise` | SSH key riêng cho installer. |
| `KITTY_ENTERPRISE_SKIP_SETUP` | rỗng | Nếu đặt là `1`, chỉ clone/xác minh, không chạy setup chính. Hữu ích cho kiểm thử package. |

Trước khi triển khai thật cần thay placeholder `<org>/<private-repo>` bằng repository chính xác.

## Bootstrap flow chung

1. In phần giới thiệu ngắn: script sẽ tạo key nếu cần, yêu cầu người dùng thêm Deploy Key vào GitHub, clone repository private và chạy setup chính.
2. Kiểm tra công cụ bắt buộc:
   - `git`
   - `ssh`
   - `ssh-keygen`
   - `bash` trên Linux/macOS
   - PowerShell trên Windows
3. Tạo thư mục `~/.ssh` nếu chưa có và đặt quyền phù hợp trên Unix (`700` cho thư mục, `600` cho private key).
4. Nếu key riêng chưa tồn tại, tạo bằng:

```text
ssh-keygen -t ed25519 -C "kitty-enterprise-bootstrap" -f <key-path> -N ""
```

5. Hiển thị public key và hướng dẫn người dùng thêm vào GitHub repository dưới dạng Deploy Key read-only.
6. Chờ người dùng xác nhận đã thêm key.
7. Kiểm tra quyền truy cập bằng:

```text
GIT_SSH_COMMAND="ssh -i <key-path> -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" git ls-remote <repo-url>
```

8. Nếu kiểm tra thất bại, giải thích các nguyên nhân thường gặp:
   - Public key chưa được thêm vào Deploy Keys.
   - Deploy Key được thêm sai repository.
   - Repository URL sai.
   - Mạng hoặc firewall chặn SSH tới GitHub.
9. Xử lý thư mục đích:
   - Nếu chưa tồn tại: clone mới.
   - Nếu đã tồn tại và là git repository đúng remote: hỏi người dùng muốn cập nhật (`git pull`), dùng nguyên trạng, clone lại, hoặc hủy.
   - Nếu đã tồn tại nhưng không phải repository mong đợi: mặc định hủy, chỉ xóa khi người dùng xác nhận rõ.
10. Sau khi clone, cấu hình repository local:

```text
git config core.sshCommand "ssh -i <key-path> -o IdentitiesOnly=yes"
```

11. Chạy script cài đặt chính:
   - Windows: `setup-kitty.ps1`
   - Linux/macOS: script cài đặt tương ứng trong repository private
12. Trả exit code khác `0` nếu bất kỳ bước bắt buộc nào thất bại.

## Bash script `scripts/bootstrap-ssh-install.sh`

Yêu cầu:

- Dùng `set -Eeuo pipefail`.
- Tương thích Bash mặc định trên macOS, tránh phụ thuộc tính năng quá mới nếu không cần.
- Dùng `command -v` để kiểm tra công cụ.
- Quote tất cả biến đường dẫn.
- Không dùng `readlink -f` vì không có sẵn trên macOS mặc định.
- Dùng `printf` thay vì phụ thuộc hành vi khác nhau của `echo`.
- Không tự động xóa thư mục `~/Kitty`.
- Hiển thị hướng dẫn cài `git`/OpenSSH phù hợp nếu thiếu công cụ.

## PowerShell script `scripts/bootstrap-ssh-install.ps1`

Yêu cầu:

- Tương thích Windows PowerShell 5.1.
- Bắt đầu bằng `$ErrorActionPreference = 'Stop'`.
- Dùng `Get-Command` để kiểm tra `git`, `ssh`, `ssh-keygen`.
- Dùng `Join-Path`, `Test-Path`, `New-Item` thay vì ghép chuỗi đường dẫn thủ công.
- Chạy từ wrapper bằng `-NoProfile -ExecutionPolicy Bypass`.
- Không yêu cầu quyền Administrator.
- Không cố bật dịch vụ `ssh-agent`; dùng `GIT_SSH_COMMAND` để chỉ định key.
- Với mỗi lệnh native như `git` hoặc `ssh-keygen`, kiểm tra `$LASTEXITCODE` và dừng với thông báo rõ nếu lỗi.
- Hạn chế dùng ký tự hoặc cú pháp chỉ có trong PowerShell 7.

## README tối thiểu

README đi kèm package cần có:

- Mục đích của package.
- Lệnh cài đặt và chạy.
- Danh sách công cụ cần có trước khi chạy.
- Giải thích package public không chứa mã nguồn private.
- Hướng dẫn thêm Deploy Key read-only vào GitHub.
- Cách gỡ package:

```bash
npm uninstall -g kitty-enterprise
```

- Ghi chú rằng uninstall npm package không tự xóa repository đã clone hoặc SSH key đã tạo trên máy người dùng.

## Kế hoạch kiểm thử

### Kiểm thử package

- Chạy `node --check bin/kitty-enterprise.js`.
- Chạy `npm pack --dry-run` và xác nhận tarball chỉ có `bin`, `scripts`, `README.md`, `package.json`.
- Cài local bằng `npm install -g .`.
- Chạy `kitty-enterprise --help`.
- Gỡ local bằng `npm uninstall -g kitty-enterprise`.

### Kiểm thử Bash

- Chạy `bash -n scripts/bootstrap-ssh-install.sh`.
- Nếu có `shellcheck`, chạy `shellcheck scripts/bootstrap-ssh-install.sh`.
- Kiểm thử trên Linux và macOS:
  - Thiếu `git`.
  - Thiếu `ssh-keygen`.
  - Chưa có SSH key riêng.
  - Đã có SSH key riêng.
  - Deploy Key chưa được thêm vào GitHub.
  - Repository đã tồn tại đúng remote.
  - Thư mục đích tồn tại nhưng không phải repository đúng.

### Kiểm thử PowerShell

- Chạy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-ssh-install.ps1
```

- Nếu có PSScriptAnalyzer, chạy phân tích static cho script.
- Kiểm thử trên Windows:
  - ExecutionPolicy mặc định bị hạn chế.
  - Không có quyền Administrator.
  - Git for Windows đã cài.
  - OpenSSH Client thiếu hoặc không có trong `PATH`.
  - Đường dẫn người dùng có khoảng trắng.
  - Repository đã tồn tại.

### Kiểm thử end-to-end

- Publish thử bằng package tarball local:

```bash
npm pack
npm install -g ./kitty-enterprise-0.1.0.tgz
kitty-enterprise
```

- Kiểm thử với biến `KITTY_ENTERPRISE_SKIP_SETUP=1` để xác minh clone mà chưa chạy setup chính.
- Kiểm thử một lượt đầy đủ trên:
  - Windows 10/11.
  - Ubuntu hoặc Debian server.
  - macOS.

## Quy trình publish

1. Cập nhật version trong `package.json`.
2. Chạy toàn bộ kiểm thử local.
3. Chạy `npm pack --dry-run` và kiểm tra file list.
4. Kiểm tra tên package trên npm:

```bash
npm view kitty-enterprise
```

5. Đăng nhập npm bằng tài khoản có 2FA.
6. Publish:

```bash
npm publish --access public
```

7. Xác minh sau publish:

```bash
npm view kitty-enterprise version
npm install -g kitty-enterprise
kitty-enterprise --help
```

## Tiêu chí hoàn thành

- `npm install -g kitty-enterprise` cài CLI thành công trên Windows, Linux và macOS.
- Lệnh `kitty-enterprise` chạy đúng bootstrap script theo hệ điều hành.
- Package public không chứa mã nguồn private hoặc secret.
- Không có tác dụng phụ trong quá trình npm install.
- Người dùng nhận được hướng dẫn rõ khi thiếu công cụ hoặc chưa cấp Deploy Key.
- Installer không ghi đè SSH key mặc định và không xóa thư mục hiện có nếu chưa xác nhận.
- Clone repository private thành công bằng Deploy Key read-only.
- Script cài đặt chính được gọi và exit code được truyền đúng về CLI.

## Việc cần xác nhận trước khi triển khai

- SSH URL chính xác của repository private.
- Tên script cài đặt chính trong repository private cho từng hệ điều hành.
- Package name `kitty-enterprise` còn khả dụng trên npm hay cần dùng scoped package.
- Có bắt buộc phải dùng key mặc định `id_ed25519` hay chấp nhận key riêng `id_ed25519_kitty_enterprise`. Khuyến nghị hiện tại là dùng key riêng.
