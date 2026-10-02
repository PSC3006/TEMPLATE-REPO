
####################################################################   BEGIN INDIVIDUAL SCRIPT ######################################################################
# Version: 2.0 - 20.08.2026
#description: v2 - 20.08.2026

# ---------------------------------------------------------------- Logging-Header
$scriptName = "CDT_Install_German_Language"
$logFileName = $scriptName + ".log"
$savedVerbosePreference = $VerbosePreference
$VerbosePreference = "Continue"
$savedErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Stop"
$logTime = ((Get-Date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss")
$logFolder = New-Item -Path "C:\Windows\Temp\NMWLogs" -ItemType Directory -Name "ScriptedActions" -Force
$tempFolder = New-Item -Path "C:\Windows\Temp" -ItemType Directory -Name $scriptName -Force
$logPath = Join-Path $logFolder.FullName $logFileName

# FIX #11: Transcript darf nicht hart fehlschlagen, wenn der HYDRA-Wrapper bereits
#          eine Transkription gestartet hat ("Transcription has already been started").
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
$Language        = 'de-DE'                    # BCP-47 Zielsprache
$FallbackUILang  = 'en-US'                    # bleibt in der Sprachliste + MUI-Fallback
$SystemUILang    = 'en-US'                    # Anzeigesprache SYSTEM / Welcome Screen
$GeoId           = 94                         # Deutschland
$TimeZone        = 'W. Europe Standard Time'  # Berlin inkl. Sommerzeit
$KeyboardId      = '0407:00000407'            # de-DE / Deutsch (QWERTZ)
$MaxAttempts     = 3
$RetryDelaySec   = 120
$InstallTimeoutMin = 25                       # Hard-Timeout je Install-Versuch
$SetHandwriting  = $false                     # FIX #13: auf Multi-Session nutzlos, kostet FoD-Payload
# =================================================================================

# ---------------------------------------------------------------- Registry-Konstanten
$AUKey       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
$WUKey       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$ServicingKey= 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing'
$IntlPolKey  = 'HKLM:\SOFTWARE\Policies\Microsoft\Control Panel\International'
$MuiKey      = 'HKLM:\SYSTEM\CurrentControlSet\Control\MUI\UILanguages'

# Merker fuer garantierte Wiederherstellung im finally-Block
$RegRestore = New-Object System.Collections.ArrayList   # @{Path;Name;Value;Existed}
$SvcRestore = New-Object System.Collections.ArrayList   # @{Name;StartType}

# ================================================================ Hilfsfunktionen
function Set-PolicyValueTemporarily {
    param([string]$Path, [string]$Name, [int]$DesiredValue)
    # Setzt einen Policy-Wert nur dann, wenn er aktuell blockierend ist, und merkt
    # sich den Originalzustand fuer das Rollback im finally-Block.
    if (-not (Test-Path $Path)) { return }
    $cur = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($null -eq $cur) { return }
    if ([int]$cur -eq $DesiredValue) { return }
    Write-Host ("Policy-Bypass: {0}\{1} : {2} -> {3}" -f $Path, $Name, $cur, $DesiredValue)
    [void]$RegRestore.Add(@{ Path = $Path; Name = $Name; Value = [int]$cur })
    Set-ItemProperty -Path $Path -Name $Name -Value $DesiredValue -Type DWord
}

function Enable-ServiceTemporarily {
    param([string]$Name)
    # FIX #5: Install-Language braucht wuauserv UND DoSvc. Auf gehaerteten AVD-Images
    # sind beide oft "Disabled" -> Restart-Service wirft (ErrorAction Stop) und/oder
    # der CDN-Download scheitert mit 0x8024402C / 0x80240438.
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Warning ("Dienst {0} nicht vorhanden." -f $Name); return }
    $wmi = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $Name) -ErrorAction SilentlyContinue
    if ($wmi -and $wmi.StartMode -eq 'Disabled') {
        Write-Host ("Dienst {0} ist Disabled - temporaer auf Manual gesetzt." -f $Name)
        [void]$SvcRestore.Add(@{ Name = $Name; StartType = 'Disabled' })
        Set-Service -Name $Name -StartupType Manual
    }
    try {
        if ((Get-Service -Name $Name).Status -ne 'Running') { Start-Service -Name $Name }
    }
    catch { Write-Warning ("Dienst {0} konnte nicht gestartet werden: {1}" -f $Name, $_.Exception.Message) }
}

function Test-LanguageReady {
    param([string]$Lang)
    # FIX #3: Get-InstalledLanguage meldet die Sprache bereits als "installiert",
    # wenn nur Teilkomponenten da sind (Fehlerbild 0x800F0991 "partially installed").
    # Harter Nachweis, dass die ANZEIGESPRACHE wirklich nutzbar ist:
    # der MUI-Schluessel existiert nur bei vollstaendig installiertem Language Pack.
    $inList = $false
    try { $inList = [bool](Get-InstalledLanguage -ErrorAction Stop | Where-Object { $_.LanguageId -eq $Lang }) } catch { }
    $muiOk = Test-Path (Join-Path $MuiKey $Lang)
    Write-Verbose ("Test-LanguageReady {0}: Get-InstalledLanguage={1}, MUI-Key={2}" -f $Lang, $inList, $muiOk)
    return ($inList -and $muiOk)
}

function Invoke-InstallLanguageWithTimeout {
    param([string]$Lang, [int]$TimeoutMinutes)
    # FIX #6: Install-Language kann unbegrenzt haengen (WU-Client blockiert).
    # Ohne Timeout laeuft der 1. Versuch in den HYDRA-Script-Timeout und die
    # Retry-Schleife greift nie. -AsJob + Wait-Job erzwingt den Abbruch.
    $job = Install-Language -Language $Lang -AsJob
    $done = Wait-Job -Job $job -Timeout ($TimeoutMinutes * 60)
    if (-not $done) {
        Write-Warning ("Install-Language ueberschreitet {0} Minuten - Versuch wird abgebrochen." -f $TimeoutMinutes)
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return
    }
    try { Receive-Job -Job $job -ErrorAction Stop | Out-String | Write-Host }
    finally { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
}

function Set-InternationalSettingsViaIntlCpl {
    param([string]$Lang, [int]$Geo, [string]$Kbd, [string]$Fallback, [string]$WorkDir)
    # FIX #1: Windows-10-Pfad. Copy-UserInternationalSettingsToSystem gibt es dort
    # NICHT (Windows 11 22000+ only). intl.cpl /f:<xml> funktioniert auf Win10 UND Win11.
    $xml = @"
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
  <gs:UserList>
    <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="false"/>
  </gs:UserList>
  <gs:UserLocale>
    <gs:Locale Name="$Lang" SetAsCurrent="true" ResetAllSettings="false"/>
  </gs:UserLocale>
  <gs:LocationPreferences>
    <gs:GeoID Value="$Geo"/>
  </gs:LocationPreferences>
  <gs:MUILanguagePreferences>
    <gs:MUILanguage Value="$Lang"/>
    <gs:MUIFallback Value="$Fallback"/>
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

# ==================================================================== Hauptteil
try {
    $ctx = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $isSystem = ($ctx -eq 'NT AUTHORITY\SYSTEM')
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    $isWin11 = $build -ge 22000

    Write-Host ("Ausfuehrungskontext : {0} (SYSTEM={1})" -f $ctx, $isSystem)
    Write-Host ("Betriebssystem      : {0} (Build {1}, Win11={2})" -f $os.Caption, $build, $isWin11)
    Write-Host ("PowerShell          : {0}" -f $PSVersionTable.PSVersion)

    # FIX #12: PowerShell 7 wird von den International-/LanguagePackManagement-Cmdlets
    # nicht zuverlaessig unterstuetzt. Frueh und klar abbrechen statt kryptisch scheitern.
    if ($PSVersionTable.PSEdition -eq 'Core') {
        throw "Dieses Script muss unter Windows PowerShell 5.1 laufen (aktuell: PowerShell $($PSVersionTable.PSVersion)). In HYDRA/NERDIO die Scripted Action auf powershell.exe (nicht pwsh.exe) stellen."
    }
    if (-not (Get-Module -ListAvailable -Name LanguagePackManagement)) {
        throw "Modul 'LanguagePackManagement' nicht verfuegbar (Build $build). Erfordert Windows 10 21H2+/Windows 11. Fuer aeltere Builds ist der DISM-/FoD-ISO-Weg noetig."
    }
    Import-Module LanguagePackManagement -ErrorAction Stop

    # --- 1) Pending-Reboot-Check ------------------------------------------------
    $pendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
                     (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
                     ($null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue))
    if ($pendingReboot) {
        Write-Warning 'Ausstehender Neustart erkannt - Install-Language kann mit 0x800F0923/0x80070bc2 scheitern. Empfehlung: Reboot-Step VOR dieses Script legen.'
    }

    # --- 2) LangPack-Bereinigung deaktivieren (AVD Best Practice) ---------------
    New-Item -Path $IntlPolKey -Force | Out-Null
    Set-ItemProperty -Path $IntlPolKey -Name 'BlockCleanupOfUnusedPreinstalledLangPacks' -Value 1 -Type DWord
    foreach ($t in @(
        @{ P = '\Microsoft\Windows\AppxDeploymentClient\';        N = 'Pre-staged app cleanup' },
        @{ P = '\Microsoft\Windows\MUI\';                          N = 'LPRemove' },
        @{ P = '\Microsoft\Windows\LanguageComponentsInstaller\';  N = 'Uninstallation' },
        @{ P = '\Microsoft\Windows\LanguageComponentsInstaller\';  N = 'ReconcileLanguageResources' }   # FIX #14
    )) {
        try { Disable-ScheduledTask -TaskPath $t.P -TaskName $t.N -ErrorAction Stop | Out-Null; Write-Host ("Task deaktiviert: {0}{1}" -f $t.P, $t.N) }
        catch { Write-Verbose ("Task {0}{1} nicht vorhanden/nicht deaktivierbar." -f $t.P, $t.N) }
    }

    # --- 3) Idempotenz-Check (hart) ---------------------------------------------
    if (Test-LanguageReady -Lang $Language) {
        Write-Host "Sprachpaket $Language vollstaendig vorhanden - Installation wird uebersprungen."
    }
    else {
        # --- 4) Blockierende WU-/Servicing-Policies temporaer entschaerfen -------
        Set-PolicyValueTemporarily -Path $AUKey -Name 'UseWUServer' -DesiredValue 0
        Set-PolicyValueTemporarily -Path $WUKey -Name 'DoNotConnectToWindowsUpdateInternetLocations' -DesiredValue 0
        Set-PolicyValueTemporarily -Path $WUKey -Name 'DisableWindowsUpdateAccess' -DesiredValue 0          # FIX #4
        # FIX #4: DIE klassische 0x800F0954-Ursache bei FoD/Language Packs -
        # GPO "Specify settings for optional component installation and component repair".
        # 2 = Repair-Content direkt von Windows Update laden.
        if (-not (Test-Path $ServicingKey)) { New-Item -Path $ServicingKey -Force | Out-Null }
        $curRepair = (Get-ItemProperty -Path $ServicingKey -Name 'RepairContentServerSource' -ErrorAction SilentlyContinue).RepairContentServerSource
        if ([int]$curRepair -ne 2) {
            Write-Host ("Servicing-Policy RepairContentServerSource: {0} -> 2" -f $curRepair)
            [void]$RegRestore.Add(@{ Path = $ServicingKey; Name = 'RepairContentServerSource'; Value = $curRepair })
            Set-ItemProperty -Path $ServicingKey -Name 'RepairContentServerSource' -Value 2 -Type DWord
        }

        # --- 4b) Dienste sicherstellen ------------------------------------------
        Enable-ServiceTemporarily -Name 'wuauserv'
        Enable-ServiceTemporarily -Name 'DoSvc'      # Delivery Optimization = CDN-Transport
        try { Restart-Service wuauserv -Force } catch { Write-Warning ("wuauserv-Neustart fehlgeschlagen: {0}" -f $_.Exception.Message) }

        # --- 4c) Konnektivitaets-Vorpruefung (Azure Local / Proxy) --------------
        # FIX #10: In Azure-Local-/Proxy-Umgebungen ist der WinHTTP-Proxy fuer SYSTEM
        # oft nicht gesetzt -> Install-Language scheitert stumm mit 0x8024402C.
        Write-Host ("WinHTTP-Proxy: {0}" -f ((netsh winhttp show proxy) -join ' ').Trim())
        $cdnOk = Test-NetConnection -ComputerName 'tlu.dl.delivery.mp.microsoft.com' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-Host ("CDN erreichbar (tlu.dl.delivery.mp.microsoft.com:443): {0}" -f $cdnOk)
        if (-not $cdnOk) { Write-Warning 'Windows-Update-CDN nicht erreichbar - Install-Language wird sehr wahrscheinlich scheitern (Firewall/Proxy/NSG pruefen).' }

        # --- 5) Installation mit begrenzter Retry-Schleife + Timeout ------------
        $attempt = 0
        do {
            $attempt++
            Write-Host ("Install-Language {0} - Versuch {1}/{2} (Timeout {3} Min.)..." -f $Language, $attempt, $MaxAttempts, $InstallTimeoutMin)
            try { Invoke-InstallLanguageWithTimeout -Lang $Language -TimeoutMinutes $InstallTimeoutMin }
            catch {
                # FIX #7: HResult mitloggen - die Message allein ist fuer die Diagnose wertlos.
                Write-Warning ("Versuch {0} fehlgeschlagen: {1} (HResult 0x{2:X8})" -f $attempt, $_.Exception.Message, $_.Exception.HResult)
            }
            $ok = Test-LanguageReady -Lang $Language
            if (-not $ok -and $attempt -lt $MaxAttempts) {
                Write-Host ("Warte {0} Sekunden bis zum naechsten Versuch..." -f $RetryDelaySec)
                Start-Sleep -Seconds $RetryDelaySec
            }
        } until ($ok -or $attempt -ge $MaxAttempts)

        if (-not $ok) {
            # FIX #7b: letzte CBS-Zeilen ins Transcript - spart eine RDP-Session zur Analyse.
            try {
                Write-Host '--- letzte 40 Zeilen C:\Windows\Logs\CBS\CBS.log ---'
                Get-Content 'C:\Windows\Logs\CBS\CBS.log' -Tail 40 -ErrorAction SilentlyContinue | Write-Host
            } catch { }
            throw "Sprachpaket $Language konnte nach $MaxAttempts Versuchen nicht vollstaendig installiert werden (WSUS/Proxy/CDN/Pending-Reboot pruefen; Log: $logPath)."
        }
        Write-Host "Sprachpaket $Language erfolgreich installiert."
    }

    # --- 6) Eingabesprache / Formate / Region / Zeitzone -------------------------
    # FIX #2: New-WinUserLanguageList ERSETZT die Liste komplett. Im Original flog
    # damit en-US raus - danach war "Set-WinUILanguageOverride -Language en-US"
    # auf eine Sprache gerichtet, die nicht mehr in der Praeferenzliste stand.
    $langList = New-WinUserLanguageList -Language $Language
    if ($SetHandwriting) { $langList[0].Handwriting = $true }
    if ($FallbackUILang -and $FallbackUILang -ne $Language) { $langList.Add($FallbackUILang) }
    Set-WinUserLanguageList -LanguageList $langList -Force
    Set-Culture         -CultureInfo  $Language
    Set-WinSystemLocale -SystemLocale $Language     # Nicht-Unicode-Programme, wirkt nach Reboot
    Set-WinHomeLocation -GeoId        $GeoId
    Set-TimeZone        -Id           $TimeZone

    # --- 7) Anzeigesprache: SYSTEM/Welcome = en-US, neue Profile = de-DE --------
    # FIX #8 (Kernfehler des Originals): Unter SYSTEM ist HKCU identisch mit
    # HKU\.DEFAULT - also exakt der Welcome-Screen-/Systemkonto-Hive.
    # Im Original blieb der LETZTE Aufruf "Set-WinUILanguageOverride -Language de-DE"
    # stehen => der Welcome Screen wurde deutsch, obwohl en-US gewollt war,
    # und der erste Copy-Aufruf (-WelcomeScreen $true) war ein reiner Self-Copy.
    if ($isWin11) {
        Set-WinUILanguageOverride -Language $Language
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $false -NewUser $true
        Write-Host 'Neue Benutzerprofile: de-DE (Copy-UserInternationalSettingsToSystem -NewUser).'
        if ($isSystem) {
            # HKU\.DEFAULT wieder auf en-US zuruecksetzen -> Welcome Screen/SYSTEM bleibt englisch
            Set-WinUILanguageOverride -Language $SystemUILang
            Write-Host "SYSTEM/Welcome Screen: $SystemUILang (HKU\.DEFAULT zurueckgesetzt)."
        }
        else {
            Write-Warning "Script laeuft NICHT als SYSTEM ($ctx). Die Einstellungen liegen im Profil '$ctx' und gehen bei Sysprep verloren. In HYDRA/NERDIO als SYSTEM ausfuehren."
        }
    }
    else {
        # Windows 10: Copy-UserInternationalSettingsToSystem existiert nicht
        Set-WinUILanguageOverride -Language $Language
        Set-InternationalSettingsViaIntlCpl -Lang $Language -Geo $GeoId -Kbd $KeyboardId `
            -Fallback $FallbackUILang -WorkDir $tempFolder.FullName
        if ($isSystem) { Set-WinUILanguageOverride -Language $SystemUILang }
    }

    # --- 8) Sysprep-Vorpruefung -------------------------------------------------
    # FIX #9: Ein nur fuer EINEN Benutzer installiertes Language Experience Pack
    # laesst Sysprep mit 0x80073cf2 scheitern ("installed for a user, but not
    # provisioned for all users") - haeufigster Image-Capture-Abbruch nach LP-Install.
    try {
        $lxpUser = Get-AppxPackage -Name "Microsoft.LanguageExperiencePack$Language" -ErrorAction SilentlyContinue
        $lxpProv = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "Microsoft.LanguageExperiencePack$Language*" }
        if ($lxpUser -and -not $lxpProv) {
            Write-Warning ("LXP '{0}' ist nur benutzerbezogen installiert und NICHT provisioniert -> Sysprep bricht mit 0x80073cf2 ab. Vor dem Capture entfernen: Remove-AppxPackage -Package '{1}'" -f $lxpUser.Name, $lxpUser.PackageFullName)
        }
        else {
            Write-Host ("LXP-Status: user={0} provisioned={1}" -f [bool]$lxpUser, [bool]$lxpProv)
        }
    } catch { Write-Verbose "LXP-Pruefung uebersprungen." }

    # --- 9) Validierung (hart) --------------------------------------------------
    Write-Host '--- Validierung ---'
    Get-InstalledLanguage | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host ("Culture           : {0}" -f (Get-Culture).Name)
    Write-Host ("SystemLocale      : {0}" -f (Get-WinSystemLocale).Name)
    Write-Host ("HomeLocation      : {0}" -f (Get-WinHomeLocation).GeoId)
    Write-Host ("TimeZone          : {0}" -f (Get-TimeZone).Id)
    Write-Host ("UILanguageOverride: {0}" -f (Get-WinUILanguageOverride).Name)
    Write-Host ("UserLanguageList  : {0}" -f ((Get-WinUserLanguageList).LanguageTag -join ', '))
    Write-Host ("MUI-UILanguages   : {0}" -f ((Get-ChildItem $MuiKey -ErrorAction SilentlyContinue).PSChildName -join ', '))

    if (-not (Test-LanguageReady -Lang $Language)) {
        throw "Abschlussvalidierung fehlgeschlagen: $Language ist nicht als Anzeigesprache verfuegbar (MUI-Schluessel fehlt)."
    }
    Write-Host 'OK. Reboot erforderlich (via HYDRA/NERDIO ausloesen), erst danach Sysprep/Image-Capture.'
}
catch {
    throw $_
}
finally {
    # --- Rollback Policies + Dienste (laeuft immer) ------------------------------
    try {
        foreach ($r in $RegRestore) {
            if ($null -eq $r.Value) {
                Remove-ItemProperty -Path $r.Path -Name $r.Name -ErrorAction SilentlyContinue
                Write-Host ("Policy entfernt (war nicht gesetzt): {0}\{1}" -f $r.Path, $r.Name)
            }
            else {
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
    catch { Write-Warning ("Rollback fehlgeschlagen: {0}" -f $_.Exception.Message) }

    # FIX #15: temp-Ordner auch im Fehlerfall raeumen (stand im Original hinter
    # dem finally und wurde bei throw nie erreicht).
    Remove-Item $tempFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue

    if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch { } }
    $VerbosePreference = $savedVerbosePreference
    $ErrorActionPreference = $savedErrorActionPreference
}
##################################################################### END INDIVIDUAL SCRIPT #######################################################################
