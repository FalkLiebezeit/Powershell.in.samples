<#
.SYNOPSIS
    Fragt den Status eines Zebra Netzwerkdruckers per ZPL ab

.DESCRIPTION
    Verbindet sich mit einem Zebra-Drucker über das Netzwerk und sendet ZPL-Befehle,
    um den Druckerstatus abzufragen. Das Skript gibt Informationen über:
    - Druckerstatus (Ready, Error, etc.)
    - Papier-Status
    - Farbband-Status (bei Thermodruckern)
    - Temperatur
    - Weitere Statusmeldungen

.PARAMETER PrinterIP
    IP-Adresse des Zebra-Druckers

.PARAMETER Port
    Netzwerk-Port (Standard: 9100 für RAW-Printing)

.PARAMETER Timeout
    Timeout in Sekunden für die Verbindung (Standard: 5)

.EXAMPLE
    .\Get-ZebraPrinterStatus.ps1
    Fragt den Status des Druckers unter 10.24.1.179 ab

.EXAMPLE
    .\Get-ZebraPrinterStatus.ps1 -PrinterIP "10.24.1.100"
    Fragt den Status eines Druckers unter einer anderen IP ab

.NOTES
    Author: PowerShell Samples
    Requires: Netzwerkzugriff auf den Zebra-Drucker über Port 9100
    Zebra ZPL-Befehle:
        ~HS  - Host Status Return (Standard-Status)
        ~HQES - Host Query Extended Status (Erweitert)
        ~HI  - Host Identification (Drucker-Info)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$PrinterIP = "10.24.1.179",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 9100,
    
    [Parameter(Mandatory=$false)]
    [int]$Timeout = 5
)

Write-Host "=== ZEBRA DRUCKER STATUS ABFRAGE ===" -ForegroundColor Cyan
Write-Host "Drucker IP: $PrinterIP"
Write-Host "Port: $Port"
Write-Host "Zeitstempel: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
Write-Host ""

# Schritt 1: Netzwerkverbindung testen
Write-Host "Schritt 1: Teste Netzwerkverbindung..." -ForegroundColor Yellow
try {
    $PingResult = Test-Connection -ComputerName $PrinterIP -Count 2 -ErrorAction Stop
    $AvgResponseTime = [math]::Round(($PingResult | Measure-Object -Property ResponseTime -Average).Average, 2)
    Write-Host "Drucker ist erreichbar (Durchschn. Antwortzeit: $AvgResponseTime ms)" -ForegroundColor Green
}
catch {
    Write-Host "Drucker unter $PrinterIP ist nicht erreichbar" -ForegroundColor Red
    Write-Host "Fehler: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Funktion zum Senden von ZPL-Befehlen und Empfangen der Antwort
function Send-ZPLQuery {
    param(
        [string]$IPAddress,
        [int]$Port,
        [string]$Command,
        [int]$TimeoutSeconds
    )
    
    try {
        # TCP-Client erstellen und verbinden
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        $TcpClient.ReceiveTimeout = $TimeoutSeconds * 1000
        $TcpClient.SendTimeout = $TimeoutSeconds * 1000
        $TcpClient.Connect($IPAddress, $Port)
        
        if ($TcpClient.Connected) {
            # Stream für Datenübertragung
            $Stream = $TcpClient.GetStream()
            $Writer = New-Object System.IO.StreamWriter($Stream)
            $Reader = New-Object System.IO.StreamReader($Stream)
            $Writer.AutoFlush = $true
            
            # ZPL-Befehl senden
            $Writer.WriteLine($Command)
            
            # Kurz warten, damit der Drucker antworten kann
            Start-Sleep -Milliseconds 300
            
            # Antwort lesen
            $Response = ""
            while ($Stream.DataAvailable) {
                $Response += $Reader.ReadLine() + "`n"
            }
            
            # Ressourcen freigeben
            $Reader.Close()
            $Writer.Close()
            $Stream.Close()
            $TcpClient.Close()
            
            return $Response
        }
        else {
            throw "Verbindung zum Drucker konnte nicht hergestellt werden"
        }
    }
    catch {
        if ($TcpClient) {
            $TcpClient.Close()
        }
        throw $_.Exception.Message
    }
}

# Schritt 2: Drucker-Identifikation abrufen
Write-Host ""
Write-Host "Schritt 2: Drucker-Identifikation abrufen..." -ForegroundColor Yellow
try {
    $IdentResponse = Send-ZPLQuery -IPAddress $PrinterIP -Port $Port -Command "~HI" -TimeoutSeconds $Timeout
    
    if ($IdentResponse) {
        Write-Host "Drucker-Information:" -ForegroundColor Green
        Write-Host $IdentResponse -ForegroundColor White
    }
    else {
        Write-Host "Keine Antwort vom Drucker erhalten (möglicherweise nicht unterstützt)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Fehler beim Abrufen der Drucker-Identifikation: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Schritt 3: Standard-Status abrufen (~HS)
Write-Host ""
Write-Host "Schritt 3: Standard-Status abrufen..." -ForegroundColor Yellow
try {
    $StatusResponse = Send-ZPLQuery -IPAddress $PrinterIP -Port $Port -Command "~HS" -TimeoutSeconds $Timeout
    
    if ($StatusResponse) {
        Write-Host "Drucker-Status:" -ForegroundColor Green
        Write-Host $StatusResponse -ForegroundColor White
        
        # Status-Code interpretieren
        if ($StatusResponse -match "(\d{3})") {
            $StatusCode = $Matches[1]
            Write-Host ""
            Write-Host "Status-Code: $StatusCode" -ForegroundColor Cyan
            
            # Häufige Status-Codes interpretieren
            switch ($StatusCode) {
                "000" { Write-Host "Status: Drucker ist bereit (Idle)" -ForegroundColor Green }
                "001" { Write-Host "Status: Drucker druckt" -ForegroundColor Green }
                "002" { Write-Host "Status: Papier ist leer" -ForegroundColor Red }
                "004" { Write-Host "Status: Farbband ist leer" -ForegroundColor Red }
                "008" { Write-Host "Status: Druckkopf offen" -ForegroundColor Yellow }
                "016" { Write-Host "Status: Pause" -ForegroundColor Yellow }
                "032" { Write-Host "Status: Druckkopf überhitzt" -ForegroundColor Red }
                default { Write-Host "Status: Code $StatusCode (siehe Zebra-Dokumentation)" -ForegroundColor White }
            }
        }
    }
    else {
        Write-Host "Keine Antwort vom Drucker erhalten" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Fehler beim Abrufen des Status: $($_.Exception.Message)" -ForegroundColor Red
}

# Schritt 4: Erweiterten Status abrufen (~HQES)
Write-Host ""
Write-Host "Schritt 4: Erweiterten Status abrufen..." -ForegroundColor Yellow
try {
    $ExtStatusResponse = Send-ZPLQuery -IPAddress $PrinterIP -Port $Port -Command "~HQES" -TimeoutSeconds $Timeout
    
    if ($ExtStatusResponse) {
        Write-Host "Erweiterter Status:" -ForegroundColor Green
        Write-Host $ExtStatusResponse -ForegroundColor White
    }
    else {
        Write-Host "Keine Antwort vom Drucker erhalten (möglicherweise nicht unterstützt)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Fehler beim Abrufen des erweiterten Status: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Zusammenfassung
Write-Host ""
Write-Host "=== STATUS-ABFRAGE ABGESCHLOSSEN ===" -ForegroundColor Cyan
Write-Host "Zeitstempel: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
