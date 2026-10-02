# Testplan – CDT Sprachpaket de-DE (Install-CDTGermanLanguage.ps1 v4.0.0)

Testumgebung: frische Azure-Marketplace-VMs **Windows 11 Enterprise multi-session** 24H2 (26100), 25H2 (26200), 26H2 (26300),
jeweils mit aktuellem Patchstand. Ausführung über Nerdio Scripted Action **und** HYDRA-Script. Nach jedem Test:
Hauptlog, Fehlerlog, Compliance-CSV und ggf. Diagnose-Ordner sichern.

Legende Ergebnis: ✅ bestanden · ❌ fehlgeschlagen · ⏳ offen

## 0. Vorab

| # | Test | Erwartung | 24H2 | 25H2 | 26H2 |
|---|---|---|---|---|---|
| 0.1 | `Test-CDTExitCodeHandling.ps1` mit 0 / 3010 / 3020 (Nerdio + HYDRA) | Bewertung je Plattform dokumentiert (README Abschnitt 3); `-RebootRequiredExitCode` festgelegt | ⏳ | ⏳ | ⏳ |
| 0.2 | Script mit `-RebootIfRequired -ForceReboot` | Exit 3050, keine Änderung (Zustand/Registry unverändert) | ⏳ | ⏳ | ⏳ |
| 0.3 | Zwei Läufe gleichzeitig starten | Zweiter Lauf: Exit 3050 „anderer Lauf aktiv“ | ⏳ | ⏳ | ⏳ |
| 0.4 | Nerdio: Parameterblock inkl. `SecureVars` (`NME_PARAMETER`) | Felder erscheinen; `$SecureVars` wird übergeben (Log: `SecureVars=True`) | ⏳ | – | – |

## 1. Quellen-Kette (jede Stufe einzeln erzwungen)

| # | Test | Erwartung | 24H2 | 25H2 | 26H2 |
|---|---|---|---|---|---|
| 1.1 | Stufe 1: `-Mode Install` mit Internet, ohne Repository | `InstallSource=1`, LP + 5 FoDs Installed/InstallPending, Exit 3010 | ⏳ | ⏳ | ⏳ |
| 1.2 | Stufe 2 UNC: `-RepositoryPath \\…\26100 -StorageAccountKey …`, WU blockiert (NSG/Policy) | `InstallSource=2`, Share nach Kopie getrennt, kein cmdkey-Eintrag, MS-07 PASS | ⏳ | ⏳ | ⏳ |
| 1.3 | Stufe 2 ZIP: `-RepositoryZipUrl <SAS>` (Secure Variable) | SAS nirgends im Log/Transcript/CSV (Suche nach `sig=`) | ⏳ | ⏳ | ⏳ |
| 1.4 | Stufe 2 mit falschem Manifest (Build 22621 / manipulierte Datei) | Stufe 2 verworfen (Log „Hauptbuild“ bzw. „SHA256“), Fallback Stufe 3 | ⏳ | ⏳ | ⏳ |
| 1.5 | Stufe 3: `-ForceIsoSource` | HEAD/Speicher/Proxy geloggt, Download mit Durchsatz, ISO danach gelöscht und ausgehängt, MS-11 PASS | ⏳ | ⏳ | ⏳ |
| 1.6 | Stufe 3 mit `-IsoPath` (umbenanntes ISO ohne Build im Namen) | WARN, Build über Sprachpaket-Version geprüft | ⏳ | ⏳ | ⏳ |
| 1.7 | Ohne Internet (NSG deny Internet), ohne Repository | Stufe 1 scheitert mit geloggtem HRESULT, Stufe 3 scheitert → FAILED 3050 + Diagnose-Ordner | ⏳ | ⏳ | ⏳ |
| 1.8 | Ohne Internet, mit Repository (Private Endpoint Azure Files) | Stufe 2 erfolgreich | ⏳ | ⏳ | ⏳ |
| 1.9 | WSUS-Policy gesetzt (`UseWUServer=1`, `DisableWindowsUpdateAccess=1`) + `-AllowTemporaryWuPolicyBypass` | Policies während Stufe 1 entschärft, danach exakt wiederhergestellt (ZUS-13 PASS) | ⏳ | ⏳ | ⏳ |
| 1.10 | Abbruch während Stufe 1 (VM hart neu starten) | Nächster Lauf: Policy-Backup und Installer-Tasks zurückgerollt | ⏳ | ⏳ | ⏳ |
| 1.11 | `-ExcludeFeatures OCR,Handwriting` | Nur Basic/TTS/Speech; MS-12 bewertet nur gewählte FoDs | ⏳ | – | – |

## 2. Idempotenz und Mode Auto über mehrere Reboots

| # | Test | Erwartung | 24H2 | 25H2 | 26H2 |
|---|---|---|---|---|---|
| 2.1 | Auto ohne Parameter, nach jedem Exit 3010 neu starten und erneut ausführen | Folge: Install (3010) → ReapplyLcu (3020 ohne Quelle bzw. 3010 mit Quelle) → Validate (0) | ⏳ | ⏳ | ⏳ |
| 2.2 | Auto zweimal ohne Neustart dazwischen | Zweiter Lauf: „WaitForReboot“, keine Änderung, Exit 3010 | ⏳ | ⏳ | ⏳ |
| 2.3 | Zweitlauf `-Mode Install` nach vollständiger Installation | Keine Paketinstallation, „bereits vollständig“, Ländereinstellungen „entsprechen bereits dem Soll“ | ⏳ | ⏳ | ⏳ |
| 2.4 | Laufzeitbudget `-MaxRuntimeMinutes 20` mit Stufe 3 | PARTIAL (3030), nächster Lauf setzt fort | ⏳ | – | – |

## 3. ReapplyLcu (MS-08)

| # | Test | Erwartung | 24H2 | 25H2 | 26H2 |
|---|---|---|---|---|---|
| 3.1 | Ohne Quelle | WARN mit KB + Catalog-Link, Exit 3020, PreSysprep → 3040 | ⏳ | ⏳ | ⏳ |
| 3.2 | `-LcuPath` mit Ziel- + Checkpoint-MSU (aktuelle KB) | Add-WindowsPackage mit Ziel-MSU, Exit 3010, nach Reboot MS-08 PASS | ⏳ | ⏳ | ⏳ |
| 3.3 | `-LcuPath` nur Ziel-MSU, Checkpoint fehlt | Fehler 0x800F0838 erkannt und erklärt | ⏳ | – | – |
| 3.4 | `-LcuUrl` (zwei URLs, Secure Variable) | Download beider MSU, Installation | ⏳ | – | – |
| 3.5 | Fremddatei im LCU-Ordner | Abbruch vor DISM („Fremddatei“) | ⏳ | – | – |
| 3.6 | `-UseWindowsUpdateForNewerLcu` | Neueres CU über WUA installiert oder WARN „kein Update angeboten“ | ⏳ | – | – |
| 3.7 | Neueres LCU nach Sprachinstallation über WU installiert | MS-08 automatisch erfüllt (`NewerLcuInstalled`) | ⏳ | ⏳ | ⏳ |
| 3.8 | Verhalten bei identischem LCU (0x800F081E?) dokumentieren | Ergebnis im README Abschnitt 8 nachtragen | ⏳ | ⏳ | ⏳ |

## 4. PreSysprep

| # | Test | Erwartung | 24H2 | 25H2 | 26H2 |
|---|---|---|---|---|---|
| 4.1 | Bewusst offener Punkt: MS-02 (LPRemove) wieder aktivieren | Exit 3040, MS-02 FAIL in CSV und Summary | ⏳ | ⏳ | ⏳ |
| 4.2 | Store-App für Build-Admin aktualisieren / LXP per Settings holen | MS-10 FAIL mit Paketnamen, Exit 3040 | ⏳ | ⏳ | ⏳ |
| 4.3 | 4.2 + `-CleanupAppxForSysprep` | Blocker entfernt, Exit 0, Sysprep läuft durch | ⏳ | ⏳ | ⏳ |
| 4.4 | Ausstehender Neustart | ZUS-10 FAIL, Exit 3040 | ⏳ | – | – |
| 4.5 | Nerdio „Set as image“ mit PreSysprep-Scripted-Action, Fall 4.1 | Set as image bricht ab | ⏳ | – | – |
| 4.6 | HYDRA-Imaging mit PreSysprep in der Collection, Fall 4.1 | Imaging startet nicht | ⏳ | – | – |

## 5. Neustart-Optionen

| # | Test | Erwartung | 24H2 |
|---|---|---|---|
| 5.1 | `-RebootIfRequired` mit Reboot-Bedarf | Exit-Code zurückgegeben, Neustart nach 60 s (Ereignis 1074, Grund p:4:2), `PlannedReboot` gesetzt | ⏳ |
| 5.2 | `-RebootIfRequired` ohne Reboot-Bedarf | Kein Neustart | ⏳ |
| 5.3 | `-ForceReboot` bei SUCCESS | Neustart erzwungen | ⏳ |
| 5.4 | `-ForceReboot` bei FAILED (ohne/mit `-ForceRebootOnError`) | kein Neustart / Neustart | ⏳ |
| 5.5 | Nerdio-CSE mit `-RebootIfRequired` (nur zur Dokumentation) | Verhalten der CSE dokumentieren | ⏳ |

## 6. Sysprep/Capture und Session Host

| # | Test | Erwartung | 24H2 | 25H2 | 26H2 |
|---|---|---|---|---|---|
| 6.1 | Sysprep/Capture über Nerdio bzw. HYDRA | erfolgreich, keine Panther-Fehler | ⏳ | ⏳ | ⏳ |
| 6.2 | Session Host aus Image, Login **neuer** Benutzer | Anzeige Deutsch, Formate dd.MM.yyyy / 1.234,56, Tastatur nur Deutsch (QWERTZ, kein EN), Zeitzone W. Europe, Region Deutschland | ⏳ | ⏳ | ⏳ |
| 6.3 | Anmeldebildschirm/Systemkonten | Deutsch | ⏳ | ⏳ | ⏳ |
| 6.4 | Mehrere Tage nach Deployment | Sprachpaket/FoDs nicht entfernt (LPRemove/Uninstallation aus) | ⏳ | ⏳ | ⏳ |
| 6.5 | Notepad (system), PowerShell ISE, Print Management | deutsch lokalisiert (ZUS-11) | ⏳ | ⏳ | ⏳ |
| 6.6 | Zeitzonen-Umleitung (GPO) aktiv | Sitzung zeigt Client-Zeitzone | ⏳ | – | – |

## 7. Nach dem nächsten Patchday

| # | Test | Erwartung |
|---|---|---|
| 7.1 | Master-Image patchen (neues LCU), `-Mode Validate` | MS-06/MS-12 PASS, Sprachpakete unverändert |
| 7.2 | `-Mode PreSysprep` vor neuem Capture | Exit 0 |
| 7.3 | Neuer Session Host, neuer Benutzer | wie 6.2 |
| 7.4 | Bei neuem OS-Release (z. B. 26H2 → Folgerelease) | Build-Prüfung: WARN bei unbekanntem Build; Repository ggf. neu erzeugen |

## 8. Statische Prüfung (bereits durchgeführt)

| Prüfung | Ergebnis (2026-10-02) |
|---|---|
| Parser (`[Parser]::ParseFile`) aller Scripts | 0 Fehler |
| PSScriptAnalyzer 1.23 (inkl. Kompatibilität PS 5.1) | 0 Funde |
| Pester 4.10 (nur Mocks) | 84/84 bestanden |
