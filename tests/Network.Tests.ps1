# Netzwerk- und Download-Pruefungen gegen lokale Testserver (127.0.0.1); keine Internetverbindung noetig.
BeforeAll {
    . (Join-Path $PSScriptRoot 'helpers/TestHelpers.ps1')
    $libPath = Join-Path $TestDrive 'cdt-lib.ps1'
    [System.IO.File]::WriteAllText($libPath, (Get-CdtLibraryText))
    . $libPath
    $ErrorActionPreference = 'Stop'
    $Cdt = @{}
    $CdtSecretValues = New-Object 'System.Collections.Generic.List[string]'
    $CdtEarlyLog = New-Object 'System.Collections.Generic.List[object]'

    function Get-TestPayloadHash([long]$Size) {
        $pattern = [System.Text.Encoding]::ASCII.GetBytes('CDT-DE-LANG-TEST')
        $bytes = New-Object byte[] $Size
        for ($i = 0; $i -lt $Size; $i += 16) { [Array]::Copy($pattern, 0, $bytes, $i, [Math]::Min(16, $Size - $i)) }
        $sha = [System.Security.Cryptography.SHA256]::Create()
        return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
    }
    function New-Target([string]$Url, [string]$Kind = 'ConcreteUrl') {
        return [ordered]@{ Id = 'T'; Url = $Url; Protocol = ([Uri]$Url).Scheme.ToUpperInvariant(); Kind = $Kind; Required = $true; Requirement = ([Uri]$Url).DnsSafeHost; Purpose = 'Test'; Reference = 'Test' }
    }

    $script:Range = Start-CdtTestServer -Mode 'range' -Size 3145728
    $script:NoRange = Start-CdtTestServer -Mode 'norange' -Size 33554432
    $script:CertDir = Join-Path $TestDrive 'cert'
    [void](New-Item -ItemType Directory -Path $CertDir -Force)
    & openssl req -x509 -newkey rsa:2048 -nodes -keyout (Join-Path $CertDir 'key.pem') -out (Join-Path $CertDir 'cert.pem') -days 2 -subj '/CN=localhost' 2>$null | Out-Null
    $script:Tls = Start-CdtTestServer -Mode 'tls' -Size 1048576 -Extra @((Join-Path $CertDir 'cert.pem'), (Join-Path $CertDir 'key.pem'))
    $script:Proxy407 = Start-CdtTestServer -Mode 'proxy' -Size 0 -Extra @('407')
    $script:Proxy403 = Start-CdtTestServer -Mode 'proxy' -Size 0 -Extra @('403')
}

AfterAll {
    foreach ($s in @($Range, $NoRange, $Tls, $Proxy407, $Proxy403)) { Stop-CdtTestServer -Server $s }
}

Describe 'Hilfstyp und Proxy-Auswertung' {
    BeforeEach { New-TestCdtContext -Root (Join-Path $TestDrive ('n-' + [guid]::NewGuid().ToString('N').Substring(0, 6))) }
    It 'kompiliert den C#-Hilfstyp' { Initialize-CdtNetHelper | Should -BeTrue }
    It 'liest WinHTTP-/URL-Proxyangaben' {
        (ConvertFrom-CdtProxyString -ProxyString 'proxy.corp:8080' -Scheme 'https').Port | Should -Be 8080
        (ConvertFrom-CdtProxyString -ProxyString 'http=p1:3128;https=p2:8443' -Scheme 'https').Host | Should -Be 'p2'
        (ConvertFrom-CdtProxyString -ProxyString 'http://user:pw@p3:80/' -Scheme 'http').Host | Should -Be 'p3'
        Test-CdtProxyBypass -HostName 'fe3.delivery.mp.microsoft.com' -BypassList '*.microsoft.com;<local>' | Should -BeTrue
        Test-CdtProxyBypass -HostName 'intranet' -BypassList '<local>' | Should -BeTrue
        Test-CdtProxyBypass -HostName 'sls.update.microsoft.com' -BypassList '*.contoso.com' | Should -BeFalse
    }
}

Describe 'Netzwerkpruefung (Test-CdtNetworkTarget)' {
    BeforeEach { New-TestCdtContext -Root (Join-Path $TestDrive ('n-' + [guid]::NewGuid().ToString('N').Substring(0, 6))) }
    It 'erkennt Range-Unterstuetzung und liest nur den angefragten Bereich' {
        $r = Test-CdtNetworkTarget -Target (New-Target ('http://127.0.0.1:{0}/file.iso' -f $Range.Port)) -PathName 'Download'
        $r.Status | Should -Be 'Pass'
        $r.Http.StatusCode | Should -Be 206
        $r.Http.RangeSupported | Should -BeTrue
        $r.Http.BytesRead | Should -Be 1024
        $r.Dns.Addresses | Should -Contain '127.0.0.1'
    }
    It 'begrenzt den Datenabruf, wenn der Server Range ignoriert, und beendet die Uebertragung' {
        $r = Test-CdtNetworkTarget -Target (New-Target ('http://127.0.0.1:{0}/file.iso' -f $NoRange.Port)) -PathName 'Download'
        $r.Http.StatusCode | Should -Be 200
        $r.Http.RangeSupported | Should -BeFalse
        $r.Http.BytesRead | Should -Be 65536
        $r.Status | Should -Be 'Warn'
        $r.Category | Should -Be 'RangeNotSupported'
        $r.DurationMs | Should -BeLessThan 10000
        Start-Sleep -Seconds 2
        $stats = Invoke-RestMethod -Uri ('http://127.0.0.1:{0}/stats' -f $NoRange.Port) -NoProxy
        $stats.aborted | Should -BeGreaterOrEqual 1
    }
    It 'bewertet 404/403 an einer Dienstwurzel als erreichbar, an einer konkreten URL als Fehler' {
        (Test-CdtNetworkTarget -Target (New-Target ('http://127.0.0.1:{0}/' -f $Range.Port) 'ServiceRoot') -PathName 'Download').Status | Should -Be 'Pass'
        (Test-CdtNetworkTarget -Target (New-Target ('http://127.0.0.1:{0}/forbidden' -f $Range.Port) 'ServiceRoot') -PathName 'Download').Status | Should -Be 'Pass'
        $nf = Test-CdtNetworkTarget -Target (New-Target ('http://127.0.0.1:{0}/missing.iso' -f $Range.Port)) -PathName 'Download'
        $nf.Status | Should -Be 'Fail'; $nf.Category | Should -Be 'UrlNotAvailable'
        $fb = Test-CdtNetworkTarget -Target (New-Target ('http://127.0.0.1:{0}/forbidden' -f $Range.Port)) -PathName 'Download'
        $fb.Status | Should -Be 'Fail'; $fb.Category | Should -Be 'HttpForbidden'
    }
    It 'folgt Weiterleitungen begrenzt und protokolliert sie' {
        $r = Test-CdtNetworkTarget -Target (New-Target ('http://127.0.0.1:{0}/redirect/2' -f $Range.Port)) -PathName 'Download'
        $r.Status | Should -Be 'Pass'
        @($r.Redirects).Count | Should -Be 3
        $Cdt.Config.NetworkMaxRedirects = 1
        $l = Test-CdtNetworkTarget -Target (New-Target ('http://127.0.0.1:{0}/redirect/2' -f $Range.Port)) -PathName 'Download'
        $l.Status | Should -Be 'Fail'; $l.Category | Should -Be 'RedirectLimit'
    }
    It 'unterscheidet TCP-Ablehnung und DNS-Fehler' {
        $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0); $l.Start(); $closed = $l.LocalEndpoint.Port; $l.Stop()
        $t = Test-CdtNetworkTarget -Target (New-Target ('http://127.0.0.1:{0}/file.iso' -f $closed)) -PathName 'Download'
        $t.Status | Should -Be 'Fail'; $t.Category | Should -Be 'TcpConnectFailure'; $t.Code | Should -Be 'ConnectionRefused'
        $d = Test-CdtNetworkTarget -Target (New-Target 'https://cdt-nonexistent-host.invalid/file.iso') -PathName 'WindowsUpdate'
        $d.Status | Should -Be 'Fail'; $d.Category | Should -Be 'DnsFailure'
        $d.Recommendation | Should -Match 'Kein Beleg fuer eine Firewall-Blockade'
    }
    It 'erkennt ein nicht vertrauenswuerdiges Zertifikat ohne die Pruefung abzuschalten' {
        $r = Test-CdtNetworkTarget -Target (New-Target ('https://localhost:{0}/file.iso' -f $Tls.Port)) -PathName 'Download'
        $r.Status | Should -Be 'Fail'
        $r.Category | Should -Be 'TlsCertificateUntrusted'
        $r.Tls.Issuer | Should -Match 'CN=localhost'
        $r.Http | Should -BeNullOrEmpty
    }
    It 'wertet Proxy-Authentifizierung (407) als nicht zuverlaessig pruefbar und 403 als Proxy-Ablehnung' {
        $Cdt.Config.ProxyUrl = ('http://127.0.0.1:{0}' -f $Proxy407.Port)
        $a = Test-CdtNetworkTarget -Target (New-Target 'https://software-static.download.prss.microsoft.com/x.iso') -PathName 'Download'
        $a.ProxyMode | Should -Be 'Proxy'
        $a.ProxyConnect.StatusCode | Should -Be 407
        $a.Status | Should -Be 'NotVerifiable'; $a.Category | Should -Be 'ProxyAuthRequired'
        $Cdt.Config.ProxyUrl = ('http://127.0.0.1:{0}' -f $Proxy403.Port)
        $b = Test-CdtNetworkTarget -Target (New-Target 'https://software-static.download.prss.microsoft.com/x.iso') -PathName 'Download'
        $b.Status | Should -Be 'Fail'; $b.Category | Should -Be 'ProxyDenied'
        $rows = ConvertTo-CdtRequirementRow -Result $b
        $rows[0].Url | Should -Be ('127.0.0.1:{0}' -f $Proxy403.Port)
        $rows.Count | Should -Be 2
    }
}

Describe 'ISO-Download (Save-CdtIsoDownload)' {
    BeforeEach {
        New-TestCdtContext -Root (Join-Path $TestDrive ('d-' + [guid]::NewGuid().ToString('N').Substring(0, 6)))
        $script:Src = [ordered]@{ Id = 'TEST-ISO'; Type = 'Iso'; Architecture = 'AMD64'; FileName = 'test.iso'; Url = ('http://127.0.0.1:{0}/file.iso' -f $Range.Port); Sha256 = '' }
    }
    It 'laedt vollstaendig, prueft die Groesse und protokolliert SHA256 ohne Integritaetsversprechen' {
        $r = Save-CdtIsoDownload -SourceInfo $Src
        $r.Ok | Should -BeTrue
        (Get-Item -LiteralPath $r.Path).Length | Should -Be 3145728
        $r.Sha256 | Should -Be (Get-TestPayloadHash -Size 3145728)
        $r.Sha256Verified | Should -BeNullOrEmpty
        Test-Path -LiteralPath ($r.Path + '.cdt-download.json') | Should -BeTrue
        [System.IO.File]::ReadAllText($Cdt.Log.Text) | Should -Match 'keine unabhaengige Integritaetsbestaetigung'
    }
    It 'setzt einen Teil-Download per Range-Request fort' {
        [void](New-Item -ItemType Directory -Path $Cdt.Log.WorkDir -Force)
        $partial = Join-Path $Cdt.Log.WorkDir 'test.iso.partial'
        $pattern = [System.Text.Encoding]::ASCII.GetBytes('CDT-DE-LANG-TEST')
        $first = New-Object byte[] 1048576
        for ($i = 0; $i -lt $first.Length; $i += 16) { [Array]::Copy($pattern, 0, $first, $i, 16) }
        [System.IO.File]::WriteAllBytes($partial, $first)
        $r = Save-CdtIsoDownload -SourceInfo $Src
        $r.Ok | Should -BeTrue
        $r.Resumed | Should -BeTrue
        $r.Sha256 | Should -Be (Get-TestPayloadHash -Size 3145728)
    }
    It 'verwirft die Datei bei abweichender Referenzpruefsumme' {
        $Src.Sha256 = ('0' * 64)
        $r = Save-CdtIsoDownload -SourceInfo $Src
        $r.Ok | Should -BeFalse
        $r.Sha256Verified | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $Cdt.Log.WorkDir 'test.iso') | Should -BeFalse
    }
    It 'startet neu, wenn der Server keine Range-Requests unterstuetzt' {
        $Src.Url = ('http://127.0.0.1:{0}/file.iso' -f $NoRange.Port)
        [void](New-Item -ItemType Directory -Path $Cdt.Log.WorkDir -Force)
        [System.IO.File]::WriteAllBytes((Join-Path $Cdt.Log.WorkDir 'test.iso.partial'), (New-Object byte[] 4096))
        $r = Save-CdtIsoDownload -SourceInfo $Src
        $r.Ok | Should -BeTrue
        $r.Resumed | Should -BeFalse
        $r.Sha256 | Should -Be (Get-TestPayloadHash -Size 33554432)
    }
    It 'bricht bei nicht verfuegbarer URL ohne Wiederholungsschleife ab' {
        $Src.Url = ('http://127.0.0.1:{0}/missing.iso' -f $Range.Port)
        $r = Save-CdtIsoDownload -SourceInfo $Src
        $r.Ok | Should -BeFalse
        $r.Category | Should -Be 'UrlNotAvailable'
        $r.Attempts | Should -Be 0
    }
    It 'beachtet das Zeitbudget (kein Download, wenn die Restzeit nicht reicht)' {
        $Cdt.Config.TimeBudgetMinutes = 15
        $r = Save-CdtIsoDownload -SourceInfo $Src
        $r.Ok | Should -BeFalse
        $r.Category | Should -Be 'TimeBudget'
    }
}
