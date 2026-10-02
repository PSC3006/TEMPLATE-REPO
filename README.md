# CDT – Deutsches Sprachpaket für AVD-Master-Images

Automatisierte Installation des deutschen Sprachpakets (de-DE) inkl. Language-FoDs und vollständige Umstellung von
Windows 11 Enterprise (Single-/Multi-Session) 24H2, 25H2 und 26H2 auf Deutschland – lauffähig unverändert als
**Nerdio Scripted Action** und als **HYDRA-Script**.

| Datei | Zweck |
|---|---|
| `Install-CDTGermanLanguage.ps1` | Hauptscript (Modes Auto/Install/ReapplyLcu/Validate/PreSysprep), Version 4.0.0 |
| `New-CDTLanguageRepository.ps1` | Einmalig pro OS-Hauptbuild: minimales Repository (Stufe 2) erzeugen, versionieren, hochladen |
| `Test-CDTExitCodeHandling.ps1` | Ändert nichts; prüft, wie Nerdio/HYDRA einen Exit-Code bewerten |
| `tests/*.Tests.ps1` | Pester-Tests (Pester 4.10/5.x) nur mit Mocks, keine Systemaufrufe |
| `PSScriptAnalyzerSettings.psd1` | Analyzer-Regeln inkl. Kompatibilität Windows PowerShell 5.1 |
| `TESTPLAN.md` | Testplan für Marketplace-VMs 24H2/25H2/26H2 |
| `CDT-STANDARD-DE-LANGUAGE.ps1` | **Legacy (v3.1)**, durch `Install-CDTGermanLanguage.ps1` abgelöst; unverändert belassen |

---

## 1. Schnellstart

```powershell
# Mode Auto ohne Parameter: führt die nächste offene Phase aus (Stufe 1 = Windows Update)
.\Install-CDTGermanLanguage.ps1

# Mit Repository (Stufe 2) aus Azure Files
.\Install-CDTGermanLanguage.ps1 -RepositoryPath '\\stcdtlang.file.core.windows.net\langrepo\26100' -StorageAccountKey $Key

# LCU erneut anwenden (MSU-Ordner mit Ziel- und Checkpoint-MSU)
.\Install-CDTGermanLanguage.ps1 -Mode ReapplyLcu -LcuPath 'C:\Install\LCU'

# Letzter Schritt vor Sysprep/Capture
.\Install-CDTGermanLanguage.ps1 -Mode PreSysprep -CleanupAppxForSysprep
```

**Pipeline (MS-09: Apps nach den Sprachen):**
`Install → Reboot → ReapplyLcu → Reboot → Apps installieren → PreSysprep → Sysprep/Capture durch Nerdio/HYDRA`
Mit `-Mode Auto` genügt nach jedem Neustart derselbe Aufruf, bis `SUCCESS` (Exit 0) gemeldet wird.

## 2. Modes und Zustandsmodell

| Mode | Wirkung |
|---|---|
| `Auto` (Default) | Ermittelt aus Zustand + System genau eine Phase: Neustart offen → nichts tun; Install unvollständig → Install; LCU offen → ReapplyLcu; sonst Validate |
| `Install` | MS-01..MS-05 setzen, Sprachpaket + FoDs (Quellen-Kette), Ländereinstellungen, Zeitzone |
| `ReapplyLcu` | LCU nach der Sprachinstallation erneut installieren (MS-08) |
| `Validate` | Soll/Ist-Prüfung ohne Änderungen (Ausnahme: Rollback abgebrochener temporärer Änderungen) |
| `PreSysprep` | Validate + harte Sysprep-Readiness; offener MUSS-Punkt → `PRESYSPREP_BLOCKED` |

Zustand: `HKLM:\SOFTWARE\CDT\LanguageDeployment\de-DE`

| Wert | Bedeutung |
|---|---|
| `ScriptVersion`, `LastPhase`, `LastResult`, `LastExitCode`, `LastRun` | letzter Lauf |
| `InstallSource` (1/2/3, z. B. `1+2`), `InstallSourceDetail`, `InstallTimestamp`, `InstallDurationSeconds` | Installationsquelle |
| `OsBuildAtInstall` (Build.UBR) | Stand bei der Sprachinstallation |
| `LcuReapplyRequired` (0/1), `LcuReapplyResult`, `LcuReapplyKb`, `LcuReappliedTimestamp`, `LcuReappliedBuild` | MS-08 |
| `RebootPending`, `RebootRequestedAt`, `PlannedReboot` | Neustart-Steuerung über Reboots |
| `LanguagePackInstalledAt`, `FodInstalledAt` | Nachweis Reihenfolge MS-07 |
| `Stage1Attempts`, `Stage1Result`, `Stage1Exhausted`, `LastStageAttempted`, `InstallRunCount` | Fortsetzung/Schleifenschutz |
| `PolicyBackupJson`, `TempDisabledTasks`, `IsoMounted`, `WinReDisabledByScript`, `RestrictTemporarilyRemoved` | Absturzschutz (werden beim nächsten Start zurückgerollt) |
| `RepositoryHost`, `LcuHost`, `WinReLanguageAdded`, `RestrictSetByScript` | MS-11/MS-13/MS-14 |

## 3. Exit-Codes

| Status | Exit-Code | Bedeutung |
|---|---|---|
| `SUCCESS` | 0 | alles erledigt |
| `SUCCESS_REBOOT_REQUIRED` | `-RebootRequiredExitCode` (Default **3010**) | Neustart nötig, danach erneut ausführen |
| `SUCCESS_LCU_REAPPLY_PENDING` | 3020 | LCU-Quelle fehlt (MS-08 offen) |
| `PARTIAL` | 3030 | unvollständig (z. B. Laufzeitbudget); erneut ausführen |
| `PRESYSPREP_BLOCKED` | 3040 | mind. ein MUSS-Punkt offen – Sysprep/Capture nicht starten |
| `FAILED` | 3050 | Fehler, Diagnose-Ordner prüfen |

Rangfolge bei mehreren Zuständen: FAILED > PRESYSPREP_BLOCKED > PARTIAL > REBOOT > LCU_PENDING > SUCCESS.

### Exit-Code-Test (Entscheidung D1 – noch offen)
Die Custom Script Extension wertet laut Microsoft **jeden Exit-Code ≠ 0 als „Failed“**
([Debug CSE/Run Command](https://learn.microsoft.com/troubleshoot/azure/virtual-machines/windows/debug-customscriptextension-runcommand-scripts)).
Nerdio nutzt die CSE – 3010 wird dort voraussichtlich als Fehler angezeigt. Für HYDRA ist das Verhalten nicht belegt.

1. `Test-CDTExitCodeHandling.ps1` als Scripted Action bzw. HYDRA-Script je einmal mit `-ExitCode 0`, `3010`, `3020` ausführen.
2. Ergebnis eintragen:

| Plattform | 0 | 3010 | 3020 | Empfohlener `-RebootRequiredExitCode` |
|---|---|---|---|---|
| Nerdio | _offen_ | _offen_ | _offen_ | _offen (erwartet: 0 + Neustart über Nerdio)_ |
| HYDRA | _offen_ | _offen_ | _offen_ | _offen_ |

Bei `-RebootRequiredExitCode 0` **muss** der Neustart über die Plattform erfolgen (Nerdio „Restart VM“, HYDRA-Collection-Task „Restart“), sonst geht die Pipeline ohne Neustart weiter.

## 4. Runbook Nerdio Manager

Fakten (Quellen: [Scripted Actions: Windows scripts](https://nmmhelp.getnerdio.com/hc/en-us/articles/26125631982733-Scripted-Actions-Windows-scripts),
[Usage, Supported Features](https://nmehelp.getnerdio.com/hc/en-us/articles/26124368713741-Windows-Scripted-Actions-Usage-Supported-Features-and-Considerations),
[Global Secure Variables](https://nmehelp.getnerdio.com/hc/en-us/articles/26124302368909-Scripted-Actions-Global-Secure-Variables),
[Set as image](https://nmehelp.getnerdio.com/hc/en-us/articles/48283775147789-Desktop-images-set-as-image); Hilfeseiten waren aus der Recherche-Umgebung nur über Suchauszüge erreichbar):
Ausführung über die Azure Custom Script Extension als LocalSystem, **90 Minuten Timeout**, ein Neustart *im* Script lässt den Vorgang scheitern,
Parameter-Block wird unterstützt (string/int/bool/switch/string[]), `$SecureVars` mit `ParameterSetName = 'NME_PARAMETER'`.

1. **Scripted Action anlegen:** *Scripted Actions → Windows scripts → Add*, Inhalt von `Install-CDTGermanLanguage.ps1` einfügen (Header `#description`, `#execution mode: Individual`, `#tags` sind enthalten).
2. **Secure Variables** (*Settings → Nerdio → Secure variables*), der Scripted Action zuweisen:
   `CDTLangStorageAccountKey`, `CDTLangRepositoryZipUrl`, `CDTLangRepositoryPath`, `CDTLangLcuUrl` (mehrere URLs mit `;`), `CDTLangLcuPath`.
   Das Script übernimmt sie nur, wenn der gleichnamige Parameter leer ist. Werte werden nie geloggt.
3. **Parameter** in der Scripted Action: mindestens `RebootRequiredExitCode = 0` (siehe Abschnitt 3), optional `RepositoryPath`.
4. **Desktop Image – Ablauf:**
   - Scripted Action `Mode=Auto` ausführen, **Restart VM** danach (bzw. Execution Mode „Individual with restart“ / Scripted Sequence mit Restart).
   - Wiederholen, bis die Konsolenzusammenfassung `SUCCESS` zeigt (typisch: Install → Neustart → ReapplyLcu → Neustart → Validate).
   - Apps installieren.
   - Bei **„Set as image“** die Scripted Action mit `Mode=PreSysprep` (optional `CleanupAppxForSysprep`) unter *„Run the following scripted actions before set as image“* eintragen. Nerdio führt sie auf dem Klon vor Sysprep aus; dass ein Exit ≠ 0 den Vorgang abbricht, ist durch das CSE-Verhalten zu erwarten, aber im Testplan zu bestätigen.
5. `-ForceReboot`/`-RebootIfRequired` unter Nerdio **nicht** verwenden (CSE-Neustart-Problematik); stattdessen Nerdio-Restart.

Beispiele je Mode (Parameterfelder in Nerdio):

| Mode | Parameter |
|---|---|
| Auto | `Mode=Auto`, `RebootRequiredExitCode=0`, optional `RepositoryPath`, Secure Variables |
| Install | `Mode=Install`, `RepositoryPath=\\stcdtlang.file.core.windows.net\langrepo\26100` |
| ReapplyLcu | `Mode=ReapplyLcu`, Secure Variable `CDTLangLcuUrl` oder `LcuPath` |
| Validate | `Mode=Validate` |
| PreSysprep | `Mode=PreSysprep`, `CleanupAppxForSysprep=true` |

## 5. Runbook HYDRA (Login VSI)

Fakten ([WVD-Hydra README](https://github.com/MarcelMeurer/WVD-Hydra/blob/main/README.md),
[Script Collections](https://support.loginvsi.com/hc/en-us/articles/21493519406236-Script-Collections)):
Scripts laufen im SYSTEM-Kontext, Script Collections verketten Scripts und Aktionen (z. B. *Restart*) mit On-Error-Aktionen;
Imaging erfolgt auf einer temporären Kopie, vor Sysprep wird `C:\Windows\Temp\PreImageCustomizing.ps1` ausgeführt.
**Nicht belegt:** Auswertung von Exit-Codes, Timeout, Syntax für Secrets → per Exit-Code-Test (Abschnitt 3) prüfen.

1. Script unter *Scripts* anlegen (Inhalt `Install-CDTGermanLanguage.ps1`). Parameter über die HYDRA-Script-Parameter oder – falls nicht verfügbar – als Defaults im `param()`-Block anpassen. Secrets nur über HYDRA-Variablen/-Parameter, nie fest im Code.
2. **Script Collection** „CDT Sprache de-DE“:
   `Script (Mode Auto)` → `Restart` → `Script (Mode Auto)` → `Restart` → `Script (Mode Auto, prüft Validate)` → *Apps* → `Script (Mode PreSysprep)`
   On Error: Collection stoppen (VM nicht löschen, Diagnose sichern).
3. Optional `-RebootIfRequired` statt eigener Restart-Tasks (verzögerter Neustart nach Rückgabe des Exit-Codes, Default 60 s).
4. Imaging erst starten, wenn `PreSysprep` Exit 0 liefert. Alternativ ein Wrapper als `C:\Windows\Temp\PreImageCustomizing.ps1`, der `-Mode PreSysprep` aufruft (Abbruchverhalten von HYDRA unbestätigt → testen).

## 6. Installationsquellen (Fallback-Kette)

| Stufe | Quelle | Details |
|---|---|---|
| 1 | `Install-Language` (Windows Update/UUP) | Job mit Timeout (`-InstallTimeoutMinutes`), Retry mit Backoff (`-InstallRetryCount`), danach Warten auf CBS-Leerlauf. Tasks `LanguageComponentsInstaller\Installation` und `\ReconcileLanguageResources` werden währenddessen deaktiviert (Microsoft AIB-Script, Bug 45044965) und im `finally` reaktiviert. Fehlende FoDs werden per `Add-WindowsCapability` nachgezogen. |
| 2 | Eigenes Repository (Microsoft-Empfehlung) | `-RepositoryPath` (UNC, temporäres Mapping per `New-SmbMapping`, Fallback `net use /persistent:no`) oder `-RepositoryZipUrl` (HTTPS + SAS). Repository wird lokal kopiert, Share **sofort getrennt** (inkl. cmdkey-Bereinigung), dann `manifest.json` (Hauptbuild, Sprache, SHA256 aller Dateien) und Authenticode geprüft. |
| 3 | LOF-ISO (Notfall oder `-ForceIsoSource`) | HEAD (Content-Length), Speicher + 20 %, WinHTTP-Proxy-Log, `curl.exe --retry -C - --fail` → Fallback BITS, `Mount-DiskImage -PassThru` + `Get-Volume` (ohne Buchstaben: mountvol-Ordner), `LanguagesAndOptionalFeatures` als Repository, Dismount + Löschen im `finally`. |

Stufe 2/3: zuerst Sprachpaket (`Add-WindowsPackage -Online`), danach Language-FoDs (`Add-WindowsCapability -Online -Source <Repo> -LimitAccess`). FoDs nie per Add-Package. Die Paketversion des Sprachpakets wird vor der Installation gegen die OS-Basis geprüft (MS-06).

**Language Experience Pack (LXP):** de-DE ist ein vollständiges CAB-Sprachpaket; für Imaging sind laut Microsoft nur CAB-Sprachpakete nutzbar. Ein LXP wird **nicht** provisioniert. Holt der Store bei Internetzugang ein LXP pro Benutzer, blockiert es Sysprep (MS-10) – `-CleanupAppxForSysprep` entfernt es nach Microsoft-KB.

**Satelliten:** Ab 24H2 vorinstallierte FoDs mit Satelliten laut Microsoft: Notepad (system), PowerShell ISE, Print Management Console, Steps Recorder (abgekündigt). WordPad ist ab 24H2 entfernt, WMIC und Fax/Scan sind nicht mehr vorinstalliert ([Non-language FoDs](https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-non-language-fod), [Removed features](https://learn.microsoft.com/windows/whats-new/removed-features)). Diese FoDs erhalten ihre de-DE-Satelliten, weil das Sprachpaket aus dem Repository/ISO installiert wird (Microsoft: ISO bzw. Repository als Quelle). ZUS-11 prüft und meldet fehlende Satelliten (WARN).

## 7. Repository erstellen, aktualisieren, versionieren (Stufe 2)

```powershell
# Lokal, mit ZIP
.\New-CDTLanguageRepository.ps1 -RepositoryRoot 'D:\LangRepo' -CreateZip

# Direkt nach Azure Files (temporär verbunden), WinPE-Sprachpakete für WinRE inklusive
.\New-CDTLanguageRepository.ps1 -RepositoryRoot '\\stcdtlang.file.core.windows.net\langrepo' -StorageAccountKey $Key -IncludeWinPE

# ZIP nach Azure Blob (Container-SAS mit Schreibrecht; azcopy wenn vorhanden, sonst curl.exe)
.\New-CDTLanguageRepository.ps1 -RepositoryRoot 'D:\LangRepo' -CreateZip -UploadBlobContainerSasUrl $ContainerSas
```

- Struktur: `<Root>\26100\de-DE_<yyyy-MM-dd>\` (+ `manifest.json`), optional `<Root>\26100\de-DE_<yyyy-MM-dd>.zip`.
- `-RepositoryPath` darf auf `<Root>`, `<Root>\26100` oder einen Versionsordner zeigen – ohne Versionsangabe wird die neueste Version gewählt.
- Export: `DISM /Export-Source` (Microsoft dokumentiert `/Image`; `/Online` ist unbestätigt und wird zuerst versucht), Fallback `/Image` mit `-ImagePath`, danach Vollkopie von `LanguagesAndOptionalFeatures`. Satelliten-FoDs werden nur exportiert, wenn sie auf der Build-VM installiert sind (Build-VM = gleiches Image wie Master).
- **Aktualisieren:** nur bei neuem OS-Hauptbuild bzw. neuem LOF-ISO nötig; neuer Versionsordner, alter bleibt für Rollback. Language-Komponenten werden über das LCU aktualisiert (deshalb MS-08), nicht über das Repository.
- Für `-RepositoryZipUrl` eine **Lese-SAS** auf den Blob erzeugen und als Nerdio Secure Variable `CDTLangRepositoryZipUrl` hinterlegen.

## 8. LCU erneut anwenden (MS-08)

Microsoft: *„After you install a language pack, you have to reinstall the latest cumulative update (LCU) … If the LCU is already installed, Windows Update does not offer it again. You have to manually install the LCU.“* ([languages-overview](https://learn.microsoft.com/windows-hardware/manufacture/desktop/languages-overview))

1. **KB ermitteln:** Das Script loggt in jedem Lauf KB und Build.UBR (CBS-Registry `Package_for_RollupFix`, sonst WU-Historie). Alternativ `Settings → Windows Update → Update history` oder [Windows 11 release information](https://learn.microsoft.com/windows/release-health/windows11-release-information) (gleiche UBR für 26100/26200/26300).
2. **MSU beschaffen:** [Microsoft Update Catalog](https://www.catalog.update.microsoft.com) → KB suchen → *Download*. Das Download-Fenster listet **alle Checkpoint-MSU**; alle herunterladen ([Checkpoint-CUs](https://learn.microsoft.com/windows/deployment/update/catalog-checkpoint-cumulative-updates): bei Sprach-/FoD-Anpassung sind alle Checkpoints + Ziel nötig, auch wenn ein Checkpoint schon installiert ist).
3. Im Ordner **nur** Ziel- und Checkpoint-MSU ablegen (sonst Abbruch). Das Script übergibt die Ziel-MSU (höchste KB) an `Add-WindowsPackage`; DISM erkennt die Checkpoints im selben Ordner.
4. Alternativen: neueres LCU (UBR > `OsBuildAtInstall`) erfüllt MS-08 automatisch; `-UseWindowsUpdateForNewerLcu` installiert ein neueres kumulatives Update über die WUA-COM-API.
5. Meldet CBS `0x800F081E` (nicht anwendbar), wird MS-08 als **WARN** gewertet (Entscheidung D4).

## 9. Compliance-Checkliste

Wird in jedem Lauf geprüft, geloggt und als `<VM>_CDT-STANDARD-Install_DE-Language_Compliance_<Zeit>.csv` (Semikolon) geschrieben.

| ID | Empfehlung | Quelle | Pflicht |
|---|---|---|---|
| MS-01 | Task `\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup` deaktiviert | [AVD Language Packs](https://learn.microsoft.com/azure/virtual-desktop/windows-11-language-packs) | MUSS |
| MS-02 | Task `\Microsoft\Windows\MUI\LPRemove` deaktiviert | [AVD Language Packs](https://learn.microsoft.com/azure/virtual-desktop/windows-11-language-packs) | MUSS |
| MS-03 | Task `\Microsoft\Windows\LanguageComponentsInstaller\Uninstallation` deaktiviert | [languages-overview](https://learn.microsoft.com/windows-hardware/manufacture/desktop/languages-overview) | MUSS |
| MS-04 | `HKLM\SOFTWARE\Policies\Microsoft\Control Panel\International\BlockCleanupOfUnusedPreinstalledLangPacks = 1` | [languages-overview](https://learn.microsoft.com/windows-hardware/manufacture/desktop/languages-overview) | MUSS |
| MS-05 | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput\AllowLanguageFeaturesUninstall = 0` | [languages-overview](https://learn.microsoft.com/windows-hardware/manufacture/desktop/languages-overview) | MUSS |
| MS-06 | Sprachkomponenten passen zum OS-Hauptbuild | [languages-overview](https://learn.microsoft.com/windows-hardware/manufacture/desktop/languages-overview) | MUSS |
| MS-07 | Reihenfolge Language Pack → Language-FoDs | [Language FoD](https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-language-fod) | MUSS |
| MS-08 | LCU nach der Sprachinstallation erneut installiert | [languages-overview](https://learn.microsoft.com/windows-hardware/manufacture/desktop/languages-overview) | MUSS |
| MS-09 | Apps nach den Sprachen (PreSysprep warnt) | [OEM Deployment](https://learn.microsoft.com/windows-hardware/manufacture/desktop/oem-deployment-of-windows-desktop-editions) | MUSS (WARN) |
| MS-10 | Sysprep-Readiness Appx (inkl. LXP) | [Sysprep fails with Store apps](https://learn.microsoft.com/troubleshoot/windows-client/deployment/sysprep-fails-remove-or-update-store-apps) | MUSS (nur PreSysprep blockierend) |
| MS-11 | Kein Share verbunden, keine cmdkey-Einträge, keine ISO-/Temp-Reste | [AVD Language Packs](https://learn.microsoft.com/azure/virtual-desktop/windows-11-language-packs) | MUSS |
| MS-12 | Language-FoDs installiert (Get-WindowsCapability State = Installed) | [Language FoD](https://learn.microsoft.com/windows-hardware/manufacture/desktop/features-on-demand-language-fod) | MUSS |
| MS-13 | `RestrictLanguagePacksAndFeaturesInstall` (Switch `-RestrictUserLanguageInstall`) | [Policy CSP](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-timelanguagesettings) | KANN |
| MS-14 | WinRE-Sprachpaket (Switch `-IncludeWinRELanguage`) | [Customize WinRE](https://learn.microsoft.com/windows-hardware/manufacture/desktop/customize-windows-re) | KANN |
| MS-15 | en-US nicht entfernen (Rückfallsprache) | [languages-overview](https://learn.microsoft.com/windows-hardware/manufacture/desktop/languages-overview) | INFO |
| MS-16 | Benutzer nach Wechsel der Anzeigesprache über das Startmenü abmelden | [AVD Language Packs](https://learn.microsoft.com/azure/virtual-desktop/windows-11-language-packs) | INFO |
| ZUS-01 | Sprachpaket de-DE installiert | [Add languages](https://learn.microsoft.com/windows-hardware/manufacture/desktop/add-language-packs-to-windows) | MUSS |
| ZUS-02 | System Preferred UI Language = de-DE | [Set-SystemPreferredUILanguage](https://learn.microsoft.com/powershell/module/languagepackmanagement/set-systempreferreduilanguage) | MUSS |
| ZUS-03 | System Locale = de-DE | [Add languages](https://learn.microsoft.com/windows-hardware/manufacture/desktop/add-language-packs-to-windows) | MUSS |
| ZUS-04 | Regionalformat Welcome Screen/Systemkonten | [Copy-UserInternationalSettingsToSystem](https://learn.microsoft.com/powershell/module/international/copy-userinternationalsettingstosystem) | MUSS |
| ZUS-05 | Home Location GeoID 94 | dto. | MUSS |
| ZUS-06 | Zeitzone W. Europe Standard Time | [Settings-Referenz](https://learn.microsoft.com/windows/apps/develop/settings/settings-common#date-and-time) | MUSS |
| ZUS-07 | tzautoupdate Start = 4 (bei `-AutoTimeZoneUpdate Disable`) | dto. | MUSS |
| ZUS-08 | Default-User-Hive: Format, GeoID, Sprachliste, Tastatur ohne en-US | [Copy-UserInternationalSettingsToSystem](https://learn.microsoft.com/powershell/module/international/copy-userinternationalsettingstosystem) | MUSS |
| ZUS-09 | .DEFAULT/Welcome Screen: Sprachliste und Tastatur ohne en-US | dto. | MUSS |
| ZUS-10 | Kein Neustart ausstehend (CBS/WU; PendingFileRenameOperations nur WARN) | – | MUSS |
| ZUS-11 | de-DE-Satelliten installierter FoDs | [languages-overview](https://learn.microsoft.com/windows-hardware/manufacture/desktop/languages-overview) | KANN |
| ZUS-12 | WSUS-/WU-/Servicing-Policies | [FoD & LP mit WSUS](https://learn.microsoft.com/windows/deployment/update/fod-and-lang-packs) | INFO |
| ZUS-13 | Temporäre Änderungen zurückgesetzt (Policies, Installer-Tasks) | [Azure/RDS-Templates](https://github.com/Azure/RDS-Templates/tree/master/CustomImageTemplateScripts) | MUSS |
| ZUS-14 | MUI-Dateiversion de-DE vs. en-US (Heuristik, unbestätigt) | – | INFO |
| ZUS-15 | OS-Build und Ausführungskontext | [Release information](https://learn.microsoft.com/windows/release-health/windows11-release-information) | INFO |

## 10. Neustart

- Default: **kein** Neustart; Bedarf wird erkannt (DISM `RestartNeeded`, CBS `RebootPending`, WU `RebootRequired`, `PendingFileRenameOperations`) und per Exit-Code gemeldet.
- `-RebootIfRequired`: Neustart nur bei Bedarf (nicht bei FAILED). `-ForceReboot`: immer (nicht bei FAILED, außer `-ForceRebootOnError`). Beide zusammen → FAILED vor jeder Änderung.
- Immer verzögert: `shutdown.exe /r /f /t <RebootDelaySeconds> /d p:4:2 /c "<Begründung>"` – erst nach Log, Zustand, Transcript-Ende und Rückgabe des Exit-Codes. Geplanter Neustart steht im Log und im Zustand (`PlannedReboot`).

## 11. Logging und Diagnose

Verzeichnis `C:\Install\CDT-STANDARD-Install_DE-Language\` (`-LogRoot`):

| Datei | Inhalt |
|---|---|
| `<VM>_CDT-STANDARD-Install_DE-Language_<yyyy-MM-dd_HHmmss>.log` | Hauptlog (UTF-8 mit BOM, ISO-Zeitstempel, Level, Mode, Phase, Dauer je Schritt) |
| `<VM>_CDT-STANDARD-Install_DE-Language_Error-Log_<…>.log` | nur WARN/ERROR inkl. Exception-Typ, HRESULT (hex), Message, ScriptStackTrace, Zeile |
| `<VM>_CDT-STANDARD-Install_DE-Language_Compliance_<…>.csv` | Checkliste MS-01..MS-16, ZUS-01..ZUS-15 |
| `<VM>_CDT-STANDARD-Install_DE-Language_Transcript_<…>.log` | Start-Transcript |
| `<VM>_CDT-STANDARD-Install_DE-Language_DISM_<…>.log` | DISM-Log der Cmdlets |
| `<VM>_Diag_<…>\` | nur bei FAILED/PARTIAL/PRESYSPREP_BLOCKED: Event-Logs (System, Application, Setup, International/Language/MUI/WindowsUpdateClient/AppXDeployment/Servicing, vorher per `Get-WinEvent -ListLog` geprüft), CBS-/DISM-Auszüge des Laufzeitfensters, Panther-Logs, Systeminfo (Build, UBR, Edition, WU-Policies, `netsh winhttp show proxy`), `HKLM\SOFTWARE\CDT`, optional `WindowsUpdate.log` |

Diagnose-Ordner älter als `-LogRetentionDays` (Default 30) werden entfernt. Secrets (Key, SAS) werden in allen Ausgaben maskiert.
Bei Abweichung von der Vorgabe wurden Unterstriche in Dateinamen ergänzt (Entscheidung D8).

## 12. Troubleshooting-Matrix

| Code / Symptom | Ursache | Maßnahme |
|---|---|---|
| `0x800F0950` | Download Sprachpaket/FoD über WU fehlgeschlagen | Netz/Proxy/Policies prüfen; Stufe 2 bereitstellen |
| `0x800F081F` | Quelle fehlt/passt nicht zum Build | Repository/ISO-Build prüfen (MS-06), Manifest neu erzeugen |
| `0x800F0954` | WSUS/Servicing-Policy liefert keine optionalen Inhalte | ZUS-12 prüfen; `-AllowTemporaryWuPolicyBypass` oder Stufe 2; auf UUP-Builds Policy „Specify settings for optional component installation“ nicht konfigurieren |
| `0x8024402C` / `0x80240438` | WU nicht erreichbar (DNS/Proxy/Endpoint) | WinHTTP-Proxy (Log), Firewall; Stufe 2 |
| `0x8024500C` | WU-Zugriff per Policy gesperrt | `DisableWindowsUpdateAccess` prüfen, Bypass-Switch oder Stufe 2 |
| `0x80070020` | Sharing Violation (Sprachkomponenten-Tasks) | Script deaktiviert die Tasks; erneut ausführen |
| `ErrorCode: -2147418113` (`0x8000FFFF`) | interner Fehler `Install-Language` | Retry erfolgt automatisch; sonst Stufe 2 |
| `0x800F0838` | Checkpoint-MSU fehlt | alle Checkpoint-MSU aus dem Catalog-Download in den LCU-Ordner |
| `0x800F081E` | LCU nicht anwendbar | MS-08 = WARN (D4); KB/Build prüfen |
| `0x800F082F` | Ausstehender Neustart blockiert Servicing | neu starten, erneut ausführen |
| Auto meldet dauerhaft 3010 | CBS/WU-Neustart bleibt nach Reboot stehen bzw. Install wiederholt sich | `InstallRunCount` ≥ 3 → PARTIAL; CBS-Log/Diagnose prüfen |
| Sysprep `0x80073cf2` | Appx nur benutzerbezogen/aktualisiert (z. B. LXP) | `-Mode PreSysprep -CleanupAppxForSysprep` |
| Stufe 2 „Hauptbuild passt nicht“ | Repository für anderen Build | Repository für 26100 erzeugen (Abschnitt 7) |
| Stufe 2 „Authenticode“ | manipulierte/falsche Dateien | Repository neu erzeugen |
| „Ein anderer Lauf … ist aktiv“ | parallel gestarteter Lauf | Lauf abwarten (Mutex) |

## 13. Bekannte Grenzen und unbestätigte Punkte

- **26H2 + LOF-ISO 26100:** im AVD-Artikel nur für 24H2/25H2 gelistet → WARN, Basis 26100 (gemeinsamer Branch laut Microsoft).
- **26H1 (Build 28000):** andere Plattform; Stufe 2/3 nur mit passendem Repository, sonst Stufe 1.
- **`DISM /Online /Export-Source`** nicht dokumentiert (Fallback vorhanden).
- **Erneute Installation desselben LCU online:** Verhalten nicht dokumentiert (0x800F081E wird abgefangen).
- **MSU-Signatur:** `NotSigned` wird nur gewarnt (CBS prüft Pakete selbst).
- **WinRE:** Zuordnung WinPE-OC-Pakete → Sprach-CABs unbestätigt; WinRE-Aktualität über SafeOS Dynamic Update sicherstellen.
- **Satelliten:** werden geprüft (ZUS-11), nicht automatisch nachinstalliert.
- **Default-User-Fallback** (Registry-Kopie aus .DEFAULT) ist unbestätigt; `intl.cpl` wird bewusst nicht genutzt (Microsoft: für migrierte Settings nicht unterstützt).
- **Nerdio `NME_PARAMETER`, HYDRA-Parameter/Secrets/Exit-Codes:** nicht vollständig belegt → Testplan.
- **Inbox-Apps:** keine Aktualisierung über das Inbox-Apps-ISO.
- **Nicht im Scope:** Sprachen für M365 Apps/Office (ODT), Teams, FSLogix-Profil.
- **Zeitzonen-Umleitung (AVD):** GPO *Computer Configuration → Administrative Templates → Windows Components → Remote Desktop Services → Remote Desktop Session Host → Device and Resource Redirection → Allow time zone redirection* (`fEnableTimeZoneRedirection`, [Policy CSP](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-admx-terminalserver)) – nicht Teil des Scripts.
- **MS-16:** Nach Änderung der Anzeigesprache müssen sich Benutzer über das Startmenü abmelden und neu anmelden.

## 14. Bewusste Abweichungen von der Vorgabe

| Vorgabe | Umsetzung | Grund |
|---|---|---|
| Parameter-Sets für `-RebootIfRequired`/`-ForceReboot` | Prüfung beim Start (FAILED vor jeder Änderung) | Konflikt mit Nerdio-Parameterset `NME_PARAMETER` vermeiden (D2) |
| `Add-WindowsPackage -PackagePath <Ordner>` | Ziel-MSU als PackagePath, Ordner für Checkpoint-Erkennung | Microsoft-Doku Checkpoint-CUs |
| intl.cpl-Fallback (alt) | Registry-Fallback | Microsoft: intl.cpl für migrierte Settings nicht unterstützt |
| Dateinamen ohne Trennzeichen | `_` zwischen den Bestandteilen | Lesbarkeit (D8) |
| Zusätzliche Parameter | `MaxRuntimeMinutes`, `InstallTimeoutMinutes`, `InstallRetryCount`, `AllowTemporaryWuPolicyBypass`, `AutoTimeZoneUpdate`, `IncludeWinRELanguage`, `CollectWindowsUpdateLog`, `IsoPath`, `SecureVars` | D10 |

## 15. Statische Prüfung

Ausschließlich statisch (kein Ausführen der Scripts): Parser, PSScriptAnalyzer 1.23 (inkl. `PSUseCompatibleSyntax`/`PSUseCompatibleCommands` für Windows PowerShell 5.1), Pester mit Mocks.

```powershell
Invoke-ScriptAnalyzer -Path .\Install-CDTGermanLanguage.ps1 -Settings .\PSScriptAnalyzerSettings.psd1
Invoke-ScriptAnalyzer -Path .\tests -Settings .\tests\PSScriptAnalyzerSettings.Tests.psd1
Invoke-Pester -Script .\tests     # Pester 4.10 oder 5.x
```

Ergebnis (2026-10-02): Parser 0 Fehler (alle Scripts); PSScriptAnalyzer 0 Funde (`Install-CDTGermanLanguage.ps1`, `New-CDTLanguageRepository.ps1`, `Test-CDTExitCodeHandling.ps1`, Tests); Pester 84/84 bestanden. Alle `.ps1` sind reines ASCII (Windows PowerShell 5.1 liest Dateien ohne BOM als ANSI).
