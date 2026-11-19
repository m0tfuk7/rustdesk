# RustDesk Map Mode with Interception

This personal build can use the official Interception v1.0.1 keyboard driver for Map Mode on a controlled Windows x64 computer. macOS controllers and the RustDesk protocol do not change.

## One-time setup

Open PowerShell as Administrator and pass the directory that contains the installed `rustdesk.exe`:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup-interception.ps1 -RustDeskDirectory "C:\Program Files\RustDesk"
```

The script downloads the official v1.0.1 archive, verifies SHA-256 `ad038963d6413055765128b0b931f6e765147c9916dba79e65d872b261f9af10`, installs the driver, and copies the official x64 `interception.dll` beside `rustdesk.exe`. Restart Windows afterward. Normal RustDesk launches should not require administrator privileges once the driver is installed.

Use an installed RustDesk build for unattended access. A single-file portable build may unpack its runtime to another directory, where the sibling DLL is not available.

## Fallback and removal

Removing `interception.dll` from the RustDesk directory makes Map Mode use its original SendInput backend. To remove the driver completely, download the same official package, open an administrator terminal in its `command line installer` directory, and run:

```powershell
.\install-interception.exe /uninstall
```

Restart Windows after uninstalling.

## Limits

The Interception project permits the public package for non-commercial use under its stated LGPL terms; commercial use requires a license from its author. This repository does not bundle the vendor DLL, installer, or driver.

Interception v1.0.1 is an older kernel filter driver. Windows 11 memory integrity, the Microsoft vulnerable-driver blocklist, Secure Boot policy, or game anti-cheat software may block it. This integration does not disable or bypass those protections.
