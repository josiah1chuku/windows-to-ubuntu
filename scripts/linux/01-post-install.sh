#!/usr/bin/env bash
# Post-install hardening for the Precision 7550 on Ubuntu 26.04.
# Safe to re-run. Usage: ./01-post-install.sh [--apply-firmware]
#   --apply-firmware   also install pending fwupd updates (reboot afterwards yourself)

# shellcheck source=scripts/linux/lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"

APPLY_FW=0
[[ "${1:-}" == "--apply-firmware" ]] && APPLY_FW=1

require_normal_user

info "System updates"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
sudo snap refresh || warn "snap refresh reported a problem"
ok "packages up to date"

info "Base packages"
apt_install git curl wget jq ca-certificates gnupg build-essential htop btop lm-sensors \
  gnome-tweaks gnome-shell-extension-manager timeshift mokutil
ok "base packages installed"

info "NVIDIA driver"
if have nvidia-smi && nvidia-smi -L >/dev/null 2>&1; then
  ok "$(nvidia-smi -L | head -1)"
else
  warn "NVIDIA driver not active; installing the recommended driver"
  sudo ubuntu-drivers install
  warn "Reboot, then re-run this script"
fi
if have prime-select; then
  mode="$(prime-select query 2>/dev/null || true)"
  if [[ "${mode}" != "on-demand" ]]; then
    sudo prime-select on-demand && warn "PRIME set to on-demand (was '${mode}'); takes effect after reboot"
  else
    ok "PRIME mode: on-demand"
  fi
fi

info "Firmware (fwupd / LVFS)"
sudo fwupdmgr refresh --force >/dev/null 2>&1 || warn "fwupd metadata refresh failed (offline?)"
# get-updates exits 2 when there is nothing to do; --no-unreported-check avoids the hidden upload prompt
# shellcheck disable=SC2024  # output goes to a user-owned temp file on purpose
if sudo fwupdmgr get-updates --no-unreported-check -y >/tmp/fwupd-updates.txt 2>&1; then
  warn "Firmware updates are available (see /tmp/fwupd-updates.txt)"
  if [[ ${APPLY_FW} -eq 1 ]]; then
    sudo fwupdmgr update -y --no-reboot-check --no-unreported-check
    warn "Firmware staged. Run 'sudo reboot', then re-run with --apply-firmware until nothing is left (new KEK unlocks newer dbx)."
  else
    warn "Re-run with --apply-firmware to install them"
  fi
else
  ok "no firmware updates pending"
fi

info "Firewall"
sudo ufw --force enable >/dev/null
ok "$(sudo ufw status | head -1)"

info "/boot space"
boot_use="$(df --output=pcent /boot | tail -1 | tr -dc '0-9')"
if [[ -d /boot/timeshift ]]; then
  warn "/boot/timeshift exists (Timeshift wrote to /boot). Removing it and rebuilding initramfs/grub."
  sudo rm -rf /boot/timeshift
  sudo update-initramfs -u -k all
  sudo update-grub
fi
(( boot_use < 80 )) && ok "/boot ${boot_use}% used" || warn "/boot ${boot_use}% used; consider 'sudo apt autoremove --purge'"

info "Timeshift (rsync, root logical volume, never /boot)"
root_dev="$(findmnt -no SOURCE /)"
[[ "${root_dev}" == /dev/mapper/* || "${root_dev}" == /dev/dm-* ]] || warn "root is ${root_dev}; expected an LVM volume"
cfg=/etc/timeshift/timeshift.json
if ! sudo test -f "${cfg}" || ! sudo timeshift --list --snapshot-device "${root_dev}" 2>/dev/null | grep -q '^[0-9]'; then
  sudo timeshift --create --rsync --snapshot-device "${root_dev}" --comments "post-install baseline" --tags O
fi
# Schedules: daily x5, boot x3; home folders stay excluded (Timeshift default)
tmp="$(mktemp)"
# shellcheck disable=SC2024  # reading root-owned config, writing a user temp file
sudo jq '.schedule_daily="true" | .count_daily="5" | .schedule_boot="true" | .count_boot="3"
         | .schedule_hourly="false" | .schedule_weekly="false" | .schedule_monthly="false"' "${cfg}" >"${tmp}"
sudo install -m 0644 "${tmp}" "${cfg}" && rm -f "${tmp}"
ok "Timeshift on ${root_dev}: daily x5, boot x3"

info "Done. Run scripts/linux/03-verify.sh for a summary."
