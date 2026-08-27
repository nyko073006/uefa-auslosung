# UI-Architektur der SwiftUI-Shell

Diese Datei haelt die Entscheidungen zur Praesentationsschicht fest
(Phase 3 der Roadmap). Die Fachlogik bleibt vollstaendig in `DrawEngine`.

Ort im Repo: `Apps/UEFADrawApp/Sources/`.

## Schichten

```
DrawEngine (Package)          Apps/UEFADrawApp
--------------------          ------------------------------------------
Team, Pot, Association
Matchup, DrawState
run(setup, seed)
  -> Ergebnis + Trace   --->  DrawEnginePort      Protokoll + Mock
     (Ablehnungen und             |
      Begruendungen)              v
                            RevealSequencer   Ergebnis -> [RevealStep]
                                  |
                                  v
                            PlaybackController  Cursor, Tempo, Pause, Replay
                                  |
                                  v
                            RevealState.apply()  reiner Reducer
                                  |
                                  v
                            @Observable ViewModel ---> SwiftUI View
```

## Leitentscheidungen

### 1. Dramaturgie aus einem fertigen Ergebnis

Die Engine ist eine Pure Function mit Seed - es troepfelt nichts live herein.
`RevealSequencer` uebersetzt das fertige Ergebnis samt Trace in eine
Enthuellungs-Sequenz. Das entspricht einer echten TV-Auslosung, bei der das
Resultat physisch feststeht und nur die Enthuellung inszeniert wird.

Folge: Pause ist ein angehaltener Cursor, Tempo ist eine Wartezeit, Replay ist
Cursor auf 0. Bei gleichem Seed ist die Wiederholung garantiert identisch.
Ein AsyncStream liesse sich fuer nichts davon sauber anhalten.

### 2. Die App kennt keine Regel

Drei Stellen halten diese Grenze:

- Die Constraint-Schalter im Setup werden aus `availableConstraints()` gerendert.
  Titel und Erklaertext kommen aus der Engine.
- Die fachliche Pruefung laeuft ueber `validate(_:)`. Die App prueft nur
  Darstellungsfragen wie ein leeres Namensfeld.
- Der Live-Screen zeigt Ablehnungen mit dem **von der Engine formulierten**
  Begruendungstext. Er wertet nichts nach.

Die Verbands-Auszaehlung im Live-Screen ist bewusst nur eine Zaehlung des
bereits Aufgedeckten - kein "voll", kein "gesperrt", kein Vergleich gegen ein
Limit.

Pruefbar mit:

```
grep -rniE "association|constraint" Apps/UEFADrawApp/Sources/{Setup,Draw,Results}
```

Treffer duerfen nur Anzeige, Suche oder Render-Bedingungen sein - nie ein
Vergleich gegen einen Schwellwert.

### 3. Namenskonvention `Reveal*`

Die Domain besitzt laut `architecture.md` bereits `DrawState`. Die
Praesentationsschicht nutzt deshalb durchgaengig das Praefix `Reveal`
(`RevealState`, `RevealStep`, `RevealSequencer`), um kollisionsfrei zu bleiben.

### 4. Navigation

Ein zentraler `NavigationStack` mit typsicherem `Route`-Enum. Der `AppRouter`
wird in die ViewModels injiziert, nicht in die Views - dadurch bleibt der
View-Body frei von Entscheidungen und die Navigation testbar.

Die ViewModels der Navigationsziele entstehen im `navigationDestination`-Builder
aus Route-Nutzlast und Abhaengigkeiten (`AppModel`).

### 5. Formfaktor

iPhone zuerst, iPad-tauglich. Adaptive Grids statt fester Breiten, keine
eigenen Split-View-Layouts. Damit ist die offene Frage aus `roadmap.md`
beantwortet.

## Die Naht zur Engine

`Apps/UEFADrawApp/Sources/Support/DrawEnginePort.swift` beschreibt, was die UI
braucht:

```swift
protocol DrawEnginePort: Sendable {
    func availableConstraints() -> [ConstraintDescriptor]
    func validate(_ setup: DrawSetup) -> [SetupIssue]
    func run(setup: DrawSetup, seed: UInt64) async throws -> DrawRun
}
```

Zwei Dateien sind als temporaer markiert und verschwinden beim Zusammenfuehren:

- `Support/DomainStubs.swift` - minimale Stubs von `Team`, `Pot`, `Association`,
  `Matchup`, `Venue`, damit die App vor Fertigstellung der Engine kompiliert.
- `Support/MockDrawEngine.swift` - ein Fake, der ein strukturell gueltiges
  Ergebnis erzeugt (8 Gegner je Team, 2 pro Topf, 4 Heim / 4 Auswaerts), aber
  bewusst **keine** Association-Regeln implementiert.

Der Wechsel auf die echte Engine ist eine Aenderung an einer Stelle:
`AppModel(engine:)` in `Shell/UEFADrawApp.swift`.

## Erwartungen an die Engine

1. `run` gibt den tatsaechlich verwendeten Seed zurueck, auch wenn er zufaellig
   gewaehlt wurde. Sonst ist ein Ergebnis nicht teilbar und der Replay nicht
   reproduzierbar.
2. Der Trace enthaelt abgelehnte Kandidaten mit fertig formuliertem
   Begruendungstext. `architecture.md` sagt das bereits zu. Es ist die
   Voraussetzung fuer das Erfolgskriterium aus `vision.md` ("zeigt
   nachvollziehbar, warum ein Matchup erlaubt oder gesperrt ist").
3. Constraints sind oeffentlich deklariert (id, Titel, Erklaertext).
4. Die Setup-Validierung ist eine oeffentliche Funktion.

Punkt 2 beruehrt die Signatur des Algorithmus und sollte frueh abgestimmt
werden. Die uebrigen Punkte sind additive API-Oberflaeche.

Faellt Punkt 2 weg, bleibt die App funktionsfaehig: der Sequencer faellt auf die
reinen Paarungen zurueck und zeigt die Auslosung ohne Erklaerung. Die App baut
die Begruendung dann **nicht** selbst nach.

## Tests

`Apps/UEFADrawApp/Sources/Tests/` enthaelt XCTest-Dateien fuer die
Praesentationslogik: Sequencer-Vollstaendigkeit, Reducer-Korrektheit und
Playback-Steuerung (Pause haelt den Cursor, Tempo aendert nie die Reihenfolge,
Replay ist identisch).

Nicht getestet werden Constraint-Erfuellung, Verbands-Verteilung und
Algorithmus-Korrektheit - das sind die seeded Tests der Engine.
