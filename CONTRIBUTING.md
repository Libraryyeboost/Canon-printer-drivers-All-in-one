# Contributing

Thanks for wanting to make this better! Here's how.

## I just want to add my printer

Read [`docs/contributing-models.md`](docs/contributing-models.md) — it's 60 seconds.

## I want to hack on the module

```powershell
git clone https://github.com/Libraryyeboost/Canon-printer-drivers-All-in-one
cd Canon-printer-drivers-All-in-one

# Load the module from the local checkout so you can iterate on it
Import-Module .\src\CanonDriverHub.psd1 -Force

# Run tests
Invoke-Pester ./tests
```

## House rules

- **One change per PR.** A new model, a bug fix, or a doc improvement —
  not all three at once.
- **Pester tests** for anything touching `CanonDriverHub.psm1`.
- **PSScriptAnalyzer clean.** CI runs it on every push.
- **No binary files in the repo.** The whole point of this project is
  that we don't host Canon's installers.
- **Allow-list additions** to `$script:AllowedHosts` require maintainer
  sign-off. Only Canon and Microsoft domains, please.

## Priorities we'd love help with

- **macOS port**. Canon's macOS driver installers are `.dmg`/`.pkg`;
  most of the detection/manifest logic ports over 1:1.
- **Linux CUPS** wrapper that installs Canon PPDs.
- **GUI** — a WPF or MAUI front-end around the same cmdlets.
- **Intune packaging template** (.intunewin) + SCCM application XML.
- **Translations** of the README, especially 日本語, Русский, Español, Português.

## Safety-sensitive changes

Anything that touches:

- `Assert-UrlAllowed` (the domain allow-list)
- `Invoke-CanonInstaller` (the silent-install cascade)
- `Test-Admin` / `Assert-IsAdmin`
- Signature verification in `Install-CanonDriver`

…gets extra review. Expect two maintainers. We're deliberately slow on
these because a bad change here could have a user run a malicious binary.
Please be patient.
