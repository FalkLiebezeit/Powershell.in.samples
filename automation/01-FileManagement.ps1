<#
.SYNOPSIS
    Dateiverwaltungsautomatisierung

.DESCRIPTION
    Beispiele für automatisierte Dateiverwaltungsaufgaben
#>

# Arbeitsverzeichnis erstellen (temporär für Demo)
$DemoPath = Join-Path $env:TEMP "PowerShell-Demo"
if (-not (Test-Path $DemoPath)) {
    New-Item -ItemType Directory -Path $DemoPath | Out-Null
}

Write-Host "=== Dateien und Ordner erstellen ==="
Write-Host "Demo-Pfad: $DemoPath"

# Mehrere Ordner erstellen
$Ordner = @("Dokumente", "Bilder", "Archive", "Logs")
foreach ($Ordner in $Ordner) {
    $OrdnerPfad = Join-Path $DemoPath $Ordner
    if (-not (Test-Path $OrdnerPfad)) {
        New-Item -ItemType Directory -Path $OrdnerPfad | Out-Null
        Write-Host "  Erstellt: $Ordner"
    }
}

# Test-Dateien erstellen
Write-Host "`n=== Test-Dateien erstellen ==="
$Dateien = @(
    @{Name="dokument1.txt"; Inhalt="Test Dokument 1"}
    @{Name="dokument2.txt"; Inhalt="Test Dokument 2"}
    @{Name="bild1.jpg"; Inhalt="Fake Bild 1"}
    @{Name="bild2.png"; Inhalt="Fake Bild 2"}
    @{Name="log1.log"; Inhalt="Log Eintrag 1"}
)

foreach ($Datei in $Dateien) {
    $DateiPfad = Join-Path $DemoPath $Datei.Name
    Set-Content -Path $DateiPfad -Value $Datei.Inhalt
    Write-Host "  Erstellt: $($Datei.Name)"
}

# Dateien nach Typ sortieren
Write-Host "`n=== Dateien nach Typ sortieren ==="
Get-ChildItem -Path $DemoPath -File | ForEach-Object {
    $ZielOrdner = switch ($_.Extension) {
        ".txt" { "Dokumente" }
        {$_ -in ".jpg", ".png"} { "Bilder" }
        ".log" { "Logs" }
        default { "Archive" }
    }
    
    $ZielPfad = Join-Path $DemoPath $ZielOrdner
    Move-Item -Path $_.FullName -Destination $ZielPfad -Force
    Write-Host "  Verschoben: $($_.Name) -> $ZielOrdner"
}

# Dateistatistiken
Write-Host "`n=== Dateistatistiken ==="
$AlleDateien = Get-ChildItem -Path $DemoPath -Recurse -File
Write-Host "Gesamtanzahl Dateien: $($AlleDateien.Count)"

$NachOrdner = $AlleDateien | Group-Object {Split-Path $_.DirectoryName -Leaf}
$NachOrdner | ForEach-Object {
    Write-Host "  $($_.Name): $($_.Count) Datei(en)"
}

# Alte Dateien finden (Demo: älter als 0 Tage = alle)
Write-Host "`n=== Alte Dateien identifizieren ==="
$AlteDateien = Get-ChildItem -Path $DemoPath -Recurse -File | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-0) }

$AlteDateien | ForEach-Object {
    Write-Host "  Alt: $($_.FullName) (Geändert: $($_.LastWriteTime))"
}

# Dateien komprimieren
Write-Host "`n=== Ordner archivieren ==="
$ArchivPfad = Join-Path $env:TEMP "PowerShell-Demo-Archive.zip"
if (Test-Path $ArchivPfad) {
    Remove-Item $ArchivPfad -Force
}

Compress-Archive -Path $DemoPath -DestinationPath $ArchivPfad
Write-Host "Archiv erstellt: $ArchivPfad"
$ArchivGroesse = (Get-Item $ArchivPfad).Length / 1KB
Write-Host "Archivgröße: $([math]::Round($ArchivGroesse, 2)) KB"

# Cleanup
Write-Host "`n=== Aufräumen ==="
Write-Host "Demo-Dateien bleiben unter: $DemoPath"
Write-Host "Archiv: $ArchivPfad"
Write-Host "Zum Löschen verwenden: Remove-Item '$DemoPath' -Recurse -Force"
