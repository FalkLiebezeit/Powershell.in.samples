param(
    [string]$DatabaseDirectory = '',
    [string]$DatabaseFile = 'MomoxNetzLEJ'
)

if (-not $DatabaseDirectory) {
    $DatabaseDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
}

if ([IO.Path]::GetExtension($DatabaseFile)) {
    $databasePath = Join-Path $DatabaseDirectory $DatabaseFile
} else {
    $databasePath = Join-Path $DatabaseDirectory ($DatabaseFile + '.db')
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$assemblyRoot = Join-Path $repoRoot 'libs/Stub.System.Data.SQLite.Core.NetStandard/1.0.118.0'
$managedDll = Join-Path $assemblyRoot 'lib/netstandard2.1/System.Data.SQLite.dll'
$nativePath = Join-Path $assemblyRoot 'runtimes/win-x64/native'

if (-not (Test-Path $managedDll)) {
    throw "Assembly not found: $managedDll"
}

if (-not ($env:PATH.Split(';') -contains $nativePath)) {
    $env:PATH = "$nativePath;$($env:PATH)"
}

Add-Type -Path $managedDll -ErrorAction Stop

$connectionString = "Data Source=$databasePath;Version=3;"
$connection = [System.Data.SQLite.SQLiteConnection]::new($connectionString)

try {
    $connection.Open()

    $command = $connection.CreateCommand()
    $command.CommandText = @'
DROP TABLE IF EXISTS "Devices";
CREATE TABLE "Devices" (
    "ID" INTEGER PRIMARY KEY AUTOINCREMENT,
    "Gerätetyp" TEXT NOT NULL,
    "IP Adresse" TEXT NOT NULL,
    "Standort" TEXT NOT NULL
);
'@
    $command.ExecuteNonQuery() | Out-Null
    $command.Dispose()

    $transaction = $connection.BeginTransaction()
    try {
        $insert = $connection.CreateCommand()
        $insert.CommandText = 'INSERT INTO "Devices" ("Gerätetyp", "IP Adresse", "Standort") VALUES (@deviceType, @ip, @location)'

        $deviceType = $insert.CreateParameter()
        $deviceType.ParameterName = '@deviceType'
        $deviceType.Value = 'unbestimmt'
        $insert.Parameters.Add($deviceType) | Out-Null

        $ipParam = $insert.CreateParameter()
        $ipParam.ParameterName = '@ip'
        $insert.Parameters.Add($ipParam) | Out-Null

        $location = $insert.CreateParameter()
        $location.ParameterName = '@location'
        $location.Value = 'noch unbekannt'
        $insert.Parameters.Add($location) | Out-Null

        for ($third = 0; $third -le 3; $third++) {
            $startFourth = 0
            if ($third -eq 0) {
                $startFourth = 1
            }

            for ($fourth = $startFourth; $fourth -le 255; $fourth++) {
                $ipParam.Value = "10.24.$third.$fourth"
                $insert.ExecuteNonQuery() | Out-Null
            }
        }

        $transaction.Commit()
        $insert.Dispose()
    }
    catch {
        $transaction.Rollback()
        throw
    }
}
finally {
    $connection.Dispose()
}

Write-Host "Database created and populated: $databasePath"
