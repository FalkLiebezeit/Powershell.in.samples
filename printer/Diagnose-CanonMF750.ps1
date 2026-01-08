<#
.SYNOPSIS
    Umfangreiche Diagnose für Canon I-Sensys MF750C Series Netzwerkdrucker

.DESCRIPTION
    Prüft Netzwerk, Ports, SNMP, IPP, Webinterface, Druckwarteschlangen
    und liefert strukturierte Ergebnisse + Logfile.

.PARAMETER PrinterIP
    IP-Adresse des Druckers

.PARAMETER LogPath
    Pfad für Logdatei

.EXAMPLE

    & ".\printer\Diagnose-CanonMF750.ps1" -PrinterIP 10.24.10.212
    
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$PrinterIP,

    [string]$LogPath = ".\CanonMF750_Diagnose_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# -------------------------------
# Hilfsfunktion: Logging
# -------------------------------
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp  $Message"
    Write-Output $line
    Add-Content -Path $LogPath -Value $line
}

Write-Log "=== Diagnose gestartet für Canon MF750C @ $PrinterIP ==="

# -------------------------------
# 1. Ping-Test
# -------------------------------
Write-Log "Starte Ping-Test..."
$ping = Test-Connection -ComputerName $PrinterIP -Count 4 -ErrorAction SilentlyContinue
if ($ping) {
    Write-Log "Ping erfolgreich. Durchschnittliche Antwortzeit: $($ping | Measure-Object -Property ResponseTime -Average | Select -ExpandProperty Average) ms"
} else {
    Write-Log "Ping fehlgeschlagen! Drucker nicht erreichbar."
}

# -------------------------------
# 2. ARP-Eintrag prüfen
# -------------------------------
Write-Log "Prüfe ARP-Eintrag..."
$arp = arp -a | Select-String $PrinterIP
if ($arp) {
    Write-Log "ARP-Eintrag gefunden: $arp"
} else {
    Write-Log "Kein ARP-Eintrag gefunden."
}

# -------------------------------
# 3. Port-Checks (RAW, LPD, IPP, HTTPS)
# -------------------------------
$ports = @{
    "RAW 9100" = 9100
    "LPD 515"  = 515
    "IPP 631"  = 631
    "HTTP 80"  = 80
    "HTTPS 443" = 443
}

Write-Log "Starte Port-Checks..."
foreach ($p in $ports.GetEnumerator()) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($PrinterIP, $p.Value, $null, $null)
        $success = $iar.AsyncWaitHandle.WaitOne(500)
        if ($success -and $tcp.Connected) {
            Write-Log "Port offen: $($p.Key)"
        } else {
            Write-Log "Port geschlossen oder blockiert: $($p.Key)"
        }
        $tcp.Close()
    } catch {
        Write-Log "Fehler beim Prüfen von Port $($p.Key): $_"
    }
}

# -------------------------------
# 4. SNMP-Abfrage (falls aktiviert)
# -------------------------------
Write-Log "SNMP-Abfrage (sysDescr)..."
try {
    $snmp = snmpget -v2c -c public $PrinterIP 1.3.6.1.2.1.1.1.0 2>$null
    if ($snmp) {
        Write-Log "SNMP Antwort: $snmp"
    } else {
        Write-Log "Keine SNMP-Antwort. SNMP evtl. deaktiviert."
    }
} catch {
    Write-Log "SNMP-Tool nicht verfügbar oder Fehler: $_"
}

# -------------------------------
# 5. Webinterface testen
# -------------------------------
Write-Log "Teste Webinterface..."
try {
    $web = Invoke-WebRequest -Uri "http://$PrinterIP" -UseBasicParsing -TimeoutSec 5
    Write-Log "Webinterface erreichbar. HTTP Status: $($web.StatusCode)"
} catch {
    Write-Log "Webinterface nicht erreichbar: $_"
}

# -------------------------------
# 6. IPP-Druckerstatus (falls unterstützt)
# -------------------------------
Write-Log "Prüfe IPP-Druckerstatus..."
try {
    $ipp = Invoke-WebRequest -Uri "http://$PrinterIP:631/printers" -UseBasicParsing -TimeoutSec 5
    Write-Log "IPP erreichbar."
} catch {
    Write-Log "IPP nicht erreichbar oder nicht aktiviert."
}

# -------------------------------
# 7. Lokale Druckwarteschlangen prüfen
# -------------------------------
Write-Log "Prüfe lokale Druckwarteschlangen..."
$queues = Get-Printer | Where-Object { $_.PortName -match $PrinterIP }
if ($queues) {
    foreach ($q in $queues) {
        Write-Log "Gefundene Queue: $($q.Name) | Status: $($q.PrinterStatus)"
    }
} else {
    Write-Log "Keine lokale Queue für diesen Drucker gefunden."
}

# -------------------------------
# 8. Testseite vorbereiten (nicht drucken)
# -------------------------------
Write-Log "Erzeuge Testseite (nur Simulation)..."
$testPage = @"
Canon MF750C Diagnose-Testseite
Erstellt: $(Get-Date)
Client: $env:COMPUTERNAME
"@

Write-Log "Testseite erzeugt (nicht gesendet)."

# -------------------------------
# Abschluss
# -------------------------------
Write-Log "=== Diagnose abgeschlossen ==="
Write-Output "Diagnose abgeschlossen. Logfile: $LogPath"