#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Installs Dell Command | Update and applies BIOS + firmware updates only.

.DESCRIPTION
  Step 5 of the Windows prechecks (docs/01-windows-prechecks.md).

  Why update the BIOS from Windows before installing Ubuntu?
    - Firmware lives on the motherboard, so the update survives wiping Windows.
    - Dell's own Windows tool is the most reliable way to flash a BIOS on a
      machine you've just received. On the real run it found an "Urgent" BIOS
      update (1.46.0).
    - Later updates can come through fwupd on Ubuntu.

  Only "bios" and "firmware" updates are applied. Windows drivers and apps are
  skipped because Windows is about to be removed.

.PARAMETER ScanOnly
  List the available BIOS/firmware updates without installing them.

.NOTES
  - Keep the charger plugged in; Dell refuses to flash on battery alone.
  - dcu-cli exit code 1 = "reboot required". It's not an error.
  - DCU 5.x installs to "Program Files (x86)", not "Program Files". The
    script checks both paths.
#>
param([switch]$ScanOnly)
$ErrorActionPreference = 'Stop'

# A BIOS change is measured by the TPM. With BitLocker on, the next boot asks
# for the recovery key. dcu-cli can suspend BitLocker for the flash
# (-autoSuspendBitLocker below), but turning encryption off first is safer:
# on the real run, BIOS setting changes triggered the recovery screen.
$bl = (Get-BitLockerVolume -MountPoint C: -ErrorAction SilentlyContinue).ProtectionStatus
if ($bl -eq 'On') {
  Write-Warning 'BitLocker is ON. dcu-cli will suspend it for the BIOS flash, but turning device encryption off first avoids recovery prompts.'
}

# Installs DCU, or upgrades it if it's already there. The flags skip the interactive licence prompts.
winget install --id Dell.CommandUpdate -e --accept-package-agreements --accept-source-agreements

# Find dcu-cli.exe in either install location; use the first one that exists
$dcu = @(
  "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe",
  "$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dcu) { throw 'dcu-cli.exe not found after install' }
Write-Host "Using $dcu"

# Scan: lists applicable BIOS/firmware updates for this exact model and configuration
& $dcu /scan -updateType=bios,firmware
if ($ScanOnly) { return }

# Apply: downloads and stages the update; the actual flash happens during the reboot.
#   -autoSuspendBitLocker=enable  pause BitLocker for one boot so the flash doesn't trigger recovery
#   -reboot=enable                restart automatically when staging is done
& $dcu /applyUpdates -updateType=bios,firmware -autoSuspendBitLocker=enable -reboot=enable

# Turn dcu-cli's exit code into a readable message
switch ($LASTEXITCODE) {
  0 { Write-Host 'Updates applied.' }
  1 { Write-Host 'Reboot required. If it does not restart on its own: shutdown /r /t 0' }
  500 { Write-Host 'No applicable updates.' }
  default { Write-Warning "dcu-cli exit code $LASTEXITCODE" }
}
# After the reboot, confirm with: (Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion
