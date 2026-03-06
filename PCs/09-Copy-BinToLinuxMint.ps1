param(
    [switch]$IncludeSubfolders
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceDirectory = 'C:\Users\Falk\source\repos\BIN'
$linuxHost = '10.24.10.98'
$linuxUser = 'madmin'
$linuxPassword = 'fq5aj~/R'
$targetDirectory = '/usr/local/bin'
$temporaryRemoteDirectory = "/home/$linuxUser/bin_upload_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

function ConvertTo-BashSingleQuotedString {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    return $Value -replace "'", "'\\''"
}

if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) {
    throw "Quellverzeichnis nicht gefunden: $sourceDirectory"
}

$filesToCopy = Get-ChildItem -LiteralPath $sourceDirectory -File -Recurse:$IncludeSubfolders
if (-not $filesToCopy) {
    throw "Keine Dateien im Quellverzeichnis gefunden: $sourceDirectory"
}

$resolvedSourceDirectory = (Resolve-Path -LiteralPath $sourceDirectory).Path
if (-not $resolvedSourceDirectory.EndsWith('\')) {
    $resolvedSourceDirectory = "$resolvedSourceDirectory\"
}

if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    Install-Module -Name Posh-SSH -Scope CurrentUser -Force
}

Import-Module Posh-SSH

$securePassword = ConvertTo-SecureString -String $linuxPassword -AsPlainText -Force
$credential = [PSCredential]::new($linuxUser, $securePassword)

$sshSession = $null
$sftpSession = $null

try {
    $sshSession = New-SSHSession -ComputerName $linuxHost -Credential $credential -AcceptKey
    $sftpSession = New-SFTPSession -ComputerName $linuxHost -Credential $credential -AcceptKey

    Invoke-SSHCommand -SessionId $sshSession.SessionId -Command "mkdir -p '$temporaryRemoteDirectory'" | Out-Null

    foreach ($file in $filesToCopy) {
        $relativePath = $file.FullName.Substring($resolvedSourceDirectory.Length).Replace('\', '/')
        $remoteRelativeDirectory = Split-Path -Path $relativePath -Parent

        $remoteUploadDirectory = $temporaryRemoteDirectory
        if ($remoteRelativeDirectory -and $remoteRelativeDirectory -ne '.') {
            $escapedRemoteRelativeDirectory = ConvertTo-BashSingleQuotedString -Value $remoteRelativeDirectory
            Invoke-SSHCommand -SessionId $sshSession.SessionId -Command "mkdir -p '$temporaryRemoteDirectory/$escapedRemoteRelativeDirectory'" | Out-Null
            $remoteUploadDirectory = "$temporaryRemoteDirectory/$remoteRelativeDirectory"
        }

        Set-SFTPItem -SessionId $sftpSession.SessionId -Path $file.FullName -Destination $remoteUploadDirectory -Force
    }

    $escapedPassword = ConvertTo-BashSingleQuotedString -Value $linuxPassword
    $escapedTargetDirectory = ConvertTo-BashSingleQuotedString -Value $targetDirectory
    $escapedTemporaryRemoteDirectory = ConvertTo-BashSingleQuotedString -Value $temporaryRemoteDirectory

    $moveCommand = @(
        "echo '$escapedPassword' | sudo -S mkdir -p '$escapedTargetDirectory'",
        "echo '$escapedPassword' | sudo -S cp -af '$escapedTemporaryRemoteDirectory'/. '$escapedTargetDirectory/'",
        "echo '$escapedPassword' | sudo -S rm -rf '$escapedTemporaryRemoteDirectory'"
    ) -join ' && '

    $result = Invoke-SSHCommand -SessionId $sshSession.SessionId -Command $moveCommand
    if ($result.ExitStatus -ne 0) {
        throw "Fehler auf dem Zielsystem: $($result.Error) $($result.Output -join ' ')"
    }

    $copyMode = if ($IncludeSubfolders) { 'inkl. Unterordner' } else { 'nur Dateien im BIN-Hauptordner' }
    Write-Host "Erfolgreich kopiert ($copyMode): $($filesToCopy.Count) Datei(en) nach ${linuxHost}:$targetDirectory"
}
finally {
    if ($sftpSession) {
        Remove-SFTPSession -SFTPSession $sftpSession | Out-Null
    }
    if ($sshSession) {
        Remove-SSHSession -SSHSession $sshSession | Out-Null
    }
}