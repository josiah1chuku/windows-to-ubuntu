#!/usr/bin/env bash
# Read-only health report. Prints PASS/WARN per check; exits 1 if any WARN.

set -uo pipefail
fails=0
pass() { printf '\033[1;32mPASS\033[0m %-22s %s\n' "$1" "$2"; }
fail() { printf '\033[1;33mWARN\033[0m %-22s %s\n' "$1" "$2"; fails=$((fails+1)); }
have() { command -v "$1" >/dev/null 2>&1; }
check() { # check <label> <command...>
  local label="$1"; shift
  local out
  if out="$("$@" 2>/dev/null | head -1)" && [[ -n "${out}" ]]; then pass "${label}" "${out}"; else fail "${label}" "not found"; fi
}

echo "== System =="
# shellcheck source=/dev/null
. /etc/os-release; pass "OS" "${PRETTY_NAME}"
pass "Kernel" "$(uname -r)"
pass "BIOS" "$(cat /sys/class/dmi/id/bios_version 2>/dev/null) ($(cat /sys/class/dmi/id/product_name 2>/dev/null))"
sb="$(mokutil --sb-state 2>/dev/null | head -1)"
[[ "${sb}" == *enabled* ]] && pass "Secure Boot" "${sb}" || fail "Secure Boot" "${sb:-unknown}"
if lsblk -no TYPE | grep -q crypt; then pass "Disk encryption" "LUKS present"; else fail "Disk encryption" "no LUKS volume"; fi
boot_use="$(df --output=pcent /boot | tail -1 | tr -dc '0-9')"
(( boot_use < 80 )) && pass "/boot usage" "${boot_use}%" || fail "/boot usage" "${boot_use}%"
[[ -d /boot/timeshift ]] && fail "/boot/timeshift" "exists; Timeshift is writing to /boot"

echo "== Graphics =="
if have nvidia-smi && nvidia-smi -L >/dev/null 2>&1; then pass "NVIDIA" "$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader)"; else fail "NVIDIA" "driver not loaded"; fi
have prime-select && { m="$(prime-select query)"; [[ "${m}" == on-demand ]] && pass "PRIME" "${m}" || fail "PRIME" "${m}"; }

echo "== Security & recovery =="
ufw_state="$(sudo -n ufw status 2>/dev/null | head -1)"
[[ "${ufw_state}" == *active* && "${ufw_state}" != *inactive* ]] && pass "Firewall" "${ufw_state}" || fail "Firewall" "${ufw_state:-run with sudo to check}"
snaps="$(sudo -n timeshift --list 2>/dev/null | grep -cE '^[0-9]+ +>' || true)"
[[ "${snaps:-0}" -gt 0 ]] && pass "Timeshift" "${snaps} snapshot(s)" || fail "Timeshift" "no snapshots (or run with sudo)"

echo "== Toolchain =="
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
exit $(( fails > 0 ))
