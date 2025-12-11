<#
.SYNOPSIS
    Demonstriert Fehlerbehandlung in PowerShell

.DESCRIPTION
    Try/Catch/Finally, ErrorAction und Fehlerbehandlung
#>

# Try-Catch-Finally
Write-Host "=== Try-Catch-Finally ==="
try {
    # Versuch, durch Null zu teilen
    $Ergebnis = 10 / 0
    Write-Host "Ergebnis: $Ergebnis"
}
catch [System.DivideByZeroException] {
    Write-Host "Fehler: Division durch Null ist nicht erlaubt!" -ForegroundColor Red
}
catch {
    Write-Host "Ein unerwarteter Fehler ist aufgetreten: $_" -ForegroundColor Red
}
finally {
    Write-Host "Cleanup: Dieser Block wird immer ausgeführt"
}

# Try-Catch mit spezifischen Fehlern
Write-Host "`n=== Datei-Zugriff mit Fehlerbehandlung ==="
try {
    $Inhalt = Get-Content -Path "C:\NichtVorhandeneDatei.txt" -ErrorAction Stop
}
catch [System.IO.FileNotFoundException] {
    Write-Host "Datei wurde nicht gefunden" -ForegroundColor Yellow
}
catch {
    Write-Host "Fehler beim Lesen der Datei: $($_.Exception.Message)" -ForegroundColor Red
}

# ErrorAction Parameter
Write-Host "`n=== ErrorAction Beispiele ==="

# SilentlyContinue - Fehler unterdrücken
$Dienst = Get-Service -Name "NichtVorhandenerDienst" -ErrorAction SilentlyContinue
if ($null -eq $Dienst) {
    Write-Host "Dienst nicht gefunden (Fehler wurde unterdrückt)"
}

# Eigene Fehler werfen
function Test-Number {
    param([int]$Zahl)
    
    if ($Zahl -lt 0) {
        throw "Negative Zahlen sind nicht erlaubt!"
    }
    return $Zahl * 2
}

try {
    $Ergebnis = Test-Number -Zahl -5
}
catch {
    Write-Host "Fehler in Test-Number: $_" -ForegroundColor Red
}

# $Error Variable
Write-Host "`n=== Fehlerprotokoll ==="
Write-Host "Anzahl der Fehler in dieser Sitzung: $($Error.Count)"
if ($Error.Count -gt 0) {
    Write-Host "Letzter Fehler: $($Error[0].Exception.Message)"
}

# ErrorActionPreference
Write-Host "`n=== ErrorActionPreference ==="
$OriginalPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop"

try {
    # Diese Operation würde normalerweise nur eine Warnung ausgeben
    Get-Item "C:\NichtVorhanden" 
}
catch {
    Write-Host "Fehler abgefangen durch ErrorActionPreference Stop" -ForegroundColor Yellow
}
finally {
    $ErrorActionPreference = $OriginalPreference
}
