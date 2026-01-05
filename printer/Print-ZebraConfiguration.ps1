<#
.SYNOPSIS
    Prints the configuration label from a Zebra ZT231 network printer

.DESCRIPTION
    Connects to a Zebra ZT231 printer via network and sends ZPL commands 
    to print the printer's configuration information

.PARAMETER PrinterIP
    IP address of the Zebra printer

.PARAMETER Port
    Network port (default: 9100 for RAW printing)

.EXAMPLE
    .\Print-ZebraConfiguration.ps1
    Prints configuration from default printer at 10.24.1.137

.EXAMPLE
    .\Print-ZebraConfiguration.ps1 -PrinterIP "10.24.1.100"
    Prints configuration from printer at specified IP

.NOTES
    Author: PowerShell Samples
    Requires: Network access to the Zebra printer on port 9100
    Zebra ZPL Command Used: ~WC (print configuration)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$PrinterIP = "10.24.3.235",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 9100
)

Write-Host "=== ZEBRA ZT231 CONFIGURATION PRINT ===" -ForegroundColor Cyan
Write-Host "Printer IP: $PrinterIP"
Write-Host "Port: $Port"
Write-Host "Timestamp: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
Write-Host ""

# Step 1: Test network connectivity
Write-Host "Step 1: Testing network connectivity..." -ForegroundColor Yellow
try {
    $PingResult = Test-Connection -ComputerName $PrinterIP -Count 2 -ErrorAction Stop
    Write-Host "Printer is reachable (Avg response: $([math]::Round(($PingResult | Measure-Object -Property ResponseTime -Average).Average, 2)) ms)" -ForegroundColor Green
}
catch {
    Write-Host "Cannot reach printer at $PrinterIP" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Connect to printer and send ZPL command
Write-Host ""
Write-Host "Step 2: Sending configuration print command..." -ForegroundColor Yellow

try {
    # Create TCP client to connect to the printer
    $TcpClient = New-Object System.Net.Sockets.TcpClient
    $TcpClient.Connect($PrinterIP, $Port)
    
    if ($TcpClient.Connected) {
        Write-Host "Connected to printer on port $Port" -ForegroundColor Green
        
        # Get network stream
        $Stream = $TcpClient.GetStream()
        $Writer = New-Object System.IO.StreamWriter($Stream)
        $Writer.AutoFlush = $true
        
        # ZPL commands to print configuration
        # ~WC prints the printer configuration label
        $ZplCommand = "~WC"
        
        Write-Host "Sending ZPL command: $ZplCommand" -ForegroundColor Cyan
        
        # Send the command
        $Writer.WriteLine($ZplCommand)
        
        # Wait a moment for the command to be processed
        Start-Sleep -Milliseconds 500
        
        Write-Host "Configuration print command sent successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "The printer should now be printing the configuration label." -ForegroundColor White
        Write-Host "This label contains:" -ForegroundColor White
        Write-Host "  - Printer model and serial number" -ForegroundColor Gray
        Write-Host "  - Firmware version" -ForegroundColor Gray
        Write-Host "  - Network settings" -ForegroundColor Gray
        Write-Host "  - Print darkness and speed settings" -ForegroundColor Gray
        Write-Host "  - Other configuration parameters" -ForegroundColor Gray
        
        # Clean up
        $Writer.Close()
        $Stream.Close()
    }
    else {
        Write-Host "Could not establish connection to printer" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Error communicating with printer" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "  - Port $Port is blocked by firewall" -ForegroundColor Gray
    Write-Host "  - Printer is not configured for RAW printing" -ForegroundColor Gray
    Write-Host "  - Another application is using the printer" -ForegroundColor Gray
    exit 1
}
finally {
    # Ensure connection is closed
    if ($TcpClient) {
        $TcpClient.Close()
    }
}

Write-Host ""
Write-Host "=== OPERATION COMPLETED ===" -ForegroundColor Cyan
