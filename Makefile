# =============================================================================
# Makefile — one-word entry points for the Linux side of the build.
#
# Typical order on a fresh Ubuntu install:
#   make post-install   # updates, drivers, firewall, Timeshift
#   make firmware       # repeat + reboot until fwupd reports nothing left
#   make dev-tools      # DevOps toolchain
#   make verify         # PASS/WARN report
#
# The targets just call the scripts in scripts/linux/, so you can also run
# those directly. `make lint` is what CI runs (.github/workflows/lint.yml).
# =============================================================================
SHELL := /usr/bin/env bash
SCRIPTS := scripts/linux

# These targets are commands, not files, so make should always run them
.PHONY: help post-install firmware dev-tools verify lint

# Default target: running `make` with no arguments prints this list
help:
	@echo "make post-install  updates, NVIDIA, fwupd check, ufw, base packages, Timeshift"
	@echo "make firmware      same as post-install but also applies fwupd updates"
	@echo "make dev-tools     VS Code, Docker, Azure CLI, Bicep, kubectl, Terraform, Helm, Argo CD, pwsh, gh"
	@echo "make verify        PASS/WARN health report"
	@echo "make lint          shellcheck + YAML parse"

post-install:
	bash $(SCRIPTS)/01-post-install.sh

# Applies Secure Boot key and firmware updates. Reboot afterwards and run it
# again: the new 2023 KEK unlocks a newer dbx update.
firmware:
	bash $(SCRIPTS)/01-post-install.sh --apply-firmware

dev-tools:
	bash $(SCRIPTS)/02-dev-tools.sh

# sudo -v first, so the firewall/Timeshift checks can read root-only state without prompting
verify:
	sudo -v && bash $(SCRIPTS)/03-verify.sh

# Static checks: shellcheck for bash (-x follows the `source lib.sh` lines), and a
# YAML parse so a typo in the autoinstall file or the CI workflow is caught before use
lint:
	shellcheck -x $(SCRIPTS)/*.sh
	python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]; print('yaml ok')" autoinstall/autoinstall.yaml .github/workflows/lint.yml
