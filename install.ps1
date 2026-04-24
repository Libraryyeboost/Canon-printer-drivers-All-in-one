<#
.SYNOPSIS
    One-line installer for Canon-printer-drivers-All-in-one.

.DESCRIPTION
    Downloads the CanonDriverHub PowerShell module to the user's module path,
    adds a `canondriver` shim to PATH, and runs a detect pass so the user
    immediately sees what's plugged in.

.EXAMPLE
    powershell -c "irm https://raw.githubusercontent.com/Libraryyeboost/Canon-printer-drivers-All-in-one/main/install.ps1 | iex"
#>

$ErrorActionPreference = 'Stop'

function Write-Banner {
    Write-Host ''
    Write-Host '  ┌──────────────────────────────────────────────────┐' -ForegroundColor Red
    Write-Host '  │   🖨️   Canon Printer Drivers — All-in-One          │' -ForegroundColor Red
    Write-Host '  │       one-command install · 400+ models           │' -ForegroundColor Red
    Write-Host '  └──────────────────────────────────────────────────┘' -ForegroundColor Red
    Write-Host ''
}

function Test-Admin {
    $currentUser  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal    = [Security.Principal.WindowsPrincipal]::new($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Banner

# ---------------------------------------------------------------------------
# 0. Sanity checks
# ---------------------------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host '  ❌  PowerShell 5.1+ required. You are on ' -NoNewline -ForegroundColor Red
    Write-Host $PSVersionTable.PSVersion -ForegroundColor Yellow
    Write-Host '      Install the latest from https://aka.ms/powershell' -ForegroundColor Red
    exit 1
}

if (-not (Test-Admin)) {
    Write-Host '  ⚠️   Not running as Administrator.' -ForegroundColor Yellow
    Write-Host '      The installer will continue, but driver-install and repair' -ForegroundColor Yellow
    Write-Host '      commands will need an elevated shell to actually run.' -ForegroundColor Yellow
    Write-Host ''
}

# ---------------------------------------------------------------------------
# 1. Work out install paths
# ---------------------------------------------------------------------------
$Repo        = 'Libraryyeboost/Canon-printer-drivers-All-in-one'
$Branch      = 'main'
$RawRoot     = "https://raw.githubusercontent.com/$Repo/$Branch"
$ModuleName  = 'CanonDriverHub'
$UserModules = Join-Path $HOME  'Documents\WindowsPowerShell\Modules'
$ModuleDir   = Join-Path $UserModules $ModuleName
$ShimDir     = Join-Path $HOME  '.canondriver'

foreach ($d in @($UserModules, $ModuleDir, $ShimDir, (Join-Path $ModuleDir 'manifests'))) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

Write-Host "[1/4] Installing module to: $ModuleDir" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 2. Download the module files
# ---------------------------------------------------------------------------
$files = @(
    'src/CanonDriverHub.psd1'
    'src/CanonDriverHub.psm1'
    'manifests/printers.json'
)
foreach ($rel in $files) {
    $url  = "$RawRoot/$rel"
    # Flatten src/ → module root; keep manifests/ as-is.
    $leaf = Split-Path $rel -Leaf
    $dest = if ($rel -like 'manifests/*') {
        Join-Path $ModuleDir 'manifests' | Join-Path -ChildPath $leaf
    } else {
        Join-Path $ModuleDir $leaf
    }
    Write-Host "      ↓ $rel" -ForegroundColor DarkGray
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "  ❌  Failed to download $rel" -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------
# 3. Register the `canondriver` shim on PATH
# ---------------------------------------------------------------------------
Write-Host "[2/4] Registering 'canondriver' command..." -ForegroundColor Cyan

$shimPath = Join-Path $ShimDir 'canondriver.cmd'
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Module CanonDriverHub; Invoke-CanonDriverCli @args" %*
"@ | Set-Content -Path $shimPath -Encoding ASCII

# Prepend ShimDir to the User PATH (idempotent)
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not ($userPath.Split(';') -contains $ShimDir)) {
    [Environment]::SetEnvironmentVariable('Path', "$ShimDir;$userPath", 'User')
    $env:Path = "$ShimDir;$env:Path"
}

# ---------------------------------------------------------------------------
# 4. Verify & greet
# ---------------------------------------------------------------------------
Write-Host "[3/4] Importing module..." -ForegroundColor Cyan
Import-Module $ModuleName -Force

Write-Host "[4/4] Scanning for connected Canon printers..." -ForegroundColor Cyan
Write-Host ''
try   { Find-CanonPrinter }
catch { Write-Host "      (scan skipped: $($_.Exception.Message))" -ForegroundColor DarkGray }

Write-Host ''
Write-Host '  ✅  Installed.' -ForegroundColor Green
Write-Host ''
Write-Host '  Try one of these:' -ForegroundColor Green
Write-Host '      canondriver detect'                  -ForegroundColor White
Write-Host '      canondriver search "pixma ts"'       -ForegroundColor White
Write-Host '      canondriver install TS3520'          -ForegroundColor White
Write-Host '      canondriver --help'                  -ForegroundColor White
Write-Host ''
Write-Host '  Open a NEW PowerShell window so the PATH change takes effect.' -ForegroundColor DarkGray
Write-Host ''
