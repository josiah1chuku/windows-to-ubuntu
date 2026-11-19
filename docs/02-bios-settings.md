# 02 — BIOS settings

Restart and tap **F2**. This unit has the classic Dell BIOS (tree menu on the left). Click **Apply** after each change. When it asks, ticking *Save as Custom User Settings* gives you a restore point.

| Setting | Menu | Value | Why |
| --- | --- | --- | --- |
| SATA Operation | System Configuration | AHCI (already NVMe here) | With RAID set, the installer can't see the drive |
| Secure Boot Enable | Secure Boot | On | Ubuntu's shim is signed, and the NVIDIA modules come pre-signed |
| Switchable Graphics | Video | On | Intel drives the panel, NVIDIA is used on demand |
| Virtualization, VT for Direct I/O | Virtualization Support | On | KVM, Docker, nested workloads |
| Primary Battery Charge Configuration | Power Management | Custom, start 50 / stop 80 | Battery longevity on a mostly plugged-in laptop |
| Fastboot | POST Behavior | Thorough | More reliable USB boot detection |
| UEFI Capsule Firmware Updates | Security | On | Needed for `fwupd` updates from Ubuntu |
| Absolute® | Security | **Disabled** | Ex-fleet machine. See below |

## Absolute (ex-fleet machines)

It was set to **Enabled**. That only means the BIOS module can load. It doesn't mean the device is enrolled in tracking. To test it:

1. Select **Disabled** → Apply → Exit.
2. Re-enter F2 and check the setting held. The BIOS can't disable it while the previous owner's Absolute service is active, so if it holds, the service isn't active.

Avoid **Permanently Disabled**, because it can't be undone.

Also check **Security → Admin Password** shows *Not set*. If an ex-fleet machine has an admin password set, go back to the seller.
