<#
.SYNOPSIS
    Systemdiagnose für grundlegende Gesundheitschecks unter Windows/PowerShell.
    (Für Ubuntu-Checks via SSH oder WSL siehe Kommentar im Code.)
#>

# -----------------------------
# Hilfsfunktion für Ausgabe
# -----------------------------
function Write-Section {
    param([string]$Title)
    Write-Host "`n==== $Title ====" -ForegroundColor Cyan
}

# -----------------------------
# 1. Systemlogs prüfen
# -----------------------------
function Check-SystemLogs {
    Write-Section "Systemlogs (Fehler & Warnungen)"

    Get-WinEvent -LogName System -MaxEvents 200 |
        Where-Object { $_.LevelDisplayName -in "Error","Warning" } |
        Select-Object TimeCreated, LevelDisplayName, Id, Message |
        Format-Table -AutoSize
}

# -----------------------------
# 2. CPU / RAM / Load
# -----------------------------
function Check-Performance {
    Write-Section "CPU / RAM / Load"

    $cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage
    $ram = Get-CimInstance Win32_OperatingSystem

    [PSCustomObject]@{
        CPU_Load_Percent = $cpu
        RAM_Total_GB     = "{0:N2}" -f ($ram.TotalVisibleMemorySize/1MB)
        RAM_Free_GB      = "{0:N2}" -f ($ram.FreePhysicalMemory/1MB)
        RAM_Used_GB      = "{0:N2}" -f (($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory)/1MB)
    } | Format-List
}

# -----------------------------
# 3. Festplattenplatz
# -----------------------------
function Check-DiskSpace {
    Write-Section "Festplattenplatz"

    Get-PSDrive -PSProvider FileSystem |
        Select-Object Name, @{N="Used(GB)";E={[math]::Round(($_.Used/1GB),2)}},
                      @{N="Free(GB)";E={[math]::Round(($_.Free/1GB),2)}},
                      @{N="Free(%)";E={[math]::Round(($_.Free/($_.Used+$_.Free)*100),1)}} |
        Format-Table -AutoSize
}

# -----------------------------
# 4. SMART-Status (falls smartctl vorhanden)
# -----------------------------
function Check-SMART {
    Write-Section "SMART-Status"

    $smartctl = Get-Command smartctl -ErrorAction SilentlyContinue
    if (-not $smartctl) {
        Write-Host "smartctl nicht gefunden. Installiere smartmontools für SMART-Checks." -ForegroundColor Yellow
        return
    }

    $disks = Get-WmiObject Win32_DiskDrive | Select-Object -ExpandProperty DeviceID
    foreach ($disk in $disks) {
        Write-Host "`n--- $disk ---"
        smartctl -H $disk
    }
}

# -----------------------------
# 5. Netzwerk
# -----------------------------
function Check-Network {
    Write-Section "Netzwerk"

    Write-Host "Ping 8.8.8.8:"
    ping 8.8.8.8 -n 4

    Write-Host "`nPing google.com (DNS-Test):"
    ping google.com -n 4

    Write-Host "`nDNS-Server:"
    Get-DnsClientServerAddress | Format-Table -AutoSize
}

# -----------------------------
# 6. Dienste
# -----------------------------
function Check-Services {
    Write-Section "Fehlerhafte Dienste"

    Get-Service | Where-Object { $_.Status -eq "Stopped" -and $_.StartType -eq "Automatic" } |
        Select-Object Name, DisplayName, Status |
        Format-Table -AutoSize
}

# -----------------------------
# 7. Boot-/Shutdown-Fehler
# -----------------------------
function Check-BootEvents {
    Write-Section "Boot- & Shutdown-Fehler"

    Get-WinEvent -LogName System -MaxEvents 200 |
        Where-Object { $_.Id -in 6008, 41, 1074, 1076 } |
        Select-Object TimeCreated, Id, Message |
        Format-Table -AutoSize
}

# -----------------------------
# Hauptfunktion
# -----------------------------
function Run-SystemHealthCheck {
    Check-SystemLogs
    Check-Performance
    Check-DiskSpace
    Check-SMART
    Check-Network
    Check-Services
    Check-BootEvents
}

Run-SystemHealthCheck