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
Sources/
  Shell/      App-Einstieg, Router, Abhaengigkeiten, Design-Tokens
  Setup/      Screen 1 - Toepfe, Regeln, Seed
  Draw/       Screen 2 - laufende Auslosung, Sequencer, Playback
  Results/    Screen 3 - Spielplaene, Suche, Export
  Support/    Engine-Naht, Stubs, Mock, Beispieldaten
  Tests/      XCTest fuer die Praesentationslogik
```

## Einbinden

Es liegt bewusst kein eigenes Xcode-Projekt bei. Die Dateien werden in ein
iOS-App-Target gezogen, das vom `DrawEngine`-Package abhaengt.

- Deployment Target: iOS 17.0
- `Sources/Tests/` gehoert in ein Test-Target, nicht ins App-Target
- Der Code ist unter vollstaendiger strikter Concurrency warnungsfrei

## Details

Die Architektur-Entscheidungen stehen in `docs/ui-architecture.md`.
