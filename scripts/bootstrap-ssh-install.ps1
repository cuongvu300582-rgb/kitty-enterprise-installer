# ============================================================================
# Kitty Agent SSH Bootstrap Installer (Windows PowerShell)
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Kitty Agent SSH Bootstrapper ===" -ForegroundColor Cyan
Write-Host "=========================================="

$sshDir = Join-Path $HOME ".ssh"
$privateKey = Join-Path $sshDir "id_ed25519"
$publicKey = Join-Path $sshDir "id_ed25519.pub"

# --- 1. Detect or Generate SSH Key -------------------------------------------
if (-not (Test-Path $privateKey)) {
    Write-Host "--> Generating new Ed25519 SSH Key..." -ForegroundColor Cyan
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    # Run ssh-keygen
    & ssh-keygen -t ed25519 -C "kitty-agent-bootstrap" -N '""' -f $privateKey
    Write-Host "[OK] New SSH Key generated." -ForegroundColor Green
} else {
    Write-Host "[OK] Found existing SSH Key at $privateKey" -ForegroundColor Green
}

# --- 2. Prompt User to Add Key to GitHub --------------------------------------
$pubKeyContent = Get-Content $publicKey -Raw
Write-Host ""
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host "YOUR SSH PUBLIC KEY:" -ForegroundColor Yellow
Write-Host $pubKeyContent -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Please copy the SSH public key above and add it to your GitHub account:" -ForegroundColor Cyan
Write-Host "  1. Open: https://github.com/settings/keys in your browser" -ForegroundColor Green
Write-Host "  2. Click 'New SSH key'" -ForegroundColor Green
Write-Host "  3. Paste the key and click 'Add SSH key'" -ForegroundColor Green
Write-Host ""

# --- 3. Connection Status Verification Loop ----------------------------------
while ($true) {
    Read-Host "Once you have added the key to GitHub, press [ENTER] to verify..."
    Write-Host "--> Verifying connection to GitHub..." -ForegroundColor Cyan
    
    $ssh_output = & ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1
    
    # Check if the output contains successfully authenticated
    $strOutput = [string]$ssh_output
    if ($strOutput -match "successfully authenticated") {
        Write-Host "[OK] Connection successful! GitHub authenticated successfully." -ForegroundColor Green
        break
    } else {
        Write-Host "[ERROR] Authentication failed." -ForegroundColor Red
        Write-Host "GitHub responded: $strOutput"
        Write-Host "Please make sure you copied the key correctly and added it to the active account." -ForegroundColor Yellow
        Write-Host ""
    }
}

# --- 4. Clone and Launch Main Installer --------------------------------------
Write-Host ""
Write-Host "--> Cloning the private repository..." -ForegroundColor Cyan

$cloneDir = Join-Path $HOME "Kitty"

if (Test-Path $cloneDir) {
    Write-Host "[WARNING] Directory '$cloneDir' already exists." -ForegroundColor Yellow
    $reply = Read-Host "Would you like to remove the existing '$cloneDir' directory and re-clone? [y/N]"
    if ($reply -match "^[Yy]$") {
        Remove-Item -Recurse -Force $cloneDir
        & git clone git@github.com:cuongvu300582-rgb/Kitty.git $cloneDir
    } else {
        Write-Host "Proceeding with the existing '$cloneDir' directory and pulling latest changes..." -ForegroundColor Yellow
        Push-Location $cloneDir
        & git pull
        Pop-Location
    }
} else {
    & git clone git@github.com:cuongvu300582-rgb/Kitty.git $cloneDir
}

if (Test-Path $cloneDir) {
    Set-Location $cloneDir
    Write-Host "--> Launching setup-kitty.ps1..." -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-kitty.ps1
} else {
    Write-Host "[ERROR] Failed to clone repository. Exiting." -ForegroundColor Red
    Exit 1
}
