# Skript zum Kopieren einer Datei von Windows nach Ubuntu via SCP
# Autor: PowerShell Script
# Datum: 06.01.2026

<#
.SYNOPSIS
    Kopiert die momox.db Datei von Windows nach Ubuntu
.DESCRIPTION
    Dieses Skript kopiert die momox.db Datei aus dem lokalen Windows-Verzeichnis
    auf einen Ubuntu-Server mittels SCP (Secure Copy Protocol)
#>

# Definiere Quell- und Zielpfade
$sourceFile = "C:\Users\Falk\source\repos\Python.in.samples\11 - Web Flask\momox\momox_tags_viewer\momox.db"
$ubuntuUser = "momox"
$ubuntuPassword = "fq5aj~/R"
$ubuntuIP = "10.24.10.146"
$destinationPath = "/home/momox/repos/falk/Python.in.samples/11.Web/Momox/"

# ============================================================
# PRÜFUNGEN
# ============================================================

Write-Host "`n=== Starte Vorprüfungen ===" -ForegroundColor Cyan

# 1. Prüfe ob die Quelldatei existiert
Write-Host "`n[1/5] Prüfe Quelldatei..." -ForegroundColor Yellow
if (-not (Test-Path $sourceFile)) {
    Write-Host "✗ FEHLER: Die Quelldatei wurde nicht gefunden!" -ForegroundColor Red
    Write-Host "  Pfad: $sourceFile" -ForegroundColor Red
    exit 1
}
$fileSize = (Get-Item $sourceFile).Length / 1KB
Write-Host "✓ Quelldatei gefunden ($([math]::Round($fileSize, 2)) KB)" -ForegroundColor Green

# 2. Prüfe ob SCP/SSH verfügbar ist
Write-Host "`n[2/5] Prüfe SSH/SCP-Client..." -ForegroundColor Yellow
$scpCommand = Get-Command scp -ErrorAction SilentlyContinue
$sshCommand = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $scpCommand -or -not $sshCommand) {
    Write-Host "✗ FEHLER: SSH/SCP-Client nicht gefunden!" -ForegroundColor Red
    Write-Host "  Installiere OpenSSH-Client über Windows-Features" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ SSH/SCP-Client gefunden" -ForegroundColor Green

# 3. Prüfe ob Ubuntu-Host erreichbar ist
Write-Host "`n[3/5] Prüfe Netzwerkverbindung zu $ubuntuIP..." -ForegroundColor Yellow
if (-not (Test-Connection -ComputerName $ubuntuIP -Count 2 -Quiet)) {
    Write-Host "✗ FEHLER: Ubuntu-Host ist nicht erreichbar!" -ForegroundColor Red
    Write-Host "  IP: $ubuntuIP (Ping fehlgeschlagen)" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Host ist erreichbar (Ping erfolgreich)" -ForegroundColor Green

# 4. Teste SSH-Verbindung
Write-Host "`n[4/5] Teste SSH-Verbindung..." -ForegroundColor Yellow
$sshTest = ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no "$ubuntuUser@$ubuntuIP" "echo 'SSH_OK'" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ WARNUNG: SSH-Key-Authentifizierung nicht verfügbar" -ForegroundColor Yellow
    Write-Host "  Sie müssen das Passwort manuell eingeben" -ForegroundColor Yellow
    Write-Host "  Oder SSH-Keys einrichten: ssh-copy-id $ubuntuUser@$ubuntuIP" -ForegroundColor Cyan
} else {
    Write-Host "✓ SSH-Key-Authentifizierung funktioniert" -ForegroundColor Green
}

# 5. Prüfe ob Zielverzeichnis existiert
Write-Host "`n[5/5] Prüfe Zielverzeichnis auf Ubuntu..." -ForegroundColor Yellow
$dirTest = ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$ubuntuUser@$ubuntuIP" "test -d '$destinationPath' && echo 'EXISTS' || echo 'NOT_EXISTS'" 2>&1
if ($dirTest -match "NOT_EXISTS") {
    Write-Host "✗ WARNUNG: Zielverzeichnis existiert nicht!" -ForegroundColor Yellow
    Write-Host "  Versuche Verzeichnis zu erstellen..." -ForegroundColor Yellow
    $mkdirResult = ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$ubuntuUser@$ubuntuIP" "mkdir -p '$destinationPath' && echo 'CREATED'" 2>&1
    if ($mkdirResult -match "CREATED") {
        Write-Host "✓ Zielverzeichnis wurde erstellt" -ForegroundColor Green
    } else {
        Write-Host "✗ FEHLER: Konnte Zielverzeichnis nicht erstellen!" -ForegroundColor Red
        Write-Host "  $mkdirResult" -ForegroundColor Red
        exit 1
    }
} elseif ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Zielverzeichnis existiert" -ForegroundColor Green
} else {
    Write-Host "✗ WARNUNG: Konnte Zielverzeichnis nicht prüfen" -ForegroundColor Yellow
}

Write-Host "`n=== Alle Prüfungen abgeschlossen ===" -ForegroundColor Cyan

Write-Host "`n=== Starte Dateiübertragung ===" -ForegroundColor Green
Write-Host "Quelle: $sourceFile" -ForegroundColor Cyan
Write-Host "Ziel: ${ubuntuUser}@${ubuntuIP}:${destinationPath}" -ForegroundColor Cyan

# Methode 1: Verwendung von SCP (wenn OpenSSH-Client installiert ist)
try {
    # Erstelle den SCP-Zielstring
    $scpDestination = "${ubuntuUser}@${ubuntuIP}:${destinationPath}"
    
    Write-Host "`nHinweis: Falls SSH-Keys nicht eingerichtet sind, geben Sie das Passwort ein:" -ForegroundColor Yellow
    Write-Host "Passwort: $ubuntuPassword" -ForegroundColor Yellow
    Write-Host "`nÜbertragung läuft..." -ForegroundColor Cyan
    
    # Führe SCP-Befehl aus mit Optionen
    # -o StrictHostKeyChecking=no: Akzeptiert automatisch neue Host-Keys
    # -o ConnectTimeout=30: Timeout nach 30 Sekunden
    scp -o StrictHostKeyChecking=no -o ConnectTimeout=30 $sourceFile $scpDestination
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✓ Datei erfolgreich kopiert!" -ForegroundColor Green
        
        # Verifiziere die Übertragung
        Write-Host "`nVerifiziere Übertragung..." -ForegroundColor Yellow
        $remoteFile = "${destinationPath}momox.db"
        $remoteSize = ssh -o ConnectTimeout=10 "$ubuntuUser@$ubuntuIP" "test -f '$remoteFile' && stat -f%z '$remoteFile' 2>/dev/null || stat -c%s '$remoteFile' 2>/dev/null || echo '0'" 2>&1
        
        if ($remoteSize -match '^\d+$' -and [int]$remoteSize -gt 0) {
            $remoteSizeKB = [math]::Round([int]$remoteSize / 1KB, 2)
            Write-Host "✓ Datei auf Ubuntu vorhanden ($remoteSizeKB KB)" -ForegroundColor Green
            
            # Vergleiche Dateigröße
            $localSize = (Get-Item $sourceFile).Length
            if ([int]$remoteSize -eq $localSize) {
                Write-Host "✓ Dateigrößen stimmen überein - Übertragung erfolgreich!" -ForegroundColor Green
            } else {
                Write-Host "⚠ WARNUNG: Dateigrößen unterscheiden sich!" -ForegroundColor Yellow
                Write-Host "  Lokal: $localSize Bytes, Remote: $remoteSize Bytes" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠ WARNUNG: Konnte Datei auf Ubuntu nicht verifizieren" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n✗ FEHLER beim Kopieren der Datei!" -ForegroundColor Red
        Write-Host "Exit Code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "`nMögliche Ursachen:" -ForegroundColor Yellow
        Write-Host "  - Falsches Passwort eingegeben" -ForegroundColor Yellow
        Write-Host "  - Keine Schreibrechte im Zielverzeichnis" -ForegroundColor Yellow
        Write-Host "  - Verbindung unterbrochen" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Host "`n✗ Ein Fehler ist aufgetreten: $_" -ForegroundColor Red
    Write-Host "`nAlternative: Installieren Sie das Posh-SSH Modul für automatisierte Übertragung:" -ForegroundColor Yellow
    Write-Host "Install-Module -Name Posh-SSH -Force" -ForegroundColor Cyan
    exit 1
}

# Alternative Methode mit Posh-SSH (auskommentiert)
<#
# Diese Methode erfordert das Posh-SSH Modul
# Installation: Install-Module -Name Posh-SSH -Force

# Importiere Posh-SSH Modul
if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "Installiere Posh-SSH Modul..." -ForegroundColor Yellow
    Install-Module -Name Posh-SSH -Force -Scope CurrentUser
}

Import-Module Posh-SSH

# Erstelle Credentials
$securePassword = ConvertTo-SecureString $ubuntuPassword -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($ubuntuUser, $securePassword)

try {
    # Erstelle SCP-Verbindung und übertrage die Datei
    Set-SCPFile -ComputerName $ubuntuIP -Credential $credential -LocalFile $sourceFile -RemotePath $destinationPath -AcceptKey
    
    Write-Host "Datei erfolgreich mit Posh-SSH kopiert!" -ForegroundColor Green
}
catch {
    Write-Error "Fehler beim Kopieren mit Posh-SSH: $_"
}
#>
