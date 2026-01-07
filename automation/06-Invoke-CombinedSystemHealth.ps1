<#
.SYNOPSIS
    Kombinierte Systemdiagnose für Windows (lokal) und Ubuntu (remote via SSH).
    Entwickelt für methodische, modulare Fehlersuche.

    .\automation\06-Invoke-CombinedSystemHealth.ps1 -UbuntuHost "10.24.10.146" -UbuntuUser "momox"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$UbuntuHost,

    [Parameter(Mandatory=$true)]
    [string]$UbuntuUser,

    [Parameter(Mandatory=$false)]
    [int]$SSHPort = 22
)

# ============================================================
# Hilfsfunktion für Abschnittsüberschriften
# ============================================================
function Write-Section {
    param([string]$Title)
    Write-Host "`n==== $Title ====" -ForegroundColor Cyan
}

# ============================================================
# Verbindungsprüfung
# ============================================================
function Test-SSHConnection {
    Write-Host "Prüfe SSH-Verbindung zu $UbuntuUser@$UbuntuHost..." -ForegroundColor Yellow
    
    # Prüfe ob Host erreichbar ist
    if (-not (Test-Connection -ComputerName $UbuntuHost -Count 2 -Quiet)) {
        Write-Host "FEHLER: Host $UbuntuHost ist nicht erreichbar (Ping fehlgeschlagen)" -ForegroundColor Red
        return $false
    }
    Write-Host "✓ Host ist erreichbar (Ping erfolgreich)" -ForegroundColor Green
    
    # Prüfe ob SSH verfügbar ist
    $sshTest = Get-Command ssh -ErrorAction SilentlyContinue
    if (-not $sshTest) {
        Write-Host "FEHLER: SSH-Client nicht gefunden. Bitte OpenSSH installieren." -ForegroundColor Red
        return $false
    }
    Write-Host "✓ SSH-Client gefunden" -ForegroundColor Green
    
    # Teste SSH-Verbindung mit Timeout (ohne BatchMode, erlaubt Passwort-Eingabe)
    Write-Host "Teste SSH-Port und -Dienst..." -ForegroundColor Yellow
    
    # Prüfe nur ob SSH-Port erreichbar ist (ohne Authentifizierung)
    $portTest = Test-NetConnection -ComputerName $UbuntuHost -Port $SSHPort -WarningAction SilentlyContinue -InformationLevel Quiet
    
    if ($portTest) {
        Write-Host "✓ SSH-Port $SSHPort ist offen und erreichbar" -ForegroundColor Green
        
        # Teste ob SSH-Keys eingerichtet sind (optional)
        Write-Host "Prüfe SSH-Key-Authentifizierung..." -ForegroundColor Yellow
        $keyTest = ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no -p $SSHPort "$UbuntuUser@$UbuntuHost" "echo 'SSH_OK'" 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $keyTest -eq "SSH_OK") {
            Write-Host "✓ SSH-Keys sind eingerichtet - keine Passwortabfrage nötig" -ForegroundColor Green
        } else {
            Write-Host "ℹ SSH-Keys nicht eingerichtet - Passwort wird bei jeder Verbindung abgefragt" -ForegroundColor Yellow
            Write-Host "  Optional: Richte SSH-Keys ein mit: ssh-copy-id $UbuntuUser@$UbuntuHost" -ForegroundColor Cyan
        }
        return $true
    } else {
        Write-Host "✗ FEHLER: SSH-Port ist nicht erreichbar!" -ForegroundColor Red
        Write-Host "  Mögliche Ursachen:" -ForegroundColor Yellow
        Write-Host "  - Port $SSHPort ist blockiert (Firewall)" -ForegroundColor Yellow
        Write-Host "  - SSH-Dienst läuft nicht auf dem Ubuntu-System" -ForegroundColor Yellow
        Write-Host "  - Falsche IP-Adresse: $UbuntuHost" -ForegroundColor Yellow
        Write-Host "`nVersuche manuelle Verbindung mit: ssh -p $SSHPort $UbuntuUser@$UbuntuHost" -ForegroundColor Cyan
        return $false
    }
}

# ============================================================
# SSH Wrapper mit Fehlerbehandlung
# ============================================================
function Invoke-SSH {
    param(
        [string]$Command
    )
    try {
        $result = ssh -o ConnectTimeout=10 -p $SSHPort "$UbuntuUser@$UbuntuHost" "$Command" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warnung: SSH-Befehl lieferte Exit-Code $LASTEXITCODE" -ForegroundColor Yellow
        }
        return $result
    } catch {
        Write-Host "FEHLER beim Ausführen des SSH-Befehls: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================
# WINDOWS CHECKS
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
# UBUNTU CHECKS (REMOTE)
# ============================================================

function Check-UbuntuLogs {
    Write-Section "Ubuntu: Systemlogs (journalctl)"
    Invoke-SSH "journalctl -p err -b"
}

function Check-UbuntuPerformance {
    Write-Section "Ubuntu: CPU / RAM / Load"
    Invoke-SSH "echo 'CPU:'; top -bn1 | head -n 5"
    Invoke-SSH "echo 'RAM:'; free -h"
    Invoke-SSH "echo 'Load:'; uptime"
}

function Check-UbuntuDiskSpace {
    Write-Section "Ubuntu: Festplattenplatz"
    Invoke-SSH "df -h"
}

function Check-UbuntuSMART {
    Write-Section "Ubuntu: SMART-Status"
    Invoke-SSH "if command -v smartctl >/dev/null; then for d in /dev/sd?; do echo '---' \$d '---'; sudo smartctl -H \$d; done; else echo 'smartctl nicht installiert'; fi"
}

function Check-UbuntuNetwork {
    Write-Section "Ubuntu: Netzwerk"
    Invoke-SSH "echo 'Ping 8.8.8.8:'; ping -c 4 8.8.8.8"
    Invoke-SSH "echo 'Ping google.com:'; ping -c 4 google.com"
    Invoke-SSH "echo 'DNS:'; systemd-resolve --status | grep 'DNS Servers' -A2"
}

function Check-UbuntuServices {
    Write-Section "Ubuntu: Fehlerhafte Dienste"
    Invoke-SSH "systemctl --failed"
}

function Check-UbuntuBoot {
    Write-Section "Ubuntu: Boot-Fehler"
    Invoke-SSH "journalctl -b -1 -p err"
}

# ============================================================
# MASTER-FUNKTION
# ============================================================

function Run-CombinedSystemHealth {
    Write-Host "`n*** Starte kombinierte Windows → Ubuntu Diagnose ***`n" -ForegroundColor Green

    # Prüfe SSH-Verbindung zuerst
    if (-not (Test-SSHConnection)) {
        Write-Host "`n*** ABBRUCH: SSH-Verbindung konnte nicht hergestellt werden ***`n" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n=== Windows Checks ===" -ForegroundColor Magenta
    try {
        Check-WindowsSystemLogs
        Check-WindowsPerformance
        Check-WindowsDiskSpace
    } catch {
        Write-Host "FEHLER bei Windows-Checks: $_" -ForegroundColor Red
    }

    Write-Host "`n=== Ubuntu Checks ===" -ForegroundColor Magenta
    try {
        Check-UbuntuLogs
        Check-UbuntuPerformance
        Check-UbuntuDiskSpace
        Check-UbuntuSMART
        Check-UbuntuNetwork
        Check-UbuntuServices
        Check-UbuntuBoot
    } catch {
        Write-Host "FEHLER bei Ubuntu-Checks: $_" -ForegroundColor Red
    }

    Write-Host "`n*** Diagnose abgeschlossen ***`n" -ForegroundColor Green
}

Run-CombinedSystemHealth