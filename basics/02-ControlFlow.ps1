<#
.SYNOPSIS
    Demonstriert Kontrollstrukturen in PowerShell

.DESCRIPTION
    If/Else, Switch, Loops und mehr
#>

# If/ElseIf/Else
$Temperatur = 22

if ($Temperatur -lt 0) {
    Write-Host "Es ist sehr kalt!"
}
elseif ($Temperatur -lt 15) {
    Write-Host "Es ist kühl"
}
elseif ($Temperatur -lt 25) {
    Write-Host "Angenehme Temperatur"
}
else {
    Write-Host "Es ist warm!"
}

# Switch Statement
$Tag = "Montag"

switch ($Tag) {
    "Montag"    { Write-Host "Wochenstart!" }
    "Freitag"   { Write-Host "Fast Wochenende!" }
    "Samstag"   { Write-Host "Wochenende!" }
    "Sonntag"   { Write-Host "Wochenende!" }
    default     { Write-Host "Normaler Wochentag" }
}

# For-Schleife
Write-Host "`nFor-Schleife:"
for ($i = 1; $i -le 5; $i++) {
    Write-Host "  Durchlauf $i"
}

# ForEach-Schleife
Write-Host "`nForEach-Schleife:"
$Zahlen = 1..5
foreach ($Zahl in $Zahlen) {
    $Quadrat = $Zahl * $Zahl
    Write-Host "  $Zahl² = $Quadrat"
}

# While-Schleife
Write-Host "`nWhile-Schleife:"
$Counter = 1
while ($Counter -le 3) {
    Write-Host "  Counter: $Counter"
    $Counter++
}

# Do-While-Schleife
Write-Host "`nDo-While-Schleife:"
$Wert = 1
do {
    Write-Host "  Wert: $Wert"
    $Wert++
} while ($Wert -le 3)
