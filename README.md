# UEFA-Auslosung

Dieses Repository steuert die Entwicklung einer SwiftUI-App, die eine UEFA Champions League Auslosung simuliert.

## Zielbild

Die spaetere App soll:
- Lostoepfe und Teams verwalten
- Auslosungsregeln nachvollziehbar abbilden
- eine komplette Simulation Schritt fuer Schritt anzeigen
- reproduzierbare Ergebnisse mit Seed-Unterstuetzung liefern
- Ergebnisse und Zwischenstaende fuer QA und Demos dokumentieren

## Was dieses Repo liefert

- Produktvision und Scope
- Zielarchitektur fuer die App
- Umsetzungsroadmap
- Arbeitsregeln fuer spaetere Beitraege
- konkrete Projektstruktur fuer die Umsetzung

## Bewusste Grenzen

- Kein Live-Datenfeed zum Start
- Kein Backend im ersten Schritt
- Keine Ueberladung mit Features vor der Kernsimulation

## Empfohlener Start fuer die Umsetzung

1. Regeln und Annahmen der Auslosung festziehen
2. Simulationskern als testbare Swift-Module bauen
3. SwiftUI-Oberflaechen um den Kern herum setzen
4. Ergebnisse, Historie und Debug-Ansichten hinzufuegen

## Repo-Struktur

- `Package.swift` - SwiftPM-Einstieg fuer DrawEngine und Tests
- `Packages/DrawEngine/` - fachliche Kernlogik
- `Apps/UEFADrawApp/` - spaetere SwiftUI-App
- `Tests/DrawEngineTests/` - Tests fuer die Auslosungslogik
- `Resources/Design/` - CL-Logo, Draw-Optik und 36 Teamlogos
- `AGENTS.md` - Arbeitsregeln fuer KI-gestuetzte Aenderungen
- `docs/vision.md` - Produktziel und Nutzererlebnis
- `docs/architecture.md` - technische Zielarchitektur
- `docs/roadmap.md` - Phasen und Reihenfolge der Umsetzung
- `docs/rules.md` - erste fachliche Regelbasis
- `docs/example-data.md` - Beispielteams und Seed

## Naechster sinnvoller Schritt

Den SwiftUI-App-Startpunkt anlegen und die Auslosungsregeln als explizite Fachlogik modellieren.
