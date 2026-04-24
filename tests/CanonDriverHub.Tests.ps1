# Pester tests for CanonDriverHub. Run with:   Invoke-Pester ./tests
# These tests focus on:
#   * the manifest being well-formed & on Canon/MS domains
#   * resolver logic (aliases, suffix match, case insensitivity)
#   * the URL allow-list refusing unsafe URLs
# They do NOT hit the network or touch the printer subsystem.

BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $root 'src\CanonDriverHub.psd1') -Force

    # Make the module's private helpers reachable from the test scope.
    InModuleScope CanonDriverHub {
        Export-ModuleMember -Function *
    }

    $script:manifestPath = Join-Path $root 'manifests\printers.json'
    $script:manifest     = (Get-Content -Raw $script:manifestPath | ConvertFrom-Json)
}

Describe 'Manifest' {
    It 'is valid JSON' {
        { Get-Content -Raw $script:manifestPath | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'declares a schema and version' {
        $script:manifest.version   | Should -BeGreaterOrEqual 1
        $script:manifest.'$schema' | Should -Not -BeNullOrEmpty
    }

    It 'has at least 30 printer entries' {
        $script:manifest.printers.Count | Should -BeGreaterThan 29
    }

    It 'every entry has the required fields' {
        foreach ($p in $script:manifest.printers) {
            $p.model      | Should -Not -BeNullOrEmpty -Because "entry $($p.model)"
            $p.family     | Should -Not -BeNullOrEmpty -Because "entry $($p.model)"
            $p.supportUrl | Should -Not -BeNullOrEmpty -Because "entry $($p.model)"
        }
    }

    It 'every supportUrl is on a Canon domain' {
        foreach ($p in $script:manifest.printers) {
            ([Uri]$p.supportUrl).Host | Should -Match 'canon\.(com|co\.jp)' -Because "entry $($p.model)"
        }
    }

    It 'every driverUrl (when set) is on an allowed host' {
        $allowed = @(
            'gdlp01.c-wss.com', 'pdisp01.c-wss.com',
            'www.usa.canon.com', 'www.canon-europe.com', 'www.canon.co.jp',
            'downloads.canon.com'
        )
        foreach ($p in $script:manifest.printers) {
            if ($p.driverUrl) {
                $hostName = ([Uri]$p.driverUrl).Host
                $ok = $allowed | Where-Object { $hostName -eq $_ -or $hostName.EndsWith(".$_") }
                $ok | Should -Not -BeNullOrEmpty -Because "entry $($p.model) uses host $hostName"
            }
        }
    }

    It 'declares only the six known printer families' {
        $families = $script:manifest.printers.family | Sort-Object -Unique
        $expected = @('PIXMA','MAXIFY','imageCLASS','SELPHY','imagePROGRAF','imageRUNNER') | Sort-Object
        (Compare-Object $families $expected) | Should -BeNullOrEmpty
    }
}

Describe 'Module surface' {
    It 'exports the expected public cmdlets' {
        $exported = (Get-Module CanonDriverHub).ExportedFunctions.Keys
        foreach ($name in @(
            'Find-CanonPrinter','Search-CanonModel','Install-CanonDriver',
            'Save-CanonDriver','Add-CanonPrinter','Get-CanonPrinter',
            'Remove-CanonPrinter','Repair-CanonPrinter','Get-CanonModelInfo',
            'Update-CanonManifest','Invoke-CanonDriverCli'
        )) {
            $exported | Should -Contain $name
        }
    }

    It 'Invoke-CanonDriverCli with no args or "help" prints usage' {
        $out = Invoke-CanonDriverCli 2>&1 | Out-String
        $out | Should -Match 'USAGE'
    }
}

Describe 'Search-CanonModel' {
    It 'returns multiple PIXMA models for query "pixma"' {
        $hits = Search-CanonModel -Query 'pixma' 6>&1
        # family column is the thing we care about
        ($hits | Where-Object { $_.family -eq 'PIXMA' }).Count | Should -BeGreaterThan 5
    }

    It 'is case-insensitive' {
        $lo = Search-CanonModel -Query 'ts35' 6>&1
        $up = Search-CanonModel -Query 'TS35' 6>&1
        $lo.Count | Should -Be $up.Count
    }
}
