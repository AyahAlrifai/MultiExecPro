# ============================================================
#  MultiExecPro Installer
#  Supports: Windows, Linux, macOS
#  Repo: https://github.com/AyahAlrifai/MultiExecPro
# ============================================================

$ErrorActionPreference = "Stop"

$ScriptName  = "multiExecPro"
$FileName    = "multiExecPro.ps1"
$RawUrl      = "https://raw.githubusercontent.com/AyahAlrifai/MultiExecPro/main/multiExecPro.ps1"

# ── Detect platform ─────────────────────────────────────────
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    $Platform   = "windows"
    $InstallDir = "$env:USERPROFILE\.multiexecpro"
} elseif ($IsMacOS) {
    $Platform   = "mac"
    $InstallDir = "$HOME/.multiexecpro"
} else {
    $Platform   = "linux"
    $InstallDir = "$HOME/.multiexecpro"
}

$TargetPath = Join-Path $InstallDir $FileName

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "   MultiExecPro Installer" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Platform  : $Platform"
Write-Host "  Install to: $InstallDir"
Write-Host ""

# ── 1. Create install directory ─────────────────────────────
Write-Host "[1/4] Preparing install folder..." -ForegroundColor Cyan
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Host "      Created: $InstallDir" -ForegroundColor Green
} else {
    Write-Host "      Already exists." -ForegroundColor Yellow
}

# ── 2. Download script from GitHub ──────────────────────────
Write-Host "[2/4] Downloading $FileName from GitHub..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $RawUrl -OutFile $TargetPath -UseBasicParsing
    Write-Host "      Downloaded successfully." -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "      ERROR: Download failed." -ForegroundColor Red
    Write-Host "      Check your internet connection and try again." -ForegroundColor Red
    Write-Host "      URL: $RawUrl" -ForegroundColor Red
    exit 1
}

# ── 3. Register command ──────────────────────────────────────
Write-Host "[3/4] Registering '$ScriptName' command..." -ForegroundColor Cyan

if ($Platform -eq "windows") {

    # Add install dir to User PATH
    $UserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($UserPath -notlike "*$InstallDir*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$UserPath;$InstallDir", "User")
        Write-Host "      Added to User PATH." -ForegroundColor Green
    } else {
        Write-Host "      PATH already contains install dir." -ForegroundColor Yellow
    }

    # Create PowerShell profile if missing
    $ProfileDir = Split-Path $PROFILE
    if (-not (Test-Path $ProfileDir)) { New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null }
    if (-not (Test-Path $PROFILE))    { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }

    # Add function to profile so user types just "multiExecPro"
    $FunctionLine    = "function $ScriptName { & '$TargetPath' @args }"
    $ProfileContent  = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

    if ($ProfileContent -notlike "*$ScriptName*") {
        Add-Content -Path $PROFILE -Value "`n# MultiExecPro`n$FunctionLine"
        Write-Host "      Added function to PowerShell profile." -ForegroundColor Green
    } else {
        Write-Host "      Function already in PowerShell profile." -ForegroundColor Yellow
    }

    # Fix execution policy if scripts are blocked
    $Policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($Policy -eq "Restricted" -or $Policy -eq "Undefined") {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "      Execution policy set to RemoteSigned." -ForegroundColor Green
    }

} else {
    # Linux / macOS
    # Auto-detect shell config file
    $ShellConfig = if     (Test-Path "$HOME/.zshrc")        { "$HOME/.zshrc" }
                   elseif (Test-Path "$HOME/.bashrc")       { "$HOME/.bashrc" }
                   else                                     { "$HOME/.bash_profile" }

    $ExportLine  = "export PATH=`"${InstallDir}:`$PATH`""
    $AliasLine   = "alias $ScriptName='pwsh $TargetPath'"

    $ShellContent = Get-Content $ShellConfig -Raw -ErrorAction SilentlyContinue

    if ($ShellContent -notlike "*multiexecpro*") {
        Add-Content -Path $ShellConfig -Value "`n# MultiExecPro`n$ExportLine`n$AliasLine"
        Write-Host "      Added alias to $ShellConfig" -ForegroundColor Green
    } else {
        Write-Host "      Alias already in $ShellConfig" -ForegroundColor Yellow
    }

    # Make script executable
    chmod +x $TargetPath
    Write-Host "      Script marked as executable." -ForegroundColor Green
}

# ── 4. Done ──────────────────────────────────────────────────
Write-Host ""
Write-Host "[4/4] Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan

if ($Platform -eq "windows") {
    Write-Host ""
    Write-Host "  Open a NEW PowerShell window, then run:" -ForegroundColor White
    Write-Host ""
    Write-Host "      multiExecPro" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "  Reload your shell config:" -ForegroundColor White
    Write-Host ""
    $cfg = if ($IsMacOS) { "~/.zshrc" } else { "~/.bashrc" }
    Write-Host "      source $cfg" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Then run from anywhere:" -ForegroundColor White
    Write-Host ""
    Write-Host "      multiExecPro" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
