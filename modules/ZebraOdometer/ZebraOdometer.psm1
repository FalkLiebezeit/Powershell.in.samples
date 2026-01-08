<#
.SYNOPSIS
    Zebra-Drucker (ZT230/231/410) diagnostizieren: Odometer, Modell, Supplies, Dashboard.

.DESCRIPTION
    Liest via SGD (! U1 getvar ...) u.a.:
      - odometer.total_labels / inches / centimeters
      - device.product_name (Modell)
      - media.* / ezpl.* / supplies-bezogene Variablen (falls verfügbar)
    Bietet:
      - Get-ZebraOdometer / Get-ZebraOdometerParallel
      - Get-ZebraPrinterInfo
      - New-ZebraOdometerDashboard
#>

# ----------------- Hilfsfunktionen -----------------

function Write-ZebraLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogPath
    )
    if (-not $LogPath) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$ts [$Level] $Message"
}

function Invoke-ZebraSgdCommand {
    param(
        [string]$Printer,
        [string]$Command,
        [int]$Port = 9100,
        [int]$TimeoutMs = 3000,
        [string]$LogPath
    )

    $result = [pscustomobject]@{
        Printer    = $Printer
        Command    = $Command
        Success    = $false
        Response   = $null
        Error      = $null
        DurationMs = $null
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        Write-ZebraLog -LogPath $LogPath -Level "DEBUG" -Message "Connect $Printer:$Port"
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($Printer, $Port, $null, $null)
        $ok