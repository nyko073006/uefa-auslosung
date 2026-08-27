# UEFADrawApp

Die SwiftUI-Shell der Auslosung. SwiftUI mit MVVM und `@Observable`, iOS 17+.

## Rolle

- Visualisierung der Auslosung
- Bedienung der Simulation
- Anzeige von Regeln, Sperren und Ergebnissen

## Abhaengigkeit

Die App verwendet die Logik aus `DrawEngine` und enthaelt **keine**
Auslosungsregeln. Die Naht dorthin ist `Support/DrawEnginePort.swift`.

Solange die Engine noch nicht fertig ist, laufen App und Previews gegen
`Support/MockDrawEngine.swift`. Der Wechsel auf die echte Engine ist eine
Aenderung an genau einer Stelle: `AppModel(engine:)` in
`Shell/UEFADrawApp.swift`.

Zwei Dateien sind als temporaer markiert und werden beim Zusammenfuehren
geloescht bzw. ersetzt:

- `Support/DomainStubs.swift`
- `Support/MockDrawEngine.swift`

## Aufbau

```
project.yml   XcodeGen-Spezifikation (Quelle der Projektstruktur)
Resources/    Asset-Katalog (AppIcon, AccentColor)
Sources/
  Shell/      App-Einstieg, Router, Abhaengigkeiten, Design-Tokens
  Setup/      Screen 1 - Toepfe, Regeln, Seed
  Draw/       Screen 2 - laufende Auslosung, Sequencer, Playback
  Results/    Screen 3 - Spielplaene, Suche, Export
  Support/    Engine-Naht, Stubs, Mock, Beispieldaten
  Tests/      XCTest fuer die Praesentationslogik
```

## Starten

```
open UEFADrawApp.xcodeproj
```

Das Projekt wird aus `project.yml` erzeugt. Nach Struktur-Aenderungen
(neue Ordner, neue Targets, andere Build-Settings) neu generieren:

```
xcodegen generate
```

Struktur-Aenderungen gehoeren immer in `project.yml`, nicht ins generierte
Projekt - sonst gehen sie beim naechsten Generieren verloren.

- Deployment Target: iOS 17.0, iPhone und iPad
- Targets: `UEFADrawApp` (App) und `UEFADrawAppTests` (24 Unit-Tests)
- `SWIFT_STRICT_CONCURRENCY = complete`, der Code ist warnungsfrei

## Sprache im Code

Kommentare, Bezeichner und Dokumentation sind ASCII (siehe `AGENTS.md`).
Sichtbare Texte in der App verwenden echte Umlaute.

## Details

Die Architektur-Entscheidungen stehen in `docs/ui-architecture.md`.
