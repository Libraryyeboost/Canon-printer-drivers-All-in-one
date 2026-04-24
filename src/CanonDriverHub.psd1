@{
    RootModule           = 'CanonDriverHub.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'b8e4c7d2-3f1a-4c8e-9b5a-6c7e8d9f0a1b'
    Author               = 'Libraryyeboost'
    CompanyName          = 'Community'
    Copyright            = '(c) 2026 Libraryyeboost. MIT licensed.'
    Description          = 'One-command Canon printer driver installation for Windows. Detects printers, downloads from Canon official servers, installs silently, and configures network printers.'

    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @(
        'Find-CanonPrinter'
        'Search-CanonModel'
        'Install-CanonDriver'
        'Save-CanonDriver'
        'Add-CanonPrinter'
        'Get-CanonPrinter'
        'Remove-CanonPrinter'
        'Remove-CanonDriver'
        'Repair-CanonPrinter'
        'Get-CanonModelInfo'
        'Update-CanonManifest'
        'Invoke-CanonDriverCli'
    )

    AliasesToExport = @('canondriver')
    CmdletsToExport = @()
    VariablesToExport = @()

    PrivateData = @{
        PSData = @{
            Tags         = @(
                'canon', 'printer', 'drivers', 'pixma', 'maxify', 'imageclass',
                'i-sensys', 'selphy', 'imageprograf', 'imagerunner',
                'windows', 'powershell', 'automation'
            )
            LicenseUri   = 'https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one'
            ReleaseNotes = 'Initial release. Supports PIXMA, MAXIFY, imageCLASS, SELPHY, imagePROGRAF, imageRUNNER families.'
        }
    }
}
