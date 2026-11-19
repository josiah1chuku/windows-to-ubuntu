#!/usr/bin/env bash
# =============================================================================
# lib.sh — shared helpers for the Linux setup scripts.
#
# This file is SOURCED by 01-post-install.sh and 02-dev-tools.sh, never run on
# its own. Keeping logging, checks and the apt-repo logic here means each
# script stays short and they all behave the same way.
# =============================================================================
# shellcheck shell=bash

# Fail fast and loudly:
#   -E  ERR traps also fire inside functions
#   -e  stop on the first failing command
#   -u  treat unset variables as errors (catches typos)
#   -o pipefail  a pipeline fails if ANY part of it fails, not just the last
set -Eeuo pipefail

# --- Logging -----------------------------------------------------------------
# Coloured prefixes make it easy to scan the output for problems.
# warn/die write to stderr so they still show if stdout is redirected.
c_info='\033[1;34m'; c_ok='\033[1;32m'; c_warn='\033[1;33m'; c_err='\033[1;31m'; c_off='\033[0m'
info() { printf "${c_info}==>${c_off} %s\n" "$*"; }          # a new section is starting
ok()   { printf "${c_ok}  ok${c_off} %s\n" "$*"; }             # a step finished successfully
warn() { printf "${c_warn}warn${c_off} %s\n" "$*" >&2; }       # something needs your attention, but carry on
die()  { printf "${c_err}fail${c_off} %s\n" "$*" >&2; exit 1; } # unrecoverable: stop the script

# have <cmd>: true if a command is on PATH.
# Used to skip installs that are already done, which is what makes the scripts safe to re-run.
have() { command -v "$1" >/dev/null 2>&1; }

# require_normal_user: the scripts must run as YOU, not root.
# Some steps are per user (e.g. `az bicep install` goes into ~/.azure, and
# `usermod -aG docker $USER` must target your account, not root).
# `sudo -v` asks for the password once up front and caches it, so later
# sudo calls don't interrupt the run.
require_normal_user() {
  [[ ${EUID} -ne 0 ]] || die "Run as your normal user (not sudo). The script calls sudo when it needs to."
  sudo -v || die "sudo is required"
}

# ubuntu_codename: prints the release codename, e.g. "resolute" for 26.04 or "noble" for 24.04.
# Third-party apt repos are organised by codename, so we need it to build their source entries.
ubuntu_codename() {
  # shellcheck source=/dev/null
  . /etc/os-release
  echo "${UBUNTU_CODENAME:-${VERSION_CODENAME}}"
}

# pick_codename <repo base URL> [fallback]
#
# Why this exists: when a new Ubuntu release comes out, vendors (Docker,
# Microsoft, HashiCorp) take weeks or months to publish packages for it.
# Pointing apt at a codename the vendor doesn't publish breaks `apt update`.
#
# So we probe the repo for  <base>/dists/<codename>/Release:
#   - found     -> use this release's codename
#   - not found -> fall back to the previous LTS (noble = 24.04), whose
#                  packages run fine on 26.04, and say so
# Re-running the script later switches to the native codename once it's published.
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

# apt_install <pkgs...>: non-interactive install.
#   DEBIAN_FRONTEND=noninteractive  stops packages from opening config dialogs mid-run
#   --no-install-recommends         installs only what's needed, keeping the system lean
apt_install() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}
