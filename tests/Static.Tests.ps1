# Statische Pruefungen: Syntax, PS-5.1-Kompatibilitaet, Kodierung, Sicherheitsregeln, Einstiegspunkt
BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/TestHelpers.ps1')
    $script:Text = [System.IO.File]::ReadAllText($CdtScriptPath)
    $tokens = $null
    $errors = $null
    $script:Ast = [System.Management.Automation.Language.Parser]::ParseFile($CdtScriptPath, [ref]$tokens, [ref]$errors)
    $script:ParseErrors = $errors
}

Describe 'Scriptdatei' {
    It 'ist reines ASCII (Windows PowerShell 5.1 liest BOM-lose Dateien als ANSI)' {
        $bytes = [System.IO.File]::ReadAllBytes($CdtScriptPath)
        @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    }
    It 'hat keine Syntaxfehler' {
        $ParseErrors.Count | Should -Be 0
    }
    It 'hat keinen param()-Block (sicher bei vorangestelltem Code durch NERDIO/HYDRA)' {
        $Ast.ParamBlock | Should -BeNullOrEmpty
    }
    It 'beginnt mit den NERDIO-Metadaten' {
        $lines = $Text -split "`r?`n"
        $lines[0] | Should -Match '^#description: '
        $lines[1] | Should -Be '#execution mode: IndividualWithRestart'
    }
    It 'enthaelt genau eine exit-Anweisung (Einstiegspunkt)' {
        $exits = $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ExitStatementAst] }, $true)
        @($exits).Count | Should -Be 1
    }
    It 'verwendet keine abgeschaltete Zertifikatspruefung' {
        $Text | Should -Not -Match 'ServerCertificateValidationCallback\s*=\s*\{'
        $Text | Should -Not -Match 'SkipCertificateCheck'
        $Text | Should -Not -Match 'return\s+true;\s*//\s*accept'
    }
    It 'schreibt keine Windows-Update- oder Servicing-Richtlinien' {
        $writes = $Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and @('Set-ItemProperty', 'New-ItemProperty', 'Remove-ItemProperty', 'New-Item') -contains $n.GetCommandName() }, $true)
        foreach ($w in $writes) { $w.Extent.Text | Should -Not -Match 'WindowsUpdate|Servicing' }
    }
    It 'nutzt keine fest verdrahteten ISO-Laufwerksbuchstaben' {
        $Text | Should -Not -Match '[D-Z]:\\LanguagesAndOptionalFeatures'
    }
    It 'verwendet keine Aliase und kein Invoke-Expression' {
        $Text | Should -Not -Match 'Invoke-Expression|\biex\b'
    }
}

Describe 'PSScriptAnalyzer (inkl. Windows PowerShell 5.1 Syntax/Typen/Parameter)' {
    It 'meldet keine Befunde' {
        $settings = @{
            Severity     = @('Error', 'Warning', 'Information')
            ExcludeRules = @('PSAvoidUsingWriteHost', 'PSUseShouldProcessForStateChangingFunctions', 'PSUseSingularNouns')
            Rules        = @{
                PSUseCompatibleSyntax   = @{ Enable = $true; TargetVersions = @('5.1') }
                PSUseCompatibleCommands = @{ Enable = $true; TargetProfiles = @('win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework') }
                PSUseCompatibleTypes    = @{ Enable = $true; TargetProfiles = @('win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework') }
            }
        }
        $r = @(Invoke-ScriptAnalyzer -Path $CdtScriptPath -Settings $settings)
        ($r | ForEach-Object { '{0}:{1} {2}' -f $_.Line, $_.RuleName, $_.Message }) -join "`n" | Should -BeNullOrEmpty
    }
}

Describe 'Einstiegspunkt ausserhalb von Windows' {
    It 'bricht kontrolliert mit Exitcode 5 ab und aendert nichts' {
        $out = & pwsh -NoLogo -NoProfile -File $CdtScriptPath -Mode Audit 2>&1
        $LASTEXITCODE | Should -Be 5
        ($out -join "`n") | Should -Match 'nur unter Windows'
    }
}
