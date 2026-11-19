#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Hardware, battery and BitLocker report for a refurbished Dell before wiping Windows.
.DESCRIPTION
  Writes laptop-check.txt and battery-report.html to the Desktop. Read-only.
#>
$ErrorActionPreference = 'Continue'
$desktop = [Environment]::GetFolderPath('Desktop')
$out = Join-Path $desktop 'laptop-check.txt'

& {
  '== System / BIOS =='
  Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model | Format-List
  Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion, ReleaseDate | Format-List
  '== CPU =='
  Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors | Format-List
  '== GPU =='
  Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion | Format-Table -AutoSize
  '== RAM =='
  Get-CimInstance Win32_PhysicalMemory |
    Select-Object BankLabel, @{n='GB';e={$_.Capacity/1GB}}, Speed, Manufacturer, PartNumber | Format-Table -AutoSize
  '== Disks =='
  Get-PhysicalDisk | Select-Object FriendlyName, BusType, MediaType, @{n='GB';e={[int]($_.Size/1GB)}}, HealthStatus | Format-Table -AutoSize
  '== Disk wear =='
  Get-PhysicalDisk | Get-StorageReliabilityCounter |
    Select-Object Wear, Temperature, PowerOnHours, ReadErrorsTotal, WriteErrorsTotal | Format-Table -AutoSize
  '== Storage controller (want NVMe/AHCI, not RST/RAID) =='
  Get-PnpDevice -PresentOnly -Class SCSIAdapter, HDC | Select-Object FriendlyName, Status | Format-Table -AutoSize
  '== Devices with problems =='
  Get-PnpDevice -PresentOnly | Where-Object Status -ne 'OK' | Select-Object FriendlyName, Class, Status | Format-Table -AutoSize
  '== Wi-Fi =='
  netsh wlan show drivers | Select-String 'Description|Driver|Vendor'
  '== BitLocker (turn OFF before BIOS changes) =='
  manage-bde -status C:
} *>&1 | Out-File -FilePath $out -Encoding utf8

powercfg /batteryreport /output (Join-Path $desktop 'battery-report.html') | Out-Null
Write-Host "Written: $out and battery-report.html on the Desktop"
Write-Host "Battery: compare Design Capacity with Full Charge Capacity (below ~80% is worth raising)."
