<#
.SYNOPSIS
    Erzeugt Install-DE_V8_Loader.ps1 aus Install-DE_V8.ps1 (Entwicklerwerkzeug, nicht fuer Zielsysteme).

.DESCRIPTION
    Der Loader ist ein einzelnes, eigenstaendiges Script fuer Nerdio/HYDRA ohne Internetzugang:
    Er enthaelt Install-DE_V8.ps1 GZip-komprimiert als Base64 und denselben Param-Block. Beim Lauf schreibt er
    die Datei in einen Ordner, den nur SYSTEM und Administratoren aendern koennen, prueft SHA256 und startet
    sie mit den uebergebenen Parametern.

    Nach jeder Aenderung an Install-DE_V8.ps1 neu erzeugen. Der Pester-Test "Offline-Loader" schlaegt sonst fehl.

.PARAMETER SourcePath
    Pfad zu Install-DE_V8.ps1. Default: Repository-Wurzel.

.PARAMETER OutputPath
    Zielpfad des Loaders. Default: Install-DE_V8_Loader.ps1 in der Repository-Wurzel.

.EXAMPLE
    .\tools\Build-InstallDE_V8Loader.ps1
#>
[CmdletBinding()]
param(
    [string]$SourcePath = '',
    [string]$OutputPath = ''
)

$script:LoaderLineLength = 120

function Get-CDTParamBlockText {
    <#
    .SYNOPSIS
        Liefert Attribute + Param-Block eines Scripts als Text sowie die Parameternamen (per AST).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory = $true)][string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw ('Parserfehler in {0}: {1}' -f $Path, $errors[0].Message) }
    $block = $ast.ParamBlock
    if ($null -eq $block) { throw ('Kein Param-Block in {0}.' -f $Path) }
    $start = $block.Extent.StartOffset
    if (@($block.Attributes).Count -gt 0) { $start = [Math]::Min($start, $block.Attributes[0].Extent.StartOffset) }
    $text = $ast.Extent.Text.Substring($start, $block.Extent.EndOffset - $start)
    return [pscustomobject]@{
        Text  = $text -replace "`r`n", "`n"
        Names = @($block.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    }
}

function ConvertTo-CDTGzipBase64 {
    <#
    .SYNOPSIS
        Komprimiert Bytes (GZip) und liefert Base64 in Zeilen fester Laenge.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [int]$LineLength = $script:LoaderLineLength
    )
    $buffer = [System.IO.MemoryStream]::new()
    $gzip = [System.IO.Compression.GZipStream]::new($buffer, [System.IO.Compression.CompressionLevel]::Optimal, $true)
    try { $gzip.Write($Bytes, 0, $Bytes.Length) } finally { $gzip.Dispose() }
    $b64 = [System.Convert]::ToBase64String($buffer.ToArray())
    $buffer.Dispose()
    $lines = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $b64.Length; $i += $LineLength) { $lines.Add($b64.Substring($i, [Math]::Min($LineLength, $b64.Length - $i))) }
    return ($lines -join "`n")
}

function ConvertFrom-CDTGzipBase64 {
    <#
    .SYNOPSIS
        Gegenstueck zu ConvertTo-CDTGzipBase64 (fuer Tests und Pruefungen).
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param([Parameter(Mandatory = $true)][string]$Payload)
    $bytes = [System.Convert]::FromBase64String(($Payload -replace '\s', ''))
    $inStream = [System.IO.MemoryStream]::new($bytes)
    $gzip = [System.IO.Compression.GZipStream]::new($inStream, [System.IO.Compression.CompressionMode]::Decompress)
    $outStream = [System.IO.MemoryStream]::new()
    try { $gzip.CopyTo($outStream) } finally { $gzip.Dispose(); $inStream.Dispose() }
    $result = $outStream.ToArray()
    $outStream.Dispose()
    Write-Output -InputObject $result -NoEnumerate
}

function ConvertTo-CDTLoaderScript {
    <#
    .SYNOPSIS
        Setzt den Loader-Text aus Vorlage, Param-Block, Payload, Hash und Version zusammen (reine Funktion).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$ParamBlock,
        [Parameter(Mandatory = $true)][string[]]$ParamName,
        [Parameter(Mandatory = $true)][string]$Payload,
        [Parameter(Mandatory = $true)][string]$Sha256,
        [Parameter(Mandatory = $true)][string]$Version
    )
    # Vorlage: __HEREEND__ steht fuer das Ende des inneren Here-Strings (sonst endet diese Vorlage dort).
    $template = @'
#description: CDT STANDARD Install-DE_V8 (Offline-Loader) - ein Script, kein Internet fuer das Script noetig: enthaelt Install-DE_V8.ps1 v__VERSION__ vollstaendig, erstellt es lokal, prueft SHA256 und startet es. Ohne Parameter (Mode Auto) nach jedem Neustart erneut ausfuehren, bis SUCCESS.
#execution mode: Individual
#tags: CDT, Language, de-DE, AVD, Image
# Erzeugt mit tools/Build-InstallDE_V8Loader.ps1 - nicht von Hand aendern.
# Inhalt: Install-DE_V8.ps1 v__VERSION__, SHA256 __SHA256__
# Parameter: identisch zu Install-DE_V8.ps1 (Beschreibung dort bzw. README), werden unveraendert weitergereicht.
__PARAMBLOCK__

# Parameter werden ueber $PSBoundParameters weitergereicht; diese Zeile markiert sie als verwendet.
$null = @(__PARAMREFS__)

$cdtVersion = '__VERSION__'
$cdtSha256 = '__SHA256__'
$cdtDir = Join-Path -Path $env:ProgramData -ChildPath 'CDT-LanguageDeployment'
$cdtFile = Join-Path -Path $cdtDir -ChildPath 'Install-DE_V8.ps1'
$cdtPayload = @'
__PAYLOAD__
__HEREEND__

try {
    $cdtPrincipal = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $cdtPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administratorrechte bzw. SYSTEM erforderlich - keine Aenderungen vorgenommen.'
    }
    # Eigener Ordner direkt unter ProgramData, nur fuer SYSTEM und Administratoren: Das Script laeuft als SYSTEM
    # und darf nicht von Standardbenutzern ausgetauscht werden (auch nicht ueber vorab angelegte Ordner/Dateien).
    $cdtTrusted = @('S-1-5-18', 'S-1-5-32-544')
    if (Test-Path -LiteralPath $cdtDir) {
        $cdtOwner = (Get-Acl -LiteralPath $cdtDir).GetOwner([System.Security.Principal.SecurityIdentifier]).Value
        if ($cdtTrusted -notcontains $cdtOwner) { Remove-Item -LiteralPath $cdtDir -Recurse -Force -ErrorAction Stop }
    }
    $null = New-Item -Path $cdtDir -ItemType Directory -Force -ErrorAction Stop
    $cdtAcl = [System.Security.AccessControl.DirectorySecurity]::new()
    $cdtAcl.SetAccessRuleProtection($true, $false)
    foreach ($cdtSid in $cdtTrusted) {
        $cdtRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            [System.Security.Principal.SecurityIdentifier]::new($cdtSid),
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow)
        $cdtAcl.AddAccessRule($cdtRule)
    }
    (Get-Item -LiteralPath $cdtDir -ErrorAction Stop).SetAccessControl($cdtAcl)
    if (Test-Path -LiteralPath $cdtFile) { Remove-Item -LiteralPath $cdtFile -Force -ErrorAction Stop }

    $cdtBytes = [System.Convert]::FromBase64String(($cdtPayload -replace '\s', ''))
    $cdtIn = [System.IO.MemoryStream]::new($cdtBytes)
    $cdtGzip = [System.IO.Compression.GZipStream]::new($cdtIn, [System.IO.Compression.CompressionMode]::Decompress)
    $cdtOut = [System.IO.MemoryStream]::new()
    try { $cdtGzip.CopyTo($cdtOut) } finally { $cdtGzip.Dispose(); $cdtIn.Dispose() }
    [System.IO.File]::WriteAllBytes($cdtFile, $cdtOut.ToArray())
    $cdtOut.Dispose()

    $cdtHash = (Get-FileHash -LiteralPath $cdtFile -Algorithm SHA256 -ErrorAction Stop).Hash
    if ($cdtHash -ne $cdtSha256) { throw ('SHA256 stimmt nicht ({0}) - Loader beschaedigt oder unvollstaendig kopiert.' -f $cdtHash) }
    Write-Output ('Loader: {0} erstellt (v{1}, {2} Bytes, SHA256 geprueft).' -f $cdtFile, $cdtVersion, (Get-Item -LiteralPath $cdtFile).Length)
}
catch {
    Write-Output ('Loader: FEHLER {0}' -f $_.Exception.Message)
    exit 3050
}

$cdtExit = 3050
try {
    & $cdtFile @PSBoundParameters
    if ($null -ne $LASTEXITCODE) { $cdtExit = $LASTEXITCODE }
}
catch {
    Write-Output ('Loader: FEHLER beim Start von Install-DE_V8.ps1: {0}' -f $_.Exception.Message)
}
Write-Output ('Loader: Install-DE_V8.ps1 beendet mit ExitCode {0}' -f $cdtExit)
exit $cdtExit
'@
    $refs = ($ParamName | ForEach-Object { '$' + $_ }) -join ', '
    $text = ($template -replace "`r`n", "`n")
    $text = $text.Replace('__PARAMBLOCK__', $ParamBlock).Replace('__PARAMREFS__', $refs).Replace('__PAYLOAD__', $Payload)
    $text = $text.Replace('__SHA256__', $Sha256).Replace('__VERSION__', $Version).Replace('__HEREEND__', "'@")
    return $text + "`n"
}

function New-CDTEmbeddedLoader {
    <#
    .SYNOPSIS
        Liest Install-DE_V8.ps1 und schreibt den Loader (ASCII, LF).
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )
    $source = (Resolve-Path -LiteralPath $SourcePath).Path
    $bytes = [System.IO.File]::ReadAllBytes($source)
    $content = [System.Text.Encoding]::ASCII.GetString($bytes)
    $match = [regex]::Match($content, "(?m)^\`$script:ScriptVersion = '([0-9.]+)'")
    if (-not $match.Success) { throw 'ScriptVersion in Install-DE_V8.ps1 nicht gefunden.' }
    $param = Get-CDTParamBlockText -Path $source
    $sha = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    $text = ConvertTo-CDTLoaderScript -ParamBlock $param.Text -ParamName $param.Names -Payload (ConvertTo-CDTGzipBase64 -Bytes $bytes) -Sha256 $sha -Version $match.Groups[1].Value
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Loader schreiben')) {
        [System.IO.File]::WriteAllText($OutputPath, $text, [System.Text.Encoding]::ASCII)
    }
    return [pscustomobject]@{ Path = $OutputPath; Version = $match.Groups[1].Value; Sha256 = $sha; Length = $text.Length }
}

if ($env:CDT_LANG_SKIP_MAIN -ne '1') {
    $root = Split-Path -Parent $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($SourcePath)) { $SourcePath = Join-Path -Path $root -ChildPath 'Install-DE_V8.ps1' }
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path -Path $root -ChildPath 'Install-DE_V8_Loader.ps1' }
    New-CDTEmbeddedLoader -SourcePath $SourcePath -OutputPath $OutputPath
}
