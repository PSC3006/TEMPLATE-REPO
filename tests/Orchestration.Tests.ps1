# Ablaufsimulation (Mocks fuer Windows-Cmdlets): Auto/Apply/Verify, Fallback, Freigaben, Neustart, Schleifenschutz.
# Simuliert wird ein Master; geprueft werden Entscheidungen, Status, Exitcodes und Fortsetzungszustand.
BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/TestHelpers.ps1')
    $libPath = Join-Path $TestDrive 'cdt-lib.ps1'
    [System.IO.File]::WriteAllText($libPath, (Get-CdtLibraryText))
    . $libPath
    $ErrorActionPreference = 'Stop'
    $Cdt = @{}
    $CdtSecretValues = New-Object 'System.Collections.Generic.List[string]'
    $CdtEarlyLog = New-Object 'System.Collections.Generic.List[object]'

    function New-SimHive([bool]$Ok, [string]$Name) {
        $lang = 'en-US'; $geo = '244'; $kbd = '00000409'; $fmt = [ordered]@{ sShortDate = 'M/d/yyyy'; sShortTime = 'h:mm tt'; sTimeFormat = 'h:mm:ss tt'; iTime = '0'; sDecimal = '.'; sThousand = ',' }
        if ($Ok) { $lang = 'de-DE'; $geo = '94'; $kbd = '00000407'; $fmt = [ordered]@{ sShortDate = 'dd.MM.yyyy'; sShortTime = 'HH:mm'; sTimeFormat = 'HH:mm:ss'; iTime = '1'; sDecimal = ','; sThousand = '.' } }
        return [ordered]@{ HiveName = $Name; Available = $true; Error = $null; LocaleName = $lang; Formats = $fmt; GeoNation = $geo; Languages = @($lang)
            LanguageInputMethods = @($(if ($Ok) { '0407:00000407' } else { '0409:00000409' })); InputMethodOverride = $null; PreloadFirst = $kbd; PreferredUILanguages = @($lang); PreferredUILanguagesPending = @() }
    }
    function New-SimSnapshot([bool]$Ok) {
        $lang = 'en-US'; if ($Ok) { $lang = 'de-DE' }
        return [ordered]@{
            TimestampUtc = 'x'
            System = [ordered]@{ SystemPreferredUILanguage = $lang; SystemLocale = $lang; SystemLocaleRegistry = $(if ($Ok) { '00000407' } else { '00000409' }); CodePages = [ordered]@{ ACP = '1252'; OEMCP = '850'; MACCP = '10000'; Utf8Active = $false }
                TimeZoneId = $(if ($Ok) { 'W. Europe Standard Time' } else { 'UTC' }); DynamicDaylightTimeDisabled = 0; MuiRegistered = $Ok; BlockCleanupPolicy = $(if ($Ok) { 1 } else { $null }); TimeZoneRedirectionPolicy = $null }
            Source = (New-SimHive $Ok '.DEFAULT')
            SourceCmdlets = [ordered]@{ LanguageTags = @($lang); FirstInputTips = @($(if ($Ok) { '0407:00000407' } else { '0409:00000409' })); UiLanguageOverride = $(if ($Ok) { 'de-DE' } else { '' }); InputMethodOverride = $(if ($Ok) { '0407:00000407' } else { '' }); HomeLocation = $(if ($Ok) { 94 } else { 244 }) }
            Welcome = (New-SimHive $Ok '.DEFAULT'); LocalService = $null; NetworkService = $null; NewUser = (New-SimHive $Ok 'CDT_DELANG_DEFUSER'); Errors = @()
        }
    }
    function Reset-Sim([string]$Build = '26200') {
        $script:Sim = @{ Build = [int]$Build; Boot = '2026-10-03T08:00:00Z'; LP = 'NotPresent'; Caps = @{ Basic = 'NotPresent'; OCR = 'NotPresent'; TextToSpeech = 'NotPresent'; Handwriting = 'NotPresent'; Speech = 'NotPresent' }
            CbsPending = $false; ConfigApplied = $false; Jobs = (New-Object System.Collections.ArrayList); WuLanguageResult = 'Pending'; WuCapResult = 'Installed'; WuError = $null; FallbackSource = $true; Policy = 'Allowed' }
    }
    function Invoke-SimReboot {
        $Sim.Boot = ([datetime]::Parse($Sim.Boot).ToUniversalTime().AddMinutes(10)).ToString('yyyy-MM-ddTHH:mm:ssZ')
        if ($Sim.LP -eq 'InstallPending') { $Sim.LP = 'Installed' }
        foreach ($k in @($Sim.Caps.Keys)) { if ($Sim.Caps[$k] -eq 'InstallPending') { $Sim.Caps[$k] = 'Installed' } }
        $Sim.CbsPending = $false
    }
    function Invoke-SimRun([string]$Mode = 'Auto', [hashtable]$Config = @{}) {
        $cfg = @{ Mode = $Mode; RetryDelaySeconds = 0 }
        foreach ($k in $Config.Keys) { $cfg[$k] = $Config[$k] }
        New-TestCdtContext -Root $script:SimRoot -Config $cfg
        Invoke-CdtRunBody
        Complete-CdtRun
        return [pscustomobject]@{ Status = $Cdt.Status; ExitCode = $Cdt.ExitCode; Capture = $Cdt.CaptureAllowed; Verification = $Cdt.IsVerificationRun; Reason = $Cdt.StatusReason; Install = $Cdt.Install }
    }
}

Describe 'Ablaufsimulation' {
    BeforeEach {
        Reset-Sim
        $script:SimRoot = Join-Path $TestDrive ('sim-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
        Mock Get-CdtPlatformInfo {
            $rel = Resolve-CdtRelease -Build $Sim.Build -DisplayVersion $null -ReleaseMap $CdtReleaseMap
            [ordered]@{ Caption = 'Microsoft Windows 11 Enterprise multi-session'; EditionId = 'ServerRdsh'; Sku = 175; DisplayVersion = $rel.Release; Build = $Sim.Build; Ubr = 6584; Architecture = 'AMD64'
                ProductType = 3; InstallationType = 'Client'; IsClient = $true; IsWindows11 = $true; ReleaseInfo = $rel; EditionClass = (Get-CdtEditionClass -EditionId 'ServerRdsh' -Sku 175 -ProductType 3 -InstallationType 'Client')
                LastBootUtc = $Sim.Boot; SmbiosUuid = 'UUID-SIM'; InstallDateUtc = 'x'; InstallLanguageLcid = '0409'; InstallLanguageTag = 'en-US'; Errors = @() }
        }
        Mock Get-CdtExecutionContext { [ordered]@{ Identity = 'NT AUTHORITY\SYSTEM'; Sid = 'S-1-5-18'; IsSystem = $true; IsAdmin = $true; SourceHiveName = '.DEFAULT'; OrchestratorHint = 'Test'; PSVersion = '5.1'; PSEdition = 'Desktop'; Is64BitProcess = $true; LanguageMode = 'FullLanguage' } }
        Mock Test-CdtPrerequisites { [ordered]@{ Ok = $true; Fatal = @(); Warnings = @(); Commands = @{} } }
        Mock Get-CdtUpdateSourcePolicy { [ordered]@{ Decision = $Sim.Policy; Reasons = @('Simulation'); WsusConfigured = $false; ServicingRepairContentSource = $null; ServicingLocalSourcePath = '' } }
        Mock Get-CdtCodePageState { [ordered]@{ ACP = '1252'; OEMCP = '850'; MACCP = '10000'; Utf8Active = $false } }
        Mock Get-CdtComponentState {
            $caps = [ordered]@{}
            foreach ($f in $CdtKnownCapabilities) { $caps[$f] = [ordered]@{ Name = (Get-CdtCapabilityName -Feature $f -Language 'de-DE'); Feature = $f; State = $Sim.Caps[$f] } }
            $il = 'None'; if (@('Installed', 'InstallPending') -contains $Sim.LP) { $il = 'LpCab' }
            $cbs = $Sim.LP; if ($cbs -eq 'Inconsistent') { $cbs = 'Staged' }
            [ordered]@{ TimestampUtc = 'x'; LanguagePack = [ordered]@{ State = $Sim.LP; CbsState = $cbs; PackageName = 'Microsoft-Windows-Client-LanguagePack-Package~31bf3856ad364e35~amd64~de-DE~10.0.26100.1'; InstalledLanguagePacks = $il; InstalledLanguageFeatures = ''; MuiRegistered = ($Sim.LP -eq 'Installed'); IsBaseLanguage = $false }
                Capabilities = $caps; Pending = [ordered]@{ CbsRebootPending = $Sim.CbsPending; CbsPackagesPending = $false; WuRebootRequired = $false; PendingFileRenameEntries = 0; Any = $Sim.CbsPending }; Errors = @() }
        }
        Mock Get-CdtSettingsSnapshot { New-SimSnapshot $Sim.ConfigApplied }
        Mock Invoke-CdtConfiguration { $Sim.ConfigApplied = $true; Add-CdtBootChange -Item 'CopyToSystem'; return , @([ordered]@{ Name = 'CopyToSystem'; Status = 'Applied' }) }
        Mock Invoke-CdtNetworkCheck { [pscustomobject]@{ Results = @(); RequiredFailed = 0; AllRequiredFailedAtTransport = $false } }
        Mock Get-CdtServicingLogExcerpt { @{} }
        Mock Suspend-CdtLanguageComponentTask { }
        Mock Resume-CdtLanguageComponentTask { }
        Mock Get-CdtSysprepAppxRisk { [ordered]@{ Checked = $true; LanguageRelated = @(); Other = @(); Error = $null } }
        Mock Get-CdtLanguageResourceState { [ordered]@{ State = 'Current'; Compared = 100; Behind = 0; Examples = @(); ReferenceLanguage = 'en-US'; Note = '' } }
        Mock Find-CdtFallbackSource { if ($Sim.FallbackSource) { return , @([ordered]@{ Kind = 'Repository'; Path = '\\fs\lof'; Origin = 'Test'; Owned = $false }) } else { return , @() } }
        Mock Test-CdtRepository { [ordered]@{ Valid = $true; Root = '\\fs\lof\LanguagesAndOptionalFeatures'; LanguagePackCab = 'lp.cab'; CapabilityCabs = @{}; Missing = @(); Issues = @(); Signature = $null; Applicable = $true } }
        Mock Mount-CdtIso { [ordered]@{ Ok = $false } }
        Mock Dismount-CdtIso { $true }
        Mock Save-CdtIsoDownload { [ordered]@{ Ok = $false; Error = 'Simulation: kein Download'; Category = 'Test' } }
        Mock Invoke-CdtServicingJob {
            [void]$Sim.Jobs.Add(('{0}:{1}' -f $SourceLabel, $Operation))
            $ok = $true; $code = $null
            switch ($Operation) {
                'InstallLanguage' {
                    if ($null -ne $Sim.WuError) { $ok = $false; $code = $Sim.WuError }
                    elseif ($Sim.WuLanguageResult -eq 'Pending') { $Sim.LP = 'InstallPending'; $Sim.CbsPending = $true }
                }
                'AddCapabilityOnline' { if ($null -ne $Sim.WuError) { $ok = $false; $code = $Sim.WuError } else { $Sim.Caps[($CapabilityName -replace '^Language\.([^~]+)~.*$', '$1')] = $Sim.WuCapResult } }
                'AddPackage' { $Sim.LP = 'InstallPending'; $Sim.CbsPending = $true }
                'AddCapabilitySource' { $Sim.Caps[($CapabilityName -replace '^Language\.([^~]+)~.*$', '$1')] = 'Installed' }
            }
            $cls = $null; if (-not $ok) { $cls = Get-CdtErrorClassification -Code $code }
            [pscustomobject]@{ Operation = $Operation; Source = $SourceLabel; Attempt = $Attempt; Ok = $ok; TimedOut = $false; RestartNeeded = $false; HResult = $null; Code = $code; Message = 'sim'; Classification = $cls; DurationMs = 5; StartLocal = (Get-Date) }
        }
    }

    It 'Auto: Apply mit Neustartbedarf (Exit 0), nach Neustart Nachpruefung SUCCESS (Exit 0, Capture frei)' {
        $r1 = Invoke-SimRun
        $r1.Status | Should -Be 'REBOOT_REQUIRED'
        $r1.ExitCode | Should -Be 0
        $r1.Capture | Should -BeFalse
        @($Sim.Jobs) | Should -Contain 'WindowsUpdate:InstallLanguage'
        @($Sim.Jobs | Where-Object { $_ -like 'Fallback:*' }).Count | Should -Be 0
        Invoke-SimReboot
        $r2 = Invoke-SimRun
        $r2.Verification | Should -BeTrue
        $r2.Status | Should -Be 'SUCCESS'
        $r2.ExitCode | Should -Be 0
        $r2.Capture | Should -BeTrue
        (Read-CdtState).pendingVerification | Should -BeNullOrEmpty
        # Fehlerfreie Laeufe: kein Error-Log, keine Netzwerkdatei; Full-Log (.json) enthaelt beide Laeufe
        Test-Path -LiteralPath $Cdt.Log.ErrorText | Should -BeFalse
        Test-Path -LiteralPath $Cdt.Log.ErrorJson | Should -BeFalse
        Test-Path -LiteralPath $Cdt.Log.MissingCsv | Should -BeFalse
        @([System.IO.File]::ReadAllText($Cdt.Log.Json) | ConvertFrom-Json | ForEach-Object { $_.runId } | Select-Object -Unique).Count | Should -Be 2
    }

    It 'Auto: Wiederholter Lauf im selben Boot aendert nichts und meldet weiter REBOOT_REQUIRED (Exit 0)' {
        [void](Invoke-SimRun)
        $Sim.Jobs.Clear()
        $r = Invoke-SimRun
        $r.Status | Should -Be 'REBOOT_REQUIRED'
        $r.ExitCode | Should -Be 0
        $Sim.Jobs.Count | Should -Be 0
    }

    It 'Auto: Nachpruefung mit weiterhin ausstehendem Neustart liefert Exit 3 (Capture stoppen)' {
        [void](Invoke-SimRun)
        $Sim.Boot = '2026-10-03T09:00:00Z'
        $r = Invoke-SimRun
        $r.Verification | Should -BeTrue
        $r.Status | Should -Be 'REBOOT_REQUIRED'
        $r.ExitCode | Should -Be 3
    }

    It 'Fallback, wenn Windows Update ohne Fehler endet, der Zustand aber unvollstaendig ist' {
        $Sim.WuLanguageResult = 'NoChange'
        $r = Invoke-SimRun
        @($Sim.Jobs) | Should -Contain 'Fallback:AddPackage'
        $r.Status | Should -Be 'REBOOT_REQUIRED'
        [System.IO.File]::ReadAllText($Cdt.Log.Text) | Should -Match 'Install-Language ohne Fehler, Sprachpaket aber nicht installiert'
    }

    It 'Fallback bei nicht voruebergehendem WU-Fehler ohne Wiederholung (0x800F0954)' {
        $Sim.WuError = '0x800F0954'
        $r = Invoke-SimRun
        @($Sim.Jobs | Where-Object { $_ -eq 'WindowsUpdate:InstallLanguage' }).Count | Should -Be 1
        @($Sim.Jobs) | Should -Contain 'Fallback:AddPackage'
        @($Sim.Jobs) | Should -Contain 'Fallback:AddCapabilitySource'
        $r.Status | Should -Be 'REBOOT_REQUIRED'
    }

    It 'Begrenzte Wiederholung bei voruebergehendem Fehler (0x80072EE2), danach Fallback' {
        $Sim.WuError = '0x80072EE2'
        [void](Invoke-SimRun)
        @($Sim.Jobs | Where-Object { $_ -eq 'WindowsUpdate:InstallLanguage' }).Count | Should -Be 2
        @($Sim.Jobs) | Should -Contain 'Fallback:AddPackage'
    }

    It 'Teilerfolg: nur fehlende Komponenten werden im Fallback nachinstalliert' {
        $Sim.WuCapResult = 'NotPresent'
        [void](Invoke-SimRun)
        @($Sim.Jobs) | Should -Not -Contain 'Fallback:AddPackage'
        @($Sim.Jobs | Where-Object { $_ -eq 'Fallback:AddCapabilitySource' }).Count | Should -Be 3
    }

    It '26H2: kein Fallback ohne Herstellerfreigabe -> FAILED (Exit 1), keine Konfiguration' {
        Reset-Sim -Build '26300'
        $Sim.WuError = '0x800F0954'
        $r = Invoke-SimRun
        $r.Status | Should -Be 'FAILED'
        $r.ExitCode | Should -Be 1
        @($Sim.Jobs | Where-Object { $_ -like 'Fallback:*' }).Count | Should -Be 0
        $Sim.ConfigApplied | Should -BeFalse
        [System.IO.File]::ReadAllText($Cdt.Log.Text) | Should -Match 'Keine herstellerseitig bestaetigte Fallback-Quelle fuer 26H2'
    }

    It '26H2: Fallback nur mit ausdruecklicher Freigabe AllowUnconfirmedFallbackSource (mit Warnung)' {
        Reset-Sim -Build '26300'
        $Sim.WuError = '0x800F0954'
        $r = Invoke-SimRun -Config @{ AllowUnconfirmedFallbackSource = $true }
        @($Sim.Jobs) | Should -Contain 'Fallback:AddPackage'
        $r.Status | Should -Be 'REBOOT_REQUIRED'
        @($Cdt.Warnings) -join ' ' | Should -Match 'NICHT herstellerbestaetigt'
    }

    It 'Richtlinienblockade: kein WU-Versuch, direkt Fallback' {
        $Sim.Policy = 'Blocked'
        [void](Invoke-SimRun)
        @($Sim.Jobs | Where-Object { $_ -like 'WindowsUpdate:*' }).Count | Should -Be 0
        @($Sim.Jobs) | Should -Contain 'Fallback:AddPackage'
    }

    It 'Fehlende Fallback-Quelle und kein Download -> FAILED mit Begruendung' {
        $Sim.WuError = '0x800F0954'
        $Sim.FallbackSource = $false
        $r = Invoke-SimRun
        $r.Status | Should -Be 'FAILED'
        $r.Reason | Should -Match 'Pflichtkomponenten fehlen'
        [System.IO.File]::ReadAllText($Cdt.Log.Text) | Should -Match 'Keine geeignete Fallback-Quelle'
        # Error-Log = exakt die ERROR-Zeilen des Full-Logs; Abschlusszeile mit Grund
        $err = @([System.IO.File]::ReadAllLines($Cdt.Log.ErrorText) | Where-Object { $_ })
        $err | Should -Be @([System.IO.File]::ReadAllLines($Cdt.Log.Text) | Where-Object { $_ -match '\[ERROR\]' })
        $err[-1] | Should -Match '\[Result/Final\] Ergebnis FAILED, Exitcode 1.*Grund: Pflichtkomponenten fehlen'
        $ej = @([System.IO.File]::ReadAllText($Cdt.Log.ErrorJson) | ConvertFrom-Json)
        $ej.Count | Should -Be $err.Count
        @($ej | Where-Object { $_.level -ne 'ERROR' }).Count | Should -Be 0
    }

    It 'Verify aendert nichts und meldet FAILED auf einem unkonfigurierten System' {
        $r = Invoke-SimRun -Mode 'Verify'
        $r.Status | Should -Be 'FAILED'
        $r.ExitCode | Should -Be 1
        $Sim.Jobs.Count | Should -Be 0
        $Sim.ConfigApplied | Should -BeFalse
    }

    It 'Schleifenschutz: nach MaxApplyRounds Laeufen mit Aenderungen ohne Erfolg keine weiteren Aenderungen' {
        # Konfiguration wird angewendet, bleibt aber nach jedem Neustart unwirksam (Reparaturschleife)
        Mock Invoke-CdtConfiguration { Add-CdtBootChange -Item 'CopyToSystem'; return , @([ordered]@{ Name = 'CopyToSystem'; Status = 'Applied' }) }
        $codes = foreach ($i in 1..3) { (Invoke-SimRun).ExitCode; Invoke-SimReboot }
        @($codes)[0] | Should -Be 1
        (Read-CdtState).applyRounds | Should -Be 3
        $Sim.Jobs.Clear()
        Should -Invoke Invoke-CdtConfiguration -Times 3 -Exactly
        $r = Invoke-SimRun
        $r.Status | Should -Be 'FAILED'
        $r.Reason | Should -Match 'Schleifenschutz'
        $Sim.Jobs.Count | Should -Be 0
        Should -Invoke Invoke-CdtConfiguration -Times 3 -Exactly
    }

    It 'Fehlgeschlagene Laeufe ohne Aenderungen zaehlen nicht als Reparaturschleife (Orchestrierung stoppt bei Exit 1)' {
        $Sim.WuError = '0x800F0954'
        $Sim.FallbackSource = $false
        $r = Invoke-SimRun
        $r.ExitCode | Should -Be 1
        (Read-CdtState).applyRounds | Should -Be 0
    }

    It 'Audit aendert nichts und meldet Handlungsbedarf' {
        $r = Invoke-SimRun -Mode 'Audit'
        $r.Status | Should -Be 'AUDIT_ACTION_REQUIRED'
        $r.ExitCode | Should -Be 0
        $r.Capture | Should -BeFalse
        $Sim.Jobs.Count | Should -Be 0
    }
}
