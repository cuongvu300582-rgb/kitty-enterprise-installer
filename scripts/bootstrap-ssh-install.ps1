# ============================================================================
# Kitty Agent SSH Bootstrap Installer (Windows PowerShell)
# ============================================================================
param (
    [switch]$Update
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Kitty Agent SSH Bootstrapper ===" -ForegroundColor Cyan
Write-Host "=========================================="

$isUpdate = $Update.IsPresent
if ($args -contains "--update" -or $args -contains "-u" -or $args -contains "update") {
    $isUpdate = $true
}

# --- 0. Add npm global directory to PATH if missing -------------------------
$npmFolder = Join-Path $env:APPDATA "npm"
try {
    $prefix = (npm config get prefix).Trim()
    if (Test-Path $prefix) {
        $npmFolder = $prefix
    }
} catch {}

$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$npmFolder*") {
    Write-Host "--> npm global directory not found in User PATH. Adding it..." -ForegroundColor Cyan
    try {
        $newUserPath = $userPath.TrimEnd(';') + ";$npmFolder"
        [System.Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
        $env:PATH = "$env:PATH;$npmFolder"
        Write-Host "[OK] Added npm global directory to User PATH: $npmFolder" -ForegroundColor Green
        
        # Spawn a new PowerShell terminal that has the updated PATH immediately
        Write-Host "--> Launching a new terminal window with the updated PATH..." -ForegroundColor Cyan
        Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Write-Host 'New terminal session loaded with updated PATH environment variable!' -ForegroundColor Green; Write-Host 'You can now run: kitty-enterprise' -ForegroundColor Cyan"
    } catch {
        Write-Warning "Could not automatically add npm global directory to permanent PATH."
    }
}

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
    $computerName = $env:COMPUTERNAME
    & ssh-keygen -t ed25519 -C "kitty-enterprise-$computerName" -N '""' -f $privateKey
    Write-Host "[OK] New SSH Key generated." -ForegroundColor Green
} else {
    Write-Host "[OK] Found existing SSH Key at $privateKey" -ForegroundColor Green
    
    # Verify if the existing key's comment needs to be updated
    $pubKeyContent = Get-Content $publicKey -Raw
    $expectedComment = "kitty-enterprise-$env:COMPUTERNAME"
    if ($pubKeyContent -notlike "*$expectedComment*") {
        Write-Host "--> Updating SSH Key comment to '$expectedComment'..." -ForegroundColor Cyan
        try {
            # Secure the private key file permissions first to avoid ssh-keygen bad permissions error
            $username = "$env:USERDOMAIN\$env:USERNAME"
            icacls.exe $privateKey /inheritance:r /grant:r "${username}:(F)" | Out-Null
            & ssh-keygen -c -C $expectedComment -f $privateKey | Out-Null
            Write-Host "[OK] SSH Key comment updated." -ForegroundColor Green
        } catch {
            Write-Warning "Could not automatically update existing SSH Key comment."
        }
    }
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
    
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $ssh_output = & ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1
    $ErrorActionPreference = $oldEap
    
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
$cloneDir = Join-Path $HOME "Kitty"

$runUpdateFlag = $false

if (Test-Path $cloneDir) {
    $choice = "1"
    if (-not $isUpdate) {
        Write-Host ""
        Write-Host "[WARNING] Directory '$cloneDir' already exists." -ForegroundColor Yellow
        Write-Host "Please choose an action:" -ForegroundColor Yellow
        Write-Host "  1) Update (Pull latest updates, rebuild, and restart services) [Default]" -ForegroundColor Cyan
        Write-Host "  2) Reinstall (Delete current directory and perform a fresh install)" -ForegroundColor Cyan
        Write-Host "  3) Cancel" -ForegroundColor Cyan
        $choiceInput = Read-Host "Enter choice [1-3]"
        if ($choiceInput -ne "") {
            $choice = $choiceInput
        }
    }

    if ($choice -eq "1") {
        Write-Host "--> Initiating update for existing installation in '$cloneDir'..." -ForegroundColor Cyan
        
        # 1. Stop any running gateway service to release file locks
        if (Test-Path "$cloneDir\.venv\Scripts\python.exe") {
            Write-Host "-> Stopping active Kitty gateway background service..." -ForegroundColor Cyan
            try {
                & "$cloneDir\.venv\Scripts\python.exe" -m kitty_cli.main gateway stop | Out-Null
            } catch {}
        }
        
        # 2. Stop any running dashboard service
        Write-Host "-> Stopping active Kitty dashboard background service..." -ForegroundColor Cyan
        try {
            & schtasks.exe /End /TN "Kitty_Dashboard" 2>$null | Out-Null
        } catch {}

        # 3. Terminate any remaining processes executing from the target directory
        Write-Host "-> Checking for active processes in '$cloneDir'..." -ForegroundColor Cyan
        try {
            Get-Process | Where-Object { $_.Path -like "$cloneDir*" } | ForEach-Object {
                Write-Host "   Terminating locking process: $($_.Name) (PID: $($_.Id))" -ForegroundColor Yellow
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
            # Give OS a moment to release file handles
            Start-Sleep -Seconds 1
        } catch {}

        Write-Host "-> Pulling latest changes from repository..." -ForegroundColor Cyan
        Push-Location $cloneDir
        & git pull
        Pop-Location
        $runUpdateFlag = $true
    } elseif ($choice -eq "2") {
        # 1. Stop any running gateway service to release file locks
        if (Test-Path "$cloneDir\.venv\Scripts\python.exe") {
            Write-Host "-> Stopping active Kitty gateway background service..." -ForegroundColor Cyan
            try {
                & "$cloneDir\.venv\Scripts\python.exe" -m kitty_cli.main gateway stop | Out-Null
            } catch {}
        }
        
        # 2. Stop any running dashboard service
        Write-Host "-> Stopping active Kitty dashboard background service..." -ForegroundColor Cyan
        try {
            & schtasks.exe /End /TN "Kitty_Dashboard" 2>$null | Out-Null
        } catch {}

        # 3. Terminate any remaining processes executing from the target directory
        Write-Host "-> Checking for active processes in '$cloneDir'..." -ForegroundColor Cyan
        try {
            Get-Process | Where-Object { $_.Path -like "$cloneDir*" } | ForEach-Object {
                Write-Host "   Terminating locking process: $($_.Name) (PID: $($_.Id))" -ForegroundColor Yellow
                Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            }
            # Give OS a moment to release file handles
            Start-Sleep -Seconds 1
        } catch {}

        Write-Host "-> Removing directory '$cloneDir'..." -ForegroundColor Cyan
        Remove-Item -Recurse -Force $cloneDir
        Write-Host "-> Cloning the private repository..." -ForegroundColor Cyan
        & git clone git@github.com:cuongvu300582-rgb/Kitty.git $cloneDir
    } else {
        Write-Host "Operation cancelled. Exiting." -ForegroundColor Yellow
        Exit 0
    }
} else {
    Write-Host "--> Cloning the private repository..." -ForegroundColor Cyan
    & git clone git@github.com:cuongvu300582-rgb/Kitty.git $cloneDir
}

if (Test-Path $cloneDir) {
    Set-Location $cloneDir
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "====================================================" -ForegroundColor Red
        Write-Host "[ERROR] Administrator privileges are required to run setup-kitty.ps1." -ForegroundColor Red
        Write-Host "Please run your terminal (PowerShell/CMD) as Administrator and run the command again." -ForegroundColor Red
        Write-Host "====================================================" -ForegroundColor Red
        Exit 1
    }

    if ($runUpdateFlag) {
        Write-Host "--> Launching setup-kitty.ps1 in Update mode..." -ForegroundColor Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-kitty.ps1 -Update
    } else {
        Write-Host "--> Launching setup-kitty.ps1..." -ForegroundColor Cyan
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-kitty.ps1
    }
} else {
    Write-Host "[ERROR] Failed to clone repository. Exiting." -ForegroundColor Red
    Exit 1
}
