#!/usr/bin/env bash
# =============================================================================
# 03-verify.sh — read-only health report for the finished build.
#
# Checks the end state the other scripts aim for: OS, Secure Boot, disk
# encryption, /boot space, NVIDIA/PRIME, firewall, Timeshift, and every tool
# from 02-dev-tools.sh.
#
# Prints PASS or WARN per line, then exits 0 if everything passed and 1 if
# not. The exit code means it can be used in CI-style checks or a cron job.
#
# It changes nothing. Run it after `sudo -v` (the Makefile does this) so the
# firewall and Timeshift checks can read root-only state without prompting.
# =============================================================================

# Not using -e on purpose: a failed check should be reported, not stop the report.
set -uo pipefail
fails=0
pass() { printf '\033[1;32mPASS\033[0m %-22s %s\n' "$1" "$2"; }
fail() { printf '\033[1;33mWARN\033[0m %-22s %s\n' "$1" "$2"; fails=$((fails+1)); }
have() { command -v "$1" >/dev/null 2>&1; }

# check <label> <command...>
# Runs a "print version" style command. PASS if it prints something, WARN if it's missing or fails.
check() {
  local label="$1"; shift
  local out
  if out="$("$@" 2>/dev/null | head -1)" && [[ -n "${out}" ]]; then pass "${label}" "${out}"; else fail "${label}" "not found"; fi
}

echo "== System =="
# shellcheck source=/dev/null
. /etc/os-release; pass "OS" "${PRETTY_NAME}"
pass "Kernel" "$(uname -r)"
# BIOS version and model come from DMI data the kernel exposes; no root needed
pass "BIOS" "$(cat /sys/class/dmi/id/bios_version 2>/dev/null) ($(cat /sys/class/dmi/id/product_name 2>/dev/null))"

# Secure Boot must be ON. Ubuntu's shim and the pre-signed NVIDIA modules boot fine with it.
sb="$(mokutil --sb-state 2>/dev/null | head -1)"
[[ "${sb}" == *enabled* ]] && pass "Secure Boot" "${sb}" || fail "Secure Boot" "${sb:-unknown}"

# A "crypt" device in lsblk means the LUKS container from the install is present
if lsblk -no TYPE | grep -q crypt; then pass "Disk encryption" "LUKS present"; else fail "Disk encryption" "no LUKS volume"; fi

# /boot is a small 2GB partition: warn early, before kernel updates start failing
boot_use="$(df --output=pcent /boot | tail -1 | tr -dc '0-9')"
(( boot_use < 80 )) && pass "/boot usage" "${boot_use}%" || fail "/boot usage" "${boot_use}%"
# The mistake from the real build: Timeshift writing snapshots into /boot
[[ -d /boot/timeshift ]] && fail "/boot/timeshift" "exists; Timeshift is writing to /boot"

echo "== Graphics =="
# Driver loaded = nvidia-smi can query the GPU's name and driver version
if have nvidia-smi && nvidia-smi -L >/dev/null 2>&1; then pass "NVIDIA" "$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader)"; else fail "NVIDIA" "driver not loaded"; fi
# on-demand = Intel for the desktop, NVIDIA only when an app asks for it
have prime-select && { m="$(prime-select query)"; [[ "${m}" == on-demand ]] && pass "PRIME" "${m}" || fail "PRIME" "${m}"; }

echo "== Security & recovery =="
# sudo -n = never prompt. If sudo isn't cached, these show WARN with a hint instead of hanging.
ufw_state="$(sudo -n ufw status 2>/dev/null | head -1)"
[[ "${ufw_state}" == *active* && "${ufw_state}" != *inactive* ]] && pass "Firewall" "${ufw_state}" || fail "Firewall" "${ufw_state:-run with sudo to check}"
# Count snapshot lines in `timeshift --list` (they start with an index number and ">")
snaps="$(sudo -n timeshift --list 2>/dev/null | grep -cE '^[0-9]+ +>' || true)"
[[ "${snaps:-0}" -gt 0 ]] && pass "Timeshift" "${snaps} snapshot(s)" || fail "Timeshift" "no snapshots (or run with sudo)"

echo "== Toolchain =="
# One line per tool installed by 02-dev-tools.sh
check "VS Code" code --version
check "PowerShell" pwsh --version
check "GitHub CLI" gh --version
check "Docker" docker --version
check "Azure CLI" bash -c "az version --query '\"azure-cli\"' -o tsv"
check "Bicep" az bicep version
check "kubectl" kubectl version --client
check "kubelogin" kubelogin --version
check "Terraform" terraform -version
check "Helm" helm version --short
check "Argo CD" argocd version --client --short

echo
(( fails == 0 )) && echo "All checks passed." || echo "${fails} warning(s)."
exit $(( fails > 0 ))   # 0 = all good, 1 = at least one WARN
