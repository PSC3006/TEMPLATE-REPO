# Logik-Pruefungen der Scriptfunktionen (plattformunabhaengige Teile, unter PowerShell 7 ausgefuehrt)
BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/TestHelpers.ps1')
    $libPath = Join-Path $TestDrive 'cdt-lib.ps1'
    [System.IO.File]::WriteAllText($libPath, (Get-CdtLibraryText))
    . $libPath
    $ErrorActionPreference = 'Stop'
    $Cdt = @{}
    $CdtSecretValues = New-Object 'System.Collections.Generic.List[string]'
    $CdtEarlyLog = New-Object 'System.Collections.Generic.List[object]'
}

Describe 'Bereinigung von Geheimnissen (Protect-CdtText)' {
    It 'entfernt SAS-/Query-Parameter aus URLs' {
        $s = Protect-CdtText -Text 'https://acc.blob.core.windows.net/c/lof.iso?sv=2022&sig=ABCDEF%2Bxyz&se=2026'
        $s | Should -Be 'https://acc.blob.core.windows.net/c/lof.iso?[REDACTED]'
    }
    It 'entfernt Anmeldedaten in URLs' {
        Protect-CdtText -Text 'http://user:Geheim123@proxy.local:8080' | Should -Be 'http://[REDACTED]@proxy.local:8080'
    }
    It 'entfernt Schluessel=Wert-Geheimnisse, Bearer-Token und JWT' {
        $s = Protect-CdtText -Text 'password=Sommer2026! token: abc123 Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJlLXRlc3Q'
        $s | Should -Not -Match 'Sommer2026|abc123|eyJ'
    }
    It 'entfernt bekannte Geheimwerte (z. B. NERDIO $ADPassword)' {
        $CdtSecretValues.Add('S3cr3t-Value')
        Protect-CdtText -Text 'Fehler mit S3cr3t-Value im Text' | Should -Be 'Fehler mit [REDACTED] im Text'
        $CdtSecretValues.Clear()
    }
    It 'laesst normale Texte unveraendert' {
        Protect-CdtText -Text 'Sprachpaket de-DE installiert (Build 26100.6584)' | Should -Be 'Sprachpaket de-DE installiert (Build 26100.6584)'
    }
}

Describe 'JSON-Ausgabe (ConvertTo-CdtJson)' {
    It 'erzeugt reines ASCII und bleibt verlustfrei lesbar' {
        $json = ConvertTo-CdtJson -InputObject ([ordered]@{ text = ('Pr' + [char]0x00FC + 'fung'); list = @('a') })
        [System.Text.Encoding]::UTF8.GetBytes($json) | Where-Object { $_ -gt 127 } | Should -BeNullOrEmpty
        $back = $json | ConvertFrom-Json
        $back.text | Should -Be ('Pr' + [char]0x00FC + 'fung')
        @($back.list).Count | Should -Be 1
    }
    It 'schreibt Datumswerte als ISO-Text mit Offset' {
        $json = ConvertTo-CdtJson -InputObject ([ordered]@{ t = [datetime]'2026-10-03T12:00:00' })
        $json | Should -Match '"t":"2026-10-03T12:00:00\.000[+-]\d{2}:\d{2}"'
    }
    It 'bereinigt Geheimnisse auch in verschachtelten Werten' {
        $json = ConvertTo-CdtJson -InputObject ([ordered]@{ a = [ordered]@{ url = 'https://x.example/f.iso?sig=abc' } })
        $json | Should -Not -Match 'sig=abc'
    }
}

Describe 'Konfiguration ohne param()-Block' {
    BeforeEach { Remove-Item Env:CDT_DELANG_MODE -ErrorAction SilentlyContinue; Remove-Variable -Name CdtDeLangMode -Scope Global -ErrorAction SilentlyContinue }
    It 'liefert Standardwerte (Auto, Pflicht Basic, optional OCR/TextToSpeech)' {
        $r = Resolve-CdtConfiguration -ArgumentList @()
        $r.Errors.Count | Should -Be 0
        $r.Config.Mode | Should -Be 'Auto'
        @($r.Config.RequiredCapabilities) | Should -Be @('Basic')
        @($r.Config.OptionalCapabilities) | Should -Be @('OCR', 'TextToSpeech')
        $r.Config.LogRoot | Should -Be 'C:\install\CDT-STANDARD-INSTALL-DE_LANG'
    }
    It 'wertet -Name Wert, -Name:Wert und Schalter aus' {
        $r = Resolve-CdtConfiguration -ArgumentList @('-Mode', 'verify', '-AllowUnconfirmedFallbackSource', '-IsoPath', 'D:\a.iso,E:\b.iso', '-TimeBudgetMinutes:60')
        $r.Errors.Count | Should -Be 0
        $r.Config.Mode | Should -Be 'Verify'
        $r.Config.AllowUnconfirmedFallbackSource | Should -BeTrue
        @($r.Config.IsoPath).Count | Should -Be 2
        $r.Config.TimeBudgetMinutes | Should -Be 60
    }
    It 'meldet unbekannte Argumente und ungueltige Werte als Fehler' {
        (Resolve-CdtConfiguration -ArgumentList @('-Bogus', '1')).Errors.Count | Should -BeGreaterThan 0
        (Resolve-CdtConfiguration -ArgumentList @('-Mode', 'Install')).Errors.Count | Should -BeGreaterThan 0
        (Resolve-CdtConfiguration -ArgumentList @('-OptionalCapabilities', 'Klingon')).Errors.Count | Should -BeGreaterThan 0
        (Resolve-CdtConfiguration -ArgumentList @('-TimeBudgetMinutes', '5')).Errors.Count | Should -BeGreaterThan 0
    }
    It 'beachtet die Rangfolge Variable < Umgebung < Argument' {
        $global:CdtDeLangMode = 'Audit'
        (Resolve-CdtConfiguration -ArgumentList @()).Config.Mode | Should -Be 'Audit'
        $env:CDT_DELANG_MODE = 'Apply'
        (Resolve-CdtConfiguration -ArgumentList @()).Config.Mode | Should -Be 'Apply'
        (Resolve-CdtConfiguration -ArgumentList @('-Mode', 'Verify')).Config.Mode | Should -Be 'Verify'
        Remove-Variable -Name CdtDeLangMode -Scope Global
        Remove-Item Env:CDT_DELANG_MODE
    }
}

Describe 'Release- und Editionszuordnung' {
    It 'ordnet 24H2/25H2 mit Fallback-Freigabe und 26H2 ohne Freigabe zu' {
        $a = Resolve-CdtRelease -Build 26100 -DisplayVersion '24H2' -ReleaseMap $CdtReleaseMap
        $a.Release | Should -Be '24H2'; $a.FallbackApproved | Should -BeTrue
        (Resolve-CdtRelease -Build 26200 -DisplayVersion '25H2' -ReleaseMap $CdtReleaseMap).FallbackApproved | Should -BeTrue
        $c = Resolve-CdtRelease -Build 26300 -DisplayVersion '26H2' -ReleaseMap $CdtReleaseMap
        $c.Release | Should -Be '26H2'; $c.FallbackApproved | Should -BeFalse
    }
    It 'leitet keine Freigabe aus aehnlichen Buildnummern ab' {
        (Resolve-CdtRelease -Build 26301 -DisplayVersion '26H2' -ReleaseMap $CdtReleaseMap).Mapped | Should -BeFalse
        (Resolve-CdtRelease -Build 22631 -DisplayVersion '23H2' -ReleaseMap $CdtReleaseMap).Mapped | Should -BeFalse
        (Resolve-CdtRelease -Build 26200 -DisplayVersion '24H2' -ReleaseMap $CdtReleaseMap).DisplayVersionMismatch | Should -BeTrue
    }
    It 'unterscheidet AVD-Ziel, technisch moeglich, sprachbeschraenkt und Server' {
        # Enterprise multi-session meldet real ProductType 3 (wie Server)
        $m = Get-CdtEditionClass -EditionId 'ServerRdsh' -Sku 175 -ProductType 3 -InstallationType 'Client'
        $m.Class | Should -Be 'EnterpriseMultiSession'; $m.AvdTarget | Should -BeTrue; $m.Supported | Should -BeTrue
        (Get-CdtEditionClass -EditionId 'ServerRdsh' -Sku 175 -ProductType 3 -InstallationType 'Server').Class | Should -Be 'EnterpriseMultiSession'
        (Get-CdtEditionClass -EditionId 'Enterprise' -Sku 4 -ProductType 1 -InstallationType 'Client').AvdTarget | Should -BeTrue
        $p = Get-CdtEditionClass -EditionId 'Professional' -Sku 48 -ProductType 1 -InstallationType 'Client'
        $p.Supported | Should -BeTrue; $p.AvdTarget | Should -BeFalse
        $sl = Get-CdtEditionClass -EditionId 'CoreSingleLanguage' -Sku 100 -ProductType 1 -InstallationType 'Client'
        $sl.LanguageRestricted | Should -BeTrue; $sl.Supported | Should -BeFalse
        (Get-CdtEditionClass -EditionId 'ServerDatacenter' -Sku 8 -ProductType 3 -InstallationType 'Server').Class | Should -Be 'Server'    }
}

Describe 'Plattformerkennung Enterprise multi-session (Regression NERDIO-Test-VM: UNSUPPORTED/Exit 5)' {
    BeforeAll {
        # CimCmdlets fehlen unter PowerShell 7/Linux: Platzhalter, damit Pester mocken kann
        if ($null -eq (Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue)) {
            function global:Get-CimInstance { [CmdletBinding()] param([string]$ClassName) }
        }
    }
    It 'stuft Windows 11 Enterprise multi-session (ServerRdsh, SKU 175, ProductType 3) als Client und AVD-Ziel ein' {
        Mock Get-CdtRegistryValues { [ordered]@{ Values = @{ ProductName = 'Windows 10 Enterprise multi-session'; EditionID = 'ServerRdsh'; DisplayVersion = '25H2'; CurrentBuild = '26200'; UBR = 9457; InstallationType = 'Client' } } }
        Mock Get-CdtRegistryValueOrNull { '0409' }
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } {
            [pscustomobject]@{ Caption = 'Microsoft Windows 11 Enterprise multi-session'; Version = '10.0.26200'; OperatingSystemSKU = 175; ProductType = 3; LastBootUpTime = [datetime]'2026-10-03T13:47:49'; BuildNumber = '26200' }
        }
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_ComputerSystemProduct' } { [pscustomobject]@{ UUID = 'UUID-TEST-1' } }
        $p = Get-CdtPlatformInfo
        $p.ProductType | Should -Be 3
        $p.EditionClass.Class | Should -Be 'EnterpriseMultiSession'
        $p.IsClient | Should -BeTrue
        $p.IsWindows11 | Should -BeTrue
        $p.ReleaseInfo.Release | Should -Be '25H2'

        New-TestCdtContext -Root (Join-Path $TestDrive 'prereq')
        $Cdt.Platform = $p
        $Cdt.Context = [ordered]@{ LanguageMode = 'FullLanguage'; IsSystem = $true; IsAdmin = $true }
        $r = Test-CdtPrerequisites
        # Unter Linux fehlen die Windows-Cmdlets (eigene Befunde); Plattform/Edition darf nicht mehr blockieren
        @($r.Fatal | Where-Object { $_ -notmatch '^Cmdlet ' }) | Should -BeNullOrEmpty
        @($r.Warnings | Where-Object { $_ -notmatch '^Cmdlet ' }) | Should -BeNullOrEmpty
    }
    It 'weist Windows Server weiterhin ab' {
        Mock Get-CdtRegistryValues { [ordered]@{ Values = @{ ProductName = 'Windows Server 2025 Datacenter'; EditionID = 'ServerDatacenter'; DisplayVersion = '24H2'; CurrentBuild = '26100'; UBR = 1; InstallationType = 'Server' } } }
        Mock Get-CdtRegistryValueOrNull { '0409' }
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' } {
            [pscustomobject]@{ Caption = 'Microsoft Windows Server 2025 Datacenter'; Version = '10.0.26100'; OperatingSystemSKU = 8; ProductType = 3; LastBootUpTime = [datetime]'2026-10-03T13:47:49'; BuildNumber = '26100' }
        }
        Mock Get-CimInstance -ParameterFilter { $ClassName -eq 'Win32_ComputerSystemProduct' } { [pscustomobject]@{ UUID = 'UUID-TEST-1' } }
        $p = Get-CdtPlatformInfo
        $p.IsClient | Should -BeFalse
        $p.EditionClass.Class | Should -Be 'Server'
    }
}

Describe 'Komponentenbewertung' {
    It 'wertet nur einen echten CBS-Zustand als installiert' {
        Resolve-CdtLanguagePackState -CbsState 'Installed' -InstalledLanguagePacks 'LpCab' -MuiRegistered $true -IsBaseLanguage $false | Should -Be 'Installed'
        Resolve-CdtLanguagePackState -CbsState 'InstallPending' -InstalledLanguagePacks 'None' -MuiRegistered $false -IsBaseLanguage $false | Should -Be 'InstallPending'
        Resolve-CdtLanguagePackState -CbsState 'NotPresent' -InstalledLanguagePacks 'None' -MuiRegistered $false -IsBaseLanguage $false | Should -Be 'NotPresent'
        Resolve-CdtLanguagePackState -CbsState 'Installed' -InstalledLanguagePacks 'LpCab' -MuiRegistered $false -IsBaseLanguage $false | Should -Be 'Inconsistent'
        Resolve-CdtLanguagePackState -CbsState 'NotPresent' -InstalledLanguagePacks 'LpCab' -MuiRegistered $true -IsBaseLanguage $false | Should -Be 'Inconsistent'
        Resolve-CdtLanguagePackState -CbsState 'Staged' -InstalledLanguagePacks 'None' -MuiRegistered $false -IsBaseLanguage $false | Should -Be 'Inconsistent'
        Resolve-CdtLanguagePackState -CbsState 'Unknown' -InstalledLanguagePacks $null -MuiRegistered $false -IsBaseLanguage $false | Should -Be 'Unknown'
    }
    It 'unterscheidet Installationsschritt (Pending zulaessig) und Abschlusspruefung (nur Installed)' {
        New-TestCdtContext -Root (Join-Path $TestDrive 'comp')
        $state = [ordered]@{ LanguagePack = [ordered]@{ State = 'InstallPending' }; Capabilities = [ordered]@{
                Basic = [ordered]@{ State = 'Installed' }; OCR = [ordered]@{ State = 'NotPresent' }; TextToSpeech = [ordered]@{ State = 'InstallPending' }; Handwriting = [ordered]@{ State = 'NotPresent' }; Speech = [ordered]@{ State = 'NotPresent' } } }
        $s = Test-CdtComponentsSatisfied -State $state
        $s.Mandatory | Should -BeTrue
        $s.All | Should -BeFalse
        @($s.MissingOptional) | Should -Be @('OCR')
        (Test-CdtComponentsSatisfied -State $state -Final).Mandatory | Should -BeFalse
    }
}

Describe 'Ergebnis, Exitcodes und Nachpruefung' {
    It 'bewertet blockierende Fehler, nicht pruefbare Punkte und Neustartbedarf' {
        $pass = New-CdtCheck -Id 'a' -Category 'c' -Scope 's' -Name 'n' -Expected 1 -Actual 1 -Status 'Pass'
        $fail = New-CdtCheck -Id 'b' -Category 'c' -Scope 's' -Name 'n' -Expected 1 -Actual 2 -Status 'Fail'
        $nv = New-CdtCheck -Id 'c' -Category 'c' -Scope 's' -Name 'n' -Expected 1 -Actual $null -Status 'NotVerifiable'
        $pend = New-CdtCheck -Id 'd' -Category 'c' -Scope 's' -Name 'n' -Expected 1 -Actual 1 -Status 'PendingReboot'
        $optFail = New-CdtCheck -Id 'e' -Category 'c' -Scope 's' -Name 'n' -Expected 1 -Actual 2 -Status 'Fail' -Blocking $false
        $optFail.Status | Should -Be 'Warn'
        Get-CdtOutcome -Checks @($pass, $optFail) | Should -Be 'SUCCESS'
        Get-CdtOutcome -Checks @($pass, $pend) | Should -Be 'REBOOT_REQUIRED'
        Get-CdtOutcome -Checks @($pend, $nv) | Should -Be 'NOT_VERIFIABLE'
        Get-CdtOutcome -Checks @($pend, $nv, $fail) | Should -Be 'FAILED'
    }
    It 'liefert Exitcode 0 bei REBOOT_REQUIRED nur im ersten Apply-Boot' -TestCases @(
        @{ S = 'SUCCESS'; M = 'Auto'; V = $false; E = 0 }
        @{ S = 'SUCCESS'; M = 'Verify'; V = $true; E = 0 }
        @{ S = 'REBOOT_REQUIRED'; M = 'Auto'; V = $false; E = 0 }
        @{ S = 'REBOOT_REQUIRED'; M = 'Auto'; V = $true; E = 3 }
        @{ S = 'REBOOT_REQUIRED'; M = 'Verify'; V = $false; E = 3 }
        @{ S = 'REBOOT_REQUIRED'; M = 'Apply'; V = $true; E = 0 }
        @{ S = 'FAILED'; M = 'Auto'; V = $false; E = 1 }
        @{ S = 'NOT_VERIFIABLE'; M = 'Verify'; V = $false; E = 2 }
        @{ S = 'LOCKED'; M = 'Auto'; V = $false; E = 4 }
        @{ S = 'UNSUPPORTED'; M = 'Auto'; V = $false; E = 5 }
        @{ S = 'INTERNAL_ERROR'; M = 'Auto'; V = $false; E = 9 }
        @{ S = 'AUDIT_PREREQUISITES_FAILED'; M = 'Audit'; V = $false; E = 1 }
        @{ S = 'AUDIT_ACTION_REQUIRED'; M = 'Audit'; V = $false; E = 0 }
    ) {
        param($S, $M, $V, $E)
        Get-CdtExitCode -Status $S -Mode $M -IsVerificationRun $V -RebootRequiredCode 0 | Should -Be $E
    }
    It 'uebernimmt einen konfigurierten Exitcode fuer REBOOT_REQUIRED (z. B. 3010) nur im Apply-Boot' {
        Get-CdtExitCode -Status 'REBOOT_REQUIRED' -Mode 'Auto' -IsVerificationRun $false -RebootRequiredCode 3010 | Should -Be 3010
        Get-CdtExitCode -Status 'REBOOT_REQUIRED' -Mode 'Auto' -IsVerificationRun $true -RebootRequiredCode 3010 | Should -Be 3
    }
    It 'erkennt einen Nachpruefungslauf nur nach einem Neustart seit REBOOT_REQUIRED' {
        Test-CdtVerificationRun -PendingVerification $null -CurrentBootUtc '2026-10-03T10:00:00Z' | Should -BeFalse
        Test-CdtVerificationRun -PendingVerification @{ bootTimeUtc = '2026-10-03T10:00:00Z' } -CurrentBootUtc '2026-10-03T10:00:00Z' | Should -BeFalse
        Test-CdtVerificationRun -PendingVerification @{ bootTimeUtc = '2026-10-03T10:00:00Z' } -CurrentBootUtc '2026-10-03T10:20:00Z' | Should -BeTrue
    }
}

Describe 'Fehlerklassifikation' {
    It 'ordnet bekannte HRESULTs zu und begrenzt Wiederholungen' {
        (Get-CdtErrorClassification -Code '0x800f0954').Category | Should -Be 'PolicyOrSource'
        (Get-CdtErrorClassification -Code '0x800F0954').Transient | Should -BeFalse
        (Get-CdtErrorClassification -Code -2146498529).Category | Should -Be 'SourceMissing'
        (Get-CdtErrorClassification -Code '0x80072EE2').Transient | Should -BeTrue
        (Get-CdtErrorClassification -Code '0x12345678').Known | Should -BeFalse
        Format-CdtHResult -HResult -2146498529 | Should -Be '0x800F081F'
    }
}

Describe 'Logging, Zustand und Zusammenfassung' {
    BeforeEach { New-TestCdtContext -Root (Join-Path $TestDrive ('log-' + [guid]::NewGuid().ToString('N').Substring(0, 6))) }
    It 'schreibt das Full-Log als Text (BOM) und als gueltiges JSON-Array (ASCII, Pflichtfelder)' {
        Write-CdtLog -Phase 'Test' -Action 'One' -Message ('Umlaut ' + [char]0x00E4) -ErrorCode '0x800F0954' -Source 'WindowsUpdate' -Attempt 1 -DurationMs 12 -PreviousState 'NotPresent' -TargetState 'Installed' -ResultState 'InstallPending' -Recommendation 'x'
        Write-CdtLog -Level WARN -Phase 'Test' -Action 'Two' -Message 'password=abc'
        $raw = [System.IO.File]::ReadAllText($Cdt.Log.Json)
        $raw.TrimStart().StartsWith('[') | Should -BeTrue
        $items = @($raw | ConvertFrom-Json)
        $items.Count | Should -Be 2
        foreach ($o in $items) {
            $o.runId | Should -Be $Cdt.RunId
            $o.scriptVersion | Should -Be $CdtScriptVersion
            $o.schemaVersion | Should -Be $CdtLogSchemaVersion
            $o.vm | Should -Be 'TESTVM'
            $o.phase | Should -Be 'Test'
        }
        $raw | Should -Match '"ts":"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}"'
        $raw | Should -Match '"tsUtc":"[^"]+Z"'
        $items[0].errorCode | Should -Be '0x800F0954'
        $items[0].resultState | Should -Be 'InstallPending'
        $items[0].message | Should -Be ('Umlaut ' + [char]0x00E4)
        ([System.IO.File]::ReadAllBytes($Cdt.Log.Json) | Where-Object { $_ -gt 127 }) | Should -BeNullOrEmpty
        $raw | Should -Not -Match 'password=abc'
        $tb = [System.IO.File]::ReadAllBytes($Cdt.Log.Text)
        ($tb[0], $tb[1], $tb[2]) | Should -Be @(0xEF, 0xBB, 0xBF)
        (Split-Path -Leaf $Cdt.Log.Text) | Should -Match ('^TESTVM_INSTALL-DE_\d{4}-\d{2}-\d{2}\.log$')
        (Split-Path -Leaf $Cdt.Log.Json) | Should -Match ('^TESTVM_INSTALL-DE_\d{4}-\d{2}-\d{2}\.json$')
    }
    It 'legt das Error-Log nur bei Fehlern an und uebernimmt ausschliesslich ERROR-Eintraege unveraendert' {
        Write-CdtLog -Phase 'Test' -Action 'Info' -Message 'alles gut'
        Write-CdtLog -Level WARN -Phase 'Test' -Action 'Warn' -Message 'nur Warnung'
        Test-Path -LiteralPath $Cdt.Log.ErrorText | Should -BeFalse
        Test-Path -LiteralPath $Cdt.Log.ErrorJson | Should -BeFalse
        Write-CdtLog -Level ERROR -Phase 'Test' -Action 'E1' -Message 'erster Fehler' -ErrorCode '0x800F081F'
        Write-CdtLog -Level 'CHECK' -Phase 'Test' -Action 'Chk' -Message 'Pruefung'
        Write-CdtLog -Level ERROR -Phase 'Test' -Action 'E2' -Message 'zweiter Fehler'
        $errLines = @([System.IO.File]::ReadAllLines($Cdt.Log.ErrorText) | Where-Object { $_ })
        $errLines.Count | Should -Be 2
        foreach ($l in $errLines) { $l | Should -Match '\[ERROR\]' }
        $fullErr = @([System.IO.File]::ReadAllLines($Cdt.Log.Text) | Where-Object { $_ -match '\[ERROR\]' })
        $errLines | Should -Be $fullErr
        $errItems = @([System.IO.File]::ReadAllText($Cdt.Log.ErrorJson) | ConvertFrom-Json)
        $errItems.Count | Should -Be 2
        @($errItems | ForEach-Object { $_.level } | Select-Object -Unique) | Should -Be @('ERROR')
        $errItems[0].errorCode | Should -Be '0x800F081F'
        @([System.IO.File]::ReadAllText($Cdt.Log.Json) | ConvertFrom-Json).Count | Should -Be 5
        $Cdt.Log.RunErrorCount | Should -Be 2
        (Split-Path -Leaf $Cdt.Log.ErrorText) | Should -Match ('^TESTVM_INSTALL-DE_\d{4}-\d{2}-\d{2}\.error\.log$')
        (Split-Path -Leaf $Cdt.Log.ErrorJson) | Should -Match ('^TESTVM_INSTALL-DE_\d{4}-\d{2}-\d{2}\.error\.json$')
    }
    It 'haengt Folgelaeufe desselben Tages an (JSON bleibt gueltig) und uebernimmt Fehler aus der Fruehphase' {
        $root = $Cdt.Log.Root
        Write-CdtLog -Phase 'Test' -Action 'Run1' -Message 'Lauf 1'
        $first = $Cdt.RunId
        New-TestCdtContext -Root $root
        Write-CdtLog -Level ERROR -Phase 'Test' -Action 'Run2' -Message 'Lauf 2 Fehler'
        $items = @([System.IO.File]::ReadAllText($Cdt.Log.Json) | ConvertFrom-Json)
        @($items | ForEach-Object { $_.runId } | Select-Object -Unique) | Should -Be @($first, $Cdt.RunId)
        # Eintraege vor der Log-Initialisierung (Fruehphase) landen nach der Initialisierung ebenfalls im Error-Log
        $Cdt.Log.Ready = $false
        Write-CdtLog -Level ERROR -Phase 'Init' -Action 'Early' -Message 'frueher Fehler'
        [void](Initialize-CdtLogging)
        @([System.IO.File]::ReadAllText($Cdt.Log.ErrorJson) | ConvertFrom-Json | ForEach-Object { $_.action }) | Should -Be @('Run2', 'Early')
    }
    It 'sichert ein unvollstaendiges JSON-Log und beginnt ein neues gueltiges Array' {
        $root = $Cdt.Log.Root
        Write-CdtLog -Phase 'Test' -Action 'A' -Message 'vorher'
        [System.IO.File]::AppendAllText($Cdt.Log.Json, ',{"abgebrochen":')
        New-TestCdtContext -Root $root
        @(Get-ChildItem -LiteralPath $root -Filter '*.json.corrupt-*').Count | Should -Be 1
        $items = @([System.IO.File]::ReadAllText($Cdt.Log.Json) | ConvertFrom-Json)
        @($items | Where-Object { $_.level -eq 'WARN' -and $_.action -eq 'Logging' }).Count | Should -Be 1
    }
    It 'haengt mehrere Laeufe eines Tages an die Zusammenfassung an (latest = neuester)' {
        $Cdt.Status = 'REBOOT_REQUIRED'; $Cdt.ExitCode = 0; $Cdt.CaptureAllowed = $false
        Write-CdtDailySummary -RunSummary (New-CdtRunSummary)
        $first = $Cdt.RunId
        $Cdt.RunId = New-CdtRunId
        $Cdt.Status = 'SUCCESS'; $Cdt.ExitCode = 0; $Cdt.CaptureAllowed = $true
        Write-CdtDailySummary -RunSummary (New-CdtRunSummary)
        $doc = [System.IO.File]::ReadAllText($Cdt.Log.Summary) | ConvertFrom-Json
        @($doc.runs).Count | Should -Be 2
        $doc.runs[0].runId | Should -Be $first
        $doc.latest.runId | Should -Be $Cdt.RunId
        $doc.latest.status | Should -Be 'SUCCESS'
    }
    It 'sichert eine beschaedigte Zusammenfassung statt sie zu ueberschreiben' {
        [System.IO.File]::WriteAllText($Cdt.Log.Summary, '{kaputt')
        $Cdt.Status = 'FAILED'; $Cdt.ExitCode = 1; $Cdt.CaptureAllowed = $false
        Write-CdtDailySummary -RunSummary (New-CdtRunSummary)
        @(Get-ChildItem -LiteralPath $Cdt.Log.Root -Filter '*.summary.json.corrupt-*').Count | Should -Be 1
        ([System.IO.File]::ReadAllText($Cdt.Log.Summary) | ConvertFrom-Json).latest.status | Should -Be 'FAILED'
    }
    It 'ignoriert einen aus dem Master uebernommenen Zustand (andere Maschine)' {
        $Cdt.State.pendingVerification = [ordered]@{ bootTimeUtc = '2026-10-01T00:00:00Z' }
        $Cdt.State.applyRounds = 2
        Save-CdtState
        $Cdt.Platform.SmbiosUuid = 'UUID-NEUER-HOST'
        $s = Read-CdtState
        $s.pendingVerification | Should -BeNullOrEmpty
        $s.applyRounds | Should -Be 0
    }
    It 'liest den eigenen Zustand wieder ein und erkennt neustartrelevante Aenderungen dieses Boots' {
        Add-CdtBootChange -Item 'SystemLocale'
        Test-CdtChangedThisBoot -Item 'SystemLocale' | Should -BeTrue
        $s = Read-CdtState
        @($s.bootChanges.items) | Should -Contain 'SystemLocale'
        $Cdt.State = $s
        $Cdt.Platform.LastBootUtc = '2026-10-03T11:00:00Z'
        Test-CdtChangedThisBoot -Item 'SystemLocale' | Should -BeFalse
    }
    It 'sichert eine beschaedigte Zustandsdatei' {
        [System.IO.File]::WriteAllText($Cdt.StatePath, 'xx')
        $s = Read-CdtState
        $s.applyRounds | Should -Be 0
        @(Get-ChildItem -LiteralPath $Cdt.Log.StateDir -Filter '*.state.json.corrupt-*').Count | Should -Be 1
    }
}

Describe 'missing-network-requirements (TXT/CSV)' {
    BeforeEach { New-TestCdtContext -Root (Join-Path $TestDrive ('net-' + [guid]::NewGuid().ToString('N').Substring(0, 6))) }
    It 'listet nur fehlgeschlagene erforderliche Verbindungen mit verbindlichen ersten Spalten' {
        $ok = [ordered]@{ Id = 'A'; Host = 'ok.example'; Port = 443; Protocol = 'HTTPS'; Url = 'https://ok.example/'; Required = $true; Requirement = 'ok.example'; Purpose = 'p'; Reference = 'r'; ProxyMode = 'Direct'; Proxy = 'direkt'; ProxySource = 'x'; ConnectTarget = 'ok.example:443'; Dns = [ordered]@{ Addresses = @('1.2.3.4'); TimestampUtc = 't' }; Status = 'Pass'; Category = ''; Code = ''; Detail = ''; Recommendation = ''; TimestampUtc = 't' }
        $tcp = [ordered]@{ Id = 'B'; Host = 'fe3.delivery.mp.microsoft.com'; Port = 443; Protocol = 'HTTPS'; Url = 'https://fe3.delivery.mp.microsoft.com/'; Required = $true; Requirement = '*.delivery.mp.microsoft.com'; Purpose = 'WU'; Reference = 'MS'; ProxyMode = 'Direct'; Proxy = 'direkt'; ProxySource = 'x'; ConnectTarget = 'fe3.delivery.mp.microsoft.com:443'; Dns = [ordered]@{ Addresses = @('20.1.1.1'); TimestampUtc = 't' }; Status = 'Fail'; Category = 'TcpConnectFailure'; Code = 'TimedOut'; Detail = 'd'; Recommendation = 'Freigabe pruefen'; TimestampUtc = 't' }
        $dns = [ordered]@{ Id = 'C'; Host = 'sls.update.microsoft.com'; Port = 443; Protocol = 'HTTPS'; Url = 'https://sls.update.microsoft.com/'; Required = $true; Requirement = '*.update.microsoft.com'; Purpose = 'WU'; Reference = 'MS'; ProxyMode = 'Direct'; Proxy = 'direkt'; ProxySource = 'x'; ConnectTarget = 'sls.update.microsoft.com:443'; Dns = [ordered]@{ Addresses = @(); TimestampUtc = 't' }; Status = 'Fail'; Category = 'DnsFailure'; Code = 'HostNotFound'; Detail = 'd'; Recommendation = 'DNS'; TimestampUtc = 't' }
        $opt = [ordered]@{ Id = 'D'; Host = 'emdl.ws.microsoft.com'; Port = 80; Protocol = 'HTTP'; Url = 'http://emdl.ws.microsoft.com/'; Required = $false; Requirement = 'emdl.ws.microsoft.com'; Purpose = 'diag'; Reference = 'MS'; ProxyMode = 'Direct'; Proxy = 'direkt'; ProxySource = 'x'; ConnectTarget = 'emdl.ws.microsoft.com:80'; Dns = $null; Status = 'Fail'; Category = 'TcpConnectFailure'; Code = 'TimedOut'; Detail = 'd'; Recommendation = 'x'; TimestampUtc = 't' }
        foreach ($x in @($ok, $tcp, $dns, $opt)) { [void]$Cdt.Network.Results.Add($x) }
        Write-CdtNetworkRequirementFiles
        $headerLine = ([System.IO.File]::ReadAllLines($Cdt.Log.MissingCsv))[0]
        $headerLine | Should -Match '^\W*"URL/IP";"Protokoll";"Port/s";"Richtung";'
        $rows = @(Import-Csv -LiteralPath $Cdt.Log.MissingCsv -Delimiter ';' -Encoding UTF8)
        $rows.Count | Should -Be 2
        ($rows | Where-Object { $_.Fehlerkategorie -eq 'TcpConnectFailure' }).'URL/IP' | Should -Be '*.delivery.mp.microsoft.com'
        ($rows | Where-Object { $_.Fehlerkategorie -eq 'DnsFailure' }).'Port/s' | Should -Be '53'
        foreach ($row in $rows) { $row.Richtung | Should -Match '^Ausgehend \(VM -> Ziel\)' }
        @($rows | ForEach-Object { $_.RunId } | Select-Object -Unique) | Should -Be @($Cdt.RunId)
        $txt = [System.IO.File]::ReadAllText($Cdt.Log.MissingTxt)
        $txt | Should -Match 'FEHLGESCHLAGENE ERFORDERLICHE VERBINDUNGEN: 2'
        $txt | Should -Match 'emdl.ws.microsoft.com'
        $Cdt.Log.MissingWritten | Should -BeTrue
    }
    It 'schreibt keine Datei, wenn keine Netzwerkvoraussetzung fehlt, und entfernt veraltete eigene Dateien' {
        $fail = [ordered]@{ Id = 'B'; Host = 'fe3.delivery.mp.microsoft.com'; Port = 443; Protocol = 'HTTPS'; Url = 'https://fe3.delivery.mp.microsoft.com/'; Required = $true; Requirement = '*.delivery.mp.microsoft.com'; Purpose = 'WU'; Reference = 'MS'; ProxyMode = 'Direct'; Proxy = 'direkt'; ProxySource = 'x'; ConnectTarget = 'fe3.delivery.mp.microsoft.com:443'; Dns = $null; Status = 'Fail'; Category = 'TcpConnectFailure'; Code = 'TimedOut'; Detail = 'd'; Recommendation = 'r'; TimestampUtc = 't' }
        [void]$Cdt.Network.Results.Add($fail)
        Write-CdtNetworkRequirementFiles
        Test-Path -LiteralPath $Cdt.Log.MissingCsv | Should -BeTrue
        # Folgelauf: erneute Pruefung erfolgreich (nur optionaler Fehler) -> keine Datei mehr
        $Cdt.Network.Results.Clear()
        $pass = [ordered]@{ Id = 'A'; Host = 'ok'; Port = 443; Protocol = 'HTTPS'; Url = 'u'; Required = $true; Requirement = 'ok'; Purpose = 'p'; Reference = 'r'; ProxyMode = 'Direct'; Proxy = 'direkt'; ProxySource = 'x'; ConnectTarget = 'ok:443'; Dns = $null; Status = 'Pass'; Category = ''; Code = ''; Detail = ''; Recommendation = ''; TimestampUtc = 't' }
        $opt = [ordered]@{ Id = 'D'; Host = 'emdl.ws.microsoft.com'; Port = 80; Protocol = 'HTTP'; Url = 'http://emdl.ws.microsoft.com/'; Required = $false; Requirement = 'emdl.ws.microsoft.com'; Purpose = 'diag'; Reference = 'MS'; ProxyMode = 'Direct'; Proxy = 'direkt'; ProxySource = 'x'; ConnectTarget = 'emdl.ws.microsoft.com:80'; Dns = $null; Status = 'Fail'; Category = 'TcpConnectFailure'; Code = 'TimedOut'; Detail = 'd'; Recommendation = 'x'; TimestampUtc = 't' }
        foreach ($x in @($pass, $opt)) { [void]$Cdt.Network.Results.Add($x) }
        Write-CdtNetworkRequirementFiles
        Test-Path -LiteralPath $Cdt.Log.MissingCsv | Should -BeFalse
        Test-Path -LiteralPath $Cdt.Log.MissingTxt | Should -BeFalse
        $Cdt.Log.MissingWritten | Should -BeFalse
        [System.IO.File]::ReadAllText($Cdt.Log.Text) | Should -Match 'keine fehlenden Netzwerkvoraussetzungen.*Veraltete Datei'
        $Cdt.State.network.lastCheck.runId | Should -Be $Cdt.RunId
    }
    It 'laesst vorhandene Dateien unveraendert, wenn in diesem Lauf keine Netzwerkpruefung stattfand' {
        [void]$Cdt.Network.Results.Add([ordered]@{ Id = 'B'; Host = 'h'; Port = 443; Protocol = 'HTTPS'; Url = 'u'; Required = $true; Requirement = 'h'; Purpose = 'WU'; Reference = 'MS'; ProxyMode = 'Direct'; Proxy = 'direkt'; ProxySource = 'x'; ConnectTarget = 'h:443'; Dns = $null; Status = 'Fail'; Category = 'TcpConnectFailure'; Code = 'TimedOut'; Detail = 'd'; Recommendation = 'r'; TimestampUtc = 't' })
        Write-CdtNetworkRequirementFiles
        $before = [System.IO.File]::ReadAllText($Cdt.Log.MissingCsv)
        $Cdt.Network.Results.Clear()
        Write-CdtNetworkRequirementFiles
        [System.IO.File]::ReadAllText($Cdt.Log.MissingCsv) | Should -Be $before
        $Cdt.Log.MissingWritten | Should -BeFalse
    }
    It 'entfernt keine fremde Datei gleichen Namens' {
        [System.IO.File]::WriteAllText($Cdt.Log.MissingTxt, 'fremder Inhalt')
        [void]$Cdt.Network.Results.Add([ordered]@{ Id = 'A'; Host = 'ok'; Port = 443; Protocol = 'HTTPS'; Url = 'u'; Required = $true; Requirement = 'ok'; Purpose = 'p'; Reference = 'r'; ProxyMode = 'Direct'; Proxy = 'direkt'; ProxySource = 'x'; ConnectTarget = 'ok:443'; Dns = $null; Status = 'Pass'; Category = ''; Code = ''; Detail = ''; Recommendation = ''; TimestampUtc = 't' })
        Write-CdtNetworkRequirementFiles
        [System.IO.File]::ReadAllText($Cdt.Log.MissingTxt) | Should -Be 'fremder Inhalt'
        [System.IO.File]::ReadAllText($Cdt.Log.Text) | Should -Match 'Fremde Datei gleichen Namens nicht veraendert'
    }
}

Describe 'Sperre gegen parallele Ausfuehrung' {
    It 'verweigert einer zweiten Instanz die Sperre' {
        New-TestCdtContext -Root (Join-Path $TestDrive 'lock')
        $lock = Enter-CdtLock
        $lock.Acquired | Should -BeTrue
        try {
            $probe = 'try { $m = New-Object System.Threading.Mutex($false, "Global\CDT-STANDARD-INSTALL-DE_LANG"); if ($m.WaitOne(1000)) { "ACQUIRED" } else { "BLOCKED" } } catch { "ERROR " + $_.Exception.Message }'
            (& pwsh -NoLogo -NoProfile -Command $probe) | Should -Be 'BLOCKED'
        }
        finally { Exit-CdtLock -Lock $lock }
        (& pwsh -NoLogo -NoProfile -Command 'try { $m = New-Object System.Threading.Mutex($false, "Global\CDT-STANDARD-INSTALL-DE_LANG"); if ($m.WaitOne(1000)) { "ACQUIRED" } else { "BLOCKED" } } catch { "ERROR" }') | Should -Be 'ACQUIRED'
    }
}
