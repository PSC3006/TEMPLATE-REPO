# Pester-Tests (kompatibel mit Pester 4.10 und 5.x). Keine echten Systemaufrufe:
# Das Script wird mit CDT_LANG_SKIP_MAIN=1 nur geladen; Windows-Cmdlets werden gemockt bzw. durch Stubs ersetzt.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $here
$env:CDT_LANG_SKIP_MAIN = '1'
. (Join-Path -Path $repoRoot -ChildPath 'Install-DE_V8.ps1')
$script:ConsoleOutput = $false

# Stubs fuer Windows-only-Befehle, damit Mock sie auf jeder Plattform findet
foreach ($stubName in @('New-SmbMapping', 'Remove-SmbMapping', 'Restart-Service', 'Get-SmbMapping')) {
    if (-not (Get-Command -Name $stubName -ErrorAction SilentlyContinue)) {
        Set-Item -Path ('function:global:{0}' -f $stubName) -Value { param() }
    }
}

function Build-TestConfig {
    param([hashtable]$Override = @{})
    $p = @{} + $script:ParamSnapshot
    foreach ($k in $Override.Keys) { $p[$k] = $Override[$k] }
    return (Build-CDTConfiguration -Parameter $p)
}

function Build-TestFact {
    param([hashtable]$Override = @{})
    $f = [ordered]@{
        Tasks                      = @{ 'MS-01' = 'Disabled'; 'MS-02' = 'Disabled'; 'MS-03' = 'Disabled' }
        BlockCleanup               = 1
        AllowLangFeaturesUninstall = 0
        RestrictLanguageInstall    = $null
        Os                         = [pscustomobject]@{ Build = 26100; Ubr = 9550; BuildUbr = '26100.9550' }
        Base                       = [pscustomobject]@{ BaseBuild = 26100; Release = '24H2'; Supported = $true; Known = $true }
        LanguageState              = [pscustomobject]@{
            LanguagePackState = 'Installed'; LanguagePackName = 'x'; LanguagePackBuild = 26100; LanguagePackPresent = $true
            CapabilitiesPresent = $true; Complete = $true; PendingReboot = $false
            Capabilities = @(
                [pscustomobject]@{ Feature = 'Basic'; Name = 'Language.Basic~~~de-DE~0.0.1.0'; State = 'Installed' }
                [pscustomobject]@{ Feature = 'OCR'; Name = 'Language.OCR~~~de-DE~0.0.1.0'; State = 'Installed' }
            )
        }
        EnUsPresent                = $true
        InstallSource              = '2'
        InstallTimestamp           = '2026-10-02T10:00:00.0000000+02:00'
        LanguagePackInstalledAt    = '2026-10-02T10:00:00.0000000+02:00'
        FodInstalledAt             = '2026-10-02T10:05:00.0000000+02:00'
        LcuReapplyResult           = 'Installed:KB5124010'
        LcuReapplyKb               = 'KB5124010'
        OsBuildAtInstall           = '26100.9550'
        LcuReappliedBuild          = '26100.9550'
        PolicyBackupJson           = ''
        TempDisabledTasks          = ''
        LcuReapplyRequired         = 0
        WinReLanguageAdded         = 0
        CurrentLcuKb               = ''
        AppsBefore                 = @()
        AppxBlockers               = @()
        Leftovers                  = @()
        SystemPreferredUi          = 'de-DE'
        SystemLocale               = 'de-DE'
        WelcomeProfile             = [pscustomobject]@{ Ok = $true; Deviations = @(); LocaleName = 'de-DE'; Nation = '94' }
        DefaultUserProfile         = [pscustomobject]@{ Ok = $true; Deviations = @(); LocaleName = 'de-DE'; Nation = '94' }
        TimeZoneId                 = 'W. Europe Standard Time'
        TzAutoStart                = 4
        PendingReboot              = [pscustomobject]@{ Required = $false; Blocking = $false; Reasons = @() }
        MissingSatellites          = @()
        WuFindings                 = @()
        MuiInfo                    = 'n/a'
        Context                    = 'SYSTEM'
    }
    foreach ($k in $Override.Keys) { $f[$k] = $Override[$k] }
    return [pscustomobject]$f
}

$script:Cfg = Build-TestConfig

Describe 'Statische Pruefung' {
    $scripts = @('Install-DE_V8.ps1')
    foreach ($s in $scripts) {
        It "$s hat keine Parser-Fehler" {
            $tokens = $null; $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path -Path $repoRoot -ChildPath $s), [ref]$tokens, [ref]$errors)
            @($errors).Count | Should -Be 0
        }
        It "$s enthaelt nur ASCII (PS 5.1 ohne BOM, Nerdio-Upload)" {
            $bytes = [System.IO.File]::ReadAllBytes((Join-Path -Path $repoRoot -ChildPath $s))
            @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
        }
    }
}

Describe 'Build-Zuordnung (24H2/25H2/26H2 -> 26100)' {
    It '26100 ist 24H2 mit Basis 26100' {
        $r = Get-CDTServicingBaseBuild -CurrentBuild 26100 -PackageBuild 26100
        $r.Release | Should -Be '24H2'; $r.BaseBuild | Should -Be 26100; $r.Supported | Should -BeTrue; $r.Severity | Should -Be 'INFO'
    }
    It '26200 ist 25H2 mit Basis 26100' { (Get-CDTServicingBaseBuild -CurrentBuild 26200).BaseBuild | Should -Be 26100 }
    It '26300 ist 26H2 mit Basis 26100' { (Get-CDTServicingBaseBuild -CurrentBuild 26300).Release | Should -Be '26H2' }
    It 'Build kleiner 26100 wird abgelehnt' { (Get-CDTServicingBaseBuild -CurrentBuild 22631).Supported | Should -BeFalse }
    It 'Unbekannter Build mit Sprachpaket-Beleg -> WARN, Basis aus Paket' {
        $r = Get-CDTServicingBaseBuild -CurrentBuild 28000 -PackageBuild 28000
        $r.Severity | Should -Be 'WARN'; $r.BaseBuild | Should -Be 28000; $r.Supported | Should -BeTrue
    }
    It 'Unbekannter Build ohne Beleg -> Basis 0 (Stufe 2/3 gesperrt)' { (Get-CDTServicingBaseBuild -CurrentBuild 26500).BaseBuild | Should -Be 0 }
    It 'ISO-Build aus Default-URL' { Get-CDTIsoBuildFromName -Name ([System.Uri]$script:Cfg.LofIsoUrl).Segments[-1] | Should -Be 26100 }
    It 'ISO-Build aus Pfad' { Get-CDTIsoBuildFromName -Name 'D:\ISO\26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso' | Should -Be 26100 }
    It 'Umbenanntes ISO -> 0' { Get-CDTIsoBuildFromName -Name 'LOF.iso' | Should -Be 0 }
}

Describe 'Parameter und Konfiguration' {
    It 'Defaults sind konsistent' {
        $c = Build-TestConfig
        @((Test-CDTParameterConsistency -Config $c).Errors).Count | Should -Be 0
        $c.Mode | Should -Be 'Auto'; $c.GeoId | Should -Be 94; $c.InputLocale | Should -Be '0407:00000407'
    }
    It '-RebootIfRequired und -ForceReboot schliessen sich aus' {
        $c = Build-TestConfig -Override @{ RebootIfRequired = $true; ForceReboot = $true }
        @((Test-CDTParameterConsistency -Config $c).Errors) -join ' ' | Should -Match 'schliessen sich'
    }
    It 'TextToSpeech abwaehlen ohne Speech ist ein Fehler' {
        $c = Build-TestConfig -Override @{ ExcludeFeatures = @('TextToSpeech') }
        @((Test-CDTParameterConsistency -Config $c).Errors).Count | Should -Be 1
    }
    It 'Speech und TextToSpeech gemeinsam abwaehlen ist erlaubt' {
        $c = Build-TestConfig -Override @{ ExcludeFeatures = @('TextToSpeech', 'Speech') }
        @((Test-CDTParameterConsistency -Config $c).Errors).Count | Should -Be 0
    }
    It 'HTTP-URL wird abgelehnt' {
        $c = Build-TestConfig -Override @{ RepositoryZipUrl = 'http://x/y.zip' }
        @((Test-CDTParameterConsistency -Config $c).Errors) -join ' ' | Should -Match 'HTTPS'
    }
    It 'RebootRequiredExitCode darf nicht mit Status-Codes kollidieren' {
        $c = Build-TestConfig -Override @{ RebootRequiredExitCode = 3030 }
        @((Test-CDTParameterConsistency -Config $c).Errors).Count | Should -Be 1
    }
    It 'LogRoot innerhalb TempPath wird abgelehnt' {
        $c = Build-TestConfig -Override @{ TempPath = 'C:\Install\CDTtmp'; LogRoot = 'C:\Install\CDTtmp\Logs' }
        @((Test-CDTParameterConsistency -Config $c).Errors) -join ' ' | Should -Match 'LogRoot'
    }
    It 'Unsichere TempPath-Werte' {
        Test-CDTSafeTempPath -Path 'C:\' | Should -BeFalse
        Test-CDTSafeTempPath -Path 'C:\Windows\Temp\x' | Should -BeFalse
        Test-CDTSafeTempPath -Path 'C:\Users\Public\x' | Should -BeFalse
        Test-CDTSafeTempPath -Path 'C:\Data' | Should -BeFalse
        Test-CDTSafeTempPath -Path '\\srv\share\tmp' | Should -BeFalse
        Test-CDTSafeTempPath -Path 'C:\Install\..\Windows' | Should -BeFalse
    }
    It 'Sichere TempPath-Werte' {
        Test-CDTSafeTempPath -Path 'C:\Install\CDT-STANDARD-Install_DE-Language_tmp' | Should -BeTrue
        Test-CDTSafeTempPath -Path 'D:\CDTtmp' | Should -BeTrue
    }
    It 'Nerdio Secure Variables fuellen leere Parameter, ueberschreiben aber keine gesetzten' {
        $c = Build-TestConfig -Override @{ RepositoryPath = '\\explizit\share'; SecureVars = @{ CDTLangStorageAccountKey = 'GeheimerKey=='; CDTLangRepositoryPath = '\\sv\share'; CDTLangLcuUrl = 'https://a/kb1.msu;https://b/kb2.msu' } }
        $c.StorageAccountKey | Should -Be 'GeheimerKey=='
        $c.RepositoryPath | Should -Be '\\explizit\share'
        @($c.LcuUrl).Count | Should -Be 2
        $c.SecureVarsUsed | Should -BeTrue
    }
    It 'LcuUrl als einzelner String mit Trennzeichen wird aufgeteilt' {
        $c = Build-TestConfig -Override @{ LcuUrl = @('https://a/1.msu, https://b/2.msu') }
        @($c.LcuUrl).Count | Should -Be 2
    }
}

Describe 'Secret-Maskierung' {
    It 'Registrierter Key wird maskiert' {
        Add-CDTSecret -Value 'SuperGeheim123=='
        Get-CDTMaskedText -Text 'net use x SuperGeheim123== /user:y' | Should -Not -Match 'SuperGeheim123'
    }
    It 'SAS-Parameter werden maskiert, auch unregistriert' {
        $t = Get-CDTMaskedText -Text 'https://acc.blob.core.windows.net/c/r.zip?sv=2022-11-02&se=2026&sp=r&sig=ABCdef%2B123'
        $t | Should -Not -Match 'ABCdef'
        $t | Should -Match 'sig=\*\*\*'
    }
    It 'URL fuer Log ohne Query' { Get-CDTUrlForLog -Url 'https://x/y.zip?sig=1' | Should -Be 'https://x/y.zip?***' }
}

Describe 'Language-FoDs' {
    It 'Default: Basic, OCR, Handwriting, TextToSpeech, Speech in Abhaengigkeitsreihenfolge' {
        $caps = @(Get-CDTRequiredCapability -Language 'de-DE')
        ($caps | ForEach-Object { $_.Feature }) -join ',' | Should -Be 'Basic,OCR,Handwriting,TextToSpeech,Speech'
        $caps[0].Name | Should -Be 'Language.Basic~~~de-DE~0.0.1.0'
    }
    It 'de-DE hat keine Font-FoD, ja-JP schon' {
        @(Get-CDTRequiredCapability -Language 'de-DE' | Where-Object { $_.Feature -eq 'Fonts' }).Count | Should -Be 0
        @(Get-CDTRequiredCapability -Language 'ja-JP' | Where-Object { $_.Feature -eq 'Fonts' }).Count | Should -Be 1
    }
    It 'Abwahl wirkt, Basic bleibt' {
        $caps = @(Get-CDTRequiredCapability -Language 'de-DE' -ExcludeFeatures @('OCR', 'Handwriting'))
        ($caps | ForEach-Object { $_.Feature }) -join ',' | Should -Be 'Basic,TextToSpeech,Speech'
    }
}

Describe 'Status, Exit-Codes, Neustart' {
    It 'Rangfolge der Status' {
        Resolve-CDTFinalStatus -Status @('SUCCESS', 'SUCCESS_LCU_REAPPLY_PENDING', 'SUCCESS_REBOOT_REQUIRED') | Should -Be 'SUCCESS_REBOOT_REQUIRED'
        Resolve-CDTFinalStatus -Status @('SUCCESS_REBOOT_REQUIRED', 'PARTIAL') | Should -Be 'PARTIAL'
        Resolve-CDTFinalStatus -Status @('PRESYSPREP_BLOCKED', 'FAILED') | Should -Be 'FAILED'
        Resolve-CDTFinalStatus -Status @() | Should -Be 'SUCCESS'
    }
    It 'Exit-Codes' {
        Get-CDTExitCodeForStatus -Status 'SUCCESS' | Should -Be 0
        Get-CDTExitCodeForStatus -Status 'SUCCESS_REBOOT_REQUIRED' -RebootRequiredExitCode 3010 | Should -Be 3010
        Get-CDTExitCodeForStatus -Status 'SUCCESS_REBOOT_REQUIRED' -RebootRequiredExitCode 0 | Should -Be 0
        Get-CDTExitCodeForStatus -Status 'SUCCESS_LCU_REAPPLY_PENDING' | Should -Be 3020
        Get-CDTExitCodeForStatus -Status 'PARTIAL' | Should -Be 3030
        Get-CDTExitCodeForStatus -Status 'PRESYSPREP_BLOCKED' | Should -Be 3040
        Get-CDTExitCodeForStatus -Status 'FAILED' | Should -Be 3050
    }
    It 'ForceReboot startet nicht bei FAILED ohne ForceRebootOnError' {
        (Get-CDTRebootDecision -Status 'FAILED' -ForceReboot $true).Reboot | Should -BeFalse
        (Get-CDTRebootDecision -Status 'FAILED' -ForceReboot $true -ForceRebootOnError $true).Reboot | Should -BeTrue
        (Get-CDTRebootDecision -Status 'SUCCESS' -ForceReboot $true).Reboot | Should -BeTrue
    }
    It 'RebootIfRequired startet nur bei ausstehendem Neustart' {
        (Get-CDTRebootDecision -Status 'SUCCESS' -RebootIfRequired $true -RebootRequired $false).Reboot | Should -BeFalse
        (Get-CDTRebootDecision -Status 'SUCCESS_REBOOT_REQUIRED' -RebootIfRequired $true -RebootRequired $true).Reboot | Should -BeTrue
    }
    It 'Default: kein Neustart' { (Get-CDTRebootDecision -Status 'SUCCESS_REBOOT_REQUIRED' -RebootRequired $true).Reboot | Should -BeFalse }
    It 'Naechste Aktion bei LCU nennt die KB' { Get-CDTNextAction -Status 'SUCCESS_LCU_REAPPLY_PENDING' -EffectiveMode 'Auto' -LcuKb 'KB5124010' | Should -Match 'KB5124010' }
}

Describe 'Mode Auto - Entscheidung' {
    It 'Wartet auf Neustart' { Select-CDTAutoAction -AwaitingReboot $true -InstallComplete $true | Should -Be 'WaitForReboot' }
    It 'CBS/WU-Neustart blockiert' { Select-CDTAutoAction -BlockingPendingReboot $true | Should -Be 'WaitForReboot' }
    It 'Install zuerst' { Select-CDTAutoAction -InstallComplete $false -LcuReapplyRequired $true | Should -Be 'Install' }
    It 'Dann ReapplyLcu' { Select-CDTAutoAction -InstallComplete $true -LcuReapplyRequired $true | Should -Be 'ReapplyLcu' }
    It 'Dann Validate' { Select-CDTAutoAction -InstallComplete $true | Should -Be 'Validate' }
    It 'Test-CDTInstallComplete erkennt fehlende Teile' {
        $f = Build-TestFact -Override @{ SystemLocale = 'en-US'; TzAutoStart = 3 }
        $r = Test-CDTInstallComplete -Fact $f -Config (Build-TestConfig)
        $r.Complete | Should -BeFalse
        $r.Missing | Should -Contain 'SystemLocale'
        $r.Missing | Should -Contain 'tzautoupdate'
    }
    It 'Test-CDTInstallComplete: vollstaendig' { (Test-CDTInstallComplete -Fact (Build-TestFact) -Config (Build-TestConfig)).Complete | Should -BeTrue }
    It 'Invoke-CDTModeAuto ruft bei unvollstaendiger Installation die Phase Install' {
        Mock Test-CDTAwaitingReboot { $false }
        Mock Get-CDTComplianceFact { Build-TestFact -Override @{ SystemLocale = 'en-US' } }
        Mock Save-CDTState { }
        Mock Invoke-CDTPhaseInstall { }
        Mock Invoke-CDTPhaseReapplyLcu { }
        Invoke-CDTModeAuto -Base ([pscustomobject]@{ BaseBuild = 26100 })
        Assert-MockCalled -CommandName Invoke-CDTPhaseInstall -Scope It -Times 1 -Exactly
        Assert-MockCalled -CommandName Invoke-CDTPhaseReapplyLcu -Scope It -Times 0 -Exactly
    }
    It 'Invoke-CDTModeAuto ruft nach vollstaendiger Installation ReapplyLcu' {
        Mock Test-CDTAwaitingReboot { $false }
        Mock Get-CDTComplianceFact { Build-TestFact -Override @{ LcuReapplyRequired = 1 } }
        Mock Save-CDTState { }
        Mock Invoke-CDTPhaseInstall { }
        Mock Invoke-CDTPhaseReapplyLcu { }
        Invoke-CDTModeAuto -Base ([pscustomobject]@{ BaseBuild = 26100 })
        Assert-MockCalled -CommandName Invoke-CDTPhaseReapplyLcu -Scope It -Times 1 -Exactly
        Assert-MockCalled -CommandName Invoke-CDTPhaseInstall -Scope It -Times 0 -Exactly
    }
}

Describe 'Compliance-Bewertung (MS-01 bis MS-16, ZUS)' {
    It 'Alle MUSS-Punkte erfuellt -> SUCCESS, auch PreSysprep' {
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact) -Config (Build-TestConfig))
        @($rows | Where-Object { $_.Pflicht -eq 'MUSS' -and $_.Ergebnis -eq 'FAIL' }).Count | Should -Be 0
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'PreSysprep') | Should -Be @('SUCCESS')
    }
    It 'Liefert MS-01 bis MS-16 und ZUS-01 bis ZUS-15' {
        $ids = @(Get-CDTComplianceResult -Fact (Build-TestFact) -Config (Build-TestConfig) | ForEach-Object { $_.ID })
        foreach ($n in 1..16) { $ids | Should -Contain ('MS-{0:D2}' -f $n) }
        foreach ($n in 1..15) { $ids | Should -Contain ('ZUS-{0:D2}' -f $n) }
    }
    It 'LCU offen: MS-08 FAIL mit KB, Validate -> LCU_PENDING, PreSysprep -> BLOCKED' {
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact -Override @{ LcuReapplyRequired = 1; CurrentLcuKb = 'KB5124010' }) -Config (Build-TestConfig))
        $ms08 = $rows | Where-Object { $_.ID -eq 'MS-08' }
        $ms08.Ergebnis | Should -Be 'FAIL'
        $ms08.Ist | Should -Match 'KB5124010'
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'Validate') | Should -Contain 'SUCCESS_LCU_REAPPLY_PENDING'
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'PreSysprep') | Should -Be @('PRESYSPREP_BLOCKED')
    }
    It 'LCU nicht anwendbar (0x800F081E) -> MS-08 WARN, blockiert nicht' {
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact -Override @{ LcuReapplyResult = 'NotApplicable:KB5124010' }) -Config (Build-TestConfig))
        ($rows | Where-Object { $_.ID -eq 'MS-08' }).Ergebnis | Should -Be 'WARN'
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'PreSysprep') | Should -Be @('SUCCESS')
    }
    It 'Appx-Blocker: MS-10 FAIL blockiert nur PreSysprep' {
        $blk = @([pscustomobject]@{ Name = 'Microsoft.LanguageExperiencePackde-DE'; Reason = 'NotProvisioned' })
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact -Override @{ AppxBlockers = $blk }) -Config (Build-TestConfig))
        ($rows | Where-Object { $_.ID -eq 'MS-10' }).Ergebnis | Should -Be 'FAIL'
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'PreSysprep') | Should -Be @('PRESYSPREP_BLOCKED')
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'Validate') | Should -Be @('SUCCESS')
    }
    It 'Ausstehender CBS-Neustart -> ZUS-10 FAIL -> REBOOT_REQUIRED' {
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact -Override @{ PendingReboot = [pscustomobject]@{ Required = $true; Blocking = $true; Reasons = @('CBS:RebootPending') } }) -Config (Build-TestConfig))
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'Validate') | Should -Contain 'SUCCESS_REBOOT_REQUIRED'
    }
    It 'Nur PendingFileRenameOperations -> ZUS-10 WARN' {
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact -Override @{ PendingReboot = [pscustomobject]@{ Required = $true; Blocking = $false; Reasons = @('PendingFileRenameOperations') } }) -Config (Build-TestConfig))
        ($rows | Where-Object { $_.ID -eq 'ZUS-10' }).Ergebnis | Should -Be 'WARN'
    }
    It 'Default-User falsch -> PARTIAL (ohne Neustart) bzw. REBOOT (mit Neustart)' {
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact -Override @{ DefaultUserProfile = [pscustomobject]@{ Ok = $false; Deviations = @('Preload1=00000409') } }) -Config (Build-TestConfig))
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'Validate') | Should -Contain 'PARTIAL'
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'Auto' -RebootPending $true) | Should -Contain 'SUCCESS_REBOOT_REQUIRED'
    }
    It 'MS-07: Reihenfolge verletzt -> FAIL' {
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact -Override @{ FodInstalledAt = '2026-10-02T09:00:00.0000000+02:00' }) -Config (Build-TestConfig))
        ($rows | Where-Object { $_.ID -eq 'MS-07' }).Ergebnis | Should -Be 'FAIL'
    }
    It 'MS-06: Sprachpaket-Build passt nicht -> FAIL' {
        $ls = (Build-TestFact).LanguageState
        $ls.LanguagePackBuild = 22621
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact -Override @{ LanguageState = $ls }) -Config (Build-TestConfig))
        ($rows | Where-Object { $_.ID -eq 'MS-06' }).Ergebnis | Should -Be 'FAIL'
    }
    It 'MS-13/MS-14 nur bei Anforderung als KANN bewertet' {
        $rows = @(Get-CDTComplianceResult -Fact (Build-TestFact) -Config (Build-TestConfig -Override @{ RestrictUserLanguageInstall = $true }))
        $ms13 = $rows | Where-Object { $_.ID -eq 'MS-13' }
        $ms13.Pflicht | Should -Be 'KANN'; $ms13.Ergebnis | Should -Be 'FAIL'
        @(Get-CDTStatusFromCompliance -Row $rows -EffectiveMode 'PreSysprep') | Should -Be @('SUCCESS')
    }
}

Describe 'Repository-Manifest' {
    BeforeEach {
        $script:repoDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('cdt-test-' + [guid]::NewGuid())
        $null = New-Item -Path $script:repoDir -ItemType Directory
        $lp = Join-Path -Path $script:repoDir -ChildPath 'Microsoft-Windows-Client-Language-Pack_x64_de-de.cab'
        $fod = Join-Path -Path $script:repoDir -ChildPath 'Microsoft-Windows-LanguageFeatures-Basic-de-de-Package~31bf3856ad364e35~amd64~~.cab'
        Set-Content -LiteralPath $lp -Value 'lp' -NoNewline
        Set-Content -LiteralPath $fod -Value 'fod' -NoNewline
        $script:writeManifest = {
            param([string]$Build = '26100', [string]$Lang = 'de-DE', [string]$BadHashFor = '', [string[]]$ExtraPath = @())
            $files = foreach ($f in Get-ChildItem -LiteralPath $script:repoDir -File | Where-Object { $_.Name -ne 'manifest.json' }) {
                $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
                if ($f.Name -eq $BadHashFor) { $h = '00' * 32 }
                [ordered]@{ path = $f.Name; size = $f.Length; sha256 = $h }
            }
            $files = @($files) + @($ExtraPath | ForEach-Object { [ordered]@{ path = $_; size = 1; sha256 = '00' } })
            $m = [ordered]@{ schemaVersion = 1; osBaseBuild = $Build; language = $Lang; sourceIso = @{ name = 'x.iso' }; createdUtc = 'now'; files = @($files) }
            Set-Content -LiteralPath (Join-Path -Path $script:repoDir -ChildPath 'manifest.json') -Value (ConvertTo-Json -InputObject $m -Depth 5)
        }
    }
    AfterEach { Remove-Item -LiteralPath $script:repoDir -Recurse -Force -ErrorAction SilentlyContinue }

    It 'Gueltiges Manifest' {
        & $script:writeManifest
        $r = Test-CDTRepositoryManifest -Path $script:repoDir -ExpectedBaseBuild 26100 -Language 'de-DE'
        $r.Valid | Should -BeTrue
        $r.FileCount | Should -Be 2
    }
    It 'Falscher Hauptbuild wird verworfen (MS-06)' {
        & $script:writeManifest -Build '22621'
        $r = Test-CDTRepositoryManifest -Path $script:repoDir -ExpectedBaseBuild 26100 -Language 'de-DE'
        $r.Valid | Should -BeFalse
        ($r.Errors -join ' ') | Should -Match 'Hauptbuild'
    }
    It 'Hash-Abweichung wird verworfen' {
        & $script:writeManifest -BadHashFor 'Microsoft-Windows-Client-Language-Pack_x64_de-de.cab'
        (Test-CDTRepositoryManifest -Path $script:repoDir -ExpectedBaseBuild 26100 -Language 'de-DE').Valid | Should -BeFalse
    }
    It 'Fehlendes Sprachpaket wird verworfen' {
        Remove-Item -LiteralPath (Join-Path -Path $script:repoDir -ChildPath 'Microsoft-Windows-Client-Language-Pack_x64_de-de.cab')
        & $script:writeManifest
        ((Test-CDTRepositoryManifest -Path $script:repoDir -ExpectedBaseBuild 26100 -Language 'de-DE').Errors -join ' ') | Should -Match 'Sprachpaket'
    }
    It 'Pfad-Traversal im Manifest wird verworfen' {
        & $script:writeManifest -ExtraPath @('..\evil.cab')
        ((Test-CDTRepositoryManifest -Path $script:repoDir -ExpectedBaseBuild 26100 -Language 'de-DE').Errors -join ' ') | Should -Match 'Ungueltiger Dateipfad'
    }
    It 'Unbekannte OS-Basis wird verworfen' {
        & $script:writeManifest
        (Test-CDTRepositoryManifest -Path $script:repoDir -ExpectedBaseBuild 0 -Language 'de-DE').Valid | Should -BeFalse
    }
    It 'Resolve-CDTRepositoryFolder waehlt die neueste Version' {
        $root = Join-Path -Path $script:repoDir -ChildPath 'root'
        foreach ($v in @('de-DE_2026-08-01', 'de-DE_2026-10-02', 'de-DE_2026-09-15')) {
            $d = Join-Path -Path (Join-Path -Path $root -ChildPath '26100') -ChildPath $v
            $null = New-Item -Path $d -ItemType Directory -Force
            Set-Content -LiteralPath (Join-Path -Path $d -ChildPath 'manifest.json') -Value '{}'
        }
        Split-Path -Path (Resolve-CDTRepositoryFolder -Root $root -Language 'de-DE' -BaseBuild 26100) -Leaf | Should -Be 'de-DE_2026-10-02'
    }
}

Describe 'LCU (MS-08, Checkpoint-CUs)' {
    It 'Ziel-MSU ist die hoechste KB' {
        $r = Get-CDTLcuTargetMsu -FileName @('windows11.0-kb5043080-x64_abc.msu', 'windows11.0-kb5124010-x64_def.msu')
        $r.Target.Kb | Should -Be 5124010
        @($r.Checkpoints).Count | Should -Be 1
        @($r.Errors).Count | Should -Be 0
    }
    It 'Fremddateien im LCU-Ordner sind ein Fehler' {
        @((Get-CDTLcuTargetMsu -FileName @('windows11.0-kb5124010-x64.msu', 'readme.txt')).Errors).Count | Should -Be 1
    }
    It 'MSU ohne KB ist ein Fehler' { @((Get-CDTLcuTargetMsu -FileName @('update.msu')).Errors).Count | Should -BeGreaterThan 0 }
    It 'Neueres LCU anhand UBR (gemeinsamer Branch)' {
        Test-CDTNewerUbr -Current '26200.9600' -Reference '26100.9550' | Should -BeTrue
        Test-CDTNewerUbr -Current '26100.9550' -Reference '26100.9550' | Should -BeFalse
        Test-CDTNewerUbr -Current '26100.9550' -Reference '' | Should -BeFalse
    }
}

Describe 'Satelliten-Pruefung' {
    It 'Erkennt fehlenden de-DE-Satelliten' {
        $pkgs = @(
            'Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~~10.0.26100.1'
            'Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~en-US~10.0.26100.1'
            'Microsoft-Windows-Notepad-System-FoD-Package~31bf3856ad364e35~amd64~~10.0.26100.1'
            'Microsoft-Windows-Notepad-System-FoD-Package~31bf3856ad364e35~amd64~en-US~10.0.26100.1'
            'Microsoft-Windows-Notepad-System-FoD-Package~31bf3856ad364e35~amd64~de-DE~10.0.26100.1'
            'Microsoft-Windows-Client-LanguagePack-Package~31bf3856ad364e35~amd64~en-US~10.0.26100.1'
        )
        $m = @(Get-CDTMissingSatellite -PackageName $pkgs -Language 'de-DE')
        $m.Count | Should -Be 1
        $m[0] | Should -Match 'PowerShell-ISE'
    }
}

Describe 'Hilfsfunktionen' {
    It 'Argument-Quoting' {
        ConvertTo-CDTArgumentString -ArgumentList @('use', '\\h\s', 'a b', '/user:x') | Should -Be 'use \\h\s "a b" /user:x'
        ConvertTo-CDTArgumentString -ArgumentList @('/q:*[System[TimeCreated[@SystemTime>=''x'']]]') | Should -Be '/q:*[System[TimeCreated[@SystemTime>=''x'']]]'
        ConvertTo-CDTArgumentString -ArgumentList @('C:\Pfad mit Leer\') | Should -Be '"C:\Pfad mit Leer\\"'
    }
    It 'Fehlercodes aus Install-Language-Text' {
        (Get-CDTErrorInfo -Text 'Failed to install language. ErrorCode: -2147418113. Please try again.').HResult | Should -Be '0x8000FFFF'
        (Get-CDTErrorInfo -Text 'Error: 0x800f0954').Explanation | Should -Match 'WSUS'
    }
    It 'ISO-Datum robust' {
        ConvertFrom-CDTIsoDate -Value 'kein Datum' | Should -BeNullOrEmpty
        (ConvertFrom-CDTIsoDate -Value '2026-10-02T10:00:00.0000000+02:00').Year | Should -Be 2026
    }
    It 'UNC-Zerlegung' {
        $s = Get-CDTUncShareRoot -UncPath '\\stcdt.file.core.windows.net\langrepo\26100\de-DE_2026-10-02'
        $s.HostName | Should -Be 'stcdt.file.core.windows.net'
        $s.Root | Should -Be '\\stcdt.file.core.windows.net\langrepo'
    }
}

Describe 'Freigaben (Mocks)' {
    if ([string]::IsNullOrEmpty($env:SystemRoot)) { $env:SystemRoot = [System.IO.Path]::GetTempPath() }
    It 'Fallback auf net use, wenn New-SmbMapping scheitert; Key erscheint nicht im Log' {
        Mock Test-CDTTcpPort { $true }
        Mock Save-CDTState { }
        Mock New-SmbMapping { throw 'nicht unterstuetzt' }
        Mock Invoke-CDTNativeCommand { [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' } }
        Mock Test-Path { $true }
        Mock Write-CDTLog { }
        Add-CDTSecret -Value 'KEY-ABC-123=='
        $c = Connect-CDTShare -UncPath '\\stcdt.file.core.windows.net\langrepo\26100' -AccountKey 'KEY-ABC-123=='
        $c.Method | Should -Be 'NetUse'
        Assert-MockCalled -CommandName Invoke-CDTNativeCommand -Scope It -ParameterFilter { $ArgumentList -contains '/persistent:no' } -Times 1 -Exactly
        Assert-MockCalled -CommandName Write-CDTLog -Scope It -ParameterFilter { $Message -match 'KEY-ABC-123' } -Times 0 -Exactly
    }
    It 'Trennen entfernt Mapping, net use und cmdkey-Eintraege' {
        Mock Remove-SmbMapping { }
        Mock Invoke-CDTNativeCommand { [pscustomobject]@{ ExitCode = 0; StdOut = '    Target: Domain:target=stcdt.file.core.windows.net'; StdErr = '' } }
        Mock Write-CDTLog { }
        Disconnect-CDTShare -Connection ([pscustomobject]@{ Root = '\\stcdt.file.core.windows.net\langrepo'; HostName = 'stcdt.file.core.windows.net'; Method = 'SmbMapping' })
        Assert-MockCalled -CommandName Remove-SmbMapping -Scope It -Times 1 -Exactly
        Assert-MockCalled -CommandName Invoke-CDTNativeCommand -Scope It -ParameterFilter { $ArgumentList -contains '/delete' } -Times 1 -Exactly
        Assert-MockCalled -CommandName Invoke-CDTNativeCommand -Scope It -ParameterFilter { @($ArgumentList | Where-Object { $_ -like '/delete:*' }).Count -eq 1 } -Times 1 -Exactly
    }
}

Describe 'Policy-Rollback (Mocks)' {
    It 'Stellt gesicherte Policies wieder her und loescht das Backup' {
        $json = ConvertTo-Json -Compress -InputObject @(
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'UseWUServer'; Kind = 'DWord'; Value = 1 }
            [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DisableWindowsUpdateAccess'; Kind = 'DWord'; Value = 1 }
        )
        Mock Get-CDTState { $json } -ParameterFilter { $Name -eq 'PolicyBackupJson' }
        Mock Write-CDTRegistryValue { }
        Mock Clear-CDTState { }
        Mock Restart-Service { }
        Mock Write-CDTLog { }
        Restore-CDTWuPolicyBypass
        Assert-MockCalled -CommandName Write-CDTRegistryValue -Scope It -Times 2 -Exactly
        Assert-MockCalled -CommandName Write-CDTRegistryValue -Scope It -ParameterFilter { $Name -eq 'UseWUServer' -and $Value -eq 1 -and $Type -eq 'DWord' } -Times 1 -Exactly
        Assert-MockCalled -CommandName Clear-CDTState -Scope It -ParameterFilter { $Name -eq 'PolicyBackupJson' } -Times 1 -Exactly
    }
    It 'Einzelner Eintrag (PS 5.1 JSON-Array) wird korrekt aufgezaehlt' {
        $json = ConvertTo-Json -Compress -InputObject @([pscustomobject]@{ Path = 'HKLM:\X'; Name = 'UseWUServer'; Kind = 'DWord'; Value = 1 })
        Mock Get-CDTState { $json } -ParameterFilter { $Name -eq 'PolicyBackupJson' }
        Mock Write-CDTRegistryValue { }
        Mock Clear-CDTState { }
        Mock Restart-Service { }
        Mock Write-CDTLog { }
        Restore-CDTWuPolicyBypass
        Assert-MockCalled -CommandName Write-CDTRegistryValue -Scope It -ParameterFilter { $Name -eq 'UseWUServer' } -Times 1 -Exactly
    }
}

Describe 'Mode CreateRepository (integriert)' {
    It 'Versionsordner <Sprache>_<yyyy-MM-dd>, bei Kollision mit Uhrzeit' {
        $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('cdt-repo-' + [guid]::NewGuid())
        $null = New-Item -Path $tmp -ItemType Directory
        try {
            $d = [datetime]'2026-10-02T14:05:00'
            Get-CDTRepositoryVersionFolderName -BuildFolder $tmp -TargetLanguage 'de-DE' -Date $d | Should -Be 'de-DE_2026-10-02'
            $null = New-Item -Path (Join-Path -Path $tmp -ChildPath 'de-DE_2026-10-02') -ItemType Directory
            Get-CDTRepositoryVersionFolderName -BuildFolder $tmp -TargetLanguage 'de-DE' -Date $d | Should -Be 'de-DE_2026-10-02_1405'
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
    It 'Roundtrip: erzeugtes manifest.json wird von Stufe 2 akzeptiert' {
        $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('cdt-rt-' + [guid]::NewGuid())
        $null = New-Item -Path $tmp -ItemType Directory
        try {
            Set-Content -LiteralPath (Join-Path -Path $tmp -ChildPath 'Microsoft-Windows-Client-Language-Pack_x64_de-de.cab') -Value 'lp' -NoNewline
            Set-Content -LiteralPath (Join-Path -Path $tmp -ChildPath 'Microsoft-Windows-LanguageFeatures-Basic-de-de-Package~31bf3856ad364e35~amd64~~.cab') -Value 'basic' -NoNewline
            $meta = [ordered]@{ schemaVersion = 1; osBaseBuild = '26100'; language = 'de-DE'; sourceIso = [ordered]@{ name = 'x.iso'; sha256 = 'AA' }; createdUtc = '2026-10-02T12:00:00Z' }
            $null = Export-CDTRepositoryManifest -Path $tmp -Metadata $meta
            $r = Test-CDTRepositoryManifest -Path $tmp -ExpectedBaseBuild 26100 -Language 'de-DE'
            $r.Valid | Should -BeTrue
            $r.FileCount | Should -Be 2
            @($r.Warnings).Count | Should -Be 0
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
    It 'Export-Pruefung erkennt fehlende Language-FoD-Cabs' {
        $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('cdt-ex-' + [guid]::NewGuid())
        $null = New-Item -Path $tmp -ItemType Directory
        try {
            Mock Write-CDTLog { }
            Set-Content -LiteralPath (Join-Path -Path $tmp -ChildPath 'Microsoft-Windows-LanguageFeatures-Basic-de-de-Package~31bf3856ad364e35~amd64~~.cab') -Value 'x'
            $caps = @(Get-CDTRequiredCapability -Language 'de-DE' -ExcludeFeatures @('OCR', 'Handwriting', 'Speech', 'TextToSpeech'))
            Test-CDTRepositoryExport -Stage $tmp -Capability $caps | Should -BeTrue
            Test-CDTRepositoryExport -Stage $tmp -Capability @(Get-CDTRequiredCapability -Language 'de-DE') | Should -BeFalse
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
    It 'CreateRepository ohne RepositoryPath ist ein Fehler' {
        $c = Build-TestConfig -Override @{ Mode = 'CreateRepository' }
        @((Test-CDTParameterConsistency -Config $c).Errors) -join ' ' | Should -Match 'RepositoryPath'
    }
    It 'Export Image ohne RepositoryImagePath ist ein Fehler' {
        $c = Build-TestConfig -Override @{ Mode = 'CreateRepository'; RepositoryPath = 'D:\LangRepo'; RepositoryExportMethod = 'Image' }
        @((Test-CDTParameterConsistency -Config $c).Errors) -join ' ' | Should -Match 'RepositoryImagePath'
    }
    It 'IsoPath innerhalb TempPath ist ein Fehler' {
        $c = Build-TestConfig -Override @{ IsoPath = 'C:\Install\CDT-STANDARD-Install_DE-Language_tmp\lof.iso' }
        @((Test-CDTParameterConsistency -Config $c).Errors) -join ' ' | Should -Match 'IsoPath'
    }
    It 'Upload-SAS wird als Secret registriert und maskiert' {
        $null = Build-TestConfig -Override @{ Mode = 'CreateRepository'; RepositoryPath = 'D:\LangRepo'; RepositoryUploadSasUrl = 'https://acc.blob.core.windows.net/c?sv=1&sp=w&sig=UPLOADGEHEIM' }
        Get-CDTMaskedText -Text 'x https://acc.blob.core.windows.net/c?sv=1&sp=w&sig=UPLOADGEHEIM y' | Should -Not -Match 'UPLOADGEHEIM'
    }
}

Describe 'Mode ExitCodeTest (integriert)' {
    It 'Setzt den Exit-Code ohne Systemaenderung' {
        Mock Write-CDTLog { }
        $script:Cfg = Build-TestConfig -Override @{ Mode = 'ExitCodeTest'; TestExitCode = 3010 }
        $null = Invoke-CDTModeExitCodeTest
        $script:FinalExitCode | Should -Be 3010
        $script:Cfg = Build-TestConfig
    }
}

Describe 'Vorpruefung und OS-Anzeige (8.0.1, Mocks)' {
    It 'Windows 11 statt Registry-ProductName "Windows 10" ab Build 22000' {
        Mock -CommandName Get-CDTRegistryValue -MockWith {
            switch ($Name) {
                'CurrentBuildNumber' { '26300' }
                'UBR' { 9457 }
                'ProductName' { 'Windows 10 Enterprise multi-session' }
                default { '' }
            }
        }
        (Get-CDTOsInfo).ProductName | Should -Be 'Windows 11 Enterprise multi-session'
    }
    It 'Aelterer Build behaelt den Registry-ProductName' {
        Mock -CommandName Get-CDTRegistryValue -MockWith {
            switch ($Name) {
                'CurrentBuildNumber' { '19045' }
                'ProductName' { 'Windows 10 Enterprise' }
                default { 0 }
            }
        }
        (Get-CDTOsInfo).ProductName | Should -Be 'Windows 10 Enterprise'
    }
    It 'Ohne Adminrechte: Ok=False, keine Paketabfrage (Elevation) und kein SYSTEM-Hinweis' {
        Mock -CommandName Get-CDTExecutionContext -MockWith {
            [pscustomobject]@{ User = 'AzureAD\Test'; Sid = 'S-1-12-1'; IsAdmin = $false; IsSystem = $false; Is64BitProcess = $true; PSVersion = '5.1'; PSEdition = 'Desktop' }
        }
        Mock -CommandName Get-CDTOsInfo -MockWith {
            [pscustomobject]@{ Build = 26300; Ubr = 9457; BuildUbr = '26300.9457'; DisplayVersion = '26H2'; EditionId = 'ServerRdsh'; ProductName = 'Windows 11 Enterprise multi-session'; InstallationType = 'Client' }
        }
        Mock -CommandName Get-CDTInstalledLanguagePackBuild -MockWith { 26100 }
        Mock -CommandName Get-Module -MockWith { [pscustomobject]@{ Name = 'x' } }
        Mock -CommandName Write-CDTLog -MockWith { }
        $savedDrive = $env:SystemDrive
        if ([string]::IsNullOrEmpty($env:SystemDrive)) { $env:SystemDrive = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetTempPath()) }
        try { $r = Test-CDTPrerequisite } finally { $env:SystemDrive = $savedDrive }
        $r.Ok | Should -Be $false
        Assert-MockCalled -CommandName Get-CDTInstalledLanguagePackBuild -Times 0 -Exactly -Scope It
        Assert-MockCalled -CommandName Write-CDTLog -Times 0 -Exactly -Scope It -ParameterFilter { $Message -like 'Nicht im SYSTEM-Kontext*' }
        Assert-MockCalled -CommandName Write-CDTLog -Times 1 -Exactly -Scope It -ParameterFilter { $Level -eq 'ERROR' -and $Message -like 'Administratorrechte*' }
    }
}
