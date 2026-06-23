#!/usr/bin/env node

const path = require('path');
const fs = require('fs');
const { spawnSync } = require('child_process');

// Hiển thị hướng dẫn sử dụng nhanh
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  console.log(`
🐈 Kitty Enterprise Installer CLI
=================================
Lệnh này khởi chạy trình cài đặt tự động cho tác tử private Kitty.

Cách hoạt động:
  1. Kiểm tra môi trường hệ thống (git, ssh, ssh-keygen).
  2. Tạo SSH Key riêng biệt phục vụ cho việc Deploy trên GitHub nếu chưa tồn tại.
  3. Hướng dẫn liên kết Deploy Key read-only.
  4. Clone/Cập nhật mã nguồn private về thư mục đích.
  5. Chạy kịch bản cài đặt chính của Kitty.

Các tùy chọn biến môi trường có sẵn:
  KITTY_ENTERPRISE_REPO_URL    URL SSH của repo private (Mặc định: git@github.com:cuongvu300582-rgb/Kitty.git)
  KITTY_ENTERPRISE_TARGET_DIR  Thư mục đích cài đặt (Mặc định: ~/Kitty)
  KITTY_ENTERPRISE_KEY_PATH    Đường dẫn SSH Key (Mặc định: ~/.ssh/id_ed25519_kitty_enterprise)
  KITTY_ENTERPRISE_SKIP_SETUP  Đặt bằng 1 để chỉ clone, bỏ qua chạy script setup chính

Cách gỡ cài đặt gói CLI này:
  npm uninstall -g kitty-enterprise
  `);
  process.exit(0);
}

const isWindows = process.platform === 'win32';
let scriptPath = '';
let command = '';
let args = [];

if (isWindows) {
  scriptPath = path.resolve(__dirname, '..', 'scripts', 'bootstrap-ssh-install.ps1');
  command = 'powershell.exe';
  args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath];
} else {
  scriptPath = path.resolve(__dirname, '..', 'scripts', 'bootstrap-ssh-install.sh');
  command = 'bash';
  args = [scriptPath];
}

// Kiểm tra xem file script có thực sự tồn tại trong package không
if (!fs.existsSync(scriptPath)) {
  console.error(`[LỖI] Không tìm thấy kịch bản khởi dựng tại: ${scriptPath}`);
  console.error('Vui lòng kiểm tra lại cấu trúc gói cài đặt.');
  process.exit(1);
}

console.log(`[Kitty Bootstrap] Đang khởi chạy kịch bản cài đặt trên nền tảng: ${process.platform}...`);

// Chạy script con và kế thừa toàn bộ luồng nhập xuất (stdio) để tương tác
const child = spawnSync(command, args, { stdio: 'inherit' });

if (child.error) {
  console.error(`\n[LỖI] Không thể khởi chạy tiến trình con (${command}):`, child.error.message);
  if (isWindows) {
    console.error('Vui lòng đảm bảo PowerShell (powershell.exe) đã được cài đặt và có trong PATH.');
  } else {
    console.error('Vui lòng đảm bảo Bash shell (bash) đã được cài đặt và có trong PATH.');
  }
  process.exit(1);
}

// Chuyển tiếp exit code từ tiến trình con về tiến trình hiện tại
process.exit(child.status !== null ? child.status : 1);
