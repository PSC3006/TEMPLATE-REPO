#description: CDT - Testet, wie Nerdio/HYDRA einen Exit-Code bewerten (keine Systemaenderung). Nacheinander mit 0, 3010 und 3020 ausfuehren.
#execution mode: Individual
#tags: CDT, Test

<#
.SYNOPSIS
    Beendet sich ohne jede Systemaenderung mit dem angegebenen Exit-Code, damit die Bewertung durch Nerdio
    (Custom Script Extension) bzw. HYDRA geprueft werden kann (Entscheidung D1, -RebootRequiredExitCode).

.DESCRIPTION
    Schreibt eine Zeile nach STDOUT und in eine Logdatei unter -LogRoot und beendet sich mit -ExitCode.
    Ergebnis (Erfolg/Fehler/Neustart-Anzeige je Plattform) im README unter "Exit-Code-Test" eintragen.

.PARAMETER ExitCode
    Zu pruefender Exit-Code. Default 3010.

.PARAMETER LogRoot
    Log-Verzeichnis. Default C:\Install\CDT-STANDARD-Install_DE-Language.

.EXAMPLE
    .\Test-CDTExitCodeHandling.ps1 -ExitCode 3010

.NOTES
    Version : 1.0.0 (2026-10-02)
    CHANGELOG
      1.0.0  2026-10-02  Erstversion.
#>
[CmdletBinding()]
param(
    [ValidateRange(0, 2147483647)]
    [int]$ExitCode = 3010,

    [string]$LogRoot = 'C:\Install\CDT-STANDARD-Install_DE-Language'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$line = '{0} [INFO ] CDT Exit-Code-Test: Computer={1}, Benutzer={2}, PowerShell={3}, ExitCode={4}' -f (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffzzz'), $env:COMPUTERNAME, [System.Security.Principal.WindowsIdentity]::GetCurrent().Name, $PSVersionTable.PSVersion, $ExitCode
try {
    if (-not (Test-Path -LiteralPath $LogRoot)) { $null = New-Item -Path $LogRoot -ItemType Directory -Force }
    $logFile = Join-Path -Path $LogRoot -ChildPath ('{0}_CDT-ExitCodeTest.log' -f $env:COMPUTERNAME)
    [System.IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($true))
}
catch {
    Write-Warning ('Log nicht schreibbar: {0}' -f $_.Exception.Message)
}
Write-Output $line
exit $ExitCode
