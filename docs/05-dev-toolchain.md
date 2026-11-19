# 05 — DevOps toolchain

`scripts/linux/02-dev-tools.sh` installs everything below. Each tool is skipped if it's already present.

| Tool | Source | Notes |
| --- | --- | --- |
| VS Code | snap `code --classic` | |
| PowerShell | snap `powershell --classic` | `pwsh` |
| GitHub CLI | Ubuntu archive `gh` | `gh auth login` afterwards |
| Docker Engine + Buildx + Compose | download.docker.com apt repo (deb822) | Adds you to the `docker` group. Log out and back in. |
| Azure CLI | packages.microsoft.com apt repo (deb822) | |
| Bicep | `az bicep install` | Per user, in `~/.azure/bin` |
| kubectl + kubelogin | `sudo az aks install-cli` | `/usr/local/bin` |
| Terraform | apt.releases.hashicorp.com apt repo (deb822) | |
| Helm | snap `helm --classic` | |
| Argo CD CLI | GitHub release binary | `/usr/local/bin/argocd` |

## Release codename fallback

Third-party apt repos can be slow to add a new Ubuntu codename. The script checks `dists/<codename>/Release` on each repo. If `resolute` (26.04) isn't published yet, it falls back to `noble` (24.04) and tells you. Re-run the script later to switch over.

## Check

```bash
code --version; pwsh --version; gh --version
docker run --rm hello-world
az version; az bicep version
kubectl version --client; kubelogin --version
terraform -version; helm version; argocd version --client
```

Or `make verify`.
