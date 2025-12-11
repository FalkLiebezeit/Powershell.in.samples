<#
.SYNOPSIS
    Demonstriert objektorientierte Programmierung in PowerShell

.DESCRIPTION
    Klassen, Vererbung und Objekte in PowerShell 5+
#>

# Einfache Klasse definieren
class Person {
    [string]$Vorname
    [string]$Nachname
    [int]$Alter
    
    # Konstruktor
    Person([string]$vorname, [string]$nachname, [int]$alter) {
        $this.Vorname = $vorname
        $this.Nachname = $nachname
        $this.Alter = $alter
    }
    
    # Methode
    [string]GetVollstaendigerName() {
        return "$($this.Vorname) $($this.Nachname)"
    }
    
    [void]GeburtstagFeiern() {
        $this.Alter++
        Write-Host "$($this.GetVollstaendigerName()) ist jetzt $($this.Alter) Jahre alt"
    }
}

# Klasse mit Vererbung
class Mitarbeiter : Person {
    [string]$Position
    [decimal]$Gehalt
    
    Mitarbeiter([string]$vorname, [string]$nachname, [int]$alter, [string]$position, [decimal]$gehalt) 
        : base($vorname, $nachname, $alter) {
        $this.Position = $position
        $this.Gehalt = $gehalt
    }
    
    [void]ErhoehungGeben([decimal]$prozent) {
        $this.Gehalt = $this.Gehalt * (1 + $prozent / 100)
        Write-Host "$($this.GetVollstaendigerName()) erhält eine Gehaltserhöhung auf $($this.Gehalt)€"
    }
    
    [string]GetInfo() {
        return "$($this.GetVollstaendigerName()) - $($this.Position)"
    }
}

# Beispiele verwenden
Write-Host "=== Person-Objekt ==="
$person1 = [Person]::new("Max", "Mustermann", 30)
Write-Host "Name: $($person1.GetVollstaendigerName())"
Write-Host "Alter: $($person1.Alter)"
$person1.GeburtstagFeiern()

Write-Host "`n=== Mitarbeiter-Objekt ==="
$mitarbeiter1 = [Mitarbeiter]::new("Anna", "Schmidt", 28, "Entwicklerin", 55000)
Write-Host $mitarbeiter1.GetInfo()
$mitarbeiter1.ErhoehungGeben(10)

# PSCustomObject (Alternative für einfache Objekte)
Write-Host "`n=== PSCustomObject ==="
$kunde = [PSCustomObject]@{
    KundenID = 1001
    Name = "Firma ABC"
    Ort = "Berlin"
    Umsatz = 150000
}

Write-Host "Kunde: $($kunde.Name) aus $($kunde.Ort)"

# Array von Objekten
Write-Host "`n=== Array von Mitarbeitern ==="
$team = @(
    [Mitarbeiter]::new("Lisa", "Müller", 32, "Team Lead", 65000)
    [Mitarbeiter]::new("Tom", "Weber", 25, "Junior Dev", 45000)
    [Mitarbeiter]::new("Sarah", "Koch", 29, "Senior Dev", 60000)
)

$team | ForEach-Object {
    Write-Host "  - $($_.GetInfo())"
}

# Gesamtgehalt berechnen
$GesamtGehalt = ($team | Measure-Object -Property Gehalt -Sum).Sum
Write-Host "`nGesamtgehalt: $GesamtGehalt€"
