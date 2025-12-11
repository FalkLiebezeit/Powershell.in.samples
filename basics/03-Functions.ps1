<#
.SYNOPSIS
    Demonstriert Funktionen in PowerShell

.DESCRIPTION
    Verschiedene Arten von Funktionen und Parameter
#>

# Einfache Funktion
function Write-Greeting {
    Write-Host "Hallo aus einer Funktion!"
}

# Funktion mit Parametern
function Get-Sum {
    param(
        [int]$A,
        [int]$B
    )
    return $A + $B
}

# Funktion mit erweiterten Parametern
function Get-PersonInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [int]$Alter = 0,
        
        [ValidateSet("Berlin", "München", "Hamburg")]
        [string]$Stadt = "Berlin"
    )
    
    Write-Host "Name: $Name"
    Write-Host "Alter: $Alter"
    Write-Host "Stadt: $Stadt"
}

# Funktion mit Pipeline-Unterstützung
function Get-Square {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [int]$Zahl
    )
    
    process {
        return $Zahl * $Zahl
    }
}

# Beispielaufrufe
Write-Host "=== Einfache Funktion ==="
Write-Greeting

Write-Host "`n=== Funktion mit Parametern ==="
$Summe = Get-Sum -A 10 -B 32
Write-Host "Summe: $Summe"

Write-Host "`n=== Erweiterte Parameter ==="
Get-PersonInfo -Name "Anna Schmidt" -Alter 28 -Stadt "Hamburg"

Write-Host "`n=== Pipeline-Funktion ==="
1..5 | Get-Square | ForEach-Object { Write-Host "Quadrat: $_" }

# Advanced Function (Cmdlet-Style)
function Get-FileSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (Test-Path $Path) {
        $Item = Get-Item $Path
        $Size = $Item.Length / 1KB
        Write-Host "Dateigröße: $([math]::Round($Size, 2)) KB"
    }
    else {
        Write-Warning "Datei nicht gefunden: $Path"
    }
}
