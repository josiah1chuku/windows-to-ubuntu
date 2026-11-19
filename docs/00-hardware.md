# 00 — Hardware

A refurbished Dell Precision 7550 (ex-US government fleet), bought from Back Market in November 2026. The original factory build was confirmed against Dell's support site (service tag → *View product specs*) and Windows Device Manager. No parts had been swapped.

| Part | Spec | Ubuntu 26.04 notes |
| --- | --- | --- |
| CPU | Intel Core i5-10400H, 4C/8T, 45W | No setup needed |
| GPU | Intel UHD + NVIDIA Quadro T1000 4GB (Turing) | Proprietary driver installed by the installer, PRIME on-demand |
| RAM | 32GB DDR4 2933MHz (2×16GB) | |
| Storage | KIOXIA XG6 512GB NVMe (KXG6AZNV512G), second M.2 slot free | Controller already in NVMe/AHCI mode (no RAID) |
| Screen | 15.6" FHD 1920×1080, 60Hz, non-touch | No scaling needed |
| Wi-Fi/BT | Intel AX201, Wi-Fi 6, BT 5.1 | No setup needed |
| Battery | 68Wh, health "Excellent" in BIOS | Charge limit set in BIOS |
| Charger | 180W barrel | |
| Keyboard | US English with numpad | Installer layout: **English (US)** |
| Extras | Smart card reader, fingerprint reader (Broadcom ControlVault) | Fingerprint support on Linux not confirmed |

Dell's basic warranty had already expired (January 2025), so the reseller's warranty is what covers the machine.
