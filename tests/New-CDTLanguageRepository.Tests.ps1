# Pester-Tests (Pester 4.10 / 5.x) fuer New-CDTLanguageRepository.ps1 - nur reine Funktionen, keine Systemaufrufe.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $here
$env:CDT_LANG_SKIP_MAIN = '1'
. (Join-Path -Path $repoRoot -ChildPath 'New-CDTLanguageRepository.ps1') -RepositoryRoot 'D:\LangRepo'
. (Join-Path -Path $repoRoot -ChildPath 'Install-CDTGermanLanguage.ps1')
$script:ConsoleOutput = $false

Describe 'Repository-Script: Hilfsfunktionen' {
    It 'Hauptbuild aus ISO-Namen' {
        Get-RepoIsoBuildFromName -Name 'C:\x\26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso' | Should -Be 26100
        Get-RepoIsoBuildFromName -Name 'lof.iso' | Should -Be 0
    }
    It 'Language-FoDs in Abhaengigkeitsreihenfolge, Basic immer enthalten' {
        (Get-RepoLanguageCapability -TargetLanguage 'de-DE' -Feature @('Speech', 'OCR', 'TextToSpeech')) -join ',' |
            Should -Be 'Language.Basic~~~de-DE~0.0.1.0,Language.OCR~~~de-DE~0.0.1.0,Language.TextToSpeech~~~de-DE~0.0.1.0,Language.Speech~~~de-DE~0.0.1.0'
    }
    It 'Versionsordner <Sprache>_<yyyy-MM-dd>, bei Kollision mit Uhrzeit' {
        $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('cdt-repo-' + [guid]::NewGuid())
        $null = New-Item -Path $tmp -ItemType Directory
        try {
            $d = [datetime]'2026-10-02T14:05:00'
            Get-RepoVersionFolderName -BuildFolder $tmp -TargetLanguage 'de-DE' -Date $d | Should -Be 'de-DE_2026-10-02'
            $null = New-Item -Path (Join-Path -Path $tmp -ChildPath 'de-DE_2026-10-02') -ItemType Directory
            Get-RepoVersionFolderName -BuildFolder $tmp -TargetLanguage 'de-DE' -Date $d | Should -Be 'de-DE_2026-10-02_1405'
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
    It 'TempPath-Schutz' {
        Test-RepoSafeTempPath -Path 'C:\' | Should -BeFalse
        Test-RepoSafeTempPath -Path 'C:\Windows\Temp' | Should -BeFalse
        Test-RepoSafeTempPath -Path 'C:\Install\CDT-LanguageRepository_tmp' | Should -BeTrue
    }
    It 'Secrets und SAS werden maskiert' {
        Add-RepoSecret -Value 'https://acc.blob.core.windows.net/c?sv=1&sig=GEHEIM'
        Get-RepoMaskedText -Text 'Upload nach https://acc.blob.core.windows.net/c/x.zip?sv=1&sig=GEHEIM' | Should -Not -Match 'GEHEIM'
    }
}

Describe 'Roundtrip: Manifest aus New-CDTLanguageRepository wird von Install-CDTGermanLanguage akzeptiert' {
    It 'Manifest ist gueltig und deckt alle Dateien ab' {
        $tmp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('cdt-rt-' + [guid]::NewGuid())
        $null = New-Item -Path $tmp -ItemType Directory
        try {
            Set-Content -LiteralPath (Join-Path -Path $tmp -ChildPath 'Microsoft-Windows-Client-Language-Pack_x64_de-de.cab') -Value 'lp' -NoNewline
            Set-Content -LiteralPath (Join-Path -Path $tmp -ChildPath 'Microsoft-Windows-LanguageFeatures-Basic-de-de-Package~31bf3856ad364e35~amd64~~.cab') -Value 'basic' -NoNewline
            $meta = [ordered]@{ schemaVersion = 1; osBaseBuild = '26100'; language = 'de-DE'; sourceIso = [ordered]@{ name = 'x.iso'; sha256 = 'AA' }; createdUtc = '2026-10-02T12:00:00Z' }
            $null = New-RepoManifest -Path $tmp -Metadata $meta -Confirm:$false
            $r = Test-CDTRepositoryManifest -Path $tmp -ExpectedBaseBuild 26100 -Language 'de-DE'
            $r.Valid | Should -BeTrue
            $r.FileCount | Should -Be 2
            @($r.Warnings).Count | Should -Be 0
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
    }
}
