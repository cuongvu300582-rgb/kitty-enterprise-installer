# ============================================================================
# Kitty Enterprise Agent SSH Bootstrap Installer (Windows PowerShell)
# ============================================================================

$ErrorActionPreference = 'Stop'

# Cấu hình mã hóa tiếng Việt cho console (UTF-8)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "(Kitty) Kitty Enterprise SSH Installer" -ForegroundColor Cyan
Write-Host "=========================================="

# Hàm chuyển đổi đường dẫn tương đối hoặc dấu ngã (~) thành đường dẫn tuyệt đối
function Resolve-AbsolutePath {
    param([string]$path)
    if ($path.StartsWith("~/") -or $path.StartsWith("~\")) {
        $path = Join-Path $HOME $path.Substring(2)
    } elseif ($path -eq "~") {
        $path = $HOME
    }
    return [System.IO.Path]::GetFullPath($path)
}

# Biến mặc định
$defaultRepo = "git@github.com:cuongvu300582-rgb/Kitty.git"
$defaultTargetDir = Join-Path $HOME "Kitty"
$defaultKeyPath = Join-Path (Join-Path $HOME ".ssh") "id_ed25519_kitty_enterprise"

# Sử dụng biến môi trường hoặc mặc định
$repoUrl = $defaultRepo
if ($env:KITTY_ENTERPRISE_REPO_URL) {
    $repoUrl = $env:KITTY_ENTERPRISE_REPO_URL
}

$rawTargetDir = $defaultTargetDir
if ($env:KITTY_ENTERPRISE_TARGET_DIR) {
    $rawTargetDir = $env:KITTY_ENTERPRISE_TARGET_DIR
}
$targetDir = Resolve-AbsolutePath $rawTargetDir

$rawKeyPath = $defaultKeyPath
if ($env:KITTY_ENTERPRISE_KEY_PATH) {
    $rawKeyPath = $env:KITTY_ENTERPRISE_KEY_PATH
}
$keyPath = Resolve-AbsolutePath $rawKeyPath

$skipSetup = $env:KITTY_ENTERPRISE_SKIP_SETUP

# --- 1. Kiểm tra Tiền Điều Kiện ------------------------------------------------
Write-Host "-> Dang kiem tra cong cu he thong..." -ForegroundColor Cyan
$missingTools = $false

if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[LOI] Chua cai dat Git hoac Git chua duoc cau hinh trong PATH." -ForegroundColor Red
    Write-Host "  Vui long tai Git tu https://git-scm.com/downloads" -ForegroundColor Yellow
    $missingTools = $true
}

if (!(Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host "[LOI] Chua cai dat OpenSSH Client (ssh)." -ForegroundColor Red
    $missingTools = $true
}

if (!(Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
    Write-Host "[LOI] Chua cai dat cong cu ssh-keygen." -ForegroundColor Red
    $missingTools = $true
}

if ($missingTools) {
    Write-Host "Vui long cai dat cac cong cu thieu phia tren va thu lai." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Cac cong cu he thong hop le." -ForegroundColor Green

# --- 2. Tạo SSH Key Riêng Biệt ------------------------------------------------
$pubKeyPath = "$keyPath.pub"

if (!(Test-Path $keyPath)) {
    Write-Host "-> Dang khoi tao SSH Key rieng biet..." -ForegroundColor Cyan
    $keyDir = Split-Path $keyPath -Parent
    if (!(Test-Path $keyDir)) {
        New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
    }
    
    # Chạy lệnh tạo SSH key ed25519
    & ssh-keygen.exe -t ed25519 -C "kitty-enterprise-bootstrap" -N '""' -f "$keyPath"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Khong the tao SSH Key. Vui long thu lai."
        exit 1
    }
    Write-Host "[OK] Da tao thanh cong SSH Key tai: $keyPath" -ForegroundColor Green
} else {
    Write-Host "[OK] Da tim thay SSH Key hien co tai: $keyPath" -ForegroundColor Green
}

# --- 3. Hướng dẫn Deploy Key trên GitHub --------------------------------------
$pubKeyContent = Get-Content -Raw -Path $pubKeyPath
Write-Host ""
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host "KHOA SSH PUBLIC KEY CUA BAN:" -ForegroundColor Yellow
Write-Host $pubKeyContent.Trim() -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Vui long sao chep khoa SSH Public Key tren va them vao GitHub:" -ForegroundColor Cyan
Write-Host "  1. Truy cap vao cai dat Deploy Keys cua Repository private."
Write-Host "  2. Nhap chon 'Add deploy key'."
Write-Host "  3. Dat ten goi nho (vi du: 'Kitty Enterprise Installer')."
Write-Host "  4. Dan khoa vao o Key va nhan 'Add key' (KHONG can tich chon quyen Write access)."
Write-Host ""

# --- 4. Xác Thực Kết Nối Với GitHub -----------------------------------------
while ($true) {
    Write-Host "Sau khi da them key vao GitHub, nhan [ENTER] de tiep tuc..." -ForegroundColor Yellow -NoNewline
    $null = Read-Host
    
    Write-Host "-> Dang kiem tra quyen truy cap kho luu tru GitHub..." -ForegroundColor Cyan
    
    # Thiết lập biến môi trường tạm thời cho git clone sử dụng key riêng
    $env:GIT_SSH_COMMAND = "ssh -i `"$keyPath`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    
    # Tạm thời tắt dừng khi gặp lỗi để bắt lỗi stderr từ git
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    
    # Chạy lệnh git ls-remote để kiểm tra quyền đọc
    $verifyOutput = & git.exe ls-remote $repoUrl 2>&1
    $exitCode = $LASTEXITCODE
    
    # Khôi phục cấu hình lỗi và dọn dẹp biến môi trường
    $ErrorActionPreference = $oldErrorAction
    Remove-Item env:GIT_SSH_COMMAND
    
    if ($exitCode -eq 0) {
        Write-Host "[OK] Ket noi thanh cong! Da xac thuc quyen doc kho luu tru Kitty." -ForegroundColor Green
        break
    } else {
        Write-Host "[LOI] Xac thuc that bai." -ForegroundColor Red
        Write-Host "Phan hoi loi tu Git:" -ForegroundColor Red
        Write-Host $verifyOutput -ForegroundColor Red
        Write-Host "Vui long kiem tra lai xem ban da them Deploy Key dung kho luu tru chua va thu lai." -ForegroundColor Yellow
        Write-Host ""
    }
}

# --- 5. Clone và Setup Kho Lưu Trữ ------------------------------------------
Write-Host ""
Write-Host "-> Dang chuan bi tai ma nguon ve: $targetDir..." -ForegroundColor Cyan

$cloneRequired = $true

if (Test-Path $targetDir) {
    Write-Host "[WARN] Thu muc '$targetDir' da ton tai." -ForegroundColor Yellow
    
    if (Test-Path (Join-Path $targetDir ".git")) {
        Push-Location $targetDir
        try {
            $currentRemote = & git.exe remote get-url origin 2>$null
            $currentRemote = $currentRemote.Trim()
        } catch {
            $currentRemote = ""
        }
        Pop-Location
        
        if ($currentRemote -eq $repoUrl) {
            Write-Host "Thu muc hien tai la repository hop le."
            Write-Host "Ban muon thuc hean thao tac nao tiep theo?"
            Write-Host "  1) Cap nhat ma nguon moi (git pull)"
            Write-Host "  2) Giu nguyen thu muc hien tai va chay tiep setup"
            Write-Host "  3) Xoa di va clone lai toan bo (Re-clone)"
            Write-Host "  4) Huy bo cai dat"
            
            $option = Read-Host "Vui long nhap lua chon cua ban [1-4]"
            switch ($option.Trim()) {
                "1" {
                    Write-Host "-> Dang cap nhat ma nguon..." -ForegroundColor Cyan
                    Push-Location $targetDir
                    $env:GIT_SSH_COMMAND = "ssh -i `"$keyPath`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
                    & git.exe pull
                    $pullExitCode = $LASTEXITCODE
                    Remove-Item env:GIT_SSH_COMMAND
                    Pop-Location
                    if ($pullExitCode -ne 0) {
                        Write-Error "Khong the cap nhat ma nguon qua git pull."
                        exit 1
                    }
                    $cloneRequired = $false
                }
                "2" {
                    Write-Host "[OK] Giu nguyen thu muc." -ForegroundColor Green
                    $cloneRequired = $false
                }
                "3" {
                    Write-Host "-> Dang xoa thu muc cu de clone lai..." -ForegroundColor Cyan
                    Remove-Item -Recurse -Force $targetDir
                    $cloneRequired = $true
                }
                default {
                    Write-Host "Da huy bo cai dat."
                    exit 0
                }
            }
        } else {
            Write-Host "[WARN] Thu muc da ton tai nhung tro toi remote Git khac: $currentRemote" -ForegroundColor Red
            $confirm = Read-Host "Ban co muon xoa thu muc nay va clone moi tu dau khong? [y/N]"
            if ($confirm.Trim().ToLower() -eq 'y') {
                Remove-Item -Recurse -Force $targetDir
                $cloneRequired = $true
            } else {
                Write-Host "Da huy bo cai dat."
                exit 0
            }
        }
    } else {
        Write-Host "[WARN] Thu muc da ton tai nhung khong phai la mot Git repository." -ForegroundColor Red
        $confirm = Read-Host "Ban co muon xoa thu muc nay va clone moi tu dau khong? [y/N]"
        if ($confirm.Trim().ToLower() -eq 'y') {
            Remove-Item -Recurse -Force $targetDir
            $cloneRequired = $true
        } else {
            Write-Host "Da huy bo cai dat."
            exit 0
        }
    }
}

if ($cloneRequired) {
    Write-Host "-> Dang tien hanh clone ma nguon..." -ForegroundColor Cyan
    $env:GIT_SSH_COMMAND = "ssh -i `"$keyPath`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    & git.exe clone $repoUrl $targetDir
    $cloneExitCode = $LASTEXITCODE
    Remove-Item env:GIT_SSH_COMMAND
    if ($cloneExitCode -ne 0) {
        Write-Error "Khong the clone repository."
        exit 1
    }
    Write-Host "[OK] Clone ma nguon thanh cong." -ForegroundColor Green
}

# Cấu hình SSH Command cục bộ cho repository
Write-Host "-> Dang cau hinh SSH Command cho repository..." -ForegroundColor Cyan
Push-Location $targetDir
& git.exe config core.sshCommand "ssh -i `"$keyPath`" -o IdentitiesOnly=yes"
Pop-Location
Write-Host "[OK] Da cau hinh core.sshCommand cuc bo." -ForegroundColor Green

# Chạy kịch bản cài đặt chính
if ($skipSetup -eq "1") {
    Write-Host ""
    Write-Host "[WARN] Bien KITTY_ENTERPRISE_SKIP_SETUP duoc bat. Bo qua chay kich ban setup chinh." -ForegroundColor Yellow
    Write-Host "[OK] Quy trinh chuan bi ma nguon hoan tat." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "-> Dang chuyen vao thu muc va khoi chay setup-kitty.ps1..." -ForegroundColor Cyan
    Push-Location $targetDir
    if (Test-Path "setup-kitty.ps1") {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-kitty.ps1
        $setupExitCode = $LASTEXITCODE
        Pop-Location
        if ($setupExitCode -ne 0) {
            Write-Error "Kich ban setup-kitty.ps1 that bai."
            exit $setupExitCode
        }
    } else {
        Pop-Location
        Write-Error "Khong tim thay kich ban setup-kitty.ps1 trong kho luu tru."
        exit 1
    }
}
