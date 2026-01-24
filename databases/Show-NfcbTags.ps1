param(
    [string]$DatabaseDirectory = 'C:\Users\Falk\source\repos\Databases',
    [string]$DatabaseFile = 'nfcb'
)

# Sucht die Datenbankdatei, lädt die SQLite-Assembly aus libs und gibt alle Zeilen aus der Tabelle "tags" aus.
$pathCandidates = @()
if ([IO.Path]::GetExtension($DatabaseFile)) {
    $pathCandidates += (Join-Path $DatabaseDirectory $DatabaseFile)
} else {
    $pathCandidates += (Join-Path $DatabaseDirectory $DatabaseFile)
    $pathCandidates += (Join-Path $DatabaseDirectory ($DatabaseFile + '.db'))
    $pathCandidates += (Join-Path $DatabaseDirectory ($DatabaseFile + '.sqlite'))
}

$databasePath = $pathCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $databasePath) {
    throw "Keine Datenbankdatei gefunden. Geprüft: $($pathCandidates -join ', ')"
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$assemblyRoot = Join-Path $repoRoot 'libs/Stub.System.Data.SQLite.Core.NetStandard/1.0.118.0'
$managedDll = Join-Path $assemblyRoot 'lib/netstandard2.1/System.Data.SQLite.dll'
$nativePath = Join-Path $assemblyRoot 'runtimes/win-x64/native'

if (-not (Test-Path $managedDll)) {
    throw "Assembly nicht gefunden: $managedDll"
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
    $command.CommandText = 'SELECT * FROM tags'
    $reader = $command.ExecuteReader()
    try {
        $rows = @()
        while ($reader.Read()) {
            $row = [ordered]@{}
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $row[$reader.GetName($i)] = $reader.GetValue($i)
            }
            $rows += [pscustomobject]$row
        }
        if ($rows.Count -eq 0) {
            Write-Host 'Keine Eintraege gefunden.'
        } else {
            $rows
        }
    }
    finally {
        $reader.Close()
        $command.Dispose()
    }
}
finally {
    $connection.Dispose()
}
