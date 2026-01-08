<#
.SYNOPSIS
    Zebra Printer Odometer Reader - Queries odometer values from multiple Zebra network printers
    
.DESCRIPTION
    This script connects to multiple Zebra printers via TCP (Port 9100) and retrieves:
    - Total labels printed
    - Total print length in inches and centimeters/meters
    - Connection diagnostics
    - Parallel processing for fast execution
    
.PARAMETER PrinterIPs
    Array of printer IP addresses to query
    
.PARAMETER Port
    TCP port for ZPL communication (default: 9100)
    
.PARAMETER TimeoutMs
    Connection timeout in milliseconds (default: 3000)

.PARAMETER TestAllVariables
    Test all known odometer variable names to find which ones are supported
    
.PARAMETER ExportCSV
    Export results to CSV file
    
.EXAMPLE
    .\ZebraOdometer_MultiPrinter.ps1
    Queries 5 default printers
    
.EXAMPLE
    .\ZebraOdometer_MultiPrinter.ps1 -PrinterIPs @("10.24.1.183", "10.24.1.184") -TimeoutMs 5000
    Queries specific printers with extended timeout

.EXAMPLE
    .\ZebraOdometer_MultiPrinter.ps1 -ExportCSV "C:\Reports\odometer.csv"
    Queries printers and exports results to CSV
#>

param(
    [string[]]$PrinterIPs = @(
        "10.24.1.179",
        "10.24.1.180",
        "10.24.1.181",
        "10.24.1.182",
        "10.24.1.183"
    ),
    [int]$Port = 9100,
    [int]$TimeoutMs = 3000,
    [switch]$TestAllVariables,
    [string]$ExportCSV
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

function Get-SinglePrinterOdometer {
    <#
    .SYNOPSIS
        Query odometer data from a single printer
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PrinterIP,
        [int]$TimeoutMs = 3000
    )
    
    Write-Verbose "Querying printer: $PrinterIP"
    
    # Test basic connectivity first
    $testCommand = "! U1 getvar `"device.uptime`""
    $testResult = Send-ZebraSGDCommand -IPAddress $PrinterIP -Command $testCommand -TimeoutMs $TimeoutMs
    
    $odometerData = [PSCustomObject]@{
        PrinterIP        = $PrinterIP
        Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Status           = "Offline"
        TotalLabels      = $null
        TotalInches      = $null
        TotalCentimeters = $null
        TotalMeters      = $null
        PrinterModel     = $null
        Uptime           = $null
        Error            = $null
    }
    
    if (-not $testResult.Success) {
        $odometerData.Error = $testResult.Error
        $odometerData.Status = "Error"
        return $odometerData
    }
    
    $odometerData.Status = "Online"
    
    # Get total labels printed
    Write-Verbose "Querying total labels..."
    $totalLabels = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "odometer.total_label_count" -TimeoutMs $TimeoutMs
    if (-not $totalLabels) {
        $totalLabels = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "odometer.total_labels_printed" -TimeoutMs $TimeoutMs
    }
    if ($totalLabels -and $totalLabels -match '^\d+$') {
        $odometerData.TotalLabels = [int]$totalLabels
    }
    
    # Get total print length in inches
    Write-Verbose "Querying total inches..."
    $totalInches = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "odometer.total_print_length" -TimeoutMs $TimeoutMs
    if (-not $totalInches) {
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
    
    # Get printer model
    Write-Verbose "Querying printer model..."
    $model = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "device.friendly_name" -TimeoutMs $TimeoutMs
    if (-not $model) {
        $model = Get-ZebraOdometerValue -IPAddress $PrinterIP -VariableName "device.product_name" -TimeoutMs $TimeoutMs
    }
    if ($model) {
        $odometerData.PrinterModel = $model
    }
    
    # Try alternative variables if labels not found
    if (-not $odometerData.TotalLabels) {
        Write-Verbose "Trying alternative odometer queries..."
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
    
    return $odometerData
}

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Zebra Multi-Printer Odometer Reader" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Querying $($PrinterIPs.Count) printer(s)..." -ForegroundColor Yellow
Write-Host ""

# Test all variables mode
if ($TestAllVariables) {
    Write-Host "Testing all known odometer variable names on first printer..." -ForegroundColor Cyan
    Write-Host "(This helps identify which variables your printer model supports)`n" -ForegroundColor Gray
    
    $testIP = $PrinterIPs[0]
    Write-Host "Testing printer: $testIP`n" -ForegroundColor White
    
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
        $value = Get-ZebraOdometerValue -IPAddress $testIP -VariableName $varName -TimeoutMs $TimeoutMs
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

# Query all printers in parallel (using jobs for compatibility with PowerShell 5.1+)
Write-Host "Connecting to printers...`n" -ForegroundColor Gray

# Get function definitions as strings for passing to parallel scopes
$sendFuncCode = ${function:Send-ZebraSGDCommand}.ToString()
$getValueFuncCode = ${function:Get-ZebraOdometerValue}.ToString()
$getOdometerFuncCode = ${function:Get-SinglePrinterOdometer}.ToString()

# Check PowerShell version and use appropriate method
if ($PSVersionTable.PSVersion.Major -ge 7) {
    # PowerShell 7+ - Use ForEach-Object -Parallel
    Write-Verbose "Using PowerShell 7+ parallel processing"
    
    $results = $PrinterIPs | ForEach-Object -Parallel {
        $printerIP = $_
        $timeout = $using:TimeoutMs
        
        # Define functions in parallel runspace from code strings
        $sendFuncCode = $using:sendFuncCode
        $getValueFuncCode = $using:getValueFuncCode
        $getOdometerFuncCode = $using:getOdometerFuncCode
        
        New-Item -Path Function: -Name Send-ZebraSGDCommand -Value ([scriptblock]::Create($sendFuncCode)) -Force | Out-Null
        New-Item -Path Function: -Name Get-ZebraOdometerValue -Value ([scriptblock]::Create($getValueFuncCode)) -Force | Out-Null
        New-Item -Path Function: -Name Get-SinglePrinterOdometer -Value ([scriptblock]::Create($getOdometerFuncCode)) -Force | Out-Null
        
        Get-SinglePrinterOdometer -PrinterIP $printerIP -TimeoutMs $timeout
    } -ThrottleLimit 5
} else {
    # PowerShell 5.1 - Use background jobs
    Write-Verbose "Using PowerShell 5.1 background jobs"
    
    $jobs = @()
    foreach ($printerIP in $PrinterIPs) {
        $job = Start-Job -ScriptBlock {
            param($IP, $Timeout, $SendFunc, $GetValueFunc, $GetOdometerFunc)
            
            # Recreate functions in job scope
            New-Item -Path Function: -Name Send-ZebraSGDCommand -Value ([scriptblock]::Create($SendFunc)) | Out-Null
            New-Item -Path Function: -Name Get-ZebraOdometerValue -Value ([scriptblock]::Create($GetValueFunc)) | Out-Null
            New-Item -Path Function: -Name Get-SinglePrinterOdometer -Value ([scriptblock]::Create($GetOdometerFunc)) | Out-Null
            
            Get-SinglePrinterOdometer -PrinterIP $IP -TimeoutMs $Timeout
        } -ArgumentList $printerIP, $TimeoutMs, $sendFuncCode, $getValueFuncCode, $getOdometerFuncCode
        
        $jobs += $job
    }
    
    # Wait for all jobs to complete
    Write-Host "Processing $($jobs.Count) printer(s) in parallel..." -ForegroundColor Gray
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
}

# Display results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ODOMETER RESULTS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$successCount = 0
$failCount = 0

foreach ($printer in $results) {
    Write-Host "Printer: " -NoNewline -ForegroundColor Yellow
    Write-Host $printer.PrinterIP -ForegroundColor White
    
    if ($printer.Status -eq "Online") {
        $successCount++
        Write-Host "  Status:    " -NoNewline
        Write-Host "ONLINE" -ForegroundColor Green
        
        if ($printer.PrinterModel) {
            Write-Host "  Model:     " -NoNewline
            Write-Host $printer.PrinterModel -ForegroundColor Cyan
        }
        
        if ($printer.TotalLabels) {
            $labelsFormatted = $printer.TotalLabels.ToString('N0')
            Write-Host "  Labels:    " -NoNewline
            Write-Host "$labelsFormatted labels" -ForegroundColor White
        } else {
            Write-Host "  Labels:    " -NoNewline
            Write-Host "N/A" -ForegroundColor Gray
        }
        
        if ($printer.TotalMeters) {
            $metersFormatted = $printer.TotalMeters.ToString('N2')
            Write-Host "  Length:    " -NoNewline
            Write-Host "$metersFormatted meters" -ForegroundColor White
        } elseif ($printer.TotalInches) {
            $inchesFormatted = $printer.TotalInches.ToString('N0')
            Write-Host "  Length:    " -NoNewline
            Write-Host "$inchesFormatted inches" -ForegroundColor White
        } else {
            Write-Host "  Length:    " -NoNewline
            Write-Host "N/A" -ForegroundColor Gray
        }
        
        if ($printer.Uptime) {
            Write-Host "  Uptime:    " -NoNewline
            # Check if uptime is numeric (seconds) or formatted string
            if ($printer.Uptime -match '^\d+$') {
                # Numeric value in seconds - convert to hours
                $uptimeHours = [math]::Round([int]$printer.Uptime / 3600, 1)
                Write-Host "$uptimeHours hours" -ForegroundColor Gray
            } else {
                # Already formatted string - display as-is
                Write-Host $printer.Uptime -ForegroundColor Gray
            }
        }
    } else {
        $failCount++
        Write-Host "  Status:    " -NoNewline
        Write-Host "OFFLINE/ERROR" -ForegroundColor Red
        if ($printer.Error) {
            Write-Host "  Error:     " -NoNewline
            Write-Host $printer.Error -ForegroundColor Red
        }
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Total Printers: $($PrinterIPs.Count)" -ForegroundColor White
Write-Host "  Online:         $successCount" -ForegroundColor Green
Write-Host "  Offline/Error:  $failCount" -ForegroundColor $(if($failCount -eq 0){'Green'}else{'Red'})
Write-Host "  Query Time:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

# Export to CSV if requested
if ($ExportCSV) {
    try {
        $results | Export-Csv -Path $ExportCSV -NoTypeInformation -Encoding UTF8
        Write-Host "Results exported to: $ExportCSV" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to export CSV: $_" -ForegroundColor Red
    }
}

# Return results object
return $results

#endregion
