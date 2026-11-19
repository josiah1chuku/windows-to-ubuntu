# Dell Precision 7550: Windows → Ubuntu 26.04.1 LTS

A reproducible record of replacing Windows on a refurbished Dell Precision 7550 with an encrypted Ubuntu 26.04.1 LTS install set up for DevOps work (Azure, AKS, Terraform/Bicep, GitOps).

Everything here was done for real on one machine. The docs record the steps in order, including the gotchas. The scripts repeat the parts that can be automated.

## Result

| Area | State |
| --- | --- |
| OS | Ubuntu 26.04.1 LTS, kernel 7.0 |
| Disk | Whole 512GB NVMe, LUKS + LVM (passphrase), ext4 |
| BIOS | 1.46.0, Secure Boot on, Absolute disabled, battery charge 50–80% |
| Secure Boot keys | KEK and db moved to the Microsoft 2023 CAs, dbx up to date (via `fwupd`) |
| Graphics | Intel UHD + NVIDIA Quadro T1000, proprietary driver, PRIME on-demand |
| Security | `ufw` enabled (deny incoming) |
| Recovery | Timeshift rsync snapshots on the root LV, daily ×5 + boot ×3 |

## How to reproduce

| Step | Doc | Automation |
| --- | --- | --- |
| 0. Know the hardware | [docs/00-hardware.md](docs/00-hardware.md) | none |
| 1. Checks while Windows is still on it | [docs/01-windows-prechecks.md](docs/01-windows-prechecks.md) | `scripts/windows/precheck.ps1`, `scripts/windows/update-dell-firmware.ps1` |
| 2. BIOS settings | [docs/02-bios-settings.md](docs/02-bios-settings.md) | manual (F2) |
| 3. USB stick and install | [docs/03-install.md](docs/03-install.md) | optional: [autoinstall/](autoinstall/) |
| 4. Post-install hardening | [docs/04-post-install.md](docs/04-post-install.md) | `scripts/linux/01-post-install.sh` |
| 5. DevOps toolchain | [docs/05-dev-toolchain.md](docs/05-dev-toolchain.md) | `scripts/linux/02-dev-tools.sh` |
| 6. Verify | none | `scripts/linux/03-verify.sh` |

The problems hit along the way, and their fixes, are in [docs/troubleshooting.md](docs/troubleshooting.md). The dated log of what was done is in [docs/build-log.md](docs/build-log.md).

### Quick start on a fresh install

```bash
sudo apt install -y git make
git clone https://github.com/<you>/dell-precision-7550-ubuntu.git
cd dell-precision-7550-ubuntu
make post-install   # updates, NVIDIA, firmware check, firewall, base packages, Timeshift
make dev-tools      # VS Code, Docker, Azure CLI, Bicep, kubectl, kubelogin, Terraform, Helm, Argo CD, pwsh, gh
make verify         # prints a PASS/WARN report
```

The scripts are idempotent, so you can re-run them safely. Run them as your normal user, not with `sudo`. They call `sudo` themselves when needed.

## Not in this repo (on purpose)

- The BitLocker recovery key, disk passphrase, account passwords and the machine's service tag
- Anything personal from the Windows side

If you use the autoinstall template, keep your filled-in copy as `autoinstall/*.local.yaml`, which is git-ignored.
