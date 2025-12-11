<#
.SYNOPSIS
    Beispiel zur Verwendung des MyUtils-Moduls

.DESCRIPTION
    Demonstriert wie man das benutzerdefinierte MyUtils-Modul verwendet
#>

# Modul importieren
$ModulePath = Join-Path $PSScriptRoot "..\modules\MyUtils"
Import-Module $ModulePath -Force

Write-Host "=== MyUtils Modul Beispiele ===" -ForegroundColor Cyan

# Beispiel 1: Verzeichnisgröße berechnen
Write-Host "`n--- Verzeichnisgröße ---" -ForegroundColor Yellow
$WindowsSize = Get-DirectorySize -Path "$env:SystemRoot\System32"
Write-Host "System32 Ordner:"
Write-Host "  Dateien: $($WindowsSize.DateiAnzahl)"
Write-Host "  Größe: $($WindowsSize.GroesseMB) MB"

# Beispiel 2: System-Snapshot
Write-Host "`n--- System Snapshot ---" -ForegroundColor Yellow
$Snapshot = Get-SystemSnapshot
Write-Host "CPU Auslastung: $([math]::Round($Snapshot.CPU_Auslastung, 2))%"
Write-Host "RAM Gesamt: $($Snapshot.RAM_GesamtGB) GB"
Write-Host "RAM Frei: $($Snapshot.RAM_FreiGB) GB"
Write-Host "Prozesse: $($Snapshot.ProzessAnzahl)"
Write-Host "Laufende Dienste: $($Snapshot.DiensteLaufend)"

# Beispiel 3: Logging
Write-Host "`n--- Logging Beispiel ---" -ForegroundColor Yellow
Write-Log -Message "Anwendung gestartet" -Level Info
Write-Log -Message "Dies ist eine Warnung" -Level Warning
Write-Log -Message "Beispiel für einen Fehler" -Level Error

# Optional: In Datei loggen
$LogFile = Join-Path $env:TEMP "MyUtils-Demo.log"
Write-Log -Message "Log-Eintrag in Datei" -Level Info -LogFile $LogFile
Write-Host "Log-Datei erstellt: $LogFile"

# Beispiel 4: Temp-Dateien prüfen (Dry Run)
Write-Host "`n--- Temporäre Dateien (Dry Run) ---" -ForegroundColor Yellow
Clear-TempFiles -DryRun

Write-Host "`n=== Beispiele abgeschlossen ===" -ForegroundColor Cyan
Write-Host "Modul kann entfernt werden mit: Remove-Module MyUtils"
