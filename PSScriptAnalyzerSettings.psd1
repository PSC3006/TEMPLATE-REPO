@{
    # Alle Standardregeln (Error, Warning, Information) plus Kompatibilitaet Windows PowerShell 5.1
    Severity     = @('Error', 'Warning', 'Information')
    IncludeDefaultRules = $true
    Rules        = @{
        PSUseCompatibleSyntax   = @{
            Enable         = $true
            TargetVersions = @('5.1')
        }
        PSUseCompatibleCommands = @{
            Enable         = $true
            # Windows PowerShell 5.1 (Windows 10 1809 Desktop) - naechstliegendes verfuegbares Profil
            TargetProfiles = @('win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework')
            # Erst ab Windows 11 vorhanden (LanguagePackManagement / International), im 1809-Profil nicht enthalten
            IgnoreCommands = @(
                'Install-Language', 'Get-InstalledLanguage', 'Set-SystemPreferredUILanguage', 'Get-SystemPreferredUILanguage',
                'Copy-UserInternationalSettingsToSystem'
            )
        }
        PSUseCompatibleTypes    = @{
            Enable         = $true
            TargetProfiles = @('win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework')
        }
    }
}
