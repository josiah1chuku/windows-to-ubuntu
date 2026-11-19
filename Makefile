SHELL := /usr/bin/env bash
SCRIPTS := scripts/linux

.PHONY: help post-install firmware dev-tools verify lint

help:
	@echo "make post-install  updates, NVIDIA, fwupd check, ufw, base packages, Timeshift"
	@echo "make firmware      same as post-install but also applies fwupd updates"
	@echo "make dev-tools     VS Code, Docker, Azure CLI, Bicep, kubectl, Terraform, Helm, Argo CD, pwsh, gh"
	@echo "make verify        PASS/WARN health report"
	@echo "make lint          shellcheck + YAML parse"

post-install:
	bash $(SCRIPTS)/01-post-install.sh

firmware:
	bash $(SCRIPTS)/01-post-install.sh --apply-firmware

dev-tools:
	bash $(SCRIPTS)/02-dev-tools.sh

verify:
	sudo -v && bash $(SCRIPTS)/03-verify.sh

lint:
	shellcheck -x $(SCRIPTS)/*.sh
	python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]; print('yaml ok')" autoinstall/autoinstall.yaml .github/workflows/lint.yml
