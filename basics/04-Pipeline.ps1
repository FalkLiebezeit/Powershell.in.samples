<#
.SYNOPSIS
    Demonstriert die PowerShell-Pipeline

.DESCRIPTION
    Beispiele für Pipeline-Operationen und Cmdlet-Verkettung
#>

# Grundlegende Pipeline
Write-Host "=== Prozesse mit hoher CPU-Nutzung ==="
Get-Process | 
    Where-Object { $_.CPU -gt 10 } | 
    Select-Object -First 5 Name, CPU, WorkingSet |
    Format-Table -AutoSize

# Pipeline mit Sort-Object
Write-Host "`n=== Top 10 Prozesse nach Speicher ==="
Get-Process | 
    Sort-Object WorkingSet -Descending | 
    Select-Object -First 10 Name, @{Name="Memory(MB)";Expression={[math]::Round($_.WorkingSet/1MB,2)}} |
    Format-Table -AutoSize

# Pipeline mit Group-Object
Write-Host "`n=== Dateien nach Erweiterung gruppiert ==="
Get-ChildItem -Path $env:USERPROFILE\Documents -File -ErrorAction SilentlyContinue | 
    Group-Object Extension | 
    Select-Object Name, Count |
    Sort-Object Count -Descending |
    Format-Table -AutoSize

# Pipeline mit ForEach-Object
Write-Host "`n=== Zahlen transformieren ==="
1..10 | ForEach-Object {
    [PSCustomObject]@{
        Zahl = $_
        Quadrat = $_ * $_
        IstGerade = ($_ % 2) -eq 0
    }
} | Format-Table -AutoSize

# Pipeline mit Measure-Object
Write-Host "`n=== Statistik für Zahlenreihe ==="
$Zahlen = 1..100
$Stats = $Zahlen | Measure-Object -Average -Sum -Maximum -Minimum

Write-Host "Anzahl: $($Stats.Count)"
Write-Host "Summe: $($Stats.Sum)"
Write-Host "Durchschnitt: $($Stats.Average)"
Write-Host "Minimum: $($Stats.Minimum)"
Write-Host "Maximum: $($Stats.Maximum)"

# Pipeline mit Where-Object und komplexen Filtern
Write-Host "`n=== Dienste gefiltert ==="
Get-Service | 
    Where-Object { $_.Status -eq 'Running' -and $_.StartType -eq 'Automatic' } |
    Select-Object -First 10 Name, DisplayName, Status |
    Format-Table -AutoSize
