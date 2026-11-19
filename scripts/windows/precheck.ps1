#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Hardware, battery and BitLocker report for a refurbished Dell, run BEFORE wiping Windows.

.DESCRIPTION
  Step 1 of the Windows-to-Ubuntu build (docs/01-windows-prechecks.md).

  A refurb should be checked against its listing while Windows is still on it.
  A faulty part is much easier to return before the OS has been replaced.

  The report answers:
    - Is the hardware what was advertised?  (CPU, GPU, RAM, disk vs Dell's original configuration)
    - Is anything failing?                  (disk wear/errors, devices with driver problems, battery capacity)
    - Will Ubuntu see the disk?             (storage controller must be NVMe/AHCI, not Intel RST/RAID)
    - Is BitLocker on?                      (it must be turned OFF before BIOS changes, or the next
                                             boot asks for the recovery key; this happened on the real run)

  Output (read-only, nothing is changed):
    Desktop\laptop-check.txt       the report
    Desktop\battery-report.html    Windows' own battery health report

.NOTES
  Run in an elevated PowerShell. manage-bde and some CIM queries need admin rights.
#>

# Keep going if one query fails; a partial report is still useful
$ErrorActionPreference = 'Continue'
$desktop = [Environment]::GetFolderPath('Desktop')
$out = Join-Path $desktop 'laptop-check.txt'

# Everything inside & { } goes to one file. *>&1 merges all output streams
# (including warnings and errors) so nothing is silently dropped.
& {
  '== System / BIOS =='
  # Model + BIOS version: confirm it's the expected machine and record the BIOS before updating it
  Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model | Format-List
  Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion, ReleaseDate | Format-List

  '== CPU =='
  Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors | Format-List

  '== GPU =='
  # Expect Intel UHD + the NVIDIA card; a missing dGPU usually means a swapped motherboard
  Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion | Format-Table -AutoSize

  '== RAM =='
  # Per-stick detail shows mismatched or downgraded modules
  Get-CimInstance Win32_PhysicalMemory |
    Select-Object BankLabel, @{n='GB';e={$_.Capacity/1GB}}, Speed, Manufacturer, PartNumber | Format-Table -AutoSize

  '== Disks =='
  Get-PhysicalDisk | Select-Object FriendlyName, BusType, MediaType, @{n='GB';e={[int]($_.Size/1GB)}}, HealthStatus | Format-Table -AutoSize

  '== Disk wear =='
  # SMART-style counters: Wear (% of rated life used), power-on hours and error totals
  Get-PhysicalDisk | Get-StorageReliabilityCounter |
    Select-Object Wear, Temperature, PowerOnHours, ReadErrorsTotal, WriteErrorsTotal | Format-Table -AutoSize

  '== Storage controller (want NVMe/AHCI, not RST/RAID) =='
  # "Standard NVM Express Controller" = good. "Intel RST"/"RAID" = switch to AHCI in the BIOS
  # first, otherwise the Ubuntu installer can't see the drive.
  Get-PnpDevice -PresentOnly -Class SCSIAdapter, HDC | Select-Object FriendlyName, Status | Format-Table -AutoSize

  '== Devices with problems =='
  # Anything not "OK" = the yellow warning icons in Device Manager
  Get-PnpDevice -PresentOnly | Where-Object Status -ne 'OK' | Select-Object FriendlyName, Class, Status | Format-Table -AutoSize

  '== Wi-Fi =='
  netsh wlan show drivers | Select-String 'Description|Driver|Vendor'

  '== BitLocker (turn OFF before BIOS changes) =='
  # Want: "Fully Decrypted" / "Protection Off" before touching the BIOS
  manage-bde -status C:
} *>&1 | Out-File -FilePath $out -Encoding utf8

# Windows' built-in battery report. The key numbers are Design Capacity vs
# Full Charge Capacity: below ~80% means a worn battery, worth raising with the seller.
powercfg /batteryreport /output (Join-Path $desktop 'battery-report.html') | Out-Null

Write-Host "Written: $out and battery-report.html on the Desktop"
Write-Host "Battery: compare Design Capacity with Full Charge Capacity (below ~80% is worth raising)."
