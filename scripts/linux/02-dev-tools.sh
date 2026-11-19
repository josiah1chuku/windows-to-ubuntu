#!/usr/bin/env bash
# DevOps toolchain for Ubuntu 26.04 (works on 24.04 too). Safe to re-run.

# shellcheck source=scripts/linux/lib.sh
source "$(dirname "$(readlink -f "$0")")/lib.sh"

require_normal_user
ARCH="$(dpkg --print-architecture)"
sudo install -m 0755 -d /etc/apt/keyrings
apt_install ca-certificates curl gnupg jq

# ---------- snaps ----------
info "Snaps: VS Code, PowerShell, Helm"
have code || sudo snap install code --classic
have pwsh || sudo snap install powershell --classic
have helm || sudo snap install helm --classic
ok "snaps present"

# ---------- GitHub CLI ----------
info "GitHub CLI"
have gh || apt_install gh
ok "$(gh --version | head -1)"

# ---------- Docker ----------
info "Docker Engine"
if ! have docker; then
  sudo apt-get remove -y docker.io docker-compose docker-doc podman-docker containerd runc 2>/dev/null || true
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  suite="$(pick_codename https://download.docker.com/linux/ubuntu)"
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
if ! id -nG "${USER}" | grep -qw docker; then
  sudo usermod -aG docker "${USER}"
  warn "Added ${USER} to the docker group. Log out and back in before using docker without sudo."
fi
ok "$(docker --version)"

# ---------- Azure CLI ----------
info "Azure CLI"
if ! have az; then
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

info "Bicep (per user)"
az bicep install >/dev/null 2>&1 || az bicep upgrade >/dev/null 2>&1 || warn "bicep install failed"
ok "$(az bicep version 2>/dev/null | head -1)"

info "kubectl + kubelogin"
if ! have kubectl || ! have kubelogin; then
  sudo az aks install-cli
fi
ok "$(kubectl version --client 2>/dev/null | head -1)"

# ---------- Terraform ----------
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

# ---------- Argo CD CLI ----------
info "Argo CD CLI"
if ! have argocd; then
  tmp="$(mktemp)"
  curl -fsSL -o "${tmp}" "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${ARCH}"
  sudo install -m 0555 "${tmp}" /usr/local/bin/argocd
  rm -f "${tmp}"
fi
ok "$(argocd version --client --short 2>/dev/null | head -1)"

info "Done. Log out and back in (docker group), then run scripts/linux/03-verify.sh"
