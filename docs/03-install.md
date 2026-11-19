# 03 — USB stick and install

## Make the USB (from Windows)

1. Download the **Ubuntu 26.04.1 LTS Desktop** ISO from ubuntu.com/download/desktop (about 5.9GB).
2. Optional: verify it against `SHA256SUMS` from releases.ubuntu.com/26.04:
   ```powershell
   Get-FileHash "$env:USERPROFILE\Downloads\ubuntu-26.04.1-desktop-amd64.iso" -Algorithm SHA256
   ```
3. Install and run Rufus:
   ```powershell
   winget install --id Rufus.Rufus -e
   # It isn't added to the Start menu. Open a NEW terminal and run:
   rufus
   ```
4. Rufus settings: Device = the USB stick · Boot selection = the ISO · Persistent partition = 0 · **GPT** · **UEFI (non CSM)** · START → **ISO Image mode (Recommended)** → OK.

> Ubuntu 24.04 LTS was the original plan. 26.04.1 LTS was current by install time (Nov 2026). It's supported until 2031, and Docker's apt repo supports it.

## Install

F12 at the Dell logo → UEFI Boot → the USB stick → **Try or Install Ubuntu**.

| Screen | Choice |
| --- | --- |
| Language / Accessibility | English / Next |
| Keyboard | **English (US)** (the laptop has a US keyboard) |
| Internet | Wi-Fi |
| Installer update | **Update now**. The installer closes. Reopen it with the **Install Ubuntu** desktop icon. |
| Type of installation | Interactive installation |
| Applications | Default selection |
| Optimise your computer | Tick **both**: third-party graphics/Wi-Fi drivers and media formats |
| Disk setup | It defaults to *Install alongside Windows Boot Manager*. **Change it to Erase disk and install Ubuntu.** |
| Encryption and file system | **Encrypt with a passphrase** (LUKS on LVM). Not "hardware-backed": TPM unlock can ask for a recovery key after BIOS or driver changes. Advanced options: leave ext4. |
| Account | Require password to log in. Not Active Directory. |
| Location | Nearest city (this build: America/Chicago) |
| Review | Should show `nvme0n1` erased, LUKS (LVM), Codecs & drivers. The USB stick (`sda1`) should show *Unchanged*. |

Expect about 20 minutes. Then **Restart now**, remove the stick when prompted ("installation medium"), and press Enter.

First boot: the welcome wizard. Ubuntu Pro → *Skip for now* (you can add it later with `sudo pro attach`) · Location services → your choice · Done.

For a mostly unattended reinstall, see [../autoinstall/](../autoinstall/).
