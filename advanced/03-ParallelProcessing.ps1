<#
.SYNOPSIS
    Demonstriert parallele Verarbeitung in PowerShell

.DESCRIPTION
    ForEach-Object -Parallel (PowerShell 7+), Jobs und Runspaces
#>

# Prüfen ob PowerShell 7+ verwendet wird
$PS7Plus = $PSVersionTable.PSVersion.Major -ge 7

if ($PS7Plus) {
    Write-Host "=== ForEach-Object -Parallel (PowerShell 7+) ==="
    
    # Sequentielle Verarbeitung
    Write-Host "`nSequentielle Verarbeitung:"
    $StopwatchSeq = [System.Diagnostics.Stopwatch]::StartNew()
    1..5 | ForEach-Object {
        Start-Sleep -Seconds 1
        Write-Host "  Verarbeite $_"
    }
    $StopwatchSeq.Stop()
    Write-Host "Zeit: $($StopwatchSeq.Elapsed.TotalSeconds) Sekunden"
    
    # Parallele Verarbeitung
    Write-Host "`nParallele Verarbeitung:"
    $StopwatchPar = [System.Diagnostics.Stopwatch]::StartNew()
    1..5 | ForEach-Object -Parallel {
        Start-Sleep -Seconds 1
        Write-Host "  Verarbeite $_"
    } -ThrottleLimit 5
    $StopwatchPar.Stop()
    Write-Host "Zeit: $($StopwatchPar.Elapsed.TotalSeconds) Sekunden"
    
    # Praktisches Beispiel: Mehrere URLs parallel abrufen
    Write-Host "`n=== URLs parallel abrufen ==="
    $urls = @(
        "https://www.google.com"
        "https://www.microsoft.com"
        "https://www.github.com"
    )
    
    $results = $urls | ForEach-Object -Parallel {
        try {
            $response = Invoke-WebRequest -Uri $_ -UseBasicParsing -TimeoutSec 5
            [PSCustomObject]@{
                URL = $_
                StatusCode = $response.StatusCode
                Erfolg = $true
            }
        }
        catch {
            [PSCustomObject]@{
                URL = $_
                StatusCode = $null
                Erfolg = $false
            }
        }
    } -ThrottleLimit 3
    
    $results | Format-Table -AutoSize
}
else {
    Write-Host "=== PowerShell Jobs (PowerShell 5.1) ===" -ForegroundColor Yellow
    Write-Host "Hinweis: Für -Parallel benötigen Sie PowerShell 7+"
}

# Background Jobs (funktioniert in allen Versionen)
Write-Host "`n=== Background Jobs ==="

# Job starten
$job1 = Start-Job -ScriptBlock {
    Start-Sleep -Seconds 2
    Get-Process | Select-Object -First 10 Name, CPU
}

$job2 = Start-Job -ScriptBlock {
    Start-Sleep -Seconds 2
    Get-Service | Where-Object Status -eq 'Running' | Select-Object -First 10 Name
}

Write-Host "Jobs gestartet, warte auf Ergebnisse..."

# Auf Jobs warten
Wait-Job -Job $job1, $job2 | Out-Null

# Ergebnisse abrufen
Write-Host "`nJob 1 - Prozesse:"
Receive-Job -Job $job1 | Format-Table -AutoSize

Write-Host "Job 2 - Dienste:"
Receive-Job -Job $job2 | Format-Table -AutoSize

# Jobs aufräumen
Remove-Job -Job $job1, $job2

Write-Host "`nJobs abgeschlossen und bereinigt"
