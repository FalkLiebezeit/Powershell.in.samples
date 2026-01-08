ZebraOdometer.psd1@{
    # Basisinformationen
    RootModule        = 'ZebraOdometer.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '3c8b4c7c-9f3d-4b8f-9c8d-123456789abc'

    Author            = 'Falk'
    CompanyName       = 'Falk-Lab'
    Copyright         = '(c) Falk'

    Description       = 'Odometer-, Modell- und Status-Abfrage für Zebra ZT230/231/410 inkl. HTML-Dashboard.'

    # PowerShell-Kompatibilität
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    # Exportierte Funktionen
    FunctionsToExport = @(
        'Get-ZebraOdometer',
        'Get-ZebraOdometerParallel',
        'Get-ZebraPrinterInfo',
        'New-ZebraOdometerDashboard'
    )

    # Keine Cmdlets, Variablen oder Aliases
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Private Daten (optional)
    PrivateData = @{
        PSData = @{
            Tags = @('Zebra','ZT230','ZT231','ZT410','Odometer','LabelPrinter','Diagnostics')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Initial release with Odometer, PrinterInfo, Parallel Query and Dashboard generator.'
        }
    }
}