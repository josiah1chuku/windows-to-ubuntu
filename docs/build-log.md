# Build log

## 2026-11-16
- Received the Precision 7550 (refurbished) with Windows 11 Pro.

## 2026-11-18
- Matched the hardware to Dell's original configuration: i5-10400H, 32GB, Quadro T1000, KIOXIA 512GB NVMe, FHD. No faults in Device Manager.
- BIOS: battery health Excellent. Absolute changed Enabled → Disabled (it held). Battery charge set to Custom 50–80%.
- BitLocker recovery triggered by the BIOS changes. Unlocked with the Microsoft account key, then turned off device encryption (Fully Decrypted).
- Webcam tested.
- Dell Command | Update 5.7.0: BIOS **1.46.0** installed (urgent).
- Rufus 4.16: wrote Ubuntu 26.04.1 LTS to a 128GB USB stick (GPT/UEFI, ISO mode).
- BIOS: Secure Boot, Switchable Graphics, Virtualization and Fastboot (Thorough) confirmed.
- Installed **Ubuntu 26.04.1 LTS**: erase disk, LUKS on LVM, ext4, third-party drivers and codecs, America/Chicago.
- First boot: apt full-upgrade and snap refresh. `nvidia-smi` shows the Quadro T1000. `prime-select` = on-demand.
- fwupd: KEK 2011→2023, db (UEFI CA) 2011→2023, dbx 20230501→20260402.

## 2026-11-19
- fwupd: dbx 20260707 offered (signed with the 2023 KEK).
- `ufw` enabled.
- Base packages and Timeshift installed. Timeshift defaulted to `/boot` and filled it. Fixed (removed `/boot/timeshift`, rebuilt initramfs and grub). Snapshot location moved to `dm-1`. First snapshot taken.

## Next
- Phase 7: run `scripts/linux/02-dev-tools.sh`.
