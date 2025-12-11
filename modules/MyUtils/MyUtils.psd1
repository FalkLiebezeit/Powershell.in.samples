@{
    # Skript-Modul oder Binärmoduldatei, die diesem Manifest zugeordnet ist
    RootModule = 'MyUtils.psm1'
    
    # Versionsnummer dieses Moduls
    ModuleVersion = '1.0.0'
    
    # ID zur eindeutigen Identifizierung dieses Moduls
    GUID = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d'
    
    # Autor dieses Moduls
    Author = 'PowerShell Samples'
    
    # Unternehmen oder Hersteller dieses Moduls
    CompanyName = 'Demo'
    
    # Urheberrechtserklärung für dieses Modul
    Copyright = '(c) 2025. Alle Rechte vorbehalten.'
    
    # Beschreibung der von diesem Modul bereitgestellten Funktionen
    Description = 'Sammlung nützlicher Hilfsfunktionen für Systemverwaltung und Automatisierung'
    
    # Die für dieses Modul mindestens erforderliche Version des Windows PowerShell-Moduls
    PowerShellVersion = '5.1'
    
    # Aus diesem Modul zu exportierende Funktionen
    FunctionsToExport = @(
        'Get-DirectorySize'
        'Clear-TempFiles'
        'Get-SystemSnapshot'
        'Write-Log'
    )
    
    # Aus diesem Modul zu exportierende Cmdlets
    CmdletsToExport = @()
    
    # Aus diesem Modul zu exportierende Variablen
    VariablesToExport = @()
    
    # Aus diesem Modul zu exportierende Aliase
    AliasesToExport = @()
    
    # Private Daten, die an das in "RootModule/ModuleToProcess" angegebene Modul übergeben werden sollen
    PrivateData = @{
        PSData = @{
            Tags = @('Utilities', 'Automation', 'System')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Erste Version mit grundlegenden Hilfsfunktionen'
        }
    }
}
