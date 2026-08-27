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

### 6. Sprache im Code

`AGENTS.md` verlangt moeglichst ASCII. Das gilt hier fuer Kommentare,
Bezeichner und Dokumentation. **Sichtbare Texte in der App verwenden echte
Umlaute**, weil "Spielplaene" auf dem Bildschirm schlicht falsch aussieht.

Pruefbar: Nicht-ASCII darf ausschliesslich innerhalb von String-Literalen
auftreten, nie in einem Kommentar oder Bezeichner.

### 7. Optik nach draw-style.md

`Resources/Design/draw-style.md` gibt die Richtung vor: tiefes UEFA-Blau,
Neon-Akzente, runde Formen, hoher Kontrast, "keine flachen Standard-Layouts".
Umgesetzt in `Tokens` und `DrawBackground`:

- **Festgelegt auf Dunkel.** `preferredColorScheme(.dark)` in `UEFADrawApp`.
  Die Farben sind gesetzt und folgen nicht dem Systemschema - der Entwurf
  verlangt ausdruecklich keine hellgrauen Systemscreens.
- **Vier Neonfarben, vier Toepfe**: Cyan, Magenta, Gelb, Gruen. Die Zuordnung
  steckt in `Tokens.potColor(_:)`, sonst nirgends.
- **Linienmuster**: `DrawBackground` zeichnet konzentrische Boegen um einen
  Punkt oberhalb des Bildschirms und nimmt die Farbe des offenen Topfs auf.
  Bewusst statisch - eine Animation im Dauerhintergrund waere Ablenkung.
- **Flaechen zurueckhaltend, Linien hell**: Karten sind `Brand.surface`
  (Weiss bei 6,5 %) mit farbiger Kontur. Das Neon liegt auf Konturen, Schrift
  und Abzeichen, nicht auf grossen Flaechen.
- **Systemflaechen ausblenden**: `brandScreenBackground()` setzt
  `scrollContentBackground(.hidden)`; Form- und List-Zeilen bekommen
  `listRowBackground(Tokens.Brand.surface)`.

### 8. Vereinswappen

Die 36 Wappen aus `Resources/Design/teams/` liegen im Asset-Katalog unter dem
Namensraum `TeamLogos`. `TeamLogoView` zeichnet sie und faellt auf das
Verbandskuerzel zurueck, wenn kein Wappen hinterlegt ist.

Die Bilder sind aus einer Montage geschnitten und nur rund 71 px hoch. Sie
sind deshalb als **3x** deklariert und tragen bis etwa 28 pt sauber - in der
Loskugel bewusst nur 54 pt, darueber wuerden sie weich.

`Team.logoName` ist optional: selbst angelegte Teams im Setup kommen ohne
Wappen aus.

### Wortmarke und App-Icon

`uefa-champions-league-logo.svg` liegt als Vektor-Bildsatz
`ChampionsLeagueLogo` im Katalog, auf `template` gestellt und damit
einfaerbbar - im Original ist die Marke dunkelblau und waere auf dem dunklen
Grund unsichtbar. `CompetitionMark` zeichnet sie im Setup-Kopf und im
Ladezustand der Auslosung.

Das App-Icon ist aus derselben Vorlage erzeugt: `Resources/Design`-SVG,
weiss eingefaerbt, auf dem Blauverlauf mit denselben konzentrischen Boegen
wie `DrawBackground`. Neu erzeugen laesst es sich mit einem kurzen
AppKit-Skript (`NSImage` liest SVG ab macOS 13); die 1024er PNG liegt fertig
im Katalog.

Nicht verwendet werden `uefa-2026-27-team-badges.webp` und
`team-logo-contact-sheet.png` - das sind die Quellen, aus denen die
Einzelwappen geschnitten wurden.

> Rechtehinweis: `Resources/Design/README.md` weist die UEFA-Marken und die
> Clubwappen als geschuetzt aus und den Ordner als Entwicklungsreferenz. Fuer
> eine Veroeffentlichung der App waere das gesondert zu klaeren.

### 9. Bewegung

Regeln, die im Code als `Tokens.Motion` festgehalten sind:

- Dauern unter 300 ms; nur die Enthuellung selbst darf laenger tragen.
- Eintritt nie aus `scale(0)` - gestartet wird bei 0,94 plus Deckkraft.
- Austritt schneller als Eintritt (`revealTransition` ist asymmetrisch).
- Druckfeedback ueber `PressableButtonStyle` bzw. die System-Button-Styles.
- `accessibilityReduceMotion` wird respektiert: Deckkraft bleibt, Verschiebung
  und Skalierung fallen weg. `Tokens.Motion.respecting(_:_:)` kapselt das.

## Xcode-Projekt

Das `.xcodeproj` wird mit XcodeGen aus `Apps/UEFADrawApp/project.yml` erzeugt
und ist damit reproduzierbar und diff-freundlich:

```
cd Apps/UEFADrawApp
xcodegen generate
open UEFADrawApp.xcodeproj
```

Targets:

- `UEFADrawApp` - iOS-App, Deployment Target 17.0, haengt am `DrawEngine`-Package
  im Repo-Wurzelverzeichnis
- `UEFADrawAppTests` - Unit-Tests aus `Sources/Tests`

`SWIFT_STRICT_CONCURRENCY` steht auf `complete`; der Code ist warnungsfrei.

Aenderungen an der Projektstruktur gehoeren in `project.yml`, nicht ins
generierte Projekt.

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
