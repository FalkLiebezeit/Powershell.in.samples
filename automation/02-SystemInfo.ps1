<#
.SYNOPSIS
    Systeminformationen sammeln

.DESCRIPTION
    Sammelt umfassende Systeminformationen für Berichte und Monitoring
#>

Write-Host "=== SYSTEM INFORMATIONSBERICHT ===" -ForegroundColor Cyan
Write-Host "Erstellt am: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
Write-Host ""

# Computer Informationen
Write-Host "--- Computer Informationen ---" -ForegroundColor Yellow
$ComputerInfo = Get-ComputerInfo -Property CsName, CsManufacturer, CsModel, OsName, OsVersion, OsArchitecture
Write-Host "Name: $($ComputerInfo.CsName)"
Write-Host "Hersteller: $($ComputerInfo.CsManufacturer)"
Write-Host "Modell: $($ComputerInfo.CsModel)"
Write-Host "Betriebssystem: $($ComputerInfo.OsName)"
Write-Host "Version: $($ComputerInfo.OsVersion)"
Write-Host "Architektur: $($ComputerInfo.OsArchitecture)"

# CPU Informationen
Write-Host "`n--- Prozessor ---" -ForegroundColor Yellow
$CPU = Get-WmiObject Win32_Processor
Write-Host "Name: $($CPU.Name)"
Write-Host "Kerne: $($CPU.NumberOfCores)"
Write-Host "Logische Prozessoren: $($CPU.NumberOfLogicalProcessors)"
Write-Host "Max. Takt: $($CPU.MaxClockSpeed) MHz"

# Speicher Informationen
Write-Host "`n--- Arbeitsspeicher ---" -ForegroundColor Yellow
$RAM = Get-WmiObject Win32_ComputerSystem
$TotalRAM = [math]::Round($RAM.TotalPhysicalMemory / 1GB, 2)
$FreeRAM = [math]::Round((Get-WmiObject Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
$UsedRAM = [math]::Round($TotalRAM - ($FreeRAM / 1024), 2)

Write-Host "Gesamt: $TotalRAM GB"
Write-Host "Verwendet: $UsedRAM GB"
Write-Host "Frei: $([math]::Round($FreeRAM / 1024, 2)) GB"
Write-Host "Auslastung: $([math]::Round(($UsedRAM / $TotalRAM) * 100, 1))%"

# Festplatten Informationen
Write-Host "`n--- Festplatten ---" -ForegroundColor Yellow
$Disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"
foreach ($Disk in $Disks) {
    $Gesamt = [math]::Round($Disk.Size / 1GB, 2)
    $Frei = [math]::Round($Disk.FreeSpace / 1GB, 2)
    $Verwendet = $Gesamt - $Frei
    $Prozent = [math]::Round(($Verwendet / $Gesamt) * 100, 1)
    
    Write-Host "`nLaufwerk $($Disk.DeviceID)"
    Write-Host "  Gesamt: $Gesamt GB"
    Write-Host "  Verwendet: $Verwendet GB"
    Write-Host "  Frei: $Frei GB"
    Write-Host "  Auslastung: $Prozent%"
}

# Netzwerk Adapter
Write-Host "`n--- Netzwerk Adapter ---" -ForegroundColor Yellow
$NetAdapters = Get-NetAdapter | Where-Object Status -eq 'Up'
foreach ($Adapter in $NetAdapters) {
    Write-Host "`n$($Adapter.Name)"
    Write-Host "  Status: $($Adapter.Status)"
    Write-Host "  Geschwindigkeit: $($Adapter.LinkSpeed)"
    
    $IPConfig = Get-NetIPAddress -InterfaceIndex $Adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($IPConfig) {
        Write-Host "  IPv4: $($IPConfig.IPAddress)"
    }
}

# Prozessübersicht
Write-Host "`n--- Top 10 Prozesse (nach Speicher) ---" -ForegroundColor Yellow
Get-Process | 
    Sort-Object WorkingSet -Descending | 
    Select-Object -First 10 |
    ForEach-Object {
        $MemMB = [math]::Round($_.WorkingSet / 1MB, 2)
        Write-Host "  $($_.Name): $MemMB MB"
    }

# Services Status
Write-Host "`n--- Dienste Übersicht ---" -ForegroundColor Yellow
$Services = Get-Service
$Running = ($Services | Where-Object Status -eq 'Running').Count
$Stopped = ($Services | Where-Object Status -eq 'Stopped').Count
Write-Host "Laufend: $Running"
Write-Host "Gestoppt: $Stopped"
Write-Host "Gesamt: $($Services.Count)"

# Systemlaufzeit
Write-Host "`n--- Systemlaufzeit ---" -ForegroundColor Yellow
$OS = Get-WmiObject Win32_OperatingSystem
$Uptime = (Get-Date) - $OS.ConvertToDateTime($OS.LastBootUpTime)
Write-Host "Letzter Start: $($OS.ConvertToDateTime($OS.LastBootUpTime))"
Write-Host "Laufzeit: $([math]::Floor($Uptime.TotalDays)) Tage, $($Uptime.Hours) Stunden, $($Uptime.Minutes) Minuten"

Write-Host "`n=== BERICHT ENDE ===" -ForegroundColor Cyan
