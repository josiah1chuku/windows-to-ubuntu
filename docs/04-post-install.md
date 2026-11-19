# 04 — Post-install

`scripts/linux/01-post-install.sh` does all of this. The manual steps are below.

## Updates

```bash
sudo apt update && sudo apt full-upgrade -y
sudo snap refresh
sudo reboot
```

## NVIDIA

The installer's "third-party drivers" box installs the driver. Ubuntu ships the NVIDIA kernel modules pre-signed, so **no MOK enrollment screen** appeared with Secure Boot on.

```bash
nvidia-smi            # Quadro T1000, 4096MiB, P8 idle
prime-select query    # on-demand
```

If `nvidia-smi` is missing: `sudo ubuntu-drivers install && sudo reboot`.

## Firmware and Secure Boot keys (fwupd)

```bash
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update
```

On this machine it applied, in order:

1. **KEK** CA 2011 → 2023 (signed by Dell's platform key)
2. **db**: UEFI CA 2011 → 2023, plus Option ROM CA
3. **dbx** 20230501 → 20260402

After a reboot, `get-updates` offered **another dbx (20260707)**. That one is signed by the 2023 KEK, so it only appeared once step 1 was done. **Run `get-updates` again after each reboot until nothing is left.**

Gotchas:

- fwupd's "Restart now? y" can fail with `BlockedByInhibitorLock`. Just run `sudo reboot`.
- After an update, `get-updates` may print a big JSON report and wait for an *upload report?* answer that has scrolled off screen. Press `Ctrl+C` or answer `n`.

## Firewall

```bash
sudo ufw enable && sudo ufw status   # Status: active
```

## Base packages

```bash
sudo apt install -y git curl wget jq build-essential htop btop lm-sensors \
  gnome-tweaks gnome-shell-extension-manager timeshift
```

The `SyntaxWarning` from gnome-tweaks during install is harmless.

## Timeshift

> Lesson learned: the first run defaulted to **`nvme0n1p2` (2GB `/boot`)**. A snapshot filled it to 0 bytes.

Settings → Location → choose **dm-1** (the ext4 logical volume inside LUKS, about 500GB). Schedule: Daily ×5, Boot ×3. Home folders: excluded. Then **Create**.

If `/boot` has already filled up:

```bash
sudo du -sh /boot/* | sort -h          # look for /boot/timeshift
sudo rm -rf /boot/timeshift
df -h /boot                             # ~1.7G free
sudo update-initramfs -u -k all && sudo update-grub
```
