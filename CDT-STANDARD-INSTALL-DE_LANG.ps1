#description: CDT Standard - de-DE Sprachpaket und deutsche Regional-/Systemkonfiguration fuer AVD-Master (Auto/Audit/Apply/Verify), unbeaufsichtigt fuer NERDIO und HYDRA
#execution mode: IndividualWithRestart
#tags: CDT, Language, de-DE, AVD, Image
<#
.SYNOPSIS
    Deutsche Sprach- und Regionalkonfiguration (de-DE) fuer einen Azure-Virtual-Desktop-Master
    (Windows 11 Enterprise / Enterprise multi-session, 24H2/25H2/26H2) mit nachweisbarer Pruefung.

.DESCRIPTION
    Ein einziges Script ohne Pflichtparameter fuer die unbeaufsichtigte Ausfuehrung als SYSTEM
    (NERDIO Scripted Action ueber Azure Custom Script Extension, HYDRA Script/Script-Collection ueber
    Azure Run Command) oder interaktiv in einer erhoehten Administrator-Sitzung.

    Standardmodus Auto (keine Parameter noetig):
      - Ermittelt den tatsaechlichen Zustand (Komponenten, persistierte Einstellungen, Neustartbedarf).
      - Ist alles korrekt: Status SUCCESS, Exitcode 0.
      - Sonst: fehlende Komponenten installieren (primaer Windows Update, automatischer Fallback auf eine
        freigegebene LOF-ISO bzw. ein Repository mit -LimitAccess), danach konfigurieren und pruefen.
      - Erster Lauf mit Aenderungen: Status REBOOT_REQUIRED, Exitcode 0 (Apply-Phase abgeschlossen) ->
        die Orchestrierung startet die VM neu und fuehrt das Script erneut aus.
      - Lauf nach dem geforderten Neustart (Nachpruefung): nur SUCCESS liefert Exitcode 0. Jeder andere
        Zustand liefert einen Exitcode ungleich 0 -> Orchestrierung stoppt vor Sysprep/Capture.

    Modi: Auto | Audit (nur pruefen) | Apply (anwenden) | Verify (streng, nur pruefen).

    Optionale Uebersteuerung ohne Scriptaenderung (aufsteigende Prioritaet):
      1. Standardwerte im Block KONFIGURATION
      2. Vorbelegte Variablen: $CdtDeLangConfig (Hashtable) bzw. $CdtDeLang<Schluessel>
      3. Umgebungsvariablen: CDT_DELANG_<SCHLUESSEL>
      4. Argumente: -Mode Verify | -IsoPath D:\lof.iso | -AllowUnconfirmedFallbackSource ...

.NOTES
    Exitcodes:
      0 SUCCESS, oder REBOOT_REQUIRED im ersten Apply-Boot (Auto/Apply) - Status steht immer im Summary
      1 FAILED            2 NOT_VERIFIABLE      3 REBOOT_REQUIRED in Nachpruefung/Verify
      4 LOCKED            5 UNSUPPORTED/PREREQUISITE
      6 LOGGING_UNAVAILABLE                     9 INTERNAL_ERROR
    Letzte Konsolenzeile: CDT_RESULT {json} (maschinenlesbar)
    Logs: C:\install\CDT-STANDARD-INSTALL-DE_LANG
    Datei ist bewusst reines ASCII (Windows PowerShell 5.1 liest BOM-lose Scripte als ANSI).
#>

# =====================================================================================================
# KONFIGURATION (Standardwerte - fuer den Normalbetrieb ist keine Aenderung noetig)
# =====================================================================================================
$CdtScriptVersion    = '4.0.0'
$CdtLogSchemaVersion = '1.0'
$CdtProductName      = 'CDT-STANDARD-INSTALL-DE_LANG'

$CdtDefaultConfig = [ordered]@{
    # --- Ablauf -------------------------------------------------------------------------------------
    Mode                           = 'Auto'      # Auto | Audit | Apply | Verify
    LogRoot                        = 'C:\install\CDT-STANDARD-INSTALL-DE_LANG'
    VmName                         = ''          # leer = automatisch (Override > NERDIO $AzureVMName > Azure IMDS > Computername)
    TimeBudgetMinutes              = 80          # NERDIO (Custom Script Extension) und HYDRA (Run Command) brechen nach 90 Minuten ab
    MaxApplyRounds                 = 3           # Schutz gegen Reparaturschleifen (Laeufe mit Aenderungen ohne SUCCESS)
    ExitCodeRebootRequired         = 0           # Exitcode fuer REBOOT_REQUIRED im ersten Apply-Boot (Auto/Apply)
    ResetState                     = $false      # $true: gespeicherten Fortsetzungszustand verwerfen (Diagnose)
    # --- Zielwerte ----------------------------------------------------------------------------------
    Language                       = 'de-DE'
    GeoId                          = 94          # Deutschland
    InputMethodTip                 = '0407:00000407'
    KeyboardLayoutId               = '00000407'
    AdditionalUserLanguages        = @()         # z. B. @('en-US') hinter de-DE; Standard: nur de-DE
    TimeZoneId                     = 'W. Europe Standard Time'
    ShortDate                      = 'dd.MM.yyyy'
    ShortTime                      = 'HH:mm'
    LongTime                       = 'HH:mm:ss'  # Uhrzeit mit Sekunden (24 h)
    DecimalSeparator               = ','
    ThousandSeparator              = '.'
    # --- Komponenten (Erfolgskriterium: Sprachpaket + RequiredCapabilities) -------------------------
    RequiredCapabilities           = @('Basic')
    OptionalCapabilities           = @('OCR', 'TextToSpeech')   # Fehlen = Warnung, kein Fehlschlag
    # --- Quellen ------------------------------------------------------------------------------------
    EnableWindowsUpdateSource      = $true
    EnableFallbackSource           = $true
    AllowUnconfirmedFallbackSource = $false      # $true: Fallback auch ohne Herstellerfreigabe fuer das Release (z. B. 26H2)
    DownloadIso                    = $true
    IsoPath                        = @()         # vorhandene LOF-ISO(s)
    RepositoryPath                 = @()         # Ordner mit Inhalt von LanguagesAndOptionalFeatures
    KeepDownloadedIso              = $false
    ProxyUrl                       = ''          # nur ISO-Download/-Pruefung; leer = automatisch (WinINet, dann WinHTTP)
    # --- Wiederholungen / Zeitlimits ----------------------------------------------------------------
    WuMaxAttempts                  = 2
    WuAttemptTimeoutMinutes        = 25
    CapabilityTimeoutMinutes       = 15
    FallbackPackageTimeoutMinutes  = 30
    RetryDelaySeconds              = 60
    DownloadMaxAttempts            = 3
    ServicingIdleWaitMinutes       = 10
    # --- Netzwerkpruefung ---------------------------------------------------------------------------
    NetworkTimeoutSeconds          = 10
    NetworkMaxRedirects            = 5
    NetworkMaxProbeBytes           = 65536
    # --- Richtlinien / Pruefungen -------------------------------------------------------------------
    PauseLanguageComponentsTasks   = $true       # MS-Workaround (ERROR_SHARING_VIOLATION), nur waehrend der Installation
    SetBlockCleanupPolicy          = $true       # BlockCleanupOfUnusedPreinstalledLangPacks = 1, falls nicht anders gesetzt
    LanguageResourceCheck          = 'Warn'      # Off | Warn | Enforce (Heuristik LCU-Sprachressourcen)
    SysprepAppxCheck               = 'Enforce'   # Off | Warn | Enforce (sprachbezogene Appx, nur benutzerbezogen installiert)
    Utf8ConflictPolicy             = 'Block'     # Block | ChangeSystemLocale
    AllowNonAvdEditions            = $true       # technisch geeignete Editionen ausserhalb der AVD-Freigabe zulassen (Warnung)
    AllowUnmappedRelease           = $false      # Releases ausserhalb 24H2/25H2/26H2 nur mit expliziter Freigabe
}

# Typ-/Wertebereich je Schluessel (fuer Uebersteuerungen)
$CdtConfigSpec = [ordered]@{
    Mode                           = 'Enum:Auto,Audit,Apply,Verify'
    LogRoot                        = 'String'
    VmName                         = 'String'
    TimeBudgetMinutes              = 'Int:15:600'
    MaxApplyRounds                 = 'Int:1:10'
    ExitCodeRebootRequired         = 'Int:0:3010'
    ResetState                     = 'Bool'
    Language                       = 'Enum:de-DE'
    GeoId                          = 'Int:1:999999'
    InputMethodTip                 = 'String'
    KeyboardLayoutId               = 'String'
    AdditionalUserLanguages        = 'StringArray'
    TimeZoneId                     = 'String'
    ShortDate                      = 'String'
    ShortTime                      = 'String'
    LongTime                       = 'String'
    DecimalSeparator               = 'String'
    ThousandSeparator              = 'String'
    RequiredCapabilities           = 'CapabilityArray'
    OptionalCapabilities           = 'CapabilityArray'
    EnableWindowsUpdateSource      = 'Bool'
    EnableFallbackSource           = 'Bool'
    AllowUnconfirmedFallbackSource = 'Bool'
    DownloadIso                    = 'Bool'
    IsoPath                        = 'StringArray'
    RepositoryPath                 = 'StringArray'
    KeepDownloadedIso              = 'Bool'
    ProxyUrl                       = 'String'
    WuMaxAttempts                  = 'Int:1:5'
    WuAttemptTimeoutMinutes        = 'Int:5:120'
    CapabilityTimeoutMinutes       = 'Int:2:120'
    FallbackPackageTimeoutMinutes  = 'Int:5:120'
    RetryDelaySeconds              = 'Int:0:600'
    DownloadMaxAttempts            = 'Int:1:10'
    ServicingIdleWaitMinutes       = 'Int:0:60'
    NetworkTimeoutSeconds          = 'Int:2:60'
    NetworkMaxRedirects            = 'Int:0:10'
    NetworkMaxProbeBytes           = 'Int:1024:1048576'
    PauseLanguageComponentsTasks   = 'Bool'
    SetBlockCleanupPolicy          = 'Bool'
    LanguageResourceCheck          = 'Enum:Off,Warn,Enforce'
    SysprepAppxCheck               = 'Enum:Off,Warn,Enforce'
    Utf8ConflictPolicy             = 'Enum:Block,ChangeSystemLocale'
    AllowNonAvdEditions            = 'Bool'
    AllowUnmappedRelease           = 'Bool'
}

$CdtKnownCapabilities = @('Basic', 'Handwriting', 'OCR', 'Speech', 'TextToSpeech')

# Release-Zuordnung: Fallback-Quelle je Release. Keine Regel "ab Build X gleiche Quelle".
# Freigabe nur, wenn der Hersteller die Quelle fuer das Release nennt.
$CdtLofIso24H2 = [ordered]@{
    Id           = 'LOF-24H2-26100.1'
    Type         = 'Iso'
    Architecture = 'AMD64'
    FileName     = '26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso'
    Url          = 'https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso'
    Sha256       = ''    # keine vertrauenswuerdige Referenzpruefsumme bekannt -> Hash wird nur protokolliert
}
$CdtReleaseMap = @(
    [ordered]@{ Release = '24H2'; Build = 26100; FallbackApproved = $true;  Source = $CdtLofIso24H2; Evidence = 'MS Learn AVD windows-11-language-packs: Languages and Optional Features ISO fuer Windows 11 24H2 und 25H2' }
    [ordered]@{ Release = '25H2'; Build = 26200; FallbackApproved = $true;  Source = $CdtLofIso24H2; Evidence = 'MS Learn AVD windows-11-language-packs: Languages and Optional Features ISO fuer Windows 11 24H2 und 25H2' }
    [ordered]@{ Release = '26H2'; Build = 26300; FallbackApproved = $false; Source = $CdtLofIso24H2; Evidence = 'Stand 2026-10-03: LOF-ISO von Microsoft nur fuer 24H2/25H2 gelistet (Inbox-Apps-ISO dagegen auch fuer 26H2) - Eignung nicht bestaetigt' }
)

# Konkrete, herstellerseitig dokumentierte Windows-Update-Ziele (Stichprobe, keine Wildcard-Vollpruefung)
$CdtWindowsUpdateTargets = @(
    [ordered]@{ Id = 'WU-SLS';  Url = 'https://sls.update.microsoft.com/';               Protocol = 'HTTPS'; Kind = 'ServiceRoot'; Required = $true;  Requirement = '*.update.microsoft.com';            Purpose = 'Windows Update Service Locator (SLS)';           Reference = 'MS Support: Windows Update 0x80072F8F, WU-Troubleshooting (Endpunkttabelle)' }
    [ordered]@{ Id = 'WU-FE3';  Url = 'https://fe3.delivery.mp.microsoft.com/';          Protocol = 'HTTPS'; Kind = 'ServiceRoot'; Required = $true;  Requirement = '*.delivery.mp.microsoft.com';       Purpose = 'Windows Update Client Web Service (Metadaten)';  Reference = 'MS Support: windows-update-issues-troubleshooting' }
    [ordered]@{ Id = 'WU-DL';   Url = 'http://dl.delivery.mp.microsoft.com/';            Protocol = 'HTTP';  Kind = 'ServiceRoot'; Required = $true;  Requirement = '*.dl.delivery.mp.microsoft.com';    Purpose = 'Inhaltsdownload Windows Update / Delivery Optimization'; Reference = 'MS Support: troubleshoot-windows-update-download-errors' }
    [ordered]@{ Id = 'WU-DOWN'; Url = 'http://download.windowsupdate.com/';              Protocol = 'HTTP';  Kind = 'ServiceRoot'; Required = $true;  Requirement = '*.windowsupdate.com';               Purpose = 'Inhaltsdownload Windows Update';                  Reference = 'MS Support: troubleshoot-windows-update-download-errors' }
    [ordered]@{ Id = 'WU-TSFE'; Url = 'https://tsfe.trafficshaping.dsp.mp.microsoft.com/'; Protocol = 'HTTPS'; Kind = 'ServiceRoot'; Required = $false; Requirement = 'tsfe.trafficshaping.dsp.mp.microsoft.com'; Purpose = 'Windows Update Traffic Shaping (diagnostisch)'; Reference = 'MS Support: windows-update-issues-troubleshooting' }
    [ordered]@{ Id = 'WU-EMDL'; Url = 'http://emdl.ws.microsoft.com/';                   Protocol = 'HTTP';  Kind = 'ServiceRoot'; Required = $false; Requirement = 'emdl.ws.microsoft.com';             Purpose = 'Windows Update (diagnostisch)';                   Reference = 'MS Support: windows-update-issues-troubleshooting' }
)
# Dokumentierte Anforderungen ohne konkreten pruefbaren Hostnamen (nur Hinweis, keine Pruefung)
$CdtUntestedRequirements = @(
    [ordered]@{ Requirement = '*.prod.do.dsp.mp.microsoft.com'; Protocol = 'HTTPS'; Port = '443'; Purpose = 'Delivery Optimization'; Note = 'Wildcard ohne konkreten dokumentierten Hostnamen - nicht geprueft' }
)

# Fehlercodes (Quelle: MS-Support-Artikel; Einordnung transient/nicht transient = Scriptentscheidung)
$CdtErrorCatalog = @{
    '0x800F081F' = @{ Category = 'SourceMissing';      Transient = $false; Text = 'CBS_E_SOURCE_MISSING: Quelle fuer Paket/Datei nicht gefunden' }
    '0x800F0906' = @{ Category = 'SourceDownload';     Transient = $true;  Text = 'CBS_E_DOWNLOAD_FAILURE: Inhalt fuer FoD/Reparatur konnte nicht geladen werden' }
    '0x800F0907' = @{ Category = 'Policy';             Transient = $false; Text = 'Richtlinie "Never attempt to download payload from Windows Update" ohne gueltige Alternativquelle' }
    '0x800F0954' = @{ Category = 'PolicyOrSource';     Transient = $false; Text = 'FoD-/Sprachquelle ueber konfigurierte Quelle nicht verfuegbar (in der Praxis haeufig WSUS/Richtlinie)' }
    '0x800F0922' = @{ Category = 'ServicingInstallers'; Transient = $false; Text = 'CBS_E_INSTALLERS_FAILED' }
    '0x800F0831' = @{ Category = 'ComponentStore';     Transient = $false; Text = 'CBS_E_STORE_CORRUPTION' }
    '0x80073712' = @{ Category = 'ComponentStore';     Transient = $false; Text = 'ERROR_SXS_COMPONENT_STORE_CORRUPT' }
    '0x80070020' = @{ Category = 'SharingViolation';   Transient = $true;  Text = 'Datei durch anderen Prozess gesperrt' }
    '0x80070005' = @{ Category = 'AccessDenied';       Transient = $false; Text = 'Zugriff verweigert' }
    '0x80070070' = @{ Category = 'DiskFull';           Transient = $false; Text = 'Zu wenig Speicherplatz' }
    '0x80070BC2' = @{ Category = 'RebootRequired';     Transient = $false; Text = 'ERROR_SUCCESS_REBOOT_REQUIRED (3010) - Zustand wird geprueft, nicht als Erfolg gewertet' }
    '0x80070BC9' = @{ Category = 'RebootRequired';     Transient = $false; Text = 'ERROR_FAIL_REBOOT_REQUIRED' }
    '0x8024402C' = @{ Category = 'NetworkDns';         Transient = $true;  Text = 'WU_E_PT_WINHTTP_NAME_NOT_RESOLVED: Proxy- oder Zielname nicht aufloesbar' }
    '0x80072EE2' = @{ Category = 'NetworkTimeout';     Transient = $true;  Text = 'WININET_E_TIMEOUT' }
    '0x80072EE7' = @{ Category = 'NetworkDns';         Transient = $true;  Text = 'Servername nicht aufloesbar' }
    '0x80072EFD' = @{ Category = 'NetworkConnect';     Transient = $true;  Text = 'Verbindung zum Server nicht moeglich' }
    '0x80072EFE' = @{ Category = 'NetworkConnect';     Transient = $true;  Text = 'Verbindung abgebrochen (u. a. TLS-Cipher)' }
    '0x80072F8F' = @{ Category = 'Tls';                Transient = $false; Text = 'Sichere Verbindung fehlgeschlagen (TLS/Zertifikat/Uhrzeit)' }
    '0x8024401B' = @{ Category = 'ProxyAuth';          Transient = $false; Text = 'WU_E_PT_HTTP_STATUS_PROXY_AUTH_REQ (HTTP 407)' }
    '0x80244018' = @{ Category = 'HttpForbidden';      Transient = $false; Text = 'HTTP 403 (Proxy oder Server verweigert)' }
    '0x80244022' = @{ Category = 'ServiceUnavailable'; Transient = $true;  Text = 'HTTP 503 (Dienst voruebergehend nicht verfuegbar)' }
    '0x80D05001' = @{ Category = 'ProxyRange';         Transient = $false; Text = 'DO_E_HTTP_BLOCKSIZE_MISMATCH (Proxy/Range-Requests)' }
    '0x80D02002' = @{ Category = 'NetworkTimeout';     Transient = $true;  Text = 'Delivery-Optimization-Downloadfehler' }
    'TIMEOUT'    = @{ Category = 'Timeout';            Transient = $true;  Text = 'Zeitlimit des Scripts fuer den Vorgang ueberschritten' }
}

# C#-Hilfstyp: TLS-Pruefung mit protokollierter (nicht abgeschwaechter) Zertifikatspruefung, WinHTTP-Proxy
$CdtNetHelperSource = @'
using System;
using System.IO;
using System.Net.Security;
using System.Runtime.InteropServices;
using System.Security.Authentication;
using System.Security.Cryptography.X509Certificates;

namespace CdtDeLang
{
    public class CertificateRecorder
    {
        public bool Invoked;
        public string Subject = "";
        public string Issuer = "";
        public string NotAfterUtc = "";
        public string PolicyErrors = "";
        public string ChainStatus = "";

        public bool Validate(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors)
        {
            Invoked = true;
            PolicyErrors = sslPolicyErrors.ToString();
            if (certificate != null)
            {
                Subject = certificate.Subject;
                Issuer = certificate.Issuer;
                try
                {
                    X509Certificate2 c2 = certificate as X509Certificate2;
                    if (c2 == null) { c2 = new X509Certificate2(certificate); }
                    NotAfterUtc = c2.NotAfter.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ");
                }
                catch (Exception) { }
            }
            if (chain != null)
            {
                foreach (X509ChainStatus status in chain.ChainStatus)
                {
                    if (ChainStatus.Length > 0) { ChainStatus = ChainStatus + "; "; }
                    ChainStatus = ChainStatus + status.Status.ToString();
                }
            }
            // Standardpruefung beibehalten: nur ohne Richtlinienfehler vertrauen.
            return sslPolicyErrors == SslPolicyErrors.None;
        }

        public RemoteCertificateValidationCallback GetCallback()
        {
            return new RemoteCertificateValidationCallback(this.Validate);
        }
    }

    public class TlsResult
    {
        public bool Success;
        public string Protocol = "";
        public string Cipher = "";
        public string Error = "";
        public string ErrorType = "";
        public CertificateRecorder Certificate;
    }

    public static class NetProbe
    {
        public static TlsResult Authenticate(Stream inner, string host, int timeoutMs)
        {
            TlsResult result = new TlsResult();
            CertificateRecorder recorder = new CertificateRecorder();
            result.Certificate = recorder;
            SslStream ssl = new SslStream(inner, true, recorder.GetCallback());
            try
            {
                ssl.ReadTimeout = timeoutMs;
                ssl.WriteTimeout = timeoutMs;
                ssl.AuthenticateAsClient(host, null, SslProtocols.Tls12, false);
                result.Success = true;
                result.Protocol = ssl.SslProtocol.ToString();
            }
            catch (Exception ex)
            {
                result.Success = false;
                result.ErrorType = ex.GetType().FullName;
                result.Error = ex.Message;
                if (ex.InnerException != null) { result.Error = result.Error + " | " + ex.InnerException.Message; }
            }
            finally
            {
                try { ssl.Dispose(); } catch (Exception) { }
            }
            return result;
        }
    }

    public static class WinHttpProxy
    {
        [StructLayout(LayoutKind.Sequential)]
        private struct ProxyInfo
        {
            public int AccessType;
            public IntPtr Proxy;
            public IntPtr Bypass;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct AutoProxyOptions
        {
            public int Flags;
            public int AutoDetectFlags;
            public string AutoConfigUrl;
            public IntPtr Reserved1;
            public int Reserved2;
            public bool AutoLogonIfChallenged;
        }

        [DllImport("winhttp.dll", SetLastError = true)]
        private static extern bool WinHttpGetDefaultProxyConfiguration(ref ProxyInfo info);

        [DllImport("winhttp.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern IntPtr WinHttpOpen(string agent, int accessType, string proxy, string bypass, int flags);

        [DllImport("winhttp.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern bool WinHttpGetProxyForUrl(IntPtr session, string url, ref AutoProxyOptions options, ref ProxyInfo info);

        [DllImport("winhttp.dll", SetLastError = true)]
        private static extern bool WinHttpSetTimeouts(IntPtr handle, int resolve, int connect, int send, int receive);

        [DllImport("winhttp.dll", SetLastError = true)]
        private static extern bool WinHttpCloseHandle(IntPtr handle);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GlobalFree(IntPtr mem);

        private static string[] Read(ref ProxyInfo info)
        {
            string proxy = info.Proxy == IntPtr.Zero ? "" : Marshal.PtrToStringUni(info.Proxy);
            string bypass = info.Bypass == IntPtr.Zero ? "" : Marshal.PtrToStringUni(info.Bypass);
            if (info.Proxy != IntPtr.Zero) { GlobalFree(info.Proxy); }
            if (info.Bypass != IntPtr.Zero) { GlobalFree(info.Bypass); }
            return new string[] { "ok", info.AccessType.ToString(), proxy, bypass };
        }

        public static string[] GetDefault()
        {
            ProxyInfo info = new ProxyInfo();
            if (!WinHttpGetDefaultProxyConfiguration(ref info))
            {
                return new string[] { "error", Marshal.GetLastWin32Error().ToString(), "", "" };
            }
            return Read(ref info);
        }

        public static string[] GetAutoDetect(string url, int timeoutMs)
        {
            IntPtr session = WinHttpOpen("CDT-DE-LANG-ProxyProbe/1.0", 1, null, null, 0);
            if (session == IntPtr.Zero)
            {
                return new string[] { "error", Marshal.GetLastWin32Error().ToString(), "", "" };
            }
            try
            {
                WinHttpSetTimeouts(session, timeoutMs, timeoutMs, timeoutMs, timeoutMs);
                AutoProxyOptions options = new AutoProxyOptions();
                options.Flags = 1;            // WINHTTP_AUTOPROXY_AUTO_DETECT
                options.AutoDetectFlags = 3;  // DHCP | DNS_A
                options.AutoLogonIfChallenged = true;
                ProxyInfo info = new ProxyInfo();
                if (!WinHttpGetProxyForUrl(session, url, ref options, ref info))
                {
                    return new string[] { "error", Marshal.GetLastWin32Error().ToString(), "", "" };
                }
                return Read(ref info);
            }
            finally
            {
                WinHttpCloseHandle(session);
            }
        }
    }
}
'@

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
$ConfirmPreference     = 'None'

# =====================================================================================================
# BASIS-HILFSFUNKTIONEN
# =====================================================================================================
function Get-CdtTimestamp {
    # Lokaler Zeitstempel mit UTC-Offset (ISO 8601)
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { $Value = [DateTimeOffset]::Now }
    if ($Value -is [datetime]) { $Value = New-Object System.DateTimeOffset($Value) }
    return ([DateTimeOffset]$Value).ToString('yyyy-MM-ddTHH:mm:ss.fffzzz', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-CdtUtcTimestamp {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { $Value = [DateTimeOffset]::UtcNow }
    if ($Value -is [datetime]) { $Value = New-Object System.DateTimeOffset($Value) }
    return ([DateTimeOffset]$Value).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-CdtUtcKey {
    # Normalisiert Zeitangaben (Text oder bereits von ConvertFrom-Json umgewandeltes Datum) auf yyyy-MM-ddTHH:mm:ssZ
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ', $inv) }
    if ($Value -is [datetime]) {
        $dt = $Value
        if ($dt.Kind -eq [System.DateTimeKind]::Unspecified) { $dt = [datetime]::SpecifyKind($dt, [System.DateTimeKind]::Utc) }
        return $dt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', $inv)
    }
    $s = [string]$Value
    $dto = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($s, $inv, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$dto)) { return $dto.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ', $inv) }
    return $s
}

function New-CdtRunId {
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture)
    return ('{0}-{1}' -f $stamp, [guid]::NewGuid().ToString('N').Substring(0, 8))
}

function ConvertTo-CdtArray {
    # Gibt Elemente einzeln aus (Aufruf immer als @(ConvertTo-CdtArray ...)):
    # $null -> nichts; Skalar/Zeichenkette/Hashtable -> 1 Element; Auflistung -> Elemente ohne $null
    param([AllowNull()][object]$InputObject)
    if ($null -eq $InputObject) { return }
    if ($InputObject -is [string] -or $InputObject -is [System.Collections.IDictionary]) { return $InputObject }
    if ($InputObject -is [System.Collections.IEnumerable]) {
        foreach ($item in $InputObject) { if ($null -ne $item) { $item } }
        return
    }
    return $InputObject
}

function Protect-CdtText {
    # Entfernt Geheimnisse aus Texten: bekannte Geheimwerte, URL-Anmeldedaten, Query-Strings (SAS),
    # Schluessel=Wert-Paare, Bearer/Basic-Token, JWT.
    param([AllowNull()][object]$Text)
    if ($null -eq $Text) { return $null }
    $s = [string]$Text
    if ($s.Length -eq 0) { return $s }
    foreach ($secret in $CdtSecretValues) {
        if (-not [string]::IsNullOrEmpty($secret) -and $secret.Length -ge 4) { $s = $s.Replace($secret, '[REDACTED]') }
    }
    $s = [regex]::Replace($s, '(?i)\b([a-z][a-z0-9+\-.]*://)[^/\s:@]+(:[^/\s@]*)?@', '$1[REDACTED]@')
    $s = [regex]::Replace($s, '(?i)\b((?:https?|ftp)://[^\s?#''"<>]+)\?[^\s#''"<>]*', '$1?[REDACTED]')
    $s = [regex]::Replace($s, '(?i)\b(bearer|basic)\s+[a-z0-9\-._~+/]+=*', '$1 [REDACTED]')
    $s = [regex]::Replace($s, '(?i)\b(password|passwd|pwd|secret|client_secret|token|access_token|refresh_token|apikey|api_key|sig|signature|sas|accesskey|account_key|sharedaccesssignature|authorization)(\s*[=:]\s*)("[^"]*"|''[^'']*''|[^\s;&,''"]+)', '$1$2[REDACTED]')
    $s = [regex]::Replace($s, '\beyJ[a-zA-Z0-9_\-]{5,}\.[a-zA-Z0-9_\-]{5,}\.[a-zA-Z0-9_\-]{5,}', '[REDACTED-JWT]')
    return $s
}

function ConvertTo-CdtJsonValue {
    # Normalisiert Werte fuer ConvertTo-Json (Windows PowerShell 5.1): Datum -> ISO-Text, Enum -> Text,
    # Zeichenketten -> bereinigt (Geheimnisse entfernt), Auflistungen bleiben Arrays.
    param([AllowNull()][object]$Value, [int]$Depth = 0)
    if ($null -eq $Value) { return $null }
    if ($Depth -gt 14) { return (Protect-CdtText -Text ([string]$Value)) }
    if ($Value -is [string]) { return (Protect-CdtText -Text $Value) }
    if ($Value -is [char]) { return [string]$Value }
    if ($Value -is [DateTimeOffset]) { return (Get-CdtTimestamp -Value $Value) }
    if ($Value -is [datetime]) { return (Get-CdtTimestamp -Value $Value) }
    if ($Value -is [enum]) { return $Value.ToString() }
    if ($Value -is [bool] -or $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal] -or
        $Value -is [int16] -or $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or $Value -is [byte] -or $Value -is [single]) {
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $o = [ordered]@{}
        foreach ($k in @($Value.Keys)) { $o[[string]$k] = ConvertTo-CdtJsonValue -Value $Value[$k] -Depth ($Depth + 1) }
        return $o
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $o = [ordered]@{}
        foreach ($p in $Value.PSObject.Properties) { $o[$p.Name] = ConvertTo-CdtJsonValue -Value $p.Value -Depth ($Depth + 1) }
        return $o
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $list = New-Object System.Collections.ArrayList
        foreach ($item in $Value) { [void]$list.Add((ConvertTo-CdtJsonValue -Value $item -Depth ($Depth + 1))) }
        return , ($list.ToArray())
    }
    return (Protect-CdtText -Text ([string]$Value))
}

function ConvertTo-CdtJson {
    # JSON mit allen Nicht-ASCII-Zeichen als \uXXXX -> Datei ist reines ASCII (= gueltiges UTF-8 ohne BOM)
    param([AllowNull()][object]$InputObject, [switch]$Pretty)
    $norm = ConvertTo-CdtJsonValue -Value $InputObject
    if ($Pretty) { $json = ConvertTo-Json -InputObject $norm -Depth 30 }
    else { $json = ConvertTo-Json -InputObject $norm -Depth 30 -Compress }
    if ($null -eq $json) { return 'null' }
    $sb = New-Object System.Text.StringBuilder ($json.Length + 16)
    foreach ($ch in $json.ToCharArray()) {
        $code = [int]$ch
        if ($code -gt 126) { [void]$sb.Append(('\u{0:x4}' -f $code)) } else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

function ConvertTo-CdtHashtable {
    # ConvertFrom-Json (5.1) liefert PSCustomObject -> rekursiv in geordnete Hashtables/Arrays umwandeln
    param([AllowNull()][object]$InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [string]) { return $InputObject }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = ConvertTo-CdtHashtable -InputObject $p.Value }
        return $h
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $h = [ordered]@{}
        foreach ($k in @($InputObject.Keys)) { $h[[string]$k] = ConvertTo-CdtHashtable -InputObject $InputObject[$k] }
        return $h
    }
    if ($InputObject -is [System.Collections.IEnumerable]) {
        $list = New-Object System.Collections.ArrayList
        foreach ($i in $InputObject) { [void]$list.Add((ConvertTo-CdtHashtable -InputObject $i)) }
        return , ($list.ToArray())
    }
    return $InputObject
}

function Add-CdtFileContent {
    # Anhaengen mit Wiederholung (andere Prozesse koennen kurzzeitig lesen); BOM nur bei neuer Datei
    param([string]$Path, [AllowEmptyString()][string]$Text, [bool]$Utf8Bom = $false)
    $enc = New-Object System.Text.UTF8Encoding($Utf8Bom)
    for ($i = 1; $i -le 6; $i++) {
        try { [System.IO.File]::AppendAllText($Path, $Text, $enc); return }
        catch {
            if ($i -eq 6) { throw }
            Start-Sleep -Milliseconds (150 * $i)
        }
    }
}

function Set-CdtFileContentAtomic {
    # Schreiben ueber temporaere Datei und Ersetzen -> keine halb geschriebenen Dateien
    param([string]$Path, [AllowEmptyString()][string]$Text, [bool]$Utf8Bom = $false)
    $enc = New-Object System.Text.UTF8Encoding($Utf8Bom)
    $tmp = '{0}.tmp-{1}' -f $Path, [guid]::NewGuid().ToString('N').Substring(0, 8)
    [System.IO.File]::WriteAllText($tmp, $Text, $enc)
    try {
        if (Test-Path -LiteralPath $Path) { [System.IO.File]::Replace($tmp, $Path, [NullString]::Value) }
        else { [System.IO.File]::Move($tmp, $Path) }
    }
    finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

function Format-CdtHResult {
    param([AllowNull()][object]$HResult)
    if ($null -eq $HResult -or [string]$HResult -eq '') { return $null }
    try {
        $v = [int64]$HResult
        if ($v -lt 0) { $v = $v + 4294967296 }
        return ('0x{0:X8}' -f $v)
    }
    catch { return [string]$HResult }
}

function Get-CdtErrorInfo {
    # Einheitliche, bereinigte Fehlerbeschreibung (HRESULT bevorzugt aus COM-/inneren Ausnahmen)
    param([AllowNull()][object]$InputObject)
    $ex = $null
    if ($InputObject -is [System.Management.Automation.ErrorRecord]) { $ex = $InputObject.Exception }
    elseif ($InputObject -is [System.Exception]) { $ex = $InputObject }
    if ($null -eq $ex) {
        return [pscustomobject]@{ HResult = $null; Code = $null; Message = (Protect-CdtText -Text ([string]$InputObject)); Type = $null }
    }
    $generic = @(-2146233087, -2146233088, 0)
    $hr = $ex.HResult
    if ($ex -is [System.Runtime.InteropServices.COMException]) { $hr = $ex.ErrorCode }
    $inner = $ex.InnerException
    $depth = 0
    while ($null -ne $inner -and $depth -lt 6) {
        if ($generic -contains $hr -and $generic -notcontains $inner.HResult) { $hr = $inner.HResult }
        $inner = $inner.InnerException
        $depth++
    }
    $msg = ([string]$ex.Message) -replace '\s+', ' '
    if ($msg.Length -gt 1500) { $msg = $msg.Substring(0, 1500) + ' ...' }
    if ($InputObject -is [System.Management.Automation.ErrorRecord] -and $null -ne $InputObject.InvocationInfo -and $InputObject.InvocationInfo.ScriptLineNumber -gt 0) {
        $msg = '{0} (Scriptzeile {1})' -f $msg, $InputObject.InvocationInfo.ScriptLineNumber
    }
    return [pscustomobject]@{ HResult = $hr; Code = (Format-CdtHResult -HResult $hr); Message = (Protect-CdtText -Text $msg); Type = $ex.GetType().FullName }
}

function Get-CdtErrorClassification {
    # Ordnet einen Fehlercode einer Kategorie zu und entscheidet, ob eine Wiederholung sinnvoll ist
    param([AllowNull()][object]$Code)
    $key = [string]$Code
    if ($key -match '^-?\d+$') { $key = Format-CdtHResult -HResult ([int64]$key) }
    if ($null -ne $key) { $key = $key.ToUpperInvariant().Replace('0X', '0x') }
    if ($null -ne $key -and $CdtErrorCatalog.ContainsKey($key)) {
        $e = $CdtErrorCatalog[$key]
        return [pscustomobject]@{ Code = $key; Category = $e.Category; Transient = [bool]$e.Transient; Text = $e.Text; Known = $true }
    }
    return [pscustomobject]@{ Code = $key; Category = 'Unknown'; Transient = $true; Text = 'Unbekannter Fehlercode (einmalige Wiederholung zulaessig)'; Known = $false }
}

function Invoke-CdtNativeCommand {
    # Externes Programm mit Zeitlimit, ohne NativeCommandError-Fallstricke (5.1)
    param([string]$FilePath, [string]$Arguments, [int]$TimeoutSeconds = 120)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    try {
        [void]$p.Start()
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
        $exited = $p.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) { try { $p.Kill() } catch { Write-Verbose 'Prozess bereits beendet.' } }
        else { $p.WaitForExit() }
        $out = ''
        $err = ''
        try { if ($outTask.Wait(5000)) { $out = $outTask.Result } } catch { $out = '' }
        try { if ($errTask.Wait(5000)) { $err = $errTask.Result } } catch { $err = '' }
        $code = $null
        if ($exited) { $code = $p.ExitCode }
        return [pscustomobject]@{ ExitCode = $code; TimedOut = (-not $exited); StdOut = [string]$out; StdErr = [string]$err }
    }
    finally { $p.Dispose() }
}

function Get-CdtRegistryValues {
    # Liest Werte ueber .NET (64-Bit-Ansicht, Schluessel werden sofort geschlossen -> hive unload moeglich)
    param([ValidateSet('LocalMachine', 'Users')][string]$Hive, [string]$SubKey, [AllowNull()][string[]]$Names)
    $result = [ordered]@{ KeyExists = $false; Values = [ordered]@{}; Kinds = [ordered]@{}; Error = $null }
    $base = $null
    $key = $null
    try {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::$Hive, [Microsoft.Win32.RegistryView]::Registry64)
        $key = $base.OpenSubKey($SubKey, $false)
        if ($null -ne $key) {
            $result.KeyExists = $true
            $present = @($key.GetValueNames())
            $targets = $Names
            if ($null -eq $targets -or $targets.Count -eq 0) { $targets = $present }
            foreach ($n in $targets) {
                if ($present -contains $n) {
                    $result.Values[$n] = $key.GetValue($n, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                    $result.Kinds[$n] = $key.GetValueKind($n).ToString()
                }
            }
        }
    }
    catch { $result.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    finally {
        if ($null -ne $key) { $key.Close() }
        if ($null -ne $base) { $base.Close() }
    }
    return $result
}

function Test-CdtRegistryKey {
    param([ValidateSet('LocalMachine', 'Users')][string]$Hive, [string]$SubKey)
    $base = $null
    $key = $null
    try {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::$Hive, [Microsoft.Win32.RegistryView]::Registry64)
        $key = $base.OpenSubKey($SubKey, $false)
        return ($null -ne $key)
    }
    catch { return $false }
    finally {
        if ($null -ne $key) { $key.Close() }
        if ($null -ne $base) { $base.Close() }
    }
}

function Get-CdtRegistryValueOrNull {
    param([ValidateSet('LocalMachine', 'Users')][string]$Hive, [string]$SubKey, [string]$Name)
    $r = Get-CdtRegistryValues -Hive $Hive -SubKey $SubKey -Names @($Name)
    if ($r.Values.Contains($Name)) { return $r.Values[$Name] }
    return $null
}

function Get-CdtFreeSpaceBytes {
    param([string]$Path)
    try {
        $root = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetFullPath($Path))
        return [int64](New-Object System.IO.DriveInfo($root)).AvailableFreeSpace
    }
    catch { return $null }
}

function Get-CdtCultureTag {
    # LCID (hex, z. B. '0407') -> BCP-47-Tag
    param([AllowNull()][string]$LcidHex)
    if ([string]::IsNullOrWhiteSpace($LcidHex)) { return $null }
    try { return [System.Globalization.CultureInfo]::GetCultureInfo([Convert]::ToInt32($LcidHex.Trim(), 16)).Name }
    catch { return $null }
}

# =====================================================================================================
# KONFIGURATION AUFLOESEN (Standard < Variable < Umgebung < Argumente)
# =====================================================================================================
function ConvertTo-CdtBoolean {
    param([AllowNull()][object]$Value)
    if ($Value -is [bool]) { return $Value }
    if ($Value -is [System.Management.Automation.SwitchParameter]) { return [bool]$Value }
    $s = ([string]$Value).Trim().ToLowerInvariant()
    if (@('1', 'true', '$true', 'yes', 'ja', 'on') -contains $s) { return $true }
    if (@('0', 'false', '$false', 'no', 'nein', 'off') -contains $s) { return $false }
    throw ('Kein gueltiger Wahrheitswert: "{0}"' -f $Value)
}

function ConvertTo-CdtStringArray {
    param([AllowNull()][object]$Value)
    $list = New-Object System.Collections.ArrayList
    foreach ($item in (ConvertTo-CdtArray -InputObject $Value)) {
        foreach ($part in @(([string]$item) -split '[,;]' | Where-Object { $_ -ne '' })) {
            $t = $part.Trim()
            if ($t.Length -gt 0) { [void]$list.Add($t) }
        }
    }
    return , ($list.ToArray())
}

function ConvertTo-CdtConfigValue {
    param([string]$Key, [AllowNull()][object]$Value, [string]$Spec)
    $parts = $Spec.Split(':')
    switch ($parts[0]) {
        'String' { return [string]$Value }
        'Bool' { return (ConvertTo-CdtBoolean -Value $Value) }
        'Int' {
            $i = 0
            if (-not [int]::TryParse(([string]$Value).Trim(), [ref]$i)) { throw ('{0}: keine Ganzzahl ("{1}")' -f $Key, $Value) }
            if ($parts.Count -ge 3 -and ($i -lt [int]$parts[1] -or $i -gt [int]$parts[2])) { throw ('{0}: {1} ausserhalb {2}..{3}' -f $Key, $i, $parts[1], $parts[2]) }
            return $i
        }
        'Enum' {
            foreach ($a in $parts[1].Split(',')) { if ($a -ieq ([string]$Value).Trim()) { return $a } }
            throw ('{0}: "{1}" nicht zulaessig (erlaubt: {2})' -f $Key, $Value, $parts[1])
        }
        'StringArray' { return , (ConvertTo-CdtStringArray -Value $Value) }
        'CapabilityArray' {
            $out = New-Object System.Collections.ArrayList
            foreach ($c in (ConvertTo-CdtStringArray -Value $Value)) {
                $match = $null
                foreach ($k in $CdtKnownCapabilities) { if ($k -ieq $c) { $match = $k } }
                if ($null -eq $match) { throw ('{0}: unbekannte Sprachkomponente "{1}" (erlaubt: {2})' -f $Key, $c, ($CdtKnownCapabilities -join ', ')) }
                if (-not $out.Contains($match)) { [void]$out.Add($match) }
            }
            return , ($out.ToArray())
        }
        default { throw ('Unbekannte Spezifikation {0}' -f $Spec) }
    }
}

function ConvertFrom-CdtArgumentList {
    # Benannte Argumente ohne param()-Block: -Name Wert | -Name:Wert | -Schalter
    param([AllowNull()][object[]]$ArgumentList)
    $map = [ordered]@{}
    $errors = New-Object System.Collections.ArrayList
    $list = @(ConvertTo-CdtArray -InputObject $ArgumentList)
    $i = 0
    while ($i -lt $list.Count) {
        $token = [string]$list[$i]
        if ($token -match '^-{1,2}([A-Za-z][A-Za-z0-9]*)(:(.*))?$') {
            $name = $Matches[1]
            if ($null -ne $Matches[2]) { $map[$name] = $Matches[3]; $i++; continue }
            if (($i + 1) -lt $list.Count -and -not ([string]$list[$i + 1] -match '^-{1,2}[A-Za-z]')) {
                $map[$name] = $list[$i + 1]
                $i += 2
                continue
            }
            $map[$name] = $true
            $i++
            continue
        }
        [void]$errors.Add(('Unerwartetes Argument: "{0}"' -f $token))
        $i++
    }
    return [pscustomobject]@{ Values = $map; Errors = @($errors) }
}

function Resolve-CdtConfiguration {
    param([AllowNull()][object[]]$ArgumentList)
    $cfg = [ordered]@{}
    foreach ($k in $CdtDefaultConfig.Keys) {
        $v = $CdtDefaultConfig[$k]
        if ($v -is [array]) { $cfg[$k] = @($v) } else { $cfg[$k] = $v }
    }
    $origin = [ordered]@{}
    $errors = New-Object System.Collections.ArrayList
    $warnings = New-Object System.Collections.ArrayList

    $layers = New-Object System.Collections.ArrayList
    $preset = Get-Variable -Name 'CdtDeLangConfig' -ValueOnly -ErrorAction SilentlyContinue
    if ($preset -is [System.Collections.IDictionary]) { [void]$layers.Add(@{ Name = 'Variable $CdtDeLangConfig'; Values = $preset; Strict = $false }) }
    $single = [ordered]@{}
    foreach ($k in $CdtConfigSpec.Keys) {
        $v = Get-Variable -Name ('CdtDeLang' + $k) -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $v) { $single[$k] = $v }
    }
    if ($single.Count -gt 0) { [void]$layers.Add(@{ Name = 'Variable $CdtDeLang<Schluessel>'; Values = $single; Strict = $true }) }
    if (-not [string]::IsNullOrEmpty($env:CDT_DELANG_CONFIG_JSON)) {
        try { [void]$layers.Add(@{ Name = 'Umgebung CDT_DELANG_CONFIG_JSON'; Values = (ConvertTo-CdtHashtable -InputObject ($env:CDT_DELANG_CONFIG_JSON | ConvertFrom-Json)); Strict = $false }) }
        catch { [void]$errors.Add('CDT_DELANG_CONFIG_JSON ist kein gueltiges JSON') }
    }
    $envValues = [ordered]@{}
    foreach ($k in $CdtConfigSpec.Keys) {
        $v = [Environment]::GetEnvironmentVariable('CDT_DELANG_' + $k.ToUpperInvariant())
        if (-not [string]::IsNullOrEmpty($v)) { $envValues[$k] = $v }
    }
    if ($envValues.Count -gt 0) { [void]$layers.Add(@{ Name = 'Umgebung CDT_DELANG_<SCHLUESSEL>'; Values = $envValues; Strict = $true }) }
    $parsed = ConvertFrom-CdtArgumentList -ArgumentList $ArgumentList
    foreach ($e in $parsed.Errors) { [void]$errors.Add($e) }
    if ($parsed.Values.Count -gt 0) { [void]$layers.Add(@{ Name = 'Argumente'; Values = $parsed.Values; Strict = $true }) }

    foreach ($layer in $layers) {
        foreach ($rawKey in @($layer.Values.Keys)) {
            $key = $null
            foreach ($k in $CdtConfigSpec.Keys) { if ($k -ieq [string]$rawKey) { $key = $k } }
            if ($null -eq $key) {
                $msg = 'Unbekannter Konfigurationsschluessel "{0}" ({1})' -f $rawKey, $layer.Name
                if ($layer.Strict) { [void]$errors.Add($msg) } else { [void]$warnings.Add($msg) }
                continue
            }
            try {
                $cfg[$key] = ConvertTo-CdtConfigValue -Key $key -Value $layer.Values[$rawKey] -Spec $CdtConfigSpec[$key]
                $origin[$key] = $layer.Name
            }
            catch { [void]$errors.Add(('{0}: {1}' -f $layer.Name, $_.Exception.Message)) }
        }
    }
    return [pscustomobject]@{ Config = $cfg; Origin = $origin; Errors = @($errors); Warnings = @($warnings) }
}

function Register-CdtKnownSecret {
    # Werte bekannter Orchestrierungs-Geheimnisse fuer die Log-Bereinigung vormerken (nie protokollieren)
    foreach ($n in @('ADPassword', 'DesktopUserPassword')) {
        $v = Get-Variable -Name $n -ValueOnly -ErrorAction SilentlyContinue
        if ($v -is [string] -and $v.Length -ge 4) { $CdtSecretValues.Add($v) }
    }
    $sv = Get-Variable -Name 'SecureVars' -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $sv) {
        $values = @()
        if ($sv -is [System.Collections.IDictionary]) { $values = @($sv.Values) } else { $values = @($sv.PSObject.Properties | ForEach-Object { $_.Value }) }
        foreach ($v in $values) { if ($v -is [string] -and $v.Length -ge 4) { $CdtSecretValues.Add($v) } }
    }
}

# =====================================================================================================
# LOGGING (Text-Log UTF-8 mit BOM, JSONL/JSON reines ASCII)
# =====================================================================================================
function Write-CdtConsole {
    param([string]$Message)
    $m = Protect-CdtText -Text $Message
    if ($m.Length -gt 400) { $m = $m.Substring(0, 400) + ' ...' }
    Write-Host ('[DE-LANG] {0}' -f $m)
}

function Write-CdtLog {
    param(
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR', 'CHECK')][string]$Level = 'INFO',
        [string]$Phase = 'General',
        [string]$Action = '',
        [string]$Message = '',
        [AllowNull()][object]$Data = $null,
        [string]$Result = '',
        [AllowNull()][object]$ErrorCode = $null,
        [string]$ErrorMessage = '',
        [AllowNull()][object]$DurationMs = $null,
        [string]$Source = '',
        [AllowNull()][object]$Attempt = $null,
        [string]$PreviousState = '',
        [string]$TargetState = '',
        [string]$ResultState = '',
        [string]$Recommendation = '',
        [AllowNull()][object]$Check = $null,
        [switch]$Console
    )
    $now = [DateTimeOffset]::Now
    $Cdt.Seq = [int]$Cdt.Seq + 1
    $nz = { param($v) if ([string]::IsNullOrEmpty([string]$v)) { $null } else { $v } }
    $evt = [ordered]@{
        schema         = 'cdt.delang.event'
        schemaVersion  = $CdtLogSchemaVersion
        scriptVersion  = $CdtScriptVersion
        ts             = Get-CdtTimestamp -Value $now
        tsUtc          = Get-CdtUtcTimestamp -Value $now
        runId          = $Cdt.RunId
        seq            = $Cdt.Seq
        level          = $Level
        vm             = $Cdt.VmName
        vmNameSource   = $Cdt.VmNameSource
        computer       = $env:COMPUTERNAME
        os             = $Cdt.OsSummary
        ctx            = $Cdt.CtxSummary
        mode           = $(if ($null -ne $Cdt.Config) { $Cdt.Config.Mode } else { $null })
        effectiveMode  = (& $nz $Cdt.EffectiveMode)
        phase          = $Phase
        action         = (& $nz $Action)
        source         = (& $nz $Source)
        attempt        = $Attempt
        durationMs     = $DurationMs
        previousState  = (& $nz $PreviousState)
        targetState    = (& $nz $TargetState)
        resultState    = (& $nz $ResultState)
        result         = (& $nz $Result)
        errorCode      = (& $nz $ErrorCode)
        errorMessage   = (& $nz $ErrorMessage)
        check          = $Check
        recommendation = (& $nz $Recommendation)
        message        = $Message
        data           = $Data
    }
    $json = ConvertTo-CdtJson -InputObject $evt
    $parts = New-Object System.Collections.ArrayList
    [void]$parts.Add(('{0} [{1,-5}] [{2}{3}] {4}' -f $evt.ts, $Level, $Phase, $(if ($Action) { '/' + $Action } else { '' }), (Protect-CdtText -Text $Message)))
    if ($TargetState -or $ResultState) { [void]$parts.Add(('Soll={0} Ist={1}' -f $TargetState, $ResultState)) }
    if ($PreviousState) { [void]$parts.Add(('Vorher={0}' -f $PreviousState)) }
    if ($Source) { [void]$parts.Add(('Quelle={0}' -f $Source)) }
    if ($null -ne $Attempt) { [void]$parts.Add(('Versuch={0}' -f $Attempt)) }
    if ($null -ne $DurationMs) { [void]$parts.Add(('Dauer={0:N1}s' -f ([double]$DurationMs / 1000))) }
    if ($ErrorCode) { [void]$parts.Add(('Code={0}' -f $ErrorCode)) }
    if ($ErrorMessage) { [void]$parts.Add(('Fehler={0}' -f (Protect-CdtText -Text $ErrorMessage))) }
    if ($Recommendation) { [void]$parts.Add(('Empfehlung: {0}' -f (Protect-CdtText -Text $Recommendation))) }
    $line = ($parts -join ' | ')
    if ($null -ne $Cdt.Log -and $Cdt.Log.Ready) {
        try {
            Add-CdtFileContent -Path $Cdt.Log.Text -Text ($line + "`r`n") -Utf8Bom $true
            Add-CdtFileContent -Path $Cdt.Log.Jsonl -Text ($json + "`n") -Utf8Bom $false
        }
        catch { Write-Host ('[DE-LANG] WARNUNG: Logeintrag konnte nicht geschrieben werden: {0}' -f $_.Exception.Message) }
    }
    else { $CdtEarlyLog.Add(@{ Line = $line; Json = $json }) }
    if ($Console -or $Level -eq 'ERROR') { Write-CdtConsole -Message $Message }
}

function Write-CdtEmergencyLog {
    # Nur wenn das vorgeschriebene Log-Verzeichnis nicht beschreibbar ist: Diagnose an Ersatzort + Konsole
    param([string]$Message)
    $path = $null
    try {
        $root = $env:SystemRoot
        if ([string]::IsNullOrEmpty($root)) { $root = [System.IO.Path]::GetTempPath() } else { $root = Join-Path $root 'Temp' }
        $path = Join-Path $root ('{0}_LOGGING-FAILURE_{1}.log' -f $CdtProductName, (Get-Date -Format 'yyyy-MM-dd'))
        Add-CdtFileContent -Path $path -Text ('{0} {1} RunId={2}{3}' -f (Get-CdtTimestamp), (Protect-CdtText -Text $Message), $Cdt.RunId, "`r`n") -Utf8Bom $true
        foreach ($e in $CdtEarlyLog) { Add-CdtFileContent -Path $path -Text ($e.Line + "`r`n") -Utf8Bom $true }
    }
    catch { $path = $null }
    return $path
}

function Initialize-CdtLogging {
    $root = $Cdt.Config.LogRoot
    $dateText = $Cdt.StartTime.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    $base = '{0}_INSTALL-DE_{1}' -f $Cdt.VmName, $dateText
    $Cdt.Log = [ordered]@{
        Root       = $root
        StateDir   = (Join-Path $root 'state')
        WorkDir    = (Join-Path $root 'work')
        Text       = (Join-Path $root ($base + '.log'))
        Jsonl      = (Join-Path $root ($base + '.jsonl'))
        Summary    = (Join-Path $root ($base + '.summary.json'))
        MissingTxt = (Join-Path $root 'missing-network-requirements.txt')
        MissingCsv = (Join-Path $root 'missing-network-requirements.csv')
        Ready      = $false
        Error      = $null
    }
    try {
        foreach ($d in @($root, $Cdt.Log.StateDir)) {
            if (-not (Test-Path -LiteralPath $d -PathType Container)) { [void](New-Item -ItemType Directory -Path $d -Force) }
        }
        Add-CdtFileContent -Path $Cdt.Log.Text -Text '' -Utf8Bom $true
        Add-CdtFileContent -Path $Cdt.Log.Jsonl -Text '' -Utf8Bom $false
        $probe = Join-Path $Cdt.Log.StateDir ('.writetest-' + $Cdt.RunId)
        [System.IO.File]::WriteAllText($probe, 'ok')
        Remove-Item -LiteralPath $probe -Force
        $Cdt.Log.Ready = $true
    }
    catch { $Cdt.Log.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    if ($Cdt.Log.Ready) {
        foreach ($e in $CdtEarlyLog) {
            Add-CdtFileContent -Path $Cdt.Log.Text -Text ($e.Line + "`r`n") -Utf8Bom $true
            Add-CdtFileContent -Path $Cdt.Log.Jsonl -Text ($e.Json + "`n") -Utf8Bom $false
        }
        $CdtEarlyLog.Clear()
    }
    return [bool]$Cdt.Log.Ready
}

# =====================================================================================================
# SPERRE GEGEN PARALLELE AUSFUEHRUNG
# =====================================================================================================
function Enter-CdtLock {
    $r = [ordered]@{ Acquired = $false; Abandoned = $false; Mutex = $null; Holder = $null; Error = $null }
    try {
        $created = $false
        $m = New-Object System.Threading.Mutex($false, 'Global\CDT-STANDARD-INSTALL-DE_LANG', [ref]$created)
        $ok = $false
        try { $ok = $m.WaitOne([TimeSpan]::FromSeconds(5)) }
        catch [System.Threading.AbandonedMutexException] { $ok = $true; $r.Abandoned = $true }
        if ($ok) { $r.Acquired = $true; $r.Mutex = $m } else { $m.Dispose() }
    }
    catch [System.UnauthorizedAccessException] { $r.Error = 'Sperrobjekt existiert, Zugriff verweigert (laufende Instanz in anderem Kontext)' }
    catch { $r.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    $lockFile = Join-Path $Cdt.Log.StateDir 'run.lock.json'
    if ($r.Acquired) {
        try { Set-CdtFileContentAtomic -Path $lockFile -Text (ConvertTo-CdtJson -InputObject ([ordered]@{ runId = $Cdt.RunId; pid = $PID; startedUtc = (Get-CdtUtcTimestamp); identity = [Environment]::UserName })) }
        catch { Write-Verbose 'Lock-Info nicht geschrieben.' }
    }
    elseif (Test-Path -LiteralPath $lockFile) {
        try { $r.Holder = ConvertTo-CdtHashtable -InputObject ([System.IO.File]::ReadAllText($lockFile) | ConvertFrom-Json) } catch { $r.Holder = $null }
    }
    return $r
}

function Exit-CdtLock {
    param([AllowNull()][object]$Lock)
    if ($null -eq $Lock -or -not $Lock.Acquired) { return }
    try { Remove-Item -LiteralPath (Join-Path $Cdt.Log.StateDir 'run.lock.json') -Force -ErrorAction SilentlyContinue } catch { Write-Verbose 'Lock-Info nicht entfernt.' }
    try { $Lock.Mutex.ReleaseMutex() } catch { Write-Verbose 'Mutex bereits freigegeben.' }
    try { $Lock.Mutex.Dispose() } catch { Write-Verbose 'Mutex bereits entsorgt.' }
}

# =====================================================================================================
# FORTSETZUNGSZUSTAND (maschinengebunden; historische Daten anderer Systeme werden ignoriert)
# =====================================================================================================
function New-CdtEmptyState {
    return [ordered]@{
        schema              = 'cdt.delang.state'
        schemaVersion       = $CdtLogSchemaVersion
        machineBinding      = $null
        updatedUtc          = $null
        pendingVerification = $null
        applyRounds         = 0
        bootChanges         = $null
        utf8Baseline        = $null
        temporary           = [ordered]@{ tasksDisabled = @(); isoMounts = @() }
        network             = [ordered]@{ lastCheck = $null }
        lastOutcome         = $null
    }
}

function Get-CdtMachineBinding {
    return [ordered]@{ computerName = $env:COMPUTERNAME; smbiosUuid = $Cdt.Platform.SmbiosUuid; osInstallDate = $Cdt.Platform.InstallDateUtc }
}

function Test-CdtMachineBinding {
    param([AllowNull()][object]$Stored, [System.Collections.IDictionary]$Current)
    if ($null -eq $Stored) { return $false }
    if ([string]$Stored.computerName -ne [string]$Current.computerName) { return $false }
    if (-not [string]::IsNullOrEmpty([string]$Stored.smbiosUuid) -and -not [string]::IsNullOrEmpty([string]$Current.smbiosUuid)) {
        return ([string]$Stored.smbiosUuid -eq [string]$Current.smbiosUuid)
    }
    return ((ConvertTo-CdtUtcKey -Value $Stored.osInstallDate) -eq (ConvertTo-CdtUtcKey -Value $Current.osInstallDate))
}

function Read-CdtState {
    $path = Join-Path $Cdt.Log.StateDir 'CDT-STANDARD-INSTALL-DE_LANG.state.json'
    $Cdt.StatePath = $path
    $state = New-CdtEmptyState
    $binding = Get-CdtMachineBinding
    $state.machineBinding = $binding
    if ($Cdt.Config.ResetState) {
        Write-CdtLog -Level WARN -Phase 'State' -Action 'Reset' -Message 'ResetState aktiv: gespeicherter Fortsetzungszustand wird verworfen.'
        return $state
    }
    if (-not (Test-Path -LiteralPath $path)) { return $state }
    $loaded = $null
    try { $loaded = ConvertTo-CdtHashtable -InputObject ([System.IO.File]::ReadAllText($path) | ConvertFrom-Json) }
    catch {
        $bad = '{0}.corrupt-{1}' -f $path, (Get-Date -Format 'yyyyMMddHHmmss')
        try { Move-Item -LiteralPath $path -Destination $bad -Force } catch { Write-Verbose 'Umbenennen fehlgeschlagen.' }
        Write-CdtLog -Level WARN -Phase 'State' -Action 'Read' -Message ('Zustandsdatei unlesbar, gesichert als {0}; Neustart mit leerem Zustand.' -f $bad)
        return $state
    }
    if (-not (Test-CdtMachineBinding -Stored $loaded.machineBinding -Current $binding)) {
        Write-CdtLog -Level INFO -Phase 'State' -Action 'Binding' -Message 'Gespeicherter Zustand gehoert zu einem anderen System (z. B. aus dem Master uebernommen) und wird fuer Entscheidungen ignoriert.' -Data ([ordered]@{ stored = $loaded.machineBinding; current = $binding; lastOutcome = $loaded.lastOutcome })
        return $state
    }
    foreach ($k in @($state.Keys)) { if ($loaded.Contains($k) -and $null -ne $loaded[$k]) { $state[$k] = $loaded[$k] } }
    if ($null -eq $state.temporary) { $state.temporary = [ordered]@{ tasksDisabled = @(); isoMounts = @() } }
    foreach ($k in @('tasksDisabled', 'isoMounts')) { if (-not $state.temporary.Contains($k) -or $null -eq $state.temporary[$k]) { $state.temporary[$k] = @() } }
    if ($null -eq $state.network) { $state.network = [ordered]@{ lastCheck = $null } }
    $state.machineBinding = $binding
    return $state
}

function Save-CdtState {
    if ($null -eq $Cdt.State -or [string]::IsNullOrEmpty($Cdt.StatePath)) { return }
    try {
        $Cdt.State.updatedUtc = Get-CdtUtcTimestamp
        Set-CdtFileContentAtomic -Path $Cdt.StatePath -Text (ConvertTo-CdtJson -InputObject $Cdt.State -Pretty) -Utf8Bom $false
    }
    catch { Write-CdtLog -Level WARN -Phase 'State' -Action 'Save' -Message 'Zustandsdatei konnte nicht gespeichert werden.' -ErrorMessage (Get-CdtErrorInfo -InputObject $_).Message }
}

function Add-CdtBootChange {
    # Merkt neustartrelevante Aenderungen dieses Boots (persistiert, damit ein Abbruch sie nicht verliert)
    param([string]$Item)
    $bc = $Cdt.State.bootChanges
    if ($null -eq $bc -or (ConvertTo-CdtUtcKey -Value $bc.bootTimeUtc) -ne (ConvertTo-CdtUtcKey -Value $Cdt.Platform.LastBootUtc)) {
        $Cdt.State.bootChanges = [ordered]@{ bootTimeUtc = $Cdt.Platform.LastBootUtc; items = @() }
    }
    if (@($Cdt.State.bootChanges.items) -notcontains $Item) { $Cdt.State.bootChanges.items = @($Cdt.State.bootChanges.items) + @($Item) }
    if (-not $Cdt.ChangesThisRun.Contains($Item)) { [void]$Cdt.ChangesThisRun.Add($Item) }
    Save-CdtState
}

function Test-CdtChangedThisBoot {
    param([string]$Item)
    $bc = $Cdt.State.bootChanges
    if ($null -eq $bc) { return $false }
    return ((ConvertTo-CdtUtcKey -Value $bc.bootTimeUtc) -eq (ConvertTo-CdtUtcKey -Value $Cdt.Platform.LastBootUtc) -and @($bc.items) -contains $Item)
}

# =====================================================================================================
# PLATTFORM, AUSFUEHRUNGSKONTEXT, VORAUSSETZUNGEN
# =====================================================================================================
function Resolve-CdtRelease {
    # Release ausschliesslich ueber die Zuordnungstabelle (Build); DisplayVersion wird gegengeprueft
    param([int]$Build, [AllowNull()][string]$DisplayVersion, [object[]]$ReleaseMap)
    $r = [ordered]@{ Release = $null; Mapped = $false; FallbackApproved = $false; Source = $null; Evidence = $null; DisplayVersion = $DisplayVersion; DisplayVersionMismatch = $false; Note = '' }
    foreach ($e in $ReleaseMap) {
        if ([int]$e.Build -eq $Build) {
            $r.Release = $e.Release
            $r.Mapped = $true
            $r.FallbackApproved = [bool]$e.FallbackApproved
            $r.Source = $e.Source
            $r.Evidence = $e.Evidence
        }
    }
    if ($r.Mapped -and -not [string]::IsNullOrEmpty($DisplayVersion) -and $DisplayVersion -ne $r.Release) {
        $r.DisplayVersionMismatch = $true
        $r.Note = 'DisplayVersion {0} passt nicht zu Build {1} ({2})' -f $DisplayVersion, $Build, $r.Release
    }
    if (-not $r.Mapped) { $r.Note = 'Build {0} (DisplayVersion {1}) ist keinem freigegebenen Release zugeordnet' -f $Build, $DisplayVersion }
    return $r
}

function Get-CdtEditionClass {
    # Unterscheidet technische Eignung von der AVD-Zielplattform (keine Umgehung von Editionsgrenzen)
    param([AllowNull()][string]$EditionId, [int]$Sku, [int]$ProductType, [AllowNull()][string]$InstallationType)
    $c = [ordered]@{ Class = 'Unknown'; Supported = $false; AvdTarget = $false; LanguageRestricted = $false; Note = '' }
    if ($ProductType -ne 1 -or $InstallationType -eq 'Server') {
        $c.Class = 'Server'; $c.Note = 'Server-Betriebssystem: LanguagePackManagement ist nur fuer Client-Betriebssysteme unterstuetzt.'
        return $c
    }
    if (@('CoreSingleLanguage', 'CoreCountrySpecific') -contains $EditionId -or @(99, 100) -contains $Sku) {
        $c.Class = 'LanguageRestricted'; $c.LanguageRestricted = $true
        $c.Note = 'Sprachbeschraenkte Edition (Single Language/Country Specific): Anzeigesprache lizenzrechtlich festgelegt; keine Umgehung.'
        return $c
    }
    if ($Sku -eq 175 -or @('ServerRdsh', 'EnterpriseMultiSession') -contains $EditionId) {
        $c.Class = 'EnterpriseMultiSession'; $c.Supported = $true; $c.AvdTarget = $true; $c.Note = 'Windows Enterprise multi-session (SKU 175).'
        return $c
    }
    if (@('Enterprise', 'EnterpriseN') -contains $EditionId) {
        $c.Class = 'Enterprise'; $c.Supported = $true; $c.AvdTarget = $true; $c.Note = 'Windows Enterprise (Single-Session).'
        return $c
    }
    if (@('EnterpriseS', 'EnterpriseSN', 'IoTEnterprise', 'IoTEnterpriseS', 'Professional', 'ProfessionalN', 'ProfessionalWorkstation', 'ProfessionalWorkstationN',
            'ProfessionalEducation', 'ProfessionalEducationN', 'Education', 'EducationN', 'Core', 'CoreN') -contains $EditionId) {
        $c.Class = 'TechnicallyPossible'; $c.Supported = $true
        $c.Note = ('Edition {0}: Sprachinstallation technisch moeglich, aber keine AVD-Zielplattform (keine Supportfreigabe).' -f $EditionId)
        return $c
    }
    $c.Note = ('Edition {0} (SKU {1}) nicht eingeordnet.' -f $EditionId, $Sku)
    return $c
}

function Get-CdtPlatformInfo {
    $p = [ordered]@{
        Caption = $null; ProductName = $null; EditionId = $null; Sku = 0; DisplayVersion = $null; Build = 0; Ubr = 0
        Version = $null; Architecture = $null; ProductType = 0; InstallationType = $null; IsClient = $false; IsWindows11 = $false
        ReleaseInfo = $null; EditionClass = $null; LastBootUtc = $null; SmbiosUuid = $null; InstallDateUtc = $null
        InstallLanguageLcid = $null; InstallLanguageTag = $null; Errors = @()
    }
    $errs = New-Object System.Collections.ArrayList
    $cv = Get-CdtRegistryValues -Hive LocalMachine -SubKey 'SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Names @('ProductName', 'EditionID', 'DisplayVersion', 'CurrentBuild', 'UBR', 'InstallationType', 'InstallDate')
    $p.ProductName = [string]$cv.Values['ProductName']
    $p.EditionId = [string]$cv.Values['EditionID']
    $p.DisplayVersion = [string]$cv.Values['DisplayVersion']
    $p.InstallationType = [string]$cv.Values['InstallationType']
    $build = 0
    if ([int]::TryParse([string]$cv.Values['CurrentBuild'], [ref]$build)) { $p.Build = $build }
    if ($null -ne $cv.Values['UBR']) { $p.Ubr = [int]$cv.Values['UBR'] }
    if ($null -ne $cv.Values['InstallDate']) {
        try { $p.InstallDateUtc = Get-CdtUtcTimestamp -Value ([DateTimeOffset]::FromUnixTimeSeconds([int64]$cv.Values['InstallDate'])) } catch { $p.InstallDateUtc = $null }
    }
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop -Verbose:$false
        $p.Caption = [string]$os.Caption
        $p.Version = [string]$os.Version
        $p.Sku = [int]$os.OperatingSystemSKU
        $p.ProductType = [int]$os.ProductType
        $p.LastBootUtc = $os.LastBootUpTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)
        if ($p.Build -eq 0) { $p.Build = [int]$os.BuildNumber }
    }
    catch { [void]$errs.Add('Win32_OperatingSystem: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    try { $p.SmbiosUuid = [string](Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop -Verbose:$false).UUID } catch { [void]$errs.Add('Win32_ComputerSystemProduct nicht lesbar') }
    $arch = $env:PROCESSOR_ARCHITEW6432
    if ([string]::IsNullOrEmpty($arch)) { $arch = $env:PROCESSOR_ARCHITECTURE }
    $p.Architecture = [string]$arch
    $p.IsClient = ($p.ProductType -eq 1 -and $p.InstallationType -ne 'Server')
    $p.IsWindows11 = ($p.IsClient -and $p.Build -ge 22000)
    $p.ReleaseInfo = Resolve-CdtRelease -Build $p.Build -DisplayVersion $p.DisplayVersion -ReleaseMap $CdtReleaseMap
    $p.EditionClass = Get-CdtEditionClass -EditionId $p.EditionId -Sku $p.Sku -ProductType $p.ProductType -InstallationType $p.InstallationType
    $p.InstallLanguageLcid = [string](Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\Nls\Language' -Name 'InstallLanguage')
    $p.InstallLanguageTag = Get-CdtCultureTag -LcidHex $p.InstallLanguageLcid
    $p.Errors = @($errs)
    return $p
}

function Get-CdtExecutionContext {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($id)
    $sid = $id.User.Value
    $isSystem = ($sid -eq 'S-1-5-18')
    $hint = 'Manuell/unbekannt'
    $path = [string]$PSCommandPath
    if ($null -ne (Get-Variable -Name 'AzureVMName' -ErrorAction SilentlyContinue) -or $path -match 'CustomScriptExtension') { $hint = 'NERDIO (Custom Script Extension) - Hinweis, kein Nachweis' }
    elseif ($null -ne (Get-Command -Name 'LogWriter' -CommandType Function -ErrorAction SilentlyContinue) -or $path -match 'RunCommand') { $hint = 'HYDRA/Run Command - Hinweis, kein Nachweis' }
    $sourceHive = $sid
    if ($isSystem) { $sourceHive = '.DEFAULT' }
    return [ordered]@{
        Identity         = $id.Name
        Sid              = $sid
        IsSystem         = $isSystem
        IsAdmin          = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        IsInteractive    = [Environment]::UserInteractive
        SessionId        = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
        Is64BitProcess   = [Environment]::Is64BitProcess
        Is64BitOs        = [Environment]::Is64BitOperatingSystem
        PSVersion        = $PSVersionTable.PSVersion.ToString()
        PSEdition        = [string]$PSVersionTable.PSEdition
        LanguageMode     = $ExecutionContext.SessionState.LanguageMode.ToString()
        HostName         = $Host.Name
        ProcessId        = $PID
        ScriptPath       = $path
        SourceHiveName   = $sourceHive
        OrchestratorHint = $hint
    }
}

function Test-CdtPrerequisites {
    $r = [ordered]@{ Ok = $true; Fatal = @(); Warnings = @(); Commands = [ordered]@{} }
    $fatal = New-Object System.Collections.ArrayList
    $warn = New-Object System.Collections.ArrayList
    $p = $Cdt.Platform
    $c = $Cdt.Context
    if ($c.LanguageMode -ne 'FullLanguage') { [void]$fatal.Add(('PowerShell LanguageMode {0}: FullLanguage erforderlich (WDAC/AppLocker-Freigabe fuer das Script pruefen).' -f $c.LanguageMode)) }
    if (-not ($c.IsSystem -or $c.IsAdmin)) { [void]$fatal.Add('Ausfuehrung weder als SYSTEM noch in erhoehter Administrator-Sitzung.') }
    if (-not $p.IsClient) { [void]$fatal.Add('Kein Windows-Client-Betriebssystem.') }
    elseif (-not $p.IsWindows11) { [void]$fatal.Add(('Windows 11 erforderlich (Build {0}).' -f $p.Build)) }
    if ($p.EditionClass.LanguageRestricted -or -not $p.EditionClass.Supported) { [void]$fatal.Add($p.EditionClass.Note) }
    elseif (-not $p.EditionClass.AvdTarget) {
        if ($Cdt.Config.AllowNonAvdEditions) { [void]$warn.Add($p.EditionClass.Note) } else { [void]$fatal.Add($p.EditionClass.Note + ' (AllowNonAvdEditions = false)') }
    }
    if (-not $p.ReleaseInfo.Mapped) {
        if ($Cdt.Config.AllowUnmappedRelease) { [void]$warn.Add($p.ReleaseInfo.Note + ' - Ausfuehrung durch AllowUnmappedRelease freigegeben.') }
        else { [void]$fatal.Add($p.ReleaseInfo.Note + ' (Zielsysteme: 24H2/25H2/26H2).') }
    }
    if ($p.ReleaseInfo.DisplayVersionMismatch) { [void]$warn.Add($p.ReleaseInfo.Note) }
    $required = [ordered]@{
        'Get-InstalledLanguage' = @(); 'Install-Language' = @('ExcludeFeatures'); 'Get-SystemPreferredUILanguage' = @(); 'Set-SystemPreferredUILanguage' = @()
        'Copy-UserInternationalSettingsToSystem' = @('WelcomeScreen', 'NewUser'); 'New-WinUserLanguageList' = @(); 'Get-WinUserLanguageList' = @(); 'Set-WinUserLanguageList' = @('Force')
        'Set-Culture' = @(); 'Get-WinSystemLocale' = @(); 'Set-WinSystemLocale' = @(); 'Get-WinHomeLocation' = @(); 'Set-WinHomeLocation' = @()
        'Get-WinUILanguageOverride' = @(); 'Set-WinUILanguageOverride' = @(); 'Get-WinDefaultInputMethodOverride' = @(); 'Set-WinDefaultInputMethodOverride' = @()
        'Get-TimeZone' = @(); 'Set-TimeZone' = @('Id'); 'Get-WindowsPackage' = @('Online', 'PackagePath'); 'Get-WindowsCapability' = @('Online', 'Name')
        'Add-WindowsCapability' = @('Online', 'Name', 'Source', 'LimitAccess'); 'Add-WindowsPackage' = @('Online', 'PackagePath', 'NoRestart'); 'Start-Job' = @()
    }
    $optional = [ordered]@{
        'Get-ScheduledTask' = @(); 'Disable-ScheduledTask' = @(); 'Enable-ScheduledTask' = @(); 'Mount-DiskImage' = @('StorageType', 'Access', 'PassThru')
        'Dismount-DiskImage' = @(); 'Get-DiskImage' = @(); 'Get-Volume' = @('DiskImage'); 'Get-AppxPackage' = @('AllUsers'); 'Get-AppxProvisionedPackage' = @('Online')
        'Get-AuthenticodeSignature' = @(); 'Get-DnsClientServerAddress' = @()
    }
    foreach ($set in @(@{ List = $required; Fatal = $true }, @{ List = $optional; Fatal = $false })) {
        foreach ($name in $set.List.Keys) {
            $cmd = Get-Command -Name $name -ErrorAction SilentlyContinue
            $status = 'OK'
            if ($null -eq $cmd) { $status = 'FEHLT' }
            else {
                $missing = @($set.List[$name] | Where-Object { -not $cmd.Parameters.ContainsKey($_) })
                if ($missing.Count -gt 0) { $status = 'Parameter fehlen: ' + ($missing -join ', ') }
            }
            $r.Commands[$name] = $status
            if ($status -ne 'OK') {
                $msg = 'Cmdlet {0}: {1}' -f $name, $status
                if ($set.Fatal) { [void]$fatal.Add($msg) } else { [void]$warn.Add($msg + ' (Funktion eingeschraenkt)') }
            }
        }
    }
    $r.Fatal = @($fatal)
    $r.Warnings = @($warn)
    $r.Ok = ($fatal.Count -eq 0)
    return $r
}

# =====================================================================================================
# KOMPONENTEN-ZUSTAND (CBS-Paket, Capabilities, Get-InstalledLanguage, MUI, Neustart)
# =====================================================================================================
function Get-CdtCapabilityName {
    param([string]$Feature, [string]$Language)
    return ('Language.{0}~~~{1}~0.0.1.0' -f $Feature, $Language)
}

function Get-CdtPendingReboot {
    $r = [ordered]@{
        CbsRebootPending         = Test-CdtRegistryKey -Hive LocalMachine -SubKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        CbsPackagesPending       = Test-CdtRegistryKey -Hive LocalMachine -SubKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending'
        WuRebootRequired         = Test-CdtRegistryKey -Hive LocalMachine -SubKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
        PendingFileRenameEntries = 0
        Any                      = $false
    }
    $pfro = Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations'
    if ($null -ne $pfro) { $r.PendingFileRenameEntries = @($pfro | Where-Object { -not [string]::IsNullOrEmpty($_) }).Count }
    # PendingFileRenameOperations allein ist haeufig und kein Servicing-Neustartbedarf -> nur Information
    $r.Any = ($r.CbsRebootPending -or $r.CbsPackagesPending -or $r.WuRebootRequired)
    return $r
}

function Resolve-CdtLanguagePackState {
    param([string]$CbsState, [AllowNull()][string]$InstalledLanguagePacks, [bool]$MuiRegistered, [bool]$IsBaseLanguage)
    if ($IsBaseLanguage) { return 'Installed' }
    $lpCab = ($null -ne $InstalledLanguagePacks -and $InstalledLanguagePacks -match 'LpCab')
    switch ($CbsState) {
        'Installed' { if ($MuiRegistered -and ($lpCab -or $null -eq $InstalledLanguagePacks)) { return 'Installed' } else { return 'Inconsistent' } }
        'InstallPending' { return 'InstallPending' }
        'NotPresent' { if ($lpCab) { return 'Inconsistent' } else { return 'NotPresent' } }
        'Unknown' { return 'Unknown' }
        default { return 'Inconsistent' }
    }
}

function Get-CdtComponentState {
    $lang = $Cdt.Config.Language
    $errs = New-Object System.Collections.ArrayList
    $lp = [ordered]@{ State = 'Unknown'; CbsState = 'Unknown'; PackageName = $null; InstalledLanguagePacks = $null; InstalledLanguageFeatures = $null; MuiRegistered = $false; IsBaseLanguage = $false }
    $lp.MuiRegistered = Test-CdtRegistryKey -Hive LocalMachine -SubKey ('SYSTEM\CurrentControlSet\Control\MUI\UILanguages\' + $lang)
    $lp.IsBaseLanguage = ([string]$Cdt.Platform.InstallLanguageTag -eq $lang)
    try {
        $pattern = '^Microsoft-Windows-Client-LanguagePack-Package~[^~]*~[^~]*~' + [regex]::Escape($lang) + '~'
        $pk = @(Get-WindowsPackage -Online -ErrorAction Stop -Verbose:$false | Where-Object { [string]$_.PackageName -match $pattern })
        if ($pk.Count -eq 0) { $lp.CbsState = 'NotPresent' }
        else {
            $rank = @{ 'Installed' = 0; 'InstallPending' = 1 }
            $best = $pk | Sort-Object -Property @{ Expression = { if ($rank.ContainsKey([string]$_.PackageState)) { $rank[[string]$_.PackageState] } else { 9 } } } | Select-Object -First 1
            $lp.CbsState = [string]$best.PackageState
            $lp.PackageName = [string]$best.PackageName
        }
    }
    catch { [void]$errs.Add('Get-WindowsPackage: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    try {
        $il = @(Get-InstalledLanguage -ErrorAction Stop | Where-Object { [string]$_.LanguageId -eq $lang })
        if ($il.Count -gt 0) {
            $lp.InstalledLanguagePacks = [string]$il[0].LanguagePacks
            $lp.InstalledLanguageFeatures = [string]$il[0].LanguageFeatures
        }
        else { $lp.InstalledLanguagePacks = 'None'; $lp.InstalledLanguageFeatures = 'None' }
    }
    catch { [void]$errs.Add('Get-InstalledLanguage: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    $lp.State = Resolve-CdtLanguagePackState -CbsState $lp.CbsState -InstalledLanguagePacks $lp.InstalledLanguagePacks -MuiRegistered $lp.MuiRegistered -IsBaseLanguage $lp.IsBaseLanguage
    $caps = [ordered]@{}
    foreach ($f in $CdtKnownCapabilities) {
        $name = Get-CdtCapabilityName -Feature $f -Language $lang
        $entry = [ordered]@{ Name = $name; Feature = $f; Required = (@($Cdt.Config.RequiredCapabilities) -contains $f); Optional = (@($Cdt.Config.OptionalCapabilities) -contains $f); State = 'Unknown' }
        try {
            $cap = Get-WindowsCapability -Online -Name $name -ErrorAction Stop -Verbose:$false | Select-Object -First 1
            if ($null -ne $cap) { $entry.State = [string]$cap.State } else { $entry.State = 'NotPresent' }
        }
        catch { [void]$errs.Add(('Get-WindowsCapability {0}: {1}' -f $name, (Get-CdtErrorInfo -InputObject $_).Message)) }
        $caps[$f] = $entry
    }
    return [ordered]@{ TimestampUtc = Get-CdtUtcTimestamp; LanguagePack = $lp; Capabilities = $caps; Pending = (Get-CdtPendingReboot); Errors = @($errs) }
}

function Test-CdtComponentsSatisfied {
    # Installationsschritt erfuellt: Installed oder InstallPending. Abschlusspruefung (-Final): nur Installed.
    param([System.Collections.IDictionary]$State, [switch]$Final)
    $ok = @('Installed')
    if (-not $Final) { $ok += 'InstallPending' }
    $missingReq = New-Object System.Collections.ArrayList
    $missingOpt = New-Object System.Collections.ArrayList
    foreach ($f in $Cdt.Config.RequiredCapabilities) { if ($ok -notcontains [string]$State.Capabilities[$f].State) { [void]$missingReq.Add($f) } }
    foreach ($f in $Cdt.Config.OptionalCapabilities) {
        if (@($Cdt.Config.RequiredCapabilities) -contains $f) { continue }
        if ($ok -notcontains [string]$State.Capabilities[$f].State) { [void]$missingOpt.Add($f) }
    }
    $lpOk = ($ok -contains [string]$State.LanguagePack.State)
    return [pscustomobject]@{
        LanguagePack    = $lpOk
        Required        = ($missingReq.Count -eq 0)
        Optional        = ($missingOpt.Count -eq 0)
        MissingRequired = @($missingReq)
        MissingOptional = @($missingOpt)
        Mandatory       = ($lpOk -and $missingReq.Count -eq 0)
        All             = ($lpOk -and $missingReq.Count -eq 0 -and $missingOpt.Count -eq 0)
    }
}

function Get-CdtComponentSummaryText {
    param([System.Collections.IDictionary]$State)
    $parts = New-Object System.Collections.ArrayList
    [void]$parts.Add(('LP={0}' -f $State.LanguagePack.State))
    foreach ($f in @($Cdt.Config.RequiredCapabilities) + @($Cdt.Config.OptionalCapabilities)) {
        if ($State.Capabilities.Contains($f)) { [void]$parts.Add(('{0}={1}' -f $f, $State.Capabilities[$f].State)) }
    }
    return ($parts -join ' ')
}

# =====================================================================================================
# QUELLEN-RICHTLINIEN (nur lesen - Update-Richtlinien werden nicht veraendert)
# =====================================================================================================
function Get-CdtUpdateSourcePolicy {
    $wu = Get-CdtRegistryValues -Hive LocalMachine -SubKey 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Names @('WUServer', 'DoNotConnectToWindowsUpdateInternetLocations', 'DisableWindowsUpdateAccess')
    $au = Get-CdtRegistryValues -Hive LocalMachine -SubKey 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Names @('UseWUServer')
    $sv = Get-CdtRegistryValues -Hive LocalMachine -SubKey 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing' -Names @('LocalSourcePath', 'UseWindowsUpdate', 'RepairContentServerSource')
    $start = { param($svc) $v = Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey ('SYSTEM\CurrentControlSet\Services\' + $svc) -Name 'Start'; if ($null -eq $v) { $null } else { [int]$v } }
    $p = [ordered]@{
        WuServer                     = (Protect-CdtText -Text ([string]$wu.Values['WUServer']))
        UseWUServer                  = $au.Values['UseWUServer']
        WsusConfigured               = ($au.Values['UseWUServer'] -eq 1 -and -not [string]::IsNullOrEmpty([string]$wu.Values['WUServer']))
        DoNotConnectToWUInternet     = $wu.Values['DoNotConnectToWindowsUpdateInternetLocations']
        DisableWindowsUpdateAccess   = $wu.Values['DisableWindowsUpdateAccess']
        ServicingUseWindowsUpdate    = $sv.Values['UseWindowsUpdate']
        ServicingRepairContentSource = $sv.Values['RepairContentServerSource']
        ServicingLocalSourcePath     = [string]$sv.Values['LocalSourcePath']
        WuauservStart                = (& $start 'wuauserv')
        BitsStart                    = (& $start 'BITS')
        DoSvcStart                   = (& $start 'DoSvc')
        TrustedInstallerStart        = (& $start 'TrustedInstaller')
        Decision                     = 'Allowed'
        Reasons                      = @()
    }
    $reasons = New-Object System.Collections.ArrayList
    if ($p.WuauservStart -eq 4) { $p.Decision = 'Blocked'; [void]$reasons.Add('Dienst wuauserv ist deaktiviert (Script aendert keine Dienste/Richtlinien).') }
    if ($p.TrustedInstallerStart -eq 4) { $p.Decision = 'Blocked'; [void]$reasons.Add('Dienst TrustedInstaller ist deaktiviert.') }
    if ($p.ServicingUseWindowsUpdate -eq 2 -and -not $p.WsusConfigured) { $p.Decision = 'Blocked'; [void]$reasons.Add('Richtlinie "Never attempt to download payload from Windows Update" aktiv, kein WSUS konfiguriert (vgl. 0x800F0907).') }
    if ($p.Decision -ne 'Blocked') {
        if ($p.WsusConfigured -and $p.ServicingRepairContentSource -ne 2) { $p.Decision = 'Uncertain'; [void]$reasons.Add('WSUS konfiguriert: FoD/Sprachpakete kommen ab Windows 11 22H2 aus WSUS, sofern dort synchronisiert (sonst Fehler wie 0x800F0954/0x8024402C).') }
        if ($p.WsusConfigured -and $p.ServicingRepairContentSource -eq 2) { [void]$reasons.Add('RepairContentServerSource=2: FoD/Sprachpakete direkt von Windows Update statt WSUS.') }
        if ($p.DoNotConnectToWUInternet -eq 1) { $p.Decision = 'Uncertain'; [void]$reasons.Add('DoNotConnectToWindowsUpdateInternetLocations=1 kann Windows-Update-Internetquellen sperren.') }
        if ($p.DisableWindowsUpdateAccess -eq 1) { $p.Decision = 'Uncertain'; [void]$reasons.Add('DisableWindowsUpdateAccess=1 gesetzt.') }
        if ($p.ServicingUseWindowsUpdate -eq 2 -and $p.WsusConfigured) { $p.Decision = 'Uncertain'; [void]$reasons.Add('UseWindowsUpdate=2 bei WSUS: nur WSUS als Quelle.') }
    }
    $p.Reasons = @($reasons)
    return $p
}

# =====================================================================================================
# NETZWERKPRUEFUNG (gleicher Kontext wie die Installation; begrenzte Zeit/Datenmenge)
# =====================================================================================================
function Initialize-CdtNetHelper {
    if ($null -ne ('CdtDeLang.NetProbe' -as [type])) { return $true }
    if ($Cdt.NetHelperFailed) { return $false }
    try {
        Add-Type -TypeDefinition $CdtNetHelperSource -Language CSharp -ErrorAction Stop
        return $true
    }
    catch {
        $Cdt.NetHelperFailed = $true
        Write-CdtLog -Level WARN -Phase 'Network' -Action 'Helper' -Message 'C#-Hilfstyp nicht verfuegbar: TLS-Details und WinHTTP-Proxyermittlung eingeschraenkt.' -ErrorMessage (Get-CdtErrorInfo -InputObject $_).Message
        return $false
    }
}

function ConvertFrom-CdtProxyString {
    # WinHTTP-/URL-Proxyangaben: "host:port", "http=host:port;https=host2:port", "http://host:port"
    param([AllowNull()][string]$ProxyString, [string]$Scheme = 'http')
    if ([string]::IsNullOrWhiteSpace($ProxyString)) { return $null }
    $entries = @($ProxyString -split '[; ]' | Where-Object { $_ -ne '' })
    $chosen = $null
    $httpEntry = $null
    foreach ($e in $entries) {
        if ($e -match '^(?<s>[a-zA-Z]+)=(?<v>.+)$') {
            if ($Matches['s'] -ieq $Scheme) { $chosen = $Matches['v'] }
            if ($Matches['s'] -ieq 'http') { $httpEntry = $Matches['v'] }
        }
        elseif ($null -eq $chosen) { $chosen = $e }
    }
    if ($null -eq $chosen) { $chosen = $httpEntry }
    if ($null -eq $chosen) { return $null }
    $v = ($chosen -replace '^[a-zA-Z]+://', '').TrimEnd('/')
    $v = $v -replace '^[^@/]*@', ''
    if ($v -match '^\[(?<h>[^\]]+)\]:(?<p>\d+)$' -or $v -match '^(?<h>[^:/]+):(?<p>\d+)$') {
        return [ordered]@{ Host = $Matches['h']; Port = [int]$Matches['p'] }
    }
    return [ordered]@{ Host = $v; Port = 80 }
}

function Test-CdtProxyBypass {
    param([string]$HostName, [AllowNull()][string]$BypassList)
    if ([string]::IsNullOrWhiteSpace($BypassList)) { return $false }
    foreach ($entry in @($BypassList -split '[; ,]' | Where-Object { $_ -ne '' })) {
        $e = $entry.Trim()
        if ($e -ieq '<local>') { if ($HostName -notmatch '\.') { return $true }; continue }
        $rx = '^' + [regex]::Escape($e).Replace('\*', '.*').Replace('\?', '.') + '$'
        if ($HostName -match $rx) { return $true }
    }
    return $false
}

function Get-CdtWinHttpProxyConfig {
    # Systemweiter WinHTTP-Proxy (netsh winhttp) und WPAD (DHCP/DNS) - von Windows Update genutzt
    if ($null -ne $Cdt.WinHttp) { return $Cdt.WinHttp }
    $r = [ordered]@{ Available = $false; AccessType = $null; Mode = 'Unknown'; Proxy = ''; Bypass = ''; Wpad = [ordered]@{ Tested = $false; Found = $false; Proxy = ''; Error = '' }; Error = '' }
    if (Initialize-CdtNetHelper) {
        try {
            $d = [CdtDeLang.WinHttpProxy]::GetDefault()
            if ($d[0] -eq 'ok') {
                $r.Available = $true
                $r.AccessType = [int]$d[1]
                $r.Proxy = Protect-CdtText -Text $d[2]
                $r.Bypass = $d[3]
                if ($r.AccessType -eq 3 -and -not [string]::IsNullOrEmpty($d[2])) { $r.Mode = 'Named' } else { $r.Mode = 'Direct' }
            }
            else { $r.Error = 'WinHttpGetDefaultProxyConfiguration Win32-Fehler ' + $d[1] }
        }
        catch { $r.Error = (Get-CdtErrorInfo -InputObject $_).Message }
        try {
            $r.Wpad.Tested = $true
            $a = [CdtDeLang.WinHttpProxy]::GetAutoDetect('https://fe3.delivery.mp.microsoft.com/', 5000)
            if ($a[0] -eq 'ok' -and -not [string]::IsNullOrEmpty($a[2])) { $r.Wpad.Found = $true; $r.Wpad.Proxy = Protect-CdtText -Text $a[2] }
            elseif ($a[0] -ne 'ok') {
                if ($a[1] -eq '12180') { $r.Wpad.Error = 'Kein WPAD gefunden (12180)' } else { $r.Wpad.Error = 'WinHttpGetProxyForUrl Win32-Fehler ' + $a[1] }
            }
        }
        catch { $r.Wpad.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    }
    else { $r.Error = 'Hilfstyp nicht verfuegbar' }
    $Cdt.WinHttp = $r
    Write-CdtLog -Phase 'Network' -Action 'WinHttpProxy' -Message ('WinHTTP-Proxy: Modus={0} Proxy={1} WPAD={2}' -f $r.Mode, $r.Proxy, $(if ($r.Wpad.Found) { $r.Wpad.Proxy } else { $r.Wpad.Error })) -Data $r
    return $r
}

function Get-CdtProxyForPath {
    # Ermittelt den tatsaechlich verwendeten Weg je Pfad:
    #   WindowsUpdate: WinHTTP (statisch, sonst WPAD), sonst direkt
    #   Download     : ProxyUrl, sonst WinINet/System des Ausfuehrungskontos, sonst WinHTTP, sonst direkt
    param([ValidateSet('WindowsUpdate', 'Download')][string]$PathName, [Uri]$Uri)
    $direct = [ordered]@{ Mode = 'Direct'; Host = $null; Port = $null; Display = 'direkt'; Source = 'kein Proxy konfiguriert/erkannt' }
    if ($PathName -eq 'Download') {
        if (-not [string]::IsNullOrWhiteSpace($Cdt.Config.ProxyUrl)) {
            $px = ConvertFrom-CdtProxyString -ProxyString $Cdt.Config.ProxyUrl -Scheme $Uri.Scheme
            if ($null -ne $px) { return [ordered]@{ Mode = 'Proxy'; Host = $px.Host; Port = $px.Port; Display = ('{0}:{1}' -f $px.Host, $px.Port); Source = 'Konfiguration ProxyUrl' } }
        }
        try {
            $sys = [System.Net.WebRequest]::GetSystemWebProxy()
            if (-not $sys.IsBypassed($Uri)) {
                $pu = $sys.GetProxy($Uri)
                if ($null -ne $pu -and $pu.Authority -ne $Uri.Authority) {
                    return [ordered]@{ Mode = 'Proxy'; Host = $pu.DnsSafeHost; Port = $pu.Port; Display = ('{0}:{1}' -f $pu.DnsSafeHost, $pu.Port); Source = 'WinINet/System-Proxy des Ausfuehrungskontos' }
                }
            }
        }
        catch { Write-Verbose 'System-Proxy nicht ermittelbar.' }
    }
    $wh = Get-CdtWinHttpProxyConfig
    if ($wh.Mode -eq 'Named' -and -not (Test-CdtProxyBypass -HostName $Uri.DnsSafeHost -BypassList $wh.Bypass)) {
        $px = ConvertFrom-CdtProxyString -ProxyString $wh.Proxy -Scheme $Uri.Scheme
        if ($null -ne $px) { return [ordered]@{ Mode = 'Proxy'; Host = $px.Host; Port = $px.Port; Display = ('{0}:{1}' -f $px.Host, $px.Port); Source = 'WinHTTP (netsh winhttp)' } }
    }
    if ($wh.Wpad.Found) {
        $px = ConvertFrom-CdtProxyString -ProxyString $wh.Wpad.Proxy -Scheme $Uri.Scheme
        if ($null -ne $px) { return [ordered]@{ Mode = 'Proxy'; Host = $px.Host; Port = $px.Port; Display = ('{0}:{1}' -f $px.Host, $px.Port); Source = 'WinHTTP WPAD' } }
    }
    return $direct
}

function Resolve-CdtDnsName {
    param([string]$HostName, [int]$TimeoutMs)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $r = [ordered]@{ Ok = $false; Status = 'Unknown'; Addresses = @(); DurationMs = 0; Error = ''; TimestampUtc = (Get-CdtUtcTimestamp) }
    try {
        $iar = [System.Net.Dns]::BeginGetHostAddresses($HostName, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { $r.Status = 'Timeout'; $r.Error = 'DNS-Zeitlimit' }
        else {
            $addrs = @([System.Net.Dns]::EndGetHostAddresses($iar) | ForEach-Object { $_.IPAddressToString })
            $r.Addresses = $addrs
            $r.Ok = ($addrs.Count -gt 0)
            if ($r.Ok) { $r.Status = 'Resolved' } else { $r.Status = 'NoAddress' }
        }
    }
    catch {
        $se = $_.Exception
        while ($null -ne $se -and -not ($se -is [System.Net.Sockets.SocketException])) { $se = $se.InnerException }
        if ($null -ne $se) { $r.Status = $se.SocketErrorCode.ToString() } else { $r.Status = 'Error' }
        $r.Error = (Get-CdtErrorInfo -InputObject $_).Message
    }
    $r.DurationMs = $sw.ElapsedMilliseconds
    return $r
}

function Connect-CdtTcp {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) {
            $client.Close()
            return [pscustomobject]@{ Ok = $false; Client = $null; Status = 'TimedOut'; RemoteEndPoint = ''; DurationMs = $sw.ElapsedMilliseconds; Error = 'TCP-Verbindungsaufbau Zeitlimit' }
        }
        $client.EndConnect($iar)
        return [pscustomobject]@{ Ok = $true; Client = $client; Status = 'Connected'; RemoteEndPoint = [string]$client.Client.RemoteEndPoint; DurationMs = $sw.ElapsedMilliseconds; Error = '' }
    }
    catch {
        $se = $_.Exception
        while ($null -ne $se -and -not ($se -is [System.Net.Sockets.SocketException])) { $se = $se.InnerException }
        $status = 'Error'
        if ($null -ne $se) { $status = $se.SocketErrorCode.ToString() }
        try { $client.Close() } catch { Write-Verbose 'Socket bereits geschlossen.' }
        return [pscustomobject]@{ Ok = $false; Client = $null; Status = $status; RemoteEndPoint = ''; DurationMs = $sw.ElapsedMilliseconds; Error = (Get-CdtErrorInfo -InputObject $_).Message }
    }
}

function Read-CdtHttpHeaderBlock {
    # Liest bis CRLFCRLF (max. 64 KB) - fuer die CONNECT-Antwort eines Proxys
    param([System.IO.Stream]$Stream, [int]$TimeoutMs)
    $buf = New-Object byte[] 4096
    $ms = New-Object System.IO.MemoryStream
    $latin = [System.Text.Encoding]::GetEncoding(28591)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($ms.Length -lt 65536 -and $sw.ElapsedMilliseconds -lt $TimeoutMs) {
        $n = $Stream.Read($buf, 0, 1)
        if ($n -le 0) { break }
        $ms.Write($buf, 0, $n)
        if ($ms.Length -ge 4) {
            $text = $latin.GetString($ms.GetBuffer(), [int]$ms.Length - 4, 4)
            if ($text -eq "`r`n`r`n") { break }
        }
    }
    return $latin.GetString($ms.ToArray())
}

function Invoke-CdtProxyConnect {
    param([System.IO.Stream]$Stream, [Uri]$Uri, [int]$TimeoutMs)
    $r = [ordered]@{ StatusCode = $null; StatusLine = ''; AuthSchemes = ''; Error = '' }
    try {
        $req = "CONNECT {0}:{1} HTTP/1.1`r`nHost: {0}:{1}`r`nUser-Agent: CDT-DE-LANG-NetCheck/1.0`r`nProxy-Connection: Keep-Alive`r`n`r`n" -f $Uri.DnsSafeHost, $Uri.Port
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($req)
        $Stream.Write($bytes, 0, $bytes.Length)
        $Stream.Flush()
        $head = Read-CdtHttpHeaderBlock -Stream $Stream -TimeoutMs $TimeoutMs
        $lines = $head -split "`r`n"
        $r.StatusLine = $lines[0]
        if ($lines[0] -match '^HTTP/\d\.\d\s+(\d{3})') { $r.StatusCode = [int]$Matches[1] }
        $auth = @($lines | Where-Object { $_ -match '^Proxy-Authenticate:\s*(\S+)' } | ForEach-Object { ($_ -replace '^Proxy-Authenticate:\s*', '').Split(' ')[0] })
        $r.AuthSchemes = ($auth -join ',')
    }
    catch { $r.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    return $r
}

function Invoke-CdtTlsCheck {
    param([System.IO.Stream]$Stream, [string]$HostName, [int]$TimeoutMs)
    $r = [ordered]@{ Success = $false; Protocol = ''; Cipher = ''; Subject = ''; Issuer = ''; NotAfterUtc = ''; PolicyErrors = ''; ChainStatus = ''; Error = ''; ErrorType = ''; Detailed = $false }
    if (Initialize-CdtNetHelper) {
        $t = [CdtDeLang.NetProbe]::Authenticate($Stream, $HostName, $TimeoutMs)
        $r.Success = $t.Success; $r.Protocol = $t.Protocol; $r.Cipher = $t.Cipher; $r.Error = Protect-CdtText -Text $t.Error; $r.ErrorType = $t.ErrorType
        $r.Subject = $t.Certificate.Subject; $r.Issuer = $t.Certificate.Issuer; $r.NotAfterUtc = $t.Certificate.NotAfterUtc
        $r.PolicyErrors = $t.Certificate.PolicyErrors; $r.ChainStatus = $t.Certificate.ChainStatus; $r.Detailed = $true
        return $r
    }
    $ssl = New-Object System.Net.Security.SslStream($Stream, $true)
    try {
        $ssl.AuthenticateAsClient($HostName, $null, [System.Security.Authentication.SslProtocols]::Tls12, $false)
        $r.Success = $true; $r.Protocol = $ssl.SslProtocol.ToString()
        if ($null -ne $ssl.RemoteCertificate) { $r.Subject = $ssl.RemoteCertificate.Subject; $r.Issuer = $ssl.RemoteCertificate.Issuer }
    }
    catch { $r.Error = (Get-CdtErrorInfo -InputObject $_).Message; $r.ErrorType = $_.Exception.GetType().FullName }
    finally { $ssl.Dispose() }
    return $r
}

function Invoke-CdtWebRequestProbe {
    # HTTP-Ebene mit HttpWebRequest: Range-Anfrage, begrenzter Lesevorgang, keine automatische Weiterleitung,
    # Proxy mit Standardanmeldeinformationen des Kontos, unveraenderte Zertifikatspruefung.
    param([Uri]$Uri, [System.Collections.IDictionary]$Proxy, [int]$TimeoutMs, [int]$MaxBytes)
    $r = [ordered]@{ StatusCode = $null; Reason = ''; ContentLength = $null; ContentRange = ''; AcceptRanges = ''; ContentType = ''; Server = ''; Via = ''
        Location = ''; LocationRaw = $null; BytesRead = 0; RangeSupported = $null; Truncated = $false; WebExceptionStatus = ''; Error = ''; TlsPolicyErrors = ''; TlsIssuer = ''; DurationMs = 0 }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = $null
    $req = $null
    try {
        $req = [System.Net.HttpWebRequest][System.Net.WebRequest]::Create($Uri)
        $req.Method = 'GET'
        $req.AllowAutoRedirect = $false
        $req.Timeout = $TimeoutMs
        $req.ReadWriteTimeout = $TimeoutMs
        $req.KeepAlive = $false
        $req.UserAgent = 'CDT-DE-LANG-NetCheck/1.0'
        $req.AddRange([long]0, [long]1023)
        if ($Proxy.Mode -eq 'Proxy') {
            $wp = New-Object System.Net.WebProxy(('http://{0}:{1}' -f $Proxy.Host, $Proxy.Port))
            $wp.UseDefaultCredentials = $true
            $req.Proxy = $wp
        }
        else { $req.Proxy = $null }
        $recorder = $null
        if ($Uri.Scheme -eq 'https' -and (Initialize-CdtNetHelper)) {
            $recorder = New-Object CdtDeLang.CertificateRecorder
            $req.ServerCertificateValidationCallback = $recorder.GetCallback()
        }
        try { $resp = [System.Net.HttpWebResponse]$req.GetResponse() }
        catch [System.Net.WebException] {
            $r.WebExceptionStatus = $_.Exception.Status.ToString()
            if ($null -ne $_.Exception.Response) { $resp = [System.Net.HttpWebResponse]$_.Exception.Response }
            else { $r.Error = (Get-CdtErrorInfo -InputObject $_).Message }
        }
        if ($null -ne $recorder -and $recorder.Invoked) { $r.TlsPolicyErrors = $recorder.PolicyErrors; $r.TlsIssuer = $recorder.Issuer }
        if ($null -ne $resp) {
            $r.StatusCode = [int]$resp.StatusCode
            $r.Reason = [string]$resp.StatusDescription
            $r.ContentLength = [int64]$resp.ContentLength
            $r.ContentRange = [string]$resp.Headers['Content-Range']
            $r.AcceptRanges = [string]$resp.Headers['Accept-Ranges']
            $r.ContentType = [string]$resp.ContentType
            $r.Server = [string]$resp.Headers['Server']
            $r.Via = [string]$resp.Headers['Via']
            $loc = [string]$resp.Headers['Location']
            if (-not [string]::IsNullOrEmpty($loc)) { $r.LocationRaw = $loc; $r.Location = Protect-CdtText -Text $loc }
            $r.RangeSupported = ($r.StatusCode -eq 206 -and $r.ContentRange -match '^bytes')
            $stream = $resp.GetResponseStream()
            $buf = New-Object byte[] 16384
            $total = 0
            while ($total -lt $MaxBytes) {
                $toRead = [Math]::Min($buf.Length, $MaxBytes - $total)
                $n = $stream.Read($buf, 0, $toRead)
                if ($n -le 0) { break }
                $total += $n
            }
            $r.BytesRead = $total
            $r.Truncated = ($total -ge $MaxBytes)
        }
    }
    catch { $r.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    finally {
        # Abbruch beendet den Transfer kontrolliert, auch wenn der Server den Range-Header ignoriert
        if ($null -ne $req) { try { $req.Abort() } catch { Write-Verbose 'Abort nicht noetig.' } }
        if ($null -ne $resp) { try { $resp.Close() } catch { Write-Verbose 'Antwort bereits geschlossen.' } }
    }
    $r.DurationMs = $sw.ElapsedMilliseconds
    return $r
}

function Get-CdtNetworkVerdict {
    # Bewertet ein Pruefergebnis. 403/404/405 an einer Dienstwurzel = Dienst erreichbar (kein Netzwerkfehler).
    param([System.Collections.IDictionary]$Result)
    $v = [ordered]@{ Status = 'Pass'; Category = ''; Code = ''; Detail = ''; Recommendation = '' }
    $target = '{0}:{1}' -f $Result.Host, $Result.Port
    $ctx = [string]$Result.Identity
    $viaProxy = ($Result.ProxyMode -eq 'Proxy')
    if ($viaProxy -and $null -ne $Result.ProxyDns -and -not $Result.ProxyDns.Ok) {
        $v.Status = 'Fail'; $v.Category = 'ProxyDnsFailure'; $v.Code = $Result.ProxyDns.Status
        $v.Detail = 'Proxy-Name {0} nicht aufloesbar' -f $Result.Proxy
        $v.Recommendation = ('Namensaufloesung des Proxys {0} im Kontext {1} pruefen.' -f $Result.Proxy, $ctx)
        return $v
    }
    if (-not $viaProxy -and $null -ne $Result.Dns -and -not $Result.Dns.Ok) {
        $v.Status = 'Fail'; $v.Category = 'DnsFailure'; $v.Code = $Result.Dns.Status
        $v.Detail = 'DNS-Aufloesung von {0} fehlgeschlagen ({1})' -f $Result.Host, $Result.Dns.Status
        $v.Recommendation = ('DNS-Aufloesung von {0} im Kontext {1} pruefen (DNS-Server/Weiterleitung/Private DNS). Kein Beleg fuer eine Firewall-Blockade.' -f $Result.Host, $ctx)
        return $v
    }
    if ($null -ne $Result.Tcp -and -not $Result.Tcp.Ok) {
        $v.Status = 'Fail'; $v.Code = $Result.Tcp.Status
        if ($viaProxy) {
            $v.Category = 'ProxyConnectFailure'
            $v.Detail = 'TCP-Verbindung zum Proxy {0} fehlgeschlagen ({1})' -f $Result.Proxy, $Result.Tcp.Status
            $v.Recommendation = ('Ausgehende Verbindung VM -> Proxy {0} (TCP) freigeben bzw. Proxy-Erreichbarkeit pruefen.' -f $Result.Proxy)
        }
        else {
            $v.Category = 'TcpConnectFailure'
            $v.Detail = 'TCP-Verbindung zu {0} fehlgeschlagen ({1})' -f $target, $Result.Tcp.Status
            if ($Result.Tcp.Status -eq 'ConnectionRefused') { $v.Recommendation = ('Verbindung zu {0} aktiv abgelehnt (RST). Zwischenstation/Ziel pruefen.' -f $target) }
            else { $v.Recommendation = ('Ausgehende Verbindung VM -> {0} wurde nicht hergestellt (Timeout). Moegliche Ursachen: NSG/Firewall/UDR/NVA. Freigabe fuer den DNS-Namen {1} (Port {2}) pruefen.' -f $target, $Result.Host, $Result.Port) }
        }
        return $v
    }
    if ($null -ne $Result.ProxyConnect -and $Result.ProxyConnect.StatusCode -ne 200) {
        $sc = $Result.ProxyConnect.StatusCode
        if ($sc -eq 407) {
            if ($null -ne $Result.Http -and $null -ne $Result.Http.StatusCode -and $Result.Http.StatusCode -ne 407) {
                $v.Detail = 'Proxy verlangt Anmeldung (407); mit Standardanmeldeinformationen des Kontos erreichbar.'
            }
            else {
                $v.Status = 'NotVerifiable'; $v.Category = 'ProxyAuthRequired'; $v.Code = 'HTTP 407'
                $v.Detail = 'Proxy {0} verlangt Authentifizierung ({1}); ohne passende Anmeldung nicht pruefbar.' -f $Result.Proxy, $Result.ProxyConnect.AuthSchemes
                $v.Recommendation = ('Proxy-Zugriff fuer das Computerkonto/SYSTEM ermoeglichen oder Ausnahme fuer {0} einrichten. Windows Update kann abweichend authentifizieren - Nachweis nur ueber den WU-Installationsversuch.' -f $Result.Host)
                return $v
            }
        }
        else {
            $v.Status = 'Fail'; $v.Category = 'ProxyDenied'; $v.Code = ('HTTP {0}' -f $sc)
            if ($null -eq $sc) { $v.Code = 'keine Antwort' }
            $v.Detail = 'Proxy {0} lehnt CONNECT zu {1} ab ({2})' -f $Result.Proxy, $target, $Result.ProxyConnect.StatusLine
            $v.Recommendation = ('Proxy-Regel fuer {0} (Port {1}) pruefen.' -f $Result.Host, $Result.Port)
            return $v
        }
    }
    if ($null -ne $Result.Tls -and -not $Result.Tls.Success) {
        $v.Status = 'Fail'; $v.Code = $Result.Tls.ErrorType
        if ([string]$Result.Tls.PolicyErrors -match 'RemoteCertificateChainErrors') {
            $v.Category = 'TlsCertificateUntrusted'
            $v.Detail = 'Zertifikatskette nicht vertrauenswuerdig (Aussteller: {0}; {1})' -f $Result.Tls.Issuer, $Result.Tls.ChainStatus
            $v.Recommendation = 'Hinweis auf TLS-Inspection oder fehlende Stammzertifikate: Ausnahme von der TLS-Inspection fuer {0} bzw. Vertrauensstellung pruefen. Die Zertifikatspruefung wird nicht deaktiviert.' -f $Result.Host
        }
        elseif ([string]$Result.Tls.PolicyErrors -match 'RemoteCertificateNameMismatch') {
            $v.Category = 'TlsNameMismatch'; $v.Detail = 'Zertifikatsname passt nicht zu {0} (Aussteller: {1})' -f $Result.Host, $Result.Tls.Issuer
            $v.Recommendation = 'Zwischengeschaltete TLS-Komponente/Proxy pruefen.'
        }
        else {
            $v.Category = 'TlsHandshakeFailure'; $v.Detail = 'TLS-Handshake fehlgeschlagen: {0}' -f $Result.Tls.Error
            $v.Recommendation = 'TLS-1.2-Konfiguration, Cipher-Suites, Systemzeit und Zwischenkomponenten pruefen.'
        }
        return $v
    }
    $h = $Result.Http
    if ($null -eq $h) { $v.Status = 'NotVerifiable'; $v.Category = 'HttpNotTested'; $v.Detail = 'HTTP-Ebene nicht geprueft'; return $v }
    if ($null -eq $h.StatusCode) {
        $v.Status = 'Fail'; $v.Code = $h.WebExceptionStatus
        switch ($h.WebExceptionStatus) {
            'NameResolutionFailure' { $v.Category = 'DnsFailure' }
            'ProxyNameResolutionFailure' { $v.Category = 'ProxyDnsFailure' }
            'ConnectFailure' { $v.Category = 'TcpConnectFailure' }
            'Timeout' { $v.Category = 'Timeout' }
            'TrustFailure' { $v.Category = 'TlsCertificateUntrusted' }
            'SecureChannelFailure' { $v.Category = 'TlsHandshakeFailure' }
            default { $v.Category = 'HttpFailure' }
        }
        $v.Detail = 'Keine HTTP-Antwort: {0} {1}' -f $h.WebExceptionStatus, $h.Error
        $v.Recommendation = ('Verbindung zu {0} im Kontext {1} pruefen (Proxy/Firewall/TLS).' -f $target, $ctx)
        return $v
    }
    $sc = [int]$h.StatusCode
    if ($sc -eq 407) {
        $v.Status = 'NotVerifiable'; $v.Category = 'ProxyAuthRequired'; $v.Code = 'HTTP 407'
        $v.Detail = 'Proxy verlangt Authentifizierung; Standardanmeldeinformationen wurden nicht akzeptiert.'
        $v.Recommendation = 'Proxy-Freigabe fuer das Computerkonto/SYSTEM oder Ausnahme fuer den Zielhost einrichten.'
        return $v
    }
    if ($Result.Kind -eq 'ServiceRoot') {
        $v.Detail = 'Dienst erreichbar (HTTP {0} an der Dienstwurzel ist kein Netzwerkfehler)' -f $sc
        if ($sc -ge 500) { $v.Status = 'Warn'; $v.Category = 'ServerError'; $v.Code = ('HTTP {0}' -f $sc) }
        return $v
    }
    $final = $h
    if ($null -ne $Result.FinalHttp) { $final = $Result.FinalHttp }
    $fsc = [int]$final.StatusCode
    if ($fsc -eq 200 -or $fsc -eq 206) {
        $v.Detail = 'Konkrete URL nutzbar (HTTP {0}, Range unterstuetzt: {1}, gelesen {2} Bytes)' -f $fsc, $final.RangeSupported, $final.BytesRead
        if (-not $final.RangeSupported) { $v.Status = 'Warn'; $v.Category = 'RangeNotSupported'; $v.Recommendation = 'Server/Proxy ignoriert Range-Anfragen: Download ohne Fortsetzung; Proxy-Konfiguration fuer Range-Requests pruefen.' }
        return $v
    }
    if (@(301, 302, 303, 307, 308) -contains $fsc) {
        $v.Status = 'Fail'; $v.Category = 'RedirectLimit'; $v.Code = ('HTTP {0}' -f $fsc); $v.Detail = 'Weiterleitungslimit erreicht'
        $v.Recommendation = 'Weiterleitungskette der Download-URL pruefen.'
        return $v
    }
    $v.Status = 'Fail'; $v.Code = ('HTTP {0}' -f $fsc)
    if (@(404, 410) -contains $fsc) { $v.Category = 'UrlNotAvailable'; $v.Detail = 'Konkrete URL nicht (mehr) verfuegbar (kein Netzwerkfehler)'; $v.Recommendation = 'Release-Zuordnung/Download-URL aktualisieren oder lokale Quelle bereitstellen.' }
    elseif ($fsc -eq 403) { $v.Category = 'HttpForbidden'; $v.Detail = ('Zugriff verweigert (Server={0}, Via={1})' -f $final.Server, $final.Via); $v.Recommendation = 'Pruefen, ob Proxy/Gateway oder Zielserver den Abruf verweigert.' }
    elseif ($fsc -ge 500) { $v.Category = 'ServerError'; $v.Detail = 'Serverfehler'; $v.Recommendation = 'Spaeter erneut versuchen.' }
    else { $v.Category = 'HttpUnexpected'; $v.Detail = ('Unerwarteter HTTP-Status {0}' -f $fsc); $v.Recommendation = 'Download-URL und Zwischenkomponenten pruefen.' }
    return $v
}

function Test-CdtNetworkTarget {
    param([System.Collections.IDictionary]$Target, [ValidateSet('WindowsUpdate', 'Download')][string]$PathName)
    $timeoutMs = [int]$Cdt.Config.NetworkTimeoutSeconds * 1000
    $uri = New-Object System.Uri([string]$Target.Url)
    $proxy = Get-CdtProxyForPath -PathName $PathName -Uri $uri
    $r = [ordered]@{
        Id = $Target.Id; Path = $PathName; Kind = $Target.Kind; Host = $uri.DnsSafeHost; Port = $uri.Port; Protocol = $Target.Protocol
        Url = (Protect-CdtText -Text $uri.AbsoluteUri); Required = [bool]$Target.Required; Requirement = $Target.Requirement; Purpose = $Target.Purpose; Reference = $Target.Reference
        ProxyMode = $proxy.Mode; Proxy = $proxy.Display; ProxySource = $proxy.Source; ConnectTarget = ''
        Identity = $Cdt.Context.Identity; TimestampUtc = (Get-CdtUtcTimestamp)
        Dns = $null; ProxyDns = $null; Tcp = $null; ProxyConnect = $null; Tls = $null; Http = $null; FinalHttp = $null; Redirects = @()
        Status = 'Unknown'; Category = ''; Code = ''; Detail = ''; Recommendation = ''; DurationMs = 0
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $useProxy = ($proxy.Mode -eq 'Proxy')
    if ($useProxy) { $r.ConnectTarget = $proxy.Display } else { $r.ConnectTarget = ('{0}:{1}' -f $uri.DnsSafeHost, $uri.Port) }
    $r.Dns = Resolve-CdtDnsName -HostName $uri.DnsSafeHost -TimeoutMs $timeoutMs
    $continue = $true
    if ($useProxy) {
        $r.ProxyDns = Resolve-CdtDnsName -HostName $proxy.Host -TimeoutMs $timeoutMs
        if (-not $r.ProxyDns.Ok) { $continue = $false }
    }
    elseif (-not $r.Dns.Ok) { $continue = $false }
    if ($continue) {
        $connHost = $uri.DnsSafeHost
        $connPort = $uri.Port
        if ($useProxy) { $connHost = $proxy.Host; $connPort = $proxy.Port }
        $tcp = Connect-CdtTcp -HostName $connHost -Port $connPort -TimeoutMs $timeoutMs
        $r.Tcp = [ordered]@{ Ok = $tcp.Ok; Status = $tcp.Status; RemoteEndPoint = $tcp.RemoteEndPoint; DurationMs = $tcp.DurationMs; Error = $tcp.Error }
        if (-not $tcp.Ok) { $continue = $false }
        else {
            try {
                $ns = $tcp.Client.GetStream()
                $ns.ReadTimeout = $timeoutMs
                $ns.WriteTimeout = $timeoutMs
                if ($uri.Scheme -eq 'https') {
                    $tunnel = $true
                    if ($useProxy) {
                        $r.ProxyConnect = Invoke-CdtProxyConnect -Stream $ns -Uri $uri -TimeoutMs $timeoutMs
                        $tunnel = ($r.ProxyConnect.StatusCode -eq 200)
                    }
                    if ($tunnel) {
                        $r.Tls = Invoke-CdtTlsCheck -Stream $ns -HostName $uri.DnsSafeHost -TimeoutMs $timeoutMs
                        if (-not $r.Tls.Success) { $continue = $false }
                    }
                    elseif ($r.ProxyConnect.StatusCode -ne 407) { $continue = $false }
                }
            }
            catch { $r.Detail = (Get-CdtErrorInfo -InputObject $_).Message }
            finally { try { $tcp.Client.Close() } catch { Write-Verbose 'Socket bereits geschlossen.' } }
        }
    }
    if ($continue) {
        $r.Http = Invoke-CdtWebRequestProbe -Uri $uri -Proxy $proxy -TimeoutMs $timeoutMs -MaxBytes ([int]$Cdt.Config.NetworkMaxProbeBytes)
        if ($Target.Kind -eq 'ConcreteUrl') {
            $current = $r.Http
            $currentUri = $uri
            $hops = New-Object System.Collections.ArrayList
            while ($null -ne $current.StatusCode -and @(301, 302, 303, 307, 308) -contains [int]$current.StatusCode -and -not [string]::IsNullOrEmpty($current.LocationRaw) -and $hops.Count -lt [int]$Cdt.Config.NetworkMaxRedirects) {
                $next = New-Object System.Uri($currentUri, $current.LocationRaw)
                $hopProxy = Get-CdtProxyForPath -PathName $PathName -Uri $next
                $current = Invoke-CdtWebRequestProbe -Uri $next -Proxy $hopProxy -TimeoutMs $timeoutMs -MaxBytes ([int]$Cdt.Config.NetworkMaxProbeBytes)
                [void]$hops.Add([ordered]@{ Url = (Protect-CdtText -Text $next.AbsoluteUri); Host = $next.DnsSafeHost; StatusCode = $current.StatusCode; Proxy = $hopProxy.Display })
                $currentUri = $next
            }
            $r.Redirects = @($hops)
            $r.FinalHttp = $current
        }
    }
    $verdict = Get-CdtNetworkVerdict -Result $r
    foreach ($k in @($verdict.Keys)) { $r[$k] = $verdict[$k] }
    $r.DurationMs = $sw.ElapsedMilliseconds
    return $r
}

function Invoke-CdtNetworkCheck {
    param([ValidateSet('WindowsUpdate', 'Download')][string]$PathName, [object[]]$Targets)
    $results = New-Object System.Collections.ArrayList
    foreach ($t in $Targets) {
        $res = Test-CdtNetworkTarget -Target $t -PathName $PathName
        [void]$results.Add($res)
        [void]$Cdt.Network.Results.Add($res)
        $level = 'CHECK'
        if ($res.Status -eq 'Fail' -and $res.Required) { $level = 'WARN' }
        $ips = ''
        if ($null -ne $res.Dns) { $ips = (@($res.Dns.Addresses) -join ',') }
        Write-CdtLog -Level $level -Phase 'Network' -Action ('{0}.{1}' -f $PathName, $res.Id) -Message ('{0} {1}:{2} via {3} -> {4} {5}' -f $res.Protocol, $res.Host, $res.Port, $res.Proxy, $res.Status, $res.Detail) `
            -Result $res.Status -ErrorCode $res.Code -Recommendation $res.Recommendation -DurationMs $res.DurationMs -Source $res.ProxySource `
            -Check ([ordered]@{ name = ('Network.' + $res.Id); expected = 'erreichbar'; actual = $res.Status; category = $res.Category; resolvedIps = $ips; resolvedAtUtc = $res.TimestampUtc }) -Data $res
    }
    $Cdt.Network.Performed = $true
    $req = @($results | Where-Object { $_.Required })
    $reqFail = @($req | Where-Object { $_.Status -eq 'Fail' })
    $transport = @('DnsFailure', 'ProxyDnsFailure', 'TcpConnectFailure', 'ProxyConnectFailure', 'Timeout')
    $allTransport = ($req.Count -gt 0 -and @($req | Where-Object { $transport -contains $_.Category }).Count -eq $req.Count)
    return [pscustomobject]@{ Results = @($results); RequiredFailed = $reqFail.Count; AllRequiredFailedAtTransport = $allTransport }
}

function Get-CdtDnsServerList {
    try { return (@(Get-DnsClientServerAddress -ErrorAction Stop | ForEach-Object { $_.ServerAddresses } | Where-Object { $_ }) | Sort-Object -Unique) -join ', ' }
    catch { return 'konfigurierte DNS-Server (nicht ermittelbar)' }
}

# =====================================================================================================
# FALLBACK-QUELLEN (lokales Repository / ISO / Download) - Pruefung von Inhalt, Architektur, Signatur
# =====================================================================================================
function Get-CdtArchitectureTokens {
    if ($Cdt.Platform.Architecture -eq 'ARM64') { return [pscustomobject]@{ Lp = 'arm64'; Pkg = 'arm64' } }
    return [pscustomobject]@{ Lp = 'x64'; Pkg = 'amd64' }
}

function Test-CdtRepository {
    # Prueft einen Ordner (oder ISO-Wurzel) als Sprach-/FoD-Repository fuer die benoetigten Komponenten
    param([string]$Path, [bool]$NeedLanguagePack, [string[]]$Capabilities, [switch]$SkipApplicability)
    $lang = $Cdt.Config.Language.ToLowerInvariant()
    $arch = Get-CdtArchitectureTokens
    $r = [ordered]@{ Valid = $false; Path = $Path; Root = $null; LanguagePackCab = $null; CapabilityCabs = [ordered]@{}; MetadataPresent = $false
        Missing = @(); Signature = $null; Applicable = $null; Issues = @() }
    $issues = New-Object System.Collections.ArrayList
    $missing = New-Object System.Collections.ArrayList
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) { [void]$issues.Add('Pfad nicht vorhanden oder nicht zugreifbar'); $r.Issues = @($issues); return $r }
        $root = $Path
        $sub = Join-Path $Path 'LanguagesAndOptionalFeatures'
        if (Test-Path -LiteralPath $sub -PathType Container) { $root = $sub }
        $r.Root = $root
        if ($NeedLanguagePack) {
            $lpName = 'Microsoft-Windows-Client-Language-Pack_{0}_{1}.cab' -f $arch.Lp, $lang
            $lp = Get-ChildItem -LiteralPath $root -Filter $lpName -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -eq $lp) { [void]$missing.Add($lpName) } else { $r.LanguagePackCab = $lp.FullName }
        }
        foreach ($cap in @($Capabilities)) {
            $fname = 'Microsoft-Windows-LanguageFeatures-{0}-{1}-Package~31bf3856ad364e35~{2}~~.cab' -f $cap, $lang, $arch.Pkg
            $f = Get-ChildItem -LiteralPath $root -Filter $fname -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -eq $f) { [void]$missing.Add($fname) } else { $r.CapabilityCabs[$cap] = $f.FullName }
        }
        $r.MetadataPresent = (Test-Path -LiteralPath (Join-Path $root 'metadata') -PathType Container)
        if (@($Capabilities).Count -gt 0 -and -not $r.MetadataPresent) { [void]$issues.Add('Ordner "metadata" fehlt (fuer Add-WindowsCapability -Source erforderlich)') }
        $sigFile = $r.LanguagePackCab
        if ($null -eq $sigFile -and $r.CapabilityCabs.Count -gt 0) { $sigFile = @($r.CapabilityCabs.Values)[0] }
        if ($null -ne $sigFile) {
            try {
                $sig = Get-AuthenticodeSignature -FilePath $sigFile -ErrorAction Stop
                $subject = ''
                if ($null -ne $sig.SignerCertificate) { $subject = $sig.SignerCertificate.Subject }
                $r.Signature = [ordered]@{ File = (Split-Path -Leaf $sigFile); Status = [string]$sig.Status; Signer = $subject }
                if ([string]$sig.Status -ne 'Valid' -or $subject -notmatch 'O=Microsoft Corporation') { [void]$issues.Add(('Signatur ungueltig oder nicht Microsoft ({0}, {1})' -f $sig.Status, $subject)) }
            }
            catch { [void]$issues.Add('Signaturpruefung nicht moeglich: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
        }
        if ($NeedLanguagePack -and $null -ne $r.LanguagePackCab -and -not $SkipApplicability) {
            try {
                $info = Get-WindowsPackage -Online -PackagePath $r.LanguagePackCab -ErrorAction Stop -Verbose:$false
                $r.Applicable = [bool]$info.Applicable
                if (-not $r.Applicable) { [void]$issues.Add('Sprachpaket laut DISM fuer dieses System nicht anwendbar (Applicable=False)') }
            }
            catch { [void]$issues.Add('Anwendbarkeit nicht ermittelbar: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
        }
    }
    catch { [void]$issues.Add((Get-CdtErrorInfo -InputObject $_).Message) }
    $r.Missing = @($missing)
    $r.Issues = @($issues)
    $blocking = @($issues | Where-Object { $_ -notmatch '^Anwendbarkeit nicht ermittelbar' })
    $r.Valid = ($missing.Count -eq 0 -and $blocking.Count -eq 0)
    return $r
}

function Find-CdtFallbackSource {
    # Reihenfolge: konfiguriertes Repository, Richtlinie LocalSourcePath, konfigurierte ISO, lokaler Cache,
    # bereits eingebundene LOF-Datentraeger. Download erst, wenn nichts Geeignetes vorhanden ist.
    param([System.Collections.IDictionary]$SourceInfo)
    $list = New-Object System.Collections.ArrayList
    foreach ($p in @($Cdt.Config.RepositoryPath)) { [void]$list.Add([ordered]@{ Kind = 'Repository'; Path = $p; Origin = 'Konfiguration RepositoryPath'; Owned = $false }) }
    $policy = $Cdt.UpdatePolicy
    if ($null -ne $policy -and -not [string]::IsNullOrWhiteSpace($policy.ServicingLocalSourcePath)) {
        foreach ($p in ([Environment]::ExpandEnvironmentVariables($policy.ServicingLocalSourcePath)).Split(';')) {
            if (-not [string]::IsNullOrWhiteSpace($p)) { [void]$list.Add([ordered]@{ Kind = 'Repository'; Path = $p.Trim(); Origin = 'Richtlinie LocalSourcePath'; Owned = $false }) }
        }
    }
    foreach ($p in @($Cdt.Config.IsoPath)) { [void]$list.Add([ordered]@{ Kind = 'Iso'; Path = $p; Origin = 'Konfiguration IsoPath'; Owned = $false }) }
    if ($null -ne $SourceInfo) {
        foreach ($dir in @((Join-Path $Cdt.Config.LogRoot 'source'), $Cdt.Log.WorkDir)) {
            $cand = Join-Path $dir $SourceInfo.FileName
            if (Test-Path -LiteralPath $cand -PathType Leaf) {
                $owned = (Test-Path -LiteralPath ($cand + '.cdt-download.json'))
                [void]$list.Add([ordered]@{ Kind = 'Iso'; Path = $cand; Origin = $(if ($owned) { 'Eigener Download (Cache)' } else { 'Lokale Quelle' }); Owned = $owned })
            }
        }
    }
    try {
        foreach ($v in @(Get-Volume -ErrorAction Stop | Where-Object { [string]$_.DriveType -eq 'CD-ROM' -and [string]$_.DriveLetter -match '^[A-Za-z]$' })) {
            $root = '{0}:\' -f $v.DriveLetter
            if (Test-Path -LiteralPath (Join-Path $root 'LanguagesAndOptionalFeatures') -PathType Container) {
                [void]$list.Add([ordered]@{ Kind = 'Repository'; Path = $root; Origin = 'Bereits eingebundener Datentraeger (wird nicht ausgehaengt)'; Owned = $false })
            }
        }
    }
    catch { Write-Verbose 'Volumes nicht ermittelbar.' }
    return , ($list.ToArray())
}

function Mount-CdtIso {
    # Bindet eine ISO schreibgeschuetzt ein; Laufwerksbuchstabe wird ermittelt, nie fest verdrahtet.
    param([string]$ImagePath)
    $r = [ordered]@{ Ok = $false; ImagePath = $ImagePath; Root = $null; DriveLetter = $null; FolderMount = $null; MountedByUs = $false; Error = $null }
    try {
        $img = Get-DiskImage -ImagePath $ImagePath -ErrorAction SilentlyContinue
        if ($null -ne $img -and $img.Attached) {
            $vol = Get-Volume -DiskImage $img -ErrorAction Stop | Select-Object -First 1
            if ([string]$vol.DriveLetter -match '^[A-Za-z]$') { $r.Root = '{0}:\' -f $vol.DriveLetter; $r.DriveLetter = [string]$vol.DriveLetter; $r.Ok = $true }
            else { $r.Error = 'ISO bereits eingebunden, aber ohne Laufwerksbuchstaben (fremde Einbindung wird nicht veraendert)' }
            return $r
        }
        $entry = [ordered]@{ imagePath = $ImagePath; folderMount = $null; runId = $Cdt.RunId; timeUtc = (Get-CdtUtcTimestamp) }
        $Cdt.State.temporary.isoMounts = @($Cdt.State.temporary.isoMounts) + @($entry)
        Save-CdtState
        $img = Mount-DiskImage -ImagePath $ImagePath -StorageType ISO -Access ReadOnly -PassThru -ErrorAction Stop
        $r.MountedByUs = $true
        $vol = $null
        for ($i = 0; $i -lt 15; $i++) {
            $vol = Get-Volume -DiskImage $img -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($null -ne $vol -and [string]$vol.DriveLetter -match '^[A-Za-z]$') { break }
            Start-Sleep -Seconds 1
        }
        if ($null -ne $vol -and [string]$vol.DriveLetter -match '^[A-Za-z]$') {
            $r.DriveLetter = [string]$vol.DriveLetter
            $r.Root = '{0}:\' -f $vol.DriveLetter
        }
        elseif ($null -ne $vol -and -not [string]::IsNullOrEmpty([string]$vol.Path)) {
            if (-not (Test-Path -LiteralPath $Cdt.Log.WorkDir)) { [void](New-Item -ItemType Directory -Path $Cdt.Log.WorkDir -Force) }
            $folder = Join-Path $Cdt.Log.WorkDir ('mnt-' + $Cdt.RunId)
            [void](New-Item -ItemType Directory -Path $folder -Force)
            $nc = Invoke-CdtNativeCommand -FilePath (Join-Path $env:SystemRoot 'System32\mountvol.exe') -Arguments ('"{0}\" {1}' -f $folder, $vol.Path) -TimeoutSeconds 60
            if ($nc.ExitCode -ne 0) { throw ('mountvol fehlgeschlagen: {0} {1}' -f $nc.StdOut, $nc.StdErr) }
            $entry.folderMount = $folder
            Save-CdtState
            $r.FolderMount = $folder
            $r.Root = $folder
        }
        else { throw 'Kein Volume fuer die eingebundene ISO gefunden' }
        $r.Ok = $true
    }
    catch { $r.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    Write-CdtLog -Level $(if ($r.Ok) { 'INFO' } else { 'WARN' }) -Phase 'Source' -Action 'MountIso' -Message ('ISO {0}: {1}' -f (Split-Path -Leaf $ImagePath), $(if ($r.Ok) { 'eingebunden unter ' + $r.Root } else { 'nicht eingebunden' })) -ErrorMessage ([string]$r.Error) -Data $r
    return $r
}

function Dismount-CdtIso {
    # Entfernt nur Einbindungen, die dieses Script selbst angelegt hat (Zustandsdatei)
    param([string]$ImagePath, [AllowNull()][string]$FolderMount)
    $ok = $true
    if (-not [string]::IsNullOrEmpty($FolderMount) -and (Test-Path -LiteralPath $FolderMount)) {
        $nc = Invoke-CdtNativeCommand -FilePath (Join-Path $env:SystemRoot 'System32\mountvol.exe') -Arguments ('"{0}\" /D' -f $FolderMount) -TimeoutSeconds 60
        if ($nc.ExitCode -ne 0) { $ok = $false }
        try { Remove-Item -LiteralPath $FolderMount -Force -Recurse -ErrorAction Stop } catch { $ok = $false }
    }
    try {
        $img = Get-DiskImage -ImagePath $ImagePath -ErrorAction SilentlyContinue
        if ($null -ne $img -and $img.Attached) { [void](Dismount-DiskImage -ImagePath $ImagePath -ErrorAction Stop) }
    }
    catch { $ok = $false }
    if ($ok) {
        $Cdt.State.temporary.isoMounts = @(@($Cdt.State.temporary.isoMounts) | Where-Object { [string]$_.imagePath -ne $ImagePath })
        Save-CdtState
    }
    Write-CdtLog -Level $(if ($ok) { 'INFO' } else { 'WARN' }) -Phase 'Cleanup' -Action 'DismountIso' -Message ('ISO {0} ausgehaengt: {1}' -f (Split-Path -Leaf $ImagePath), $ok)
    return $ok
}

function Save-CdtIsoDownload {
    # Bedarfsgesteuerter ISO-Download mit Pruefung (Netzwerk, Platz, Groesse, SHA256), Fortsetzung via Range
    param([System.Collections.IDictionary]$SourceInfo)
    $r = [ordered]@{ Ok = $false; Path = $null; Owned = $true; TotalBytes = $null; Bytes = 0; Resumed = $false; Attempts = 0; Sha256 = $null; Sha256Verified = $null; Error = $null; Category = $null; DurationMs = 0 }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not (Test-Path -LiteralPath $Cdt.Log.WorkDir)) { [void](New-Item -ItemType Directory -Path $Cdt.Log.WorkDir -Force) }
    $dest = Join-Path $Cdt.Log.WorkDir $SourceInfo.FileName
    $partial = $dest + '.partial'
    $marker = $dest + '.cdt-download.json'
    $r.Path = $dest
    $target = [ordered]@{ Id = 'ISO'; Url = $SourceInfo.Url; Protocol = 'HTTPS'; Kind = 'ConcreteUrl'; Required = $true; Requirement = ([Uri]$SourceInfo.Url).DnsSafeHost; Purpose = 'Fallback-Quelle LOF-ISO'; Reference = 'Release-Zuordnung ' + $SourceInfo.Id }
    $net = Invoke-CdtNetworkCheck -PathName 'Download' -Targets @($target)
    $probe = $net.Results[0]
    if (@('Pass', 'Warn') -notcontains $probe.Status) { $r.Error = 'Netzwerkpruefung der Download-URL fehlgeschlagen: ' + $probe.Detail; $r.Category = $probe.Category; return $r }
    $final = $probe.FinalHttp
    if ($null -eq $final) { $final = $probe.Http }
    $total = $null
    if ([string]$final.ContentRange -match '/(\d+)\s*$') { $total = [int64]$Matches[1] }
    elseif ([int]$final.StatusCode -eq 200 -and [int64]$final.ContentLength -gt 0) { $total = [int64]$final.ContentLength }
    $r.TotalBytes = $total
    $rangeOk = [bool]$final.RangeSupported
    $existing = 0
    if (Test-Path -LiteralPath $partial) { $existing = (Get-Item -LiteralPath $partial).Length }
    $free = Get-CdtFreeSpaceBytes -Path $Cdt.Log.WorkDir
    $needed = 2GB
    if ($null -ne $total) { $needed = $total - $existing + 2GB }
    if ($null -ne $free -and $free -lt $needed) { $r.Error = ('Zu wenig Speicherplatz: frei {0:N1} GB, benoetigt {1:N1} GB' -f ($free / 1GB), ($needed / 1GB)); $r.Category = 'DiskFull'; return $r }
    $proxy = Get-CdtProxyForPath -PathName 'Download' -Uri ([Uri]$SourceInfo.Url)
    for ($attempt = 1; $attempt -le [int]$Cdt.Config.DownloadMaxAttempts; $attempt++) {
        $r.Attempts = $attempt
        if ((Get-CdtRemainingSeconds) -lt 1200) { $r.Error = 'Zeitbudget fuer Download nicht ausreichend (Teil-Download bleibt fuer den naechsten Lauf erhalten)'; $r.Category = 'TimeBudget'; break }
        $r.Error = $null
        $r.Category = $null
        $streamCompleted = $false
        $existing = 0
        if (Test-Path -LiteralPath $partial) { $existing = (Get-Item -LiteralPath $partial).Length }
        $req = $null; $resp = $null; $fs = $null
        try {
            $req = [System.Net.HttpWebRequest][System.Net.WebRequest]::Create([Uri]$SourceInfo.Url)
            $req.Method = 'GET'; $req.AllowAutoRedirect = $true; $req.MaximumAutomaticRedirections = [Math]::Max(1, [int]$Cdt.Config.NetworkMaxRedirects)
            $req.Timeout = 60000; $req.ReadWriteTimeout = 120000; $req.UserAgent = 'CDT-DE-LANG-Download/1.0'
            if ($proxy.Mode -eq 'Proxy') { $wp = New-Object System.Net.WebProxy(('http://{0}:{1}' -f $proxy.Host, $proxy.Port)); $wp.UseDefaultCredentials = $true; $req.Proxy = $wp } else { $req.Proxy = $null }
            if ($existing -gt 0 -and $rangeOk) { $req.AddRange([long]$existing) }
            $resp = [System.Net.HttpWebResponse]$req.GetResponse()
            $status = [int]$resp.StatusCode
            $mode = [System.IO.FileMode]::Create
            if ($status -eq 206 -and $existing -gt 0) { $mode = [System.IO.FileMode]::Append; $r.Resumed = $true } else { $existing = 0 }
            if ($null -eq $total -and $status -eq 200 -and $resp.ContentLength -gt 0) { $total = [int64]$resp.ContentLength; $r.TotalBytes = $total }
            $fs = New-Object System.IO.FileStream($partial, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
            $stream = $resp.GetResponseStream()
            $buf = New-Object byte[] 1048576
            $written = $existing
            $nextLog = 0.1
            $lastBudgetCheck = [DateTime]::UtcNow
            while ($true) {
                $n = $stream.Read($buf, 0, $buf.Length)
                if ($n -le 0) { break }
                $fs.Write($buf, 0, $n)
                $written += $n
                if ($null -ne $total -and $total -gt 0 -and ($written / $total) -ge $nextLog) {
                    Write-CdtLog -Phase 'Source' -Action 'Download' -Message ('ISO-Download {0:P0} ({1:N0} MB)' -f ($written / $total), ($written / 1MB)) -Attempt $attempt
                    if ($nextLog -eq 0.5) { Write-CdtConsole -Message ('ISO-Download 50% ({0:N0} MB)' -f ($written / 1MB)) }
                    $nextLog = [Math]::Round($nextLog + 0.1, 1)
                }
                if (([DateTime]::UtcNow - $lastBudgetCheck).TotalSeconds -ge 15) {
                    $lastBudgetCheck = [DateTime]::UtcNow
                    if ((Get-CdtRemainingSeconds) -lt 900) { throw 'Zeitbudget erschoepft - Download unterbrochen (Fortsetzung im naechsten Lauf)' }
                }
            }
            $streamCompleted = $true
            $r.Bytes = $written
        }
        catch {
            $e = Get-CdtErrorInfo -InputObject $_
            $r.Error = $e.Message
            $r.Category = 'DownloadError'
            Write-CdtLog -Level WARN -Phase 'Source' -Action 'Download' -Message ('Download-Versuch {0} unterbrochen' -f $attempt) -ErrorCode $e.Code -ErrorMessage $e.Message -Attempt $attempt
            if ($e.Message -match 'Zeitbudget') { $r.Category = 'TimeBudget'; break }
            if ($_.Exception -is [System.Net.WebException] -and $null -ne $_.Exception.Response) {
                $sc = [int]([System.Net.HttpWebResponse]$_.Exception.Response).StatusCode
                if (@(403, 404, 407, 410) -contains $sc) { $r.Category = ('HTTP{0}' -f $sc); break }
            }
            Start-Sleep -Seconds ([Math]::Min(30, 5 * $attempt))
        }
        finally {
            if ($null -ne $fs) { $fs.Dispose() }
            if ($null -ne $resp) { $resp.Close() }
        }
        if (Test-Path -LiteralPath $partial) {
            $len = (Get-Item -LiteralPath $partial).Length
            if ($null -ne $total -and $len -eq $total) { $r.Error = $null; $r.Category = $null; break }
            if ($null -ne $total -and $len -gt $total) { Remove-Item -LiteralPath $partial -Force; $r.Error = 'Teil-Download groesser als erwartet - verworfen'; $r.Category = 'SizeMismatch'; continue }
            if ($streamCompleted -and $null -eq $total) { $r.Error = $null; $r.Category = $null; break }
            if ($streamCompleted -and $null -ne $total -and $len -lt $total) { $r.Error = ('Verbindung vorzeitig beendet ({0} von {1} Bytes)' -f $len, $total); $r.Category = 'Truncated' }
        }
    }
    if ($null -eq $r.Error -and (Test-Path -LiteralPath $partial)) {
        $len = (Get-Item -LiteralPath $partial).Length
        if ($null -ne $total -and $len -ne $total) { $r.Error = ('Groessenpruefung fehlgeschlagen ({0} statt {1} Bytes)' -f $len, $total) }
        else {
            Move-Item -LiteralPath $partial -Destination $dest -Force
            $hash = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
            $r.Sha256 = $hash
            if (-not [string]::IsNullOrEmpty($SourceInfo.Sha256)) {
                $r.Sha256Verified = ($hash -ieq $SourceInfo.Sha256)
                if (-not $r.Sha256Verified) { Remove-Item -LiteralPath $dest -Force; $r.Error = 'SHA256 stimmt nicht mit der Referenz ueberein - Datei verworfen' }
            }
            if ($null -eq $r.Error) {
                Set-CdtFileContentAtomic -Path $marker -Text (ConvertTo-CdtJson -InputObject ([ordered]@{ sourceId = $SourceInfo.Id; url = $SourceInfo.Url; bytes = $len; sha256 = $hash; sha256Reference = $SourceInfo.Sha256; runId = $Cdt.RunId; timeUtc = (Get-CdtUtcTimestamp) }))
                $r.Ok = $true
            }
        }
    }
    $r.DurationMs = $sw.ElapsedMilliseconds
    $integrity = 'SHA256 protokolliert, keine Referenzpruefsumme verfuegbar (keine unabhaengige Integritaetsbestaetigung)'
    if ($r.Sha256Verified -eq $true) { $integrity = 'SHA256 stimmt mit Referenz ueberein' }
    Write-CdtLog -Level $(if ($r.Ok) { 'INFO' } else { 'WARN' }) -Phase 'Source' -Action 'Download' -Message ('ISO-Download {0}: {1}' -f $(if ($r.Ok) { 'abgeschlossen' } else { 'nicht abgeschlossen' }), $(if ($r.Ok) { $integrity } else { $r.Error })) -Source $SourceInfo.Id -DurationMs $r.DurationMs -Data $r -Console
    return $r
}

# =====================================================================================================
# SERVICING-AUFRUFE MIT ZEITLIMIT, WARTUNGSAUFGABEN
# =====================================================================================================
function Invoke-CdtServicingJob {
    # Fuehrt Install-Language / Add-WindowsCapability / Add-WindowsPackage in einem Hintergrundjob mit Zeitlimit aus.
    param([ValidateSet('InstallLanguage', 'AddCapabilityOnline', 'AddCapabilitySource', 'AddPackage')][string]$Operation,
        [string]$Language, [string]$CapabilityName, [string]$SourcePath, [string]$PackagePath, [int]$TimeoutSeconds, [string]$SourceLabel, [int]$Attempt = 1)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $start = Get-Date
    $res = [ordered]@{ Operation = $Operation; Source = $SourceLabel; Attempt = $Attempt; Ok = $false; TimedOut = $false; RestartNeeded = $false; HResult = $null; Code = $null; Message = $null; Classification = $null; DurationMs = 0; StartLocal = $start }
    $sb = {
        param($Op, $Lang, $Cap, $Src, $Pkg)
        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'SilentlyContinue'
        $o = [ordered]@{ Ok = $false; RestartNeeded = $false; HResult = $null; Message = $null; Type = $null }
        try {
            switch ($Op) {
                'InstallLanguage' { Import-Module LanguagePackManagement -ErrorAction Stop; [void](Install-Language -Language $Lang -ExcludeFeatures -ErrorAction Stop) }
                'AddCapabilityOnline' { $x = Add-WindowsCapability -Online -Name $Cap -ErrorAction Stop; $o.RestartNeeded = [bool]$x.RestartNeeded }
                'AddCapabilitySource' { $x = Add-WindowsCapability -Online -Name $Cap -Source $Src -LimitAccess -ErrorAction Stop; $o.RestartNeeded = [bool]$x.RestartNeeded }
                'AddPackage' { $x = Add-WindowsPackage -Online -PackagePath $Pkg -NoRestart -ErrorAction Stop; $o.RestartNeeded = [bool]$x.RestartNeeded }
            }
            $o.Ok = $true
        }
        catch {
            $ex = $_.Exception
            $o.HResult = $ex.HResult
            if ($ex -is [System.Runtime.InteropServices.COMException]) { $o.HResult = $ex.ErrorCode }
            $o.Message = $ex.Message
            $o.Type = $ex.GetType().FullName
        }
        [pscustomobject]$o
    }
    $job = Start-Job -ScriptBlock $sb -ArgumentList $Operation, $Language, $CapabilityName, $SourcePath, $PackagePath
    try {
        $done = Wait-Job -Job $job -Timeout ([Math]::Max(60, $TimeoutSeconds))
        if ($null -eq $done) {
            $res.TimedOut = $true
            $res.Code = 'TIMEOUT'
            $res.Message = ('Zeitlimit {0} s ueberschritten' -f $TimeoutSeconds)
            Stop-Job -Job $job -ErrorAction SilentlyContinue
        }
        else {
            $out = @(Receive-Job -Job $job -ErrorAction SilentlyContinue | Where-Object { $null -ne $_ -and $_.PSObject.Properties['Ok'] })
            if ($out.Count -gt 0) {
                $o = $out[-1]
                $res.Ok = [bool]$o.Ok
                $res.RestartNeeded = [bool]$o.RestartNeeded
                $res.HResult = $o.HResult
                $res.Code = Format-CdtHResult -HResult $o.HResult
                $res.Message = Protect-CdtText -Text ([string]$o.Message)
            }
            else { $res.Message = ('Job ohne Ergebnis beendet (Status {0})' -f $job.State) }
        }
    }
    finally { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
    $res.DurationMs = $sw.ElapsedMilliseconds
    if (-not $res.Ok) {
        $res.Classification = Get-CdtErrorClassification -Code $res.Code
        if ($res.TimedOut) { [void](Wait-CdtServicingIdle -MaxSeconds ([int]$Cdt.Config.ServicingIdleWaitMinutes * 60)) }
    }
    return [pscustomobject]$res
}

function Wait-CdtServicingIdle {
    # Ein abgebrochener Job beendet laufende CBS-Operationen nicht zwingend -> begrenzt auf Ende warten
    param([int]$MaxSeconds)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $waited = $false
    while ($sw.Elapsed.TotalSeconds -lt $MaxSeconds) {
        if (@(Get-Process -Name 'TiWorker' -ErrorAction SilentlyContinue).Count -eq 0) { break }
        $waited = $true
        Start-Sleep -Seconds 15
    }
    $idle = (@(Get-Process -Name 'TiWorker' -ErrorAction SilentlyContinue).Count -eq 0)
    Write-CdtLog -Level $(if ($idle) { 'INFO' } else { 'WARN' }) -Phase 'Install' -Action 'WaitServicingIdle' -Message ('Servicing (TiWorker) {0} nach {1:N0} s' -f $(if ($idle) { 'im Leerlauf' } else { 'weiterhin aktiv' }), $sw.Elapsed.TotalSeconds) -Data ([ordered]@{ waited = $waited; idle = $idle })
    return $idle
}

function Suspend-CdtLanguageComponentTask {
    # MS-Workaround (AVD-Imagescripte): Tasks waehrend der Installation pausieren, danach wiederherstellen.
    if (-not $Cdt.Config.PauseLanguageComponentsTasks) { return }
    if ($null -eq (Get-Command -Name 'Get-ScheduledTask' -ErrorAction SilentlyContinue)) { return }
    foreach ($name in @('Installation', 'ReconcileLanguageResources')) {
        $taskPath = '\Microsoft\Windows\LanguageComponentsInstaller\'
        try {
            $t = Get-ScheduledTask -TaskPath $taskPath -TaskName $name -ErrorAction SilentlyContinue
            if ($null -eq $t) { Write-CdtLog -Phase 'Install' -Action 'PauseTask' -Message ('Task {0}{1} nicht vorhanden' -f $taskPath, $name); continue }
            if ([string]$t.State -eq 'Disabled') { Write-CdtLog -Phase 'Install' -Action 'PauseTask' -Message ('Task {0}{1} bereits deaktiviert (nicht durch dieses Script) - unveraendert' -f $taskPath, $name); continue }
            $entry = [ordered]@{ taskPath = $taskPath; taskName = $name; runId = $Cdt.RunId; timeUtc = (Get-CdtUtcTimestamp) }
            $Cdt.State.temporary.tasksDisabled = @($Cdt.State.temporary.tasksDisabled) + @($entry)
            Save-CdtState
            if ([string]$t.State -eq 'Running') { Stop-ScheduledTask -TaskPath $taskPath -TaskName $name -ErrorAction SilentlyContinue }
            [void](Disable-ScheduledTask -TaskPath $taskPath -TaskName $name -ErrorAction Stop)
            Write-CdtLog -Phase 'Install' -Action 'PauseTask' -Message ('Task {0}{1} fuer die Installation pausiert' -f $taskPath, $name)
        }
        catch { Write-CdtLog -Level WARN -Phase 'Install' -Action 'PauseTask' -Message ('Task {0}{1} nicht pausierbar' -f $taskPath, $name) -ErrorMessage (Get-CdtErrorInfo -InputObject $_).Message }
    }
}

function Resume-CdtLanguageComponentTask {
    # Reaktiviert ausschliesslich Tasks, die laut Zustandsdatei durch dieses Script deaktiviert wurden
    $remaining = New-Object System.Collections.ArrayList
    foreach ($e in @($Cdt.State.temporary.tasksDisabled)) {
        if ($null -eq $e) { continue }
        try {
            [void](Enable-ScheduledTask -TaskPath $e.taskPath -TaskName $e.taskName -ErrorAction Stop)
            Write-CdtLog -Phase 'Cleanup' -Action 'ResumeTask' -Message ('Task {0}{1} reaktiviert (pausiert durch RunId {2})' -f $e.taskPath, $e.taskName, $e.runId)
        }
        catch {
            [void]$remaining.Add($e)
            Write-CdtLog -Level WARN -Phase 'Cleanup' -Action 'ResumeTask' -Message ('Task {0}{1} konnte nicht reaktiviert werden' -f $e.taskPath, $e.taskName) -ErrorMessage (Get-CdtErrorInfo -InputObject $_).Message
        }
    }
    $Cdt.State.temporary.tasksDisabled = @($remaining)
    Save-CdtState
}

function Get-CdtServicingLogExcerpt {
    # Ordnet DISM-/CBS-Diagnosen dem Zeitfenster eines fehlgeschlagenen Vorgangs zu (begrenzt)
    param([datetime]$From, [datetime]$To, [int]$MaxLines = 30)
    $out = [ordered]@{}
    foreach ($f in @((Join-Path $env:SystemRoot 'Logs\CBS\CBS.log'), (Join-Path $env:SystemRoot 'Logs\DISM\dism.log'))) {
        $lines = New-Object System.Collections.ArrayList
        try {
            if (-not (Test-Path -LiteralPath $f)) { continue }
            $fs = New-Object System.IO.FileStream($f, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
            try {
                $len = $fs.Length
                $startPos = [Math]::Max([int64]0, $len - 4MB)
                [void]$fs.Seek($startPos, [System.IO.SeekOrigin]::Begin)
                $sr = New-Object System.IO.StreamReader($fs)
                while (-not $sr.EndOfStream) {
                    $l = $sr.ReadLine()
                    if ($l -match '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}),\s+(Error|Warning|Info)\s' -and ($l -match 'Error|Failed|failed|0x8[0-9A-Fa-f]{7}')) {
                        $ts = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
                        if ($ts -ge $From.AddSeconds(-5) -and $ts -le $To.AddSeconds(5)) {
                            [void]$lines.Add((Protect-CdtText -Text $l))
                            if ($lines.Count -gt $MaxLines) { $lines.RemoveAt(0) }
                        }
                    }
                }
            }
            finally { $fs.Dispose() }
        }
        catch { [void]$lines.Add('nicht lesbar: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
        $out[(Split-Path -Leaf $f)] = @($lines)
    }
    try {
        $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-WindowsUpdateClient/Operational'; StartTime = $From.AddSeconds(-5); EndTime = $To.AddSeconds(5) } -MaxEvents 20 -ErrorAction Stop |
                ForEach-Object { '{0} Id={1} {2}: {3}' -f $_.TimeCreated.ToString('s'), $_.Id, $_.LevelDisplayName, ((Protect-CdtText -Text $_.Message) -replace '\s+', ' ') })
        $out['WindowsUpdateClient'] = $ev
    }
    catch { $out['WindowsUpdateClient'] = @('keine Ereignisse im Zeitfenster bzw. nicht lesbar') }
    return $out
}

# =====================================================================================================
# INSTALLATION: Windows Update (primaer) -> Pruefung -> Fallback (ISO/Repository, -LimitAccess) -> Pruefung
# =====================================================================================================
function Get-CdtRemainingSeconds {
    return [int]([Math]::Floor(([double]$Cdt.Config.TimeBudgetMinutes * 60) - $Cdt.Stopwatch.Elapsed.TotalSeconds))
}

function Write-CdtServicingResult {
    param([object]$Job, [string]$Item, [string]$SourceLabel, [int]$Attempt, [string]$Before, [string]$After)
    $level = 'INFO'
    if (-not $Job.Ok) { $level = 'WARN' }
    $diag = $null
    if (-not $Job.Ok) { $diag = Get-CdtServicingLogExcerpt -From $Job.StartLocal -To (Get-Date) }
    $rec = ''
    if (-not $Job.Ok -and $null -ne $Job.Classification) { $rec = ('Fehlerkategorie {0}: {1}' -f $Job.Classification.Category, $Job.Classification.Text) }
    Write-CdtLog -Level $level -Phase 'Install' -Action ('{0}.{1}' -f $SourceLabel, $Job.Operation) -Message ('{0}: {1}' -f $Item, $(if ($Job.Ok) { 'Befehl ohne Fehler beendet (Zustand wird separat geprueft)' } else { 'fehlgeschlagen' })) `
        -Source $SourceLabel -Attempt $Attempt -DurationMs $Job.DurationMs -PreviousState $Before -TargetState 'Installed' -ResultState $After `
        -Result $(if ($Job.Ok) { 'CommandSucceeded' } else { 'Failed' }) -ErrorCode $Job.Code -ErrorMessage ([string]$Job.Message) -Recommendation $rec `
        -Data ([ordered]@{ restartNeeded = $Job.RestartNeeded; timedOut = $Job.TimedOut; classification = $Job.Classification; diagnostics = $diag })
}

function Install-CdtViaWindowsUpdate {
    param([System.Collections.IDictionary]$State)
    $lang = $Cdt.Config.Language
    $res = [ordered]@{ Attempted = $false; Skipped = $false; SkipReason = ''; Success = $false; Errors = @(); State = $State; NetworkChecked = $false }
    $errors = New-Object System.Collections.ArrayList
    $policy = $Cdt.UpdatePolicy
    Write-CdtLog -Phase 'Install' -Action 'WindowsUpdate.Policy' -Message ('Quellenrichtlinie: {0}. {1}' -f $policy.Decision, ($policy.Reasons -join ' ')) -Data $policy
    if ($policy.Decision -eq 'Blocked') {
        $res.Skipped = $true; $res.SkipReason = 'Richtlinie/Dienst verhindert Windows Update: ' + ($policy.Reasons -join ' ')
        Write-CdtLog -Level WARN -Phase 'Install' -Action 'WindowsUpdate.Skip' -Message $res.SkipReason -Console
        return $res
    }
    $targets = New-Object System.Collections.ArrayList
    if ($policy.WsusConfigured) {
        try {
            $wsusUri = [Uri]([string](Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name 'WUServer'))
            [void]$targets.Add([ordered]@{ Id = 'WSUS'; Url = ('{0}://{1}:{2}/' -f $wsusUri.Scheme, $wsusUri.DnsSafeHost, $wsusUri.Port); Protocol = $wsusUri.Scheme.ToUpperInvariant(); Kind = 'ServiceRoot'; Required = $true; Requirement = $wsusUri.DnsSafeHost; Purpose = 'WSUS (Richtlinie WUServer)'; Reference = 'Richtlinie WUServer' })
        }
        catch { Write-CdtLog -Level WARN -Phase 'Network' -Action 'WSUS' -Message 'WUServer-URL nicht auswertbar' }
    }
    if (-not $policy.WsusConfigured -or $policy.ServicingRepairContentSource -eq 2) { foreach ($t in $CdtWindowsUpdateTargets) { [void]$targets.Add($t) } }
    $net = Invoke-CdtNetworkCheck -PathName 'WindowsUpdate' -Targets @($targets)
    $res.NetworkChecked = $true
    if ($net.AllRequiredFailedAtTransport) {
        $res.Skipped = $true; $res.SkipReason = 'Alle erforderlichen Update-Endpunkte auf DNS-/TCP-Ebene nicht erreichbar (Beleg im Log); Windows-Update-Versuch entfaellt.'
        Write-CdtLog -Level WARN -Phase 'Install' -Action 'WindowsUpdate.Skip' -Message $res.SkipReason -Console
        return $res
    }
    $res.Attempted = $true
    for ($attempt = 1; $attempt -le [int]$Cdt.Config.WuMaxAttempts; $attempt++) {
        $remaining = Get-CdtRemainingSeconds
        if ($remaining -lt 900) { [void]$errors.Add('Zeitbudget fuer weitere Windows-Update-Versuche nicht ausreichend'); break }
        $attemptErrors = New-Object System.Collections.ArrayList
        $sat = Test-CdtComponentsSatisfied -State $State
        if (-not $sat.LanguagePack) {
            Write-CdtConsole -Message ('Windows Update: Install-Language {0} (Versuch {1}/{2}) ...' -f $lang, $attempt, $Cdt.Config.WuMaxAttempts)
            $before = $State.LanguagePack.State
            $timeout = [int][Math]::Min([int]$Cdt.Config.WuAttemptTimeoutMinutes * 60, $remaining - 600)
            $job = Invoke-CdtServicingJob -Operation 'InstallLanguage' -Language $lang -TimeoutSeconds $timeout -SourceLabel 'WindowsUpdate' -Attempt $attempt
            $State = Get-CdtComponentState
            Write-CdtServicingResult -Job $job -Item ('Sprachpaket ' + $lang) -SourceLabel 'WindowsUpdate' -Attempt $attempt -Before $before -After $State.LanguagePack.State
            if (-not $job.Ok) { [void]$attemptErrors.Add($job) }
            if ($job.Ok -and @('Installed', 'InstallPending') -notcontains $State.LanguagePack.State) {
                Write-CdtLog -Level WARN -Phase 'Install' -Action 'WindowsUpdate.Verify' -Message ('Install-Language ohne Fehler, Sprachpaket aber nicht installiert (Ist={0}) - kein Erfolg' -f $State.LanguagePack.State)
            }
        }
        $sat = Test-CdtComponentsSatisfied -State $State
        if ($sat.LanguagePack) {
            foreach ($f in @($sat.MissingRequired) + @($sat.MissingOptional)) {
                $remaining = Get-CdtRemainingSeconds
                if ($remaining -lt 900) { break }
                $capName = Get-CdtCapabilityName -Feature $f -Language $lang
                $before = $State.Capabilities[$f].State
                $timeout = [int][Math]::Min([int]$Cdt.Config.CapabilityTimeoutMinutes * 60, $remaining - 600)
                $job = Invoke-CdtServicingJob -Operation 'AddCapabilityOnline' -CapabilityName $capName -TimeoutSeconds $timeout -SourceLabel 'WindowsUpdate' -Attempt $attempt
                $State = Get-CdtComponentState
                Write-CdtServicingResult -Job $job -Item $capName -SourceLabel 'WindowsUpdate' -Attempt $attempt -Before $before -After $State.Capabilities[$f].State
                if (-not $job.Ok) { [void]$attemptErrors.Add($job) }
            }
        }
        $sat = Test-CdtComponentsSatisfied -State $State
        foreach ($e in $attemptErrors) { [void]$errors.Add(('{0}: {1} {2}' -f $e.Operation, $e.Code, $e.Message)) }
        if ($sat.All) { $res.Success = $true; break }
        $nonTransient = @($attemptErrors | Where-Object { $null -ne $_.Classification -and -not $_.Classification.Transient })
        $netErr = @($attemptErrors | Where-Object { $null -ne $_.Classification -and $_.Classification.Category -match '^(Network|Proxy|Tls|ServiceUnavailable|SourceDownload|HttpForbidden)' })
        if ($netErr.Count -gt 0 -and $attempt -eq 1) {
            Write-CdtLog -Level WARN -Phase 'Network' -Action 'Recheck' -Message 'Installationsfehler deutet auf Netzwerk/Quelle hin - erneute Netzwerkpruefung.'
            [void](Invoke-CdtNetworkCheck -PathName 'WindowsUpdate' -Targets @($targets))
        }
        if ($nonTransient.Count -gt 0) {
            Write-CdtLog -Level WARN -Phase 'Install' -Action 'WindowsUpdate.Retry' -Message ('Nicht voruebergehender Fehler ({0}) - keine weiteren Windows-Update-Versuche.' -f (($nonTransient | ForEach-Object { $_.Classification.Category }) -join ', '))
            break
        }
        if ($attemptErrors.Count -eq 0 -and -not $sat.All) {
            Write-CdtLog -Level WARN -Phase 'Install' -Action 'WindowsUpdate.Retry' -Message 'Befehle ohne Fehler, Zustand dennoch unvollstaendig - Wechsel zum Fallback statt Wiederholung.'
            break
        }
        if ($attempt -lt [int]$Cdt.Config.WuMaxAttempts) {
            $delay = [Math]::Min([int]$Cdt.Config.RetryDelaySeconds, [Math]::Max(0, (Get-CdtRemainingSeconds) - 1200))
            Write-CdtLog -Phase 'Install' -Action 'WindowsUpdate.Retry' -Message ('Voruebergehender Fehler - neuer Versuch in {0} s' -f $delay)
            Start-Sleep -Seconds $delay
        }
    }
    $res.Errors = @($errors)
    $res.State = $State
    return $res
}

function Install-CdtViaFallback {
    param([System.Collections.IDictionary]$State)
    $lang = $Cdt.Config.Language
    $rel = $Cdt.Platform.ReleaseInfo
    $res = [ordered]@{ Attempted = $false; Skipped = $false; SkipReason = ''; Success = $false; SourceUsed = $null; Approval = ''; Download = $null; Errors = @(); State = $State }
    $errors = New-Object System.Collections.ArrayList
    if ($rel.FallbackApproved) { $res.Approval = 'Herstellerseitig fuer ' + $rel.Release + ' genannt: ' + $rel.Evidence }
    elseif ($Cdt.Config.AllowUnconfirmedFallbackSource) {
        $res.Approval = ('NICHT herstellerbestaetigt fuer {0} - Nutzung durch AllowUnconfirmedFallbackSource ausdruecklich freigegeben' -f $rel.Release)
        [void]$Cdt.Warnings.Add($res.Approval)
    }
    else {
        $res.Skipped = $true
        $res.SkipReason = ('Keine herstellerseitig bestaetigte Fallback-Quelle fuer {0} ({1}). Freigabe nur nach eigener Pruefung ueber AllowUnconfirmedFallbackSource.' -f $rel.Release, $rel.Evidence)
        Write-CdtLog -Level WARN -Phase 'Install' -Action 'Fallback.Skip' -Message $res.SkipReason -Console
        return $res
    }
    $res.Attempted = $true
    $sat = Test-CdtComponentsSatisfied -State $State
    $needLp = -not $sat.LanguagePack
    $needCaps = @($sat.MissingRequired) + @($sat.MissingOptional)
    $chosen = $null
    $validation = $null
    $mount = $null
    $download = $null
    try {
        foreach ($cand in (Find-CdtFallbackSource -SourceInfo $rel.Source)) {
            Write-CdtLog -Phase 'Source' -Action 'Candidate' -Message ('Pruefe Quelle: {0} ({1}, {2})' -f $cand.Path, $cand.Kind, $cand.Origin)
            $v = $null
            $m = $null
            if ($cand.Kind -eq 'Iso') {
                if (-not (Test-Path -LiteralPath $cand.Path -PathType Leaf)) { Write-CdtLog -Level WARN -Phase 'Source' -Action 'Candidate' -Message ('ISO nicht vorhanden: {0}' -f $cand.Path); continue }
                $m = Mount-CdtIso -ImagePath $cand.Path
                if (-not $m.Ok) { continue }
                $v = Test-CdtRepository -Path $m.Root -NeedLanguagePack $needLp -Capabilities $needCaps
            }
            else { $v = Test-CdtRepository -Path $cand.Path -NeedLanguagePack $needLp -Capabilities $needCaps }
            Write-CdtLog -Level $(if ($v.Valid) { 'INFO' } else { 'WARN' }) -Phase 'Source' -Action 'Validate' -Message ('Quelle {0}: {1}' -f $cand.Path, $(if ($v.Valid) { 'geeignet' } else { 'ungeeignet: ' + ((@($v.Missing) + @($v.Issues)) -join '; ') })) -Data $v
            if ($v.Valid) { $chosen = $cand; $validation = $v; $mount = $m; break }
            if ($null -ne $m -and $m.MountedByUs) { [void](Dismount-CdtIso -ImagePath $cand.Path -FolderMount $m.FolderMount) }
        }
        if ($null -eq $chosen -and $Cdt.Config.DownloadIso) {
            if ($Cdt.Platform.Architecture -ne $rel.Source.Architecture) {
                [void]$errors.Add(('Freigegebene ISO ist {0}, System ist {1} - kein Download' -f $rel.Source.Architecture, $Cdt.Platform.Architecture))
            }
            else {
                Write-CdtConsole -Message ('Fallback: lade freigegebene ISO {0} ...' -f $rel.Source.FileName)
                $download = Save-CdtIsoDownload -SourceInfo $rel.Source
                $res.Download = $download
                if ($download.Ok) {
                    $m = Mount-CdtIso -ImagePath $download.Path
                    if ($m.Ok) {
                        $v = Test-CdtRepository -Path $m.Root -NeedLanguagePack $needLp -Capabilities $needCaps
                        Write-CdtLog -Level $(if ($v.Valid) { 'INFO' } else { 'WARN' }) -Phase 'Source' -Action 'Validate' -Message ('Heruntergeladene ISO: {0}' -f $(if ($v.Valid) { 'geeignet' } else { 'ungeeignet: ' + ((@($v.Missing) + @($v.Issues)) -join '; ') })) -Data $v
                        if ($v.Valid) { $chosen = [ordered]@{ Kind = 'Iso'; Path = $download.Path; Origin = 'Download'; Owned = $true }; $validation = $v; $mount = $m }
                        elseif ($m.MountedByUs) { [void](Dismount-CdtIso -ImagePath $download.Path -FolderMount $m.FolderMount) }
                    }
                }
                else { [void]$errors.Add('Download: ' + $download.Error) }
            }
        }
        if ($null -eq $chosen) {
            [void]$errors.Add('Keine geeignete Fallback-Quelle verfuegbar')
            Write-CdtLog -Level ERROR -Phase 'Install' -Action 'Fallback' -Message 'Keine geeignete Fallback-Quelle verfuegbar (lokal nicht vorhanden/ungeeignet, Download nicht moeglich).'
        }
        else {
            $res.SourceUsed = [ordered]@{ Kind = $chosen.Kind; Path = $chosen.Path; Origin = $chosen.Origin; Root = $validation.Root; Signature = $validation.Signature; Applicable = $validation.Applicable }
            if ($needLp) {
                $before = $State.LanguagePack.State
                $job = Invoke-CdtServicingJob -Operation 'AddPackage' -PackagePath $validation.LanguagePackCab -TimeoutSeconds ([int][Math]::Min([int]$Cdt.Config.FallbackPackageTimeoutMinutes * 60, (Get-CdtRemainingSeconds) - 300)) -SourceLabel 'Fallback' -Attempt 1
                $State = Get-CdtComponentState
                Write-CdtServicingResult -Job $job -Item ('Sprachpaket ' + (Split-Path -Leaf $validation.LanguagePackCab)) -SourceLabel 'Fallback' -Attempt 1 -Before $before -After $State.LanguagePack.State
                if (-not $job.Ok) { [void]$errors.Add(('AddPackage: {0} {1}' -f $job.Code, $job.Message)) }
            }
            $sat = Test-CdtComponentsSatisfied -State $State
            if ($sat.LanguagePack) {
                foreach ($f in @($sat.MissingRequired) + @($sat.MissingOptional)) {
                    if ((Get-CdtRemainingSeconds) -lt 300) { [void]$errors.Add('Zeitbudget erschoepft'); break }
                    $capName = Get-CdtCapabilityName -Feature $f -Language $lang
                    $before = $State.Capabilities[$f].State
                    $job = Invoke-CdtServicingJob -Operation 'AddCapabilitySource' -CapabilityName $capName -SourcePath $validation.Root -TimeoutSeconds ([int][Math]::Min([int]$Cdt.Config.CapabilityTimeoutMinutes * 60, (Get-CdtRemainingSeconds) - 300)) -SourceLabel 'Fallback' -Attempt 1
                    $State = Get-CdtComponentState
                    Write-CdtServicingResult -Job $job -Item $capName -SourceLabel 'Fallback' -Attempt 1 -Before $before -After $State.Capabilities[$f].State
                    if (-not $job.Ok) { [void]$errors.Add(('AddCapability {0}: {1} {2}' -f $f, $job.Code, $job.Message)) }
                }
            }
            $res.Success = (Test-CdtComponentsSatisfied -State $State).All
        }
    }
    finally {
        if ($null -ne $mount -and $mount.MountedByUs) { [void](Dismount-CdtIso -ImagePath $mount.ImagePath -FolderMount $mount.FolderMount) }
    }
    if ((Test-CdtComponentsSatisfied -State $State).Mandatory -and $null -ne $download -and $download.Ok -and -not $Cdt.Config.KeepDownloadedIso) {
        foreach ($p in @($download.Path, ($download.Path + '.cdt-download.json'))) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
        Write-CdtLog -Phase 'Cleanup' -Action 'DeleteIso' -Message 'Eigener ISO-Download nach erfolgreicher Installation entfernt (kein Ballast im Image).'
    }
    $res.Errors = @($errors)
    $res.State = $State
    return $res
}

function Invoke-CdtInstallation {
    $res = [ordered]@{ Performed = $false; Before = $null; WindowsUpdate = $null; Fallback = $null; Final = $null; Sources = @(); Errors = @() }
    $state = Get-CdtComponentState
    $res.Before = $state
    $sat = Test-CdtComponentsSatisfied -State $state
    if ($sat.All) {
        Write-CdtLog -Phase 'Install' -Action 'Decision' -Message ('Alle konfigurierten Komponenten vorhanden ({0}) - keine Installation.' -f (Get-CdtComponentSummaryText -State $state)) -Console
        $res.Final = $state
        return $res
    }
    $res.Performed = $true
    Write-CdtLog -Phase 'Install' -Action 'Decision' -Message ('Fehlend: {0} - Installation startet.' -f ((@($(if (-not $sat.LanguagePack) { 'Sprachpaket' })) + @($sat.MissingRequired) + @($sat.MissingOptional) | Where-Object { $_ }) -join ', ')) -Console
    $sources = New-Object System.Collections.ArrayList
    Suspend-CdtLanguageComponentTask
    try {
        if ($Cdt.Config.EnableWindowsUpdateSource) {
            $res.WindowsUpdate = Install-CdtViaWindowsUpdate -State $state
            $state = $res.WindowsUpdate.State
            if ($res.WindowsUpdate.Attempted) { [void]$sources.Add('WindowsUpdate') }
        }
        $sat = Test-CdtComponentsSatisfied -State $state
        if (-not $sat.All -and $Cdt.Config.EnableFallbackSource) {
            $reason = 'Windows Update deaktiviert'
            if ($null -ne $res.WindowsUpdate) {
                if ($res.WindowsUpdate.Skipped) { $reason = $res.WindowsUpdate.SkipReason } else { $reason = 'Zustand nach Windows Update unvollstaendig: ' + (Get-CdtComponentSummaryText -State $state) }
            }
            Write-CdtLog -Level WARN -Phase 'Install' -Action 'SwitchToFallback' -Message ('Wechsel zum Fallback. Grund: {0}' -f $reason) -Console
            $res.Fallback = Install-CdtViaFallback -State $state
            $state = $res.Fallback.State
            if ($res.Fallback.Attempted) { [void]$sources.Add('Fallback') }
        }
    }
    finally { Resume-CdtLanguageComponentTask }
    $sat = Test-CdtComponentsSatisfied -State $state
    if ($sat.LanguagePack -and $state.LanguagePack.State -eq 'InstallPending') { Add-CdtBootChange -Item 'LanguagePack' }
    foreach ($f in $state.Capabilities.Keys) { if ($state.Capabilities[$f].State -eq 'InstallPending') { Add-CdtBootChange -Item ('Capability.' + $f) } }
    $res.Final = $state
    $res.Sources = @($sources)
    $errs = New-Object System.Collections.ArrayList
    if ($null -ne $res.WindowsUpdate) { foreach ($e in $res.WindowsUpdate.Errors) { [void]$errs.Add('WU: ' + $e) } }
    if ($null -ne $res.Fallback) { foreach ($e in $res.Fallback.Errors) { [void]$errs.Add('Fallback: ' + $e) } }
    $res.Errors = @($errs)
    Write-CdtLog -Level $(if ($sat.Mandatory) { 'INFO' } else { 'ERROR' }) -Phase 'Install' -Action 'Result' -Message ('Installationsergebnis: {0} | Pflichtumfang erfuellt: {1}' -f (Get-CdtComponentSummaryText -State $state), $sat.Mandatory) -Console
    return $res
}

# =====================================================================================================
# KONFIGURATION: Zeitzone, Systemgebietsschema, Systemanzeigesprache, Quellprofil, Uebernahme, Richtlinie
# =====================================================================================================
function New-CdtActionResult {
    param([string]$Name)
    return [ordered]@{ Name = $Name; Status = 'NotRun'; Changed = $false; RebootRelevant = $false; Before = $null; After = $null; Message = ''; Error = $null }
}

function Write-CdtActionResult {
    param([System.Collections.IDictionary]$Action)
    $level = 'INFO'
    if (@('Failed', 'Blocked') -contains $Action.Status) { $level = 'WARN' }
    Write-CdtLog -Level $level -Phase 'Configure' -Action $Action.Name -Message ('{0}: {1} {2}' -f $Action.Name, $Action.Status, $Action.Message) -PreviousState ([string]$Action.Before) -ResultState ([string]$Action.After) `
        -Result $Action.Status -ErrorMessage ([string]$Action.Error) -Data $Action
}

function Get-CdtCodePageState {
    $cp = Get-CdtRegistryValues -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\Nls\CodePage' -Names @('ACP', 'OEMCP', 'MACCP')
    return [ordered]@{ ACP = [string]$cp.Values['ACP']; OEMCP = [string]$cp.Values['OEMCP']; MACCP = [string]$cp.Values['MACCP']; Utf8Active = ([string]$cp.Values['ACP'] -eq '65001') }
}

function Set-CdtTimeZoneTarget {
    $a = New-CdtActionResult -Name 'TimeZone'
    $target = $Cdt.Config.TimeZoneId
    try {
        $before = (Get-TimeZone -ErrorAction Stop).Id
        $dst = Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name 'DynamicDaylightTimeDisabled'
        $a.Before = '{0} (DST deaktiviert={1})' -f $before, [int]$dst
        if ($before -eq $target -and [int]$dst -eq 0) { $a.Status = 'AlreadyCompliant'; $a.After = $a.Before; return $a }
        if ($before -ne $target) { Set-TimeZone -Id $target -ErrorAction Stop; $a.Changed = $true }
        $dst = Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name 'DynamicDaylightTimeDisabled'
        if ([int]$dst -ne 0) {
            # tzutil ohne Suffix "_dstoff" aktiviert die automatische Sommerzeitumstellung
            $nc = Invoke-CdtNativeCommand -FilePath (Join-Path $env:SystemRoot 'System32\tzutil.exe') -Arguments ('/s "{0}"' -f $target) -TimeoutSeconds 60
            if ($nc.ExitCode -ne 0) { throw ('tzutil Exitcode {0}: {1}' -f $nc.ExitCode, $nc.StdErr) }
            $a.Changed = $true
        }
        $after = (Get-TimeZone -ErrorAction Stop).Id
        $dst = Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name 'DynamicDaylightTimeDisabled'
        $a.After = '{0} (DST deaktiviert={1})' -f $after, [int]$dst
        if ($after -eq $target -and [int]$dst -eq 0) { $a.Status = 'Applied' } else { $a.Status = 'Failed'; $a.Message = 'Zielzeitzone nach dem Setzen nicht bestaetigt' }
    }
    catch { $a.Status = 'Failed'; $a.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    return $a
}

function Set-CdtSystemLocaleTarget {
    $a = New-CdtActionResult -Name 'SystemLocale'
    $lang = $Cdt.Config.Language
    $lcid = '{0:X8}' -f [System.Globalization.CultureInfo]::GetCultureInfo($lang).LCID
    try {
        $current = [string](Get-WinSystemLocale -ErrorAction Stop).Name
        $configured = [string](Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\Nls\Locale' -Name '')
        $a.Before = '{0} (Registry {1})' -f $current, $configured
        if ($current -eq $lang) { $a.Status = 'AlreadyCompliant'; $a.After = $a.Before; return $a }
        if ($configured -ieq $lcid) { $a.Status = 'PendingReboot'; $a.After = $a.Before; $a.RebootRelevant = $true; $a.Message = 'Bereits konfiguriert, wirksam nach Neustart'; return $a }
        $cpBefore = Get-CdtCodePageState
        if ($cpBefore.Utf8Active -and $Cdt.Config.Utf8ConflictPolicy -eq 'Block') {
            $a.Status = 'Blocked'
            $a.Message = 'UTF-8-Option (ACP 65001) ist aktiv. Systemgebietsschema wird nicht geaendert, damit die UTF-8-Einstellung nicht beilaeufig veraendert wird. Entscheidung erforderlich (Utf8ConflictPolicy).'
            return $a
        }
        Set-WinSystemLocale -SystemLocale $lang -ErrorAction Stop
        $a.Changed = $true
        $a.RebootRelevant = $true
        Add-CdtBootChange -Item 'SystemLocale'
        $cpAfter = Get-CdtCodePageState
        if ($cpBefore.Utf8Active -ne $cpAfter.Utf8Active) {
            $Cdt.Utf8ChangedByScript = $true
            $a.Message = ('UTF-8-Status durch Set-WinSystemLocale veraendert ({0} -> {1})' -f $cpBefore.Utf8Active, $cpAfter.Utf8Active)
        }
        $a.After = '{0} (Registry {1}), wirksam nach Neustart' -f [string](Get-WinSystemLocale).Name, [string](Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\Nls\Locale' -Name '')
        $a.Status = 'Applied'
    }
    catch { $a.Status = 'Failed'; $a.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    return $a
}

function Set-CdtSystemUiLanguageTarget {
    param([string]$LanguagePackState)
    $a = New-CdtActionResult -Name 'SystemPreferredUILanguage'
    $lang = $Cdt.Config.Language
    try {
        $before = [string](Get-SystemPreferredUILanguage -ErrorAction Stop)
        $a.Before = $before
        if ($before -eq $lang) { $a.Status = 'AlreadyCompliant'; $a.After = $before; return $a }
        Set-SystemPreferredUILanguage -Language $lang -ErrorAction Stop
        $a.Changed = $true
        $a.RebootRelevant = $true
        Add-CdtBootChange -Item 'SystemPreferredUILanguage'
        $a.After = [string](Get-SystemPreferredUILanguage -ErrorAction Stop)
        $a.Status = 'Applied'
        $a.Message = 'wirksam nach Neustart/Neuanmeldung (Herstellerangabe)'
    }
    catch {
        $a.Error = (Get-CdtErrorInfo -InputObject $_).Message
        if ($LanguagePackState -eq 'InstallPending') {
            $a.Status = 'Deferred'
            $a.RebootRelevant = $true
            $a.Message = 'Sprachpaket wartet auf Neustart - Systemanzeigesprache wird im naechsten Lauf gesetzt'
            Add-CdtBootChange -Item 'SystemPreferredUILanguage.Deferred'
        }
        else { $a.Status = 'Failed' }
    }
    return $a
}

function Get-CdtFormatTargets {
    return [ordered]@{
        sShortDate  = $Cdt.Config.ShortDate
        sShortTime  = $Cdt.Config.ShortTime
        sTimeFormat = $Cdt.Config.LongTime
        iTime       = '1'
        sDecimal    = $Cdt.Config.DecimalSeparator
        sThousand   = $Cdt.Config.ThousandSeparator
    }
}

function New-CdtIntlXml {
    # Dokumentiertes Antwortdatei-Format fuer intl.cpl (MS KB 2764405) - nur als Fallback
    param([bool]$CopyToSystem, [bool]$CopyToDefaultUser)
    $esc = { param($v) [System.Security.SecurityElement]::Escape([string]$v) }
    $userAttr = 'UserID="Current"'
    if ($CopyToDefaultUser) { $userAttr += ' CopySettingsToDefaultUserAcct="true"' }
    if ($CopyToSystem) { $userAttr += ' CopySettingsToSystemAcct="true"' }
    $c = $Cdt.Config
    $lines = @(
        '<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">'
        ' <gs:UserList>'
        ('  <gs:User {0}/>' -f $userAttr)
        ' </gs:UserList>'
        ' <gs:LocationPreferences>'
        ('  <gs:GeoID Value="{0}"/>' -f (& $esc $c.GeoId))
        ' </gs:LocationPreferences>'
        ' <gs:MUILanguagePreferences>'
        ('  <gs:MUILanguage Value="{0}"/>' -f (& $esc $c.Language))
        ' </gs:MUILanguagePreferences>'
        ' <gs:InputPreferences>'
        ('  <gs:InputLanguageID Action="add" ID="{0}"/>' -f (& $esc $c.InputMethodTip))
        ' </gs:InputPreferences>'
        ' <gs:UserLocale>'
        ('  <gs:Locale Name="{0}" SetAsCurrent="true" ResetAllSettings="false">' -f (& $esc $c.Language))
        '   <gs:Win32>'
        ('    <gs:sShortDate>{0}</gs:sShortDate>' -f (& $esc $c.ShortDate))
        ('    <gs:sTimeFormat>{0}</gs:sTimeFormat>' -f (& $esc $c.LongTime))
        ('    <gs:sDecimal>{0}</gs:sDecimal>' -f (& $esc $c.DecimalSeparator))
        ('    <gs:sThousand>{0}</gs:sThousand>' -f (& $esc $c.ThousandSeparator))
        '   </gs:Win32>'
        '  </gs:Locale>'
        ' </gs:UserLocale>'
        '</gs:GlobalizationServices>'
    )
    return ($lines -join "`r`n")
}

function Invoke-CdtIntlCpl {
    param([string]$XmlContent, [string]$Purpose)
    if (-not (Test-Path -LiteralPath $Cdt.Log.WorkDir)) { [void](New-Item -ItemType Directory -Path $Cdt.Log.WorkDir -Force) }
    $file = Join-Path $Cdt.Log.WorkDir ('intl-{0}-{1}.xml' -f $Purpose, $Cdt.RunId)
    [System.IO.File]::WriteAllText($file, $XmlContent, (New-Object System.Text.UTF8Encoding($false)))
    try {
        $nc = Invoke-CdtNativeCommand -FilePath (Join-Path $env:SystemRoot 'System32\rundll32.exe') -Arguments ('shell32.dll,Control_RunDLL intl.cpl,,/f:"{0}"' -f $file) -TimeoutSeconds 180
        Start-Sleep -Seconds 3
        Write-CdtLog -Phase 'Configure' -Action ('IntlCpl.' + $Purpose) -Message ('intl.cpl-Antwortdatei angewendet (Exitcode {0}, Zeitlimit={1}); Ergebnis wird ueber die Registry geprueft' -f $nc.ExitCode, $nc.TimedOut)
        return $nc
    }
    finally { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
}

function Set-CdtSourceProfile {
    # Quellwerte im tatsaechlichen Ausfuehrungskonto setzen (SYSTEM -> HKU\.DEFAULT, Admin -> eigenes Profil)
    $a = New-CdtActionResult -Name 'SourceProfile'
    $lang = $Cdt.Config.Language
    $tip = $Cdt.Config.InputMethodTip
    $steps = New-Object System.Collections.ArrayList
    try {
        $desired = @($lang) + @($Cdt.Config.AdditionalUserLanguages | Where-Object { $_ -and $_ -ne $lang })
        $current = @(Get-WinUserLanguageList -ErrorAction Stop)
        $currentTags = @($current | ForEach-Object { [string]$_.LanguageTag })
        $firstTips = @()
        if ($current.Count -gt 0) { $firstTips = @($current[0].InputMethodTips) }
        $a.Before = 'Sprachliste=' + ($currentTags -join ',')
        if (($currentTags -join ',') -ne ($desired -join ',') -or $firstTips -notcontains $tip) {
            $list = New-WinUserLanguageList -Language $lang
            $list[0].InputMethodTips.Clear()
            $list[0].InputMethodTips.Add($tip)
            foreach ($add in @($desired | Select-Object -Skip 1)) { $list.Add($add) }
            Set-WinUserLanguageList -LanguageList $list -Force -ErrorAction Stop
            [void]$steps.Add('Sprachliste')
        }
        $ov = Get-WinUILanguageOverride -ErrorAction Stop
        if ($null -eq $ov -or [string]$ov.Name -ne $lang) { Set-WinUILanguageOverride -Language $lang -ErrorAction Stop; [void]$steps.Add('Anzeigesprache-Override') }
        $im = Get-WinDefaultInputMethodOverride -ErrorAction Stop
        $imText = ''
        if ($null -ne $im) { if ($null -ne $im.PSObject.Properties['InputMethodTip']) { $imText = [string]$im.InputMethodTip } else { $imText = [string]$im } }
        if ($imText -ne $tip) { Set-WinDefaultInputMethodOverride -InputTip $tip -ErrorAction Stop; [void]$steps.Add('Standardeingabe-Override') }
        $hive = Read-CdtIntlHive -HiveName $Cdt.Context.SourceHiveName
        $fmt = Get-CdtFormatTargets
        $fmtDeviation = @($fmt.Keys | Where-Object { $null -ne $hive.Formats[$_] -and [string]$hive.Formats[$_] -cne [string]$fmt[$_] })
        if ([string]$hive.LocaleName -ne $lang -or $fmtDeviation.Count -gt 0) { Set-Culture -CultureInfo $lang -ErrorAction Stop; [void]$steps.Add('Kultur/Formate') }
        $geo = Get-WinHomeLocation -ErrorAction Stop
        if ([int]$geo.GeoId -ne [int]$Cdt.Config.GeoId) { Set-WinHomeLocation -GeoId ([int]$Cdt.Config.GeoId) -ErrorAction Stop; [void]$steps.Add('Region') }
        $hive = Read-CdtIntlHive -HiveName $Cdt.Context.SourceHiveName
        $fmtDeviation = @($fmt.Keys | Where-Object { $null -ne $hive.Formats[$_] -and [string]$hive.Formats[$_] -cne [string]$fmt[$_] })
        if ($fmtDeviation.Count -gt 0) {
            Write-CdtLog -Level WARN -Phase 'Configure' -Action 'SourceProfile.Formats' -Message ('Formatwerte nach Set-Culture abweichend ({0}) - Fallback intl.cpl (nur Quellkonto)' -f ($fmtDeviation -join ', '))
            [void](Invoke-CdtIntlCpl -XmlContent (New-CdtIntlXml -CopyToSystem $false -CopyToDefaultUser $false) -Purpose 'Source')
            [void]$steps.Add('Formate(intl.cpl)')
        }
        $a.Changed = ($steps.Count -gt 0)
        if ($a.Changed) { $a.Status = 'Applied' } else { $a.Status = 'AlreadyCompliant' }
        $a.After = 'Schritte: ' + ($(if ($steps.Count) { $steps -join ', ' } else { 'keine' }))
    }
    catch { $a.Status = 'Failed'; $a.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    return $a
}

function Copy-CdtSettingsToSystem {
    # Primaer Copy-UserInternationalSettingsToSystem (kopiert die Werte des AKTUELLEN Kontos), Fallback intl.cpl
    param([switch]$UseFallback)
    $a = New-CdtActionResult -Name $(if ($UseFallback) { 'CopyToSystem.IntlCplFallback' } else { 'CopyToSystem' })
    try {
        if ($UseFallback) { [void](Invoke-CdtIntlCpl -XmlContent (New-CdtIntlXml -CopyToSystem $true -CopyToDefaultUser $true) -Purpose 'Copy') }
        else { Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true -ErrorAction Stop }
        $a.Changed = $true
        $a.RebootRelevant = $true
        Add-CdtBootChange -Item 'CopyToSystem'
        $a.Status = 'Applied'
        $a.Message = ('Quelle: {0} ({1}); Ziele: Willkommensbildschirm/Systemkonten, neue Benutzer' -f $Cdt.Context.Identity, $Cdt.Context.SourceHiveName)
    }
    catch { $a.Status = 'Failed'; $a.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    return $a
}

function Set-CdtCleanupPolicy {
    # Gezielt: nur die dokumentierte Richtlinie gegen LPRemove; keine pauschale Deaktivierung von Wartungsaufgaben
    $a = New-CdtActionResult -Name 'BlockCleanupOfUnusedPreinstalledLangPacks'
    $subKey = 'SOFTWARE\Policies\Microsoft\Control Panel\International'
    $cur = Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey $subKey -Name 'BlockCleanupOfUnusedPreinstalledLangPacks'
    $a.Before = [string]$cur
    if ($null -ne $cur -and [int]$cur -eq 1) { $a.Status = 'AlreadyCompliant'; $a.After = '1'; return $a }
    if ($null -ne $cur) { $a.Status = 'Blocked'; $a.After = [string]$cur; $a.Message = ('Richtlinie explizit auf {0} gesetzt (vermutlich GPO/MDM) - wird nicht uebersteuert' -f $cur); return $a }
    try {
        $path = 'HKLM:\' + $subKey
        if (-not (Test-Path -LiteralPath $path)) { [void](New-Item -Path $path -Force) }
        [void](New-ItemProperty -Path $path -Name 'BlockCleanupOfUnusedPreinstalledLangPacks' -Value 1 -PropertyType DWord -Force)
        $a.After = [string](Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey $subKey -Name 'BlockCleanupOfUnusedPreinstalledLangPacks')
        $a.Changed = $true
        if ($a.After -eq '1') { $a.Status = 'Applied' } else { $a.Status = 'Failed' }
    }
    catch { $a.Status = 'Failed'; $a.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    return $a
}

function Invoke-CdtConfiguration {
    # Fuehrt nur Schritte aus, deren Pruefung nicht bestanden ist (wiederholbar, keine unnoetigen Aenderungen)
    param([System.Collections.IDictionary]$Components)
    $actions = New-Object System.Collections.ArrayList
    $snap = Get-CdtSettingsSnapshot
    $cmp = Test-CdtCompliance -Components $Components -Snapshot $snap -Stage 'PreConfigure'
    $failing = @($cmp.Checks | Where-Object { @('Fail', 'NotVerifiable') -contains $_.Status -or ($_.Status -eq 'Warn' -and $_.Id -like 'SRC-*') } | ForEach-Object { $_.Id })
    $need = { param($prefix) @($failing | Where-Object { $_ -like $prefix }).Count -gt 0 }
    if (& $need 'S-TZ*') { [void]$actions.Add((Set-CdtTimeZoneTarget)) }
    if ($Cdt.Config.SetBlockCleanupPolicy -and (& $need 'S-CLEANUP')) { [void]$actions.Add((Set-CdtCleanupPolicy)) }
    if (& $need 'S-SYSLOCALE') { [void]$actions.Add((Set-CdtSystemLocaleTarget)) }
    if (& $need 'S-SYSUI') { [void]$actions.Add((Set-CdtSystemUiLanguageTarget -LanguagePackState $Components.LanguagePack.State)) }
    $sourceAction = $null
    if (& $need 'SRC-*') { $sourceAction = Set-CdtSourceProfile; [void]$actions.Add($sourceAction) }
    $sourceOk = $true
    if ($null -ne $sourceAction -and $sourceAction.Status -eq 'Failed') { $sourceOk = $false }
    $targetFailing = (& $need 'W-*') -or (& $need 'NU-*')
    if ($sourceOk -and ($targetFailing -or ($null -ne $sourceAction -and $sourceAction.Changed))) {
        $snapSrc = Get-CdtSettingsSnapshot
        $srcCheck = Test-CdtCompliance -Components $Components -Snapshot $snapSrc -Stage 'SourceVerify'
        $srcBad = @($srcCheck.Checks | Where-Object { $_.Id -like 'SRC-*' -and $_.Blocking -and @('Fail', 'NotVerifiable') -contains $_.Status })
        if ($srcBad.Count -gt 0) {
            $blocked = New-CdtActionResult -Name 'CopyToSystem'
            $blocked.Status = 'Blocked'
            $blocked.Message = 'Quellwerte im Ausfuehrungskonto nicht korrekt (' + (($srcBad | ForEach-Object { $_.Id }) -join ', ') + ') - keine Uebernahme falscher Werte'
            [void]$actions.Add($blocked)
        }
        else {
            $copy = Copy-CdtSettingsToSystem
            [void]$actions.Add($copy)
            $snapT = Get-CdtSettingsSnapshot
            $tCheck = Test-CdtCompliance -Components $Components -Snapshot $snapT -Stage 'TargetVerify'
            $tBad = @($tCheck.Checks | Where-Object { ($_.Id -like 'W-*' -or $_.Id -like 'NU-*') -and $_.Blocking -and @('Fail', 'NotVerifiable') -contains $_.Status })
            if ($tBad.Count -gt 0) {
                Write-CdtLog -Level WARN -Phase 'Configure' -Action 'CopyToSystem.Verify' -Message ('Uebernahme unvollstaendig ({0}) - Fallback intl.cpl' -f (($tBad | ForEach-Object { $_.Id }) -join ', ')) -Console
                [void]$actions.Add((Copy-CdtSettingsToSystem -UseFallback))
            }
        }
    }
    foreach ($act in $actions) { Write-CdtActionResult -Action $act }
    $summary = ($actions | ForEach-Object { '{0}={1}' -f $_.Name, $_.Status }) -join ' '
    if ($actions.Count -eq 0) { $summary = 'keine Aenderung erforderlich' }
    Write-CdtLog -Phase 'Configure' -Action 'Result' -Message ('Konfiguration: {0}' -f $summary) -Console
    return , ($actions.ToArray())
}

# =====================================================================================================
# PRUEFUNG: persistierte Werte (Registry/Cmdlets), nicht die Kultur der laufenden Sitzung
# =====================================================================================================
function Read-CdtIntlHive {
    param([string]$HiveName)
    $lang = $Cdt.Config.Language
    $base = $HiveName + '\Control Panel\International'
    $h = [ordered]@{ HiveName = $HiveName; Available = $false; Error = $null; LocaleName = $null; Formats = [ordered]@{}; GeoNation = $null; Languages = @()
        LanguageInputMethods = @(); InputMethodOverride = $null; PreloadFirst = $null; PreferredUILanguages = @(); PreferredUILanguagesPending = @() }
    $intl = Get-CdtRegistryValues -Hive Users -SubKey $base -Names @('LocaleName', 'sShortDate', 'sShortTime', 'sTimeFormat', 'iTime', 'sDecimal', 'sThousand')
    if (-not $intl.KeyExists) { $h.Error = ('Schluessel HKU\{0} nicht vorhanden/lesbar {1}' -f $base, $intl.Error); return $h }
    $h.Available = $true
    $h.LocaleName = $intl.Values['LocaleName']
    foreach ($n in @('sShortDate', 'sShortTime', 'sTimeFormat', 'iTime', 'sDecimal', 'sThousand')) { $h.Formats[$n] = $intl.Values[$n] }
    $h.GeoNation = Get-CdtRegistryValueOrNull -Hive Users -SubKey ($base + '\Geo') -Name 'Nation'
    $up = Get-CdtRegistryValues -Hive Users -SubKey ($base + '\User Profile') -Names @('Languages', 'InputMethodOverride')
    $h.Languages = @(ConvertTo-CdtArray -InputObject $up.Values['Languages'])
    $h.InputMethodOverride = $up.Values['InputMethodOverride']
    $ul = Get-CdtRegistryValues -Hive Users -SubKey ($base + '\User Profile\' + $lang) -Names $null
    $h.LanguageInputMethods = @($ul.Values.Keys | Where-Object { $_ -match '^[0-9A-Fa-f]{4}:' })
    $h.PreloadFirst = Get-CdtRegistryValueOrNull -Hive Users -SubKey ($HiveName + '\Keyboard Layout\Preload') -Name '1'
    $desk = Get-CdtRegistryValues -Hive Users -SubKey ($HiveName + '\Control Panel\Desktop') -Names @('PreferredUILanguages', 'PreferredUILanguagesPending')
    $h.PreferredUILanguages = @(ConvertTo-CdtArray -InputObject $desk.Values['PreferredUILanguages'])
    $h.PreferredUILanguagesPending = @(ConvertTo-CdtArray -InputObject $desk.Values['PreferredUILanguagesPending'])
    return $h
}

function Invoke-CdtWithDefaultUserHive {
    # Vorlageprofil fuer neue Benutzer lesen: bereits geladenen Hive nutzen, sonst laden und sicher entladen
    param([scriptblock]$ScriptBlock)
    $profileDir = [string](Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -Name 'Default')
    if ([string]::IsNullOrEmpty($profileDir)) { $profileDir = '%SystemDrive%\Users\Default' }
    $profileDir = [Environment]::ExpandEnvironmentVariables($profileDir)
    $hiveFile = Join-Path $profileDir 'NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $hiveFile)) { return [ordered]@{ Available = $false; Error = ('Vorlageprofil nicht gefunden: {0}' -f $hiveFile) } }
    $suffix = $hiveFile.Substring(2)
    $hl = Get-CdtRegistryValues -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\hivelist' -Names $null
    foreach ($k in @($hl.Values.Keys)) {
        if ([string]$k -like '\REGISTRY\USER\*' -and [string]$hl.Values[$k] -like ('*' + $suffix)) {
            $name = ([string]$k).Substring('\REGISTRY\USER\'.Length)
            $res = & $ScriptBlock $name
            $res['LoadedBy'] = 'bereits geladen (fremd, nicht entladen)'
            return $res
        }
    }
    $mount = 'CDT_DELANG_DEFUSER'
    $load = Invoke-CdtNativeCommand -FilePath (Join-Path $env:SystemRoot 'System32\reg.exe') -Arguments ('load "HKU\{0}" "{1}"' -f $mount, $hiveFile) -TimeoutSeconds 60
    if ($load.ExitCode -ne 0) { return [ordered]@{ Available = $false; Error = ('Hive nicht ladbar ({0}): {1}' -f $load.ExitCode, ($load.StdErr -replace '\s+', ' ')) } }
    try {
        $res = & $ScriptBlock $mount
        $res['LoadedBy'] = 'durch dieses Script geladen und entladen'
        return $res
    }
    finally {
        $unloaded = $false
        for ($i = 1; $i -le 5 -and -not $unloaded; $i++) {
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            $u = Invoke-CdtNativeCommand -FilePath (Join-Path $env:SystemRoot 'System32\reg.exe') -Arguments ('unload "HKU\{0}"' -f $mount) -TimeoutSeconds 60
            if ($u.ExitCode -eq 0) { $unloaded = $true } else { Start-Sleep -Seconds $i }
        }
        if (-not $unloaded) {
            $Cdt.HiveUnloadFailed = $true
            Write-CdtLog -Level ERROR -Phase 'Verify' -Action 'DefaultUserHive' -Message ('Vorlage-Hive HKU\{0} konnte nicht entladen werden - Neustart erforderlich, vorher kein Sysprep' -f $mount)
        }
    }
}

function Get-CdtSettingsSnapshot {
    $lang = $Cdt.Config.Language
    $s = [ordered]@{ TimestampUtc = (Get-CdtUtcTimestamp); System = [ordered]@{}; Source = $null; SourceCmdlets = [ordered]@{}; Welcome = $null; LocalService = $null; NetworkService = $null; NewUser = $null; Errors = @() }
    $errs = New-Object System.Collections.ArrayList
    try { $s.System.SystemPreferredUILanguage = [string](Get-SystemPreferredUILanguage -ErrorAction Stop) } catch { $s.System.SystemPreferredUILanguage = $null; [void]$errs.Add('Get-SystemPreferredUILanguage: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    try { $s.System.SystemLocale = [string](Get-WinSystemLocale -ErrorAction Stop).Name } catch { $s.System.SystemLocale = $null; [void]$errs.Add('Get-WinSystemLocale: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    $s.System.SystemLocaleRegistry = [string](Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\Nls\Locale' -Name '')
    $s.System.CodePages = Get-CdtCodePageState
    try { $s.System.TimeZoneId = (Get-TimeZone -ErrorAction Stop).Id } catch { $s.System.TimeZoneId = $null; [void]$errs.Add('Get-TimeZone: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    $dst = Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name 'DynamicDaylightTimeDisabled'
    if ($null -eq $dst) { $s.System.DynamicDaylightTimeDisabled = 0 } else { $s.System.DynamicDaylightTimeDisabled = [int]$dst }
    $s.System.MuiRegistered = Test-CdtRegistryKey -Hive LocalMachine -SubKey ('SYSTEM\CurrentControlSet\Control\MUI\UILanguages\' + $lang)
    $s.System.BlockCleanupPolicy = Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SOFTWARE\Policies\Microsoft\Control Panel\International' -Name 'BlockCleanupOfUnusedPreinstalledLangPacks'
    $s.System.TimeZoneRedirectionPolicy = Get-CdtRegistryValueOrNull -Hive LocalMachine -SubKey 'SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -Name 'fEnableTimeZoneRedirection'
    $s.Source = Read-CdtIntlHive -HiveName $Cdt.Context.SourceHiveName
    try {
        $ll = @(Get-WinUserLanguageList -ErrorAction Stop)
        $s.SourceCmdlets.LanguageTags = @($ll | ForEach-Object { [string]$_.LanguageTag })
        $s.SourceCmdlets.FirstInputTips = @()
        if ($ll.Count -gt 0) { $s.SourceCmdlets.FirstInputTips = @($ll[0].InputMethodTips) }
    }
    catch { [void]$errs.Add('Get-WinUserLanguageList: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    try { $o = Get-WinUILanguageOverride -ErrorAction Stop; $s.SourceCmdlets.UiLanguageOverride = $(if ($null -ne $o) { [string]$o.Name } else { '' }) } catch { [void]$errs.Add('Get-WinUILanguageOverride: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    try {
        $im = Get-WinDefaultInputMethodOverride -ErrorAction Stop
        $s.SourceCmdlets.InputMethodOverride = ''
        if ($null -ne $im) { if ($null -ne $im.PSObject.Properties['InputMethodTip']) { $s.SourceCmdlets.InputMethodOverride = [string]$im.InputMethodTip } else { $s.SourceCmdlets.InputMethodOverride = [string]$im } }
    }
    catch { [void]$errs.Add('Get-WinDefaultInputMethodOverride: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    try { $s.SourceCmdlets.HomeLocation = [int](Get-WinHomeLocation -ErrorAction Stop).GeoId } catch { [void]$errs.Add('Get-WinHomeLocation: ' + (Get-CdtErrorInfo -InputObject $_).Message) }
    $s.Welcome = Read-CdtIntlHive -HiveName '.DEFAULT'
    if (Test-CdtRegistryKey -Hive Users -SubKey 'S-1-5-19') { $s.LocalService = Read-CdtIntlHive -HiveName 'S-1-5-19' }
    if (Test-CdtRegistryKey -Hive Users -SubKey 'S-1-5-20') { $s.NetworkService = Read-CdtIntlHive -HiveName 'S-1-5-20' }
    $s.NewUser = Invoke-CdtWithDefaultUserHive -ScriptBlock { param($hiveName) Read-CdtIntlHive -HiveName $hiveName }
    $s.Errors = @($errs)
    return $s
}

function New-CdtCheck {
    param([string]$Id, [string]$Category, [string]$Scope, [string]$Name, [AllowNull()][object]$Expected, [AllowNull()][object]$Actual,
        [ValidateSet('Pass', 'Fail', 'Warn', 'PendingReboot', 'NotVerifiable', 'Info', 'Skipped')][string]$Status, [bool]$Blocking = $true, [string]$Note = '')
    if (-not $Blocking -and @('Fail', 'NotVerifiable') -contains $Status) { $Note = ('{0} (nicht blockierend: {1})' -f $Note, $Status).Trim(); $Status = 'Warn' }
    return [ordered]@{ Id = $Id; Category = $Category; Scope = $Scope; Name = $Name; Expected = $Expected; Actual = $Actual; Status = $Status; Blocking = $Blocking; Note = $Note }
}

function Add-CdtHiveChecks {
    # Gleiche Pruefungen fuer Quellkonto, Willkommensbildschirm/Systemkonten und Vorlage neuer Benutzer
    param([System.Collections.ArrayList]$List, [string]$Prefix, [string]$Scope, [AllowNull()][System.Collections.IDictionary]$Hive, [bool]$Blocking, [switch]$Source)
    $lang = $Cdt.Config.Language
    if ($null -eq $Hive -or -not $Hive.Available) {
        $err = 'nicht lesbar'
        if ($null -ne $Hive -and $Hive.Error) { $err = $Hive.Error }
        [void]$List.Add((New-CdtCheck -Id ($Prefix + '-HIVE') -Category 'Profile' -Scope $Scope -Name 'Registry-Hive lesbar' -Expected 'lesbar' -Actual $err -Status 'NotVerifiable' -Blocking $Blocking))
        return
    }
    $st = 'Fail'; if ([string]$Hive.LocaleName -eq $lang) { $st = 'Pass' }
    [void]$List.Add((New-CdtCheck -Id ($Prefix + '-LOCALE') -Category 'Profile' -Scope $Scope -Name 'Regionalformat (LocaleName)' -Expected $lang -Actual $Hive.LocaleName -Status $st -Blocking $Blocking))
    $fmt = Get-CdtFormatTargets
    foreach ($k in $fmt.Keys) {
        $actual = $Hive.Formats[$k]
        if ($null -eq $actual) { [void]$List.Add((New-CdtCheck -Id ('{0}-FMT-{1}' -f $Prefix, $k) -Category 'Profile' -Scope $Scope -Name $k -Expected $fmt[$k] -Actual '(nicht gesetzt = Standard von de-DE)' -Status 'Pass' -Blocking $Blocking -Note 'Wert nicht ueberschrieben; de-DE-Standard entspricht dem Ziel')) }
        else {
            $st = 'Fail'; if ([string]$actual -ceq [string]$fmt[$k]) { $st = 'Pass' }
            [void]$List.Add((New-CdtCheck -Id ('{0}-FMT-{1}' -f $Prefix, $k) -Category 'Profile' -Scope $Scope -Name $k -Expected $fmt[$k] -Actual $actual -Status $st -Blocking $Blocking))
        }
    }
    $st = 'Fail'; if ([string]$Hive.GeoNation -eq [string]$Cdt.Config.GeoId) { $st = 'Pass' }
    [void]$List.Add((New-CdtCheck -Id ($Prefix + '-GEO') -Category 'Profile' -Scope $Scope -Name 'Land/Region (GeoID)' -Expected ([string]$Cdt.Config.GeoId) -Actual $Hive.GeoNation -Status $st -Blocking $Blocking))
    $langs = @($Hive.Languages)
    $first = $null; if ($langs.Count -gt 0) { $first = [string]$langs[0] }
    $st = 'Fail'; if ($first -eq $lang) { $st = 'Pass' }
    [void]$List.Add((New-CdtCheck -Id ($Prefix + '-LANGLIST') -Category 'Profile' -Scope $Scope -Name 'Sprachliste (erste Sprache)' -Expected $lang -Actual ($langs -join ',') -Status $st -Blocking $Blocking))
    if ($Source) {
        $st = 'Fail'; if (@($Hive.LanguageInputMethods) -contains $Cdt.Config.InputMethodTip) { $st = 'Pass' }
        [void]$List.Add((New-CdtCheck -Id ($Prefix + '-INPUT') -Category 'Profile' -Scope $Scope -Name 'Eingabemethode de-DE' -Expected $Cdt.Config.InputMethodTip -Actual (@($Hive.LanguageInputMethods) -join ',') -Status $st -Blocking $Blocking))
    }
    else {
        $st = 'Fail'; if ([string]$Hive.PreloadFirst -ieq [string]$Cdt.Config.KeyboardLayoutId) { $st = 'Pass' }
        [void]$List.Add((New-CdtCheck -Id ($Prefix + '-KEYBOARD') -Category 'Profile' -Scope $Scope -Name 'Standardtastatur (Keyboard Layout\Preload\1)' -Expected $Cdt.Config.KeyboardLayoutId -Actual $Hive.PreloadFirst -Status $st -Blocking $Blocking))
    }
    $ui = @($Hive.PreferredUILanguages)
    if ($ui.Count -eq 0) { [void]$List.Add((New-CdtCheck -Id ($Prefix + '-UILANG') -Category 'Profile' -Scope $Scope -Name 'Anzeigesprache (PreferredUILanguages)' -Expected $lang -Actual '(nicht gesetzt - folgt Sprachliste/Systemsprache)' -Status 'Pass' -Blocking $Blocking)) }
    else {
        $st = 'Fail'; if ([string]$ui[0] -eq $lang) { $st = 'Pass' }
        [void]$List.Add((New-CdtCheck -Id ($Prefix + '-UILANG') -Category 'Profile' -Scope $Scope -Name 'Anzeigesprache (PreferredUILanguages)' -Expected $lang -Actual ($ui -join ',') -Status $st -Blocking $Blocking))
    }
}

function Test-CdtCompliance {
    param([System.Collections.IDictionary]$Components, [System.Collections.IDictionary]$Snapshot, [string]$Stage, [switch]$IncludeExtended)
    $lang = $Cdt.Config.Language
    $list = New-Object System.Collections.ArrayList
    # --- Komponenten ---
    $lp = $Components.LanguagePack
    switch ($lp.State) {
        'Installed' { $st = 'Pass' } 'InstallPending' { $st = 'PendingReboot' } 'Unknown' { $st = 'NotVerifiable' } default { $st = 'Fail' }
    }
    [void]$list.Add((New-CdtCheck -Id 'C-LP' -Category 'Component' -Scope 'System' -Name ('Windows-Anzeigesprachpaket {0} (CBS)' -f $lang) -Expected 'Installed' -Actual ('{0} (CBS={1})' -f $lp.State, $lp.CbsState) -Status $st))
    $st = 'Pass'
    if (-not $lp.MuiRegistered) { if ($lp.State -eq 'InstallPending') { $st = 'PendingReboot' } else { $st = 'Fail' } }
    [void]$list.Add((New-CdtCheck -Id 'C-MUI' -Category 'Component' -Scope 'System' -Name 'MUI-Registrierung der Anzeigesprache' -Expected $true -Actual $lp.MuiRegistered -Status $st))
    if ($null -eq $lp.InstalledLanguagePacks) { $st = 'NotVerifiable' }
    elseif ([string]$lp.InstalledLanguagePacks -match 'LpCab' -or $lp.IsBaseLanguage) { $st = 'Pass' }
    elseif ($lp.State -eq 'InstallPending') { $st = 'PendingReboot' }
    else { $st = 'Fail' }
    [void]$list.Add((New-CdtCheck -Id 'C-IL' -Category 'Component' -Scope 'System' -Name 'Get-InstalledLanguage meldet LpCab' -Expected 'LpCab' -Actual $lp.InstalledLanguagePacks -Status $st))
    foreach ($f in $CdtKnownCapabilities) {
        $c = $Components.Capabilities[$f]
        $isReq = (@($Cdt.Config.RequiredCapabilities) -contains $f)
        $isOpt = (@($Cdt.Config.OptionalCapabilities) -contains $f)
        if (-not ($isReq -or $isOpt)) { continue }
        switch ($c.State) { 'Installed' { $st = 'Pass' } 'InstallPending' { $st = 'PendingReboot' } 'Unknown' { $st = 'NotVerifiable' } default { $st = 'Fail' } }
        [void]$list.Add((New-CdtCheck -Id ('C-CAP-' + $f) -Category 'Component' -Scope 'System' -Name $c.Name -Expected 'Installed' -Actual $c.State -Status $st -Blocking $isReq -Note $(if ($isReq) { 'Pflichtkomponente' } else { 'optionale Komponente' })))
    }
    $pend = $Components.Pending
    $st = 'Pass'; if ($pend.Any) { $st = 'PendingReboot' }
    [void]$list.Add((New-CdtCheck -Id 'C-REBOOT' -Category 'Component' -Scope 'System' -Name 'Ausstehender Servicing-Neustart (CBS/WU)' -Expected 'kein' -Actual ('CBS={0} Pakete={1} WU={2} PFRO={3}' -f $pend.CbsRebootPending, $pend.CbsPackagesPending, $pend.WuRebootRequired, $pend.PendingFileRenameEntries) -Status $st))
    # --- System ---
    $sys = $Snapshot.System
    if ($null -eq $sys.SystemPreferredUILanguage) { $st = 'NotVerifiable' }
    elseif ($sys.SystemPreferredUILanguage -eq $lang) { if (Test-CdtChangedThisBoot -Item 'SystemPreferredUILanguage') { $st = 'PendingReboot' } else { $st = 'Pass' } }
    elseif ((Test-CdtChangedThisBoot -Item 'SystemPreferredUILanguage.Deferred') -and $lp.State -eq 'InstallPending') { $st = 'PendingReboot' }
    else { $st = 'Fail' }
    [void]$list.Add((New-CdtCheck -Id 'S-SYSUI' -Category 'System' -Scope 'System' -Name 'Bevorzugte System-Anzeigesprache' -Expected $lang -Actual $sys.SystemPreferredUILanguage -Status $st))
    $lcid = '{0:X8}' -f [System.Globalization.CultureInfo]::GetCultureInfo($lang).LCID
    if ($null -eq $sys.SystemLocale) { $st = 'NotVerifiable' }
    elseif ($sys.SystemLocale -eq $lang -and -not (Test-CdtChangedThisBoot -Item 'SystemLocale')) { $st = 'Pass' }
    elseif ((Test-CdtChangedThisBoot -Item 'SystemLocale') -or $sys.SystemLocaleRegistry -ieq $lcid) { $st = 'PendingReboot' }
    else { $st = 'Fail' }
    [void]$list.Add((New-CdtCheck -Id 'S-SYSLOCALE' -Category 'System' -Scope 'System' -Name 'Systemgebietsschema (Nicht-Unicode)' -Expected $lang -Actual ('{0} (Registry {1})' -f $sys.SystemLocale, $sys.SystemLocaleRegistry) -Status $st))
    $cp = $sys.CodePages
    $base = $Cdt.State.utf8Baseline
    if ($Cdt.Utf8ChangedByScript) { $st = 'Fail'; $note = 'UTF-8-Status wurde durch die Systemgebietsschema-Aenderung veraendert' }
    elseif ($null -ne $base -and [string]$base.ACP -ne [string]$cp.ACP) { $st = 'Warn'; $note = ('ACP abweichend von Baseline {0} (Ursache pruefen)' -f $base.ACP) }
    else { $st = 'Pass'; $note = 'unveraendert' }
    [void]$list.Add((New-CdtCheck -Id 'S-UTF8' -Category 'System' -Scope 'System' -Name 'UTF-8-Option fuer Nicht-Unicode (nicht beilaeufig geaendert)' -Expected 'unveraendert' -Actual ('ACP={0} OEMCP={1} UTF8={2}' -f $cp.ACP, $cp.OEMCP, $cp.Utf8Active) -Status $st -Note $note))
    if ($cp.Utf8Active -and $sys.SystemLocale -ne $lang -and $Cdt.Config.Utf8ConflictPolicy -eq 'Block') {
        [void]$list.Add((New-CdtCheck -Id 'S-UTF8CONFLICT' -Category 'System' -Scope 'System' -Name 'Konflikt UTF-8-Option / Systemgebietsschema' -Expected 'Entscheidung' -Actual 'UTF-8 aktiv, Systemgebietsschema abweichend' -Status 'Fail' -Note 'Utf8ConflictPolicy=Block: Entscheidung erforderlich'))
    }
    $st = 'Fail'; if ($sys.TimeZoneId -eq $Cdt.Config.TimeZoneId) { $st = 'Pass' } elseif ($null -eq $sys.TimeZoneId) { $st = 'NotVerifiable' }
    [void]$list.Add((New-CdtCheck -Id 'S-TZ' -Category 'System' -Scope 'Host' -Name 'Host-Zeitzone' -Expected $Cdt.Config.TimeZoneId -Actual $sys.TimeZoneId -Status $st))
    $st = 'Fail'; if ([int]$sys.DynamicDaylightTimeDisabled -eq 0) { $st = 'Pass' }
    [void]$list.Add((New-CdtCheck -Id 'S-TZ-DST' -Category 'System' -Scope 'Host' -Name 'Automatische Sommerzeitumstellung' -Expected 'aktiv (DynamicDaylightTimeDisabled=0)' -Actual $sys.DynamicDaylightTimeDisabled -Status $st))
    if ($Cdt.Config.SetBlockCleanupPolicy) {
        $pv = $sys.BlockCleanupPolicy
        if ($null -ne $pv -and [int]$pv -eq 1) { [void]$list.Add((New-CdtCheck -Id 'S-CLEANUP' -Category 'System' -Scope 'Policy' -Name 'BlockCleanupOfUnusedPreinstalledLangPacks' -Expected 1 -Actual $pv -Status 'Pass')) }
        elseif ($null -ne $pv) { [void]$list.Add((New-CdtCheck -Id 'S-CLEANUP-CONFLICT' -Category 'System' -Scope 'Policy' -Name 'BlockCleanupOfUnusedPreinstalledLangPacks' -Expected 1 -Actual $pv -Status 'Warn' -Blocking $false -Note 'explizit anders gesetzt (GPO/MDM?) - nicht uebersteuert; LPRemove kann ungenutzte Sprachpakete entfernen')) }
        else { [void]$list.Add((New-CdtCheck -Id 'S-CLEANUP' -Category 'System' -Scope 'Policy' -Name 'BlockCleanupOfUnusedPreinstalledLangPacks' -Expected 1 -Actual '(nicht gesetzt)' -Status 'Fail')) }
    }
    $tzr = $sys.TimeZoneRedirectionPolicy
    $tzrText = 'Richtlinie nicht gesetzt'
    if ($null -ne $tzr) { $tzrText = ('fEnableTimeZoneRedirection={0}' -f $tzr) }
    [void]$list.Add((New-CdtCheck -Id 'S-TZREDIRECT' -Category 'System' -Scope 'RDP' -Name 'Zeitzonenumleitung (nur erfasst, nicht geaendert)' -Expected '(offene Entscheidung)' -Actual $tzrText -Status 'Info' -Blocking $false -Note 'Bei aktiver Umleitung zeigt die Sitzung die Client-Zeitzone statt der Host-Zeitzone'))
    # --- Quellkonto (Ausfuehrungsidentitaet) ---
    $srcScope = 'Quellkonto ' + $Cdt.Context.Identity
    Add-CdtHiveChecks -List $list -Prefix 'SRC' -Scope $srcScope -Hive $Snapshot.Source -Blocking $true -Source
    $sc = $Snapshot.SourceCmdlets
    $desired = @($lang) + @($Cdt.Config.AdditionalUserLanguages | Where-Object { $_ -and $_ -ne $lang })
    $st = 'NotVerifiable'; if ($null -ne $sc.LanguageTags) { if ((@($sc.LanguageTags) -join ',') -eq ($desired -join ',')) { $st = 'Pass' } else { $st = 'Fail' } }
    [void]$list.Add((New-CdtCheck -Id 'SRC-CMD-LANGLIST' -Category 'Profile' -Scope $srcScope -Name 'Sprachliste (Get-WinUserLanguageList)' -Expected ($desired -join ',') -Actual (@($sc.LanguageTags) -join ',') -Status $st))
    $st = 'Fail'; if ([string]$sc.UiLanguageOverride -eq $lang) { $st = 'Pass' }
    [void]$list.Add((New-CdtCheck -Id 'SRC-CMD-UIOVERRIDE' -Category 'Profile' -Scope $srcScope -Name 'Anzeigesprache-Override' -Expected $lang -Actual $sc.UiLanguageOverride -Status $st))
    $st = 'Fail'; if ([string]$sc.InputMethodOverride -eq $Cdt.Config.InputMethodTip) { $st = 'Pass' }
    [void]$list.Add((New-CdtCheck -Id 'SRC-CMD-INPUTOVERRIDE' -Category 'Profile' -Scope $srcScope -Name 'Standard-Eingabemethode-Override' -Expected $Cdt.Config.InputMethodTip -Actual $sc.InputMethodOverride -Status $st -Blocking $false))
    # --- Ziele ---
    Add-CdtHiveChecks -List $list -Prefix 'W' -Scope 'Willkommensbildschirm/SYSTEM (HKU\.DEFAULT)' -Hive $Snapshot.Welcome -Blocking $true
    if ($null -ne $Snapshot.LocalService) { Add-CdtHiveChecks -List $list -Prefix 'LS' -Scope 'LocalService (S-1-5-19)' -Hive $Snapshot.LocalService -Blocking $false }
    if ($null -ne $Snapshot.NetworkService) { Add-CdtHiveChecks -List $list -Prefix 'NS' -Scope 'NetworkService (S-1-5-20)' -Hive $Snapshot.NetworkService -Blocking $false }
    Add-CdtHiveChecks -List $list -Prefix 'NU' -Scope 'Neue Benutzer (Default-Profil)' -Hive $Snapshot.NewUser -Blocking $true
    if (Test-CdtChangedThisBoot -Item 'CopyToSystem') {
        [void]$list.Add((New-CdtCheck -Id 'W-EFFECTIVE' -Category 'Profile' -Scope 'Willkommensbildschirm/Systemkonten' -Name 'Uebernahme wirksam nach Neustart (Herstellerangabe)' -Expected 'Neustart seit Uebernahme' -Actual 'Uebernahme in diesem Boot' -Status 'PendingReboot'))
    }
    if ($Cdt.HiveUnloadFailed) { [void]$list.Add((New-CdtCheck -Id 'X-HIVE-UNLOAD' -Category 'Cleanup' -Scope 'System' -Name 'Vorlage-Hive entladen' -Expected 'entladen' -Actual 'weiterhin geladen' -Status 'PendingReboot')) }
    # --- Erweiterte Pruefungen (nur fuer die Endbewertung) ---
    if ($IncludeExtended) {
        $risk = Get-CdtSysprepAppxRisk
        if ($Cdt.Config.SysprepAppxCheck -ne 'Off') {
            $blockLang = ($Cdt.Config.SysprepAppxCheck -eq 'Enforce')
            if (-not $risk.Checked) { [void]$list.Add((New-CdtCheck -Id 'X-SYSPREP-LANG' -Category 'Sysprep' -Scope 'Appx' -Name 'Sprachbezogene Appx nur benutzerbezogen installiert' -Expected 'keine' -Actual $risk.Error -Status 'NotVerifiable' -Blocking $blockLang)) }
            else {
                $st = 'Pass'; if (@($risk.LanguageRelated).Count -gt 0) { $st = 'Fail' }
                [void]$list.Add((New-CdtCheck -Id 'X-SYSPREP-LANG' -Category 'Sysprep' -Scope 'Appx' -Name 'Sprachbezogene Appx nur benutzerbezogen installiert (Sysprep 0x80073CF2)' -Expected 'keine' -Actual (@($risk.LanguageRelated) -join ', ') -Status $st -Blocking $blockLang -Note 'Behebung: Paket fuer den Benutzer und ggf. Provisionierung entfernen (MS Support "Sysprep fails with Microsoft Store apps")'))
                $st = 'Pass'; if (@($risk.Other).Count -gt 0) { $st = 'Warn' }
                [void]$list.Add((New-CdtCheck -Id 'X-SYSPREP-OTHER' -Category 'Sysprep' -Scope 'Appx' -Name 'Weitere nur benutzerbezogen installierte Appx' -Expected 'keine' -Actual ('{0}: {1}' -f @($risk.Other).Count, ((@($risk.Other) | Select-Object -First 8) -join ', ')) -Status $st -Blocking $false -Note 'Hinweis fuer die Sysprep-Vorbereitung der Orchestrierung'))
            }
        }
        if ($Cdt.Config.LanguageResourceCheck -ne 'Off') {
            $res = Get-CdtLanguageResourceState
            $Cdt.LanguageResources = $res
            $blockRes = ($Cdt.Config.LanguageResourceCheck -eq 'Enforce')
            switch ($res.State) { 'Current' { $st = 'Pass' } 'NotApplicable' { $st = 'Pass' } 'MinorDeviation' { $st = 'Warn' } 'Behind' { $st = 'Fail' } default { $st = 'NotVerifiable' } }
            if ($lp.State -ne 'Installed') { $st = 'Skipped' }
            [void]$list.Add((New-CdtCheck -Id 'X-LANGRES' -Category 'Servicing' -Scope 'System' -Name 'Sprachressourcen auf Stand des kumulativen Updates (Heuristik MUI-Versionen)' -Expected 'aktuell' -Actual ('{0}: {1}/{2} Dateien aelter als {3}' -f $res.State, $res.Behind, $res.Compared, $res.ReferenceLanguage) -Status $st -Blocking $blockRes -Note 'Bei Abweichung: aktuelles LCU erneut installieren (Windows Update bietet ein installiertes LCU nicht erneut an)'))
        }
        foreach ($t in @($Cdt.State.temporary.tasksDisabled)) {
            if ($null -ne $t) { [void]$list.Add((New-CdtCheck -Id 'X-TASKS' -Category 'Cleanup' -Scope 'Tasks' -Name 'Pausierte Wartungsaufgaben wiederhergestellt' -Expected 'aktiv' -Actual ('{0}{1} deaktiviert' -f $t.taskPath, $t.taskName) -Status 'Fail' -Blocking $true)) }
        }
        foreach ($m in @($Cdt.State.temporary.isoMounts)) {
            if ($null -ne $m) { [void]$list.Add((New-CdtCheck -Id 'X-MOUNTS' -Category 'Cleanup' -Scope 'ISO' -Name 'Eigene ISO-Einbindungen entfernt' -Expected 'keine' -Actual $m.imagePath -Status 'Fail' -Blocking $true)) }
        }
    }
    $checks = @($list.ToArray())
    $outcome = Get-CdtOutcome -Checks $checks
    $counts = [ordered]@{}
    foreach ($s in @('Pass', 'Fail', 'Warn', 'PendingReboot', 'NotVerifiable', 'Info', 'Skipped')) { $counts[$s] = @($checks | Where-Object { $_.Status -eq $s }).Count }
    return [ordered]@{ Stage = $Stage; Outcome = $outcome; Counts = $counts; Checks = $checks; SnapshotErrors = @($Snapshot.Errors); ComponentErrors = @($Components.Errors) }
}

function Get-CdtOutcome {
    param([object[]]$Checks)
    $blockingFail = @($Checks | Where-Object { $_.Blocking -and $_.Status -eq 'Fail' })
    $blockingNv = @($Checks | Where-Object { $_.Blocking -and $_.Status -eq 'NotVerifiable' })
    $pending = @($Checks | Where-Object { $_.Status -eq 'PendingReboot' })
    if ($blockingFail.Count -gt 0) { return 'FAILED' }
    if ($blockingNv.Count -gt 0) { return 'NOT_VERIFIABLE' }
    if ($pending.Count -gt 0) { return 'REBOOT_REQUIRED' }
    return 'SUCCESS'
}

function Test-CdtVerificationRun {
    # Nachpruefungslauf = ein frueherer Lauf hat REBOOT_REQUIRED gemeldet UND seitdem wurde neu gestartet
    param([AllowNull()][object]$PendingVerification, [AllowNull()][string]$CurrentBootUtc)
    if ($null -eq $PendingVerification) { return $false }
    $bt = ConvertTo-CdtUtcKey -Value $PendingVerification.bootTimeUtc
    $cur = ConvertTo-CdtUtcKey -Value $CurrentBootUtc
    if ([string]::IsNullOrEmpty($bt) -or [string]::IsNullOrEmpty($cur)) { return $false }
    return ($bt -ne $cur)
}

function Get-CdtExitCode {
    param([string]$Status, [string]$Mode, [bool]$IsVerificationRun, [int]$RebootRequiredCode = 0)
    switch ($Status) {
        'SUCCESS' { return 0 }
        'REBOOT_REQUIRED' {
            if ($Mode -eq 'Verify') { return 3 }
            if ($Mode -eq 'Auto' -and $IsVerificationRun) { return 3 }
            return $RebootRequiredCode
        }
        'FAILED' { return 1 }
        'NOT_VERIFIABLE' { return 2 }
        'LOCKED' { return 4 }
        'UNSUPPORTED' { return 5 }
        'LOGGING_UNAVAILABLE' { return 6 }
        'INTERNAL_ERROR' { return 9 }
        'AUDIT_COMPLIANT' { return 0 }
        'AUDIT_ACTION_REQUIRED' { return 0 }
        'AUDIT_REBOOT_PENDING' { return 0 }
        'AUDIT_PREREQUISITES_FAILED' { return 1 }
        default { return 9 }
    }
}

function Get-CdtLanguageResourceState {
    # Heuristik: de-DE-MUI-Dateien aelter als die Referenzsprache (gleicher Build-Zweig) deuten auf
    # fehlende Sprachressourcen des kumulativen Updates hin (kein Herstellernachweis).
    $lang = $Cdt.Config.Language
    $r = [ordered]@{ State = 'Unknown'; Compared = 0; Behind = 0; Examples = @(); ReferenceLanguage = $null; Note = '' }
    if ([string]$Cdt.Platform.InstallLanguageTag -eq $lang) { $r.State = 'NotApplicable'; $r.Note = 'de-DE ist Installationssprache'; return $r }
    $ref = $Cdt.Platform.InstallLanguageTag
    if ([string]::IsNullOrEmpty($ref)) { $ref = 'en-US' }
    $r.ReferenceLanguage = $ref
    $sys32 = Join-Path $env:SystemRoot 'System32'
    $refDir = Join-Path $sys32 $ref
    $dir = Join-Path $sys32 $lang
    if (-not (Test-Path -LiteralPath $refDir) -or -not (Test-Path -LiteralPath $dir)) { $r.Note = 'Verzeichnisse nicht vorhanden'; return $r }
    $examples = New-Object System.Collections.ArrayList
    try {
        foreach ($f in @(Get-ChildItem -LiteralPath $refDir -Filter '*.mui' -File -ErrorAction Stop)) {
            $peer = Join-Path $dir $f.Name
            if (-not (Test-Path -LiteralPath $peer -PathType Leaf)) { continue }
            $a = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($f.FullName)
            $b = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($peer)
            if ($a.FileMajorPart -ne $b.FileMajorPart -or $a.FileBuildPart -ne $b.FileBuildPart) { continue }
            $r.Compared++
            if ($b.FilePrivatePart -lt $a.FilePrivatePart) {
                $r.Behind++
                if ($examples.Count -lt 8) { [void]$examples.Add(('{0}: {1}={2} {3}={4}' -f $f.Name, $lang, $b.FilePrivatePart, $ref, $a.FilePrivatePart)) }
            }
        }
    }
    catch { $r.Note = (Get-CdtErrorInfo -InputObject $_).Message; return $r }
    $r.Examples = @($examples)
    if ($r.Compared -eq 0) { $r.State = 'Unknown' }
    elseif ($r.Behind -eq 0) { $r.State = 'Current' }
    elseif ($r.Behind -ge 5 -and ($r.Behind / $r.Compared) -ge 0.02) { $r.State = 'Behind' }
    else { $r.State = 'MinorDeviation' }
    return $r
}

function Get-CdtSysprepAppxRisk {
    # Sysprep scheitert mit 0x80073CF2, wenn Appx nur fuer einen Benutzer installiert, aber nicht provisioniert sind
    $r = [ordered]@{ Checked = $false; LanguageRelated = @(); Other = @(); Error = $null }
    try {
        $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | ForEach-Object { [string]$_.DisplayName })
        $lang = New-Object System.Collections.ArrayList
        $other = New-Object System.Collections.ArrayList
        foreach ($p in @(Get-AppxPackage -AllUsers -ErrorAction Stop)) {
            if ($p.IsFramework -or [string]$p.SignatureKind -eq 'System' -or $p.NonRemovable) { continue }
            if ($prov -contains [string]$p.Name) { continue }
            $installed = @($p.PackageUserInformation | Where-Object { [string]$_.InstallState -eq 'Installed' })
            if ($installed.Count -eq 0) { continue }
            if ([string]$p.Name -like 'Microsoft.LanguageExperiencePack*') { [void]$lang.Add([string]$p.PackageFullName) }
            elseif ($other.Count -lt 50) { [void]$other.Add([string]$p.Name) }
        }
        $r.LanguageRelated = @($lang)
        $r.Other = @($other)
        $r.Checked = $true
    }
    catch { $r.Error = (Get-CdtErrorInfo -InputObject $_).Message }
    return $r
}

# =====================================================================================================
# BERICHTE: missing-network-requirements (TXT/CSV), Tageszusammenfassung, Konsole
# =====================================================================================================
function ConvertTo-CdtCsvLine {
    param([object[]]$Values)
    $cells = foreach ($v in $Values) { '"' + (([string]$v) -replace '[\r\n]+', ' ').Replace('"', '""') + '"' }
    return ($cells -join ';')
}

function ConvertTo-CdtRequirementRow {
    # Uebersetzt ein fehlgeschlagenes Pruefergebnis in Freigabeanforderungen aus Sicht der VM
    param([System.Collections.IDictionary]$Result)
    $dir = 'Ausgehend (VM -> Ziel); Antwortverkehr ueber dieselbe Verbindung, keine eingehende Regel erforderlich'
    $ips = ''
    if ($null -ne $Result.Dns) { $ips = ('{0} @ {1}' -f (@($Result.Dns.Addresses) -join ','), $Result.Dns.TimestampUtc) }
    $rows = New-Object System.Collections.ArrayList
    $base = [ordered]@{ Url = $Result.Requirement; Protocol = ('{0} (TCP)' -f $Result.Protocol); Ports = [string]$Result.Port; Direction = $dir; Purpose = $Result.Purpose
        Checked = $Result.Url; Via = $Result.ConnectTarget; Ips = $ips; Status = 'FEHLGESCHLAGEN'; Category = $Result.Category; Code = [string]$Result.Code
        Action = $Result.Recommendation; Reference = $Result.Reference; RunId = $Cdt.RunId; Time = $Result.TimestampUtc }
    switch ($Result.Category) {
        'DnsFailure' {
            $row = [ordered]@{}; foreach ($k in $base.Keys) { $row[$k] = $base[$k] }
            $row.Url = Get-CdtDnsServerList; $row.Protocol = 'DNS (UDP/TCP)'; $row.Ports = '53'; $row.Purpose = ('Namensaufloesung fuer {0}' -f $Result.Host); $row.Via = $row.Url
            [void]$rows.Add($row)
        }
        { @('ProxyDnsFailure', 'ProxyConnectFailure', 'ProxyDenied') -contains $_ } {
            $row = [ordered]@{}; foreach ($k in $base.Keys) { $row[$k] = $base[$k] }
            $row.Url = $Result.Proxy; $row.Protocol = 'HTTP-Proxy (TCP)'; $row.Ports = ([string]$Result.Proxy -replace '^.*:', ''); $row.Purpose = ('Proxy fuer {0} ({1})' -f $Result.Host, $Result.ProxySource)
            [void]$rows.Add($row)
            if ($Result.Category -eq 'ProxyDenied') { [void]$rows.Add($base) }
        }
        default { [void]$rows.Add($base) }
    }
    return , ($rows.ToArray())
}

function Write-CdtNetworkRequirementFiles {
    $current = @($Cdt.Network.Results)
    $origin = 'Dieser Lauf'
    $results = $current
    if ($current.Count -eq 0 -and $null -ne $Cdt.State -and $null -ne $Cdt.State.network -and $null -ne $Cdt.State.network.lastCheck) {
        $results = @($Cdt.State.network.lastCheck.results)
        $origin = ('Letzte Pruefung: RunId {0} ({1})' -f $Cdt.State.network.lastCheck.runId, $Cdt.State.network.lastCheck.timeUtc)
    }
    $header = @('URL/IP', 'Protokoll', 'Port/s', 'Richtung', 'Zweck', 'Gepruefte URL', 'Verbindungsziel (Proxy)', 'Aufgeloeste IPs (Diagnose, Zeitstempel UTC)', 'Pruefstatus', 'Fehlerkategorie', 'Fehlercode', 'Empfohlene Massnahme', 'Quelle der Anforderung', 'RunId', 'Zeitpunkt (UTC)')
    $rows = New-Object System.Collections.ArrayList
    $notes = New-Object System.Collections.ArrayList
    foreach ($res in $results) {
        if ($null -eq $res) { continue }
        if ($res.Status -eq 'Fail' -and $res.Required) { foreach ($row in (ConvertTo-CdtRequirementRow -Result $res)) { [void]$rows.Add($row) } }
        elseif (@('Fail', 'NotVerifiable', 'Warn') -contains $res.Status) { [void]$notes.Add(('{0} {1}:{2} -> {3} {4}: {5}' -f $res.Protocol, $res.Host, $res.Port, $res.Status, $res.Category, $res.Detail)) }
    }
    $now = Get-CdtUtcTimestamp
    $csv = New-Object System.Text.StringBuilder
    [void]$csv.AppendLine((ConvertTo-CdtCsvLine -Values $header))
    if ($rows.Count -gt 0) { foreach ($r in $rows) { [void]$csv.AppendLine((ConvertTo-CdtCsvLine -Values @($r.Url, $r.Protocol, $r.Ports, $r.Direction, $r.Purpose, $r.Checked, $r.Via, $r.Ips, $r.Status, $r.Category, $r.Code, $r.Action, $r.Reference, $r.RunId, $r.Time))) } }
    elseif ($results.Count -gt 0) { [void]$csv.AppendLine((ConvertTo-CdtCsvLine -Values @('(keine)', '-', '-', '-', 'Statusmeldung', '-', '-', '-', 'KEINE_FEHLGESCHLAGENEN_ERFORDERLICHEN_VERBINDUNGEN', '-', '-', '-', $origin, $Cdt.RunId, $now))) }
    else { [void]$csv.AppendLine((ConvertTo-CdtCsvLine -Values @('(keine)', '-', '-', '-', 'Statusmeldung', '-', '-', '-', 'NICHT_GEPRUEFT', '-', '-', 'In diesem Lauf war keine Netzwerkpruefung erforderlich', '-', $Cdt.RunId, $now))) }
    $txt = New-Object System.Text.StringBuilder
    [void]$txt.AppendLine('CDT-STANDARD-INSTALL-DE_LANG - fehlende Netzwerkanforderungen')
    [void]$txt.AppendLine(('Stand: {0} UTC | RunId: {1} | VM: {2} | Kontext: {3}' -f $now, $Cdt.RunId, $Cdt.VmName, $Cdt.Context.Identity))
    [void]$txt.AppendLine(('Datenbasis: {0}' -f $origin))
    [void]$txt.AppendLine('Richtung aus Sicht der VM: ausgehend. Antwortverkehr laeuft ueber dieselbe Verbindung; keine eingehende Freigabe noetig.')
    [void]$txt.AppendLine('Freigaben auf DNS-Namen beziehen (Microsoft-CDN-IP-Adressen sind dynamisch; IPs nur als Diagnose).')
    [void]$txt.AppendLine('Ein fehlgeschlagener Zugriff ist nur dann ein Firewall-Befund, wenn die Kategorie das belegt (z. B. TCP-Timeout); DNS-, Proxy- und TLS-Befunde sind gesondert ausgewiesen.')
    [void]$txt.AppendLine('')
    if ($rows.Count -gt 0) {
        [void]$txt.AppendLine(('FEHLGESCHLAGENE ERFORDERLICHE VERBINDUNGEN: {0}' -f $rows.Count))
        foreach ($r in $rows) {
            [void]$txt.AppendLine(('- {0} | {1} | Port {2} | {3}' -f $r.Url, $r.Protocol, $r.Ports, $r.Purpose))
            [void]$txt.AppendLine(('  Geprueft: {0} | Verbindungsziel: {1} | Kategorie: {2} {3}' -f $r.Checked, $r.Via, $r.Category, $r.Code))
            [void]$txt.AppendLine(('  IPs (Diagnose): {0}' -f $r.Ips))
            [void]$txt.AppendLine(('  Massnahme: {0}' -f $r.Action))
        }
    }
    elseif ($results.Count -gt 0) { [void]$txt.AppendLine('Derzeit wurden KEINE fehlgeschlagenen erforderlichen Netzwerkverbindungen festgestellt.') }
    else { [void]$txt.AppendLine('In diesem Lauf war keine Netzwerkpruefung erforderlich; es liegen keine aktuellen Befunde vor. Historische Befunde: Tageslogs.') }
    if ($notes.Count -gt 0) {
        [void]$txt.AppendLine('')
        [void]$txt.AppendLine('HINWEISE (nicht als Pflichtverbindung eingestuft oder nicht zuverlaessig pruefbar):')
        foreach ($n in $notes) { [void]$txt.AppendLine('- ' + $n) }
    }
    [void]$txt.AppendLine('')
    [void]$txt.AppendLine('Nicht konkret geprueft (Wildcard ohne dokumentierten Hostnamen):')
    foreach ($u in $CdtUntestedRequirements) { [void]$txt.AppendLine(('- {0} ({1} {2}) - {3}' -f $u.Requirement, $u.Protocol, $u.Port, $u.Purpose)) }
    [void]$txt.AppendLine('Tatsaechlicher Windows-Update-Zugriff ist nur durch den Installationsversuch nachweisbar (siehe Log, Phase Install).')
    Set-CdtFileContentAtomic -Path $Cdt.Log.MissingCsv -Text $csv.ToString() -Utf8Bom $true
    Set-CdtFileContentAtomic -Path $Cdt.Log.MissingTxt -Text $txt.ToString() -Utf8Bom $true
    if ($current.Count -gt 0 -and $null -ne $Cdt.State) {
        $compact = @($current | ForEach-Object {
                [ordered]@{ Id = $_.Id; Path = $_.Path; Host = $_.Host; Port = $_.Port; Protocol = $_.Protocol; Url = $_.Url; Required = $_.Required; Requirement = $_.Requirement; Purpose = $_.Purpose
                    Reference = $_.Reference; ProxyMode = $_.ProxyMode; Proxy = $_.Proxy; ProxySource = $_.ProxySource; ConnectTarget = $_.ConnectTarget; Dns = $_.Dns; Status = $_.Status
                    Category = $_.Category; Code = $_.Code; Detail = $_.Detail; Recommendation = $_.Recommendation; TimestampUtc = $_.TimestampUtc } })
        $Cdt.State.network.lastCheck = [ordered]@{ runId = $Cdt.RunId; timeUtc = $now; results = $compact }
    }
}

function New-CdtRunSummary {
    $statusText = @{
        'SUCCESS'                    = 'Vollstaendig erfolgreich - alle erforderlichen Pruefungen bestanden.'
        'REBOOT_REQUIRED'            = 'Aenderungen durchgefuehrt bzw. Neustart ausstehend - Neustart und Nachpruefung erforderlich.'
        'FAILED'                     = 'Installation oder Konfiguration unvollstaendig bzw. fehlgeschlagen.'
        'NOT_VERIFIABLE'             = 'Pruefung nicht zuverlaessig moeglich.'
        'LOCKED'                     = 'Andere Instanz laeuft - keine Aktion.'
        'UNSUPPORTED'                = 'Voraussetzungen/Plattform nicht erfuellt - keine Aenderung.'
        'INTERNAL_ERROR'             = 'Unerwarteter Scriptfehler.'
        'AUDIT_COMPLIANT'            = 'Audit: Zielzustand vollstaendig erreicht.'
        'AUDIT_ACTION_REQUIRED'      = 'Audit: Apply erforderlich, Voraussetzungen erfuellt.'
        'AUDIT_REBOOT_PENDING'       = 'Audit: Neustart ausstehend.'
        'AUDIT_PREREQUISITES_FAILED' = 'Audit: Apply wuerde voraussichtlich scheitern (Quelle/Netzwerk/Konflikt).'
    }
    $next = switch ($Cdt.Status) {
        'SUCCESS' { 'Freigabe fuer Sysprep/Capture durch die Orchestrierung moeglich.' }
        'REBOOT_REQUIRED' { 'VM neu starten (Orchestrierung) und Script erneut ausfuehren (Nachpruefung). KEIN Sysprep/Capture.' }
        'LOCKED' { 'Ende der laufenden Instanz abwarten und erneut ausfuehren.' }
        'AUDIT_ACTION_REQUIRED' { 'Apply/Auto ausfuehren.' }
        'AUDIT_REBOOT_PENDING' { 'Neustart durchfuehren, dann Auto/Verify.' }
        default { 'Ursache laut Log beheben; Sysprep/Capture stoppen.' }
    }
    $checks = @()
    $counts = $null
    if ($null -ne $Cdt.FinalCompliance) { $checks = @($Cdt.FinalCompliance.Checks); $counts = $Cdt.FinalCompliance.Counts }
    $failedChecks = @($checks | Where-Object { @('Fail', 'NotVerifiable', 'PendingReboot') -contains $_.Status } | ForEach-Object { '{0}={1} (Soll {2}, Ist {3})' -f $_.Id, $_.Status, $_.Expected, $_.Actual })
    $warnChecks = @($checks | Where-Object { $_.Status -eq 'Warn' } | ForEach-Object { '{0}: {1}' -f $_.Id, $_.Note })
    $net = @($Cdt.Network.Results | ForEach-Object { [ordered]@{ id = $_.Id; host = $_.Host; port = $_.Port; via = $_.ConnectTarget; status = $_.Status; category = $_.Category; code = $_.Code } })
    $endedAt = [DateTimeOffset]::Now
    return [ordered]@{
        runId              = $Cdt.RunId
        scriptVersion      = $CdtScriptVersion
        logSchemaVersion   = $CdtLogSchemaVersion
        mode               = $(if ($null -ne $Cdt.Config) { $Cdt.Config.Mode } else { $null })
        effectiveMode      = $Cdt.EffectiveMode
        startedAt          = (Get-CdtTimestamp -Value $Cdt.StartTime)
        endedAt            = (Get-CdtTimestamp -Value $endedAt)
        durationSeconds    = [Math]::Round($Cdt.Stopwatch.Elapsed.TotalSeconds, 1)
        status             = $Cdt.Status
        statusText         = $statusText[[string]$Cdt.Status]
        statusReason       = $Cdt.StatusReason
        exitCode           = $Cdt.ExitCode
        captureAllowed     = $Cdt.CaptureAllowed
        rebootRequired     = ($Cdt.Status -eq 'REBOOT_REQUIRED')
        verificationRun    = [bool]$Cdt.IsVerificationRun
        nextStep           = $next
        vm                 = [ordered]@{ name = $Cdt.VmName; source = $Cdt.VmNameSource; computerName = $env:COMPUTERNAME }
        os                 = $Cdt.OsSummary
        platform           = $(if ($null -ne $Cdt.Platform) { [ordered]@{ caption = $Cdt.Platform.Caption; editionId = $Cdt.Platform.EditionId; sku = $Cdt.Platform.Sku; editionClass = $Cdt.Platform.EditionClass; release = $Cdt.Platform.ReleaseInfo; installLanguage = $Cdt.Platform.InstallLanguageTag } } else { $null })
        context            = $Cdt.Context
        components         = [ordered]@{ before = $Cdt.ComponentsBefore; after = $Cdt.ComponentsAfter }
        install            = $Cdt.Install
        configuration      = $Cdt.Configuration
        checkCounts        = $counts
        openChecks         = $failedChecks
        warnings           = @($Cdt.Warnings) + $warnChecks
        errors             = @($Cdt.Errors)
        network            = [ordered]@{ performed = [bool]$Cdt.Network.Performed; results = $net; missingRequirementsCsv = $Cdt.Log.MissingCsv }
        languageResources  = $Cdt.LanguageResources
        checks             = $checks
        files              = [ordered]@{ log = $Cdt.Log.Text; jsonl = $Cdt.Log.Jsonl; summary = $Cdt.Log.Summary; state = $Cdt.StatePath }
    }
}

function Write-CdtDailySummary {
    param([System.Collections.IDictionary]$RunSummary)
    $path = $Cdt.Log.Summary
    $m = $null
    try {
        $created = $false
        $m = New-Object System.Threading.Mutex($false, 'Global\CDT-STANDARD-INSTALL-DE_LANG-SUMMARY', [ref]$created)
        try { [void]$m.WaitOne([TimeSpan]::FromSeconds(30)) } catch [System.Threading.AbandonedMutexException] { Write-Verbose 'Verwaister Summary-Mutex uebernommen.' }
        $doc = $null
        if (Test-Path -LiteralPath $path) {
            try { $doc = ConvertTo-CdtHashtable -InputObject ([System.IO.File]::ReadAllText($path) | ConvertFrom-Json) }
            catch {
                $bad = '{0}.corrupt-{1}' -f $path, (Get-Date -Format 'yyyyMMddHHmmss')
                Move-Item -LiteralPath $path -Destination $bad -Force
                Write-CdtLog -Level WARN -Phase 'Report' -Action 'Summary' -Message ('Bestehende Zusammenfassung unlesbar, gesichert als {0}' -f $bad)
                $doc = $null
            }
        }
        if ($null -eq $doc -or -not $doc.Contains('runs')) {
            $doc = [ordered]@{ schema = 'cdt.delang.summary'; schemaVersion = $CdtLogSchemaVersion; product = $CdtProductName; vmName = $Cdt.VmName; vmNameSource = $Cdt.VmNameSource; date = $Cdt.StartTime.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture); latest = $null; runs = @() }
        }
        $doc.runs = @($doc.runs) + @($RunSummary)
        $doc.latest = [ordered]@{ runId = $RunSummary.runId; status = $RunSummary.status; exitCode = $RunSummary.exitCode; captureAllowed = $RunSummary.captureAllowed; mode = $RunSummary.mode; effectiveMode = $RunSummary.effectiveMode; endedAt = $RunSummary.endedAt; nextStep = $RunSummary.nextStep }
        $doc.updatedAt = Get-CdtTimestamp
        Set-CdtFileContentAtomic -Path $path -Text (ConvertTo-CdtJson -InputObject $doc -Pretty) -Utf8Bom $false
    }
    catch { Write-CdtLog -Level ERROR -Phase 'Report' -Action 'Summary' -Message 'Zusammenfassung konnte nicht geschrieben werden' -ErrorMessage (Get-CdtErrorInfo -InputObject $_).Message }
    finally {
        if ($null -ne $m) { try { $m.ReleaseMutex() } catch { Write-Verbose 'Mutex nicht gehalten.' }; $m.Dispose() }
    }
}

function Write-CdtConsoleSummary {
    param([System.Collections.IDictionary]$RunSummary)
    Write-Host '==================== CDT-STANDARD-INSTALL-DE_LANG ERGEBNIS ===================='
    Write-Host ('STATUS={0}  EXIT={1}  CAPTURE_ALLOWED={2}  MODUS={3}/{4}' -f $RunSummary.status, $RunSummary.exitCode, $RunSummary.captureAllowed, $RunSummary.mode, $RunSummary.effectiveMode)
    Write-Host ('Bedeutung: {0}' -f $RunSummary.statusText)
    if ($RunSummary.statusReason) { Write-Host ('Grund: {0}' -f (Protect-CdtText -Text $RunSummary.statusReason)) }
    Write-Host ('Naechster Schritt: {0}' -f $RunSummary.nextStep)
    if ($null -ne $Cdt.ComponentsAfter) { Write-Host ('Komponenten: {0}' -f (Get-CdtComponentSummaryText -State $Cdt.ComponentsAfter)) }
    elseif ($null -ne $Cdt.ComponentsBefore) { Write-Host ('Komponenten: {0}' -f (Get-CdtComponentSummaryText -State $Cdt.ComponentsBefore)) }
    if ($null -ne $RunSummary.checkCounts) { Write-Host ('Pruefungen: OK={0} Fehler={1} Neustart={2} NichtPruefbar={3} Warnung={4}' -f $RunSummary.checkCounts.Pass, $RunSummary.checkCounts.Fail, $RunSummary.checkCounts.PendingReboot, $RunSummary.checkCounts.NotVerifiable, $RunSummary.checkCounts.Warn) }
    foreach ($o in @($RunSummary.openChecks | Select-Object -First 6)) { Write-Host ('  offen: {0}' -f (Protect-CdtText -Text $o)) }
    if ($null -ne $Cdt.Network -and $Cdt.Network.Performed) {
        $failed = @($Cdt.Network.Results | Where-Object { $_.Status -eq 'Fail' -and $_.Required })
        Write-Host ('Netzwerk: {0} Pruefungen, {1} erforderliche fehlgeschlagen -> {2}' -f @($Cdt.Network.Results).Count, $failed.Count, $Cdt.Log.MissingCsv)
    }
    Write-Host ('Logs: {0} (RunId {1})' -f $Cdt.Log.Text, $RunSummary.runId)
    $line = ConvertTo-CdtJson -InputObject ([ordered]@{ product = $CdtProductName; version = $CdtScriptVersion; runId = $RunSummary.runId; mode = $RunSummary.mode; status = $RunSummary.status; exitCode = $RunSummary.exitCode; captureAllowed = $RunSummary.captureAllowed; verificationRun = $RunSummary.verificationRun; vm = $Cdt.VmName })
    Write-Host ('CDT_RESULT {0}' -f $line)
}

# =====================================================================================================
# AUFRAEUMEN (nur eigene Ressourcen) UND WIEDERHERSTELLUNG NACH ABBRUCH
# =====================================================================================================
function Restore-CdtPreviousRunArtifact {
    $tasks = @(@($Cdt.State.temporary.tasksDisabled) | Where-Object { $null -ne $_ -and $_.runId -ne $Cdt.RunId })
    if ($tasks.Count -gt 0) {
        Write-CdtLog -Level WARN -Phase 'Recovery' -Action 'Tasks' -Message ('{0} von einem abgebrochenen Lauf pausierte Task(s) werden reaktiviert' -f $tasks.Count) -Console
        Resume-CdtLanguageComponentTask
    }
    foreach ($m in @(@($Cdt.State.temporary.isoMounts) | Where-Object { $null -ne $_ -and $_.runId -ne $Cdt.RunId })) {
        Write-CdtLog -Level WARN -Phase 'Recovery' -Action 'IsoMount' -Message ('ISO-Einbindung eines abgebrochenen Laufs ({0}) wird entfernt' -f $m.runId)
        [void](Dismount-CdtIso -ImagePath $m.imagePath -FolderMount $m.folderMount)
    }
}

function Remove-CdtOwnArtifact {
    if ($null -eq $Cdt.State) { return }
    if (@($Cdt.State.temporary.tasksDisabled).Count -gt 0) { Resume-CdtLanguageComponentTask }
    foreach ($m in @(@($Cdt.State.temporary.isoMounts) | Where-Object { $null -ne $_ })) { [void](Dismount-CdtIso -ImagePath $m.imagePath -FolderMount $m.folderMount) }
    $work = $Cdt.Log.WorkDir
    if (-not (Test-Path -LiteralPath $work)) { return }
    Get-ChildItem -LiteralPath $work -Filter 'intl-*.xml' -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    if ($Cdt.Status -eq 'SUCCESS' -and -not $Cdt.Config.KeepDownloadedIso) {
        foreach ($mk in @(Get-ChildItem -LiteralPath $work -Filter '*.cdt-download.json' -File -ErrorAction SilentlyContinue)) {
            $iso = $mk.FullName.Substring(0, $mk.FullName.Length - '.cdt-download.json'.Length)
            foreach ($p in @($iso, $mk.FullName, ($iso + '.partial'))) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue } }
            Write-CdtLog -Phase 'Cleanup' -Action 'DeleteIso' -Message ('Eigener ISO-Download entfernt: {0}' -f (Split-Path -Leaf $iso))
        }
        foreach ($pf in @(Get-ChildItem -LiteralPath $work -Filter '*.partial' -File -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $pf.FullName -Force -ErrorAction SilentlyContinue }
    }
    if (@(Get-ChildItem -LiteralPath $work -Force -ErrorAction SilentlyContinue).Count -eq 0) { Remove-Item -LiteralPath $work -Force -ErrorAction SilentlyContinue }
    else { Write-CdtLog -Phase 'Cleanup' -Action 'WorkDir' -Message ('Arbeitsverzeichnis enthaelt noch Dateien fuer einen Folgelauf: {0}' -f $work) }
}

# =====================================================================================================
# HAUPTABLAUF
# =====================================================================================================
function Get-CdtImdsVmName {
    # Azure Instance Metadata Service (link-lokal, ohne Proxy, ohne Anmeldedaten)
    try {
        $req = [System.Net.HttpWebRequest][System.Net.WebRequest]::Create('http://169.254.169.254/metadata/instance/compute/name?api-version=2021-02-01&format=text')
        $req.Headers.Add('Metadata', 'true')
        $req.Proxy = $null
        $req.Timeout = 2000
        $req.ReadWriteTimeout = 2000
        $resp = $req.GetResponse()
        try { $name = (New-Object System.IO.StreamReader($resp.GetResponseStream())).ReadToEnd().Trim() } finally { $resp.Close() }
        if ($name -match '^[A-Za-z0-9][A-Za-z0-9_.\-]{0,79}$') { return $name }
    }
    catch { Write-Verbose 'IMDS nicht erreichbar (kein Azure oder blockiert).' }
    return $null
}

function Resolve-CdtVmName {
    $name = $null
    $source = $null
    if (-not [string]::IsNullOrWhiteSpace($Cdt.Config.VmName)) { $name = $Cdt.Config.VmName; $source = 'Konfiguration VmName' }
    if ($null -eq $name) {
        $nv = Get-Variable -Name 'AzureVMName' -ValueOnly -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace([string]$nv)) { $nv = $env:CDT_DELANG_NERDIO_AZUREVMNAME }
        if (-not [string]::IsNullOrWhiteSpace([string]$nv)) { $name = [string]$nv; $source = 'NERDIO-Variable $AzureVMName' }
    }
    if ($null -eq $name) { $imds = Get-CdtImdsVmName; if ($null -ne $imds) { $name = $imds; $source = 'Azure IMDS (compute.name)' } }
    if ($null -eq $name) { $name = $env:COMPUTERNAME; $source = 'Windows-Computername' }
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'UNKNOWN-VM'; $source = 'nicht ermittelbar' }
    $Cdt.VmName = ([regex]::Replace($name, '[^A-Za-z0-9_.\-]', '_')).Trim('.')
    if ($Cdt.VmName.Length -gt 64) { $Cdt.VmName = $Cdt.VmName.Substring(0, 64) }
    $Cdt.VmNameSource = $source
}

function Export-CdtPresetToEnvironment {
    # Vorbelegte Variablen (NERDIO/HYDRA/manuell) fuer einen Host-Neustart an den Kindprozess weitergeben
    foreach ($k in $CdtConfigSpec.Keys) {
        $v = Get-Variable -Name ('CdtDeLang' + $k) -ValueOnly -ErrorAction SilentlyContinue
        if ($null -ne $v) { [Environment]::SetEnvironmentVariable('CDT_DELANG_' + $k.ToUpperInvariant(), ((ConvertTo-CdtArray -InputObject $v) -join ',')) }
    }
    $preset = Get-Variable -Name 'CdtDeLangConfig' -ValueOnly -ErrorAction SilentlyContinue
    if ($preset -is [System.Collections.IDictionary]) { $env:CDT_DELANG_CONFIG_JSON = ConvertTo-Json -InputObject $preset -Compress -Depth 5 }
    $nv = Get-Variable -Name 'AzureVMName' -ValueOnly -ErrorAction SilentlyContinue
    if (-not [string]::IsNullOrWhiteSpace([string]$nv)) { $env:CDT_DELANG_NERDIO_AZUREVMNAME = [string]$nv }
}

function Invoke-CdtHostRelaunch {
    # Begrenzter Neustart in nativer 64-Bit-Windows-PowerShell 5.1; Argumente und Exitcode werden weitergereicht
    param([AllowNull()][object[]]$ScriptArgs)
    $reason = $null
    if ($PSVersionTable.PSEdition -eq 'Core') { $reason = ('PowerShell {0} (Core) statt Windows PowerShell 5.1' -f $PSVersionTable.PSVersion) }
    elseif ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) { $reason = '32-Bit-Prozess auf 64-Bit-Windows' }
    if ($null -eq $reason) { return $null }
    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { Write-Host '[DE-LANG] FEHLER: Script ist nur unter Windows ausfuehrbar.'; return 5 }
    if ($env:CDT_DELANG_RELAUNCHED -eq '1') { Write-Host ('[DE-LANG] FEHLER: Host weiterhin ungeeignet nach Neustart ({0}).' -f $reason); return 5 }
    if ([string]::IsNullOrEmpty($PSCommandPath)) { Write-Host ('[DE-LANG] FEHLER: {0}; kein Scriptpfad fuer Neustart verfuegbar.' -f $reason); return 5 }
    if ([Environment]::Is64BitProcess) { $exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
    else { $exe = Join-Path $env:SystemRoot 'Sysnative\WindowsPowerShell\v1.0\powershell.exe' }
    if (-not (Test-Path -LiteralPath $exe)) { Write-Host ('[DE-LANG] FEHLER: {0} nicht gefunden.' -f $exe); return 5 }
    Export-CdtPresetToEnvironment
    $env:CDT_DELANG_RELAUNCHED = '1'
    Write-Host ('[DE-LANG] Neustart in {0} (Grund: {1})' -f $exe, $reason)
    $argList = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath) + @(ConvertTo-CdtArray -InputObject $ScriptArgs | ForEach-Object { [string]$_ })
    & $exe @argList
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 9 }
    return [int]$code
}

function Invoke-CdtAudit {
    # Nur lesen: Zustand + Voraussetzungen fuer Apply (Quelle, Netzwerk, Konflikte). Keine ISO-Einbindung.
    param([System.Collections.IDictionary]$Compliance)
    $Cdt.FinalCompliance = $Compliance
    if ($Compliance.Outcome -eq 'SUCCESS') { $Cdt.Status = 'AUDIT_COMPLIANT'; return }
    $issues = New-Object System.Collections.ArrayList
    $sat = Test-CdtComponentsSatisfied -State $Cdt.ComponentsBefore
    if (-not $sat.Mandatory -or -not $sat.Optional) {
        $wuOk = $false
        if ($Cdt.Config.EnableWindowsUpdateSource) {
            if ($Cdt.UpdatePolicy.Decision -eq 'Blocked') { [void]$issues.Add('Windows Update durch Richtlinie/Dienst blockiert') }
            else {
                $net = Invoke-CdtNetworkCheck -PathName 'WindowsUpdate' -Targets $CdtWindowsUpdateTargets
                $wuOk = ($net.RequiredFailed -eq 0)
                if (-not $wuOk) { [void]$issues.Add(('{0} erforderliche Windows-Update-Endpunkte nicht erreichbar' -f $net.RequiredFailed)) }
            }
        }
        $fbOk = $false
        $rel = $Cdt.Platform.ReleaseInfo
        if ($Cdt.Config.EnableFallbackSource -and ($rel.FallbackApproved -or $Cdt.Config.AllowUnconfirmedFallbackSource)) {
            $needCaps = @($sat.MissingRequired) + @($sat.MissingOptional)
            foreach ($cand in (Find-CdtFallbackSource -SourceInfo $rel.Source)) {
                if ($cand.Kind -eq 'Iso') { if (Test-Path -LiteralPath $cand.Path -PathType Leaf) { $fbOk = $true; Write-CdtLog -Phase 'Audit' -Action 'Source' -Message ('Lokale ISO vorhanden (Inhalt wird erst bei Apply geprueft): {0}' -f $cand.Path) } }
                else {
                    $v = Test-CdtRepository -Path $cand.Path -NeedLanguagePack (-not $sat.LanguagePack) -Capabilities $needCaps -SkipApplicability
                    if ($v.Valid) { $fbOk = $true }
                    Write-CdtLog -Phase 'Audit' -Action 'Source' -Message ('Repository {0}: {1}' -f $cand.Path, $(if ($v.Valid) { 'geeignet' } else { 'ungeeignet' })) -Data $v
                }
            }
            if (-not $fbOk -and $Cdt.Config.DownloadIso -and $Cdt.Platform.Architecture -eq $rel.Source.Architecture) {
                $t = [ordered]@{ Id = 'ISO'; Url = $rel.Source.Url; Protocol = 'HTTPS'; Kind = 'ConcreteUrl'; Required = $true; Requirement = ([Uri]$rel.Source.Url).DnsSafeHost; Purpose = 'Fallback-Quelle LOF-ISO'; Reference = 'Release-Zuordnung ' + $rel.Source.Id }
                $n = Invoke-CdtNetworkCheck -PathName 'Download' -Targets @($t)
                $free = Get-CdtFreeSpaceBytes -Path $Cdt.Config.LogRoot
                $fbOk = (@('Pass', 'Warn') -contains $n.Results[0].Status -and ($null -eq $free -or $free -gt 9GB))
                if (-not $fbOk) { [void]$issues.Add('Fallback-Download nicht moeglich (Netzwerk oder Speicherplatz)') }
            }
        }
        elseif ($Cdt.Config.EnableFallbackSource) { [void]$issues.Add(('Kein freigegebener Fallback fuer {0}' -f $rel.Release)) }
        if (-not $wuOk -and -not $fbOk) {
            $Cdt.Status = 'AUDIT_PREREQUISITES_FAILED'
            $Cdt.StatusReason = ($issues -join '; ')
            return
        }
    }
    $conflict = @($Compliance.Checks | Where-Object { $_.Id -eq 'S-UTF8CONFLICT' })
    if ($conflict.Count -gt 0) { $Cdt.Status = 'AUDIT_PREREQUISITES_FAILED'; $Cdt.StatusReason = 'UTF-8-Konflikt erfordert Entscheidung'; return }
    $onlyPending = (@($Compliance.Checks | Where-Object { $_.Blocking -and @('Fail', 'NotVerifiable') -contains $_.Status }).Count -eq 0)
    if ($onlyPending) { $Cdt.Status = 'AUDIT_REBOOT_PENDING' } else { $Cdt.Status = 'AUDIT_ACTION_REQUIRED' }
    $Cdt.StatusReason = ($issues -join '; ')
}

function Invoke-CdtApplyPhase {
    $Cdt.EffectiveMode = 'Apply'
    $inst = Invoke-CdtInstallation
    $Cdt.Install = $inst
    $sat = Test-CdtComponentsSatisfied -State $inst.Final
    if (-not $sat.Mandatory) {
        $Cdt.StatusReason = 'Pflichtkomponenten fehlen nach Windows Update und Fallback - Konfiguration nicht ausgefuehrt. ' + ($inst.Errors -join ' | ')
        Write-CdtLog -Level ERROR -Phase 'Configure' -Action 'Skip' -Message 'Sprachinstallation unvollstaendig - keine Konfiguration (Erfolgsvoraussetzung fehlt).'
        return
    }
    $Cdt.Configuration = Invoke-CdtConfiguration -Components $inst.Final
}

function Invoke-CdtRunBody {
    $Cdt.Platform = Get-CdtPlatformInfo
    $Cdt.Context = Get-CdtExecutionContext
    $Cdt.OsSummary = [ordered]@{ release = $Cdt.Platform.ReleaseInfo.Release; displayVersion = $Cdt.Platform.DisplayVersion; edition = $Cdt.Platform.EditionId; editionClass = $Cdt.Platform.EditionClass.Class; build = $Cdt.Platform.Build; ubr = $Cdt.Platform.Ubr; arch = $Cdt.Platform.Architecture }
    $Cdt.CtxSummary = [ordered]@{ identity = $Cdt.Context.Identity; sid = $Cdt.Context.Sid; isSystem = $Cdt.Context.IsSystem; isAdmin = $Cdt.Context.IsAdmin; source = $Cdt.Context.SourceHiveName; orchestrator = $Cdt.Context.OrchestratorHint }
    Write-CdtLog -Phase 'Init' -Action 'Platform' -Message ('{0} | Edition {1} ({2}) | Release {3} Build {4}.{5} | {6}' -f $Cdt.Platform.Caption, $Cdt.Platform.EditionId, $Cdt.Platform.EditionClass.Class, $Cdt.Platform.ReleaseInfo.Release, $Cdt.Platform.Build, $Cdt.Platform.Ubr, $Cdt.Platform.Architecture) -Data $Cdt.Platform -Console
    Write-CdtLog -Phase 'Init' -Action 'Context' -Message ('Ausfuehrungsidentitaet {0} ({1}) | Quellprofil HKU\{2} | PS {3} {4} 64-Bit={5} | {6}' -f $Cdt.Context.Identity, $Cdt.Context.Sid, $Cdt.Context.SourceHiveName, $Cdt.Context.PSVersion, $Cdt.Context.PSEdition, $Cdt.Context.Is64BitProcess, $Cdt.Context.OrchestratorHint) -Data $Cdt.Context -Console
    $Cdt.State = Read-CdtState
    Restore-CdtPreviousRunArtifact
    if ($null -eq $Cdt.State.utf8Baseline) { $cp = Get-CdtCodePageState; $Cdt.State.utf8Baseline = [ordered]@{ ACP = $cp.ACP; OEMCP = $cp.OEMCP; MACCP = $cp.MACCP; Utf8Active = $cp.Utf8Active; runId = $Cdt.RunId; timeUtc = (Get-CdtUtcTimestamp) } }
    $pv = $Cdt.State.pendingVerification
    $Cdt.IsVerificationRun = Test-CdtVerificationRun -PendingVerification $pv -CurrentBootUtc $Cdt.Platform.LastBootUtc
    Write-CdtLog -Phase 'Init' -Action 'State' -Message ('Boot {0} | Nachpruefungslauf={1} | Apply-Runden ohne Erfolg={2}' -f $Cdt.Platform.LastBootUtc, $Cdt.IsVerificationRun, $Cdt.State.applyRounds) -Data ([ordered]@{ pendingVerification = $pv; bootChanges = $Cdt.State.bootChanges; lastOutcome = $Cdt.State.lastOutcome }) -Console
    $pre = Test-CdtPrerequisites
    foreach ($w in $pre.Warnings) { [void]$Cdt.Warnings.Add($w); Write-CdtLog -Level WARN -Phase 'Init' -Action 'Prerequisite' -Message $w }
    Write-CdtLog -Phase 'Init' -Action 'Commands' -Message 'Verfuegbarkeit der benoetigten Cmdlets/Parameter geprueft' -Data $pre.Commands
    if (-not $pre.Ok) {
        foreach ($f in $pre.Fatal) { [void]$Cdt.Errors.Add($f); Write-CdtLog -Level ERROR -Phase 'Init' -Action 'Prerequisite' -Message $f }
        $Cdt.Status = 'UNSUPPORTED'
        $Cdt.StatusReason = ($pre.Fatal -join ' | ')
        return
    }
    $Cdt.UpdatePolicy = Get-CdtUpdateSourcePolicy
    $Cdt.ComponentsBefore = Get-CdtComponentState
    Write-CdtLog -Phase 'Audit' -Action 'Components' -Message ('Ist-Zustand: {0}' -f (Get-CdtComponentSummaryText -State $Cdt.ComponentsBefore)) -Data $Cdt.ComponentsBefore -Console
    $snapBefore = Get-CdtSettingsSnapshot
    $mode = $Cdt.Config.Mode
    $extended = ($mode -eq 'Verify' -or $mode -eq 'Audit' -or $mode -eq 'Auto')
    $before = Test-CdtCompliance -Components $Cdt.ComponentsBefore -Snapshot $snapBefore -Stage 'Before' -IncludeExtended:$extended
    foreach ($c in $before.Checks) { Write-CdtLog -Level 'CHECK' -Phase 'Audit' -Action $c.Id -Message ('{0} [{1}]: {2}' -f $c.Name, $c.Scope, $c.Status) -TargetState ([string]$c.Expected) -ResultState ([string]$c.Actual) -Result $c.Status -Check $c }
    Write-CdtLog -Phase 'Audit' -Action 'Outcome' -Message ('Bewertung vorher: {0} (OK={1} Fehler={2} Neustart={3} NichtPruefbar={4})' -f $before.Outcome, $before.Counts.Pass, $before.Counts.Fail, $before.Counts.PendingReboot, $before.Counts.NotVerifiable) -Console
    switch ($mode) {
        'Audit' { $Cdt.EffectiveMode = 'Audit'; Invoke-CdtAudit -Compliance $before; return }
        'Verify' { $Cdt.EffectiveMode = 'Verify'; $Cdt.FinalCompliance = $before; $Cdt.Status = $before.Outcome; return }
    }
    if ($mode -eq 'Auto' -and $before.Outcome -eq 'SUCCESS') { $Cdt.EffectiveMode = 'Verify'; $Cdt.FinalCompliance = $before; $Cdt.Status = 'SUCCESS'; return }
    $actionable = @($before.Checks | Where-Object { $_.Blocking -and @('Fail', 'NotVerifiable') -contains $_.Status })
    if ($mode -eq 'Auto' -and $actionable.Count -eq 0) {
        $Cdt.EffectiveMode = 'Verify'
        $Cdt.FinalCompliance = $before
        $Cdt.Status = $before.Outcome
        $Cdt.StatusReason = 'Nur ausstehender Neustart offen - keine Aenderung in diesem Lauf'
        return
    }
    if ([int]$Cdt.State.applyRounds -ge [int]$Cdt.Config.MaxApplyRounds) {
        $Cdt.FinalCompliance = $before
        $Cdt.Status = 'FAILED'
        $Cdt.StatusReason = ('Maximale Anzahl Apply-Runden ({0}) ohne Erfolg erreicht - keine weiteren Aenderungen (Schleifenschutz). Ursache analysieren, danach ResetState.' -f $Cdt.Config.MaxApplyRounds)
        Write-CdtLog -Level ERROR -Phase 'Apply' -Action 'LoopGuard' -Message $Cdt.StatusReason -Console
        return
    }
    Invoke-CdtApplyPhase
    $Cdt.ComponentsAfter = Get-CdtComponentState
    $snapAfter = Get-CdtSettingsSnapshot
    $after = Test-CdtCompliance -Components $Cdt.ComponentsAfter -Snapshot $snapAfter -Stage 'After' -IncludeExtended
    foreach ($c in $after.Checks) { Write-CdtLog -Level 'CHECK' -Phase 'Verify' -Action $c.Id -Message ('{0} [{1}]: {2}' -f $c.Name, $c.Scope, $c.Status) -TargetState ([string]$c.Expected) -ResultState ([string]$c.Actual) -Result $c.Status -Check $c }
    $Cdt.FinalCompliance = $after
    $Cdt.Status = $after.Outcome
}

function Complete-CdtRun {
    param([switch]$SkipState)
    if (-not $SkipState) {
        try { Remove-CdtOwnArtifact } catch { Write-CdtLog -Level WARN -Phase 'Cleanup' -Action 'Artifacts' -Message 'Aufraeumen unvollstaendig' -ErrorMessage (Get-CdtErrorInfo -InputObject $_).Message }
    }
    if ([string]::IsNullOrEmpty($Cdt.Status)) { $Cdt.Status = 'INTERNAL_ERROR' }
    $mode = 'Auto'
    if ($null -ne $Cdt.Config) { $mode = $Cdt.Config.Mode }
    $rrCode = 0
    if ($null -ne $Cdt.Config) { $rrCode = [int]$Cdt.Config.ExitCodeRebootRequired }
    $Cdt.ExitCode = Get-CdtExitCode -Status $Cdt.Status -Mode $mode -IsVerificationRun ([bool]$Cdt.IsVerificationRun) -RebootRequiredCode $rrCode
    $Cdt.CaptureAllowed = ($Cdt.Status -eq 'SUCCESS' -and $mode -ne 'Audit')
    if (-not $SkipState -and $null -ne $Cdt.State) {
        if (@('Auto', 'Apply', 'Verify') -contains $mode -and @('SUCCESS', 'REBOOT_REQUIRED', 'FAILED', 'NOT_VERIFIABLE') -contains $Cdt.Status) {
            if ($Cdt.Status -eq 'SUCCESS') { $Cdt.State.pendingVerification = $null; $Cdt.State.applyRounds = 0 }
            elseif ($Cdt.Status -eq 'REBOOT_REQUIRED') { $Cdt.State.pendingVerification = [ordered]@{ bootTimeUtc = $Cdt.Platform.LastBootUtc; runId = $Cdt.RunId; changesThisRun = @($Cdt.ChangesThisRun); timeUtc = (Get-CdtUtcTimestamp) } }
            if ($Cdt.ChangesThisRun.Count -gt 0 -and $Cdt.Status -ne 'SUCCESS') { $Cdt.State.applyRounds = [int]$Cdt.State.applyRounds + 1 }
        }
        $Cdt.State.lastOutcome = [ordered]@{ runId = $Cdt.RunId; mode = $mode; status = $Cdt.Status; exitCode = $Cdt.ExitCode; timeUtc = (Get-CdtUtcTimestamp) }
    }
    if ($Cdt.Status -ne 'LOCKED') {
        try { Write-CdtNetworkRequirementFiles } catch { Write-CdtLog -Level ERROR -Phase 'Report' -Action 'NetworkFiles' -Message 'missing-network-requirements konnte nicht geschrieben werden' -ErrorMessage (Get-CdtErrorInfo -InputObject $_).Message }
    }
    if (-not $SkipState) { Save-CdtState }
    $summary = New-CdtRunSummary
    Write-CdtLog -Level $(if ($Cdt.ExitCode -eq 0) { 'INFO' } else { 'ERROR' }) -Phase 'Result' -Action 'Final' -Message ('Ergebnis {0}, Exitcode {1}, Capture erlaubt {2}. {3}' -f $Cdt.Status, $Cdt.ExitCode, $Cdt.CaptureAllowed, $summary.nextStep) -Result $Cdt.Status -Recommendation $summary.nextStep -Data ([ordered]@{ statusReason = $Cdt.StatusReason; openChecks = $summary.openChecks })
    Write-CdtDailySummary -RunSummary $summary
    Write-CdtConsoleSummary -RunSummary $summary
}

function Invoke-CdtMain {
    param([AllowNull()][object[]]$ScriptArgs)
    $relaunch = Invoke-CdtHostRelaunch -ScriptArgs $ScriptArgs
    if ($null -ne $relaunch) { return [int]$relaunch }
    $Cdt.Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $Cdt.StartTime = [DateTimeOffset]::Now
    $Cdt.RunId = New-CdtRunId
    $Cdt.Seq = 0
    $Cdt.ChangesThisRun = New-Object System.Collections.ArrayList
    $Cdt.Network = [ordered]@{ Performed = $false; Results = (New-Object System.Collections.ArrayList) }
    $Cdt.Warnings = New-Object System.Collections.ArrayList
    $Cdt.Errors = New-Object System.Collections.ArrayList
    $resolved = Resolve-CdtConfiguration -ArgumentList $ScriptArgs
    $Cdt.Config = $resolved.Config
    $Cdt.EffectiveMode = $Cdt.Config.Mode
    Register-CdtKnownSecret
    Resolve-CdtVmName
    if (-not (Initialize-CdtLogging)) {
        $where = Write-CdtEmergencyLog -Message ('Log-Verzeichnis {0} nicht beschreibbar: {1}' -f $Cdt.Config.LogRoot, $Cdt.Log.Error)
        Write-Host ('[DE-LANG] FEHLER: Pflicht-Logverzeichnis {0} nicht beschreibbar ({1}). Keine Aenderungen durchgefuehrt. Notfalldiagnose: {2}' -f $Cdt.Config.LogRoot, $Cdt.Log.Error, $where)
        Write-Host ('CDT_RESULT {{"product":"{0}","runId":"{1}","status":"LOGGING_UNAVAILABLE","exitCode":6,"captureAllowed":false}}' -f $CdtProductName, $Cdt.RunId)
        return 6
    }
    Write-CdtLog -Phase 'Init' -Action 'Start' -Message ('{0} v{1} | RunId {2} | Modus {3} | VM {4} (Quelle: {5})' -f $CdtProductName, $CdtScriptVersion, $Cdt.RunId, $Cdt.Config.Mode, $Cdt.VmName, $Cdt.VmNameSource) -Data ([ordered]@{ configOrigin = $resolved.Origin; config = $Cdt.Config }) -Console
    foreach ($w in $resolved.Warnings) { [void]$Cdt.Warnings.Add($w); Write-CdtLog -Level WARN -Phase 'Init' -Action 'Config' -Message $w }
    if ($resolved.Errors.Count -gt 0) {
        foreach ($e in $resolved.Errors) { [void]$Cdt.Errors.Add($e); Write-CdtLog -Level ERROR -Phase 'Init' -Action 'Config' -Message $e }
        $Cdt.Status = 'UNSUPPORTED'
        $Cdt.StatusReason = 'Ungueltige Konfiguration/Argumente: ' + ($resolved.Errors -join ' | ')
        Complete-CdtRun -SkipState
        return $Cdt.ExitCode
    }
    $lock = Enter-CdtLock
    if (-not $lock.Acquired) {
        $holder = ''
        if ($null -ne $lock.Holder) { $holder = ('RunId {0}, PID {1}, Start {2}' -f $lock.Holder.runId, $lock.Holder.pid, $lock.Holder.startedUtc) }
        $Cdt.Status = 'LOCKED'
        $Cdt.StatusReason = ('Andere Instanz aktiv ({0}) {1}' -f $holder, $lock.Error).Trim()
        Write-CdtLog -Level WARN -Phase 'Init' -Action 'Lock' -Message $Cdt.StatusReason -Console
        Complete-CdtRun -SkipState
        return $Cdt.ExitCode
    }
    try {
        if ($lock.Abandoned) { Write-CdtLog -Level WARN -Phase 'Init' -Action 'Lock' -Message 'Sperre eines abgebrochenen Laufs uebernommen' }
        try { Invoke-CdtRunBody }
        catch {
            $e = Get-CdtErrorInfo -InputObject $_
            $Cdt.Status = 'INTERNAL_ERROR'
            $Cdt.StatusReason = $e.Message
            [void]$Cdt.Errors.Add($e.Message)
            Write-CdtLog -Level ERROR -Phase 'Run' -Action 'Exception' -Message ('Unerwarteter Fehler: {0}' -f $e.Message) -ErrorCode $e.Code -ErrorMessage $e.Message -Data ([ordered]@{ type = $e.Type; stack = (Protect-CdtText -Text $_.ScriptStackTrace) })
        }
        try { Complete-CdtRun }
        catch {
            $Cdt.ExitCode = 9
            Write-Host ('[DE-LANG] FEHLER beim Abschluss: {0}' -f (Get-CdtErrorInfo -InputObject $_).Message)
            Write-Host ('CDT_RESULT {{"product":"{0}","runId":"{1}","status":"INTERNAL_ERROR","exitCode":9,"captureAllowed":false}}' -f $CdtProductName, $Cdt.RunId)
        }
    }
    finally { Exit-CdtLock -Lock $lock }
    return $Cdt.ExitCode
}

# --- CDT-ENTRYPOINT ---------------------------------------------------------------------------------
$Cdt = @{}
$CdtSecretValues = New-Object 'System.Collections.Generic.List[string]'
$CdtEarlyLog = New-Object 'System.Collections.Generic.List[object]'
$CdtExitCode = @(Invoke-CdtMain -ScriptArgs $args) | Select-Object -Last 1
if ($null -eq $CdtExitCode -or [string]$CdtExitCode -notmatch '^-?\d+$') { $CdtExitCode = 9 }
exit ([int]$CdtExitCode)
