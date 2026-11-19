#!/usr/bin/env bash
# Shared helpers for the Linux setup scripts. Source it; don't run it.
# shellcheck shell=bash

set -Eeuo pipefail

c_info='\033[1;34m'; c_ok='\033[1;32m'; c_warn='\033[1;33m'; c_err='\033[1;31m'; c_off='\033[0m'
info() { printf "${c_info}==>${c_off} %s\n" "$*"; }
ok()   { printf "${c_ok}  ok${c_off} %s\n" "$*"; }
warn() { printf "${c_warn}warn${c_off} %s\n" "$*" >&2; }
die()  { printf "${c_err}fail${c_off} %s\n" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

require_normal_user() {
  [[ ${EUID} -ne 0 ]] || die "Run as your normal user (not sudo). The script calls sudo when it needs to."
  sudo -v || die "sudo is required"
}

ubuntu_codename() {
  # shellcheck source=/dev/null
  . /etc/os-release
  echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}"
}

# pick_codename <repo base URL> [fallback]
# Prints this release's codename if the repo publishes it, otherwise the fallback (default: noble).
pick_codename() {
  local base="$1" fallback="${2:-noble}" cn
  cn="$(ubuntu_codename)"
  if curl -fsSIL --max-time 15 "${base%/}/dists/${cn}/Release" >/dev/null 2>&1; then
    echo "${cn}"
  else
    warn "${base} has no '${cn}' suite yet; using '${fallback}'. Re-run later to switch."
    echo "${fallback}"
  fi
}

apt_install() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}
