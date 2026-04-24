# Troubleshooting

A grab-bag of fixes for the most common Canon-on-Windows headaches. If
`canondriver repair` doesn't solve it, try the matching section below.

## "Windows doesn't find the printer"

1. **Confirm it's on the network.** `Test-Connection 10.0.0.42 -Count 4`
2. **Check the printer's own IP panel** — Canon printers often show their IP
   under *Setup → Device settings → LAN settings → Confirm LAN settings*.
3. Run `canondriver detect`. If nothing appears:
   - USB-connected? Unplug, wait 5s, plug into a different port.
   - Network-connected? Make sure your PC and the printer are on the
     **same subnet**. Guest Wi-Fi usually isn't.

## "Driver installed, but printer prints blank / garbage"

You probably installed the wrong driver family (e.g. PCL instead of UFRII LT,
or XPS instead of PCL). Canon publishes multiple drivers per model. Fix:

```powershell
canondriver remove --driver "Canon <wrong driver name>"
canondriver install <model>   # picks the recommended one
```

If the recommended one is still wrong, open the support page manually:

```powershell
canondriver info <model>   # prints the Canon support URL
```

…and pick the UFRII LT (lasers) or Generic Plus driver (MFPs).

## "Spooler keeps crashing"

Classic symptom after a botched update. Run:

```powershell
canondriver repair
```

If that doesn't stick for more than a day, nuke and reinstall:

```powershell
canondriver remove --all-canon
canondriver install <model>
canondriver add-printer --model <model> --ip <ip>
```

## "Canon installer pops up dialogs even with -Silent"

Some older Canon installers (2018 and earlier) ignore `/s` and only respect
`/quiet`, and a few require a `/norestart` on top. The module tries a
cascade, but if yours is stubborn:

```powershell
canondriver save --model <m> --out $env:TEMP
& "$env:TEMP\<installer>.exe" /quiet /norestart
```

## "Driver download is slow"

Canon's Japan-based CDN (`gdlp01.c-wss.com`) can be slow from non-Asia-Pacific
regions. Workaround: set `$env:HTTPS_PROXY` to a closer mirror before running
`canondriver install`, or download manually from `canon.com/<region>` and use
`canondriver install -From <file>`.

## "Printer works locally but not shared"

Windows printer sharing requires:

1. **File & Printer Sharing** turned on (Control Panel → Network).
2. A matching driver architecture for each client (install the x86 driver
   on the server too if any client is 32-bit — rare now, but happens).
3. **SMB 2.0+** enabled (SMB1 is disabled by default on recent Windows).

```powershell
Set-Printer -Name "Office Laser" -Shared $true -ShareName "OfficeLaser"
```

## "I'm on Windows 11 ARM and the driver won't install"

Canon's ARM64 driver coverage is spotty. Options:
- Check if your model has an ARM64 UFRII LT driver (MF, LBP families are best).
- Fall back to Microsoft's **Universal Print** + Canon's IPP Everywhere support,
  which works on any ARM64 box.
- Run Windows 11 x64 in a VM (Hyper-V) and print from there.

## Still stuck?

[Open an issue](https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one/issues/new?template=bug_report.yml)
with the output of:

```powershell
canondriver detect
canondriver list
Get-PrinterDriver | Where-Object Name -match canon
$PSVersionTable
```
