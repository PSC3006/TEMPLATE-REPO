#description: CDT STANDARD - Deutsches Sprachpaket (de-DE) inkl. Language-FoDs installieren und Windows auf Deutschland einstellen (AVD-Master-Image, Windows 11 24H2/25H2/26H2). Mode Auto: nach jedem Neustart erneut ausfuehren, bis SUCCESS.
#execution mode: Individual
#tags: CDT, Language, de-DE, AVD, Image

<#
.SYNOPSIS
    Installiert das deutsche Sprachpaket (de-DE) samt Language-FoDs auf einem AVD-Master-Image und stellt
    System, Welcome Screen und neue Benutzer auf Deutschland ein. Setzt die Microsoft-Empfehlungen zum
    Hinzufuegen von Sprachen um und prueft sie in jedem Lauf (Compliance MS-01 bis MS-16, ZUS-01 bis ZUS-15).

.DESCRIPTION
    Laeuft unveraendert als Nerdio Scripted Action (Custom Script Extension, LocalSystem) und als
    HYDRA-Script (SYSTEM). Windows PowerShell 5.1, keine externen Module, keine Aliase, kein wmic.

    Phasen (-Mode):
      Auto        (Default) Ermittelt anhand Zustand und System die naechste offene Phase und fuehrt genau
                  diese aus. Dasselbe Script wird nach jedem Neustart einfach erneut gestartet.
      Install     Cleanup-Blocker (MS-01..MS-05), Sprachpaket + Language-FoDs ueber die Quellen-Kette
                  (Stufe 1 Windows Update -> Stufe 2 Repository -> Stufe 3 LOF-ISO), Laendereinstellungen,
                  Zeitzone.
      ReapplyLcu  LCU nach der Sprachinstallation erneut installieren (MS-08, Checkpoint-CUs ab 24H2).
      Validate    Soll/Ist-Pruefung ohne Aenderungen.
      PreSysprep  Validate + harte Sysprep-Readiness. Endet mit PRESYSPREP_BLOCKED (3040), wenn auch nur ein
                  MUSS-Punkt offen ist. Letzter Schritt vor "Set as Image"/Capture.

    Empfohlene Pipeline: Install -> Reboot -> ReapplyLcu -> Reboot -> Apps installieren -> PreSysprep ->
    Sysprep/Capture durch Nerdio/HYDRA. Mit -Mode Auto genuegt nach jedem Neustart derselbe Aufruf.

    Zustand: HKLM:\SOFTWARE\CDT\LanguageDeployment\<Language>
    Logs:    -LogRoot (Default C:\Install\CDT-STANDARD-Install_DE-Language)

    Exit-Codes:
      0                          SUCCESS
      -RebootRequiredExitCode    SUCCESS_REBOOT_REQUIRED (Default 3010; fuer Nerdio ggf. 0, siehe README)
      3020                       SUCCESS_LCU_REAPPLY_PENDING
      3030                       PARTIAL
      3040                       PRESYSPREP_BLOCKED
      3050                       FAILED

.PARAMETER Mode
    Auto (Default), Install, ReapplyLcu, Validate, PreSysprep.

.PARAMETER Language
    BCP-47-Sprache. Default de-DE.

.PARAMETER GeoId
    Home Location. Default 94 (Deutschland).

.PARAMETER TimeZone
    Zeitzonen-ID. Default 'W. Europe Standard Time'.

.PARAMETER InputLocale
    Eingabesprache/Tastatur. Default 0407:00000407 (Deutsch, QWERTZ).

.PARAMETER RepositoryPath
    Stufe 2: UNC-Pfad (Azure Files) oder lokaler Pfad des Repositorys. Darf auf den Versionsordner
    (<Root>\26100\de-DE_<yyyy-MM-dd>), auf <Root>\26100 oder auf <Root> zeigen (neueste Version wird gewaehlt).

.PARAMETER RepositoryZipUrl
    Stufe 2: HTTPS-URL (inkl. SAS) einer ZIP-Datei des Repositorys in Azure Blob. Wird nie geloggt.

.PARAMETER StorageAccountKey
    Optionaler Storage-Account-Key fuer UNC-Pfade (Azure Files). Wird nie geloggt.
    Nerdio: alternativ Secure Variable CDTLangStorageAccountKey.

.PARAMETER LofIsoUrl
    Stufe 3: Download-URL des Languages-and-Optional-Features-ISO (Default: 24H2/25H2-ISO laut Microsoft).

.PARAMETER IsoPath
    Stufe 3: bereits vorhandenes LOF-ISO (lokal oder UNC) statt Download.

.PARAMETER ForceIsoSource
    Nur Stufe 3 verwenden.

.PARAMETER TempPath
    Arbeitsverzeichnis fuer Downloads, Repository-Kopie und ISO. Wird nach jedem Lauf geloescht.

.PARAMETER LcuPath
    ReapplyLcu: Ordner (lokal/UNC) mit Ziel-MSU und allen benoetigten Checkpoint-MSU, oder eine einzelne MSU.

.PARAMETER LcuUrl
    ReapplyLcu: eine oder mehrere direkte HTTPS-Download-URLs der MSU-Dateien (Ziel + Checkpoints).

.PARAMETER UseWindowsUpdateForNewerLcu
    ReapplyLcu: ohne MSU-Quelle ein neueres LCU ueber die Windows-Update-Agent-COM-API installieren.

.PARAMETER ExcludeFeatures
    Abzuwaehlende Language-FoDs: OCR, Handwriting, Speech, TextToSpeech. Basic ist immer Pflicht.

.PARAMETER CleanupAppxForSysprep
    Appx-Pakete, die Sysprep blockieren (nur benutzerbezogen installiert oder fuer Benutzer aktualisiert),
    nach Microsoft-KB entfernen (Mode PreSysprep).

.PARAMETER RestrictUserLanguageInstall
    MS-13: Policy RestrictLanguagePacksAndFeaturesInstall = 1 setzen (Multi-Session).

.PARAMETER IncludeWinRELanguage
    MS-14: WinRE-Sprachpaket aus dem LOF-ISO/Repository in WinRE integrieren (reagentc).

.PARAMETER RebootIfRequired
    Startet am Ende neu, wenn ein Neustart ansteht (nicht zusammen mit -ForceReboot).

.PARAMETER ForceReboot
    Startet am Ende immer neu (offene Anwendungen werden geschlossen). Nicht bei FAILED, ausser
    zusaetzlich -ForceRebootOnError.

.PARAMETER ForceRebootOnError
    Erlaubt -ForceReboot auch bei FAILED.

.PARAMETER RebootDelaySeconds
    Verzoegerung fuer shutdown.exe /t. Default 60.

.PARAMETER RebootRequiredExitCode
    Exit-Code fuer SUCCESS_REBOOT_REQUIRED. Default 3010.

.PARAMETER LogRoot
    Log-Verzeichnis. Default C:\Install\CDT-STANDARD-Install_DE-Language.

.PARAMETER LogRetentionDays
    Diagnose-Ordner, die aelter sind, werden geloescht. Default 30.

.PARAMETER MaxRuntimeMinutes
    Laufzeitbudget (Custom Script Extension: 90 Minuten). Default 80.

.PARAMETER InstallTimeoutMinutes
    Timeout je Install-Language-Versuch (Stufe 1). Default 30.

.PARAMETER InstallRetryCount
    Anzahl Install-Language-Versuche (Stufe 1). Default 3.

.PARAMETER AllowTemporaryWuPolicyBypass
    Blockierende WU-/Servicing-Policies waehrend Stufe 1 temporaer entschaerfen. Rollback garantiert
    (finally + beim naechsten Start).

.PARAMETER AutoTimeZoneUpdate
    Disable (Default): automatische Zeitzone (tzautoupdate) abschalten. Keep: unveraendert lassen.

.PARAMETER CollectWindowsUpdateLog
    Get-WindowsUpdateLog in den Diagnose-Ordner aufnehmen.

.PARAMETER SecureVars
    Nerdio Secure Variables (wird von Nerdio uebergeben). Unterstuetzte Namen: CDTLangStorageAccountKey,
    CDTLangRepositoryZipUrl, CDTLangRepositoryPath, CDTLangLcuUrl, CDTLangLcuPath.

.EXAMPLE
    .\Install-CDTGermanLanguage.ps1
    Mode Auto ohne Parameter: naechste offene Phase ausfuehren (Stufe 1 Windows Update).

.EXAMPLE
    .\Install-CDTGermanLanguage.ps1 -Mode Install -RepositoryPath '\\stcdtlang.file.core.windows.net\langrepo\26100' -StorageAccountKey $Key

.EXAMPLE
    .\Install-CDTGermanLanguage.ps1 -Mode ReapplyLcu -LcuPath 'C:\Install\LCU'

.EXAMPLE
    .\Install-CDTGermanLanguage.ps1 -Mode PreSysprep -CleanupAppxForSysprep

.NOTES
    Version : 4.0.0 (2026-10-02)
    Autor   : CDT

    CHANGELOG
      4.0.0  2026-10-02  Neuentwicklung, loest CDT-STANDARD-DE-LANGUAGE.ps1 (v3.1) ab:
                         Modes Auto/Install/ReapplyLcu/Validate/PreSysprep, Zustandsmodell ueber Reboots,
                         Quellen-Kette Windows Update -> Repository -> LOF-ISO, Compliance MS-01..MS-16 und
                         ZUS-01..ZUS-15, LCU-Reapply inkl. Checkpoint-CUs, Sysprep-Readiness (Appx),
                         Diagnose-Ordner, Secret-Maskierung, Laufzeitbudget.

    Bewusste Abweichungen von der Vorgabe (siehe README):
      - Kein Parameter-Set fuer -RebootIfRequired/-ForceReboot. Der gegenseitige Ausschluss wird beim Start
        geprueft (vermeidet Konflikte mit dem Nerdio-Parameterset NME_PARAMETER).
      - LCU: Ziel-MSU als PackagePath; der Ordner dient DISM zur Checkpoint-Erkennung (Microsoft-Doku).
      - Kein intl.cpl-Fallback (Microsoft: fuer in die Settings-App migrierte Einstellungen nicht unterstuetzt).
#>
[CmdletBinding()]
param(
    [ValidateSet('Auto', 'Install', 'ReapplyLcu', 'Validate', 'PreSysprep')]
    [string]$Mode = 'Auto',

    [ValidatePattern('^[a-z]{2,3}-[A-Z]{2}$')]
    [string]$Language = 'de-DE',

    [ValidateRange(1, 999999)]
    [int]$GeoId = 94,

    [ValidateNotNullOrEmpty()]
    [string]$TimeZone = 'W. Europe Standard Time',

    [ValidatePattern('^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{8}$')]
    [string]$InputLocale = '0407:00000407',

    [string]$RepositoryPath = '',

    [string]$RepositoryZipUrl = '',

    [string]$StorageAccountKey = '',

    [string]$LofIsoUrl = 'https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso',

    [string]$IsoPath = '',

    [switch]$ForceIsoSource,

    [string]$TempPath = 'C:\Install\CDT-STANDARD-Install_DE-Language_tmp',

    [string]$LcuPath = '',

    [string[]]$LcuUrl = @(),

    [switch]$UseWindowsUpdateForNewerLcu,

    [ValidateSet('OCR', 'Handwriting', 'Speech', 'TextToSpeech')]
    [string[]]$ExcludeFeatures = @(),

    [switch]$CleanupAppxForSysprep,

    [switch]$RestrictUserLanguageInstall,

    [switch]$IncludeWinRELanguage,

    [switch]$RebootIfRequired,

    [switch]$ForceReboot,

    [switch]$ForceRebootOnError,

    [ValidateRange(15, 3600)]
    [int]$RebootDelaySeconds = 60,

    [ValidateRange(0, 2147483647)]
    [int]$RebootRequiredExitCode = 3010,

    [string]$LogRoot = 'C:\Install\CDT-STANDARD-Install_DE-Language',

    [ValidateRange(1, 3650)]
    [int]$LogRetentionDays = 30,

    [ValidateRange(20, 1440)]
    [int]$MaxRuntimeMinutes = 80,

    [ValidateRange(5, 240)]
    [int]$InstallTimeoutMinutes = 30,

    [ValidateRange(1, 10)]
    [int]$InstallRetryCount = 3,

    [switch]$AllowTemporaryWuPolicyBypass,

    [ValidateSet('Disable', 'Keep')]
    [string]$AutoTimeZoneUpdate = 'Disable',

    [switch]$CollectWindowsUpdateLog,

    # Nerdio Secure Variables: Nerdio verlangt fuer eingebaute Variablen das Parameterset NME_PARAMETER.
    [Parameter(ParameterSetName = 'NME_PARAMETER')]
    [object]$SecureVars = $null
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Parameter-Snapshot: Funktionen lesen Parameter ausschliesslich ueber Build-CDTConfiguration (testbar, keine Scope-Abhaengigkeit)
$script:ParamSnapshot = @{
    Mode                         = $Mode
    Language                     = $Language
    GeoId                        = $GeoId
    TimeZone                     = $TimeZone
    InputLocale                  = $InputLocale
    RepositoryPath               = $RepositoryPath
    RepositoryZipUrl             = $RepositoryZipUrl
    StorageAccountKey            = $StorageAccountKey
    LofIsoUrl                    = $LofIsoUrl
    IsoPath                      = $IsoPath
    ForceIsoSource               = [bool]$ForceIsoSource
    TempPath                     = $TempPath
    LcuPath                      = $LcuPath
    LcuUrl                       = @($LcuUrl)
    UseWindowsUpdateForNewerLcu  = [bool]$UseWindowsUpdateForNewerLcu
    ExcludeFeatures              = @($ExcludeFeatures)
    CleanupAppxForSysprep        = [bool]$CleanupAppxForSysprep
    RestrictUserLanguageInstall  = [bool]$RestrictUserLanguageInstall
    IncludeWinRELanguage         = [bool]$IncludeWinRELanguage
    RebootIfRequired             = [bool]$RebootIfRequired
    ForceReboot                  = [bool]$ForceReboot
    ForceRebootOnError           = [bool]$ForceRebootOnError
    RebootDelaySeconds           = $RebootDelaySeconds
    RebootRequiredExitCode       = $RebootRequiredExitCode
    LogRoot                      = $LogRoot
    LogRetentionDays             = $LogRetentionDays
    MaxRuntimeMinutes            = $MaxRuntimeMinutes
    InstallTimeoutMinutes        = $InstallTimeoutMinutes
    InstallRetryCount            = $InstallRetryCount
    AllowTemporaryWuPolicyBypass = [bool]$AllowTemporaryWuPolicyBypass
    AutoTimeZoneUpdate           = $AutoTimeZoneUpdate
    CollectWindowsUpdateLog      = [bool]$CollectWindowsUpdateLog
    SecureVars                   = $SecureVars
}

#region Konstanten und Laufzeitstatus
$script:ScriptVersion = '4.0.0'
$script:ScriptBaseName = 'CDT-STANDARD-Install_DE-Language'
$script:RunStart = Get-Date
$script:RunTimestamp = $script:RunStart.ToString('yyyy-MM-dd_HHmmss')
$script:CurrentPhase = 'Init'
$script:ModeName = $Mode
$script:Cfg = $null
$script:LogFile = $null
$script:ErrorLogFile = $null
$script:ComplianceFile = $null
$script:TranscriptFile = $null
$script:DismLogFile = $null
$script:TranscriptActive = $false
$script:ConsoleOutput = $true
$script:LogWriteFailures = 0
$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:Utf8Bom = [System.Text.UTF8Encoding]::new($true)
$script:Secrets = [System.Collections.Generic.List[string]]::new()
$script:StatusFlags = [System.Collections.Generic.List[string]]::new()
$script:RestartNeeded = $false
$script:PackageCache = $null
$script:BudgetExhausted = $false
$script:LanguageChanged = $false
$script:InstallStagesUsed = [System.Collections.Generic.List[string]]::new()
$script:InstallSourceDetail = ''
$script:AutoAction = ''
$script:ComplianceRows = @()
$script:LastFacts = $null
$script:FinalStatus = 'FAILED'
$script:FinalExitCode = 3050
$script:RebootPlan = $null

# Status-Rangfolge (hoechste zuerst) und feste Exit-Codes
$script:StatusPrecedence = @('FAILED', 'PRESYSPREP_BLOCKED', 'PARTIAL', 'SUCCESS_REBOOT_REQUIRED', 'SUCCESS_LCU_REAPPLY_PENDING', 'SUCCESS')
$script:FixedExitCodes = @{
    SUCCESS                     = 0
    SUCCESS_LCU_REAPPLY_PENDING = 3020
    PARTIAL                     = 3030
    PRESYSPREP_BLOCKED          = 3040
    FAILED                      = 3050
}

# Windows 11 Releases mit gemeinsamem Servicing-Branch 26100 (Microsoft Release Information)
$script:SupportedBuilds = @{ 26100 = '24H2'; 26200 = '25H2'; 26300 = '26H2' }
$script:ServicingBaseBuild = 26100

# MS-01 bis MS-03: Cleanup-Tasks dauerhaft deaktivieren (AVD-Artikel, languages-overview)
$script:CleanupTasks = @(
    @{ Id = 'MS-01'; Path = '\Microsoft\Windows\AppxDeploymentClient\'; Name = 'Pre-staged app cleanup' }
    @{ Id = 'MS-02'; Path = '\Microsoft\Windows\MUI\'; Name = 'LPRemove' }
    @{ Id = 'MS-03'; Path = '\Microsoft\Windows\LanguageComponentsInstaller\'; Name = 'Uninstallation' }
)

# Waehrend der Installation temporaer deaktivieren (Microsoft AIB-Script, Bug 45044965 ERROR_SHARING_VIOLATION)
$script:InstallConflictTasks = @(
    @{ Path = '\Microsoft\Windows\LanguageComponentsInstaller\'; Name = 'Installation' }
    @{ Path = '\Microsoft\Windows\LanguageComponentsInstaller\'; Name = 'ReconcileLanguageResources' }
)

# MS-04/MS-05 (Pflicht) und MS-13 (optional)
$script:IntlPolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Control Panel\International'
$script:TextInputPolicyKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput'
$script:PolicyValues = @(
    @{ Id = 'MS-04'; Path = $script:IntlPolicyKey; Name = 'BlockCleanupOfUnusedPreinstalledLangPacks'; Value = 1 }
    @{ Id = 'MS-05'; Path = $script:TextInputPolicyKey; Name = 'AllowLanguageFeaturesUninstall'; Value = 0 }
)
$script:RestrictPolicy = @{ Id = 'MS-13'; Path = $script:IntlPolicyKey; Name = 'RestrictLanguagePacksAndFeaturesInstall'; Value = 1 }

# Quellen fuer die Compliance-Checkliste
$script:Src = @{
    AvdLang      = 'https://learn.microsoft.com/azure/virtual-desktop/windows-11-language-packs'
    LangOverview = 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/languages-overview'
    FodV2        = 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-v2--capabilities'
    LangFod      = 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-language-fod'
    NonLangFod   = 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-non-language-fod'
    AddLang      = 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/add-language-packs-to-windows'
    Checkpoint   = 'https://learn.microsoft.com/windows/deployment/update/catalog-checkpoint-cumulative-updates'
    SysprepAppx  = 'https://learn.microsoft.com/troubleshoot/windows-client/deployment/sysprep-fails-remove-or-update-store-apps'
    PolicyCsp    = 'https://learn.microsoft.com/windows/client-management/mdm/policy-csp-timelanguagesettings'
    CopyIntl     = 'https://learn.microsoft.com/powershell/module/international/copy-userinternationalsettingstosystem'
    SysPrefUi    = 'https://learn.microsoft.com/powershell/module/languagepackmanagement/set-systempreferreduilanguage'
    OemDeploy    = 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/oem-deployment-of-windows-desktop-editions'
    TzAuto       = 'https://learn.microsoft.com/windows/apps/develop/settings/settings-common#date-and-time'
    ReleaseInfo  = 'https://learn.microsoft.com/windows/release-health/windows11-release-information'
    WsusFod      = 'https://learn.microsoft.com/windows/deployment/update/fod-and-lang-packs'
    WinRE        = 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/customize-windows-re'
    AibScript    = 'https://github.com/Azure/RDS-Templates/tree/master/CustomImageTemplateScripts'
    Catalog      = 'https://www.catalog.update.microsoft.com/Search.aspx?q='
}

# Bekannte Fehlercodes (Quelle: Microsoft-Doku/Q&A, siehe README-Troubleshooting-Matrix)
$script:KnownErrors = @{
    '0x800F0950' = 'Download/Installation des Sprachpakets bzw. FoD fehlgeschlagen (Windows Update, Netz oder Policy pruefen; Stufe 2/3 nutzen).'
    '0x800F081F' = 'CBS_E_SOURCE_MISSING: Quelldateien fehlen oder passen nicht zum Build (Repository/ISO pruefen).'
    '0x800F0954' = 'Optionale Inhalte ueber WSUS/Policy nicht verfuegbar (WSUS-/Servicing-Policy pruefen).'
    '0x8024402C' = 'WU_E_PT_WINHTTP_NAME_NOT_RESOLVED: DNS/Proxy fuer Windows Update pruefen.'
    '0x80240438' = 'WU_E_PT_ENDPOINT_UNREACHABLE: Windows Update nicht erreichbar.'
    '0x8024500C' = 'Verbindung zu Windows Update durch Policy blockiert.'
    '0x80070020' = 'ERROR_SHARING_VIOLATION: parallel laufende Sprachkomponenten-Tasks (MS Bug 45044965).'
    '0x8000FFFF' = 'E_UNEXPECTED: interner Fehler von Install-Language (Retry/Stufe 2).'
    '0x800F0838' = 'Checkpoint-LCU fehlt im LCU-Ordner (alle Checkpoint-MSU mit ablegen).'
    '0x800F081E' = 'CBS_E_NOT_APPLICABLE: Paket ist fuer dieses System nicht anwendbar.'
    '0x800F0922' = 'CBS: Installation fehlgeschlagen (Servicing-Stack/Partitionen pruefen).'
    '0x800F082F' = 'CBS_E_PENDING: ausstehender Neustart blockiert Servicing.'
    '0x80070005' = 'Zugriff verweigert.'
    '0x80070070' = 'Nicht genug Speicherplatz.'
    '0x80070057' = 'Ungueltiger Parameter (Capability-/Paketname pruefen).'
}

# Sprachen mit eigener Font-FoD (Microsoft: Language and region FoDs). de-DE benoetigt keine.
$script:FontCapabilityMap = @{
    'am-ET' = 'Language.Fonts.Ethi~~~und-ETHI~0.0.1.0'; 'ar-SA' = 'Language.Fonts.Arab~~~und-ARAB~0.0.1.0'
    'ar-SY' = 'Language.Fonts.Syrc~~~und-SYRC~0.0.1.0'; 'as-IN' = 'Language.Fonts.Beng~~~und-BENG~0.0.1.0'
    'bn-BD' = 'Language.Fonts.Beng~~~und-BENG~0.0.1.0'; 'bn-IN' = 'Language.Fonts.Beng~~~und-BENG~0.0.1.0'
    'fa-IR' = 'Language.Fonts.Arab~~~und-ARAB~0.0.1.0'; 'gu-IN' = 'Language.Fonts.Gujr~~~und-GUJR~0.0.1.0'
    'he-IL' = 'Language.Fonts.Hebr~~~und-HEBR~0.0.1.0'; 'hi-IN' = 'Language.Fonts.Deva~~~und-DEVA~0.0.1.0'
    'ja-JP' = 'Language.Fonts.Jpan~~~und-JPAN~0.0.1.0'; 'km-KH' = 'Language.Fonts.Khmr~~~und-KHMR~0.0.1.0'
    'kn-IN' = 'Language.Fonts.Knda~~~und-KNDA~0.0.1.0'; 'ko-KR' = 'Language.Fonts.Kore~~~und-KORE~0.0.1.0'
    'lo-LA' = 'Language.Fonts.Laoo~~~und-LAOO~0.0.1.0'; 'ml-IN' = 'Language.Fonts.Mlym~~~und-MLYM~0.0.1.0'
    'mr-IN' = 'Language.Fonts.Deva~~~und-DEVA~0.0.1.0'; 'ne-NP' = 'Language.Fonts.Deva~~~und-DEVA~0.0.1.0'
    'or-IN' = 'Language.Fonts.Orya~~~und-ORYA~0.0.1.0'; 'pa-IN' = 'Language.Fonts.Guru~~~und-GURU~0.0.1.0'
    'si-LK' = 'Language.Fonts.Sinh~~~und-SINH~0.0.1.0'; 'ta-IN' = 'Language.Fonts.Taml~~~und-TAML~0.0.1.0'
    'te-IN' = 'Language.Fonts.Telu~~~und-TELU~0.0.1.0'; 'th-TH' = 'Language.Fonts.Thai~~~und-THAI~0.0.1.0'
    'ti-ET' = 'Language.Fonts.Ethi~~~und-ETHI~0.0.1.0'; 'ur-PK' = 'Language.Fonts.Arab~~~und-ARAB~0.0.1.0'
    'zh-CN' = 'Language.Fonts.Hans~~~und-HANS~0.0.1.0'; 'zh-TW' = 'Language.Fonts.Hant~~~und-HANT~0.0.1.0'
}
#endregion

#region Allgemeine Hilfsfunktionen
function Get-CDTPropertyValue {
    <#
    .SYNOPSIS
        Liest eine Eigenschaft StrictMode-sicher aus einem Objekt oder einer Hashtable.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][object]$Default = $null
    )
    if ($null -eq $InputObject) { return $Default }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $Default
    }
    $prop = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $Default }
    return $prop.Value
}

function Add-CDTSecret {
    <#
    .SYNOPSIS
        Registriert einen geheimen Wert, der in allen Logs maskiert wird.
    #>
    [CmdletBinding()]
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrEmpty($Value) -or $Value.Length -lt 4) { return }
    if (-not $script:Secrets.Contains($Value)) { $script:Secrets.Add($Value) }
    $q = $Value.IndexOf('?')
    if ($q -ge 0 -and $q -lt ($Value.Length - 1)) {
        $query = $Value.Substring($q + 1)
        if ($query.Length -ge 4 -and -not $script:Secrets.Contains($query)) { $script:Secrets.Add($query) }
    }
}

function Get-CDTMaskedText {
    <#
    .SYNOPSIS
        Maskiert registrierte Secrets und SAS-Parameter (sig, se, sp, ...) in einem Text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $masked = $Text
    foreach ($secret in $script:Secrets) {
        if (-not [string]::IsNullOrEmpty($secret)) { $masked = $masked.Replace($secret, '***') }
    }
    $masked = [regex]::Replace($masked, '(?i)([?&](sig|se|st|sp|sv|sr|spr|srt|ss|skoid|sktid|skt|ske|sks|skv)=)[^&\s"'']+', '$1***')
    return $masked
}

function Get-CDTUrlForLog {
    <#
    .SYNOPSIS
        Liefert eine URL ohne Query-String (SAS) fuer Log-Ausgaben.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyString()][string]$Url)
    if ([string]::IsNullOrEmpty($Url)) { return '' }
    $q = $Url.IndexOf('?')
    if ($q -ge 0) { return ($Url.Substring(0, $q) + '?***') }
    return $Url
}

function ConvertFrom-CDTIsoDate {
    <#
    .SYNOPSIS
        Wandelt einen ISO-8601-Zeitstempel (Format "o") in DateTime; $null bei ungueltigem Wert.
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param([AllowNull()][AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = [datetime]::MinValue
    if ([datetime]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) { return $parsed }
    return $null
}

function Get-CDTRemainingBudget {
    <#
    .SYNOPSIS
        Verbleibendes Laufzeitbudget in Minuten.
    #>
    [CmdletBinding()]
    [OutputType([double])]
    param()
    $budget = 80
    if ($null -ne $script:Cfg) { $budget = $script:Cfg.MaxRuntimeMinutes }
    return [Math]::Round($budget - ((Get-Date) - $script:RunStart).TotalMinutes, 1)
}

function Add-CDTStatus {
    <#
    .SYNOPSIS
        Merkt einen Ergebnisstatus fuer diesen Lauf vor (Rangfolge wird am Ende aufgeloest).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][ValidateSet('SUCCESS', 'SUCCESS_REBOOT_REQUIRED', 'SUCCESS_LCU_REAPPLY_PENDING', 'PARTIAL', 'PRESYSPREP_BLOCKED', 'FAILED')][string]$Status)
    $script:StatusFlags.Add($Status)
}

function Resolve-CDTFinalStatus {
    <#
    .SYNOPSIS
        Ermittelt den Gesamtstatus nach Rangfolge FAILED > PRESYSPREP_BLOCKED > PARTIAL > REBOOT > LCU_PENDING > SUCCESS.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyCollection()][string[]]$Status = @())
    foreach ($candidate in $script:StatusPrecedence) {
        if (@($Status) -contains $candidate) { return $candidate }
    }
    return 'SUCCESS'
}

function Get-CDTExitCodeForStatus {
    <#
    .SYNOPSIS
        Liefert den dokumentierten Exit-Code zu einem Status.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [int]$RebootRequiredExitCode = 3010
    )
    if ($Status -eq 'SUCCESS_REBOOT_REQUIRED') { return $RebootRequiredExitCode }
    if ($script:FixedExitCodes.ContainsKey($Status)) { return [int]$script:FixedExitCodes[$Status] }
    return 3050
}

function ConvertTo-CDTArgumentString {
    <#
    .SYNOPSIS
        Baut eine Windows-Kommandozeile mit korrektem Quoting (CommandLineToArgvW-Regeln).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowEmptyCollection()][string[]]$ArgumentList = @())
    $parts = foreach ($a in $ArgumentList) {
        if ($null -eq $a -or $a -eq '') { '""' }
        elseif ($a -notmatch '[\s"]') { $a }
        else {
            $escaped = [regex]::Replace($a, '(\\*)"', '$1$1\"')
            $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
            '"' + $escaped + '"'
        }
    }
    return (@($parts) -join ' ')
}

function Get-CDTErrorInfo {
    <#
    .SYNOPSIS
        Extrahiert HRESULT (hex) und eine bekannte Erklaerung aus ErrorRecord und/oder Text.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowNull()][System.Management.Automation.ErrorRecord]$ErrorRecord = $null,
        [AllowNull()][AllowEmptyString()][string]$Text = ''
    )
    $codes = [System.Collections.Generic.List[string]]::new()
    $allText = [string]$Text
    if ($null -ne $ErrorRecord) {
        $ex = $ErrorRecord.Exception
        while ($null -ne $ex) {
            if ($ex.HResult -ne 0) { $codes.Add(('0x{0:X8}' -f $ex.HResult)) }
            $allText = $allText + ' ' + $ex.Message
            $ex = $ex.InnerException
        }
    }
    foreach ($m in [regex]::Matches($allText, '0x[0-9A-Fa-f]{8}')) { $codes.Add(('0x' + $m.Value.Substring(2).ToUpperInvariant())) }
    foreach ($m in [regex]::Matches($allText, '(?i)(?:ErrorCode|HRESULT|Fehlercode)\s*[:=]\s*(-?\d{5,})')) {
        $codes.Add(('0x{0:X8}' -f [int64]::Parse($m.Groups[1].Value)).Replace('0xFFFFFFFF', '0x'))
    }
    $generic = @('0x80131500', '0x80131501', '0x80004005', '0x80131509')
    $selected = ''
    foreach ($c in $codes) { if ($script:KnownErrors.ContainsKey($c)) { $selected = $c; break } }
    if (-not $selected) { foreach ($c in $codes) { if ($generic -notcontains $c) { $selected = $c; break } } }
    if (-not $selected -and $codes.Count -gt 0) { $selected = $codes[0] }
    $explanation = ''
    if ($selected -and $script:KnownErrors.ContainsKey($selected)) { $explanation = $script:KnownErrors[$selected] }
    return [pscustomobject]@{ HResult = $selected; Explanation = $explanation; AllCodes = @($codes | Select-Object -Unique) }
}
#endregion

#region Logging
function Write-CDTLog {
    <#
    .SYNOPSIS
        Schreibt eine Logzeile (ISO-Zeitstempel, Level, Mode, Phase) ins Hauptlog, bei WARN/ERROR zusaetzlich ins Fehlerlog.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')][string]$Level = 'INFO'
    )
    $line = '{0} [{1,-5}] [Mode={2}] [Phase={3}] {4}' -f (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffzzz'), $Level, $script:ModeName, $script:CurrentPhase, (Get-CDTMaskedText -Text $Message)
    if ($script:LogFile) {
        try { [System.IO.File]::AppendAllText($script:LogFile, $line + [Environment]::NewLine, $script:Utf8NoBom) }
        catch { $script:LogWriteFailures++ }
    }
    if (($Level -eq 'WARN' -or $Level -eq 'ERROR') -and $script:ErrorLogFile) {
        try { [System.IO.File]::AppendAllText($script:ErrorLogFile, $line + [Environment]::NewLine, $script:Utf8NoBom) }
        catch { $script:LogWriteFailures++ }
    }
    if ($script:ConsoleOutput -and $Level -ne 'DEBUG') {
        Write-Information -MessageData $line -InformationAction Continue
    }
}

function Write-CDTErrorRecord {
    <#
    .SYNOPSIS
        Protokolliert einen Fehler mit Exception-Typ, HRESULT (hex), Message, ScriptStackTrace und Zeile.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Context = ''
    )
    $info = Get-CDTErrorInfo -ErrorRecord $ErrorRecord
    $lineNo = 0
    $lineText = ''
    if ($null -ne $ErrorRecord.InvocationInfo) {
        $lineNo = $ErrorRecord.InvocationInfo.ScriptLineNumber
        $lineText = ([string]$ErrorRecord.InvocationInfo.Line).Trim()
    }
    $summary = '{0}: {1} | Typ={2} | HRESULT={3} | Zeile={4}' -f $Context, $ErrorRecord.Exception.Message, $ErrorRecord.Exception.GetType().FullName, $info.HResult, $lineNo
    if ($info.Explanation) { $summary = $summary + ' | Hinweis: ' + $info.Explanation }
    Write-CDTLog -Level ERROR -Message $summary
    if ($script:ErrorLogFile) {
        $detail = [System.Text.StringBuilder]::new()
        $null = $detail.AppendLine(('    Befehl     : {0}' -f $lineText))
        $null = $detail.AppendLine(('    Kategorie  : {0}' -f $ErrorRecord.CategoryInfo))
        $null = $detail.AppendLine(('    HRESULTs   : {0}' -f (@($info.AllCodes) -join ', ')))
        $inner = $ErrorRecord.Exception.InnerException
        while ($null -ne $inner) {
            $null = $detail.AppendLine(('    Inner      : {0}: {1} (0x{2:X8})' -f $inner.GetType().FullName, $inner.Message, $inner.HResult))
            $inner = $inner.InnerException
        }
        $null = $detail.AppendLine('    StackTrace :')
        foreach ($l in ([string]$ErrorRecord.ScriptStackTrace -split "`r?`n")) { $null = $detail.AppendLine('      ' + $l) }
        try { [System.IO.File]::AppendAllText($script:ErrorLogFile, (Get-CDTMaskedText -Text $detail.ToString()), $script:Utf8NoBom) }
        catch { $script:LogWriteFailures++ }
    }
}

function Enter-CDTPhase {
    <#
    .SYNOPSIS
        Setzt die aktuelle Phase fuer Log und Zustand.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Name)
    $script:CurrentPhase = $Name
}

function Invoke-CDTStep {
    <#
    .SYNOPSIS
        Fuehrt einen Schritt mit Dauer-Logging aus; Fehler werden geloggt und weitergereicht.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$StepName,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    $cdtStepWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-CDTLog -Message ('-> {0}' -f $StepName)
    try {
        $cdtStepResult = & $Action
        Write-CDTLog -Message ('<- {0}: OK ({1:N1} s)' -f $StepName, $cdtStepWatch.Elapsed.TotalSeconds)
        return $cdtStepResult
    }
    catch {
        Write-CDTLog -Level ERROR -Message ('<- {0}: FEHLER nach {1:N1} s' -f $StepName, $cdtStepWatch.Elapsed.TotalSeconds)
        throw
    }
}

function Initialize-CDTLogging {
    <#
    .SYNOPSIS
        Legt Log-Verzeichnis und Logdateien (UTF-8 mit BOM) an.
    #>
    [CmdletBinding()]
    param()
    if (-not (Test-Path -LiteralPath $script:Cfg.LogRoot)) { $null = New-Item -Path $script:Cfg.LogRoot -ItemType Directory -Force }
    $vm = $env:COMPUTERNAME
    $script:LogFile = Join-Path -Path $script:Cfg.LogRoot -ChildPath ('{0}_{1}_{2}.log' -f $vm, $script:ScriptBaseName, $script:RunTimestamp)
    $script:ErrorLogFile = Join-Path -Path $script:Cfg.LogRoot -ChildPath ('{0}_{1}_Error-Log_{2}.log' -f $vm, $script:ScriptBaseName, $script:RunTimestamp)
    $script:ComplianceFile = Join-Path -Path $script:Cfg.LogRoot -ChildPath ('{0}_{1}_Compliance_{2}.csv' -f $vm, $script:ScriptBaseName, $script:RunTimestamp)
    $script:TranscriptFile = Join-Path -Path $script:Cfg.LogRoot -ChildPath ('{0}_{1}_Transcript_{2}.log' -f $vm, $script:ScriptBaseName, $script:RunTimestamp)
    $script:DismLogFile = Join-Path -Path $script:Cfg.LogRoot -ChildPath ('{0}_{1}_DISM_{2}.log' -f $vm, $script:ScriptBaseName, $script:RunTimestamp)
    foreach ($file in @($script:LogFile, $script:ErrorLogFile)) {
        [System.IO.File]::WriteAllBytes($file, $script:Utf8Bom.GetPreamble())
    }
}

function Open-CDTTranscript {
    <#
    .SYNOPSIS
        Startet ein Transcript; ein bereits laufendes Wrapper-Transcript fuehrt nur zu einer Warnung.
    #>
    [CmdletBinding()]
    param()
    try {
        $null = Start-Transcript -Path $script:TranscriptFile -Force
        $script:TranscriptActive = $true
    }
    catch {
        Write-CDTLog -Level WARN -Message ('Start-Transcript nicht moeglich (laeuft evtl. bereits im Wrapper): {0}' -f $_.Exception.Message)
    }
}

function Close-CDTTranscript {
    <#
    .SYNOPSIS
        Beendet das eigene Transcript.
    #>
    [CmdletBinding()]
    param()
    if (-not $script:TranscriptActive) { return }
    try { $null = Stop-Transcript; $script:TranscriptActive = $false }
    catch { Write-CDTLog -Level WARN -Message ('Stop-Transcript: {0}' -f $_.Exception.Message) }
}
#endregion

#region Native Prozesse, Registry und Zustand
function Invoke-CDTNativeCommand {
    <#
    .SYNOPSIS
        Startet ein natives Programm mit Timeout, faengt StdOut/StdErr ab und loggt nur maskiert.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [AllowEmptyCollection()][string[]]$ArgumentList = @(),
        [ValidateRange(1, 86400)][int]$TimeoutSeconds = 3600,
        [switch]$NoLog
    )
    $argString = ConvertTo-CDTArgumentString -ArgumentList $ArgumentList
    if (-not $NoLog) { Write-CDTLog -Message ('Starte: {0} {1}' -f $FilePath, $argString) }
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.Arguments = $argString
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    try {
        $null = $proc.Start()
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            try { $proc.Kill() } catch { Write-CDTLog -Level WARN -Message ('Prozess {0} konnte nicht beendet werden: {1}' -f $FilePath, $_.Exception.Message) }
            throw ('Timeout nach {0} s: {1}' -f $TimeoutSeconds, $FilePath)
        }
        $proc.WaitForExit()
        $result = [pscustomobject]@{ ExitCode = $proc.ExitCode; StdOut = [string]$outTask.Result; StdErr = [string]$errTask.Result }
        if (-not $NoLog) { Write-CDTLog -Message ('{0} beendet mit ExitCode {1}' -f (Split-Path -Path $FilePath -Leaf), $result.ExitCode) }
        return $result
    }
    finally {
        $proc.Dispose()
    }
}

function Get-CDTRegistryValue {
    <#
    .SYNOPSIS
        Liest einen Registry-Wert; liefert Default, wenn Schluessel/Wert fehlt.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][object]$Default = $null
    )
    if (-not (Test-Path -LiteralPath $Path)) { return $Default }
    $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $Default }
    return (Get-CDTPropertyValue -InputObject $item -Name $Name -Default $Default)
}

function Write-CDTRegistryValue {
    <#
    .SYNOPSIS
        Schreibt einen Registry-Wert (legt den Schluessel bei Bedarf an).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][AllowEmptyString()][object]$Value,
        [ValidateSet('String', 'ExpandString', 'DWord', 'QWord', 'MultiString', 'Binary')][string]$Type = 'String'
    )
    if (-not (Test-Path -LiteralPath $Path)) { $null = New-Item -Path $Path -Force }
    $null = New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force
}

function Clear-CDTRegistryValue {
    <#
    .SYNOPSIS
        Entfernt einen Registry-Wert, falls vorhanden.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($null -ne (Get-CDTRegistryValue -Path $Path -Name $Name)) {
        Remove-ItemProperty -LiteralPath $Path -Name $Name -Force
    }
}

function Get-CDTStateKey {
    <#
    .SYNOPSIS
        Registry-Pfad des Zustandsmodells.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    return ('HKLM:\SOFTWARE\CDT\LanguageDeployment\{0}' -f $script:Cfg.Language)
}

function Get-CDTState {
    <#
    .SYNOPSIS
        Liest einen Zustandswert.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][object]$Default = $null
    )
    return (Get-CDTRegistryValue -Path (Get-CDTStateKey) -Name $Name -Default $Default)
}

function Save-CDTState {
    <#
    .SYNOPSIS
        Schreibt einen Zustandswert (String oder DWord) und loggt die Aenderung.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][AllowEmptyString()][object]$Value,
        [ValidateSet('String', 'DWord')][string]$Type = 'String'
    )
    Write-CDTRegistryValue -Path (Get-CDTStateKey) -Name $Name -Value $Value -Type $Type
    Write-CDTLog -Level DEBUG -Message ('Zustand: {0} = {1}' -f $Name, $Value)
}

function Clear-CDTState {
    <#
    .SYNOPSIS
        Entfernt einen Zustandswert.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Name)
    Clear-CDTRegistryValue -Path (Get-CDTStateKey) -Name $Name
}
#endregion

#region Konfiguration und Vorpruefungen
function Build-CDTConfiguration {
    <#
    .SYNOPSIS
        Erzeugt das Konfigurationsobjekt aus dem Parameter-Snapshot und Nerdio Secure Variables.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([hashtable]$Parameter = $script:ParamSnapshot)
    $p = $Parameter
    $lcuList = @(@($p.LcuUrl) | ForEach-Object { ([string]$_) -split '[;,\s]+' } | Where-Object { $_ })
    $cfg = [pscustomobject]@{
        Mode                         = [string]$p.Mode
        Language                     = [string]$p.Language
        GeoId                        = [int]$p.GeoId
        TimeZone                     = [string]$p.TimeZone
        InputLocale                  = [string]$p.InputLocale
        RepositoryPath               = [string]$p.RepositoryPath
        RepositoryZipUrl             = [string]$p.RepositoryZipUrl
        StorageAccountKey            = [string]$p.StorageAccountKey
        LofIsoUrl                    = [string]$p.LofIsoUrl
        IsoPath                      = [string]$p.IsoPath
        ForceIsoSource               = [bool]$p.ForceIsoSource
        TempPath                     = [string]$p.TempPath
        LcuPath                      = [string]$p.LcuPath
        LcuUrl                       = $lcuList
        UseWindowsUpdateForNewerLcu  = [bool]$p.UseWindowsUpdateForNewerLcu
        ExcludeFeatures              = @(@($p.ExcludeFeatures) | Where-Object { $_ })
        CleanupAppxForSysprep        = [bool]$p.CleanupAppxForSysprep
        RestrictUserLanguageInstall  = [bool]$p.RestrictUserLanguageInstall
        IncludeWinRELanguage         = [bool]$p.IncludeWinRELanguage
        RebootIfRequired             = [bool]$p.RebootIfRequired
        ForceReboot                  = [bool]$p.ForceReboot
        ForceRebootOnError           = [bool]$p.ForceRebootOnError
        RebootDelaySeconds           = [int]$p.RebootDelaySeconds
        RebootRequiredExitCode       = [int]$p.RebootRequiredExitCode
        LogRoot                      = [string]$p.LogRoot
        LogRetentionDays             = [int]$p.LogRetentionDays
        MaxRuntimeMinutes            = [int]$p.MaxRuntimeMinutes
        InstallTimeoutMinutes        = [int]$p.InstallTimeoutMinutes
        InstallRetryCount            = [int]$p.InstallRetryCount
        AllowTemporaryWuPolicyBypass = [bool]$p.AllowTemporaryWuPolicyBypass
        AutoTimeZoneUpdate           = [string]$p.AutoTimeZoneUpdate
        CollectWindowsUpdateLog      = [bool]$p.CollectWindowsUpdateLog
        SecureVarsUsed               = $false
    }
    $secureVars = $p.SecureVars
    if ($null -ne $secureVars) {
        $map = [ordered]@{
            StorageAccountKey = 'CDTLangStorageAccountKey'
            RepositoryZipUrl  = 'CDTLangRepositoryZipUrl'
            RepositoryPath    = 'CDTLangRepositoryPath'
            LcuUrl            = 'CDTLangLcuUrl'
            LcuPath           = 'CDTLangLcuPath'
        }
        foreach ($target in $map.Keys) {
            $val = Get-CDTPropertyValue -InputObject $secureVars -Name $map[$target]
            if ($null -eq $val -or [string]::IsNullOrWhiteSpace([string]$val)) { continue }
            if ($target -eq 'LcuUrl') {
                if (@($cfg.LcuUrl).Count -eq 0) {
                    $cfg.LcuUrl = @(([string]$val) -split '[;,\s]+' | Where-Object { $_ })
                    $cfg.SecureVarsUsed = $true
                }
            }
            elseif ([string]::IsNullOrWhiteSpace([string]$cfg.$target)) {
                $cfg.$target = [string]$val
                $cfg.SecureVarsUsed = $true
            }
        }
    }
    Add-CDTSecret -Value $cfg.StorageAccountKey
    Add-CDTSecret -Value $cfg.RepositoryZipUrl
    foreach ($u in @($cfg.LcuUrl)) { Add-CDTSecret -Value $u }
    return $cfg
}

function Test-CDTSafeTempPath {
    <#
    .SYNOPSIS
        Prueft, ob TempPath gefahrlos rekursiv geloescht werden darf.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][AllowEmptyString()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $p = $Path.Trim().TrimEnd('\')
    if ($p -notmatch '^[A-Za-z]:\\') { return $false }
    if ($p -match '\.\.' -or $p -match '[*?]') { return $false }
    $segments = @($p.Substring(3).Split('\') | Where-Object { $_ })
    if ($segments.Count -lt 1) { return $false }
    $protected = @('Windows', 'Program Files', 'Program Files (x86)', 'ProgramData', 'Users', 'Recovery', 'Boot', 'System Volume Information', '$Recycle.Bin', 'PerfLogs')
    if ($protected -contains $segments[0]) { return $false }
    if ($segments.Count -lt 2 -and $segments[-1] -notmatch '(?i)(CDT|tmp|temp)') { return $false }
    return $true
}

function Test-CDTParameterConsistency {
    <#
    .SYNOPSIS
        Prueft Parameterkombinationen vor jeder Aenderung (ersetzt die Parameter-Sets).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory = $true)][pscustomobject]$Config)
    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    if ($Config.RebootIfRequired -and $Config.ForceReboot) {
        $errors.Add('-RebootIfRequired und -ForceReboot schliessen sich gegenseitig aus.')
    }
    if ($Config.ForceRebootOnError -and -not $Config.ForceReboot) {
        $warnings.Add('-ForceRebootOnError wirkt nur zusammen mit -ForceReboot und wird ignoriert.')
    }
    $excl = @($Config.ExcludeFeatures)
    if (($excl -contains 'TextToSpeech') -and -not ($excl -contains 'Speech')) {
        $errors.Add('Speech benoetigt TextToSpeech (Microsoft: Abhaengigkeit). Speech ebenfalls abwaehlen oder TextToSpeech installieren.')
    }
    foreach ($pair in @(@('RepositoryZipUrl', $Config.RepositoryZipUrl), @('LofIsoUrl', $Config.LofIsoUrl))) {
        if (-not [string]::IsNullOrWhiteSpace([string]$pair[1]) -and [string]$pair[1] -notmatch '^(?i)https://') {
            $errors.Add(('-{0} muss eine HTTPS-URL sein.' -f $pair[0]))
        }
    }
    foreach ($u in @($Config.LcuUrl)) {
        if ($u -notmatch '^(?i)https://') { $errors.Add('-LcuUrl muss HTTPS-URLs enthalten.'); break }
    }
    if (@(3020, 3030, 3040, 3050) -contains $Config.RebootRequiredExitCode) {
        $errors.Add(('-RebootRequiredExitCode {0} kollidiert mit einem anderen Status-Code.' -f $Config.RebootRequiredExitCode))
    }
    if (-not (Test-CDTSafeTempPath -Path $Config.TempPath)) {
        $errors.Add(('-TempPath "{0}" ist nicht sicher loeschbar (lokaler Pfad, nicht unter Windows/Programme/Users, mindestens 2 Ebenen oder Name mit CDT/tmp).' -f $Config.TempPath))
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Config.LogRoot) -and ($Config.LogRoot.TrimEnd('\') + '\').StartsWith(($Config.TempPath.TrimEnd('\') + '\'), [System.StringComparison]::OrdinalIgnoreCase)) {
        $errors.Add('-LogRoot darf nicht innerhalb von -TempPath liegen (TempPath wird geloescht).')
    }
    if (-not [string]::IsNullOrWhiteSpace($Config.RepositoryPath) -and $Config.RepositoryPath -notmatch '^(\\\\[^\\]+\\[^\\]+|[A-Za-z]:\\)') {
        $errors.Add('-RepositoryPath muss ein UNC-Pfad (\\server\share\...) oder lokaler Pfad sein.')
    }
    if (-not [string]::IsNullOrWhiteSpace($Config.StorageAccountKey) -and $Config.RepositoryPath -notmatch '^\\\\' -and $Config.LcuPath -notmatch '^\\\\') {
        $warnings.Add('-StorageAccountKey ist gesetzt, aber weder -RepositoryPath noch -LcuPath ist ein UNC-Pfad.')
    }
    if ($Config.CleanupAppxForSysprep -and $Config.Mode -ne 'PreSysprep') {
        $warnings.Add('-CleanupAppxForSysprep wirkt nur in Mode PreSysprep.')
    }
    return [pscustomobject]@{ Errors = $errors.ToArray(); Warnings = $warnings.ToArray() }
}

function Get-CDTOsInfo {
    <#
    .SYNOPSIS
        Liest Build, UBR, Edition und Release aus der Registry (kein wmic).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $cv = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $build = [int](Get-CDTRegistryValue -Path $cv -Name 'CurrentBuildNumber' -Default '0')
    $ubr = [int](Get-CDTRegistryValue -Path $cv -Name 'UBR' -Default 0)
    return [pscustomobject]@{
        Build            = $build
        Ubr              = $ubr
        BuildUbr         = ('{0}.{1}' -f $build, $ubr)
        DisplayVersion   = [string](Get-CDTRegistryValue -Path $cv -Name 'DisplayVersion' -Default '')
        EditionId        = [string](Get-CDTRegistryValue -Path $cv -Name 'EditionID' -Default '')
        ProductName      = [string](Get-CDTRegistryValue -Path $cv -Name 'ProductName' -Default '')
        InstallationType = [string](Get-CDTRegistryValue -Path $cv -Name 'InstallationType' -Default '')
    }
}

function Get-CDTServicingBaseBuild {
    <#
    .SYNOPSIS
        Ordnet den OS-Build dem Servicing-Basisbuild zu (24H2/25H2/26H2 -> 26100).
    .DESCRIPTION
        PackageBuild = Build-Anteil der Version eines installierten Client-Sprachpakets (Beleg vom System).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][int]$CurrentBuild,
        [int]$PackageBuild = 0
    )
    $known = $script:SupportedBuilds.ContainsKey($CurrentBuild)
    $res = [ordered]@{ CurrentBuild = $CurrentBuild; Release = ''; Supported = $true; Known = $known; BaseBuild = 0; Severity = 'INFO'; Message = '' }
    if ($CurrentBuild -lt $script:ServicingBaseBuild) {
        $res.Supported = $false
        $res.Severity = 'ERROR'
        $res.Message = ('Build {0} ist kleiner als 26100: nicht unterstuetzt (Windows 11 24H2 oder neuer erforderlich).' -f $CurrentBuild)
    }
    elseif ($known) {
        $res.Release = $script:SupportedBuilds[$CurrentBuild]
        $res.BaseBuild = $script:ServicingBaseBuild
        $res.Message = ('Build {0} ({1}) -> Servicing-Basis {2}.' -f $CurrentBuild, $res.Release, $script:ServicingBaseBuild)
        if ($PackageBuild -gt 0 -and $PackageBuild -ne $script:ServicingBaseBuild) {
            $res.Severity = 'WARN'
            $res.BaseBuild = $PackageBuild
            $res.Message = ('Build {0}: installiertes Sprachpaket meldet Basis {1} statt {2} - Basis aus Sprachpaket verwendet.' -f $CurrentBuild, $PackageBuild, $script:ServicingBaseBuild)
        }
    }
    else {
        $res.Severity = 'WARN'
        if ($PackageBuild -gt 0) {
            $res.BaseBuild = $PackageBuild
            $res.Message = ('Unbekannter neuerer Build {0}: Basis {1} aus installiertem Sprachpaket abgeleitet. Weiter mit Warnung.' -f $CurrentBuild, $PackageBuild)
        }
        else {
            $res.Message = ('Unbekannter Build {0}: Servicing-Basis nicht ermittelbar - Stufe 2/3 gesperrt, nur Stufe 1.' -f $CurrentBuild)
        }
    }
    return [pscustomobject]$res
}

function Get-CDTIsoBuildFromName {
    <#
    .SYNOPSIS
        Liest den Hauptbuild aus einem LOF-ISO-Dateinamen (z. B. 26100.1.240331-...iso -> 26100).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([AllowEmptyString()][string]$Name)
    if ($Name -match '(?:^|[\\/])(\d{5})\.\d+\.') { return [int]$Matches[1] }
    return 0
}

function Get-CDTExecutionContext {
    <#
    .SYNOPSIS
        Liefert Benutzer, SID, Admin-Status und Prozessarchitektur.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]::new($id)
    return [pscustomobject]@{
        User           = $id.Name
        Sid            = $id.User.Value
        IsSystem       = ($id.User.Value -eq 'S-1-5-18')
        IsAdmin        = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        Is64BitProcess = [Environment]::Is64BitProcess
        PSVersion      = $PSVersionTable.PSVersion.ToString()
        PSEdition      = [string](Get-CDTPropertyValue -InputObject $PSVersionTable -Name 'PSEdition' -Default 'Desktop')
    }
}

function Test-CDTPrerequisite {
    <#
    .SYNOPSIS
        Prueft Kontext, PowerShell, OS-Build und Module. Liefert Ok=$false bei harten Fehlern.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $ok = $true
    $ctx = Get-CDTExecutionContext
    Write-CDTLog -Message ('Kontext: {0} ({1}), Admin={2}, 64-Bit={3}, PowerShell {4} {5}' -f $ctx.User, $ctx.Sid, $ctx.IsAdmin, $ctx.Is64BitProcess, $ctx.PSVersion, $ctx.PSEdition)
    if (-not $ctx.IsAdmin) { Write-CDTLog -Level ERROR -Message 'Administratorrechte bzw. SYSTEM-Kontext erforderlich.'; $ok = $false }
    if (-not $ctx.IsSystem) { Write-CDTLog -Level WARN -Message 'Nicht im SYSTEM-Kontext: Einstellungen werden ueber den aktuellen Admin-Benutzer kopiert (Nerdio/HYDRA laufen als SYSTEM).' }
    if (-not $ctx.Is64BitProcess) { Write-CDTLog -Level ERROR -Message '64-Bit-PowerShell erforderlich (DISM/Registry-Umleitung).'; $ok = $false }
    if ($PSVersionTable.PSVersion.Major -ne 5) { Write-CDTLog -Level WARN -Message ('Getestet fuer Windows PowerShell 5.1, gefunden: {0}.' -f $ctx.PSVersion) }

    $os = Get-CDTOsInfo
    Write-CDTLog -Message ('OS: {0} | Build {1} | DisplayVersion {2} | Edition {3} | Typ {4}' -f $os.ProductName, $os.BuildUbr, $os.DisplayVersion, $os.EditionId, $os.InstallationType)
    $pkgBuild = Get-CDTInstalledLanguagePackBuild -PreferLanguage 'en-US'
    $base = Get-CDTServicingBaseBuild -CurrentBuild $os.Build -PackageBuild $pkgBuild
    $level = 'INFO'
    if ($base.Severity -eq 'WARN') { $level = 'WARN' } elseif ($base.Severity -eq 'ERROR') { $level = 'ERROR' }
    Write-CDTLog -Level $level -Message $base.Message
    if (-not $base.Supported) { $ok = $false }
    if ($base.Known -and $base.Release -eq '26H2') {
        Write-CDTLog -Level WARN -Message 'Windows 11 26H2: LOF-ISO 26100 ist im AVD-Artikel nur fuer 24H2/25H2 gelistet (fuer 26H2 unbestaetigt). Basis 26100 wird verwendet.'
    }
    if ($os.EditionId -notmatch '(?i)Enterprise|ServerRdsh') { Write-CDTLog -Level WARN -Message ('Edition {0} ist nicht Windows 11 Enterprise / Enterprise multi-session.' -f $os.EditionId) }

    foreach ($module in @('LanguagePackManagement', 'International', 'Dism')) {
        if ($null -eq (Get-Module -ListAvailable -Name $module)) {
            Write-CDTLog -Level ERROR -Message ('PowerShell-Modul {0} fehlt.' -f $module)
            $ok = $false
        }
    }
    $sysDrive = [System.IO.DriveInfo]::new($env:SystemDrive)
    $freeGb = [Math]::Round($sysDrive.AvailableFreeSpace / 1GB, 1)
    $freeLevel = 'INFO'
    if ($freeGb -lt 10) { $freeLevel = 'WARN' }
    Write-CDTLog -Level $freeLevel -Message ('Freier Speicher {0}: {1} GB' -f $env:SystemDrive, $freeGb)
    return [pscustomobject]@{ Ok = $ok; Os = $os; Base = $base; Context = $ctx }
}
#endregion

#region Systemzustand (Pakete, Capabilities, Reboot, Policies)
function Get-CDTWindowsPackageList {
    <#
    .SYNOPSIS
        Liefert Get-WindowsPackage -Online (gecacht, mit -Refresh neu eingelesen).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([switch]$Refresh)
    if ($Refresh -or $null -eq $script:PackageCache) {
        $script:PackageCache = @(Get-WindowsPackage -Online)
    }
    return $script:PackageCache
}

function Get-CDTInstalledLanguagePackBuild {
    <#
    .SYNOPSIS
        Build-Anteil der Version eines installierten Client-Sprachpakets (Beleg fuer die Servicing-Basis).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([string]$PreferLanguage = '')
    try {
        $lps = @(Get-CDTWindowsPackageList | Where-Object { $_.PackageName -like 'Microsoft-Windows-Client-LanguagePack-Package~31bf3856ad364e35~*' -and ([string]$_.PackageState) -in @('Installed', 'InstallPending') })
    }
    catch {
        Write-CDTLog -Level WARN -Message ('Get-WindowsPackage fehlgeschlagen: {0}' -f $_.Exception.Message)
        return 0
    }
    if ($lps.Count -eq 0) { return 0 }
    $pick = $lps[0]
    if ($PreferLanguage) {
        $pref = @($lps | Where-Object { ($_.PackageName -split '~')[3] -eq $PreferLanguage })
        if ($pref.Count -gt 0) { $pick = $pref[0] }
    }
    $version = ($pick.PackageName -split '~')[4]
    $parts = $version.Split('.')
    if ($parts.Count -ge 3) { return [int]$parts[2] }
    return 0
}

function Get-CDTRequiredCapability {
    <#
    .SYNOPSIS
        Liefert die zu installierenden Language-FoDs in Abhaengigkeitsreihenfolge (Basic zuerst, Speech nach TextToSpeech).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)][string]$Language,
        [AllowEmptyCollection()][string[]]$ExcludeFeatures = @()
    )
    $list = [System.Collections.Generic.List[object]]::new()
    $list.Add([pscustomobject]@{ Feature = 'Basic'; Name = ('Language.Basic~~~{0}~0.0.1.0' -f $Language) })
    if ($script:FontCapabilityMap.ContainsKey($Language)) {
        $list.Add([pscustomobject]@{ Feature = 'Fonts'; Name = $script:FontCapabilityMap[$Language] })
    }
    foreach ($feature in @('OCR', 'Handwriting', 'TextToSpeech', 'Speech')) {
        if (@($ExcludeFeatures) -notcontains $feature) {
            $list.Add([pscustomobject]@{ Feature = $feature; Name = ('Language.{0}~~~{1}~0.0.1.0' -f $feature, $Language) })
        }
    }
    return $list.ToArray()
}

function Get-CDTCapabilityState {
    <#
    .SYNOPSIS
        Status einer Capability ohne Windows-Update-Zugriff (-LimitAccess).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][string]$Name)
    try {
        $cap = @(Get-WindowsCapability -Online -Name $Name -LimitAccess -ErrorAction Stop)
        if ($cap.Count -eq 0) { return 'NotPresent' }
        return [string]$cap[0].State
    }
    catch {
        Write-CDTLog -Level DEBUG -Message ('Get-WindowsCapability {0}: {1}' -f $Name, $_.Exception.Message)
        return 'Unknown'
    }
}

function Get-CDTLanguageState {
    <#
    .SYNOPSIS
        Status von Sprachpaket und Pflicht-FoDs der Zielsprache.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([switch]$Refresh)
    $lang = $script:Cfg.Language
    $pkgs = Get-CDTWindowsPackageList -Refresh:$Refresh
    $lp = @($pkgs | Where-Object { $_.PackageName -like ('Microsoft-Windows-Client-LanguagePack-Package~31bf3856ad364e35~*~{0}~*' -f $lang) })
    $lpState = 'NotPresent'
    $lpName = ''
    $lpBuild = 0
    if ($lp.Count -gt 0) {
        $lpState = [string]$lp[0].PackageState
        $lpName = $lp[0].PackageName
        $verParts = (($lpName -split '~')[4]).Split('.')
        if ($verParts.Count -ge 3) { $lpBuild = [int]$verParts[2] }
    }
    $caps = foreach ($req in @(Get-CDTRequiredCapability -Language $lang -ExcludeFeatures $script:Cfg.ExcludeFeatures)) {
        [pscustomobject]@{ Feature = $req.Feature; Name = $req.Name; State = (Get-CDTCapabilityState -Name $req.Name) }
    }
    $caps = @($caps)
    $present = @('Installed', 'InstallPending')
    $lpPresent = $present -contains $lpState
    $capsPresent = (@($caps | Where-Object { $present -notcontains $_.State }).Count -eq 0)
    $pending = ($lpState -eq 'InstallPending') -or (@($caps | Where-Object { $_.State -eq 'InstallPending' }).Count -gt 0)
    return [pscustomobject]@{
        LanguagePackState   = $lpState
        LanguagePackName    = $lpName
        LanguagePackBuild   = $lpBuild
        LanguagePackPresent = $lpPresent
        Capabilities        = $caps
        CapabilitiesPresent = $capsPresent
        Complete            = ($lpPresent -and $capsPresent)
        PendingReboot       = $pending
    }
}

function Get-CDTPendingReboot {
    <#
    .SYNOPSIS
        Erkennt ausstehende Neustarts (CBS, Windows Update, PendingFileRenameOperations, DISM in diesem Lauf).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $reasons = [System.Collections.Generic.List[string]]::new()
    $blocking = $false
    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $reasons.Add('CBS:RebootPending'); $blocking = $true }
    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $reasons.Add('WindowsUpdate:RebootRequired'); $blocking = $true }
    $pfro = Get-CDTRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations'
    if ($null -ne $pfro -and @(@($pfro) | Where-Object { $_ }).Count -gt 0) { $reasons.Add('PendingFileRenameOperations') }
    if ($script:RestartNeeded) { $reasons.Add('DISM:RestartNeeded (dieser Lauf)'); $blocking = $true }
    return [pscustomobject]@{ Required = ($reasons.Count -gt 0); Blocking = $blocking; Reasons = $reasons.ToArray() }
}

function Get-CDTLastBootTime {
    <#
    .SYNOPSIS
        Letzter Systemstart (CIM statt wmic).
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param()
    return [datetime](Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
}

function Get-CDTWuPolicyFinding {
    <#
    .SYNOPSIS
        Liest WSUS-/WU-/Servicing-Policies, die Sprachpakete/FoDs blockieren koennen.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    $svc = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing'
    $defs = @(
        @{ Path = $au; Name = 'UseWUServer'; BlockValue = 1; Text = 'WSUS aktiv: Sprachpakete/FoDs nur, wenn WSUS sie (UUP) bereitstellt.' }
        @{ Path = $wu; Name = 'WUServer'; BlockValue = $null; Text = 'WSUS-Server konfiguriert.' }
        @{ Path = $wu; Name = 'DisableWindowsUpdateAccess'; BlockValue = 1; Text = 'Zugriff auf Windows Update per Policy gesperrt.' }
        @{ Path = $wu; Name = 'DoNotConnectToWindowsUpdateInternetLocations'; BlockValue = 1; Text = 'Keine Verbindung zu Windows-Update-Internetadressen.' }
        @{ Path = $wu; Name = 'SetPolicyDrivenUpdateSourceForQualityUpdates'; BlockValue = 0; Text = 'Quality-Updates (inkl. FoDs) auf WSUS festgelegt.' }
        @{ Path = $wu; Name = 'SetPolicyDrivenUpdateSourceForFeatureUpdates'; BlockValue = $null; Text = 'Scan-Quelle Feature-Updates konfiguriert.' }
        @{ Path = $au; Name = 'UseUpdateClassPolicySource'; BlockValue = $null; Text = 'Scan-Quellen-Policy aktiv.' }
        @{ Path = $au; Name = 'NoAutoUpdate'; BlockValue = $null; Text = 'Automatische Updates deaktiviert.' }
        @{ Path = $svc; Name = 'UseWindowsUpdate'; BlockValue = 2; Text = 'Servicing-Policy: nie von Windows Update laden (0x800F0954).' }
        @{ Path = $svc; Name = 'LocalSourcePath'; BlockValue = $null; Text = 'Alternative Reparaturquelle konfiguriert.' }
        @{ Path = $svc; Name = 'RepairContentServerSource'; BlockValue = $null; Text = 'Reparaturinhalte-Quelle konfiguriert.' }
        @{ Path = $script:IntlPolicyKey; Name = 'RestrictLanguagePacksAndFeaturesInstall'; BlockValue = 1; Text = 'Installation von Sprachpaketen/-features eingeschraenkt.' }
    )
    $findings = foreach ($d in $defs) {
        $value = Get-CDTRegistryValue -Path $d.Path -Name $d.Name
        if ($null -eq $value) { continue }
        $isBlocking = ($null -ne $d.BlockValue) -and ([string]$value -eq [string]$d.BlockValue)
        [pscustomobject]@{ Path = $d.Path; Name = $d.Name; Value = $value; Blocking = $isBlocking; Text = $d.Text }
    }
    return @($findings)
}
#endregion

#region Temporaere Aenderungen mit garantiertem Rollback
function Enable-CDTWuPolicyBypass {
    <#
    .SYNOPSIS
        Entschaerft blockierende WU-Policies temporaer; Backup vorher im Zustand (Absturzschutz).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Finding)
    $blocking = @($Finding | Where-Object { $_.Blocking })
    if ($blocking.Count -eq 0) { return $false }
    $backup = foreach ($f in $blocking) {
        $kind = (Get-Item -LiteralPath $f.Path).GetValueKind($f.Name).ToString()
        [pscustomobject]@{ Path = $f.Path; Name = $f.Name; Kind = $kind; Value = $f.Value }
    }
    Save-CDTState -Name 'PolicyBackupJson' -Value (ConvertTo-Json -InputObject @($backup) -Compress -Depth 4)
    foreach ($f in $blocking) {
        if ($f.Name -eq 'UseWUServer') { Write-CDTRegistryValue -Path $f.Path -Name $f.Name -Value 0 -Type DWord }
        else { Clear-CDTRegistryValue -Path $f.Path -Name $f.Name }
        Write-CDTLog -Level WARN -Message ('Policy temporaer entschaerft: {0}\{1} (vorher {2})' -f $f.Path, $f.Name, $f.Value)
    }
    try { Restart-Service -Name wuauserv -Force -ErrorAction Stop } catch { Write-CDTLog -Level WARN -Message ('wuauserv-Neustart: {0}' -f $_.Exception.Message) }
    return $true
}

function Restore-CDTWuPolicyBypass {
    <#
    .SYNOPSIS
        Stellt temporaer geaenderte Policies aus dem Zustand wieder her (finally und beim naechsten Start).
    #>
    [CmdletBinding()]
    param()
    $json = [string](Get-CDTState -Name 'PolicyBackupJson' -Default '')
    if ([string]::IsNullOrWhiteSpace($json)) { return }
    # PS 5.1 liefert ein JSON-Array als ein Objekt: per foreach (nicht @()) aufzaehlen
    $parsed = ConvertFrom-Json -InputObject $json
    foreach ($i in $parsed) {
        $value = $i.Value
        switch ($i.Kind) {
            'MultiString' { $value = [string[]]@($i.Value) }
            'Binary' { $value = [byte[]]@($i.Value) }
            'DWord' { $value = [int]$i.Value }
            'QWord' { $value = [long]$i.Value }
            default { $value = [string]$i.Value }
        }
        Write-CDTRegistryValue -Path $i.Path -Name $i.Name -Value $value -Type $i.Kind
        Write-CDTLog -Message ('Policy wiederhergestellt: {0}\{1} = {2}' -f $i.Path, $i.Name, $i.Value)
    }
    Clear-CDTState -Name 'PolicyBackupJson'
    try { Restart-Service -Name wuauserv -Force -ErrorAction Stop } catch { Write-CDTLog -Level WARN -Message ('wuauserv-Neustart: {0}' -f $_.Exception.Message) }
}

function Get-CDTTaskState {
    <#
    .SYNOPSIS
        Status eines Scheduled Tasks: Disabled, Ready, Running, NotFound oder Error.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$TaskPath,
        [Parameter(Mandatory = $true)][string]$TaskName
    )
    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($null -eq $task) { return 'NotFound' }
        return [string]@($task)[0].State
    }
    catch {
        Write-CDTLog -Level WARN -Message ('Get-ScheduledTask {0}{1}: {2}' -f $TaskPath, $TaskName, $_.Exception.Message)
        return 'Error'
    }
}

function Suspend-CDTLanguageInstallerTask {
    <#
    .SYNOPSIS
        Deaktiviert LanguageComponentsInstaller\Installation und \ReconcileLanguageResources waehrend der Installation.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    $suspended = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $script:InstallConflictTasks) {
        $state = Get-CDTTaskState -TaskPath $t.Path -TaskName $t.Name
        if ($state -eq 'Ready' -or $state -eq 'Running' -or $state -eq 'Queued') {
            try {
                $null = Disable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name
                $suspended.Add(('{0}|{1}' -f $t.Path, $t.Name))
                Write-CDTLog -Message ('Task temporaer deaktiviert: {0}{1}' -f $t.Path, $t.Name)
            }
            catch { Write-CDTLog -Level WARN -Message ('Task {0}{1} nicht deaktivierbar: {2}' -f $t.Path, $t.Name, $_.Exception.Message) }
        }
    }
    if ($suspended.Count -gt 0) { Save-CDTState -Name 'TempDisabledTasks' -Value ($suspended -join ';') }
    return $suspended.ToArray()
}

function Resume-CDTLanguageInstallerTask {
    <#
    .SYNOPSIS
        Aktiviert temporaer deaktivierte Installer-Tasks wieder (finally und beim naechsten Start).
    #>
    [CmdletBinding()]
    param([AllowEmptyCollection()][string[]]$Task = @())
    $list = @($Task)
    if ($list.Count -eq 0) {
        $saved = [string](Get-CDTState -Name 'TempDisabledTasks' -Default '')
        if ($saved) { $list = @($saved.Split(';') | Where-Object { $_ }) }
    }
    $failed = 0
    foreach ($entry in $list) {
        $parts = $entry.Split('|')
        try {
            $null = Enable-ScheduledTask -TaskPath $parts[0] -TaskName $parts[1]
            Write-CDTLog -Message ('Task wieder aktiviert: {0}{1}' -f $parts[0], $parts[1])
        }
        catch {
            $failed++
            Write-CDTLog -Level ERROR -Message ('Task {0}{1} konnte nicht reaktiviert werden: {2}' -f $parts[0], $parts[1], $_.Exception.Message)
        }
    }
    if ($failed -eq 0) { Clear-CDTState -Name 'TempDisabledTasks' }
}

function Restore-CDTCrashLeftover {
    <#
    .SYNOPSIS
        Raeumt Reste eines abgebrochenen Laufs auf (Policies, Tasks, ISO, WinRE, MS-13).
    #>
    [CmdletBinding()]
    param()
    if ([string](Get-CDTState -Name 'PolicyBackupJson' -Default '')) {
        Write-CDTLog -Level WARN -Message 'Policy-Backup eines abgebrochenen Laufs gefunden - Rollback.'
        Restore-CDTWuPolicyBypass
    }
    if ([string](Get-CDTState -Name 'TempDisabledTasks' -Default '')) {
        Write-CDTLog -Level WARN -Message 'Temporaer deaktivierte Tasks eines abgebrochenen Laufs gefunden - Reaktivierung.'
        Resume-CDTLanguageInstallerTask
    }
    $iso = [string](Get-CDTState -Name 'IsoMounted' -Default '')
    if ($iso) {
        Write-CDTLog -Level WARN -Message ('ISO eines abgebrochenen Laufs noch eingebunden: {0} - Dismount.' -f $iso)
        try { if (Test-Path -LiteralPath $iso) { $null = Dismount-DiskImage -ImagePath $iso } } catch { Write-CDTLog -Level WARN -Message ('Dismount: {0}' -f $_.Exception.Message) }
        Clear-CDTState -Name 'IsoMounted'
    }
    if ([int](Get-CDTState -Name 'WinReDisabledByScript' -Default 0) -eq 1) {
        Write-CDTLog -Level WARN -Message 'WinRE wurde in einem abgebrochenen Lauf deaktiviert - reagentc /enable.'
        $r = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\reagentc.exe') -ArgumentList @('/enable')
        if ($r.ExitCode -eq 0) { Clear-CDTState -Name 'WinReDisabledByScript' } else { Write-CDTLog -Level ERROR -Message 'reagentc /enable fehlgeschlagen - WinRE manuell pruefen.' }
    }
    if ([int](Get-CDTState -Name 'RestrictTemporarilyRemoved' -Default 0) -eq 1) {
        Write-CDTRegistryValue -Path $script:RestrictPolicy.Path -Name $script:RestrictPolicy.Name -Value 1 -Type DWord
        Clear-CDTState -Name 'RestrictTemporarilyRemoved'
        Write-CDTLog -Level WARN -Message 'MS-13-Policy eines abgebrochenen Laufs wiederhergestellt.'
    }
}
#endregion

#region Freigaben, Downloads, Signaturen, ISO
function Get-CDTUncShareRoot {
    <#
    .SYNOPSIS
        Zerlegt einen UNC-Pfad in Host, Share und Share-Root.
    #>
    [CmdletBinding()]
    param([AllowEmptyString()][string]$UncPath)
    if ($UncPath -match '^\\\\([^\\]+)\\([^\\]+)') {
        return [pscustomobject]@{ HostName = $Matches[1]; Share = $Matches[2]; Root = ('\\{0}\{1}' -f $Matches[1], $Matches[2]) }
    }
    return $null
}

function Clear-CDTCmdKey {
    <#
    .SYNOPSIS
        Entfernt cmdkey-Eintraege fuer einen Host (Microsoft: Share nach Nutzung trennen).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$HostName)
    $cmdkey = Join-Path -Path $env:SystemRoot -ChildPath 'System32\cmdkey.exe'
    $list = Invoke-CDTNativeCommand -FilePath $cmdkey -ArgumentList @('/list') -NoLog
    foreach ($m in [regex]::Matches($list.StdOut, '(?im)target=(\S+)')) {
        $target = $m.Groups[1].Value
        if ($target -like ('*{0}*' -f $HostName)) {
            $null = Invoke-CDTNativeCommand -FilePath $cmdkey -ArgumentList @(('/delete:{0}' -f $target)) -NoLog
            Write-CDTLog -Message ('cmdkey-Eintrag entfernt: {0}' -f $target)
        }
    }
}

function Test-CDTTcpPort {
    <#
    .SYNOPSIS
        Erreichbarkeitstest eines TCP-Ports mit Timeout (z. B. SMB 445 zu Azure Files).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][int]$Port,
        [int]$TimeoutMilliseconds = 5000
    )
    $tcp = [System.Net.Sockets.TcpClient]::new()
    try {
        $ar = $tcp.BeginConnect($HostName, $Port, $null, $null)
        return ($ar.AsyncWaitHandle.WaitOne($TimeoutMilliseconds) -and $tcp.Connected)
    }
    catch {
        Write-CDTLog -Level WARN -Message ('TCP-Test {0}:{1}: {2}' -f $HostName, $Port, $_.Exception.Message)
        return $false
    }
    finally { $tcp.Dispose() }
}

function Connect-CDTShare {
    <#
    .SYNOPSIS
        Verbindet einen UNC-Share temporaer (New-SmbMapping, Fallback net use /persistent:no).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$UncPath,
        [AllowEmptyString()][string]$AccountKey = '',
        [string]$StateName = 'RepositoryHost'
    )
    $share = Get-CDTUncShareRoot -UncPath $UncPath
    if ($null -eq $share) { throw ('Kein gueltiger UNC-Pfad: {0}' -f $UncPath) }
    Save-CDTState -Name $StateName -Value $share.HostName
    $conn = [pscustomobject]@{ Root = $share.Root; HostName = $share.HostName; Method = 'None' }
    Write-CDTLog -Message ('SMB 445 zu {0} erreichbar: {1}' -f $share.HostName, (Test-CDTTcpPort -HostName $share.HostName -Port 445))

    if ([string]::IsNullOrEmpty($AccountKey)) {
        if (-not (Test-Path -LiteralPath $UncPath)) { throw ('Pfad ohne Storage-Key nicht erreichbar: {0}' -f $UncPath) }
        return $conn
    }
    $account = $share.HostName.Split('.')[0]
    $user = 'localhost\{0}' -f $account
    try {
        $null = New-SmbMapping -RemotePath $share.Root -UserName $user -Password $AccountKey -Persistent $false -ErrorAction Stop
        $conn.Method = 'SmbMapping'
    }
    catch {
        Write-CDTLog -Level WARN -Message ('New-SmbMapping fehlgeschlagen ({0}) - Fallback net use.' -f $_.Exception.Message)
        $r = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\net.exe') -ArgumentList @('use', $share.Root, $AccountKey, ('/user:{0}' -f $user), '/persistent:no')
        if ($r.ExitCode -ne 0) { throw ('net use fehlgeschlagen ({0}): {1}' -f $r.ExitCode, (Get-CDTMaskedText -Text ($r.StdErr + $r.StdOut))) }
        $conn.Method = 'NetUse'
    }
    Write-CDTLog -Message ('Share verbunden ({0}): {1}' -f $conn.Method, $share.Root)
    if (-not (Test-Path -LiteralPath $UncPath)) { throw ('Pfad nach Verbindung nicht erreichbar: {0}' -f $UncPath) }
    return $conn
}

function Disconnect-CDTShare {
    <#
    .SYNOPSIS
        Trennt die temporaere Verbindung und entfernt cmdkey-Eintraege (immer im finally).
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Connection)
    if ($null -eq $Connection) { return }
    try { Remove-SmbMapping -RemotePath $Connection.Root -Force -UpdateProfile -ErrorAction Stop } catch { Write-CDTLog -Level DEBUG -Message ('Remove-SmbMapping: {0}' -f $_.Exception.Message) }
    $null = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\net.exe') -ArgumentList @('use', $Connection.Root, '/delete', '/y') -NoLog
    try { Clear-CDTCmdKey -HostName $Connection.HostName } catch { Write-CDTLog -Level WARN -Message ('cmdkey-Bereinigung: {0}' -f $_.Exception.Message) }
    Write-CDTLog -Message ('Share getrennt: {0}' -f $Connection.Root)
}

function Copy-CDTDirectory {
    <#
    .SYNOPSIS
        Kopiert ein Verzeichnis per robocopy (Exit-Codes kleiner 8 = Erfolg).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string[]]$FileFilter = @()
    )
    $robo = Join-Path -Path $env:SystemRoot -ChildPath 'System32\robocopy.exe'
    $robocopyArgs = @($Source, $Destination) + @($FileFilter) + @('/E', '/R:3', '/W:10', '/NP', '/NFL', '/NDL', '/MT:8')
    $r = Invoke-CDTNativeCommand -FilePath $robo -ArgumentList $robocopyArgs -TimeoutSeconds 7200
    if ($r.ExitCode -ge 8) { throw ('robocopy fehlgeschlagen (ExitCode {0}): {1}' -f $r.ExitCode, ($r.StdOut + $r.StdErr).Trim()) }
}

function Get-CDTWinHttpProxy {
    <#
    .SYNOPSIS
        Loggt die WinHTTP-Proxy-Konfiguration und liefert den HTTPS-Proxy (leer = direkt).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    try {
        $r = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\netsh.exe') -ArgumentList @('winhttp', 'show', 'proxy') -NoLog
        $text = ($r.StdOut -replace '\s+', ' ').Trim()
        Write-CDTLog -Message ('WinHTTP-Proxy: {0}' -f $text)
        $m = [regex]::Match($r.StdOut, '(?im)^\s*Proxy[- ]?Server(?:\(s\))?\s*:\s*(\S+)')
        if ($m.Success) {
            $proxy = $m.Groups[1].Value
            $https = [regex]::Match($proxy, '(?i)https=([^;]+)')
            if ($https.Success) { return $https.Groups[1].Value }
            if ($proxy -notmatch '=') { return $proxy }
        }
    }
    catch { Write-CDTLog -Level WARN -Message ('netsh winhttp show proxy: {0}' -f $_.Exception.Message) }
    return ''
}

function Get-CDTRemoteFileSize {
    <#
    .SYNOPSIS
        Ermittelt Content-Length per HEAD (curl.exe, Fallback HttpWebRequest). 0 = unbekannt.
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [AllowEmptyString()][string]$Proxy = ''
    )
    $curl = Join-Path -Path $env:SystemRoot -ChildPath 'System32\curl.exe'
    if (Test-Path -LiteralPath $curl) {
        $curlArgs = @('--head', '--location', '--silent', '--show-error', '--fail', '--max-time', '60')
        if ($Proxy) { $curlArgs += @('--proxy', $Proxy) }
        $r = Invoke-CDTNativeCommand -FilePath $curl -ArgumentList ($curlArgs + @($Url)) -TimeoutSeconds 120
        if ($r.ExitCode -eq 0) {
            $lengths = @([regex]::Matches($r.StdOut, '(?im)^content-length:\s*(\d+)') | ForEach-Object { [long]$_.Groups[1].Value })
            if ($lengths.Count -gt 0) { return $lengths[-1] }
        }
        else { Write-CDTLog -Level WARN -Message ('HEAD per curl fehlgeschlagen (ExitCode {0}): {1}' -f $r.ExitCode, $r.StdErr.Trim()) }
    }
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $req = [System.Net.WebRequest]::Create($Url)
        $req.Method = 'HEAD'
        $req.Timeout = 60000
        $resp = $req.GetResponse()
        try { return [long]$resp.ContentLength } finally { $resp.Close() }
    }
    catch {
        Write-CDTLog -Level WARN -Message ('HEAD-Request fehlgeschlagen: {0}' -f $_.Exception.Message)
        return [long]0
    }
}

function Invoke-CDTDownload {
    <#
    .SYNOPSIS
        Laedt eine Datei per curl.exe (Retry, Resume, --fail) mit Fallback Start-BitsTransfer; loggt Dauer und Durchsatz.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Destination,
        [ValidateRange(1, 1440)][int]$TimeoutMinutes = 60,
        [AllowEmptyString()][string]$Proxy = ''
    )
    $dir = Split-Path -Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -Path $dir -ItemType Directory -Force }
    Write-CDTLog -Message ('Download: {0} -> {1}' -f (Get-CDTUrlForLog -Url $Url), $Destination)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $ok = $false
    $curl = Join-Path -Path $env:SystemRoot -ChildPath 'System32\curl.exe'
    if (Test-Path -LiteralPath $curl) {
        $curlArgs = @('--fail', '--location', '--silent', '--show-error', '--retry', '5', '--retry-delay', '15', '--retry-all-errors',
            '--connect-timeout', '30', '--max-time', [string]($TimeoutMinutes * 60), '-C', '-', '--output', $Destination)
        if ($Proxy) { $curlArgs += @('--proxy', $Proxy) }
        $r = Invoke-CDTNativeCommand -FilePath $curl -ArgumentList ($curlArgs + @($Url)) -TimeoutSeconds (($TimeoutMinutes * 60) + 120)
        if ($r.ExitCode -eq 0) { $ok = $true }
        else { Write-CDTLog -Level WARN -Message ('curl fehlgeschlagen (ExitCode {0}): {1} - Fallback BITS.' -f $r.ExitCode, $r.StdErr.Trim()) }
    }
    if (-not $ok) {
        if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }
        try {
            Import-Module -Name BitsTransfer -ErrorAction Stop
            Start-BitsTransfer -Source $Url -Destination $Destination -Priority Foreground -ErrorAction Stop
            $ok = $true
        }
        catch { throw ('Download fehlgeschlagen (curl und BITS): {0}' -f (Get-CDTMaskedText -Text $_.Exception.Message)) }
    }
    $size = (Get-Item -LiteralPath $Destination).Length
    $seconds = [Math]::Max($watch.Elapsed.TotalSeconds, 0.1)
    Write-CDTLog -Message ('Download fertig: {0:N1} MB in {1:N0} s ({2:N1} MB/s)' -f ($size / 1MB), $seconds, (($size / 1MB) / $seconds))
    return $size
}

function Test-CDTCabSignature {
    <#
    .SYNOPSIS
        Prueft die Authenticode-Signatur (gueltig, Signer Microsoft) der Dateien. Liefert nur die beanstandeten Dateien.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([AllowEmptyCollection()][string[]]$FilePath = @())
    $bad = foreach ($f in $FilePath) {
        $status = 'Error'
        $subject = ''
        try {
            $sig = Get-AuthenticodeSignature -LiteralPath $f
            $status = [string]$sig.Status
            if ($null -ne $sig.SignerCertificate) { $subject = $sig.SignerCertificate.Subject }
        }
        catch { $subject = $_.Exception.Message }
        if ($status -ne 'Valid' -or $subject -notmatch 'O=Microsoft Corporation') {
            [pscustomobject]@{ File = (Split-Path -Path $f -Leaf); Status = $status; Signer = $subject }
        }
    }
    $bad = @($bad)
    Write-CDTLog -Message ('Authenticode-Pruefung: {0} Datei(en), {1} beanstandet.' -f @($FilePath).Count, $bad.Count)
    return $bad
}

function Get-CDTCabPackageBuild {
    <#
    .SYNOPSIS
        Build-Anteil der Paketversion einer .cab (Get-WindowsPackage -PackagePath); 0 = nicht ermittelbar.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory = $true)][string]$CabPath)
    try {
        $info = @(Get-WindowsPackage -Online -PackagePath $CabPath -ErrorAction Stop)
        if ($info.Count -gt 0) {
            $parts = (($info[0].PackageName -split '~')[-1]).Split('.')
            if ($parts.Count -ge 3) { return [int]$parts[2] }
        }
    }
    catch { Write-CDTLog -Level WARN -Message ('Paketversion von {0} nicht ermittelbar: {1}' -f (Split-Path -Path $CabPath -Leaf), $_.Exception.Message) }
    return 0
}

function Get-CDTUsedCabFile {
    <#
    .SYNOPSIS
        Liefert die fuer die Zielsprache verwendeten .cab-Dateien (Sprachpaket, Language-FoDs, Satelliten, Metadaten).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory = $true)][string]$Path)
    $lang = $script:Cfg.Language
    $files = @(Get-ChildItem -LiteralPath $Path -Filter '*.cab' -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ('*{0}*' -f $lang) -or $_.Name -like '*metadata*' })
    return @($files | ForEach-Object { $_.FullName })
}

function Mount-CDTIso {
    <#
    .SYNOPSIS
        Bindet ein ISO ein und ermittelt das Wurzelverzeichnis robust (Laufwerksbuchstabe oder mountvol-Ordner).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory = $true)][string]$ImagePath)
    $image = Mount-DiskImage -ImagePath $ImagePath -StorageType ISO -PassThru
    Save-CDTState -Name 'IsoMounted' -Value $ImagePath
    $volume = $null
    for ($i = 0; $i -lt 10 -and $null -eq $volume; $i++) {
        $volume = @($image | Get-Volume -ErrorAction SilentlyContinue) | Select-Object -First 1
        if ($null -eq $volume) { Start-Sleep -Seconds 2 }
    }
    if ($null -eq $volume) { throw 'Volume des eingebundenen ISO nicht gefunden.' }
    $letter = [string](Get-CDTPropertyValue -InputObject $volume -Name 'DriveLetter' -Default '')
    $mountFolder = ''
    if ($letter -match '^[A-Za-z]$') {
        $root = '{0}:\' -f $letter
    }
    else {
        $mountFolder = Join-Path -Path $script:Cfg.TempPath -ChildPath 'isomount'
        $null = New-Item -Path $mountFolder -ItemType Directory -Force
        $r = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\mountvol.exe') -ArgumentList @($mountFolder, [string]$volume.Path)
        if ($r.ExitCode -ne 0) { throw ('mountvol fehlgeschlagen: {0}' -f $r.StdErr) }
        $root = $mountFolder + '\'
    }
    Write-CDTLog -Message ('ISO eingebunden: {0} -> {1}' -f $ImagePath, $root)
    return [pscustomobject]@{ ImagePath = $ImagePath; Root = $root; MountFolder = $mountFolder }
}

function Dismount-CDTIso {
    <#
    .SYNOPSIS
        Haengt ein mit Mount-CDTIso eingebundenes ISO aus (immer im finally).
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Mount)
    if ($null -eq $Mount) { return }
    if ($Mount.MountFolder) {
        $null = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\mountvol.exe') -ArgumentList @($Mount.MountFolder, '/D') -NoLog
    }
    try {
        $null = Dismount-DiskImage -ImagePath $Mount.ImagePath
        Clear-CDTState -Name 'IsoMounted'
        Write-CDTLog -Message ('ISO ausgehaengt: {0}' -f $Mount.ImagePath)
    }
    catch { Write-CDTLog -Level ERROR -Message ('Dismount-DiskImage fehlgeschlagen: {0}' -f $_.Exception.Message) }
}

function Clear-CDTTempPath {
    <#
    .SYNOPSIS
        Loescht TempPath vollstaendig (ISO, Repository-Kopie, Downloads), damit nichts ins Image gelangt.
    #>
    [CmdletBinding()]
    param()
    $p = $script:Cfg.TempPath
    if (-not (Test-CDTSafeTempPath -Path $p)) { Write-CDTLog -Level WARN -Message ('TempPath nicht sicher loeschbar: {0}' -f $p); return }
    if (Test-Path -LiteralPath $p) {
        try {
            Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop
            Write-CDTLog -Message ('TempPath geloescht: {0}' -f $p)
        }
        catch { Write-CDTLog -Level ERROR -Message ('TempPath konnte nicht geloescht werden: {0}' -f $_.Exception.Message) }
    }
}
#endregion

#region Repository (Stufe 2) und ISO (Stufe 3)
function Resolve-CDTRepositoryFolder {
    <#
    .SYNOPSIS
        Findet den Repository-Versionsordner (mit manifest.json); waehlt bei mehreren die neueste Version.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Language,
        [int]$BaseBuild = 0
    )
    if (Test-Path -LiteralPath (Join-Path -Path $Root -ChildPath 'manifest.json')) { return $Root }
    $searchRoots = @($Root)
    if ($BaseBuild -gt 0) { $searchRoots += (Join-Path -Path $Root -ChildPath ([string]$BaseBuild)) }
    $candidates = foreach ($sr in $searchRoots) {
        if (-not (Test-Path -LiteralPath $sr)) { continue }
        Get-ChildItem -LiteralPath $sr -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like ('{0}_*' -f $Language) -and (Test-Path -LiteralPath (Join-Path -Path $_.FullName -ChildPath 'manifest.json')) }
    }
    $pick = @($candidates | Sort-Object -Property Name -Descending) | Select-Object -First 1
    if ($null -eq $pick) { throw ('Kein Repository-Versionsordner ({0}_*) mit manifest.json unter {1} gefunden.' -f $Language, $Root) }
    return $pick.FullName
}

function Test-CDTRepositoryManifest {
    <#
    .SYNOPSIS
        Prueft manifest.json: Hauptbuild, Sprache, Vollstaendigkeit und SHA256 aller Dateien.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$ExpectedBaseBuild,
        [Parameter(Mandatory = $true)][string]$Language
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $manifest = $null
    $manifestPath = Join-Path -Path $Path -ChildPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        $errors.Add('manifest.json fehlt.')
    }
    else {
        try { $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { $errors.Add(('manifest.json nicht lesbar: {0}' -f $_.Exception.Message)) }
    }
    $fileCount = 0
    if ($null -ne $manifest) {
        foreach ($required in @('schemaVersion', 'osBaseBuild', 'language', 'files')) {
            if ($null -eq $manifest.PSObject.Properties[$required]) { $errors.Add(('manifest.json: Feld {0} fehlt.' -f $required)) }
        }
        if ($errors.Count -eq 0) {
            if ($ExpectedBaseBuild -le 0) { $errors.Add('Servicing-Basisbuild des OS unbekannt - Repository kann nicht zugeordnet werden.') }
            elseif ([int]$manifest.osBaseBuild -ne $ExpectedBaseBuild) {
                $errors.Add(('Hauptbuild passt nicht: Repository {0}, OS-Basis {1} (Microsoft: Language components must match the version of Windows).' -f $manifest.osBaseBuild, $ExpectedBaseBuild))
            }
            if ([string]$manifest.language -ne $Language) { $errors.Add(('Sprache passt nicht: Repository {0}, erwartet {1}.' -f $manifest.language, $Language)) }
            $listed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($f in @($manifest.files)) {
                $rel = [string](Get-CDTPropertyValue -InputObject $f -Name 'path' -Default '')
                $hash = [string](Get-CDTPropertyValue -InputObject $f -Name 'sha256' -Default '')
                if ([string]::IsNullOrWhiteSpace($rel) -or $rel -match '\.\.' -or $rel -match '^[\\/]' -or $rel -match '^[A-Za-z]:') {
                    $errors.Add(('Ungueltiger Dateipfad im Manifest: {0}' -f $rel)); continue
                }
                $null = $listed.Add($rel.Replace('/', '\'))
                $full = Join-Path -Path $Path -ChildPath $rel
                if (-not (Test-Path -LiteralPath $full)) { $errors.Add(('Datei fehlt: {0}' -f $rel)); continue }
                $actual = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
                if ($actual -ne $hash) { $errors.Add(('SHA256 stimmt nicht: {0}' -f $rel)) }
                $fileCount++
            }
            $lpName = 'Microsoft-Windows-Client-Language-Pack_x64_{0}.cab' -f $Language.ToLowerInvariant()
            $hasLp = @(@($manifest.files) | Where-Object { (Split-Path -Path ([string](Get-CDTPropertyValue -InputObject $_ -Name 'path' -Default '')) -Leaf) -eq $lpName }).Count -gt 0
            if (-not $hasLp) { $errors.Add(('Sprachpaket {0} fehlt im Manifest.' -f $lpName)) }
            $rootFull = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\', '/')
            $actualFiles = @(Get-ChildItem -LiteralPath $rootFull -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'manifest.json' })
            $extra = 0
            foreach ($af in $actualFiles) {
                $relActual = $af.FullName.Substring($rootFull.Length).TrimStart('\', '/').Replace('/', '\')
                if (-not $listed.Contains($relActual)) { $extra++ }
            }
            if ($extra -gt 0) { $warnings.Add(('{0} Datei(en) im Repository sind nicht im Manifest gelistet.' -f $extra)) }
        }
    }
    return [pscustomobject]@{ Valid = ($errors.Count -eq 0); Errors = $errors.ToArray(); Warnings = $warnings.ToArray(); Manifest = $manifest; FileCount = $fileCount }
}

function Open-CDTRepositorySource {
    <#
    .SYNOPSIS
        Stufe 2: Repository (UNC oder ZIP) lokal bereitstellen, Share sofort trennen, Manifest/Hashes/Signaturen pruefen.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory = $true)][int]$BaseBuild)
    $lang = $script:Cfg.Language
    $local = Join-Path -Path $script:Cfg.TempPath -ChildPath 'repo'
    if (Test-Path -LiteralPath $local) { Remove-Item -LiteralPath $local -Recurse -Force }
    $null = New-Item -Path $local -ItemType Directory -Force
    $description = ''
    $prepared = $false
    if (-not [string]::IsNullOrWhiteSpace($script:Cfg.RepositoryPath)) {
        $conn = $null
        try {
            if ($script:Cfg.RepositoryPath -match '^\\\\') {
                $conn = Connect-CDTShare -UncPath $script:Cfg.RepositoryPath -AccountKey $script:Cfg.StorageAccountKey -StateName 'RepositoryHost'
            }
            $folder = Resolve-CDTRepositoryFolder -Root $script:Cfg.RepositoryPath -Language $lang -BaseBuild $BaseBuild
            Write-CDTLog -Message ('Repository-Version: {0}' -f $folder)
            Copy-CDTDirectory -Source $folder -Destination $local
            $description = 'Repository ' + $folder
            $prepared = $true
        }
        catch {
            Write-CDTErrorRecord -ErrorRecord $_ -Context 'Stufe 2 (UNC/lokal)'
        }
        finally {
            Disconnect-CDTShare -Connection $conn
        }
    }
    if (-not $prepared -and -not [string]::IsNullOrWhiteSpace($script:Cfg.RepositoryZipUrl)) {
        $zip = Join-Path -Path $script:Cfg.TempPath -ChildPath 'repo.zip'
        $proxy = Get-CDTWinHttpProxy
        $null = Invoke-CDTDownload -Url $script:Cfg.RepositoryZipUrl -Destination $zip -TimeoutMinutes ([int][Math]::Max(10, (Get-CDTRemainingBudget) - 20)) -Proxy $proxy
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $local)
        Remove-Item -LiteralPath $zip -Force
        $inner = @(Get-ChildItem -LiteralPath $local -Directory)
        if (-not (Test-Path -LiteralPath (Join-Path -Path $local -ChildPath 'manifest.json')) -and $inner.Count -eq 1) {
            $local = $inner[0].FullName
        }
        $description = 'Repository-ZIP ' + (Get-CDTUrlForLog -Url $script:Cfg.RepositoryZipUrl)
        $prepared = $true
    }
    if (-not $prepared) { throw 'Stufe 2: keine nutzbare Repository-Quelle.' }

    $check = Test-CDTRepositoryManifest -Path $local -ExpectedBaseBuild $BaseBuild -Language $lang
    foreach ($w in $check.Warnings) { Write-CDTLog -Level WARN -Message $w }
    if (-not $check.Valid) {
        foreach ($e in $check.Errors) { Write-CDTLog -Level ERROR -Message ('Manifest: {0}' -f $e) }
        throw 'Stufe 2 verworfen: Manifest-Pruefung fehlgeschlagen.'
    }
    $m = $check.Manifest
    Write-CDTLog -Message ('Manifest OK: Build {0}, Sprache {1}, Quelle-ISO {2}, erstellt {3}, {4} Datei(en).' -f $m.osBaseBuild, $m.language, (Get-CDTPropertyValue -InputObject (Get-CDTPropertyValue -InputObject $m -Name 'sourceIso') -Name 'name' -Default '?'), (Get-CDTPropertyValue -InputObject $m -Name 'createdUtc' -Default '?'), $check.FileCount)
    $badSig = @(Test-CDTCabSignature -FilePath (Get-CDTUsedCabFile -Path $local))
    if ($badSig.Count -gt 0) {
        foreach ($b in $badSig) { Write-CDTLog -Level ERROR -Message ('Signatur: {0} Status={1} Signer={2}' -f $b.File, $b.Status, $b.Signer) }
        throw 'Stufe 2 verworfen: Authenticode-Pruefung fehlgeschlagen.'
    }
    $winPe = Join-Path -Path $local -ChildPath ('WinPE_OCs\{0}' -f $lang.ToLowerInvariant())
    if (-not (Test-Path -LiteralPath $winPe)) { $winPe = '' }
    return [pscustomobject]@{ Stage = 2; Path = $local; WinPePath = $winPe; Description = $description; Mount = $null; DownloadedIso = ''; BaseBuild = $BaseBuild }
}

function Open-CDTIsoSource {
    <#
    .SYNOPSIS
        Stufe 3: LOF-ISO herunterladen (oder vorhandenes nutzen), Build pruefen, einbinden, Signaturen pruefen.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory = $true)][int]$BaseBuild)
    $iso = $script:Cfg.IsoPath
    $downloaded = ''
    $name = $iso
    if ([string]::IsNullOrWhiteSpace($iso)) {
        $name = [System.Uri]::UnescapeDataString(([System.Uri]$script:Cfg.LofIsoUrl).Segments[-1])
    }
    $isoBuild = Get-CDTIsoBuildFromName -Name $name
    if ($BaseBuild -le 0) { throw 'Stufe 3: Servicing-Basis des OS unbekannt.' }
    if ($isoBuild -eq 0) {
        Write-CDTLog -Level WARN -Message ('Stufe 3: Build aus ISO-Name "{0}" nicht ermittelbar - Pruefung erfolgt ueber die Sprachpaket-Version.' -f $name)
    }
    elseif ($isoBuild -ne $BaseBuild) {
        throw ('Stufe 3: ISO-Build {0} passt nicht zur OS-Basis {1} (MS-06).' -f $isoBuild, $BaseBuild)
    }
    if ([string]::IsNullOrWhiteSpace($iso)) {
        $iso = Join-Path -Path $script:Cfg.TempPath -ChildPath $name
        $proxy = Get-CDTWinHttpProxy
        $size = Get-CDTRemoteFileSize -Url $script:Cfg.LofIsoUrl -Proxy $proxy
        if ($size -le 0) { Write-CDTLog -Level WARN -Message 'ISO-Groesse unbekannt (HEAD ohne Content-Length) - Speicherpruefung uebersprungen.' }
        else {
            $drive = [System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($script:Cfg.TempPath))
            $needed = [long]($size * 1.2)
            Write-CDTLog -Message ('ISO {0:N1} GB, frei {1:N1} GB, benoetigt inkl. 20 % Puffer {2:N1} GB.' -f ($size / 1GB), ($drive.AvailableFreeSpace / 1GB), ($needed / 1GB))
            if ($drive.AvailableFreeSpace -lt $needed) { throw 'Stufe 3: nicht genug freier Speicher fuer das ISO.' }
        }
        $remaining = Get-CDTRemainingBudget
        if ($remaining -lt 25) { $script:BudgetExhausted = $true; throw ('Stufe 3: Laufzeitbudget reicht nicht ({0} min).' -f $remaining) }
        $null = Invoke-CDTDownload -Url $script:Cfg.LofIsoUrl -Destination $iso -TimeoutMinutes ([int]($remaining - 15)) -Proxy $proxy
        $downloaded = $iso
        if ($size -gt 0 -and (Get-Item -LiteralPath $iso).Length -ne $size) { throw 'Stufe 3: ISO-Groesse stimmt nicht mit Content-Length ueberein.' }
    }
    $ctx = [pscustomobject]@{ Stage = 3; Path = ''; WinPePath = ''; Description = ''; Mount = $null; DownloadedIso = $downloaded; BaseBuild = $BaseBuild }
    try {
        $ctx.Mount = Mount-CDTIso -ImagePath $iso
        $ctx.Path = Join-Path -Path $ctx.Mount.Root -ChildPath 'LanguagesAndOptionalFeatures'
        if (-not (Test-Path -LiteralPath $ctx.Path)) { throw 'Ordner LanguagesAndOptionalFeatures im ISO nicht gefunden.' }
        $winPe = Join-Path -Path $ctx.Mount.Root -ChildPath ('Windows Preinstallation Environment\x64\WinPE_OCs\{0}' -f $script:Cfg.Language.ToLowerInvariant())
        if (Test-Path -LiteralPath $winPe) { $ctx.WinPePath = $winPe }
        $ctx.Description = 'LOF-ISO ' + (Split-Path -Path $iso -Leaf)
        $badSig = @(Test-CDTCabSignature -FilePath (Get-CDTUsedCabFile -Path $ctx.Path))
        if ($badSig.Count -gt 0) {
            foreach ($b in $badSig) { Write-CDTLog -Level ERROR -Message ('Signatur: {0} Status={1} Signer={2}' -f $b.File, $b.Status, $b.Signer) }
            throw 'Stufe 3 verworfen: Authenticode-Pruefung fehlgeschlagen.'
        }
    }
    catch {
        Close-CDTSource -Context $ctx
        throw
    }
    return $ctx
}

function Close-CDTSource {
    <#
    .SYNOPSIS
        Haengt ISO aus und loescht heruntergeladene ISO bzw. lokale Repository-Kopie.
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Context)
    if ($null -eq $Context) { return }
    if ($null -ne $Context.Mount) { Dismount-CDTIso -Mount $Context.Mount; $Context.Mount = $null }
    if ($Context.DownloadedIso -and (Test-Path -LiteralPath $Context.DownloadedIso)) {
        try { Remove-Item -LiteralPath $Context.DownloadedIso -Force -ErrorAction Stop; Write-CDTLog -Message 'Heruntergeladenes ISO geloescht.' }
        catch { Write-CDTLog -Level ERROR -Message ('ISO konnte nicht geloescht werden: {0}' -f $_.Exception.Message) }
    }
    if ($Context.Stage -eq 2 -and $Context.Path -and (Test-Path -LiteralPath $Context.Path)) {
        try { Remove-Item -LiteralPath (Join-Path -Path $script:Cfg.TempPath -ChildPath 'repo') -Recurse -Force -ErrorAction Stop }
        catch { Write-CDTLog -Level WARN -Message ('Repository-Kopie konnte nicht geloescht werden: {0}' -f $_.Exception.Message) }
    }
}
#endregion

#region Installation (Stufe 1, Stufe 2/3, WinRE)
function Invoke-CDTInstallLanguageJob {
    <#
    .SYNOPSIS
        Fuehrt Install-Language als Job mit Timeout aus (bekanntes Haengen abfangen).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$TargetLanguage,
        [switch]$ExcludeLanguageFeatures,
        [Parameter(Mandatory = $true)][int]$TimeoutMinutes
    )
    $excludeFlag = [bool]$ExcludeLanguageFeatures
    $job = Start-Job -Name ('CDT-InstallLanguage-{0}' -f $TargetLanguage) -ScriptBlock {
        $ErrorActionPreference = 'Stop'
        Import-Module -Name LanguagePackManagement -ErrorAction Stop
        if ($using:excludeFlag) { Install-Language -Language $using:TargetLanguage -ExcludeFeatures }
        else { Install-Language -Language $using:TargetLanguage }
    }
    try {
        $done = Wait-Job -Job $job -Timeout ($TimeoutMinutes * 60)
        if ($null -eq $done) {
            Stop-Job -Job $job
            return [pscustomobject]@{ Success = $false; TimedOut = $true; Message = ('Timeout nach {0} min' -f $TimeoutMinutes); HResult = ''; Explanation = '' }
        }
        $jobErrors = $null
        $output = @(Receive-Job -Job $job -ErrorAction SilentlyContinue -ErrorVariable jobErrors)
        $reason = $job.ChildJobs[0].JobStateInfo.Reason
        if ([string]$job.State -eq 'Failed' -or @($jobErrors).Count -gt 0) {
            $text = ''
            if ($null -ne $reason) { $text = $reason.Message }
            $first = $null
            if (@($jobErrors).Count -gt 0) { $first = @($jobErrors)[0]; $text = $text + ' ' + $first.Exception.Message }
            $info = Get-CDTErrorInfo -ErrorRecord $first -Text $text
            return [pscustomobject]@{ Success = $false; TimedOut = $false; Message = $text.Trim(); HResult = $info.HResult; Explanation = $info.Explanation }
        }
        foreach ($o in $output) {
            Write-CDTLog -Message ('Install-Language: Sprache={0} Pakete={1} Features={2}' -f (Get-CDTPropertyValue -InputObject $o -Name 'LanguageId' -Default '?'), (Get-CDTPropertyValue -InputObject $o -Name 'LanguagePacks' -Default '?'), (Get-CDTPropertyValue -InputObject $o -Name 'LanguageFeatures' -Default '?'))
        }
        return [pscustomobject]@{ Success = $true; TimedOut = $false; Message = 'OK'; HResult = ''; Explanation = '' }
    }
    finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

function Wait-CDTServicingIdle {
    <#
    .SYNOPSIS
        Wartet nach Timeout/Fehler auf das Ende laufender CBS-Operationen (TiWorker), statt parallel neu zu starten.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([int]$MaxMinutes = 10)
    $deadline = (Get-Date).AddMinutes($MaxMinutes)
    while ((Get-Date) -lt $deadline) {
        $worker = @(Get-Process -Name 'TiWorker' -ErrorAction SilentlyContinue)
        if ($worker.Count -eq 0) { Write-CDTLog -Message 'Servicing ist im Leerlauf.'; return $true }
        Start-Sleep -Seconds 15
    }
    Write-CDTLog -Level WARN -Message ('Servicing nach {0} min weiterhin aktiv.' -f $MaxMinutes)
    return $false
}

function Add-CDTCapabilityFromWindowsUpdate {
    <#
    .SYNOPSIS
        Installiert fehlende Pflicht-FoDs ueber Windows Update (Stufe 1, z. B. bei abgewaehlten Features).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Capability)
    foreach ($cap in $Capability) {
        if (@('Installed', 'InstallPending') -contains $cap.State) { continue }
        try {
            $res = Add-WindowsCapability -Online -Name $cap.Name -LogPath $script:DismLogFile
            if ([bool](Get-CDTPropertyValue -InputObject $res -Name 'RestartNeeded' -Default $false)) { $script:RestartNeeded = $true }
            $script:LanguageChanged = $true
            Save-CDTState -Name 'FodInstalledAt' -Value (Get-Date).ToString('o')
            Write-CDTLog -Message ('FoD installiert (Windows Update): {0}' -f $cap.Name)
        }
        catch { Write-CDTErrorRecord -ErrorRecord $_ -Context ('Add-WindowsCapability {0}' -f $cap.Name) }
    }
}

function Invoke-CDTInstallStage1 {
    <#
    .SYNOPSIS
        Stufe 1: Install-Language (Windows Update/UUP) als Job mit Timeout, Retry und Backoff.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    Enter-CDTPhase 'Install/Stufe1'
    $lang = $script:Cfg.Language
    $bypass = $false
    $restrictRemoved = $false
    try {
        $findings = @(Get-CDTWuPolicyFinding)
        foreach ($f in $findings) {
            $lvl = 'INFO'
            if ($f.Blocking) { $lvl = 'WARN' }
            Write-CDTLog -Level $lvl -Message ('Policy {0}\{1} = {2}: {3}' -f $f.Path, $f.Name, $f.Value, $f.Text)
        }
        $blocking = @($findings | Where-Object { $_.Blocking })
        $ownRestrict = [int](Get-CDTState -Name 'RestrictSetByScript' -Default 0) -eq 1
        $onlyOwnRestrict = ($blocking.Count -eq 1 -and $blocking[0].Name -eq $script:RestrictPolicy.Name -and $ownRestrict)
        if ($onlyOwnRestrict) {
            Save-CDTState -Name 'RestrictTemporarilyRemoved' -Value 1 -Type DWord
            Clear-CDTRegistryValue -Path $script:RestrictPolicy.Path -Name $script:RestrictPolicy.Name
            $restrictRemoved = $true
            Write-CDTLog -Message 'Eigene MS-13-Policy temporaer entfernt.'
        }
        elseif ($blocking.Count -gt 0 -and $script:Cfg.AllowTemporaryWuPolicyBypass) {
            $bypass = Enable-CDTWuPolicyBypass -Finding $findings
        }
        elseif ($blocking.Count -gt 0) {
            Write-CDTLog -Level WARN -Message 'Blockierende Policies aktiv (ohne -AllowTemporaryWuPolicyBypass). Stufe 1 wird trotzdem versucht (WSUS kann UUP-Inhalte liefern).'
        }

        $excludeFeatures = @($script:Cfg.ExcludeFeatures).Count -gt 0
        $success = $false
        $attemptsDone = 0
        for ($attempt = 1; $attempt -le $script:Cfg.InstallRetryCount; $attempt++) {
            $remaining = Get-CDTRemainingBudget
            if ($remaining -lt 10) {
                $script:BudgetExhausted = $true
                Write-CDTLog -Level WARN -Message ('Laufzeitbudget erschoepft ({0} min) - Stufe 1 abgebrochen.' -f $remaining)
                break
            }
            $timeout = [int][Math]::Max(5, [Math]::Min($script:Cfg.InstallTimeoutMinutes, $remaining - 5))
            $attemptsDone = $attempt
            Write-CDTLog -Message ('Install-Language {0} - Versuch {1}/{2}, Timeout {3} min, ExcludeFeatures={4}' -f $lang, $attempt, $script:Cfg.InstallRetryCount, $timeout, $excludeFeatures)
            $r = Invoke-CDTInstallLanguageJob -TargetLanguage $lang -ExcludeLanguageFeatures:$excludeFeatures -TimeoutMinutes $timeout
            if ($r.Success) { $success = $true; break }
            Write-CDTLog -Level WARN -Message ('Install-Language fehlgeschlagen: {0} | HRESULT={1} {2}' -f $r.Message, $r.HResult, $r.Explanation)
            $null = Wait-CDTServicingIdle -MaxMinutes 10
            if ($attempt -lt $script:Cfg.InstallRetryCount) {
                $delay = [int][Math]::Min(60 * [Math]::Pow(2, $attempt - 1), [Math]::Max(0, ((Get-CDTRemainingBudget) - 10) * 60))
                Write-CDTLog -Message ('Backoff {0} s vor dem naechsten Versuch.' -f $delay)
                if ($delay -gt 0) { Start-Sleep -Seconds $delay }
            }
        }
        Save-CDTState -Name 'Stage1Attempts' -Value $attemptsDone -Type DWord
        $state = Get-CDTLanguageState -Refresh
        if ($success) { $script:LanguageChanged = $true }
        if ($state.LanguagePackPresent -and -not $state.CapabilitiesPresent) {
            Write-CDTLog -Message 'Fehlende Pflicht-FoDs werden ueber Windows Update nachinstalliert.'
            Add-CDTCapabilityFromWindowsUpdate -Capability $state.Capabilities
            $state = Get-CDTLanguageState -Refresh
        }
        if ($state.LanguagePackPresent -and -not (Get-CDTState -Name 'LanguagePackInstalledAt')) {
            Save-CDTState -Name 'LanguagePackInstalledAt' -Value (Get-Date).ToString('o')
        }
        $ok = $state.Complete
        Save-CDTState -Name 'Stage1Result' -Value ($(if ($ok) { 'Success' } elseif ($script:BudgetExhausted) { 'Budget' } else { 'Failed' }))
        if (-not $ok -and -not $script:BudgetExhausted -and $attemptsDone -ge $script:Cfg.InstallRetryCount) { Save-CDTState -Name 'Stage1Exhausted' -Value 1 -Type DWord }
        if ($ok) { Save-CDTState -Name 'Stage1Exhausted' -Value 0 -Type DWord }
        Write-CDTLog -Message ('Stufe 1 Ergebnis: Sprachpaket={0}, FoDs vollstaendig={1} ({2})' -f $state.LanguagePackState, $state.CapabilitiesPresent, ((@($state.Capabilities) | ForEach-Object { '{0}={1}' -f $_.Feature, $_.State }) -join ', '))
        return $ok
    }
    finally {
        if ($bypass) { Restore-CDTWuPolicyBypass }
        if ($restrictRemoved) {
            Write-CDTRegistryValue -Path $script:RestrictPolicy.Path -Name $script:RestrictPolicy.Name -Value 1 -Type DWord
            Clear-CDTState -Name 'RestrictTemporarilyRemoved'
            Write-CDTLog -Message 'Eigene MS-13-Policy wiederhergestellt.'
        }
    }
}

function Install-CDTFromSource {
    <#
    .SYNOPSIS
        Stufe 2/3: zuerst Sprachpaket (Add-WindowsPackage), danach Language-FoDs (Add-WindowsCapability -Source -LimitAccess).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory = $true)][object]$Context)
    $lang = $script:Cfg.Language
    $state = Get-CDTLanguageState -Refresh
    if (-not $state.LanguagePackPresent) {
        $lpCab = Join-Path -Path $Context.Path -ChildPath ('Microsoft-Windows-Client-Language-Pack_x64_{0}.cab' -f $lang.ToLowerInvariant())
        if (-not (Test-Path -LiteralPath $lpCab)) { throw ('Sprachpaket nicht in der Quelle: {0}' -f $lpCab) }
        # MS-06 hart pruefen: Paketversion des Sprachpakets muss zur Servicing-Basis passen
        $cabBuild = Get-CDTCabPackageBuild -CabPath $lpCab
        if ($cabBuild -gt 0 -and $cabBuild -ne [int]$Context.BaseBuild) {
            throw ('MS-06: Sprachpaket-Build {0} passt nicht zur OS-Basis {1}.' -f $cabBuild, $Context.BaseBuild)
        }
        Write-CDTLog -Message ('MS-06: Sprachpaket-Build {0}, OS-Basis {1}.' -f $cabBuild, $Context.BaseBuild)
        $res = Invoke-CDTStep -StepName ('Add-WindowsPackage {0}' -f (Split-Path -Path $lpCab -Leaf)) -Action {
            Add-WindowsPackage -Online -PackagePath $lpCab -NoRestart -LogPath $script:DismLogFile
        }
        if ([bool](Get-CDTPropertyValue -InputObject $res -Name 'RestartNeeded' -Default $false)) { $script:RestartNeeded = $true }
        $script:LanguageChanged = $true
        Save-CDTState -Name 'LanguagePackInstalledAt' -Value (Get-Date).ToString('o')
        $state = Get-CDTLanguageState -Refresh
    }
    else {
        Write-CDTLog -Message ('Sprachpaket bereits vorhanden ({0}).' -f $state.LanguagePackState)
    }
    foreach ($cap in @($state.Capabilities)) {
        if (@('Installed', 'InstallPending') -contains $cap.State) { continue }
        $res = Invoke-CDTStep -StepName ('Add-WindowsCapability {0}' -f $cap.Name) -Action {
            Add-WindowsCapability -Online -Name $cap.Name -Source $Context.Path -LimitAccess -LogPath $script:DismLogFile
        }
        if ([bool](Get-CDTPropertyValue -InputObject $res -Name 'RestartNeeded' -Default $false)) { $script:RestartNeeded = $true }
        $script:LanguageChanged = $true
        Save-CDTState -Name 'FodInstalledAt' -Value (Get-Date).ToString('o')
    }
    $state = Get-CDTLanguageState -Refresh
    return $state.Complete
}

function Add-CDTWinRELanguage {
    <#
    .SYNOPSIS
        MS-14: WinRE-Sprachpaket (lp.cab + WinPE-OC-Sprachpakete) per reagentc/DISM integrieren.
    .NOTES
        Zuordnung der WinPE-OC-Paketnamen ist unbestaetigt; nicht gefundene OC-Pakete werden geloggt.
        WinRE-Servicing (SafeOS Dynamic Update) bleibt Aufgabe des Patch-Prozesses.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory = $true)][string]$WinPePath)
    $lang = $script:Cfg.Language.ToLowerInvariant()
    $lpCab = Join-Path -Path $WinPePath -ChildPath 'lp.cab'
    if (-not (Test-Path -LiteralPath $lpCab)) { Write-CDTLog -Level WARN -Message ('WinRE: lp.cab fehlt in {0}' -f $WinPePath); return $false }
    $reagentc = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reagentc.exe'
    $wim = Join-Path -Path $env:SystemRoot -ChildPath 'System32\Recovery\Winre.wim'
    $mountDir = Join-Path -Path $script:Cfg.TempPath -ChildPath 'winre_mount'
    $info = Invoke-CDTNativeCommand -FilePath $reagentc -ArgumentList @('/info')
    $wasEnabled = $info.StdOut -match '(?im)Windows RE.*:\s*(Enabled|Aktiviert)'
    $disabled = $false
    $mounted = $false
    $ok = $false
    try {
        if ($wasEnabled) {
            Save-CDTState -Name 'WinReDisabledByScript' -Value 1 -Type DWord
            $r = Invoke-CDTNativeCommand -FilePath $reagentc -ArgumentList @('/disable')
            if ($r.ExitCode -ne 0) { throw ('reagentc /disable fehlgeschlagen: {0}' -f $r.StdOut) }
            $disabled = $true
        }
        if (-not (Test-Path -LiteralPath $wim)) { throw ('Winre.wim nicht gefunden: {0}' -f $wim) }
        $null = New-Item -Path $mountDir -ItemType Directory -Force
        $null = Mount-WindowsImage -ImagePath $wim -Index 1 -Path $mountDir
        $mounted = $true
        $installed = @(Get-WindowsPackage -Path $mountDir)
        $null = Add-WindowsPackage -Path $mountDir -PackagePath $lpCab
        foreach ($p in $installed) {
            $m = [regex]::Match($p.PackageName, '(?i)WinPE-(?<oc>[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*?)-Package~')
            if (-not $m.Success) { continue }
            $ocCab = Join-Path -Path $WinPePath -ChildPath ('WinPE-{0}_{1}.cab' -f $m.Groups['oc'].Value, $lang)
            if (Test-Path -LiteralPath $ocCab) {
                $null = Add-WindowsPackage -Path $mountDir -PackagePath $ocCab
                Write-CDTLog -Message ('WinRE: {0} hinzugefuegt.' -f (Split-Path -Path $ocCab -Leaf))
            }
            else { Write-CDTLog -Level DEBUG -Message ('WinRE: kein Sprachpaket fuer {0}' -f $p.PackageName) }
        }
        $null = Dismount-WindowsImage -Path $mountDir -Save
        $mounted = $false
        $ok = $true
    }
    catch {
        Write-CDTErrorRecord -ErrorRecord $_ -Context 'WinRE-Sprachpaket'
    }
    finally {
        if ($mounted) {
            try { $null = Dismount-WindowsImage -Path $mountDir -Discard } catch { Write-CDTLog -Level ERROR -Message ('WinRE-Dismount: {0}' -f $_.Exception.Message) }
        }
        if ($disabled) {
            $r = Invoke-CDTNativeCommand -FilePath $reagentc -ArgumentList @('/enable')
            if ($r.ExitCode -eq 0) { Clear-CDTState -Name 'WinReDisabledByScript' }
            else { Write-CDTLog -Level ERROR -Message 'reagentc /enable fehlgeschlagen - WinRE manuell pruefen!' }
        }
        if (Test-Path -LiteralPath $mountDir) { Remove-Item -LiteralPath $mountDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    if ($ok) {
        Save-CDTState -Name 'WinReLanguageAdded' -Value 1 -Type DWord
        Write-CDTLog -Level WARN -Message 'WinRE-Sprachpaket integriert. WinRE danach mit SafeOS Dynamic Update aktuell halten (Microsoft).'
    }
    return $ok
}

function Invoke-CDTSourceChain {
    <#
    .SYNOPSIS
        Fallback-Kette Stufe 1 -> Stufe 2 -> Stufe 3 (Stufe 3 nur, wenn 1 und 2 scheitern oder -ForceIsoSource).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)][object]$LanguageState,
        [Parameter(Mandatory = $true)][int]$BaseBuild,
        [bool]$NeedWinRE = $false
    )
    $stages = [System.Collections.Generic.List[int]]::new()
    if ($script:Cfg.ForceIsoSource) {
        $stages.Add(3)
    }
    else {
        if (-not $LanguageState.Complete) {
            $skip1 = ($script:Cfg.Mode -eq 'Auto') -and ([int](Get-CDTState -Name 'Stage1Exhausted' -Default 0) -eq 1)
            if ($skip1) { Write-CDTLog -Level WARN -Message 'Stufe 1 war im vorherigen Lauf erschoepft und wird uebersprungen (Mode Install erzwingt einen neuen Versuch).' }
            else { $stages.Add(1) }
        }
        if ($script:Cfg.RepositoryPath -or $script:Cfg.RepositoryZipUrl) { $stages.Add(2) }
        else { Write-CDTLog -Message 'Stufe 2 nicht konfiguriert (-RepositoryPath/-RepositoryZipUrl).' }
        $stages.Add(3)
    }
    $langDone = [bool]$LanguageState.Complete
    $winReDone = -not $NeedWinRE
    $stageFailed = @{}
    foreach ($stage in $stages) {
        if ($langDone -and $winReDone) { break }
        # Stufe 3 nur als Notfall (Vorgabe). Nur fuer WinRE wird kein ISO heruntergeladen, ein vorhandenes -IsoPath ist erlaubt.
        if ($stage -eq 3 -and $langDone -and -not $script:Cfg.ForceIsoSource -and [string]::IsNullOrWhiteSpace($script:Cfg.IsoPath)) {
            Write-CDTLog -Level WARN -Message 'WinRE: Stufe 3 wird nicht nur fuer WinRE heruntergeladen (-IsoPath oder Repository mit WinPE_OCs verwenden).'
            continue
        }
        $remaining = Get-CDTRemainingBudget
        if ($remaining -lt 10) {
            $script:BudgetExhausted = $true
            Write-CDTLog -Level WARN -Message ('Laufzeitbudget erschoepft ({0} min) vor Stufe {1}. Naechster Lauf setzt fort.' -f $remaining, $stage)
            break
        }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Save-CDTState -Name 'LastStageAttempted' -Value $stage -Type DWord
        if ($stage -eq 1) {
            if ($langDone) { continue }
            $ok = $false
            try { $ok = Invoke-CDTInstallStage1 } catch { Write-CDTErrorRecord -ErrorRecord $_ -Context 'Stufe 1' }
            Enter-CDTPhase 'Install'
            Write-CDTLog -Message ('Stufe 1 (Windows Update) Ergebnis: {0}, Dauer {1:N0} s' -f $ok, $sw.Elapsed.TotalSeconds)
            if ($ok) { $langDone = $true; $script:InstallStagesUsed.Add('1'); $script:InstallSourceDetail = 'Stufe 1: Install-Language (Windows Update/UUP)' }
            else { $stageFailed[1] = $true }
            continue
        }
        Enter-CDTPhase ('Install/Stufe{0}' -f $stage)
        $ctx = $null
        try {
            if ($stage -eq 2) { $ctx = Open-CDTRepositorySource -BaseBuild $BaseBuild } else { $ctx = Open-CDTIsoSource -BaseBuild $BaseBuild }
            if (-not $langDone) {
                $ok = Install-CDTFromSource -Context $ctx
                Write-CDTLog -Message ('Stufe {0} ({1}) Ergebnis: {2}, Dauer {3:N0} s' -f $stage, $ctx.Description, $ok, $sw.Elapsed.TotalSeconds)
                if ($ok) { $langDone = $true; $script:InstallStagesUsed.Add([string]$stage); $script:InstallSourceDetail = ('Stufe {0}: {1}' -f $stage, $ctx.Description) }
                else { $stageFailed[$stage] = $true }
            }
            if (-not $winReDone -and $langDone) {
                if ($ctx.WinPePath) { $winReDone = Add-CDTWinRELanguage -WinPePath $ctx.WinPePath }
                else { Write-CDTLog -Level WARN -Message ('Stufe {0}: keine WinPE-Sprachpakete in der Quelle.' -f $stage) }
            }
        }
        catch {
            $stageFailed[$stage] = $true
            Write-CDTErrorRecord -ErrorRecord $_ -Context ('Stufe {0}' -f $stage)
        }
        finally {
            Close-CDTSource -Context $ctx
            Enter-CDTPhase 'Install'
        }
    }
    if ($NeedWinRE -and -not $winReDone) { Write-CDTLog -Level WARN -Message 'WinRE-Sprachpaket nicht integriert (keine Quelle mit WinPE_OCs erfolgreich).' }
    return $langDone
}
#endregion

#region Laendereinstellungen, Zeitzone
function Get-CDTUserHiveValue {
    <#
    .SYNOPSIS
        Liest einen Wert unter HKEY_USERS ueber .NET (Handle wird sofort freigegeben, wichtig fuer reg unload).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$HiveRoot,
        [Parameter(Mandatory = $true)][string]$SubKey,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Name
    )
    $key = $null
    try {
        $key = [Microsoft.Win32.Registry]::Users.OpenSubKey(('{0}\{1}' -f $HiveRoot, $SubKey), $false)
        if ($null -eq $key) { return $null }
        return $key.GetValue($Name, $null)
    }
    finally { if ($null -ne $key) { $key.Dispose() } }
}

function Get-CDTUserHiveValueTable {
    <#
    .SYNOPSIS
        Liest alle Werte eines Schluessels unter HKEY_USERS als Hashtable.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$HiveRoot,
        [Parameter(Mandatory = $true)][string]$SubKey
    )
    $table = @{}
    $key = $null
    try {
        $key = [Microsoft.Win32.Registry]::Users.OpenSubKey(('{0}\{1}' -f $HiveRoot, $SubKey), $false)
        if ($null -ne $key) { foreach ($n in $key.GetValueNames()) { $table[$n] = $key.GetValue($n, $null) } }
    }
    finally { if ($null -ne $key) { $key.Dispose() } }
    return $table
}

function Test-CDTIntlProfile {
    <#
    .SYNOPSIS
        Verifiziert Regionalformat, GeoID, Sprachliste und Tastatur eines Profils (.DEFAULT oder geladener Default-User-Hive).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory = $true)][string]$HiveRoot)
    $lang = $script:Cfg.Language
    $klid = $script:Cfg.InputLocale.Split(':')[1].ToUpperInvariant()
    $locale = [string](Get-CDTUserHiveValue -HiveRoot $HiveRoot -SubKey 'Control Panel\International' -Name 'LocaleName')
    $nation = [string](Get-CDTUserHiveValue -HiveRoot $HiveRoot -SubKey 'Control Panel\International\Geo' -Name 'Nation')
    $languages = @(@(Get-CDTUserHiveValue -HiveRoot $HiveRoot -SubKey 'Control Panel\International\User Profile' -Name 'Languages') | Where-Object { $_ })
    $preload = Get-CDTUserHiveValueTable -HiveRoot $HiveRoot -SubKey 'Keyboard Layout\Preload'
    $preloadValues = @($preload.Values | ForEach-Object { ([string]$_).ToUpperInvariant() })
    $deviations = [System.Collections.Generic.List[string]]::new()
    if ($locale -ne $lang) { $deviations.Add(('LocaleName={0}' -f $locale)) }
    if ($nation -ne [string]$script:Cfg.GeoId) { $deviations.Add(('Geo={0}' -f $nation)) }
    if (@($languages).Count -eq 0 -or [string]@($languages)[0] -ne $lang) { $deviations.Add(('Sprachliste={0}' -f (@($languages) -join ','))) }
    if (@($languages) -contains 'en-US') { $deviations.Add('en-US in Sprachliste') }
    $first = ''
    if ($preload.ContainsKey('1')) { $first = ([string]$preload['1']).ToUpperInvariant() }
    if ($first -ne $klid) { $deviations.Add(('Preload1={0}' -f $first)) }
    if ($preloadValues -contains '00000409') { $deviations.Add('en-US-Tastatur 00000409 vorhanden') }
    return [pscustomobject]@{
        HiveRoot   = $HiveRoot
        Ok         = ($deviations.Count -eq 0)
        LocaleName = $locale
        Nation     = $nation
        Languages  = (@($languages) -join ',')
        Preload    = ($preloadValues -join ',')
        Deviations = $deviations.ToArray()
    }
}

function Invoke-CDTWithDefaultUserHive {
    <#
    .SYNOPSIS
        Laedt C:\Users\Default\NTUSER.DAT temporaer, fuehrt eine Aktion aus und entlaedt sauber (GC, Retries).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][scriptblock]$Action)
    $profileDir = [string](Get-CDTRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -Name 'Default' -Default '')
    if (-not $profileDir) { $profileDir = Join-Path -Path $env:SystemDrive -ChildPath 'Users\Default' }
    $hivePath = Join-Path -Path ([Environment]::ExpandEnvironmentVariables($profileDir)) -ChildPath 'NTUSER.DAT'
    $mountName = 'CDT_DefaultUser_{0}' -f $PID
    $reg = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reg.exe'
    $load = Invoke-CDTNativeCommand -FilePath $reg -ArgumentList @('load', ('HKU\{0}' -f $mountName), $hivePath) -NoLog
    if ($load.ExitCode -ne 0) { throw ('Default-User-Hive nicht ladbar ({0}): {1}' -f $hivePath, $load.StdErr.Trim()) }
    try {
        return (& $Action $mountName)
    }
    finally {
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $unloaded = $false
        for ($i = 1; $i -le 10 -and -not $unloaded; $i++) {
            $u = Invoke-CDTNativeCommand -FilePath $reg -ArgumentList @('unload', ('HKU\{0}' -f $mountName)) -NoLog
            if ($u.ExitCode -eq 0) { $unloaded = $true } else { Start-Sleep -Seconds 2; [GC]::Collect() }
        }
        if (-not $unloaded) { Write-CDTLog -Level ERROR -Message ('Default-User-Hive konnte nicht entladen werden (HKU\{0}).' -f $mountName) }
    }
}

function Copy-CDTIntlRegistry {
    <#
    .SYNOPSIS
        Fallback (unbestaetigt): kopiert International- und Keyboard-Layout-Schluessel von .DEFAULT in den Default-User-Hive.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$TargetRoot)
    $reg = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reg.exe'
    foreach ($sub in @('Control Panel\International\User Profile', 'Keyboard Layout\Preload', 'Keyboard Layout\Substitutes')) {
        $null = Invoke-CDTNativeCommand -FilePath $reg -ArgumentList @('delete', ('HKU\{0}\{1}' -f $TargetRoot, $sub), '/f') -NoLog
    }
    foreach ($sub in @('Control Panel\International', 'Keyboard Layout')) {
        $r = Invoke-CDTNativeCommand -FilePath $reg -ArgumentList @('copy', ('HKU\.DEFAULT\{0}' -f $sub), ('HKU\{0}\{1}' -f $TargetRoot, $sub), '/s', '/f') -NoLog
        if ($r.ExitCode -ne 0) { Write-CDTLog -Level WARN -Message ('reg copy {0}: {1}' -f $sub, $r.StdErr.Trim()) }
    }
}

function Invoke-CDTInternationalConfiguration {
    <#
    .SYNOPSIS
        Setzt System Preferred UI, System Locale, Culture, GeoID, Sprachliste/Tastatur (SYSTEM = .DEFAULT) und kopiert auf Welcome Screen + neue Benutzer; verifiziert per Registry.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $lang = $script:Cfg.Language
    $tip = $script:Cfg.InputLocale.ToUpperInvariant()
    Import-Module -Name International -ErrorAction Stop
    Import-Module -Name LanguagePackManagement -ErrorAction Stop

    $curUi = [string](Get-SystemPreferredUILanguage)
    if ($curUi -ne $lang) {
        Invoke-CDTStep -StepName ('Set-SystemPreferredUILanguage {0} (vorher {1})' -f $lang, $curUi) -Action { Set-SystemPreferredUILanguage -Language $lang }
        $script:RestartNeeded = $true
    }
    $curLocale = [string](Get-WinSystemLocale).Name
    if ($curLocale -ne $lang) {
        Invoke-CDTStep -StepName ('Set-WinSystemLocale {0} (vorher {1})' -f $lang, $curLocale) -Action { Set-WinSystemLocale -SystemLocale $lang }
        $script:RestartNeeded = $true
    }
    Invoke-CDTStep -StepName ('Set-Culture {0}' -f $lang) -Action { Set-Culture -CultureInfo $lang }
    Invoke-CDTStep -StepName ('Set-WinHomeLocation {0}' -f $script:Cfg.GeoId) -Action { Set-WinHomeLocation -GeoId $script:Cfg.GeoId }
    Invoke-CDTStep -StepName ('Set-WinUserLanguageList {0} mit {1} (ohne en-US)' -f $lang, $tip) -Action {
        $list = New-WinUserLanguageList -Language $lang
        $list[0].InputMethodTips.Clear()
        $list[0].InputMethodTips.Add($tip)
        Set-WinUserLanguageList -LanguageList $list -Force
    }
    Invoke-CDTStep -StepName ('Set-WinUILanguageOverride {0}' -f $lang) -Action { Set-WinUILanguageOverride -Language $lang }
    Invoke-CDTStep -StepName ('Set-WinDefaultInputMethodOverride {0}' -f $tip) -Action { Set-WinDefaultInputMethodOverride -InputTip $tip }
    Invoke-CDTStep -StepName 'Copy-UserInternationalSettingsToSystem (Welcome Screen + neue Benutzer)' -Action {
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    }
    $script:RestartNeeded = $true

    # Ergebnis nicht blind vertrauen: Registry verifizieren
    $welcome = Test-CDTIntlProfile -HiveRoot '.DEFAULT'
    if (-not $welcome.Ok) { Write-CDTLog -Level WARN -Message ('Welcome Screen (.DEFAULT) weicht ab: {0}' -f ($welcome.Deviations -join '; ')) }
    $defaultUser = Invoke-CDTWithDefaultUserHive -Action { param($root) Test-CDTIntlProfile -HiveRoot $root }
    if (-not $defaultUser.Ok -and $welcome.Ok) {
        Write-CDTLog -Level WARN -Message ('Default-User weicht ab ({0}) - Fallback: Registry-Kopie von .DEFAULT.' -f ($defaultUser.Deviations -join '; '))
        $defaultUser = Invoke-CDTWithDefaultUserHive -Action {
            param($root)
            Copy-CDTIntlRegistry -TargetRoot $root
            Test-CDTIntlProfile -HiveRoot $root
        }
    }
    $lvl = 'INFO'
    if (-not ($welcome.Ok -and $defaultUser.Ok)) { $lvl = 'ERROR' }
    Write-CDTLog -Level $lvl -Message ('Verifikation: Welcome Screen OK={0}, Default-User OK={1} {2}' -f $welcome.Ok, $defaultUser.Ok, ($defaultUser.Deviations -join '; '))
    return [pscustomobject]@{ Welcome = $welcome; DefaultUser = $defaultUser }
}

function Test-CDTInternationalNeeded {
    <#
    .SYNOPSIS
        True, wenn UI-Sprache, System Locale, Welcome Screen oder Default-User noch nicht dem Soll entsprechen (Idempotenz).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $lang = $script:Cfg.Language
    try {
        if ([string](Get-SystemPreferredUILanguage) -ne $lang) { return $true }
        if ([string](Get-WinSystemLocale).Name -ne $lang) { return $true }
        if (-not (Test-CDTIntlProfile -HiveRoot '.DEFAULT').Ok) { return $true }
        $du = Invoke-CDTWithDefaultUserHive -Action { param($root) Test-CDTIntlProfile -HiveRoot $root }
        return (-not $du.Ok)
    }
    catch {
        Write-CDTLog -Level WARN -Message ('Pruefung der Laendereinstellungen: {0}' -f $_.Exception.Message)
        return $true
    }
}

function Invoke-CDTTimeZoneConfiguration {
    <#
    .SYNOPSIS
        Setzt die Zeitzone und verhindert automatische Zeitzonenwechsel (tzautoupdate Start=4).
    #>
    [CmdletBinding()]
    param()
    $current = (Get-TimeZone).Id
    if ($current -ne $script:Cfg.TimeZone) {
        Set-TimeZone -Id $script:Cfg.TimeZone
        Write-CDTLog -Message ('Zeitzone gesetzt: {0} (vorher {1})' -f $script:Cfg.TimeZone, $current)
    }
    else { Write-CDTLog -Message ('Zeitzone bereits {0}.' -f $current) }
    if ($script:Cfg.AutoTimeZoneUpdate -eq 'Disable') {
        $svc = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
        if (Test-Path -LiteralPath $svc) {
            $start = Get-CDTRegistryValue -Path $svc -Name 'Start'
            if ([string]$start -ne '4') {
                Write-CDTRegistryValue -Path $svc -Name 'Start' -Value 4 -Type DWord
                Write-CDTLog -Message ('tzautoupdate deaktiviert (Start {0} -> 4).' -f $start)
            }
        }
        else { Write-CDTLog -Level WARN -Message 'Dienst tzautoupdate nicht vorhanden.' }
    }
}

function Enable-CDTLanguageCleanupBlocker {
    <#
    .SYNOPSIS
        MS-01..MS-05: Cleanup-Tasks deaktivieren und Policies gegen das Entfernen von Sprachkomponenten setzen.
    #>
    [CmdletBinding()]
    param()
    foreach ($t in $script:CleanupTasks) {
        $state = Get-CDTTaskState -TaskPath $t.Path -TaskName $t.Name
        if ($state -eq 'NotFound') { Write-CDTLog -Level WARN -Message ('{0}: Task {1}{2} nicht vorhanden.' -f $t.Id, $t.Path, $t.Name); continue }
        if ($state -ne 'Disabled') {
            $null = Disable-ScheduledTask -TaskPath $t.Path -TaskName $t.Name
            Write-CDTLog -Message ('{0}: Task deaktiviert: {1}{2} (vorher {3})' -f $t.Id, $t.Path, $t.Name, $state)
        }
        else { Write-CDTLog -Message ('{0}: Task bereits deaktiviert: {1}{2}' -f $t.Id, $t.Path, $t.Name) }
    }
    foreach ($pv in $script:PolicyValues) {
        $current = Get-CDTRegistryValue -Path $pv.Path -Name $pv.Name
        if ([string]$current -ne [string]$pv.Value) {
            Write-CDTRegistryValue -Path $pv.Path -Name $pv.Name -Value $pv.Value -Type DWord
            Write-CDTLog -Message ('{0}: {1}\{2} = {3} gesetzt (vorher {4}).' -f $pv.Id, $pv.Path, $pv.Name, $pv.Value, $current)
        }
        else { Write-CDTLog -Message ('{0}: {1} bereits {2}.' -f $pv.Id, $pv.Name, $pv.Value) }
    }
}
#endregion

#region LCU erneut anwenden (MS-08)
function Get-CDTLcuTargetMsu {
    <#
    .SYNOPSIS
        Waehlt aus den MSU-Dateinamen die Ziel-MSU (hoechste KB); Fremddateien sind ein Fehler (Microsoft: nur Ziel + Checkpoints).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([AllowEmptyCollection()][string[]]$FileName = @())
    $errors = [System.Collections.Generic.List[string]]::new()
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($n in $FileName) {
        if ($n -notmatch '(?i)\.msu$') { $errors.Add(('Fremddatei im LCU-Ordner: {0} (Microsoft: nur Ziel- und Checkpoint-MSU).' -f $n)); continue }
        $m = [regex]::Match($n, '(?i)kb(\d{6,8})')
        if ($m.Success) { $items.Add([pscustomobject]@{ Name = $n; Kb = [int]$m.Groups[1].Value }) }
        else { $errors.Add(('Keine KB-Nummer im Dateinamen: {0}' -f $n)) }
    }
    if ($items.Count -eq 0) { $errors.Add('Keine MSU-Datei gefunden.') }
    $sorted = @($items | Sort-Object -Property Kb -Descending)
    $target = $null
    if ($sorted.Count -gt 0) { $target = $sorted[0] }
    return [pscustomobject]@{ Target = $target; Checkpoints = @($sorted | Select-Object -Skip 1); Errors = $errors.ToArray() }
}

function Test-CDTNewerUbr {
    <#
    .SYNOPSIS
        True, wenn der aktuelle UBR groesser ist als der UBR zum Zeitpunkt der Sprachinstallation (gemeinsamer Branch).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowEmptyString()][string]$Current,
        [AllowEmptyString()][string]$Reference
    )
    $c = [regex]::Match([string]$Current, '^\d+\.(\d+)$')
    $r = [regex]::Match([string]$Reference, '^\d+\.(\d+)$')
    if (-not ($c.Success -and $r.Success)) { return $false }
    return ([int]$c.Groups[1].Value -gt [int]$r.Groups[1].Value)
}

function Get-CDTCurrentLcu {
    <#
    .SYNOPSIS
        Ermittelt Build.UBR, RollupFix-Version und KB des installierten LCU (CBS-Registry, WUA-Historie).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $os = Get-CDTOsInfo
    $kb = ''
    $source = ''
    $rollupVersion = ''
    try {
        $cbs = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'
        $keys = @(Get-ChildItem -LiteralPath $cbs -ErrorAction Stop | Where-Object { $_.PSChildName -like 'Package_for_RollupFix~*' })
        $installed = @($keys | Where-Object { [int](Get-CDTRegistryValue -Path $_.PSPath -Name 'CurrentState' -Default 0) -eq 112 })
        if ($installed.Count -eq 0) { $installed = $keys }
        $newest = @($installed | Sort-Object -Property @{ Expression = { try { [version](($_.PSChildName -split '~')[-1]) } catch { [version]'0.0' } } } -Descending) | Select-Object -First 1
        if ($null -ne $newest) {
            $rollupVersion = ($newest.PSChildName -split '~')[-1]
            foreach ($valueName in @('InstallName', 'InstallLocation')) {
                $v = [string](Get-CDTRegistryValue -Path $newest.PSPath -Name $valueName -Default '')
                $m = [regex]::Match($v, '(?i)KB(\d{6,8})')
                if ($m.Success) { $kb = 'KB' + $m.Groups[1].Value; $source = 'CBS-Registry'; break }
            }
        }
    }
    catch { Write-CDTLog -Level DEBUG -Message ('RollupFix-Ermittlung: {0}' -f $_.Exception.Message) }
    if (-not $kb) {
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            $count = $searcher.GetTotalHistoryCount()
            if ($count -gt 0) {
                foreach ($entry in $searcher.QueryHistory(0, [Math]::Min($count, 300))) {
                    $title = [string]$entry.Title
                    if ($entry.ResultCode -eq 2 -and $title -match '(?i)(Cumulative Update|Kumulatives Update)' -and $title -notmatch '(?i)\.NET') {
                        $m = [regex]::Match($title, '(?i)(KB\d{6,8})')
                        if ($m.Success) { $kb = $m.Groups[1].Value.ToUpperInvariant(); $source = 'WU-Historie'; break }
                    }
                }
            }
        }
        catch { Write-CDTLog -Level DEBUG -Message ('WU-Historie: {0}' -f $_.Exception.Message) }
    }
    if (-not $kb) { $kb = 'unbekannt' }
    return [pscustomobject]@{ Build = $os.Build; Ubr = $os.Ubr; BuildUbr = $os.BuildUbr; RollupFixVersion = $rollupVersion; Kb = $kb; KbSource = $source }
}

function Get-CDTLcuSource {
    <#
    .SYNOPSIS
        Stellt die MSU-Dateien (Ziel + Checkpoints) in einem sauberen lokalen Ordner bereit. Liefert '' ohne Quelle.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $target = Join-Path -Path $script:Cfg.TempPath -ChildPath 'lcu'
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    if (-not [string]::IsNullOrWhiteSpace($script:Cfg.LcuPath)) {
        $null = New-Item -Path $target -ItemType Directory -Force
        $conn = $null
        try {
            if ($script:Cfg.LcuPath -match '^\\\\') {
                $conn = Connect-CDTShare -UncPath $script:Cfg.LcuPath -AccountKey $script:Cfg.StorageAccountKey -StateName 'LcuHost'
            }
            $item = Get-Item -LiteralPath $script:Cfg.LcuPath
            if ($item.PSIsContainer) { Copy-CDTDirectory -Source $item.FullName -Destination $target -FileFilter @('*.msu') }
            else { Copy-Item -LiteralPath $item.FullName -Destination $target -Force }
        }
        finally { Disconnect-CDTShare -Connection $conn }
        return $target
    }
    if (@($script:Cfg.LcuUrl).Count -gt 0) {
        $null = New-Item -Path $target -ItemType Directory -Force
        $proxy = Get-CDTWinHttpProxy
        foreach ($u in @($script:Cfg.LcuUrl)) {
            $leaf = [System.Uri]::UnescapeDataString(([System.Uri]$u).Segments[-1])
            $null = Invoke-CDTDownload -Url $u -Destination (Join-Path -Path $target -ChildPath $leaf) -TimeoutMinutes ([int][Math]::Max(10, (Get-CDTRemainingBudget) - 20)) -Proxy $proxy
        }
        return $target
    }
    return ''
}

function Install-CDTLcu {
    <#
    .SYNOPSIS
        Installiert die Ziel-MSU per Add-WindowsPackage; DISM erkennt Checkpoint-MSU im selben Ordner.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][string]$Folder)
    $files = @(Get-ChildItem -LiteralPath $Folder -File)
    $selection = Get-CDTLcuTargetMsu -FileName @($files | ForEach-Object { $_.Name })
    if (@($selection.Errors).Count -gt 0) {
        foreach ($e in $selection.Errors) { Write-CDTLog -Level ERROR -Message $e }
        throw 'LCU-Ordner ungueltig.'
    }
    Write-CDTLog -Message ('Ziel-MSU: {0} (KB{1}); Checkpoints: {2}' -f $selection.Target.Name, $selection.Target.Kb, ((@($selection.Checkpoints) | ForEach-Object { 'KB' + $_.Kb }) -join ', '))
    # MSU: ungueltige/fremde Signatur = Abbruch. "NotSigned" nur WARN (eingebettete MSU-Signatur unbestaetigt; CBS prueft Pakete selbst).
    $badSig = @(Test-CDTCabSignature -FilePath @($files | ForEach-Object { $_.FullName }))
    $hardFail = @($badSig | Where-Object { $_.Status -ne 'NotSigned' })
    foreach ($b in $badSig) {
        $lvl = 'WARN'
        if ($b.Status -ne 'NotSigned') { $lvl = 'ERROR' }
        Write-CDTLog -Level $lvl -Message ('Signatur: {0} Status={1} Signer={2}' -f $b.File, $b.Status, $b.Signer)
    }
    if ($hardFail.Count -gt 0) { throw 'LCU verworfen: Authenticode-Pruefung fehlgeschlagen.' }
    $targetPath = Join-Path -Path $Folder -ChildPath $selection.Target.Name
    try {
        $res = Invoke-CDTStep -StepName ('Add-WindowsPackage {0}' -f $selection.Target.Name) -Action {
            Add-WindowsPackage -Online -PackagePath $targetPath -NoRestart -LogPath $script:DismLogFile
        }
        if ([bool](Get-CDTPropertyValue -InputObject $res -Name 'RestartNeeded' -Default $false)) { $script:RestartNeeded = $true }
        Save-CDTState -Name 'LcuReapplyKb' -Value ('KB{0}' -f $selection.Target.Kb)
        return ('Installed:KB{0}' -f $selection.Target.Kb)
    }
    catch {
        $info = Get-CDTErrorInfo -ErrorRecord $_
        if ($info.HResult -eq '0x800F081E') {
            Write-CDTLog -Level WARN -Message ('CBS meldet das LCU als nicht anwendbar (0x800F081E) - CBS sieht keine Sprachanteile zum Aktualisieren. MS-08 wird mit WARN als erfuellt gewertet.')
            Save-CDTState -Name 'LcuReapplyKb' -Value ('KB{0}' -f $selection.Target.Kb)
            return ('NotApplicable:KB{0}' -f $selection.Target.Kb)
        }
        throw
    }
}

function Install-CDTLcuViaWindowsUpdate {
    <#
    .SYNOPSIS
        Sucht und installiert ein neueres kumulatives Update ueber die Windows-Update-Agent-COM-API (keine externen Module).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $session = New-Object -ComObject Microsoft.Update.Session
    $session.ClientApplicationID = 'CDT-LanguageDeployment'
    $searcher = $session.CreateUpdateSearcher()
    Write-CDTLog -Message 'WUA: Suche nach nicht installierten Updates ...'
    $result = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
    $collection = New-Object -ComObject Microsoft.Update.UpdateColl
    $titles = [System.Collections.Generic.List[string]]::new()
    foreach ($u in $result.Updates) {
        $title = [string]$u.Title
        if ($title -match '(?i)(Cumulative Update|Kumulatives Update)' -and $title -match '(?i)Windows 11' -and $title -notmatch '(?i)\.NET') {
            if (-not $u.EulaAccepted) { $u.AcceptEula() }
            $null = $collection.Add($u)
            $titles.Add($title)
        }
    }
    if ($collection.Count -eq 0) { Write-CDTLog -Level WARN -Message 'WUA: kein neueres kumulatives Update angeboten.'; return '' }
    Write-CDTLog -Message ('WUA: installiere {0}' -f ($titles -join ' | '))
    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $collection
    $null = $downloader.Download()
    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $collection
    $installResult = $installer.Install()
    if ($installResult.RebootRequired) { $script:RestartNeeded = $true }
    if ($installResult.ResultCode -ne 2 -and $installResult.ResultCode -ne 3) { throw ('WUA-Installation fehlgeschlagen, ResultCode {0}, HRESULT 0x{1:X8}' -f $installResult.ResultCode, $installResult.HResult) }
    $kb = [regex]::Match(($titles -join ' '), '(?i)KB\d{6,8}').Value
    return ('WindowsUpdate:{0}' -f $kb)
}
#endregion

#region Sysprep-Readiness, Satelliten, Reste
function Get-CDTAppxSysprepBlocker {
    <#
    .SYNOPSIS
        MS-10: Appx-Pakete, die nur benutzerbezogen installiert oder fuer Benutzer aktualisiert wurden (Sysprep-Fehler 0x80073cf2).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()
    $provMap = @{}
    foreach ($p in @(Get-AppxProvisionedPackage -Online)) { $provMap[[string]$p.DisplayName] = $p }
    $blockers = foreach ($pkg in @(Get-AppxPackage -AllUsers)) {
        if ([string](Get-CDTPropertyValue -InputObject $pkg -Name 'SignatureKind' -Default '') -eq 'System') { continue }
        if ([bool](Get-CDTPropertyValue -InputObject $pkg -Name 'IsFramework' -Default $false)) { continue }
        $users = @(@(Get-CDTPropertyValue -InputObject $pkg -Name 'PackageUserInformation' -Default @()) | Where-Object {
                [string](Get-CDTPropertyValue -InputObject $_ -Name 'InstallState' -Default '') -eq 'Installed' -and
                [string](Get-CDTPropertyValue -InputObject (Get-CDTPropertyValue -InputObject $_ -Name 'UserSecurityId') -Name 'Sid' -Default '') -ne 'S-1-5-18'
            })
        if ($users.Count -eq 0) { continue }
        $userNames = (@($users | ForEach-Object { [string](Get-CDTPropertyValue -InputObject (Get-CDTPropertyValue -InputObject $_ -Name 'UserSecurityId') -Name 'Username' -Default '?') }) -join ',')
        $isLxp = ([string]$pkg.Name -like 'Microsoft.LanguageExperiencePack*')
        if (-not $provMap.ContainsKey([string]$pkg.Name)) {
            [pscustomobject]@{ Name = $pkg.Name; PackageFullName = $pkg.PackageFullName; Reason = 'NotProvisioned'; Users = $userNames; IsLxp = $isLxp; ProvisionedPackageName = '' }
        }
        else {
            $prov = $provMap[[string]$pkg.Name]
            $newer = $false
            try { $newer = ([version]$pkg.Version -gt [version]$prov.Version) } catch { $newer = ([string]$pkg.Version -ne [string]$prov.Version) }
            if ($newer) {
                [pscustomobject]@{ Name = $pkg.Name; PackageFullName = $pkg.PackageFullName; Reason = 'UpdatedForUser'; Users = $userNames; IsLxp = $isLxp; ProvisionedPackageName = $prov.PackageName }
            }
        }
    }
    return @($blockers)
}

function Repair-CDTAppxSysprepBlocker {
    <#
    .SYNOPSIS
        Entfernt Sysprep-Blocker nach Microsoft-KB: Remove-AppxPackage -AllUsers und ggf. Remove-AppxProvisionedPackage.
    #>
    [CmdletBinding()]
    param([AllowEmptyCollection()][object[]]$Blocker = @())
    foreach ($b in $Blocker) {
        try {
            Remove-AppxPackage -Package $b.PackageFullName -AllUsers -ErrorAction Stop
            Write-CDTLog -Message ('Appx entfernt (alle Benutzer): {0} [{1}]' -f $b.PackageFullName, $b.Reason)
        }
        catch { Write-CDTErrorRecord -ErrorRecord $_ -Context ('Remove-AppxPackage {0}' -f $b.PackageFullName) }
        if ($b.Reason -eq 'UpdatedForUser' -and $b.ProvisionedPackageName) {
            try {
                $null = Remove-AppxProvisionedPackage -Online -PackageName $b.ProvisionedPackageName -ErrorAction Stop
                Write-CDTLog -Level WARN -Message ('Provisionierung entfernt (Microsoft-KB): {0} - App fehlt im Image, ggf. neu provisionieren.' -f $b.ProvisionedPackageName)
            }
            catch { Write-CDTErrorRecord -ErrorRecord $_ -Context ('Remove-AppxProvisionedPackage {0}' -f $b.ProvisionedPackageName) }
        }
    }
}

function Get-CDTMissingSatellite {
    <#
    .SYNOPSIS
        Ermittelt installierte FoD-Pakete mit en-US-Satellit, denen der Satellit der Zielsprache fehlt.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowEmptyCollection()][string[]]$PackageName = @(),
        [Parameter(Mandatory = $true)][string]$Language
    )
    $parsed = foreach ($n in $PackageName) {
        $m = [regex]::Match($n, '^(?<base>[^~]+)~(?<key>[^~]*)~(?<arch>[^~]*)~(?<lang>[^~]*)~(?<ver>.*)$')
        if ($m.Success) { [pscustomobject]@{ Base = $m.Groups['base'].Value; Arch = $m.Groups['arch'].Value; Lang = $m.Groups['lang'].Value } }
    }
    $parsed = @($parsed)
    $comparer = [System.StringComparer]::OrdinalIgnoreCase
    $neutral = [System.Collections.Generic.HashSet[string]]::new($comparer)
    $targetSet = [System.Collections.Generic.HashSet[string]]::new($comparer)
    foreach ($p in $parsed) {
        if ($p.Lang -eq '') { $null = $neutral.Add(('{0}|{1}' -f $p.Base, $p.Arch)) }
        elseif ($p.Lang -eq $Language) { $null = $targetSet.Add(('{0}|{1}' -f $p.Base, $p.Arch)) }
    }
    $excluded = '^(?i)(Microsoft-Windows-Client-LanguagePack-Package|Microsoft-Windows-LanguageFeatures-|Microsoft-Windows-Lip-|Package_for_)'
    $missing = foreach ($p in $parsed) {
        if ($p.Lang -ne 'en-US' -or $p.Base -match $excluded) { continue }
        $key = '{0}|{1}' -f $p.Base, $p.Arch
        if ($neutral.Contains($key) -and -not $targetSet.Contains($key)) { '{0} ({1})' -f $p.Base, $p.Arch }
    }
    return @($missing | Select-Object -Unique)
}

function Get-CDTAppInstalledBefore {
    <#
    .SYNOPSIS
        MS-09: Desktop-Apps (Uninstall-Registry) mit Installationsdatum vor der Sprachinstallation.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param([Parameter(Mandatory = $true)][datetime]$Reference)
    $paths = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
    $apps = foreach ($p in $paths) {
        foreach ($e in @(Get-ItemProperty -Path $p -ErrorAction SilentlyContinue)) {
            $name = [string](Get-CDTPropertyValue -InputObject $e -Name 'DisplayName' -Default '')
            $date = [string](Get-CDTPropertyValue -InputObject $e -Name 'InstallDate' -Default '')
            $sysComp = [string](Get-CDTPropertyValue -InputObject $e -Name 'SystemComponent' -Default '0')
            if (-not $name -or $date -notmatch '^\d{8}$' -or $sysComp -eq '1') { continue }
            $parsedDate = [datetime]::ParseExact($date, 'yyyyMMdd', [System.Globalization.CultureInfo]::InvariantCulture)
            if ($parsedDate -lt $Reference.Date) { $name }
        }
    }
    return @($apps | Sort-Object -Unique)
}

function Get-CDTLeftover {
    <#
    .SYNOPSIS
        MS-11: verbundene Repository-Shares, cmdkey-Eintraege, eingebundene ISOs und Temp-Reste.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    $items = [System.Collections.Generic.List[string]]::new()
    $hosts = @(@((Get-CDTState -Name 'RepositoryHost' -Default ''), (Get-CDTState -Name 'LcuHost' -Default '')) | Where-Object { $_ } | Select-Object -Unique)
    if ($hosts.Count -gt 0) {
        $netUse = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\net.exe') -ArgumentList @('use') -NoLog
        $cmdkey = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\cmdkey.exe') -ArgumentList @('/list') -NoLog
        $mappings = @()
        try { $mappings = @(Get-SmbMapping -ErrorAction Stop) } catch { Write-CDTLog -Level DEBUG -Message ('Get-SmbMapping: {0}' -f $_.Exception.Message) }
        foreach ($h in $hosts) {
            if ($netUse.StdOut -match [regex]::Escape([string]$h)) { $items.Add(('net use: Verbindung zu {0}' -f $h)) }
            if ($cmdkey.StdOut -match [regex]::Escape([string]$h)) { $items.Add(('cmdkey: Anmeldedaten fuer {0}' -f $h)) }
            if (@($mappings | Where-Object { [string]$_.RemotePath -like ('\\{0}\*' -f $h) }).Count -gt 0) { $items.Add(('SMB-Mapping zu {0}' -f $h)) }
        }
    }
    if ([string](Get-CDTState -Name 'IsoMounted' -Default '')) { $items.Add('ISO noch eingebunden') }
    if (Test-Path -LiteralPath $script:Cfg.TempPath) {
        $files = @(Get-ChildItem -LiteralPath $script:Cfg.TempPath -Recurse -File -Force -ErrorAction SilentlyContinue)
        $isoFiles = @($files | Where-Object { $_.Extension -eq '.iso' })
        if ($isoFiles.Count -gt 0) { $items.Add(('ISO-Datei(en) in TempPath: {0}' -f ($isoFiles.Name -join ', '))) }
        if ($files.Count -gt 0) { $items.Add(('{0} Datei(en) in TempPath {1}' -f $files.Count, $script:Cfg.TempPath)) }
    }
    return $items.ToArray()
}
#endregion

#region Compliance
function Build-CDTComplianceRow {
    <#
    .SYNOPSIS
        Erzeugt eine Zeile der Compliance-Checkliste.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Empfehlung,
        [AllowEmptyString()][string]$Quelle = '',
        [AllowEmptyString()][string]$Soll = '',
        [AllowEmptyString()][AllowNull()][string]$Ist = '',
        [Parameter(Mandatory = $true)][ValidateSet('PASS', 'WARN', 'FAIL', 'INFO')][string]$Ergebnis,
        [Parameter(Mandatory = $true)][ValidateSet('MUSS', 'KANN', 'INFO')][string]$Pflicht
    )
    return [pscustomobject]@{ ID = $Id; Empfehlung = $Empfehlung; Quelle = $Quelle; Soll = $Soll; Ist = [string]$Ist; Ergebnis = $Ergebnis; Pflicht = $Pflicht }
}

function Get-CDTComplianceFact {
    <#
    .SYNOPSIS
        Sammelt alle Ist-Werte fuer Compliance und Auto-Entscheidung (jede Teilmessung fehlertolerant).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $f = [ordered]@{}
    $f.Tasks = @{}
    foreach ($t in $script:CleanupTasks) { $f.Tasks[$t.Id] = Get-CDTTaskState -TaskPath $t.Path -TaskName $t.Name }
    $f.BlockCleanup = Get-CDTRegistryValue -Path $script:PolicyValues[0].Path -Name $script:PolicyValues[0].Name
    $f.AllowLangFeaturesUninstall = Get-CDTRegistryValue -Path $script:PolicyValues[1].Path -Name $script:PolicyValues[1].Name
    $f.RestrictLanguageInstall = Get-CDTRegistryValue -Path $script:RestrictPolicy.Path -Name $script:RestrictPolicy.Name
    $os = Get-CDTOsInfo
    $f.Os = $os
    $f.Base = Get-CDTServicingBaseBuild -CurrentBuild $os.Build -PackageBuild (Get-CDTInstalledLanguagePackBuild -PreferLanguage 'en-US')
    try { $f.LanguageState = Get-CDTLanguageState -Refresh } catch { $f.LanguageState = $null; Write-CDTErrorRecord -ErrorRecord $_ -Context 'Sprachstatus' }
    $f.EnUsPresent = @(Get-CDTWindowsPackageList | Where-Object { $_.PackageName -like 'Microsoft-Windows-Client-LanguagePack-Package~31bf3856ad364e35~*~en-US~*' }).Count -gt 0
    foreach ($n in @('InstallSource', 'InstallTimestamp', 'LanguagePackInstalledAt', 'FodInstalledAt', 'LcuReapplyResult', 'LcuReapplyKb', 'OsBuildAtInstall', 'LcuReappliedBuild', 'PolicyBackupJson', 'TempDisabledTasks')) {
        $f[$n] = [string](Get-CDTState -Name $n -Default '')
    }
    $f.LcuReapplyRequired = [int](Get-CDTState -Name 'LcuReapplyRequired' -Default 0)
    $f.WinReLanguageAdded = [int](Get-CDTState -Name 'WinReLanguageAdded' -Default 0)
    $f.CurrentLcuKb = ''
    if ($f.LcuReapplyRequired -eq 1) { try { $f.CurrentLcuKb = (Get-CDTCurrentLcu).Kb } catch { $f.CurrentLcuKb = 'unbekannt' } }
    $f.AppsBefore = @()
    $installDate = ConvertFrom-CDTIsoDate -Value $f.InstallTimestamp
    if ($null -ne $installDate) {
        try { $f.AppsBefore = @(Get-CDTAppInstalledBefore -Reference $installDate) }
        catch { Write-CDTLog -Level WARN -Message ('MS-09-Pruefung: {0}' -f $_.Exception.Message) }
    }
    try { $f.AppxBlockers = @(Get-CDTAppxSysprepBlocker) } catch { $f.AppxBlockers = @([pscustomobject]@{ Name = 'Pruefung fehlgeschlagen'; Reason = $_.Exception.Message; PackageFullName = ''; Users = ''; IsLxp = $false; ProvisionedPackageName = '' }) }
    try { $f.Leftovers = @(Get-CDTLeftover) } catch { $f.Leftovers = @(('Pruefung fehlgeschlagen: {0}' -f $_.Exception.Message)) }
    try { $f.SystemPreferredUi = [string](Get-SystemPreferredUILanguage) } catch { $f.SystemPreferredUi = 'Fehler' }
    try { $f.SystemLocale = [string](Get-WinSystemLocale).Name } catch { $f.SystemLocale = 'Fehler' }
    try { $f.WelcomeProfile = Test-CDTIntlProfile -HiveRoot '.DEFAULT' } catch { $f.WelcomeProfile = [pscustomobject]@{ Ok = $false; Deviations = @($_.Exception.Message); LocaleName = ''; Nation = '' } }
    try { $f.DefaultUserProfile = Invoke-CDTWithDefaultUserHive -Action { param($root) Test-CDTIntlProfile -HiveRoot $root } } catch { $f.DefaultUserProfile = [pscustomobject]@{ Ok = $false; Deviations = @($_.Exception.Message); LocaleName = ''; Nation = '' } }
    $f.TimeZoneId = (Get-TimeZone).Id
    $f.TzAutoStart = Get-CDTRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate' -Name 'Start'
    $f.PendingReboot = Get-CDTPendingReboot
    try {
        $names = @(Get-CDTWindowsPackageList | Where-Object { @('Installed', 'InstallPending') -contains [string]$_.PackageState } | ForEach-Object { $_.PackageName })
        $f.MissingSatellites = @(Get-CDTMissingSatellite -PackageName $names -Language $script:Cfg.Language)
    }
    catch { $f.MissingSatellites = @(('Pruefung fehlgeschlagen: {0}' -f $_.Exception.Message)) }
    $f.WuFindings = @(Get-CDTWuPolicyFinding)
    $mui = 'n/a'
    $deMui = Join-Path -Path $env:SystemRoot -ChildPath ('System32\{0}\explorer.exe.mui' -f $script:Cfg.Language)
    $enMui = Join-Path -Path $env:SystemRoot -ChildPath 'System32\en-US\explorer.exe.mui'
    if ((Test-Path -LiteralPath $deMui) -and (Test-Path -LiteralPath $enMui)) {
        $mui = ('{0}: {1} / en-US: {2}' -f $script:Cfg.Language, (Get-Item -LiteralPath $deMui).VersionInfo.FileVersionRaw, (Get-Item -LiteralPath $enMui).VersionInfo.FileVersionRaw)
    }
    $f.MuiInfo = $mui
    $ctx = Get-CDTExecutionContext
    $f.Context = ('{0}, PS {1}, 64-Bit={2}' -f $ctx.User, $ctx.PSVersion, $ctx.Is64BitProcess)
    return [pscustomobject]$f
}

function Get-CDTComplianceResult {
    <#
    .SYNOPSIS
        Bewertet die Fakten gegen MS-01..MS-16 und ZUS-01..ZUS-15 (reine Funktion, testbar).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)][object]$Fact,
        [Parameter(Mandatory = $true)][object]$Config
    )
    $s = $script:Src
    $lang = $Config.Language
    $rows = [System.Collections.Generic.List[object]]::new()

    $taskDefs = @(
        @{ Id = 'MS-01'; Text = 'Scheduled Task "\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup" deaktiviert' }
        @{ Id = 'MS-02'; Text = 'Scheduled Task "\Microsoft\Windows\MUI\LPRemove" deaktiviert' }
        @{ Id = 'MS-03'; Text = 'Scheduled Task "\Microsoft\Windows\LanguageComponentsInstaller\Uninstallation" deaktiviert' }
    )
    foreach ($td in $taskDefs) {
        $st = [string](Get-CDTPropertyValue -InputObject $Fact.Tasks -Name $td.Id -Default 'Error')
        $res = 'FAIL'
        if ($st -eq 'Disabled') { $res = 'PASS' } elseif ($st -eq 'NotFound') { $res = 'WARN' }
        $src = $s.AvdLang
        if ($td.Id -eq 'MS-03') { $src = $s.LangOverview }
        $rows.Add((Build-CDTComplianceRow -Id $td.Id -Empfehlung $td.Text -Quelle $src -Soll 'Disabled' -Ist $st -Ergebnis $res -Pflicht 'MUSS'))
    }
    $v4 = [string]$Fact.BlockCleanup
    $rows.Add((Build-CDTComplianceRow -Id 'MS-04' -Empfehlung 'HKLM\SOFTWARE\Policies\Microsoft\Control Panel\International\BlockCleanupOfUnusedPreinstalledLangPacks = 1' -Quelle $s.LangOverview -Soll '1' -Ist $v4 -Ergebnis $(if ($v4 -eq '1') { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    $v5 = [string]$Fact.AllowLangFeaturesUninstall
    $rows.Add((Build-CDTComplianceRow -Id 'MS-05' -Empfehlung 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput\AllowLanguageFeaturesUninstall = 0' -Quelle $s.LangOverview -Soll '0' -Ist $v5 -Ergebnis $(if ($v5 -eq '0') { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))

    $ls = $Fact.LanguageState
    $lpPresent = ($null -ne $ls) -and [bool]$ls.LanguagePackPresent
    $lpBuild = 0
    if ($null -ne $ls) { $lpBuild = [int]$ls.LanguagePackBuild }
    $base = [int]$Fact.Base.BaseBuild
    $r6 = 'FAIL'
    if ($lpPresent -and $base -gt 0 -and $lpBuild -eq $base) { $r6 = 'PASS' } elseif ($lpPresent -and $base -le 0) { $r6 = 'WARN' }
    $rows.Add((Build-CDTComplianceRow -Id 'MS-06' -Empfehlung 'Sprachkomponenten passen zum OS-Hauptbuild' -Quelle $s.LangOverview -Soll ('Sprachpaket-Build = Servicing-Basis {0}' -f $base) -Ist ('Sprachpaket-Build {0}, OS {1}' -f $lpBuild, $Fact.Os.BuildUbr) -Ergebnis $r6 -Pflicht 'MUSS'))

    $src7 = [string]$Fact.InstallSource
    $r7 = 'WARN'
    $ist7 = 'Installationsquelle unbekannt (nicht durch dieses Script installiert)'
    if (-not $lpPresent) { $r7 = 'FAIL'; $ist7 = 'Sprachpaket fehlt' }
    elseif ($src7 -match '[23]') {
        $lpAt = [string]$Fact.LanguagePackInstalledAt
        $fodAt = [string]$Fact.FodInstalledAt
        $lpDate = ConvertFrom-CDTIsoDate -Value $lpAt
        $fodDate = ConvertFrom-CDTIsoDate -Value $fodAt
        if ($null -ne $lpDate -and ($null -eq $fodDate -or $lpDate -le $fodDate)) {
            $r7 = 'PASS'; $ist7 = ('Stufe {0}: LP {1} vor FoDs {2}' -f $src7, $lpAt, $fodAt)
        }
        else { $r7 = 'FAIL'; $ist7 = ('Reihenfolge verletzt oder nicht belegt: LP {0}, FoDs {1}' -f $lpAt, $fodAt) }
    }
    elseif ($src7 -match '1') { $r7 = 'PASS'; $ist7 = 'Stufe 1: Install-Language installiert Sprachpaket vor FoDs' }
    $rows.Add((Build-CDTComplianceRow -Id 'MS-07' -Empfehlung 'Reihenfolge Language Pack -> Language-FoDs (Stufe 2/3)' -Quelle $s.LangFod -Soll 'LP vor FoDs' -Ist $ist7 -Ergebnis $r7 -Pflicht 'MUSS'))

    $r8 = 'FAIL'
    $ist8 = ''
    $result8 = [string]$Fact.LcuReapplyResult
    if (-not $lpPresent) { $ist8 = 'Sprachpaket fehlt' }
    elseif ([int]$Fact.LcuReapplyRequired -eq 1) { $ist8 = ('LCU erneut installieren: {0} ({1}{0}), Checkpoint-MSU beachten' -f $Fact.CurrentLcuKb, $s.Catalog) }
    elseif ($result8 -like 'NotApplicable*') { $r8 = 'WARN'; $ist8 = ('{0} (CBS: nicht anwendbar)' -f $result8) }
    elseif ($result8) { $r8 = 'PASS'; $ist8 = ('{0}, Build {1}' -f $result8, $Fact.LcuReappliedBuild) }
    else { $ist8 = 'Kein Nachweis (Zustand fehlt)' }
    $rows.Add((Build-CDTComplianceRow -Id 'MS-08' -Empfehlung 'LCU nach der Sprachpaket-Installation erneut installiert (oder neueres LCU)' -Quelle $s.LangOverview -Soll 'LcuReapplyRequired = 0' -Ist $ist8 -Ergebnis $r8 -Pflicht 'MUSS'))

    $apps = @($Fact.AppsBefore)
    $r9 = 'PASS'
    $ist9 = 'Keine Desktop-App vor der Sprachinstallation'
    if (-not $Fact.InstallTimestamp) { $r9 = 'WARN'; $ist9 = 'Installationszeitpunkt der Sprache unbekannt' }
    elseif ($apps.Count -gt 0) { $r9 = 'WARN'; $ist9 = ('{0} App(s) vor der Sprache installiert (ggf. neu installieren): {1}' -f $apps.Count, (($apps | Select-Object -First 10) -join '; ')) }
    $rows.Add((Build-CDTComplianceRow -Id 'MS-09' -Empfehlung 'Apps erst nach den Sprachen installieren (Pipeline-Hinweis)' -Quelle $s.OemDeploy -Soll 'Apps nach Sprache + LCU' -Ist $ist9 -Ergebnis $r9 -Pflicht 'MUSS'))

    $blk = @($Fact.AppxBlockers)
    $ist10 = 'Keine'
    if ($blk.Count -gt 0) { $ist10 = (@($blk | ForEach-Object { '{0} [{1}]' -f $_.Name, $_.Reason }) -join '; ') }
    $rows.Add((Build-CDTComplianceRow -Id 'MS-10' -Empfehlung 'Sysprep-Readiness: keine nur benutzerbezogenen/aktualisierten Appx-Pakete (inkl. LXP)' -Quelle $s.SysprepAppx -Soll '0 Blocker' -Ist $ist10 -Ergebnis $(if ($blk.Count -eq 0) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))

    $left = @($Fact.Leftovers)
    $ist11 = 'Keine'
    if ($left.Count -gt 0) { $ist11 = ($left -join '; ') }
    $rows.Add((Build-CDTComplianceRow -Id 'MS-11' -Empfehlung 'Kein Repository-Share verbunden, keine cmdkey-Eintraege, keine ISO-/Temp-Reste' -Quelle $s.AvdLang -Soll 'Keine Reste' -Ist $ist11 -Ergebnis $(if ($left.Count -eq 0) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))

    $caps = @()
    if ($null -ne $ls) { $caps = @($ls.Capabilities) }
    $missingCaps = @($caps | Where-Object { @('Installed', 'InstallPending') -notcontains $_.State })
    $pendingCaps = @($caps | Where-Object { $_.State -eq 'InstallPending' })
    $r12 = 'PASS'
    if ($null -eq $ls -or $missingCaps.Count -gt 0) { $r12 = 'FAIL' } elseif ($pendingCaps.Count -gt 0) { $r12 = 'WARN' }
    $ist12 = (@($caps | ForEach-Object { '{0}={1}' -f $_.Feature, $_.State }) -join ', ')
    $rows.Add((Build-CDTComplianceRow -Id 'MS-12' -Empfehlung 'Language-FoDs Basic (+ gewaehlte OCR/Handwriting/Speech/TextToSpeech) installiert' -Quelle $s.LangFod -Soll 'State = Installed' -Ist $ist12 -Ergebnis $r12 -Pflicht 'MUSS'))

    $v13 = [string]$Fact.RestrictLanguageInstall
    if ($Config.RestrictUserLanguageInstall) {
        $rows.Add((Build-CDTComplianceRow -Id 'MS-13' -Empfehlung 'Policy RestrictLanguagePacksAndFeaturesInstall = 1 (Multi-Session)' -Quelle $s.PolicyCsp -Soll '1' -Ist $v13 -Ergebnis $(if ($v13 -eq '1') { 'PASS' } else { 'FAIL' }) -Pflicht 'KANN'))
    }
    else {
        $rows.Add((Build-CDTComplianceRow -Id 'MS-13' -Empfehlung 'Policy RestrictLanguagePacksAndFeaturesInstall (optional, -RestrictUserLanguageInstall)' -Quelle $s.PolicyCsp -Soll 'nicht angefordert' -Ist $v13 -Ergebnis 'INFO' -Pflicht 'KANN'))
    }
    if ($Config.IncludeWinRELanguage) {
        $rows.Add((Build-CDTComplianceRow -Id 'MS-14' -Empfehlung ('WinRE-Sprachpaket {0}' -f $lang) -Quelle $s.WinRE -Soll 'integriert' -Ist ([string]$Fact.WinReLanguageAdded) -Ergebnis $(if ([int]$Fact.WinReLanguageAdded -eq 1) { 'PASS' } else { 'FAIL' }) -Pflicht 'KANN'))
    }
    else {
        $rows.Add((Build-CDTComplianceRow -Id 'MS-14' -Empfehlung 'WinRE-Sprachpaket (optional, -IncludeWinRELanguage; fuer AVD i. d. R. nicht noetig)' -Quelle $s.WinRE -Soll 'nicht angefordert' -Ist ([string]$Fact.WinReLanguageAdded) -Ergebnis 'INFO' -Pflicht 'KANN'))
    }
    $rows.Add((Build-CDTComplianceRow -Id 'MS-15' -Empfehlung 'en-US nicht entfernen (Rueckfallsprache; Entfernen nur in umgekehrter Reihenfolge)' -Quelle $s.LangOverview -Soll 'en-US vorhanden' -Ist $(if ($Fact.EnUsPresent) { 'vorhanden' } else { 'fehlt' }) -Ergebnis $(if ($Fact.EnUsPresent) { 'INFO' } else { 'WARN' }) -Pflicht 'INFO'))
    $rows.Add((Build-CDTComplianceRow -Id 'MS-16' -Empfehlung 'Benutzer nach Wechsel der Anzeigesprache ueber das Startmenue abmelden (README)' -Quelle $s.AvdLang -Soll 'dokumentiert' -Ist 'README' -Ergebnis 'INFO' -Pflicht 'INFO'))

    # Zusatzpruefungen
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-01' -Empfehlung ('Sprachpaket {0} installiert' -f $lang) -Quelle $s.AddLang -Soll 'Installed' -Ist $(if ($null -ne $ls) { $ls.LanguagePackState } else { 'Fehler' }) -Ergebnis $(if ($null -ne $ls -and $ls.LanguagePackState -eq 'Installed') { 'PASS' } elseif ($lpPresent) { 'WARN' } else { 'FAIL' }) -Pflicht 'MUSS'))
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-02' -Empfehlung 'System Preferred UI Language' -Quelle $s.SysPrefUi -Soll $lang -Ist $Fact.SystemPreferredUi -Ergebnis $(if ($Fact.SystemPreferredUi -eq $lang) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-03' -Empfehlung 'System Locale (Sprache fuer Unicode-fremde Programme)' -Quelle $s.AddLang -Soll $lang -Ist $Fact.SystemLocale -Ergebnis $(if ($Fact.SystemLocale -eq $lang) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    $wp = $Fact.WelcomeProfile
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-04' -Empfehlung 'Regionalformat (Culture) Welcome Screen/Systemkonten' -Quelle $s.CopyIntl -Soll $lang -Ist ([string](Get-CDTPropertyValue -InputObject $wp -Name 'LocaleName' -Default '')) -Ergebnis $(if ([string](Get-CDTPropertyValue -InputObject $wp -Name 'LocaleName' -Default '') -eq $lang) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-05' -Empfehlung 'Home Location (GeoID)' -Quelle $s.CopyIntl -Soll ([string]$Config.GeoId) -Ist ([string](Get-CDTPropertyValue -InputObject $wp -Name 'Nation' -Default '')) -Ergebnis $(if ([string](Get-CDTPropertyValue -InputObject $wp -Name 'Nation' -Default '') -eq [string]$Config.GeoId) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-06' -Empfehlung 'Zeitzone' -Quelle $s.TzAuto -Soll $Config.TimeZone -Ist $Fact.TimeZoneId -Ergebnis $(if ($Fact.TimeZoneId -eq $Config.TimeZone) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    if ($Config.AutoTimeZoneUpdate -eq 'Disable') {
        $rows.Add((Build-CDTComplianceRow -Id 'ZUS-07' -Empfehlung 'Automatische Zeitzone deaktiviert (tzautoupdate Start = 4)' -Quelle $s.TzAuto -Soll '4' -Ist ([string]$Fact.TzAutoStart) -Ergebnis $(if ([string]$Fact.TzAutoStart -eq '4') { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    }
    else {
        $rows.Add((Build-CDTComplianceRow -Id 'ZUS-07' -Empfehlung 'Automatische Zeitzone (tzautoupdate) unveraendert (-AutoTimeZoneUpdate Keep)' -Quelle $s.TzAuto -Soll 'Keep' -Ist ([string]$Fact.TzAutoStart) -Ergebnis 'INFO' -Pflicht 'INFO'))
    }
    $du = $Fact.DefaultUserProfile
    $duOk = [bool](Get-CDTPropertyValue -InputObject $du -Name 'Ok' -Default $false)
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-08' -Empfehlung 'Default-User-Profil (neue Benutzer): Format, GeoID, Sprachliste, Tastatur ohne en-US' -Quelle $s.CopyIntl -Soll ('{0}, {1}, {2}' -f $lang, $Config.GeoId, $Config.InputLocale) -Ist $(if ($duOk) { 'OK' } else { (@(Get-CDTPropertyValue -InputObject $du -Name 'Deviations' -Default @()) -join '; ') }) -Ergebnis $(if ($duOk) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    $wpOk = [bool](Get-CDTPropertyValue -InputObject $wp -Name 'Ok' -Default $false)
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-09' -Empfehlung 'Welcome Screen/Systemkonten (.DEFAULT): Sprachliste und Tastatur ohne en-US' -Quelle $s.CopyIntl -Soll ('{0}, {1}' -f $lang, $Config.InputLocale) -Ist $(if ($wpOk) { 'OK' } else { (@(Get-CDTPropertyValue -InputObject $wp -Name 'Deviations' -Default @()) -join '; ') }) -Ergebnis $(if ($wpOk) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    $pr = $Fact.PendingReboot
    $r10 = 'PASS'
    if ([bool]$pr.Blocking) { $r10 = 'FAIL' } elseif ([bool]$pr.Required) { $r10 = 'WARN' }
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-10' -Empfehlung 'Kein Neustart ausstehend (CBS/WU; PendingFileRenameOperations nur WARN)' -Quelle $s.AddLang -Soll 'kein Neustart ausstehend' -Ist $(if (@($pr.Reasons).Count -gt 0) { (@($pr.Reasons) -join ', ') } else { 'keiner' }) -Ergebnis $r10 -Pflicht 'MUSS'))
    $sat = @($Fact.MissingSatellites)
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-11' -Empfehlung ('Satellitenpakete {0} fuer installierte FoDs (sonst unlokalisiert)' -f $lang) -Quelle $s.LangOverview -Soll 'keine fehlenden Satelliten' -Ist $(if ($sat.Count -eq 0) { 'Keine fehlend' } else { ($sat -join '; ') }) -Ergebnis $(if ($sat.Count -eq 0) { 'PASS' } else { 'WARN' }) -Pflicht 'KANN'))
    $wu = @($Fact.WuFindings)
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-12' -Empfehlung 'WSUS-/WU-/Servicing-Policies (Blocker fuer Stufe 1)' -Quelle $s.WsusFod -Soll 'keine Blocker' -Ist $(if ($wu.Count -eq 0) { 'keine' } else { (@($wu | ForEach-Object { '{0}={1}{2}' -f $_.Name, $_.Value, $(if ($_.Blocking) { ' (Blocker)' } else { '' }) }) -join '; ') }) -Ergebnis 'INFO' -Pflicht 'INFO'))
    $open13 = [System.Collections.Generic.List[string]]::new()
    if ($Fact.PolicyBackupJson) { $open13.Add('Policy-Backup offen (Rollback ausstehend)') }
    if ($Fact.TempDisabledTasks) { $open13.Add(('Installer-Tasks deaktiviert: {0}' -f $Fact.TempDisabledTasks)) }
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-13' -Empfehlung 'Temporaere Aenderungen zurueckgesetzt (Policies, LanguageComponentsInstaller-Tasks)' -Quelle $s.AibScript -Soll 'keine offenen Aenderungen' -Ist $(if ($open13.Count -eq 0) { 'keine' } else { ($open13 -join '; ') }) -Ergebnis $(if ($open13.Count -eq 0) { 'PASS' } else { 'FAIL' }) -Pflicht 'MUSS'))
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-14' -Empfehlung 'MUI-Dateiversion explorer.exe.mui (Heuristik fuer LCU-Sprachanteile, unbestaetigt)' -Quelle $s.LangOverview -Soll 'gleiche Version wie en-US' -Ist $Fact.MuiInfo -Ergebnis 'INFO' -Pflicht 'INFO'))
    $rows.Add((Build-CDTComplianceRow -Id 'ZUS-15' -Empfehlung 'OS-Build und Ausfuehrungskontext' -Quelle $s.ReleaseInfo -Soll 'Build >= 26100, SYSTEM' -Ist ('{0} ({1}), Basis {2}; {3}' -f $Fact.Os.BuildUbr, $Fact.Base.Release, $Fact.Base.BaseBuild, $Fact.Context) -Ergebnis $(if ($Fact.Base.Supported) { 'INFO' } else { 'FAIL' }) -Pflicht 'INFO'))
    return $rows.ToArray()
}

function Get-CDTStatusFromCompliance {
    <#
    .SYNOPSIS
        Leitet Status aus offenen MUSS-Punkten ab (reine Funktion).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [AllowEmptyCollection()][object[]]$Row = @(),
        [Parameter(Mandatory = $true)][string]$EffectiveMode,
        [bool]$RebootPending = $false
    )
    $mustFail = @($Row | Where-Object { $_.Pflicht -eq 'MUSS' -and $_.Ergebnis -eq 'FAIL' })
    if ($EffectiveMode -eq 'PreSysprep') {
        if ($mustFail.Count -gt 0) { return @('PRESYSPREP_BLOCKED') }
        return @('SUCCESS')
    }
    # Sysprep-Readiness (MS-10) blockiert nur PreSysprep; vorher werden noch Apps installiert.
    $mustFail = @($mustFail | Where-Object { $_.ID -ne 'MS-10' })
    if ($mustFail.Count -eq 0) { return @('SUCCESS') }
    $ids = @($mustFail | ForEach-Object { $_.ID })
    $statuses = [System.Collections.Generic.List[string]]::new()
    $other = @($ids | Where-Object { $_ -ne 'MS-08' -and $_ -ne 'ZUS-10' })
    if ($other.Count -gt 0) {
        if ($RebootPending) { $statuses.Add('SUCCESS_REBOOT_REQUIRED') } else { $statuses.Add('PARTIAL') }
    }
    if ($ids -contains 'ZUS-10') { $statuses.Add('SUCCESS_REBOOT_REQUIRED') }
    if ($ids -contains 'MS-08') { $statuses.Add('SUCCESS_LCU_REAPPLY_PENDING') }
    return $statuses.ToArray()
}

function Test-CDTInstallComplete {
    <#
    .SYNOPSIS
        Prueft, ob die Install-Phase vollstaendig ist (reine Funktion fuer Mode Auto).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][object]$Fact,
        [Parameter(Mandatory = $true)][object]$Config
    )
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($id in @('MS-01', 'MS-02', 'MS-03')) {
        $st = [string](Get-CDTPropertyValue -InputObject $Fact.Tasks -Name $id -Default 'Error')
        if ($st -ne 'Disabled' -and $st -ne 'NotFound') { $missing.Add($id) }
    }
    if ([string]$Fact.BlockCleanup -ne '1') { $missing.Add('MS-04') }
    if ([string]$Fact.AllowLangFeaturesUninstall -ne '0') { $missing.Add('MS-05') }
    $ls = $Fact.LanguageState
    if ($null -eq $ls -or -not $ls.LanguagePackPresent) { $missing.Add('Sprachpaket') }
    elseif (-not $ls.CapabilitiesPresent) { $missing.Add('Language-FoDs') }
    if ($Fact.SystemPreferredUi -ne $Config.Language) { $missing.Add('SystemPreferredUILanguage') }
    if ($Fact.SystemLocale -ne $Config.Language) { $missing.Add('SystemLocale') }
    if (-not [bool](Get-CDTPropertyValue -InputObject $Fact.WelcomeProfile -Name 'Ok' -Default $false)) { $missing.Add('WelcomeScreen') }
    if (-not [bool](Get-CDTPropertyValue -InputObject $Fact.DefaultUserProfile -Name 'Ok' -Default $false)) { $missing.Add('DefaultUser') }
    if ($Fact.TimeZoneId -ne $Config.TimeZone) { $missing.Add('Zeitzone') }
    if ($Config.AutoTimeZoneUpdate -eq 'Disable' -and [string]$Fact.TzAutoStart -ne '4') { $missing.Add('tzautoupdate') }
    if ($Config.RestrictUserLanguageInstall -and [string]$Fact.RestrictLanguageInstall -ne '1') { $missing.Add('MS-13') }
    if ($Config.IncludeWinRELanguage -and [int]$Fact.WinReLanguageAdded -ne 1) { $missing.Add('MS-14') }
    return [pscustomobject]@{ Complete = ($missing.Count -eq 0); Missing = $missing.ToArray() }
}

function Select-CDTAutoAction {
    <#
    .SYNOPSIS
        Entscheidungslogik von Mode Auto (reine Funktion).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [bool]$AwaitingReboot,
        [bool]$BlockingPendingReboot,
        [bool]$InstallComplete,
        [bool]$LcuReapplyRequired
    )
    if ($AwaitingReboot -or $BlockingPendingReboot) { return 'WaitForReboot' }
    if (-not $InstallComplete) { return 'Install' }
    if ($LcuReapplyRequired) { return 'ReapplyLcu' }
    return 'Validate'
}

function Get-CDTRebootDecision {
    <#
    .SYNOPSIS
        Entscheidet ueber einen verzoegerten Neustart (reine Funktion).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [bool]$RebootRequired,
        [bool]$RebootIfRequired,
        [bool]$ForceReboot,
        [bool]$ForceRebootOnError
    )
    if ($ForceReboot) {
        if ($Status -eq 'FAILED' -and -not $ForceRebootOnError) {
            return [pscustomobject]@{ Reboot = $false; Reason = 'ForceReboot unterdrueckt: Status FAILED ohne -ForceRebootOnError' }
        }
        return [pscustomobject]@{ Reboot = $true; Reason = ('ForceReboot (Status {0})' -f $Status) }
    }
    if ($RebootIfRequired -and $RebootRequired) {
        if ($Status -eq 'FAILED') { return [pscustomobject]@{ Reboot = $false; Reason = 'RebootIfRequired: kein Neustart bei FAILED (Diagnose sichern)' } }
        return [pscustomobject]@{ Reboot = $true; Reason = 'RebootIfRequired: Neustart ausstehend' }
    }
    if ($RebootRequired) { return [pscustomobject]@{ Reboot = $false; Reason = 'Neustart erforderlich - per Exit-Code signalisiert (kein automatischer Neustart)' } }
    return [pscustomobject]@{ Reboot = $false; Reason = 'Kein Neustart erforderlich' }
}

function Get-CDTNextAction {
    <#
    .SYNOPSIS
        Formuliert die naechste Aktion fuer Summary und Log (reine Funktion).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$EffectiveMode,
        [AllowEmptyString()][string]$LcuKb = '',
        [bool]$RebootPlanned = $false
    )
    switch ($Status) {
        'FAILED' { return 'Fehlerlog und Diagnose-Ordner pruefen, Ursache beheben, Script erneut ausfuehren.' }
        'PRESYSPREP_BLOCKED' { return 'Offene MUSS-Punkte beheben (Compliance-CSV), dann Mode PreSysprep erneut ausfuehren. Sysprep/Capture NICHT starten.' }
        'PARTIAL' { return 'Script erneut ausfuehren (Mode Auto setzt an der offenen Stelle fort). Bei Wiederholung Diagnose-Ordner pruefen.' }
        'SUCCESS_REBOOT_REQUIRED' {
            if ($RebootPlanned) { return 'Neustart ist geplant. Danach Script erneut ausfuehren (Mode Auto).' }
            return 'VM neu starten, danach Script erneut ausfuehren (Mode Auto).'
        }
        'SUCCESS_LCU_REAPPLY_PENDING' {
            return ('LCU {0} inkl. Checkpoint-MSU aus dem Microsoft Update Catalog bereitstellen und Mode ReapplyLcu (oder Auto) mit -LcuPath/-LcuUrl ausfuehren; alternativ -UseWindowsUpdateForNewerLcu.' -f $LcuKb)
        }
        default {
            if ($EffectiveMode -eq 'PreSysprep') { return 'Sysprep/Capture freigegeben ("Set as Image" bzw. HYDRA-Imaging).' }
            return 'Apps installieren, danach Mode PreSysprep als letzten Schritt vor Sysprep/Capture ausfuehren.'
        }
    }
}
#endregion

#region Diagnose, Rotation, Summary, Reboot
function Export-CDTLogExcerpt {
    <#
    .SYNOPSIS
        Kopiert die Zeilen eines CBS-/DISM-Logs aus dem Zeitfenster des Laufs (streamend, Datei bleibt offen fuer Windows).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][datetime]$Since
    )
    if (-not (Test-Path -LiteralPath $Source)) { return }
    $stream = [System.IO.File]::Open($Source, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $reader = [System.IO.StreamReader]::new($stream)
    $writer = [System.IO.StreamWriter]::new($Destination, $false, $script:Utf8Bom)
    try {
        $inWindow = $false
        $limit = $Since.AddMinutes(-1)
        while ($null -ne ($line = $reader.ReadLine())) {
            if ($line.Length -ge 19 -and $line -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') {
                $ts = [datetime]::MinValue
                if ([datetime]::TryParseExact($line.Substring(0, 19), 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$ts)) {
                    $inWindow = ($ts -ge $limit)
                }
            }
            if ($inWindow) { $writer.WriteLine($line) }
        }
    }
    finally {
        $writer.Dispose()
        $reader.Dispose()
        $stream.Dispose()
    }
}

function Export-CDTDiagnosticBundle {
    <#
    .SYNOPSIS
        Erstellt den Diagnose-Ordner (Event-Logs, CBS/DISM-Auszuege, Panther, Systeminfo, Proxy, Zustand).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $dir = Join-Path -Path $script:Cfg.LogRoot -ChildPath ('{0}_Diag_{1}' -f $env:COMPUTERNAME, $script:RunTimestamp)
    $null = New-Item -Path $dir -ItemType Directory -Force
    Write-CDTLog -Message ('Diagnose-Ordner: {0}' -f $dir)
    $info = [System.Collections.Generic.List[string]]::new()
    try {
        $os = Get-CDTOsInfo
        $info.Add(('Zeitpunkt      : {0}' -f (Get-Date).ToString('o')))
        $info.Add(('Script         : {0} {1}, Mode {2}' -f $script:ScriptBaseName, $script:ScriptVersion, $script:Cfg.Mode))
        $info.Add(('OS             : {0} | Build {1} | {2} | Edition {3}' -f $os.ProductName, $os.BuildUbr, $os.DisplayVersion, $os.EditionId))
        $ctx = Get-CDTExecutionContext
        $info.Add(('Kontext        : {0} ({1}), PS {2}' -f $ctx.User, $ctx.Sid, $ctx.PSVersion))
        $info.Add(('Pending Reboot : {0}' -f (@((Get-CDTPendingReboot).Reasons) -join ', ')))
        foreach ($f in @(Get-CDTWuPolicyFinding)) { $info.Add(('Policy         : {0}\{1} = {2} (Blocker={3})' -f $f.Path, $f.Name, $f.Value, $f.Blocking)) }
        $proxy = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\netsh.exe') -ArgumentList @('winhttp', 'show', 'proxy') -NoLog
        $info.Add('netsh winhttp show proxy:')
        $info.Add($proxy.StdOut.Trim())
        try {
            $ls = Get-CDTLanguageState
            $info.Add(('Sprachpaket    : {0} {1}' -f $ls.LanguagePackName, $ls.LanguagePackState))
            foreach ($c in @($ls.Capabilities)) { $info.Add(('Capability     : {0} = {1}' -f $c.Name, $c.State)) }
        }
        catch { $info.Add(('Sprachstatus   : Fehler {0}' -f $_.Exception.Message)) }
    }
    catch { $info.Add(('Systeminfo unvollstaendig: {0}' -f $_.Exception.Message)) }
    [System.IO.File]::WriteAllText((Join-Path -Path $dir -ChildPath 'SystemInfo.txt'), (Get-CDTMaskedText -Text ($info -join [Environment]::NewLine)), $script:Utf8Bom)

    $reg = Join-Path -Path $env:SystemRoot -ChildPath 'System32\reg.exe'
    $null = Invoke-CDTNativeCommand -FilePath $reg -ArgumentList @('export', 'HKLM\SOFTWARE\CDT', (Join-Path -Path $dir -ChildPath 'CDT-State.reg'), '/y') -NoLog

    try {
        $startUtc = $script:RunStart.ToUniversalTime().AddMinutes(-5).ToString('yyyy-MM-ddTHH:mm:ss.000Z')
        $available = @(Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | Where-Object { $_.RecordCount -gt 0 } | ForEach-Object { $_.LogName })
        $wanted = @('System', 'Application', 'Setup') + @($available | Where-Object { $_ -match '(?i)(International|LanguagePack|Language|MUI|WindowsUpdateClient|AppXDeployment|AppxPackaging|Servicing|Bits-Client)' })
        $wevtutil = Join-Path -Path $env:SystemRoot -ChildPath 'System32\wevtutil.exe'
        foreach ($logName in @($wanted | Select-Object -Unique)) {
            if ($available -notcontains $logName) { continue }
            $file = Join-Path -Path $dir -ChildPath ('EventLog_{0}.evtx' -f ($logName -replace '[\\/:*?"<>| ]', '_'))
            $null = Invoke-CDTNativeCommand -FilePath $wevtutil -ArgumentList @('epl', $logName, $file, ("/q:*[System[TimeCreated[@SystemTime>='{0}']]]" -f $startUtc), '/ow:true') -NoLog -TimeoutSeconds 600
        }
    }
    catch { Write-CDTLog -Level WARN -Message ('Event-Log-Export: {0}' -f $_.Exception.Message) }

    foreach ($pair in @(
            @((Join-Path -Path $env:SystemRoot -ChildPath 'Logs\CBS\CBS.log'), 'CBS_Auszug.log'),
            @((Join-Path -Path $env:SystemRoot -ChildPath 'Logs\DISM\dism.log'), 'DISM_Auszug.log'))) {
        try { Export-CDTLogExcerpt -Source $pair[0] -Destination (Join-Path -Path $dir -ChildPath $pair[1]) -Since $script:RunStart }
        catch { Write-CDTLog -Level WARN -Message ('Log-Auszug {0}: {1}' -f $pair[0], $_.Exception.Message) }
    }
    foreach ($p in @('System32\Sysprep\Panther\setupact.log', 'System32\Sysprep\Panther\setuperr.log', 'Panther\setupact.log', 'Panther\setuperr.log')) {
        $full = Join-Path -Path $env:SystemRoot -ChildPath $p
        if (Test-Path -LiteralPath $full) { Copy-Item -LiteralPath $full -Destination (Join-Path -Path $dir -ChildPath ('Panther_' + ($p -replace '[\\]', '_'))) -Force -ErrorAction SilentlyContinue }
    }
    if ($script:Cfg.CollectWindowsUpdateLog) {
        try { Get-WindowsUpdateLog -LogPath (Join-Path -Path $dir -ChildPath 'WindowsUpdate.log') | Out-Null }
        catch { Write-CDTLog -Level WARN -Message ('Get-WindowsUpdateLog: {0}' -f $_.Exception.Message) }
    }
    foreach ($f in @($script:LogFile, $script:ErrorLogFile, $script:ComplianceFile, $script:DismLogFile)) {
        if ($f -and (Test-Path -LiteralPath $f)) { Copy-Item -LiteralPath $f -Destination $dir -Force -ErrorAction SilentlyContinue }
    }
    return $dir
}

function Clear-CDTOldDiagnosticFolder {
    <#
    .SYNOPSIS
        Log-Rotation: Diagnose-Ordner aelter als LogRetentionDays entfernen.
    #>
    [CmdletBinding()]
    param()
    if (-not (Test-Path -LiteralPath $script:Cfg.LogRoot)) { return }
    $limit = (Get-Date).AddDays(-$script:Cfg.LogRetentionDays)
    foreach ($d in @(Get-ChildItem -LiteralPath $script:Cfg.LogRoot -Directory -Filter '*_Diag_*' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $limit })) {
        try { Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction Stop; Write-CDTLog -Message ('Alter Diagnose-Ordner entfernt: {0}' -f $d.Name) }
        catch { Write-CDTLog -Level WARN -Message ('Diagnose-Ordner {0}: {1}' -f $d.Name, $_.Exception.Message) }
    }
}

function Export-CDTCompliance {
    <#
    .SYNOPSIS
        Schreibt die Compliance-Checkliste als CSV (Semikolon, UTF-8 mit BOM) und ins Log.
    #>
    [CmdletBinding()]
    param([AllowEmptyCollection()][object[]]$Row = @())
    foreach ($r in $Row) {
        $lvl = 'INFO'
        if ($r.Ergebnis -eq 'FAIL' -and $r.Pflicht -eq 'MUSS') { $lvl = 'ERROR' } elseif ($r.Ergebnis -eq 'FAIL' -or $r.Ergebnis -eq 'WARN') { $lvl = 'WARN' }
        Write-CDTLog -Level $lvl -Message ('{0} [{1}/{2}] {3} | Soll: {4} | Ist: {5}' -f $r.ID, $r.Pflicht, $r.Ergebnis, $r.Empfehlung, $r.Soll, $r.Ist)
    }
    if ($script:ComplianceFile) {
        $Row | Select-Object -Property ID, Empfehlung, Quelle, Soll, @{ Name = 'Ist'; Expression = { Get-CDTMaskedText -Text $_.Ist } }, Ergebnis, Pflicht |
            Export-Csv -LiteralPath $script:ComplianceFile -Delimiter ';' -NoTypeInformation -Encoding UTF8
    }
}

function Write-CDTSummary {
    <#
    .SYNOPSIS
        Kurze Zusammenfassung nach STDOUT (Konsole von Nerdio/HYDRA) und ins Log.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [AllowEmptyString()][string]$NextAction = '',
        [AllowNull()][object]$RebootPlan = $null
    )
    $openMust = @($script:ComplianceRows | Where-Object { $_.Pflicht -eq 'MUSS' -and $_.Ergebnis -eq 'FAIL' } | ForEach-Object { '{0} ({1})' -f $_.ID, $_.Empfehlung })
    $warnRows = @($script:ComplianceRows | Where-Object { $_.Ergebnis -eq 'WARN' } | ForEach-Object { $_.ID })
    $os = $null
    try { $os = Get-CDTOsInfo } catch { $os = $null }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('==================== CDT Sprachpaket - Zusammenfassung ====================')
    $lines.Add(('Status          : {0} (ExitCode {1})' -f $Status, $ExitCode))
    $lines.Add(('Mode / Aktion   : {0}{1}' -f $script:Cfg.Mode, $(if ($script:AutoAction) { ' -> ' + $script:AutoAction } else { '' })))
    $lines.Add(('Sprache         : {0}, GeoID {1}, Zeitzone {2}, Tastatur {3}' -f $script:Cfg.Language, $script:Cfg.GeoId, $script:Cfg.TimeZone, $script:Cfg.InputLocale))
    if ($null -ne $os) { $lines.Add(('OS              : Build {0} ({1}, {2})' -f $os.BuildUbr, $os.DisplayVersion, $os.EditionId)) }
    $source = $script:InstallSourceDetail
    if (-not $source) { try { $source = [string](Get-CDTState -Name 'InstallSourceDetail' -Default '') } catch { $source = '' } }
    $lines.Add(('Quelle          : {0}' -f $(if ($source) { $source } else { '-' })))
    $lines.Add(('Dauer           : {0:N1} min' -f ((Get-Date) - $script:RunStart).TotalMinutes))
    $lines.Add(('Offene MUSS     : {0}' -f $(if ($openMust.Count -gt 0) { $openMust -join '; ' } else { 'keine' })))
    $lines.Add(('Warnungen       : {0}' -f $(if ($warnRows.Count -gt 0) { $warnRows -join ', ' } else { 'keine' })))
    if ($null -ne $RebootPlan) { $lines.Add(('Neustart        : {0}' -f $RebootPlan.Reason)) }
    $lines.Add(('Naechste Aktion : {0}' -f $NextAction))
    $lines.Add('Pipeline        : Install -> Reboot -> ReapplyLcu -> Reboot -> Apps -> PreSysprep -> Sysprep/Capture')
    $lines.Add(('Log             : {0}' -f $script:LogFile))
    $lines.Add('============================================================================')
    foreach ($l in $lines) {
        Write-CDTLog -Level DEBUG -Message $l
        Write-Output (Get-CDTMaskedText -Text $l)
    }
}

function Invoke-CDTDelayedReboot {
    <#
    .SYNOPSIS
        Plant einen verzoegerten, erzwungenen Neustart (shutdown.exe /r /f /t), damit Exit-Code und Logs vorher zurueckgegeben werden.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Reason)
    $comment = ('CDT Sprachpaket {0}: {1}' -f $script:Cfg.Language, $Reason)
    if ($comment.Length -gt 500) { $comment = $comment.Substring(0, 500) }
    $r = Invoke-CDTNativeCommand -FilePath (Join-Path -Path $env:SystemRoot -ChildPath 'System32\shutdown.exe') -ArgumentList @('/r', '/f', '/t', [string]$script:Cfg.RebootDelaySeconds, '/d', 'p:4:2', '/c', $comment)
    if ($r.ExitCode -ne 0) { Write-CDTLog -Level ERROR -Message ('shutdown.exe fehlgeschlagen ({0}): {1}' -f $r.ExitCode, $r.StdErr.Trim()) }
}
#endregion

#region Phasen
function Invoke-CDTPhaseInstall {
    <#
    .SYNOPSIS
        Phase Install: Cleanup-Blocker, Sprachpaket + FoDs (Quellen-Kette), Laendereinstellungen, Zeitzone.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Base)
    Enter-CDTPhase 'Install'
    $suspended = @()
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $pending = Get-CDTPendingReboot
        if ($pending.Blocking) {
            Write-CDTLog -Level WARN -Message ('Ausstehender Neustart blockiert Servicing ({0}) - erst neu starten.' -f (@($pending.Reasons) -join ', '))
            Add-CDTStatus -Status 'SUCCESS_REBOOT_REQUIRED'
            return
        }
        Invoke-CDTStep -StepName 'Cleanup-Blocker (MS-01..MS-05)' -Action { Enable-CDTLanguageCleanupBlocker }
        # Schleifenschutz: Install darf nicht endlos "Neustart erforderlich" melden
        $runCount = [int](Get-CDTState -Name 'InstallRunCount' -Default 0) + 1
        Save-CDTState -Name 'InstallRunCount' -Value $runCount -Type DWord

        $langState = Get-CDTLanguageState -Refresh
        $needWinRe = $script:Cfg.IncludeWinRELanguage -and ([int](Get-CDTState -Name 'WinReLanguageAdded' -Default 0) -ne 1)
        if ($langState.LanguagePackPresent -and -not (Get-CDTState -Name 'InstallTimestamp')) {
            Write-CDTLog -Level WARN -Message 'Sprachpaket war bereits vorhanden, Installationszeitpunkt unbekannt - LCU-Reapply wird vorsorglich gefordert (MS-08).'
            Save-CDTState -Name 'InstallSource' -Value 'Vorhanden'
            Save-CDTState -Name 'InstallTimestamp' -Value (Get-Date).ToString('o')
            Save-CDTState -Name 'OsBuildAtInstall' -Value (Get-CDTOsInfo).BuildUbr
            Save-CDTState -Name 'LcuReapplyRequired' -Value 1 -Type DWord
        }
        if (-not $langState.Complete -or $needWinRe) {
            if ($Base.BaseBuild -le 0) { Write-CDTLog -Level WARN -Message 'Servicing-Basis unbekannt: nur Stufe 1 moeglich.' }
            $suspended = Suspend-CDTLanguageInstallerTask
            $langDone = Invoke-CDTSourceChain -LanguageState $langState -BaseBuild $Base.BaseBuild -NeedWinRE $needWinRe
            if (-not $langDone) {
                if ($script:BudgetExhausted) {
                    Write-CDTLog -Level WARN -Message 'Installation unvollstaendig (Laufzeitbudget). Naechster Lauf setzt fort.'
                    Add-CDTStatus -Status 'PARTIAL'
                }
                else {
                    Write-CDTLog -Level ERROR -Message 'Alle Quellen (Stufe 1/2/3) fehlgeschlagen.'
                    Add-CDTStatus -Status 'FAILED'
                }
            }
        }
        else { Write-CDTLog -Message 'Sprachpaket und Pflicht-FoDs bereits vollstaendig.' }

        if ($script:LanguageChanged) {
            $stages = ($script:InstallStagesUsed | Select-Object -Unique) -join '+'
            if (-not $stages) { $stages = [string](Get-CDTState -Name 'InstallSource' -Default '') }
            Save-CDTState -Name 'InstallSource' -Value $stages
            Save-CDTState -Name 'InstallSourceDetail' -Value (Get-CDTMaskedText -Text $script:InstallSourceDetail)
            Save-CDTState -Name 'InstallTimestamp' -Value (Get-Date).ToString('o')
            Save-CDTState -Name 'InstallDurationSeconds' -Value ([int]$watch.Elapsed.TotalSeconds) -Type DWord
            Save-CDTState -Name 'OsBuildAtInstall' -Value (Get-CDTOsInfo).BuildUbr
            Save-CDTState -Name 'LcuReapplyRequired' -Value 1 -Type DWord
            Clear-CDTState -Name 'LcuReapplyResult'
            Write-CDTLog -Level WARN -Message 'Sprachkomponenten geaendert: LCU muss erneut installiert werden (MS-08, Mode ReapplyLcu).'
        }

        $langState = Get-CDTLanguageState -Refresh
        $intlIncomplete = $true
        if ($langState.LanguagePackPresent) {
            if (Test-CDTInternationalNeeded) {
                try {
                    $intl = Invoke-CDTStep -StepName 'Laendereinstellungen' -Action { Invoke-CDTInternationalConfiguration }
                    $intlIncomplete = -not ($intl.Welcome.Ok -and $intl.DefaultUser.Ok)
                }
                catch {
                    Write-CDTErrorRecord -ErrorRecord $_ -Context 'Laendereinstellungen'
                    if ($langState.PendingReboot) { Write-CDTLog -Level WARN -Message 'Sprachpaket wartet auf Neustart - Einstellungen werden im naechsten Lauf erneut gesetzt.'; $script:RestartNeeded = $true }
                    else { Add-CDTStatus -Status 'PARTIAL' }
                }
            }
            else {
                $intlIncomplete = $false
                Write-CDTLog -Message 'Laendereinstellungen entsprechen bereits dem Soll.'
            }
        }
        else { Write-CDTLog -Level WARN -Message 'Sprachpaket fehlt - Laendereinstellungen uebersprungen.' }
        Invoke-CDTStep -StepName 'Zeitzone' -Action { Invoke-CDTTimeZoneConfiguration }
        if ($script:Cfg.RestrictUserLanguageInstall -and $langState.Complete) {
            Write-CDTRegistryValue -Path $script:RestrictPolicy.Path -Name $script:RestrictPolicy.Name -Value 1 -Type DWord
            Save-CDTState -Name 'RestrictSetByScript' -Value 1 -Type DWord
            Write-CDTLog -Message 'MS-13: RestrictLanguagePacksAndFeaturesInstall = 1 gesetzt.'
        }
        if ($langState.PendingReboot) { $script:RestartNeeded = $true }
        if ($langState.Complete -and -not $intlIncomplete) {
            Save-CDTState -Name 'InstallRunCount' -Value 0 -Type DWord
        }
        elseif ($runCount -ge 3) {
            Write-CDTLog -Level ERROR -Message ('Install nach {0} Laeufen weiterhin unvollstaendig - Schleifenschutz, bitte Diagnose pruefen.' -f $runCount)
            Add-CDTStatus -Status 'PARTIAL'
        }
    }
    catch {
        Write-CDTErrorRecord -ErrorRecord $_ -Context 'Phase Install'
        Add-CDTStatus -Status 'FAILED'
    }
    finally {
        if (@($suspended).Count -gt 0) { Resume-CDTLanguageInstallerTask -Task $suspended }
        Clear-CDTTempPath
    }
}

function Invoke-CDTPhaseReapplyLcu {
    <#
    .SYNOPSIS
        Phase ReapplyLcu: LCU nach Sprachinstallation erneut installieren oder neueres LCU nachweisen (MS-08).
    #>
    [CmdletBinding()]
    param()
    Enter-CDTPhase 'ReapplyLcu'
    try {
        $lcu = Get-CDTCurrentLcu
        Write-CDTLog -Message ('Installiertes LCU: {0} (Quelle {1}), Build {2}, RollupFix {3}' -f $lcu.Kb, $lcu.KbSource, $lcu.BuildUbr, $lcu.RollupFixVersion)
        $required = [int](Get-CDTState -Name 'LcuReapplyRequired' -Default 0)
        if ($required -ne 1) { Write-CDTLog -Message 'LCU-Reapply nicht erforderlich (LcuReapplyRequired = 0).'; return }
        $atInstall = [string](Get-CDTState -Name 'OsBuildAtInstall' -Default '')
        if (Test-CDTNewerUbr -Current $lcu.BuildUbr -Reference $atInstall) {
            Save-CDTState -Name 'LcuReapplyRequired' -Value 0 -Type DWord
            Save-CDTState -Name 'LcuReapplyResult' -Value ('NewerLcuInstalled:{0}' -f $lcu.Kb)
            Save-CDTState -Name 'LcuReappliedTimestamp' -Value (Get-Date).ToString('o')
            Save-CDTState -Name 'LcuReappliedBuild' -Value $lcu.BuildUbr
            Write-CDTLog -Message ('MS-08 erfuellt: neueres LCU ({0}) nach der Sprachinstallation ({1}).' -f $lcu.BuildUbr, $atInstall)
            return
        }
        $pending = Get-CDTPendingReboot
        if ($pending.Blocking) {
            Write-CDTLog -Level WARN -Message ('Ausstehender Neustart blockiert Servicing ({0}).' -f (@($pending.Reasons) -join ', '))
            Add-CDTStatus -Status 'SUCCESS_REBOOT_REQUIRED'
            return
        }
        $folder = Get-CDTLcuSource
        $result = ''
        if ($folder) { $result = Install-CDTLcu -Folder $folder }
        elseif ($script:Cfg.UseWindowsUpdateForNewerLcu) { $result = Install-CDTLcuViaWindowsUpdate }
        if ($result) {
            Save-CDTState -Name 'LcuReapplyRequired' -Value 0 -Type DWord
            Save-CDTState -Name 'LcuReapplyResult' -Value $result
            Save-CDTState -Name 'LcuReappliedTimestamp' -Value (Get-Date).ToString('o')
            Save-CDTState -Name 'LcuReappliedBuild' -Value (Get-CDTOsInfo).BuildUbr
            Write-CDTLog -Message ('MS-08: LCU erneut angewendet ({0}). Neustart erforderlich.' -f $result)
            $script:RestartNeeded = $true
        }
        else {
            Write-CDTLog -Level WARN -Message ('LCU muss erneut installiert werden: {0}. Quelle fehlt (-LcuPath/-LcuUrl/-UseWindowsUpdateForNewerLcu). Catalog: {1}{0} - alle Checkpoint-MSU mit herunterladen.' -f $lcu.Kb, $script:Src.Catalog)
            Add-CDTStatus -Status 'SUCCESS_LCU_REAPPLY_PENDING'
        }
    }
    catch {
        Write-CDTErrorRecord -ErrorRecord $_ -Context 'Phase ReapplyLcu'
        Add-CDTStatus -Status 'FAILED'
    }
    finally {
        Clear-CDTTempPath
    }
}

function Invoke-CDTPhasePreSysprep {
    <#
    .SYNOPSIS
        Phase PreSysprep: optional Appx-Bereinigung, Temp-Bereinigung; Bewertung erfolgt in der Compliance.
    #>
    [CmdletBinding()]
    param()
    Enter-CDTPhase 'PreSysprep'
    try {
        if ($script:Cfg.CleanupAppxForSysprep) {
            $blockers = @(Get-CDTAppxSysprepBlocker)
            Write-CDTLog -Message ('Sysprep-Blocker (Appx): {0}' -f $blockers.Count)
            if ($blockers.Count -gt 0) { Repair-CDTAppxSysprepBlocker -Blocker $blockers }
        }
        Clear-CDTTempPath
    }
    catch {
        Write-CDTErrorRecord -ErrorRecord $_ -Context 'Phase PreSysprep'
        Add-CDTStatus -Status 'FAILED'
    }
}

function Test-CDTAwaitingReboot {
    <#
    .SYNOPSIS
        True, wenn ein vom Script angeforderter Neustart noch nicht erfolgt ist; raeumt RebootPending nach erfolgtem Neustart.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    if ([int](Get-CDTState -Name 'RebootPending' -Default 0) -ne 1) { return $false }
    $requestedAt = ConvertFrom-CDTIsoDate -Value ([string](Get-CDTState -Name 'RebootRequestedAt' -Default ''))
    if ($null -eq $requestedAt) { return $false }
    $boot = Get-CDTLastBootTime
    if ($boot -gt $requestedAt) {
        Save-CDTState -Name 'RebootPending' -Value 0 -Type DWord
        Write-CDTLog -Message ('Angeforderter Neustart erfolgt (Boot {0}).' -f $boot.ToString('o'))
        return $false
    }
    return $true
}

function Invoke-CDTModeAuto {
    <#
    .SYNOPSIS
        Mode Auto: naechste offene Phase ermitteln und genau diese ausfuehren.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Base)
    Enter-CDTPhase 'Auto/Analyse'
    $awaiting = Test-CDTAwaitingReboot
    $facts = Get-CDTComplianceFact
    $script:LastFacts = $facts
    $complete = Test-CDTInstallComplete -Fact $facts -Config $script:Cfg
    $action = Select-CDTAutoAction -AwaitingReboot $awaiting -BlockingPendingReboot ([bool]$facts.PendingReboot.Blocking) -InstallComplete $complete.Complete -LcuReapplyRequired ($facts.LcuReapplyRequired -eq 1)
    $script:AutoAction = $action
    if ($complete.Complete) { Save-CDTState -Name 'InstallRunCount' -Value 0 -Type DWord }
    Write-CDTLog -Message ('Auto-Entscheidung: {0} (Neustart offen={1}, CBS/WU blockiert={2}, Install fehlt: {3}, LcuReapplyRequired={4})' -f $action, $awaiting, $facts.PendingReboot.Blocking, $(if ($complete.Complete) { '-' } else { $complete.Missing -join ',' }), $facts.LcuReapplyRequired)
    switch ($action) {
        'WaitForReboot' { Add-CDTStatus -Status 'SUCCESS_REBOOT_REQUIRED' }
        'Install' { Invoke-CDTPhaseInstall -Base $Base }
        'ReapplyLcu' { Invoke-CDTPhaseReapplyLcu }
        default { Enter-CDTPhase 'Validate' }
    }
}

function Complete-CDTRun {
    <#
    .SYNOPSIS
        Abschluss: Compliance, Status/Exit-Code, Zustand, Diagnose, Rotation, Summary, Transcript-Ende, ggf. verzoegerter Neustart.
    #>
    [CmdletBinding()]
    param()
    Enter-CDTPhase 'Abschluss'
    $status = 'FAILED'
    $code = 3050
    $plan = $null
    try {
        $effectiveMode = $script:Cfg.Mode
        if ($effectiveMode -eq 'Auto') {
            if ($script:AutoAction -eq 'Validate') { $effectiveMode = 'Validate' } else { $effectiveMode = 'Auto' }
        }
        if ($script:Cfg.Mode -ne 'Validate') { Clear-CDTTempPath }
        $rebootPending = $script:RestartNeeded
        try {
            $facts = Get-CDTComplianceFact
            $rows = @(Get-CDTComplianceResult -Fact $facts -Config $script:Cfg)
            $script:ComplianceRows = $rows
            Export-CDTCompliance -Row $rows
            $rebootPending = $rebootPending -or [bool]$facts.PendingReboot.Blocking
            $fromCompliance = @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode $effectiveMode -RebootPending $rebootPending)
            if ($effectiveMode -eq 'Validate' -or $effectiveMode -eq 'PreSysprep') {
                foreach ($s in $fromCompliance) { Add-CDTStatus -Status $s }
            }
            else {
                foreach ($s in $fromCompliance) { if ($s -ne 'SUCCESS') { Add-CDTStatus -Status $s } }
            }
        }
        catch {
            Write-CDTErrorRecord -ErrorRecord $_ -Context 'Compliance'
            Add-CDTStatus -Status 'FAILED'
        }
        if ($rebootPending) { Add-CDTStatus -Status 'SUCCESS_REBOOT_REQUIRED' }
        $status = Resolve-CDTFinalStatus -Status $script:StatusFlags.ToArray()
        $code = Get-CDTExitCodeForStatus -Status $status -RebootRequiredExitCode $script:Cfg.RebootRequiredExitCode

        if ($script:RestartNeeded) {
            Save-CDTState -Name 'RebootPending' -Value 1 -Type DWord
            Save-CDTState -Name 'RebootRequestedAt' -Value (Get-Date).ToString('o')
        }
        Save-CDTState -Name 'ScriptVersion' -Value $script:ScriptVersion
        Save-CDTState -Name 'LastPhase' -Value $(if ($script:AutoAction) { 'Auto:' + $script:AutoAction } else { $script:Cfg.Mode })
        Save-CDTState -Name 'LastResult' -Value $status
        Save-CDTState -Name 'LastExitCode' -Value $code -Type DWord
        Save-CDTState -Name 'LastRun' -Value (Get-Date).ToString('o')

        if (@('FAILED', 'PARTIAL', 'PRESYSPREP_BLOCKED') -contains $status) {
            try { $null = Export-CDTDiagnosticBundle } catch { Write-CDTErrorRecord -ErrorRecord $_ -Context 'Diagnose-Ordner' }
        }
        try { Clear-CDTOldDiagnosticFolder } catch { Write-CDTLog -Level WARN -Message ('Rotation: {0}' -f $_.Exception.Message) }

        $plan = Get-CDTRebootDecision -Status $status -RebootRequired ($status -eq 'SUCCESS_REBOOT_REQUIRED' -or $rebootPending) -RebootIfRequired $script:Cfg.RebootIfRequired -ForceReboot $script:Cfg.ForceReboot -ForceRebootOnError $script:Cfg.ForceRebootOnError
        Write-CDTLog -Message ('Neustart-Entscheidung: {0}' -f $plan.Reason)
        if ($plan.Reboot) {
            Save-CDTState -Name 'PlannedReboot' -Value ('{0} | in {1} s | {2}' -f (Get-Date).ToString('o'), $script:Cfg.RebootDelaySeconds, $plan.Reason)
            Save-CDTState -Name 'RebootPending' -Value 1 -Type DWord
            Save-CDTState -Name 'RebootRequestedAt' -Value (Get-Date).ToString('o')
        }
        $kb = ''
        $lcuRow = @($script:ComplianceRows | Where-Object { $_.ID -eq 'MS-08' })
        if ($lcuRow.Count -gt 0) { $kb = [regex]::Match([string]$lcuRow[0].Ist, '(?i)KB\d{6,8}').Value }
        $next = Get-CDTNextAction -Status $status -EffectiveMode $effectiveMode -LcuKb $kb -RebootPlanned ([bool]$plan.Reboot)
        Write-CDTSummary -Status $status -ExitCode $code -NextAction $next -RebootPlan $plan
    }
    catch {
        Write-CDTErrorRecord -ErrorRecord $_ -Context 'Abschluss'
        $status = 'FAILED'
        $code = Get-CDTExitCodeForStatus -Status 'FAILED'
    }
    finally {
        Write-CDTLog -Message ('Ende: Status {0}, ExitCode {1}' -f $status, $code)
        Close-CDTTranscript
        if ($null -ne $plan -and $plan.Reboot) {
            Write-CDTLog -Level WARN -Message ('Neustart geplant in {0} s: {1}' -f $script:Cfg.RebootDelaySeconds, $plan.Reason)
            Invoke-CDTDelayedReboot -Reason $plan.Reason
        }
    }
    $script:FinalStatus = $status
    $script:FinalExitCode = $code
}

function Invoke-CDTMain {
    <#
    .SYNOPSIS
        Hauptablauf: Konfiguration, Logging, Vorpruefung, Phase, Abschluss.
    #>
    [CmdletBinding()]
    param()
    $mutex = $null
    $acquired = $false
    $skipCompletion = $false
    try {
        $script:Cfg = Build-CDTConfiguration
        $script:ModeName = $script:Cfg.Mode
        try { Initialize-CDTLogging } catch { Write-CDTLog -Level ERROR -Message ('Logging-Initialisierung fehlgeschlagen: {0}' -f $_.Exception.Message) }
        # Nur ein Lauf gleichzeitig (z. B. erneuter Start durch Nerdio/HYDRA waehrend ein Lauf noch aktiv ist)
        $mutex = [System.Threading.Mutex]::new($false, 'Global\CDT-LanguageDeployment')
        try { $acquired = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $acquired = $true }
        if (-not $acquired) {
            $skipCompletion = $true
            throw 'Ein anderer Lauf dieses Scripts ist aktiv - Abbruch ohne Aenderungen.'
        }
        Open-CDTTranscript
        Write-CDTLog -Message ('##### {0} v{1} | Mode {2} | Start {3} #####' -f $script:ScriptBaseName, $script:ScriptVersion, $script:Cfg.Mode, $script:RunStart.ToString('o'))
        Write-CDTLog -Message ('Parameter: Sprache={0}, GeoId={1}, TZ={2}, Tastatur={3}, Repo={4}, RepoZip={5}, Key={6}, IsoUrl={7}, IsoPath={8}, ForceIso={9}, LcuPath={10}, LcuUrl={11}, Exclude={12}, Reboot(IfRequired={13}, Force={14}, OnError={15}, Delay={16}, ExitCode={17}), Budget={18} min, SecureVars={19}' -f
            $script:Cfg.Language, $script:Cfg.GeoId, $script:Cfg.TimeZone, $script:Cfg.InputLocale, $script:Cfg.RepositoryPath, (Get-CDTUrlForLog -Url $script:Cfg.RepositoryZipUrl), $(if ($script:Cfg.StorageAccountKey) { '***' } else { '-' }),
            (Get-CDTUrlForLog -Url $script:Cfg.LofIsoUrl), $script:Cfg.IsoPath, $script:Cfg.ForceIsoSource, $script:Cfg.LcuPath, @($script:Cfg.LcuUrl).Count, (@($script:Cfg.ExcludeFeatures) -join ','),
            $script:Cfg.RebootIfRequired, $script:Cfg.ForceReboot, $script:Cfg.ForceRebootOnError, $script:Cfg.RebootDelaySeconds, $script:Cfg.RebootRequiredExitCode, $script:Cfg.MaxRuntimeMinutes, $script:Cfg.SecureVarsUsed)

        Enter-CDTPhase 'Vorpruefung'
        $consistency = Test-CDTParameterConsistency -Config $script:Cfg
        foreach ($w in $consistency.Warnings) { Write-CDTLog -Level WARN -Message $w }
        if (@($consistency.Errors).Count -gt 0) {
            foreach ($e in $consistency.Errors) { Write-CDTLog -Level ERROR -Message $e }
            throw 'Ungueltige Parameterkombination - keine Aenderungen vorgenommen.'
        }
        $pre = Test-CDTPrerequisite
        if (-not $pre.Ok) { throw 'Vorpruefung fehlgeschlagen - keine Aenderungen vorgenommen.' }
        Restore-CDTCrashLeftover

        switch ($script:Cfg.Mode) {
            'Auto' { Invoke-CDTModeAuto -Base $pre.Base }
            'Install' { Invoke-CDTPhaseInstall -Base $pre.Base }
            'ReapplyLcu' { Invoke-CDTPhaseReapplyLcu }
            'Validate' { Enter-CDTPhase 'Validate' }
            'PreSysprep' { Invoke-CDTPhasePreSysprep }
        }
    }
    catch {
        Write-CDTErrorRecord -ErrorRecord $_ -Context 'Hauptablauf'
        Add-CDTStatus -Status 'FAILED'
    }
    finally {
        if ($null -eq $script:Cfg -or $skipCompletion) {
            $script:FinalExitCode = 3050
            Write-Output ('CDT Sprachpaket: FAILED (ExitCode 3050) - siehe Log {0}' -f $script:LogFile)
        }
        else {
            Complete-CDTRun
        }
        if ($acquired) { $mutex.ReleaseMutex() }
        if ($null -ne $mutex) { $mutex.Dispose() }
    }
}
#endregion

# Einstiegspunkt. CDT_LANG_SKIP_MAIN=1 laedt nur die Funktionen (Pester-Tests).
if ($env:CDT_LANG_SKIP_MAIN -ne '1') {
    Invoke-CDTMain
    exit $script:FinalExitCode
}
