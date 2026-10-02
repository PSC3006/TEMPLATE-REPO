
####################################################################   BEGIN INDIVIDUAL SCRIPT ######################################################################
# Version: 3.1 - 02.10.2026
#description: v3.1 - de-DE Sprachpaket inkl. Sprachfeatures maschinenweit installieren und als Standard setzen (Win11 25H2+, NERDIO/SYSTEM oder Admin)
#
# Aenderungen v3.1 ("laeuft durch, installiert aber nicht verlaesslich"):
#  - Erfolg = Language Pack UND Pflicht-Features (Basic/Rechtschreibung, Handschrift, OCR, Sprachausgabe,
#    Spracherkennung). v3 pruefte nur das Language Pack: fehlende Features blieben unbemerkt und wurden
#    wegen des Idempotenz-Checks auch bei weiteren Laeufen nie nachinstalliert.
#  - Fehlende Features werden gezielt per Add-WindowsCapability nachinstalliert.
#  - Nach Copy-UserInternationalSettingsToSystem wird das Ergebnis in HKU\.DEFAULT (Welcome Screen) und im
#    Default-User-Profil (neue Benutzer) geprueft: Regionalformat, Datum/Uhrzeit, Region, Sprachliste.
#    Bei Abweichung: Fallback intl.cpl, danach direkte Registry-Kopie; sonst Abbruch statt "Erfolg".
#  - Sprachliste standardmaessig nur de-DE (kein en-US-Tastaturlayout fuer neue Benutzer), deutsche
#    Tastatur als Standard-Eingabemethode.
#
# Aenderungen v3.0:
#
# Aenderungen v3 (Ursachen der unzuverlaessigen Laeufe in v2):
#  - Tasks LanguageComponentsInstaller\Installation + ReconcileLanguageResources werden WAEHREND der
#    Installation deaktiviert und danach wieder aktiviert (MS-Bug ERROR_SHARING_VIOLATION, vgl.
#    Azure/RDS-Templates InstallLanguagePacks.ps1). v2 hat ReconcileLanguageResources dauerhaft deaktiviert.
#  - Erfolgspruefung akzeptiert "installiert, Reboot ausstehend". v2 verlangte den MUI-Schluessel, der
#    teils erst nach dem Neustart existiert -> Fehlalarm, 3 unnoetige Versuche, Abbruch.
#  - SYSTEM-Erkennung per SID statt Kontoname (auf deutschem OS heisst es "NT-AUTORITAET\SYSTEM").
#  - Set-Service auf geschuetzte Dienste (DoSvc) bricht das Script nicht mehr ab.
#  - Servicing-Policy UseWindowsUpdate=2 ("nie von WU laden", Ursache 0x800F0954) wird temporaer entfernt.
#  - Nach Timeout wird auf Ende der laufenden CBS-Operation gewartet statt parallel neu zu starten;
#    Gesamtbudget bleibt unter dem 90-Min-Limit der Custom Script Extension.
#  - Deutsch als Standard fuer System, Welcome Screen und neue Benutzer (Set-SystemPreferredUILanguage
#    + Copy-UserInternationalSettingsToSystem). v2 setzte Welcome Screen/SYSTEM bewusst auf en-US.
#  - Fehler werden vor dem Abbruch ins Log geschrieben (v2: erst nach Stop-Transcript -> fehlte im Log).

# ---------------------------------------------------------------- Logging-Header
$scriptName = "CDT_Install_German_Language"
$logFileName = $scriptName + ".log"
$savedVerbosePreference = $VerbosePreference
$VerbosePreference = "Continue"
$savedErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop"
$savedProgressPreference = $ProgressPreference
$ProgressPreference = "SilentlyContinue"        # kein Fortschrittsbalken im nicht-interaktiven Host
$logTime = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
$logFolder = New-Item -Path "C:\Windows\Temp\NMWLogs" -ItemType Directory -Name "ScriptedActions" -Force
$tempFolder = New-Item -Path "C:\Windows\Temp" -ItemType Directory -Name $scriptName -Force
$logPath = Join-Path $logFolder.FullName $logFileName

# Transcript darf nicht hart fehlschlagen, wenn ein Wrapper bereits eine Transkription gestartet hat.
$transcriptStarted = $false
try {
    Start-Transcript -Path $logPath -Append | Out-Null
    $transcriptStarted = $true
}
catch {
    Write-Warning ("Start-Transcript nicht moeglich (laeuft evtl. bereits im Wrapper): {0}" -f $_.Exception.Message)
}
Write-Host "################# New Script Run #################"
Write-Host "Current time (UTC-0): $logTime"
Write-Host "Log: $logPath"

# ===== Konfiguration =============================================================
$Language            = 'de-DE'                    # BCP-47 Zielsprache (Anzeige, Formate, Systemgebietsschema)
$GeoId               = 94                         # Deutschland
$TimeZone            = 'W. Europe Standard Time'  # Berlin inkl. Sommerzeit
$KeyboardId          = '0407:00000407'            # de-DE / Deutsch (QWERTZ), Standard-Eingabemethode
$KeepOtherLanguages  = $false                     # $true: vorhandene Sprachen (z. B. en-US) hinter de-DE behalten
# Pflicht-Sprachfeatures (Reihenfolge = Abhaengigkeiten: Basic zuerst, Speech braucht TextToSpeech).
# Bei Bedarf reduzieren, z. B. @('BasicTyping') fuer Hosts ohne Sprach-/Stifteingabe.
$RequiredFeatures    = @('BasicTyping', 'Handwriting', 'OCR', 'TextToSpeech', 'Speech')
$MaxAttempts         = 3
$RetryDelaySec       = 60
$InstallTimeoutMin   = 25                         # Hard-Timeout je Install-Versuch
$ServicingIdleMaxMin = 10                         # nach Timeout: max. Wartezeit auf Ende der CBS-Operation
$InstallBudgetMin    = 70                         # Gesamtbudget Installation (CSE-Limit: 90 Min.)
# =================================================================================

# ---------------------------------------------------------------- Registry-Konstanten
$AUKey        = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
$WUKey        = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$ServicingKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing'
$IntlPolKey   = 'HKLM:\SOFTWARE\Policies\Microsoft\Control Panel\International'
$MuiKey       = 'HKLM:\SYSTEM\CurrentControlSet\Control\MUI\UILanguages'
$DefaultGeoKey= 'Registry::HKEY_USERS\.DEFAULT\Control Panel\International\Geo'

$LciTaskPath  = '\Microsoft\Windows\LanguageComponentsInstaller\'
$DefUserMount = 'HKU\CDT_DefaultUser'

# Get-InstalledLanguage-Feature -> FoD-Capability (Language.<Name>~~~<Sprache>~0.0.1.0)
$FeatureCapMap = @{ BasicTyping = 'Basic'; Handwriting = 'Handwriting'; OCR = 'OCR'; TextToSpeech = 'TextToSpeech'; Speech = 'Speech' }

# Merker fuer garantierte Wiederherstellung im finally-Block
$RegRestore   = New-Object System.Collections.ArrayList   # @{Path;Name;Value}  Value $null = war nicht gesetzt
$SvcRestore   = New-Object System.Collections.ArrayList   # @{Name;StartType}
$TaskReenable = New-Object System.Collections.ArrayList   # Tasknamen unter $LciTaskPath

# ================================================================ Hilfsfunktionen
function Set-PolicyValueTemporarily {
    # Setzt einen DWORD-Policy-Wert (bzw. entfernt ihn bei $DesiredValue = $null) und merkt sich den
    # Originalzustand fuer das Rollback im finally-Block. -OnlyIfPresent: nur aendern, wenn gesetzt.
    param([string]$Path, [string]$Name, $DesiredValue, [switch]$OnlyIfPresent)
    $cur = $null
    if (Test-Path $Path) { $cur = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name }
    if ($OnlyIfPresent -and $null -eq $cur) { return }
    if ($null -eq $DesiredValue) { if ($null -eq $cur) { return } }
    elseif ($null -ne $cur -and [int]$cur -eq [int]$DesiredValue) { return }

    $curText = if ($null -eq $cur) { '<nicht gesetzt>' } else { $cur }
    $newText = if ($null -eq $DesiredValue) { '<entfernt>' } else { $DesiredValue }
    Write-Host ("Policy-Bypass: {0}\{1} : {2} -> {3}" -f $Path, $Name, $curText, $newText)
    [void]$RegRestore.Add(@{ Path = $Path; Name = $Name; Value = $cur })
    if ($null -eq $DesiredValue) {
        Remove-ItemProperty -Path $Path -Name $Name
    }
    else {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value ([int]$DesiredValue) -Type DWord
    }
}

function Enable-ServiceTemporarily {
    # Install-Language braucht wuauserv und DoSvc (Delivery Optimization = CDN-Transport).
    # DoSvc ist ein geschuetzter Dienst: Set-Service liefert dort teils "Zugriff verweigert".
    # Das darf das Script NICHT abbrechen (v2: ungefangener Fehler -> Gesamtabbruch).
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Warning ("Dienst {0} nicht vorhanden." -f $Name); return }
    try {
        if ($svc.StartType -eq 'Disabled') {
            Set-Service -Name $Name -StartupType Manual
            [void]$SvcRestore.Add(@{ Name = $Name; StartType = 'Disabled' })
            Write-Host ("Dienst {0} war Disabled - temporaer auf Manual gesetzt." -f $Name)
        }
        if ((Get-Service -Name $Name).Status -ne 'Running') { Start-Service -Name $Name }
        Write-Host ("Dienst {0}: {1}" -f $Name, (Get-Service -Name $Name).Status)
    }
    catch { Write-Warning ("Dienst {0} konnte nicht aktiviert/gestartet werden: {1}" -f $Name, $_.Exception.Message) }
}

function Get-LanguageState {
    # Installationsstand: maschinenweites Language Pack (CBS, 'LpCab') UND Pflicht-Features.
    # 'InstallPending' (Neustart ausstehend) zaehlt als installiert. Nur Features ohne LP oder nur das
    # benutzerbezogene LXP zaehlen NICHT (Teilinstallation, Fehlerbild 0x800F0991).
    param([string]$Lang)
    $lp = $false
    $features = ''
    try {
        $il = Get-InstalledLanguage -ErrorAction Stop | Where-Object { $_.LanguageId -eq $Lang } | Select-Object -First 1
        if ($il) {
            $features = "$($il.LanguageFeatures)"
            Write-Host ("Get-InstalledLanguage {0}: Packs=[{1}] Features=[{2}]" -f $Lang, $il.LanguagePacks, $features)
            $lp = ("$($il.LanguagePacks)" -match 'LpCab')
        }
    }
    catch { Write-Warning ("Get-InstalledLanguage fehlgeschlagen: {0}" -f $_.Exception.Message) }

    if (-not $lp) {
        # Fallback: CBS-Paketstatus.
        try {
            $pkg = Get-WindowsPackage -Online -ErrorAction Stop | Where-Object {
                $_.PackageName -like '*Client-Language-Pack*' -and $_.PackageName -like "*$Lang*" -and
                @('Installed', 'InstallPending') -contains "$($_.PackageState)"
            } | Select-Object -First 1
            if ($pkg) { Write-Host ("CBS-Paket: {0} ({1})" -f $pkg.PackageName, $pkg.PackageState); $lp = $true }
        }
        catch { Write-Warning ("Get-WindowsPackage fehlgeschlagen: {0}" -f $_.Exception.Message) }
    }

    # Features: Get-InstalledLanguage, Fallback FoD-Capability-Status (erkennt auch 'InstallPending').
    $missing = New-Object System.Collections.ArrayList
    $caps = $null
    foreach ($f in $RequiredFeatures) {
        if ($features -match "\b$f\b") { continue }
        if ($null -eq $caps) {
            try { $caps = @(Get-WindowsCapability -Online -ErrorAction Stop | Where-Object { $_.Name -like "Language.*~~~$Lang~*" }) }
            catch { Write-Warning ("Get-WindowsCapability fehlgeschlagen: {0}" -f $_.Exception.Message); $caps = @() }
        }
        $cap = $caps | Where-Object { $_.Name -like ("Language.{0}~~~{1}~*" -f $FeatureCapMap[$f], $Lang) } | Select-Object -First 1
        if ($cap -and (@('Installed', 'InstallPending') -contains "$($cap.State)")) { continue }
        [void]$missing.Add($f)
    }

    $state = [pscustomobject]@{
        LanguagePack    = [bool]$lp
        MissingFeatures = @($missing)
        Complete        = ([bool]$lp -and $missing.Count -eq 0)
    }
    Write-Host ("Status {0}: LanguagePack={1}, fehlende Features=[{2}]" -f $Lang, $state.LanguagePack, ($state.MissingFeatures -join ', '))
    return $state
}

function Add-MissingLanguageFeature {
    # Gezielte Nachinstallation fehlender Features, falls Install-Language sie nicht vollstaendig liefert.
    param([string]$Lang, [string[]]$Features, [datetime]$Deadline)
    foreach ($f in $Features) {
        $remainingMin = [int][Math]::Floor(($Deadline - (Get-Date)).TotalMinutes)
        if ($remainingMin -lt 5) { Write-Warning 'Installationsbudget aufgebraucht - Feature-Nachinstallation abgebrochen.'; break }
        $capName = 'Language.{0}~~~{1}~0.0.1.0' -f $FeatureCapMap[$f], $Lang
        Write-Host ("Add-WindowsCapability {0} (Timeout {1} Min.)..." -f $capName, $remainingMin)
        $job = Start-Job -ScriptBlock { param($n) Add-WindowsCapability -Online -Name $n -ErrorAction Stop | Out-String } -ArgumentList $capName
        if (-not (Wait-Job -Job $job -Timeout ($remainingMin * 60))) {
            Write-Warning ("Add-WindowsCapability {0}: Timeout." -f $capName)
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            Wait-ServicingIdle -MaxMinutes $ServicingIdleMaxMin
            continue
        }
        try { Receive-Job -Job $job -ErrorAction Stop | Write-Host }
        catch { Write-Warning ("Add-WindowsCapability {0} fehlgeschlagen: {1} (HResult 0x{2:X8})" -f $capName, $_.Exception.Message, $_.Exception.HResult) }
        finally { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
    }
}

function Test-LanguageActive {
    # MUI-Registrierung = Anzeigesprache sofort nutzbar. Fehlt sie bei installiertem LP -> Reboot ausstehend.
    param([string]$Lang)
    return (Test-Path (Join-Path $MuiKey $Lang))
}

function Invoke-InstallLanguageWithTimeout {
    # Install-Language kann haengen (WU-Client blockiert). -AsJob + Wait-Job erzwingt einen Abbruch,
    # bevor der Timeout der Scripted Action greift. Rueckgabe: $true = beendet, $false = Timeout.
    param([string]$Lang, [int]$TimeoutMinutes)
    $job = Install-Language -Language $Lang -AsJob
    $done = Wait-Job -Job $job -Timeout ($TimeoutMinutes * 60)
    if (-not $done) {
        Write-Warning ("Install-Language ueberschreitet {0} Minuten - Versuch wird abgebrochen." -f $TimeoutMinutes)
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return $false
    }
    try { Receive-Job -Job $job -ErrorAction Stop | Out-String | Write-Host }
    finally { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
    return $true
}

function Wait-ServicingIdle {
    # Ein gestoppter Job beendet die CBS-Operation (TiWorker) nicht zwingend. Ein sofortiger neuer
    # Install-Language-Aufruf wuerde mit ihr kollidieren -> erst auf Ende warten (begrenzt).
    param([int]$MaxMinutes)
    $deadline = (Get-Date).AddMinutes($MaxMinutes)
    while ((Get-Process -Name TiWorker -ErrorAction SilentlyContinue) -and ((Get-Date) -lt $deadline)) {
        Write-Host 'CBS (TiWorker) noch aktiv - warte 30 Sekunden...'
        Start-Sleep -Seconds 30
    }
}

function Test-TcpPort {
    param([string]$HostName, [int]$Port = 443, [int]$TimeoutMs = 5000)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $client.EndConnect($iar)
        return $true
    }
    catch { return $false }
    finally { $client.Close() }
}

function Set-InternationalSettingsViaIntlCpl {
    # Fallback, falls Copy-UserInternationalSettingsToSystem fehlschlaegt.
    # intl.cpl /f:<xml> kopiert die Einstellungen auf Welcome Screen/Systemkonten und Default-Profil.
    param([string]$Lang, [int]$Geo, [string]$Kbd, [string]$WorkDir)
    $xml = @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
  <gs:UserList>
    <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true"/>
  </gs:UserList>
  <gs:UserLocale>
    <gs:Locale Name="$Lang" SetAsCurrent="true" ResetAllSettings="false"/>
  </gs:UserLocale>
  <gs:LocationPreferences>
    <gs:GeoID Value="$Geo"/>
  </gs:LocationPreferences>
  <gs:MUILanguagePreferences>
    <gs:MUILanguage Value="$Lang"/>
  </gs:MUILanguagePreferences>
  <gs:InputPreferences>
    <gs:InputLanguageID Action="add" ID="$Kbd" Default="true"/>
  </gs:InputPreferences>
</gs:GlobalizationServices>
"@
    $xmlPath = Join-Path $WorkDir "intl_$Lang.xml"
    # UTF8 ohne BOM - intl.cpl ist bei BOM empfindlich
    [System.IO.File]::WriteAllText($xmlPath, $xml, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Wende internationale Einstellungen via intl.cpl an: $xmlPath"
    $p = Start-Process -FilePath "$env:SystemRoot\System32\control.exe" `
        -ArgumentList ('intl.cpl,, /f:"{0}"' -f $xmlPath) -Wait -PassThru -WindowStyle Hidden
    Write-Host ("intl.cpl ExitCode: {0}" -f $p.ExitCode)
}

function Get-RegValueViaRegExe {
    # reg.exe statt Registry-Provider: haelt keine Handles offen (wichtig fuer reg unload).
    param([string]$Key, [string]$Name)
    $ErrorActionPreference = 'Continue'
    $out = & reg.exe query $Key /v $Name 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    foreach ($line in $out) {
        if ($line -match ('^\s+{0}\s+REG_\w+\s*(.*)$' -f [regex]::Escape($Name))) { return $Matches[1].Trim() }
    }
    return $null
}

function Test-IntlProfile {
    # Prueft in einem Profil-Hive: Regionalformat, Datums-/Uhrzeitformat, Region, Sprachliste/Anzeigesprache.
    # Nicht vorhandene Format-Werte = Standard des Gebietsschemas = OK.
    param([string]$Root, [string]$Label)
    $ref  = New-Object System.Globalization.CultureInfo($Language, $false)
    $intl = "$Root\Control Panel\International"
    $v = [ordered]@{
        LocaleName  = Get-RegValueViaRegExe $intl 'LocaleName'
        sShortDate  = Get-RegValueViaRegExe $intl 'sShortDate'
        sTimeFormat = Get-RegValueViaRegExe $intl 'sTimeFormat'
        Nation      = Get-RegValueViaRegExe "$intl\Geo" 'Nation'
        Languages   = Get-RegValueViaRegExe "$intl\User Profile" 'Languages'
        UILanguage  = Get-RegValueViaRegExe "$Root\Control Panel\Desktop" 'PreferredUILanguages'
        Keyboard    = Get-RegValueViaRegExe "$Root\Keyboard Layout\Preload" '1'
    }
    Write-Host ("[{0}] {1}" -f $Label, (($v.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, $_.Value }) -join '; '))
    $errors = @()
    if ($v.LocaleName -ne $Language) { $errors += 'Regionalformat' }
    if ($v.sShortDate  -and $v.sShortDate  -ne $ref.DateTimeFormat.ShortDatePattern) { $errors += 'Datumsformat' }
    if ($v.sTimeFormat -and $v.sTimeFormat -ne $ref.DateTimeFormat.LongTimePattern)  { $errors += 'Uhrzeitformat' }
    if ($v.Nation      -and $v.Nation      -ne [string]$GeoId)                       { $errors += 'Region' }
    if ($v.Languages   -and ($v.Languages  -split '\\0')[0] -ne $Language)          { $errors += 'Sprachliste' }
    if ($v.UILanguage  -and ($v.UILanguage -split '\\0')[0] -ne $Language)          { $errors += 'Anzeigesprache' }
    if ($errors) { Write-Warning ("[{0}] abweichend: {1}" -f $Label, ($errors -join ', ')); return $false }
    return $true
}

function Invoke-WithDefaultUserHive {
    # Laedt C:\Users\Default\NTUSER.DAT (Vorlage fuer neue Benutzer) temporaer nach $DefUserMount.
    param([scriptblock]$Action)
    $ErrorActionPreference = 'Continue'
    $hive = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    $null = & reg.exe load $DefUserMount $hive 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Warning "Default-User-Hive konnte nicht geladen werden ($hive)."; return $null }
    try { return (& $Action $DefUserMount) }
    finally {
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        $null = & reg.exe unload $DefUserMount 2>&1
        if ($LASTEXITCODE -ne 0) { Write-Warning "Default-User-Hive konnte nicht entladen werden ($DefUserMount)." }
    }
}

function Copy-IntlRegistry {
    # Letzter Fallback: Internationale Einstellungen des Quellprofils 1:1 in ein Zielprofil kopieren.
    param([string]$SourceRoot, [string]$TargetRoot)
    $ErrorActionPreference = 'Continue'
    foreach ($k in @('Control Panel\International', 'Keyboard Layout\Preload')) {
        $null = & reg.exe delete "$TargetRoot\$k" /f 2>&1
        $null = & reg.exe copy "$SourceRoot\$k" "$TargetRoot\$k" /s /f 2>&1
        Write-Host ("reg copy {0}\{1} -> {2} : ExitCode {3}" -f $SourceRoot, $k, $TargetRoot, $LASTEXITCODE)
    }
    $null = & reg.exe add "$TargetRoot\Control Panel\Desktop" /v PreferredUILanguages /t REG_MULTI_SZ /d $Language /f 2>&1
}

# ==================================================================== Hauptteil
try {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $ctx      = $identity.Name
    $isSystem = ($identity.User.Value -eq 'S-1-5-18')    # SID statt Name: Kontoname ist lokalisiert
    $isAdmin  = ([System.Security.Principal.WindowsPrincipal]$identity).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    $os       = Get-CimInstance Win32_OperatingSystem -Verbose:$false
    $build    = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber

    Write-Host ("Ausfuehrungskontext : {0} (SYSTEM={1}, Admin={2})" -f $ctx, $isSystem, $isAdmin)
    Write-Host ("Betriebssystem      : {0} (Build {1})" -f $os.Caption, $build)
    Write-Host ("PowerShell          : {0} ({1}, 64-Bit-Prozess={2})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition, [Environment]::Is64BitProcess)

    # --- 0) Voraussetzungen -----------------------------------------------------
    if (-not $isSystem -and -not $isAdmin) {
        throw "Script muss als SYSTEM (NERDIO) oder in einer erhoehten Admin-Sitzung laufen."
    }
    # International-/LanguagePackManagement-Cmdlets sind unter PowerShell 7 nicht zuverlaessig.
    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw "Dieses Script muss unter Windows PowerShell 5.1 laufen (aktuell: PowerShell $($PSVersionTable.PSVersion)). Scripted Action auf powershell.exe (nicht pwsh.exe) stellen."
    }
    # 32-Bit-Host (SysWOW64) findet das Modul LanguagePackManagement nicht.
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        throw "Script laeuft in 32-Bit-PowerShell. Bitte 64-Bit-powershell.exe verwenden (z. B. %WINDIR%\SysNative\WindowsPowerShell\v1.0\powershell.exe)."
    }
    if ($build -lt 22000) {
        throw "Windows 11 erforderlich (Build $build). Copy-UserInternationalSettingsToSystem gibt es erst ab Build 22000."
    }
    if ($build -lt 26200) {
        Write-Warning "Build $build liegt unter Windows 11 25H2 (26200). Script ist fuer 25H2+ ausgelegt."
    }
    if (-not (Get-Module -ListAvailable -Name LanguagePackManagement)) {
        throw "Modul 'LanguagePackManagement' nicht verfuegbar (Build $build)."
    }
    Import-Module LanguagePackManagement -ErrorAction Stop -Verbose:$false

    # --- 1) Pending-Reboot-Check ------------------------------------------------
    $pendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
                     (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
                     ($null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue))
    if ($pendingReboot) {
        Write-Warning 'Ausstehender Neustart erkannt - Install-Language kann mit 0x800F0922/0x80070BC2 scheitern. Empfehlung: Reboot-Step VOR dieses Script legen.'
    }

    # --- 2) LangPack-Bereinigung dauerhaft deaktivieren (AVD Best Practice) ------
    New-Item -Path $IntlPolKey -Force | Out-Null
    Set-ItemProperty -Path $IntlPolKey -Name 'BlockCleanupOfUnusedPreinstalledLangPacks' -Value 1 -Type DWord
    foreach ($t in @(
        @{ P = '\Microsoft\Windows\AppxDeploymentClient\'; N = 'Pre-staged app cleanup' },
        @{ P = '\Microsoft\Windows\MUI\';                   N = 'LPRemove' },
        @{ P = $LciTaskPath;                                N = 'Uninstallation' }
    )) {
        try { Disable-ScheduledTask -TaskPath $t.P -TaskName $t.N -ErrorAction Stop | Out-Null; Write-Host ("Task deaktiviert: {0}{1}" -f $t.P, $t.N) }
        catch { Write-Verbose ("Task {0}{1} nicht vorhanden/nicht deaktivierbar." -f $t.P, $t.N) }
    }

    # --- 3) LanguageComponentsInstaller waehrend des Laufs pausieren -------------
    # Laufen diese Tasks parallel zu Install-Language, scheitert die Installation sporadisch mit
    # ERROR_SHARING_VIOLATION (0x80070020). Reaktivierung im finally-Block (wie MS-Referenzscript).
    foreach ($n in @('Installation', 'ReconcileLanguageResources')) {
        try {
            Stop-ScheduledTask    -TaskPath $LciTaskPath -TaskName $n -ErrorAction SilentlyContinue
            Disable-ScheduledTask -TaskPath $LciTaskPath -TaskName $n -ErrorAction Stop | Out-Null
            [void]$TaskReenable.Add($n)
            Write-Host ("Task temporaer deaktiviert: {0}{1}" -f $LciTaskPath, $n)
        }
        catch { Write-Verbose ("Task {0}{1} nicht vorhanden/nicht deaktivierbar." -f $LciTaskPath, $n) }
    }

    # --- 4) Idempotenz-Check (LP + Pflicht-Features) ---------------------------
    $langState = Get-LanguageState -Lang $Language
    if ($langState.Complete) {
        Write-Host "Sprachpaket $Language inkl. Features bereits installiert - Installation wird uebersprungen."
    }
    else {
        # --- 4a) Blockierende WU-/Servicing-Policies temporaer entschaerfen -------
        Set-PolicyValueTemporarily -Path $AUKey -Name 'UseWUServer' -DesiredValue 0 -OnlyIfPresent
        Set-PolicyValueTemporarily -Path $WUKey -Name 'DoNotConnectToWindowsUpdateInternetLocations' -DesiredValue 0 -OnlyIfPresent
        Set-PolicyValueTemporarily -Path $WUKey -Name 'DisableWindowsUpdateAccess' -DesiredValue 0 -OnlyIfPresent
        # GPO "Einstellungen fuer die Installation optionaler Komponenten und die Komponentenreparatur":
        # UseWindowsUpdate=2 verbietet WU als Quelle, RepairContentServerSource=2 laedt direkt von WU
        # statt WSUS. Beides ist die klassische Ursache fuer 0x800F0954 bei Language Packs.
        Set-PolicyValueTemporarily -Path $ServicingKey -Name 'UseWindowsUpdate' -DesiredValue $null -OnlyIfPresent
        Set-PolicyValueTemporarily -Path $ServicingKey -Name 'RepairContentServerSource' -DesiredValue 2

        # --- 4b) Dienste sicherstellen ------------------------------------------
        Enable-ServiceTemporarily -Name 'wuauserv'
        Enable-ServiceTemporarily -Name 'DoSvc'
        if ($RegRestore.Count -gt 0) {
            # Nur bei geaenderten Policies neu starten, damit der WU-Client sie neu einliest.
            try { Restart-Service wuauserv -Force } catch { Write-Warning ("wuauserv-Neustart fehlgeschlagen: {0}" -f $_.Exception.Message) }
        }

        # --- 4c) Konnektivitaets-Vorpruefung (nur Diagnose) ---------------------
        Write-Host ("WinHTTP-Proxy: {0}" -f ((netsh winhttp show proxy) -join ' ').Trim())
        $cdnHost = 'tlu.dl.delivery.mp.microsoft.com'
        $cdnOk = Test-TcpPort -HostName $cdnHost -Port 443
        Write-Host ("CDN erreichbar ({0}:443): {1}" -f $cdnHost, $cdnOk)
        if (-not $cdnOk) { Write-Warning 'Windows-Update-CDN direkt nicht erreichbar - bei Fehlschlag Firewall/Proxy/NSG pruefen.' }

        # --- 4d) Installation mit Retry, Timeout und Gesamtbudget ----------------
        $deadline  = (Get-Date).AddMinutes($InstallBudgetMin)
        $attempt   = 0
        $installed = $false
        do {
            $attempt++
            $remainingMin = [int][Math]::Floor(($deadline - (Get-Date)).TotalMinutes)
            if ($remainingMin -lt 5) { Write-Warning 'Installationsbudget aufgebraucht - keine weiteren Versuche.'; break }
            $timeoutMin = [Math]::Min($InstallTimeoutMin, $remainingMin)
            Write-Host ("Install-Language {0} - Versuch {1}/{2} (Timeout {3} Min.)..." -f $Language, $attempt, $MaxAttempts, $timeoutMin)

            $finished = $true
            try { $finished = Invoke-InstallLanguageWithTimeout -Lang $Language -TimeoutMinutes $timeoutMin }
            catch {
                # HResult mitloggen - die Message allein ist fuer die Diagnose oft wertlos.
                Write-Warning ("Versuch {0} fehlgeschlagen: {1} (HResult 0x{2:X8})" -f $attempt, $_.Exception.Message, $_.Exception.HResult)
            }
            if (-not $finished) { Wait-ServicingIdle -MaxMinutes $ServicingIdleMaxMin }

            $langState = Get-LanguageState -Lang $Language
            $installed = $langState.Complete
            if (-not $installed -and $attempt -lt $MaxAttempts) {
                Write-Host ("Warte {0} Sekunden bis zum naechsten Versuch..." -f $RetryDelaySec)
                Start-Sleep -Seconds $RetryDelaySec
            }
        } until ($installed -or $attempt -ge $MaxAttempts)

        # --- 4e) Fehlende Features gezielt nachinstallieren ----------------------
        if ($langState.LanguagePack -and -not $langState.Complete) {
            Add-MissingLanguageFeature -Lang $Language -Features $langState.MissingFeatures -Deadline $deadline
            $langState = Get-LanguageState -Lang $Language
        }

        if (-not $langState.Complete) {
            # Letzte CBS-Zeilen ins Transcript - spart eine RDP-Session zur Analyse.
            Write-Host '--- letzte 40 Zeilen C:\Windows\Logs\CBS\CBS.log ---'
            try { Get-Content 'C:\Windows\Logs\CBS\CBS.log' -Tail 40 -ErrorAction Stop | Write-Host } catch { Write-Verbose 'CBS.log nicht lesbar.' }
            if (-not $langState.LanguagePack) {
                throw "Sprachpaket $Language konnte nicht installiert werden (WSUS/Proxy/CDN/Pending-Reboot pruefen; Log: $logPath)."
            }
            throw ("Sprachpaket {0} installiert, aber Features fehlen: {1} (WSUS/Proxy/CDN pruefen; Log: {2})." -f $Language, ($langState.MissingFeatures -join ', '), $logPath)
        }
        Write-Host "Sprachpaket $Language inkl. Features erfolgreich installiert."
    }

    # --- 5) Systemweite Anzeigesprache ------------------------------------------
    # Setzt die System Preferred UI Language (Welcome Screen, Systemkonten, Standard fuer neue
    # Benutzer). Wirksam nach Neustart.
    $sysUiOk = $false
    try {
        Set-SystemPreferredUILanguage -Language $Language
        $sysUiOk = $true
        Write-Host "System Preferred UI Language: $Language"
    }
    catch {
        Write-Warning ("Set-SystemPreferredUILanguage fehlgeschlagen: {0} - Welcome Screen/neue Benutzer werden trotzdem ueber Schritt 7 auf {1} gesetzt. Nach dem Neustart Script erneut ausfuehren." -f $_.Exception.Message, $Language)
    }

    # --- 6) Sprache/Formate/Region des ausfuehrenden Kontos ---------------------
    # Als SYSTEM ist das HKU\.DEFAULT (Welcome Screen), als Admin dessen Profil. Beides ist nur die
    # Quelle fuer Schritt 7. de-DE kommt an Position 1; weitere Sprachen nur mit $KeepOtherLanguages.
    $langList = New-WinUserLanguageList -Language $Language
    if ($KeepOtherLanguages) {
        foreach ($l in (Get-WinUserLanguageList)) {
            if ($l.LanguageTag -ne $Language) { $langList.Add($l) }
        }
    }
    Set-WinUserLanguageList -LanguageList $langList -Force
    try { Set-WinDefaultInputMethodOverride -InputTip $KeyboardId }
    catch { Write-Warning ("Set-WinDefaultInputMethodOverride fehlgeschlagen: {0}" -f $_.Exception.Message) }
    # Setzt auch einen evtl. von v2 in HKU\.DEFAULT hinterlassenen en-US-Override auf de-DE.
    try { Set-WinUILanguageOverride -Language $Language }
    catch { Write-Warning ("Set-WinUILanguageOverride fehlgeschlagen: {0}" -f $_.Exception.Message) }
    Set-Culture        -CultureInfo  $Language
    Set-WinSystemLocale -SystemLocale $Language     # Nicht-Unicode-Programme, wirkt nach Reboot
    Set-WinHomeLocation -GeoId        $GeoId
    if (-not (Test-Path $DefaultGeoKey)) { New-Item -Path $DefaultGeoKey -Force | Out-Null }
    Set-ItemProperty -Path $DefaultGeoKey -Name 'Nation' -Value ([string]$GeoId) -Type String
    Set-TimeZone        -Id           $TimeZone

    # --- 7) Auf Welcome Screen, Systemkonten und neue Benutzer uebertragen -------
    try {
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
        Write-Host "Welcome Screen/Systemkonten und neue Benutzer: $Language (Copy-UserInternationalSettingsToSystem)."
    }
    catch {
        Write-Warning ("Copy-UserInternationalSettingsToSystem fehlgeschlagen: {0} - Fallback intl.cpl." -f $_.Exception.Message)
        Set-InternationalSettingsViaIntlCpl -Lang $Language -Geo $GeoId -Kbd $KeyboardId -WorkDir $tempFolder.FullName
    }

    # --- 7b) Ergebnis pruefen: Welcome Screen und neue Benutzer -----------------
    # Copy-UserInternationalSettingsToSystem meldet keinen Fehler, wenn es Werte nicht uebernimmt.
    # Deshalb das Ergebnis direkt in den Ziel-Hives pruefen und notfalls nachziehen.
    $srcRoot  = if ($isSystem) { 'HKU\.DEFAULT' } else { 'HKCU' }
    $checkAll = {
        $w = Test-IntlProfile -Root 'HKU\.DEFAULT' -Label 'Welcome Screen/Systemkonten'
        $n = Invoke-WithDefaultUserHive { param($r) Test-IntlProfile -Root $r -Label 'Neue Benutzer (Default-Profil)' }
        [pscustomobject]@{ Welcome = [bool]$w; NewUser = [bool]$n }
    }
    $chk = & $checkAll
    if (-not ($chk.Welcome -and $chk.NewUser)) {
        Write-Warning 'Einstellungen nicht vollstaendig uebernommen - Fallback intl.cpl.'
        Set-InternationalSettingsViaIntlCpl -Lang $Language -Geo $GeoId -Kbd $KeyboardId -WorkDir $tempFolder.FullName
        $chk = & $checkAll
    }
    if (-not ($chk.Welcome -and $chk.NewUser)) {
        Write-Warning 'Weiterhin abweichend - direkte Registry-Kopie aus dem Quellprofil.'
        if (-not $chk.Welcome -and -not $isSystem) { Copy-IntlRegistry -SourceRoot $srcRoot -TargetRoot 'HKU\.DEFAULT' }
        if (-not $chk.NewUser) { [void](Invoke-WithDefaultUserHive { param($r) Copy-IntlRegistry -SourceRoot $srcRoot -TargetRoot $r }) }
        $chk = & $checkAll
    }
    if (-not ($chk.Welcome -and $chk.NewUser)) {
        throw ("Deutsche Standard-Einstellungen konnten nicht gesetzt werden (Welcome Screen={0}, Neue Benutzer={1})." -f $chk.Welcome, $chk.NewUser)
    }
    Write-Host "Welcome Screen und neue Benutzer: $Language geprueft OK."

    # --- 8) Sysprep-Vorpruefung -------------------------------------------------
    # Ein nur benutzerbezogen installiertes Language Experience Pack laesst Sysprep mit 0x80073CF2
    # scheitern ("installed for a user, but not provisioned for all users").
    try {
        $lxpUser = Get-AppxPackage -AllUsers -Name "Microsoft.LanguageExperiencePack$Language" -ErrorAction SilentlyContinue | Select-Object -First 1
        $lxpProv = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "Microsoft.LanguageExperiencePack$Language*" }
        if ($lxpUser -and -not $lxpProv) {
            Write-Warning ("LXP '{0}' ist nur benutzerbezogen installiert und NICHT provisioniert -> Sysprep bricht mit 0x80073CF2 ab. Vor einem Image-Capture entfernen: Remove-AppxPackage -AllUsers -Package '{1}'" -f $lxpUser.Name, $lxpUser.PackageFullName)
        }
        else {
            Write-Host ("LXP-Status: user={0} provisioned={1}" -f [bool]$lxpUser, [bool]$lxpProv)
        }
    } catch { Write-Verbose "LXP-Pruefung uebersprungen." }

    # --- 9) Validierung ---------------------------------------------------------
    Write-Host '--- Validierung ---'
    Get-InstalledLanguage | Format-Table -AutoSize | Out-String | Write-Host
    try { Write-Host ("SystemPreferredUI : {0}" -f (Get-SystemPreferredUILanguage)) } catch { Write-Verbose 'Get-SystemPreferredUILanguage nicht verfuegbar.' }
    Write-Host ("Culture           : {0}" -f (Get-Culture).Name)
    Write-Host ("SystemLocale      : {0}" -f (Get-WinSystemLocale).Name)
    Write-Host ("HomeLocation      : {0}" -f (Get-WinHomeLocation).GeoId)
    Write-Host ("TimeZone          : {0}" -f (Get-TimeZone).Id)
    Write-Host ("UILanguageOverride: {0}" -f (Get-WinUILanguageOverride).Name)
    Write-Host ("UserLanguageList  : {0}" -f ((Get-WinUserLanguageList).LanguageTag -join ', '))
    Write-Host ("MUI-UILanguages   : {0}" -f ((Get-ChildItem $MuiKey -ErrorAction SilentlyContinue).PSChildName -join ', '))

    $langState = Get-LanguageState -Lang $Language
    if (-not $langState.Complete) {
        throw ("Abschlussvalidierung fehlgeschlagen: {0} unvollstaendig (LanguagePack={1}, fehlende Features=[{2}])." -f $Language, $langState.LanguagePack, ($langState.MissingFeatures -join ', '))
    }
    if (-not (Test-LanguageActive -Lang $Language)) {
        Write-Host "Hinweis: $Language ist installiert, die MUI-Registrierung erfolgt beim Neustart."
    }
    if (-not $sysUiOk) {
        Write-Warning "System Preferred UI Language konnte nicht gesetzt werden - nach dem Neustart Script erneut ausfuehren."
    }
    Write-Host 'Hinweis (Microsoft): Nach einer Sprachpaket-Installation das aktuelle kumulative Update (LCU) erneut installieren, sonst bleiben Teile der Oberflaeche ggf. englisch.'
    Write-Host 'OK. Reboot erforderlich (via NERDIO ausloesen), erst danach ist Deutsch aktiv bzw. Sysprep/Image-Capture moeglich.'
}
catch {
    # Fehler VOR Stop-Transcript ausgeben, damit er im Log steht.
    Write-Host ("FEHLER: {0} (HResult 0x{1:X8}, Zeile {2})" -f $_.Exception.Message, $_.Exception.HResult, $_.InvocationInfo.ScriptLineNumber)
    throw
}
finally {
    # --- Rollback Policies, Dienste, Tasks (laeuft immer) ------------------------
    try {
        foreach ($r in $RegRestore) {
            if ($null -eq $r.Value) {
                Remove-ItemProperty -Path $r.Path -Name $r.Name -ErrorAction SilentlyContinue
                Write-Host ("Policy entfernt (war nicht gesetzt): {0}\{1}" -f $r.Path, $r.Name)
            }
            else {
                if (-not (Test-Path $r.Path)) { New-Item -Path $r.Path -Force | Out-Null }
                Set-ItemProperty -Path $r.Path -Name $r.Name -Value ([int]$r.Value) -Type DWord -ErrorAction SilentlyContinue
                Write-Host ("Policy wiederhergestellt: {0}\{1} = {2}" -f $r.Path, $r.Name, $r.Value)
            }
        }
        foreach ($s in $SvcRestore) {
            Set-Service -Name $s.Name -StartupType $s.StartType -ErrorAction SilentlyContinue
            Write-Host ("Dienst wiederhergestellt: {0} = {1}" -f $s.Name, $s.StartType)
        }
        if ($RegRestore.Count -gt 0) { Restart-Service wuauserv -Force -ErrorAction SilentlyContinue }
    }
    catch { Write-Warning ("Rollback Policies/Dienste fehlgeschlagen: {0}" -f $_.Exception.Message) }

    foreach ($n in $TaskReenable) {
        try { Enable-ScheduledTask -TaskPath $LciTaskPath -TaskName $n -ErrorAction Stop | Out-Null; Write-Host ("Task reaktiviert: {0}{1}" -f $LciTaskPath, $n) }
        catch { Write-Warning ("Task {0}{1} konnte nicht reaktiviert werden: {2}" -f $LciTaskPath, $n, $_.Exception.Message) }
    }

    Remove-Item $tempFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue

    if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch { } }
    $VerbosePreference = $savedVerbosePreference
    $ErrorActionPreference = $savedErrorActionPreference
    $ProgressPreference = $savedProgressPreference
}
##################################################################### END INDIVIDUAL SCRIPT #######################################################################
