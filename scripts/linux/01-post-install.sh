#!/usr/bin/env bash
# =============================================================================
# 01-post-install.sh — first thing to run after a fresh Ubuntu 26.04 install.
#
# What it does, in order:
#   1. Updates every package (apt + snap)
#   2. Installs base tools (git, jq, Timeshift, build tools, monitoring)
#   3. Checks the NVIDIA driver is loaded and PRIME is in on-demand mode
#   4. Checks for firmware / Secure Boot key updates through fwupd
#   5. Turns on the firewall (ufw)
#   6. Checks /boot isn't full (and repairs the Timeshift-on-/boot mistake)
#   7. Points Timeshift at the right disk and sets the snapshot schedule
#
# Re-running is safe: every step checks the current state before changing it.
#
# Usage:
#   ./01-post-install.sh                   check firmware, don't install it
#   ./01-post-install.sh --apply-firmware  also install pending firmware
#                                          (reboot yourself afterwards)
# =============================================================================

# Load the shared helpers (logging, have(), apt_install, ...).
# readlink -f resolves the script's real location, so this works from any folder.
# shellcheck source=scripts/linux/lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"

# Firmware is only CHECKED by default. Applying it changes the Secure Boot
# key stores and needs a reboot, so it should be a deliberate choice.
APPLY_FW=0
[[ "${1:-}" == "--apply-firmware" ]] && APPLY_FW=1

require_normal_user

# -----------------------------------------------------------------------------
# 1. Updates
# full-upgrade (rather than plain upgrade) may add or remove packages to
# complete an upgrade, e.g. a new kernel. That's what a fresh install needs.
# -----------------------------------------------------------------------------
info "System updates"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
sudo snap refresh || warn "snap refresh reported a problem"   # snaps update separately from apt
ok "packages up to date"

# -----------------------------------------------------------------------------
# 2. Base packages
#   jq        edits Timeshift's JSON config (step 7)
#   mokutil   reports Secure Boot state (used by 03-verify.sh)
#   lm-sensors / htop / btop  temperature and resource monitoring
# -----------------------------------------------------------------------------
info "Base packages"
apt_install git curl wget jq ca-certificates gnupg build-essential htop btop lm-sensors \
  gnome-tweaks gnome-shell-extension-manager timeshift mokutil
ok "base packages installed"

# -----------------------------------------------------------------------------
# 3. NVIDIA (Quadro T1000)
# The installer's "third-party drivers" box normally installs the driver.
# `nvidia-smi -L` lists GPUs, so it only succeeds when the driver is loaded.
# If it isn't, ubuntu-drivers picks and installs the recommended version.
# -----------------------------------------------------------------------------
info "NVIDIA driver"
if have nvidia-smi && nvidia-smi -L >/dev/null 2>&1; then
  ok "$(nvidia-smi -L | head -1)"
else
  warn "NVIDIA driver not active; installing the recommended driver"
  sudo ubuntu-drivers install
  warn "Reboot, then re-run this script"
fi

# PRIME on-demand: the Intel GPU drives the desktop and the NVIDIA GPU powers
# up only when an app asks for it. That's the best balance of battery and
# performance on a hybrid-graphics laptop. Only change it if it's set differently.
if have prime-select; then
  mode="$(prime-select query 2>/dev/null || true)"
  if [[ "${mode}" != "on-demand" ]]; then
    sudo prime-select on-demand && warn "PRIME set to on-demand (was '${mode}'); takes effect after reboot"
  else
    ok "PRIME mode: on-demand"
  fi
fi

# -----------------------------------------------------------------------------
# 4. Firmware via fwupd / LVFS (Linux Vendor Firmware Service)
# Dell publishes BIOS and UEFI updates here. On this machine it also delivered
# the Microsoft 2023 Secure Boot certificates (KEK, db) and the latest dbx
# revocation list.
#
# Lessons from the real run, built in here:
#   - `get-updates` exit codes: 0 = updates available, 2 = nothing to do.
#   - Without --no-unreported-check, fwupd may stop at a hidden
#     "upload report?" prompt after printing a large JSON block.
#   - The new KEK unlocks a NEWER dbx, so firmware needs more than one
#     update-and-reboot round.
# -----------------------------------------------------------------------------
info "Firmware (fwupd / LVFS)"
sudo fwupdmgr refresh --force >/dev/null 2>&1 || warn "fwupd metadata refresh failed (offline?)"
# shellcheck disable=SC2024  # output goes to a user-owned temp file on purpose
if sudo fwupdmgr get-updates --no-unreported-check -y >/tmp/fwupd-updates.txt 2>&1; then
  warn "Firmware updates are available (see /tmp/fwupd-updates.txt)"
  if [[ ${APPLY_FW} -eq 1 ]]; then
    # --no-reboot-check: we reboot ourselves. fwupd's own restart request was
    # refused by a systemd inhibitor lock on the real run.
    sudo fwupdmgr update -y --no-reboot-check --no-unreported-check
    warn "Firmware staged. Run 'sudo reboot', then re-run with --apply-firmware until nothing is left (new KEK unlocks newer dbx)."
  else
    warn "Re-run with --apply-firmware to install them"
  fi
else
  ok "no firmware updates pending"
fi

# -----------------------------------------------------------------------------
# 5. Firewall
# ufw's default policy is deny incoming, allow outgoing: right for a laptop.
# --force skips the "may disrupt SSH connections" prompt so this runs unattended.
# -----------------------------------------------------------------------------
info "Firewall"
sudo ufw --force enable >/dev/null
ok "$(sudo ufw status | head -1)"

# -----------------------------------------------------------------------------
# 6. /boot health
# With encryption, /boot is a separate, small (2GB) unencrypted partition. It
# holds the kernels and initramfs images. If it fills up, kernel updates fail.
#
# On the real run, Timeshift defaulted to /boot and filled it. If that folder
# exists we remove it and rebuild the boot files, in case an update tried to
# write them while the partition was full.
# -----------------------------------------------------------------------------
info "/boot space"
if [[ -d /boot/timeshift ]]; then
  warn "/boot/timeshift exists (Timeshift wrote to /boot). Removing it and rebuilding initramfs/grub."
  sudo rm -rf /boot/timeshift          # only this folder; everything else in /boot is needed to boot
  sudo update-initramfs -u -k all      # regenerate the initramfs for every installed kernel
  sudo update-grub                     # refresh the boot menu entries
fi
boot_use="$(df --output=pcent /boot | tail -1 | tr -dc '0-9')"   # e.g. " 9%" -> "9"
(( boot_use < 80 )) && ok "/boot ${boot_use}% used" || warn "/boot ${boot_use}% used; consider 'sudo apt autoremove --purge'"

# -----------------------------------------------------------------------------
# 7. Timeshift (system snapshots)
# The snapshot device is set EXPLICITLY to whatever holds / (the ext4 logical
# volume inside LUKS, e.g. /dev/mapper/ubuntu--vg-ubuntu--lv), so Timeshift can
# never pick /boot again.
# rsync mode works on ext4; BTRFS mode would need a btrfs root.
# Home folders stay excluded (Timeshift default): it protects the SYSTEM, it
# isn't a backup of your files.
# -----------------------------------------------------------------------------
info "Timeshift (rsync, root logical volume, never /boot)"
root_dev="$(findmnt -no SOURCE /)"
[[ "${root_dev}" == /dev/mapper/* || "${root_dev}" == /dev/dm-* ]] || warn "root is ${root_dev}; expected an LVM volume"
cfg=/etc/timeshift/timeshift.json

# Take a first "baseline" snapshot if there's no config or no snapshots yet.
# This also makes Timeshift write its config file, which we edit next.
# Tag O = "on demand" (manual) snapshot.
if ! sudo test -f "${cfg}" || ! sudo timeshift --list --snapshot-device "${root_dev}" 2>/dev/null | grep -q '^[0-9]'; then
  sudo timeshift --create --rsync --snapshot-device "${root_dev}" --comments "post-install baseline" --tags O
fi

# Set the schedule in Timeshift's JSON config: daily x5, at boot x3, nothing else.
# Timeshift stores these as strings ("true", "5"), so the values are quoted.
# Write to a temp file first, then install it, so a failed jq never leaves a broken config.
tmp="$(mktemp)"
# shellcheck disable=SC2024  # reading root-owned config, writing a user temp file
sudo jq '.schedule_daily="true" | .count_daily="5" | .schedule_boot="true" | .count_boot="3"
         | .schedule_hourly="false" | .schedule_weekly="false" | .schedule_monthly="false"' "${cfg}" >"${tmp}"
sudo install -m 0644 "${tmp}" "${cfg}" && rm -f "${tmp}"
ok "Timeshift on ${root_dev}: daily x5, boot x3"

info "Done. Run scripts/linux/03-verify.sh for a summary."
