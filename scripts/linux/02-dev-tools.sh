#!/usr/bin/env bash
# =============================================================================
# 02-dev-tools.sh — installs the DevOps / Azure toolchain.
#
# Tools: VS Code, PowerShell, Helm, GitHub CLI, Docker Engine, Azure CLI,
#        Bicep, kubectl, kubelogin, Terraform, Argo CD CLI.
#
# Install source policy, in order of preference:
#   1. The vendor's own apt repo (Docker, Microsoft, HashiCorp): signed and
#      current, and updated with the rest of the system by `apt upgrade`
#   2. Snap, where the vendor publishes an official classic snap (Code, pwsh, Helm)
#   3. A single release binary (Argo CD), where there's no official package
#
# Every tool is skipped if it's already installed, so re-running is safe.
# Works on Ubuntu 26.04, and on 24.04 too.
# =============================================================================

# shellcheck source=scripts/linux/lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"

require_normal_user
ARCH="$(dpkg --print-architecture)"              # "amd64" on this laptop; used in repo entries and binary names
sudo install -m 0755 -d /etc/apt/keyrings         # standard place for third-party repo signing keys
apt_install ca-certificates curl gnupg jq         # needed to fetch and de-armor the signing keys

# -----------------------------------------------------------------------------
# Snaps: official classic snaps from Microsoft and the Helm project.
# "--classic" lets them access the whole filesystem, which editors and CLIs need.
# -----------------------------------------------------------------------------
info "Snaps: VS Code, PowerShell, Helm"
have code || sudo snap install code --classic
have pwsh || sudo snap install powershell --classic
have helm || sudo snap install helm --classic
ok "snaps present"

# -----------------------------------------------------------------------------
# GitHub CLI: in Ubuntu's own archive, so no extra repo is needed.
# -----------------------------------------------------------------------------
info "GitHub CLI"
have gh || apt_install gh
ok "$(gh --version | head -1)"

# -----------------------------------------------------------------------------
# Docker Engine, from Docker's repo rather than Ubuntu's `docker.io` package,
# which lags behind and doesn't ship the Buildx/Compose plugins the same way.
#
# Repo entries use the deb822 ".sources" format (the default from Ubuntu 24.04 on).
# "Signed-By" pins the repo to its own key, so that key can't be used to sign
# packages from any other repo.
# -----------------------------------------------------------------------------
info "Docker Engine"
if ! have docker; then
  # Docker's docs say to remove conflicting distro packages first; "|| true" because they're usually absent
  sudo apt-get remove -y docker.io docker-compose docker-doc podman-docker containerd runc 2>/dev/null || true
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  suite="$(pick_codename https://download.docker.com/linux/ubuntu)"   # resolute if published, otherwise noble
  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${suite}
Components: stable
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  sudo apt-get update
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
# Adding you to the "docker" group lets you run docker without sudo.
# Note: that group gives root-equivalent access, which is acceptable on a single-user workstation.
# Group membership only applies to NEW login sessions, hence the warning.
if ! id -nG "${USER}" | grep -qw docker; then
  sudo usermod -aG docker "${USER}"
  warn "Added ${USER} to the docker group. Log out and back in before using docker without sudo."
fi
ok "$(docker --version)"

# -----------------------------------------------------------------------------
# Azure CLI, from Microsoft's repo. This is the manual method in Microsoft's
# docs. It's used instead of the `curl | sudo bash` one-liner so every step is
# visible, and so the codename fallback can be applied.
# -----------------------------------------------------------------------------
info "Azure CLI"
if ! have az; then
  # Microsoft ships an ASCII-armored key; apt wants binary, so gpg --dearmor converts it
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
  sudo chmod a+r /etc/apt/keyrings/microsoft.gpg
  suite="$(pick_codename https://packages.microsoft.com/repos/azure-cli)"
  sudo tee /etc/apt/sources.list.d/azure-cli.sources >/dev/null <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${suite}
Components: main
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF
  sudo apt-get update
  apt_install azure-cli
fi
ok "azure-cli $(az version --query '"azure-cli"' -o tsv)"

# Bicep: az downloads the Bicep binary into ~/.azure/bin (per user, no sudo).
# install fails if Bicep is already there, so fall back to upgrade.
info "Bicep (per user)"
az bicep install >/dev/null 2>&1 || az bicep upgrade >/dev/null 2>&1 || warn "bicep install failed"
ok "$(az bicep version 2>/dev/null | head -1)"

# kubectl + kubelogin: `az aks install-cli` fetches both into /usr/local/bin.
# kubelogin is needed for AKS clusters that use Microsoft Entra ID (Azure AD) sign-in.
info "kubectl + kubelogin"
if ! have kubectl || ! have kubelogin; then
  sudo az aks install-cli
fi
ok "$(kubectl version --client 2>/dev/null | head -1)"

# -----------------------------------------------------------------------------
# Terraform, from HashiCorp's apt repo (same pattern as Docker and Azure CLI).
# -----------------------------------------------------------------------------
info "Terraform"
if ! have terraform; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
  suite="$(pick_codename https://apt.releases.hashicorp.com)"
  sudo tee /etc/apt/sources.list.d/hashicorp.sources >/dev/null <<EOF
Types: deb
URIs: https://apt.releases.hashicorp.com
Suites: ${suite}
Components: main
Architectures: ${ARCH}
Signed-By: /usr/share/keyrings/hashicorp-archive-keyring.gpg
EOF
  sudo apt-get update
  apt_install terraform
fi
ok "$(terraform -version | head -1)"

# -----------------------------------------------------------------------------
# Argo CD CLI: there's no official apt package or snap, so we install the
# latest release binary from GitHub.
# `install -m 0555` copies it with read+execute permissions (no write), owned by root.
# -----------------------------------------------------------------------------
info "Argo CD CLI"
if ! have argocd; then
  tmp="$(mktemp)"
  curl -fsSL -o "${tmp}" "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${ARCH}"
  sudo install -m 0555 "${tmp}" /usr/local/bin/argocd
  rm -f "${tmp}"
fi
ok "$(argocd version --client --short 2>/dev/null | head -1)"

info "Done. Log out and back in (docker group), then run scripts/linux/03-verify.sh"
