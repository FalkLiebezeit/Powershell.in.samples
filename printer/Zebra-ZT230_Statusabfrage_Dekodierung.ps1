param(
    [Parameter(Mandatory=$false)]
    [string]$PrinterIP = "10.24.1.179"
)

function Test-Network {
    param($IP)
    Write-Host "`n[1] Netzwerk-Test" -ForegroundColor Cyan

    if (Test-Connection -Count 1 -Quiet -ComputerName $IP) {
        Write-Host "Ping erfolgreich" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Ping fehlgeschlagen" -ForegroundColor Red
        return $false
    }
}

function Test-Port9100 {
    param($IP)
    Write-Host "`n[2] Port 9100-Test" -ForegroundColor Cyan

    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.Connect($IP,9100)
        Write-Host "Port 9100 erreichbar" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Port 9100 nicht erreichbar" -ForegroundColor Red
        return $false
    }
    finally {
        if ($client -ne $null) {
            $client.Close()
        }
    }
}

function Get-ZebraStatus {
    param($IP)
    Write-Host "`n[3] Zebra-Status (~HQES)" -ForegroundColor Cyan

    $client = $null
    $stream = $null
    $writer = $null
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient($IP,9100)
        $stream = $client.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.Write("~HQES")
        $writer.Flush()

        Start-Sleep -Milliseconds 500

        $buffer = New-Object byte[] 4096
        $bytes = $stream.Read($buffer,0,$buffer.Length)
        $response = [System.Text.Encoding]::ASCII.GetString($buffer,0,$bytes)

        Write-Host "Rohantwort ($bytes Bytes):" -ForegroundColor Yellow
        if ($bytes -gt 0) {
            Write-Host $response -ForegroundColor White
            Write-Host "Hex-Dump der ersten 100 Bytes:" -ForegroundColor Yellow
            $hexDump = ($buffer[0..[Math]::Min(99,$bytes-1)] | ForEach-Object { $_.ToString("X2") }) -join " "
            Write-Host $hexDump -ForegroundColor Gray
        } else {
            Write-Host "Keine Daten empfangen" -ForegroundColor Red
        }

        return $response
    }
    catch {
        Write-Host "Fehler beim Abrufen des Status: $($_.Exception.Message)" -ForegroundColor Red
        return ""
    }
    finally {
        if ($writer) { $writer.Close() }
        if ($stream) { $stream.Close() }
        if ($client) { $client.Close() }
    }
}

function Decode-ZebraStatus {
    param($Response)

    Write-Host "`n[4] Dekodierung" -ForegroundColor Cyan

    if ([string]::IsNullOrWhiteSpace($Response)) {
        Write-Host "Keine Antwort vom Drucker erhalten." -ForegroundColor Red
        return
    }

    # Zeige alle Zeilen der Antwort
    Write-Host "Antwortzeilen:" -ForegroundColor Yellow
    $lines = $Response -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        Write-Host "Zeile $i : '$($lines[$i])'" -ForegroundColor Gray
    }

    # Extrahiere die Statuszeile (z. B. 030,0,0,1201,000,0,0,0,000,0,0)
    $matchingLines = $Response -split "`n" | Where-Object { $_ -match "^\d{3}," }
    
    if ($matchingLines -eq $null -or $matchingLines.Count -eq 0) {
        Write-Host "Keine gueltige Statuszeile gefunden." -ForegroundColor Red
        Write-Host "Hinweis: Erwartet wird eine Zeile die mit 3 Ziffern und Komma beginnt (z.B. '030,0,0,...')" -ForegroundColor Yellow
        return
    }
    
    $line = $matchingLines[0]

    Write-Host "Gefundene Statuszeile: $line" -ForegroundColor Yellow

    $fields = $line -split ","

    $StatusCode = $fields[0]
    $ErrorBits  = $fields[3]

    Write-Host "`nStatuscode: $StatusCode" -ForegroundColor White

    switch ($StatusCode) {
        "000" { Write-Host "Drucker bereit" -ForegroundColor Green }
        "030" { Write-Host "Drucker im Selbsttest / Initialisierung" -ForegroundColor Cyan }
        default { Write-Host "Unbekannter Statuscode" -ForegroundColor DarkYellow }
    }

    Write-Host "`nFehlerbits (Hex): $ErrorBits" -ForegroundColor White

    # Beispielhafte Bitdekodierung
    $bitMap = @{
        0x0001 = "Papierende"
        0x0002 = "Farbbandende"
        0x0004 = "Druckkopf offen"
        0x0010 = "Temperaturfehler"
        0x1000 = "Kalibrierung erforderlich"
        0x2000 = "Sensorfehler"
    }

    $value = [Convert]::ToInt32($ErrorBits,16)

    foreach ($bit in $bitMap.Keys) {
        if ($value -band $bit) {
            Write-Host ("Fehler: " + $bitMap[$bit]) -ForegroundColor Red
        }
    }

    if ($value -eq 0) {
        Write-Host "Keine Fehler gemeldet" -ForegroundColor Green
    }
}

# --- MAIN ---

if (Test-Network $PrinterIP) {
    if (Test-Port9100 $PrinterIP) {
        $resp = Get-ZebraStatus $PrinterIP
        Decode-ZebraStatus $resp
    }
}
