# Gemeinsame Hilfen fuer die Pester-Tests (Entwicklungspruefung, fuer den Betrieb nicht erforderlich).
# Laedt alle Funktionen/Konstanten des Scripts OHNE den Einstiegspunkt auszufuehren.

$script:CdtRepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:CdtScriptPath = Join-Path $script:CdtRepoRoot 'CDT-STANDARD-INSTALL-DE_LANG.ps1'

function Get-CdtLibraryText {
    $text = [System.IO.File]::ReadAllText($script:CdtScriptPath)
    $idx = $text.IndexOf('# --- CDT-ENTRYPOINT')
    if ($idx -lt 0) { throw 'Einstiegspunkt-Markierung nicht gefunden' }
    return $text.Substring(0, $idx)
}

function New-TestCdtContext {
    # Initialisiert $Cdt fuer Funktionstests (Log-Verzeichnis im Testlaufwerk)
    param([string]$Root, [hashtable]$Config = @{})
    $Cdt.Clear()
    $resolved = Resolve-CdtConfiguration -ArgumentList @()
    $Cdt.Config = $resolved.Config
    $Cdt.Config.LogRoot = $Root
    foreach ($k in $Config.Keys) { $Cdt.Config[$k] = $Config[$k] }
    $Cdt.Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $Cdt.StartTime = [DateTimeOffset]::Now
    $Cdt.RunId = New-CdtRunId
    $Cdt.Seq = 0
    $Cdt.VmName = 'TESTVM'
    $Cdt.VmNameSource = 'Test'
    $Cdt.EffectiveMode = $Cdt.Config.Mode
    $Cdt.ChangesThisRun = New-Object System.Collections.ArrayList
    $Cdt.Network = [ordered]@{ Performed = $false; Results = (New-Object System.Collections.ArrayList) }
    $Cdt.Warnings = New-Object System.Collections.ArrayList
    $Cdt.Errors = New-Object System.Collections.ArrayList
    $Cdt.Context = [ordered]@{ Identity = 'TEST\runner'; Sid = 'S-1-5-18'; SourceHiveName = '.DEFAULT' }
    $Cdt.Platform = [ordered]@{ LastBootUtc = '2026-10-03T10:00:00Z'; SmbiosUuid = 'UUID-TEST-1'; InstallDateUtc = '2026-01-01T00:00:00.000Z'; Architecture = 'AMD64'; InstallLanguageTag = 'en-US' }
    $Cdt.WinHttp = [ordered]@{ Available = $false; Mode = 'Direct'; Proxy = ''; Bypass = ''; Wpad = [ordered]@{ Tested = $false; Found = $false; Proxy = ''; Error = '' }; Error = 'Test' }
    $CdtSecretValues.Clear()
    $CdtEarlyLog.Clear()
    if (-not (Initialize-CdtLogging)) { throw ('Logging-Initialisierung im Test fehlgeschlagen: {0}' -f $Cdt.Log.Error) }
    $Cdt.StatePath = Join-Path $Cdt.Log.StateDir 'CDT-STANDARD-INSTALL-DE_LANG.state.json'
    $Cdt.State = New-CdtEmptyState
    $Cdt.State.machineBinding = Get-CdtMachineBinding
}

function Start-CdtTestServer {
    # Startet tests/helpers/testserver.py und liefert Prozess + Port
    param([string]$Mode, [long]$Size = 1048576, [string[]]$Extra = @())
    $out = [System.IO.Path]::GetTempFileName()
    $argList = @((Join-Path $PSScriptRoot 'testserver.py'), $Mode, [string]$Size) + $Extra
    $p = Start-Process -FilePath 'python3' -ArgumentList $argList -RedirectStandardOutput $out -PassThru -NoNewWindow
    $port = $null
    for ($i = 0; $i -lt 100 -and $null -eq $port; $i++) {
        Start-Sleep -Milliseconds 100
        $line = Get-Content -LiteralPath $out -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($line -match '^READY (\d+)') { $port = [int]$Matches[1] }
    }
    if ($null -eq $port) { try { $p.Kill() } catch { }; throw ('Testserver {0} nicht gestartet' -f $Mode) }
    return [pscustomobject]@{ Process = $p; Port = $port; Mode = $Mode }
}

function Stop-CdtTestServer {
    param($Server)
    if ($null -ne $Server -and $null -ne $Server.Process -and -not $Server.Process.HasExited) { try { $Server.Process.Kill() } catch { } }
}
