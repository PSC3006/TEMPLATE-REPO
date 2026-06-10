# CLAUDE.md

Anweisungen für Claude Code in diesem Repository (PSC_Blood-Tracker).

## Git- & PR-Workflow

- **Niemals direkt auf `main` arbeiten.** Jede Änderung erfolgt auf einem neuen,
  thematisch benannten Branch.
- Für jede Änderung wird ein **Pull Request als Draft** erstellt.
- **Niemals automatisch mergen.** Das Mergen erfolgt ausschließlich durch den
  Repo-Owner nach Review/Approval.
- **Commit-Messages werden auf Deutsch verfasst**, kurz und prägnant, mit Fokus
  auf das "Warum" der Änderung.

## Projekt-Hintergrund

PSC Blood-Tracker ist ein einzelnes PowerShell-Skript mit einer Windows-Forms-GUI
zur Erfassung, grafischen Auswertung und proaktiven Überwachung von Blutwerten
(Hauptdatei: `Blood-Tracker_*.ps1`).

- **Zielumgebung:** Windows (PowerShell, Windows Forms, DPAPI, Registry `HKCU`).
- **Funktionsumfang:** Tabs für Cockpit (Risiko-Übersicht), Einzelmarker-Analyse,
  Korrelationen, Datenmanagement nach Bluttests, Custom Reports und persönliche
  Metriken (inkl. genetischer Vorbelastungen, PhenoAge/Longevity-Scores).
- **Daten & Sicherheit:** Konfiguration und Tagesdaten werden als JSON lokal
  gespeichert und automatisch per DPAPI (CurrentUser-Scope) verschlüsselt.
  Portable Backups erfolgen passwortbasiert via AES-256 (`.btbackup`).
- **Sonstiges:** PDF-Import von Blutbild-Befunden (Beta, via iTextSharp) mit
  automatischem Marker-Matching und Review-Dialog.

## Code-Konventionen (PowerShell)

- **Funktionsnamen:** Verb-Noun in PascalCase (z.B. `Save-Data`,
  `Calculate-LongevityScore`, `Import-PdfBloodValues`).
- **Einrückung:** 4 Leerzeichen, keine Tabs.
- **Variablen:** Script-weite Variablen mit `$script:`-Prefix und camelCase
  (z.B. `$script:cockpitTimeFilter`).
- **Sprache:** UI-Texte, Meldungen und Kommentare sind auf Deutsch.
- **Strukturierung:** Größere Abschnitte werden mit Kommentar-Headern
  abgegrenzt (`# ---------- Abschnitt ----------`).
- **Dokumentation:** Wichtige Funktionen erhalten Comment-Based-Help
  (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`).
- **Changelog:** Änderungen werden im Changelog-Kommentarblock am Dateianfang
  dokumentiert (Versionsnummer, Datum, Beschreibung).
