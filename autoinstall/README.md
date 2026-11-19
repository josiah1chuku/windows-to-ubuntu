# Autoinstall (optional)

`autoinstall.yaml` repeats the install choices in [docs/03-install.md](../docs/03-install.md): US keyboard, America/Chicago, LVM + LUKS, NVIDIA drivers and codecs, all updates. It also enables `ufw`.

It still **asks for the account and disk/encryption screens**, so no passwords are stored here.

## Use it

1. Write the Ubuntu 26.04.1 ISO to a USB stick (Rufus, as in step 03).
2. Copy `autoinstall.yaml` to a second USB stick or a web server you can reach.
3. In the installer, on **Type of installation**, choose **Automated with autoinstall file** and point it at the file.

## Fully unattended

Copy it to `autoinstall/<name>.local.yaml` (git-ignored). Remove `interactive-sections` and fill in the commented `identity` and `storage.layout.password` blocks. Make the password hash with `mkpasswd -m sha-512` (package `whois`).

> This is a template. It hasn't been run end to end on this machine yet, and it **erases the disk**.

After the install, run `make post-install` and `make dev-tools` from this repo.
