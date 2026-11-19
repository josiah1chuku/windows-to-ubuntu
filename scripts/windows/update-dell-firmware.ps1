#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Installs Dell Command | Update and applies BIOS + firmware updates only.
.NOTES
  Keep the charger plugged in. Return code 1 from dcu-cli = reboot required (not an error).
#>
param([switch]$ScanOnly)
$ErrorActionPreference = 'Stop'

$bl = (Get-BitLockerVolume -MountPoint C: -ErrorAction SilentlyContinue).ProtectionStatus
if ($bl -eq 'On') {
  Write-Warning 'BitLocker is ON. dcu-cli will suspend it for the BIOS flash, but turning device encryption off first avoids recovery prompts.'
}

winget install --id Dell.CommandUpdate -e --accept-package-agreements --accept-source-agreements

$dcu = @(
  "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe",
  "$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $dcu) { throw 'dcu-cli.exe not found after install' }
Write-Host "Using $dcu"

& $dcu /scan -updateType=bios,firmware
if ($ScanOnly) { return }

& $dcu /applyUpdates -updateType=bios,firmware -autoSuspendBitLocker=enable -reboot=enable
switch ($LASTEXITCODE) {
  0 { Write-Host 'Updates applied.' }
  1 { Write-Host 'Reboot required. If it does not restart on its own: shutdown /r /t 0' }
  500 { Write-Host 'No applicable updates.' }
  default { Write-Warning "dcu-cli exit code $LASTEXITCODE" }
}
