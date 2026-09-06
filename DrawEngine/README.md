# DrawEngine

Swift-Package mit der vollstaendigen Fachlogik einer UEFA-Champions-League-
Auslosung im Swiss-Model: 36 Teams, vier Toepfe, 144 Paarungen, deterministisch
ueber einen Seed.

Dieses README richtet sich an **Integratoren** - an den Entwickler oder Agenten,
der das Package als Dependency einbindet. Es beantwortet die Integration
vollstaendig; der Engine-Quellcode muss dafuer nicht gelesen werden.

Die Regeln, Annahmen und der Algorithmus stehen in
[`Docs/draw-regeln.md`](Docs/draw-regeln.md).

---

## 1. Was das Package ist - und was es nicht tut

**Es ist** eine reine, testbare Fachlogik-Bibliothek. Eingang: 36 Teams und ein
Seed. Ausgang: die 144 Paarungen inklusive Heimrecht sowie eine Ereignisliste,
mit der eine Oberflaeche die Auslosung Schritt fuer Schritt nachspielen kann.

**Es tut bewusst nicht:**

- **Keine UI.** Kein SwiftUI, kein UIKit, keine Views, keine ViewModels.
- **Kein Foundation.** Das Package importiert ausschliesslich die Standard-
  bibliothek. Kein `Date`, kein `URL`, kein `JSONEncoder`.
- **Keine Persistenz und kein Netzwerk.** Nichts wird geladen, gespeichert oder
  gesendet.
- **Keine Nebenlaeufigkeit.** Kein `async`, keine Tasks, kein globaler Zustand.
- **Keine Setzlisten-Berechnung.** Die Topfzuordnung ist Eingabe, kein Ergebnis.

---

## 2. Einbindung als lokale SPM-Dependency

Das Package liegt im Repository unter `DrawEngine/`. Es hat keine externen
Abhaengigkeiten.

| | |
| --- | --- |
| swift-tools-version | 6.0 |
| Sprachmodus | Swift 6 |
| Plattformen | iOS 17+, macOS 14+ |
| Produkt | `.library(name: "DrawEngine")` |
| Abhaengigkeiten | keine |

### In einem SPM-Paket

```swift
// Package.swift der App
let package = Package(
    name: "App",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(path: "../DrawEngine"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "DrawEngine", package: "DrawEngine"),
            ]
        ),
    ]
)
```

Der Pfad ist relativ zum `Package.swift` der App. Liegt das App-Paket direkt im
Repo-Root, lautet er `"./DrawEngine"`.

### In einem Xcode-Projekt

1. **File > Add Package Dependencies...**
2. Unten links **Add Local...** waehlen
3. Den Ordner `DrawEngine` auswaehlen
4. Beim App-Target unter **Frameworks, Libraries, and Embedded Content** die
   Bibliothek `DrawEngine` hinzufuegen

### Import

```swift
import DrawEngine
```

---

## 3. Oeffentliche API

Alle Signaturen sind woertlich aus dem Quellcode uebernommen. Alles hier
Aufgefuehrte ist `public`; alles andere im Package ist `internal` und geht den
Integrator nichts an.

### Stammdaten

```swift
public struct TeamID: RawRepresentable, Hashable, Comparable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String)
    public init(_ value: String)          // Kurzform: TeamID("FCB")
}

public struct Association: RawRepresentable, Hashable, Comparable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String)
    public init(_ value: String)          // Kurzform: Association("GER")
}

public enum Pot: Int, CaseIterable, Hashable, Comparable, Sendable, Codable {
    case pot1 = 1
    case pot2
    case pot3
    case pot4
}

public struct Team: Hashable, Identifiable, Sendable, Codable {
    public let id: TeamID
    public let name: String
    public let association: Association
    public let pot: Pot
    public init(id: TeamID, name: String, association: Association, pot: Pot)
}
```

`TeamID`, `Association` und `Pot` kodieren als **einfache Werte**, nicht als
verschachtelte Objekte: eine `TeamID` wird zu `"FCB"`, ein `Pot` zu `1`.

### Ergebnis

```swift
/// Eine gerichtete Paarung: `home` empfaengt `away`.
public struct Matchup: Hashable, Sendable, Codable {
    public let home: TeamID
    public let away: TeamID
    public init(home: TeamID, away: TeamID)
}

public struct DrawResult: Equatable, Sendable {
    public let seed: UInt64
    public let teams: [Team]        // 36, sortiert nach (pot, id)
    public let matches: [Matchup]   // 144, sortiert nach (home, away) in Team-Ordnung
    public let events: [DrawEvent]  // 190, in Auftrittsreihenfolge

    public init(seed: UInt64, teams: [Team], matches: [Matchup], events: [DrawEvent])

    /// Alle acht Paarungen, an denen das Team beteiligt ist.
    public func matches(involving id: TeamID) -> [Matchup]

    /// Die beiden Gegner des Teams aus diesem Topf, aufsteigend sortiert.
    public func opponents(of id: TeamID, in pot: Pot) -> [TeamID]

    /// Die vier Heimspiele des Teams, Reihenfolge wie in `matches`.
    public func homeMatches(of id: TeamID) -> [Matchup]

    /// Die vier Auswaertsspiele des Teams, Reihenfolge wie in `matches`.
    public func awayMatches(of id: TeamID) -> [Matchup]
}
```

**Hinweis:** `DrawResult` und `DrawEvent` sind **nicht** `Codable`. Wer ein
Ergebnis speichern will, serialisiert `matches` und `teams` einzeln oder legt
einen eigenen DTO an.

### Ereignisse

```swift
public enum DrawEvent: Hashable, Sendable {
    case drawStarted(seed: UInt64)
    case potStarted(Pot)
    case teamDrawn(team: TeamID, pot: Pot)
    case matchRevealed(drawnTeam: TeamID, opponent: TeamID, opponentPot: Pot, drawnTeamPlaysHome: Bool)
    case potCompleted(Pot)
    case drawCompleted
}
```

Details in Abschnitt 5.

### Engine

```swift
public struct DrawEngine: Sendable {

    public struct Configuration: Sendable {
        /// Obergrenze fuer die Anzahl ausprobierter Kantenplatzierungen.
        public var maxSearchNodes: Int
        public init(maxSearchNodes: Int = 2_000_000)
    }

    public let configuration: Configuration
    public init(configuration: Configuration = .init())

    /// Fuehrt eine vollstaendige Auslosung durch.
    public func draw(teams: [Team], seed: UInt64) throws(DrawError) -> DrawResult
}
```

`maxSearchNodes` ist **kein Tuning-Parameter**, sondern eine Reissleine gegen
pathologische Eingaben. Bei einem realistischen Feld liegt der gemessene Aufwand
zwischen 144 und 190 Knoten. Die Voreinstellung passt fuer den Regelfall.

### Fehler

```swift
public enum DrawError: Error, Hashable, Sendable {
    case wrongTeamCount(actual: Int)
    case wrongPotSize(pot: Pot, actual: Int)
    case duplicateTeamID(TeamID)
    case infeasibleAssociationDistribution(association: Association, reason: InfeasibilityReason)
    case unsolvable
    case searchBudgetExceeded(exploredNodes: Int)
}

public enum InfeasibilityReason: Hashable, Sendable {
    case tooManyTeamsTotal(count: Int)                  // mehr als 7 Teams je Association
    case tooManyTeamsInPot(pot: Pot, count: Int)        // mehr als 4 Teams je Association und Topf
    case potPairOverflow(potA: Pot, potB: Pot, total: Int) // zwei Toepfe zusammen mehr als 9
}
```

Details in Abschnitt 7.

### Nachpruefung

```swift
public enum RuleViolation: Hashable, Sendable {
    case wrongMatchCount(actual: Int)
    case pairPlayedTwice(TeamID, TeamID)
    case teamPlaysItself(TeamID)
    case wrongOpponentCount(team: TeamID, pot: Pot, actual: Int)
    case sameAssociationPairing(TeamID, TeamID)
    case associationCapExceeded(team: TeamID, association: Association, count: Int)
    case homeAwayImbalance(team: TeamID, pot: Pot, home: Int, away: Int)
    case unknownTeam(TeamID)
}

public enum DrawValidator {
    /// Prueft ein Ergebnis gegen alle Fachregeln. Leer bedeutet regelkonform.
    public static func violations(matches: [Matchup], teams: [Team]) -> [RuleViolation]
}
```

Ein Ergebnis aus `DrawEngine.draw` ist immer regelkonform - die Pruefung laeuft
intern bereits als Debug-Selbstcheck. `DrawValidator` ist fuer **fremde** oder
von Hand veraenderte Ergebnisse gedacht, etwa in einer Debug-Ansicht oder in
Tests. Er bricht nicht beim ersten Fund ab, sondern sammelt alle Verstoesse in
einer festen, deterministischen Reihenfolge.

### Zufallsgenerator

```swift
public struct SplitMix64: RandomNumberGenerator, Sendable {
    public private(set) var state: UInt64
    public init(seed: UInt64)
    public mutating func next() -> UInt64
    public mutating func uniform(upperBound: UInt64) -> UInt64
    public mutating func uniform(upperBound: Int) -> Int
}
```

Oeffentlich, damit eine Oberflaeche denselben deterministischen Generator
verwenden kann - etwa fuer ein zufaelliges Testfeld, das bei gleichem Seed
reproduzierbar bleibt. Fuer die Auslosung selbst wird er nicht gebraucht;
`draw(teams:seed:)` erzeugt seine Generatoren selbst.

---

## 4. Minimalbeispiel Ende zu Ende

```swift
import DrawEngine

// 36 Teams: neun je Topf, eindeutige IDs, hoechstens sieben je Association.
let teams: [Team] = [
    Team(id: TeamID("FCB"), name: "FC Bayern",  association: Association("GER"), pot: .pot1),
    Team(id: TeamID("RMA"), name: "Real Madrid", association: Association("ESP"), pot: .pot1),
    // ... insgesamt 36
]

do {
    let result = try DrawEngine().draw(teams: teams, seed: 42)

    result.matches          // 144 Paarungen, kanonisch sortiert
    result.events           // 190 Ereignisse, Reveal-Sequenz fuer die Anzeige
    result.teams            // 36 Teams, sortiert nach (pot, id)
    result.seed             // 42

    // Bequeme Abfragen fuer eine Detailansicht
    result.matches(involving: TeamID("FCB"))            // 8 Paarungen
    result.opponents(of: TeamID("FCB"), in: .pot1)      // 2 TeamIDs
    result.homeMatches(of: TeamID("FCB"))               // 4 Paarungen
    result.awayMatches(of: TeamID("FCB"))               // 4 Paarungen
} catch {
    // `error` ist dank Typed Throws direkt ein DrawError - kein Casting noetig.
    print(error)
}
```

Die Reihenfolge des uebergebenen Arrays spielt keine Rolle. `result.teams` ist
immer kanonisch nach `(pot, id)` sortiert, `result.matches` in derselben
Ordnung.

---

## 5. Events fuer eine schrittweise Darstellung

`result.events` ist die vollstaendige Anleitung, um die Auslosung zu
animieren - ohne Ratespiel und ohne eigene Fachlogik in der View.

### Garantierte Reihenfolge

```
drawStarted(seed:)
  potStarted(.pot1)
    teamDrawn(team:pot:)          <- neun Mal je Topf, in gemischter Ziehreihenfolge
      matchRevealed(...)          <- null bis acht Mal je gezogenem Team
    ...
  potCompleted(.pot1)
  potStarted(.pot2) ... potCompleted(.pot2)
  potStarted(.pot3) ... potCompleted(.pot3)
  potStarted(.pot4) ... potCompleted(.pot4)
drawCompleted
```

Zugesichert ist:

- Das erste Ereignis ist immer `.drawStarted(seed:)`, das letzte immer
  `.drawCompleted`.
- Die Toepfe kommen in der Reihenfolge `pot1, pot2, pot3, pot4` und jeder genau
  einmal. Jedes `.potStarted` hat sein `.potCompleted`; die Klammern
  verschachteln sich nicht.
- Zwischen `.potStarted(p)` und `.potCompleted(p)` stehen genau neun
  `.teamDrawn`-Ereignisse mit `pot == p`, jedes Team genau einmal. Ueber alle
  Toepfe sind es 36.
- Jedes `.matchRevealed` gehoert zum zuletzt vorangegangenen `.teamDrawn`; sein
  `drawnTeam` ist immer dieses Team.
- Die Liste hat immer **190** Ereignisse: `1 + 2 x 4 + 36 + 144 + 1`.

### Jede Paarung erscheint genau einmal

Eine Begegnung hat zwei Beteiligte, aber nur einen Auftritt: Sie wird bei dem
der beiden Teams enthuellt, das **zuerst** gezogen wird. Beim zweiten Team ist
sie schon bekannt und wird uebersprungen.

Praktische Folge fuer die Animation: Das erste gezogene Team enthuellt alle acht
Paarungen, das letzte keine einzige. Die 144 `matchRevealed`-Ereignisse
verteilen sich also sehr ungleichmaessig auf die 36 Bloecke. Eine feste
Schrittdauer je Reveal fuehrt zu stark unterschiedlich langen Bloecken - das ist
korrekt und beabsichtigt, sollte im Timing der Oberflaeche aber eingeplant sein.

### Reihenfolge innerhalb eines Team-Blocks

Fest, nicht zufaellig:

1. **Gegner-Topf aufsteigend** - erst die Gegner aus Topf 1, zuletzt die aus
   Topf 4.
2. **Innerhalb eines Gegner-Topfes zuerst das Heimspiel** des gezogenen Teams,
   danach das Auswaertsspiel.

Uebersprungene (bereits enthuellte) Paarungen fallen aus dieser Folge einfach
heraus; die relative Ordnung der verbleibenden bleibt erhalten.

### Heimrecht aus dem Event lesen

`drawnTeamPlaysHome` gilt immer aus Sicht des **gezogenen** Teams:

```swift
case let .matchRevealed(drawnTeam, opponent, opponentPot, drawnTeamPlaysHome):
    let matchup = drawnTeamPlaysHome
        ? Matchup(home: drawnTeam, away: opponent)
        : Matchup(home: opponent,  away: drawnTeam)
    // `matchup` ist exakt einer der Eintraege aus result.matches
```

`opponentPot` ist der Topf des Gegners und muss nicht nachgeschlagen werden.

### Konsistenz mit `result.matches`

Die aus den 144 `matchRevealed`-Ereignissen rekonstruierte Menge ist **exakt**
`Set(result.matches)` - keine Paarung fehlt, keine kommt doppelt vor, keine ist
gegenlaeufig orientiert. Beide Sichten beschreiben dasselbe Ergebnis; `matches`
ist die kanonisch sortierte Endansicht, `events` die Praesentationsreihenfolge.
Die Oberflaeche kann also waehrend der Animation aus den Events aufbauen und am
Ende gegen `matches` austauschen, ohne dass etwas springt.

---

## 6. Threading und Nebenlaeufigkeit

- **Alle oeffentlichen Typen sind `Sendable`** - `Team`, `TeamID`,
  `Association`, `Pot`, `Matchup`, `DrawResult`, `DrawEvent`, `DrawError`,
  `InfeasibilityReason`, `RuleViolation`, `DrawEngine`,
  `DrawEngine.Configuration`, `SplitMix64`. Alles sind Value-Types ohne
  Referenzen; sie lassen sich frei ueber Aktor-Grenzen reichen.
- **`draw(teams:seed:)` ist eine reine Funktion.** Kein globaler Zustand, keine
  Statics mit Schreibzugriff, kein Caching. Zwei parallele Aufrufe beeinflussen
  sich nicht.
- **Kein `async`, kein `await`.** Der Aufruf ist synchron und blockiert.
- **Kein Aktor-Isolationsbedarf.** `DrawEngine` kann als `let` in einer View, in
  einem ViewModel oder als lokale Variable liegen.

**Laufzeit**, gemessen auf einem Apple-Silicon-Mac ueber 1000 Draws mit einem
realistischen 36er-Feld:

| Build | je Draw |
| --- | --- |
| Release | rund **0,26 ms** |
| Debug | rund **10,6 ms** (enthaelt den Debug-only-Selbstcheck des Validators) |

Beides ist unterhalb eines Frames. Ein Aufruf direkt aus dem Main-Actor heraus
ist unbedenklich; ein Auslagern auf einen Hintergrund-Task ist nicht noetig.

---

## 7. Fehlerbehandlung

`draw(teams:seed:)` nutzt Typed Throws, `catch` liefert also direkt einen
`DrawError`.

| Fall | Ursache | Sinnvolle Reaktion in der UI |
| --- | --- | --- |
| `wrongTeamCount(actual:)` | nicht genau 36 Teams | Setup-Ansicht: fehlende oder ueberzaehlige Teams anzeigen |
| `wrongPotSize(pot:actual:)` | ein Topf hat nicht neun Teams | den genannten Topf markieren |
| `duplicateTeamID(_:)` | zwei Teams mit derselben ID | die genannte ID hervorheben |
| `infeasibleAssociationDistribution(association:reason:)` | zu viele Teams eines Verbands (insgesamt, je Topf oder je Topfpaar) | Verband und Grund im Klartext anzeigen; die Eingabe muss geaendert werden |
| `unsolvable` | formal gueltig, aber beweisbar keine Loesung | Ein neuer Seed hilft **nicht**. Der Nutzer muss das Feld aendern. |
| `searchBudgetExceeded(exploredNodes:)` | Knotenbudget aufgebraucht | Unloesbarkeit ist **nicht** bewiesen. Neuer Seed oder hoeheres `maxSearchNodes`. |

Die ersten vier Faelle stammen aus der Vorpruefung und treten auf, bevor
irgendetwas gerechnet wird. Sie beziehen sich immer auf die **Eingabe** und
lassen sich in der Setup-Ansicht direkt zuordnen.

Der Unterschied zwischen den letzten beiden ist wichtig:

- **`unsolvable`** ist eine Aussage ueber die Eingabe. Der Suchraum wurde
  vollstaendig durchlaufen, die Unloesbarkeit ist bewiesen. Ein anderer Seed
  aendert nur die Reihenfolge des Durchlaufs, nicht sein Ergebnis - ein
  "Nochmal"-Knopf ist hier die falsche Antwort.
- **`searchBudgetExceeded`** ist eine Aussage ueber die Suche, nicht ueber die
  Eingabe. Es kann eine Loesung geben, die innerhalb des Budgets nicht gefunden
  wurde. Hier ist ein Neuversuch sinnvoll. Bei einem realistischen Feld tritt
  der Fall nicht auf.

```swift
do {
    let result = try DrawEngine().draw(teams: teams, seed: seed)
    // ...
} catch .wrongTeamCount(let anzahl) {
    zeige("Es werden 36 Teams gebraucht, angegeben sind \(anzahl).")
} catch .wrongPotSize(let topf, let anzahl) {
    zeige("Topf \(topf.rawValue) enthaelt \(anzahl) statt 9 Teams.")
} catch .duplicateTeamID(let id) {
    zeige("Die Kennung \(id.rawValue) kommt mehrfach vor.")
} catch .infeasibleAssociationDistribution(let verband, _) {
    zeige("Der Verband \(verband.rawValue) ist zu stark vertreten.")
} catch .unsolvable {
    zeige("Fuer dieses Teilnehmerfeld existiert keine gueltige Auslosung.")
} catch .searchBudgetExceeded {
    zeige("Die Suche wurde abgebrochen. Bitte mit einem anderen Seed erneut versuchen.")
}
```

---

## 8. Determinismus-Vertrag

**Dieselbe Team-Menge und derselbe Seed erzeugen immer dasselbe `DrawResult`** -
identische Paarungen, identisches Heimrecht und identische Ereignisliste in
identischer Reihenfolge, unabhaengig von der Reihenfolge des uebergebenen Arrays,
ueber Prozesslaeufe und ueber Debug wie Release hinweg. Moeglich wird das durch
eine kanonische Team-Sortierung nach `(pot, id)`, einen eigenen SplitMix64 statt
der nicht versionsstabilen Stdlib-Zufalls-APIs und den vollstaendigen Verzicht
auf Iteration ueber `Set` und `Dictionary`.

Abgesichert ist der Vertrag durch einen Golden-Master-Test, der fuer Seed 42 das
konkrete Ergebnis festschreibt. Ein gespeicherter Seed bleibt damit ueber
Commits und Compiler-Versionen hinweg gueltig; eine Aenderung am Verfahren faellt
sofort auf und ist ein bewusster Breaking Change.

Die ausfuehrliche Begruendung und die Absicherung durch Tests stehen in
[`Docs/draw-regeln.md`](Docs/draw-regeln.md), Abschnitt 3.

---

## 9. Build und Test

```bash
cd DrawEngine
swift build
swift test
```

Getestet wird mit **Swift Testing** (`import Testing`, `@Test`, `#expect`,
`#require`, `@Suite`), nicht mit XCTest. Die Suiten decken jede Schicht einzeln
ab: `SplitMix64 und deterministischer Shuffle`, `InputValidation`,
`DrawContext`, `OpponentMatcher`, `HomeAwayOrienter`, `EventSequencer`,
`DrawValidator`, `DrawEngine`, `Unloesbare Eingaben und Suchbudget` sowie
`DrawEngine: Ende-zu-Ende`.

Fuer eine Laufzeitmessung lohnt der Release-Build:

```bash
swift build -c release
```

---

## 10. Weiterfuehrende Dokumente

- [`Docs/draw-regeln.md`](Docs/draw-regeln.md) - Regelmenge, Annahmen,
  Determinismus-Vertrag, Algorithmus, Fehlerfaelle, offene Fragen
- `../AGENTS.md` - Arbeitsregeln des Repositories
- `../docs/architecture.md` - Zielarchitektur der App
- `../docs/roadmap.md` - Phasen und offene Fragen des Gesamtprojekts
