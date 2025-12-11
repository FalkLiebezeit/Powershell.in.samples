<#
.SYNOPSIS
    Testet einen Netzwerkdrucker und löst einen Testdruck aus

.DESCRIPTION
    Prüft die Netzwerkverbindung zu einem Drucker und sendet eine Testseite

.PARAMETER PrinterIP
    IP-Adresse des Netzwerkdruckers

.PARAMETER PrinterName
    Name für den temporären Drucker (optional)

.EXAMPLE
    .\03-TestNetworkPrinter.ps1 -PrinterIP "10.24.1.197"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$PrinterIP = "10.24.1.197",
    
    [Parameter(Mandatory=$false)]
    [string]$PrinterName = "TestDrucker_$PrinterIP"
)

Write-Host "=== NETZWERKDRUCKER TEST ===" -ForegroundColor Cyan
Write-Host "Drucker-IP: $PrinterIP"
Write-Host "Zeitstempel: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
Write-Host ""

# Schritt 1: Netzwerkverbindung testen
Write-Host "--- Schritt 1: Netzwerkverbindung testen ---" -ForegroundColor Yellow
try {
    $PingResult = Test-Connection -ComputerName $PrinterIP -Count 3 -ErrorAction Stop
    $AvgResponseTime = ($PingResult | Measure-Object -Property ResponseTime -Average).Average
    
    Write-Host "✓ Drucker ist erreichbar" -ForegroundColor Green
    Write-Host "  Erfolgreiche Pings: $($PingResult.Count)"
    Write-Host "  Durchschnittliche Antwortzeit: $([math]::Round($AvgResponseTime, 2)) ms"
}
catch {
    Write-Host "✗ Drucker ist nicht erreichbar!" -ForegroundColor Red
    Write-Host "  Fehler: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nBitte überprüfen Sie:"
    Write-Host "  - IP-Adresse korrekt: $PrinterIP"
    Write-Host "  - Drucker ist eingeschaltet"
    Write-Host "  - Netzwerkverbindung aktiv"
    Write-Host "  - Firewall lässt ICMP-Pakete zu"
    exit 1
}

# Schritt 2: Port 9100 testen (Standard Raw TCP/IP Port für Drucker)
Write-Host "`n--- Schritt 2: Druckerport testen ---" -ForegroundColor Yellow
try {
    $TcpClient = New-Object System.Net.Sockets.TcpClient
    $Connect = $TcpClient.BeginConnect($PrinterIP, 9100, $null, $null)
    $Wait = $Connect.AsyncWaitHandle.WaitOne(3000, $false)
    
    if ($Wait -and $TcpClient.Connected) {
        Write-Host "✓ Port 9100 ist offen (Raw TCP/IP Printing)" -ForegroundColor Green
        $TcpClient.Close()
    }
    else {
        Write-Host "⚠ Port 9100 antwortet nicht" -ForegroundColor Yellow
        Write-Host "  Der Drucker könnte andere Ports verwenden (IPP: 631, LPD: 515)" -ForegroundColor Yellow
        $TcpClient.Close()
    }
}
catch {
    Write-Host "⚠ Porttest fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Schritt 3: Drucker installieren oder finden
Write-Host "`n--- Schritt 3: Drucker einrichten ---" -ForegroundColor Yellow

# Prüfen ob Drucker bereits existiert
$ExistingPrinter = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue

if ($ExistingPrinter) {
    Write-Host "✓ Drucker '$PrinterName' bereits installiert" -ForegroundColor Green
}
else {
    Write-Host "Installiere temporären Drucker..."
    
    try {
        # Versuche Standard-Treiber zu verwenden
        $DriverName = "Generic / Text Only"
        
        # Erstelle TCP/IP Port
        $PortName = "IP_$PrinterIP"
        $ExistingPort = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
        
        if (-not $ExistingPort) {
            Add-PrinterPort -Name $PortName -PrinterHostAddress $PrinterIP -ErrorAction Stop
            Write-Host "✓ Druckerport erstellt: $PortName" -ForegroundColor Green
        }
        else {
            Write-Host "✓ Druckerport existiert bereits: $PortName" -ForegroundColor Green
        }
        
        # Drucker hinzufügen
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop
        Write-Host "✓ Drucker '$PrinterName' installiert" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Fehler beim Installieren des Druckers: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nAlternative: Manuelle Druckerinstallation erforderlich" -ForegroundColor Yellow
        Write-Host "1. Öffnen Sie Einstellungen → Drucker & Scanner"
        Write-Host "2. Fügen Sie den Drucker mit IP $PrinterIP hinzu"
        exit 1
    }
}

# Schritt 4: Druckerstatus prüfen
Write-Host "`n--- Schritt 4: Druckerstatus prüfen ---" -ForegroundColor Yellow
try {
    $Printer = Get-Printer -Name $PrinterName -ErrorAction Stop
    Write-Host "Status: $($Printer.PrinterStatus)"
    Write-Host "Bereit: $($Printer.PrinterStatus -eq 'Normal' -or $Printer.PrinterStatus -eq 'Idle')"
    
    if ($Printer.JobCount -gt 0) {
        Write-Host "⚠ Druckaufträge in Warteschlange: $($Printer.JobCount)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠ Konnte Druckerstatus nicht abrufen" -ForegroundColor Yellow
}

# Schritt 5: Testseite drucken
Write-Host "`n--- Schritt 5: Testdruck auslösen ---" -ForegroundColor Yellow

$Continue = Read-Host "Möchten Sie eine Testseite drucken? (J/N)"

if ($Continue -eq "J" -or $Continue -eq "j") {
    try {
        # Testseite über Drucker-Eigenschaften
        $PrinterObject = Get-CimInstance -ClassName Win32_Printer -Filter "Name='$($PrinterName.Replace('\','\\'))'"
        
        if ($PrinterObject) {
            $Result = Invoke-CimMethod -InputObject $PrinterObject -MethodName PrintTestPage
            
            if ($Result.ReturnValue -eq 0) {
                Write-Host "✓ Testseite wurde an den Drucker gesendet!" -ForegroundColor Green
            }
            else {
                Write-Host "⚠ Testseite konnte nicht gesendet werden (Code: $($Result.ReturnValue))" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "⚠ Drucker-Objekt nicht gefunden für WMI-Methode" -ForegroundColor Yellow
            
            # Alternative: Textdatei drucken
            Write-Host "`nAlternative: Erstelle Text-Testseite..." -ForegroundColor Cyan
            $TempFile = Join-Path $env:TEMP "DruckerTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            
            $TestContent = @"
═══════════════════════════════════════════
        DRUCKER TESTSEITE
═══════════════════════════════════════════

Drucker-IP:    $PrinterIP
Druckername:   $PrinterName
Zeitstempel:   $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
Computer:      $env:COMPUTERNAME
Benutzer:      $env:USERNAME

═══════════════════════════════════════════
Status:        Test erfolgreich gesendet
═══════════════════════════════════════════
"@
            
            Set-Content -Path $TempFile -Value $TestContent -Encoding UTF8
            Start-Process -FilePath $TempFile -Verb Print -Wait
            
            Write-Host "✓ Testdatei erstellt und an Drucker gesendet: $TempFile" -ForegroundColor Green
            Start-Sleep -Seconds 2
            Remove-Item $TempFile -ErrorAction SilentlyContinue
        }
        
        Write-Host "`nBitte überprüfen Sie den Drucker auf die Testseite."
    }
    catch {
        Write-Host "✗ Fehler beim Drucken: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "Testdruck übersprungen." -ForegroundColor Gray
}

# Schritt 6: Aufräumen (optional)
Write-Host "`n--- Schritt 6: Aufräumen ---" -ForegroundColor Yellow
$Cleanup = Read-Host "Möchten Sie den Test-Drucker entfernen? (J/N)"

if ($Cleanup -eq "J" -or $Cleanup -eq "j") {
    try {
        Remove-Printer -Name $PrinterName -ErrorAction Stop
        Write-Host "✓ Drucker '$PrinterName' entfernt" -ForegroundColor Green
        
        # Port entfernen (optional)
        $RemovePort = Read-Host "Auch den Druckerport entfernen? (J/N)"
        if ($RemovePort -eq "J" -or $RemovePort -eq "j") {
            $PortName = "IP_$PrinterIP"
            Remove-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
            Write-Host "✓ Druckerport entfernt" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠ Fehler beim Entfernen: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== TEST ABGESCHLOSSEN ===" -ForegroundColor Cyan
Write-Host "Zusammenfassung:"
Write-Host "  - Netzwerkverbindung: ✓"
Write-Host "  - Drucker-IP: $PrinterIP"
Write-Host "  - Druckername: $PrinterName"
