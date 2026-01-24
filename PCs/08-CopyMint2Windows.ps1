# Copies the healthcheck CSV from the remote Linux Mint box to this Windows machine via SFTP (Posh-SSH).
param(
    [string]$RemoteHost = "10.24.10.146",
    [string]$RemoteUser = "momox",
    [string]$RemotePassword = "fq5aj~/R",
    [string]$RemoteFile = "/home/momox/.local/bin/healthcheck_2026-01-24_06-00-02.csv",
    [string]$LocalDirectory = "C:\\Users\\Falk\\source\\repos"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $LocalDirectory)) {
    New-Item -ItemType Directory -Path $LocalDirectory | Out-Null
}

if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "Installing Posh-SSH module for current user ..."
    Install-Module -Name Posh-SSH -Scope CurrentUser -Force -ErrorAction Stop
}

Import-Module Posh-SSH -ErrorAction Stop

$securePassword = ConvertTo-SecureString $RemotePassword -AsPlainText -Force
$credential = [System.Management.Automation.PSCredential]::new($RemoteUser, $securePassword)

Write-Host "Opening SFTP session to $RemoteHost ..."
$sftp = New-SFTPSession -ComputerName $RemoteHost -Credential $credential -AcceptKey -ConnectionTimeout 30 -ErrorAction Stop
try {
    $destinationFile = Join-Path $LocalDirectory (Split-Path $RemoteFile -Leaf)
    Write-Host "Copying $RemoteFile to $destinationFile ..."
    Get-SFTPItem -SessionId $sftp.SessionId -Path $RemoteFile -Destination $LocalDirectory -ErrorAction Stop
    Write-Host "Copy complete."
}
finally {
    if ($null -ne $sftp) {
        Remove-SFTPSession -SessionId $sftp.SessionId | Out-Null
    }
}
