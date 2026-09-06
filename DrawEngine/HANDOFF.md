# DrawEngine (UEFA-Auslosung) - Session-Handoff

_Stand: 2026-09-06, nach dem Merge. Die Bau-Session hat die komplette Auslosungs-Engine als
eigenstaendiges Swift-Package gebaut, adversarial pruefen lassen, einen dabei gefundenen
Blocker behoben und das Ergebnis unabhaengig verifiziert. Eine Folge-Session hat den Stand
nachgemessen, PR #1 nach `main` gemergt und dabei festgestellt, dass parallel die komplette
SwiftUI-App entstanden ist. **Engine und App liegen jetzt nebeneinander auf `main`, aber sie
sind noch nicht verbunden** - siehe Abschnitt 5 und 5a._

## 1. Worum es geht

Fuer eine geplante SwiftUI-App, die eine UEFA-Champions-League-Auslosung (Swiss-Model)
simuliert, wurde der Simulationskern gebaut: Models, Regelpruefung, Auslosungsalgorithmus
mit Backtracking, Heim/Auswaerts-Verteilung, Event-Sequenz fuer die UI, deterministische
Tests mit Seed.

- **Repo:** `https://github.com/nyko073006/uefa-auslosung`
- **Lokal:** `/Users/nyko/Documents/GitHub/uefa-auslosung`
- **Package:** `/Users/nyko/Documents/GitHub/uefa-auslosung/DrawEngine`
- **Branch:** `main`. `feature/draw-engine` ist ueber PR #1 gemergt und bleibt als
  Arbeitsbranch fuer Engine-Aenderungen bestehen.
- **Commits:** `c1aaba5` (Engine, 28 Dateien, 7.074 Zeilen), gemergt als `b5e5967`
- **Stack:** Swift 6.3.1, swift-tools-version 6.0, Swift-6-Language-Mode,
  Test-Framework **Swift Testing** (kein XCTest), keine Dependencies, kein Foundation-Import

Das Repo war vorher ein reines Orchestrierungs-Repo (nur Markdown). Die Engine erfuellt
Phase 2 der `docs/roadmap.md` ("Simulationskern").

## 2. Fertig und verifiziert

Die Engine ist vollstaendig. **121 Tests gruen** in Debug und Release.

Umgesetzte Regelmenge (genau diese sechs, keine weiteren):
36 Teams in 4 Toepfen a 9; je Team 8 Gegner, genau 2 aus jedem Topf inklusive dem eigenen;
Paarungen symmetrisch (144 Matches); keine Verbandsduelle; hoechstens 2 Gegner je Verband;
je Topf genau 1 Heim- und 1 Auswaertsspiel (gesamt 4/4).

Eigene, unabhaengige Verifikation (nicht nur die Testsuite - siehe Abschnitt 6, warum das
noetig war). Pruefprogramm lag unter
`/private/tmp/claude-501/-Users-nyko/e6a8a156-72dd-4d96-9245-46c34baade7d/scratchpad/verify`
(Scratchpad, vermutlich inzwischen geloescht; bei Bedarf neu bauen - es bindet das Package
ueber `.package(path: "DrawEngine")` ein und nutzt eine BEWUSST eigenstaendig geschriebene
Regelpruefung, nicht `DrawValidator`):

| Pruefung | Umfang | Ergebnis |
|---|---|---|
| Regeltreue, Verbandsdichte 4 bis 7 | 440 Auslosungen | 0 Verstoesse |
| Faelschlich "unloesbar" gemeldet | 92 unsolvable-Faelle mit 50 Mio. Knoten gegengeprueft | 0 |
| Determinismus ueber Prozessgrenzen | 25 separate Prozesse | byteidentisch |
| Debug gegen Release | Fingerabdruck ueber Matches und Events | identisch |
| Input-Reihenfolge | 60 Permutationen | 0 Abweichungen |

## 3. Aufbau und wichtige Dateien

Drei Phasen: A verteilt die Paarungen, B orientiert Heim/Auswaerts, C erzeugt die
Reveal-Sequenz fuer die UI.

| Datei (unter `DrawEngine/`) | Zweck |
|---|---|
| `Sources/DrawEngine/Engine/DrawEngine.swift` | **Einzige oeffentliche Einstiegs-API.** `draw(teams:seed:) throws(DrawError) -> DrawResult`. Orchestriert A/B/C, leitet drei getrennte Sub-Seeds ab. |
| `Sources/DrawEngine/Engine/OpponentMatcher.swift` | **Herzstueck.** Phase A: Backtracking mit explizitem Frame-Stack, MRV-Heuristik, globalem Forward-Checking, Neustarts mit wachsendem Budget. Hier sass der Blocker (Abschnitt 6). |
| `Sources/DrawEngine/Engine/HomeAwayOrienter.swift` | Phase B: Kreiszerlegung der 2-regulaeren Topfpaar-Teilgraphen, jeder Kreis gerichtet orientiert. Nach Phase A immer loesbar, auch bei ungeraden Kreisen. |
| `Sources/DrawEngine/Engine/EventSequencer.swift` | Phase C: Reveal-Sequenz (Topf 1 bis 4, Team-Ziehreihenfolge per RNG, je Team die noch nicht enthuellten Paarungen). |
| `Sources/DrawEngine/Engine/InputValidation.swift` | Strukturpruefung plus drei notwendige Feasibility-Schranken (max. 7 Teams je Verband gesamt, max. 4 je Topf, Topfpaar-Summe <= 9), jeweils mit Herleitung im Kommentar. |
| `Sources/DrawEngine/Engine/DrawContext.swift` | Interne Index-Repraesentation. Kanonisiert Teams nach `(pot, id)` - dadurch ist das Ergebnis unabhaengig von der Input-Reihenfolge. |
| `Sources/DrawEngine/Random/SplitMix64.swift` | Eigener RNG plus unbiased `uniform(upperBound:)`. |
| `Sources/DrawEngine/Random/Shuffle.swift` | Eigener Fisher-Yates. |
| `Sources/DrawEngine/Validation/DrawValidator.swift` | Oeffentliche, **bewusst naive** Nachpruefung eines fertigen Ergebnisses gegen alle sechs Regeln. Nutzt nichts aus dem Suchzustand - das macht ihn als Kontrollinstanz erst wertvoll. |
| `Sources/DrawEngine/Models/` | `Team`, `TeamID`, `Association`, `Pot`, `Matchup`, `DrawEvent`, `DrawResult`, `DrawError`, `InfeasibilityReason`. Value-Types, `Sendable`, `Codable`. |
| `Tests/DrawEngineTests/DenseFieldTests.swift` | **Wichtigste Testdatei.** Dicht besetzte Felder inklusive des echten Feldes 2025/26. Ohne sie waere der Blocker unsichtbar. |
| `Tests/DrawEngineTests/Fixtures.swift` | `realistic36`, `ligaphase2526`, `ligaphase2425`, `dense5`, `unsolvableDense`, Builder `makeTeams(potLayout:)`. |
| `Tests/DrawEngineTests/UnsolvableInputTests.swift` | Beweisbar unloesbares Feld, das alle billigen Vorpruefungen besteht. Beweis steht als Kommentar in der Datei. |
| `README.md` | Package-README, geschrieben FUER DEN INTEGRATOR (den SwiftUI-Agenten): API-Referenz, SPM-Einbindung, Event-Reihenfolge. |
| `Docs/draw-regeln.md` | Vollstaendige Regel- und Algorithmus-Dokumentation, Annahmen, Determinismus-Vertrag, Fehlerfaelle. |

## 4. Bauen und testen

```bash
cd /Users/nyko/Documents/GitHub/uefa-auslosung/DrawEngine
swift build
swift test            # 121 Tests, dauert rund 25 s (das echte Feld ueber 300 Seeds kostet ~22 s)
swift test -c release
```

Einbindung in die App (so wird der SwiftUI-Agent es tun, ist verifiziert):

```swift
.package(path: "../DrawEngine")   // bzw. in Xcode: Add Local Package
```

Nutzung:

```swift
let result = try DrawEngine().draw(teams: teams, seed: 42)
result.matches   // 144 Paarungen, kanonisch sortiert, mit Heim/Auswaerts
result.events    // Reveal-Sequenz fuer die schrittweise Darstellung
```

## 5. Wo wir stehen

> **Dieser Abschnitt ist am 2026-09-06 komplett neu geschrieben worden.** Der urspruengliche
> Text sagte "kein Pull Request geoeffnet" und "der App-Agent hat nichts im Repo abgelegt".
> Beides war zu dem Zeitpunkt schon falsch. Die Ursache ist lehrreich und steht als
> Fallstrick (h) in Abschnitt 6: der Stand war aus einem **veralteten `origin/main`**
> abgelesen, ohne vorher zu fetchen.

**PR #1 ist gemergt** (2026-09-06, Merge-Commit `b5e5967`). `main` traegt jetzt Engine und App.

**Der App-Agent war die ganze Zeit produktiv.** Auf `main` liegen neun Commits nach dem
initialen: die vollstaendige SwiftUI-Shell (Phase 3 der Roadmap) mit Setup-, Live- und
Ergebnis-Screens, Playback-Controller, Design-Tokens nach `draw-style.md`, App-Icon und den
Wappen aller 36 Teams unter `Apps/UEFADrawApp/`.

**Wichtig: Es gibt seit dem Merge zwei Dinge namens DrawEngine.**

| Pfad | Was es ist |
|---|---|
| `DrawEngine/` | Das **echte** Package aus diesem Handoff. swift-tools 6.0, Swift Testing, 121 Tests. |
| `Packages/DrawEngine/` | Ein **8-Zeilen-Platzhalter** (`isReady: Bool`) aus dem App-Geruest. Die Wurzel-`Package.swift` (swift-tools 5.10, XCTest) zeigt hierauf. |

**Die App laeuft heute nicht auf der echten Engine**, sondern auf `MockDrawEngine`
(231 Zeilen) hinter dem Protokoll `DrawEnginePort`. Beides steht in
`Apps/UEFADrawApp/Sources/Support/`.

Der App-Agent hat dabei sauber gearbeitet: Er hat **keine Regel nachgebaut**, sondern eine
Naht gezogen und sie beschriftet. `DrawEnginePort.swift` traegt den Hinweis "BEIM MERGE mit
feature/draw-engine: eine Adapter-Implementierung anlegen", `DomainStubs.swift` den Hinweis
"BEIM MERGE: diese Datei ersatzlos loeschen".

**Nachmessung auf `main` am 2026-09-06:** Beide Packages bauen und testen nebeneinander
ohne Stoerung. Wurzel-Package `swift build` sauber, 1 Stub-Test gruen. `DrawEngine/`
121 Tests gruen in 22,4 s. Die Zahlen aus Abschnitt 2 tragen weiterhin.

### 5a. Was die Zusammenfuehrung konkret verlangt

Der Adapter ist **nicht** nur Umbenennen. Vier Punkte, absteigend nach Aufwand:

1. **Ablehnungen.** `DrawEnginePort.run(setup:seed:)` gibt einen `DrawRun` mit
   `trace: [DrawTraceEntry]` zurueck, und `DrawTraceEntry.Outcome` kennt
   `.rejected(reason: String)`. **Die Engine liefert das nicht.** Sie findet eine
   vollstaendige Loesung; verworfene Kandidaten verlassen die Suche nie. Entweder die Engine
   bekommt Ablehnungs-Ereignisse, oder die Oberflaeche leitet die Begruendung selbst aus den
   Fachregeln ab. **Das ist eine Produktentscheidung und noch nicht getroffen** (steht als
   offene Frage in `docs/roadmap.md`). Ohne sie ist der Port nur teilweise bedienbar.
2. **Doppelte Typnamen.** `Team`, `Pot`, `Association`, `Matchup` und `Venue` gibt es in
   `DomainStubs.swift` **und** in `DrawEngine/Sources/DrawEngine/Models/`. Die Stubs nutzen
   `UUID` als `Team.ID`, die Engine einen eigenen `TeamID`. Die Stub-Datei faellt weg, die
   App importiert die Engine-Modelle, und die Views ziehen nach.
3. **Regeln als Daten.** Der Port verlangt `availableConstraints() -> [ConstraintDescriptor]`
   und `validate(_:) -> [SetupIssue]`. Die Engine hat dafuer keine oeffentliche
   Entsprechung. Bausteine sind da (`InputValidation`, `DrawError`, `InfeasibilityReason`),
   sie muessen nur nach aussen gereicht werden. Die sechs Regeltexte stehen in
   `Docs/draw-regeln.md` Abschnitt 1 und gehoeren in die Engine, nicht in die UI.
4. **Package-Umbau.** Die Wurzel-`Package.swift` muss auf das echte Package zeigen, der
   Platzhalter unter `Packages/DrawEngine/` verschwinden. Dabei von swift-tools 5.10 auf 6.0
   und von XCTest auf Swift Testing ziehen, sonst laufen zwei Testwelten nebeneinander.

`MockDrawEngine` danach nicht loeschen: Fuer SwiftUI-Previews ist ein schneller,
determinierter Mock weiterhin das richtige Werkzeug.

## 6. Fallstricke - bitte nicht erneut hineinlaufen

**(a) Der Blocker, der fast durchgerutscht waere.** Die Forward-Checks in `OpponentMatcher`
prueften urspruenglich nur das GERADE bearbeitete Topfpaar. Die Verbands-Obergrenze von 2
koppelt aber global ueber alle zehn Topfpaare. Folge: Auf dem echten Feld 2025/26 scheiterten
**63 von 300 Seeds** mit `searchBudgetExceeded`, obwohl das Feld loesbar ist - ein groesseres
Budget half nicht (auch 100 Mio. Knoten scheiterten). Behoben durch globales Forward-Checking
plus `globalAssociationCheckPasses()` plus Neustarts. **Diese drei Bestandteile nicht
zurueckbauen.** Wer am Matcher arbeitet: `DenseFieldTests` muss gruen bleiben.

**(b) Warum 111 gruene Tests den Blocker nicht sahen - die eigentliche Lehre.** Das
urspruengliche Fixture hatte hoechstens 2 Teams je Verband und Topf. Das echte Feld 2025/26
hat drei englische Teams allein in Topf 1 und sechs insgesamt. Genau in diesem Dichtebereich
kippt der Suchaufwand. Ein Testfeld, das die Realitaet unterschaetzt, produziert gruene Tests
ohne Aussagekraft. **Neue Tests immer auch gegen `Fixtures.ligaphase2526` laufen lassen.**

**(c) Determinismus ist fragil.** Im Produktivcode kommt **kein `Set` und kein `Dictionary`**
vor - der gesamte Suchzustand sind Arrays fester Groesse. Grund: Swift randomisiert
Hash-Seeds pro Prozesslauf, eine einzige Iteration ueber ein Set wuerde den Seed-Vertrag
still brechen, und zwar unsichtbar fuer jeden Test innerhalb eines einzelnen Prozesses.
Ebenso verboten: `shuffled(using:)`, `next(upperBound:)`, `random(in:)`, `randomElement()` -
die Stdlib garantiert deren Wertefolgen nicht ueber Swift-Versionen. Nur `SplitMix64` und
`deterministicShuffle`. **Determinismus nur ueber mehrere separate Prozesse pruefen**, sonst
misst man nichts.

**(d) Golden-Master-Pins.** In `DrawEngineE2ETests.swift` (Seed 42) und
`UnsolvableInputTests.swift` (`unsolvableExpectedNodes`) stehen gepinnte Werte. Jede Aenderung
am Algorithmus oder an der RNG-Nutzung verschiebt sie - das ist ein bewusster Breaking Change
am Determinismus-Vertrag und gehoert im Kommentar dokumentiert, nicht stillschweigend
aktualisiert.

**(e) SwiftPM-Lock bei parallelen Agenten.** Laufen mehrere Agenten im selben Package, blockieren
sie sich am `.build`-Lock ("Another instance of SwiftPM is already running..."). Ein eigener
Testlauf waehrend laufender Agenten wartet nicht nur, er blockiert sie auch. Bei
Parallelarbeit: Kopie ins Scratchpad, dort testen.

**(f) Workflow-Agenten stallen bei langen Kommandos.** Ein Verifikations-Workflow ist komplett
gescheitert (4 von 4 Agenten), weil die Auftraege Messreihen ueber 200 Felder und 2000
Auslosungen enthielten - Kommandos, die minutenlang ohne Ausgabe laufen, gelten als haengend.
Besonders tueckisch: Der Workflow meldete danach "keine Befunde", was nur hiess, dass es gar
keine Ergebnisse gab. **Solche Rueckgaben immer gegen `agents_done` pruefen.** Lange Messungen
in kleine Portionen schneiden.

**(g) `unsolvable` vs. `searchBudgetExceeded`.** Zwei bewusst getrennte Fehlerfaelle: Ersteres
heisst "Unloesbarkeit bewiesen, Suchraum erschoepft", Letzteres nur "abgebrochen". Vor dem Fix
trug diese Zusage nicht (unloesbare Felder liefen meist ins Budget). Jetzt schon. Beim Umbau
der Suche darauf achten, dass `.exhausted` wirklich nur bei erschoepftem Raum entsteht.

**(h) Bei parallelen Agenten ist der lokale Repo-Stand wertlos ohne `git fetch`.** Am
2026-09-06 stand `origin/main` lokal noch auf dem initialen Commit `9073356`. Daraus wurde
geschlossen und dem Nutzer gesagt, `main` sei leer und ein Merge folglich konfliktfrei.
Tatsaechlich lagen dort neun Commits mit der fertigen App. Erschwerend: `gh pr view` meldete
noch `MERGEABLE`/`CLEAN`, weil GitHub die Mergebarkeit zwischenspeichert - erst der
Merge-Versuch selbst schlug fehl. **Bei einem Repo, in dem ein zweiter Agent arbeitet, gilt
kein Stand als bekannt, der nicht unmittelbar vorher gefetcht wurde**, und
`mergeable: MERGEABLE` ist kein Beweis, sondern ein Zwischenstand.

## 7. Naechste Schritte

Die drei Punkte, die hier urspruenglich standen (PR oeffnen, Roadmap-Verweis setzen, auf den
App-Agenten reagieren), sind **alle erledigt**. Was jetzt ansteht:

1. **Die Ablehnungs-Frage entscheiden.** Alles Weitere haengt daran. Gibt die Engine
   Ablehnungen mit Begruendung aus, oder leitet die UI sie selbst ab? Solange das offen ist,
   kann der Adapter den Port nur teilweise bedienen. Siehe Abschnitt 5a Punkt 1.
2. **Adapter bauen und die zweite DrawEngine entfernen.** Reihenfolge, die den Bruch klein
   haelt: erst `DomainStubs.swift` durch die Engine-Modelle ersetzen (Punkt 2 in 5a), dann
   `availableConstraints`/`validate` aus der Engine heraus bedienen (Punkt 3), dann die
   Wurzel-`Package.swift` umziehen und `Packages/DrawEngine/` loeschen (Punkt 4). Der
   Zwischenzustand ist nach jedem Schritt lauffaehig, weil die Views nur gegen
   `DrawEnginePort` arbeiten.
3. **Nach dem Umzug beide Testwelten zusammenlegen.** Heute laufen `Tests/DrawEngineTests`
   (XCTest, 1 Stub-Test) und `DrawEngine/Tests/` (Swift Testing, 121 Tests) getrennt. Wer
   `swift test` in der Wurzel aufruft, sieht die 121 Tests **nicht** - eine Falle fuer jeden,
   der glaubt, er habe die Engine gepruft.
4. **Engine-Aenderungen bleiben in `DrawEngine/`.** Vermisst die App etwas, gehoert die
   Aenderung dorthin, **nicht** als nachgebaute Regel in den App-Layer. Das war die
   urspruengliche Scope-Regel und gilt nach dem Merge unveraendert.

## 8. Was ueber den Nutzer wichtig ist

- **Sprache Deutsch.** Code-Kommentare und Doku im Projekt zusaetzlich in
  **ASCII-Schreibweise** (ae/oe/ue/ss statt Umlauten) - so verlangt es `AGENTS.md` des Repos.
  Ist im gesamten Package eingehalten und per `grep` verifiziert.
- **Sehr knappe Rueckfragen** ("und?", "so?", "wie siehts aus?", "laeuft?"). Das sind
  Statusabfragen, keine Kritik. Antwort: konkret, mit Zahlen, ohne Fuellwoerter.
- **Scope-Grenze, die er ausdruecklich gesetzt hat:** Ein anderer Agent baut parallel die
  SwiftUI-App im selben Repo. Anweisung war woertlich "komm ihm nicht in die Quere". Deshalb
  wurde in der Bau-Session **ausschliesslich innerhalb von `DrawEngine/` geschrieben**.
  **Am 2026-09-06 hat er diese Grenze fuer genau einen Fall gelockert** und den Verweis auf
  die Regeldoku in `docs/roadmap.md` freigegeben. Das war eine punktuelle Freigabe, keine
  generelle: `AGENTS.md` und die App unter `Apps/` bleiben fremdes Gebiet. Vor jedem weiteren
  Eingriff ausserhalb von `DrawEngine/` erneut fragen.
- **Er entscheidet auf Basis dessen, was man ihm sagt - Praemissen also pruefen.** Er hat den
  Merge freigegeben, weil ihm gesagt wurde, `main` sei leer und der Merge folglich
  konfliktfrei. Das war falsch (Fallstrick h). Als es auffiel, war die richtige Reaktion,
  den Merge zu stoppen, den Fehler zu benennen und ihn neu entscheiden zu lassen. Genau so
  weitermachen: **eine Freigabe gilt nur fuer die Lage, die man beschrieben hat.**
- **Arbeitsweise:** Er erwartet Delegation an Sub-Agents statt Alleingang (steht so in seiner
  globalen `CLAUDE.md`). Substanzielle Ausfuehrung an Agenten, Koordination und Ergebnis-Merge
  selbst.
- **Ehrlichkeit ueber Zwischenstaende:** Er hat mehrfach nach dem Stand gefragt, waehrend ein
  Test rot war und ein Workflow gescheitert ist. Beides offen benannt statt geglaettet - das
  hat gut funktioniert und sollte so bleiben.

## 9. Kurzfassung

Die Draw-Engine fuer die UEFA-Auslosung ist als eigenstaendiges, UI-freies Swift-Package unter
`DrawEngine/` fertig, mit 121 gruenen Tests committet (`c1aaba5`) und auf
`feature/draw-engine` gepusht. Sie loest die Auslosung per Backtracking, verteilt Heim und
Auswaerts ueber Kreisorientierung und liefert zusaetzlich eine deterministische Event-Sequenz
fuer die spaetere Live-Darstellung. Ein adversarialer Review fand einen echten Blocker -
topfpaar-lokale Forward-Checks liessen die Suche auf dem echten Feld 2025/26 bei 21 Prozent
der Seeds scheitern - der behoben und anschliessend unabhaengig nachgemessen wurde (440
Auslosungen ohne Regelverstoss, Determinismus ueber 25 Prozesse byteidentisch).

**Seit dem 2026-09-06 liegt sie ueber PR #1 auf `main`** (`b5e5967`), zusammen mit der
parallel entstandenen SwiftUI-App. Verbunden sind die beiden aber noch nicht: Die App laeuft
auf `MockDrawEngine` hinter dem Protokoll `DrawEnginePort`, und die Wurzel-`Package.swift`
zeigt weiter auf einen 8-Zeilen-Platzhalter unter `Packages/DrawEngine/`. **Der naechste
Schritt ist der Adapter** (Abschnitt 5a und 7), und er haengt an einer Produktentscheidung,
die noch offen ist: Der Port erwartet Ablehnungen mit Begruendung, die Engine liefert keine.
