# Enterprise deployment

Rolling this out to 50+ machines? Here's the fastest path for each platform.

## One-liner onboarding script

Drop this anywhere that runs on first login (Autopilot, SetupComplete,
scheduled task, whatever):

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
irm https://raw.githubusercontent.com/Libraryyeboost/Canon-printer-drivers-All-in-one/main/install.ps1 | iex
canondriver install TS3520 -Silent
canondriver add-printer -Model TS3520 -IP 10.0.0.50 -Name "Reception"
```

## Air-gapped / offline deployment

On an internet-connected machine:

```powershell
canondriver save --model MF644Cdw --out \\fileserver\canon\
```

On the target machine (no internet required):

```powershell
# Preload the module once (ship CanonDriverHub folder with your image)
Import-Module \\fileserver\ps-modules\CanonDriverHub

Install-CanonDriver -From \\fileserver\canon\MF644Cdw.exe
Add-CanonPrinter -Model MF644Cdw -IP 10.0.0.42
```

## Intune (Win32 app)

1. Package `install.ps1` and your target model list using the
   [Microsoft Win32 Content Prep Tool](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management).
2. Install command:
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1
   ```
3. Uninstall command:
   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module CanonDriverHub; Remove-CanonPrinter -AllCanon -Confirm:$false"
   ```
4. Detection rule: file `%ProgramFiles%\WindowsPowerShell\Modules\CanonDriverHub\CanonDriverHub.psd1` exists.

## SCCM / ConfigMgr

Create an application with two deployment types:

- **Script installer**: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1`
- **Detection**: registry or file presence of the module path.
- **Dependencies**: none.

## Group Policy (legacy)

1. Put `install.ps1` on a share readable by all machines.
2. Computer Config → Policies → Windows Settings → Scripts → Startup.
3. Add `powershell.exe` with arguments `-NoProfile -ExecutionPolicy Bypass -File \\server\share\install.ps1`.

## Per-user vs per-machine

- The default installer writes the module to the current user's
  `Documents\WindowsPowerShell\Modules` and adds the shim to **User PATH**.
- For per-machine deployment, copy the module folder to
  `$env:ProgramFiles\WindowsPowerShell\Modules\CanonDriverHub` and set the
  shim in `$env:ProgramData\chocolatey\bin` or a similar system location.
- Driver install commands (`Install-CanonDriver`, `Add-Printer`) always
  require **administrator** rights — this is a Windows constraint, not ours.

## License check for MSPs

Before bundling this tool in a product or managed service, read Canon's
end-user license agreement for each driver you distribute. Canon's EULA
terms vary by region and product family. This tool is MIT licensed, but
the drivers it downloads are not.
