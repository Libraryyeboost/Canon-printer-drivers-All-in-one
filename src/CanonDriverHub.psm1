<#
    CanonDriverHub.psm1
    --------------------
    Single-file PowerShell module that powers the `canondriver` command.
    Pure PowerShell — no external binaries, no Python, no .NET extras.

    Design notes
    * We NEVER host Canon binaries. `Install-CanonDriver` fetches from
      the URL recorded in manifests/printers.json, which always points at
      an official Canon domain (*.canon.com / *.c-wss.com) or a Microsoft
      Windows Update catalog entry.
    * Trademarks — "Canon", "PIXMA", etc. — belong to Canon Inc. This
      module is a community tool and is not affiliated with Canon.
#>

#region ────────────────────────────── globals ────────────────────────────────

$script:ManifestPath  = Join-Path $PSScriptRoot 'manifests\printers.json'
$script:ManifestUrl   = 'https://raw.githubusercontent.com/Libraryyeboost/Canon-printer-drivers-All-in-one/main/manifests/printers.json'
$script:CacheDir      = Join-Path $env:LOCALAPPDATA 'CanonDriverHub\cache'
$script:AllowedHosts  = @(
    'www.canon.com',       'canon.com',
    'www.usa.canon.com',   'www.canon-europe.com', 'www.canon.co.jp',
    'downloads.canon.com', 'gdlp01.c-wss.com',     'pdisp01.c-wss.com',
    'catalog.update.microsoft.com'
)

if (-not (Test-Path $script:CacheDir)) {
    New-Item -ItemType Directory -Path $script:CacheDir -Force | Out-Null
}

#endregion

#region ────────────────────────────── helpers ────────────────────────────────

function Get-CanonManifest {
    if (-not (Test-Path $script:ManifestPath)) {
        throw "Manifest not found at $script:ManifestPath. Run Update-CanonManifest."
    }
    try {
        return (Get-Content -Raw $script:ManifestPath | ConvertFrom-Json).printers
    } catch {
        throw "Manifest is malformed: $($_.Exception.Message)"
    }
}

function Resolve-CanonModel {
    <#
      Accepts a model string like "ts3520", "TS 3520", "pixma ts3520"
      and returns the matching manifest entry, or $null.
    #>
    param([Parameter(Mandatory)][string]$Query)

    $q = ($Query -replace '\s+', '').ToLowerInvariant()
    $manifest = Get-CanonManifest

    # 1. Exact match on model field
    $hit = $manifest | Where-Object { ($_.model -replace '\s+', '').ToLowerInvariant() -eq $q }
    if ($hit) { return $hit | Select-Object -First 1 }

    # 2. Match on any alias
    $hit = $manifest | Where-Object {
        $_.aliases | Where-Object { ($_ -replace '\s+','').ToLowerInvariant() -eq $q }
    }
    if ($hit) { return $hit | Select-Object -First 1 }

    # 3. Suffix match (so "pixma ts3520" → "TS3520")
    $hit = $manifest | Where-Object {
        $modelNorm = ($_.model -replace '\s+','').ToLowerInvariant()
        $q.EndsWith($modelNorm) -or $modelNorm.EndsWith($q)
    }
    return $hit | Select-Object -First 1
}

function Assert-UrlAllowed {
    param([Parameter(Mandatory)][string]$Url)

    try {
        $u = [Uri]$Url
    } catch {
        throw "Refusing to download: '$Url' is not a valid URL."
    }

    if ($u.Scheme -ne 'https') {
        throw "Refusing to download: only HTTPS is allowed (got $($u.Scheme))."
    }

    $hostOk = $script:AllowedHosts | Where-Object { $u.Host -eq $_ -or $u.Host.EndsWith(".$_") }
    if (-not $hostOk) {
        throw "Refusing to download: '$($u.Host)' is not on the allow-list. Only Canon and Microsoft domains are permitted."
    }
}

function Invoke-SafeDownload {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$DestPath,
        [string]$ExpectedSha256
    )

    Assert-UrlAllowed -Url $Url

    Write-Host "      ↓ downloading " -NoNewline -ForegroundColor DarkGray
    Write-Host $Url                    -ForegroundColor Gray

    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        Invoke-WebRequest -Uri $Url -OutFile $DestPath -UseBasicParsing -ErrorAction Stop
    } catch {
        throw "Download failed: $($_.Exception.Message)"
    }
    $sw.Stop()

    $size = (Get-Item $DestPath).Length / 1MB
    Write-Host ("      ✅ {0:N1} MB in {1:N1}s" -f $size, $sw.Elapsed.TotalSeconds) -ForegroundColor Green

    if ($ExpectedSha256) {
        $actual = (Get-FileHash -Algorithm SHA256 -Path $DestPath).Hash
        if ($actual -ne $ExpectedSha256.ToUpperInvariant()) {
            Remove-Item -Force $DestPath -ErrorAction SilentlyContinue
            throw "SHA256 mismatch. Expected $ExpectedSha256, got $actual. File deleted."
        }
        Write-Host "      🔐 SHA256 verified." -ForegroundColor Green
    }
}

function Test-IsAdmin {
    $p = [Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-IsAdmin {
    if (-not (Test-IsAdmin)) {
        throw 'This command requires Administrator. Re-launch PowerShell as admin.'
    }
}

#endregion

#region ────────────────────────────── cmdlets ────────────────────────────────

function Find-CanonPrinter {
    <#
    .SYNOPSIS
        Scans USB, network, and installed printers for Canon devices.
    .EXAMPLE
        Find-CanonPrinter
    #>
    [CmdletBinding()]
    param()

    $found = @()

    # Installed printers via CIM
    try {
        Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop |
            Where-Object { $_.Name -match 'canon' -or $_.DriverName -match 'canon' } |
            ForEach-Object {
                $found += [PSCustomObject]@{
                    Device     = $_.Name
                    Family     = (Get-CanonFamily -Name $_.Name)
                    Connection = if ($_.Network) { 'Network' } elseif ($_.PortName) { $_.PortName } else { 'Local' }
                    Status     = if ($_.WorkOffline) { '⚠  offline' } else { '✅ driver' }
                }
            }
    } catch {
        Write-Verbose "Win32_Printer query failed: $($_.Exception.Message)"
    }

    # PnP devices (catches plugged-in but not-yet-installed printers)
    try {
        Get-PnpDevice -ErrorAction Stop |
            Where-Object { $_.Manufacturer -match 'Canon' -or $_.FriendlyName -match 'Canon' } |
            ForEach-Object {
                $name = $_.FriendlyName
                if (-not ($found | Where-Object { $_.Device -eq $name })) {
                    $found += [PSCustomObject]@{
                        Device     = $name
                        Family     = (Get-CanonFamily -Name $name)
                        Connection = 'USB/PnP'
                        Status     = if ($_.Status -eq 'OK') { '✅ enumerated' } else { '⚠  no drv' }
                    }
                }
            }
    } catch {
        Write-Verbose "PnP query failed: $($_.Exception.Message)"
    }

    if (-not $found) {
        Write-Host '  No Canon devices detected.' -ForegroundColor Yellow
        Write-Host '  Try `canondriver search <model>` to install manually.' -ForegroundColor DarkGray
        return
    }

    Write-Host ("  🔍  Found {0} Canon device(s):" -f $found.Count) -ForegroundColor Cyan
    $found | Format-Table -AutoSize
}

function Get-CanonFamily {
    param([string]$Name)
    switch -Regex ($Name) {
        'PIXMA|TS\d|TR\d|MG\d|MX\d|iP\d|G\d\d\d\d' { return 'PIXMA' }
        'MAXIFY|MB\d|GX\d|iB\d'                    { return 'MAXIFY' }
        'imageCLASS|i-SENSYS|LBP|MF\d|MF64\d|D\d\d\d' { return 'imageCLASS' }
        'SELPHY|CP\d'                              { return 'SELPHY' }
        'imagePROGRAF|PRO-\d|TM-\d|TC-\d'          { return 'imagePROGRAF' }
        'imageRUNNER|iR\d|ADVANCE'                 { return 'imageRUNNER' }
        default                                     { return 'Canon' }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
function Search-CanonModel {
    <#
    .SYNOPSIS
        Fuzzy-search the manifest for a model by name, family, or alias.
    .EXAMPLE
        Search-CanonModel pixma
        Search-CanonModel "TS35"
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Query)

    $q = $Query.ToLowerInvariant()
    $hits = Get-CanonManifest | Where-Object {
        $_.model.ToLowerInvariant().Contains($q) -or
        $_.family.ToLowerInvariant().Contains($q) -or
        ($_.aliases -and ($_.aliases | Where-Object { $_.ToLowerInvariant().Contains($q) }))
    }

    if (-not $hits) {
        Write-Host "  No models match '$Query'."  -ForegroundColor Yellow
        Write-Host '  Request it:  https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one/issues/new?template=model_request.yml' -ForegroundColor DarkGray
        return
    }

    $hits | Select-Object model, family, verified, supportUrl | Format-Table -AutoSize
}

# ─────────────────────────────────────────────────────────────────────────────
function Install-CanonDriver {
    <#
    .SYNOPSIS
        Downloads the driver from Canon's official servers and installs it.
    .PARAMETER Model
        Printer model, e.g. TS3520.
    .PARAMETER Silent
        Suppress Canon installer dialogs (default: on).
    .PARAMETER From
        Skip the download and install an already-downloaded Canon installer.
    .EXAMPLE
        Install-CanonDriver -Model TS3520
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Online')]
        [string]$Model,

        [Parameter(ParameterSetName = 'Online')]
        [switch]$Silent = $true,

        [Parameter(Mandatory, ParameterSetName = 'Offline')]
        [string]$From
    )

    Assert-IsAdmin

    if ($PSCmdlet.ParameterSetName -eq 'Offline') {
        return Invoke-CanonInstaller -Path $From -Silent:$Silent
    }

    Write-Host "[1/4] Looking up $Model in the manifest..." -NoNewline
    $entry = Resolve-CanonModel -Query $Model
    if (-not $entry) {
        Write-Host ''
        throw "Unknown model '$Model'. Try `Search-CanonModel $Model`, or file a model request."
    }
    Write-Host (' ✅ found ({0} family)' -f $entry.family) -ForegroundColor Green

    if (-not $entry.driverUrl) {
        Write-Host '      ⚠  No direct download URL recorded for this model.' -ForegroundColor Yellow
        Write-Host '      Opening Canon support page — download, then run:' -ForegroundColor Yellow
        Write-Host "          Install-CanonDriver -From <downloaded-file>.exe" -ForegroundColor Yellow
        Start-Process $entry.supportUrl
        return
    }

    Write-Host '[2/4] Fetching driver from canon.com...'
    $fileName   = [IO.Path]::GetFileName(([Uri]$entry.driverUrl).LocalPath)
    $localFile  = Join-Path $script:CacheDir $fileName
    Invoke-SafeDownload -Url $entry.driverUrl -DestPath $localFile -ExpectedSha256 $entry.sha256

    Write-Host '[3/4] Verifying signature...'
    $sig = Get-AuthenticodeSignature -FilePath $localFile
    if ($sig.Status -ne 'Valid') {
        throw "Driver Authenticode signature is '$($sig.Status)' — refusing to run. File at $localFile."
    }
    if ($sig.SignerCertificate.Subject -notmatch 'Canon') {
        Write-Host "      ⚠  Signer is '$($sig.SignerCertificate.Subject)'. Not Canon — proceed with caution." -ForegroundColor Yellow
    } else {
        Write-Host '      ✅ signed by Canon.' -ForegroundColor Green
    }

    Write-Host '[4/4] Running installer silently...'
    Invoke-CanonInstaller -Path $localFile -Silent:$Silent

    Write-Host ''
    Write-Host "  ✅  Driver installed for $($entry.model)." -ForegroundColor Green
    Write-Host '  Add the printer next with:' -ForegroundColor DarkGray
    Write-Host "      Add-CanonPrinter -Model $($entry.model) -IP <ip-address>" -ForegroundColor White
}

function Invoke-CanonInstaller {
    param([string]$Path, [switch]$Silent)

    if (-not (Test-Path $Path)) { throw "Installer not found: $Path" }

    # Canon installers usually accept /s or -s for silent. Try a cascade.
    $argSets = if ($Silent) {
        @('/s', '/silent', '/quiet', '/S', '-s')
    } else {
        @('')
    }

    foreach ($a in $argSets) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $p  = Start-Process -FilePath $Path -ArgumentList $a -PassThru -Wait -WindowStyle Hidden
        $sw.Stop()
        if ($p.ExitCode -in 0, 3010) {
            Write-Host ("      ✅ installed in {0:N0}s (exit {1})" -f $sw.Elapsed.TotalSeconds, $p.ExitCode) -ForegroundColor Green
            if ($p.ExitCode -eq 3010) {
                Write-Host '      ⚠  Reboot required to finish.' -ForegroundColor Yellow
            }
            return
        }
    }
    throw 'Installer exited with a non-zero code. Run it manually to see the error dialog.'
}

# ─────────────────────────────────────────────────────────────────────────────
function Save-CanonDriver {
    <#
    .SYNOPSIS
        Download a Canon driver installer to a folder without running it.
        Useful for offline / air-gapped deployments.
    .EXAMPLE
        Save-CanonDriver -Model MF644Cdw -Out \\fileserver\printers\
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Model,
        [Parameter(Mandatory)][string]$Out
    )

    $entry = Resolve-CanonModel -Query $Model
    if (-not $entry) { throw "Unknown model '$Model'." }
    if (-not $entry.driverUrl) {
        throw "No direct driver URL for $Model. See Canon's support page: $($entry.supportUrl)"
    }

    if (-not (Test-Path $Out)) { New-Item -ItemType Directory -Path $Out -Force | Out-Null }
    $dest = Join-Path $Out ([IO.Path]::GetFileName(([Uri]$entry.driverUrl).LocalPath))

    Invoke-SafeDownload -Url $entry.driverUrl -DestPath $dest -ExpectedSha256 $entry.sha256
    Write-Host "  💾 Saved: $dest" -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
function Add-CanonPrinter {
    <#
    .SYNOPSIS
        Create a TCP/IP port and register a Canon printer in one step.
    .EXAMPLE
        Add-CanonPrinter -Model MF644Cdw -IP 10.0.0.42 -Name "Office Laser"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Model,
        [Parameter(Mandatory)][string]$IP,
        [string]$Name
    )
    Assert-IsAdmin

    $entry = Resolve-CanonModel -Query $Model
    if (-not $entry) { throw "Unknown model '$Model'." }

    if (-not $Name) { $Name = "Canon $($entry.model)" }

    # 1. Port
    $portName = "TCPIP_$IP"
    if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
        Write-Host "  ➕  Adding TCP/IP port $IP..."
        Add-PrinterPort -Name $portName -PrinterHostAddress $IP
    }

    # 2. Driver must already be installed; pick the best match
    $drivers = Get-PrinterDriver | Where-Object { $_.Name -match [regex]::Escape($entry.model) -or $_.Name -match 'Canon' }
    if (-not $drivers) {
        throw "No matching driver is installed. Run: Install-CanonDriver -Model $($entry.model)"
    }
    $driver = $drivers | Select-Object -First 1
    Write-Host "  ➕  Binding driver '$($driver.Name)'..."

    # 3. Printer object
    if (Get-Printer -Name $Name -ErrorAction SilentlyContinue) {
        Write-Host "      Printer '$Name' already exists — skipping add." -ForegroundColor Yellow
    } else {
        Add-Printer -Name $Name -DriverName $driver.Name -PortName $portName
        Write-Host "  ✅  Printer '$Name' registered." -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────────────────────────────────────
function Get-CanonPrinter {
    <# .SYNOPSIS List installed Canon printers and their drivers. #>
    [CmdletBinding()] param()
    Get-Printer | Where-Object { $_.Name -match 'canon' -or $_.DriverName -match 'canon' } |
        Select-Object Name, DriverName, PortName, Type, Shared
}

# ─────────────────────────────────────────────────────────────────────────────
function Remove-CanonPrinter {
    <#
    .SYNOPSIS
        Remove a printer, a driver, or every Canon printer on the machine.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ParameterSetName='Printer')][string]$Printer,
        [Parameter(ParameterSetName='Driver')] [string]$Driver,
        [Parameter(ParameterSetName='AllCanon')][switch]$AllCanon
    )
    Assert-IsAdmin

    switch ($PSCmdlet.ParameterSetName) {
        'Printer' {
            if ($PSCmdlet.ShouldProcess($Printer, 'Remove-Printer')) {
                Remove-Printer -Name $Printer
                Write-Host "  🗑  Removed printer '$Printer'." -ForegroundColor Green
            }
        }
        'Driver'  {
            if ($PSCmdlet.ShouldProcess($Driver, 'Remove-PrinterDriver')) {
                Remove-PrinterDriver -Name $Driver
                Write-Host "  🗑  Removed driver '$Driver'." -ForegroundColor Green
            }
        }
        'AllCanon' {
            $printers = Get-Printer | Where-Object { $_.Name -match 'canon' -or $_.DriverName -match 'canon' }
            foreach ($p in $printers) {
                if ($PSCmdlet.ShouldProcess($p.Name, 'Remove-Printer')) {
                    Remove-Printer -Name $p.Name
                    Write-Host "  🗑  Printer '$($p.Name)' removed." -ForegroundColor Green
                }
            }
            $drivers = Get-PrinterDriver | Where-Object { $_.Name -match 'canon' }
            foreach ($d in $drivers) {
                if ($PSCmdlet.ShouldProcess($d.Name, 'Remove-PrinterDriver')) {
                    try {
                        Remove-PrinterDriver -Name $d.Name -ErrorAction Stop
                        Write-Host "  🗑  Driver '$($d.Name)' removed." -ForegroundColor Green
                    } catch {
                        Write-Host "  ⚠  Could not remove '$($d.Name)': $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
}

Set-Alias -Name Remove-CanonDriver -Value Remove-CanonPrinter

# ─────────────────────────────────────────────────────────────────────────────
function Repair-CanonPrinter {
    <#
    .SYNOPSIS
        Fix the common "printer stopped working" bucket: stuck spooler,
        jammed queue, orphaned TCP port. Run as admin.
    #>
    [CmdletBinding()] param([string]$Printer)
    Assert-IsAdmin

    Write-Host '  🧹  Stopping print spooler...'
    Stop-Service -Name Spooler -Force

    $queue = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
    $stuck = Get-ChildItem $queue -ErrorAction SilentlyContinue
    if ($stuck) {
        Write-Host ("      Removing {0} stuck job(s)..." -f $stuck.Count)
        $stuck | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    Write-Host '  ▶  Starting print spooler...'
    Start-Service -Name Spooler

    if ($Printer) {
        $p = Get-Printer -Name $Printer -ErrorAction SilentlyContinue
        if ($p -and $p.PortName -like 'TCPIP_*') {
            $ip = $p.PortName.Replace('TCPIP_', '')
            Write-Host "  🔌  Re-pinging $ip..."
            if (Test-Connection -ComputerName $ip -Count 2 -Quiet) {
                Write-Host '      ✅ reachable.' -ForegroundColor Green
            } else {
                Write-Host '      ⚠  not reachable — check network.' -ForegroundColor Yellow
            }
        }
    }

    Write-Host '  ✅  Done. Try printing again.' -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
function Get-CanonModelInfo {
    <# .SYNOPSIS Show the full manifest entry for a model. #>
    [CmdletBinding()] param([Parameter(Mandatory, Position=0)][string]$Model)
    $e = Resolve-CanonModel -Query $Model
    if (-not $e) { throw "Unknown model '$Model'." }
    $e | Format-List
}

# ─────────────────────────────────────────────────────────────────────────────
function Update-CanonManifest {
    <#
    .SYNOPSIS
        Pull the latest printers.json from GitHub.
    #>
    [CmdletBinding()] param()
    Write-Host '  ⬇  Fetching latest manifest...'
    Invoke-SafeDownload -Url $script:ManifestUrl -DestPath $script:ManifestPath
    $count = (Get-CanonManifest).Count
    Write-Host "  ✅  $count models indexed." -ForegroundColor Green
}

#endregion

#region ───────────────────────────── cli dispatcher ──────────────────────────

function Invoke-CanonDriverCli {
    <#
    .SYNOPSIS
        Thin CLI dispatcher so `canondriver <verb> <args>` feels like a tool,
        not a PowerShell cmdlet set. Called by the canondriver.cmd shim.
    #>
    [CmdletBinding()] param([Parameter(ValueFromRemainingArguments)][string[]]$Args)

    if (-not $Args -or $Args.Count -eq 0 -or $Args[0] -in '-h', '--help', '/?', 'help') {
        Show-CanonDriverHelp; return
    }

    $verb = $Args[0].ToLowerInvariant()
    $rest = if ($Args.Count -gt 1) { $Args[1..($Args.Count-1)] } else { @() }

    try {
        switch ($verb) {
            'detect'       { Find-CanonPrinter }
            'search'       { Search-CanonModel -Query ($rest -join ' ') }
            'install'      {
                $model = $rest | Where-Object { $_ -notlike '--*' } | Select-Object -First 1
                if (-not $model) { throw 'Usage: canondriver install <model>' }
                Install-CanonDriver -Model $model
            }
            'save'         {
                $m = Get-CliArg $rest '--model'; $o = Get-CliArg $rest '--out'
                if (-not ($m -and $o)) { throw 'Usage: canondriver save --model <m> --out <dir>' }
                Save-CanonDriver -Model $m -Out $o
            }
            'add-printer'  {
                $m  = Get-CliArg $rest '--model'; $ip = Get-CliArg $rest '--ip'; $n = Get-CliArg $rest '--name'
                if (-not ($m -and $ip)) { throw 'Usage: canondriver add-printer --model <m> --ip <ip> [--name <n>]' }
                if ($n) { Add-CanonPrinter -Model $m -IP $ip -Name $n }
                else    { Add-CanonPrinter -Model $m -IP $ip }
            }
            'list'         { Get-CanonPrinter | Format-Table -AutoSize }
            'remove'       {
                if ($rest -contains '--all-canon')      { Remove-CanonPrinter -AllCanon }
                elseif (Get-CliArg $rest '--printer')   { Remove-CanonPrinter -Printer (Get-CliArg $rest '--printer') }
                elseif (Get-CliArg $rest '--driver')    { Remove-CanonPrinter -Driver  (Get-CliArg $rest '--driver')  }
                else { throw 'Usage: canondriver remove [--printer <n> | --driver <n> | --all-canon]' }
            }
            'repair'       {
                $p = Get-CliArg $rest '--printer'
                if ($p) { Repair-CanonPrinter -Printer $p } else { Repair-CanonPrinter }
            }
            'info'         { Get-CanonModelInfo -Model ($rest -join ' ') }
            'update'       { Update-CanonManifest }
            'version'      { (Get-Module CanonDriverHub).Version.ToString() }
            default        {
                Write-Host "Unknown command '$verb'." -ForegroundColor Red
                Show-CanonDriverHelp
            }
        }
    } catch {
        Write-Host "  ❌  $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Get-CliArg {
    param([string[]]$Args, [string]$Name)
    $i = [Array]::IndexOf($Args, $Name)
    if ($i -lt 0 -or $i -ge $Args.Count - 1) { return $null }
    return $Args[$i + 1]
}

function Show-CanonDriverHelp {
@"
canondriver  —  Canon printer drivers, one command.

USAGE
  canondriver <command> [args]

COMMANDS
  detect                                   Scan for connected Canon printers
  search <query>                           Fuzzy-search the model index
  install <model>                          Download + install silently
  save --model <m> --out <dir>             Download installer to a folder
  add-printer --model <m> --ip <ip> [--name <n>]
                                           Create TCP/IP port + printer
  list                                     List installed Canon printers
  remove --printer <n>                     Remove one printer
  remove --driver <n>                      Uninstall a driver package
  remove --all-canon                       Nuke every Canon printer + driver
  repair [--printer <n>]                   Fix spooler / stuck queue / port
  info <model>                             Show the manifest entry
  update                                   Pull the latest manifest
  version                                  Print module version

EXAMPLES
  canondriver detect
  canondriver install TS3520
  canondriver add-printer --model MF644Cdw --ip 10.0.0.42 --name "Office Laser"
  canondriver repair

More:   https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one
"@ | Write-Host
}

#endregion

# Export public surface. (Private helpers stay internal thanks to the .psd1.)
Export-ModuleMember -Function @(
    'Find-CanonPrinter', 'Search-CanonModel', 'Install-CanonDriver',
    'Save-CanonDriver', 'Add-CanonPrinter', 'Get-CanonPrinter',
    'Remove-CanonPrinter', 'Remove-CanonDriver', 'Repair-CanonPrinter',
    'Get-CanonModelInfo', 'Update-CanonManifest', 'Invoke-CanonDriverCli'
) -Alias 'canondriver'
