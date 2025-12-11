<#
.SYNOPSIS
    Demonstriert die Verwendung von Variablen in PowerShell

.DESCRIPTION
    Dieses Skript zeigt verschiedene Variablentypen und deren Verwendung
#>

# String-Variablen
$Name = "PowerShell"
$Greeting = "Hallo, $Name!"
Write-Host $Greeting

# Numerische Variablen
$Zahl1 = 42
$Zahl2 = 8
$Summe = $Zahl1 + $Zahl2
Write-Host "Summe: $Summe"

# Boolean-Variablen
$IstAktiv = $true
$IstGesperrt = $false

if ($IstAktiv) {
    Write-Host "Status: Aktiv"
}

# Arrays
$Farben = @("Rot", "Grün", "Blau")
Write-Host "Erste Farbe: $($Farben[0])"
Write-Host "Alle Farben: $($Farben -join ', ')"

# HashTables (Dictionaries)
$Person = @{
    Name = "Max Mustermann"
    Alter = 30
    Stadt = "Berlin"
}

Write-Host "Name: $($Person.Name)"
Write-Host "Alter: $($Person.Alter)"

# Umgebungsvariablen
Write-Host "Computername: $env:COMPUTERNAME"
Write-Host "Benutzername: $env:USERNAME"
