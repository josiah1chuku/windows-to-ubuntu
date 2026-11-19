# Troubleshooting (issues hit during this build)

| Symptom | Cause | Fix |
| --- | --- | --- |
| BitLocker recovery screen after changing BIOS settings | Windows device encryption is measured against the BIOS config | Key from aka.ms/myrecoverykey (match the key ID). Then turn off device encryption before any more BIOS changes or updates. |
| `cd "C:\Program Files\Dell\CommandUpdate"` fails | DCU 5.x installs to the 32-bit folder | Use `C:\Program Files (x86)\Dell\CommandUpdate` |
| `dcu-cli /applyUpdates` exits with code 1 and doesn't reboot | 1 = reboot required | `shutdown /r /t 0` |
| Rufus not in the Start menu after winget | Portable app with a command alias | Open a new terminal and run `rufus` |
| Installer closes after "Update now" | Self-update restarts it | Double-click **Install Ubuntu 26.04.1 LTS** on the desktop |
| Disk setup defaults to "alongside Windows" | Installer detects Windows Boot Manager | Pick **Erase disk and install Ubuntu** |
| Live session clock looks wrong | Live session runs on UTC | It's fixed by the time zone step |
| `fwupdmgr update` → `BlockedByInhibitorLock` on restart | fwupd's restart request refused; only *delay* inhibitors were present | `sudo reboot` |
| `fwupdmgr get-updates` prints JSON and hangs | Waiting on a hidden *upload report?* prompt | `Ctrl+C`, or answer `n` |
| New dbx update appears after the first round | It needs the 2023 KEK that was just installed | Run `get-updates` again after each reboot |
| "Low Disk Space on boot: 0 bytes" | Timeshift defaulted to `/boot` (`nvme0n1p2`) | Point Timeshift at `dm-1`, `rm -rf /boot/timeshift`, rebuild initramfs and grub (see 04) |
| `os-prober will not be executed` from `update-grub` | Default on Ubuntu | Harmless with a single OS |
