<#
.SYNOPSIS
    Erstellt einmalig pro OS-Hauptbuild ein minimales, versioniertes FoD- und Sprachpaket-Repository (Stufe 2)
    fuer Install-CDTGermanLanguage.ps1 nach dem Microsoft-Vorgehen "Build a custom FOD and language pack repository".

.DESCRIPTION
    Interaktiv als Administrator auszufuehren, idealerweise auf einer VM mit demselben Image wie der Master.

    Ablauf:
      1. LOF-ISO herunterladen (HEAD, Speicherpruefung, curl.exe mit Retry/Resume, Fallback BITS) oder -IsoPath nutzen.
      2. ISO einbinden (Laufwerksbuchstabe oder mountvol-Ordner).
      3. DISM /Export-Source fuer Language.Basic/OCR/Handwriting/Speech/TextToSpeech~~~<Sprache> und die
         Satelliten-FoDs (nur installierte Capabilities). Microsoft dokumentiert /Export-Source mit /Image; /Online ist
         unbestaetigt und wird zuerst versucht (-ExportMethod Auto: Online -> Image -> FullCopy).
      4. Fallback: kompletter Inhalt von LanguagesAndOptionalFeatures (groesser, laut Microsoft zulaessig).
      5. Sprachpaket-.cab der Zielsprache in dasselbe Verzeichnis kopieren (optional WinPE-Sprachpakete fuer WinRE).
      6. Authenticode-Pruefung aller .cab, manifest.json mit SHA256 aller Dateien.
      7. Ablage versioniert: <RepositoryRoot>\<OS-Hauptbuild>\<Sprache>_<yyyy-MM-dd>. UNC-Ziel (Azure Files) wird
         temporaer verbunden und danach getrennt (inkl. cmdkey-Bereinigung).
      8. Optional ZIP (-CreateZip) und Upload nach Azure Blob (-UploadBlobContainerSasUrl; azcopy oder curl.exe).

    Keine Secrets im Code: Storage-Key und SAS-URL nur per Parameter, sie werden nie geloggt.

.PARAMETER RepositoryRoot
    Wurzel des Repositorys (lokal oder UNC, z. B. \\stcdtlang.file.core.windows.net\langrepo).

.PARAMETER Language
    Zielsprache. Default de-DE.

.PARAMETER IsoPath
    Vorhandenes LOF-ISO. Ohne Angabe wird -LofIsoUrl heruntergeladen.

.PARAMETER LofIsoUrl
    Download-URL des LOF-ISO (Default: 24H2/25H2 laut Microsoft AVD-Artikel).

.PARAMETER OsBaseBuild
    OS-Hauptbuild des Repositorys. 0 (Default) = aus dem ISO-Namen bzw. der Sprachpaket-Version ermitteln.

.PARAMETER Features
    Language-FoDs. Default Basic, OCR, Handwriting, TextToSpeech, Speech.

.PARAMETER ExportMethod
    Auto (Default: Online -> Image -> FullCopy), Online, Image, FullCopy.

.PARAMETER ImagePath
    Eingebundenes Offline-Image (Mount-Ordner von install.wim) fuer DISM /Image /Export-Source.

.PARAMETER SatelliteCapability
    FoDs mit Satellitenpaketen, die mitexportiert werden. Bei Online-Export nur, wenn auf dieser Maschine installiert.

.PARAMETER IncludeWinPE
    WinPE-Sprachpakete (lp.cab, WinPE-*_<sprache>.cab) fuer WinRE (MS-14) nach WinPE_OCs\<sprache> kopieren.

.PARAMETER CreateZip
    Zusaetzlich <Sprache>_<Datum>.zip neben dem Versionsordner ablegen.

.PARAMETER StorageAccountKey
    Optionaler Storage-Account-Key fuer ein UNC-Ziel (Azure Files).

.PARAMETER UploadBlobContainerSasUrl
    Container-SAS-URL (Schreibrecht) fuer den ZIP-Upload. Setzt -CreateZip voraus.

.PARAMETER AzCopyPath
    Pfad zu azcopy.exe. Ohne Angabe: azcopy aus PATH, sonst curl.exe (Bordmittel, max. 5000 MiB).

.PARAMETER TempPath
    Arbeitsverzeichnis. Wird am Ende geloescht.

.PARAMETER LogRoot
    Log-Verzeichnis. Default C:\Install\CDT-STANDARD-Install_DE-Language.

.PARAMETER KeepIso
    Heruntergeladenes ISO nicht loeschen.

.EXAMPLE
    .\New-CDTLanguageRepository.ps1 -RepositoryRoot 'D:\LangRepo' -CreateZip

.EXAMPLE
    .\New-CDTLanguageRepository.ps1 -RepositoryRoot '\\stcdtlang.file.core.windows.net\langrepo' -StorageAccountKey $Key -IsoPath 'D:\ISO\26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso' -IncludeWinPE

.NOTES
    Version : 1.0.0 (2026-10-02)
    Autor   : CDT

    CHANGELOG
      1.0.0  2026-10-02  Erstversion: Download/ISO, export-source (Online/Image) mit Fallback Vollkopie,
                         manifest.json (SHA256), versionierte Ablage, ZIP, Upload Azure Files/Blob.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryRoot,

    [ValidatePattern('^[a-z]{2,3}-[A-Z]{2}$')]
    [string]$Language = 'de-DE',

    [string]$IsoPath = '',

    [string]$LofIsoUrl = 'https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso',

    [ValidateRange(0, 99999)]
    [int]$OsBaseBuild = 0,

    [ValidateSet('Basic', 'OCR', 'Handwriting', 'TextToSpeech', 'Speech')]
    [string[]]$Features = @('Basic', 'OCR', 'Handwriting', 'TextToSpeech', 'Speech'),

    [ValidateSet('Auto', 'Online', 'Image', 'FullCopy')]
    [string]$ExportMethod = 'Auto',

    [string]$ImagePath = '',

    [string[]]$SatelliteCapability = @(
        'App.StepsRecorder~~~~0.0.1.0'
        'Microsoft.Windows.Notepad.System~~~~0.0.1.0'
        'Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0'
        'Print.Management.Console~~~~0.0.1.0'
        'Print.Fax.Scan~~~~0.0.1.0'
        'WMIC~~~~'
    ),

    [switch]$IncludeWinPE,

    [switch]$CreateZip,

    [string]$StorageAccountKey = '',

    [string]$UploadBlobContainerSasUrl = '',

    [string]$AzCopyPath = '',

    [string]$TempPath = 'C:\Install\CDT-LanguageRepository_tmp',

    [string]$LogRoot = 'C:\Install\CDT-STANDARD-Install_DE-Language',

    [switch]$KeepIso
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

#region Laufzeitstatus
$script:Version = '1.0.0'
$script:RunStart = Get-Date
$script:RunTimestamp = $script:RunStart.ToString('yyyy-MM-dd_HHmmss')
$script:Secrets = [System.Collections.Generic.List[string]]::new()
$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:Utf8Bom = [System.Text.UTF8Encoding]::new($true)
$script:LogFile = $null
$script:ErrorLogFile = $null
$script:ConsoleOutput = $true
$script:Opt = @{
    RepositoryRoot            = $RepositoryRoot
    Language                  = $Language
    IsoPath                   = $IsoPath
    LofIsoUrl                 = $LofIsoUrl
    OsBaseBuild               = $OsBaseBuild
    Features                  = @($Features)
    ExportMethod              = $ExportMethod
    ImagePath                 = $ImagePath
    SatelliteCapability       = @($SatelliteCapability)
    IncludeWinPE              = [bool]$IncludeWinPE
    CreateZip                 = [bool]$CreateZip
    StorageAccountKey         = $StorageAccountKey
    UploadBlobContainerSasUrl = $UploadBlobContainerSasUrl
    AzCopyPath                = $AzCopyPath
    TempPath                  = $TempPath
    LogRoot                   = $LogRoot
    KeepIso                   = [bool]$KeepIso
}
#endregion

#region Hilfsfunktionen
function Add-RepoSecret {
    <#
    .SYNOPSIS
        Registriert einen geheimen Wert (wird in Logs maskiert).
    #>
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrEmpty($Value) -or $Value.Length -lt 4) { return }
    $script:Secrets.Add($Value)
    $q = $Value.IndexOf('?')
    if ($q -ge 0 -and $q -lt ($Value.Length - 1)) { $script:Secrets.Add($Value.Substring($q + 1)) }
}

function Get-RepoMaskedText {
    <#
    .SYNOPSIS
        Maskiert Secrets und SAS-Parameter.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    $masked = $Text
    foreach ($s in $script:Secrets) { if ($s) { $masked = $masked.Replace($s, '***') } }
    return [regex]::Replace($masked, '(?i)([?&](sig|se|st|sp|sv|sr|spr|srt|ss|skoid|sktid|skt|ske|sks|skv)=)[^&\s"'']+', '$1***')
}

function Write-RepoLog {
    <#
    .SYNOPSIS
        Logzeile (ISO-Zeitstempel, Level) ins Log, WARN/ERROR zusaetzlich ins Fehlerlog.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = '{0} [{1,-5}] {2}' -f (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffzzz'), $Level, (Get-RepoMaskedText -Text $Message)
    if ($script:LogFile) { [System.IO.File]::AppendAllText($script:LogFile, $line + [Environment]::NewLine, $script:Utf8NoBom) }
    if ($Level -ne 'INFO' -and $script:ErrorLogFile) { [System.IO.File]::AppendAllText($script:ErrorLogFile, $line + [Environment]::NewLine, $script:Utf8NoBom) }
    if ($script:ConsoleOutput) { Write-Information -MessageData $line -InformationAction Continue }
}

function ConvertTo-RepoArgumentString {
    <#
    .SYNOPSIS
        Windows-Kommandozeile mit korrektem Quoting.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowEmptyCollection()][string[]]$ArgumentList = @())
    $parts = foreach ($a in $ArgumentList) {
        if ($null -eq $a -or $a -eq '') { '""' }
        elseif ($a -notmatch '[\s"]') { $a }
        else { '"' + [regex]::Replace([regex]::Replace($a, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"' }
    }
    return (@($parts) -join ' ')
}

function Invoke-RepoNativeCommand {
    <#
    .SYNOPSIS
        Startet ein natives Programm mit Timeout und abgefangener Ausgabe.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [AllowEmptyCollection()][string[]]$ArgumentList = @(),
        [int]$TimeoutSeconds = 14400,
        [switch]$NoLog
    )
    $argString = ConvertTo-RepoArgumentString -ArgumentList $ArgumentList
    if (-not $NoLog) { Write-RepoLog -Message ('Starte: {0} {1}' -f $FilePath, $argString) }
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
            try { $proc.Kill() } catch { Write-RepoLog -Level WARN -Message ('Kill fehlgeschlagen: {0}' -f $_.Exception.Message) }
            throw ('Timeout nach {0} s: {1}' -f $TimeoutSeconds, $FilePath)
        }
        $proc.WaitForExit()
        return [pscustomobject]@{ ExitCode = $proc.ExitCode; StdOut = [string]$outTask.Result; StdErr = [string]$errTask.Result }
    }
    finally { $proc.Dispose() }
}

function Get-RepoSystemTool {
    <#
    .SYNOPSIS
        Pfad zu einem Programm in %SystemRoot%\System32.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][string]$Name)
    return (Join-Path -Path $env:SystemRoot -ChildPath ('System32\{0}' -f $Name))
}

function Test-RepoSafeTempPath {
    <#
    .SYNOPSIS
        Prueft, ob TempPath gefahrlos geleert werden darf (lokal, nicht unter Systemordnern, mind. 2 Ebenen oder CDT/tmp im Namen).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowEmptyString()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $p = $Path.Trim().TrimEnd('\')
    if ($p -notmatch '^[A-Za-z]:\\' -or $p -match '\.\.' -or $p -match '[*?]') { return $false }
    $segments = @($p.Substring(3).Split('\') | Where-Object { $_ })
    if ($segments.Count -lt 1) { return $false }
    if (@('Windows', 'Program Files', 'Program Files (x86)', 'ProgramData', 'Users', 'Recovery', 'Boot', 'System Volume Information', '$Recycle.Bin', 'PerfLogs') -contains $segments[0]) { return $false }
    if ($segments.Count -lt 2 -and $segments[-1] -notmatch '(?i)(CDT|tmp|temp)') { return $false }
    return $true
}

function Get-RepoIsoBuildFromName {
    <#
    .SYNOPSIS
        Hauptbuild aus dem ISO-Namen (26100.1....iso -> 26100), 0 = unbekannt.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([AllowEmptyString()][string]$Name)
    if ($Name -match '(?:^|[\\/])(\d{5})\.\d+\.') { return [int]$Matches[1] }
    return 0
}

function Get-RepoVersionFolderName {
    <#
    .SYNOPSIS
        Name des Versionsordners <Sprache>_<yyyy-MM-dd>; existiert er, wird _HHmm angehaengt.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$BuildFolder,
        [Parameter(Mandatory = $true)][string]$TargetLanguage,
        [Parameter(Mandatory = $true)][datetime]$Date
    )
    $name = '{0}_{1}' -f $TargetLanguage, $Date.ToString('yyyy-MM-dd')
    if (Test-Path -LiteralPath (Join-Path -Path $BuildFolder -ChildPath $name)) { $name = '{0}_{1}' -f $name, $Date.ToString('HHmm') }
    return $name
}

function Get-RepoLanguageCapability {
    <#
    .SYNOPSIS
        Capability-Namen der Language-FoDs in Abhaengigkeitsreihenfolge.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)][string]$TargetLanguage,
        [Parameter(Mandatory = $true)][string[]]$Feature
    )
    $order = @('Basic', 'OCR', 'Handwriting', 'TextToSpeech', 'Speech')
    $list = foreach ($f in $order) { if (@($Feature) -contains $f -or $f -eq 'Basic') { 'Language.{0}~~~{1}~0.0.1.0' -f $f, $TargetLanguage } }
    return [string[]]@($list)
}

function New-RepoManifest {
    <#
    .SYNOPSIS
        Erzeugt manifest.json mit SHA256 aller Dateien des Repositorys.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Metadata
    )
    $root = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\', '/')
    $files = foreach ($f in @(Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object { $_.Name -ne 'manifest.json' } | Sort-Object -Property FullName)) {
        [ordered]@{
            path   = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('/', '\')
            size   = $f.Length
            sha256 = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        }
    }
    $manifest = [ordered]@{}
    foreach ($k in $Metadata.Keys) { $manifest[$k] = $Metadata[$k] }
    $manifest['files'] = @($files)
    $target = Join-Path -Path $root -ChildPath 'manifest.json'
    if ($PSCmdlet.ShouldProcess($target, 'manifest.json schreiben')) {
        [System.IO.File]::WriteAllText($target, (ConvertTo-Json -InputObject $manifest -Depth 6), $script:Utf8NoBom)
    }
    return $target
}
#endregion

#region Schritte
function Get-RepoIso {
    <#
    .SYNOPSIS
        Liefert den ISO-Pfad: vorhandenes ISO oder Download (HEAD, Speicherpruefung, curl mit Retry/Resume, Fallback BITS).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    if ($script:Opt.IsoPath) {
        if (-not (Test-Path -LiteralPath $script:Opt.IsoPath)) { throw ('ISO nicht gefunden: {0}' -f $script:Opt.IsoPath) }
        return [pscustomobject]@{ Path = $script:Opt.IsoPath; Downloaded = $false }
    }
    $leaf = [System.Uri]::UnescapeDataString(([System.Uri]$script:Opt.LofIsoUrl).Segments[-1])
    $dest = Join-Path -Path $script:Opt.TempPath -ChildPath $leaf
    $null = New-Item -Path $script:Opt.TempPath -ItemType Directory -Force
    $proxyOut = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'netsh.exe') -ArgumentList @('winhttp', 'show', 'proxy') -NoLog
    Write-RepoLog -Message ('WinHTTP-Proxy: {0}' -f (($proxyOut.StdOut -replace '\s+', ' ').Trim()))
    $curl = Get-RepoSystemTool -Name 'curl.exe'
    $head = Invoke-RepoNativeCommand -FilePath $curl -ArgumentList @('--head', '--location', '--silent', '--show-error', '--fail', '--max-time', '60', $script:Opt.LofIsoUrl)
    if ($head.ExitCode -ne 0) { throw ('ISO-URL nicht erreichbar (curl {0}): {1}' -f $head.ExitCode, $head.StdErr.Trim()) }
    $lengths = @([regex]::Matches($head.StdOut, '(?im)^content-length:\s*(\d+)') | ForEach-Object { [long]$_.Groups[1].Value })
    $size = 0
    if ($lengths.Count -gt 0) { $size = $lengths[-1] }
    $drive = [System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($dest))
    Write-RepoLog -Message ('ISO {0:N1} GB, frei {1:N1} GB.' -f ($size / 1GB), ($drive.AvailableFreeSpace / 1GB))
    if ($size -gt 0 -and $drive.AvailableFreeSpace -lt [long]($size * 1.2)) { throw 'Nicht genug freier Speicher (ISO + 20 % Puffer).' }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-RepoNativeCommand -FilePath $curl -ArgumentList @('--fail', '--location', '--silent', '--show-error', '--retry', '5', '--retry-delay', '15', '--retry-all-errors', '--connect-timeout', '30', '-C', '-', '--output', $dest, $script:Opt.LofIsoUrl)
    if ($r.ExitCode -ne 0) {
        Write-RepoLog -Level WARN -Message ('curl fehlgeschlagen ({0}): {1} - Fallback BITS.' -f $r.ExitCode, $r.StdErr.Trim())
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
        Import-Module -Name BitsTransfer -ErrorAction Stop
        Start-BitsTransfer -Source $script:Opt.LofIsoUrl -Destination $dest -Priority Foreground -ErrorAction Stop
    }
    $actual = (Get-Item -LiteralPath $dest).Length
    $sec = [Math]::Max($watch.Elapsed.TotalSeconds, 0.1)
    Write-RepoLog -Message ('Download fertig: {0:N1} MB in {1:N0} s ({2:N1} MB/s)' -f ($actual / 1MB), $sec, (($actual / 1MB) / $sec))
    if ($size -gt 0 -and $actual -ne $size) { throw 'ISO-Groesse stimmt nicht mit Content-Length ueberein.' }
    return [pscustomobject]@{ Path = $dest; Downloaded = $true }
}

function Mount-RepoIso {
    <#
    .SYNOPSIS
        Bindet das ISO ein und liefert das Wurzelverzeichnis (Laufwerksbuchstabe oder mountvol-Ordner).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory = $true)][string]$Path)
    $image = Mount-DiskImage -ImagePath $Path -StorageType ISO -PassThru
    $volume = $null
    for ($i = 0; $i -lt 10 -and $null -eq $volume; $i++) {
        $volume = @($image | Get-Volume -ErrorAction SilentlyContinue) | Select-Object -First 1
        if ($null -eq $volume) { Start-Sleep -Seconds 2 }
    }
    if ($null -eq $volume) { throw 'Volume des ISO nicht gefunden.' }
    $letter = [string]$volume.DriveLetter
    $mountFolder = ''
    if ($letter -match '^[A-Za-z]$') { $root = '{0}:\' -f $letter }
    else {
        $mountFolder = Join-Path -Path $script:Opt.TempPath -ChildPath 'isomount'
        $null = New-Item -Path $mountFolder -ItemType Directory -Force
        $r = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'mountvol.exe') -ArgumentList @($mountFolder, [string]$volume.Path)
        if ($r.ExitCode -ne 0) { throw ('mountvol fehlgeschlagen: {0}' -f $r.StdErr) }
        $root = $mountFolder + '\'
    }
    Write-RepoLog -Message ('ISO eingebunden: {0}' -f $root)
    return [pscustomobject]@{ ImagePath = $Path; Root = $root; MountFolder = $mountFolder }
}

function Dismount-RepoIso {
    <#
    .SYNOPSIS
        Haengt das ISO aus.
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Mount)
    if ($null -eq $Mount) { return }
    if ($Mount.MountFolder) { $null = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'mountvol.exe') -ArgumentList @($Mount.MountFolder, '/D') -NoLog }
    try { $null = Dismount-DiskImage -ImagePath $Mount.ImagePath; Write-RepoLog -Message 'ISO ausgehaengt.' }
    catch { Write-RepoLog -Level ERROR -Message ('Dismount fehlgeschlagen: {0}' -f $_.Exception.Message) }
}

function Test-RepoExport {
    <#
    .SYNOPSIS
        Prueft, ob nach dem Export alle Language-FoD-Cabs im Staging liegen.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)][string]$Stage,
        [Parameter(Mandatory = $true)][string[]]$Feature
    )
    $lang = $script:Opt.Language.ToLowerInvariant()
    foreach ($f in @('Basic') + @($Feature | Where-Object { $_ -ne 'Basic' })) {
        $hit = @(Get-ChildItem -LiteralPath $Stage -Recurse -File -Filter ('*LanguageFeatures-{0}-{1}-Package*.cab' -f $f, $lang) -ErrorAction SilentlyContinue)
        if ($hit.Count -eq 0) { Write-RepoLog -Level WARN -Message ('Export unvollstaendig: Language.{0} fehlt.' -f $f); return $false }
    }
    return $true
}

function Invoke-RepoExport {
    <#
    .SYNOPSIS
        Fuehrt export-source (Online/Image) aus, faellt auf die Vollkopie von LanguagesAndOptionalFeatures zurueck.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Stage
    )
    $langCaps = Get-RepoLanguageCapability -TargetLanguage $script:Opt.Language -Feature $script:Opt.Features
    $methods = switch ($script:Opt.ExportMethod) {
        'Auto' { @('Online', 'Image', 'FullCopy') }
        default { @($script:Opt.ExportMethod) }
    }
    $installedSat = @()
    try {
        $installedSat = @(Get-WindowsCapability -Online -LimitAccess | Where-Object { [string]$_.State -eq 'Installed' -and @($script:Opt.SatelliteCapability) -contains $_.Name } | ForEach-Object { $_.Name })
    }
    catch { Write-RepoLog -Level WARN -Message ('Installierte Capabilities nicht ermittelbar: {0}' -f $_.Exception.Message) }
    Write-RepoLog -Message ('Satelliten-FoDs (installiert): {0}' -f $(if ($installedSat.Count -gt 0) { $installedSat -join ', ' } else { 'keine' }))
    $dism = Get-RepoSystemTool -Name 'dism.exe'
    foreach ($method in $methods) {
        if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
        $null = New-Item -Path $Stage -ItemType Directory -Force
        if ($method -eq 'FullCopy') {
            $r = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'robocopy.exe') -ArgumentList @($Source, $Stage, '/E', '/R:3', '/W:10', '/NP', '/NFL', '/NDL', '/MT:8')
            if ($r.ExitCode -ge 8) { throw ('robocopy fehlgeschlagen ({0})' -f $r.ExitCode) }
            Write-RepoLog -Message 'Vollkopie von LanguagesAndOptionalFeatures erstellt (Microsoft: zulaessig, groesser).'
            return 'FullCopy'
        }
        if ($method -eq 'Image' -and [string]::IsNullOrWhiteSpace($script:Opt.ImagePath)) {
            Write-RepoLog -Message 'Export /Image uebersprungen (-ImagePath nicht angegeben).'
            continue
        }
        $target = '/Online'
        $caps = @($langCaps)
        if ($method -eq 'Image') { $target = ('/Image:{0}' -f $script:Opt.ImagePath); $caps += @($script:Opt.SatelliteCapability) }
        else { $caps += $installedSat }
        $dismArgs = @($target, '/Export-Source', ('/Source:{0}' -f $Source.TrimEnd('\')), ('/Target:{0}' -f $Stage)) + @($caps | ForEach-Object { '/CapabilityName:{0}' -f $_ })
        $r = Invoke-RepoNativeCommand -FilePath $dism -ArgumentList $dismArgs
        if ($r.ExitCode -ne 0 -and @($caps).Count -gt @($langCaps).Count) {
            Write-RepoLog -Level WARN -Message ('export-source {0} mit Satelliten fehlgeschlagen ({1}) - erneut nur mit Language-FoDs.' -f $method, $r.ExitCode)
            Remove-Item -LiteralPath $Stage -Recurse -Force
            $null = New-Item -Path $Stage -ItemType Directory -Force
            $dismArgs = @($target, '/Export-Source', ('/Source:{0}' -f $Source.TrimEnd('\')), ('/Target:{0}' -f $Stage)) + @($langCaps | ForEach-Object { '/CapabilityName:{0}' -f $_ })
            $r = Invoke-RepoNativeCommand -FilePath $dism -ArgumentList $dismArgs
        }
        if ($r.ExitCode -eq 0 -and (Test-RepoExport -Stage $Stage -Feature $script:Opt.Features)) {
            Write-RepoLog -Message ('export-source erfolgreich ({0}).' -f $method)
            return ('ExportSource{0}' -f $method)
        }
        Write-RepoLog -Level WARN -Message ('export-source {0} fehlgeschlagen (ExitCode {1}): {2}' -f $method, $r.ExitCode, (($r.StdOut + ' ' + $r.StdErr) -replace '\s+', ' ').Trim())
    }
    throw 'Kein Export-Verfahren erfolgreich.'
}

function Test-RepoSignature {
    <#
    .SYNOPSIS
        Authenticode-Pruefung aller .cab im Staging (gueltig, Signer Microsoft).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory = $true)][string]$Stage)
    $bad = foreach ($f in @(Get-ChildItem -LiteralPath $Stage -Recurse -File -Filter '*.cab')) {
        $sig = Get-AuthenticodeSignature -LiteralPath $f.FullName
        $subject = ''
        if ($null -ne $sig.SignerCertificate) { $subject = $sig.SignerCertificate.Subject }
        if ([string]$sig.Status -ne 'Valid' -or $subject -notmatch 'O=Microsoft Corporation') { '{0}: {1} {2}' -f $f.Name, $sig.Status, $subject }
    }
    return [string[]]@($bad)
}

function Connect-RepoShare {
    <#
    .SYNOPSIS
        Verbindet ein UNC-Ziel temporaer (New-SmbMapping, Fallback net use /persistent:no).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory = $true)][string]$UncPath)
    if ($UncPath -notmatch '^\\\\([^\\]+)\\([^\\]+)') { return $null }
    $hostName = $Matches[1]
    $root = '\\{0}\{1}' -f $Matches[1], $Matches[2]
    $conn = [pscustomobject]@{ Root = $root; HostName = $hostName; Method = 'None' }
    if ([string]::IsNullOrEmpty($script:Opt.StorageAccountKey)) { return $conn }
    $user = 'localhost\{0}' -f $hostName.Split('.')[0]
    try {
        $null = New-SmbMapping -RemotePath $root -UserName $user -Password $script:Opt.StorageAccountKey -Persistent $false -ErrorAction Stop
        $conn.Method = 'SmbMapping'
    }
    catch {
        Write-RepoLog -Level WARN -Message ('New-SmbMapping fehlgeschlagen - Fallback net use: {0}' -f $_.Exception.Message)
        $r = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'net.exe') -ArgumentList @('use', $root, $script:Opt.StorageAccountKey, ('/user:{0}' -f $user), '/persistent:no') -NoLog
        if ($r.ExitCode -ne 0) { throw ('net use fehlgeschlagen ({0})' -f $r.ExitCode) }
        $conn.Method = 'NetUse'
    }
    Write-RepoLog -Message ('Share verbunden ({0}): {1}' -f $conn.Method, $root)
    return $conn
}

function Disconnect-RepoShare {
    <#
    .SYNOPSIS
        Trennt die Verbindung und entfernt cmdkey-Eintraege fuer den Host.
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Connection)
    if ($null -eq $Connection) { return }
    try { Remove-SmbMapping -RemotePath $Connection.Root -Force -UpdateProfile -ErrorAction Stop } catch { Write-RepoLog -Message ('Remove-SmbMapping: {0}' -f $_.Exception.Message) }
    $null = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'net.exe') -ArgumentList @('use', $Connection.Root, '/delete', '/y') -NoLog
    $list = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'cmdkey.exe') -ArgumentList @('/list') -NoLog
    foreach ($m in [regex]::Matches($list.StdOut, '(?im)target=(\S+)')) {
        if ($m.Groups[1].Value -like ('*{0}*' -f $Connection.HostName)) {
            $null = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'cmdkey.exe') -ArgumentList @(('/delete:{0}' -f $m.Groups[1].Value)) -NoLog
        }
    }
    Write-RepoLog -Message ('Share getrennt: {0}' -f $Connection.Root)
}

function Send-RepoZipToBlob {
    <#
    .SYNOPSIS
        Laedt das ZIP in einen Blob-Container (azcopy, sonst curl.exe als Bordmittel). SAS wird nie geloggt.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$ZipPath,
        [Parameter(Mandatory = $true)][string]$BlobName
    )
    $sas = $script:Opt.UploadBlobContainerSasUrl
    $q = $sas.IndexOf('?')
    if ($q -lt 0) { throw 'Container-SAS-URL ohne Query (SAS) angegeben.' }
    $blobUrl = '{0}/{1}{2}' -f $sas.Substring(0, $q).TrimEnd('/'), $BlobName, $sas.Substring($q)
    Add-RepoSecret -Value $blobUrl
    $azcopy = $script:Opt.AzCopyPath
    if (-not $azcopy) {
        $cmd = Get-Command -Name 'azcopy.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $cmd) { $azcopy = $cmd.Source }
    }
    if ($azcopy -and (Test-Path -LiteralPath $azcopy)) {
        $r = Invoke-RepoNativeCommand -FilePath $azcopy -ArgumentList @('copy', $ZipPath, $blobUrl, '--overwrite=true') -NoLog
        if ($r.ExitCode -ne 0) { throw ('azcopy fehlgeschlagen ({0}): {1}' -f $r.ExitCode, (Get-RepoMaskedText -Text $r.StdOut)) }
    }
    else {
        if ((Get-Item -LiteralPath $ZipPath).Length -gt 5000MB) { throw 'ZIP groesser als 5000 MiB: azcopy erforderlich (-AzCopyPath).' }
        $r = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'curl.exe') -ArgumentList @('--fail', '--silent', '--show-error', '--retry', '3', '-X', 'PUT', '-H', 'x-ms-blob-type: BlockBlob', '-H', 'x-ms-version: 2021-08-06', '-T', $ZipPath, $blobUrl) -NoLog
        if ($r.ExitCode -ne 0) { throw ('Upload per curl fehlgeschlagen ({0}): {1}' -f $r.ExitCode, (Get-RepoMaskedText -Text $r.StdErr)) }
    }
    $plain = $blobUrl.Substring(0, $blobUrl.IndexOf('?'))
    Write-RepoLog -Message ('ZIP hochgeladen: {0}' -f $plain)
    return $plain
}
#endregion

#region Hauptablauf
function Invoke-RepoMain {
    <#
    .SYNOPSIS
        Hauptablauf des Repository-Aufbaus. Setzt $script:RepoExitCode (0 = OK, 1 = Fehler).
    #>
    [CmdletBinding()]
    param()
    Add-RepoSecret -Value $script:Opt.StorageAccountKey
    Add-RepoSecret -Value $script:Opt.UploadBlobContainerSasUrl
    if (-not (Test-Path -LiteralPath $script:Opt.LogRoot)) { $null = New-Item -Path $script:Opt.LogRoot -ItemType Directory -Force }
    $script:LogFile = Join-Path -Path $script:Opt.LogRoot -ChildPath ('{0}_CDT-LanguageRepository_{1}.log' -f $env:COMPUTERNAME, $script:RunTimestamp)
    $script:ErrorLogFile = Join-Path -Path $script:Opt.LogRoot -ChildPath ('{0}_CDT-LanguageRepository_Error-Log_{1}.log' -f $env:COMPUTERNAME, $script:RunTimestamp)
    foreach ($f in @($script:LogFile, $script:ErrorLogFile)) { [System.IO.File]::WriteAllBytes($f, $script:Utf8Bom.GetPreamble()) }
    $transcript = $false
    try { $null = Start-Transcript -Path (Join-Path -Path $script:Opt.LogRoot -ChildPath ('{0}_CDT-LanguageRepository_Transcript_{1}.log' -f $env:COMPUTERNAME, $script:RunTimestamp)) -Force; $transcript = $true }
    catch { Write-RepoLog -Level WARN -Message ('Start-Transcript: {0}' -f $_.Exception.Message) }

    $exitCode = 1
    $iso = $null
    $mount = $null
    $conn = $null
    $stage = Join-Path -Path $script:Opt.TempPath -ChildPath 'stage'
    try {
        Write-RepoLog -Message ('##### New-CDTLanguageRepository v{0} | Sprache {1} | Ziel {2} #####' -f $script:Version, $script:Opt.Language, $script:Opt.RepositoryRoot)
        $principal = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administratorrechte erforderlich.' }
        if (-not (Test-RepoSafeTempPath -Path $script:Opt.TempPath)) { $script:Opt.TempPath = ''; throw '-TempPath ist nicht sicher loeschbar.' }
        if ($script:Opt.UploadBlobContainerSasUrl -and -not $script:Opt.CreateZip) { throw '-UploadBlobContainerSasUrl erfordert -CreateZip.' }

        $iso = Get-RepoIso
        $base = $script:Opt.OsBaseBuild
        if ($base -le 0) { $base = Get-RepoIsoBuildFromName -Name $iso.Path }
        $mount = Mount-RepoIso -Path $iso.Path
        $lof = Join-Path -Path $mount.Root -ChildPath 'LanguagesAndOptionalFeatures'
        if (-not (Test-Path -LiteralPath $lof)) { throw 'LanguagesAndOptionalFeatures im ISO nicht gefunden.' }
        $lpName = 'Microsoft-Windows-Client-Language-Pack_x64_{0}.cab' -f $script:Opt.Language.ToLowerInvariant()
        $lpSource = Join-Path -Path $lof -ChildPath $lpName
        if (-not (Test-Path -LiteralPath $lpSource)) { throw ('Sprachpaket nicht im ISO: {0}' -f $lpName) }
        $lpInfo = @(Get-WindowsPackage -Online -PackagePath $lpSource)
        $lpBuild = 0
        if ($lpInfo.Count -gt 0) { $lpBuild = [int]((($lpInfo[0].PackageName -split '~')[-1]).Split('.')[2]) }
        if ($base -le 0) { $base = $lpBuild }
        if ($lpBuild -gt 0 -and $lpBuild -ne $base) { throw ('Sprachpaket-Build {0} passt nicht zum Hauptbuild {1}.' -f $lpBuild, $base) }
        if ($base -le 0) { throw 'OS-Hauptbuild nicht ermittelbar (-OsBaseBuild angeben).' }
        Write-RepoLog -Message ('OS-Hauptbuild des Repositorys: {0} (Sprachpaket-Build {1})' -f $base, $lpBuild)

        $exportMethod = Invoke-RepoExport -Source $lof -Stage $stage
        if (-not (Test-Path -LiteralPath (Join-Path -Path $stage -ChildPath $lpName))) {
            Copy-Item -LiteralPath $lpSource -Destination $stage -Force
            Write-RepoLog -Message ('Sprachpaket kopiert: {0}' -f $lpName)
        }
        $winPeIncluded = $false
        if ($script:Opt.IncludeWinPE) {
            $winPeSrc = Join-Path -Path $mount.Root -ChildPath ('Windows Preinstallation Environment\x64\WinPE_OCs\{0}' -f $script:Opt.Language.ToLowerInvariant())
            if (Test-Path -LiteralPath $winPeSrc) {
                $winPeDst = Join-Path -Path $stage -ChildPath ('WinPE_OCs\{0}' -f $script:Opt.Language.ToLowerInvariant())
                $null = New-Item -Path $winPeDst -ItemType Directory -Force
                Copy-Item -Path (Join-Path -Path $winPeSrc -ChildPath '*') -Destination $winPeDst -Recurse -Force
                $winPeIncluded = $true
                Write-RepoLog -Message 'WinPE-Sprachpakete (WinRE) uebernommen.'
            }
            else { Write-RepoLog -Level WARN -Message ('WinPE-Sprachpakete nicht im ISO: {0}' -f $winPeSrc) }
        }
        $bad = @(Test-RepoSignature -Stage $stage)
        if ($bad.Count -gt 0) {
            foreach ($b in $bad) { Write-RepoLog -Level ERROR -Message ('Signatur: {0}' -f $b) }
            throw 'Authenticode-Pruefung fehlgeschlagen.'
        }
        Write-RepoLog -Message 'Authenticode-Pruefung aller .cab: OK.'
        $isoHash = (Get-FileHash -LiteralPath $iso.Path -Algorithm SHA256).Hash
        $meta = [ordered]@{
            schemaVersion       = 1
            osBaseBuild         = [string]$base
            language            = $script:Opt.Language
            sourceIso           = [ordered]@{ name = (Split-Path -Path $iso.Path -Leaf); sha256 = $isoHash }
            createdUtc          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            createdBy           = ('New-CDTLanguageRepository.ps1 {0}' -f $script:Version)
            createdOn           = $env:COMPUTERNAME
            exportMethod        = $exportMethod
            capabilities        = @(Get-RepoLanguageCapability -TargetLanguage $script:Opt.Language -Feature $script:Opt.Features)
            includesWinPE       = $winPeIncluded
        }
        $null = New-RepoManifest -Path $stage -Metadata $meta
        $fileCount = @(Get-ChildItem -LiteralPath $stage -Recurse -File).Count
        $sizeMb = (@(Get-ChildItem -LiteralPath $stage -Recurse -File) | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-RepoLog -Message ('manifest.json erstellt: {0} Dateien, {1:N1} MB' -f $fileCount, $sizeMb)

        $conn = Connect-RepoShare -UncPath $script:Opt.RepositoryRoot
        $buildFolder = Join-Path -Path $script:Opt.RepositoryRoot -ChildPath ([string]$base)
        if (-not (Test-Path -LiteralPath $buildFolder)) { $null = New-Item -Path $buildFolder -ItemType Directory -Force }
        $versionName = Get-RepoVersionFolderName -BuildFolder $buildFolder -TargetLanguage $script:Opt.Language -Date (Get-Date)
        $versionFolder = Join-Path -Path $buildFolder -ChildPath $versionName
        $r = Invoke-RepoNativeCommand -FilePath (Get-RepoSystemTool -Name 'robocopy.exe') -ArgumentList @($stage, $versionFolder, '/E', '/R:3', '/W:10', '/NP', '/NFL', '/NDL', '/MT:8')
        if ($r.ExitCode -ge 8) { throw ('robocopy ins Ziel fehlgeschlagen ({0})' -f $r.ExitCode) }
        Write-RepoLog -Message ('Repository abgelegt: {0}' -f $versionFolder)

        $blobPlain = ''
        if ($script:Opt.CreateZip) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = Join-Path -Path $script:Opt.TempPath -ChildPath ('{0}.zip' -f $versionName)
            if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
            [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
            Copy-Item -LiteralPath $zip -Destination $buildFolder -Force
            Write-RepoLog -Message ('ZIP erstellt: {0}' -f (Join-Path -Path $buildFolder -ChildPath (Split-Path -Path $zip -Leaf)))
            if ($script:Opt.UploadBlobContainerSasUrl) {
                $blobPlain = Send-RepoZipToBlob -ZipPath $zip -BlobName ('{0}/{1}' -f $base, (Split-Path -Path $zip -Leaf))
            }
        }
        Write-Output '==================== CDT Sprach-Repository ===================='
        Write-Output ('Version   : {0}' -f $versionFolder)
        Write-Output ('Build     : {0}, Sprache {1}, Export {2}, Dateien {3}, {4:N1} MB' -f $base, $script:Opt.Language, $exportMethod, $fileCount, $sizeMb)
        Write-Output ('Stufe 2   : -RepositoryPath "{0}"' -f $buildFolder)
        if ($blobPlain) { Write-Output ('Stufe 2   : -RepositoryZipUrl "{0}?<Lese-SAS>"' -f $blobPlain) }
        Write-Output ('Log       : {0}' -f $script:LogFile)
        $exitCode = 0
    }
    catch {
        Write-RepoLog -Level ERROR -Message ('FEHLER: {0} | Typ={1} | HRESULT=0x{2:X8} | Zeile={3}' -f $_.Exception.Message, $_.Exception.GetType().FullName, $_.Exception.HResult, $_.InvocationInfo.ScriptLineNumber)
        Write-RepoLog -Level ERROR -Message ([string]$_.ScriptStackTrace)
        Write-Output ('FEHLER: {0} - siehe {1}' -f (Get-RepoMaskedText -Text $_.Exception.Message), $script:ErrorLogFile)
    }
    finally {
        Disconnect-RepoShare -Connection $conn
        Dismount-RepoIso -Mount $mount
        if ($null -ne $iso -and $iso.Downloaded -and -not $script:Opt.KeepIso -and (Test-Path -LiteralPath $iso.Path)) {
            Remove-Item -LiteralPath $iso.Path -Force -ErrorAction SilentlyContinue
        }
        if ($script:Opt.TempPath -and (Test-RepoSafeTempPath -Path $script:Opt.TempPath) -and (Test-Path -LiteralPath $script:Opt.TempPath)) {
            $userIso = ''
            if ($script:Opt.IsoPath) { $userIso = [System.IO.Path]::GetFullPath($script:Opt.IsoPath) }
            Get-ChildItem -LiteralPath $script:Opt.TempPath -Force |
                Where-Object { -not ($script:Opt.KeepIso -and $_.Extension -eq '.iso') -and $_.FullName -ne $userIso } |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-RepoLog -Message ('Ende: ExitCode {0}, Dauer {1:N1} min' -f $exitCode, ((Get-Date) - $script:RunStart).TotalMinutes)
        if ($transcript) { try { $null = Stop-Transcript } catch { Write-RepoLog -Level WARN -Message 'Stop-Transcript fehlgeschlagen.' } }
    }
    $script:RepoExitCode = $exitCode
}
#endregion

if ($env:CDT_LANG_SKIP_MAIN -ne '1') {
    $script:RepoExitCode = 1
    Invoke-RepoMain
    exit $script:RepoExitCode
}
