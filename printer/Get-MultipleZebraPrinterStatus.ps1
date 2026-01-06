<#
.SYNOPSIS
    Queries the status of multiple Zebra ZT230 network printers and decodes the response

.DESCRIPTION
    Connects to multiple Zebra ZT230 printers via network and sends ZPL commands
    to query the printer status. The script provides information for each printer about:
    - Printer status (Ready, Error, etc.)
    - Paper status
    - Ribbon status
    - Temperature
    - Additional status messages

.PARAMETER PrinterIPs
    Array of IP addresses for the Zebra printers

.EXAMPLE
    .\Get-MultipleZebraPrinterStatus.ps1
    Queries the status of all configured printers

.NOTES
    Author: PowerShell Samples
    Requires: Network access to the Zebra printers via port 9100
    Zebra ZPL Commands: ~HQES (Host Query Extended Status)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    # Array of IP addresses for all Zebra ZT230 printers in the network
    [string[]]$PrinterIPs = @(

        "10.24.1.188",  # Band 1 
        "10.24.1.189",
        "10.24.1.190",
        "10.24.1.191",
        "10.24.1.192",

        "10.24.1.179",  # Band 1 gegenüber
        "10.24.1.180",
        "10.24.1.181",
        "10.24.1.182",
        "10.24.1.183",

        "10.24.1.194",  # Band 2
        "10.24.1.196",
        "10.24.1.197",
        "10.24.1.195",
        "10.24.1.193",

        "10.24.1.137",  # Band 2 gegenüber
        "10.24.1.138",
        "10.24.1.139",
        "10.24.1.140",
        "10.24.1.141"
    ),
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 9100,
    
    [Parameter(Mandatory=$false)]
    [int]$Timeout = 3
)

function Test-Network {
    param($IP)
    
    try {
        $result = Test-Connection -Count 1 -Quiet -ComputerName $IP -ErrorAction Stop
        return $result
    }
    catch {
        return $false
    }
}

function Test-Port9100 {
    param($IP, $Timeout)
    
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $result = $client.BeginConnect($IP, 9100, $null, $null)
        $success = $result.AsyncWaitHandle.WaitOne($Timeout * 1000, $false)
        
        if ($success) {
            $client.EndConnect($result)
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
    finally {
        if ($client -ne $null) {
            $client.Close()
        }
    }
}

function Get-ZebraStatus {
    param($IP, $Port, $Timeout)
    
    $client = $null
    $stream = $null
    $writer = $null
    
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $client.ReceiveTimeout = $Timeout * 1000
        $client.SendTimeout = $Timeout * 1000
        $client.Connect($IP, $Port)
        
        $stream = $client.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $writer.Write("~HQES")
        $writer.Flush()

        Start-Sleep -Milliseconds 500

        $buffer = New-Object byte[] 4096
        $bytes = $stream.Read($buffer, 0, $buffer.Length)
        
        if ($bytes -gt 0) {
            $response = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytes)
            return $response
        }
        
        return ""
    }
    catch {
        return ""
    }
    finally {
        if ($writer) { $writer.Close() }
        if ($stream) { $stream.Close() }
        if ($client) { $client.Close() }
    }
}

function Decode-ZebraStatus {
    param($Response, $PrinterIP)

    if ([string]::IsNullOrWhiteSpace($Response)) {
        Write-Host "  Status: No response received" -ForegroundColor Red
        return
    }

    # Extract the status line (e.g. 030,0,0,1201,000,0,0,0,000,0,0)
    $matchingLines = $Response -split "`n" | Where-Object { $_ -match "^\d{3}," }
    
    if ($matchingLines -eq $null -or $matchingLines.Count -eq 0) {
        Write-Host "  Status: Invalid response" -ForegroundColor Red
        return
    }
    
    $line = $matchingLines[0]
    $fields = $line -split ","

    if ($fields.Count -lt 4) {
        Write-Host "  Status: Incomplete data" -ForegroundColor Yellow
        return
    }

    $StatusCode = $fields[0]
    $ErrorBits = $fields[3]

    # Interpret status code
    $statusText = switch ($StatusCode) {
        "000" { "Printer ready"; $color = "Green" }
        "001" { "Printer printing"; $color = "Green" }
        "002" { "Paper out"; $color = "Red" }
        "004" { "Ribbon out"; $color = "Red" }
        "008" { "Printhead open"; $color = "Yellow" }
        "016" { "Paused"; $color = "Yellow" }
        "030" { "Self-test/Initialization"; $color = "Cyan" }
        "032" { "Printhead overheated"; $color = "Red" }
        default { "Status: $StatusCode"; $color = "White" }
    }
    
    Write-Host ("  Status: " + $statusText) -ForegroundColor $color

    # Decode error bits
    if ($ErrorBits -match "^[0-9A-Fa-f]+$") {
        $bitMap = @{
            0x0001 = "Paper out"
            0x0002 = "Ribbon out"
            0x0004 = "Printhead open"
            0x0008 = "Cutter error"
            0x0010 = "Temperature error"
            0x0020 = "Printhead error"
            0x0100 = "Memory error"
            0x1000 = "Calibration required"
            0x2000 = "Sensor error"
        }

        try {
            $value = [Convert]::ToInt32($ErrorBits, 16)
            
            if ($value -eq 0) {
                Write-Host "  Errors: No errors" -ForegroundColor Green
            }
            else {
                $errors = @()
                foreach ($bit in $bitMap.Keys) {
                    if ($value -band $bit) {
                        $errors += $bitMap[$bit]
                    }
                }
                
                if ($errors.Count -gt 0) {
                    Write-Host ("  Errors: " + ($errors -join ", ")) -ForegroundColor Red
                }
                else {
                    Write-Host ("  Errors: Code 0x" + $ErrorBits) -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-Host "  Errors: Decoding failed" -ForegroundColor Yellow
        }
    }
}

# ==================== MAIN ====================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ZEBRA ZT230 MULTI-PRINTER STATUS QUERY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
Write-Host "Number of printers: $($PrinterIPs.Count)"
Write-Host ""

$results = @()

for ($i = 0; $i -lt $PrinterIPs.Count; $i++) {
    $printerIP = $PrinterIPs[$i]
    $printerNum = $i + 1
    
    Write-Host "[$printerNum/$($PrinterIPs.Count)] Printer: $printerIP" -ForegroundColor Yellow
    Write-Host ("-" * 40)
    
    # Test network
    Write-Host "  Ping: " -NoNewline
    if (Test-Network $printerIP) {
        Write-Host "OK" -ForegroundColor Green
        
        # Test port
        Write-Host "  Port 9100: " -NoNewline
        if (Test-Port9100 $printerIP $Timeout) {
            Write-Host "OK" -ForegroundColor Green
            
            # Query status
            Write-Host "  Status query: " -NoNewline
            $response = Get-ZebraStatus $printerIP $Port $Timeout
            
            if ($response) {
                Write-Host "OK" -ForegroundColor Green
                Decode-ZebraStatus $response $printerIP
                
                $results += [PSCustomObject]@{
                    Printer = $printerIP
                    Status = "Online"
                    Details = "Status retrieved"
                }
            }
            else {
                Write-Host "Failed" -ForegroundColor Red
                Write-Host "  Status: No response from printer" -ForegroundColor Red
                
                $results += [PSCustomObject]@{
                    Printer = $printerIP
                    Status = "No response"
                    Details = "Connection OK, but no data"
                }
            }
        }
        else {
            Write-Host "Failed" -ForegroundColor Red
            Write-Host "  Status: Port 9100 not reachable" -ForegroundColor Red
            
            $results += [PSCustomObject]@{
                Printer = $printerIP
                Status = "Port closed"
                Details = "Port 9100 not reachable"
            }
        }
    }
    else {
        Write-Host "Failed" -ForegroundColor Red
        Write-Host "  Status: Printer not reachable on network" -ForegroundColor Red
        
        $results += [PSCustomObject]@{
            Printer = $printerIP
            Status = "Offline"
            Details = "Ping failed"
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$onlineCount = ($results | Where-Object { $_.Status -eq "Online" }).Count
$offlineCount = ($results | Where-Object { $_.Status -eq "Offline" }).Count
$errorCount = $results.Count - $onlineCount - $offlineCount

Write-Host ""
Write-Host "Online:  $onlineCount" -ForegroundColor Green
Write-Host "Offline: $offlineCount" -ForegroundColor Red
Write-Host "Errors:  $errorCount" -ForegroundColor Yellow
Write-Host ""
Write-Host "Query completed: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
