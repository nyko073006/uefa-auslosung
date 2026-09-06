# DrawEngine (UEFA-Auslosung) - Session-Handoff

_Stand: 2026-09-06. Diese Session hat die komplette Auslosungs-Engine als eigenstaendiges
Swift-Package gebaut, adversarial pruefen lassen, einen dabei gefundenen Blocker behoben,
das Ergebnis unabhaengig verifiziert, committet und gepusht._

## 1. Worum es geht

Fuer eine geplante SwiftUI-App, die eine UEFA-Champions-League-Auslosung (Swiss-Model)
simuliert, wurde der Simulationskern gebaut: Models, Regelpruefung, Auslosungsalgorithmus
mit Backtracking, Heim/Auswaerts-Verteilung, Event-Sequenz fuer die UI, deterministische
Tests mit Seed.

- **Repo:** `https://github.com/nyko073006/uefa-auslosung`
- **Lokal:** `/Users/nyko/Documents/GitHub/uefa-auslosung`
- **Package:** `/Users/nyko/Documents/GitHub/uefa-auslosung/DrawEngine`
- **Branch:** `feature/draw-engine` (gepusht, trackt `origin/feature/draw-engine`)
- **Commit:** `c1aaba5` - 28 Dateien, 7.074 Zeilen
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

Alles committet und gepusht, Arbeitskopie sauber.

> **Berichtigung 2026-09-06, nachgemessen:** Hier stand urspruenglich "Kein Pull Request
> geoeffnet". Das ist falsch. **PR #1 ist offen seit 2026-08-28**
> (`https://github.com/nyko073006/uefa-auslosung/pull/1`), `feature/draw-engine` → `main`,
> Zustand `MERGEABLE` / `CLEAN`, **kein Review, kein Kommentar, keine CI-Pruefung**
> (das Repo hat keine Actions). Offen ist also nicht das Oeffnen, sondern der **Merge** -
> und der bleibt beim Menschen.

Der App-Agent hat weiterhin **nichts im Repo abgelegt**: `main` steht unveraendert auf dem
initialen Commit `9073356`, es gibt keinen App-Ordner und keinen weiteren Branch
(nachgeprueft 2026-09-06).

**Nachmessung 2026-09-06:** `swift build` sauber, `swift test` **121 Tests gruen in 23,8 s**,
`git status` bis auf diese Datei sauber. Die Zahlen aus Abschnitt 2 tragen weiterhin.

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

## 7. Naechste Schritte

1. ~~**PR oeffnen**~~ - erledigt, PR #1 ist seit 2026-08-28 offen. Offen ist der **Merge**:
   `MERGEABLE`/`CLEAN`, ohne Review. Entscheidung liegt beim Menschen, der Zeitpunkt haengt
   am SwiftUI-Agenten.
2. **Offene Roadmap-Frage schliessen:** `docs/roadmap.md` im Repo-Root fragt "Welche
   UEFA-Regelmenge soll exakt simuliert werden?". Die Antwort steht vollstaendig in
   `DrawEngine/Docs/draw-regeln.md`, aber im Repo-Root weiss davon niemand. Ein Verweis
   wuerde das aufloesen - **nur nach Freigabe des Nutzers**, siehe Abschnitt 8.
3. **Auf den SwiftUI-Agenten reagieren:** Vermisst er etwas an der Engine, gehoert die
   Aenderung auf `feature/draw-engine` - **nicht** als nachgebaute Regel in den App-Layer.

## 8. Was ueber den Nutzer wichtig ist

- **Sprache Deutsch.** Code-Kommentare und Doku im Projekt zusaetzlich in
  **ASCII-Schreibweise** (ae/oe/ue/ss statt Umlauten) - so verlangt es `AGENTS.md` des Repos.
  Ist im gesamten Package eingehalten und per `grep` verifiziert.
- **Sehr knappe Rueckfragen** ("und?", "so?", "wie siehts aus?", "laeuft?"). Das sind
  Statusabfragen, keine Kritik. Antwort: konkret, mit Zahlen, ohne Fuellwoerter.
- **Scope-Grenze, die er ausdruecklich gesetzt hat:** Ein anderer Agent baut parallel die
  SwiftUI-App im selben Repo. Anweisung war woertlich "komm ihm nicht in die Quere". Deshalb
  wurde **ausschliesslich innerhalb von `DrawEngine/` geschrieben** - `README.md`, `docs/`
  und `AGENTS.md` im Repo-Root sind unveraendert, und auch `.gitignore` und die Doku liegen
  bewusst im Package statt im Root. Diese Grenze weiter respektieren.
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
Auslosungen ohne Regelverstoss, Determinismus ueber 25 Prozesse byteidentisch). Offen sind
nur der **Merge** von PR #1 (offen seit 2026-08-28, `MERGEABLE`, ohne Review) und ein Verweis
auf die Regeldoku im Repo-Root; Letzteres bitte nur mit Freigabe, weil dort parallel der
SwiftUI-Agent arbeitet.
