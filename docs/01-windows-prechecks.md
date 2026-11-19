# 01 — Checks while Windows is still on it

Do these before wiping Windows. A faulty part is easier to return while the OS is still the one it shipped with.

## 1. Confirm the hardware matches the listing

Run `scripts/windows/precheck.ps1` in an **admin** PowerShell. It writes `laptop-check.txt` and `battery-report.html` to the Desktop.

Or check by hand:

- **Device Manager:** Display adaptors shows Intel UHD + Quadro T1000; Disk drives shows the 512GB NVMe; Storage controllers shows **Standard NVM Express Controller** (not Intel RST/RAID). Look for yellow warning icons.
- **Settings → System → About:** CPU, 32GB RAM.
- **Service tag:** compare it with Dell's *Original Configuration* at dell.com/support.

## 2. Battery health

BIOS (F2) → General → **Battery Information**. It should show Health **Excellent**. Also check the AC adapter reads 180W.

## 3. Functional tests

Camera app · Sound Recorder · YouTube for speakers · keyboardtester.com · every USB-A/USB-C port · charging over USB-C · Wi-Fi · Bluetooth.

## 4. Turn off BitLocker before touching the BIOS

> Lesson learned: changing BIOS settings (Absolute, charge limit) caused a **BitLocker recovery** prompt on the next boot. Turn encryption off first.

Windows 11 turns on device encryption by itself when you sign in with a Microsoft account. If you do get the prompt, the key is at **aka.ms/myrecoverykey**. Match the key ID shown on screen.

```powershell
# Settings → Privacy & security → Device encryption → Off, then wait for:
manage-bde -status C:   # Conversion Status: Fully Decrypted, Protection Off
```

## 5. BIOS and firmware updates via Dell Command | Update

Run `scripts/windows/update-dell-firmware.ps1`, or by hand:

```powershell
winget install --id Dell.CommandUpdate -e
cd "C:\Program Files (x86)\Dell\CommandUpdate"     # note: (x86), not Program Files
.\dcu-cli.exe /scan -updateType=bios,firmware
.\dcu-cli.exe /applyUpdates -updateType=bios,firmware -reboot=enable
```

Return code **1** means "reboot required" and is not an error. If it doesn't restart by itself, run `shutdown /r /t 0`. After the update, check the version:

```powershell
(Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion   # 1.46.0 at the time of writing
```

## 6. Back up anything you need

Downloads, Desktop, Documents and Pictures. Edge bookmarks sync if you're signed in. The drive gets fully erased in step 03.
