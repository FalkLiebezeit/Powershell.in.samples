<#

# Standard-Ausführung
.\printer\ZebraOdometer.ps1

# Alle verfügbaren Variablen testen (empfohlen beim ersten Mal!)
.\printer\ZebraOdometer.ps1 -TestAllVariables -Verbose

# Mit spezifischer IP
.\printer\ZebraOdometer.ps1 -PrinterIP "10.24.1.183" -TestAllVariables

.SYNOPSIS
    Zebra Printer Odometer Reader - Queries odometer values from a Zebra network printer
    
.DESCRIPTION
    This script connects to a Zebra printer via TCP (Port 9100) and retrieves:
    - Total labels printed
    - Total print length in inches and centimeters/meters
    - Connection diagnostics
    
.PARAMETER PrinterIP
    IP address of the Zebra printer (default: 10.24.1.183)
    
.PARAMETER Port
    TCP port for ZPL communication (default: 9100)
    
.PARAMETER TimeoutMs
    Connection timeout in milliseconds (default: 3000)

.PARAMETER TestAllVariables
    Test all known odometer variable names to find which ones are supported
    
.EXAMPLE
    .\ZebraOdometer.ps1
    Queries the default printer at 10.24.1.183
    
.EXAMPLE
    .\ZebraOdometer.ps1 -PrinterIP "192.168.1.100" -TimeoutMs 5000
    Queries a different printer with extended timeout

.EXAMPLE
    .\ZebraOdometer.ps1 -TestAllVariables -Verbose
    Tests all known variable names to see which are supported
#>

param(
    [string]$PrinterIP = "10.24.1.183",
    [int]$Port = 9100,
    [int]$TimeoutMs = 3000,
    [switch]$TestAllVariables
)

#region Helper Functions

function Send-ZebraSGDCommand {
    <#
    .SYNOPSIS
        Sends an SGD (Set-Get-Do) command to a Zebra printer
    #>
    param(
        [Parameter(Mandatory)]
        [string]$IPAddress,
        [Parameter(Mandatory)]
        [string]$Command,
        [int]$Port = 9100,
        [int]$TimeoutMs = 3000
    )
    
    $result = @{
        Success = $false
        Response = $null
        Error = $null
    }
    
    try {
        Write-Verbose "Connecting to $IPAddress`:$Port..."
        
        # Create TCP client with timeout
        $client = New-Object System.Net.Sockets.TcpClient
        $connect = $client.BeginConnect($IPAddress, $Port, $null, $null)
        $success = $connect.AsyncWaitHandle.WaitOne($TimeoutMs)
        
        if (-not $success -or -not $client.Connected) {
            throw "Connection timeout or failed to connect to $IPAddress`:$Port"
        }
        
        # Get network stream
        $stream = $client.GetStream()
        $stream.ReadTimeout = $TimeoutMs
        $stream.WriteTimeout = $TimeoutMs
        
        # Send command (SGD commands need CR+LF)
        $commandBytes = [System.Text.Encoding]::ASCII.GetBytes($Command + "`r`n")
        $stream.Write($commandBytes, 0, $commandBytes.Length)
        Write-Verbose "Sent command: $Command"
        
        # Wait a moment for response
        Start-Sleep -Milliseconds 100
        
        # Read response
        $buffer = New-Object byte[] 4096
        $response = ""
        
        while ($stream.DataAvailable) {
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -gt 0) {
                $response += [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
            }
        }
        
        $result.Success = $true
        $result.Response = $response.Trim()
        
        Write-Verbose "Received response: $($result.Response)"
    }
    catch {
        $result.Error = $_.Exception.Message
        Write-Verbose "Error: $($result.Error)"
    }
    finally {
        if ($client) {
            $client.Close()
            $client.Dispose()
        }
    }
    
    return $result
}

function Get-ZebraOdometerValue {
    <#
    .SYNOPSIS
        Retrieves a specific odometer value from the printer
    #>
    param(
        [string]$IPAddress,
        [string]$VariableName,
        [int]$TimeoutMs = 3000
    )
    
    # SGD command format: ! U1 getvar "variable.name"
    $command = "! U1 getvar `"$VariableName`""
    $result = Send-ZebraSGDCommand -IPAddress $IPAddress -Command $command -TimeoutMs $TimeoutMs
    
    if ($result.Success -and $result.Response) {
        Write-Verbose "Response for $VariableName`: $($result.Response)"
        
        # Check if response is '?' which means variable not supported
        if ($result.Response -eq '?') {
            Write-Verbose "Variable $VariableName not supported by printer"
            return $null
        }
        
        # Parse response - typically returns: "variable.name" "value"
        if ($result.Response -match '"([^"]*)"[^"]*"([^"]*)"') {
            $value = $Matches[2]
            if ($value -ne '?') {
                return $value
            }
        }
        # Alternative format: just the value
        elseif ($result.Response -match '"([^"]*)"') {
            $value = $Matches[1]
            if ($value -ne '?') {
                return $value
            }
        }
        # Or just a number
        elseif ($result.Response -match '(\d+)') {
            return $Matches[1]
        }
    }
    
    return $null
}

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Zebra Printer Odometer Reader" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Printer IP: " -NoNewline -ForegroundColor Yellow
Write-Host $PrinterIP -ForegroundColor White

Write-Host "Connecting to printer..." -ForegroundColor Gray

# Test basic connectivity first
$testCommand = "! U1 getvar `"device.uptime`""
$testResult = Send-ZebraSGDCommand -IPAddress $PrinterIP -Command $testCommand -TimeoutMs $TimeoutMs

if (-not $testResult.Success) {
    Write-Host "`n[ERROR] Cannot connect to printer at $PrinterIP" -ForegroundColor Red
    Write-Host "   $($testResult.Error)" -ForegroundColor Red
    Write-Host "`nPlease verify:" -ForegroundColor Yellow
    Write-Host "  - Printer is powered on" -ForegroundColor Gray
    Write-Host "  - IP address is correct ($PrinterIP)" -ForegroundColor Gray
    Write-Host "  - Network connection is working" -ForegroundColor Gray
    Write-Host "  - Port 9100 is accessible" -ForegroundColor Gray
    exit 1
}

Write-Host "[OK] Connected successfully`n" -ForegroundColor Green

# Test all variables mode
if ($TestAllVariables) {
    Write-Host "Testing all known odometer variable names..." -ForegroundColor Cyan
    Write-Host "(This helps identify which variables your printer model supports)`n" -ForegroundColor Gray
    
    $testVariables = @(
        "odometer.total_label_count",
        "odometer.total_labels_printed",
        "odometer.total_nonresettable_cnt",
        "odometer.user_label_count",
        "odometer.total_print_cnt",
        "odometer.total_print_length",
        "odometer.total_print_length_inches",
        "odometer.total_print_length_cm",
        "odometer.resettable_cnt",
        "device.friendly_name",
        "device.product_name",
        "device.uptime"
    )
    
    foreach ($varName in $testVariables) {
        $value = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName $varName -TimeoutMs $TimeoutMs
        if ($value -and $value -ne '?') {
            Write-Host "[SUPPORTED] " -ForegroundColor Green -NoNewline
            Write-Host "$varName = " -ForegroundColor White -NoNewline
            Write-Host $value -ForegroundColor Yellow
        } else {
            Write-Host "[NOT FOUND] " -ForegroundColor Red -NoNewline
            Write-Host $varName -ForegroundColor Gray
        }
    }
    
    Write-Host "`nTesting complete. Use the supported variable names above.`n" -ForegroundColor Cyan
    exit 0
}

# Query odometer values
Write-Host "Querying odometer values..." -ForegroundColor Gray

$odometerData = [PSCustomObject]@{
    PrinterIP        = $PrinterIP
    Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    TotalLabels      = $null
    TotalInches      = $null
    TotalCentimeters = $null
    TotalMeters      = $null
    PrinterModel     = $null
    Uptime           = $null
}

# Get total labels printed
Write-Verbose "Querying total labels..."
$totalLabels = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "odometer.total_label_count" -TimeoutMs $TimeoutMs
if (-not $totalLabels) {
    # Try alternative variable name
    $totalLabels = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "odometer.total_labels_printed" -TimeoutMs $TimeoutMs
}
if ($totalLabels -and $totalLabels -match '^\d+$') {
    $odometerData.TotalLabels = [int]$totalLabels
}

# Get total print length in inches
Write-Verbose "Querying total inches..."
$totalInches = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "odometer.total_print_length" -TimeoutMs $TimeoutMs
if (-not $totalInches) {
    # Try alternative variable name
    $totalInches = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "odometer.total_print_length_inches" -TimeoutMs $TimeoutMs
}
if ($totalInches -and $totalInches -match '^\d+$') {
    $odometerData.TotalInches = [int]$totalInches
}

# Get total print length in centimeters
Write-Verbose "Querying total centimeters..."
$totalCm = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "odometer.total_print_length_cm" -TimeoutMs $TimeoutMs
if ($totalCm -and $totalCm -match '^\d+$') {
    $odometerData.TotalCentimeters = [int]$totalCm
    $odometerData.TotalMeters = [math]::Round($totalCm / 100, 2)
}

# Get printer model (optional)
Write-Verbose "Querying printer model..."
$model = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "device.friendly_name" -TimeoutMs $TimeoutMs
if (-not $model) {
    # Try alternative variable name
    $model = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "device.product_name" -TimeoutMs $TimeoutMs
}
if ($model) {
    $odometerData.PrinterModel = $model
}

# Try to get additional odometer information if primary methods failed
if (-not $odometerData.TotalLabels) {
    Write-Verbose "Trying alternative odometer queries..."
    
    # Some printers use different variable names
    $altNames = @(
        "odometer.total_nonresettable_cnt",
        "odometer.user_label_count",
        "odometer.total_print_cnt"
    )
    
    foreach ($altName in $altNames) {
        $value = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName $altName -TimeoutMs $TimeoutMs
        if ($value -and $value -match '^\d+$') {
            $odometerData.TotalLabels = [int]$value
            Write-Verbose "Found labels using variable: $altName"
            break
        }
    }
}

# Get uptime
if ($testResult.Response -match '"([^"]*)"') {
    $odometerData.Uptime = $Matches[1]
}

# Display results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ODOMETER RESULTS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($odometerData.PrinterModel) {
    Write-Host "Printer Model:  " -NoNewline -ForegroundColor Yellow
    Write-Host $odometerData.PrinterModel -ForegroundColor White
    Write-Host ""
}

Write-Host "Total Labels Printed:" -ForegroundColor Yellow
if ($odometerData.TotalLabels) {
    $labelsFormatted = $odometerData.TotalLabels.ToString('N0')
    Write-Host "   $labelsFormatted labels" -ForegroundColor Green
} else {
    Write-Host "   Not available" -ForegroundColor Red
}

Write-Host "`nTotal Print Length:" -ForegroundColor Yellow
if ($odometerData.TotalMeters) {
    $metersFormatted = $odometerData.TotalMeters.ToString('N2')
    $centimetersFormatted = $odometerData.TotalCentimeters.ToString('N0')
    Write-Host "   $metersFormatted meters" -ForegroundColor Green
    Write-Host "   $centimetersFormatted centimeters" -ForegroundColor Gray
}
if ($odometerData.TotalInches) {
    $inchesFormatted = $odometerData.TotalInches.ToString('N0')
    Write-Host "   $inchesFormatted inches" -ForegroundColor Gray
}
if (-not $odometerData.TotalMeters -and -not $odometerData.TotalInches) {
    Write-Host "   Not available" -ForegroundColor Red
}

if ($odometerData.Uptime) {
    Write-Host "`nPrinter Uptime:" -ForegroundColor Yellow
    Write-Host "   $($odometerData.Uptime) seconds" -ForegroundColor Gray
}

Write-Host "`nQuery Time:" -ForegroundColor Yellow
Write-Host "   $($odometerData.Timestamp)" -ForegroundColor Gray

Write-Host "`n========================================`n" -ForegroundColor Cyan

# Return object for further processing
return $odometerData

#endregion
