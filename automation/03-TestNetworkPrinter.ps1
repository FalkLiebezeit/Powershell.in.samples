<#
.SYNOPSIS
    Tests a network printer and triggers a test print

.DESCRIPTION
    Checks the network connection to a printer and sends a test page

.PARAMETER PrinterIP
    IP address of the network printer

.PARAMETER PrinterName
    Name for the temporary printer (optional)

.EXAMPLE
    .\03-TestNetworkPrinter.ps1 -PrinterIP "10.24.1.197"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$PrinterIP = "10.24.10.24",
    
    [Parameter(Mandatory=$false)]
    [string]$PrinterName = "TestPrinter_$PrinterIP"
)

Write-Host "=== NETWORK PRINTER TEST ===" -ForegroundColor Cyan
Write-Host "Printer IP: $PrinterIP"
Write-Host "Timestamp: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
Write-Host ""

# Step 1: Test network connectivity
Write-Host "--- Step 1: Test Network Connection ---" -ForegroundColor Yellow
try {
    # Send 3 ping requests to test if the printer is reachable
    $PingResult = Test-Connection -ComputerName $PrinterIP -Count 3 -ErrorAction Stop
    $AvgResponseTime = ($PingResult | Measure-Object -Property ResponseTime -Average).Average
    
    Write-Host "✓ Printer is reachable" -ForegroundColor Green
    Write-Host "  Successful pings: $($PingResult.Count)"
    Write-Host "  Average response time: $([math]::Round($AvgResponseTime, 2)) ms"
}
catch {
    Write-Host "✗ Printer is not reachable!" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nPlease check:"
    Write-Host "  - IP address is correct: $PrinterIP"
    Write-Host "  - Printer is powered on"
    Write-Host "  - Network connection is active"
    Write-Host "  - Firewall allows ICMP packets"
    exit 1
}

# Step 2: Test port 9100 (Standard Raw TCP/IP port for printers)
Write-Host "`n--- Step 2: Test Printer Port ---" -ForegroundColor Yellow
try {
    # Create TCP client and attempt connection to port 9100
    $TcpClient = New-Object System.Net.Sockets.TcpClient
    $Connect = $TcpClient.BeginConnect($PrinterIP, 9100, $null, $null)
    $Wait = $Connect.AsyncWaitHandle.WaitOne(3000, $false)  # 3 second timeout
    
    if ($Wait -and $TcpClient.Connected) {
        Write-Host "✓ Port 9100 is open (Raw TCP/IP Printing)" -ForegroundColor Green
        $TcpClient.Close()
    }
    else {
        Write-Host "⚠ Port 9100 is not responding" -ForegroundColor Yellow
        Write-Host "  The printer might use other ports (IPP: 631, LPD: 515)" -ForegroundColor Yellow
        $TcpClient.Close()
    }
}
catch {
    Write-Host "⚠ Port test failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Step 3: Install or find printer
Write-Host "`n--- Step 3: Set Up Printer ---" -ForegroundColor Yellow

# Check if printer already exists
$ExistingPrinter = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue

if ($ExistingPrinter) {
    Write-Host "✓ Printer '$PrinterName' already installed" -ForegroundColor Green
}
else {
    Write-Host "Installing temporary printer..."
    
    try {
        # Search for available printer drivers
        Write-Host "Searching for available printer drivers..." -ForegroundColor Cyan
        $AvailableDrivers = Get-PrinterDriver | Select-Object -ExpandProperty Name
        
        # List of preferred drivers (in order of preference)
        $PreferredDrivers = @(
            "Generic / Text Only",
            "Microsoft Print To PDF",
            "Microsoft XPS Document Writer",
            "Generic IBM Graphics Printer"
        )
        
        # Find the first available driver from preferred list
        $DriverName = $null
        foreach ($Driver in $PreferredDrivers) {
            if ($AvailableDrivers -contains $Driver) {
                $DriverName = $Driver
                Write-Host "✓ Using driver: $DriverName" -ForegroundColor Green
                break
            }
        }
        
        # If no preferred driver was found, use any available driver
        if (-not $DriverName -and $AvailableDrivers.Count -gt 0) {
            $DriverName = $AvailableDrivers[0]
            Write-Host "⚠ Using first available driver: $DriverName" -ForegroundColor Yellow
        }
        
        # Throw error if no driver is available at all
        if (-not $DriverName) {
            throw "No printer driver found! Please install a printer driver."
        }
        
        # Create TCP/IP port for the printer
        $PortName = "IP_$PrinterIP"
        $ExistingPort = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
        
        if (-not $ExistingPort) {
            Add-PrinterPort -Name $PortName -PrinterHostAddress $PrinterIP -ErrorAction Stop
            Write-Host "✓ Printer port created: $PortName" -ForegroundColor Green
        }
        else {
            Write-Host "✓ Printer port already exists: $PortName" -ForegroundColor Green
        }
        
        # Add the printer using the selected driver and port
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop
        Write-Host "✓ Printer '$PrinterName' installed with driver '$DriverName'" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Error installing printer: $($_.Exception.Message)" -ForegroundColor Red
        
        # Display available drivers for troubleshooting
        Write-Host "`nAvailable printer drivers on this system:" -ForegroundColor Yellow
        $AllDrivers = Get-PrinterDriver -ErrorAction SilentlyContinue
        if ($AllDrivers) {
            $AllDrivers | Select-Object -First 10 Name | ForEach-Object { Write-Host "  - $($_.Name)" }
            if ($AllDrivers.Count -gt 10) {
                Write-Host "  ... and $($AllDrivers.Count - 10) more"
            }
        }
        else {
            Write-Host "  No drivers found!" -ForegroundColor Red
        }
        
        Write-Host "`nSuggested solutions:" -ForegroundColor Yellow
        Write-Host "1. Install a standard printer driver"
        Write-Host "2. Use 'Add-PrinterDriver' to install a driver"
        Write-Host "3. Manual installation: Settings → Printers & Scanners → Add a printer"
        Write-Host "4. Open Print Management: printmanagement.msc"
        exit 1
    }
}

# Step 4: Check printer status
Write-Host "`n--- Step 4: Check Printer Status ---" -ForegroundColor Yellow
try {
    # Query printer object to check current status
    $Printer = Get-Printer -Name $PrinterName -ErrorAction Stop
    Write-Host "Status: $($Printer.PrinterStatus)"
    Write-Host "Ready: $($Printer.PrinterStatus -eq 'Normal' -or $Printer.PrinterStatus -eq 'Idle')"
    
    # Check if there are any pending print jobs
    if ($Printer.JobCount -gt 0) {
        Write-Host "⚠ Print jobs in queue: $($Printer.JobCount)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠ Could not retrieve printer status" -ForegroundColor Yellow
}

# Step 5: Print test page
Write-Host "`n--- Step 5: Trigger Test Print ---" -ForegroundColor Yellow

$Continue = Read-Host "Would you like to print a test page? (Y/N)"

if ($Continue -eq "Y" -or $Continue -eq "y") {
    try {
        # Attempt to print test page using WMI printer properties
        $PrinterObject = Get-CimInstance -ClassName Win32_Printer -Filter "Name='$($PrinterName.Replace('\\','\\\\'))'"
        
        if ($PrinterObject) {
            $Result = Invoke-CimMethod -InputObject $PrinterObject -MethodName PrintTestPage
            
            if ($Result.ReturnValue -eq 0) {
                Write-Host "✓ Test page was sent to the printer!" -ForegroundColor Green
            }
            else {
                Write-Host "⚠ Test page could not be sent (Code: $($Result.ReturnValue))" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "⚠ Printer object not found for WMI method" -ForegroundColor Yellow
            
            # Alternative: Create and print a text file
            Write-Host "`nAlternative: Creating text test page..." -ForegroundColor Cyan
            $TempFile = Join-Path $env:TEMP "PrinterTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            
            $TestContent = @"
═══════════════════════════════════════════
        PRINTER TEST PAGE
═══════════════════════════════════════════

Printer IP:    $PrinterIP
Printer Name:  $PrinterName
Timestamp:     $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')
Computer:      $env:COMPUTERNAME
User:          $env:USERNAME

═══════════════════════════════════════════
Status:        Test successfully sent
═══════════════════════════════════════════
"@
            
            Set-Content -Path $TempFile -Value $TestContent -Encoding UTF8
            Start-Process -FilePath $TempFile -Verb Print -Wait
            
            Write-Host "✓ Test file created and sent to printer: $TempFile" -ForegroundColor Green
            Start-Sleep -Seconds 2
            Remove-Item $TempFile -ErrorAction SilentlyContinue
        }
        
        Write-Host "`nPlease check the printer for the test page."
    }
    catch {
        Write-Host "✗ Error printing: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "Test print skipped." -ForegroundColor Gray
}

# Step 6: Cleanup (optional)
Write-Host "`n--- Step 6: Cleanup ---" -ForegroundColor Yellow
$Cleanup = Read-Host "Would you like to remove the test printer? (Y/N)"

if ($Cleanup -eq "Y" -or $Cleanup -eq "y") {
    try {
        # Remove the temporary printer
        Remove-Printer -Name $PrinterName -ErrorAction Stop
        Write-Host "✓ Printer '$PrinterName' removed" -ForegroundColor Green
        
        # Optionally remove the printer port as well
        $RemovePort = Read-Host "Also remove the printer port? (Y/N)"
        if ($RemovePort -eq "Y" -or $RemovePort -eq "y") {
            $PortName = "IP_$PrinterIP"
            Remove-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
            Write-Host "✓ Printer port removed" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠ Error during removal: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== TEST COMPLETED ===" -ForegroundColor Cyan
Write-Host "Summary:"
Write-Host "  - Network connection: ✓"
Write-Host "  - Printer IP: $PrinterIP"
Write-Host "  - Printer name: $PrinterName"
