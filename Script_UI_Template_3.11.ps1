<#
╔══════════════════════════════════════════════════════════════════════════════════╗
║  PSC POWERSHELL GUI TEMPLATE                                                     ║
║  Version: 3.14.0 (Template, 10. Oktober 2026)                                                        ║
║  Zweck: Referenzvorlage für KI-gestützte Erstellung neuer PowerShell-GUI-Skripte ║
║                                                                                  ║
║  ANLEITUNG FÜR KI-MODELLE:                                                      ║
║  Versionierte Bausteinbibliothek; Module und Grenzen siehe Einbauverzeichnis.  ║
║  Beim Erstellen eines neuen Skripts:                                             ║
║  1. Kopiere die benötigten Sektionen aus diesem Template                         ║
║  2. Passe die mit [PLACEHOLDER] markierten Stellen an                            ║
║  3. Entferne nicht benötigte optionale Sektionen (markiert mit [OPTIONAL])       ║
║  4. Halte die Reihenfolge der Sektionen (1-7) ein                               ║
║                                                                                  ║
║  ARCHITEKTUR-ÜBERSICHT:                                                          ║
║  ┌─────────────────────────────────────────────────────────────────────┐         ║
║  │ 1. Globale Konfiguration (Assemblies, AppName, Registry, Pfade)   │         ║
║  │ 2. Hilfsfunktionen (Parse, Convert, Normalize, Merge, Debug)      │         ║
║  │ 3. Datenpersistenz (Load, Save, Daily-Data, AdditionalDB, Import) │         ║
║  │ 4. Kernlogik / Berechnungen (domänenspezifisch)                   │         ║
║  │ 5. UI-Popups (Settings, Restore, Edit, Filter-Popups, Export)     │         ║
║  │ 6. Hauptformular (Show-MainForm mit Tabs & Events)                │         ║
║  │ 6Z. Zusatz-Patterns für das Hauptformular (v3.9, dokumentiert)     │         ║
║  │ 6Q. BETA-Testmodus & Qualitätssicherung (v3.10, dokumentiert)     │         ║
║  │ 7. Skript-Einstiegspunkt (Show-MainForm Aufruf)                  │         ║
║  └─────────────────────────────────────────────────────────────────────┘         ║
║                                                                                  ║
║  KONVENTIONEN:                                                                   ║
║  - Script-Scope-Variablen: $script:variableName                                 ║
║  - Zentrale App-Identität: $script:AppName (für Registry, Ordner, UI, Backups)  ║
║  - Registry-Pfad: HKCU:\Software\PSC\$($script:AppName)                        ║
║  - Datenverzeichnis: ~/$($script:AppName)/ mit data/ Unterordner                ║
║  - JSON: Tiefe je Schema; neue Speicherwege mit gepruefter Serialisierung                                ║
║  - PS1-Ausgabe: UTF-8 MIT BOM und CRLF; JSON-Schreiben siehe 2j                                                          ║
║  - GUI-Font: "Segoe UI"                                                          ║
║  - Fehler: Kern wirft; UI zeigt Dialog, Erfolg erst nach Dateicommit              ║
║  - ArrayList statt Array für dynamische Listen                                   ║
║  - Zahlen-Parsing: immer über Parse-Number (Komma/Punkt-tolerant)               ║
║  - Event-Handler: $script: Prefix für alle globalen Variablen verwenden          ║
║  - Versionierung: AppVersion bleibt rein; AppDisplayVersion fuer UI                            ║
║  - Longevity-Scores: Spezial-Formel-Dispatcher (z.B. [PHENOAGE], [INFLAMMAGING]) ║
║  - Einheiten-Normalisierung: KRITISCH bei klinischen Scores (US vs. DE-Einheiten)║
║  - Export-Popup: Kontext-agnostischer ScriptBlock-Provider (JSON+CSV+PDF)        ║
║  - Tab-Button-Enablement: state-abhängig via Add_Click der Trigger-Buttons       ║
║  - User-Konfig-Block: Steuerbare Feature-Toggles ganz oben im Script, vor        ║
║    den Assembly-Loads (z.B. ExportOpenFolderAfter, ExportAskOpenFile)            ║
║  - Post-Export-Routine: Invoke-PostExportAction zentral nutzen (DRY-Prinzip),    ║
║    damit alle Export-Endpunkte einheitliches Verhalten zeigen                    ║
║  - Persistenz: bei personenbezogenen Daten IMMER über Read-/Write-              ║
║    ProtectedJsonFile (DPAPI) statt Get-/Set-Content (Sektion 3h)                ║
║  - Stammdaten: jede Version, die Defaults ergänzt, trägt sich in                ║
║    $script:CatalogAdditions ein - sonst erreicht sie Bestandsinstallationen nie  ║
║  - Automatische Importe: NIE ungeprüft schreiben, Review-Dialog ist Pflicht      ║
║  - Re-Entry-Schutz: jedes programmatische Setzen von Control-Eigenschaften mit   ║
║    einem $script:...Busy/Suspend-Flag kapseln (Event-Kaskaden)                   ║
║  - Kodierte Werte: Code<->Klartext an genau EINER Stelle (Sektion 2i)           ║
║  - Layout-Kaskade: wächst eine GroupBox, wandern alle nachgelagerten Controls    ║
║    UND die Fensterhöhe in derselben Änderung mit                                 ║
║  - Schreiben: standardmaessig strikt atomar; Fehler bricht ab (Sektion 2j)       ║
║    Write-AtomicTextFile / Write-ProtectedJsonFile (Sektion 2j/3h) - nie direkt   ║
║    Set-Content auf die Zieldatei (Absturz = halb geschriebene Datei)             ║
║  - Datenbestand ersetzen (Import, Restore, Umzug, Neu-Speichern): ERST neuen     ║
║    Stand vollständig aufbauen und prüfen, DANN tauschen, bei Fehler Rückweg.     ║
║    Nie "erst löschen, dann schreiben" (Sektion 3e/3i/3o/3p)                      ║
║  - Unlesbare Dateien NIE löschen oder überschreiben, ohne vorher eine            ║
║    Rettungskopie anzulegen (Sektion 3a/3d/3e)                                    ║
║  - PS 5.1: Listen normalisieren; Ausnahme Komma-Return beachten -       ║
║    siehe Block PS-5.1-FALLEN unten (Pflichtlektüre vor jeder Änderung)           ║
║  - Event-Handler: Zustand explizit in $script: oder Control-/Dialogobjekt   ║
║    (keine lokalen Capture-Annahmen; kein GetNewClosure fuer Skriptfunktionen)            ║
║  - BETA-Tests: NIE gegen echte Daten - eigener Registry-Schlüssel und eigener    ║
║    Datenordner über $script:BetaMode (Sektion 0/1b/6Q)                           ║
║  - Bewertungen 0-100: an den Bereichen des Eintrags (Optimal/Referenz), nicht    ║
║    an zusätzlich hartcodierten Schwellen - sonst widersprechen sich die Ansichten║
╚══════════════════════════════════════════════════════════════════════════════════╝

KI-EINBAUVERZEICHNIS v3.14.0 (Abgleichbasis: Blood-Tracker v3.0.0)
Dieses Skript ist eine Referenz mit optionalen Modulen und Platzhaltern, keine fertige App.
Vor Uebernahme: Zweck, Abhaengigkeiten, Datenform und Ausgabe-/Fehlervertrag lesen.
Nur benoetigte Module kopieren; Funktionen nicht doppelt einfuegen. Keine automatische
Uebernahme von Blutmarkern, medizinischen Grenzwerten oder Blood-Tracker-Pfadkonstanten.

Modul / Sektion           | Abhaengigkeiten              | Stand / Einbaugrenze
Identitaet / 0,1b         | vor Registry und Pfaden      | App/Template/Anzeige getrennt
Konfiguration / 3a,3b     | 2c,2d,2j,2m,3h                 | explizite Feldliste anpassen
Striktes Schreiben / 2j   | 0 RequireAtomicWrites, Ordner          | fertig, Abbruch bei Replace-Fehler
JSON-Pruefung / 2m        | 0 AppJsonDepth               | fertig, Tiefe/Zyklen/Zahlentypen
Tagesstapel / 3q          | 2c,2e,2j,2m,3h; Callbacks   | fertig, ein Tag/eine Datei
Snapshot-Schreiber / 3c,e | vorhandene Tagesdaten        | Bestand; nicht parallel zu 3q
Messungen / 1k,3n,3r      | 0,2b,c,j,l,m,3h             | Schema 1/2, Sperren, Listenvertrag
Quellenmittel / 3r       | Messkatalog, JSON, AppWriter | separat; keine Verrechnung
Auswertung / 3r          | Tages-/Trainingsdaten        | YTD/6 Monate, Abdeckung/Abweichung
Navigation/Sortieren / 5m | WinForms, 0, Control-Zustand | wiederverwendbare UI-Bausteine
Mehrfacheingabe / 5n     | 5m,2m,3q; Fach-Callbacks    | Eingabe -> Pruefansicht -> Commit
Export / 5d             | 2j,2m,WinForms/Drawing      | Dialog, Dateiexport, PDF getrennt
Hauptformular / 6       | App-Datenmodell              | weiterhin anwendungsspezifische Beispiele
Dashboard/Ansichten / 5o | 0,2c/m,3a/b,5m; Provider    | Cache, Raster, Editor, Config-Persistenz
Release-Notes / 5p       | 2j,5m,5o; AppVersion/Notes   | Pruefung, Filter, Gruppen, Markdown, UI

VERSIONSVERTRAG:
- TemplateVersion beschreibt diese Bibliothek; AppVersion die erzeugte Anwendung.
- AppVersion ist eine reine x.y.z-Zeichenfolge; BETA-Anzeige in AppDisplayVersion.
- Header, Versionswert, neuer technischer Changelog und versionierter Dateiname zusammen
  aktualisieren. Publizierte Historie unveraendert lassen. Neue Funktion: Minor-Version.
- AppReleaseNotes passend zur Ziel-App oben ergaenzen; Test-AppReleaseNotes prueft
  Version/Datum/Typen und unveraenderte Veroeffentlichungen. App-Beispiel ersetzen.
- TemplateReleaseNotes beginnt mit 3.14.0; aeltere Historie bleibt im technischen
  Changelog. Bibliotheks- und App-Releases sind getrennte, explizite Datenquellen.
- Blood-Tracker hat einen eigenen Starter-Vertrag ($Version und ersetzbare Pfadtexte).
  Diesen bei Arbeiten an Blood-Tracker erhalten, nicht auf alle Ziel-Apps uebertragen.

KONFIGURATIONSVERTRAG:
- In diesem Hauptbeispiel ist $script:data = Load-Config die Konfigurationswurzel.
  Optionale Fachbeispiele mit $script:data.Config.Markers erwarten eine andere Form:
  beim Einbau bewusst adaptieren; nicht beide Formen unverbunden mischen.
- Neuer persistenter Schluessel: Default, Laden/Merge/Migration, Rueckgabe und explizite
  Save-UserData-Feldliste gemeinsam erweitern. Fehlender Altschluessel -> Default.
- Vorhandenes false, 0 und leere Liste nicht per Wahrheitspruefung als fehlend ersetzen.
  Schluessel-Existenz und Datentyp getrennt pruefen; falsche Typen melden/sichern.
- Ein Roundtrip-Test je neuem Schluessel: Altbestand ohne Feld, gespeicherter eigener
  Wert, 0/1/mehrere Listenelemente und erneuter Start. Unbekannte Felder nur nach
  ausdruecklicher Schemaentscheidung uebernehmen oder verwerfen.
- Settings/Categories sind Beispiele der Save-Feldliste; Items ist NICHT automatisch
  Konfiguration. Katalogdaten und Messdaten zuerst fachlich zuordnen.

SPEICHER- UND UI-VERTRAG:
- Neue reine Speicherfunktionen werfen terminierende Fehler, zeigen keine Dialoge.
  Save-UserData/Save-DailyData in neuen Aufrufern mit -ThrowOnError verwenden.
- Write-AppJsonFile reicht -RequireAtomic durch Klartext und DPAPI weiter. Standard
  true; bei false ist der Kompatibilitaets-Fallback ausdruecklich NICHT atomar.
- Save-DailyItems erzwingt strikten Modus, prueft den Bestand unter Schreibsperre,
  verwirft den ganzen neuen Stapel bei Duplikaten/Fehlern und schreibt genau einmal.
- Atomarer Dateiaustausch ersetzt keine Mehrdatei-Transaktion, Backups oder Zusagen
  zur Stromausfallsicherheit aller Dateisysteme. Parallelzugriffe brauchen ein
  gemeinsames Sperrprotokoll (3q); Snapshot-Schreiber verwenden dieses noch nicht.
- Erst fachlich vorbereiten/pruefen, dann speichern; erst danach In-Memory-Daten und
  Anzeige erneuern, Erfolg zeigen, Eingaben leeren. Bei Anzeigefehler nach Dateierfolg
  nicht blind erneut speichern. Keine Erfolgsmeldung nach abgefangenem Schreibfehler.
- Hauptformular und Fachmodule enthalten weiterhin PLACEHOLDER: Der Hinzufuegen-Handler
  speichert ohne angepassten Einbau noch nichts. Vor produktiver Nutzung vervollstaendigen.
- Exportdialog und neue UI-Module verwenden expliziten Zustand. Historische Changelogs
  mit GetNewClosure sind keine aktuelle Empfehlung. Uebrige alte Formularbeispiele
  bleiben PLACEHOLDER; insbesondere lokale Handler-Daten vor produktivem Einbau adaptieren.
- SYSTEM-Tools brauchen eigene feste Daten-/Logpfade und passende Identitaet. Die
  interaktive Vorlage mit HKCU/UserProfile/DPAPI CurrentUser nicht unveraendert als
  SYSTEM-Dienst einsetzen. Keine Secrets; IDs hoechstens letzte vier Zeichen loggen.

PS-5.1-FALLEN (Pflichtlektüre - alle real aufgetreten im Blood-Tracker v2.26.1-v2.33.0):
 1. EIN-ELEMENT-ERGEBNISSE: Pipeline, Where-Object, Sort-Object oder eine Funktions-
    rückgabe mit genau EINEM Treffer liefert das Objekt selbst, kein Array. Ein
    [PSCustomObject] hat in PS 5.1 KEIN .Count, $x[0] liefert Unsinn ("Letzter Wert"
    fehlte bei nur einem Messwert).  ->  IMMER $x = @(...)   (0 Treffer -> leeres Array)
 2. "$wert = if (...) { $a } else { $b }" gibt $a über die Pipeline aus: eine Liste mit
    EINEM Element wird zum Einzelwert, eine leere Liste zu $null (Bugfix 2c - der BMI
    wurde nach einem Neustart nie mehr berechnet).  ->  Listen direkt zuweisen.
 3. KOMMA-RÜCKGABE NICHT MIT @() MISCHEN: Gibt eine Funktion "return , $liste" zurück,
    liefert @(Get-X) eine VERSCHACHTELTE Liste - .Count ist dann IMMER 1, auch bei 0
    Einträgen. TEMPLATE-REGEL: Funktionen geben Listen normal zurück (return @($liste)),
    Aufrufer umschließen IMMER mit @(Get-X). Komma-Rückgabe nur, wenn der Aufrufer
    ausdrücklich OHNE @() zuweist - dann im .NOTES der Funktion dokumentieren.
 4. [Math]::Round(<int>, 0) wählt die decimal-Überladung -> Ergebnis [decimal]. Prüfungen
    wie "-is [double]" schlagen dann fehl (fehlende Ampelfarbe).  ->  [Math]::Round([double]$x, n)
 5. [Math]::Round rundet standardmäßig mathematisch ("Banker's Rounding": 82,25 -> 82,2).
    Kaufmännisch:  [Math]::Round($x, 1, [MidpointRounding]::AwayFromZero)
 6. Doppelte Anführungszeichen expandieren Variablen SOFORT beim Laden des Scripts:
    "%0% / ($personal.Groesse)" wird zu "%0% / (.Groesse)".  ->  Formeln, Platzhalter und
    Regex-Muster mit $ IMMER in einfache Anführungszeichen.
 7. ">" und "<" sind Umleitungs-Operatoren: "if ($a > $b)" vergleicht nicht, sondern
    schreibt eine Datei namens $b.  ->  nur -gt / -lt / -ge / -le.
 8. Befehlsmodus: "-Wert -1.0" an einen untypisierten Parameter kommt als TEXT "-1.0" an
    (Vergleiche werden dann zu Textvergleichen).  ->  Parameter typisieren oder konvertieren.
 9. Event-Handler laufen in einem eigenen Scope: "$changesMade = $true" im Handler erzeugt
    eine LOKALE Variable - die umgebende Funktion sieht weiter $false (Bugfix 5c).
    ->  $script:-Variablen. Handler-Argumente ohne param() lesen:  $e = $args[1]
10. Join-Path akzeptiert in PS 5.1 nur 2 Pfad-Argumente  ->  verschachteln.
11. [double]::TryParse akzeptiert "NaN", "Infinity" und - mit NumberStyles.Any - auch "(5)"
    und "5-" als -5  ->  NumberStyles.Float + IsNaN/IsInfinity prüfen (Bugfix 2b).
12. Move-Item verschiebt Ordner nur innerhalb DESSELBEN Laufwerks (Microsoft Learn,
    Move-Item > Notes)  ->  Datenumzug per Kopieren + Prüfen + Umschalten (Sektion 3p).
13. ConvertFrom-Json + ConvertTo-Hashtable liefern je nach Tiefe Hashtable ODER
    PSCustomObject  ->  Zugriffe auf Unterobjekte für beide Typen schreiben (Sektion 3a).
14. Jeder nicht zugewiesene Rückgabewert landet in der FUNKTIONSAUSGABE: MessageBox::Show,
    ShowDialog(), ArrayList.Add(), Items.Add() ... -> eine Funktion liefert dann z.B.
    @(DialogResult, Config) statt der Config (Blood-Tracker: Load-Config im Fehlerfall).
    ->  In Funktionen mit Rückgabewert IMMER [void] / | Out-Null / $null = davor.

15. [string]-Parameter wandeln $null in '' um. Fehlend/leerer Text nur vor der
    Typumwandlung unterscheiden; nicht durch zufaellige Wahrheitspruefungen.
16. Typografische doppelte Anfuehrungszeichen koennen PS-Strings beenden. Solche
    UI-Texte in einfache Anfuehrungszeichen setzen; keine PS-7-Operatoren einfuehren.
17. Hashtable-Reihenfolge ist kein Vertrag. Signaturen/Pruefsummen rekursiv nach
    Schluesseln kanonisieren; Listen nur sortieren, wenn Reihenfolge fachlich egal ist.
18. JSON-Tiefe in PS 5.1 vorab pruefen (2m); ConvertTo-Json kann tiefe Daten kuerzen.
19. Handler benutzen expliziten Zustand und $args[0]/$args[1]; $sender/$event/
    $eventArgs nicht als eigene Variablen belegen. Ressourcen in finally freigeben.
20. Keine automatische DPI-Logik/EnableVisualStyles einfuehren. GUI-Aenderungen
    getrennt testen; reine Engine-Tests ohne Formularstart mit synthetischen BETA-Daten.

CHANGELOG Template v3.14.0 (2026-10-10; Blood-Tracker v3.0.0, Schritt 4/4):
- NEU 5o: generisches Dashboard mit Modell-/Signatur-Provider, optionalem Standard-
  Renderer, Kachelraster, festen/dynamischen Ansichten, Navigation und Leerzustaenden.
- NEU: eigene Ansichten erstellen/bearbeiten/loeschen; doppelte Namen/Eintraege
  verhindern, unbekannte Eintraege erhalten, Speichern vor In-Memory-Aenderung.
- NEU 3a/3b: DashboardViews in Default, Ladepruefung/Rueckgabe und Save-Feldliste.
  Ungueltige Ansichten werfen vor automatischem Speichern, kein stilles Verwerfen.
- NEU: SHA256 ueber gepruefte kanonische Daten; sortierte Schluessel, escaped Strings,
  keine stille Tiefenkuerzung; Tagesdatum/Ansichten Bestandteil des Dashboard-Caches.
- BUGFIX 2m: echte Dictionary-Schluessel via psbase lesen; ein Datenfeld Keys darf
  die JSON-Pruefung von Tiefe/Zyklen nicht verdecken.
- NEU 5p: strukturierte Release-Notes, Konsistenz-/Historienpruefung, Suche/Typfilter,
  numerische Sortierung, Versionsgruppen, Detailansicht und atomarer Markdown-Export.
- HINWEIS: Einbauverzeichnis/Callback-Vertraege abgeglichen. Optionale Altbeispiele
  bleiben anwendungsspezifisch; das Template ist keine fertige Fachanwendung.

CHANGELOG Template v3.13.0 (2026-10-10; Blood-Tracker v3.0.0, Schritt 3/4):
- NEU 5m: zweizeilige Kategorienavigation mit erhaltenen Seiteninstanzen, zuletzt
  gewaehltem Reiter je Kategorie und programmatischem Wechsel ueber eine Funktion.
- NEU: aktive Reiter mit dezenter Linie/fetter Schrift; Farben/Schalter in Sektion 0.
- NEU: Tabellensortierung fuer Zahlen/Datum/Text, Rangspalten, Gruppen und Klickfolge
  aufsteigend/absteigend/Standard; Zustand je Control statt globaler Namensschluessel.
- NEU 5n: generische Mehrfacheingabe mit Datum, Zeilen, Suche/Aliasen, Auswahlwerten,
  Einheiten, Notizen und Pruefansicht; Fachregeln ueber dokumentierte Callbacks.
- BUGFIX 5d: GetNewClosure entfernt; Dialog und Druckjobs mit explizitem Zustand.
  JSON/CSV strikt atomar, alle Spalten erhalten, PDF-Ressourcen in finally freigegeben.
- HINWEIS: UI-Bausteine unabhaengig pruefbar; kein Umbau der gesamten Beispiel-App.
  Dashboard, Ansichten und Release-Notes folgen in Schritt 4.

CHANGELOG Template v3.12.0 (2026-10-09; Blood-Tracker v3.0.0, Schritt 2/4):
- NEU 3r: wiederverwendbare Mehrfachmessungen mit Datum/Uhrzeit, Quelle/Geraet,
  Kontext, Details und Hinweisen. Eigene Kategorien ueber zentralen Katalog erweiterbar.
- NEU: Aktivitaets-Tageswerte, Cardio je Training, separat gespeicherte Quellenmittel
  mit exakten Zeitraumgrenzen, bekannter/unbekannter Anzahl und Messverfahren.
- NEU: YTD-/Sechsmonats-Auswertung mit Datenabdeckung, Quellenvorrang, Abweichungen
  und nicht vergleichbaren Werten. Keine medizinische Bewertung neuer Messgroessen.
- ANPASSUNG 3n: Schema 1 fuer bestehende Einzel-Tagesdaten bleibt erhalten; Schema 2
  fuer Mehrfachmessungen. Sperren, Bestandsvalidierung und striktes Schreiben fuer
  alle Messungsschreiber. Defekte/ unbekannte Formate blockieren Aenderungen.
- ANPASSUNG: einheitliche Pipeline-Listen (Aufrufer mit @()), keine Blood-Tracker-
  Komma-Returns. Speicherung ueber Template-Klartext/DPAPI-Schalter und Tiefepruefung.
- NEU Sektion 0: Messkategorien, eigene Katalogdefinitionen, Herkunftsverfahren,
  technische Warnschwellen und Anzeige-Dezimalstellen zentral konfigurierbar.
- HINWEIS: keine GUI/Importautomatik. UI-Muster und Dashboard folgen in Schritten 3/4.

CHANGELOG Template v3.11.0 (2026-10-09; Blood-Tracker v3.0.0, Schritt 1/4):
- NEU: KI-Einbauverzeichnis mit Modulstand, Abhaengigkeiten und Daten-/Fehlervertraegen.
- ANPASSUNG: TemplateVersion, AppVersion und AppDisplayVersion getrennt; BETA aendert
  nur AppName/Anzeigetext, nicht die fachliche Versionsnummer.
- NEU 2m: JSON-Tiefen-/Zykluspruefung vor dem Schreiben; keine stille Datenkuerzung.
- ANPASSUNG 2j/3h: RequireAtomic standardmaessig aktiv; kein Copy-Fallback im strikten
  Modus. Eindeutige Temp-/Backup-Dateien; ausdrueckliche nichtatomare Kompatibilitaet.
- NEU 3q: generische Tages-Stapelspeicherung mit Schreibsperre, Bestandspruefung,
  Validierungs-/Identitaets-Callbacks und Alles-oder-nichts je Tagesdatei.
- ANPASSUNG 3a/3b/3c: gepruefte JSON-Serialisierung; Save-Funktionen bieten ThrowOnError.
- HINWEIS: Messengine, UI-Muster und Dashboard/Release-Notes folgen in Schritten 2-4.

CHANGELOG Template v3.10 (Abgleich mit Blood-Tracker v2.33.0):
- BUGFIX 2c: ConvertTo-Hashtable - "$value = if (...)" machte Listen mit EINEM Eintrag zum
  Einzelwert und leere Listen zu $null (PS-5.1-FALLE 2).
- BUGFIX 2b: Parse-Number - NumberStyles.Float statt Any, NaN/Infinity werden abgewiesen
  ("(5)" und "5-" wurden bisher als -5 gelesen).
- BUGFIX 4h: Convert-ToLongevityScore - [Math]::Round([double]...) statt Round(int) (decimal).
- BUGFIX 5c: Show-EditPopup - nur gelöschte Zeilen (ohne Wertänderung) meldeten "Cancel",
  die Löschung wurde nicht gespeichert (Handler-Scope, PS-5.1-FALLE 9). Löschungen werden
  jetzt vorgemerkt und erst beim Übernehmen angewendet ("Abbrechen" ändert nichts mehr).
  Zusätzlich die drei Buttons in EINER Reihe, gleiche Größe, Gesamtbreite = Tabellenbreite.
- BUGFIX 4d: Calculate-InflammAgingScore - [Math]::Min(100, x) wählte Min(int,int) und
  rundete die Teilscores; PLR jetzt mit ABSOLUTEN Lymphozyten (5. Wert Leukozyten).
- KORREKTUR 4e: TyG-Formel ln(TG x Glu) / 2 passend zum Grenzwert 4,68.
- 6d: Trendlinie per Series.Insert(0) UNTER der Messwert-Linie (Tooltips bleiben erreichbar).
- BUGFIX 3e: Save-AllHistoricalData - 3 Phasen (vorbereiten -> atomar schreiben -> erst dann
  verwaiste Dateien löschen) statt "alles löschen, dann schreiben" (Datenverlust bei Fehler).
- BUGFIX 3a: Load-Config - eine unlesbare Config (beschädigt / DPAPI eines anderen PCs) wird
  vor dem Weiterarbeiten mit Standardwerten als Rettungskopie gesichert; bisher wurde sie
  beim nächsten Speichern still überschrieben. Unlesbarer Inhalt löst jetzt eine Meldung aus.
- BUGFIX 3a/5b: Load-Config (Fehlerfall) und Show-FilterSettingsPopup gaben zusätzlich das
  DialogResult zurück (PS-5.1-FALLE 14) - Ausgaben jetzt unterdrückt.
- BUGFIX 3d: Load-AllHistoricalItems - Fehler je Datei; eine defekte Datei bricht das Laden
  nicht mehr ab, unlesbare Dateien werden geschützt (nie gelöscht) und EINMAL gemeldet.
- BUGFIX 3i: Import-AesBackup - Inhalt vorab prüfen, Staging-Ordner + Austausch per
  Umbenennen + Rückweg statt Löschen des Datenordners vor dem Schreiben.
- BUGFIX 5a: "Datenpfad ändern" über Move-DataDirectorySafe (3p), "Sicherung
  wiederherstellen" über Get-UnreadableJsonFiles + Invoke-SafeDataRestore (3o).
- NEU 2j: Write-AtomicTextFile (Temp-Datei + [IO.File]::Replace + Vorversion, 3 Versuche,
  Fallback, Aufräumen) und Write-AppJsonFile (Klartext oder DPAPI per Schalter).
- NEU 2k: Get-AppPathKey - normalisierter Pfad-Vergleichsschlüssel.
- NEU 3h: Write-ProtectedJsonFile schreibt atomar (über Write-AtomicTextFile).
- NEU 3k: Korrektur-Migration ($script:CatalogCorrections: Fields + OnlyIf) für fachlich
  korrigierte BESTEHENDE Einträge; Load-Config ergänzt neue Unterfelder (Hashtable UND
  PSCustomObject) mit Defaults.
- NEU 3n: Getrennte Ablage für Zusatz-Messungen (reservierter Unterordner, Katalog mit
  Plausibilitätsgrenzen, Datums-/Dauer-Parser h/min, Datensatz-API). Listen werden normal
  zurückgegeben (keine Komma-Rückgabe, PS-5.1-FALLE 3 - neu dokumentiert).
- NEU 3o/3p: Invoke-SafeDataRestore, Get-UnreadableJsonFiles, Move-DataDirectorySafe.
- NEU 4o: Bereichsbasierte 0-100-Bewertung (Get-RangeScore) + Komposit-Score mit
  Mindestanzahl (Get-CompositeScore), kaufmännisch gerundet.
- NEU 4p: Geburtsdatum statt festem Alter (ConvertTo-AppDate, Get-AgeAtDate - Alter am
  jeweiligen Messtag in vollendeten Jahren).
- NEU 1f/1g/1j/1k: $script:CatalogCorrections, $script:ItemSearchBlocklist,
  $script:ItemPreferred (Vorrang vor Standard vor Fallback), Messungs-Ablage.
- NEU 2h: Suche in einer beliebigen Anzeigeliste (Get-ListItemTokens, Get-ListMatches,
  Resolve-ListSelection) + Sperrliste in allen Suchfunktionen.
- NEU 6n-6p: Such-ComboBox für eine Anzeige-/Filterliste (ohne Neuzeichnen beim Tippen,
  Enter/Esc/Leave/DropDown), Geburtsdatum-Feld mit Live-Altersanzeige, Dropdown mit
  stabilem Speicher-Schlüssel statt Anzeigetext.
- NEU 6Q: BETA-Testmodus ($script:BetaMode / PSC_BETA=1), Test-Config-Muster, QS-Checkliste
  (Parser, PSScriptAnalyzer mit PS-5.1-Profil, AST-Testharness, Ein-Element-Tests).
- NEU Sektion 0: $script:BetaMode. Sektion 1e: $script:UseDpapiEncryption.
- 3a/3d lesen über Read-ProtectedJsonFile (erkennt Klartext UND verschlüsselt);
  3b/3c/3e schreiben über Write-AppJsonFile.
- Update-Chart (6e): Datenreihe mit @() sortieren; "Letzter Wert" auch bei nur EINEM Wert.

CHANGELOG Template v3.9 (Abgleich mit Blood-Tracker v2.26.0):
- NEU: Sektion 3h - Transparente DPAPI-Verschlüsselung aller JSON-Dateien inkl.
  automatischer Klartext-Migration (Write-/Read-ProtectedJsonFile).
- NEU: Sektion 3i - Portables AES-256-Backup mit Passphrase (PBKDF2 100k/SHA256,
  Dateiformat [Salt 32][IV 16][Cipher]), Export + Import mit DPAPI-Re-Encryption.
- NEU: Sektion 3j - Unverschlüsselter Migrations-Export für PC-/Profilwechsel.
- NEU: Sektion 3k - Versionierte, additive Stammdaten-Migration
  (Merge-NewDefaultItems + $script:CatalogVersion/-Additions, Sektion 1f).
- NEU: Sektion 3l - Dokument-Archivierung je Datensatz (Namensschema
  YYYY-MM-dd_DOKUMENT[_n].ext, Mehrfach-Upload, strikter Datums-Filter).
- NEU: Sektion 3m - PDF-Text-Import-Pipeline (iTextSharp-Auto-Download von NuGet,
  Textextraktion, Alias-Map, Wert-Parser mit Konfidenz-Bewertung).
- NEU: Sektion 2h - Freitext-Suchindex mit Relevanz-Ranking (Get-ItemToken,
  Build-ItemSearchIndex, Get-ItemMatches, Resolve-ItemName).
- NEU: Sektion 2i - Kodierte/qualitative Werte: Code <-> Klartext an einer Stelle.
- NEU: Sektion 4k - Backup-Retention/Cleanup mit typgetrennten Zählern.
- NEU: Sektion 4l - Trend- und Abweichungs-Warnungen (Get-TrendWarnings).
- NEU: Sektion 4m - Korrelations-Screening mit Auto-Vorschlägen.
- NEU: Sektion 4n - Risiko-Score per logistischer Funktion inkl. Pflicht-Warnung
  zu Koeffizienten-Herkunft und Einheiten.
- NEU: Sektion 5i - Passphrase-Dialog (SecureString, optionale Bestätigung).
- NEU: Sektion 5j - Import-Review-Dialog mit Konfidenz-Kennzeichnung.
- NEU: Sektion 5k - Tab-spezifische Einstellungs-Popups mit dynamischer Höhe.
- NEU: Sektion 5l - Report-Korrekturen: Fußzeile auf JEDER Seite, erzwungener
  Seitenumbruch pro Section, Papierformat fest auf DIN A4 (nach Druckerwahl).
- NEU: Sektion 6Z (6i-6m) - Live-Filter-ComboBox mit Freitext-Auflösung,
  kontextabhängiger Eingabemodus, dynamisches Checkbox-Panel mit Master-Schalter,
  zentraler Update-ScriptBlock für abhängige Buttons, global sichtbare Buttons.
- NEU: Sektion 1f-1j - Katalog-Versionierung, Alias-Tabelle, kodierte Werte,
  Import-Ausschlusslisten, Fallback-Ketten für Berechnungen.
- ASSEMBLY: System.Security ergänzt (DPAPI/ProtectedData).
- PS-5.1-FALLE dokumentiert: Join-Path akzeptiert nur 2 Argumente.

CHANGELOG Template v3.8:
- NEU: Sektion 5h - AutoBackup-Konfigurations-Popup-Pattern (ZIP/Ordner/Beides mit
  intelligenter Checkbox-Synchronisation via SuspendEvent-Pattern).
- NEU: Sektion 4j - AutoBackup-Scheduler-Pattern (In-Process-Timer + Fälligkeits-
  Check, Intervalle: täglich/wöchentlich/monatlich/jährlich/bei Programm-Start).
- NEU: Registry-Export-in-Backup-Pattern. Nutzt reg.exe export für konsistente
  Sicherung des App-Config-Pfads. Essenziell für Restore auf anderem Gerät.
- PATTERN: Rekursions-Schutz bei Backup-Zielpfaden (Test-BackupPathSafe). Verhindert,
  dass Backup-Ziel unterhalb des Quell-Datenverzeichnisses liegt.
- PATTERN: Robocopy statt Copy-Item für inkrementelle Ordner-Backups (/E /R:1 /W:1).

CHANGELOG Template v3.7:
- NEU: User-Konfiguration-Block als eigene Sektion ganz oben im Script (vor den
  Assembly-Loads). Pattern für global steuerbare Feature-Toggles ($script:-Scope).
- NEU: Invoke-PostExportAction als zentrale Nach-Export-Routine (DRY-Prinzip).
  Vermeidet Code-Duplizierung über mehrere Export-Endpunkte hinweg.
- PATTERN: Feature-Toggles immer als $script:-Variablen am Script-Anfang deklarieren,
  damit sie sowohl außerhalb als auch innerhalb von Funktionen/Event-Handlern
  zugreifbar sind. Dokumentation über jeder Variable als Kommentar.

CHANGELOG Template v3.6:
- BUGFIX-PATTERN: PDF-Export mit 1-elementigen Daten. $data muss explizit als @()
  gecastet werden (Auto-Unwrapping), PrintPage-Handler via $script:-Variablen statt
  GetNewClosure() arbeiten lassen.
- NEU: Sektion 4g - Render-MarkerChartToImage (GDI+ Liniengrafik als Bitmap,
  ohne externe Chart-Libraries, einsetzbar in Print/PDF-Pipelines).
- NEU: Sektion 5g - Multi-Section-Report-Pattern (Section = Überschrift + Chart +
  Tabelle). Phasenbasierter PrintPage-Handler mit Script-Scope-State für
  zuverlässige Seitenumbrüche zwischen Sections.

CHANGELOG Template v3.5:
- NEU: PDF-Export-Pattern in Sektion 5d via "Microsoft Print to PDF"-Drucker
- NEU: Owner-Drawn CheckedListBox-Pattern mit Disabled-Items (Items bleiben sichtbar
  aber ausgegraut, ItemCheck-Handler blockt Klicks). Essentiell für Marker-Auswahl-UIs.
- NEU: Sektion 6b - Custom-Report-Tab-Pattern (Hinweis + Marker-Auswahl + Zeitraum +
  Vorschau + Drucken + Exportieren). Wiederverwendbar für beliebige Filter-Reports.
- DOKU: Closure vs. Script-Scope bei PrintDocument.Add_PrintPage - GetNewClosure() reicht
  bei synchronem Print, $script:-Variablen bei asynchronem Kontext verwenden.
- DOKU: CheckBoxRenderer für konsistentes Disabled-Look der Checkboxen

CHANGELOG Template v3.4:
- NEU: Sektion 5d - Generisches Export-Popup-Pattern (Show-ExportPopup) für JSON + CSV
- NEU: Pattern "ScriptBlock-als-Daten-Provider" für kontext-agnostische Popups
- NEU: Pattern für state-abhängige Button-Aktivierung (Enabled = $false initial)
- DOKU: Button-Platzierungs-Konvention "Exportieren..." neben "Drucken"

CHANGELOG Template v3.3:
- NEU: Sektion 4d - Wissenschaftliche Longevity-Berechnungen (PhenoAge, InflammAging, TyG)
- NEU: Sektion 4e - Einheiten-Normalisierung für klinische Laborwerte (US vs. deutsche Einheiten)
- NEU: Sektion 4f - Special-Formula-Dispatcher-Pattern für komplexe Berechnungen
- NEU: Muster für wissenschaftliche Referenzen in Marker-Beschreibungen
- NEU: Convert-ToLongevityScore-Pattern für einheitliche 0-100-Skalenbewertung
- DOKU: Warnung bzgl. hsCRP vs. CRP bei Inflammations-Scores
- DOKU: Kritische Einheiten-Fallen bei PhenoAge (Albumin g/L, Kreatinin µmol/L, Glukose mmol/L)

CHANGELOG Template v3.2:
- PFLICHT: $script:AppName als zentrale Variable für Registry, Ordner, UI, Backups
- PFLICHT: $script:AppVersion statt $Version (einheitlich)
- NEU: Parse-Number Variante B (Tausender-Trennzeichen + Prozentzeichen, für Finanz-Apps)
- NEU: Debug-Logging-Pattern mit $script:DebugMode Flag
- NEU: Zusätzliche Datenbank-Dateien Muster (z.B. Meal-DB, Portfolio-DB)
- NEU: Filter-Zustandsvariablen Muster für Multi-Tab-Filterung
- NEU: $script: Prefix für alle globalen Variablen in Event-Handlern dokumentiert
- VERBESSERT: ConvertTo-Hashtable mit Null-Check, Hashtable-Input, DictionaryEntry
- VERBESSERT: Settings-Popup mit allen Buttons und vollständigen Event-Handlern
#>

# ╔══════════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 0: USER-KONFIGURATION                                                   ║
# ║  OPTIONAL: Feature-Toggles, die der Endnutzer bei Bedarf anpasst.               ║
# ║  PATTERN: Immer ganz oben im Script (noch vor den Assembly-Loads), damit leicht  ║
# ║  auffindbar. Jede Variable mit Kommentar erläutert. $script:-Scope zwingend,    ║
# ║  damit auch Funktionen/Event-Handler darauf zugreifen können.                   ║
# ╚══════════════════════════════════════════════════════════════════════════════════╝

# BEISPIEL: Export-Verhalten steuern (siehe Blood-Tracker v2.13.1)
# Nach jedem Export: Ordner im Windows-Explorer automatisch öffnen?
#   $true  = Ordner wird nach erfolgreichem Export geöffnet (Default)
#   $false = Ordner wird NICHT geöffnet
$script:ExportOpenFolderAfter = $true

# Nach jedem Export: Dialog anzeigen "Möchten Sie die Datei jetzt öffnen?"
#   $true  = Dialog erscheint, bei "Ja" wird die Datei mit Standardprogramm geöffnet (Default)
#   $false = Kein Dialog, keine automatische Datei-Öffnung
$script:ExportAskOpenFile = $true

# [OPTIONAL, v3.10] BETA-Testmodus (siehe Sektion 1b und 6Q)
#   $true  = Script läuft isoliert: eigener Registry-Schlüssel und eigener Datenordner
#            ($script:AppName + ".BETA") - echte Daten werden weder gelesen noch verändert.
#   $false = Normalbetrieb (Default)
# Alternativ ohne Script-Änderung: Umgebungsvariable PSC_BETA=1 setzen. Sie gilt auch für
# Neustarts aus der App heraus (Start-Process vererbt die Umgebung).
$script:BetaMode = $false
# Neue Speicherwege pruefen diese Tiefe VOR ConvertTo-Json. Schema bewusst waehlen.
$script:AppJsonDepth = 12
# false nur fuer bewusst nichtatomare Kompatibilitaet; Stapelspeicherung bleibt strikt.
$script:RequireAtomicWrites = $true

# Messwert-Engine (3n/3r): eigene Kategorien mit stabilem ASCII-Schluessel konfigurieren.
$script:MeasurementFolderName = '_messungen'
$script:MeasurementPeriodFolderName = '_zeitraeume'
$script:MeasurementCategories = @('Schlaf', 'Fitness', 'Aktivitaet')
$script:MeasurementMultiCategories = @('Fitness', 'Aktivitaet')
# Beispiel eigener Katalog: zusaetzlich Kategorie in beiden Listen eintragen.
# @{ Sensor = @(@{Key='Wert';Name='Sensorwert';Unit='Einheit';Group='Sensor';
#                PlausMin=0;PlausMax=100;Description='Anwendungsspezifisch begruenden.'}) }
$script:CustomMeasurementDefinitions = @{}
$script:Vo2maxMethods = @('Spiroergometrie (Labor)', 'Feldtest', 'Schätzung Uhr/App')
$script:MeasurementFutureToleranceMinutes = 5
# Nur technische Warnhinweise; null = keine erfundene obere Grenze. Kein Verwerfen.
$script:ActivityWarningUpperBounds = @{Aktivitaetsenergie=$null; Schritte=$null; CardioErholung=$null}
$script:ActivitySummaryDecimals = 2  # nur Anzeige, 0..15; Roh-/Quellenwerte ungerundet

# Wiederverwendbare UI (5d/5m/5n); vor Initialisierung der Controls festlegen.
$script:ActiveTabIndicatorEnabled = $true
$script:ActiveTabIndicatorColor = '#B84040'
$script:ActiveTabBoldEnabled = $true
$script:GridSortCulture = 'de-DE'
$script:ExportPdfPrinterName = 'Microsoft Print to PDF'

# Dashboard (5o): feste Spaltenzahl, bei kleinen Fenstern horizontal scrollbar.
$script:DashboardColumns = 4
$script:DashboardTileWidth = 220
$script:DashboardTileHeight = 126
$script:DashboardLevelColors = @{None='#9A9A9A';Good='#398653';Warning='#BB8426';Critical='#B84040'}

# Weitere Toggles nach Bedarf hier ergänzen. Z.B.:
# $script:DebugMode = $false                # Debug-Logging ein/aus
# $script:AutoBackupOnExit = $true          # Backup beim Schließen
# $script:DefaultDateFormat = "dd.MM.yyyy"  # UI-Datumsformat


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 1: GLOBALE KONFIGURATION & ASSEMBLIES                              ║
# ║  PFLICHT: Immer vollständig übernehmen. Assemblies je nach Bedarf wählen.    ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# --- 1a. .NET-Assemblies laden ---
# PFLICHT: Immer benötigt für GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# [OPTIONAL] Nur laden wenn Charts (Line/Bar/Pie/Scatter) verwendet werden
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

# [OPTIONAL] Nur laden wenn System.Collections.ArrayList oder BindingList benötigt wird
Add-Type -AssemblyName System

# [OPTIONAL, v3.9] PFLICHT für DPAPI-Verschlüsselung (Sektion 3h) und für das
# portable AES-Backup (Sektion 3i). Ohne diese Zeile wirft ProtectedData einen
# Typ-nicht-gefunden-Fehler.
Add-Type -AssemblyName System.Security

# [OPTIONAL, v3.9] Wird für ZIP-Backups und den NuGet-DLL-Download gebraucht.
# Kann auch lazy in der jeweiligen Funktion geladen werden.
# Add-Type -AssemblyName System.IO.Compression.FileSystem

# --- 1b. App-Identität & Versionierung (PFLICHT) ---
# PFLICHT: Zentraler App-Name wird durchgängig für Registry, Ordner, UI-Texte,
# Backups und Deinstallation verwendet. Verhindert hardcodierte Strings.
$script:AppName    = "MeineApp"       # [PLACEHOLDER] z.B. "Blood-Tracker", "Finance-Planner"
$script:TemplateVersion = '3.14.0'    # Bibliotheksstand, keine App-Release-Version
$script:AppVersion = "1.0.0"          # [PLACEHOLDER] Aktuelle App-Version anpassen
$script:AppDisplayVersion = $script:AppVersion

# Release-Notes-Daten (5p): bewusst getrennte Quellen. Bestehende Eintraege nie aendern.
$script:TemplateReleaseNotes = @(
    @{Version='3.14.0';Datum='2026-10-10';Titel='Dashboard, eigene Ansichten und Release-Notes';Eintraege=@(
        @{Typ='Neu';Text='Wiederverwendbares Dashboard mit eigenen Ansichten und sicherer Speicherung ergänzt.'}
        @{Typ='Neu';Text='Release-Notes können geprüft, durchsucht, gefiltert und als Markdown exportiert werden.'}
        @{Typ='Bugfix';Text='Datenfelder mit dem Namen Keys werden bei der Prüfung verschachtelter Daten korrekt berücksichtigt.'}
        @{Typ='Anpassung';Text='Einbauhinweise und Abhängigkeiten für die neuen Bausteine vervollständigt.'}
        @{Typ='Hinweis';Text='Die Vorlage enthält weiterhin Beispiele, die an die jeweilige Anwendung angepasst werden müssen.'}
    )}
)
# [PLACEHOLDER] Beispieldaten fuer eine NEUE Ziel-App; vor deren Release ersetzen.
$script:AppReleaseNotes = @(
    @{Version='1.0.0';Datum='2026-10-10';Titel='Erste Anwendungsversion';Eintraege=@(
        @{Typ='Hinweis';Text='Beispiel für strukturierte Release-Notes einer neuen Anwendung.'}
    )}
)

# [OPTIONAL, v3.10] BETA-Isolation - MUSS vor 1c stehen: Registry-Pfad, Datenordner,
# Backup-Namen und Fenstertitel leiten sich alle von $script:AppName ab.
if ($script:BetaMode -or $env:PSC_BETA -eq '1') {
    $script:BetaMode   = $true
    $script:AppName    = "$($script:AppName).BETA"
    $script:AppDisplayVersion = "$($script:AppVersion) BETA-TEST"
}

# --- 1c. Registry-basierter flexibler Datenpfad (PFLICHT) ---
# Ermöglicht dem Benutzer, den Speicherort der Daten zu ändern.
# Der Registry-Schlüssel speichert den vom Benutzer gewählten Pfad.
# Fallback: UserProfile-Verzeichnis.
# WICHTIG: $script: Prefix verwenden, damit Event-Handler darauf zugreifen können.
$script:regPath = "HKCU:\Software\PSC\$($script:AppName)"
if (-not (Test-Path $script:regPath)) { New-Item -Path $script:regPath -Force | Out-Null }
$storedPath = (Get-ItemProperty -Path $script:regPath -Name DataPath -ErrorAction SilentlyContinue).DataPath

if ($storedPath -and (Test-Path $storedPath)) {
    $script:dataDir = $storedPath
} else {
    $script:dataDir = Join-Path -Path ([Environment]::GetFolderPath("UserProfile")) -ChildPath $script:AppName
    if (-not (Test-Path $script:dataDir)) { New-Item -Path $script:dataDir -ItemType Directory -Force | Out-Null }
    Set-ItemProperty -Path $script:regPath -Name DataPath -Value $script:dataDir
}

# --- 1d. Dateipfade definieren ---
# PFLICHT: Mindestens eine Config-Datei.
# WICHTIG: $script: Prefix für Zugriff in Event-Handlern.
$script:dataFile = Join-Path -Path $script:dataDir -ChildPath "Config.json"  # [PLACEHOLDER] Dateiname anpassen

# [OPTIONAL] Nur wenn tägliche Daten gespeichert werden (z.B. Ausgaben, Mahlzeiten, Blutwerte)
$script:dailyDataDirBase = Join-Path -Path $script:dataDir -ChildPath "data"

# [OPTIONAL] Zusätzliche Datenbank-Dateien (z.B. Lebensmittel-DB, Portfolio-Daten)
# Verwendet in: Kalorien-Tracker (meal-db.json), Finance-Planner (portfolio-data.json)
# $script:additionalDbFile = Join-Path -Path $script:dataDir -ChildPath "additional-db.json"

# --- 1e. Globale Script-Variablen ---
# PFLICHT: Zentraler Datenspeicher im Script-Scope
$script:data = @{}

# [v3.10] Speicherformat aller JSON-Dateien (Write-AppJsonFile, Sektion 2j):
#   $true  = DPAPI-verschlüsselt (Sektion 3h) - PFLICHT bei personenbezogenen Daten
#   $false = Klartext-JSON (ebenfalls atomar geschrieben)
# Gelesen wird immer automatisch richtig: Read-ProtectedJsonFile erkennt beide Formate,
# ein späteres Umschalten auf $true verschlüsselt den Bestand beim nächsten Speichern.
$script:UseDpapiEncryption = $true

# [OPTIONAL] Historische Daten (für Apps mit Daily-Data)
# $script:allHistoricalItems = [System.Collections.ArrayList]@()

# [OPTIONAL] Filter-Zustandsvariablen für Multi-Tab-Filterung
# Verwendet in: Blood-Tracker (Cockpit, DataMgmt, Longevity mit separaten Filtern)
# Jeder Tab kann eigene Filter haben, die über Tab-Wechsel erhalten bleiben.
# $script:tab1TimeFilter   = "Alle Daten"
# $script:tab1GroupFilter  = "Alle"
# $script:tab2TimeFilter   = "Alle Daten"

# [OPTIONAL] Debug-Modus Flag
# Steuert ob Debug-Ausgaben in der Konsole erscheinen.
# Auf $false setzen für Produktion. Siehe auch Write-DebugLog in Sektion 2.
$script:DebugMode = $false

# --- 1f. Katalog-/Stammdaten-Versionierung (OPTIONAL, v3.9) ---
# PROBLEM: Bringt eine neue Script-Version zusätzliche Default-Stammdaten mit
# (neue Marker, neue Kategorien, neue Konten), tauchen diese in einer BESTEHENDEN
# Installation nie auf - die Config.json überschreibt die Defaults beim Laden.
# LÖSUNG: Versionierte, additive Migration (siehe Merge-NewDefaultItems, Sektion 3k).
#   - $script:CatalogVersion   = Stand, den DIESES Script mitbringt
#   - $script:CatalogAdditions = Was welche Version ergänzt hat (Historie!)
#   - Der erreichte Stand wird in der Config gespeichert -> vom Nutzer GELÖSCHTE
#     Einträge kommen nicht zurück, NEUE Einträge werden genau einmal nachgezogen.
# PFLICHT-REGEL: Jede Version, die Stammdaten ergänzt, trägt sich hier ein.
# $script:CatalogVersion = '1.0.0'
# $script:CatalogAdditions = @(
#     @{ Version = '1.1.0'; Items = @('Neuer Eintrag A', 'Neuer Eintrag B'); CalculatedItems = @() },
#     @{ Version = '1.2.0'; Items = @('Neuer Eintrag C');                    CalculatedItems = @('Berechnet X') }
# )
#
# [v3.10] KORREKTUR-MIGRATION: Wird die Definition eines BESTEHENDEN Eintrags fachlich
# korrigiert (Formel, Bereiche, Beschreibung), hilft CatalogAdditions nicht - die
# Config.json behält die alte Definition. CatalogCorrections überschreibt genau die
# genannten Felder einmalig (Version > gespeicherter Stand, Umsetzung in Sektion 3k).
# OnlyIf: nur korrigieren, wenn der gespeicherte Eintrag noch den ALTEN Standardwert hat -
#         eigene Anpassungen des Nutzers bleiben unangetastet.
# FALLE: Formeln mit Platzhaltern IMMER in einfachen Anführungszeichen (PS-5.1-FALLE 6).
# OnlyIf nur für einfache Felder (Text/Zahl) - nicht für Listen.
# $script:CatalogCorrections = @(
#     @{ Version = '1.2.0'; CalculatedItems = @('Berechnet X'); Fields = @('Formula', 'Description'); OnlyIf = @{ Formula = '%0% / %1%' } },
#     @{ Version = '1.3.0'; Items = @('Eintrag A'); Fields = @('RefMin', 'RefMax'); OnlyIf = @{ RefMin = 0.38; RefMax = 0.49 } }
# )

# --- 1g. Alias-Tabelle für Freitext-Suche (OPTIONAL, v3.9) ---
# Kürzel/Synonyme, die NICHT im offiziellen Namen stehen sollen. Siehe Sektion 2h.
# WARNUNG (harte Praxis-Regel aus Blood-Tracker v2.26.0):
#   Keine 2-stelligen Kürzel in Klammern im Namen führen ("Zink (Zn)" ist FALSCH).
#   Build-AliasMap (Sektion 3m) zieht Klammerinhalte automatisch in den Datei-Import;
#   2-stellige Kürzel erzeugen dort massenhaft Fehltreffer. Kürzel gehören hierher.
# $script:ItemAliases = @{
#     'Leukozyten (WBC)' = @('weisse Blutkoerperchen', 'Leuko')
#     'Zink'             = @('Zn')
# }
#
# [v3.10] Sperrliste: Suchbegriffe, die NIE automatisch einem Eintrag zugeordnet werden
# dürfen, weil die Teilwort-Suche sonst einen ähnlich benannten, aber FALSCHEN Eintrag
# liefert (Blood-Tracker: "BNP" -> NT-proBNP, "Troponin" -> Troponin T - andere Laborwerte
# mit anderen Grenzwerten). Angabe als normalisiertes Token (siehe Get-ItemToken, 2h).
# $script:ItemSearchBlocklist = @('bnp', 'troponin')

# --- 1h. Kodierte (qualitative) Werte (OPTIONAL, v3.9) ---
# Wenn der Datenspeicher ausschließlich Zahlen hält, ein Merkmal aber qualitativ ist
# (Genotyp, reaktiv/nicht reaktiv, Ampelstufe), wird es als CODE abgelegt und überall
# über eine zentrale Mapping-Funktion (Sektion 2i) im Klartext angezeigt.
# REGEL: Reihenfolge der Optionen = Code 1..n, aufsteigend nach Schweregrad/Risiko.
# REGEL: Nur ASCII in Auswahllisten ("E2/E3" statt griechischem Epsilon) - überlebt
#        versehentliches Speichern in ANSI/Windows-1252.
# $script:CodedItemName    = 'Apolipoprotein E-Genotyp (APOE)'
# $script:CodedItemOptions = @('E2/E2', 'E2/E3', 'E3/E3', 'E2/E4', 'E3/E4', 'E4/E4')

# --- 1i. Import-Ausschlusslisten (OPTIONAL, v3.9) ---
# Einträge, die ein automatischer Datei-Import NIE befüllen darf, plus Zeilen-Muster,
# die für einen bestimmten Eintrag fachlich NICHT gelten (Verwechslungsschutz).
# Siehe Sektion 3m. Beide Listen sind Bugfix-getrieben, nicht optional-kosmetisch.
# $script:ImportExcludedItems = @('HIV (Anti-HIV-1/2)', 'Apolipoprotein E-Genotyp (APOE)')
# $script:ImportSkipLinePatterns = @{
#     'C-reaktives Protein (CRP)' = '(?i)(hs[\s\-]?crp|hochsensitiv|high\s*sensitivity)'
# }

# --- 1j. Fallback- und Vorrang-Ketten für Berechnungen (OPTIONAL, v3.9 / Vorrang v3.10) ---
# Fehlt ein Schlüssel-Eingangswert, wird der erste verfügbare Ersatz genutzt.
# HARTE VORAUSSETZUNG: identische Einheit - sonst rechnet der Score stillschweigend falsch.
# $script:ItemFallbacks = @{ 'C-reaktives Protein (CRP)' = @('Hochsensitives CRP (hs-CRP)') }
#
# [v3.10] VORRANG statt Ersatz: Ist ein fachlich BESSERER Eingangswert vorhanden, wird er
# auch dann genutzt, wenn der Standardwert am selben Tag ebenfalls gemessen wurde
# (Blood-Tracker: hs-CRP vor CRP für PhenoAge/InflammAging/Longevity-Score).
# Auflösung je Messtag: Vorrang -> Standard -> Fallback (siehe Dispatcher 4i).
# REGEL: nur für Spezial-Formeln - bei einfachen Formeln änderte sich sonst rückwirkend
#        die Bedeutung bestehender berechneter Einträge.
# $script:ItemPreferred = @{ 'C-reaktives Protein (CRP)' = @('Hochsensitives CRP (hs-CRP)') }

# --- 1k. Getrennte Ablage für Zusatz-Messungen (OPTIONAL, v3.10) ---
# Messungen mit EIGENEM Datenmodell (z.B. DEXA-Scan, Schlaf mit Phasen), die nicht in die
# Tagesdaten gehören. Ablage in einem reservierten Unterordner von data\, damit ALLE
# Sicherungswege (ZIP-Export, AES-Backup, AutoBackup, Restore, Datenpfad ändern) sie
# automatisch mit erfassen. Load-/Save-AllHistorical* überspringen den Ordner (Sektion 3n).
# Konfigurierbare Ordner/Kategorien stehen in USER-KONFIGURATION (Sektion 0).
$script:MeasurementSchemaVersion = 1       # feste Struktur des bestehenden Einzel-Tagesformats
$script:MeasurementMultiSchemaVersion = 2  # feste Struktur fuer mehrere Messungen pro Tag




# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 2: HILFSFUNKTIONEN                                                 ║
# ║  PFLICHT: Parse-Number und ConvertTo-Hashtable immer übernehmen.             ║
# ║  Merge-Hashtables und Normalize-DailyData nur wenn benötigt.                 ║
# ║  v3.10: Write-AtomicTextFile / Write-AppJsonFile / Get-AppPathKey (2j/2k)     ║
# ║  ebenfalls PFLICHT, sobald Daten gespeichert werden.                          ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# --- 2a. Post-Export-Routine (OPTIONAL, wenn Export-Features genutzt werden) ---
# Zentrale Nach-Export-Routine für einheitliches Verhalten über alle Export-Endpunkte.
# Steuerung via Feature-Toggles aus Sektion 0:
#   $script:ExportOpenFolderAfter  - Ordner im Explorer öffnen?
#   $script:ExportAskOpenFile      - "Datei öffnen?"-Dialog anzeigen?
#
# USAGE (in jedem Export-Endpunkt, NACH erfolgreichem Speichern):
#   Invoke-PostExportAction -FilePath $saveDlg.FileName -SuccessTitle "Export" `
#                           -SuccessMessage "JSON erfolgreich gespeichert:`n$($saveDlg.FileName)"
function Invoke-PostExportAction {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string]$SuccessTitle   = "Export abgeschlossen",
        [string]$SuccessMessage = $null
    )
    try {
        if (-not $SuccessMessage) { $SuccessMessage = "Export erfolgreich gespeichert:`n$FilePath" }
        [System.Windows.Forms.MessageBox]::Show($SuccessMessage, $SuccessTitle, "OK", "Information") | Out-Null

        if ($script:ExportOpenFolderAfter) {
            $folder = Split-Path -Path $FilePath -Parent
            if ($folder -and (Test-Path $folder)) {
                try { Invoke-Item $folder } catch { Write-Warning "Ordner konnte nicht geöffnet werden: $($_.Exception.Message)" }
            }
        }
        if ($script:ExportAskOpenFile) {
            $ask = [System.Windows.Forms.MessageBox]::Show(
                "Möchtest du die exportierte Datei jetzt öffnen?`n`n$FilePath",
                "Datei öffnen?",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )
            if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) {
                if (Test-Path $FilePath) {
                    try { Invoke-Item $FilePath } catch {
                        [System.Windows.Forms.MessageBox]::Show("Datei konnte nicht geöffnet werden: $($_.Exception.Message)", "Fehler", "OK", "Warning") | Out-Null
                    }
                }
            }
        }
    } catch { Write-Warning "Invoke-PostExportAction Fehler: $($_.Exception.Message)" }
}

# --- 2b. Zahlen-Parser (PFLICHT – eine der beiden Varianten wählen) ---
#
# VARIANTE A: Standard (für die meisten Apps)
# Toleriert deutsches Komma UND englischen Punkt als Dezimaltrenner.
# Gibt $null zurück bei leerem Input (für optionale Felder).
# Verwendet in: Blood-Tracker, allgemeine Tracker-Apps.
function Parse-Number {
    param([string]$text)
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    $t = $text.Trim() -replace ",", "."
    # [OPTIONAL] Prozentzeichen entfernen wenn Prozent-Eingaben erwartet werden:
    # $t = $t.Replace("%", "").Trim()
    # [OPTIONAL] Tausender-Trennzeichen (DE: Punkt) entfernen wenn große Zahlen erwartet werden:
    # $t = $t -replace "\.", ""  # ACHTUNG: Nur wenn Tausender-Punkte vorkommen!
    # v3.10 BUGFIX: NumberStyles.Float statt Any. "Any" las "(5)" und "5-" als -5 und erlaubte
    # Währungssymbole. NaN/Infinity ("NaN", "Infinity", je nach .NET auch "1e400") abweisen -
    # TryParse liefert dafür $true, gespeichert und gerechnet würde dann mit NaN.
    $out = 0.0
    if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture, [ref]$out)) {
        if ([double]::IsNaN($out) -or [double]::IsInfinity($out)) { throw "Ungültige Zahl: '$text'" }
        return [double]$out
    }
    # Fallback: Deutsche Kultur mit Tausenderpunkt (z.B. "1.000,5")
    $floatWithThousands = [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands
    if ([double]::TryParse($text.Trim(), $floatWithThousands,
        [System.Globalization.CultureInfo]::GetCultureInfo("de-DE"), [ref]$out)) {
        if ([double]::IsNaN($out) -or [double]::IsInfinity($out)) { throw "Ungültige Zahl: '$text'" }
        return [double]$out
    }
    throw "Ungültige Zahl: '$text'"
}

<#
VARIANTE B: Finanz-Modus (für Finanz-Apps mit Tausender-Trennung und Prozent-Eingaben)
Entfernt Prozentzeichen und deutsche Tausender-Punkte automatisch.
Gibt 0.0 statt $null zurück (Pflichtfelder in Finanzformularen).
Verwendet in: Finance-Planner, Haushalts-Tracker.

function Parse-Number {
    param([string]$text)
    if ([string]::IsNullOrWhiteSpace($text)) { return 0.0 }
    $t = $text.Trim()
    # 1. Prozentzeichen entfernen (Division passiert im Event-Handler)
    $t = $t.Replace("%", "").Trim()
    # 2. Tausender-Trennzeichen (Punkte in DE) entfernen
    $t = $t -replace "\.", ""
    # 3. Dezimal-Trennzeichen (Komma in DE) durch invarianten Punkt ersetzen
    $t = $t -replace ",", "."
    $out = 0.0
    # v3.10: Float statt Any + NaN/Infinity abweisen (siehe Variante A)
    if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture, [ref]$out) -and
        -not [double]::IsNaN($out) -and -not [double]::IsInfinity($out)) {
        return [double]$out
    }
    throw "Ungültige Zahl: '$text'"
}
#>

# --- 2c. JSON → Hashtable Konverter (PFLICHT) ---
# ConvertFrom-Json liefert PSCustomObject, viele Operationen brauchen aber Hashtables.
# Diese Funktion konvertiert rekursiv, inkl. verschachtelter Objekte und Arrays.
# WICHTIG: Unterstützt PSCustomObject UND Hashtable als Input (robust bei gemischten Daten).
# WICHTIG: Null-Check vor .GetType().IsArray verhindert NullReferenceException.
# v3.10 BUGFIX: Name/Wert DIREKT zuweisen. "$value = if (...) { $prop.Value }" gab den Wert
# über die Pipeline aus - eine Liste mit EINEM Eintrag wurde zum Einzelwert (Blood-Tracker:
# RequiredMarkers @('Gewicht') -> 'Gewicht' -> [0] = 'G', BMI nach Neustart nie berechnet),
# eine leere Liste zu $null. Test: Liste mit 0/1/2 Einträgen speichern -> neu laden.
function ConvertTo-Hashtable {
    param ([Parameter(ValueFromPipeline)] $InputObject)
    $hash = @{}
    $properties = $null
    if ($InputObject -is [System.Management.Automation.PSCustomObject] -or $InputObject.PSObject -ne $null) {
        $properties = $InputObject.PSObject.Properties
    } elseif ($InputObject -is [hashtable]) {
        $properties = $InputObject.GetEnumerator()
    } else {
        return $InputObject
    }
    foreach ($prop in $properties) {
        if ($prop -is [System.Collections.DictionaryEntry]) { $name = $prop.Key; $value = $prop.Value }
        else { $name = $prop.Name; $value = $prop.Value }

        if ($null -eq $value) {
            $hash[$name] = $null
        } elseif ($value -is [System.Management.Automation.PSCustomObject] -or $value -is [hashtable]) {
            $hash[$name] = ConvertTo-Hashtable -InputObject $value
        } elseif ($value -is [Array] -or $value -is [System.Collections.ArrayList] -or
                  ($null -ne $value -and $value.GetType().IsArray)) {
            $arrayList = New-Object System.Collections.ArrayList
            foreach ($item in $value) {
                if ($item -is [System.Management.Automation.PSCustomObject] -or $item -is [hashtable]) {
                    $arrayList.Add((ConvertTo-Hashtable -InputObject $item)) | Out-Null
                } else {
                    $arrayList.Add($item) | Out-Null
                }
            }
            $hash[$name] = $arrayList
        } else {
            $hash[$name] = $value
        }
    }
    return $hash
}

# --- 2d. Hashtable-Merge (OPTIONAL) ---
# Wird benötigt wenn gespeicherte Konfiguration mit Default-Werten zusammengeführt werden soll.
# Vorteil: Neue Config-Felder werden automatisch ergänzt, bestehende bleiben erhalten.
function Merge-Hashtables {
    param (
        [Parameter(Mandatory=$true)] [hashtable]$destination,
        [Parameter(Mandatory=$true)] [hashtable]$source
    )
    foreach ($key in $source.Keys) {
        if ($destination.ContainsKey($key) -and
            $destination[$key] -is [hashtable] -and
            $source[$key] -is [hashtable]) {
            Merge-Hashtables -destination $destination[$key] -source $source[$key]
        } else {
            $destination[$key] = $source[$key]
        }
    }
}

# --- 2e. Dateipfad für Tagesdaten (OPTIONAL - nur mit Daily-Data) ---
# Erzeugt eine Ordnerstruktur: data/YYYY/MM/YYYY.MM.DD.json
# Rückgabe: (Dateipfad, Verzeichnispfad)
function Get-DailyDataFilePath {
    param($dateString)
    try {
        $date = [datetime]::ParseExact($dateString, "yyyy-MM-dd", $null)
        $year  = $date.ToString("yyyy")
        $month = $date.ToString("MM")
        $day   = $date.ToString("yyyy.MM.dd")
        $dailyDataDir  = Join-Path -Path $script:dailyDataDirBase -ChildPath $year | Join-Path -ChildPath $month
        $dailyDataFile = Join-Path -Path $dailyDataDir -ChildPath "$day.json"
        return $dailyDataFile, $dailyDataDir
    } catch {
        throw "Ungültiges Datumsformat: $dateString"
    }
}

# --- 2f. Daten-Normalisierung (OPTIONAL - nur wenn Tagesdaten Validierung brauchen) ---
# Stellt sicher, dass geladene Tagesdaten die erwartete Struktur haben.
# Filtert ungültige Einträge heraus und setzt Defaults für fehlende Felder.
# Verwendet in: Haushalts-Tracker (Expenses), Kalorien-Tracker (Meals)
function Normalize-DailyData {
    param($data, [string]$expectedDate = $null)
    if (-not $data) { return $data }

    # [PLACEHOLDER] Anpassen an die eigene Datenstruktur:
    # Beispiel für eine Liste namens "Items":
    if (-not $data.ContainsKey('Items')) {
        $data.Items = New-Object System.Collections.ArrayList
    } elseif (-not ($data.Items -is [System.Collections.IList])) {
        $data.Items = [System.Collections.ArrayList]@($data.Items)
    }

    $validItems = New-Object System.Collections.ArrayList
    foreach ($item in $data.Items) {
        try {
            # Objekt zu Hashtable konvertieren (robust für beide Typen)
            $d = if ($item -is [hashtable]) {
                $tmp = [ordered]@{}; foreach ($k in $item.Keys) { $tmp[$k] = $item[$k] }; $tmp
            } else {
                $tmp = [ordered]@{}; foreach ($p in $item.PSObject.Properties) { $tmp[$p.Name] = $p.Value }; $tmp
            }

            # [PLACEHOLDER] Validierung und Normalisierung der Felder:
            $isValid = $true
            # if ($null -eq $d['Amount']) { $isValid = $false }

            if ($isValid) {
                $normItem = [PSCustomObject]@{
                    Date = if ($d['Date']) { $d['Date'] } else { if ($expectedDate) { $expectedDate } else { (Get-Date).ToString("yyyy-MM-dd") } }
                    # [PLACEHOLDER] Weitere Felder hier...
                }
                $validItems.Add($normItem) | Out-Null
            }
        } catch {
            Write-Warning "Ungültiger Eintrag: $($_.Exception.Message)"
        }
    }
    $data.Items = $validItems
    return $data
}

# --- 2g. Debug-Logging (OPTIONAL) ---
# Zentralisierte Debug-Ausgabe, gesteuert über $script:DebugMode.
# Ersetzt verteilte Write-Host "Debug:..." Aufrufe durch einheitliches Pattern.
# Für Produktion: $script:DebugMode = $false → keine Konsolenausgabe.
function Write-DebugLog {
    param([string]$message)
    if ($script:DebugMode) {
        Write-Host "DEBUG [$($script:AppName)]: $message" -ForegroundColor Cyan
    }
}



# --- 2h. Freitext-Suchindex mit Relevanz-Ranking (OPTIONAL, v3.9) ---
# Basis für Live-Filter-ComboBoxen (Sektion 6i) und für Freitext-Auflösung.
# Quellen je Eintrag: voller Name, Name ohne Klammerzusatz, Kürzel aus Klammern
# (getrennt an "/" und ","), plus $script:ItemAliases (Sektion 1g).
# Nach jeder Katalog-Änderung neu bauen, damit selbst angelegte Einträge sofort
# auffindbar sind.

function Get-ItemToken {
    <#
    .SYNOPSIS
        Normalisiert einen Suchbegriff für den Alias-Vergleich.
    .DESCRIPTION
        Kleinschreibung, Umlaut-Auflösung, Entfernen aller Sonderzeichen:
        "Haemoglobin (HGB/Hb)" -> "haemoglobinhgbhb"   |   "hs-CRP" -> "hscrp"
    #>
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $t = $Text.ToLowerInvariant()
    $t = $t -replace 'ä', 'ae' -replace 'ö', 'oe' -replace 'ü', 'ue' -replace 'ß', 'ss'
    $t = $t -replace '[^a-z0-9]', ''
    return $t
}

function Build-ItemSearchIndex {
    <#
    .SYNOPSIS
        Baut den Suchindex auf (kanonischer Name -> alle Tokens).
    #>
    $index = @()
    $names = @()
    # [PLACEHOLDER] Quelle der Namen an die eigene Datenstruktur anpassen:
    if ($script:data -and $script:data.Config -and $script:data.Config.Markers) {
        $names = @($script:data.Config.Markers | ForEach-Object { [string]$_.Name } | Where-Object { $_ } | Sort-Object)
    }
    foreach ($name in $names) {
        $cands = @($name)
        $base = ($name -replace '\s*\([^)]*\)\s*', '').Trim()
        if ($base) { $cands += $base }
        if ($name -match '\(([^)]+)\)') {
            foreach ($part in ($Matches[1] -split '[/,]')) {
                $p = $part.Trim()
                if ($p) { $cands += $p }
            }
        }
        if ($script:ItemAliases -and $script:ItemAliases.ContainsKey($name)) {
            foreach ($a in $script:ItemAliases[$name]) { if ($a) { $cands += [string]$a } }
        }
        $tokens = @($cands | ForEach-Object { Get-ItemToken $_ } | Where-Object { $_ } | Select-Object -Unique)
        $index += [PSCustomObject]@{ Name = $name; Tokens = $tokens }
    }
    $script:ItemSearchIndex = $index
}

function Get-ItemMatches {
    <#
    .SYNOPSIS
        Liefert alle passenden Namen, nach Relevanz sortiert.
    .DESCRIPTION
        Rang 0 = exakter Token-Treffer ("WBC")
        Rang 1 = Token beginnt mit der Eingabe ("Leuk" -> "Leukozyten (WBC)")
        Rang 2 = Token enthält die Eingabe
        KRITISCH: Tokens mit <= 3 Zeichen (K, AP, GOT) werden NUR exakt gematcht,
        sonst entstehen massenhaft Fehltreffer.
    #>
    param([Parameter(Mandatory)][string]$Query)
    $q = Get-ItemToken $Query
    if ([string]::IsNullOrEmpty($q)) { return @() }
    if ($script:ItemSearchBlocklist -contains $q) { return @() }   # v3.10: Sperrliste (1g)
    if (-not $script:ItemSearchIndex) { Build-ItemSearchIndex }

    $rank0 = @(); $rank1 = @(); $rank2 = @()
    foreach ($entry in $script:ItemSearchIndex) {
        $best = 99
        foreach ($tok in $entry.Tokens) {
            if ($tok -eq $q) { $best = 0; break }
            if ($tok.Length -le 3) { continue }
            if ($tok.StartsWith($q)) { if ($best -gt 1) { $best = 1 }; continue }
            if ($tok.Contains($q))   { if ($best -gt 2) { $best = 2 } }
        }
        switch ($best) {
            0 { $rank0 += $entry.Name }
            1 { $rank1 += $entry.Name }
            2 { $rank2 += $entry.Name }
        }
    }
    return @($rank0) + @($rank1) + @($rank2)
}

function Resolve-ItemName {
    <#
    .SYNOPSIS
        Löst eine freie Eingabe auf genau EINEN kanonischen Namen auf.
    .OUTPUTS
        Kanonischer Name, oder $null bei Mehrdeutigkeit / keinem Treffer.
    .NOTES
        Mehrdeutigkeit gibt bewusst $null zurück, statt still den ersten Treffer zu
        nehmen (Beispiel: "Erythrozyten-Verteilungsbreite" -> RDW-CV UND RDW-SD).
    #>
    param([string]$Query)
    if ([string]::IsNullOrWhiteSpace($Query)) { return $null }
    $q = Get-ItemToken $Query
    if (-not $q) { return $null }
    if ($script:ItemSearchBlocklist -contains $q) { return $null }   # v3.10: Sperrliste (1g)
    if (-not $script:ItemSearchIndex) { Build-ItemSearchIndex }

    $exact = @()
    foreach ($entry in $script:ItemSearchIndex) {
        if ($entry.Tokens -contains $q) { $exact += [string]$entry.Name }
    }
    if ($exact.Count -eq 1) { return [string]$exact[0] }
    if ($exact.Count -gt 1) { return $null }
    $hits = @(Get-ItemMatches -Query $Query)
    if ($hits.Count -eq 1) { return [string]$hits[0] }
    return $null
}

# [v3.10] SUCHE IN EINER BELIEBIGEN ANZEIGELISTE
# Get-ItemMatches durchsucht den Katalog. Zeigt eine ComboBox eine ANDERE Liste (z.B. nur
# Einträge mit Daten plus berechnete Einträge), muss die Suche genau diese Liste nutzen -
# sonst werden Treffer angeboten, die gar nicht auswählbar sind. Gleiche Regeln wie oben
# (Rang 0/1/2, Kürzel <= 3 Zeichen nur exakt, Sperrliste, Mehrdeutigkeit -> $null).
# GUI-Einbindung: Sektion 6n.

function Get-ListItemTokens {
    <#
    .SYNOPSIS
        Such-Tokens eines Listeneintrags: voller Name, Name ohne Klammerzusatz,
        Kürzel aus Klammern, Aliase (1g).
    #>
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return @() }
    $candidates = @($Name)
    $baseName = ($Name -replace '\s*\([^)]*\)\s*', '').Trim()
    if ($baseName) { $candidates += $baseName }
    if ($Name -match '\(([^)]+)\)') {
        foreach ($part in ($Matches[1] -split '[/,]')) { $trimmedPart = $part.Trim(); if ($trimmedPart) { $candidates += $trimmedPart } }
    }
    if ($script:ItemAliases -and $script:ItemAliases.ContainsKey($Name)) {
        foreach ($alias in $script:ItemAliases[$Name]) { if ($alias) { $candidates += [string]$alias } }
    }
    return @($candidates | ForEach-Object { Get-ItemToken $_ } | Where-Object { $_ } | Select-Object -Unique)
}

function Get-ListMatches {
    <#
    .SYNOPSIS
        Wie Get-ItemMatches, aber nur innerhalb von -Items (Reihenfolge nach Relevanz).
    #>
    param([string]$Query, [string[]]$Items)
    $queryToken = Get-ItemToken $Query
    if ([string]::IsNullOrEmpty($queryToken) -or -not $Items) { return @() }
    if ($script:ItemSearchBlocklist -contains $queryToken) { return @() }
    $rank0 = @(); $rank1 = @(); $rank2 = @()
    foreach ($itemName in $Items) {
        if ([string]::IsNullOrWhiteSpace($itemName)) { continue }
        $best = 99
        foreach ($token in (Get-ListItemTokens -Name $itemName)) {
            if ($token -eq $queryToken) { $best = 0; break }
            if ($token.Length -le 3) { continue }
            if ($token.StartsWith($queryToken)) { if ($best -gt 1) { $best = 1 }; continue }
            if ($token.Contains($queryToken)) { if ($best -gt 2) { $best = 2 } }
        }
        switch ($best) {
            0 { $rank0 += $itemName }
            1 { $rank1 += $itemName }
            2 { $rank2 += $itemName }
        }
    }
    return @($rank0) + @($rank1) + @($rank2)
}

function Resolve-ListSelection {
    <#
    .SYNOPSIS
        Löst eine Eingabe auf genau EINEN Eintrag von -Items auf.
    .OUTPUTS
        Listeneintrag, oder $null (kein Treffer / mehrdeutig).
    #>
    param([string]$Query, [string[]]$Items)
    if ([string]::IsNullOrWhiteSpace($Query) -or -not $Items) { return $null }
    $trimmedQuery = $Query.Trim()
    foreach ($itemName in $Items) { if ($itemName -ieq $trimmedQuery) { return [string]$itemName } }
    $queryToken = Get-ItemToken $trimmedQuery
    if (-not $queryToken) { return $null }
    if ($script:ItemSearchBlocklist -contains $queryToken) { return $null }
    $exact = @($Items | Where-Object { $_ -and ((Get-ListItemTokens -Name $_) -contains $queryToken) })
    if ($exact.Count -eq 1) { return [string]$exact[0] }
    if ($exact.Count -gt 1) { return $null }
    $hits = @(Get-ListMatches -Query $trimmedQuery -Items $Items)
    if ($hits.Count -eq 1) { return [string]$hits[0] }
    return $null
}


# --- 2i. Kodierte Werte: Code <-> Klartext (OPTIONAL, v3.9) ---
# Gegenstück zu Sektion 1h. WICHTIG: Diese beiden Funktionen sind der EINZIGE Ort,
# an dem die Kodierung liegt. Jede Anzeigestelle (Grid, Chart-Tooltip, Ausdruck,
# Report, PDF) ruft Get-CodedValueText auf - nie selbst umrechnen.

function Get-CodedValueText {
    <#
    .SYNOPSIS
        Wandelt den gespeicherten Zahlencode in Klartext (z.B. 3 -> "E3/E3").
    #>
    param($Value)
    $code = -1
    try { $code = [int][Math]::Round([double]$Value) } catch { $code = -1 }
    if ($code -ge 1 -and $code -le $script:CodedItemOptions.Count) {
        return [string]$script:CodedItemOptions[$code - 1]
    }
    return "unbekannt ($Value)"
}

function Get-CodedValueCode {
    <#
    .SYNOPSIS
        Wandelt einen Klartext zurück in den Code 1..n. 0 = nicht zuordenbar.
    .DESCRIPTION
        Beispiel-Implementierung für Genotyp-Paare, Reihenfolge egal
        ("E3/E4", "e3/e4", "3/4", "E4/E3" ergeben alle denselben Code).
        [PLACEHOLDER] Für andere Domänen durch ein einfaches IndexOf ersetzen:
            $i = [array]::IndexOf($script:CodedItemOptions, $Text); return ($i + 1)
    #>
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return 0 }
    $digits = ($Text -replace '[^2-4]', '')
    if ($digits.Length -ne 2) { return 0 }
    $sorted = -join (($digits.ToCharArray()) | Sort-Object)
    switch ($sorted) {
        '22' { return 1 }
        '23' { return 2 }
        '33' { return 3 }
        '24' { return 4 }
        '34' { return 5 }
        '44' { return 6 }
    }
    return 0
}


# --- 2j. Atomares Schreiben (PFLICHT fuer jede Datendatei, v3.11.0) ---
# Temp/Backup liegen eindeutig benannt im Zielordner. Neue Datei: Move; Bestand:
# Replace mit drei Versuchen. RequireAtomic=true bricht danach ab, ohne Copy-Fallback.
# RequireAtomic=false erlaubt ausdruecklich nichtatomaren Copy-Fallback mit Sicherung.
# Kein Schutz gegen konkurrierende Read-Modify-Write-Zyklen: dafuer Sperrprotokoll 3q.
# Zielordner vorher anlegen. Fehler werden terminierend weitergegeben.
function Write-AtomicTextFile {
    <#
    .SYNOPSIS
        Schreibt UTF-8 mit BOM; atomarer Austausch im standardmaessig strikten Modus.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content,
        [switch]$RequireAtomic = $script:RequireAtomicWrites
    )
    $fullPath = $null; $tmpPath = $null; $bakPath = $null
    try {
        # Absoluter Pfad - die .NET-Dateifunktionen kennen das PS-Arbeitsverzeichnis nicht
        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        $suffix = [guid]::NewGuid().ToString('N')
        $tmpPath  = "$fullPath.$suffix.apptmp"
        $bakPath  = "$fullPath.$suffix.appbak"

        # Schritt 1: vollständig in die Temp-Datei schreiben
        [IO.File]::WriteAllText($tmpPath, $Content, (New-Object Text.UTF8Encoding($true)))

        # Schritt 2a: neue Datei -> umbenennen
        if (-not [System.IO.File]::Exists($fullPath)) {
            [System.IO.File]::Move($tmpPath, $fullPath)
            return
        }

        # Schritt 2b: bestehende Datei atomar ersetzen (3 Versuche bei kurzzeitiger Sperre)
        $replaced = $false
        for ($attempt = 1; ($attempt -le 3) -and (-not $replaced); $attempt++) {
            try {
                [System.IO.File]::Replace($tmpPath, $fullPath, $bakPath, $true)
                $replaced = $true
            } catch {
                if ($attempt -lt 3) { Start-Sleep -Milliseconds 150 }
            }
        }
        if (-not $replaced) {
            if ($RequireAtomic) { throw 'Atomarer Dateiaustausch fehlgeschlagen; kein Copy-Fallback erlaubt.' }
            Write-Warning 'Nichtatomarer Kompatibilitaetsmodus: Kopieren kann unterbrochen werden.'
            # Vor dem destruktiven Fallback muss eine vollstaendige Sicherung vorliegen.
            if (-not [IO.File]::Exists($bakPath)) { [IO.File]::Copy($fullPath, $bakPath, $false) }
            try {
                [System.IO.File]::Copy($tmpPath, $fullPath, $true)
                Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
            } catch {
                # Vorversion auch nach unvollstaendigem Kopieren bestmoeglich wiederherstellen.
                if ([System.IO.File]::Exists($bakPath)) {
                    try { [System.IO.File]::Copy($bakPath, $fullPath, $true) }
                    catch { Write-Warning 'Wiederherstellung fehlgeschlagen; Sicherungsdatei im Zielordner erhalten.' }
                }
                throw
            }
        }

        # Schritt 3: Vorversion nach erfolgreichem Ersetzen entfernen
        if ([System.IO.File]::Exists($bakPath)) {
            Remove-Item -LiteralPath $bakPath -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Temp-Datei aufräumen - außer im Sonderfall "Zieldatei fehlt, Vorversion liegt als
        # .appbak vor" (dann bleibt alles für eine manuelle Rettung liegen)
        if ($tmpPath -and [System.IO.File]::Exists($tmpPath) -and
            ([System.IO.File]::Exists($fullPath) -or -not [System.IO.File]::Exists($bakPath))) {
            Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
        }
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Write-AppJsonFile {
    <#
    .SYNOPSIS
        Zentraler Schreibzugriff für JSON-Dateien: verschlüsselt (DPAPI, Sektion 3h) oder
        Klartext - je nach $script:UseDpapiEncryption (Sektion 1e). Standardmaessig strikt atomar; RequireAtomic wird weitergereicht.
    .NOTES
        Gegenstück zum Lesen ist IMMER Read-ProtectedJsonFile (erkennt beide Formate).
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$JsonString,
        [switch]$RequireAtomic = $script:RequireAtomicWrites
    )
    if ($script:UseDpapiEncryption) { Write-ProtectedJsonFile -Path $Path -JsonString $JsonString -RequireAtomic:$RequireAtomic }
    else { Write-AtomicTextFile -Path $Path -Content $JsonString -RequireAtomic:$RequireAtomic }
}

# --- 2k. Pfad-Vergleichsschlüssel (PFLICHT bei Datei-Abgleichen, v3.10) ---
# Dateipfade nie als Text vergleichen ("C:\Daten\" vs "c:\daten", relative Pfade).
# Verwendet in: 3e (verwaiste Dateien), 3o (Restore), 3p (Umzug).
function Get-AppPathKey {
    param([string]$Path)
    $full = $Path
    try { $full = [System.IO.Path]::GetFullPath($Path) } catch { $full = $Path }
    return $full.TrimEnd('\', '/').ToLowerInvariant()
}

# --- 2l. Datums-Parser für Texteingaben (OPTIONAL, v3.10) ---
# Erlaubt TT.MM.JJJJ / T.M.JJJJ (Eingabe) und JJJJ-MM-TT (Speicherformat), kulturunabhängig.
# REGEL: gespeichert wird IMMER 'yyyy-MM-dd' (sortierbar, eindeutig), angezeigt 'dd.MM.yyyy'.
function ConvertTo-AppDate {
    <#
    .OUTPUTS
        [datetime] (nur Datum) oder $null bei leerer/ungültiger Eingabe.
    #>
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $formats = [string[]]@('dd.MM.yyyy', 'd.M.yyyy', 'yyyy-MM-dd')
    $parsed = [datetime]::MinValue
    if ([datetime]::TryParseExact($Text.Trim(), $formats, [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        return $parsed.Date
    }
    return $null
}


# --- 2m. Gepruefte JSON-Serialisierung (PFLICHT fuer 3a/3b/3c/3q; v3.11.0) ---
# Abhaengigkeit: AppJsonDepth aus Sektion 0. Keine GUI, kein Dateizugriff.
# Vertrag: JSON-Datenbaum aus Dictionaries, PSCustomObjects, IList und Skalaren.
# Tiefe: Wurzel = 0; Container jenseits von Depth werden abgelehnt, nicht gekuerzt.
# PS 5.1 meldet Tiefenverlust nicht verlaesslich als Warnung. Daher Vorpruefung.
function ConvertTo-CheckedAppJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()]$InputObject, [ValidateRange(1,100)][int]$Depth = $script:AppJsonDepth)
    $ancestors = New-Object System.Collections.ArrayList
    $visit = {
        param($Node, [int]$Level)
        if ($null -eq $Node -or $Node -is [string] -or $Node -is [bool] -or $Node -is [datetime] -or $Node -is [guid]) { return }
        if ($Node -is [ValueType]) {
            if ($Node -is [double] -or $Node -is [single]) {
                if ([double]::IsNaN([double]$Node) -or [double]::IsInfinity([double]$Node)) { throw 'JSON enthält einen nicht endlichen Zahlenwert.' }
            }
            if ($Node -is [byte] -or $Node -is [sbyte] -or $Node -is [int16] -or $Node -is [uint16] -or $Node -is [int32] -or $Node -is [uint32] -or $Node -is [int64] -or $Node -is [uint64] -or $Node -is [decimal] -or $Node -is [double] -or $Node -is [single]) { return }
            throw 'Nicht unterstützter JSON-Skalartyp.'
        }
        $isMap = $Node -is [System.Collections.IDictionary]
        $isList = $Node -is [System.Collections.IList]
        $isObject = $Node -is [System.Management.Automation.PSCustomObject]
        if (-not ($isMap -or $isList -or $isObject)) { throw 'Nur einfache JSON-Datenobjekte sind erlaubt.' }
        if ($Level -gt $Depth) { throw 'Die JSON-Struktur überschreitet die konfigurierte Tiefe.' }
        foreach ($ancestor in $ancestors) { if ([object]::ReferenceEquals($ancestor, $Node)) { throw 'Zyklische JSON-Struktur ist nicht erlaubt.' } }
        [void]$ancestors.Add($Node)
        try {
            if ($isMap) {
                foreach ($key in $Node.psbase.Keys) {
                    if ($key -isnot [string]) { throw 'JSON-Objektschlüssel müssen Zeichenfolgen sein.' }
                    & $visit $Node[$key] ($Level + 1)
                }
            } elseif ($isList) {
                foreach ($child in $Node) { & $visit $child ($Level + 1) }
            } else {
                foreach ($property in $Node.PSObject.Properties) {
                    if ($property.MemberType -ne [System.Management.Automation.PSMemberTypes]::NoteProperty) { throw 'JSON-Objekte dürfen nur Datenfelder enthalten.' }
                    & $visit $property.Value ($Level + 1)
                }
            }
        } finally { $ancestors.RemoveAt($ancestors.Count - 1) }
    }
    & $visit $InputObject 0
    return (ConvertTo-Json -InputObject $InputObject -Depth $Depth -ErrorAction Stop)
}



# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 3: DATENPERSISTENZ (Load / Save / Import / Export)                  ║
# ║  PFLICHT: Load-Config und Save-UserData. Daily-Data und Import sind optional.║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# --- 3a. Konfiguration laden (PFLICHT) ---
# Lädt die Config-JSON, merged mit Default-Werten, migriert alte Felder.
# MUSTER: Default definieren → Datei laden → Merge → Migration → Speichern → Zurückgeben
function Load-Config {
    # Schritt 1: Default-Konfiguration definieren
    $defaultConfig = @{
        # [PLACEHOLDER] Eigene Default-Werte hier definieren:
        # Beispiel:
        Settings = @{
            SettingA = 100.0
            SettingB = "Standard"
        }
        Categories = @("Kategorie1", "Kategorie2", "Kategorie3")
        DashboardViews = @()  # 5o: {Id;Name;Keys}; Altbestand ohne Feld bleibt leer
        Items = [System.Collections.ArrayList]@()
    }

    # Schritt 2: Tiefe Kopie erstellen (verhindert Referenz-Probleme)
    $configData = (ConvertTo-CheckedAppJson -InputObject $defaultConfig) | ConvertFrom-Json | ConvertTo-Hashtable

    $saveNeeded = $false

    # Schritt 3: Gespeicherte Datei laden und mergen
    if (Test-Path $script:dataFile) {
        try {
            # v3.10: Read-ProtectedJsonFile erkennt Klartext UND DPAPI-verschlüsselt (Sektion 3h)
            $jsonContent = Read-ProtectedJsonFile -Path $script:dataFile
            if ([string]::IsNullOrWhiteSpace($jsonContent) -and
                -not [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $script:dataFile -Raw -ErrorAction SilentlyContinue))) {
                throw "Inhalt weder entschlüsselbar noch gültiges JSON."   # Inhalt vorhanden, aber unlesbar
            }
            if (-not [string]::IsNullOrWhiteSpace($jsonContent)) {
                $loadedObject = $jsonContent | ConvertFrom-Json
                if ($null -ne $loadedObject) {
                    $loadedData = ConvertTo-Hashtable -InputObject $loadedObject
                    Merge-Hashtables -destination $configData -source $loadedData
                }
            }
            Write-DebugLog "Konfiguration geladen aus $($script:dataFile)"
        } catch {
            # v3.10 BUGFIX-MUSTER (Datenverlust): Eine unlesbare Config (beschädigt oder mit DPAPI
            # eines anderen PCs/Profils verschlüsselt) wurde bisher beim nächsten Speichern still
            # durch die Standardwerte ersetzt. Deshalb ZUERST eine Rettungskopie anlegen.
            $loadErrorText = $_.Exception.Message
            $rescueNote = ""
            try {
                $rescuePath = "$($script:dataFile).unlesbar_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
                Copy-Item -LiteralPath $script:dataFile -Destination $rescuePath -Force -ErrorAction Stop
                $rescueNote = "`n`nDie bisherige Datei wurde unverändert gesichert als:`n$rescuePath"
            } catch {
                $rescueNote = "`n`nACHTUNG: Die Sicherungskopie ist fehlgeschlagen. Bitte das Programm beenden und die Datei manuell sichern:`n$($script:dataFile)"
            }
            [System.Windows.Forms.MessageBox]::Show(
                "Fehler beim Laden der Konfigurationsdatei: $loadErrorText`nStandardwerte werden verwendet.$rescueNote",
                "Ladefehler", "OK", "Warning") | Out-Null   # v3.10: sonst liefert Load-Config @(DialogResult, Config)
        }
    } else {
        Write-DebugLog "Keine Konfigurationsdatei gefunden – Standardwerte werden verwendet"
    }

    # Schritt 4: [OPTIONAL] Migration alter Felder / Ergänzung neuer Felder
    # Beispiel: Neues Feld hinzufügen wenn es noch nicht existiert
    # if (-not $configData.ContainsKey('NewField')) {
    #     $configData.NewField = "DefaultValue"; $saveNeeded = $true
    # }
    #
    # [v3.10] Neue UNTERFELDER in Blöcken, die NICHT über Merge-Hashtables laufen (z.B. ein
    # gespeicherter Block wird bewusst als Ganzes übernommen), mit Defaults ergänzen. Nach
    # ConvertTo-Hashtable kann ein Block Hashtable ODER PSCustomObject sein - beide Fälle
    # behandeln, sonst fehlt das Feld still (PS-5.1-FALLE 13):
    # $newDefaults = [ordered]@{ SettingC = $false; Anzeige = 'Standard' }
    # $block = $configData['Settings']
    # foreach ($defaultKey in $newDefaults.Keys) {
    #     if ($block -is [hashtable]) {
    #         if (-not $block.ContainsKey($defaultKey)) { $block[$defaultKey] = $newDefaults[$defaultKey]; $saveNeeded = $true }
    #     } elseif ($block.PSObject -and ($block.PSObject.Properties.Name -notcontains $defaultKey)) {
    #         $block | Add-Member -NotePropertyName $defaultKey -NotePropertyValue $newDefaults[$defaultKey] -Force
    #         $saveNeeded = $true
    #     }
    # }
    #
    # [v3.10] Stammdaten (neue UND fachlich korrigierte Einträge): Merge-NewDefaultItems (3k).
    # Gespeicherte Altwerte in eine neue Einheit umrechnen (z.B. l/l -> %) beim LADEN der
    # Daten, nicht hier: siehe Platzhalter in Load-AllHistoricalItems (3d).

    # v3.14.0: Nach Merge, vor jedem automatischen Speichern pruefen. Bei ungueltigen
    # Ansichten Abbruch ausserhalb des Lade-catch: Originaldatei bleibt unangetastet.
    # Kein Umwandeln defekter Daten in leere Default-Liste; Fehler am App-Start behandeln.
    $configData.DashboardViews = @(ConvertTo-AppDashboardViews -Views $configData.DashboardViews)

    # Schritt 5: Bei Änderungen sofort speichern
    if ($saveNeeded) {
        Save-UserData -data $configData -ThrowOnError
    }

    # Schritt 6: [OPTIONAL] ArrayLists nach dem Laden korrekt typisieren
    # PowerShell deserialisiert JSON-Arrays als Object[] → explizit zu ArrayList konvertieren
    # if ($configData.Items) {
    #     $configData.Items = [System.Collections.ArrayList]@($configData.Items | ForEach-Object { [PSCustomObject]$_ })
    # }

    return $configData
}

# --- 3b. Konfiguration speichern (PFLICHT) ---
# Speichert die aktuelle Konfiguration als JSON. Erstellt Verzeichnis falls nötig.
# Neue Aufrufer: -ThrowOnError; ohne Switch bleibt der bisherige Fehlerdialog bestehen.
function Save-UserData {
    param ($data, [switch]$ThrowOnError)
    try {
        if (-not (Test-Path $script:dataDir)) {
            New-Item -Path $script:dataDir -ItemType Directory -Force | Out-Null
        }
        # [PLACEHOLDER] Nur die Config-relevanten Felder speichern (keine Tagesdaten!):
        $configToSave = @{
            Settings   = $data.Settings
            Categories = $data.Categories
            DashboardViews = @(ConvertTo-AppDashboardViews -Views $data.DashboardViews)
            # ... weitere Config-Felder
            # CatalogVersion = $script:CatalogVersion   # PFLICHT bei Stammdaten-Migration (3k)
        }
        # v3.10: atomar, je nach $script:UseDpapiEncryption verschlüsselt (Sektion 2j)
        Write-AppJsonFile -Path $script:dataFile -JsonString (ConvertTo-CheckedAppJson -InputObject $configToSave)
        Write-DebugLog "Konfiguration gespeichert in $($script:dataFile)"
    } catch {
        if ($ThrowOnError) { throw }
        [System.Windows.Forms.MessageBox]::Show(
            "Fehler beim Speichern: $($_.Exception.Message)", "Speicherfehler", "OK", "Error") | Out-Null
    }
}

# --- 3c. Tagesdaten speichern (OPTIONAL - nur mit Daily-Data) ---
# Ersetzt den kompletten Tages-Snapshot; kein Append. Fuer neue Stapel: Sektion 3q.
# Keine parallele Verwendung mit 3q. Neue Aufrufer: -ThrowOnError und UI erst nach Erfolg.
function Save-DailyData {
    param ($data, $dateString, [switch]$ThrowOnError)
    try {
        $dailyDataFile, $dailyDataDir = Get-DailyDataFilePath -dateString $dateString
        if (-not (Test-Path $dailyDataDir)) {
            New-Item -Path $dailyDataDir -ItemType Directory -Force | Out-Null
        }
        # [PLACEHOLDER] Nur die Tages-relevanten Daten filtern und speichern:
        # v3.10: @() - ein einzelner Eintrag würde sonst als Objekt statt als Liste gespeichert
        $dailyData = @{
            Items = @($data.Items | Where-Object { $_.Date -eq $dateString })
        }
        Write-AppJsonFile -Path $dailyDataFile -JsonString (ConvertTo-CheckedAppJson -InputObject $dailyData)
        Write-DebugLog "Tagesdaten gespeichert: $dailyDataFile"
    } catch {
        if ($ThrowOnError) { throw }
        [System.Windows.Forms.MessageBox]::Show(
            "Fehler beim Speichern der Tagesdaten: $($_.Exception.Message)", "Speicherfehler", "OK", "Error") | Out-Null
    }
}

# --- 3d. Alle historischen Tagesdaten laden (OPTIONAL - nur mit Daily-Data) ---
# Durchsucht rekursiv das Datenverzeichnis und sammelt alle Einträge.
# WICHTIG: Rückgabe ist ArrayList (nicht Array!), damit .Remove() funktioniert.
# v3.10 BUGFIX (Datenverlust): Fehler JE DATEI abfangen. Bisher brach die erste defekte
# Datei das Laden ab - alle folgenden Tage fehlten im Speicher und wurden beim nächsten
# Save-AllHistoricalData gelöscht. Unlesbare Dateien landen in
# $script:HistoricalLoadFailedFiles: 3e löscht sie NIE und sichert sie vor einem
# Überschreiben. Der Nutzer wird je Fehlerbild genau EINMAL informiert.
# Ordner der Zusatz-Messungen (1k/3n) wird übersprungen.
function Load-AllHistoricalItems {
    $allItems = New-Object System.Collections.ArrayList
    $script:HistoricalLoadFailedFiles = New-Object System.Collections.ArrayList
    try {
        $files = @(Get-ChildItem -Path $script:dailyDataDirBase -Filter "*.json" -Recurse -ErrorAction SilentlyContinue |
                   Where-Object { -not (Test-IsMeasurementPath -Path $_.FullName) })
        foreach ($file in $files) {
            try {
                $json = Read-ProtectedJsonFile -Path $file.FullName
                if ($json) {
                    $data = $json | ConvertFrom-Json
                    if ($data.Items) {
                        [void]$allItems.AddRange(@($data.Items | ForEach-Object { [PSCustomObject]$_ }))
                    }
                } elseif (-not [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue))) {
                    # Inhalt vorhanden, aber weder entschlüsselbar noch gültiges JSON
                    [void]$script:HistoricalLoadFailedFiles.Add($file.FullName)
                }
            } catch {
                [void]$script:HistoricalLoadFailedFiles.Add($file.FullName)
                Write-Warning "Tagesdatei nicht lesbar: $($file.FullName) - $($_.Exception.Message)"
            }
        }
        Write-DebugLog "Historische Daten geladen: $($allItems.Count) Einträge"
    } catch {
        Write-Warning "Fehler beim Laden der Verlaufsdaten: $($_.Exception.Message)"
    }

    # [OPTIONAL, v3.10] Altwerte in eine geänderte Einheit umrechnen - NUR im Speicher, beim
    # nächsten Speichern wird der neue Wert geschrieben (Blood-Tracker: Hämatokrit l/l -> %).
    # Bedingung so wählen, dass sie physiologisch eindeutig ist und nie doppelt greift:
    # foreach ($histItem in $allItems) {
    #     if ($histItem.Name -eq '[PLACEHOLDER]' -and $null -ne $histItem.Value -and
    #         [double]$histItem.Value -gt 0 -and [double]$histItem.Value -lt 1.5) {
    #         $histItem.Value = [Math]::Round([double]$histItem.Value * 100, 1)
    #     }
    # }

    # Nutzer einmalig je Fehlerbild informieren (nicht bei jedem Neuladen erneut)
    if ($script:HistoricalLoadFailedFiles.Count -gt 0) {
        $warnKey = ($script:HistoricalLoadFailedFiles | Sort-Object) -join '|'
        if ($script:HistoricalLoadWarnedKey -ne $warnKey) {
            $script:HistoricalLoadWarnedKey = $warnKey
            $shownFiles = @($script:HistoricalLoadFailedFiles | Select-Object -First 5 | ForEach-Object { "- " + (Split-Path -Path $_ -Leaf) })
            $moreText = if ($script:HistoricalLoadFailedFiles.Count -gt 5) { "`n- ... und $($script:HistoricalLoadFailedFiles.Count - 5) weitere" } else { "" }
            [System.Windows.Forms.MessageBox]::Show(
                "$($script:HistoricalLoadFailedFiles.Count) Datei(en) konnten nicht gelesen werden und werden nicht angezeigt:`n`n$($shownFiles -join "`n")$moreText`n`nDie Dateien bleiben unverändert erhalten und werden vom Programm NICHT gelöscht.`n`nMögliche Ursachen: Datei beschädigt oder mit einem anderen Windows-Benutzerprofil/PC verschlüsselt (DPAPI).",
                "Daten nicht lesbar", "OK", "Warning") | Out-Null
        }
    }
    return $allItems
}

# --- 3e. Alle historischen Daten komplett neu speichern (OPTIONAL - nur mit Daily-Data) ---
# Schreibt den kompletten Speicherstand und entfernt "Geister-Dateien" gelöschter Tage.
# v3.10 BUGFIX (Datenverlust): Bisher wurden ZUERST alle Dateien gelöscht und DANACH neu
# geschrieben - ein Fehler mittendrin (ungültiger Wert, Datei gesperrt, Platte voll)
# vernichtete alle noch nicht geschriebenen Tage. Jetzt 3 Phasen:
#   Phase 1: alle Dateien nur im Speicher vorbereiten (keine Dateiänderung)
#   Phase 2: jede Datei atomar schreiben (Write-AppJsonFile)
#   Phase 3: ERST DANACH verwaiste Dateien entfernen - unlesbare Dateien (3d) nie
# Ordner der Zusatz-Messungen (1k/3n) wird nie angefasst.
function Save-AllHistoricalData {
    param ($AllItems)
    try {
        # Phase 1: Vorbereiten
        $plannedFiles = @{}
        $groupedData = @($AllItems | Group-Object -Property Date)
        foreach ($group in $groupedData) {
            $dateString = $group.Name
            $itemsForDay = $group.Group
            $dailyDataFile, $dailyDataDir = Get-DailyDataFilePath -dateString $dateString
            # [PLACEHOLDER] Saveable-Objekte erstellen (nur benötigte Properties):
            $savableItems = @($itemsForDay | ForEach-Object {
                [PSCustomObject]@{
                    Date  = $_.Date
                    Name  = $_.Name
                    Value = [double]$_.Value
                    # ... weitere Felder (optionale Felder per Add-Member nur, wenn vorhanden)
                }
            })
            $jsonString = @{ Items = $savableItems } | ConvertTo-Json -Depth 5
            $plannedFiles[(Get-AppPathKey -Path $dailyDataFile)] = @{ File = $dailyDataFile; Dir = $dailyDataDir; Json = $jsonString }
        }

        # Schutzliste: beim Laden unlesbare Dateien (siehe Load-AllHistoricalItems)
        $protectedKeys = @{}
        if ($script:HistoricalLoadFailedFiles) {
            foreach ($failedFile in $script:HistoricalLoadFailedFiles) { $protectedKeys[(Get-AppPathKey -Path $failedFile)] = $true }
        }

        # Phase 2: Schreiben (atomar je Datei - bei Fehler bleibt die Vorversion erhalten)
        foreach ($planKey in $plannedFiles.Keys) {
            $plan = $plannedFiles[$planKey]
            if (-not (Test-Path -LiteralPath $plan.Dir)) { New-Item -Path $plan.Dir -ItemType Directory -Force | Out-Null }
            if ($protectedKeys.ContainsKey($planKey) -and (Test-Path -LiteralPath $plan.File)) {
                # Unlesbare Datei würde überschrieben -> Original vorher als Kopie sichern
                $rescuePath = "$($plan.File).unlesbar_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
                Copy-Item -LiteralPath $plan.File -Destination $rescuePath -Force -ErrorAction Stop
            }
            Write-AppJsonFile -Path $plan.File -JsonString $plan.Json
        }

        # Phase 3: Erst nach vollständig erfolgreichem Schreiben verwaiste Dateien entfernen
        if (Test-Path $script:dailyDataDirBase) {
            $existingFiles = @(Get-ChildItem -Path $script:dailyDataDirBase -Filter "*.json" -Recurse -ErrorAction SilentlyContinue |
                               Where-Object { -not (Test-IsMeasurementPath -Path $_.FullName) })
            foreach ($file in $existingFiles) {
                $fileKey = Get-AppPathKey -Path $file.FullName
                if ($plannedFiles.ContainsKey($fileKey)) { continue }   # gerade geschrieben
                if ($protectedKeys.ContainsKey($fileKey)) { continue }  # unlesbar -> nie löschen
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
            }
            # Leere Unterverzeichnisse (Monat/Jahr) aufräumen - tiefste zuerst
            Get-ChildItem -Path $script:dailyDataDirBase -Directory -Recurse -ErrorAction SilentlyContinue |
                Sort-Object { $_.FullName.Length } -Descending |
                Where-Object { @(Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
                ForEach-Object { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue }
        }

        # Überschriebene (vorher unlesbare) Dateien sind jetzt wieder gültig
        if ($script:HistoricalLoadFailedFiles -and $script:HistoricalLoadFailedFiles.Count -gt 0) {
            $stillFailed = @($script:HistoricalLoadFailedFiles | Where-Object { -not $plannedFiles.ContainsKey((Get-AppPathKey -Path $_)) })
            $script:HistoricalLoadFailedFiles = New-Object System.Collections.ArrayList
            foreach ($stillFailedFile in $stillFailed) { [void]$script:HistoricalLoadFailedFiles.Add($stillFailedFile) }
        }
        Write-DebugLog "Historische Daten komplett neu gespeichert"
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Schwerwiegender Fehler beim Speichern: $($_.Exception.Message)", "Speicherfehler", "OK", "Error") | Out-Null
    }
}

# --- 3f. Zusätzliche Datenbank laden/speichern (OPTIONAL) ---
# Muster für separate Datenbank-Dateien neben der Haupt-Config.
# Verwendet in: Kalorien-Tracker (Meal-DB), Finance-Planner (Portfolio-Daten).
# Jede DB hat eigene Load/Save-Funktionen mit eigenem Dateiformat.
<#
function Load-AdditionalDb {
    $dbItems = New-Object System.Collections.ArrayList
    if (Test-Path $script:additionalDbFile) {
        try {
            $fileContent = Read-ProtectedJsonFile -Path $script:additionalDbFile   # v3.10
            if (-not [string]::IsNullOrWhiteSpace($fileContent)) {
                $loaded = $fileContent | ConvertFrom-Json
                foreach ($item in $loaded) {
                    $dbItems.Add((ConvertTo-Hashtable -InputObject $item)) | Out-Null
                }
            }
            Write-DebugLog "Zusätzliche DB geladen: $($dbItems.Count) Einträge"
        } catch {
            Write-Warning "Fehler beim Laden der DB: $($_.Exception.Message)"
        }
    }
    return $dbItems
}

function Save-AdditionalDb {
    param ($dbItems)
    try {
        if (-not (Test-Path $script:dataDir)) {
            New-Item -Path $script:dataDir -ItemType Directory -Force | Out-Null
        }
        Write-AppJsonFile -Path $script:additionalDbFile -JsonString (ConvertTo-Json -InputObject @($dbItems) -Depth 5)   # v3.10: atomar, Liste bleibt Liste
        Write-DebugLog "Zusätzliche DB gespeichert: $($dbItems.Count) Einträge"
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Fehler beim Speichern der Datenbank: $($_.Exception.Message)", "Speicherfehler", "OK", "Error")
    }
}
#>

# --- 3g. CSV-Import (OPTIONAL) ---
# Importiert Daten aus einer CSV-Datei mit Duplikatsprüfung.
# Verwendet in: Blood-Tracker (Blutwerte importieren).
function Import-CsvData {
    param($filePath)
    try {
        $csvData = Import-Csv -Path $filePath
        $importedCount = 0; $skippedCount = 0
        $newItems = New-Object System.Collections.ArrayList

        foreach ($row in $csvData) {
            try {
                # [PLACEHOLDER] CSV-Spalten auslesen und validieren:
                $dateStr = $row.Date
                $date = [datetime]::Parse($dateStr).ToString("yyyy-MM-dd")
                $value = Parse-Number $row.Value
                if ($null -eq $value) { throw "Leerer Wert." }

                # Duplikatsprüfung gegen bestehende historische Daten
                $existingHistorical = @($script:allHistoricalItems | Where-Object {
                    ($_.Date -eq $date) -and ($_.Name -eq $row.Name)
                })
                if ($existingHistorical.Count -gt 0) { throw "Doppelter Eintrag (existiert bereits)." }

                # Duplikatsprüfung gegen aktuelle Import-Charge
                $existingInImport = @($newItems | Where-Object {
                    ($_.Date -eq $date) -and ($_.Name -eq $row.Name)
                })
                if ($existingInImport.Count -gt 0) { throw "Doppelter Eintrag (CSV-Duplikat)." }

                $newItem = [PSCustomObject]@{ Date = $date; Name = $row.Name; Value = $value }
                $newItems.Add($newItem) | Out-Null
                $importedCount++
            } catch {
                Write-Warning "Überspringe Zeile: $($_.Exception.Message)"
                $skippedCount++
            }
        }

        # Element-für-Element zur globalen Liste hinzufügen (NICHT AddRange!)
        if ($newItems.Count -gt 0) {
            foreach ($item in $newItems) {
                [void]$script:allHistoricalItems.Add($item)
            }
            Save-AllHistoricalData -AllItems $script:allHistoricalItems
        }

        [System.Windows.Forms.MessageBox]::Show(
            "$importedCount importiert, $skippedCount übersprungen.", "Import", "OK", "Information")
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Import-Fehler: $($_.Exception.Message)", "Fehler", "OK", "Error")
    }
}



# --- 3h. Transparente Verschlüsselung aller JSON-Dateien (DPAPI, OPTIONAL, v3.9) ---
# PFLICHT bei personenbezogenen oder Gesundheitsdaten.
# Add-Type -AssemblyName System.Security  (siehe Sektion 1a)
#
# PATTERN: Statt Get-Content/Set-Content laufen ALLE Lese-/Schreibzugriffe über
# Read-ProtectedJsonFile / Write-ProtectedJsonFile. Kein Passwort nötig - Windows
# (DPAPI, CurrentUser-Scope) übernimmt das Schlüsselmanagement.
#
# MIGRATION: Read-ProtectedJsonFile erkennt Klartext-Altbestände automatisch und
# liest sie transparent; beim nächsten Speichern werden sie verschlüsselt.
# Genau dieser Auto-Detect macht auch den Klartext-Migrationsexport (3j) möglich.
#
# GRENZE (unbedingt dokumentieren): DPAPI/CurrentUser ist an Windows-Benutzer UND
# Gerät gebunden. Ein einfaches Kopieren des Datenordners auf einen anderen PC
# schlägt fehl - dafür gibt es 3i (verschlüsselt) bzw. 3j (Klartext).
# PREFIX: Der Marker-Prefix ("BTENC:") sollte app-spezifisch gewählt werden.

function Write-ProtectedJsonFile {
    <#
    .SYNOPSIS
        Verschlüsselt einen JSON-String mit DPAPI und schreibt ihn als Datei.
    .DESCRIPTION
        Dateiformat: "<PREFIX>:" + Base64(DPAPI(UTF8(JSON)))
        v3.10: Atomar über Write-AtomicTextFile (Sektion 2j) - bisher Set-Content direkt
        auf die Zieldatei (Absturz = halbe Datei, Schreibfehler wurden still übergangen).
        Fehler gehen jetzt als abfangbarer Fehler an den Aufrufer.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$JsonString,
        [switch]$RequireAtomic = $script:RequireAtomicWrites
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonString)
    $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
        $bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    Write-AtomicTextFile -Path $Path -Content ("APPENC:" + [Convert]::ToBase64String($encrypted)) -RequireAtomic:$RequireAtomic
}

function Read-ProtectedJsonFile {
    <#
    .SYNOPSIS
        Liest eine JSON-Datei - erkennt automatisch, ob verschlüsselt oder Klartext.
    .OUTPUTS
        JSON-String, oder $null bei Fehler / leerer Datei.
    #>
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }

    # Fall 1: verschlüsselt
    if ($raw.TrimStart().StartsWith("APPENC:")) {
        $base64 = $raw.TrimStart().Substring(7).Trim()
        $encrypted = [Convert]::FromBase64String($base64)
        $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encrypted, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return [System.Text.Encoding]::UTF8.GetString($decrypted)
    }
    # Fall 2: Klartext-JSON (Altbestand / Migration von anderem PC)
    try {
        $null = $raw | ConvertFrom-Json -ErrorAction Stop
        return $raw
    } catch {
        Write-Warning "Datei '$Path' ist weder verschlüsselt noch gültiges JSON."
        return $null
    }
}


# --- 3i. Portables AES-256-Backup mit Passphrase (OPTIONAL, v3.9) ---
# Löst das DPAPI-Geräte-/Benutzerbindungs-Problem für den geplanten Umzug.
# FORMAT der .appbackup-Datei:  [Salt 32 Byte][IV 16 Byte][AES-256-CBC-Ciphertext]
# SCHLÜSSELABLEITUNG: PBKDF2 (Rfc2898DeriveBytes), 100.000 Iterationen, SHA256.
# ABLAUF Export:  DPAPI entschlüsseln -> Temp-Klartext -> ZIP -> AES -> Datei
# ABLAUF Import:  AES entschlüsseln -> ZIP entpacken -> mit lokalem DPAPI neu schreiben
# Danach ist die Nutzung auf dem Zielgerät wieder passwortfrei.
# WICHTIG: Nicht-JSON-Dateien (hochgeladene Dokumente) unverändert mitkopieren.
# WICHTIG (PS 5.1): Join-Path akzeptiert nur 2 Argumente - verschachteln, nicht
#          Join-Path $a $b $c (bricht unter Windows PowerShell 5.1).

function Export-AesBackup {
    param(
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][System.Security.SecureString]$Passphrase
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $tempDir = Join-Path -Path $env:TEMP -ChildPath "APP_export_$timestamp"
    $tempZip = Join-Path -Path $env:TEMP -ChildPath "APP_export_$timestamp.zip"
    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # 1a. Config entschlüsseln
        if (Test-Path $script:dataFile) {
            $json = Read-ProtectedJsonFile -Path $script:dataFile
            if ($json) { Set-Content -Path (Join-Path $tempDir "Config.json") -Value $json -Encoding UTF8 }
        }
        # 1b. Tagesdaten entschlüsseln (Ordnerstruktur erhalten)
        if (Test-Path $script:dailyDataDirBase) {
            foreach ($file in @(Get-ChildItem -Path $script:dailyDataDirBase -Recurse -File -ErrorAction SilentlyContinue)) {
                $relativePath = $file.FullName.Substring($script:dailyDataDirBase.Length).TrimStart('\','/')
                $targetPath = Join-Path (Join-Path $tempDir "data") $relativePath
                $targetDir  = Split-Path $targetPath -Parent
                if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
                if ($file.Extension -eq ".json") {
                    $json = Read-ProtectedJsonFile -Path $file.FullName
                    if ($json) { Set-Content -Path $targetPath -Value $json -Encoding UTF8 }
                } else {
                    # Dokumente/Anhänge unverändert übernehmen
                    Copy-Item -LiteralPath $file.FullName -Destination $targetPath -Force
                }
            }
        }

        # 2. ZIP
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $tempZip)
        $zipBytes = [System.IO.File]::ReadAllBytes($tempZip)

        # 3. AES-256-CBC
        $salt = New-Object byte[] 32
        $iv   = New-Object byte[] 16
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($salt); $rng.GetBytes($iv); $rng.Dispose()

        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Passphrase)
        $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        $deriveBytes = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($plainPass, $salt, 100000, "SHA256")
        $key = $deriveBytes.GetBytes(32)
        $deriveBytes.Dispose()
        $plainPass = $null

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $key; $aes.IV = $iv
        $encryptor = $aes.CreateEncryptor()
        $cipherBytes = $encryptor.TransformFinalBlock($zipBytes, 0, $zipBytes.Length)
        $encryptor.Dispose(); $aes.Dispose()

        # 4. [Salt][IV][Cipher]
        $out = [System.IO.File]::Create($OutputPath)
        $out.Write($salt, 0, 32); $out.Write($iv, 0, 16)
        $out.Write($cipherBytes, 0, $cipherBytes.Length)
        $out.Close()
        return $true
    } catch { throw $_ }
    finally {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
    }
}

function Import-AesBackup {
    <#
    .DESCRIPTION
        v3.10 BUGFIX (Datenverlust): Bisher wurde der Datenordner gelöscht, BEVOR die
        importierten Dateien geschrieben waren - ein Fehler mittendrin hinterließ einen leeren
        oder halben Bestand. Jetzt:
          a) Backup-Inhalt vorab prüfen (gültiges JSON) - vor jeder Änderung
          b) Tagesdaten vollständig in einem Staging-Ordner NEBEN "data" aufbauen
          c) Austausch per Umbenennen (data -> Sicherung, Staging -> data), 3 Versuche
          d) Config atomar schreiben; schlägt das fehl, wird der alte Datenordner
             zurückgeholt (Config und Daten bleiben konsistent)
          e) Erst nach vollständigem Erfolg wird der alte Stand entfernt
        Gesperrter Datenordner (geöffnetes Dokument, Explorer-Vorschau, Sync) = sauberer
        Abbruch ohne Änderung.
    #>
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][System.Security.SecureString]$Passphrase
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $tempDir = Join-Path -Path $env:TEMP -ChildPath "APP_import_$timestamp"
    $tempZip = Join-Path -Path $env:TEMP -ChildPath "APP_import_$timestamp.zip"

    # Staging-/Sicherungsordner NEBEN dem Datenordner (gleiches Laufwerk -> Umbenennen statt Kopieren)
    $dataBaseFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($script:dailyDataDirBase).TrimEnd('\', '/')
    $stagingDir   = "$dataBaseFull.import_$timestamp"
    $preImportDir = "$dataBaseFull.vorimport_$timestamp"
    $dataSwapped  = $false
    $moveDirectory = {
        param([string]$Source, [string]$Destination)
        for ($moveAttempt = 1; $moveAttempt -le 3; $moveAttempt++) {
            try { [System.IO.Directory]::Move($Source, $Destination); return }
            catch { if ($moveAttempt -eq 3) { throw }; Start-Sleep -Milliseconds 200 }
        }
    }
    try {
        $fileBytes = [System.IO.File]::ReadAllBytes($InputPath)
        if ($fileBytes.Length -lt 49) { throw "Ungültige Backup-Datei (zu klein)." }
        $salt = $fileBytes[0..31]; $iv = $fileBytes[32..47]
        $cipherBytes = $fileBytes[48..($fileBytes.Length - 1)]

        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Passphrase)
        $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        $deriveBytes = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($plainPass, [byte[]]$salt, 100000, "SHA256")
        $key = $deriveBytes.GetBytes(32); $deriveBytes.Dispose(); $plainPass = $null

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $key; $aes.IV = [byte[]]$iv
        $decryptor = $aes.CreateDecryptor()
        # Falsche Passphrase -> CryptographicException (Padding). Im Aufrufer abfangen
        # und als "Passwort falsch" melden, nicht als technischen Fehler.
        $zipBytes = $decryptor.TransformFinalBlock([byte[]]$cipherBytes, 0, $cipherBytes.Length)
        $decryptor.Dispose(); $aes.Dispose()

        [System.IO.File]::WriteAllBytes($tempZip, $zipBytes)
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempDir)

        $importedConfig  = Join-Path $tempDir "Config.json"
        $importedDataDir = Join-Path $tempDir "data"

        # a) Backup-Inhalt prüfen, BEVOR irgendetwas verändert wird
        $jsonFilesToCheck = @()
        if (Test-Path -LiteralPath $importedConfig)  { $jsonFilesToCheck += @(Get-Item -LiteralPath $importedConfig) }
        if (Test-Path -LiteralPath $importedDataDir) { $jsonFilesToCheck += @(Get-ChildItem -LiteralPath $importedDataDir -Recurse -File -Filter "*.json" -ErrorAction Stop) }
        foreach ($jsonFile in $jsonFilesToCheck) {
            $checkOk = $false
            try {
                $checkContent = Get-Content -LiteralPath $jsonFile.FullName -Raw -Encoding UTF8
                if (-not [string]::IsNullOrWhiteSpace($checkContent)) {
                    $null = $checkContent | ConvertFrom-Json -ErrorAction Stop
                    $checkOk = $true
                }
            } catch { $checkOk = $false }
            if (-not $checkOk) {
                throw "Das Backup enthält eine ungültige Datei ($($jsonFile.Name)). Import abgebrochen - bestehende Daten wurden NICHT verändert."
            }
        }

        # b) Tagesdaten -> DPAPI neu verschlüsseln, in den Staging-Ordner (Bestand unberührt)
        if (Test-Path -LiteralPath $importedDataDir) {
            New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
            foreach ($file in @(Get-ChildItem -LiteralPath $importedDataDir -Recurse -File -ErrorAction Stop)) {
                $relativePath = $file.FullName.Substring($importedDataDir.Length).TrimStart('\', '/')
                $targetPath = Join-Path $stagingDir $relativePath
                $targetDir  = Split-Path $targetPath -Parent
                if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
                if ($file.Extension -eq ".json") {
                    Write-ProtectedJsonFile -Path $targetPath -JsonString (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)
                } else {
                    Copy-Item -LiteralPath $file.FullName -Destination $targetPath -Force -ErrorAction Stop
                }
            }

            # c) Austausch: aktueller Datenordner -> Sicherung, Staging -> Datenordner
            if (Test-Path -LiteralPath $dataBaseFull) {
                try { & $moveDirectory $dataBaseFull $preImportDir }
                catch {
                    throw "Der Datenordner ist gesperrt (z.B. geöffnetes Dokument, Explorer-Vorschau oder Synchronisierung). Import abgebrochen - bestehende Daten wurden NICHT verändert.`n`nDetails: $($_.Exception.Message)"
                }
            }
            try { & $moveDirectory $stagingDir $dataBaseFull }
            catch {
                if (Test-Path -LiteralPath $preImportDir) { & $moveDirectory $preImportDir $dataBaseFull }   # Rückweg
                throw
            }
            $dataSwapped = $true
        }

        # d) Config -> DPAPI (atomar); bei Fehler Tagesdaten zurückrollen
        if (Test-Path -LiteralPath $importedConfig) {
            try {
                Write-ProtectedJsonFile -Path $script:dataFile -JsonString (Get-Content -LiteralPath $importedConfig -Raw -Encoding UTF8)
            } catch {
                if ($dataSwapped -and (Test-Path -LiteralPath $preImportDir)) {
                    $failedDir = "$dataBaseFull.fehlimport_$timestamp"
                    & $moveDirectory $dataBaseFull $failedDir
                    & $moveDirectory $preImportDir $dataBaseFull
                    Remove-Item -LiteralPath $failedDir -Recurse -Force -ErrorAction SilentlyContinue
                    $dataSwapped = $false
                }
                throw
            }
        }

        # e) Erfolg: alten Stand entfernen (Import ersetzt alle Daten)
        if (Test-Path -LiteralPath $preImportDir) {
            Remove-Item -LiteralPath $preImportDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        return $true
    } catch { throw $_ }
    finally {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
        # nicht übernommenen (unvollständigen) Staging-Ordner entfernen
        if (Test-Path -LiteralPath $stagingDir) { Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}


# --- 3j. Unverschlüsselter Migrations-Export (OPTIONAL, v3.9) ---
# Zweck: einfachster Weg auf einen anderen PC / Windows-Benutzer, wenn kein
# Passwort verwaltet werden soll. Erzeugt ein KLARTEXT-ZIP; die Zielinstallation
# erkennt Klartext automatisch (siehe 3h) und verschlüsselt beim nächsten Speichern.
# PFLICHT: LIESMICH-Datei ins ZIP legen UND den Nutzer im Dialog warnen, dass das
# Archiv sensible Daten im Klartext enthält und nach der Migration zu löschen ist.
#
# function Export-PlaintextBackup {
#     param([Parameter(Mandatory)][string]$OutputPath)
#     # identisch zu Export-AesBackup Schritt 1+2, danach ZIP direkt nach $OutputPath
#     # kopieren (kein AES). Zusätzlich vor dem Zippen schreiben:
#     #   Set-Content (Join-Path $tempDir "LIESMICH_Migration.txt") -Value $anleitung -Encoding UTF8
# }


# --- 3k. Versionierte Stammdaten-Migration (OPTIONAL, v3.9) ---
# Gegenstück zu Sektion 1f. Wird in Load-Config aufgerufen, NACHDEM die
# gespeicherte Config über die Defaults gelegt wurde, aber VOR dem Speichern.
#
# EINBINDUNG in Load-Config:
#   $defaultSnapshot     = @($defaultItems)      # VOR dem Überschreiben sichern!
#   $defaultCalcSnapshot = @($defaultCalcItems)
#   ... Config laden/mergen ...
#   $savedVersion = if ($loadedData.CatalogVersion) { [string]$loadedData.CatalogVersion } else { $null }
#   $changed = Merge-NewDefaultItems -ConfigData $configData -DefaultItems $defaultSnapshot `
#                                    -DefaultCalculatedItems $defaultCalcSnapshot -SavedVersion $savedVersion
#   $finalConfig['CatalogVersion'] = $script:CatalogVersion   # erreichten Stand mitschreiben
#
# FALLE: Save-Data MUSS CatalogVersion mitschreiben. Fehlt das Feld, läuft die
# Migration bei jedem Start erneut und holt vom Nutzer gelöschte Einträge zurück.
#
# v3.10: Zusätzlich Korrektur-Migration ($script:CatalogCorrections, Sektion 1f) für
# fachlich korrigierte BESTEHENDE Einträge: nur die genannten Felder, nur einmalig,
# optional nur wenn noch der alte Standardwert gespeichert ist (OnlyIf).

function Merge-NewDefaultItems {
    <#
    .SYNOPSIS
        Zieht Default-Stammdaten neuer Versionen additiv in eine bestehende Config nach.
    .OUTPUTS
        [bool] $true, wenn etwas ergänzt wurde (Config muss gespeichert werden).
    #>
    param(
        [Parameter(Mandatory)]$ConfigData,
        $DefaultItems,
        $DefaultCalculatedItems,
        [string]$SavedVersion
    )
    $changed = $false
    try {
        $savedVer = $null
        if (-not [string]::IsNullOrWhiteSpace($SavedVersion)) {
            [void][version]::TryParse($SavedVersion, [ref]$savedVer)
        }
        $existingNames     = @($ConfigData['Markers']           | ForEach-Object { [string]$_.Name })
        $existingCalcNames = @($ConfigData['CalculatedMarkers'] | ForEach-Object { [string]$_.Name })

        foreach ($addition in $script:CatalogAdditions) {
            $addVer = $null
            if (-not [version]::TryParse($addition.Version, [ref]$addVer)) { continue }
            if ($savedVer -and $addVer -le $savedVer) { continue }   # schon erreicht

            foreach ($name in @($addition.Items)) {
                if ($existingNames -contains $name) { continue }     # nie überschreiben
                $default = $DefaultItems | Where-Object { $_.Name -eq $name } | Select-Object -First 1
                if (-not $default) { Write-Warning "Migration: Default '$name' nicht gefunden."; continue }
                [void]$ConfigData['Markers'].Add($default)
                $existingNames += $name
                $changed = $true
            }
            foreach ($name in @($addition.CalculatedItems)) {
                if ($existingCalcNames -contains $name) { continue }
                $default = $DefaultCalculatedItems | Where-Object { $_.Name -eq $name } | Select-Object -First 1
                if (-not $default) { Write-Warning "Migration: Berechneter Default '$name' nicht gefunden."; continue }
                [void]$ConfigData['CalculatedMarkers'].Add($default)
                $existingCalcNames += $name
                $changed = $true
            }
        }

        # v3.10: Korrekturen bestehender Definitionen (nur genannte Felder, nur einmalig)
        foreach ($correction in @($script:CatalogCorrections)) {
            if (-not $correction) { continue }
            $corrVer = $null
            if (-not [version]::TryParse($correction.Version, [ref]$corrVer)) { continue }
            if ($savedVer -and $corrVer -le $savedVer) { continue }   # schon erreicht
            $targets = @()
            foreach ($calcName in @($correction.CalculatedItems)) { if ($calcName) { $targets += @{ Name = $calcName; Defaults = $DefaultCalculatedItems; List = 'CalculatedMarkers' } } }
            foreach ($itemName in @($correction.Items))           { if ($itemName) { $targets += @{ Name = $itemName; Defaults = $DefaultItems;           List = 'Markers' } } }
            foreach ($target in $targets) {
                $default = @($target.Defaults) | Where-Object { $_.Name -eq $target.Name } | Select-Object -First 1
                if (-not $default) { Write-Warning "Korrektur: Default '$($target.Name)' nicht gefunden."; continue }
                foreach ($existing in @($ConfigData[$target.List] | Where-Object { $_.Name -eq $target.Name })) {
                    # OnlyIf: nur korrigieren, wenn noch der ALTE Standardwert gespeichert ist
                    if ($correction.OnlyIf) {
                        $matchesOld = $true
                        foreach ($condKey in $correction.OnlyIf.Keys) {
                            $existingValue = if ($existing -is [System.Collections.IDictionary]) { $existing[$condKey] } else { $existing.$condKey }
                            $hasKey = if ($existing -is [System.Collections.IDictionary]) { $existing.Contains($condKey) } else { $existing.PSObject.Properties.Name -contains $condKey }
                            if (-not $hasKey -or $existingValue -ne $correction.OnlyIf[$condKey]) { $matchesOld = $false }
                        }
                        if (-not $matchesOld) { Write-Verbose "Korrektur '$($target.Name)' übersprungen (vom Nutzer angepasst)."; continue }
                    }
                    foreach ($field in @($correction.Fields)) {
                        $defaultHasField = if ($default -is [System.Collections.IDictionary]) { $default.Contains($field) } else { $default.PSObject.Properties.Name -contains $field }
                        if (-not $defaultHasField) { continue }
                        $defaultValue = if ($default -is [System.Collections.IDictionary]) { $default[$field] } else { $default.$field }
                        if ($existing -is [System.Collections.IDictionary]) { $existing[$field] = $defaultValue }
                        else { $existing | Add-Member -NotePropertyName $field -NotePropertyValue $defaultValue -Force }
                    }
                    $changed = $true
                }
            }
        }
    } catch { Write-Warning "Stammdaten-Migration fehlgeschlagen: $($_.Exception.Message)" }
    return $changed
}


# --- 3l. Dokument-Archivierung je Datensatz (OPTIONAL, v3.9) ---
# Nutzer lädt beliebige Dateien (Befund-PDF, Foto, Rechnung) zu EINEM Datum hoch.
# NAMENSSCHEMA (Datum bleibt eindeutiger Schlüssel):  YYYY-MM-dd_TAG[_n].ext
# Ablage im Tagesordner aus Get-DailyDataFilePath.
#
# FALLE (Bugfix Blood-Tracker v2.24.1): Die Tagesdaten liegen physisch in einem
# MONATS-Ordner (data\YYYY\MM\). Ein Filter "*_TAG*" trifft deshalb die Dokumente
# ALLER Tage dieses Monats - falsche Anzahl im Button, falsches Dokument geöffnet.
# Deshalb IMMER strikt auf den Datums-Prefix filtern (Regex unten).

function Get-ArchivedDocuments {
    <#
    .SYNOPSIS
        Liefert alle archivierten Dokumente EINES Datums, in Upload-Reihenfolge.
    .OUTPUTS
        Array von System.IO.FileInfo (leer, wenn keine Dokumente existieren).
    #>
    param([Parameter(Mandatory)][string]$DateString)
    try {
        if ([string]::IsNullOrWhiteSpace($DateString)) { return @() }
        $dailyDataFile, $dailyDataDir = Get-DailyDataFilePath -dateString $DateString
        if (-not (Test-Path $dailyDataDir)) { return @() }

        # [PLACEHOLDER] "DOKUMENT" durch das eigene Suffix ersetzen (z.B. BLUTTEST, BELEG)
        $pattern = '^' + [regex]::Escape($DateString) + '_DOKUMENT(_(?<idx>\d+))?(\..+)?$'
        $files = @(Get-ChildItem -Path $dailyDataDir -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match $pattern })
        if ($files.Count -eq 0) { return @() }
        return @($files | Sort-Object `
                   @{ Expression = { if ($_.Name -match $pattern -and $Matches['idx']) { [int]$Matches['idx'] } else { 0 } } }, `
                   @{ Expression = { $_.Name } })
    } catch {
        Write-Warning "Dokument-Erkennung für $DateString fehlgeschlagen: $($_.Exception.Message)"
        return @()
    }
}

# UPLOAD-HANDLER (Mehrfachauswahl, kollisionsfreie Nummerierung):
#   $ofd = New-Object System.Windows.Forms.OpenFileDialog
#   $ofd.Filter = "Alle Dateien (*.*)|*.*"
#   $ofd.Multiselect = $true
#   if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
#       $dailyDataFile, $dailyDataDir = Get-DailyDataFilePath -dateString $selectedDate
#       if (-not (Test-Path $dailyDataDir)) { New-Item -Path $dailyDataDir -ItemType Directory -Force | Out-Null }
#       foreach ($src in @($ofd.FileNames)) {
#           $ext = [System.IO.Path]::GetExtension($src)
#           $targetName = "${selectedDate}_DOKUMENT${ext}"
#           $targetPath = Join-Path -Path $dailyDataDir -ChildPath $targetName
#           $counter = 1
#           while (Test-Path $targetPath) {
#               $targetName = "${selectedDate}_DOKUMENT_${counter}${ext}"
#               $targetPath = Join-Path -Path $dailyDataDir -ChildPath $targetName
#               $counter++
#           }
#           Copy-Item -LiteralPath $src -Destination $targetPath -Force
#       }
#   }
# NACH dem Upload: Anzeige-Button zentral neu aufbauen (siehe Sektion 6l).


# --- 3m. PDF-Text-Import-Pipeline (OPTIONAL, v3.9) ---
# Liest Werte aus einem textbasierten PDF (Laborbefund, Rechnung, Kontoauszug) und
# schlägt sie dem Nutzer in einem Review-Dialog zur Übernahme vor.
# ABLAUF: Bibliothek laden -> Text extrahieren -> parsen -> Review -> speichern
#         -> Original-PDF im Tagesordner archivieren.
#
# GRUNDREGEL: Ein solcher Import ist IMMER "Beta". Die Werte werden NIE ungeprüft
# geschrieben - der Review-Dialog (Sektion 5k) ist Pflicht, nicht Komfort.

function Initialize-PdfLibrary {
    <#
    .SYNOPSIS
        Lädt itextsharp.dll - bei Bedarf automatisch von NuGet herunterladen.
    .OUTPUTS
        $true wenn geladen, sonst $false.
    .NOTES
        Ein NuGet-Paket ist ein ZIP; benötigt wird nur die eine DLL aus lib/net4*.
        Ablage unter <dataDir>\lib\, damit kein Adminrecht nötig ist.
    #>
    $libDir  = Join-Path -Path $script:dataDir -ChildPath "lib"
    $dllPath = Join-Path -Path $libDir -ChildPath "itextsharp.dll"

    if ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq "itextsharp" }) { return $true }
    if (Test-Path $dllPath) {
        try { Add-Type -Path $dllPath -ErrorAction Stop; return $true }
        catch { Write-Warning "itextsharp.dll konnte nicht geladen werden: $($_.Exception.Message)"; return $false }
    }
    try {
        if (-not (Test-Path $libDir)) { New-Item -ItemType Directory -Path $libDir -Force | Out-Null }
        $nugetUrl  = "https://www.nuget.org/api/v2/package/iTextSharp/5.5.13.3"
        $nupkgPath = Join-Path -Path $env:TEMP -ChildPath "itextsharp.5.5.13.3.nupkg"
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($nugetUrl, $nupkgPath)
        $wc.Dispose()

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($nupkgPath)
        $entry = $zip.Entries | Where-Object { $_.FullName -like "lib/net4*/itextsharp.dll" } | Select-Object -First 1
        if (-not $entry) { $zip.Dispose(); throw "itextsharp.dll nicht im NuGet-Paket gefunden." }
        $stream = $entry.Open()
        $fileStream = [System.IO.File]::Create($dllPath)
        $stream.CopyTo($fileStream)
        $fileStream.Close(); $stream.Close(); $zip.Dispose()
        Remove-Item $nupkgPath -Force -ErrorAction SilentlyContinue

        Add-Type -Path $dllPath -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "PDF-Bibliothek Download fehlgeschlagen: $($_.Exception.Message)"
        return $false
    }
}

function Extract-PdfText {
    <#
    .SYNOPSIS
        Extrahiert den gesamten Text aus einer PDF-Datei.
    .NOTES
        Gescannte (reine Bild-)PDFs liefern leeren Text - das ist KEIN Fehler,
        sondern muss dem Nutzer als solches gemeldet werden (kein OCR enthalten).
    #>
    param([Parameter(Mandatory)][string]$PdfPath)
    try {
        $reader = New-Object iTextSharp.text.pdf.PdfReader($PdfPath)
        $sb = New-Object System.Text.StringBuilder
        for ($i = 1; $i -le $reader.NumberOfPages; $i++) {
            [void]$sb.AppendLine([iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($reader, $i))
        }
        $reader.Close()
        return $sb.ToString()
    } catch {
        Write-Warning "PDF-Textextraktion fehlgeschlagen: $($_.Exception.Message)"
        return $null
    }
}

function Build-ImportAliasMap {
    <#
    .SYNOPSIS
        Erstellt die Mapping-Tabelle Alias -> Katalog-Name für den Datei-Import.
    .DESCRIPTION
        Aus "Alanin-Aminotransferase (ALT/GPT)" entstehen: "ALT", "GPT",
        "Alanin-Aminotransferase", plus der volle Name. Längste zuerst (Priorität).
    #>
    $map = @()
    foreach ($item in $script:data.Config.Markers) {
        $name = $item.Name
        $aliases = @()
        if ($name -match '\(([^)]+)\)') {
            $aliases += ($Matches[1] -split '[/,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
        $baseName = ($name -replace '\s*\([^)]*\)\s*', '').Trim()
        if ($baseName) { $aliases += $baseName }
        $aliases += $name
        $aliases = $aliases | Select-Object -Unique | Sort-Object { $_.Length } -Descending
        $map += @{ ConfigName = $name; Unit = $item.Unit; Aliases = $aliases; RefMin = $item.RefMin; RefMax = $item.RefMax }
    }
    return $map
}

function Parse-ValuesFromText {
    <#
    .SYNOPSIS
        Parst extrahierten PDF-Text und findet Alias-Wert-Zuordnungen.
    .OUTPUTS
        Array von @{ ItemName; Value; Unit; Confidence; MatchedBy; SourceLine }
    .NOTES
        Konfidenz "Niedrig", wenn der Wert weit außerhalb des 3-fachen
        Referenzbereichs liegt - im Review-Dialog dann per Default NICHT angehakt.
    #>
    param([Parameter(Mandatory)][string]$Text)
    $aliasMap = Build-ImportAliasMap
    $results = @()
    $alreadyMatched = @{}
    $lines = $Text -split "`r?`n" | Where-Object { $_.Trim() }

    foreach ($entry in $aliasMap) {
        if ($alreadyMatched.ContainsKey($entry.ConfigName)) { continue }
        # Qualitative Einträge nie automatisch befüllen (siehe Sektion 1i)
        if ($script:ImportExcludedItems -contains $entry.ConfigName) { continue }

        foreach ($alias in $entry.Aliases) {
            if ($alreadyMatched.ContainsKey($entry.ConfigName)) { break }
            $escapedAlias = [regex]::Escape($alias)
            # Trifft "ALT  42", "ALT: 42", "ALT 42,5", "ALT 4.2"
            $pattern = "(?i)(?<!\w)${escapedAlias}(?!\w)\s*[:\.\s]*\s*(?<value>\d+[.,]?\d*)"

            foreach ($line in $lines) {
                # Zeilen überspringen, die fachlich zu einem ANDEREN Eintrag gehören
                if ($script:ImportSkipLinePatterns -and $script:ImportSkipLinePatterns.ContainsKey($entry.ConfigName) -and
                    ($line -match $script:ImportSkipLinePatterns[$entry.ConfigName])) { continue }
                if ($line -match $pattern) {
                    $rawValue = $Matches['value'] -replace ',', '.'
                    $numValue = 0.0
                    if ([double]::TryParse($rawValue, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$numValue)) {
                        $confidence = "Hoch"
                        if ($entry.RefMin -and $entry.RefMax) {
                            $rangeSpan = $entry.RefMax - $entry.RefMin
                            if ($rangeSpan -gt 0) {
                                if ($numValue -lt ($entry.RefMin - $rangeSpan * 3) -or $numValue -gt ($entry.RefMax + $rangeSpan * 3)) {
                                    $confidence = "Niedrig"
                                }
                            }
                        }
                        $results += @{
                            ItemName   = $entry.ConfigName
                            Value      = $numValue
                            Unit       = $entry.Unit
                            Confidence = $confidence
                            MatchedBy  = $alias
                            SourceLine = $line.Trim().Substring(0, [Math]::Min($line.Trim().Length, 80))
                        }
                        $alreadyMatched[$entry.ConfigName] = $true
                        break
                    }
                }
            }
        }
    }
    return $results
}

# ORCHESTRIERUNG (Import-PdfValues):
#   1. Initialize-PdfLibrary  -> bei $false klare Meldung inkl. manuellem DLL-Pfad
#   2. OpenFileDialog (*.pdf)
#   3. Extract-PdfText        -> < 20 Zeichen = vermutlich Scan/Bild-PDF, abbrechen
#   4. Parse-ValuesFromText   -> 0 Treffer = unbekanntes Layout, abbrechen
#   5. Show-ImportReviewDialog (Sektion 5k) -> bestätigte Werte
#   6. je Wert Save-Data ... -type "Daily"; danach Historie neu laden
#   7. Original-PDF nach <Tagesordner>\YYYY-MM-dd_DOKUMENT[_n].pdf kopieren
#   8. Jeder importierte Wert bekommt die Notiz "PDF-Import (Beta)" -> Rückverfolgbarkeit


# --- 3n. Getrennte Ablage für Zusatz-Messungen (OPTIONAL, v3.12.0) ---
# ENGINEMODUL: 3n und 3r gemeinsam einbauen; bestehende Funktionen nutzen Pruefer aus 3r.
# Muster aus Blood-Tracker v2.33.0 (DEXA-Scan + Schlaf, erst Grundarchitektur, GUI später).
# ABLAGE: <data>\<MeasurementFolderName>\<Kategorie>\<JJJJ>\<JJJJ-MM-TT>.json  (Sektion 1k)
#   - atomar und je nach Schalter verschlüsselt wie alle Datendateien (Write-AppJsonFile)
#   - liegt im data-Ordner -> automatisch in ALLEN Sicherungswegen enthalten
#   - Load-/Save-AllHistorical* überspringen den Ordner (Test-IsMeasurementPath):
#     Tagesdaten und Messungen bleiben getrennt, keine gegenseitige Löschung
# SCHEMA 1: ein Datensatz je Kategorie/Datum; SCHEMA 2: Messungen-Liste, siehe 3r.
#   [ordered]@{ SchemaVersion; Kategorie; Datum (yyyy-MM-dd); Werte = @{ Key = Zahl }; Notiz; Erfasst }
# KATALOG: jeder Wert mit stabilem Key (wird gespeichert), Anzeigename, Einheit, Gruppe,
#   Plausibilitätsgrenzen (PFLICHT - fangen Tipp- und Einheitenfehler ab) und Bewertungs-
#   bereichen NUR, wenn leitlinienbasiert und alters-/geschlechtsunabhängig (sonst leer).
# DATUM fachlich festlegen und dokumentieren (Blood-Tracker: Schlaf = Tag des AUFWACHENS).
# Ohne GUI vollständig testbar (Testharness, Sektion 6Q).

function New-MeasurementDefinition {
    <# Ein Katalogeintrag. Plaus* = erlaubter Eingabebereich, Ref*/Optimal* = Bewertung. #>
    param(
        [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Name, [string]$Unit = '',
        [Parameter(Mandatory)][string]$Group, [double]$PlausMin, [double]$PlausMax,
        $RefMin = $null, $RefMax = $null, $OptimalMin = $null, $OptimalMax = $null, [string]$Description = ''
    )
    # Bereiche immer als Zahl - "-1.0" kommt im Befehlsmodus sonst als TEXT an (PS-5.1-FALLE 8)
    $toNumber = { param($x) if ($null -eq $x -or "$x" -eq '') { $null } else { [double]$x } }
    return [PSCustomObject]@{
        Key = $Key; Name = $Name; Unit = $Unit; Group = $Group; PlausMin = $PlausMin; PlausMax = $PlausMax
        RefMin = (& $toNumber $RefMin); RefMax = (& $toNumber $RefMax)
        OptimalMin = (& $toNumber $OptimalMin); OptimalMax = (& $toNumber $OptimalMax); Description = $Description
    }
}

function Get-MeasurementCatalog {
    <#
    .SYNOPSIS
        Katalog aller Messwerte einer Kategorie. [PLACEHOLDER] je Kategorie erweitern.
    .NOTES
        Aufruf IMMER als @(Get-MeasurementCatalog -Category ...) (PS-5.1-FALLE 1 + 3).
    #>
    param([Parameter(Mandatory)][string]$Category)
    $Category = Resolve-AppMeasurementCategory $Category
    $catalog = New-Object System.Collections.ArrayList
    switch ($Category) {
        'Schlaf' {
            # Schlafdauer 7-9 h: Empfehlung Erwachsene 18-64 J. (National Sleep Foundation,
            # Hirshkowitz et al., Sleep Health 2015). Score: geräteabhängig -> keine Bereiche.
            [void]$catalog.Add((New-MeasurementDefinition -Key 'Schlafdauer' -Name 'Schlafdauer' -Unit 'h' -Group 'Schlaf' -PlausMin 0 -PlausMax 24 -RefMin 7 -RefMax 9 -OptimalMin 7 -OptimalMax 9 -Description 'Gesamtschlafzeit der Nacht.'))
            [void]$catalog.Add((New-MeasurementDefinition -Key 'Schlafscore' -Name 'Schlafscore' -Unit 'Punkte' -Group 'Schlaf' -PlausMin 0 -PlausMax 100 -Description 'Optional, Skala des Messgeräts.'))
            [void]$catalog.Add((New-MeasurementDefinition -Key 'Tiefschlaf' -Name 'Tiefschlaf (N3)' -Unit 'min' -Group 'Schlaf' -PlausMin 0 -PlausMax 1440 -Description 'Optional.'))
        }
        default { foreach ($definition in @(Get-ExtendedMeasurementDefinitions -Category $Category)) { [void]$catalog.Add($definition) } }
    }
    return @($catalog.ToArray())
}

function Resolve-MeasurementDefinition {
    <# Katalogeintrag zu Key ODER Anzeigename (Groß/Klein egal), sonst $null. #>
    param([Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)][string]$KeyOrName)
    $lookup = $KeyOrName.Trim()
    foreach ($definition in @(Get-MeasurementCatalog -Category $Category)) {
        if ($definition.Key -ieq $lookup -or $definition.Name -ieq $lookup) { return $definition }
    }
    return $null
}

function ConvertTo-AppIsoDate {
    <# Datum -> 'yyyy-MM-dd' ([datetime] oder Text wie ConvertTo-AppDate). Kein Datum in der Zukunft. #>
    param([Parameter(Mandatory)]$Date)
    $parsedDate = if ($Date -is [datetime]) { $Date.Date } else { ConvertTo-AppDate -Text ([string]$Date) }
    if ($null -eq $parsedDate) { throw "Ungültiges Datum: '$Date' (erwartet TT.MM.JJJJ oder JJJJ-MM-TT)." }
    if ($parsedDate -gt (Get-Date).Date) { throw "Das Datum $($parsedDate.ToString('dd.MM.yyyy')) liegt in der Zukunft." }
    return $parsedDate.ToString('yyyy-MM-dd')
}

function ConvertTo-AppDurationMinutes {
    <#
    .SYNOPSIS
        Dauer -> Minuten. Stunden ODER Minuten: 95 | 1,5 | "1:35" | "1h 35min" | "1 Std 35 Min" |
        "1,5 h" | "95 min". Reine Zahlen gelten in -DefaultUnit.
    #>
    param([Parameter(Mandatory)]$Value, [ValidateSet('min', 'h')][string]$DefaultUnit = 'min')
    if ($null -eq $Value) { throw 'Dauer fehlt.' }
    $minutes = $null
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal] -or $Value -is [single]) {
        $minutes = if ($DefaultUnit -eq 'h') { [double]$Value * 60 } else { [double]$Value }
    } else {
        $text = ([string]$Value).Trim().ToLowerInvariant() -replace ',', '.'
        $numberPattern = '\d+(?:\.\d+)?'
        $ci = [System.Globalization.CultureInfo]::InvariantCulture
        if ($text -match '^(\d+):([0-5]\d)$') {
            $minutes = [double]$Matches[1] * 60 + [double]$Matches[2]
        } elseif ($text -match "^($numberPattern)\s*(?:h|std|stunde|stunden)\.?\s*(?:($numberPattern)\s*(?:m|min|minute|minuten)?\.?)?$") {
            $minutes = [double]::Parse($Matches[1], $ci) * 60
            if ($Matches[2]) { $minutes += [double]::Parse($Matches[2], $ci) }
        } elseif ($text -match "^($numberPattern)\s*(?:m|min|minute|minuten)\.?$") {
            $minutes = [double]::Parse($Matches[1], $ci)
        } elseif ($text -match "^($numberPattern)$") {
            $plainNumber = [double]::Parse($Matches[1], $ci)
            $minutes = if ($DefaultUnit -eq 'h') { $plainNumber * 60 } else { $plainNumber }
        }
    }
    if ($null -eq $minutes -or [double]::IsNaN($minutes) -or [double]::IsInfinity($minutes) -or $minutes -lt 0) {
        throw "Ungültige Dauer: '$Value' (z.B. 95, 1:35, 1h 35min, 1,5 h)."
    }
    return [Math]::Round($minutes, 1)
}

function Get-MeasurementRoot {
    return (Join-Path -Path $script:dailyDataDirBase -ChildPath $script:MeasurementFolderName)
}

function Test-IsMeasurementPath {
    <# $true, wenn die Datei im Messungs-Ordner liegt (für Load-/Save-AllHistorical* tabu). #>
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not $script:dailyDataDirBase -or
        [string]::IsNullOrWhiteSpace($script:MeasurementFolderName)) { return $false }
    try {
        $rootFull = [System.IO.Path]::GetFullPath((Get-MeasurementRoot)).TrimEnd('\', '/')
        $pathFull = [System.IO.Path]::GetFullPath($Path)
    } catch { return $false }
    return ($pathFull.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase) -or
            $pathFull.StartsWith($rootFull + '/', [System.StringComparison]::OrdinalIgnoreCase))
}

function Get-MeasurementFilePath {
    param([Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)]$Date)
    $Category = Resolve-AppMeasurementCategory $Category
    $isoDate = ConvertTo-AppIsoDate -Date $Date
    return (Join-Path (Join-Path (Join-Path (Get-MeasurementRoot) $Category) $isoDate.Substring(0, 4)) "$isoDate.json")
}

function New-MeasurementRecord {
    <#
    .SYNOPSIS
        Prüft Werte gegen den Katalog und erstellt einen Datensatz (speichert NICHT).
    .PARAMETER Values
        Hashtable Key ODER Anzeigename -> Wert. Zahl oder Text ("18,4"); Werte mit Einheit
        h/min auch als Dauer ("7:30", "7h 30min", "450 min").
    #>
    param([Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)]$Date,
          [Parameter(Mandatory)][hashtable]$Values, [string]$Notiz = '')
    $Category = Resolve-AppMeasurementCategory $Category
    if ($script:MeasurementMultiCategories -contains $Category) { throw 'Diese Kategorie benötigt einen Mehrfachmessungs-Konstruktor aus Sektion 3r.' }
    if ($Values.Count -eq 0) { throw 'Keine Werte angegeben.' }
    $checkedValues = [ordered]@{}
    foreach ($inputKey in @($Values.Keys)) {
        $definition = Resolve-MeasurementDefinition -Category $Category -KeyOrName ([string]$inputKey)
        if (-not $definition) { throw "Unbekannter Wert '$inputKey' (Kategorie $Category)." }
        if ($checkedValues.Contains($definition.Key)) { throw "Wert '$($definition.Name)' ist doppelt angegeben." }
        $rawValue = $Values[$inputKey]
        if ($null -eq $rawValue -or $rawValue -is [bool]) { throw 'Messwert fehlt oder ist ein Wahrheitswert.' }
        $numericValue = $null
        try {
            if ($definition.Unit -eq 'h' -or $definition.Unit -eq 'min') {
                $durationMinutes = ConvertTo-AppDurationMinutes -Value $rawValue -DefaultUnit $definition.Unit
                $numericValue = if ($definition.Unit -eq 'h') { [Math]::Round($durationMinutes / 60, 2) } else { $durationMinutes }
            } elseif ($rawValue -is [string]) { $numericValue = Parse-Number $rawValue }
            else { $numericValue = [double]$rawValue }
        } catch { $numericValue = $null }
        if ($null -eq $numericValue -or [double]::IsNaN($numericValue) -or [double]::IsInfinity($numericValue)) {
            throw "Ungültiger Wert für '$($definition.Name)': '$rawValue'."
        }
        if ($numericValue -lt $definition.PlausMin -or $numericValue -gt $definition.PlausMax) {
            throw "Unplausibler Wert für '$($definition.Name)': $numericValue $($definition.Unit) (erlaubt $($definition.PlausMin) bis $($definition.PlausMax))."
        }
        $checkedValues[$definition.Key] = [double]$numericValue
    }
    return [ordered]@{
        SchemaVersion = $script:MeasurementSchemaVersion; Kategorie = $Category; Datum = (ConvertTo-AppIsoDate -Date $Date)
        Werte = $checkedValues; Notiz = $Notiz; Erfasst = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    }
}

function Save-MeasurementRecord {
    <# Snapshot fuer einen ganzen Tag. Ersetzt bewusst, nach Bestandspruefung unter Sperre. #>
    param([Parameter(Mandatory)]$Record)
    $ErrorActionPreference = 'Stop'
    $copy = Copy-AppMeasurementObject $Record
    $category = Resolve-AppMeasurementCategory $copy.Kategorie
    $date = ConvertTo-AppIsoDate $copy.Datum
    Assert-AppMeasurementRecord -Record $copy -Category $category -Date $date
    $path = Get-MeasurementFilePath -Category $category -Date $date
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
    $lock = $null
    try {
        $lock = [IO.File]::Open(($path+'.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $null = Read-MeasurementDayRecord -Category $category -Date $date
        Write-AppJsonFile -Path $path -JsonString (ConvertTo-CheckedAppJson $copy) -RequireAtomic
    } finally { if ($null -ne $lock) { $lock.Dispose() } }
    return $path
}

function Get-MeasurementRecords {
    <# Normale Pipeline-Elemente: immer @(Get-MeasurementRecords ...). Ladefehler in
       MeasurementLoadFailedFiles; Berechnungen muessen diese Liste pruefen. #>
    param([Parameter(Mandatory)][string]$Category, $From = $null, $To = $null)
    $Category = Resolve-AppMeasurementCategory $Category
    $script:MeasurementLoadFailedFiles = New-Object Collections.ArrayList
    $fromIso = if ($null -ne $From) { ConvertTo-AppIsoDate $From } else { '' }
    $toIso = if ($null -ne $To) { ConvertTo-AppIsoDate $To } else { '' }
    if ($fromIso -and $toIso -and $fromIso -gt $toIso) { throw 'Ungültiger Suchzeitraum.' }
    $directory = Join-Path (Get-MeasurementRoot) $Category
    if (-not (Test-Path -LiteralPath $directory)) { return @() }
    $records = New-Object Collections.ArrayList
    foreach ($file in @(Get-ChildItem -LiteralPath $directory -Filter '*.json' -Recurse -File -ErrorAction Stop)) {
        try {
            $iso = ConvertTo-AppIsoDate $file.BaseName
            $expected = Get-MeasurementFilePath -Category $Category -Date $iso
            if ([IO.Path]::GetFullPath($file.FullName) -ine [IO.Path]::GetFullPath($expected)) { throw 'Unpassender Dateipfad.' }
            $record = Read-MeasurementDayRecord -Category $Category -Date $iso
            if ($null -eq $record) { throw 'Datei während des Ladens entfernt.' }
            if (($fromIso -and $iso -lt $fromIso) -or ($toIso -and $iso -gt $toIso)) { continue }
            [void]$records.Add($record)
        } catch {
            [void]$script:MeasurementLoadFailedFiles.Add($file.FullName)
            Write-Warning 'Messungsdatei nicht lesbar oder unpassend; Auswertung muss Ladefehler berücksichtigen.'
        }
    }
    return @($records | Sort-Object Datum)
}

function Remove-MeasurementRecord {
    <# Entfernt bewusst den ganzen Tag; unbekanntes/defektes Format wird nicht geloescht. #>
    param([Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)]$Date)
    $ErrorActionPreference = 'Stop'
    $Category = Resolve-AppMeasurementCategory $Category
    $dateIso = ConvertTo-AppIsoDate $Date
    $path = Get-MeasurementFilePath -Category $Category -Date $dateIso
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $lock = $null
    try {
        $lock = [IO.File]::Open(($path+'.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $old = Read-MeasurementDayRecord -Category $Category -Date $dateIso
        if ($null -eq $old) { return $false }
        [IO.File]::Delete($path)
        return $true
    } finally { if ($null -ne $lock) { $lock.Dispose() } }
}
# ABGELEITETE WERTE (z.B. Index = Masse / Größe², Anteile in %) NICHT speichern, sondern bei
# Bedarf aus dem Datensatz berechnen - gemessene Werte haben immer Vorrang.


# --- 3o. Transaktionale Wiederherstellung aus ZIP-Backup (PFLICHT mit 5a-Restore, v3.10) ---
# PROBLEM (Blood-Tracker bis v2.26.1): Modus "Alles löschen" löschte ZUERST den Datenordner
# und kopierte DANACH das Backup - ein Fehler beim Kopieren hinterließ einen leeren oder
# halben Bestand. Außerdem: ZIP-Backups enthalten DPAPI-verschlüsselte Dateien des
# Quell-PCs/-Profils - auf einem anderen PC sind sie unlesbar und würden lesbare Daten
# ersetzen. Deshalb VOR der Wiederherstellung Get-UnreadableJsonFiles prüfen.

function Get-UnreadableJsonFiles {
    <#
    .SYNOPSIS
        Relative Pfade aller JSON-Dateien eines Ordners, die hier NICHT lesbar sind.
    .NOTES
        Leere Dateien und der Ordner "lib" ([PLACEHOLDER] eigene Nicht-Daten-Ordner) zählen nicht.
    #>
    param([Parameter(Mandatory)][string]$RootDir)
    $unreadable = New-Object System.Collections.ArrayList
    $rootFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RootDir).TrimEnd('\', '/')
    foreach ($jsonFile in @(Get-ChildItem -LiteralPath $rootFull -Recurse -File -Filter "*.json" -Force -ErrorAction SilentlyContinue)) {
        $relPath = $jsonFile.FullName.Substring($rootFull.Length).TrimStart('\', '/')
        if ((($relPath -split '[\\/]')[0]) -eq 'lib') { continue }
        $isReadable = $false
        try {
            $json = Read-ProtectedJsonFile -Path $jsonFile.FullName
            if ($json) {
                $null = $json | ConvertFrom-Json -ErrorAction Stop
                $isReadable = $true
            } elseif ([string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $jsonFile.FullName -Raw -ErrorAction SilentlyContinue))) {
                $isReadable = $true   # leere Datei - nichts, was verloren gehen kann
            }
        } catch { $isReadable = $false }
        if (-not $isReadable) { [void]$unreadable.Add($relPath) }
    }
    return $unreadable.ToArray()
}

function Invoke-SafeDataRestore {
    <#
    .SYNOPSIS
        Stellt den Datenordner transaktional aus einem entpackten Backup wieder her.
    .DESCRIPTION
        1. Zielzustand vollständig in einem Staging-Ordner NEBEN dem Datenordner aufbauen
           (merge: aktueller Stand + Backup darüber; clean/overwrite: nur Backup).
           Bis hierhin ist nichts verändert.
        2. Austausch per Umbenennen: bisherige Einträge -> Sicherungsordner,
           Staging-Einträge -> Datenordner (je 3 Versuche bei kurzer Sperre).
        3. Bei jedem Fehler: Rückweg (alles an den alten Platz).
        4. Erst nach Erfolg Sicherungs- und Staging-Ordner entfernen.
        Ordner in $excludeNames (z.B. heruntergeladene Bibliotheken, ggf. geladen/gesperrt)
        bleiben unangetastet. Das laufende Script (-ProtectedFile) wird nie verschoben.
    .PARAMETER Mode
        clean = exakt durch das Backup ersetzen | merge = ergänzen, gleichnamige Dateien
        überschreiben | overwrite = wie clean (kein Bestand vorhanden)
    #>
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DataDir,
        [ValidateSet('clean', 'merge', 'overwrite')][string]$Mode = 'clean',
        [string]$ProtectedFile = $null
    )
    $excludeNames = @('lib')   # [PLACEHOLDER] Ordner ohne Nutzerdaten
    $timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $sourceFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourceDir).TrimEnd('\', '/')
    $dataFull   = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DataDir).TrimEnd('\', '/')
    $stageDir   = "$dataFull.restore_$timestamp"
    $oldDir     = "$dataFull.vorrestore_$timestamp"
    $protectedKey = if ($ProtectedFile) { Get-AppPathKey -Path $ProtectedFile } else { $null }
    $movedOut = New-Object System.Collections.ArrayList   # Datenordner -> Sicherungsordner
    $movedIn  = New-Object System.Collections.ArrayList   # Staging -> Datenordner

    $moveEntry = {
        param([string]$Source, [string]$Destination)
        for ($moveAttempt = 1; $moveAttempt -le 3; $moveAttempt++) {
            try {
                if ([System.IO.Directory]::Exists($Source)) { [System.IO.Directory]::Move($Source, $Destination) }
                else { [System.IO.File]::Move($Source, $Destination) }
                return
            } catch { if ($moveAttempt -eq 3) { throw }; Start-Sleep -Milliseconds 200 }
        }
    }
    # Dateibaum kopieren (deterministisch, ohne die Verschachtelungs-Eigenheiten von Copy-Item -Recurse)
    $copyTree = {
        param([string]$From, [string]$To, [string[]]$SkipTopNames)
        $fromFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($From).TrimEnd('\', '/')
        foreach ($srcFile in @(Get-ChildItem -LiteralPath $fromFull -Recurse -File -Force -ErrorAction Stop)) {
            $relPath = $srcFile.FullName.Substring($fromFull.Length).TrimStart('\', '/')
            if ($SkipTopNames -and ($SkipTopNames -contains (($relPath -split '[\\/]')[0]))) { continue }
            if ($protectedKey -and ((Get-AppPathKey -Path $srcFile.FullName) -eq $protectedKey)) { continue }
            $targetFile = Join-Path $To $relPath
            $targetDir  = Split-Path -Path $targetFile -Parent
            if (-not (Test-Path -LiteralPath $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
            Copy-Item -LiteralPath $srcFile.FullName -Destination $targetFile -Force -ErrorAction Stop
        }
    }

    # Staging/Sicherung müssen NEBEN dem Datenordner liegen können (nicht im Laufwerksstamm)
    if ([string]::IsNullOrEmpty((Split-Path -Path $dataFull -Parent))) {
        throw "Der Datenordner '$DataDir' liegt im Laufwerksstamm - Wiederherstellung nicht möglich. Bestehende Daten wurden NICHT verändert."
    }

    try {
        # 1. Zielzustand im Staging-Ordner aufbauen
        New-Item -ItemType Directory -Path $stageDir -Force -ErrorAction Stop | Out-Null
        if ($Mode -eq 'merge' -and (Test-Path -LiteralPath $dataFull)) { & $copyTree $dataFull $stageDir $excludeNames }
        & $copyTree $sourceFull $stageDir @()

        # 2a. Bisherige Einträge in den Sicherungsordner verschieben
        if (-not (Test-Path -LiteralPath $dataFull)) { New-Item -ItemType Directory -Path $dataFull -Force -ErrorAction Stop | Out-Null }
        New-Item -ItemType Directory -Path $oldDir -Force -ErrorAction Stop | Out-Null
        foreach ($entry in @(Get-ChildItem -LiteralPath $dataFull -Force -ErrorAction Stop)) {
            if ($excludeNames -contains $entry.Name) { continue }
            if ($protectedKey -and ((Get-AppPathKey -Path $entry.FullName) -eq $protectedKey)) { continue }
            try { & $moveEntry $entry.FullName (Join-Path $oldDir $entry.Name) }
            catch {
                throw "'$($entry.Name)' im Datenordner ist gesperrt (z.B. geöffnetes Dokument, Explorer-Vorschau oder Synchronisierung). Wiederherstellung abgebrochen - bestehende Daten wurden NICHT verändert.`n`nDetails: $($_.Exception.Message)"
            }
            [void]$movedOut.Add($entry.Name)
        }

        # 2b. Staging-Einträge in den Datenordner übernehmen
        foreach ($entry in @(Get-ChildItem -LiteralPath $stageDir -Force -ErrorAction Stop)) {
            $destination = Join-Path $dataFull $entry.Name
            if (Test-Path -LiteralPath $destination) { continue }   # z.B. "lib" bleibt bestehen
            & $moveEntry $entry.FullName $destination
            [void]$movedIn.Add($entry.Name)
        }

        # 3. Erfolg: Sicherungs- und Staging-Ordner entfernen
        Remove-Item -LiteralPath $oldDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        $originalError = $_
        # Rückweg: neue Einträge zurück ins Staging, alte zurück in den Datenordner
        $rollbackFailed = $false
        for ($i = $movedIn.Count - 1; $i -ge 0; $i--) {
            try { & $moveEntry (Join-Path $dataFull $movedIn[$i]) (Join-Path $stageDir $movedIn[$i]) } catch { $rollbackFailed = $true }
        }
        for ($i = $movedOut.Count - 1; $i -ge 0; $i--) {
            try { & $moveEntry (Join-Path $oldDir $movedOut[$i]) (Join-Path $dataFull $movedOut[$i]) } catch { $rollbackFailed = $true }
        }
        if (Test-Path -LiteralPath $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force -ErrorAction SilentlyContinue }
        if ($rollbackFailed) {
            throw "Wiederherstellung fehlgeschlagen UND der alte Stand konnte nicht vollständig zurückgeholt werden. Bitte NICHTS löschen - der vorherige Stand liegt unter:`n$oldDir`n`nUrsache: $($originalError.Exception.Message)"
        }
        if ((Test-Path -LiteralPath $oldDir) -and (@(Get-ChildItem -LiteralPath $oldDir -Force -ErrorAction SilentlyContinue).Count -eq 0)) {
            Remove-Item -LiteralPath $oldDir -Force -ErrorAction SilentlyContinue
        }
        throw $originalError
    }
}


# --- 3p. Sicherer Datenordner-Umzug (PFLICHT mit 5a "Datenpfad ändern", v3.10) ---
# PROBLEM (Blood-Tracker bis v2.27.1): Move-Item "<Daten>\*" + Remove-Item ohne Prüfung.
# Move-Item verschiebt Ordner nur innerhalb DESSELBEN Laufwerks (Microsoft Learn, Move-Item >
# Notes) - bei einem anderen Laufwerk blieb ein Unterordner zurück und wurde danach gelöscht.
# ABLAUF: kopieren -> jede Kopie prüfen (Größe + SHA256) -> umschalten (Registry) -> ERST
# DANN alten Ordner löschen. Fehler in 1-3: Kopien entfernen, alter Ordner bleibt aktiv.

function Move-DataDirectorySafe {
    <#
    .OUTPUTS
        PSCustomObject @{ FileCount; OldDirRemoved }
    #>
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$TargetDir,
        [Parameter(Mandatory)][scriptblock]$SwitchAction
    )
    $sourceFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($SourceDir).TrimEnd('\', '/')
    $targetFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetDir).TrimEnd('\', '/')
    $sourceKey = Get-AppPathKey -Path $sourceFull
    $targetKey = Get-AppPathKey -Path $targetFull
    $sep = [string][System.IO.Path]::DirectorySeparatorChar
    if ($targetKey -eq $sourceKey -or $targetKey.StartsWith($sourceKey + $sep)) {
        throw "Der Zielordner darf nicht im aktuellen Datenordner liegen. Es wurde nichts verändert."
    }

    $createdFiles = New-Object System.Collections.ArrayList
    $createdDirs  = New-Object System.Collections.ArrayList
    try {
        # 1. Kopieren
        if (-not (Test-Path -LiteralPath $targetFull)) {
            New-Item -ItemType Directory -Path $targetFull -Force -ErrorAction Stop | Out-Null
            [void]$createdDirs.Add($targetFull)
        }
        $sourceFiles = @(Get-ChildItem -LiteralPath $sourceFull -Recurse -File -Force -ErrorAction Stop)
        foreach ($srcFile in $sourceFiles) {
            $relPath = $srcFile.FullName.Substring($sourceFull.Length).TrimStart('\', '/')
            $targetFile = Join-Path $targetFull $relPath
            $targetDir = Split-Path -Path $targetFile -Parent
            if (-not (Test-Path -LiteralPath $targetDir)) {
                # alle fehlenden Ebenen merken (oben -> unten), damit das Aufräumen sie entfernt
                $missingDirs = New-Object System.Collections.ArrayList
                $probeDir = $targetDir
                while ($probeDir -and -not (Test-Path -LiteralPath $probeDir)) { $missingDirs.Insert(0, $probeDir); $probeDir = Split-Path -Path $probeDir -Parent }
                New-Item -ItemType Directory -Path $targetDir -Force -ErrorAction Stop | Out-Null
                foreach ($missingDir in $missingDirs) { [void]$createdDirs.Add($missingDir) }
            }
            Copy-Item -LiteralPath $srcFile.FullName -Destination $targetFile -Force -ErrorAction Stop
            [void]$createdFiles.Add($targetFile)
        }

        # 2. Prüfen (vorhanden, Größe, SHA256)
        foreach ($srcFile in $sourceFiles) {
            $relPath = $srcFile.FullName.Substring($sourceFull.Length).TrimStart('\', '/')
            $targetFile = Join-Path $targetFull $relPath
            if (-not (Test-Path -LiteralPath $targetFile)) { throw "Kopie fehlt: $relPath" }
            if ((Get-Item -LiteralPath $targetFile -Force).Length -ne $srcFile.Length) { throw "Kopie unvollständig (Größe): $relPath" }
            $srcHash = (Get-FileHash -LiteralPath $srcFile.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
            $dstHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256 -ErrorAction Stop).Hash
            if ($srcHash -ne $dstHash) { throw "Kopie fehlerhaft (Prüfsumme): $relPath" }
        }

        # 3. Umschalten (z.B. Registry DataPath)
        & $SwitchAction
    } catch {
        $originalError = $_
        for ($i = $createdFiles.Count - 1; $i -ge 0; $i--) { Remove-Item -LiteralPath $createdFiles[$i] -Force -ErrorAction SilentlyContinue }
        for ($i = $createdDirs.Count - 1; $i -ge 0; $i--) {
            if ((Test-Path -LiteralPath $createdDirs[$i]) -and @(Get-ChildItem -LiteralPath $createdDirs[$i] -Force -ErrorAction SilentlyContinue).Count -eq 0) {
                Remove-Item -LiteralPath $createdDirs[$i] -Force -ErrorAction SilentlyContinue
            }
        }
        throw $originalError
    }

    # 4. Alten Ordner entfernen (best effort - die Daten liegen geprüft im Ziel)
    Remove-Item -LiteralPath $sourceFull -Recurse -Force -ErrorAction SilentlyContinue
    return [PSCustomObject]@{ FileCount = $sourceFiles.Count; OldDirRemoved = (-not (Test-Path -LiteralPath $sourceFull)) }
}


# --- 3q. Tages-Stapelspeicherung (OPTIONAL; v3.11.0) ---
# HERKUNFT: Save-BtBloodValueItems, Blood-Tracker v3.0.0; hier ohne Fachlogik.
# ABHAENGIGKEITEN: 0 AppJsonDepth; 2c ConvertTo-Hashtable; 2e Get-DailyDataFilePath;
#   2j Write-AppJsonFile/Write-AtomicTextFile; 2m ConvertTo-CheckedAppJson;
#   3h Read-/Write-ProtectedJsonFile und System.Security bei DPAPI.
# FORMAT: Tagesobjekt mit Items; weitere Wurzelfelder bleiben unveraendert erhalten.
#   Items=[] oder Liste; historisches Einzelobjekt wird zur Liste normalisiert.
#   Jeder Eintrag braucht Date als exakten ISO-Text passend zum gewaehlten Tag.
# VERTRAEGE:
#   ValidateItem: param($Item), prueft ALLE fachlichen Pflichtfelder, wirft bei Fehler;
#                 KEINE Ausgabe und keine Seiteneffekte. Gilt auch fuer Altbestand.
#   GetIdentity:  param($Item), genau ein nicht leerer stabiler String; keine Ausgabe
#                 neben dem Schluessel. Vergleich ordinal, Gross-/Kleinschreibung relevant.
#                 Falls Namen unabhaengig von Schreibweise gelten: ToUpperInvariant().
#   Zusammengesetzte Schluessel eindeutig kodieren (z.B. JSON), nicht naiv verketten.
#   Diese Callbacks normalisieren NICHT: Umrechnung/Notizen vorher in reiner Vorbereitung.
# ERGEBNIS: genau ein Objekt {Date; AddedCount; TotalCount}, erst nach Dateierfolg.
# FEHLER: immer terminierend, kein Dialog; UI zeigt Fehler und behaelt Eingaben.
# GARANTIE: ein Dateicommit, alle neuen Eintraege gemeinsam oder keiner. Kein Ersetzen,
#   Ueberspringen oder teilweises Speichern von Duplikaten; keine Mehrdatei-Transaktion.
# KONKURRENZ: Alle Schreiber derselben Tagesdatei muessen dieselbe .lock-Datei nutzen.
#   Alte Snapshot-Schreiber (3c/3e) duerfen nicht parallel dazwischen schreiben.
#   Sperrdatei nach Dispose NICHT loeschen (Race mit wartenden/neu startenden Schreibern).
# UI erst nach Erfolg: Historie neu laden -> Listen/Charts aktualisieren -> Eingaben leeren.
function Assert-AppDailyItem {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Item, [Parameter(Mandatory)][string]$DateString,
          [Parameter(Mandatory)][scriptblock]$ValidateItem)
    if ($Item -is [System.Collections.IDictionary]) { $date = $Item['Date'] }
    elseif ($Item -is [System.Management.Automation.PSCustomObject]) { $date = $Item.Date }
    else { throw 'Ein Tagesdatensatz hat keine gültige Objektstruktur.' }
    if ($date -isnot [string] -or $date -cne $DateString) { throw 'Ein Tagesdatensatz gehört nicht zum gewählten Datum.' }
    $output = @(& $ValidateItem $Item)
    if ($output.Count -ne 0) { throw 'ValidateItem darf keine Ausgabe liefern; bei Fehlern throw verwenden.' }
}

function Save-DailyItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DateString,
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][scriptblock]$ValidateItem,
        [Parameter(Mandatory)][scriptblock]$GetIdentity
    )
    $parsedDate = [datetime]::MinValue
    if ($DateString -notmatch '^\d{4}-\d{2}-\d{2}$' -or -not [datetime]::TryParseExact($DateString, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) { throw 'Das Datum muss im Format JJJJ-MM-TT vorliegen.' }
    if ($Items.Count -eq 0) { throw 'Mindestens ein neuer Datensatz ist erforderlich.' }
    # Eigene JSON-Kopie: Caller-Objekte und deren Listen nie durch Validierung veraendern.
    $preparedJson = ConvertTo-CheckedAppJson -InputObject @{ Items = @($Items) }
    $prepared = ConvertTo-Hashtable -InputObject (ConvertFrom-Json -InputObject $preparedJson -ErrorAction Stop)
    $incoming = @($prepared.Items)
    foreach ($item in $incoming) { Assert-AppDailyItem -Item $item -DateString $DateString -ValidateItem $ValidateItem }
    $filePath, $directory = Get-DailyDataFilePath -dateString $DateString
    [void][IO.Directory]::CreateDirectory($directory)
    $lock = $null
    try {
        $lock = [IO.File]::Open(($filePath + '.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $document = @{ Items = @() }
        if (Test-Path -LiteralPath $filePath) {
            $json = Read-ProtectedJsonFile -Path $filePath
            if ([string]::IsNullOrWhiteSpace($json)) { throw 'Der Tagesbestand ist leer oder nicht lesbar; es wird nichts überschrieben.' }
            $document = ConvertTo-Hashtable -InputObject (ConvertFrom-Json -InputObject $json -ErrorAction Stop)
            if ($document -isnot [System.Collections.IDictionary] -or -not $document.Contains('Items') -or $null -eq $document.Items) { throw 'Der Tagesbestand hat ein unbekanntes Format.' }
            if ($document.Items -isnot [System.Collections.IList] -and $document.Items -isnot [System.Collections.IDictionary] -and $document.Items -isnot [System.Management.Automation.PSCustomObject]) { throw 'Die Tagesliste hat ein unbekanntes Format.' }
        }
        $combined = @($document.Items) + @($incoming)
        $identities = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($item in $combined) {
            Assert-AppDailyItem -Item $item -DateString $DateString -ValidateItem $ValidateItem
            $keys = @(& $GetIdentity $item)
            if ($keys.Count -ne 1 -or $keys[0] -isnot [string] -or [string]::IsNullOrWhiteSpace($keys[0])) { throw 'GetIdentity muss genau einen stabilen, nicht leeren Textschlüssel liefern.' }
            if (-not $identities.Add($keys[0])) { throw 'Doppelte Datensätze im Bestand oder in der Eingabe; nichts gespeichert.' }
        }
        $document.Items = @($combined)
        $jsonToSave = ConvertTo-CheckedAppJson -InputObject $document
        Write-AppJsonFile -Path $filePath -JsonString $jsonToSave -RequireAtomic
        return [PSCustomObject]@{ Date = $DateString; AddedCount = $incoming.Count; TotalCount = $combined.Count }
    } finally { if ($null -ne $lock) { $lock.Dispose() } }
}

# MINIMALER EINBAU (nach anwendungsspezifischer Vorbereitung der Eingaben):
# $validate = {
#     param($Item)
#     if ([string]::IsNullOrWhiteSpace([string]$Item.Name) -or $null -eq $Item.Value) {
#         throw 'Name und Wert sind erforderlich.'
#     }
#     # [PLACEHOLDER] Typ, Einheit, Zahlenbereich und weitere Pflichtfelder pruefen.
# }
# $key = { param($Item) ([string]$Item.Name).Trim().ToUpperInvariant() }
# try {
#     $result = Save-DailyItems -DateString $date -Items @($preparedItems) -ValidateItem $validate -GetIdentity $key
#     # Erst hier: Historie neu laden und UI aktualisieren; Fehler dabei als Anzeige-
#     # fehler NACH erfolgreicher Speicherung melden, nicht erneut blind speichern.
# } catch {
#     # Keine Erfolgsmeldung, keine Eingaben leeren; Fehler ohne Daten/volle IDs anzeigen.
# }


# --- 3r. Mehrfachmessungen, Herkunft und Zeitraum-Auswertung (OPTIONAL, v3.12.0) ---
# BASIS: Blood-Tracker v3.0.0, adaptiert an Template-Pfade, Fehler- und Listenvertraege.
# ABHAENGIGKEITEN: 0/1k Konfiguration; 2b Parse-Number; 2c ConvertTo-Hashtable;
#   2j/2m geprueftes atomisches Schreiben; 2l/3n Datum, Katalog und Pfade; 3h DPAPI.
# Schema 1 bleibt fuer Einzel-Tagesdatensaetze (z.B. Schlaf) erhalten. Schema 2:
#   {SchemaVersion=2; Kategorie; Datum; Messungen=[Eintrag,...]}.
# Eintrag: {Kategorie; Datum; Zeit='HH:mm' oder ''; Werte; Kontext; Details;
#           Quelle; Notiz; Hinweise=[]; Erfasst}. Identitaet: Kategorie+Datum+Zeit.
# Genau ein Eintrag ohne Uhrzeit pro Tag. Aktivitaet: ein konsolidierter Tages-Eintrag.
# Kein automatisches Mischen mehrerer Geraetesummen; -Replace ersetzt den ganzen Eintrag.
# Hersteller/Geraet/Quelle sind freie Metadaten. Es gibt keine Apple-Abhaengigkeit.
# Neue Kategorien: USER-KONFIGURATION -> MeasurementCategories/MultiCategories und
# CustomMeasurementDefinitions ergaenzen. Werte muessen dieselbe kanonische Einheit haben.
# Keine Einheiten still umrechnen; Adapter fuer Importe muessen explizit normalisieren.
# Eigene fachliche Zusatzregeln vor New-GenericMeasurementEntry pruefen. Der generische
# Konstruktor ist fuer eigene Kategorien; Aktivitaet/Fitness haben spezialisierte Regeln.
#
# LISTEN: Alle Get-/Read-Listen liefern normale Pipeline-Elemente: IMMER @(Get-...).
# Anders als Blood-Tracker KEIN Komma-Return. Leere Liste -> @(), ein Element -> @(Objekt).
# Schreibende Funktionen liefern Pfad bzw. Remove liefert bool; Fehler terminieren.
# Alle Messungsschreiber teilen .lock-Dateien (FileShare.None). Nicht loeschen nach Dispose.
# Unbekannte/defekte Formate blockieren Aenderungen; keine automatische Schema-Migration.
# Vorhandene Tagesdateien werden vor Ersetzen/Loeschen erneut validiert. Snapshot-Speichern
# ersetzt bewusst den gesamten Tag; Read-Modify-Write nur ueber Add-/Remove-MeasurementEntry.
#
# ZEITRAEUME: eigener Store _messungen\_zeitraeume\Aktivitaet.json, Schema 1. Ein Eintrag
# je Messgroesse/Zeitraum/Quelle/Verfahren; Id dient nur gezieltem Bearbeiten/Loeschen.
# Keine IDs loggen. Quellmittel nie mit Tageswerten addieren, aufteilen oder neu mitteln.
# YTD: 1. Januar bis Stichtag inklusive. Last6Months: Stichtag.AddMonths(-6).AddDays(1)
# bis Stichtag inklusive (keine festen 180 Tage, kein Fenster ganzer abgeschlossener Monate).
# Berechnung mittelt nur vorhandene abgeschlossene Tage; fehlend ist NICHT null/0.
# Ergebnis weist Nenner, Datenabdeckung, letzten Wert, Ausnahmen und Quellen getrennt aus.
# Cardio: Training und Tagesmittel getrennt; Intervall/Verfahren unbekannt -> keine
# automatische Zusammenfassung. Negative Quellwerte bleiben mit Hinweis erhalten.
# Exaktes Quellenfenster hat Vorrang; mehrere Quellen bleiben sichtbar nebeneinander.
# Abweichung ist rechnerisch, keine medizinische Bewertung. Nur Anzeige wird gerundet.
# Get-ActivitySummary blockiert bei Ladefehlern; Measure-ActivitySummary rechnet ohne I/O.
#
# MINIMALBEISPIEL (nur BETA-Pfade initialisieren, nie echte Nutzerdaten fuer Tests):
# $entry = New-ActivityEntry -Date '2026-01-02' -Werte @{Schritte=6500} -Quelle 'App A' -Geraet 'Uhr A'
# $path = Add-MeasurementEntry -Entry $entry
# $days = @(Get-MeasurementEntries -Category Aktivitaet)
# $period = New-ActivityPeriodRecord -From '2026-01-01' -To '2026-01-31' -ValueKey Schritte -Value 6250.5 -Anzahl 25 -Quelle 'App A'
# $path = Save-ActivityPeriodRecord -Record $period
# $report = Get-ActivitySummary -Period YTD -AsOf '2026-01-31'
# QS: 0/1/viele, Duplikat/Replace, Altschema, kaputte Datei, Sperre, DPAPI, fehlend/0,
# Fenster/Schaltjahr, Herkunft/Intervalle, Quellenabweichung, unbekannte Abdeckung.

function Resolve-AppMeasurementCategory {
    param([Parameter(Mandatory)][string]$Category)
    # Kategorien werden Teil eines Pfades: Konfiguration darf kein Traversal erlauben.
    if ($Category -notmatch '^[A-Za-z][A-Za-z0-9_]*$') { throw 'Unzulässiger Kategorie-Schlüssel.' }
    foreach ($known in $script:MeasurementCategories) { if ($known -ieq $Category) { return [string]$known } }
    throw 'Unbekannte Messungs-Kategorie.'
}

function Copy-AppMeasurementObject {
    param([Parameter(Mandatory)]$Value)
    return (ConvertTo-Hashtable -InputObject (ConvertFrom-Json -InputObject (ConvertTo-CheckedAppJson -InputObject $Value) -ErrorAction Stop))
}

function Get-ExtendedMeasurementDefinitions {
    # Nur technische Wertebereiche; keine medizinischen Bewertungen. Quelle der
    # Begriffe: Blood-Tracker v3.0.0, Bausteine v2.41/v2.42/v2.45. Keine Web-API noetig.
    param([Parameter(Mandatory)][string]$Category)
    $Category = Resolve-AppMeasurementCategory $Category
    switch ($Category) {
        'Aktivitaet' {
            New-MeasurementDefinition -Key 'Aktivitaetsenergie' -Name 'Aktivitätsenergie' -Unit 'kcal' -Group 'Aktivität' -PlausMin 0 -PlausMax ([double]::MaxValue) -Description 'Konsolidierte aktive Energie pro Tag ohne Ruheenergie. Keine Addition von Gerätesummen; ohne medizinische Bewertung.'
            New-MeasurementDefinition -Key 'Schritte' -Name 'Schritte' -Unit 'Schritte' -Group 'Aktivität' -PlausMin 0 -PlausMax 9007199254740991 -Description 'Tagesgesamtwert ganzzahlig, übernommenes Zeitraum-Mittel darf Nachkommastellen haben. Fehlende Tage sind keine Nullwerte.'
            New-MeasurementDefinition -Key 'CardioErholung' -Name 'Cardio-Erholung (Tagesmittel)' -Unit 'bpm' -Group 'Aktivität' -PlausMin (-[double]::MaxValue) -PlausMax ([double]::MaxValue) -Description 'Übernommenes Tagesmittel; Erholungsintervall und Verfahren separat erhalten. Negative Quellenwerte bleiben erhalten; keine medizinische Bewertung.'
        }
        'Fitness' {
            New-MeasurementDefinition -Key 'CardioErholung' -Name 'Cardio-Erholung' -Unit 'bpm' -Group 'Fitness' -PlausMin (-[double]::MaxValue) -PlausMax ([double]::MaxValue) -Description 'Quellenwert je Training; unbekanntes Intervall nicht ergänzen und nicht automatisch mit anderen Verfahren zusammenfassen.'
            New-MeasurementDefinition -Key 'VO2max' -Name 'VO2max' -Unit 'ml/kg/min' -Group 'Fitness' -PlausMin 0 -PlausMax ([double]::MaxValue) -Description 'Quellenwert mit Messverfahren; Laborwerte und Geräteschätzungen unterscheiden. Keine medizinische Bewertung und keine erfundene obere Warnschwelle.'
        }
        default {
            if (-not $script:CustomMeasurementDefinitions.ContainsKey($Category)) { throw 'Katalog der eigenen Kategorie fehlt.' }
            $seen = @{}
            foreach ($definition in @($script:CustomMeasurementDefinitions[$Category])) {
                if ($definition -isnot [hashtable]) { throw 'Eigene Katalogdefinition muss eine Hashtable sein.' }
                foreach ($required in @('Key','Name','Group','Unit','PlausMin','PlausMax','Description')) {
                    if (-not $definition.ContainsKey($required)) { throw 'Eigene Katalogdefinition ist unvollständig.' }
                }
                if ([string]::IsNullOrWhiteSpace($definition.Key) -or $seen.ContainsKey($definition.Key)) { throw 'Leerer oder doppelter Katalog-Schlüssel.' }
                $seen[$definition.Key] = $true
                $min = [double]$definition.PlausMin; $max = [double]$definition.PlausMax
                if ([double]::IsNaN($min) -or [double]::IsInfinity($min) -or [double]::IsNaN($max) -or [double]::IsInfinity($max) -or $min -gt $max) { throw 'Ungültige Katalog-Grenzen.' }
                New-MeasurementDefinition @definition
            }
        }
    }
}

function New-GenericMeasurementEntry {
    <# Fachneutraler Konstruktor fuer eigene Kategorien. Liefert Objekt, schreibt nichts. #>
    param([Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)]$Date, $Zeit = '',
          [Parameter(Mandatory)][hashtable]$Werte, [string]$Kontext = '', [hashtable]$Details = @{},
          [string]$Quelle = '', [string]$Geraet = '', [string]$Notiz = '')
    $Category = Resolve-AppMeasurementCategory $Category
    if ($script:MeasurementMultiCategories -notcontains $Category -or $Category -in @('Aktivitaet','Fitness')) { throw 'Kategorie benötigt einen eigenen spezialisierten Konstruktor.' }
    $checked = ConvertTo-CheckedMeasurementValues -Category $Category -Values $Werte
    if ($checked.Count -eq 0) { throw 'Keine Messwerte angegeben.' }
    $metadata = Copy-AppMeasurementObject $Details
    $metadata['Geraet'] = $Geraet.Trim()
    return (New-MeasurementEntryObject -Category $Category -Date $Date -Zeit $Zeit -Werte $checked -Kontext $Kontext -Details $metadata -Quelle $Quelle.Trim() -Notiz $Notiz -Hinweise @())
}

function Assert-AppMeasurementEntry {
    # Prueft auch gespeicherte Daten; kein Umformen oder Wegwerfen von Metadaten.
    param([Parameter(Mandatory)]$Entry, [Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)][string]$Date)
    if ($Entry -isnot [Collections.IDictionary]) { throw 'Messung hat keine Objektstruktur.' }
    foreach ($name in @('Kategorie','Datum','Zeit','Kontext','Quelle','Notiz','Erfasst')) {
        if (-not $Entry.Contains($name) -or $Entry[$name] -isnot [string]) { throw 'Messung hat ein fehlendes oder ungültiges Textfeld.' }
    }
    if ($Entry.Kategorie -cne $Category -or $Entry.Datum -cne $Date -or (ConvertTo-AppMeasurementTime $Entry.Zeit) -cne $Entry.Zeit) { throw 'Kategorie, Datum oder Uhrzeit der Messung ist unpassend.' }
    if ($Entry.Details -isnot [Collections.IDictionary] -or $Entry.Hinweise -isnot [Collections.IList] -or @($Entry.Hinweise | Where-Object { $_ -isnot [string] }).Count -gt 0) { throw 'Metadaten oder Hinweise der Messung sind ungültig.' }
    if ($Entry.Werte -isnot [hashtable]) { throw 'Wertetabelle der Messung ist ungültig.' }
    $checked = ConvertTo-CheckedMeasurementValues -Category $Category -Values $Entry.Werte
    if ($checked.Count -eq 0) { throw 'Messung enthält keine Werte.' }
    foreach ($valueKey in $checked.Keys) { if (-not $Entry.Werte.ContainsKey($valueKey)) { throw 'Gespeicherte Werte benötigen kanonische Katalog-Schlüssel.' } }
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($Entry.Erfasst,'yyyy-MM-ddTHH:mm:ss',[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$parsed)) { throw 'Erfassungszeitpunkt ist ungültig.' }
    if ($Category -eq 'Aktivitaet') {
        if ($Entry.Zeit -ne '' -or $Entry.Kontext -ne 'Tag' -or $Entry.Details.Datenart -cne 'Tageswerte' -or $Entry.Details.Herkunft -cne 'Quelle' -or $Entry.Details.TagesAbgeschlossen -isnot [bool]) { throw 'Ungültiger konsolidierter Tageswert.' }
        if ($checked.Contains('Schritte') -and $checked.Schritte -ne [Math]::Truncate($checked.Schritte)) { throw 'Tages-Schritte müssen ganzzahlig sein.' }
    }
    if ($checked.Contains('CardioErholung') -and $Category -in @('Aktivitaet','Fitness')) {
        $details = $Entry.Details.CardioErholung
        $expected = if ($Category -eq 'Aktivitaet') { 'Tagesmittel' } else { 'Training' }
        if ($details -isnot [Collections.IDictionary] -or $details.Datenart -cne $expected -or $details.Methode -isnot [string]) { throw 'Unpassende Cardio-Metadaten.' }
        $verified = New-AppCardioRecoveryDetails -Datenart $expected -ErholungsintervallSekunden $details.ErholungsintervallSekunden -AnzahlMessungen $details.AnzahlMessungen -Methode $details.Methode
        if ($expected -eq 'Training' -and $details.AnzahlMessungen -ne 1) { throw 'Ein Trainingswert benötigt die Messungsanzahl 1.' }
    }
}

function Assert-AppMeasurementRecord {
    param([Parameter(Mandatory)]$Record, [Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)][string]$Date)
    if ($Record -isnot [Collections.IDictionary] -or $Record.Kategorie -cne $Category -or $Record.Datum -cne $Date) { throw 'Tagesdatei passt nicht zu Kategorie/Datum.' }
    if ($script:MeasurementMultiCategories -contains $Category) {
        if (($Record.SchemaVersion -isnot [int] -and $Record.SchemaVersion -isnot [long]) -or $Record.SchemaVersion -ne $script:MeasurementMultiSchemaVersion -or $Record.Messungen -isnot [Collections.IList]) { throw 'Unbekanntes Mehrfachmessungs-Format.' }
        if (@($Record.Keys | Where-Object { $_ -notin @('SchemaVersion','Kategorie','Datum','Messungen') }).Count -gt 0) { throw 'Unbekannte Tagesfelder; keine automatische Änderung.' }
        if ($Record.Messungen.Count -eq 0 -or ($Category -eq 'Aktivitaet' -and $Record.Messungen.Count -ne 1)) { throw 'Unpassende Anzahl von Tagesmessungen.' }
        $times = @{}
        foreach ($entry in $Record.Messungen) {
            Assert-AppMeasurementEntry -Entry $entry -Category $Category -Date $Date
            if ($times.ContainsKey($entry.Zeit)) { throw 'Doppelte Uhrzeit im Tagesbestand.' }
            $times[$entry.Zeit] = $true
        }
    } else {
        if (($Record.SchemaVersion -isnot [int] -and $Record.SchemaVersion -isnot [long]) -or $Record.SchemaVersion -ne $script:MeasurementSchemaVersion -or $Record.Werte -isnot [hashtable]) { throw 'Unbekanntes Einzel-Tagesformat.' }
        $null = New-MeasurementRecord -Category $Category -Date $Date -Values $Record.Werte
    }
}

function Read-MeasurementDayRecord {
    <# Keine Datei -> null; unbekannt/defekt -> terminierender Fehler ohne Ueberschreiben. #>
    param([Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)]$Date)
    $Category = Resolve-AppMeasurementCategory $Category
    $iso = ConvertTo-AppIsoDate $Date
    $path = Get-MeasurementFilePath -Category $Category -Date $iso
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $json = Read-ProtectedJsonFile -Path $path 3>$null
    if ([string]::IsNullOrWhiteSpace($json) -or -not $json.TrimStart().StartsWith('{')) { throw 'Tagesdatei ist leer oder nicht lesbar.' }
    $record = ConvertTo-Hashtable -InputObject (ConvertFrom-Json -InputObject $json -ErrorAction Stop)
    Assert-AppMeasurementRecord -Record $record -Category $Category -Date $iso
    return $record
}

function Add-MeasurementEntry {
    <# Pruefen + Append in einer Sperre. -Replace braucht genau eine vorhandene Uhrzeit. #>
    param([Parameter(Mandatory)]$Entry, [switch]$Replace)
    $ErrorActionPreference = 'Stop'
    $candidate = Copy-AppMeasurementObject $Entry
    $category = Resolve-AppMeasurementCategory $candidate.Kategorie
    if ($script:MeasurementMultiCategories -notcontains $category) { throw 'Kategorie unterstützt keine Mehrfachmessungen.' }
    $date = ConvertTo-AppIsoDate $candidate.Datum
    Assert-AppMeasurementEntry -Entry $candidate -Category $category -Date $date
    $path = Get-MeasurementFilePath -Category $category -Date $date
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
    $lock = $null
    try {
        $lock = [IO.File]::Open(($path+'.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $old = Read-MeasurementDayRecord -Category $category -Date $date
        $entries = @(); if ($null -ne $old) { $entries = @($old.Messungen) }
        $same = @($entries | Where-Object { $_.Zeit -ceq $candidate.Zeit })
        if (($same.Count -gt 0 -and -not $Replace) -or ($Replace -and $same.Count -ne 1)) { throw 'Duplikat oder fehlendes Ersetzungsziel; nichts gespeichert.' }
        $next = @($entries | Where-Object { $_.Zeit -cne $candidate.Zeit }) + @($candidate)
        $record = @{SchemaVersion=$script:MeasurementMultiSchemaVersion; Kategorie=$category; Datum=$date; Messungen=@($next | Sort-Object Zeit)}
        Assert-AppMeasurementRecord -Record $record -Category $category -Date $date
        Write-AppJsonFile -Path $path -JsonString (ConvertTo-CheckedAppJson $record) -RequireAtomic
    } finally { if ($null -ne $lock) { $lock.Dispose() } }
    return $path
}

function Remove-MeasurementEntry {
    <# Loescht exakt eine Uhrzeit; letzter Eintrag -> Tagesdatei entfernen, Lock bleibt. #>
    param([Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)]$Date, $Zeit = '')
    $ErrorActionPreference = 'Stop'
    $Category = Resolve-AppMeasurementCategory $Category
    if ($script:MeasurementMultiCategories -notcontains $Category) { throw 'Kategorie unterstützt keine Mehrfachmessungen.' }
    $dateIso = ConvertTo-AppIsoDate $Date; $time = ConvertTo-AppMeasurementTime $Zeit
    $path = Get-MeasurementFilePath -Category $Category -Date $dateIso
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $lock = $null
    try {
        $lock = [IO.File]::Open(($path+'.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $old = Read-MeasurementDayRecord -Category $Category -Date $dateIso
        if ($null -eq $old) { return $false }
        $kept = @($old.Messungen | Where-Object { $_.Zeit -cne $time })
        if ($kept.Count -eq $old.Messungen.Count) { return $false }
        if ($kept.Count -eq 0) { [IO.File]::Delete($path) }
        else {
            $old.Messungen = @($kept)
            Write-AppJsonFile -Path $path -JsonString (ConvertTo-CheckedAppJson $old) -RequireAtomic
        }
        return $true
    } finally { if ($null -ne $lock) { $lock.Dispose() } }
}

function Get-MeasurementEntries {
    <# Normale Pipeline-Ausgabe; Aufrufer IMMER @(Get-MeasurementEntries ...). #>
    param([Parameter(Mandatory)][string]$Category, $From = $null, $To = $null, [string]$ValueKey = '')
    $Category = Resolve-AppMeasurementCategory $Category
    if ($script:MeasurementMultiCategories -notcontains $Category) { throw 'Kategorie unterstützt keine Mehrfachmessungen.' }
    $filter = ''
    if ($ValueKey) {
        $def = Resolve-MeasurementDefinition -Category $Category -KeyOrName $ValueKey
        if ($null -eq $def) { throw 'Unbekannter Messwertfilter.' }
        $filter = $def.Key
    }
    $result = New-Object Collections.ArrayList
    foreach ($day in @(Get-MeasurementRecords -Category $Category -From $From -To $To)) {
        foreach ($entry in @($day.Messungen)) {
            if ($filter -and ($null -eq $entry.Werte[$filter] -or [string]::IsNullOrWhiteSpace([string]$entry.Werte[$filter]))) { continue }
            [void]$result.Add([pscustomobject]$entry)
        }
    }
    return @($result | Sort-Object Datum, Zeit)
}


function ConvertTo-AppMeasurementTime {
    <#
    .SYNOPSIS
        v2.35.0: Uhrzeit -> 'HH:mm' ('' = unbekannt). Erlaubt [datetime], "7:05", "07:05", "7.05", "07:05:30".
    #>
    param($Time)
    if ($null -eq $Time) { return '' }
    if ($Time -is [datetime]) { return $Time.ToString('HH:mm') }
    $text = ([string]$Time).Trim()
    if ($text -eq '') { return '' }
    if ($text -match '^(\d{1,2})[:.](\d{2})(?::[0-5]\d)?$') {
        $hours = [int]$Matches[1]; $minutes = [int]$Matches[2]
        if ($hours -le 23 -and $minutes -le 59) { return ('{0:00}:{1:00}' -f $hours, $minutes) }
    }
    throw "Ungültige Uhrzeit: '$Time' (erwartet HH:MM, z. B. 07:30)."
}

function Resolve-AppMeasurementOption {
    <# v2.35.0: Auswahlwert prüfen (Groß/Klein egal) -> Schreibweise der Liste; leer -> ''. #>
    param([string]$Value, [string[]]$Allowed, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    foreach ($option in $Allowed) { if ($option -ieq $Value.Trim()) { return $option } }
    throw "Ungültige Angabe für $Label`: '$Value' (erlaubt: $($Allowed -join ', '))."
}

function ConvertTo-CheckedMeasurementValues {
    <#
    .SYNOPSIS
        v2.35.0: Prüft Werte gegen den Katalog einer Kategorie: Schlüssel oder Anzeigename -> Zahl
        im Plausibilitätsbereich (Text mit Komma erlaubt). Leere Felder werden ignoriert.
    .OUTPUTS
        Geordnete Hashtable Schlüssel -> [double].
    #>
    param([Parameter(Mandatory)][string]$Category, [hashtable]$Values)
    $checked = [ordered]@{}
    if (-not $Values) { return $checked }
    foreach ($inputKey in @($Values.Keys)) {
        $rawValue = $Values[$inputKey]
        if ($null -eq $rawValue -or ([string]$rawValue).Trim() -eq '') { continue }
        $definition = Resolve-MeasurementDefinition -Category $Category -KeyOrName ([string]$inputKey)
        if (-not $definition) { throw "Unbekannter Messwert '$inputKey' in Kategorie '$Category'." }
        if ($checked.Contains($definition.Key)) { throw "Messwert '$($definition.Name)' ist doppelt angegeben." }
        if ($rawValue -is [bool]) { throw 'Messwerte müssen Zahlen sein, keine Wahrheitswerte.' }
        $numericValue = $null
        try { $numericValue = if ($rawValue -is [string]) { Parse-Number $rawValue } else { [double]$rawValue } } catch { $numericValue = $null }
        if ($null -eq $numericValue -or [double]::IsNaN($numericValue) -or [double]::IsInfinity($numericValue)) { throw "Ungültiger Zahlenwert für '$($definition.Name)': '$rawValue'." }
        if ($numericValue -lt $definition.PlausMin -or $numericValue -gt $definition.PlausMax) {
            throw "Unplausibler Wert für '$($definition.Name)': $numericValue $($definition.Unit) (erlaubt $($definition.PlausMin) bis $($definition.PlausMax))."
        }
        $checked[$definition.Key] = [double]$numericValue
    }
    return $checked
}

function New-MeasurementEntryObject {
    <# v2.35.0 (intern): baut einen geprüften Messungs-Eintrag; Datum/Uhrzeit nicht in der Zukunft. #>
    param([string]$Category, $Date, $Zeit, $Werte, [string]$Kontext, $Details, [string]$Quelle, [string]$Notiz, $Hinweise)
    if ($script:MeasurementFutureToleranceMinutes -isnot [int] -or $script:MeasurementFutureToleranceMinutes -lt 0 -or $script:MeasurementFutureToleranceMinutes -gt 60) { throw 'Ungültige Uhrzeit-Toleranz (0..60 Minuten).' }
    $isoDate = ConvertTo-AppIsoDate -Date $Date
    $timeText = ConvertTo-AppMeasurementTime -Time $Zeit
    if ($timeText -and $isoDate -eq (Get-Date).ToString('yyyy-MM-dd')) {
        $entryMoment = [datetime]::ParseExact("$isoDate $timeText", 'yyyy-MM-dd HH:mm', [System.Globalization.CultureInfo]::InvariantCulture)
        if ($entryMoment -gt (Get-Date).AddMinutes($script:MeasurementFutureToleranceMinutes)) { throw "Die Uhrzeit $timeText liegt in der Zukunft." }
    }
    $hintList = @(@($Hinweise) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    foreach ($hint in $hintList) { Write-Warning "$Category $isoDate $timeText`: $hint" }
    if ($null -eq $Details) { $Details = [ordered]@{} }
    return [ordered]@{
        Kategorie = $Category; Datum = $isoDate; Zeit = $timeText; Werte = $Werte; Kontext = $Kontext; Details = $Details
        Quelle = $Quelle; Notiz = $Notiz; Hinweise = $hintList; Erfasst = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
    }
}

function Get-AppActivityHints {
    # Technische Hinweise, keine medizinische Einstufung. Quellwerte unveraendert lassen.
    param($Values)
    $hints = @()
    foreach ($key in @('Aktivitaetsenergie', 'Schritte', 'CardioErholung')) {
        if (-not $Values.Contains($key)) { continue }
        if ($key -eq 'CardioErholung' -and $Values[$key] -lt 0) { $hints += 'Negative Cardio-Erholung aus der Quelle übernommen. Vorzeichen, Messverfahren und Erholungsintervall prüfen; keine automatische Korrektur.' }
        $limit = $script:ActivityWarningUpperBounds[$key]
        if ($null -eq $limit) { continue }
        $limitNumber = $null
        try { $limitNumber = if ($limit -is [string]) { Parse-Number $limit } else { [double]$limit } } catch { $limitNumber = $null }
        if ($null -eq $limitNumber -or [double]::IsNaN($limitNumber) -or [double]::IsInfinity($limitNumber) -or $limitNumber -lt 0) { throw 'Eine technische Aktivitäts-Warnschwelle in USER-KONFIGURATION ist ungültig.' }
        if ($Values[$key] -gt $limitNumber) { $hints += "Technische Warnschwelle für $key überschritten. Quellwert bleibt unverändert; dies ist keine medizinische Bewertung." }
    }
    return $hints
}

function New-AppCardioRecoveryDetails {
    # $null bleibt unbekannt. Insbesondere Quelle/Geraet niemals als Intervall-Nachweis verwenden.
    param([ValidateSet('Training', 'Tagesmittel')][string]$Datenart, $ErholungsintervallSekunden = $null, $AnzahlMessungen = $null, [string]$Methode = '')
    $interval = $null; $count = $null
    foreach ($field in @('ErholungsintervallSekunden', 'AnzahlMessungen')) {
        $raw = if ($field -eq 'ErholungsintervallSekunden') { $ErholungsintervallSekunden } else { $AnzahlMessungen }
        if ($null -eq $raw -or ($raw -is [string] -and [string]::IsNullOrWhiteSpace($raw))) { continue }
        $number = $null
        try { if ($raw -is [bool]) { throw 'bool' }; $number = if ($raw -is [string]) { Parse-Number $raw } else { [double]$raw } } catch { $number = $null }
        if ($null -eq $number -or [double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -le 0 -or $number -gt 9007199254740991) { throw "Ungültige Angabe für $field (positive endliche Zahl oder unbekannt erforderlich)." }
        if ($field -eq 'AnzahlMessungen') {
            if ($number -ne [Math]::Truncate($number)) { throw 'AnzahlMessungen muss ganzzahlig sein.' }
            $count = [long]$number
        } else { $interval = [double]$number }
    }
    if ($Datenart -eq 'Training') { $count = 1 }
    return [ordered]@{ Datenart = $Datenart; ErholungsintervallSekunden = $interval; AnzahlMessungen = $count; Methode = $Methode.Trim() }
}

function New-ActivityEntry {
    <#
    .SYNOPSIS
        v2.41.0: Konsolidierte Tageswerte; nur erzeugen, speichern mit Add-MeasurementEntry.
    .DESCRIPTION
        Werte: Aktivitaetsenergie (kcal, aktive Energie ohne Ruheenergie), Schritte (ganze Anzahl),
        optional CardioErholung (bpm, ausdruecklich uebernommenes Tagesmittel).
        Keine Aufteilung oder Addition von Quellenwerten. Ein gemeinsamer Eintrag je Tag,
        ohne Uhrzeit. -Replace beim Speichern ersetzt den GESAMTEN Tages-Eintrag.
        Quelle/Geraet sind optionale Herkunftsangaben, keine Bindung an einen Hersteller.
        Vergangene Tage gelten standardmaessig als abgeschlossen, heute als unvollstaendig;
        -TagesAbgeschlossen $false kennzeichnet auch unvollstaendige vergangene Tage.
        Fehlende Werte bleiben fehlend, explizite Nullwerte bleiben erhalten.
    #>
    param(
        [Parameter(Mandatory)]$Date, [Parameter(Mandatory)][hashtable]$Werte,
        $TagesAbgeschlossen = $null, [string]$Quelle = '', [string]$Geraet = '', [string]$Notiz = '',
        $ErholungsintervallSekunden = $null, $AnzahlCardioMessungen = $null, [string]$ErholungsMethode = ''
    )
    foreach ($raw in $Werte.Values) { if ($raw -is [bool]) { throw 'Aktivitätswerte müssen Zahlen sein, keine Wahrheitswerte.' } }
    $checked = ConvertTo-CheckedMeasurementValues -Category 'Aktivitaet' -Values $Werte
    if ($checked.Count -eq 0) { throw 'Keine Aktivitätswerte angegeben.' }
    if ($checked.Contains('Schritte') -and $checked['Schritte'] -ne [Math]::Truncate($checked['Schritte'])) { throw 'Schritte als Tagesgesamtwert müssen ganzzahlig sein.' }
    $isoDate = ConvertTo-AppIsoDate -Date $Date
    $complete = ($isoDate -lt (Get-Date).ToString('yyyy-MM-dd'))
    if ($null -ne $TagesAbgeschlossen) {
        if ($TagesAbgeschlossen -isnot [bool]) { throw 'TagesAbgeschlossen muss $true oder $false sein.' }
        $complete = $TagesAbgeschlossen
    }
    $details = [ordered]@{ Datenart = 'Tageswerte'; Herkunft = 'Quelle'; TagesAbgeschlossen = [bool]$complete; Geraet = $Geraet.Trim() }
    $hints = @(Get-AppActivityHints -Values $checked)
    if (-not $complete) { $hints += 'Unvollständiger Tag: für spätere Tagesdurchschnitte nicht als vollständigen Tageswert verwenden.' }
    if ($checked.Contains('CardioErholung')) {
        $cardio = New-AppCardioRecoveryDetails -Datenart 'Tagesmittel' -ErholungsintervallSekunden $ErholungsintervallSekunden -AnzahlMessungen $AnzahlCardioMessungen -Methode $ErholungsMethode
        $details['CardioErholung'] = $cardio
        if ($null -eq $cardio.ErholungsintervallSekunden) { $hints += 'Erholungsintervall unbekannt: Cardio-Erholung nicht automatisch mit anderen Messungen zusammenfassen.' }
    } elseif ($null -ne $ErholungsintervallSekunden -or $null -ne $AnzahlCardioMessungen -or $ErholungsMethode) { throw 'Angaben zur Cardio-Erholung benötigen einen Cardio-Erholungswert.' }
    return (New-MeasurementEntryObject -Category 'Aktivitaet' -Date $isoDate -Zeit '' -Werte $checked -Kontext 'Tag' -Details $details -Quelle $Quelle.Trim() -Notiz $Notiz -Hinweise $hints)
}

function New-FitnessEntry {
    <#
    .SYNOPSIS
        v2.41.0: Fitness-Messung (VO2max und/oder CardioErholung je Training), speichert NICHT.
        Cardio-Tagesmittel dagegen mit New-ActivityEntry erzeugen. Quelle/Geraet frei waehlbar.
        -ErholungsintervallSekunden bleibt ohne Angabe unbekannt (z. B. 60 oder 120 explizit).
        -ErholungsMethode dokumentiert das Quellenverfahren, -Methode gilt weiterhin fuer VO2max.
    .PARAMETER Methode
        $script:Vo2maxMethods - Labor und Uhr-Schätzung sind nicht gleichwertig.
    #>
    param([Parameter(Mandatory)]$Date, $Zeit = '', [Parameter(Mandatory)][hashtable]$Werte, [string]$Methode = '', [string]$Quelle = '', [string]$Notiz = '',
          [string]$Geraet = '', $ErholungsintervallSekunden = $null, [string]$ErholungsMethode = '')
    $checked = ConvertTo-CheckedMeasurementValues -Category 'Fitness' -Values $Werte
    if ($checked.Count -eq 0) { throw 'Keine Fitnesswerte angegeben.' }
    $methodValue = Resolve-AppMeasurementOption -Value $Methode -Allowed $script:Vo2maxMethods -Label 'Methode'
    $hints = @()
    if ($checked.Contains('VO2max') -and -not $methodValue) { $hints += 'Messmethode fehlt - Laborwert und Schätzung der Uhr sind nicht gleichwertig.' }
    $details = [ordered]@{}
    if ($methodValue) { $details['Methode'] = $methodValue }
    if ($Geraet.Trim()) { $details['Geraet'] = $Geraet.Trim() }
    if ($checked.Contains('CardioErholung')) {
        foreach ($key in $Werte.Keys) {
            $definition = Resolve-MeasurementDefinition -Category 'Fitness' -KeyOrName $key
            if ($definition -and $definition.Key -eq 'CardioErholung' -and $Werte[$key] -is [bool]) { throw 'Cardio-Erholung muss eine Zahl sein, kein Wahrheitswert.' }
        }
        $cardio = New-AppCardioRecoveryDetails -Datenart 'Training' -ErholungsintervallSekunden $ErholungsintervallSekunden -Methode $ErholungsMethode
        $details['CardioErholung'] = $cardio; $details['Herkunft'] = 'Quelle'
        $hints += @(Get-AppActivityHints -Values $checked)
        if ($null -eq $cardio.ErholungsintervallSekunden) { $hints += 'Erholungsintervall unbekannt: Cardio-Erholung nicht automatisch mit anderen Messungen zusammenfassen.' }
    } elseif ($null -ne $ErholungsintervallSekunden -or $ErholungsMethode) { throw 'Angaben zur Cardio-Erholung benötigen einen Cardio-Erholungswert.' }
    return (New-MeasurementEntryObject -Category 'Fitness' -Date $Date -Zeit $Zeit -Werte $checked -Kontext '' -Details $details -Quelle $Quelle -Notiz $Notiz -Hinweise $hints)
}

function New-ActivityPeriodRecord {
    <#
    .SYNOPSIS
        Ein uebernommenes Zeitraum-Mittel vorbereiten; speichert NICHT.
    .DESCRIPTION
        Je Eintrag genau eine Messgroesse. From/To inklusive, keine Zukunft.
        Energie/Schritte = Mittel pro Tag, Schritte duerfen hier Nachkommastellen haben.
        Cardio: Basis Trainingswerte, Tagesmittel oder Unbekannt; niemals automatisch mischen.
        Anzahl = bekannte beruecksichtigte Tage bzw. Trainingsmessungen; null bleibt unbekannt.
        Quelle/Geraet/Methode sind frei waehlbar. Kein Import und keine Berechnung.
        Id/Erfasst erlauben Bearbeitung vorhandener Eintraege ohne neue Identitaet.
    #>
    param(
        [Parameter(Mandatory)]$From, [Parameter(Mandatory)]$To,
        [Parameter(Mandatory)][string]$ValueKey, [Parameter(Mandatory)]$Value,
        [string]$Basis = '', $Anzahl = $null, $ErholungsintervallSekunden = $null,
        [string]$Quelle = '', [string]$Geraet = '', [string]$Methode = '', [string]$Notiz = '',
        [string]$Id = '', [string]$Erfasst = ''
    )
    $fromIso = ConvertTo-AppIsoDate -Date $From
    $toIso = ConvertTo-AppIsoDate -Date $To
    if ($fromIso -gt $toIso) { throw 'Der Beginn des Zeitraums muss vor oder auf seinem Ende liegen.' }
    $definition = Resolve-MeasurementDefinition -Category 'Aktivitaet' -KeyOrName $ValueKey
    if (-not $definition) { throw 'Unbekannte Messgröße für ein Aktivitäts-Zeitraummittel.' }
    if ($null -eq $Value -or $Value -is [bool] -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) { throw 'Ein Zeitraum-Mittel benötigt einen Zahlenwert; fehlend ist nicht null.' }
    $values = ConvertTo-CheckedMeasurementValues -Category 'Aktivitaet' -Values @{ $definition.Key = $Value }
    if ($values.Count -ne 1) { throw 'Ein Zeitraum-Mittel benötigt genau einen Zahlenwert.' }
    $isCardio = ($definition.Key -eq 'CardioErholung')
    $basisValue = $Basis.Trim()
    if (-not $basisValue) { $basisValue = if ($isCardio) { 'Unbekannt' } else { 'Tageswerte' } }
    $allowed = if ($isCardio) { @('Trainingswerte', 'Tagesmittel', 'Unbekannt') } else { @('Tageswerte') }
    $basisValue = Resolve-AppMeasurementOption -Value $basisValue -Allowed $allowed -Label 'Berechnungsbasis'
    if (-not $isCardio -and $null -ne $ErholungsintervallSekunden) { throw 'Ein Erholungsintervall ist nur für Cardio-Erholung zulässig.' }
    # Wiederverwendete Zahlenpruefung; Datenart des Ergebnisses wird hier nicht uebernommen.
    $details = New-AppCardioRecoveryDetails -Datenart 'Tagesmittel' -ErholungsintervallSekunden $ErholungsintervallSekunden -AnzahlMessungen $Anzahl
    if ($basisValue -eq 'Unbekannt' -and $null -ne $details.AnzahlMessungen) { throw 'Bei bekannter Anzahl bitte auch die Berechnungsbasis angeben.' }
    $calendarDays = ([datetime]::ParseExact($toIso, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture) - [datetime]::ParseExact($fromIso, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)).Days + 1
    if ($basisValue -in @('Tageswerte', 'Tagesmittel') -and $null -ne $details.AnzahlMessungen -and $details.AnzahlMessungen -gt $calendarDays) { throw 'Die Anzahl berücksichtigter Tage übersteigt die Länge des Zeitraums.' }
    $parsedId = [guid]::Empty
    if (-not $Id) { $Id = [guid]::NewGuid().ToString('D') }
    if (-not [guid]::TryParseExact($Id, 'D', [ref]$parsedId) -or $parsedId -eq [guid]::Empty) { throw 'Ungültige Kennung des Zeitraum-Eintrags.' }
    $parsedTime = [datetime]::MinValue
    if (-not $Erfasst) { $Erfasst = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss') }
    if (-not [datetime]::TryParseExact($Erfasst, 'yyyy-MM-ddTHH:mm:ss', [cultureinfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedTime)) { throw 'Ungültiger Erfassungszeitpunkt des Zeitraum-Eintrags.' }
    $hints = @(Get-AppActivityHints -Values $values)
    if ($null -eq $details.AnzahlMessungen) { $hints += 'Anzahl berücksichtigter Tage oder Messungen unbekannt; keine vollständige Datenabdeckung ableiten.' }
    if ($isCardio -and $basisValue -eq 'Unbekannt') { $hints += 'Berechnungsbasis unbekannt: nicht automatisch mit Trainingswerten oder Tagesmitteln vergleichen.' }
    if ($isCardio -and $null -eq $details.ErholungsintervallSekunden) { $hints += 'Erholungsintervall unbekannt: Cardio-Erholung nicht automatisch mit anderen Messungen zusammenfassen.' }
    return [ordered]@{
        Id = $parsedId.ToString('D'); Datenart = 'Zeitraummittel'; Herkunft = 'Quelle'
        Von = $fromIso; Bis = $toIso; Messgroesse = $definition.Key; Wert = $values[$definition.Key]; Einheit = $definition.Unit
        Basis = $basisValue; Anzahl = $details.AnzahlMessungen; ErholungsintervallSekunden = $details.ErholungsintervallSekunden
        Quelle = $Quelle.Trim(); Geraet = $Geraet.Trim(); Methode = $Methode.Trim(); Notiz = $Notiz
        Hinweise = @($hints); Erfasst = $Erfasst
    }
}

function ConvertTo-AppActivityPeriodRecord {
    # Validiert vollstaendig vor Schreiben. Unbekannte Felder niemals stillschweigend verlieren.
    param([Parameter(Mandatory)]$Record)
    $required = @('Id','Datenart','Herkunft','Von','Bis','Messgroesse','Wert','Einheit','Basis','Anzahl','ErholungsintervallSekunden','Quelle','Geraet','Methode','Notiz','Hinweise','Erfasst')
    if ($Record -is [System.Collections.IDictionary]) { $keys = @($Record.Keys) }
    elseif ($Record -is [System.Management.Automation.PSCustomObject]) { $keys = @($Record.PSObject.Properties.Name) }
    else { throw 'Ungültiger Zeitraum-Eintrag.' }
    if ($keys.Count -ne $required.Count -or @($required | Where-Object { $keys -notcontains $_ }).Count -gt 0) { throw 'Unbekanntes oder unvollständiges Zeitraum-Format; keine Änderung vorgenommen.' }
    foreach ($field in @('Id','Datenart','Herkunft','Von','Bis','Messgroesse','Einheit','Basis','Quelle','Geraet','Methode','Notiz','Erfasst')) {
        if ($Record.$field -isnot [string]) { throw 'Ungültiges Textfeld im Zeitraum-Eintrag.' }
    }
    if (-not $Record.Id -or -not $Record.Erfasst -or -not $Record.Basis -or $Record.Datenart -cne 'Zeitraummittel' -or $Record.Herkunft -cne 'Quelle') { throw 'Unpassende Datenart oder Herkunft des Zeitraum-Eintrags.' }
    if ($Record.Hinweise -isnot [System.Collections.IList] -or @($Record.Hinweise | Where-Object { $_ -isnot [string] }).Count -gt 0) { throw 'Ungültige Hinweisliste im Zeitraum-Eintrag.' }
    $normalized = New-ActivityPeriodRecord -From $Record.Von -To $Record.Bis -ValueKey $Record.Messgroesse -Value $Record.Wert -Basis $Record.Basis -Anzahl $Record.Anzahl -ErholungsintervallSekunden $Record.ErholungsintervallSekunden -Quelle $Record.Quelle -Geraet $Record.Geraet -Methode $Record.Methode -Notiz $Record.Notiz -Id $Record.Id -Erfasst $Record.Erfasst
    if ($normalized.Einheit -cne $Record.Einheit -or $normalized.Messgroesse -cne $Record.Messgroesse -or $normalized.Von -cne $Record.Von -or $normalized.Bis -cne $Record.Bis) { throw 'Unpassende Einheit, Messgröße oder Datumsform im Zeitraum-Eintrag.' }
    # Historische Hinweise erhalten; aktuelle Warnschwellen aendern keinen gespeicherten Inhalt.
    $normalized.Hinweise = @($Record.Hinweise)
    return $normalized
}

function Get-AppActivityPeriodPath {
    return (Join-Path (Join-Path (Get-MeasurementRoot) $script:MeasurementPeriodFolderName) 'Aktivitaet.json')
}

function Get-AppActivityPeriodIdentity {
    param($Record)
    # Feste Feldreihenfolge, JSON-Escaping statt mehrdeutiger Trennzeichen. Keine Wert-/Anzahlanteile.
    return (ConvertTo-Json -InputObject @($Record.Von, $Record.Bis, $Record.Messgroesse, $Record.Basis, $Record.ErholungsintervallSekunden, $Record.Quelle.ToLowerInvariant(), $Record.Geraet.ToLowerInvariant(), $Record.Methode.ToLowerInvariant()) -Compress)
}

function Read-AppActivityPeriodStore {
    # Fehler blockieren die gesamte Ablage statt still Eintraege beim naechsten Speichern zu verlieren.
    $path = Get-AppActivityPeriodPath
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try {
        $json = Read-ProtectedJsonFile -Path $path 3>$null
        if ([string]::IsNullOrWhiteSpace($json) -or -not $json.TrimStart().StartsWith('{')) { throw 'Leer/Format' }
        $store = $json | ConvertFrom-Json -ErrorAction Stop
        $keys = @($store.PSObject.Properties.Name)
        if ($keys.Count -ne 3 -or @(@('SchemaVersion','Kategorie','Eintraege') | Where-Object { $keys -notcontains $_ }).Count -gt 0 -or ($store.SchemaVersion -isnot [int] -and $store.SchemaVersion -isnot [long]) -or $store.SchemaVersion -ne 1 -or $store.Kategorie -cne 'AktivitaetZeitraeume' -or $store.Eintraege -isnot [System.Collections.IList]) { throw 'Format' }
        $records = @(); $seenIds = @{}; $seenIdentities = @{}
        foreach ($entry in @($store.Eintraege)) {
            $record = ConvertTo-AppActivityPeriodRecord -Record $entry
            $identity = Get-AppActivityPeriodIdentity -Record $record
            if ($seenIds.ContainsKey($record.Id) -or $seenIdentities.ContainsKey($identity)) { throw 'Duplikat' }
            $seenIds[$record.Id] = $true; $seenIdentities[$identity] = $true
            $records += [PSCustomObject]$record
        }
        return @($records)
    } catch { throw 'Die Zeitraum-Ablage ist nicht lesbar oder hat ein unbekanntes/ungültiges Format. Sie bleibt unverändert.' }
}

function Get-ActivityPeriodRecords {
    <#
    .SYNOPSIS
        Quellenmittel laden, optional nach Messgroesse und Zeitraum filtern; keine Berechnung.
    .DESCRIPTION
        Standardfilter: alle ueberlappenden Eintraege, immer mit ihrem GANZEN Originalzeitraum.
        -ExactPeriod benoetigt From UND To und liefert nur genau diesen Zeitraum.
        Normale Pipeline-Liste; Aufrufer IMMER @(Get-ActivityPeriodRecords ...).
    #>
    param($From = $null, $To = $null, [string]$ValueKey = '', [switch]$ExactPeriod)
    $fromIso = if ($null -ne $From) { ConvertTo-AppIsoDate -Date $From } else { '' }
    $toIso = if ($null -ne $To) { ConvertTo-AppIsoDate -Date $To } else { '' }
    if ($fromIso -and $toIso -and $fromIso -gt $toIso) { throw 'Ungültiger Suchzeitraum.' }
    if ($ExactPeriod -and (-not $fromIso -or -not $toIso)) { throw 'ExactPeriod benötigt Anfang und Ende des Zeitraums.' }
    $key = ''
    if ($ValueKey) {
        $definition = Resolve-MeasurementDefinition -Category 'Aktivitaet' -KeyOrName $ValueKey
        if (-not $definition) { throw 'Unbekannte Messgröße für die Zeitraum-Suche.' }
        $key = $definition.Key
    }
    $records = @(Read-AppActivityPeriodStore)
    $selected = @($records | Where-Object {
        (-not $key -or $_.Messgroesse -eq $key) -and
        (-not $fromIso -or $_.Bis -ge $fromIso) -and (-not $toIso -or $_.Von -le $toIso) -and
        (-not $ExactPeriod -or ($_.Von -eq $fromIso -and $_.Bis -eq $toIso))
    } | Sort-Object Von, Bis, Messgroesse, Id)
    return @($selected)
}

function Save-ActivityPeriodRecord {
    <# Neuer Eintrag; vorhandene Id nur mit -Replace. Keine Addition, keine automatische Ueberschreibung. #>
    param([Parameter(Mandatory)]$Record, [switch]$Replace)
    $ErrorActionPreference = 'Stop'
    $candidate = ConvertTo-AppActivityPeriodRecord -Record $Record
    $path = Get-AppActivityPeriodPath; $directory = Split-Path -Parent $path
    $null = [System.IO.Directory]::CreateDirectory($directory)
    $lock = $null
    try {
        $lock = [System.IO.File]::Open(($path + '.lock'), [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $records = @(Read-AppActivityPeriodStore)
        $existing = @($records | Where-Object { $_.Id -eq $candidate.Id })
        if ($existing.Count -gt 0 -and -not $Replace) { throw 'Vorhandener Eintrag' }
        if ($Replace -and $existing.Count -ne 1) { throw 'Ersetzen ohne Ziel' }
        $identity = Get-AppActivityPeriodIdentity -Record $candidate
        if (@($records | Where-Object { $_.Id -ne $candidate.Id -and (Get-AppActivityPeriodIdentity -Record $_) -ceq $identity }).Count -gt 0) { throw 'Doppelte Quelle fuer diesen Zeitraum' }
        $next = @(); $replaced = $false
        foreach ($entry in $records) {
            if ($entry.Id -eq $candidate.Id) { $next += $candidate; $replaced = $true } else { $next += $entry }
        }
        if (-not $replaced) { $next += $candidate }
        $store = [ordered]@{ SchemaVersion = 1; Kategorie = 'AktivitaetZeitraeume'; Eintraege = @($next) }
        Write-AppJsonFile -Path $path -JsonString (ConvertTo-CheckedAppJson $store) -RequireAtomic
    } catch { throw 'Zeitraum-Mittel nicht gespeichert. Ablage/Schreibzugriff prüfen; doppelte Quellenwerte sind gesperrt und Ersetzen benötigt eine vorhandene Kennung mit -Replace.' }
    finally { if ($lock) { $lock.Dispose() } }
    return $path
}

function Remove-ActivityPeriodRecord {
    # Genau eine Kennung entfernen. Eine leere Liste bleibt explizit als [] gespeichert.
    param([Parameter(Mandatory)][string]$Id)
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParseExact($Id, 'D', [ref]$parsedId) -or $parsedId -eq [guid]::Empty) { throw 'Ungültige Kennung des Zeitraum-Eintrags.' }
    $path = Get-AppActivityPeriodPath
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    $lock = $null; $ErrorActionPreference = 'Stop'
    try {
        $lock = [System.IO.File]::Open(($path + '.lock'), [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $records = @(Read-AppActivityPeriodStore)
        $kept = @($records | Where-Object { $_.Id -ne $parsedId.ToString('D') })
        if ($kept.Count -eq $records.Count) { return $false }
        $store = [ordered]@{ SchemaVersion = 1; Kategorie = 'AktivitaetZeitraeume'; Eintraege = @($kept) }
        Write-AppJsonFile -Path $path -JsonString (ConvertTo-CheckedAppJson $store) -RequireAtomic
        return $true
    } catch { throw 'Zeitraum-Mittel nicht entfernt. Ablage und Schreibzugriff prüfen; unlesbare oder unbekannte Formate werden nicht überschrieben.' }
    finally { if ($lock) { $lock.Dispose() } }
}

function Get-ActivitySummaryWindow {
    <# Kalendergrenzen inklusive. Sechs Monate sind kein festes 180-Tage-Fenster. #>
    param([ValidateSet('YTD', 'Last6Months')][string]$Period = 'YTD', $AsOf = (Get-Date))
    $iso = ConvertTo-AppIsoDate -Date $AsOf
    $end = [datetime]::ParseExact($iso, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
    $start = if ($Period -eq 'YTD') { [datetime]::new($end.Year, 1, 1) } else { $end.AddMonths(-6).AddDays(1) }
    return [PSCustomObject]@{ Zeitraum = $Period; Von = $start.ToString('yyyy-MM-dd'); Bis = $iso; Kalendertage = ($end - $start).Days + 1 }
}

function Get-AppActivityAggregate {
    # Eingaben sind bereits gepruefte, vergleichbare Einzelwerte, niemals Zeitraum-Mittel.
    param([object[]]$Rows, [int]$Digits, [int]$CalendarDays, [string]$To)
    $rowsSorted = @($Rows | Sort-Object Datum, Zeit)
    if ($rowsSorted.Count -eq 0) { return $null }
    # Normierte Summation verhindert Ueberlauf auch bei grossen endlichen Quellwerten.
    $scale = 0.0
    foreach ($row in $rowsSorted) { $scale = [Math]::Max($scale, [Math]::Abs([double]$row.Wert)) }
    $sum = 0.0
    if ($scale -gt 0) { foreach ($row in $rowsSorted) { $sum += ([double]$row.Wert / $scale) } }
    $mean = if ($scale -eq 0) { 0.0 } else { $scale * [Math]::Max(-1.0, [Math]::Min(1.0, $sum / $rowsSorted.Count)) }
    $dates = @($rowsSorted | Select-Object -ExpandProperty Datum -Unique)
    $first = $rowsSorted[0]; $last = $rowsSorted[-1]
    $daysSince = ([datetime]::ParseExact($To, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture) - [datetime]::ParseExact($last.Datum, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)).Days
    $hints = @()
    if ($first.Basis -eq 'Trainingswerte') {
        $hints += 'Mittel pro erfasster Trainingsmessung. Tage ohne Training sind keine Nullwerte; die Vollständigkeit aller Trainings ist unbekannt.'
    } else {
        $hints += 'Gleichgewichtetes Mittel der vorhandenen abgeschlossenen Tage. Fehlende Tage werden nicht ergänzt.'
        if ($first.Basis -eq 'Tagesmittel') { $hints += 'Mittel der Tagesmittel; kein nach Trainingsanzahl gewichteter Trainingsdurchschnitt.' }
    }
    if ($daysSince -gt 0) { $hints += "Letzter verwendeter Wert liegt $daysSince Tage vor dem Stichtag." }
    if (@($rowsSorted | Where-Object { $_.Wert -lt 0 }).Count -gt 0) { $hints += 'Negative Cardio-Erholungswerte wurden unverändert berücksichtigt; Vorzeichen und Quellenverfahren prüfen.' }
    return [PSCustomObject]@{
        Basis = $first.Basis; ErholungsintervallSekunden = $first.ErholungsintervallSekunden; Methode = $first.Methode
        Quelle = $(if (@($rowsSorted | Select-Object -ExpandProperty Quelle -Unique).Count -eq 1) { $first.Quelle } else { '' })
        Geraet = $(if (@($rowsSorted | Select-Object -ExpandProperty Geraet -Unique).Count -eq 1) { $first.Geraet } else { '' })
        Quellen = @($rowsSorted | Select-Object -ExpandProperty Quelle -Unique | Sort-Object)
        Geraete = @($rowsSorted | Select-Object -ExpandProperty Geraet -Unique | Sort-Object)
        Mittelwert = [double]$mean; AnzeigeMittelwert = [Math]::Round($mean, $Digits, [MidpointRounding]::AwayFromZero)
        Anzahl = $rowsSorted.Count; Nenner = $(if ($first.Basis -eq 'Trainingswerte') { 'Trainingsmessungen' } else { 'Tage' })
        TageMitWert = $dates.Count; Kalendertage = $CalendarDays
        AbdeckungProzent = $(if ($first.Basis -eq 'Trainingswerte') { $null } else { 100.0 * $dates.Count / $CalendarDays })
        ErsterWertAm = $first.Datum; LetzterWertAm = $last.Datum; TageSeitLetztemWert = $daysSince
        Hinweise = @($hints)
    }
}

function Measure-ActivitySummary {
    <#
    .SYNOPSIS
        Reine Berechnung aus uebergebenen Tages-/Trainingswerten und Quellenmitteln.
    .DESCRIPTION
        Kein Dateizugriff und keine Speicherung. Ergebnis = ein Objekt mit Fenster und
        Ergebnissen fuer Energie, Schritte, Cardio. Berechnet und Quellenmittel bleiben
        getrennte Arrays. BevorzugteDatenart gibt exakten Quellenmitteln Vorrang, waehlt
        aber bei mehreren Quellen NICHT willkuerlich einen Wert aus.
        Tageswerte: vorhandene abgeschlossene Tage gleich gewichten. Training und
        Cardio-Tagesmittel bleiben getrennt; gruppieren nach bekanntem Intervall,
        bekanntem Verfahren, Quelle und Geraet. Unbekanntes nicht als Gleichheit werten.
        Quellenmittel nur bei exakt passendem Fenster vergleichen. Andere ueberlappende
        Zeitraeume mit Originalgrenzen melden; nie aufteilen, mitteln oder hinzurechnen.
        Differenz = Quellenwert minus eigener Mittelwert, keine medizinische Bewertung.
        Gerundet wird nur AnzeigeMittelwert/AnzeigeDifferenz (AwayFromZero).
        Arrays duerfen auch die einzelnen Objekte der New-...-Funktionen enthalten.
    #>
    param(
        [ValidateSet('YTD', 'Last6Months')][string]$Period = 'YTD', $AsOf = (Get-Date),
        [object[]]$ActivityEntries = @(), [object[]]$FitnessEntries = @(), [object[]]$PeriodRecords = @()
    )
    $window = Get-ActivitySummaryWindow -Period $Period -AsOf $AsOf
    $digits = $script:ActivitySummaryDecimals
    if ($null -eq $digits -or $digits -is [bool] -or $digits -is [string] -or $digits -lt 0 -or $digits -gt 15 -or $digits -ne [Math]::Truncate($digits)) { throw 'ActivitySummaryDecimals muss eine ganze Zahl von 0 bis 15 sein.' }
    $keys = @('Aktivitaetsenergie', 'Schritte', 'CardioErholung')
    $rowsByKey = @{}; $excludedByKey = @{}
    foreach ($key in $keys) { $rowsByKey[$key] = New-Object System.Collections.ArrayList; $excludedByKey[$key] = New-Object System.Collections.ArrayList }
    $seenDays = @{}; $seenTrainings = @{}
    foreach ($category in @('Aktivitaet', 'Fitness')) {
        $entries = if ($category -eq 'Aktivitaet') { $ActivityEntries } else { $FitnessEntries }
        foreach ($entry in $entries) {
            if ($null -eq $entry) { continue }
            $date = ConvertTo-AppIsoDate -Date $entry.Datum
            if ($date -lt $window.Von -or $date -gt $window.Bis) { continue }
            $time = ConvertTo-AppMeasurementTime -Time $entry.Zeit
            if ($category -eq 'Aktivitaet') {
                if ($time -ne '' -or $entry.Details.Datenart -ne 'Tageswerte' -or $entry.Details.TagesAbgeschlossen -isnot [bool]) { throw 'Ungültige Aktivitäts-Tagesdaten: Auswertung abgebrochen, keine Daten geändert.' }
                if ($seenDays.ContainsKey($date)) { throw 'Doppelte Aktivitäts-Tageswerte: keine automatische Auswahl oder Addition.' }
                $seenDays[$date] = $true
            }
            foreach ($key in $keys) {
                if ($category -eq 'Fitness' -and $key -ne 'CardioErholung') { continue }
                $raw = $entry.Werte.$key
                # Fehlend bleibt fehlend, insbesondere kein [double]$null -> 0.
                if ($null -eq $raw -or ($raw -is [string] -and [string]::IsNullOrWhiteSpace($raw))) { continue }
                if ($raw -is [bool]) { throw 'Ungültiger Wahrheitswert in den Aktivitätsdaten.' }
                $checked = ConvertTo-CheckedMeasurementValues -Category 'Aktivitaet' -Values @{ $key = $raw }
                if ($checked.Count -ne 1) { throw 'Ungültiger Aktivitätswert: Auswertung abgebrochen.' }
                $value = $checked[$key]
                if ($key -eq 'Schritte' -and $value -ne [Math]::Truncate($value)) { throw 'Einzelne Schritt-Tageswerte müssen ganzzahlig sein.' }
                $reason = ''; $interval = $null; $method = ''; $measurementCount = $null
                $basis = 'Tageswerte'
                if ($category -eq 'Aktivitaet' -and -not $entry.Details.TagesAbgeschlossen) { $reason = 'UnvollstaendigerTag' }
                if ($key -eq 'CardioErholung') {
                    $expected = if ($category -eq 'Fitness') { 'Training' } else { 'Tagesmittel' }
                    $basis = if ($category -eq 'Fitness') { 'Trainingswerte' } else { 'Tagesmittel' }
                    $cardio = $entry.Details.CardioErholung
                    if ($null -eq $cardio -or $cardio.Datenart -ne $expected) { throw 'Unpassende Cardio-Datenart: Training und Tagesmittel dürfen nicht vermischt werden.' }
                    $details = New-AppCardioRecoveryDetails -Datenart $expected -ErholungsintervallSekunden $cardio.ErholungsintervallSekunden -AnzahlMessungen $cardio.AnzahlMessungen -Methode ([string]$cardio.Methode)
                    $interval = $details.ErholungsintervallSekunden; $method = $details.Methode; $measurementCount = $details.AnzahlMessungen
                    if (-not $reason) {
                        if ($null -eq $interval) { $reason = 'ErholungsintervallUnbekannt' }
                        elseif ([string]::IsNullOrWhiteSpace($method)) { $reason = 'ErholungsverfahrenUnbekannt' }
                    }
                    if ($category -eq 'Fitness') {
                        $identity = $date + 'T' + $time
                        if ($seenTrainings.ContainsKey($identity)) { throw 'Doppelte Cardio-Trainingsmessung: keine automatische Auswahl oder Addition.' }
                        $seenTrainings[$identity] = $true
                    }
                }
                $row = [PSCustomObject]@{
                    Datum = $date; Zeit = $time; Wert = $value; Basis = $basis
                    ErholungsintervallSekunden = $interval; Methode = $method; AnzahlMessungen = $measurementCount
                    Quelle = ([string]$entry.Quelle).Trim(); Geraet = ([string]$entry.Details.Geraet).Trim()
                }
                if ($reason) {
                    [void]$excludedByKey[$key].Add([PSCustomObject]@{ Grund = $reason; Messung = $row })
                } else { [void]$rowsByKey[$key].Add($row) }
            }
        }
    }
    $periods = @(); $seenIds = @{}; $seenIdentities = @{}
    foreach ($record in $PeriodRecords) {
        if ($null -eq $record) { continue }
        $normalized = ConvertTo-AppActivityPeriodRecord -Record $record
        $identity = Get-AppActivityPeriodIdentity -Record $normalized
        if ($seenIds.ContainsKey($normalized.Id) -or $seenIdentities.ContainsKey($identity)) { throw 'Doppelte Zeitraum-Mittel: keine automatische Auswahl oder Addition.' }
        $seenIds[$normalized.Id] = $true; $seenIdentities[$identity] = $true
        if ($normalized.Von -le $window.Bis -and $normalized.Bis -ge $window.Von) { $periods += [PSCustomObject]$normalized }
    }
    $results = @()
    foreach ($key in $keys) {
        $groups = @{}
        foreach ($row in $rowsByKey[$key]) {
            $groupKey = 'Tageswerte'
            if ($key -eq 'CardioErholung') {
                $groupKey = ConvertTo-Json -InputObject @($row.Basis, $row.ErholungsintervallSekunden, $row.Methode.ToLowerInvariant(), $row.Quelle.ToLowerInvariant(), $row.Geraet.ToLowerInvariant()) -Compress
            }
            if (-not $groups.ContainsKey($groupKey)) { $groups[$groupKey] = New-Object System.Collections.ArrayList }
            [void]$groups[$groupKey].Add($row)
        }
        $calculated = @()
        foreach ($groupKey in @($groups.Keys | Sort-Object)) {
            $aggregate = Get-AppActivityAggregate -Rows @($groups[$groupKey]) -Digits $digits -CalendarDays $window.Kalendertage -To $window.Bis
            $calculated += $aggregate
        }
        $sources = @($periods | Where-Object { $_.Messgroesse -eq $key -and $_.Von -eq $window.Von -and $_.Bis -eq $window.Bis } | Sort-Object Quelle, Geraet, Basis, Methode, Id)
        $otherPeriods = @($periods | Where-Object { $_.Messgroesse -eq $key -and ($_.Von -ne $window.Von -or $_.Bis -ne $window.Bis) } | Sort-Object Von, Bis, Quelle, Id)
        $comparisons = @(); $hints = @()
        foreach ($source in $sources) {
            $matches = @($calculated | Where-Object {
                $_.Basis -eq $source.Basis -and ($key -ne 'CardioErholung' -or (
                    $null -ne $source.ErholungsintervallSekunden -and $_.ErholungsintervallSekunden -eq $source.ErholungsintervallSekunden -and
                    $source.Methode -and $_.Methode -ieq $source.Methode -and $_.Quelle -ieq $source.Quelle -and $_.Geraet -ieq $source.Geraet
                ))
            })
            if ($matches.Count -eq 0) { $hints += 'Ein Quellenmittel hat keine passende Berechnungsgruppe; es bleibt ohne automatischen Vergleich erhalten.' }
            foreach ($aggregate in $matches) {
                $difference = [double]$source.Wert - $aggregate.Mittelwert
                $differenceFinite = -not ([double]::IsInfinity($difference) -or [double]::IsNaN($difference))
                $sameCoverage = $null
                if ($aggregate.Basis -ne 'Trainingswerte') { $sameCoverage = ($aggregate.Anzahl -eq $window.Kalendertage -and $source.Anzahl -eq $window.Kalendertage) }
                $comparisons += [PSCustomObject]@{
                    Quellenmittel = $source; Berechnet = $aggregate
                    Differenz = $(if ($differenceFinite) { $difference } else { $null })
                    AnzeigeDifferenz = $(if ($differenceFinite) { [Math]::Round($difference, $digits, [MidpointRounding]::AwayFromZero) } else { $null })
                    Abweichend = ([double]$source.Wert -ne $aggregate.Mittelwert)
                    GleicheTagesabdeckung = $sameCoverage
                    Hinweis = $(if (-not $differenceFinite) { 'Differenz außerhalb des darstellbaren Zahlenbereichs; beide Ausgangswerte bleiben erhalten.' } elseif ($sameCoverage -eq $true) { 'Beide Mittel betreffen alle Tage des Fensters; Quellen und Verfahren können dennoch abweichen.' } else { 'Unterschiedliche oder unbekannte Datenabdeckung: rechnerische Differenz, kein Nachweis eines Fehlers. Quellenmittel hat Vorrang.' })
                }
            }
        }
        if ($calculated.Count -eq 0) { $hints += 'Keine verwendbaren Einzelwerte für einen eigenen Durchschnitt vorhanden.' }
        if ($sources.Count -gt 0) { $hints += 'Exakte Quellenmittel bleiben maßgeblich und unverändert neben der eigenen Berechnung erhalten; mehrere Quellen werden nicht automatisch zusammengefasst.' }
        if ($otherPeriods.Count -gt 0) { $hints += 'Weitere Quellenmittel überlappen das Fenster, passen aber nicht exakt. Keine anteilige Umrechnung und kein Vergleich als gleiches Zeitfenster.' }
        if ($excludedByKey[$key].Count -gt 0) { $hints += 'Einzelwerte wurden nicht zusammengefasst: unvollständige Tage oder unbekanntes Cardio-Intervall/Verfahren. Gründe und Quellwerte stehen in NichtZusammengefasst.' }
        if (@($comparisons | Where-Object Abweichend).Count -gt 0) { $hints += 'Quellenmittel und eigener Durchschnitt weichen ab. Datenabdeckung und Herkunft vor einer Interpretation prüfen.' }
        $definition = Resolve-MeasurementDefinition -Category 'Aktivitaet' -KeyOrName $key
        $results += [PSCustomObject]@{
            Messgroesse = $key; Einheit = $definition.Unit
            BevorzugteDatenart = $(if ($sources.Count -gt 0) { 'Quellenmittel' } elseif ($calculated.Count -gt 0) { 'Berechnet' } else { 'Keine' })
            Berechnet = @($calculated); Quellenmittel = @($sources); Abweichungen = @($comparisons); AndereZeitraeume = @($otherPeriods)
            NichtZusammengefasst = @($excludedByKey[$key] | Sort-Object { $_.Messung.Datum }, { $_.Messung.Zeit }, Grund)
            Hinweise = @($hints | Select-Object -Unique)
        }
    }
    return [PSCustomObject]@{ Zeitraum = $window.Zeitraum; Von = $window.Von; Bis = $window.Bis; Kalendertage = $window.Kalendertage; Ergebnisse = @($results) }
}

function Get-ActivitySummary {
    <#
    .SYNOPSIS
        Gespeicherte Daten fuer YTD oder die letzten sechs Kalendermonate auswerten.
    .EXAMPLE
        Get-ActivitySummary -Period YTD -AsOf '2026-10-09'
    .EXAMPLE
        Get-ActivitySummary -Period Last6Months -AsOf '2026-10-09'
    .DESCRIPTION
        Liefert ein Ergebnisobjekt, keine Speicherung/GUI. Unlesbare Tagesdateien
        blockieren die Auswertung statt einen scheinbar vollstaendigen Mittelwert
        zu liefern. Die reine Rechenfunktion Measure-ActivitySummary ist ohne Ablage nutzbar.
    #>
    param([ValidateSet('YTD', 'Last6Months')][string]$Period = 'YTD', $AsOf = (Get-Date))
    $window = Get-ActivitySummaryWindow -Period $Period -AsOf $AsOf
    $days = @(Get-MeasurementEntries -Category Aktivitaet -From $window.Von -To $window.Bis 3>$null)
    if ($script:MeasurementLoadFailedFiles.Count -gt 0) { throw 'Mindestens eine Aktivitätsdatei ist nicht lesbar. Auswertung abgebrochen; Dateien bleiben unverändert.' }
    $trainings = @(Get-MeasurementEntries -Category Fitness -From $window.Von -To $window.Bis 3>$null)
    if ($script:MeasurementLoadFailedFiles.Count -gt 0) { throw 'Mindestens eine Fitnessdatei ist nicht lesbar. Auswertung abgebrochen; Dateien bleiben unverändert.' }
    $periods = @(Get-ActivityPeriodRecords -From $window.Von -To $window.Bis)
    return (Measure-ActivitySummary -Period $Period -AsOf $window.Bis -ActivityEntries $days -FitnessEntries $trainings -PeriodRecords $periods)
}

# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 4: KERNLOGIK / BERECHNUNGEN (domänenspezifisch)                    ║
# ║  OPTIONAL: Nur implementieren was die Anwendung braucht.                    ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# --- 4a. Korrelationsberechnung (Pearson) ---
# Verwendet in: Blood-Tracker (Korrelationen-Tab)
function Calculate-Correlation {
    param ($values1, $values2)
    $n = $values1.Count
    if ($n -eq 0) { return 0 }
    $sumX  = ($values1 | Measure-Object -Sum).Sum
    $sumY  = ($values2 | Measure-Object -Sum).Sum
    $sumXY = 0; for ($i = 0; $i -lt $n; $i++) { $sumXY += $values1[$i] * $values2[$i] }
    $sumX2 = ($values1 | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum
    $sumY2 = ($values2 | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum
    $numerator   = $n * $sumXY - $sumX * $sumY
    $denominator = [Math]::Sqrt(($n * $sumX2 - $sumX * $sumX) * ($n * $sumY2 - $sumY * $sumY))
    if ($denominator -eq 0) { return 0 }
    return $numerator / $denominator
}

# --- 4b. Lineare Regression ---
# Verwendet in: Blood-Tracker (Trendlinien)
function Calculate-LinearRegression {
    param($dataPoints)
    $n = $dataPoints.Count
    if ($n -lt 2) { return $null }
    $xValues = $dataPoints | ForEach-Object { ([datetime]$_.Date).ToOADate() }
    $yValues = $dataPoints.Value
    $sumX  = ($xValues | Measure-Object -Sum).Sum
    $sumY  = ($yValues | Measure-Object -Sum).Sum
    $sumXY = 0; for ($i = 0; $i -lt $n; $i++) { $sumXY += $xValues[$i] * $yValues[$i] }
    $sumX2 = ($xValues | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum
    $denominator = $n * $sumX2 - $sumX * $sumX
    if ($denominator -eq 0) { return $null }
    $slope     = ($n * $sumXY - $sumX * $sumY) / $denominator
    $intercept = ($sumY - $slope * $sumX) / $n
    return [PSCustomObject]@{ Slope = $slope; Intercept = $intercept }
}

# --- 4c. Zeitfilter-Logik ---
# Verwendet in: Blood-Tracker (Cockpit, Daten-Tab, Longevity), Haushalts-Tracker
# Gibt ein Cutoff-Datum zurück basierend auf dem gewählten Zeitraum-String.
function Get-CutoffDate {
    param([string]$timeFilter)
    $now = Get-Date
    switch ($timeFilter) {
        "Aktuelles Jahr"  { return [datetime]::new($now.Year, 1, 1) }
        "Letzte 3 Jahre"  { return $now.AddYears(-3) }
        "Letzte 5 Jahre"  { return $now.AddYears(-5) }
        "Letzte 10 Jahre" { return $now.AddYears(-10) }
        default           { return $null }  # "Alle Daten"
    }
}

# --- 4d. Wissenschaftliche Longevity-Scores (OPTIONAL) ---
# Verwendet in: Blood-Tracker (Longevity-Indizes, Risiko-Cockpit).
# PATTERN: Spezial-Formel-Dispatcher. CalculatedMarkers erhalten einen "Formula"-String
# wie "[PHENOAGE]", der in Get-CalculatedValuesForMarker auf eine dedizierte Funktion
# gemappt wird. Vorteil: Komplexe Logik nicht als Invoke-Expression, sondern typsicher.
#
# KRITISCH - EINHEITEN: Klinische Longevity-Scores (PhenoAge, GrimAge, etc.) nutzen
# US-Einheiten (g/L, µmol/L, mmol/L). Deutsche Labore nutzen oft g/dL, mg/dL, etc.
# IMMER Einheiten-Normalisierung vor Berechnung durchführen!

function Calculate-PhenoAge {
    <#
    .SYNOPSIS
        Biologisches Alter nach Levine et al. (2018, Aging) - Gompertz-Mortalitätsmodell.
    .DESCRIPTION
        Referenz: Levine ME et al., "An epigenetic biomarker of aging for lifespan
        and healthspan", Aging (Albany NY), 2018; 10(4):573-591. doi:10.18632/aging.101414
        
        Benötigt 9 Laborparameter + chronologisches Alter:
        [0] Albumin             (g/L     - US-Einheit; g/dL * 10)
        [1] Kreatinin           (µmol/L  - US-Einheit; mg/dL * 88.4)
        [2] Glukose             (mmol/L  - US-Einheit; mg/dL / 18)
        [3] CRP (hsCRP!)        (mg/L    - Achtung: nicht normales CRP)
        [4] Lymphozyten         (%)
        [5] MCV                 (fL)
        [6] RDW-CV              (%)
        [7] Alkalische Phosph.  (U/L)
        [8] Leukozyten          (1000 cells/µL - identisch Tsd./µl)
    .OUTPUTS
        Biologisches Alter in Jahren.
    #>
    param([double[]]$values, [double]$chronoAge)
    try {
        # Einheiten-Normalisierung (Heuristik basierend auf typischer Wertebereichs-Abweichung)
        $albumin_gL = if ($values[0] -lt 10) { $values[0] * 10 } else { $values[0] }
        $krea_umolL = if ($values[1] -lt 10) { $values[1] * 88.4 } else { $values[1] }
        $glu_mmolL  = if ($values[2] -gt 20) { $values[2] / 18.0 } else { $values[2] }
        $crp_mgL    = $values[3]
        $lympho_pct = $values[4]; $mcv_fL = $values[5]; $rdw_pct = $values[6]
        $ap_UL      = $values[7]; $wbc_1000uL = $values[8]

        # Original-Koeffizienten Levine 2018 (Table 1)
        $xb = -19.907 `
              + (-0.0336 * $albumin_gL) `
              + ( 0.0095 * $krea_umolL) `
              + ( 0.1953 * $glu_mmolL) `
              + ( 0.0954 * [Math]::Log([Math]::Max($crp_mgL, 0.01) / 10.0 + 0.001)) `
              + (-0.0120 * $lympho_pct) `
              + ( 0.0268 * $mcv_fL) `
              + ( 0.3306 * $rdw_pct) `
              + ( 0.00188 * $ap_UL) `
              + ( 0.0554 * $wbc_1000uL) `
              + ( 0.0804 * $chronoAge)

        $g = 0.0076927
        $mortScore = 1 - [Math]::Exp(-[Math]::Exp($xb) * ([Math]::Exp(120 * $g) - 1) / $g)
        $mortScore = [Math]::Min([Math]::Max($mortScore, 0.0001), 0.9999)
        $phenoAge = 141.50225 + [Math]::Log(-0.00553 * [Math]::Log(1 - $mortScore)) / 0.09165
        return [Math]::Round($phenoAge, 1)
    } catch {
        Write-Warning "PhenoAge-Berechnungsfehler: $($_.Exception.Message)"
        return $null
    }
}

function Calculate-InflammAgingScore {
    <#
    .SYNOPSIS
        InflammAging-Komposit aus hsCRP, NLR, PLR (Franceschi-Konzept).
    .DESCRIPTION
        Chronische niedriggradige systemische Entzündung als Haupttreiber des
        biologischen Alterns. Skala: 100 = optimal, 0 = stark entzündlich.
    .PARAMETER values
        Array [CRP mg/L, Neutrophile %, Lymphozyten %, Thrombozyten Tsd./µL, Leukozyten Tsd./µL]
        v3.10 (Blood-Tracker v2.28.0): Leukozyten (5. Wert) für die ABSOLUTE Lymphozytenzahl.
        PLR = Thrombozyten / absolute Lymphozyten (ca. 140) - NICHT / Lymphozyten-% (ca. 8,
        PLR-Anteil war dadurch immer 100). Ohne Leukozyten: nur CRP + NLR, normiert.
    .NOTES
        v3.10 BUGFIX: 0.0/100.0 statt 0/100 - mit Ganzzahl-Literalen wählt PowerShell
        [Math]::Min(int,int) und rundet jeden Teilscore auf eine ganze Zahl.
    #>
    param([double[]]$values)
    try {
        $crp = [double]$values[0]; $neut = [double]$values[1]
        $lymph = [double]$values[2]; $plt = [double]$values[3]
        $wbc = if ($values.Count -ge 5) { [double]$values[4] } else { 0 }
        if ($lymph -le 0) { return 0 }

        $nlr = $neut / $lymph   # Prozent / Prozent = Verhältnis der absoluten Zahlen

        $crpScore = [Math]::Max(0.0, [Math]::Min(100.0, (1 - $crp / 3.0) * 100))
        $nlrScore = [Math]::Max(0.0, [Math]::Min(100.0, (1 - ($nlr - 1.0) / 2.5) * 100))

        if ($wbc -gt 0) {
            $plr = $plt / ($lymph * $wbc / 100)
            $plrScore = [Math]::Max(0.0, [Math]::Min(100.0, (1 - ($plr - 70) / 130) * 100))
            $score = ($crpScore * 0.5) + ($nlrScore * 0.3) + ($plrScore * 0.2)
        } else {
            $score = (($crpScore * 0.5) + ($nlrScore * 0.3)) / 0.8
        }
        return [Math]::Round($score, 1)
    } catch {
        Write-Warning "InflammAging-Berechnungsfehler: $($_.Exception.Message)"
        return $null
    }
}

# --- 4e. TyG-Index (Triglyceride-Glukose-Index, Simental-Mendia 2008) ---
# Surrogatmarker für Insulinresistenz. Formel: ln(Trig_mg/dL * Glu_mg/dL / 2)  (Werte ca. 8-9)
# v3.10 KORREKTUR (Blood-Tracker v2.28.0): Der Grenzwert 4,68 gilt für die Schreibweise
# ln(Trig * Glu) / 2 (Simental-Mendia 2008 / Guerrero-Romero 2010) - beide Schreibweisen
# NIE mit demselben Grenzwert mischen. Formel und Bereiche immer gemeinsam ändern
# (bestehende Installationen: Korrektur-Migration 1f/3k mit OnlyIf auf die alte Formel).
# Einbaubar als inline-Formel in CalculatedMarkers (einfache Anführungszeichen!):
#   Formula = '[Math]::Log((%0%) * (%1%)) / 2'   # RequiredMarkers = @("Triglyceride", "Glukose")
#   RefMax = 4.68; OptimalMax = 4.5

# --- 4f. Trajektorien-Analyse (Trend-Slope über Zeit) ---
# Oft aussagekräftiger als Einzelwerte (z.B. HbA1c-Slope/Jahr).
function Calculate-MarkerTrajectory {
    param($items)
    if (-not $items -or $items.Count -lt 2) { return $null }
    try {
        $sortedItems = $items | Sort-Object { [datetime]::ParseExact($_.Date, "yyyy-MM-dd", $null) }
        $firstDate = [datetime]::ParseExact($sortedItems[0].Date, "yyyy-MM-dd", $null)
        $xValues = $sortedItems | ForEach-Object { ([datetime]::ParseExact($_.Date, "yyyy-MM-dd", $null) - $firstDate).TotalDays / 365.25 }
        $yValues = $sortedItems.Value
        $n = $sortedItems.Count
        $sumX = ($xValues | Measure-Object -Sum).Sum
        $sumY = ($yValues | Measure-Object -Sum).Sum
        $sumXY = 0; for ($i = 0; $i -lt $n; $i++) { $sumXY += $xValues[$i] * $yValues[$i] }
        $sumX2 = ($xValues | ForEach-Object { $_ * $_ } | Measure-Object -Sum).Sum
        $denom = $n * $sumX2 - $sumX * $sumX
        if ($denom -eq 0) { return $null }
        return [Math]::Round(($n * $sumXY - $sumX * $sumY) / $denom, 3)
    } catch {
        return $null
    }
}

# --- 4g. Chart-Bitmap-Rendering (GDI+, ohne externe Libraries, OPTIONAL) ---
# Rendert eine Liniengrafik eines Markers/Zeitreihe als System.Drawing.Bitmap.
# Eignet sich perfekt für PDF-Export und PrintDocument, weil keine Form-Controls
# beteiligt sind und der Handler asynchron sicher ist.
#
# USAGE:
#   $bmp = Render-MarkerChartToImage -items $dataPoints -markerName "HbA1c" -unit "%" `
#           -refMin 4.0 -refMax 5.7 -optMin 4.5 -optMax 5.3 -width 1600 -height 560
#   $graphics.DrawImage($bmp, $x, $y, $targetW, $targetH)
#   $bmp.Dispose()
#
# FEATURES:
# - Automatische Y-Skala (inkl. RefMin/RefMax berücksichtigt)
# - Referenz- und Optimalbereich als schattierte Zonen
# - 5 Gridlines auf Y, 6 Ticks auf X, antialiased Linien mit Markerpunkten
# - Kompaktes Layout, passt in 300-600 px Höhe
function Render-MarkerChartToImage {
    param(
        [array]$items,
        [string]$markerName,
        [string]$unit = "",
        $refMin = $null, $refMax = $null,
        $optMin = $null, $optMax = $null,
        [int]$width = 900, [int]$height = 300
    )
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::White)
    # ... (volle Implementierung siehe Blood-Tracker v2.13.0) ...
    $g.Dispose()
    return $bmp
}

# --- 4h. Einheitlicher 0-100-Score-Mapper für heterogene Marker (OPTIONAL) ---
# Longevity-Marker haben völlig unterschiedliche Einheiten (Jahre, Punkte, Ratios).
# Dieser Mapper normalisiert sie auf 0-100 für einheitliche UI-Bewertung.
function Convert-ToLongevityScore {
    param([string]$markerName, [double]$value, [double]$chronoAge = 0)
    $score = 50
    switch ($markerName) {
        "PhenoAge-Accel" {
            if     ($value -le -5) { $score = 100 }
            elseif ($value -le -2) { $score = 90  }
            elseif ($value -le  0) { $score = 80  }
            elseif ($value -le  2) { $score = 60  }
            elseif ($value -le  5) { $score = 40  }
            else                   { $score = 20  }
        }
        "InflammAging-Score" {
            $score = [Math]::Round($value, 0)
        }
        "NLR" {
            if     ($value -le 1.5) { $score = 100 }
            elseif ($value -le 2.0) { $score = 85  }
            elseif ($value -le 2.5) { $score = 70  }
            elseif ($value -le 3.0) { $score = 50  }
            elseif ($value -le 4.0) { $score = 30  }
            else                    { $score = 10  }
        }
        "TyG-Index" {
            if     ($value -lt 4.5 ) { $score = 100 }
            elseif ($value -lt 4.68) { $score = 85  }
            elseif ($value -lt 4.9 ) { $score = 65  }
            elseif ($value -lt 5.1 ) { $score = 45  }
            else                     { $score = 20  }
        }
        default { $score = 50 }
    }
    # v3.10 BUGFIX: [double] - bei ganzzahligem $score wählt PowerShell Math.Round(decimal);
    # das Ergebnis ist dann [decimal] und Farbprüfungen auf double/int schlagen fehl.
    return [Math]::Round([double]$score, 0)
}

# --- 4i. Special-Formula-Dispatcher-Pattern ---
# PATTERN für komplexe berechnete Marker, die nicht mit Invoke-Expression lösbar sind.
# Beispiel-Integration in Get-CalculatedValuesForMarker:
#
#     $specialFormulas = @("[LONGEVITY_SCORE]", "[PHENOAGE]", "[PHENOAGE_ACCEL]", "[INFLAMMAGING]")
#     $isSpecialFormula = $specialFormulas -contains $markerConfig.Formula
#     ...
#     if     ($markerConfig.Formula -eq "[PHENOAGE]")       { $resultValue = Calculate-PhenoAge -values $markerValues -chronoAge $chronoAge }
#     elseif ($markerConfig.Formula -eq "[PHENOAGE_ACCEL]") { $resultValue = (Calculate-PhenoAge ...) - $chronoAge }
#     elseif ($markerConfig.Formula -eq "[INFLAMMAGING]")   { $resultValue = Calculate-InflammAgingScore -values $markerValues }
#     else                                                  { $resultValue = Invoke-Expression $formula }
#
# [v3.10] EINGANGSWERTE JE MESSTAG AUFLÖSEN (Spezial-Formeln):
#     foreach ($required in $markerConfig.RequiredMarkers) {
#         $candidates = @()
#         if ($script:ItemPreferred -and $script:ItemPreferred.ContainsKey($required)) { $candidates += $script:ItemPreferred[$required] }
#         $candidates += $required
#         if ($script:ItemFallbacks -and $script:ItemFallbacks.ContainsKey($required)) { $candidates += $script:ItemFallbacks[$required] }
#         # erster Kandidat mit Wert am Testtag gewinnt; den TATSÄCHLICH verwendeten Namen
#         # merken - Bewertungen (4o) nutzen dessen Bereiche, nicht die des Standards
#     }
# [v3.10] ALTER: nie ein festes Alter für historische Werte - Get-AgeAtDate (4p) mit dem
#         Datum des jeweiligen Messtags. Ergebnis $null (weder Geburtsdatum noch festes
#         Alter, oder Messtag vor der Geburt) -> kein Wert berechnen.
# [v3.10] ERGEBNIS: NaN/Infinity (z.B. Division durch 0, fehlende Größe) nie anzeigen oder
#         speichern:  if ([double]::IsNaN($resultValue) -or [double]::IsInfinity($resultValue)) { $resultValue = $null }
# [v3.10] AUFRUFER: Ergebnisliste IMMER mit @() übernehmen - ein berechneter Eintrag mit genau
#         EINEM Messtag fehlte sonst in Übersichten (PS-5.1-FALLE 1).


# --- 4j. AutoBackup-Scheduler-Pattern (OPTIONAL, v3.8) ---
# Ermöglicht automatische Backups während der App-Laufzeit ohne Windows-Task-Scheduler.
#
# ARCHITEKTUR:
#   Invoke-AutoBackupNow     - Führt das Backup tatsächlich aus (ZIP und/oder Ordner-Kopie)
#   Invoke-AutoBackupIfDue   - Prüft Fälligkeit, triggert Invoke-AutoBackupNow wenn nötig
#   Show-AutoBackupPopup     - GUI zur Konfiguration (siehe Sektion 5h)
#
# INTEGRATION in Form.Load:
#   $script:autoBackupRanThisSession = $false
#   Invoke-AutoBackupIfDue                              # Start-Check
#   $script:autoBackupTimer = New-Object System.Windows.Forms.Timer
#   $script:autoBackupTimer.Interval = 15 * 60 * 1000   # 15 Minuten
#   $script:autoBackupTimer.Add_Tick({ Invoke-AutoBackupIfDue })
#   $script:autoBackupTimer.Start()
# IN Form.FormClosing:
#   $script:autoBackupTimer.Stop(); $script:autoBackupTimer.Dispose()
#
# CONFIG-FELDER (in Config.json unter "AutoBackup"):
#   Enabled         - Boolean, Feature ein/aus
#   TargetPath      - Zielverzeichnis
#   FormatZip       - ZIP-Archiv erstellen?
#   FormatFolder    - Ordner-Kopie erstellen (inkrementell via robocopy)?
#   Interval        - "täglich" | "wöchentlich" | "monatlich" | "jährlich" | "bei Programm-Start"
#   TimeOfDay       - "HH:mm" - irrelevant bei "bei Programm-Start"
#   IncludeRegistry - Boolean, Registry-Export mitsichern
#   LastBackup      - ISO-Timestamp (yyyy-MM-ddTHH:mm:ss) des letzten Erfolgs
#
# REKURSIONS-SCHUTZ (PFLICHT):
function Test-BackupPathSafe {
    param([string]$TargetPath, [string]$DataDir)
    if ([string]::IsNullOrWhiteSpace($TargetPath)) { return "Zielverzeichnis darf nicht leer sein." }
    try {
        $t = [System.IO.Path]::GetFullPath($TargetPath.TrimEnd('\'))
        $d = [System.IO.Path]::GetFullPath($DataDir.TrimEnd('\'))
        if ($t -ieq $d) { return "Zielverzeichnis darf nicht das Datenverzeichnis selbst sein." }
        if ($t.StartsWith($d + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            return "Zielverzeichnis darf nicht unterhalb des Datenverzeichnisses liegen (rekursive Backups)."
        }
    } catch { return "Ungültiger Pfad: $($_.Exception.Message)" }
    return $null
}
#
# REGISTRY-EXPORT-MUSTER:
#   $tempReg = Join-Path $env:TEMP "App_reg_$timestamp.reg"
#   & reg.exe export "HKCU\Software\PSC\MeineApp" $tempReg /y 2>&1 | Out-Null
#   # Datei in Staging-Ordner/ZIP-Root neben UserData/ legen
#
# ROBOCOPY-MUSTER (inkrementelle Ordner-Kopie):
#   $args = @($src, $dst, "/E", "/R:1", "/W:1", "/NP", "/NFL", "/NDL", "/NJH", "/NJS")
#   & robocopy.exe @args
#   # Exit-Codes 0-7 sind OK, ab 8 Fehler



# --- 4k. Backup-Retention / Cleanup (OPTIONAL, v3.9) ---
# Ergänzt den AutoBackup-Scheduler (4j) um eine Aufräumregel.
# REIHENFOLGE: Cleanup läuft IMMER NACH erfolgreicher Backup-Erstellung. Bei einem
#              Fehler im Backup gehen sonst alte Sicherungen verloren, ohne dass
#              eine neue existiert.
# SCHUTZ 1: Es werden ausschließlich Einträge mit dem App-eigenen Prefix betrachtet.
#           Fremde Dateien im Zielverzeichnis bleiben unberührt.
# SCHUTZ 2: ZIP-Dateien, Ordner und portable Archive haben JEWEILS einen eigenen
#           Retention-Zähler - sonst entstehen bei Format="Beides" Lücken.
# SCHUTZ 3: Es bleibt immer mindestens 1 Backup übrig (Math::Max($Keep,1)), auch
#           bei der Regel "alle löschen".

function Invoke-BackupCleanup {
    param(
        [Parameter(Mandatory)][string]$TargetPath,
        [Parameter(Mandatory)][int]$Keep
    )
    try {
        if (-not (Test-Path $TargetPath)) { return }
        $prefix = "$($script:AppName)_AutoBackup_"
        $effectiveKeep = [Math]::Max($Keep, 1)

        # Typ-getrennte Behandlung: ZIP / Ordner / portables Archiv
        $groups = @(
            @{ Kind = 'ZIP';      Items = @(Get-ChildItem -Path $TargetPath -Filter "$prefix*.zip"        -File      -ErrorAction SilentlyContinue) }
            @{ Kind = 'Ordner';   Items = @(Get-ChildItem -Path $TargetPath -Filter "$prefix*"            -Directory -ErrorAction SilentlyContinue) }
            @{ Kind = 'Portabel'; Items = @(Get-ChildItem -Path $TargetPath -Filter "$prefix*.appbackup"  -File      -ErrorAction SilentlyContinue) }
        )
        foreach ($grp in $groups) {
            $sorted = @($grp.Items | Sort-Object -Property CreationTime -Descending)
            if ($sorted.Count -le $effectiveKeep) { continue }
            foreach ($obj in ($sorted | Select-Object -Skip $effectiveKeep)) {
                try {
                    if ($obj.PSIsContainer) { Remove-Item -Path $obj.FullName -Recurse -Force -ErrorAction Stop }
                    else                    { Remove-Item -Path $obj.FullName -Force -ErrorAction Stop }
                    Write-Verbose "Cleanup ($($grp.Kind)) gelöscht: $($obj.Name)"
                } catch { Write-Warning "Cleanup-Fehler bei $($obj.Name): $($_.Exception.Message)" }
            }
        }
    } catch { Write-Warning "Invoke-BackupCleanup-Fehler: $($_.Exception.Message)" }
}


# --- 4l. Trend- und Abweichungs-Warnungen (OPTIONAL, v3.9) ---
# Proaktive Hinweise statt reiner Anzeige: erkennt (a) einen signifikanten
# Langzeit-Trend und (b) prozentuale Abweichungen gegenüber definierten
# Vergleichszeitpunkten. Schwellwert kommt aus der UI (TextBox), nicht hartcodiert.
#
# BAUSTEINE:
#   1. Trend  : Calculate-LinearRegression -> Slope * 365.25 = Änderung/Jahr,
#               relativ zum Mittelwert. Ab |10 %| pro Jahr wird gewarnt.
#   2. Vergleich: jüngster Wert gegen den letzten Wert vor 1 bzw. 3 Jahren.
#   3. Fachliche Info-Texte je Eintrag (z.B. Einheiten-Hinweise) vorab einreihen.
# AUSGABE: alle Meldungen in einer ArrayList sammeln, am Ende EINMAL in ein Label
#          schreiben und die GroupBox nur dann sichtbar schalten.

function Get-TrendWarnings {
    <#
    .SYNOPSIS
        Liefert alle Warn-/Hinweistexte zu einer Datenreihe als String-Array.
    .PARAMETER DataPoints
        Objekte mit .Date (yyyy-MM-dd) und .Value.
    .PARAMETER ThresholdPercent
        Relative Abweichung, ab der gewarnt wird (z.B. 10 für 10 %).
    #>
    param(
        $DataPoints,
        [double]$ThresholdPercent = 10
    )
    $messages = New-Object System.Collections.ArrayList
    $points = @($DataPoints)
    if ($points.Count -eq 0) { return @() }

    # 1. Trend über die gesamte Reihe
    $regression = Calculate-LinearRegression -dataPoints $points
    if ($regression) {
        $meanValue = ($points.Value | Measure-Object -Average).Average
        if ($meanValue -ne 0) {
            $relativeChange = ($regression.Slope * 365.25) / $meanValue
            if ([Math]::Abs($relativeChange) -gt 0.1) {
                $direction = if ($regression.Slope -gt 0) { "steigender" } else { "fallender" }
                [void]$messages.Add("WARNUNG (Trend): signifikant $direction Trend von ca. $('{0:P0}' -f $relativeChange) pro Jahr.")
            }
        }
    }
    if ($points.Count -lt 2) { return @($messages) }

    # 2. Vergleich mit 1 und 3 Jahren zuvor
    $threshold = $ThresholdPercent / 100
    $withDates = $points | Select-Object *, @{N='DateObject'; E={ [datetime]$_.Date }} | Sort-Object DateObject
    $latest = $withDates[-1]
    foreach ($span in @(1, 3)) {
        $target = $latest.DateObject.AddYears(-$span)
        $ref = $withDates | Where-Object { $_.DateObject -le $target } | Select-Object -Last 1
        if ($ref -and $ref.Value -ne 0) {
            $percentChange = ($latest.Value - $ref.Value) / $ref.Value
            if ([Math]::Abs($percentChange) -gt $threshold) {
                $label = if ($span -eq 1) { "1 Jahr" } else { "$span Jahre" }
                [void]$messages.Add(("WARNUNG ($label): Wert hat sich um {0:P0} verändert (aktuell {1} am {2} vs. {3} am {4})." -f `
                    $percentChange, $latest.Value, $latest.DateObject.ToString('dd.MM.yyyy'), $ref.Value, $ref.DateObject.ToString('dd.MM.yyyy')))
            }
        }
    }
    return @($messages)
}


# --- 4m. Korrelations-Screening (Auto-Vorschläge, OPTIONAL, v3.9) ---
# Statt den Nutzer zwei Einträge raten zu lassen: alle Paarungen zwischen zwei
# Gruppen durchrechnen und nur die relevanten anbieten.
# SCHWELLEN: mindestens 4 gepaarte Datenpunkte, |r| >= 0.3.
# INTERPRETATION: |r| >= 0.7 "sehr stark", >= 0.5 "stark", sonst "moderat";
#                 Vorzeichen -> "positiver"/"negativer Zusammenhang".
# UX: Berechnung im Add_Shown des Popups mit WaitCursor - bei vielen Einträgen
#     dauert das spürbar, das Fenster soll aber sofort erscheinen.
# WARNUNG (fachlich, immer mit ausgeben): Korrelation ist keine Kausalität, und bei
#     n Paarungen sind Zufallstreffer erwartbar (multiples Testen).
#
# function Get-CorrelationSuggestions {
#     param([string[]]$GroupA, [string[]]$GroupB, [int]$MinPoints = 4, [double]$MinAbsR = 0.3)
#     $results = New-Object System.Collections.ArrayList
#     foreach ($a in $GroupA) {
#         foreach ($b in $GroupB) {
#             $paired = Get-PairedData -marker1Name $a -marker2Name $b
#             if ($paired.Count -lt $MinPoints) { continue }
#             $r = Calculate-Correlation -values1 $paired.Value1 -values2 $paired.Value2
#             if ([Math]::Abs($r) -lt $MinAbsR) { continue }
#             [void]$results.Add([PSCustomObject]@{ Marker1=$a; Marker2=$b; Correlation=$r
#                                                  DataPoints=$paired.Count; AbsCorr=[Math]::Abs($r) })
#         }
#     }
#     return @($results | Sort-Object AbsCorr -Descending)
# }


# --- 4n. Risiko-Score per logistischer Funktion (OPTIONAL, v3.9) ---
# Muster für Scores der Form  Risiko % = 1 / (1 + e^-x) * 100  mit
#   x = Basiskonstante + Summe(Koeffizient_i * Eingangsgröße_i)
# und getrennten Koeffizientensätzen je Geschlecht.
#
# ┌─ PFLICHT-WARNUNG FÜR JEDE KI, DIE DIESES MUSTER ÜBERNIMMT ────────────────────┐
# │ Ein solcher Score ist NUR dann publikationstreu, wenn die Koeffizienten aus   │
# │ der Originalarbeit stammen. Selbst gewählte Koeffizienten ergeben eine Zahl,  │
# │ die aussieht wie ein validierter Score, aber keiner ist.                      │
# │ REGELN:                                                                       │
# │  1. Koeffizienten immer mit Quelle (Autor, Journal, Jahr) im Kommentar.       │
# │  2. Ist die Formel nur genähert, MUSS das Label "(Näherung)" tragen und der   │
# │     Hinweis in der UI stehen.                                                 │
# │  3. Einheiten VOR der Formel normalisieren (siehe Sektion 4e) - US- vs.       │
# │     deutsche Einheiten sind die häufigste Fehlerquelle.                       │
# │  4. Fehlt eine Eingangsgröße: $null zurückgeben, NICHT mit 0 weiterrechnen.   │
# └──────────────────────────────────────────────────────────────────────────────┘
#
# function Calculate-RiskScore {
#     param($values, $personal)
#     foreach ($v in $values) { if ($null -eq $v) { return $null } }   # Regel 4
#     $exponent = if ($personal.Geschlecht -eq 'männlich') {
#         $script:RiskCoef.M.Base + ($script:RiskCoef.M.Age * $personal.Age) + ...
#     } else {
#         $script:RiskCoef.W.Base + ($script:RiskCoef.W.Age * $personal.Age) + ...
#     }
#     return (1 / (1 + [Math]::Exp(-$exponent)) * 100)
# }


# --- 4o. Bereichsbasierte 0-100-Bewertung + Komposit-Score (OPTIONAL, v3.10) ---
# PROBLEM (Blood-Tracker bis v2.29.0): Der Longevity-Score nutzte eigene, fest codierte
# Formeln, die den Referenz-/Optimalbereichen derselben Marker widersprachen (HbA1c 5,2 %
# = 0 Punkte, gesunder Datensatz ca. 33/100) und rechnete nur, wenn ALLE Werte vorlagen.
# LÖSUNG: Jeder Wert wird an den Bereichen SEINES Eintrags bewertet - dieselbe Einteilung
# wie die Ampel im Cockpit; der Komposit-Score ist der Mittelwert der vorhandenen Teilwerte
# ab einer Mindestanzahl.
#   im Optimalbereich                 -> 100        (grün)
#   im Referenzbereich, nicht optimal -> 79 bis 50  (gelb, linear bis zur Referenzgrenze)
#   außerhalb des Referenzbereichs    -> 49 bis 0   (rot, 0 ab einem weiteren Abstand in
#                                                    Breite der gelben Zone)
#   ohne Optimalbereich: im Referenzbereich 79
# Gerundet wird kaufmännisch (PS-5.1-FALLE 5).

function Get-RangeScore {
    <#
    .OUTPUTS
        [double] 0-100 (1 Nachkommastelle) oder $null (keine Bereiche hinterlegt).
    #>
    param([double]$Value, $RefMin, $RefMax, $OptimalMin, $OptimalMax)
    $toNum = { param($x) if ($null -eq $x -or [string]$x -eq '') { $null } else { try { [double]$x } catch { $null } } }
    $rMin = & $toNum $RefMin; $rMax = & $toNum $RefMax; $oMin = & $toNum $OptimalMin; $oMax = & $toNum $OptimalMax
    $hasOptimal = ($null -ne $oMin -and $null -ne $oMax)
    if (-not $hasOptimal) {
        if ($null -eq $rMin -or $null -eq $rMax) { return $null }
        if ($Value -ge $rMin -and $Value -le $rMax) { return 79.0 }
        $oMin = $rMin; $oMax = $rMax
    }
    if ($null -eq $rMin) { $rMin = $oMin }
    if ($null -eq $rMax) { $rMax = $oMax }
    $rMin = [Math]::Min($rMin, $oMin); $rMax = [Math]::Max($rMax, $oMax)
    if ($Value -ge $oMin -and $Value -le $oMax) { return 100.0 }
    if ($Value -gt $oMax) { $zone = $rMax - $oMax; $dist = $Value - $oMax } else { $zone = $oMin - $rMin; $dist = $oMin - $Value }
    if ($hasOptimal -and $zone -gt 0 -and $dist -le $zone) {
        return [Math]::Round(79.0 - 29.0 * ($dist / $zone), 1, [MidpointRounding]::AwayFromZero)
    }
    # außerhalb: Skala = Breite der gelben Zone (sonst Breite des Optimal-/Referenzbereichs)
    $scale = if ($hasOptimal -and $zone -gt 0) { $zone } else { $oMax - $oMin }
    if ($scale -le 0) { $scale = [Math]::Max([Math]::Abs($oMax), 1.0) }
    $over = if ($hasOptimal -and $zone -gt 0) { $dist - $zone } else { $dist }
    return [Math]::Round([Math]::Max(0.0, 49.0 * (1.0 - $over / $scale)), 1, [MidpointRounding]::AwayFromZero)
}

function Get-ItemRangeScore {
    <# Bewertung eines Werts an den Bereichen seines Katalog-Eintrags. [PLACEHOLDER] Datenquelle. #>
    param([string]$ItemName, [double]$Value)
    $itemCfg = @($script:data.Config.Markers) | Where-Object { $_.Name -eq $ItemName } | Select-Object -First 1
    if (-not $itemCfg) { return $null }
    return Get-RangeScore -Value $Value -RefMin $itemCfg.RefMin -RefMax $itemCfg.RefMax -OptimalMin $itemCfg.OptimalMin -OptimalMax $itemCfg.OptimalMax
}

function Get-CompositeScore {
    <#
    .SYNOPSIS
        Mittelwert der Einzelbewertungen (Get-ItemRangeScore) der vorhandenen Werte.
    .PARAMETER Values
        Werte in der Reihenfolge von -Names ($null = am Messtag nicht vorhanden).
    .PARAMETER Names
        TATSÄCHLICH verwendete Eintragsnamen (z.B. hs-CRP statt CRP, siehe 4i) - deren
        Bereiche zählen.
    .OUTPUTS
        [double] (1 Nachkommastelle) oder $null (weniger als -MinComponents Werte).
    #>
    param($Values, [string[]]$Names, [int]$MinComponents = 4)
    $scores = New-Object System.Collections.ArrayList
    $valueList = @($Values)
    for ($i = 0; $i -lt $valueList.Count; $i++) {
        if ($null -eq $valueList[$i] -or $null -eq $Names -or $i -ge $Names.Count -or [string]::IsNullOrEmpty($Names[$i])) { continue }
        $componentScore = Get-ItemRangeScore -ItemName $Names[$i] -Value ([double]$valueList[$i])
        if ($null -ne $componentScore) { [void]$scores.Add([double]$componentScore) }
    }
    if ($scores.Count -lt $MinComponents) { return $null }
    return [Math]::Round(($scores | Measure-Object -Average).Average, 1, [MidpointRounding]::AwayFromZero)
}


# --- 4p. Geburtsdatum statt festem Alter (OPTIONAL, v3.10) ---
# PROBLEM (Blood-Tracker bis v2.28.0): ein festes Alter in den Einstellungen - ältere Messwerte
# wurden mit dem HEUTIGEN Alter bewertet (PhenoAge, Risiko-Scores, eGFR).
# LÖSUNG: Geburtsdatum speichern ('yyyy-MM-dd'), Alter je Messtag in vollendeten Lebensjahren
# berechnen (wie die offiziellen Rechner). Ohne Geburtsdatum (Altbestand) gilt weiter das
# feste Alter als Fallback - die Migration ist damit verlustfrei. UI: Sektion 6o.
function Get-AgeAtDate {
    <#
    .PARAMETER BirthDate
        [datetime] oder Text (TT.MM.JJJJ / JJJJ-MM-TT); leer = Fallback verwenden.
    .PARAMETER Date
        Stichtag (z.B. Messtag); leer = heute.
    .PARAMETER FallbackAge
        Festes Alter für Altbestände ohne Geburtsdatum.
    .OUTPUTS
        [double] Alter oder $null (keine Angabe, ungültiges Datum, Stichtag vor der Geburt).
    #>
    param($BirthDate, $Date = $null, $FallbackAge = $null)
    $birth = $null
    if ($BirthDate -is [datetime]) { $birth = $BirthDate.Date }
    elseif ($BirthDate) { $birth = ConvertTo-AppDate -Text ([string]$BirthDate) }
    if ($null -eq $birth) {
        $fixedAge = 0.0
        if ($null -ne $FallbackAge -and [double]::TryParse([string]$FallbackAge, [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture, [ref]$fixedAge) -and $fixedAge -gt 0) {
            return $fixedAge
        }
        return $null
    }
    $refDate = (Get-Date).Date
    if ($Date -is [datetime]) { $refDate = $Date.Date }
    elseif ($null -ne $Date -and [string]$Date -ne '') {
        # Text über ConvertTo-AppDate - ein [datetime]-Cast läse "01.02.2026" kulturabhängig
        $parsedRef = ConvertTo-AppDate -Text ([string]$Date)
        if ($null -eq $parsedRef) { return $null }
        $refDate = $parsedRef
    }
    if ($refDate -lt $birth) { return $null }
    $years = $refDate.Year - $birth.Year
    if ($refDate.Month -lt $birth.Month -or ($refDate.Month -eq $birth.Month -and $refDate.Day -lt $birth.Day)) { $years-- }
    return [double]$years
}
# AUFRUF:  Get-AgeAtDate -BirthDate $script:data.Config.Personal.Geburtsdatum `
#                        -FallbackAge $script:data.Config.Personal.Age -Date $item.Date


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 5: UI-POPUP-FORMULARE                                              ║
# ║  Wiederverwendbare Popup-Fenster für Einstellungen, Bearbeitung, Filter.     ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# --- 5a. Einstellungs-Popup (PFLICHT) ---
# Standard-Popup mit: Config öffnen, Datenverzeichnis öffnen, ZIP-Export,
# CSV-Import (optional), Datenpfad ändern (optional), Backup-Restore, Deinstallation.
# WICHTIG: Alle Zugriffe auf globale Variablen mit $script: Prefix!
function Show-SettingsPopup {
    param($mainForm)
    $popupForm = New-Object System.Windows.Forms.Form
    $popupForm.Size = New-Object System.Drawing.Size(450, 455)
    $popupForm.Text = "Einstellungen & Datenverwaltung"
    $popupForm.StartPosition = "CenterParent"
    $popupForm.FormBorderStyle = "FixedDialog"
    $popupForm.MaximizeBox = $false
    $popupForm.MinimizeBox = $false

    # Beschreibungs-Label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Verwalten Sie hier Ihre Konfigurationsdateien und Exporte."
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(400, 20)
    $popupForm.Controls.Add($label)

    # Button: Konfigurationsdatei öffnen
    $openConfigFileButton = New-Object System.Windows.Forms.Button
    $openConfigFileButton.Text = "Konfigurationsdatei öffnen (.json)"
    $openConfigFileButton.Location = New-Object System.Drawing.Point(20, 60)
    $openConfigFileButton.Size = New-Object System.Drawing.Size(400, 35)
    $popupForm.Controls.Add($openConfigFileButton)

    # Button: Datenverzeichnis öffnen
    $openDataPathButton = New-Object System.Windows.Forms.Button
    $openDataPathButton.Text = "Daten-Verzeichnis im Explorer öffnen"
    $openDataPathButton.Location = New-Object System.Drawing.Point(20, 105)
    $openDataPathButton.Size = New-Object System.Drawing.Size(400, 35)
    $popupForm.Controls.Add($openDataPathButton)

    # Button: ZIP-Export
    $exportDataButton = New-Object System.Windows.Forms.Button
    $exportDataButton.Text = "Benutzerdaten als ZIP-Archiv exportieren..."
    $exportDataButton.Location = New-Object System.Drawing.Point(20, 150)
    $exportDataButton.Size = New-Object System.Drawing.Size(400, 35)
    $popupForm.Controls.Add($exportDataButton)

    # [OPTIONAL] Button: CSV-Import
    $importDataButton = New-Object System.Windows.Forms.Button
    $importDataButton.Text = "Daten aus CSV importieren..."
    $importDataButton.Location = New-Object System.Drawing.Point(20, 195)
    $importDataButton.Size = New-Object System.Drawing.Size(400, 35)
    $popupForm.Controls.Add($importDataButton)

    # [OPTIONAL] Button: Datenpfad ändern
    $moveDataButton = New-Object System.Windows.Forms.Button
    $moveDataButton.Text = "Datenpfad ändern..."
    $moveDataButton.Location = New-Object System.Drawing.Point(20, 240)
    $moveDataButton.Size = New-Object System.Drawing.Size(400, 35)
    $popupForm.Controls.Add($moveDataButton)

    # Button: Sicherung wiederherstellen (PFLICHT)
    # Stellt ein Deinstallations-Backup (ZIP) vollständig wieder her.
    # Unterstützt Clean-Restore (bestehende Daten ersetzen) und Merge-Modus (ergänzen).
    $restoreBackupButton = New-Object System.Windows.Forms.Button
    $restoreBackupButton.Text = "Sicherung wiederherstellen (ZIP)..."
    $restoreBackupButton.Location = New-Object System.Drawing.Point(20, 285)
    $restoreBackupButton.Size = New-Object System.Drawing.Size(400, 35)
    $restoreBackupButton.ForeColor = [System.Drawing.Color]::DarkGreen
    $popupForm.Controls.Add($restoreBackupButton)

    # Button: Deinstallieren (PFLICHT)
    # Entfernt alle Benutzerdaten, Registry-Einträge und das Script selbst.
    # Bietet vorher optional eine vollständige Sicherung als ZIP an.
    $uninstallButton = New-Object System.Windows.Forms.Button
    $uninstallButton.Text = "Deinstallieren"
    $uninstallButton.Location = New-Object System.Drawing.Point(20, 330)
    $uninstallButton.Size = New-Object System.Drawing.Size(400, 35)
    $uninstallButton.ForeColor = [System.Drawing.Color]::DarkRed
    $popupForm.Controls.Add($uninstallButton)

    # Button: Schließen
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Text = "Schließen"
    $closeButton.Location = New-Object System.Drawing.Point(170, 383)
    $closeButton.Size = New-Object System.Drawing.Size(100, 30)
    $closeButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $popupForm.Controls.Add($closeButton)
    $popupForm.AcceptButton = $closeButton

    # --- Event-Handler ---
    # WICHTIG: Innerhalb von Event-Handlern immer $script: Prefix für globale Variablen!

    $openConfigFileButton.Add_Click({
        if (Test-Path $script:dataFile) {
            try { Invoke-Item $script:dataFile }
            catch { [System.Windows.Forms.MessageBox]::Show("Fehler: $($_.Exception.Message)") }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Konfigurationsdatei nicht gefunden.")
        }
    })

    $openDataPathButton.Add_Click({
        if (Test-Path $script:dataDir) {
            try { Invoke-Item $script:dataDir }
            catch { [System.Windows.Forms.MessageBox]::Show("Fehler: $($_.Exception.Message)") }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Datenverzeichnis nicht gefunden.")
        }
    })

    $exportDataButton.Add_Click({
        $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveFileDialog.Filter = "ZIP-Archiv (*.zip)|*.zip"
        $saveFileDialog.Title = "Benutzerdaten exportieren"
        $saveFileDialog.FileName = "$($script:AppName)_Export_$(Get-Date -Format 'yyyy-MM-dd').zip"
        if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            try {
                Compress-Archive -Path "$($script:dataDir)\*" -DestinationPath $saveFileDialog.FileName -Force
                [System.Windows.Forms.MessageBox]::Show(
                    "Daten erfolgreich exportiert.", "Export abgeschlossen", "OK", "Information")
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Fehler beim Exportieren: $($_.Exception.Message)")
            }
        }
    })

    # [OPTIONAL] CSV-Import Handler
    $importDataButton.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "CSV-Datei (*.csv)|*.csv"
        $openFileDialog.Title = "CSV-Datei für Import auswählen"
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Import-CsvData -filePath $openFileDialog.FileName
            # [PLACEHOLDER] Nach Import: Daten neu laden und UI aktualisieren
        }
    })

    # [OPTIONAL] Datenpfad-Änderung Handler
    # v3.10 BUGFIX (Datenverlust): über Move-DataDirectorySafe (Sektion 3p) - kopieren, jede
    # Datei prüfen, Registry umstellen, ERST DANN den alten Ordner löschen. Bisher Move-Item +
    # Remove-Item ohne Prüfung (anderes Laufwerk: Unterordner nicht verschoben, aber gelöscht).
    $moveDataButton.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Wählen Sie ein neues, leeres Verzeichnis für die Anwendungsdaten."
        if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $newPath = $folderBrowser.SelectedPath
            if ((Get-AppPathKey -Path $newPath) -eq (Get-AppPathKey -Path $script:dataDir)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Der Pfad ist bereits der aktuelle Speicherort.", "Information", "OK", "Information")
                return
            }
            if (@(Get-ChildItem -LiteralPath $newPath -Force -ErrorAction SilentlyContinue).Count -gt 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Das Verzeichnis ist nicht leer. Bitte leeren Ordner wählen.", "Fehler", "OK", "Error")
                return
            }
            try {
                $popupForm.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
                $moveResult = Move-DataDirectorySafe -SourceDir $script:dataDir -TargetDir $newPath -SwitchAction {
                    Set-ItemProperty -Path $script:regPath -Name "DataPath" -Value $newPath -ErrorAction Stop
                }
                $popupForm.Cursor = [System.Windows.Forms.Cursors]::Default
                $moveMsg = "Datenpfad geändert nach `"$newPath`" ($($moveResult.FileCount) Dateien kopiert und geprüft)."
                if (-not $moveResult.OldDirRemoved) {
                    $moveMsg += "`n`nHinweis: Der alte Ordner konnte nicht vollständig entfernt werden (Datei in Benutzung):`n$($script:dataDir)`nAlle Daten liegen geprüft am neuen Ort - den alten Ordner nach dem Neustart manuell löschen."
                }
                $moveMsg += "`n`nDas Programm wird nun neu gestartet."
                [System.Windows.Forms.MessageBox]::Show($moveMsg, "Erfolg", "OK", "Information")
                # $PSCommandPath verwenden - $MyInvocation.MyCommand.Path ist im Event-Handler leer
                $scriptPath = $PSCommandPath
                if (-not $scriptPath) { $scriptPath = $MyInvocation.ScriptName }
                if ($scriptPath -and (Test-Path $scriptPath)) {
                    Start-Process powershell -ArgumentList "-File `"$scriptPath`""
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Bitte $($script:AppName) manuell neu starten.", "Neustart", "OK", "Information")
                }
                $popupForm.Close()
                $mainForm.Close()
            } catch {
                $popupForm.Cursor = [System.Windows.Forms.Cursors]::Default
                [System.Windows.Forms.MessageBox]::Show(
                    "Fehler beim Verschieben der Daten: $($_.Exception.Message)`n`nEs wurde nichts verändert - die Daten liegen weiterhin unter:`n$($script:dataDir)",
                    "Fehler", "OK", "Error")
            }
        }
    })

    # Backup-Restore-Handler (PFLICHT)
    # Ablauf: ZIP auswählen → Validieren (UserData-Ordner) → Lesbarkeit prüfen (v3.10) →
    #         Clean/Merge fragen → transaktional wiederherstellen (v3.10, Sektion 3o) → Registry → Neustart
    $restoreBackupButton.Add_Click({
        # Schritt 1: ZIP-Datei auswählen
        $openDlg = New-Object System.Windows.Forms.OpenFileDialog
        $openDlg.Filter = "ZIP-Archiv (*.zip)|*.zip"
        $openDlg.Title = "Backup-ZIP auswählen..."
        if ($openDlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $zipPath = $openDlg.FileName

        try {
            # Schritt 2: ZIP in temporäres Verzeichnis entpacken und validieren
            $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PSC_$($script:AppName)_Restore_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
            Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

            # Prüfe ob UserData-Ordner vorhanden ist (Pflicht-Inhalt eines gültigen Backups)
            $userDataSource = Join-Path -Path $tempDir -ChildPath "UserData"
            $hasUserData = Test-Path $userDataSource

            if (-not $hasUserData) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Die gewählte ZIP-Datei enthält keinen 'UserData'-Ordner und ist kein gültiges $($script:AppName) Backup.",
                    "Ungültiges Backup", "OK", "Error")
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                return
            }

            # Quelle bestimmen: verschachtelt (UserData\[AppName]\...) oder flach
            $innerAppDir = Join-Path -Path $userDataSource -ChildPath $script:AppName
            $restoreSource = if (Test-Path $innerAppDir) { $innerAppDir } else { $userDataSource }

            # Schritt 2b (v3.10): Sind die Backup-Dateien auf DIESEM PC/Benutzerprofil lesbar?
            # ZIP-Backups enthalten DPAPI-verschlüsselte Dateien des Quell-PCs/-Profils - dort
            # unlesbar, würden sie lesbare Daten ersetzen. Für PC-Wechsel: AES-Backup (3i).
            $unreadableFiles = @(Get-UnreadableJsonFiles -RootDir $restoreSource)
            if ($unreadableFiles.Count -gt 0) {
                $shownList = ($unreadableFiles | Select-Object -First 5 | ForEach-Object { "- $_" }) -join "`n"
                $moreText = if ($unreadableFiles.Count -gt 5) { "`n- ... und $($unreadableFiles.Count - 5) weitere" } else { "" }
                $continueChoice = [System.Windows.Forms.MessageBox]::Show(
                    "Das Backup enthält $($unreadableFiles.Count) Datei(en), die auf diesem PC bzw. mit diesem Windows-Benutzer NICHT lesbar sind:`n`n$shownList$moreText`n`nUrsache meist: Das Backup stammt von einem anderen PC oder Benutzerprofil (DPAPI). Für einen PC-Wechsel bitte den portablen, passwortgeschützten Export verwenden.`n`nTrotzdem wiederherstellen? (nicht empfohlen)",
                    "Backup auf diesem PC nicht lesbar",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Warning,
                    [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
                if ($continueChoice -ne "Yes") {
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                    return
                }
            }

            # Schritt 3: Bestehende Daten prüfen und Merge/Überschreiben fragen
            $existingDataCount = 0
            if (Test-Path $script:dataDir) {
                $existingDataCount = @(Get-ChildItem -Path $script:dataDir -Recurse -File -ErrorAction SilentlyContinue).Count
            }

            $restoreMode = "overwrite"
            if ($existingDataCount -gt 0) {
                $choice = [System.Windows.Forms.MessageBox]::Show(
                    "Es sind bereits $existingDataCount Dateien im aktuellen Datenverzeichnis vorhanden.`n`nMöchten Sie die bestehenden Daten vorher löschen und komplett durch das Backup ersetzen?`n`n[Ja] = Alles löschen und Backup wiederherstellen`n[Nein] = Backup-Daten ergänzen (bestehende Dateien werden überschrieben)`n[Abbrechen] = Nichts tun",
                    "Bestehende Daten gefunden", "YesNoCancel", "Question")
                if ($choice -eq "Cancel") {
                    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                    return
                }
                if ($choice -eq "Yes") { $restoreMode = "clean" }
                else { $restoreMode = "merge" }
            }

            # Schritt 4: Daten wiederherstellen
            # v3.10 BUGFIX (Datenverlust): Bisher löschte "clean" ZUERST alles und kopierte DANACH -
            # ein Fehler beim Kopieren hinterließ einen leeren/halben Bestand. Jetzt transaktional
            # (Staging + Austausch + Rückweg, Sektion 3o). Bei Fehler: Bestand unverändert.
            $runningScript = $PSCommandPath
            if (-not $runningScript) { $runningScript = $MyInvocation.ScriptName }
            $null = Invoke-SafeDataRestore -SourceDir $restoreSource -DataDir $script:dataDir -Mode $restoreMode -ProtectedFile $runningScript

            # 4d: Registry wiederherstellen (falls .reg-Datei vorhanden)
            $regRestored = $false
            $regFile = Join-Path -Path $tempDir -ChildPath "Registry_Backup.reg"
            if (Test-Path $regFile) {
                $regImportResult = & reg import $regFile 2>&1
                $regRestored = $true
            }

            # Registry: DataPath auf aktuellen Pfad setzen (verhindert Pfadkonflikte aus altem Backup)
            if (-not (Test-Path $script:regPath)) { New-Item -Path $script:regPath -Force | Out-Null }
            Set-ItemProperty -Path $script:regPath -Name "DataPath" -Value $script:dataDir

            # Schritt 5: Temporäres Verzeichnis aufräumen
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

            # Schritt 6: Zusammenfassung und Neustart
            $summary = "Wiederherstellung erfolgreich abgeschlossen!`n`n"
            $summary += "- Benutzerdaten: Wiederhergestellt ($restoreMode)`n"
            $summary += "- Registry: $(if ($regRestored) { 'Importiert' } else { 'Übersprungen (wird beim Start initialisiert)' })`n"
            $summary += "`nDas Programm wird nun neu gestartet."

            [System.Windows.Forms.MessageBox]::Show($summary, "Wiederherstellung abgeschlossen", "OK", "Information")

            # Neustart
            $scriptPath = $PSCommandPath
            if (-not $scriptPath) { $scriptPath = $MyInvocation.ScriptName }
            if ($scriptPath -and (Test-Path $scriptPath)) {
                Start-Process powershell -ArgumentList "-File `"$scriptPath`""
            }
            $popupForm.Close()
            $mainForm.Close()
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Fehler bei der Wiederherstellung: $($_.Exception.Message)",
                "Fehler", "OK", "Error")
            # Temp-Verzeichnis aufräumen falls vorhanden
            if ($tempDir -and (Test-Path $tempDir)) {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    })

    # Deinstallations-Handler (PFLICHT)
    # Ablauf: Bestätigung → Sicherungsfrage → ZIP-Export (Daten + Registry + Script) → Löschung
    $uninstallButton.Add_Click({
        # Schritt 1: Bestätigung einholen
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Möchten Sie $($script:AppName) wirklich vollständig deinstallieren?`n`nFolgende Daten werden unwiderruflich entfernt:`n- Alle gespeicherten Benutzerdaten`n- Registry-Einträge`n- Das Script selbst`n`nDieser Vorgang kann nicht rückgängig gemacht werden!",
            "Deinstallation bestätigen", "YesNo", "Warning")
        if ($confirm -ne "Yes") { return }

        # Schritt 2: Sicherung anbieten (Ja/Nein/Abbrechen)
        $backup = [System.Windows.Forms.MessageBox]::Show(
            "Möchten Sie vorher eine vollständige Sicherung aller Daten erstellen?`n`n(Enthält: Benutzerdaten, Registry-Einträge und das Script)",
            "Sicherung erstellen?", "YesNoCancel", "Question")
        if ($backup -eq "Cancel") { return }

        # Script-Pfad ermitteln (mehrere Fallbacks für verschiedene Aufrufszenarien)
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.ScriptName }
        if (-not $scriptPath) { $scriptPath = & { $MyInvocation.ScriptName } }

        if ($backup -eq "Yes") {
            # Schritt 3: Zielpfad auswählen und ZIP-Sicherung erstellen
            $saveDlg = New-Object System.Windows.Forms.SaveFileDialog
            $saveDlg.Filter = "ZIP-Archiv (*.zip)|*.zip"
            $saveDlg.Title = "Sicherung speichern unter..."
            $saveDlg.FileName = "$($script:AppName)_Backup_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').zip"
            if ($saveDlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
            $backupZip = $saveDlg.FileName

            try {
                # Temporäres Staging-Verzeichnis im System-Temp anlegen
                $stagingDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "PSC_$($script:AppName)_Uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null

                # 3a: Benutzerdaten kopieren
                if (Test-Path $script:dataDir) {
                    $dataBackupDir = Join-Path -Path $stagingDir -ChildPath "UserData"
                    Copy-Item -Path $script:dataDir -Destination $dataBackupDir -Recurse -Force
                }

                # 3b: Registry-Schlüssel exportieren (nativer .reg-Export, Fallback als .txt)
                $regExportFile = Join-Path -Path $stagingDir -ChildPath "Registry_Backup.reg"
                $regKeyFull = ($script:regPath -replace "HKCU:\\", "HKCU\")  # reg.exe braucht HKCU\ statt HKCU:\
                $regExportResult = & reg export $regKeyFull $regExportFile /y 2>&1
                if (-not (Test-Path $regExportFile)) {
                    $regExportFile = Join-Path -Path $stagingDir -ChildPath "Registry_Backup.txt"
                    $regValues = Get-ItemProperty -Path $script:regPath -ErrorAction SilentlyContinue
                    if ($regValues) { $regValues | Out-String | Set-Content -Path $regExportFile -Encoding UTF8 }
                }

                # 3c: Script-Datei kopieren
                if ($scriptPath -and (Test-Path $scriptPath)) {
                    Copy-Item -Path $scriptPath -Destination $stagingDir -Force
                }

                # 3d: ZIP erstellen und Staging aufräumen
                if (Test-Path $backupZip) { Remove-Item -Path $backupZip -Force }
                Compress-Archive -Path "$stagingDir\*" -DestinationPath $backupZip -Force
                Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue

                [System.Windows.Forms.MessageBox]::Show(
                    "Sicherung erfolgreich erstellt:`n$backupZip`n`nDie Deinstallation wird nun fortgesetzt.",
                    "Sicherung abgeschlossen", "OK", "Information")
            } catch {
                $errMsg = $_.Exception.Message
                $abortChoice = [System.Windows.Forms.MessageBox]::Show(
                    "Fehler bei der Sicherung: $errMsg`n`nMöchten Sie die Deinstallation trotzdem fortsetzen?",
                    "Sicherungsfehler", "YesNo", "Error")
                if ($abortChoice -ne "Yes") { return }
            }
        }

        # Schritt 4: Daten vollständig entfernen
        try {
            # 4a: Datenverzeichnis löschen
            if (Test-Path $script:dataDir) {
                Remove-Item -Path $script:dataDir -Recurse -Force
            }

            # 4b: Registry-Schlüssel entfernen
            # Löscht auch den übergeordneten PSC-Schlüssel wenn er danach leer ist.
            if (Test-Path $script:regPath) {
                Remove-Item -Path $script:regPath -Recurse -Force
            }
            $parentRegPath = "HKCU:\Software\PSC"
            if ((Test-Path $parentRegPath) -and @(Get-ChildItem -Path $parentRegPath -ErrorAction SilentlyContinue).Count -eq 0) {
                Remove-Item -Path $parentRegPath -Force -ErrorAction SilentlyContinue
            }

            # 4c: Script-Datei löschen (verzögert per Hintergrundjob,
            #     da die Datei während der Ausführung gesperrt sein kann)
            if ($scriptPath -and (Test-Path $scriptPath)) {
                $deleteCmd = "Start-Sleep -Seconds 2; Remove-Item -Path '$($scriptPath -replace "'","''")' -Force -ErrorAction SilentlyContinue"
                Start-Process powershell -ArgumentList "-WindowStyle Hidden -Command $deleteCmd" -WindowStyle Hidden
            }

            [System.Windows.Forms.MessageBox]::Show(
                "$($script:AppName) wurde erfolgreich deinstalliert.`nAlle Daten und Einstellungen wurden entfernt.`n`nDas Programm wird jetzt beendet.",
                "Deinstallation abgeschlossen", "OK", "Information")

            # Programm beenden
            $popupForm.Close()
            $mainForm.Close()
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Fehler bei der Deinstallation: $($_.Exception.Message)`n`nEinige Daten konnten möglicherweise nicht entfernt werden.",
                "Fehler", "OK", "Error")
        }
    })

    $popupForm.ShowDialog()
}

# --- 5b. Filter-Einstellungs-Popup (OPTIONAL) ---
# Popup mit Zeitraum-Filter, Gruppen-Filter und/oder Bewertungs-Filter.
# Verwendet in: Blood-Tracker (Cockpit, DataMgmt, Longevity Tabs)
function Show-FilterSettingsPopup {
    param(
        [string]$title = "Einstellungen",
        [scriptblock]$onApply = $null  # Callback nach Schließen
    )
    $popupForm = New-Object System.Windows.Forms.Form
    $popupForm.Size = New-Object System.Drawing.Size(450, 250)
    $popupForm.Text = $title
    $popupForm.StartPosition = "CenterParent"
    $popupForm.FormBorderStyle = "FixedDialog"
    $popupForm.MaximizeBox = $false
    $popupForm.MinimizeBox = $false

    # Filter-GroupBox
    $filterGroup = New-Object System.Windows.Forms.GroupBox
    $filterGroup.Text = "Filter"
    $filterGroup.Location = New-Object System.Drawing.Point(20, 20)
    $filterGroup.Size = New-Object System.Drawing.Size(400, 110)
    $popupForm.Controls.Add($filterGroup)

    # Zeitraum-Auswahl
    $zeitraumGroup = New-Object System.Windows.Forms.GroupBox
    $zeitraumGroup.Text = "Zeitraum"
    $zeitraumGroup.Location = New-Object System.Drawing.Point(15, 25)
    $zeitraumGroup.Size = New-Object System.Drawing.Size(370, 60)
    $filterGroup.Controls.Add($zeitraumGroup)

    $zeitraumLabel = New-Object System.Windows.Forms.Label
    $zeitraumLabel.Text = "Zeitraum:"
    $zeitraumLabel.Location = New-Object System.Drawing.Point(15, 24)
    $zeitraumLabel.Size = New-Object System.Drawing.Size(70, 20)
    $zeitraumGroup.Controls.Add($zeitraumLabel)

    $zeitraumCombo = New-Object System.Windows.Forms.ComboBox
    $zeitraumCombo.Location = New-Object System.Drawing.Point(90, 22)
    $zeitraumCombo.Size = New-Object System.Drawing.Size(260, 20)
    $zeitraumCombo.DropDownStyle = "DropDownList"
    $zeitraumCombo.Items.AddRange(@("Aktuelles Jahr", "Letzte 3 Jahre", "Letzte 5 Jahre", "Letzte 10 Jahre", "Alle Daten"))
    $zeitraumCombo.SelectedItem = "Alle Daten"  # [PLACEHOLDER] Aktuellen Filter-Wert setzen
    $zeitraumGroup.Controls.Add($zeitraumCombo)

    # Schließen-Button
    $closeBtn = New-Object System.Windows.Forms.Button
    $closeBtn.Text = "Schließen"
    $closeBtn.Location = New-Object System.Drawing.Point(20, 140)
    $closeBtn.Size = New-Object System.Drawing.Size(100, 30)
    $closeBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $popupForm.Controls.Add($closeBtn)
    $popupForm.AcceptButton = $closeBtn

    # Filter zurücksetzen-Button
    $resetBtn = New-Object System.Windows.Forms.Button
    $resetBtn.Text = "Filter zurücksetzen"
    $resetBtn.Location = New-Object System.Drawing.Point(280, 140)
    $resetBtn.Size = New-Object System.Drawing.Size(140, 30)
    $popupForm.Controls.Add($resetBtn)

    $resetBtn.Add_Click({
        $zeitraumCombo.SelectedItem = "Alle Daten"
    })

    [void]$popupForm.ShowDialog()   # v3.10: [void] - sonst liefert die Funktion @(DialogResult, Filter)

    # Rückgabe des gewählten Filters
    return $zeitraumCombo.SelectedItem
}

# --- 5c. Bearbeitungs-Popup (OPTIONAL) ---
# Popup mit DataGridView zum Bearbeiten von Einträgen (Werte ändern, Zeilen löschen).
# Verwendet in: Blood-Tracker (Marker-Einträge bearbeiten), Haushalts-Tracker (Ausgaben bearbeiten)
function Show-EditPopup {
    param($itemName, $historicalData)
    $popupForm = New-Object System.Windows.Forms.Form
    $popupForm.Size = New-Object System.Drawing.Size(500, 450)
    $popupForm.Text = "Einträge für '$itemName' bearbeiten"
    $popupForm.StartPosition = "CenterParent"
    $popupForm.FormBorderStyle = "FixedDialog"
    $popupForm.MinimizeBox = $false
    # v3.10 BUGFIX: $script:-Variable. Ein lokales "$changesMade = $true" im Lösch-Handler
    # erzeugte nur eine Handler-lokale Variable (PS-5.1-FALLE 9) - wurden NUR Zeilen gelöscht,
    # meldete "Übernehmen" Cancel und die Löschung wurde nicht gespeichert.
    # Löschungen werden vorgemerkt und erst beim Übernehmen angewendet - bisher sofort aus
    # $historicalData entfernt, auch wenn danach "Abbrechen" gewählt wurde.
    $script:editChangesMade = $false
    $script:editPendingDeletes = New-Object System.Collections.ArrayList

    # DataGridView für Einträge
    $dgv = New-Object System.Windows.Forms.DataGridView
    $dgv.Location = New-Object System.Drawing.Point(10, 10)
    $dgv.Size = New-Object System.Drawing.Size(460, 320)
    $dgv.AutoSizeColumnsMode = "Fill"
    $dgv.AllowUserToAddRows = $false
    $dgv.AllowUserToDeleteRows = $true
    $dgv.SelectionMode = "FullRowSelect"
    $popupForm.Controls.Add($dgv)

    # Spalten definieren
    $dateCol  = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $dateCol.Name = "Datum"; $dateCol.ReadOnly = $true
    $valueCol = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $valueCol.Name = "Wert"
    $noteCol  = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $noteCol.Name = "Notiz"
    $dgv.Columns.Add($dateCol); $dgv.Columns.Add($valueCol); $dgv.Columns.Add($noteCol)

    # Daten laden
    $itemData = $historicalData | Where-Object { $_.Name -eq $itemName } | Sort-Object Date -Descending
    foreach ($item in $itemData) {
        $rowIndex = $dgv.Rows.Add($item.Date, $item.Value, $item.Note)
        $dgv.Rows[$rowIndex].Tag = $item  # Original-Objekt als Referenz speichern
    }

    # Buttons - v3.10 (Blood-Tracker v2.27.1): alle drei in EINER Reihe unter der Tabelle,
    # gleiche Größe, Gesamtbreite = Tabellenbreite (460 px = 3 x 146 px + 2 x 11 px Abstand).
    # LAYOUT-REGEL: Breite und Abstand aus der Tabellenbreite ableiten, nicht einzeln setzen.
    $btnY = 340; $btnW = 146; $btnH = 34; $btnGap = 11
    $deleteBtn = New-Object System.Windows.Forms.Button
    $deleteBtn.Text = "Auswahl löschen"; $deleteBtn.Location = New-Object System.Drawing.Point(10, $btnY)
    $deleteBtn.Size = New-Object System.Drawing.Size($btnW, $btnH)
    $saveBtn = New-Object System.Windows.Forms.Button
    $saveBtn.Text = "Änderungen übernehmen"; $saveBtn.Location = New-Object System.Drawing.Point((10 + $btnW + $btnGap), $btnY)
    $saveBtn.Size = New-Object System.Drawing.Size($btnW, $btnH)
    $cancelBtn = New-Object System.Windows.Forms.Button
    $cancelBtn.Text = "Abbrechen"; $cancelBtn.Location = New-Object System.Drawing.Point((10 + 2 * ($btnW + $btnGap)), $btnY)
    $cancelBtn.Size = New-Object System.Drawing.Size($btnW, $btnH)
    $popupForm.Controls.AddRange(@($deleteBtn, $saveBtn, $cancelBtn))

    # Event: Zeilen löschen
    $deleteBtn.Add_Click({
        if ($dgv.SelectedRows.Count -eq 0) { return }
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Möchten Sie die $($dgv.SelectedRows.Count) Einträge löschen?",
            "Löschen bestätigen", "YesNo", "Warning")
        if ($result -eq "Yes") {
            $rowsToDelete = New-Object System.Collections.ArrayList
            $rowsToDelete.AddRange($dgv.SelectedRows)
            foreach ($row in $rowsToDelete) {
                # v3.10: erst beim Übernehmen aus den Daten entfernen - "Abbrechen" ändert nichts
                [void]$script:editPendingDeletes.Add($row.Tag)
                $dgv.Rows.Remove($row)
            }
            $script:editChangesMade = $true
        }
    })

    # Event: Speichern
    $saveBtn.Add_Click({
        try {
            foreach ($row in $dgv.Rows) {
                $originalItem = $row.Tag
                $newValue = Parse-Number $row.Cells["Wert"].Value
                $newNote  = $row.Cells["Notiz"].Value
                if ($originalItem.Value -ne $newValue) { $originalItem.Value = $newValue; $script:editChangesMade = $true }
                if ($originalItem.Note  -ne $newNote)  { $originalItem.Note = $newNote;   $script:editChangesMade = $true }
            }
            foreach ($pendingItem in $script:editPendingDeletes) { $historicalData.Remove($pendingItem) }
            $popupForm.DialogResult = if ($script:editChangesMade) { "OK" } else { "Cancel" }
            $popupForm.Close()
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Fehler: $($_.Exception.Message)", "Fehler", "OK", "Error")
        }
    })

    $cancelBtn.Add_Click({ $popupForm.DialogResult = "Cancel"; $popupForm.Close() })

    return $popupForm.ShowDialog()
}


# --- 5d. Export-Popup (OPTIONAL, generisch, v3.5: inkl. PDF) ---
# Kontext-agnostisches Export-Popup für JSON + CSV + PDF. Wird von Tab-Buttons
# "Exportieren..." aufgerufen. Jeder Tab liefert via ScriptBlock seinen
# eigenen Daten-Provider, sodass eine einzige Funktion für alle Tabs genügt.
#
# USAGE:
#   $provider = { return $myGrid.Rows | ForEach-Object { [PSCustomObject]@{...} } }
#   Show-ExportPopup -source "Mein Tab" -dataProvider $provider `
#                    -defaultFileName "Export_$(Get-Date -Format 'yyyy-MM-dd')" `
#                    -pdfTitle "Mein Report"
#
# PATTERN:
# - Button initial: $exportButton.Enabled = $false, wenn Aktivierung an State gebunden
# - Aktivierung: in Add_Click des State-Triggers (z.B. Analyse-Button, SelectionChanged)
# - Deaktivierung: bei leerer Selektion oder Reset
#
# PDF-HINWEIS: Nutzt systemweiten "Microsoft Print to PDF"-Drucker (Windows 10+).
# Keine externen Dependencies nötig. Fallback auf andere PDF-Drucker (Foxit, Adobe)
# falls vorhanden.
# --- 5d. Export: expliziter Dialog-/Druckzustand statt Closures (v3.13.0) ---
# Provider param($Context) -> normale Pipeline-Liste aus Datenobjekten. Kein Komma-Return.
# JSON behaelt verschachtelte Daten. CSV/PDF brauchen flache Zeilen: vorher fachlich
# aufbereiten; unbekannte Zusatzspalten werden ueber alle Zeilen gesammelt, nicht verworfen.
# Write-AppExportRows nutzt 2j/2m, PDF nutzt den konfigurierten installierten Drucker.
# PDF: gekuerzte Zellen moeglich, JSON/CSV fuer vollstaendige Inhalte. Kein PDF-Medizinreport.
# PDF-Ausgabe erfolgt durch den Druckertreiber, nicht ueber den atomaren JSON/CSV-Schreiber.
# Show-ExportPopup bleibt kompatibel mit bisherigen Parametern; ProviderContext/Owner neu.
# Funktionssichtbarkeit bleibt erhalten, da Handler normale Skriptfunktionen aufrufen.

function Get-AppExportColumns {
    param([object[]]$Rows)
    $names=@{}
    foreach($row in $Rows){
        if($row -is [Collections.IDictionary]){$keys=@($row.Keys)}
        elseif($row -is [Management.Automation.PSCustomObject]){$keys=@($row.PSObject.Properties.Name)}
        else{throw 'Export benötigt Datenobjekte statt einzelner Skalare.'}
        foreach($key in $keys){if($key -isnot [string]){throw 'Exportspalten benötigen Textnamen.'};$names[$key]=$true}
    }
    return @($names.Keys|Sort-Object)
}

function ConvertTo-AppFlatExportRows {
    param([object[]]$Rows,[string[]]$Columns)
    foreach($row in $Rows){
        $flat=[ordered]@{}
        foreach($column in $Columns){
            $value=$row.$column
            if($null -ne $value -and $value -isnot [string] -and $value -isnot [ValueType]){throw 'CSV/PDF benötigt flache Zeilen. Verschachtelte Daten als JSON exportieren oder vorher aufbereiten.'}
            $flat[$column]=$value
        }
        [pscustomobject]$flat
    }
}

function Write-AppExportRows {
    <# Keine Dialoge; genau ein Schreibversuch, terminierender Fehler. Pfad als Ergebnis. #>
    param([Parameter(Mandatory)][object[]]$Rows,[Parameter(Mandatory)][string]$Path,[ValidateSet('json','csv')][string]$Format)
    if($Rows.Count -eq 0){throw 'Keine Daten zum Exportieren.'}
    $columns=@(Get-AppExportColumns $Rows)
    if($columns.Count -eq 0){throw 'Keine Exportspalten vorhanden.'}
    $json=ConvertTo-CheckedAppJson -InputObject @($Rows)
    if($Format -eq 'json'){$content=$json}
    else{$flat=@(ConvertTo-AppFlatExportRows -Rows $Rows -Columns $columns);$content=(@($flat|ConvertTo-Csv -Delimiter ';' -NoTypeInformation) -join "`r`n")+"`r`n"}
    Write-AtomicTextFile -Path $Path -Content $content -RequireAtomic
    return $Path
}

function Invoke-AppPdfPage {
    param($State,$PrintArgs)
    $g=$PrintArgs.Graphics;$m=$PrintArgs.MarginBounds
    if($m.Width -lt 100 -or $m.Height -lt 140){throw 'Druckbereich ist zu klein.'}
    $font=New-Object Drawing.Font('Segoe UI',9);$bold=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
    $pen=New-Object Drawing.Pen([Drawing.Color]::Gray,0.5)
    $format=New-Object Drawing.StringFormat;$format.Trimming='EllipsisCharacter';$format.FormatFlags='NoWrap'
    try{
        $State.Page++;$y=$m.Top
        $titleBox=New-Object Drawing.RectangleF($m.Left,$y,$m.Width,25)
        $g.DrawString($State.Title,$bold,[Drawing.Brushes]::Black,$titleBox,$format);$y+=30
        $width=[single]($m.Width/$State.Columns.Count)
        $x=[single]$m.Left
        foreach($col in $State.Columns){$rect=New-Object Drawing.RectangleF(($x+3),$y,($width-6),22);$g.DrawString($col,$bold,[Drawing.Brushes]::Black,$rect,$format);$x+=$width};$y+=26
        while($State.Index -lt $State.Rows.Count -and $y+24 -le $m.Bottom-40){
            $x=[single]$m.Left;$row=$State.Rows[$State.Index]
            foreach($col in $State.Columns){$rect=New-Object Drawing.RectangleF(($x+3),($y+3),($width-6),22);$g.DrawRectangle($pen,$x,[single]$y,$width,24);$g.DrawString([string]$row.$col,$font,[Drawing.Brushes]::Black,$rect,$format);$x+=$width}
            $State.Index++;$y+=24
        }
        $foot=New-Object Drawing.RectangleF($m.Left,($m.Bottom-30),$m.Width,28)
        $g.DrawString("Seite $($State.Page) – Zellen ggf. gekürzt; vollständige Daten in JSON/CSV.",$font,[Drawing.Brushes]::DimGray,$foot,$format)
        $PrintArgs.HasMorePages=($State.Index -lt $State.Rows.Count)
    }finally{$format.Dispose();$pen.Dispose();$bold.Dispose();$font.Dispose()}
}

function Write-AppPdfRows {
    param([Parameter(Mandatory)][object[]]$Rows,[Parameter(Mandatory)][string]$Path,[string]$Title)
    $columns=@(Get-AppExportColumns $Rows)
    if($Rows.Count -eq 0 -or $columns.Count -eq 0){throw 'Keine PDF-Daten vorhanden.'}
    if(@([Drawing.Printing.PrinterSettings]::InstalledPrinters) -notcontains $script:ExportPdfPrinterName){throw 'Der konfigurierte PDF-Drucker ist nicht installiert.'}
    $flat=@(ConvertTo-AppFlatExportRows -Rows $Rows -Columns $columns)
    $doc=New-Object Drawing.Printing.PrintDocument
    if($null -eq $script:AppPdfJobs){$script:AppPdfJobs=@{}}
    $script:AppPdfJobs[$doc]=@{Rows=$flat;Columns=$columns;Index=0;Page=0;Title=$Title}
    try{
        $doc.PrinterSettings.PrinterName=$script:ExportPdfPrinterName;$doc.PrinterSettings.PrintToFile=$true;$doc.PrinterSettings.PrintFileName=$Path
        $doc.DefaultPageSettings.Landscape=$true;$doc.DocumentName=$Title
        $doc.PrintController=New-Object Drawing.Printing.StandardPrintController
        $doc.Add_PrintPage({Invoke-AppPdfPage -State $script:AppPdfJobs[$args[0]] -PrintArgs $args[1]})
        $doc.Print()
    }finally{$script:AppPdfJobs.Remove($doc);$doc.Dispose()}
    # Print() bestaetigt die Uebergabe an den Treiber, nicht den Abschluss des Spoolers.
}

function Invoke-AppExportChoice {
    param($State,[ValidateSet('json','csv','pdf')][string]$Format)
    if($State.Busy){return};$State.Busy=$true;$dialog=$null
    try{
        $rows=@(& $State.Provider $State.Context)
        if($rows.Count -eq 0){throw 'Keine Daten zum Exportieren vorhanden.'}
        $dialog=New-Object Windows.Forms.SaveFileDialog;$dialog.Filter="$($Format.ToUpperInvariant()) (*.$Format)|*.$Format";$dialog.FileName=$State.FileName+'.'+$Format;$dialog.OverwritePrompt=$true
        if($dialog.ShowDialog($State.Form) -ne 'OK'){return}
        if($Format -eq 'pdf'){
            Write-AppPdfRows -Rows $rows -Path $dialog.FileName -Title $State.Title
            $message='Druckauftrag an den PDF-Drucker übergeben. Ausgabe am gewählten Ziel prüfen.'
        }else{
            $null=Write-AppExportRows -Rows $rows -Path $dialog.FileName -Format $Format
            $message='Export erfolgreich abgeschlossen.'
        }
        [void][Windows.Forms.MessageBox]::Show($State.Form,$message,'Export','OK','Information')
        $State.Busy=$false;$State.Form.Close()
    }catch{[void][Windows.Forms.MessageBox]::Show($State.Form,('Export nicht abgeschlossen: '+$_.Exception.Message),'Exportfehler','OK','Error')}
    finally{if($dialog){$dialog.Dispose()};$State.Busy=$false}
}

function New-AppExportDialog {
    param([string]$Source,[scriptblock]$DataProvider,[string]$DefaultFileName,[string]$PdfTitle,$ProviderContext=$null)
    $f=New-Object Windows.Forms.Form;$f.Text='Exportieren – '+$Source;$f.ClientSize=New-Object Drawing.Size(450,275);$f.StartPosition='CenterParent';$f.FormBorderStyle='FixedDialog';$f.MaximizeBox=$false;$f.MinimizeBox=$false
    $s=@{Form=$f;Provider=$DataProvider;Context=$ProviderContext;FileName=$DefaultFileName;Title=$PdfTitle;Busy=$false}
    $f.Tag=@{Export=$s};$y=25
    foreach($format in @('json','csv','pdf')){
        $b=New-Object Windows.Forms.Button;$b.Text='Als '+$format.ToUpperInvariant()+' exportieren …';$b.SetBounds(20,$y,410,38);$y+=50
        $b.Tag=@{State=$s;Format=$format};$b.Add_Click({Invoke-AppExportChoice -State $args[0].Tag.State -Format $args[0].Tag.Format});$f.Controls.Add($b)
    }
    $close=New-Object Windows.Forms.Button;$close.Text='Schließen';$close.SetBounds(170,220,110,30);$close.DialogResult='Cancel';$f.Controls.Add($close);$f.CancelButton=$close
    $f.Add_FormClosing({if($args[0].Tag.Export.Busy){$args[1].Cancel=$true}})
    $f.Add_Disposed({$s=$args[0].Tag.Export;$s.Provider=$null;$s.Context=$null})
    return $s
}

function Show-ExportPopup {
    param([Parameter(Mandatory)][string]$source,[Parameter(Mandatory)][scriptblock]$dataProvider,
          [string]$defaultFileName="Export_$(Get-Date -Format 'yyyy-MM-dd')",[string]$pdfTitle=$null,
          $ProviderContext=$null,[Windows.Forms.IWin32Window]$Owner)
    if(-not $pdfTitle){$pdfTitle='Report: '+$source}
    $state=New-AppExportDialog -Source $source -DataProvider $dataProvider -DefaultFileName $defaultFileName -PdfTitle $pdfTitle -ProviderContext $ProviderContext
    try{if($Owner){[void]$state.Form.ShowDialog($Owner)}else{[void]$state.Form.ShowDialog()}}finally{$state.Form.Dispose()}
}



# --- 5e. Owner-Drawn CheckedListBox mit Disabled-Items (OPTIONAL) ---
# PATTERN: Items bleiben sichtbar, aber "[keine Daten]"-Marker sind nicht auswählbar
# und werden ausgegraut. Genutzt z.B. im Custom-Report-Tab für Marker-Auswahl.
#
# SETUP:
#   $list = New-Object System.Windows.Forms.CheckedListBox
#   $list.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
#   $list.ItemHeight = 20
#
# BEFÜLLUNG: Disabled-Items mit Suffix markieren, z.B. "Marker  [keine Daten]"
#
# ItemCheck blockiert Klicks:
#   $list.Add_ItemCheck({
#       param($s, $e)
#       if ([string]$list.Items[$e.Index] -match '\s+\[keine Daten\]$') {
#           $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked
#       }
#   })
#
# DrawItem rendert per CheckBoxRenderer (konsistentes Windows-Look):
#   $list.Add_DrawItem({
#       param($s, $e)
#       ...
#       [System.Windows.Forms.CheckBoxRenderer]::DrawCheckBox($e.Graphics, $rect.Location, $state)
#       ...
#   })


# --- 5f. PrintDocument / Drucken-Pattern (OPTIONAL) ---
# PATTERN für PrintDocument mit mehreren Seiten, Header, Tabelle, Footer.
# WICHTIG: $script:-Variablen verwenden für Row-Index und Seiten-Counter, damit der
# Handler zwischen Seiten den State behält.
#
#   $script:printRowIndex = 0
#   $script:printPageNum = 0
#   $script:printData = @($myData)     # <- IMMER als @() casten! (Bugfix v3.6)
#   $printDoc = New-Object System.Drawing.Printing.PrintDocument
#   $printDoc.Add_PrintPage({
#       param($sender, $ev)
#       # ... Header bei pageNum == 0 ...
#       # while (rowIndex < data.Count) { if (yPos > bottom) { ev.HasMorePages=$true; return } }
#       $ev.HasMorePages = $false
#   })
#   $printDoc.Print()
#
# ACHTUNG - Array-Unwrapping (Bugfix v3.6):
# PowerShell entpackt Arrays mit einem Element automatisch, sodass $data[0] auf das
# Einzelobjekt selbst zeigt (nicht dessen Index). Das führt zu "Arrayindex wurde als
# NULL ausgewertet"-Fehlern. IMMER $data = @($rawData) verwenden.


# --- 5g. Multi-Section-Report-Pattern (OPTIONAL) ---
# Berichtstyp mit mehreren Sections: pro Section ein Block aus Überschrift,
# Grafik und Tabelle. Beispiel: Custom Report im Blood-Tracker.
#
# ZUSTANDS-VARIABLEN (immer $script:-Scope):
#   $script:reportSections         # Array von Section-Objekten
#   $script:reportSectionIndex     # aktueller Section-Index
#   $script:reportSectionPhase     # 0 = Heading+Chart, 1 = Tab-Header, 2 = Rows
#   $script:reportSectionRowIndex  # aktuelle Row innerhalb Section
#   $script:reportPageNum          # Seitenzähler
#   $script:reportChartBmp         # gerenderter Chart (wird pro Section 1x erzeugt)
#
# ALGORITHMUS im PrintPage-Handler:
#   while (sectionIndex < sections.Count):
#     phase 0: Heading + Chart rendern (Chart nur 1x pro Section)
#              if (space < needed) { HasMorePages = true; return }
#     phase 1: Tabellen-Header zeichnen
#     phase 2: Rows zeichnen bis Seitenende oder Section-Ende
#              bei Section-Ende: ChartBmp.Dispose(), Index inkrementieren, Phase=0
#
# WICHTIG: Jede Phase muss bei Platzmangel sauber pausieren können.
# Den Chart-Bitmap IMMER disposen, sonst GDI-Handle-Leak bei vielen Markern.


# --- 5h. AutoBackup-Popup-Pattern mit Checkbox-Intelligenz (OPTIONAL, v3.8) ---
# Konfigurations-Dialog für automatisches Backup mit intelligenter Format-Auswahl
# (ZIP / Ordner-und-Dateien / Beides).
#
# LAYOUT (siehe Blood-Tracker v2.14.0 Show-AutoBackupPopup):
#   GroupBox "Basis-Konfiguration":
#     - Enabled-Checkbox
#     - Zielverzeichnis (TextBox + Durchsuchen-Button)
#     - Format: 3 Checkboxen (ZIP / Ordner / Beides)
#     - Registry-Include-Checkbox (empfohlen $true)
#     - Last-Backup-Status-Label
#   GroupBox "Zeit-Einstellungen":
#     - Interval-Combo (5 Optionen)
#     - Uhrzeit-DateTimePicker (DisplayFormat=Time, ShowUpDown=true)
#     - Dynamisches Enable/Disable bei "bei Programm-Start"
#   Buttons: "Jetzt Backup ausführen", "Abbrechen", "Speichern"
#
# CHECKBOX-INTELLIGENZ (SuspendEvent-Pattern gegen Event-Kaskaden):
#   $script:abSuspend = $false
#   $syncFromIndividual = {
#       if ($script:abSuspend) { return }
#       $script:abSuspend = $true
#       try {
#           $bothChecked = $chkZip.Checked -and $chkFolder.Checked
#           $chkBoth.Checked = $bothChecked
#           $chkZip.Enabled    = -not $bothChecked
#           $chkFolder.Enabled = -not $bothChecked
#       } finally { $script:abSuspend = $false }
#   }
#   $syncFromBoth = {
#       if ($script:abSuspend) { return }
#       $script:abSuspend = $true
#       try {
#           if ($chkBoth.Checked) {
#               $chkZip.Checked = $true; $chkFolder.Checked = $true
#               $chkZip.Enabled = $false; $chkFolder.Enabled = $false
#           } else {
#               $chkZip.Checked = $false; $chkFolder.Checked = $false
#               $chkZip.Enabled = $true;  $chkFolder.Enabled = $true
#           }
#       } finally { $script:abSuspend = $false }
#   }
#   $chkZip.Add_CheckedChanged($syncFromIndividual)
#   $chkFolder.Add_CheckedChanged($syncFromIndividual)
#   $chkBoth.Add_CheckedChanged($syncFromBoth)
#
# WARUM SuspendEvent? Programmatisches Setzen ($chkZip.Checked = $true) triggert
# CheckedChanged-Event, das wiederum syncFromIndividual aufrufen würde → Endlos-
# Kaskade. Der $abSuspend-Flag durchbricht den Zyklus sauber.



# --- 5i. Passphrase-Dialog (OPTIONAL, v3.9) ---
# Gehört zum portablen AES-Backup (Sektion 3i). Gibt einen SecureString zurück -
# das Klartext-Passwort verlässt den Dialog nie.

function Show-PassphraseDialog {
    <#
    .SYNOPSIS
        Passwort-Dialog, optional mit Bestätigungsfeld.
    .OUTPUTS
        [SecureString] oder $null bei Abbruch.
    #>
    param(
        [string]$Title = "Passwort eingeben",
        [bool]$Confirm = $false
    )
    $ppForm = New-Object System.Windows.Forms.Form
    $ppForm.Text = $Title
    $ppForm.Size = New-Object System.Drawing.Size(420, $(if ($Confirm) { 210 } else { 170 }))
    $ppForm.StartPosition = "CenterParent"
    $ppForm.FormBorderStyle = "FixedDialog"
    $ppForm.MaximizeBox = $false; $ppForm.MinimizeBox = $false

    $lbl1 = New-Object System.Windows.Forms.Label
    $lbl1.Text = "Passwort:"
    $lbl1.Location = New-Object System.Drawing.Point(15, 18)
    $lbl1.Size = New-Object System.Drawing.Size(80, 20)
    $ppForm.Controls.Add($lbl1)

    $txt1 = New-Object System.Windows.Forms.TextBox
    $txt1.UseSystemPasswordChar = $true
    $txt1.Location = New-Object System.Drawing.Point(100, 15)
    $txt1.Size = New-Object System.Drawing.Size(280, 22)
    $ppForm.Controls.Add($txt1)

    $txt2 = $null
    if ($Confirm) {
        $lbl2 = New-Object System.Windows.Forms.Label
        $lbl2.Text = "Bestätigen:"
        $lbl2.Location = New-Object System.Drawing.Point(15, 50)
        $lbl2.Size = New-Object System.Drawing.Size(80, 20)
        $ppForm.Controls.Add($lbl2)

        $txt2 = New-Object System.Windows.Forms.TextBox
        $txt2.UseSystemPasswordChar = $true
        $txt2.Location = New-Object System.Drawing.Point(100, 47)
        $txt2.Size = New-Object System.Drawing.Size(280, 22)
        $ppForm.Controls.Add($txt2)
    }

    $btnY = if ($Confirm) { 85 } else { 55 }
    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "OK"
    $btnOk.Location = New-Object System.Drawing.Point(210, $btnY)
    $btnOk.Size = New-Object System.Drawing.Size(80, 28)
    $ppForm.Controls.Add($btnOk); $ppForm.AcceptButton = $btnOk

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Abbrechen"
    $btnCancel.Location = New-Object System.Drawing.Point(300, $btnY)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 28)
    $ppForm.Controls.Add($btnCancel); $ppForm.CancelButton = $btnCancel

    # Ergebnis über $script:-Scope, da der Handler eine eigene Closure ist
    $script:ppResult = $null
    $btnOk.Add_Click({
        $pw = $txt1.Text
        if ($pw.Length -lt 6) {
            [System.Windows.Forms.MessageBox]::Show("Das Passwort muss mindestens 6 Zeichen lang sein.", "Zu kurz", "OK", "Warning")
            return
        }
        if ($Confirm -and $txt2 -and $pw -ne $txt2.Text) {
            [System.Windows.Forms.MessageBox]::Show("Die Passwörter stimmen nicht überein.", "Keine Übereinstimmung", "OK", "Warning")
            return
        }
        $ss = New-Object System.Security.SecureString
        foreach ($c in $pw.ToCharArray()) { $ss.AppendChar($c) }
        $ss.MakeReadOnly()
        $script:ppResult = $ss
        $ppForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $ppForm.Close()
    })
    $btnCancel.Add_Click({
        $ppForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $ppForm.Close()
    })

    $ppForm.ShowDialog() | Out-Null
    return $script:ppResult
}


# --- 5j. Import-Review-Dialog mit Konfidenz (OPTIONAL, v3.9) ---
# Pflicht-Zwischenschritt für JEDEN automatischen Import (PDF, CSV, Screenshot).
# Der Nutzer bestätigt, das Script schreibt nichts blind.
#
# AUFBAU:
#   - Roter Warnhinweis oben ("Beta - bitte jeden Wert gegen das Original prüfen")
#   - DateTimePicker für das Zieldatum (Short-Format)
#   - Label "n Werte erkannt"
#   - DataGridView, AutoSizeColumnsMode = "Fill", FullRowSelect:
#       [x] (CheckBoxColumn, Width 35, AutoSizeMode "None")
#       Eintrag (ReadOnly, FillWeight 35)
#       Wert    (EDITIERBAR!, FillWeight 12)
#       Einheit (ReadOnly, FillWeight 10)
#       Konfidenz (ReadOnly, FillWeight 10)
#       Quelle - die Original-Zeile (ReadOnly, FillWeight 33)
#   - Buttons: "Alle auswählen" / "Alle abwählen" / "Ausgewählte importieren" / "Abbrechen"
#
# KERNREGELN:
#   1. Zeilen mit Konfidenz "Niedrig" gelb hinterlegen (LemonChiffon) UND per
#      Default NICHT anhaken - der Nutzer muss sie bewusst aktivieren.
#   2. Die Spalte "Wert" bleibt editierbar, damit Erkennungsfehler direkt im
#      Dialog korrigiert werden können.
#   3. Die Spalte "Quelle" zeigt die Original-Zeile (auf ~80 Zeichen gekürzt) -
#      ohne sie ist eine Prüfung gegen das Original nicht zumutbar.
#   4. Ergebnis über $script:-Variable zurückgeben (Handler-Closure).
#   5. Jeder übernommene Wert bekommt eine Herkunfts-Notiz ("PDF-Import (Beta)").
#
#   foreach ($val in ($ParsedValues | Sort-Object { $_.ItemName })) {
#       $i = $grid.Rows.Add($true, $val.ItemName, $val.Value, $val.Unit, $val.Confidence, $val.SourceLine)
#       if ($val.Confidence -eq "Niedrig") {
#           $grid.Rows[$i].DefaultCellStyle.BackColor = [System.Drawing.Color]::LemonChiffon
#           $grid.Rows[$i].Cells["Import"].Value = $false
#       }
#   }


# --- 5k. Tab-spezifisches Einstellungs-Popup (OPTIONAL, v3.9) ---
# Ergänzung zum globalen Settings-Popup (5a): jeder Haupt-Tab bekommt einen
# eigenen, schlanken Dialog nur mit SEINEN Filtern/Optionen.
# NAMENSSCHEMA: Show-<Tabname>SettingsPopup (z.B. Show-CockpitSettingsPopup).
#
# WARUM getrennt? Ein einziger Mega-Dialog wird unübersichtlich, und Filter sind
# tab-lokal ($script:tab1TimeFilter etc., siehe Sektion 1e).
#
# PATTERN A - nur Gruppen mit Daten anbieten:
#   Vor dem Aufbau prüfen, für welche Gruppen überhaupt Datensätze existieren, und
#   nur diese in die ComboBox aufnehmen. Leere Filter frustrieren.
#
# PATTERN B - dynamische Fensterhöhe (Ein-/Ausklappen):
#   $checkboxAreaHeight = [Math]::Max(120, ($groupsWithData.Count * 24) + 20)
#   $collapsedHeight    = 400
#   $expandedHeight     = $collapsedHeight + $checkboxAreaHeight
#   # Bei Auswahl "Custom" die CheckedListBox einblenden und
#   # $popupForm.Height = $expandedHeight setzen, sonst $collapsedHeight.
#   # Nachgelagerte Controls (Buttons) müssen mitverschoben werden.
#
# PATTERN C - Filter sofort persistieren:
#   $zeitraumCombo.Add_SelectedIndexChanged({ $script:tab1TimeFilter = $zeitraumCombo.SelectedItem })
#   Kein "Übernehmen"-Button nötig; beim Schließen den Tab neu zeichnen.
#
# LAYOUT-REGEL (aus mehreren Layout-Hotfixes gelernt):
#   Wächst eine Sub-GroupBox, MÜSSEN alle nachgelagerten Controls und die
#   Fensterhöhe in derselben Änderung mitwandern (Layout-Kaskade). Ein Hinweistext
#   braucht 2 Zeilen Platz - eine GroupBox-Höhe von 85 px reicht dafür nicht (105).


# --- 5l. Report: erzwungener Seitenumbruch, Fußzeile, Papierformat (v3.9) ---
# Drei Korrekturen/Erweiterungen zum Multi-Section-Report aus Sektion 5g.
#
# (1) FUSSZEILE AUF JEDER SEITE - häufiger Bug:
#     Steht der DrawString-Aufruf für die Fußzeile am ENDE des PrintPage-Handlers,
#     erscheint sie nur auf der LETZTEN Seite: jeder Seitenumbruch verlässt den
#     Handler vorher per "return". Lösung: Fußzeile als ScriptBlock definieren und
#     vor JEDEM "HasMorePages = $true; return" aufrufen.
#
#       $drawFooter = {
#           param($gfx, $fnt, $mgn, $pageNo)
#           $gfx.DrawString("Seite $pageNo - $($script:AppName) Report", $fnt,
#                           [System.Drawing.Brushes]::DarkSlateGray,
#                           $mgn.Left, ($mgn.Top + $mgn.Height - 15))
#       }
#       # an jeder Umbruchstelle:
#       & $drawFooter $g $smallFont $margins $script:reportPageNum
#       $ev.HasMorePages = $true
#       return
#
# (2) ERZWUNGENER SEITENUMBRUCH PRO SECTION:
#     Ohne diesen Umbruch wird die nächste Section direkt unter der vorherigen
#     Tabelle weitergedruckt, sobald noch Platz ist. Am Section-Ende (Phase 2):
#
#       $script:reportSectionIndex++
#       $script:reportSectionPhase    = 0
#       $script:reportSectionRowIndex = 0
#       if ($script:reportSectionIndex -lt $script:reportSections.Count) {
#           & $drawFooter $g $smallFont $margins $script:reportPageNum
#           $ev.HasMorePages = $true
#           return
#       }
#
# (3) PAPIERFORMAT FEST AUF DIN A4:
#     Ohne explizite Zuweisung gilt das Standardformat des Druckers (z.B. Letter) -
#     der erzwungene Umbruch wäre dann nicht auf A4 bezogen.
#     REIHENFOLGE-FALLE: PaperSizes hängt am KONKRETEN Drucker. A4 deshalb erst
#     NACH dem Setzen von PrinterSettings.PrinterName zuweisen.
#
#       $applyA4Paper = {
#           param($doc)
#           try {
#               $a4 = $doc.PrinterSettings.PaperSizes |
#                     Where-Object { $_.Kind -eq [System.Drawing.Printing.PaperKind]::A4 } |
#                     Select-Object -First 1
#               if ($a4) { $doc.DefaultPageSettings.PaperSize = $a4 }
#           } catch { }
#       }
#       $printDoc.DefaultPageSettings.Landscape = $true   # Querformat für breite Charts
#       $printDoc.PrinterSettings.PrinterName = $pdfPrinterName
#       & $applyA4Paper $printDoc
#
# (4) KODIERTE WERTE IM AUSDRUCK:
#     Qualitative Einträge müssen auch im PDF als Klartext erscheinen, nicht als
#     Zahlencode - über Get-CodedValueText (Sektion 2i), Einheit dabei leeren.


# --- 5m. Wiederverwendbare UI-Zustaende, Navigation, Sortierung (v3.13.0) ---
# Abhaengigkeiten: WinForms/System.Drawing (1a), USER-KONFIGURATION (0), Parse-Number (2b).
# Keine DPI-Automatik/EnableVisualStyles. UI immer auf dem STA-UI-Thread bedienen.
# Get-AppControlState reserviert Tag['PscUi']; andere Hashtable-Tag-Schluessel bleiben.
# Ein vorhandenes nicht-dictionary Tag wird NICHT ueberschrieben: vor Einbau adaptieren.
# Handler benutzen $args und expliziten Zustand, niemals GetNewClosure.

function Get-AppControlState {
    param([Parameter(Mandatory)]$Control)
    if ($null -eq $Control.Tag) { $Control.Tag = @{} }
    if ($Control.Tag -isnot [Collections.IDictionary]) { throw 'UI-Bausteine benötigen ein freies oder Dictionary-Tag.' }
    if (-not $Control.Tag.Contains('PscUi')) { $Control.Tag['PscUi'] = @{} }
    if ($Control.Tag['PscUi'] -isnot [hashtable]) { throw 'Tag.PscUi ist bereits anderweitig belegt.' }
    return $Control.Tag['PscUi']
}

function Invoke-AppDrawTabHeader {
    param([Windows.Forms.TabControl]$TabControl, $DrawArgs)
    if ($null -eq $DrawArgs -or $DrawArgs.Index -lt 0 -or $DrawArgs.Index -ge $TabControl.TabCount) { return }
    $style = (Get-AppControlState $TabControl).HeaderStyle
    $bounds = $DrawArgs.Bounds
    if ($null -eq $style -or $bounds.Width -lt 8 -or $bounds.Height -lt 4) { return }
    $page = $TabControl.TabPages[$DrawArgs.Index]
    $selected = $DrawArgs.Index -eq $TabControl.SelectedIndex
    $background = New-Object Drawing.SolidBrush([Drawing.SystemColors]::Control)
    try {
        $DrawArgs.Graphics.FillRectangle($background,$bounds)
        if ($selected -and $style.Line) {
            $brush = New-Object Drawing.SolidBrush($style.Color)
            try { $DrawArgs.Graphics.FillRectangle($brush,($bounds.X+4),($bounds.Y+1),($bounds.Width-8),2) } finally { $brush.Dispose() }
        }
        $font = $style.NormalFont
        if ($selected -and $null -ne $style.BoldFont) { $font = $style.BoldFont }
        $color = if ($TabControl.Enabled -and $page.Enabled) { $TabControl.ForeColor } else { [Drawing.SystemColors]::GrayText }
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::SingleLine -bor [Windows.Forms.TextFormatFlags]::EndEllipsis -bor [Windows.Forms.TextFormatFlags]::NoPrefix
        [Windows.Forms.TextRenderer]::DrawText($DrawArgs.Graphics,$page.Text,$font,$bounds,$color,$flags)
        if ($selected -and $TabControl.Focused) {
            $focus = New-Object Drawing.Rectangle(($bounds.X+3),($bounds.Y+4),($bounds.Width-6),([Math]::Max(1,$bounds.Height-6)))
            [Windows.Forms.ControlPaint]::DrawFocusRectangle($DrawArgs.Graphics,$focus)
        }
    } finally { $background.Dispose() }
}

function Initialize-AppActiveTabIndicator {
    <# Einmal nach Setzen der Schrift installieren. Erneuter Aufruf registriert keine Doppelhandler.
       Tab-Font bemisst fette Beschriftung; Seiten behalten ihre bisherige Inhalts-Schrift. #>
    param([Parameter(Mandatory)][Windows.Forms.TabControl]$TabControl)
    $state = Get-AppControlState $TabControl
    if ($state.HeaderStyle -or (-not $script:ActiveTabIndicatorEnabled -and -not $script:ActiveTabBoldEnabled)) { return }
    if ($TabControl.Alignment -ne [Windows.Forms.TabAlignment]::Top) { throw 'Tab-Hervorhebung unterstützt obere Reiter.' }
    if ($script:ActiveTabIndicatorColor -notmatch '^#[0-9a-fA-F]{6}$') { throw 'Ungültige Reiterfarbe in USER-KONFIGURATION.' }
    $style = @{NormalFont=$TabControl.Font; BoldFont=$null; Color=[Drawing.ColorTranslator]::FromHtml($script:ActiveTabIndicatorColor); Line=[bool]$script:ActiveTabIndicatorEnabled}
    $state.HeaderStyle=$style
    if ($script:ActiveTabBoldEnabled) {
        foreach ($page in $TabControl.TabPages) { $page.Font=$page.Font }
        $style.BoldFont=New-Object Drawing.Font($style.NormalFont,($style.NormalFont.Style -bor [Drawing.FontStyle]::Bold))
        $TabControl.Font=$style.BoldFont
        $TabControl.Add_ControlAdded({ if ($args[1].Control -is [Windows.Forms.TabPage]) { if (-not [ComponentModel.TypeDescriptor]::GetProperties($args[1].Control)['Font'].ShouldSerializeValue($args[1].Control)) { $args[1].Control.Font=(Get-AppControlState $args[0]).HeaderStyle.NormalFont } } })
    }
    $TabControl.DrawMode='OwnerDrawFixed'
    $TabControl.Add_DrawItem({ Invoke-AppDrawTabHeader -TabControl $args[0] -DrawArgs $args[1] })
    $TabControl.Add_SelectedIndexChanged({$args[0].Invalidate()})
    $TabControl.Add_GotFocus({$args[0].Invalidate()}); $TabControl.Add_LostFocus({$args[0].Invalidate()})
    $TabControl.Add_Disposed({$style=(Get-AppControlState $args[0]).HeaderStyle; if($style.BoldFont){$style.BoldFont.Dispose()}})
}

function Invoke-AppNavigationRefresh {
    param($State)
    if ($State.Disposed -or $State.Switching -or $null -eq $State.Tabs.SelectedTab) { return }
    $State.LastPages[$State.Current.Name]=$State.Tabs.SelectedTab
    if ($null -ne $State.OnChanged) { & $State.OnChanged $State.Tabs.SelectedTab $State.Context | Out-Null }
}

function Set-AppNavigationCategory {
    param($State,$Group,[Windows.Forms.TabPage]$Page)
    if ($State.Disposed -or $State.Switching) { return }
    if ($null -eq $Page) { $Page=$State.LastPages[$Group.Name]; if ($null -eq $Page) { $Page=$Group.Pages[0] } }
    if ($Group.Pages -notcontains $Page) { throw 'Reiter gehört nicht zur Kategorie.' }
    if ($State.Current -eq $Group) { if ($State.Tabs.SelectedTab -ne $Page) {$State.Tabs.SelectedTab=$Page}; return }
    $State.Switching=$true; $State.Tabs.SuspendLayout()
    try {
        if ($State.Current -and $State.Tabs.SelectedTab) {$State.LastPages[$State.Current.Name]=$State.Tabs.SelectedTab}
        $State.Tabs.TabPages.Clear()
        foreach ($item in $Group.Pages) {[void]$State.Tabs.TabPages.Add($item)}
        $State.Current=$Group; $State.Categories.SelectedTab=$Group.CategoryPage; $State.Tabs.SelectedTab=$Page
        $State.LastPages[$Group.Name]=$Page
    } finally {$State.Tabs.ResumeLayout($true);$State.Switching=$false}
    Invoke-AppNavigationRefresh $State
}

function Select-AppNavigationPage {
    <# Fuer programmatische Navigation immer diese Funktion, nicht SelectedIndex verwenden. #>
    param([Parameter(Mandatory)][Windows.Forms.TabControl]$Tabs,[Parameter(Mandatory)][Windows.Forms.TabPage]$Page)
    $state=(Get-AppControlState $Tabs).Navigation
    if ($null -eq $state) {if (-not $Tabs.TabPages.Contains($Page)){throw 'Reiter fehlt.'};$Tabs.SelectedTab=$Page;return}
    $groups=@($state.Groups|Where-Object {$_.Pages -contains $Page})
    if ($groups.Count -ne 1 -or $state.Disposed) {throw 'Reiter gehört nicht zur aktiven Navigation.'}
    Set-AppNavigationCategory -State $state -Group $groups[0] -Page $Page
}

function Initialize-AppCategoryNavigation {
    <# Host layoutet zwei TabControls: Categories oben (ca. 28px), Tabs darunter.
       Groups=@(@{Name='Kategorie';Pages=@($page1,$page2)},...). Jede Seite genau einmal.
       Besitzt alle zugeordneten Seiten bis zum Dispose eines der TabControls.
       OnChanged param($Page,$Context); normale Skriptfunktion aufrufen, keine Closure. #>
    param([Parameter(Mandatory)][Windows.Forms.TabControl]$Tabs,[Parameter(Mandatory)][Windows.Forms.TabControl]$Categories,
          [Parameter(Mandatory)][object[]]$Groups,[scriptblock]$OnChanged,$Context=$null)
    if ($Tabs -eq $Categories -or $Categories.TabCount -ne 0 -or $Groups.Count -eq 0) {throw 'Ungültige Navigations-Controls/Gruppen.'}
    $tabState=Get-AppControlState $Tabs; $catState=Get-AppControlState $Categories
    if ($tabState.Navigation -or $catState.Navigation) {throw 'Navigation bereits initialisiert.'}
    $names=@{}; $pages=New-Object Collections.ArrayList; $copies=@()
    foreach ($g in $Groups) {
        if ([string]::IsNullOrWhiteSpace([string]$g.Name) -or $names.ContainsKey([string]$g.Name) -or @($g.Pages).Count -eq 0) {throw 'Kategorien benötigen eindeutige Namen und mindestens eine Seite.'}
        $names[[string]$g.Name]=$true
        foreach($p in @($g.Pages)){if($p -isnot [Windows.Forms.TabPage] -or -not $Tabs.TabPages.Contains($p) -or $pages.Contains($p)){throw 'Ungültige oder doppelte Reiterzuordnung.'};[void]$pages.Add($p)}
        $copies+=[pscustomobject]@{Name=[string]$g.Name;Pages=@($g.Pages);CategoryPage=$null}
    }
    if ($pages.Count -ne $Tabs.TabCount) {throw 'Jeder Reiter muss einer Kategorie zugeordnet sein.'}
    $state=@{Tabs=$Tabs;Categories=$Categories;Groups=$copies;Current=$null;LastPages=@{};Switching=$true;Disposed=$false;OnChanged=$OnChanged;Context=$Context}
    $tabState.Navigation=$state;$catState.Navigation=$state
    foreach($g in $copies){$p=New-Object Windows.Forms.TabPage;$p.Text=$g.Name;$g.CategoryPage=$p;[void]$Categories.TabPages.Add($p)}
    Initialize-AppActiveTabIndicator $Tabs; Initialize-AppActiveTabIndicator $Categories
    $Categories.Add_SelectedIndexChanged({
        $s=(Get-AppControlState $args[0]).Navigation
        if($s.Switching -or $s.Disposed -or $null -eq $args[0].SelectedTab){return}
        $g=@($s.Groups|Where-Object {$_.CategoryPage -eq $s.Categories.SelectedTab})[0]
        Set-AppNavigationCategory -State $s -Group $g
    })
    $Tabs.Add_SelectedIndexChanged({Invoke-AppNavigationRefresh (Get-AppControlState $args[0]).Navigation})
    $dispose={
        $s=(Get-AppControlState $args[0]).Navigation
        if($s.Disposed){return};$s.Disposed=$true;$s.OnChanged=$null;$s.Context=$null
        foreach($g in $s.Groups){foreach($p in $g.Pages){if(-not $p.IsDisposed){$p.Dispose()}}}
    }
    $Tabs.Add_Disposed($dispose);$Categories.Add_Disposed($dispose)
    $state.Switching=$false
    Set-AppNavigationCategory -State $state -Group $copies[0]
    return $state
}

function Register-AppGridSorting {
    <# Ungebundene, nicht virtuelle DataGridView. Klick: auf/ab/Einbaureihenfolge.
       Row.Tag bleibt frei; Cell.Tag ist nur bei optionaler GroupColumn reserviert.
       Nach Fuellen/Neuaufbau Invoke-AppGridApplySort aufrufen; Zeilen erhalten dabei
       eine interne stabile Einbaunummer. DataSource-Sortierung gehoert in den Provider. #>
    param([Parameter(Mandatory)][Windows.Forms.DataGridView]$Grid,[hashtable]$Modes=@{},[hashtable]$RankColumns=@{},
          [string]$DefaultColumn='__Order',[string[]]$TieBreak=@(),[string]$GroupColumn='')
    if($null -ne $Grid.DataSource -or $Grid.VirtualMode){throw 'Sortierbaustein benötigt eine ungebundene Tabelle.'}
    $state=Get-AppControlState $Grid
    if($state.Sorting){throw 'Sortierung bereits registriert.'}
    foreach($name in @($Modes.Keys)+@($RankColumns.Keys)+@($RankColumns.Values)+@($TieBreak)+@($DefaultColumn,$GroupColumn)){
        if($name -and $name -ne '__Order' -and -not $Grid.Columns.Contains([string]$name)){throw 'Sortierspalte fehlt.'}
    }
    foreach($mode in $Modes.Values){if($mode -notin @('Auto','Number','Date','Text')){throw 'Ungültiger Sortiermodus.'}}
    $visible=@($Grid.Columns|Where-Object Visible)
    if($visible.Count -eq 0){throw 'Mindestens eine sichtbare Spalte erforderlich.'}
    $state.Sorting=@{Modes=$Modes;RankColumns=$RankColumns;DefaultColumn=$DefaultColumn;TieBreak=@($TieBreak);GroupColumn=$GroupColumn;SortHostColumn=$visible[0].Name;ActiveColumn='';ActiveDescending=$false;Order=@{};NextOrder=0}
    foreach($col in $Grid.Columns){$col.SortMode='Programmatic'}
    $Grid.Add_ColumnHeaderMouseClick({Invoke-AppGridHeaderClick -Grid $args[0] -ClickArgs $args[1]})
    $Grid.Add_SortCompare({Invoke-AppGridSortCompare -Grid $args[0] -CompareArgs $args[1]})
    $Grid.Add_Disposed({(Get-AppControlState $args[0]).Sorting.Order.Clear()})
    Invoke-AppGridApplySort $Grid
}

function Update-AppGridOrder {
    param($Grid,$Config)
    $live=@{}
    foreach($row in $Grid.Rows){if($row.IsNewRow){continue};$live[$row]=$true;if(-not $Config.Order.ContainsKey($row)){$Config.Order[$row]=$Config.NextOrder;$Config.NextOrder++}}
    foreach($row in @($Config.Order.Keys)){if(-not $live.ContainsKey($row)){$Config.Order.Remove($row)}}
}


function Get-AppGridSortKey {
    <#
    .SYNOPSIS
        v2.35.0: Sortierschlüssel eines Zellwerts.
    .PARAMETER Mode
        Auto/Number: Zahl (auch führende Zahl in Text, z. B. "5.2 %", "< 5.2"), sonst Text.
        Date: TT.MM.JJJJ bzw. JJJJ-MM-TT. Text: immer alphabetisch.
    .OUTPUTS
        PSCustomObject { Empty; Kind (0 = Zahl, 1 = Text); Number; Text }
    #>
    param($Value, [ValidateSet('Auto', 'Number', 'Date', 'Text')][string]$Mode = 'Auto')
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return [PSCustomObject]@{ Empty = $true; Kind = 2; Number = 0.0; Text = '' } }
    $isNumericType = ($Value -is [double] -or $Value -is [int] -or $Value -is [long] -or $Value -is [decimal] -or $Value -is [single] -or $Value -is [int16] -or $Value -is [byte])
    if ($Mode -ne 'Text' -and $isNumericType) {
        $numeric = [double]$Value
        if (([double]::IsNaN($numeric) -or [double]::IsInfinity($numeric))) { return [PSCustomObject]@{ Empty = $true; Kind = 2; Number = 0.0; Text = '' } }
        return [PSCustomObject]@{ Empty = $false; Kind = 0; Number = $numeric; Text = '' }
    }
    if ($Value -is [datetime]) { return [PSCustomObject]@{ Empty = $false; Kind = 0; Number = [double]$Value.Ticks; Text = '' } }
    $text = ([string]$Value).Trim()
    if ($text -eq '' -or $text -match '^[-–—]+$') { return [PSCustomObject]@{ Empty = $true; Kind = 2; Number = 0.0; Text = '' } }
    if ($Mode -eq 'Date') {
        $parsedDate = [datetime]::MinValue
        if ([datetime]::TryParseExact($text, [string[]]@('dd.MM.yyyy', 'd.M.yyyy', 'yyyy-MM-dd'), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
            return [PSCustomObject]@{ Empty = $false; Kind = 0; Number = [double]$parsedDate.Ticks; Text = '' }
        }
    } elseif ($Mode -ne 'Text') {
        $numberMatch = [regex]::Match($text, '^[<>≤≥~]?\s*([-+]?\d+(?:[.,]\d+)*(?:[eE][-+]?\d+)?)')
        if ($numberMatch.Success) {
            try {
                $number = Parse-Number $numberMatch.Groups[1].Value
                if ($null -ne $number) { return [PSCustomObject]@{ Empty = $false; Kind = 0; Number = $number; Text = '' } }
            } catch { } # Unlesbarer Zahlentext wird als Text einsortiert, nie als 0.
        }
    }
    # Warnsymbol vor Markernamen ("⚠ Homocystein") beim Sortieren ignorieren
    $clean = $text -replace '^[⚠\s]+', ''
    return [PSCustomObject]@{ Empty = $false; Kind = 1; Number = 0.0; Text = $clean }
}

function Compare-AppGridSortKey {
    <# v2.35.0: Vergleich zweier Sortierschlüssel; leere Werte stehen IMMER unten (unabhängig von -Descending). #>
    param($A, $B, [switch]$Descending)
    if ($A.Empty -and $B.Empty) { return 0 }
    if ($A.Empty) { return 1 }
    if ($B.Empty) { return -1 }
    $result = 0
    if ($A.Kind -ne $B.Kind) { $result = [Math]::Sign($A.Kind - $B.Kind) }
    elseif ($A.Kind -eq 0) { $result = ([double]$A.Number).CompareTo([double]$B.Number) }
    else { $result = [string]::Compare([string]$A.Text, [string]$B.Text, ([cultureinfo]::GetCultureInfo($script:GridSortCulture)), [System.Globalization.CompareOptions]::IgnoreCase) }
    if ($Descending) { $result = -$result }
    return [int][Math]::Sign($result)
}

function Get-AppGridCellSortValue {
    <# v2.35.0: Vergleichswert einer Zeile: Einfügereihenfolge (Row.Tag), Rang-Hilfsspalte, echter Gruppenname (Cell.Tag) oder Zellwert. #>
    param($Row, [string]$ColumnName, $Config)
    if ($ColumnName -eq '__Order') { return $Config.Order[$Row] }
    if ($Config.RankColumns.ContainsKey($ColumnName)) { return $Row.Cells[[string]$Config.RankColumns[$ColumnName]].Value }
    $cell = $Row.Cells[$ColumnName]
    if ($ColumnName -eq $Config.GroupColumn -and $null -ne $cell.Tag) { return $cell.Tag }
    return $cell.Value
}

function Compare-AppGridRows {
    <#
    .SYNOPSIS
        v2.35.0: Vergleicht zwei Tabellenzeilen nach der gewählten Spalte ($Config.ActiveColumn,
        $Config.ActiveDescending) bzw. ohne Auswahl nach der Standardspalte (aufsteigend), danach
        Folgespalten ($Config.TieBreak, aufsteigend) und zuletzt nach der Einfügereihenfolge.
    #>
    param($Row1, $Row2, $Config)
    $column = [string]$Config.ActiveColumn
    $descending = [bool]$Config.ActiveDescending
    if ([string]::IsNullOrEmpty($column)) { $column = [string]$Config.DefaultColumn; $descending = $false }
    $steps = @(@{ Name = $column; Desc = $descending })
    foreach ($tieColumn in @($Config.TieBreak)) { if ($tieColumn -and $tieColumn -ne $column) { $steps += , @{ Name = $tieColumn; Desc = $false } } }
    if ($column -ne '__Order') { $steps += , @{ Name = '__Order'; Desc = $false } }
    foreach ($step in $steps) {
        $mode = 'Auto'
        if ($step.Name -eq '__Order' -or $Config.RankColumns.ContainsKey($step.Name)) { $mode = 'Number' }
        elseif ($Config.Modes.ContainsKey($step.Name)) { $mode = [string]$Config.Modes[$step.Name] }
        $key1 = Get-AppGridSortKey -Value (Get-AppGridCellSortValue -Row $Row1 -ColumnName $step.Name -Config $Config) -Mode $mode
        $key2 = Get-AppGridSortKey -Value (Get-AppGridCellSortValue -Row $Row2 -ColumnName $step.Name -Config $Config) -Mode $mode
        $result = Compare-AppGridSortKey -A $key1 -B $key2 -Descending:([bool]$step.Desc)
        if ($result -ne 0) { return $result }
    }
    return 0
}

function Get-AppGridNextSortState {
    <# v2.35.0: Klickfolge je Spalte: aufsteigend -> absteigend -> Standard; andere Spalte: aufsteigend. #>
    param([string]$CurrentColumn, [bool]$CurrentDescending, [string]$ClickedColumn)
    if ($CurrentColumn -ne $ClickedColumn) { return [PSCustomObject]@{ Column = $ClickedColumn; Descending = $false } }
    if (-not $CurrentDescending) { return [PSCustomObject]@{ Column = $ClickedColumn; Descending = $true } }
    return [PSCustomObject]@{ Column = ''; Descending = $false }
}

function Update-AppGridGroupDisplay {
    <#
    .SYNOPSIS
        v2.35.0: Gruppenspalte - mit -Collapse nur in der ersten Zeile einer Gruppe, sonst in jeder
        Zeile. Der echte Name steht in Cell.Tag (ersetzt die Ausblend-Schleife bis v2.34.1, die mit
        der bereits geleerten Vorzeile verglich).
    #>
    param($Rows, [Parameter(Mandatory)][string]$GroupColumn, [bool]$Collapse)
    $previous = $null
    $isFirst = $true
    foreach ($row in $Rows) {
        if ($row.IsNewRow) { continue }
        $cell = $row.Cells[$GroupColumn]
        if ($null -eq $cell.Tag) { $cell.Tag = [string]$cell.Value }
        $realName = [string]$cell.Tag
        if ($Collapse -and -not $isFirst -and $realName -eq $previous) { $cell.Value = '' } else { $cell.Value = $realName }
        $previous = $realName
        $isFirst = $false
    }
}

function Invoke-AppGridApplySort {
    <# v2.35.0: Sortiert eine registrierte Tabelle nach dem gespeicherten Zustand (oder Standard) und setzt die Sortierpfeile. #>
    param([Parameter(Mandatory)]$Grid)
    $config = (Get-AppControlState $Grid).Sorting
    if (-not $config) { return }
    Update-AppGridOrder -Grid $Grid -Config $config
    if ($Grid.Rows.Count -gt 1) {
        # Die Vergleichslogik steckt im SortCompare-Ereignis (Invoke-AppGridSortCompare) - die
        # übergebene Spalte und Richtung dienen nur als Auslöser.
        $Grid.Sort($Grid.Columns[[string]$config.SortHostColumn], [System.ComponentModel.ListSortDirection]::Ascending)
    }
    foreach ($column in $Grid.Columns) { $column.HeaderCell.SortGlyphDirection = [System.Windows.Forms.SortOrder]::None }
    if ($config.ActiveColumn) {
        $glyph = [System.Windows.Forms.SortOrder]::Ascending
        if ($config.ActiveDescending) { $glyph = [System.Windows.Forms.SortOrder]::Descending }
        $Grid.Columns[[string]$config.ActiveColumn].HeaderCell.SortGlyphDirection = $glyph
    }
    if ($config.GroupColumn) {
        $collapse = (-not $config.ActiveColumn) -or ($config.ActiveColumn -eq $config.GroupColumn)
        Update-AppGridGroupDisplay -Rows $Grid.Rows -GroupColumn $config.GroupColumn -Collapse $collapse
    }
}

function Invoke-AppGridHeaderClick {
    <# v2.35.0: Ereignis ColumnHeaderMouseClick (nur linke Maustaste). #>
    param($Grid, $ClickArgs)
    if ($null -eq $ClickArgs -or $ClickArgs.ColumnIndex -lt 0 -or $ClickArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    $config = (Get-AppControlState $Grid).Sorting
    if (-not $config) { return }
    $next = Get-AppGridNextSortState -CurrentColumn ([string]$config.ActiveColumn) -CurrentDescending ([bool]$config.ActiveDescending) -ClickedColumn ([string]$Grid.Columns[$ClickArgs.ColumnIndex].Name)
    $config.ActiveColumn = $next.Column
    $config.ActiveDescending = $next.Descending
    try { Invoke-AppGridApplySort -Grid $Grid } catch { Write-Warning "Sortieren: $($_.Exception.Message)" }
}

function Invoke-AppGridSortCompare {
    <# v2.35.0: Ereignis SortCompare - vergleicht ganze Zeilen (Compare-AppGridRows); bricht nie mit Fehler ab. #>
    param($Grid, $CompareArgs)
    $config = (Get-AppControlState $Grid).Sorting
    if (-not $config) { return }
    $result = 0
    try { $result = Compare-AppGridRows -Row1 $Grid.Rows[$CompareArgs.RowIndex1] -Row2 $Grid.Rows[$CompareArgs.RowIndex2] -Config $config } catch { $result = 0 }
    $CompareArgs.SortResult = [int]$result
    $CompareArgs.Handled = $true
}

# --- 5n. Generische Mehrfacheingabe mit Pruefansicht (v3.13.0) ---
# Abhaengigkeiten: 5m, 2m, 3q (Save-DailyItems). Keine Blutmarker-Abhaengigkeit.
# Definitions: @(@{Key;Name;Aliases=@();Kind='Number'|'Text'|'Choice';Unit='';
#                  Choices=@(@{Text;Value});Units=@('Einheit A','Einheit B')})
# Name/Key/Aliases sind Suchbegriffe; mehrdeutig -> Fehler, keine willkuerliche Auswahl.
# PrepareItem param($Date,$Definition,$EntryInput,$Context) -> GENAU ein Objekt:
#   @{Item=<zu speichernder Datensatz>;Display='angezeigter gespeicherter Wert';Hint='';Warning=$false}
# EntryInput={Text;ChoiceValue;Unit;Note}; Einheitenumrechnung/qualitative Codes nur hier.
# PrepareItem, ValidateItem und GetIdentity sind rein, werfen bei Fehler und arbeiten
# mit explizitem Context bzw. $script:-Daten; keine lokalen Closures erforderlich.
# Automatische Variablen wie $input nicht als eigene Parameternamen verwenden.
# ValidateItem/GetIdentity: Vertraege aus 3q, fuer Einzel- UND Formulareingabe gemeinsam.
# Schreiben erfolgt ueber Save-DailyItems (Date/Identitaet/Bestand/atomarer Tagesstapel).
# Vorhandene Duplikate werden beim Commit unter Sperre geprueft. Kein Ueberschreiben.
# Sonderformate nicht direkt anbinden: eigenen transaktionalen Adapter planen.
# Konstruktion liefert Zustand, Show liefert Result oder null; Aufrufer aktualisiert
# Anzeige erst nach Rueckgabe. Ein Anzeigefehler ist KEIN fehlgeschlagener Commit.
# Kein AcceptButton: Enter bestaetigt Auswahl, speichert niemals ungefragt.
# Beispiel-Aufruf (Callbacks zuvor definieren):
# $result=Show-AppBatchEntryDialog -Definitions $catalog -PrepareItem $prepare -ValidateItem $validate -GetIdentity $identity -Context $model -Owner $form

function Resolve-AppEntryDefinition {
    param([string]$Query,[object[]]$Definitions)
    $text=$Query.Trim()
    $matches=@($Definitions|Where-Object { @($_.Name,$_.Key)+@($_.Aliases) -icontains $text })
    if($matches.Count -ne 1){throw 'Bitte einen eindeutigen Eintrag aus der Liste wählen.'}
    return $matches[0]
}

function Set-AppBatchInputMode {
    param($Row)
    $Row.Definition=$null;$Row.Choice.Visible=$false;$Row.Value.Visible=$true;$Row.Unit.Items.Clear()
    try{$d=Resolve-AppEntryDefinition -Query $Row.Select.Text -Definitions $Row.State.Definitions}catch{return}
    $Row.Definition=$d
    if($d.Kind -eq 'Choice'){
        $Row.Choice.Items.Clear();foreach($c in @($d.Choices)){[void]$Row.Choice.Items.Add([string]$c.Text)}
        $Row.Choice.SelectedIndex=-1;$Row.Choice.Visible=$true;$Row.Value.Visible=$false
    }
    foreach($unit in @($d.Units)){if($unit){[void]$Row.Unit.Items.Add([string]$unit)}}
    if($Row.Unit.Items.Count -eq 0 -and $d.Unit){[void]$Row.Unit.Items.Add([string]$d.Unit)}
    if($Row.Unit.Items.Count -gt 0){$Row.Unit.SelectedIndex=0}
}

function Resize-AppBatchRows {
    param($State)
    if($State.Resizing -or $State.Form.IsDisposed){return};$State.Resizing=$true
    try{
        $width=[Math]::Max(700,$State.Flow.ClientSize.Width-8)
        foreach($row in $State.Rows){$row.Panel.Width=$width;$row.Note.Width=$width-540;$row.Remove.Left=$width-32}
    }finally{$State.Resizing=$false}
}

function Add-AppBatchRow {
    param($State)
    if($State.Reviewing -or $State.Busy){return}
    $panel=New-Object Windows.Forms.Panel;$panel.Height=38;$panel.Width=800
    $select=New-Object Windows.Forms.ComboBox;$select.SetBounds(0,3,250,26);$select.DropDownStyle='DropDown'
    $select.AutoCompleteMode='SuggestAppend';$select.AutoCompleteSource='ListItems'
    foreach($d in $State.Definitions){[void]$select.Items.Add([string]$d.Name)}
    $value=New-Object Windows.Forms.TextBox;$value.SetBounds(260,3,120,26)
    $choice=New-Object Windows.Forms.ComboBox;$choice.SetBounds(260,3,120,26);$choice.DropDownStyle='DropDownList';$choice.Visible=$false
    $unit=New-Object Windows.Forms.ComboBox;$unit.SetBounds(390,3,100,26);$unit.DropDownStyle='DropDownList'
    $note=New-Object Windows.Forms.TextBox;$note.SetBounds(500,3,150,26)
    $remove=New-Object Windows.Forms.Button;$remove.Text='×';$remove.SetBounds(720,2,28,27)
    $panel.Controls.AddRange([Windows.Forms.Control[]]@($select,$value,$choice,$unit,$note,$remove))
    $row=@{State=$State;Panel=$panel;Select=$select;Value=$value;Choice=$choice;Unit=$unit;Note=$note;Remove=$remove;Definition=$null}
    foreach($control in @($select,$value,$choice,$unit,$note,$remove)){$control.Tag=@{Row=$row}}
    $select.TabIndex=0;$value.TabIndex=1;$choice.TabIndex=1;$unit.TabIndex=2;$note.TabIndex=3;$remove.TabIndex=4
    $select.Add_TextChanged({$row=$args[0].Tag.Row;$row.State.Dirty=$true;Set-AppBatchInputMode $row})
    $select.Add_KeyDown({if($args[1].KeyCode -eq 'Enter'){$args[1].SuppressKeyPress=$true;$r=$args[0].Tag.Row;if($r.Choice.Visible){[void]$r.Choice.Focus()}else{[void]$r.Value.Focus()}}})
    foreach($control in @($value,$note)){$control.Add_TextChanged({$args[0].Tag.Row.State.Dirty=$true})}
    foreach($control in @($choice,$unit)){$control.Add_SelectedIndexChanged({$args[0].Tag.Row.State.Dirty=$true})}
    $remove.Add_Click({$r=$args[0].Tag.Row;$s=$r.State;if($s.Reviewing -or $s.Busy){return};$s.Rows.Remove($r);$s.Flow.Controls.Remove($r.Panel);$r.Panel.Dispose();$s.Dirty=$true;Resize-AppBatchRows $s})
    [void]$State.Rows.Add($row);$State.Flow.Controls.Add($panel);Resize-AppBatchRows $State
    $State.Dirty=$true;[void]$select.Focus()
}

function Set-AppBatchReview {
    param($State,[bool]$Visible)
    $State.Reviewing=$Visible;$State.Flow.Visible=-not $Visible;$State.Grid.Visible=$Visible
    $State.Headers.Visible=-not $Visible;$State.Date.Enabled=-not $Visible;$State.Add.Enabled=-not $Visible;$State.Back.Visible=$Visible
    $State.Primary.Text=if($Visible){"Alle $($State.Prepared.Count) Werte speichern"}else{'Eingaben prüfen …'}
    if(-not $Visible){$State.Prepared=@();$State.Status.Text='Tab: nächstes Feld. Enter übernimmt die Auswahl. Leere Zeilen werden ignoriert.'}
}

function Invoke-AppBatchPrimary {
    param($State)
    if($State.Busy -or $State.Result){return}
    $State.Busy=$true;$State.Primary.Enabled=$false
    try{
        if(-not $State.Reviewing){
            $items=@();$display=@();$keys=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal);$number=0;$date=$State.Date.Value.ToString('yyyy-MM-dd')
            foreach($r in $State.Rows){
                $number++
                if([string]::IsNullOrWhiteSpace($r.Select.Text+$r.Value.Text+$r.Choice.Text+$r.Note.Text)){continue}
                try{
                    $d=Resolve-AppEntryDefinition $r.Select.Text $State.Definitions
                    $choiceValue=$null
                    if($d.Kind -eq 'Choice'){
                        if($r.Choice.SelectedIndex -lt 0){throw 'Bitte einen Auswahlwert wählen.'}
                        $choiceValue=@($d.Choices)[$r.Choice.SelectedIndex].Value
                    }elseif([string]::IsNullOrWhiteSpace($r.Value.Text)){throw 'Bitte einen Wert eingeben.'}
                    $inputValue=[pscustomobject]@{Text=$r.Value.Text;ChoiceValue=$choiceValue;Unit=$r.Unit.Text;Note=$r.Note.Text}
                    $prepared=@(& $State.PrepareItem $date $d $inputValue $State.Context)
                    if($prepared.Count -ne 1 -or $null -eq $prepared[0].Item -or $prepared[0].Display -isnot [string]){throw 'PrepareItem verletzt den dokumentierten Rückgabevertrag.'}
                    $item=ConvertTo-Hashtable -InputObject ((ConvertTo-CheckedAppJson $prepared[0].Item)|ConvertFrom-Json)
                    Assert-AppDailyItem -Item $item -DateString $date -ValidateItem $State.ValidateItem
                    $id=@(& $State.GetIdentity $item)
                    if($id.Count -ne 1 -or $id[0] -isnot [string] -or [string]::IsNullOrWhiteSpace($id[0])){throw 'Ungültiger Identitätsschlüssel.'}
                    if(-not $keys.Add($id[0])){throw 'Eintrag ist im Formular doppelt vorhanden.'}
                    $items+=$item;$display+=@{Name=$d.Name;Original=($(if($d.Kind -eq 'Choice'){$r.Choice.Text}else{$r.Value.Text})+' '+$r.Unit.Text).Trim();Value=$prepared[0].Display;Hint=[string]$prepared[0].Hint;Warning=[bool]$prepared[0].Warning;Note=$r.Note.Text}
                }catch{throw "Zeile $number`: $($_.Exception.Message)"}
            }
            if($items.Count -eq 0){throw 'Bitte mindestens einen Wert eingeben.'}
            $State.Prepared=@($items);$State.Grid.Rows.Clear()
            foreach($d in $display){$idx=$State.Grid.Rows.Add($d.Name,$d.Original,$d.Value,$d.Hint,$d.Note);if($d.Warning){$State.Grid.Rows[$idx].DefaultCellStyle.BackColor=[Drawing.Color]::LemonChiffon}}
            Set-AppBatchReview $State $true;$State.Status.Text='Bitte Werte und Umrechnungen prüfen. Gespeichert wird erst mit dem rechten Button.'
        }else{
            $receipt=Save-DailyItems -DateString $State.Date.Value.ToString('yyyy-MM-dd') -Items @($State.Prepared) -ValidateItem $State.ValidateItem -GetIdentity $State.GetIdentity
            # Commit ist abgeschlossen. Keine fachlichen/UI-Callbacks nach dem Commit hier ausfuehren.
            $State.Result=[pscustomobject]@{Date=$receipt.Date;AddedCount=$receipt.AddedCount;Items=@($State.Prepared)}
            $State.Dirty=$false;$State.AllowClose=$true;$State.Form.DialogResult='OK'
            $State.Form.Close()
        }
    }catch{$State.Status.Text='Nicht gespeichert: '+$_.Exception.Message}
    finally{$State.Busy=$false;if(-not $State.Form.IsDisposed){$State.Primary.Enabled=$true}}
}

function New-AppBatchEntryDialog {
    param([Parameter(Mandatory)][object[]]$Definitions,[Parameter(Mandatory)][scriptblock]$PrepareItem,
          [Parameter(Mandatory)][scriptblock]$ValidateItem,[Parameter(Mandatory)][scriptblock]$GetIdentity,
          $Context=$null,[datetime]$Date=(Get-Date),[string]$Title='Mehrere Werte erfassen')
    $defs=@();$keys=@{};$names=@{}
    foreach($d in $Definitions){
        if([string]::IsNullOrWhiteSpace($d.Key) -or [string]::IsNullOrWhiteSpace($d.Name) -or $keys.ContainsKey($d.Key) -or $names.ContainsKey($d.Name) -or $d.Kind -notin @('Number','Text','Choice')){throw 'Ungültige oder doppelte Eingabedefinition.'}
        if($d.Kind -eq 'Choice' -and @($d.Choices).Count -eq 0){throw 'Auswahldefinition benötigt Werte.'}
        $keys[$d.Key]=$true;$names[$d.Name]=$true;$defs+=$d
    }
    if($defs.Count -eq 0){throw 'Eingabekatalog ist leer.'}
    $f=New-Object Windows.Forms.Form;$f.Text=$Title;$f.ClientSize=New-Object Drawing.Size(920,540);$f.MinimumSize=New-Object Drawing.Size(830,420);$f.StartPosition='CenterParent';$f.MinimizeBox=$false
    $font=New-Object Drawing.Font('Segoe UI',9);$f.Font=$font
    $label=New-Object Windows.Forms.Label;$label.Text='Gemeinsames Datum:';$label.SetBounds(16,18,150,24)
    $picker=New-Object Windows.Forms.DateTimePicker;$picker.Format='Short';$picker.SetBounds(170,15,140,26);$picker.Value=$Date
    $add=New-Object Windows.Forms.Button;$add.Text='+ Weitere Zeile';$add.SetBounds(16,54,160,29)
    $headers=New-Object Windows.Forms.Panel;$headers.SetBounds(16,90,888,22);$headers.Anchor='Top,Left,Right'
    foreach($column in @(@('Eintrag',3,250),@('Wert / Auswahl',263,120),@('Einheit',393,100),@('Notiz',503,100))){
        $heading=New-Object Windows.Forms.Label;$heading.Text=$column[0];$heading.SetBounds($column[1],0,$column[2],22);$headers.Controls.Add($heading)
    }
    $flow=New-Object Windows.Forms.FlowLayoutPanel;$flow.SetBounds(16,114,888,310);$flow.Anchor='Top,Bottom,Left,Right';$flow.AutoScroll=$true;$flow.FlowDirection='TopDown';$flow.WrapContents=$false
    $grid=New-Object Windows.Forms.DataGridView;$grid.SetBounds(16,114,888,310);$grid.Anchor=$flow.Anchor;$grid.ReadOnly=$true;$grid.AllowUserToAddRows=$false;$grid.AllowUserToDeleteRows=$false;$grid.RowHeadersVisible=$false;$grid.AutoSizeColumnsMode='Fill';$grid.BackgroundColor=[Drawing.SystemColors]::Window;$grid.DefaultCellStyle.WrapMode='True';$grid.AutoSizeRowsMode='AllCells'
    foreach($col in @('Eintrag','Eingabe','Gespeicherter Wert','Hinweis','Notiz')){[void]$grid.Columns.Add($col,$col);$grid.Columns[$col].SortMode='NotSortable'}
    $status=New-Object Windows.Forms.Label;$status.SetBounds(16,435,888,45);$status.Anchor='Bottom,Left,Right'
    $cancel=New-Object Windows.Forms.Button;$cancel.Text='Abbrechen';$cancel.SetBounds(16,494,115,30);$cancel.Anchor='Bottom,Left'
    $back=New-Object Windows.Forms.Button;$back.Text='Zurück zur Eingabe';$back.SetBounds(510,494,160,30);$back.Anchor='Bottom,Right'
    $primary=New-Object Windows.Forms.Button;$primary.SetBounds(680,494,224,30);$primary.Anchor='Bottom,Right'
    $f.Controls.AddRange([Windows.Forms.Control[]]@($label,$picker,$add,$headers,$flow,$grid,$status,$cancel,$back,$primary))
    $picker.TabIndex=0;$flow.TabIndex=1;$grid.TabIndex=1;$add.TabIndex=2;$back.TabIndex=3;$primary.TabIndex=4;$cancel.TabIndex=5
    $s=@{Form=$f;Date=$picker;Headers=$headers;Flow=$flow;Grid=$grid;Add=$add;Back=$back;Primary=$primary;Status=$status;Rows=(New-Object Collections.ArrayList);Definitions=$defs;PrepareItem=$PrepareItem;ValidateItem=$ValidateItem;GetIdentity=$GetIdentity;Context=$Context;Font=$font;Dirty=$false;Busy=$false;Reviewing=$false;Resizing=$false;AllowClose=$false;Prepared=@();Result=$null}
    $f.Tag=@{Batch=$s};foreach($c in @($picker,$flow,$add,$back,$primary,$cancel)){$c.Tag=@{Batch=$s}}
    $picker.Add_ValueChanged({$args[0].Tag.Batch.Dirty=$true})
    $flow.Add_SizeChanged({Resize-AppBatchRows $args[0].Tag.Batch})
    $add.Add_Click({Add-AppBatchRow $args[0].Tag.Batch})
    $back.Add_Click({Set-AppBatchReview $args[0].Tag.Batch $false})
    $primary.Add_Click({Invoke-AppBatchPrimary $args[0].Tag.Batch})
    $cancel.Add_Click({$args[0].Tag.Batch.Form.Close()});$f.CancelButton=$cancel
    $f.Add_FormClosing({$s=$args[0].Tag.Batch;if($s.AllowClose){return};if($s.Busy){$args[1].Cancel=$true;return};if($s.Dirty){$answer=[Windows.Forms.MessageBox]::Show($args[0],'Ungespeicherte Eingaben verwerfen?','Formular schließen','YesNo','Question','Button2');$args[1].Cancel=($answer -ne 'Yes')}})
    $f.Add_Disposed({$s=$args[0].Tag.Batch;$s.Font.Dispose();$s.Context=$null;$s.PrepareItem=$null;$s.ValidateItem=$null;$s.GetIdentity=$null})
    Set-AppBatchReview $s $false;Add-AppBatchRow $s;$s.Dirty=$false
    return $s
}

function Show-AppBatchEntryDialog {
    param([Parameter(Mandatory)][object[]]$Definitions,[Parameter(Mandatory)][scriptblock]$PrepareItem,
          [Parameter(Mandatory)][scriptblock]$ValidateItem,[Parameter(Mandatory)][scriptblock]$GetIdentity,
          $Context=$null,[datetime]$Date=(Get-Date),[string]$Title='Mehrere Werte erfassen',[Windows.Forms.IWin32Window]$Owner)
    $state=New-AppBatchEntryDialog -Definitions $Definitions -PrepareItem $PrepareItem -ValidateItem $ValidateItem -GetIdentity $GetIdentity -Context $Context -Date $Date -Title $Title
    try{if($null -ne $Owner){[void]$state.Form.ShowDialog($Owner)}else{[void]$state.Form.ShowDialog()};return $state.Result}finally{$state.Form.Dispose()}
}


# --- 5o. Dashboard, eigene Ansichten und stabile Signaturen (v3.14.0) ---
<#
EINBAUVERTRAG (keine medizinische Bewertung in diesem Modul):
- Abhaengigkeiten: 0, 2c/2m (JSON), 3a/3b (Config), 5m (Control-Zustand), WinForms/Drawing.
- Config ist die Konfigurationswurzel, nicht data.Config. DashboardViews speichert
  {Id GUID; Name; Keys string[]}. Keys sind stabile, von der App definierte Kennungen.
  Unbekannte Keys bleiben erhalten; ungueltige Listen werfen, ohne Teilresultate.
- Provider haben genau EINEN Rueckgabewert; kein Debug-Text auf der Erfolgspipeline.
  ModelProvider param($Context) -> {Title;Info;Tiles;Views}.
  Tiles: {Key;Title;ValueText;Unit;Status;Level;Trend}; Level None/Good/Warning/Critical.
  Views: {Id;Name;Keys;EmptyText;LinkText}; erste Ansicht Id='standard', Name='Standard'.
  Weitere feste/dynamische Ansichten liefert die App; fehlende Auswahl -> standard.
  Beispiel dynamisch: nur bei Treffern liefern, Schwere/Alter bereits im Provider filtern.
  Keine Schwellen, Risiko-Scores oder Marker-Gruppen implizit kopieren.
- SignatureProvider param($Context) -> nichtleerer String ueber ALLE Modell-Eingaben.
  Get-AppDataSignature eignet sich fuer Messwerte, Config, Formeln, Personendaten.
  Tagesdatum und DashboardViews kommen automatisch hinzu. Kein Provider: immer rechnen.
- OnTileActivated param($Key,$Context), OnEmptyLink param($ViewId,$Context).
  Optional RenderStandard param($Panel,$Model,$Context) baut die bisherige Standard-
  ansicht auf (kein Rueckgabewert). Ohne Renderer gilt das generische Kachelraster.
- Initialize liefert State, Update-AppDashboard -State $state [-Force] nach Aenderungen
  oder Reiterwechsel aufrufen. Fehler: vorherige Anzeige bleibt, Cache wird NICHT bestaetigt.
  Anzeige meldet Fehler ohne Rohdaten/IDs; der aufrufende Code erhaelt die Exception.
- Eigene Ansichten: Dialog liefert nur Definition. Commit speichert zuerst, ersetzt erst
  danach Config.DashboardViews. Alternativer PersistConfig param($Candidate,$Context)
  MUSS bei Fehler werfen und darf nichts ausgeben. Kein paralleler Config-Schreiber;
  atomarer Dateiaustausch allein ist kein Schutz vor Lost Updates mehrerer Instanzen.
- Listenfunktionen liefern Pipeline-Eintraege; Aufrufer @(). Ausnahme Get-AppField:
  Feldwert bleibt unveraendert (Komma-Return), nicht mit zusaetzlichem @() verschachteln.
- Keine automatische Einbindung ins Beispiel-Hauptformular: fachlichen Adapter schreiben.
#>
function Get-AppField {
    param($Object,[string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [Collections.IDictionary]) { return ,($Object[$Name]) }
    $property=$Object.PSObject.Properties[$Name]
    if ($null -ne $property) { return ,($property.Value) }
}

function ConvertTo-AppCanonicalText {
    # Intern: Aufrufer Get-AppDataSignature prueft Tiefe/Zyklen/Typen zuerst.
    # JSON-Strings sind escaped; Schluessel ordinal sortiert, Listenreihenfolge bleibt.
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [Collections.IDictionary] -or $Value -is [Management.Automation.PSCustomObject]) {
        if ($Value -is [Collections.IDictionary]) { [string[]]$keys=@($Value.psbase.Keys) }
        else { [string[]]$keys=@($Value.PSObject.Properties.Name) }
        [Array]::Sort($keys,[StringComparer]::Ordinal)
        $parts=New-Object 'Collections.Generic.List[string]'
        foreach ($key in $keys) {
            $encoded=ConvertTo-Json -InputObject $key -Compress
            $parts.Add($encoded+':'+(ConvertTo-AppCanonicalText (Get-AppField $Value $key)))
        }
        return '{'+($parts -join ',')+'}'
    }
    if ($Value -is [Collections.IList]) {
        $parts=New-Object 'Collections.Generic.List[string]'
        foreach ($element in $Value) { $parts.Add((ConvertTo-AppCanonicalText $element)) }
        return '['+($parts -join ',')+']'
    }
    return (ConvertTo-Json -InputObject $Value -Compress)
}

function Get-AppDataSignature {
    param($Value)
    $null=ConvertTo-CheckedAppJson -InputObject $Value
    $text=ConvertTo-AppCanonicalText $Value
    $hash=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))).Replace('-','') }
    finally { $hash.Dispose() }
}

function ConvertTo-AppDashboardViews {
    param($Views,[string[]]$ReservedNames=@('Standard'))
    if ($null -eq $Views) { return }
    if ($Views -isnot [Collections.IList]) { throw 'DashboardViews muss eine Liste sein.' }
    $result=New-Object Collections.ArrayList; $ids=@{}; $names=@{}
    foreach ($view in $Views) {
        if ($view -is [Collections.IDictionary]) { $fields=@($view.psbase.Keys) }
        elseif ($view -is [Management.Automation.PSCustomObject]) { $fields=@($view.PSObject.Properties.Name) }
        else { throw 'Ungueltige Ansichtsdefinition.' }
        if ($fields.Count -ne 3 -or @($fields|Where-Object {$_ -notin @('Id','Name','Keys')}).Count) { throw 'Ansichten benoetigen genau Id, Name und Keys.' }
        $id=[guid]::Empty
        if ($view.Id -isnot [string] -or -not [guid]::TryParseExact($view.Id,'D',[ref]$id) -or $id -eq [guid]::Empty) { throw 'Ungueltige Ansichtskennung.' }
        if ($view.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($view.Name)) { throw 'Ansichtsname fehlt.' }
        $name=$view.Name.Trim(); $key=$id.ToString('D')
        if ($ids.ContainsKey($key) -or $names.ContainsKey($name) -or $ReservedNames -contains $name) { throw 'Ansichtskennung oder Name ist bereits vergeben/reserviert.' }
        if ($view.Keys -isnot [Collections.IList]) { throw 'Keys muss eine Liste sein.' }
        $seen=@{}; $keys=New-Object Collections.ArrayList
        foreach ($item in $view.Keys) {
            if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item) -or $item -cne $item.Trim()) { throw 'Ungueltiger Eintragsschluessel.' }
            if ($seen.ContainsKey($item)) { throw 'Ein Eintrag ist mehrfach ausgewaehlt.' }
            $seen[$item]=$true; [void]$keys.Add($item)
        }
        $ids[$key]=$true; $names[$name]=$true
        [void]$result.Add([pscustomobject]@{Id=$key;Name=$name;Keys=@($keys.ToArray())})
    }
    return $result.ToArray()
}

function Save-AppDashboardViews {
    param([Parameter(Mandatory)][Collections.IDictionary]$Config,$Views,
          [string[]]$ReservedNames=@('Standard'),[scriptblock]$PersistConfig,$Context)
    $normalized=@(ConvertTo-AppDashboardViews -Views $Views -ReservedNames $ReservedNames)
    $candidate=ConvertTo-Hashtable ((ConvertTo-CheckedAppJson -InputObject $Config)|ConvertFrom-Json)
    $candidate.DashboardViews=$normalized
    if ($PersistConfig) { $null=& $PersistConfig $candidate $Context }
    else { Save-UserData -data $candidate -ThrowOnError }
    $Config['DashboardViews']=$normalized
}

function ConvertTo-AppDashboardModel {
    param($Model)
    # Detached validated snapshot: later provider mutations cannot change cached controls.
    $copy=ConvertTo-Hashtable ((ConvertTo-CheckedAppJson -InputObject $Model)|ConvertFrom-Json)
    if ($copy -isnot [Collections.IDictionary]) { throw 'Dashboard-Modell fehlt.' }
    if ($copy.Tiles -isnot [Collections.IList] -or $copy.Views -isnot [Collections.IList]) { throw 'Tiles und Views muessen Listen sein.' }
    $keys=@{}; $ids=@{}; $names=@{}
    foreach ($tile in $copy.Tiles) {
        if ($tile.Key -isnot [string] -or [string]::IsNullOrWhiteSpace($tile.Key) -or $tile.Key -cne $tile.Key.Trim() -or $keys.ContainsKey($tile.Key)) { throw 'Ungueltiger/doppelter Kachelschluessel.' }
        if ($tile.Title -isnot [string] -or [string]::IsNullOrWhiteSpace($tile.Title)) { throw 'Kacheltitel fehlt.' }
        if ($tile.Level -notin @('None','Good','Warning','Critical')) { throw 'Unbekannte Kachelstufe.' }
        $keys[$tile.Key]=$true
    }
    foreach ($view in $copy.Views) {
        if ($view.Id -isnot [string] -or $view.Id -cnotmatch '^[a-z][a-z0-9-]*$' -or $ids.ContainsKey($view.Id)) { throw 'Ungueltige/doppelte eingebaute Ansichtskennung.' }
        if ($view.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($view.Name) -or $names.ContainsKey($view.Name)) { throw 'Ungueltiger/doppelter Ansichtsname.' }
        if ($view.Keys -isnot [Collections.IList]) { throw 'Ansichtsschluessel muessen eine Liste sein.' }
        $seen=@{}
        foreach ($key in $view.Keys) {
            if ($key -isnot [string] -or -not $keys.ContainsKey($key) -or $seen.ContainsKey($key)) { throw 'Eingebaute Ansicht enthaelt unbekannte/doppelte Schluessel.' }
            $seen[$key]=$true
        }
        $ids[$view.Id]=$true; $names[$view.Name]=$true
    }
    if ($copy.Views.Count -lt 1 -or $copy.Views[0].Id -cne 'standard' -or $copy.Views[0].Name -cne 'Standard') { throw 'Erste Ansicht muss standard / Standard sein.' }
    return $copy
}

function Get-AppDashboardViews {
    param($Model,$CustomViews)
    $builtins=@($Model.Views)
    $custom=@(ConvertTo-AppDashboardViews -Views $CustomViews -ReservedNames @($builtins|ForEach-Object {$_.Name}))
    foreach ($view in $builtins) { [pscustomobject]@{Id=$view.Id;Name=$view.Name;Keys=@($view.Keys);Custom=$false;EmptyText=$view.EmptyText;LinkText=$view.LinkText} }
    foreach ($view in $custom) { [pscustomobject]@{Id=$view.Id;Name=$view.Name;Keys=@($view.Keys);Custom=$true;EmptyText='Diese Ansicht enthält noch keine Einträge.';LinkText=''} }
}

function New-AppDashboardContent {
    param($State,$Model,$View)
    $panel=New-Object Windows.Forms.Panel; $panel.Dock='Fill'; $panel.AutoScroll=$true; $panel.BackColor=[Drawing.Color]::White
    try {
        if ($View.Id -eq 'standard' -and $State.RenderStandard) { $null=& $State.RenderStandard $panel $Model $State.Context; return $panel }
        $tiles=@{}; foreach ($tile in $Model.Tiles) { $tiles[$tile.Key]=$tile }
        $index=0; $columns=$script:DashboardColumns; $width=$script:DashboardTileWidth; $height=$script:DashboardTileHeight
        foreach ($key in $View.Keys) {
            $tile=$tiles[$key]; $button=New-Object Windows.Forms.Button
            $button.SetBounds((12+($index % $columns)*($width+12)),(12+[math]::Floor($index/$columns)*($height+12)),$width,$height)
            $button.TextAlign='MiddleLeft'; $button.Padding=New-Object Windows.Forms.Padding(10); $button.FlatStyle='Flat'; $button.UseVisualStyleBackColor=$false
            $button.FlatAppearance.BorderSize=1; $button.BackColor=[Drawing.Color]::WhiteSmoke
            if ($null -eq $tile) { $button.Text='Nicht mehr verfügbar'; $button.Enabled=$false; $button.AccessibleName='Nicht mehr verfügbarer Eintrag' }
            else {
                $button.Text=('{0}{5}{1} {2}{5}{3}{5}{4}' -f $tile.Title,$tile.ValueText,$tile.Unit,$tile.Status,$tile.Trend,[Environment]::NewLine)
                $button.FlatAppearance.BorderColor=[Drawing.ColorTranslator]::FromHtml($script:DashboardLevelColors[$tile.Level])
                $button.AccessibleName=$button.Text; $button.Tag=@{Key=$key;State=$State}
                $button.Add_Click({$s=$args[0].Tag.State; if($s.OnTileActivated){try{$null=& $s.OnTileActivated $args[0].Tag.Key $s.Context}catch{$s.Info.Text='Eintrag konnte nicht geöffnet werden.'}}})
            }
            $panel.Controls.Add($button); $index++
        }
        if ($index -eq 0) {
            $label=New-Object Windows.Forms.Label; $label.AutoSize=$true; $label.Location=New-Object Drawing.Point(16,18)
            $label.Text='Keine Einträge verfügbar.'; if ($View.EmptyText) { $label.Text=$View.EmptyText }; $panel.Controls.Add($label)
            if ($View.LinkText -and $State.OnEmptyLink) {
                $link=New-Object Windows.Forms.LinkLabel; $link.AutoSize=$true; $link.Text=$View.LinkText; $link.Location=New-Object Drawing.Point(16,52); $link.Tag=@{Id=$View.Id;State=$State}
                $link.Add_LinkClicked({$s=$args[0].Tag.State;try{$null=& $s.OnEmptyLink $args[0].Tag.Id $s.Context}catch{$s.Info.Text='Ziel konnte nicht geöffnet werden.'}}); $panel.Controls.Add($link)
            }
        }
        return $panel
    } catch { $panel.Dispose(); throw }
}

function Set-AppDashboardView {
    param($State,[string]$Id='standard')
    $view=@($State.Views|Where-Object {$_.Id -eq $Id})
    if ($view.Count -ne 1) { $view=@($State.Views|Where-Object {$_.Id -eq 'standard'}) }
    if ($view.Count -ne 1) { return }
    $content=New-AppDashboardContent $State $State.Model $view[0]
    $old=$State.Content; $State.Host.Controls.Add($content); $State.Content=$content
    if ($old) { $State.Host.Controls.Remove($old); $old.Dispose() }
    $State.SelectedId=$view[0].Id; $State.Edit.Enabled=$view[0].Custom; $State.Delete.Enabled=$view[0].Custom
    $State.Busy=$true
    try { $State.Selector.SelectedItem=$view[0] } finally { $State.Busy=$false }
}

function Update-AppDashboard {
    param($State,[switch]$Force,[datetime]$Today=(Get-Date).Date)
    if ($State.Busy -or $State.Root.IsDisposed) { return }
    $State.Busy=$true
    try {
        $signature=$null
        if ($State.SignatureProvider) {
            $tokens=@(& $State.SignatureProvider $State.Context)
            if ($tokens.Count -ne 1 -or $tokens[0] -isnot [string] -or [string]::IsNullOrWhiteSpace($tokens[0])) { throw 'Signatur-Provider muss genau einen nichtleeren String liefern.' }
            $signature=Get-AppDataSignature @{Source=$tokens[0];Views=$State.Config.DashboardViews;Date=$Today.ToString('yyyy-MM-dd')}
            if (-not $Force -and $State.Model -and $signature -ceq $State.Signature) { return }
        }
        $provided=@(& $State.ModelProvider $State.Context)
        if ($provided.Count -ne 1) { throw 'Modell-Provider muss genau ein Modell liefern.' }
        $model=ConvertTo-AppDashboardModel $provided[0]
        $views=@(Get-AppDashboardViews $model $State.Config.DashboardViews)
        $view=@($views|Where-Object {$_.Id -eq $State.SelectedId}); if ($view.Count -ne 1) { $view=@($views[0]) }
        # Erst den kompletten neuen Inhalt erstellen, dann sichtbaren Zustand tauschen.
        $content=New-AppDashboardContent $State $model $view[0]
        $old=$State.Content; $State.Host.Controls.Add($content); $State.Content=$content
        if ($old) { $State.Host.Controls.Remove($old); $old.Dispose() }
        $State.Model=$model; $State.Views=$views; $State.SelectedId=$view[0].Id
        $State.Selector.Items.Clear(); foreach ($item in $views) { [void]$State.Selector.Items.Add($item) }; $State.Selector.SelectedItem=$view[0]
        $State.Title.Text=[string]$model.Title; $State.Info.Text=[string]$model.Info
        $State.Edit.Enabled=$view[0].Custom; $State.Delete.Enabled=$view[0].Custom
        $State.Signature=$signature; $State.LastError=$null
    } catch { $State.LastError=$_.Exception; $State.Info.Text='Aktualisierung fehlgeschlagen. Vorherige Anzeige bleibt erhalten.'; throw }
    finally { $State.Busy=$false }
}

function Initialize-AppDashboard {
    param([Parameter(Mandatory)][Windows.Forms.Control]$Container,
          [Parameter(Mandatory)][Collections.IDictionary]$Config,
          [Parameter(Mandatory)][scriptblock]$ModelProvider,[scriptblock]$SignatureProvider,
          [scriptblock]$OnTileActivated,[scriptblock]$OnEmptyLink,[scriptblock]$RenderStandard,
          [scriptblock]$PersistConfig,$Context)
    $ownerState=Get-AppControlState $Container
    if ($ownerState.ContainsKey('Dashboard')) { throw 'Dashboard wurde bereits initialisiert.' }
    if ($script:DashboardColumns -lt 1 -or $script:DashboardColumns -gt 12 -or $script:DashboardTileWidth -lt 140 -or $script:DashboardTileHeight -lt 90) { throw 'Ungueltige Dashboard-Abmessungen in USER-KONFIGURATION.' }
    foreach ($level in @('None','Good','Warning','Critical')) { $null=[Drawing.ColorTranslator]::FromHtml($script:DashboardLevelColors[$level]) }
    $null=@(ConvertTo-AppDashboardViews $Config.DashboardViews)
    $root=New-Object Windows.Forms.TableLayoutPanel; $root.Dock='Fill'; $root.ColumnCount=1; [void]$root.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100))); $root.RowCount=4
    foreach ($h in @(40,56,32)) { [void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,$h))) }
    [void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))
    $title=New-Object Windows.Forms.Label; $title.Dock='Fill'; $title.TextAlign='MiddleLeft'; $title.Padding=New-Object Windows.Forms.Padding(12,0,0,0)
    $bar=New-Object Windows.Forms.FlowLayoutPanel; $bar.Dock='Fill'; $bar.AutoScroll=$true; $bar.WrapContents=$false
    $label=New-Object Windows.Forms.Label; $label.Text='Ansicht:'; $label.AutoSize=$true; $label.Margin=New-Object Windows.Forms.Padding(12,10,4,0)
    $selector=New-Object Windows.Forms.ComboBox; $selector.DropDownStyle='DropDownList'; $selector.Width=230; $selector.DisplayMember='Name'
    $add=New-Object Windows.Forms.Button; $add.Text='+ Eigene Ansicht …'; $add.Width=152; $add.Height=28
    $edit=New-Object Windows.Forms.Button; $edit.Text='Bearbeiten …'; $edit.Width=108; $edit.Height=28
    $delete=New-Object Windows.Forms.Button; $delete.Text='Löschen'; $delete.Width=88; $delete.Height=28
    $bar.Controls.AddRange([Windows.Forms.Control[]]@($label,$selector,$add,$edit,$delete))
    $info=New-Object Windows.Forms.Label; $info.Dock='Fill'; $info.AutoEllipsis=$true; $info.Padding=New-Object Windows.Forms.Padding(12,3,0,0)
    $hostPanel=New-Object Windows.Forms.Panel; $hostPanel.Dock='Fill'
    $root.Controls.Add($title,0,0); $root.Controls.Add($bar,0,1); $root.Controls.Add($info,0,2); $root.Controls.Add($hostPanel,0,3)
    $state=@{Root=$root;Host=$hostPanel;Title=$title;Info=$info;Selector=$selector;Edit=$edit;Delete=$delete;Config=$Config;Context=$Context;
        ModelProvider=$ModelProvider;SignatureProvider=$SignatureProvider;OnTileActivated=$OnTileActivated;OnEmptyLink=$OnEmptyLink;RenderStandard=$RenderStandard;
        PersistConfig=$PersistConfig;Model=$null;Signature=$null;Content=$null;SelectedId='standard';Views=@();Busy=$false;LastError=$null}
    foreach ($control in @($selector,$add,$edit,$delete)) { $control.Tag=$state }
    $selector.Add_SelectedIndexChanged({$s=$args[0].Tag;if(-not $s.Busy -and $args[0].SelectedItem){try{Set-AppDashboardView $s $args[0].SelectedItem.Id}catch{$s.Info.Text='Ansicht konnte nicht angezeigt werden.'}}})
    $add.Add_Click({Invoke-AppDashboardViewAction $args[0].Tag 'Add'})
    $edit.Add_Click({Invoke-AppDashboardViewAction $args[0].Tag 'Edit'})
    $delete.Add_Click({Invoke-AppDashboardViewAction $args[0].Tag 'Delete'})
    try { Update-AppDashboard $state -Force; $Container.Controls.Add($root); $ownerState.Dashboard=$state; return $state }
    catch { $root.Dispose(); throw }
}

function Add-AppDashboardEditorRow {
    param($State,[string]$Key='')
    $row=New-Object Windows.Forms.Panel; $row.Width=510; $row.Height=36
    $combo=New-Object Windows.Forms.ComboBox; $combo.SetBounds(0,3,458,28); $combo.DropDownStyle='DropDown'; $combo.AutoCompleteMode='SuggestAppend'; $combo.AutoCompleteSource='ListItems'; $combo.DisplayMember='Name'
    foreach ($item in $State.Catalog) { [void]$combo.Items.Add($item) }
    $matches=@($State.Catalog|Where-Object {$_.Key -eq $Key}); if ($matches.Count -eq 1) { $combo.SelectedItem=$matches[0] }
    $remove=New-Object Windows.Forms.Button; $remove.Text='×'; $remove.SetBounds(468,2,32,28); $remove.Tag=@{State=$State;Row=$row}
    $remove.Add_Click({$s=$args[0].Tag.State;$r=$args[0].Tag.Row;$s.Flow.Controls.Remove($r);[void]$s.Rows.Remove($r);$r.Dispose()})
    $row.Tag=$combo; $row.Controls.AddRange([Windows.Forms.Control[]]@($combo,$remove)); [void]$State.Rows.Add($row); $State.Flow.Controls.Add($row)
}

function Complete-AppDashboardViewEditor {
    param($State)
    $keys=@()
    foreach ($row in $State.Rows) {
        $combo=$row.Tag; $matches=@($State.Catalog|Where-Object {$_.Name -ieq $combo.Text.Trim()})
        if ($matches.Count -ne 1) { throw 'Bitte in jeder Zeile einen gültigen Eintrag wählen oder die Zeile entfernen.' }
        $keys+=$matches[0].Key
    }
    $candidate=[pscustomobject]@{Id=$State.Id;Name=$State.NameBox.Text;Keys=@($keys)}
    $others=@($State.Existing|Where-Object {$_.Id -ne $State.Id})
    $checked=@(ConvertTo-AppDashboardViews -Views @($others+$candidate) -ReservedNames $State.ReservedNames)
    $State.Result=@($checked|Where-Object {$_.Id -eq $State.Id})[0]
}

function New-AppDashboardViewEditor {
    param($Catalog,$ExistingViews,$View=$null,[string[]]$ReservedNames=@('Standard'))
    $existing=@(ConvertTo-AppDashboardViews $ExistingViews -ReservedNames $ReservedNames)
    $items=@(); $names=@{}; $keys=@{}
    foreach ($item in @($Catalog)) {
        if ($item.Key -isnot [string] -or [string]::IsNullOrWhiteSpace($item.Key) -or $item.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($item.Name) -or $names.ContainsKey($item.Name) -or $keys.ContainsKey($item.Key)) { throw 'Katalog benötigt eindeutige Schlüssel und Anzeigenamen.' }
        $items+=[pscustomobject]@{Key=$item.Key;Name=$item.Name}; $names[$item.Name]=$true; $keys[$item.Key]=$true
    }
    if ($View) {
        $View=@(ConvertTo-AppDashboardViews -Views @($View) -ReservedNames $ReservedNames)[0]
        $unknown=0
        foreach ($key in $View.Keys) {
            if (-not $keys.ContainsKey($key)) {
                do { $unknown++; $name='Nicht mehr verfügbar ('+$unknown+')' } while ($names.ContainsKey($name))
                $items+=[pscustomobject]@{Key=$key;Name=$name}; $names[$name]=$true; $keys[$key]=$true
            }
        }
    }
    $form=New-Object Windows.Forms.Form; $form.Text='Eigene Ansicht erstellen'; $form.ClientSize=New-Object Drawing.Size(580,430); $form.MinimumSize=$form.Size; $form.StartPosition='CenterParent'; $form.ShowInTaskbar=$false
    $nameLabel=New-Object Windows.Forms.Label; $nameLabel.Text='Name:'; $nameLabel.SetBounds(16,20,56,24)
    $nameBox=New-Object Windows.Forms.TextBox; $nameBox.SetBounds(76,16,480,26); $nameBox.Anchor='Top,Left,Right'
    $add=New-Object Windows.Forms.Button; $add.Text='+ Eintrag hinzufügen'; $add.SetBounds(16,55,172,30)
    $flow=New-Object Windows.Forms.FlowLayoutPanel; $flow.SetBounds(16,95,548,278); $flow.Anchor='Top,Bottom,Left,Right'; $flow.AutoScroll=$true; $flow.WrapContents=$false; $flow.FlowDirection='TopDown'
    $ok=New-Object Windows.Forms.Button; $ok.Text='Übernehmen'; $ok.SetBounds(334,389,110,28); $ok.Anchor='Bottom,Right'
    $cancel=New-Object Windows.Forms.Button; $cancel.Text='Abbrechen'; $cancel.SetBounds(454,389,110,28); $cancel.Anchor='Bottom,Right'; $cancel.DialogResult='Cancel'; $form.CancelButton=$cancel
    $state=@{Form=$form;NameBox=$nameBox;Flow=$flow;Rows=(New-Object Collections.ArrayList);Catalog=$items;Existing=$existing;ReservedNames=$ReservedNames;Id=([guid]::NewGuid().ToString('D'));Result=$null;Add=$add;Ok=$ok}
    if ($View) { $state.Id=$View.Id; $nameBox.Text=$View.Name; $form.Text='Eigene Ansicht bearbeiten' }
    $add.Tag=$state; $ok.Tag=$state
    $add.Add_Click({Add-AppDashboardEditorRow $args[0].Tag})
    $ok.Add_Click({$s=$args[0].Tag;try{Complete-AppDashboardViewEditor $s;$s.Form.DialogResult='OK';$s.Form.Close()}catch{[Windows.Forms.MessageBox]::Show($s.Form,$_.Exception.Message,'Ansicht prüfen','OK','Warning')|Out-Null}})
    $form.Controls.AddRange([Windows.Forms.Control[]]@($nameLabel,$nameBox,$add,$flow,$ok,$cancel))
    if ($View) { foreach ($key in $View.Keys) { Add-AppDashboardEditorRow $state $key } }
    else { Add-AppDashboardEditorRow $state }
    return $state
}

function Invoke-AppDashboardViewAction {
    param($State,[ValidateSet('Add','Edit','Delete')][string]$Action)
    if ($State.Busy) { return }
    $committed=$false; $editor=$null
    try {
        $views=@(ConvertTo-AppDashboardViews $State.Config.DashboardViews)
        $selected=@($views|Where-Object {$_.Id -eq $State.SelectedId}); $current=$null
        if ($Action -ne 'Add') { if ($selected.Count -ne 1) { return }; $current=$selected[0] }
        $reserved=@($State.Model.Views|ForEach-Object {$_.Name})
        if ($Action -eq 'Delete') {
            if ([Windows.Forms.MessageBox]::Show($State.Root,'Ausgewählte Ansicht löschen?','Eigene Ansicht','YesNo','Question') -ne 'Yes') { return }
            $candidate=@($views|Where-Object {$_.Id -ne $current.Id}); $selectedId='standard'
        } else {
            $catalog=@($State.Model.Tiles|ForEach-Object {[pscustomobject]@{Key=$_.Key;Name=$_.Title}})
            $editor=New-AppDashboardViewEditor $catalog $views $current -ReservedNames $reserved
            if ($editor.Form.ShowDialog($State.Root.FindForm()) -ne 'OK') { return }
            $candidate=@(@($views|Where-Object {$_.Id -ne $editor.Result.Id})+$editor.Result); $selectedId=$editor.Result.Id
        }
        Save-AppDashboardViews -Config $State.Config -Views $candidate -ReservedNames $reserved -PersistConfig $State.PersistConfig -Context $State.Context
        $committed=$true; $State.SelectedId=$selectedId; Update-AppDashboard $State -Force
    } catch {
        if ($committed) { $State.Info.Text='Ansichten gespeichert; Anzeige konnte nicht erneuert werden. Bitte erneut aktualisieren.' }
        else { [Windows.Forms.MessageBox]::Show($State.Root,'Ansicht konnte nicht gespeichert werden. Die bisherigen Ansichten bleiben erhalten.','Eigene Ansicht','OK','Warning')|Out-Null }
    } finally { if ($editor) { $editor.Form.Dispose() } }
}


# --- 5p. Release-Notes: Pruefung, Suche, Gruppierung, Markdown, UI (v3.14.0) ---
<#
EINBAU: 5o Get-AppField/Get-AppDataSignature, 2j, 5m, WinForms.
Datensatz: {Version='x.y.z';Datum='yyyy-MM-dd';Titel='...';Eintraege=@({Typ;Text})}.
Typ: Neu|Bugfix|Anpassung|Sicherheit|Hinweis. Texte in einfachen Anfuehrungszeichen.
AppReleaseNotes ist ein bewusst anzupassendes App-Beispiel, TemplateReleaseNotes die
Bibliothekshistorie ab 3.14.0. NIE AppVersion mit TemplateVersion vergleichen.
Test-AppReleaseNotes vor Auslieferung mit HeaderVersion und PreviousNotes aufrufen:
IsValid muss true sein. Neue Version oben; gleicher Tag erlaubt; alte Eintraege unveraendert.
UI zeigt numerisch sortierte Releases, gruppiert nach Major.Minor; Suche+Typ wirken
gemeinsam. Treffer in Version/Titel -> alle Eintraege des Typs, sonst passende Texte.
Export enthaelt NUR die aktuell sichtbaren Ergebnisse (Dialog nennt diese Grenze).
Initialize liefert State; Update-AppReleaseNotes -State $state [-Notes $neueNotes].
Keine App-spezifischen Versionsregexe, globalen UI-Zustaende oder Dateizugriffe beim Laden.
#>
function ConvertTo-AppReleaseNotes {
    param($Notes)
    $result=New-Object Collections.ArrayList; $seen=@{}
    foreach ($note in @($Notes)) {
        $version=Get-AppField $note 'Version'
        if ($version -isnot [string] -or $version -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') { throw 'Release-Version muss x.y.z sein.' }
        try { $null=[version]$version } catch { throw 'Release-Version liegt außerhalb des unterstützten Bereichs.' }
        if ($seen.ContainsKey($version)) { throw 'Release-Version ist doppelt vorhanden.' }; $seen[$version]=$true
        $date=Get-AppField $note 'Datum'; $parsed=[datetime]::MinValue
        if ($date -isnot [string] -or -not [datetime]::TryParseExact($date,'yyyy-MM-dd',[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$parsed)) { throw 'Release-Datum muss JJJJ-MM-TT sein.' }
        $title=Get-AppField $note 'Titel'
        if ($title -isnot [string] -or [string]::IsNullOrWhiteSpace($title) -or $title -match '\[PLACEHOLDER\]') { throw 'Release-Titel fehlt oder ist ein Platzhalter.' }
        $entries=New-Object Collections.ArrayList
        foreach ($entry in (Get-AppField $note 'Eintraege')) {
            $type=Get-AppField $entry 'Typ'; $text=Get-AppField $entry 'Text'
            if ($type -cnotin @('Neu','Bugfix','Anpassung','Sicherheit','Hinweis')) { throw 'Unbekannter Release-Eintragstyp.' }
            if ($text -isnot [string] -or [string]::IsNullOrWhiteSpace($text) -or $text -match '\[PLACEHOLDER\]') { throw 'Release-Eintrag fehlt oder ist ein Platzhalter.' }
            [void]$entries.Add([pscustomobject]@{Typ=$type;Text=$text})
        }
        if ($entries.Count -eq 0) { throw 'Release benötigt mindestens einen Eintrag.' }
        [void]$result.Add([pscustomobject]@{Version=$version;Datum=$date;Titel=$title;Eintraege=@($entries.ToArray())})
    }
    return $result.ToArray()
}

function Test-AppReleaseNotes {
    param($Notes,[string]$CurrentVersion,[string]$HeaderVersion='',$PreviousNotes=$null,[datetime]$Today=(Get-Date).Date)
    $errors=New-Object Collections.ArrayList; $warnings=New-Object Collections.ArrayList
    try {
        $list=@(ConvertTo-AppReleaseNotes $Notes)
        if ($list.Count -eq 0) { throw 'Release-Notes fehlen.' }
        if ($list[0].Version -cne $CurrentVersion) { [void]$errors.Add('Aktuelle Version und oberster Release-Eintrag stimmen nicht überein.') }
        if ($HeaderVersion -and $HeaderVersion -cne $CurrentVersion) { [void]$errors.Add('Kopfzeile und aktuelle Version stimmen nicht überein.') }
        $last=$null; $byVersion=@{}
        foreach ($note in $list) {
            $v=[version]$note.Version
            if ($null -ne $last -and $v -ge $last) { [void]$errors.Add('Release-Versionen müssen numerisch absteigend stehen.') }; $last=$v
            if ([datetime]::ParseExact($note.Datum,'yyyy-MM-dd',[cultureinfo]::InvariantCulture) -gt $Today.Date) { [void]$warnings.Add('Ein Release-Datum liegt in der Zukunft.') }
            $byVersion[$note.Version]=$note
        }
        if ($null -ne $PreviousNotes) {
            foreach ($old in @(ConvertTo-AppReleaseNotes $PreviousNotes)) {
                if (-not $byVersion.ContainsKey($old.Version)) { [void]$errors.Add('Ein veröffentlichter Release-Eintrag wurde entfernt.'); continue }
                if ((Get-AppDataSignature $old) -cne (Get-AppDataSignature $byVersion[$old.Version])) { [void]$errors.Add('Ein veröffentlichter Release-Eintrag wurde geändert.') }
            }
        }
    } catch { [void]$errors.Add($_.Exception.Message) }
    return [pscustomobject]@{IsValid=($errors.Count -eq 0);Errors=@($errors.ToArray());Warnings=@($warnings.ToArray())}
}

function Get-AppReleaseNotesView {
    param($Notes,[string]$SearchText='',[ValidateSet('Alle','Neu','Bugfix','Anpassung','Sicherheit','Hinweis')][string]$TypeFilter='Alle')
    $search=$SearchText.Trim()
    foreach ($note in @(ConvertTo-AppReleaseNotes $Notes|Sort-Object -Property @{Expression={[version]$_.Version};Descending=$true})) {
        $headerHit=$note.Version.IndexOf($search,[StringComparison]::OrdinalIgnoreCase) -ge 0 -or $note.Titel.IndexOf($search,[StringComparison]::OrdinalIgnoreCase) -ge 0
        $entries=@($note.Eintraege|Where-Object {($TypeFilter -eq 'Alle' -or $_.Typ -eq $TypeFilter) -and ($headerHit -or $_.Text.IndexOf($search,[StringComparison]::OrdinalIgnoreCase) -ge 0)})
        if ($entries.Count -gt 0) { [pscustomobject]@{Version=$note.Version;Datum=$note.Datum;Titel=$note.Titel;Eintraege=$entries} }
    }
}

function ConvertTo-AppReleaseMarkdown {
    param($Notes,[string]$AppName='Anwendung')
    $builder=New-Object Text.StringBuilder
    [void]$builder.AppendLine('# Änderungen – '+$AppName)
    foreach ($note in @(Get-AppReleaseNotesView $Notes)) {
        [void]$builder.AppendLine(''); [void]$builder.AppendLine('## '+$note.Version+' – '+$note.Datum)
        [void]$builder.AppendLine(''); [void]$builder.AppendLine($note.Titel)
        foreach ($type in @('Neu','Bugfix','Anpassung','Sicherheit','Hinweis')) {
            $entries=@($note.Eintraege|Where-Object {$_.Typ -eq $type}); if ($entries.Count -eq 0) { continue }
            [void]$builder.AppendLine(''); [void]$builder.AppendLine('### '+$type)
            foreach ($entry in $entries) { [void]$builder.AppendLine('- '+$entry.Text.Replace("`r`n","`n").Replace("`n","`r`n  ")) }
        }
    }
    return $builder.ToString()
}

function Export-AppReleaseNotes {
    param($Notes,[Parameter(Mandatory)][string]$Path,[string]$AppName='Anwendung')
    $text=ConvertTo-AppReleaseMarkdown -Notes $Notes -AppName $AppName
    Write-AtomicTextFile -Path $Path -Content $text -RequireAtomic:$true
}

function Update-AppReleaseNotes {
    param($State,$Notes=$null)
    $source=$State.Notes; if ($PSBoundParameters.ContainsKey('Notes')) { $source=$Notes }
    $validated=@(ConvertTo-AppReleaseNotes $source)
    $view=@(Get-AppReleaseNotesView -Notes $validated -SearchText $State.Search.Text -TypeFilter ([string]$State.Filter.SelectedItem))
    $selected=$State.CurrentVersion
    if ($State.Tree.SelectedNode -and $State.Tree.SelectedNode.Tag) { $selected=$State.Tree.SelectedNode.Tag.Version }
    $State.Tree.BeginUpdate()
    try {
        $State.Tree.Nodes.Clear(); $groups=@{}; $selection=$null; $first=$null
        foreach ($note in $view) {
            $version=[version]$note.Version; $key='{0}.{1}' -f $version.Major,$version.Minor
            if (-not $groups.ContainsKey($key)) { $groups[$key]=$State.Tree.Nodes.Add('Version '+$key) }
            $text=$note.Version+' – '+$note.Datum+' – '+$note.Titel
            if ($note.Version -ceq $State.CurrentVersion) { $text+=' (aktuell)' }
            $node=$groups[$key].Nodes.Add($text); $node.Tag=$note
            if ($null -eq $first) { $first=$node }; if ($note.Version -ceq $selected) { $selection=$node }
        }
        $State.Notes=$validated; $State.VisibleNotes=$view; $State.Details.Clear()
        if ($null -eq $selection) { $selection=$first }; $State.Tree.ExpandAll(); $State.Tree.SelectedNode=$selection
        $State.Export.Enabled=($view.Count -gt 0); $State.Count.Text=('{0} Version(en)' -f $view.Count)
        if ($view.Count -eq 0) { $State.Details.Text='Keine passenden Release-Notes.' }
    } finally { $State.Tree.EndUpdate() }
}

function Initialize-AppReleaseNotes {
    param([Parameter(Mandatory)][Windows.Forms.Control]$Container,$Notes,
          [Parameter(Mandatory)][string]$CurrentVersion,[string]$AppName='Anwendung')
    $ownerState=Get-AppControlState $Container
    if ($ownerState.ContainsKey('ReleaseNotes')) { throw 'Release-Notes wurden bereits initialisiert.' }
    $check=Test-AppReleaseNotes $Notes -CurrentVersion $CurrentVersion
    if (-not $check.IsValid) { throw ($check.Errors -join ' ') }
    $root=New-Object Windows.Forms.TableLayoutPanel; $root.Dock='Fill'; $root.ColumnCount=1; [void]$root.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100))); $root.RowCount=3
    [void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,38)))
    [void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,56)))
    [void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))
    $header=New-Object Windows.Forms.FlowLayoutPanel; $header.Dock='Fill'; $header.AutoScroll=$true; $header.WrapContents=$false
    $current=New-Object Windows.Forms.Label; $current.Text='aktuelle Version: '+$CurrentVersion; $current.AutoSize=$true; $current.Margin=New-Object Windows.Forms.Padding(12,10,10,0)
    $count=New-Object Windows.Forms.Label; $count.AutoSize=$true; $count.Margin=New-Object Windows.Forms.Padding(12,10,0,0); $header.Controls.AddRange([Windows.Forms.Control[]]@($current,$count))
    $bar=New-Object Windows.Forms.FlowLayoutPanel; $bar.Dock='Fill'; $bar.WrapContents=$false; $bar.AutoScroll=$true
    $searchLabel=New-Object Windows.Forms.Label; $searchLabel.Text='Suche:'; $searchLabel.AutoSize=$true; $searchLabel.Margin=New-Object Windows.Forms.Padding(12,8,0,0)
    $search=New-Object Windows.Forms.TextBox; $search.Width=210; $search.AccessibleName='Release-Notes durchsuchen'
    $filter=New-Object Windows.Forms.ComboBox; $filter.DropDownStyle='DropDownList'; $filter.Width=130; $filter.Items.AddRange([object[]]@('Alle','Neu','Bugfix','Anpassung','Sicherheit','Hinweis')); $filter.SelectedIndex=0; $filter.AccessibleName='Eintragstyp'
    $reset=New-Object Windows.Forms.Button; $reset.Text='Zurücksetzen'; $reset.Width=110; $reset.Height=28
    $export=New-Object Windows.Forms.Button; $export.Text='Treffer exportieren …'; $export.Width=165; $export.Height=28
    $bar.Controls.AddRange([Windows.Forms.Control[]]@($searchLabel,$search,$filter,$reset,$export))
    $split=New-Object Windows.Forms.SplitContainer; $split.Dock='Fill'; $split.Size=New-Object Drawing.Size(780,340); $split.SplitterDistance=320
    $tree=New-Object Windows.Forms.TreeView; $tree.Dock='Fill'; $tree.HideSelection=$false
    $details=New-Object Windows.Forms.TextBox; $details.Dock='Fill'; $details.Multiline=$true; $details.ReadOnly=$true; $details.ScrollBars='Vertical'; $details.BackColor=[Drawing.Color]::White
    $split.Panel1.Controls.Add($tree); $split.Panel2.Controls.Add($details)
    $root.Controls.Add($header,0,0); $root.Controls.Add($bar,0,1); $root.Controls.Add($split,0,2)
    $state=@{Root=$root;Notes=@(ConvertTo-AppReleaseNotes $Notes);VisibleNotes=@();CurrentVersion=$CurrentVersion;AppName=$AppName;Search=$search;Filter=$filter;Tree=$tree;Details=$details;Export=$export;Count=$count;Busy=$false}
    foreach ($control in @($tree,$search,$filter,$reset,$export)) { $control.Tag=$state }
    $tree.Add_AfterSelect({$s=$args[0].Tag;$note=$args[1].Node.Tag;if($note){$s.Details.Text=ConvertTo-AppReleaseMarkdown -Notes @($note) -AppName $s.AppName}else{$s.Details.Clear()}})
    $search.Add_TextChanged({$s=$args[0].Tag;if(-not $s.Busy){Update-AppReleaseNotes $s}})
    $filter.Add_SelectedIndexChanged({$s=$args[0].Tag;if(-not $s.Busy){Update-AppReleaseNotes $s}})
    $reset.Add_Click({$s=$args[0].Tag;$s.Busy=$true;try{$s.Search.Clear();$s.Filter.SelectedIndex=0}finally{$s.Busy=$false};Update-AppReleaseNotes $s})
    $export.Add_Click({
        $s=$args[0].Tag;$dialog=New-Object Windows.Forms.SaveFileDialog
        try{
            $dialog.Title='Sichtbare Release-Notes exportieren';$dialog.Filter='Markdown (*.md)|*.md';$dialog.FileName='CHANGELOG.md';$dialog.OverwritePrompt=$true
            if($dialog.ShowDialog($s.Root.FindForm()) -eq 'OK'){Export-AppReleaseNotes -Notes $s.VisibleNotes -Path $dialog.FileName -AppName $s.AppName}
        }catch{[Windows.Forms.MessageBox]::Show($s.Root,'Export fehlgeschlagen.','Release-Notes','OK','Error')|Out-Null}finally{$dialog.Dispose()}
    })
    try { Update-AppReleaseNotes $state; $Container.Controls.Add($root); $ownerState.ReleaseNotes=$state; return $state }
    catch { $root.Dispose(); throw }
}


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 6: HAUPTFORMULAR (Show-MainForm)                                   ║
# ║  PFLICHT: Enthält das Hauptfenster mit TabControl, GUI-Elementen & Events.   ║
# ║  Alle lokalen Funktionen (Update-*, Refresh-*) werden INNERHALB dieser       ║
# ║  Funktion definiert, damit sie Zugriff auf die GUI-Variablen haben.          ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

function Show-MainForm {

    # --- 6a. Hauptfenster erstellen ---
    $form = New-Object System.Windows.Forms.Form
    $form.Size = New-Object System.Drawing.Size(1200, 850)
    $form.StartPosition = "CenterScreen"
    $form.Text = "$($script:AppName) - Version $($script:AppDisplayVersion)"
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    # --- 6b. TabControl erstellen ---
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(10, 10)
    $tabControl.Size = New-Object System.Drawing.Size(1160, 790)
    $tabControl.Anchor = 'Top, Bottom, Left, Right'
    $form.Controls.Add($tabControl)

    # --- 6c. Tabs anlegen ---
    # Jeder Tab hat einen beschreibenden Text und ein Tag mit Tooltip-Beschreibung.
    $tabPage1 = New-Object System.Windows.Forms.TabPage
    $tabPage1.Text = "Hauptansicht"  # [PLACEHOLDER]
    $tabPage1.Tag = "Beschreibung des Tabs für Tooltip."  # [PLACEHOLDER]
    $tabControl.TabPages.Add($tabPage1)

    # [OPTIONAL] Weitere Tabs:
    # $tabPage2 = New-Object System.Windows.Forms.TabPage; $tabPage2.Text = "Tab 2"; $tabControl.TabPages.Add($tabPage2)

    # [OPTIONAL 5m] Hervorhebung nach Festlegen der Tab-Schrift:
    # Initialize-AppActiveTabIndicator -TabControl $tabControl
    # Kategorien: zweites TabControl in der bisherigen Kopfzeile anlegen, bisheriges
    # TabControl eine Zeile tiefer setzen und dessen Hoehe entsprechend reduzieren.
    # $navigation = Initialize-AppCategoryNavigation -Tabs $tabControl -Categories $categoryTabs -Groups @(@{Name='Uebersicht';Pages=@($tabPage1)},@{Name='Verwaltung';Pages=@($tabPage2)})
    # SELECT: Select-AppNavigationPage -Tabs $tabControl -Page $tabPage2
    # REFRESH: OnChanged param($Page,$Context) statt numerischer SelectedIndex-Logik.
    # Sortieren: Register-AppGridSorting -Grid $dataGrid -Modes @{Wert='Number';Datum='Date'}
    # Mehrfacheingabe: Show-AppBatchEntryDialog (5n); dieselben Fach-Callbacks wie
    # Einzeleingabe einsetzen. Layoutidee: Gruppe 'Werte erfassen' mit Einzeleingabe
    # und zusaetzlichem Button 'Mehrere Werte erfassen ...'. Keine doppelte Fachlogik.

    # [OPTIONAL 5o/5p] Vollstaendige Module, aber bewusste App-Integration erforderlich:
    # $dash = Initialize-AppDashboard -Container $dashboardTab -Config $script:data `
    #     -Context $appContext -ModelProvider {param($ctx) Get-MyDashboardModel $ctx} `
    #     -SignatureProvider {param($ctx) Get-AppDataSignature $ctx.ModelInputs} `
    #     -OnTileActivated {param($key,$ctx) Select-MyAnalysisItem $key $ctx}
    # Die drei My*-Namen sind Adapter-Platzhalter, keine Funktionen dieses Templates.
    # Nach Reiterwechsel/Datenaenderung: Update-AppDashboard -State $dash
    # Release-App: Initialize-AppReleaseNotes -Container $releaseTab `
    #     -Notes $script:AppReleaseNotes -CurrentVersion $script:AppVersion -AppName $script:AppName
    # Release-Bibliothek: explizit TemplateReleaseNotes + TemplateVersion verwenden.
    # Initialisierung/Refresh mit try/catch behandeln; keine echten Daten fuer BETA-QS.

    # --- 6d. GUI-Elemente erstellen ---
    # HINWEIS: Alle GUI-Elemente werden hier erstellt und zu den Tabs hinzugefügt.

    # === MUSTER: Eingabegruppe (GroupBox mit Label + TextBox + Button) ===
    $entryGroup = New-Object System.Windows.Forms.GroupBox
    $entryGroup.Location = New-Object System.Drawing.Point(20, 20)
    $entryGroup.Size = New-Object System.Drawing.Size(420, 180)
    $entryGroup.Text = "Daten eingeben"  # [PLACEHOLDER]
    $tabPage1.Controls.Add($entryGroup)

    $labelDate = New-Object System.Windows.Forms.Label
    $labelDate.Text = "Datum:"; $labelDate.Location = New-Object System.Drawing.Point(10, 30)
    $labelDate.Size = New-Object System.Drawing.Size(100, 20)
    $entryGroup.Controls.Add($labelDate)

    $datePicker = New-Object System.Windows.Forms.DateTimePicker
    $datePicker.Location = New-Object System.Drawing.Point(110, 30)
    $datePicker.Size = New-Object System.Drawing.Size(300, 20)
    $entryGroup.Controls.Add($datePicker)

    # === MUSTER: ComboBox (Dropdown) ===
    $labelCombo = New-Object System.Windows.Forms.Label
    $labelCombo.Text = "Auswahl:"; $labelCombo.Location = New-Object System.Drawing.Point(10, 60)
    $labelCombo.Size = New-Object System.Drawing.Size(100, 20)
    $entryGroup.Controls.Add($labelCombo)

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(110, 60)
    $comboBox.Size = New-Object System.Drawing.Size(300, 20)
    # $comboBox.DropDownStyle = "DropDownList"  # Nur Auswahl, keine freie Eingabe
    $entryGroup.Controls.Add($comboBox)

    # === MUSTER: TextBox (Eingabefeld) ===
    $labelValue = New-Object System.Windows.Forms.Label
    $labelValue.Text = "Wert:"; $labelValue.Location = New-Object System.Drawing.Point(10, 90)
    $labelValue.Size = New-Object System.Drawing.Size(100, 20)
    $entryGroup.Controls.Add($labelValue)

    $valueTextBox = New-Object System.Windows.Forms.TextBox
    $valueTextBox.Location = New-Object System.Drawing.Point(110, 90)
    $valueTextBox.Size = New-Object System.Drawing.Size(100, 20)
    $entryGroup.Controls.Add($valueTextBox)

    # === MUSTER: Mehrzeilige TextBox (Notiz) ===
    $noteTextBox = New-Object System.Windows.Forms.TextBox
    $noteTextBox.Location = New-Object System.Drawing.Point(110, 120)
    $noteTextBox.Size = New-Object System.Drawing.Size(300, 50)
    $noteTextBox.Multiline = $true; $noteTextBox.ScrollBars = "Vertical"
    $entryGroup.Controls.Add($noteTextBox)

    # === MUSTER: Button ===
    $addButton = New-Object System.Windows.Forms.Button
    $addButton.Location = New-Object System.Drawing.Point(110, 140)
    $addButton.Size = New-Object System.Drawing.Size(300, 30)
    $addButton.Text = "Hinzufügen"
    $entryGroup.Controls.Add($addButton)

    # === MUSTER: DataGridView (Tabelle) ===
    $dataGrid = New-Object System.Windows.Forms.DataGridView
    $dataGrid.Location = New-Object System.Drawing.Point(460, 50)
    $dataGrid.Size = New-Object System.Drawing.Size(680, 570)
    $dataGrid.AutoSizeColumnsMode = "Fill"
    $dataGrid.AllowUserToAddRows = $false
    $dataGrid.AllowUserToDeleteRows = $false
    $dataGrid.ReadOnly = $true
    $dataGrid.SelectionMode = "FullRowSelect"
    # Spalten definieren:
    $dataGrid.Columns.Add("Col1", "Spalte 1")  # [PLACEHOLDER]
    $dataGrid.Columns.Add("Col2", "Spalte 2")  # [PLACEHOLDER]
    # Spaltenbreiten (FillWeight):
    $dataGrid.Columns["Col1"].FillWeight = 40
    $dataGrid.Columns["Col2"].FillWeight = 60
    # Styling:
    $dataGrid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $dataGrid.DefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $dataGrid.RowTemplate.Height = 30
    $tabPage1.Controls.Add($dataGrid)

    # === MUSTER: Chart (Diagramm) [OPTIONAL] ===
    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.Location = New-Object System.Drawing.Point(460, 50)
    $chart.Size = New-Object System.Drawing.Size(680, 570)
    $tabPage1.Controls.Add($chart)

    $chartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $chartArea.AxisX.Title = "X-Achse"  # [PLACEHOLDER]
    $chartArea.AxisX.LabelStyle.Format = "dd.MM.yy"  # Für Datumsachsen
    $chartArea.AxisY.Title = "Y-Achse"  # [PLACEHOLDER]
    $chartArea.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
    $chart.ChartAreas.Add($chartArea)
    $chart.Legends.Clear()

    # Linienserie:
    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series
    $series.Name = "Daten"
    $series.XValueType = [System.Windows.Forms.DataVisualization.Charting.ChartValueType]::DateTime
    $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $series.BorderWidth = 3
    $series.MarkerStyle = [System.Windows.Forms.DataVisualization.Charting.MarkerStyle]::Circle
    $series.MarkerSize = 8
    $chart.Series.Add($series)

    # [OPTIONAL] Trendlinie:
    $trendSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series
    $trendSeries.Name = "Trend"
    $trendSeries.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $trendSeries.BorderWidth = 2
    $trendSeries.Color = [System.Drawing.Color]::MediumPurple
    $trendSeries.BorderDashStyle = "Dash"
    $trendSeries.XValueType = [System.Windows.Forms.DataVisualization.Charting.ChartValueType]::DateTime
    # v3.10: Insert(0) statt Add - die Trendlinie liegt UNTER der Messwert-Linie, Messpunkte
    # bleiben per Maus erreichbar. Ein Tooltip-/HitTest-Handler muss die Serie "Trend"
    # ignorieren:  if ($hit.Series -and $hit.Series.Name -ne 'Trend') { ... }
    $chart.Series.Insert(0, $trendSeries)

    # [OPTIONAL] Streudiagramm (Scatter):
    # $scatterSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series
    # $scatterSeries.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Point
    # $scatterSeries.MarkerStyle = "Circle"; $scatterSeries.MarkerSize = 10

    # === MUSTER: TreeView (Baumansicht) [OPTIONAL] ===
    $treeView = New-Object System.Windows.Forms.TreeView
    $treeView.Location = New-Object System.Drawing.Point(10, 50)
    $treeView.Size = New-Object System.Drawing.Size(300, 660)
    # $tabPageX.Controls.Add($treeView)

    # === MUSTER: ToolTip ===
    $toolTip = New-Object System.Windows.Forms.ToolTip
    # $toolTip.SetToolTip($someControl, "Beschreibender Tooltip-Text")

    # === MUSTER: Top-Panel mit Einstellungs-/Druck-Buttons [OPTIONAL] ===
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Height = 40
    $topPanel.Dock = [System.Windows.Forms.DockStyle]::Top

    $settingsBtn = New-Object System.Windows.Forms.Button
    $settingsBtn.Text = "Einstellungen"
    $settingsBtn.Size = New-Object System.Drawing.Size(100, 24)
    $settingsBtn.Location = New-Object System.Drawing.Point(10, 8)
    $topPanel.Controls.Add($settingsBtn)

    $printBtn = New-Object System.Windows.Forms.Button
    $printBtn.Text = "Drucken"
    $printBtn.Size = New-Object System.Drawing.Size(80, 24)
    $printBtn.Location = New-Object System.Drawing.Point(120, 8)
    $topPanel.Controls.Add($printBtn)

    # Filter-Hinweis-Label (zeigt aktive Filter an)
    $filterHintLabel = New-Object System.Windows.Forms.Label
    $filterHintLabel.Location = New-Object System.Drawing.Point(210, 12)
    $filterHintLabel.Size = New-Object System.Drawing.Size(930, 20)
    $filterHintLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $filterHintLabel.ForeColor = [System.Drawing.Color]::Red
    $filterHintLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $topPanel.Controls.Add($filterHintLabel)
    # $tabPageX.Controls.Add($topPanel)

    # === MUSTER: Bottom-Panel mit Aktions-Buttons [OPTIONAL] ===
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Height = 40
    $bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom

    $actionBtn1 = New-Object System.Windows.Forms.Button
    $actionBtn1.Text = "Aktion 1"; $actionBtn1.Location = New-Object System.Drawing.Point(320, 5)
    $actionBtn1.Size = New-Object System.Drawing.Size(240, 30)
    $bottomPanel.Controls.Add($actionBtn1)
    # $tabPageX.Controls.Add($bottomPanel)

    # === MUSTER: NumericUpDown (Zahleneingabe mit Pfeilen) ===
    # $numericInput = New-Object System.Windows.Forms.NumericUpDown
    # $numericInput.Minimum = 1; $numericInput.Maximum = 100; $numericInput.Value = 10

    # === MUSTER: CheckBox ===
    # $checkBox = New-Object System.Windows.Forms.CheckBox
    # $checkBox.Text = "Option aktivieren"
    # $checkBox.Location = New-Object System.Drawing.Point(110, 200)

    # === MUSTER: RichTextBox (für Hilfe-Tab) [OPTIONAL] ===
    # $richTextBox = New-Object System.Windows.Forms.RichTextBox
    # $richTextBox.Dock = "Fill"; $richTextBox.ReadOnly = $true
    # $richTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    # $richTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None

    # === MUSTER: Beenden-Button ===
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Point(20, 710)
    $closeButton.Size = New-Object System.Drawing.Size(150, 40)
    $closeButton.Text = "Beenden"
    $closeButton.Add_Click({ $form.Close() })
    $tabPage1.Controls.Add($closeButton)

    # --- 6e. Lokale Update-Funktionen ---
    # HINWEIS: Diese Funktionen werden INNERHALB von Show-MainForm definiert,
    # damit sie Zugriff auf die GUI-Variablen ($dataGrid, $chart, etc.) haben.

    # [PLACEHOLDER] Beispiel-Update-Funktion:
    function Update-MainView {
        $dataGrid.Rows.Clear()
        # [PLACEHOLDER] Grid mit aktuellen Daten füllen
        # foreach ($item in $script:data.Items) {
        #     $dataGrid.Rows.Add($item.Name, $item.Value)
        # }
    }

    # [PLACEHOLDER] Beispiel-Chart-Update:
    function Update-Chart {
        $series.Points.Clear()
        $trendSeries.Points.Clear()
        # [PLACEHOLDER] Datenpunkte zum Chart hinzufügen
        # v3.10: Datenreihe IMMER mit @() sortieren - bei genau EINEM Wert liefert Sort-Object
        # sonst ein Einzelobjekt ohne .Count (PS 5.1); "Letzter Wert" fehlte bei neuen Einträgen.
        # $itemData = @($script:allHistoricalItems | Where-Object { $_.Name -eq $selectedName } | Sort-Object Date)
        # foreach ($item in $itemData) {
        #     [void]$series.Points.AddXY([datetime]$item.Date, $item.Value)
        # }
        # "Letzter Wert" schon ab EINEM Wert anzeigen:
        # if ($itemData.Count -ge 1) {
        #     $lastItem = $itemData[-1]
        #     $lastValueLabel.Text = "Letzter Wert: $($lastItem.Value)  (am $(([datetime]$lastItem.Date).ToString('dd.MM.yyyy')))"
        # }
        # Trendlinie erst ab 2 Werten - Vergleich mit -gt, NIE mit ">" (PS-5.1-FALLE 7):
        # if ($itemData.Count -gt 1) { $regression = Calculate-LinearRegression -dataPoints $itemData ... }
    }

    # --- 6f. Event-Handler ---

    # Event: Tab-Wechsel (aktualisiert alle Tabs mit aktuellen Daten)
    $tabControl.Add_SelectedIndexChanged({
        # [PLACEHOLDER] Je nach aktivem Tab die entsprechende Update-Funktion aufrufen:
        # switch ($tabControl.SelectedIndex) {
        #     0 { Update-MainView }
        #     1 { Update-SecondaryView }
        # }
    })

    # Event: Hinzufügen-Button
    $addButton.Add_Click({
        try {
            $date = $datePicker.Value.ToString("yyyy-MM-dd")
            $value = Parse-Number $valueTextBox.Text
            if ($null -eq $value) { throw "Bitte einen Wert eingeben." }

            $newItem = [PSCustomObject]@{
                Date  = $date
                Name  = $comboBox.SelectedItem
                Value = $value
                Note  = $noteTextBox.Text
            }

            # [PLACEHOLDER] Fachliche Validatoren/Schluessel definieren (Sektion 3q).
            # $result = Save-DailyItems -DateString $date -Items @($newItem) -ValidateItem $script:ValidateItem -GetIdentity $script:GetItemIdentity
            # Erst nach Erfolg: $script:allHistoricalItems = Load-AllHistoricalItems
            # Dieses Beispiel ist ohne eingebauten Speicheraufruf NICHT produktionsbereit.

            # UI aktualisieren:
            $valueTextBox.Clear()
            $noteTextBox.Clear()
            Update-MainView
            Update-Chart

            [System.Windows.Forms.MessageBox]::Show("Eintrag erfolgreich hinzugefügt.", "Erfolg", "OK", "Information")
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Fehler: $($_.Exception.Message)", "Eingabefehler", "OK", "Error")
        }
    })

    # Event: Einstellungen-Button
    $settingsBtn.Add_Click({ Show-SettingsPopup -mainForm $form })

    # Event: Drucken-Button [OPTIONAL]
    # Muster für PrintPreviewDialog mit Druckdokument
    $printBtn.Add_Click({
        try {
            $printDoc = New-Object System.Drawing.Printing.PrintDocument
            $printDoc.DefaultPageSettings.Landscape = $true
            $printDoc.Add_PrintPage({
                param($sender, $ev)
                $g = $ev.Graphics
                $margins = $ev.MarginBounds
                $titleFont = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
                $subFont   = New-Object System.Drawing.Font("Segoe UI", 10)
                $smallFont = New-Object System.Drawing.Font("Segoe UI", 8)
                $yPos = $margins.Top

                # Titel
                $g.DrawString("$($script:AppName) - Druckansicht", $titleFont, [System.Drawing.Brushes]::Black, $margins.Left, $yPos)
                $yPos += 30
                # Druckdatum
                $g.DrawString("Druckdatum: $(Get-Date -Format 'dd.MM.yyyy HH:mm')", $smallFont, [System.Drawing.Brushes]::Gray, $margins.Left, $yPos)
                $yPos += 25

                # [OPTIONAL] Chart als Bitmap drucken:
                # $chartBitmap = New-Object System.Drawing.Bitmap($chart.Width, $chart.Height)
                # $chart.DrawToBitmap($chartBitmap, (New-Object System.Drawing.Rectangle(0, 0, $chart.Width, $chart.Height)))
                # $destRect = New-Object System.Drawing.Rectangle($margins.Left, $yPos, $margins.Width, 480)
                # $g.DrawImage($chartBitmap, $destRect)
                # $chartBitmap.Dispose()

                $ev.HasMorePages = $false
            })

            $preview = New-Object System.Windows.Forms.PrintPreviewDialog
            $preview.Document = $printDoc
            $preview.Width = 1000; $preview.Height = 700
            $preview.ShowDialog()
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Druckfehler: $($_.Exception.Message)", "Fehler", "OK", "Error")
        }
    })

    # --- 6g. Formular-Lade-Event (PFLICHT) ---
    # Wird beim Programmstart ausgeführt. Lädt Daten und initialisiert die UI.
    $form.Add_Load({
        # Daten laden
        $script:data = Load-Config
        # [OPTIONAL] Historische Tagesdaten laden:
        # $script:allHistoricalItems = [System.Collections.ArrayList]@(Load-AllHistoricalItems)
        # [OPTIONAL] Zusätzliche DB laden:
        # $script:additionalDb = Load-AdditionalDb

        # UI initialisieren
        # [PLACEHOLDER] ComboBoxen füllen, Felder setzen, etc.
        # $comboBox.Items.Clear()
        # foreach ($item in $script:data.Categories) { $comboBox.Items.Add($item) }

        # Ansichten aktualisieren
        Update-MainView
        # Update-Chart

        Write-DebugLog "Anwendung gestartet"
    })

    # --- 6h. Formular anzeigen (PFLICHT - letzter Schritt!) ---
    $form.ShowDialog()
}



# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 6Z: ZUSATZ-PATTERNS FÜR DAS HAUPTFORMULAR (v3.9)                    ║
# ║  OPTIONAL. Alle Blöcke gehören INNERHALB von Show-MainForm eingefügt         ║
# ║  (sie brauchen Zugriff auf die GUI-Variablen). Hier ausgelagert, damit        ║
# ║  Sektion 6 als lauffähiges Minimalgerüst lesbar bleibt.                       ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# --- 6i. Live-Filter-ComboBox mit Freitext-Auflösung (OPTIONAL, v3.9) ---
# Editierbare ComboBox, die während des Tippens auf Treffer filtert (Sektion 2h),
# nicht auflösbare Eingaben rot markiert und beim Verlassen genau einen
# kanonischen Namen festlegt.
#
# ZUSTAND (vor den Handlern anlegen):
#   $script:itemFullList    = @()      # vollständige, sortierte Namensliste
#   $script:itemFilterBusy  = $false   # Re-Entry-Schutz (siehe unten)
#   $script:currentItemName = $null
#
# WARUM DER BUSY-FLAG? Jedes programmatische Setzen von .Items/.Text/.SelectedIndex
# feuert erneut TextUpdate/SelectedIndexChanged. Ohne Flag entsteht eine Endlos-
# Kaskade. Gleiches Prinzip wie $script:abSuspend in Sektion 5h.
# WARUM TextUpdate (nicht TextChanged)? TextUpdate feuert NUR bei echter
# Nutzereingabe, nicht beim programmatischen Setzen.
#
#     function Set-ItemComboItems {
#         param([string[]]$Items)
#         $prev = $script:itemFilterBusy
#         $script:itemFilterBusy = $true
#         $itemComboBox.BeginUpdate()          # BeginUpdate/EndUpdate = kein Flackern
#         $itemComboBox.Items.Clear()
#         if ($Items -and $Items.Count -gt 0) { $itemComboBox.Items.AddRange([string[]]$Items) }
#         $itemComboBox.EndUpdate()
#         $script:itemFilterBusy = $prev
#     }
#
#     function Commit-ItemSelection {
#         # Löst die Eingabe auf, stellt die volle Liste wieder her, markiert Fehler.
#         $typed = "$($itemComboBox.Text)".Trim()
#         $resolved = Resolve-ItemName -Query $typed
#         $prev = $script:itemFilterBusy
#         $script:itemFilterBusy = $true
#         if ($itemComboBox.DroppedDown) { $itemComboBox.DroppedDown = $false }
#         Set-ItemComboItems -Items $script:itemFullList
#         if ($resolved) {
#             $idx = $itemComboBox.Items.IndexOf($resolved)
#             if ($idx -ge 0) { $itemComboBox.SelectedIndex = $idx } else { $itemComboBox.Text = $resolved }
#             $itemComboBox.BackColor = [System.Drawing.SystemColors]::Window
#         } else {
#             $itemComboBox.SelectedIndex = -1
#             $itemComboBox.Text = $typed
#             # Rot nur bei nicht-leerer, unauflösbarer Eingabe
#             $itemComboBox.BackColor = if ($typed) { [System.Drawing.Color]::MistyRose }
#                                      else        { [System.Drawing.SystemColors]::Window }
#         }
#         $script:itemFilterBusy = $prev
#         Update-ItemInputMode -ItemName $resolved
#     }
#
#     $itemComboBox.Add_TextUpdate({
#         if ($script:itemFilterBusy) { return }
#         $typed = "$($itemComboBox.Text)"
#         if ([string]::IsNullOrWhiteSpace($typed)) { Set-ItemComboItems -Items $script:itemFullList; return }
#         $hits  = @(Get-ItemMatches -Query $typed)
#         $noHit = ($hits.Count -eq 0)
#         if ($noHit) { $hits = @($script:itemFullList) }
#         Set-ItemComboItems -Items $hits
#         $script:itemFilterBusy = $true
#         $itemComboBox.SelectedIndex = -1
#         $itemComboBox.Text = $typed
#         if ($noHit) { $itemComboBox.BackColor = [System.Drawing.Color]::MistyRose }
#         else {
#             $itemComboBox.BackColor = [System.Drawing.SystemColors]::Window
#             if (-not $itemComboBox.DroppedDown) { $itemComboBox.DroppedDown = $true }
#         }
#         # Cursor ans Ende, sonst springt er bei jedem Tastendruck an Position 0
#         $itemComboBox.SelectionStart  = $typed.Length
#         $itemComboBox.SelectionLength = 0
#         $script:itemFilterBusy = $false
#     })
#     $itemComboBox.Add_Leave({ Commit-ItemSelection })


# --- 6j. Kontextabhängiger Eingabemodus (OPTIONAL, v3.9) ---
# Ein Eingabefeld passt sich dem gewählten Eintrag an: Zahl, Auswahlliste
# (qualitative/kodierte Werte, Sektion 1h/2h) oder Zahl mit Einheiten-Umschalter.
# Zusätzlich blendet eine Info-Zeile Einheit und Referenzbereich ein.
#
# REGEL: Alle Sonderfelder liegen deckungsgleich übereinander; sichtbar ist immer
#        genau eins. Beim Wechsel IMMER alle zurücksetzen - sonst bleibt ein
#        falsches Feld stehen, wenn die Eingabe wieder mehrdeutig wird.
#
#     function Update-ItemInputMode {
#         param([string]$ItemName)
#         $script:currentItemName = $ItemName
#         $isCoded = ($ItemName -eq $script:CodedItemName)
#         $codedComboBox.Visible = $isCoded
#         $valueTextBox.Visible  = -not $isCoded
#         if ($isCoded) {
#             $itemInfoLabel.Text    = "Auswahl treffen  |  Referenz: [PLACEHOLDER]"
#             $itemInfoLabel.Visible = $true
#             return
#         }
#         if ([string]::IsNullOrWhiteSpace($ItemName)) { $itemInfoLabel.Visible = $false; return }
#         $cfg = $script:data.Config.Markers | Where-Object { $_.Name -eq $ItemName } | Select-Object -First 1
#         if (-not $cfg) { $itemInfoLabel.Visible = $false; return }
#         $parts = @()
#         if ("$($cfg.Unit)".Trim()) { $parts += "$($cfg.Unit)".Trim() }
#         if ($null -ne $cfg.RefMin -and $null -ne $cfg.RefMax) { $parts += "Ref $($cfg.RefMin)-$($cfg.RefMax)" }
#         $itemInfoLabel.Text    = ($parts -join "  |  ")
#         $itemInfoLabel.Visible = ($parts.Count -gt 0)
#     }
#
# CHECKLISTE bei einem neuen qualitativen Eintrag - ALLE Stellen anfassen:
#   [ ] Update-ItemInputMode      (Auswahlliste statt Zahlenfeld)
#   [ ] Speichern-Handler         (Code ablegen + sprechende Notiz)
#   [ ] Übersichts-/Cockpit-Grid  (Klartext statt Code)
#   [ ] Chart-Tooltip
#   [ ] Detail-Tab / Datenliste
#   [ ] Ausdruck und Report-PDF   (Sektion 5l Punkt 4)
#   [ ] Import-Ausschlussliste    (Sektion 1i)


# --- 6k. Dynamisches Checkbox-Panel mit Master-Schalter (OPTIONAL, v3.9) ---
# Muster für "Profile"/"Vorbelastungen"/"Regelsätze": eine Menge benannter Einträge,
# jeder mit einer Liste betroffener Katalog-Einträge, ein Master-Schalter über allen,
# plus eine Eingabemaske für benutzerdefinierte Einträge.
#
# DATENSTRUKTUR (in der Config persistiert):
#   Profiles = @{
#       Enabled = $false                      # Master
#       BuiltIn = @( @{ Name='...'; Active=$false; Items=@('A','B') } )   # mitgeliefert
#       Custom  = @( @{ Name='...'; Active=$false; Items=@('C') } )       # vom Nutzer
#   }
#
# REGELN:
#   1. Master-Checkbox steuert .Enabled ALLER Unter-Checkboxen (nicht deren .Checked)
#      - der Nutzer soll seine Auswahl beim Aus-/Einschalten nicht verlieren.
#   2. Custom-Einträge in ein Panel rendern und bei jeder Änderung neu aufbauen:
#      Panel.Controls.Clear(), Liste der Checkbox-Referenzen ($script:...Checks) neu
#      aufbauen, .Tag = Name (dient als Schlüssel beim Speichern).
#   3. Merge beim Laden in EIGENEN try/catch - ein Fehler in den Profildaten darf
#      nicht die gesamte Config-Ladung abbrechen.
#   4. Save-Data muss den Block explizit mitschreiben (siehe Falle in Sektion 3k).
#
#     function Get-ActiveProfileHints {
#         # Liefert Hashtable: EintragsName -> @(Hinweistexte) für ToolTips im Grid
#         $result = @{}
#         $p = $script:data.Config.Profiles
#         if (-not $p -or -not $p['Enabled']) { return $result }
#         foreach ($entry in (@($p['BuiltIn']) + @($p['Custom']))) {
#             if (-not $entry -or -not $entry['Active']) { continue }
#             foreach ($item in $entry['Items']) {
#                 if (-not $result.ContainsKey($item)) { $result[$item] = @() }
#                 $result[$item] += "Hinweis: $((($entry['Name'] -split '\(')[0]).Trim())"
#             }
#         }
#         return $result
#     }


# --- 6l. Zentraler Update-ScriptBlock für abhängige Buttons (OPTIONAL, v3.9) ---
# Wird ein Button-Zustand (Sichtbarkeit, Text, Zähler, ToolTip, Tag) an mehreren
# Stellen gebraucht (Auswahl geändert, nach Upload, nach Löschen), gehört die Logik
# EINMAL in einen ScriptBlock - nicht dreimal inline kopiert.
# (Genau diese Duplizierung war die Ursache eines Anzeigefehlers im Blood-Tracker.)
#
#     $UpdateShowDocButton = {
#         param($dateString)
#         $showDocButton.Visible = $false
#         $showDocButton.Tag     = $null
#         $showDocButton.Text    = "Dokument`nanzeigen"
#         $showDocToolTip.SetToolTip($showDocButton, "")
#         if ([string]::IsNullOrWhiteSpace($dateString)) { return }
#         try {
#             $docs = @(Get-ArchivedDocuments -DateString $dateString)
#             if ($docs.Count -eq 0) { return }
#             # Tag transportiert die vollständigen Pfade zum Click-Handler
#             $showDocButton.Tag  = [PSCustomObject]@{ Date = $dateString; Files = @($docs.FullName) }
#             $showDocButton.Text = if ($docs.Count -gt 1) { "Dokument`nanzeigen ($($docs.Count))" }
#                                   else                   { "Dokument`nanzeigen" }
#             $tipList = ($docs | ForEach-Object { " - $($_.Name)  ($([Math]::Round($_.Length / 1KB, 0)) KB)" }) -join "`r`n"
#             $showDocToolTip.SetToolTip($showDocButton, "$($docs.Count) Dokument(e):`r`n$tipList")
#             $showDocButton.Visible = $true
#         } catch { Write-Warning "Button-Aktualisierung: $($_.Exception.Message)" }
#     }
#     # Aufruf an JEDER relevanten Stelle:  & $UpdateShowDocButton $selectedDate


# --- 6m. Global sichtbare Buttons (Form-Ebene statt Tab-Ebene) (v3.9) ---
# FALLE: Ein Button in $tabPage1.Controls ist NUR in Tab 1 sichtbar. Buttons, die
# aus jedem Tab erreichbar sein sollen ("Beenden", "globale Einstellungen"),
# gehören auf $form.Controls - platziert auf Tab-Reiter-Höhe rechts neben dem
# letzten Tab-Header.
#
#   $exitButton.Location = New-Object System.Drawing.Point(($tabControl.Right - 180), 8)
#   $exitButton.Anchor   = "Top,Right"     # bleibt beim Resize bündig
#   $form.Controls.Add($exitButton)
#   $exitButton.BringToFront()             # sonst liegt er hinter dem TabControl
#
# PRÜFUNG NACH JEDER LAYOUT-ÄNDERUNG: Button darf keine anderen Controls überdecken
# und muss oberhalb der TabControl-Oberkante liegen (Y=8 statt Y=12).


# --- 6n. Such-ComboBox für eine Anzeige-/Filterliste (OPTIONAL, v3.10) ---
# Unterschied zu 6i: 6i löst Freitext gegen den KATALOG auf (Eingabefeld). 6n ist eine
# AUSWAHLLISTE (z.B. "Verlauf anzeigen für"), deren Inhalt von den Daten abhängt - gesucht
# wird nur in genau dieser Liste (Get-ListMatches / Resolve-ListSelection, Sektion 2h).
# VERHALTEN: Tippen filtert die Liste OHNE die Ansicht neu zu zeichnen, Enter übernimmt den
# eindeutigen Treffer, Esc und Verlassen ohne Treffer stellen die bisherige Auswahl wieder
# her, Aufklappen per Pfeil nach einer gefilterten Auswahl zeigt wieder die volle Liste.
#
# ZUSTAND (nach dem Anlegen der ComboBox):
#   $displayComboBox.DropDownStyle      = [System.Windows.Forms.ComboBoxStyle]::DropDown
#   $displayComboBox.AutoCompleteMode   = [System.Windows.Forms.AutoCompleteMode]::None
#   $displayComboBox.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::None
#   $script:displayBusy          = $false   # Re-Entry-Schutz UND "nicht neu zeichnen"
#   $script:displayFullList      = @()      # volle Liste - bei JEDEM Neubefüllen setzen!
#   $script:displayLastSelection = $null    # zuletzt angezeigter Eintrag
#   $script:displayPlaceholder   = '--- Bitte auswählen ---'
#
#     function Set-DisplayComboItems {
#         param([string[]]$Items)
#         $previousBusy = $script:displayBusy
#         $script:displayBusy = $true
#         $displayComboBox.BeginUpdate()
#         $displayComboBox.Items.Clear()
#         if ($Items -and $Items.Count -gt 0) { $displayComboBox.Items.AddRange([object[]]$Items) }
#         $displayComboBox.EndUpdate()
#         $script:displayBusy = $previousBusy
#     }
#     function Get-DisplaySearchItems {
#         return @($script:displayFullList | Where-Object { $_ -and $_ -ne $script:displayPlaceholder })
#     }
#     function Restore-DisplaySelection {
#         param([string]$Name)
#         $script:displayBusy = $true
#         try {
#             if ($displayComboBox.DroppedDown) { $displayComboBox.DroppedDown = $false }
#             Set-DisplayComboItems -Items $script:displayFullList
#             $restoreIndex = if ($Name) { $displayComboBox.Items.IndexOf($Name) } else { -1 }
#             if ($restoreIndex -lt 0 -and $displayComboBox.Items.Count -gt 0) { $restoreIndex = 0 }
#             $displayComboBox.SelectedIndex = $restoreIndex
#             $displayComboBox.BackColor = [System.Drawing.SystemColors]::Window
#         } finally { $script:displayBusy = $false }
#     }
#     function Commit-DisplaySelection {
#         # $true = übernommen (oder leer), $false = kein eindeutiger Treffer
#         $typedText = "$($displayComboBox.Text)".Trim()
#         if ([string]::IsNullOrWhiteSpace($typedText)) { Restore-DisplaySelection -Name $script:displayLastSelection; return $true }
#         $target = Resolve-ListSelection -Query $typedText -Items (Get-DisplaySearchItems)
#         if (-not $target) { return $false }
#         Restore-DisplaySelection -Name $target
#         if ($target -ne $script:displayLastSelection) { $script:displayLastSelection = $target; Update-Chart }
#         return $true
#     }
#     $displayComboBox.Add_TextUpdate({                 # feuert NUR bei Nutzereingabe
#         if ($script:displayBusy) { return }
#         $typedText = "$($displayComboBox.Text)"
#         $script:displayBusy = $true
#         try {
#             if ([string]::IsNullOrWhiteSpace($typedText)) {
#                 Set-DisplayComboItems -Items $script:displayFullList
#                 $displayComboBox.SelectedIndex = -1; $displayComboBox.Text = ""
#                 $displayComboBox.BackColor = [System.Drawing.SystemColors]::Window
#                 return
#             }
#             $hits = @(Get-ListMatches -Query $typedText -Items (Get-DisplaySearchItems))
#             if ($hits.Count -eq 0) {
#                 Set-DisplayComboItems -Items $script:displayFullList
#                 $displayComboBox.BackColor = [System.Drawing.Color]::MistyRose
#             } else {
#                 Set-DisplayComboItems -Items $hits
#                 $displayComboBox.BackColor = [System.Drawing.SystemColors]::Window
#             }
#             $displayComboBox.SelectedIndex = -1
#             $displayComboBox.Text = $typedText
#             if ($hits.Count -gt 0 -and -not $displayComboBox.DroppedDown) {
#                 $displayComboBox.DroppedDown = $true
#                 # Aufklappen blendet den Mauszeiger aus - wieder einblenden
#                 [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
#             }
#             $displayComboBox.SelectionStart = $typedText.Length
#             $displayComboBox.SelectionLength = 0
#         } finally { $script:displayBusy = $false }
#     })
#     $displayComboBox.Add_KeyDown({
#         $keyArgs = $args[1]                            # ohne param() (PS-5.1-FALLE 9)
#         if ($keyArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
#             $keyArgs.Handled = $true; $keyArgs.SuppressKeyPress = $true
#             if (-not (Commit-DisplaySelection)) { $displayComboBox.BackColor = [System.Drawing.Color]::MistyRose }
#         } elseif ($keyArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
#             $keyArgs.Handled = $true; $keyArgs.SuppressKeyPress = $true
#             Restore-DisplaySelection -Name $script:displayLastSelection
#         }
#     })
#     $displayComboBox.Add_Leave({
#         if ($script:displayBusy) { return }
#         if (-not (Commit-DisplaySelection)) { Restore-DisplaySelection -Name $script:displayLastSelection }
#     })
#     $displayComboBox.Add_DropDown({
#         if ($script:displayBusy) { return }
#         $currentSelection = [string]$displayComboBox.SelectedItem
#         if ($currentSelection -and $displayComboBox.Items.Count -lt @($script:displayFullList).Count -and
#             "$($displayComboBox.Text)" -eq $currentSelection) {
#             $script:displayBusy = $true
#             try {
#                 Set-DisplayComboItems -Items $script:displayFullList
#                 $displayComboBox.SelectedIndex = $displayComboBox.Items.IndexOf($currentSelection)
#             } finally { $script:displayBusy = $false }
#         }
#     })
# BESTEHENDER SelectedIndexChanged-Handler: als ERSTE Zeile  if ($script:displayBusy) { return }
#   und danach  $script:displayLastSelection = [string]$displayComboBox.SelectedItem
# BEIM (NEU-)BEFÜLLEN der Liste (z.B. Update-*Dropdown):
#   $script:displayFullList      = @($displayComboBox.Items | ForEach-Object { [string]$_ })
#   $script:displayLastSelection = [string]$displayComboBox.SelectedItem


# --- 6o. Geburtsdatum-Feld mit Live-Altersanzeige (OPTIONAL, v3.10) ---
# Gehört zu Sektion 4p. TextBox (TT.MM.JJJJ, MaxLength 10) + Label rechts daneben:
#   gültig -> "= 37 Jahre (heute)" | leer + Altbestand -> "bisher fest: 37 J." |
#   ungültig -> "Format TT.MM.JJJJ" (rot)
#
#     function Update-BirthDateAgeLabel {
#         $birthPreview = ConvertTo-AppDate -Text $textBirthDate.Text
#         if ($birthPreview) {
#             $agePreview = Get-AgeAtDate -BirthDate $birthPreview
#             $labelAge.Text = if ($null -ne $agePreview) { "= $agePreview Jahre (heute)" } else { "Datum in der Zukunft" }
#             $labelAge.ForeColor = [System.Drawing.Color]::DimGray
#         } elseif ([string]::IsNullOrWhiteSpace($textBirthDate.Text)) {
#             $fixedAge = $script:data.Config.Personal.Age
#             $labelAge.Text = if ($fixedAge) { "bisher fest: $fixedAge J." } else { "" }
#             $labelAge.ForeColor = [System.Drawing.Color]::DimGray
#         } else {
#             $labelAge.Text = "Format TT.MM.JJJJ"
#             $labelAge.ForeColor = [System.Drawing.Color]::Firebrick
#         }
#     }
#     $textBirthDate.Add_TextChanged({ Update-BirthDateAgeLabel })
#
# SPEICHERN: gültiges Datum Pflicht, nicht in der Zukunft, plausibles Alter; gespeichert als
#   'yyyy-MM-dd'. Das feste Alter (Fallback) gleichzeitig auf das heutige Alter setzen, damit
#   ältere Script-Versionen mit derselben Config weiter sinnvoll rechnen.
#     $birthDate = ConvertTo-AppDate -Text $textBirthDate.Text
#     if ($null -eq $birthDate) { throw "Bitte ein gültiges Geburtsdatum im Format TT.MM.JJJJ eingeben." }
#     if ($birthDate -gt (Get-Date).Date) { throw "Das Geburtsdatum liegt in der Zukunft." }
#     $age = Get-AgeAtDate -BirthDate $birthDate
#     if ($age -lt 18 -or $age -gt 120) { throw "Bitte das Geburtsdatum prüfen ($age Jahre)." }   # [PLACEHOLDER] Grenzen
#     $script:data.Config.Personal.Geburtsdatum = $birthDate.ToString('yyyy-MM-dd')
#     $script:data.Config.Personal.Age = $age
# LADEN: Anzeige 'dd.MM.yyyy'; neues Feld in Altbeständen per Default-Ergänzung (3a) mit "".
# TOOLTIP erklärt, WOFÜR das Alter genutzt wird (je Messtag, vollendete Lebensjahre).


# --- 6p. Auswahl-Dropdown mit stabilem Speicher-Schlüssel (OPTIONAL, v3.10) ---
# Gespeichert wird ein kurzer, stabiler SCHLÜSSEL, nie der Anzeigetext - sonst bricht jede
# Textänderung im Dropdown die gespeicherte Auswahl (Blood-Tracker: 'ASCVD' / 'CVD').
#   $comboMode.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
#   $script:modeKeys = @('STANDARD', 'GESAMT')                                    # gespeichert
#   [void]$comboMode.Items.AddRange(@('10 Jahre Standard', '10 Jahre gesamt'))   # angezeigt
#   # Laden:     $modeIndex = [array]::IndexOf($script:modeKeys, [string]$script:data.Config.Settings.Mode)
#   #            $comboMode.SelectedIndex = if ($modeIndex -ge 0) { $modeIndex } else { 0 }   # unbekannt -> Default
#   # Speichern: $script:data.Config.Settings.Mode = $script:modeKeys[$comboMode.SelectedIndex]
# Neuer Schlüssel in bestehender Config: Default-Ergänzung beim Laden (3a, Schritt 4).
# Alle Ansichten, die den Wert nutzen, lesen ihn beim Neuzeichnen aus der Config (nicht aus
# dem Dropdown) - dann wirkt die Einstellung auch in Tabs, die das Dropdown nicht kennen.



# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 6Q: BETA-TESTMODUS & QUALITÄTSSICHERUNG (v3.10, Dokumentation)      ║
# ║  Kein Laufzeit-Code außer dem Schalter in Sektion 0/1b. Gilt für JEDE         ║
# ║  Änderung an einem Script dieser Familie.                                     ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# --- 6Q-1. BETA-Testmodus ---
# GRUNDREGEL: Ein BETA-Test darf echte Daten NIE lesen oder verändern.
# UMSETZUNG (Sektion 0/1b): $script:BetaMode = $true ODER Umgebungsvariable PSC_BETA=1
#   -> AppName + ".BETA" -> eigener Registry-Schlüssel HKCU:\Software\PSC\<App>.BETA,
#      eigener Datenordner ~\<App>.BETA, eigene Backup-Namen, Titel mit "BETA-TEST".
# START ohne Script-Änderung (Windows PowerShell 5.1):
#   $env:PSC_BETA = '1'; powershell.exe -ExecutionPolicy Bypass -File .\MeineApp_v1.2.0.ps1
#   Danach $env:PSC_BETA = $null - die Variable gilt sonst für jeden weiteren Start aus
#   DIESER Konsole (dann unbeabsichtigt BETA statt echter Daten).
# NEUSTARTS aus der App (Datenpfad ändern, Wiederherstellung) bleiben im BETA-Modus, weil
#   Start-Process die Umgebung des laufenden Prozesses erbt.
# ZURÜCKSETZEN: nur BETA-Datenordner und BETA-Registry-Schlüssel entfernen - nie den echten.
# BESTEHENDE Apps ohne Schalter: externer Starter, der eine Test-Kopie des Scripts mit
#   ersetztem Registry-Pfad/Datenordner erzeugt. Jede Ersetzung muss GENAU EINMAL greifen
#   (sonst Abbruch, nichts starten) + Endkontrolle, dass der echte Pfad nicht mehr vorkommt.

# --- 6Q-2. Test-Config mit fiktiven Daten ---
# Ziel: Umsetzungsfehler sofort SICHTBAR machen - nicht nur "läuft ohne Fehlermeldung".
#  - Fiktive Persona (nie echte Werte); Config im Format einer ÄLTEREN Version (z.B. ohne
#    CatalogVersion), damit die Migration (3k) beim ersten Start mitgeprüft wird.
#  - Grenzfälle gezielt einbauen: Listen mit 0 / 1 / 2 Einträgen, Eintrag mit genau EINEM
#    Messwert, Werte exakt auf Bereichsgrenzen, fehlende Eingangswerte, Vorrang-/Ersatz-
#    Werte (1j), alte Standardwerte (OnlyIf greift) UND vom Nutzer geänderte Werte (OnlyIf
#    greift nicht), Messtage vor und nach einem Geburtstag (4p).
#  - Erwartete Ergebnisse (Soll) VORAB außerhalb des Scripts berechnen und als Testprotokoll
#    (Test-ID, Schritt, Soll, Ist, OK) mitliefern - Abweichungen sind dann sofort sichtbar.
#  - Einspielen nur in den BETA-Datenordner, nie überschreiben; die App liest Klartext und
#    verschlüsselt beim ersten Speichern (3h).

# --- 6Q-3. QS-Checkliste vor jeder Auslieferung ---
#  [ ] Parser: 0 Fehler
#        $parseErrors = $null
#        [void][System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$parseErrors)
#  [ ] PSScriptAnalyzer mit PS-5.1-Kompatibilitätsprofil (auch wenn unter PS 7 entwickelt):
#        $profile51 = 'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
#        Invoke-ScriptAnalyzer -Path $p -Settings @{ Rules = @{
#            PSUseCompatibleSyntax   = @{ Enable = $true; TargetVersions = @('5.1') }
#            PSUseCompatibleCommands = @{ Enable = $true; TargetProfiles = @($profile51) }
#            PSUseCompatibleTypes    = @{ Enable = $true; TargetProfiles = @($profile51) } } }
#        Anzahl der Findings mit der Vorversion vergleichen - neue Findings erklären oder beheben.
#  [ ] Geänderte Stellen per Select-String gegenprüfen; Version, Header und Changelog erhöht.
#  [ ] Funktionstests OHNE GUI (6Q-4) für jede geänderte Funktion.
#  [ ] Pflicht-Testfälle: Liste mit 0/1/2 Einträgen speichern -> laden -> erneut laden
#      (Round-Trip), Eintrag mit genau 1 Wert, defekte/unlesbare Datei, gesperrte Datei,
#      Fehler mitten im Schreiben (der Bestand muss vollständig erhalten bleiben).
#  [ ] Regression: ALLE bisherigen Tests erneut ausführen, nicht nur die neuen.

# --- 6Q-4. Testharness ohne GUI (AST-Extraktion) ---
# Einzelne Funktionen laden, ohne Show-MainForm zu starten:
#   $ast = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$null)
#   $want = 'ConvertTo-Hashtable', 'Write-AtomicTextFile', 'Get-RangeScore'
#   $funcs = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
#                           $want -contains $args[0].Name }, $true)
#   . ([scriptblock]::Create((@($funcs | ForEach-Object { $_.Extent.Text }) -join "`n`n")))
# MessageBox und DPAPI im extrahierten Text durch Test-Klassen ersetzen (Add-Type), z.B.
#   '[System.Windows.Forms.MessageBox]::Show(' -> '[TestMsg]::Show('   (protokolliert statt anzeigt)
# PS 7 kennt .Count auch auf Einzelobjekten - ein Test, der unter PS 7 grün ist, kann unter
#   Windows PowerShell 5.1 rot sein. Ein-Element-Fälle deshalb unter 5.1 testen oder die 5.1-
#   Situation erzwingen (Testobjekt mit NoteProperty "Count" = $null).
# Event-Handler-Logik (z.B. Scope-Fehler 5c) mit einem Fake-Control prüfen: Add-Type-Klasse
#   mit "public event EventHandler Click" + PerformClick(), Handler per Add_Click anhängen.


# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  SEKTION 7: SKRIPT-EINSTIEGSPUNKT                                           ║
# ║  PFLICHT: Immer die letzte Zeile im Skript.                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

Show-MainForm
