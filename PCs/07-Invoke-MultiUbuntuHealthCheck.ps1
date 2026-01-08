<#
.SYNOPSIS
    Führt eine vollständige Ubuntu-Diagnose auf mehreren Servern nacheinander durch.
    Windows-Checks laufen einmal lokal, Ubuntu-Checks pro Host via SSH.
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$UbuntuHosts,   # Liste von Servern

    [Parameter(Mandatory=$true)]
    [string]$UbuntuUser,

    [Parameter(Mandatory=$false)]
    [int]$SSHPort = 22
)

# ============================================================
# Hilfsfunktionen
# ============================================================
function Write-Section {
    param([string]$Title)
    Write-Host "`n==== $Title ====" -ForegroundColor Cyan
}

function Write-HostHeader {
    param([string]$Host)
    Write-Host "`n###############################################"
    Write-Host "###   Starte Diagnose für: $Host"
    Write-Host "###############################################`n"
}

# ============================================================
# SSH Wrapper
# ============================================================
function Invoke-SSH {
    param(
        [string]$Host,
        [string]$Command
    )
    ssh -o ConnectTimeout=5 -p $SSHPort "$UbuntuUser@$Host" "$Command"
}

# ============================================================
# WINDOWS CHECKS (einmalig)
# ============================================================
function Check-WindowsSystemLogs {
    Write-Section "Windows: Systemlogs"
    Get-WinEvent -LogName System -MaxEvents 200 |
        Where-Object { $_.LevelDisplayName -in "Error","Warning" } |
        Select-Object TimeCreated, LevelDisplayName, Id, Message |
        Format-Table -AutoSize
}

function Check-WindowsPerformance {
    Write-Section "Windows: CPU / RAM"

    $cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage
    $ram = Get-CimInstance Win32_OperatingSystem

    [PSCustomObject]@{
        CPU_Load_Percent = $cpu
        RAM_Total_GB     = "{0:N2}" -f ($ram.TotalVisibleMemorySize/1MB)
        RAM_Free_GB      = "{0:N2}" -f ($ram.FreePhysicalMemory/1MB)
    } | Format-List
}

function Check-WindowsDiskSpace {
    Write-Section "Windows: Festplattenplatz"

    Get-PSDrive -PSProvider FileSystem |
        Select-Object Name,
            @{N="Used(GB)";E={[math]::Round(($_.Used/1GB),2)}},
            @{N="Free(GB)";E={[math]::Round(($_.Free/1GB),2)}},
            @{N="Free(%)";E={[math]::Round(($_.Free/($_.Used+$_.Free)*100),1)}} |
        Format-Table -AutoSize
}

# ============================================================
# UBUNTU CHECKS (pro Host)
# ============================================================
function Check-UbuntuLogs {
    param($Host)
    Write-Section "Ubuntu ($Host): Systemlogs"
    Invoke-SSH $Host "journalctl -p err -b"
}

function Check-UbuntuPerformance {
    param($Host)
    Write-Section "Ubuntu ($Host): CPU / RAM / Load"
    Invoke-SSH $Host "echo 'CPU:'; top -bn1 | head -n 5"
    Invoke-SSH $Host "echo 'RAM:'; free -h"
    Invoke-SSH $Host "echo 'Load:'; uptime"
}

function Check-UbuntuDiskSpace {
    param($Host)
    Write-Section "Ubuntu ($Host): Festplattenplatz"
    Invoke-SSH $Host "df -h"
}

function Check-UbuntuSMART {
    param($Host)
    Write-Section "Ubuntu ($Host): SMART-Status"
    Invoke-SSH $Host "if command -v smartctl >/dev/null; then for d in /dev/sd?; do echo '---' \$d '---'; sudo smartctl -H \$d; done; else echo 'smartctl nicht installiert'; fi"
}

function Check-UbuntuNetwork {
    param($Host)
    Write-Section "Ubuntu ($Host): Netzwerk"
    Invoke-SSH $Host "echo 'Ping 8.8.8.8:'; ping -c 4 8.8.8.8"
    Invoke-SSH $Host "echo 'Ping google.com:'; ping -c 4 google.com"
    Invoke-SSH $Host "echo 'DNS:'; systemd-resolve --status | grep 'DNS Servers' -A2"
}

function Check-UbuntuServices {
    param($Host)
    Write-Section "Ubuntu ($Host): Fehlerhafte Dienste"
    Invoke-SSH $Host "systemctl --failed"
}

function Check-UbuntuBoot {
    param($Host)
    Write-Section "Ubuntu ($Host): Boot-Fehler"
    Invoke-SSH $Host "journalctl -b -1 -p err"
}

# ============================================================
# MASTER-FUNKTION
# ============================================================
function Run-MultiUbuntuHealthCheck {

    Write-Host "`n*** Starte lokale Windows-Diagnose ***`n" -ForegroundColor Green
    Check-WindowsSystemLogs
    Check-WindowsPerformance
    Check-WindowsDiskSpace

    Write-Host "`n*** Starte Remote-Diagnose für Ubuntu-Server ***`n" -ForegroundColor Green

    foreach ($Host in $UbuntuHosts) {

        Write-HostHeader $Host

        try {
            # Teste SSH-Verbindung
            $test = Invoke-SSH $Host "echo OK" 2>$null
            if ($test -notmatch "OK") {
                Write-Host "SSH-Verbindung zu $Host fehlgeschlagen" -ForegroundColor Red
                continue
            }

            # Ubuntu Checks
            Check-UbuntuLogs $Host
            Check-UbuntuPerformance $Host
            Check-UbuntuDiskSpace $Host
            Check-UbuntuSMART $Host
            Check-UbuntuNetwork $Host
            Check-UbuntuServices $Host
            Check-UbuntuBoot $Host

        } catch {
            Write-Host "Fehler bei der Diagnose von $Host: $_" -ForegroundColor Red
        }
    }

    Write-Host "`n*** Multi-Server-Diagnose abgeschlossen ***`n" -ForegroundColor Green
}

Run-MultiUbuntuHealthCheck