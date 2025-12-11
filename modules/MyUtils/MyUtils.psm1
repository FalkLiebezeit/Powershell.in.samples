<#
.SYNOPSIS
    MyUtils - Benutzerdefiniertes PowerShell-Modul

.DESCRIPTION
    Sammlung nützlicher Hilfsfunktionen
#>

# Funktion: Größe eines Verzeichnisses berechnen
function Get-DirectorySize {
    <#
    .SYNOPSIS
        Berechnet die Gesamtgröße eines Verzeichnisses
    
    .PARAMETER Path
        Pfad zum Verzeichnis
    
    .EXAMPLE
        Get-DirectorySize -Path "C:\Windows"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "Pfad nicht gefunden: $Path"
        return
    }
    
    $Items = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
    $TotalSize = ($Items | Measure-Object -Property Length -Sum).Sum
    
    [PSCustomObject]@{
        Pfad = $Path
        DateiAnzahl = $Items.Count
        GroesseBytes = $TotalSize
        GroesseMB = [math]::Round($TotalSize / 1MB, 2)
        GroesseGB = [math]::Round($TotalSize / 1GB, 2)
    }
}

# Funktion: Temporäre Dateien bereinigen
function Clear-TempFiles {
    <#
    .SYNOPSIS
        Bereinigt temporäre Dateien
    
    .PARAMETER DryRun
        Wenn gesetzt, werden nur Dateien angezeigt, nicht gelöscht
    
    .EXAMPLE
        Clear-TempFiles -DryRun
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )
    
    $TempPaths = @(
        $env:TEMP
        "$env:USERPROFILE\AppData\Local\Temp"
    )
    
    $TotalSize = 0
    $FileCount = 0
    
    foreach ($TempPath in $TempPaths) {
        if (Test-Path $TempPath) {
            $Files = Get-ChildItem -Path $TempPath -File -Recurse -ErrorAction SilentlyContinue
            $Size = ($Files | Measure-Object -Property Length -Sum).Sum
            $TotalSize += $Size
            $FileCount += $Files.Count
            
            if (-not $DryRun) {
                $Files | Remove-Item -Force -ErrorAction SilentlyContinue
                Write-Host "Bereinigt: $TempPath"
            }
        }
    }
    
    $SizeMB = [math]::Round($TotalSize / 1MB, 2)
    
    if ($DryRun) {
        Write-Host "DRY RUN: Würde $FileCount Dateien ($SizeMB MB) löschen"
    }
    else {
        Write-Host "Gelöscht: $FileCount Dateien ($SizeMB MB)"
    }
}

# Funktion: System-Snapshot erstellen
function Get-SystemSnapshot {
    <#
    .SYNOPSIS
        Erstellt einen Snapshot der wichtigsten Systemmetriken
    
    .EXAMPLE
        Get-SystemSnapshot
    #>
    [CmdletBinding()]
    param()
    
    $OS = Get-WmiObject Win32_OperatingSystem
    $CPU = Get-WmiObject Win32_Processor
    $RAM = Get-WmiObject Win32_ComputerSystem
    
    [PSCustomObject]@{
        Zeitstempel = Get-Date
        Computername = $env:COMPUTERNAME
        CPU_Auslastung = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
        RAM_GesamtGB = [math]::Round($RAM.TotalPhysicalMemory / 1GB, 2)
        RAM_FreiGB = [math]::Round($OS.FreePhysicalMemory / 1MB / 1024, 2)
        ProzessAnzahl = (Get-Process).Count
        DiensteLaufend = (Get-Service | Where-Object Status -eq 'Running').Count
    }
}

# Funktion: Log-Eintrag schreiben
function Write-Log {
    <#
    .SYNOPSIS
        Schreibt formatierten Log-Eintrag
    
    .PARAMETER Message
        Log-Nachricht
    
    .PARAMETER Level
        Log-Level (Info, Warning, Error)
    
    .PARAMETER LogFile
        Pfad zur Log-Datei (optional)
    
    .EXAMPLE
        Write-Log -Message "Vorgang gestartet" -Level Info
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Level = "Info",
        
        [string]$LogFile
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Konsolen-Ausgabe mit Farbe
    $Color = switch ($Level) {
        "Info"    { "White" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }
    
    Write-Host $LogEntry -ForegroundColor $Color
    
    # In Datei schreiben (optional)
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $LogEntry
    }
}

# Funktionen exportieren
Export-ModuleMember -Function Get-DirectorySize, Clear-TempFiles, Get-SystemSnapshot, Write-Log
