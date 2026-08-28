# Auslosungsregeln der DrawEngine

Dieses Dokument beschreibt, welche Regelmenge das Swift-Package `DrawEngine`
tatsaechlich simuliert, welche Annahmen dabei getroffen wurden, welcher
Determinismus zugesichert ist und wie der Algorithmus arbeitet. Es beantwortet
damit die offene Roadmap-Frage "Welche UEFA-Regelmenge soll exakt simuliert
werden?" fuer den aktuellen Stand des Packages.

Alles hier Beschriebene ist im Code umgesetzt und durch Tests abgedeckt. Was
nicht umgesetzt ist, steht in Abschnitt 2 und Abschnitt 6.

---

## 1. Implementierte Regelmenge

Die Engine kennt genau sechs Fachregeln. Weitere Restriktionen gibt es nicht.

### R1 - Teilnehmerfeld und Toepfe

Genau **36 Teams**, verteilt auf **vier Toepfe** (`pot1` bis `pot4`) mit je
**neun Teams**. Die Zuordnung Team -> Topf ist Eingabe und wird von der Engine
nicht berechnet. Jede TeamID muss eindeutig sein.

*Konsequenz in Zahlen:* 36 = 4 x 9.

### R2 - Acht Gegner je Team, zwei aus jedem Topf

Jedes Team bekommt genau **zwei Gegner aus jedem der vier Toepfe**, ausdruecklich
auch aus dem **eigenen** Topf.

*Konsequenz in Zahlen:* 4 Toepfe x 2 Gegner = **8 Gegner je Team**.

### R3 - Symmetrie der Paarungen

"A gegen B" und "B gegen A" sind dieselbe Begegnung. Sie erscheint im Ergebnis
**genau einmal**, naemlich als ein `Matchup` mit Heim- und Auswaertsseite.

*Konsequenz in Zahlen:* 36 Teams x 8 Gegner / 2 = **144 Matches**.

### R4 - Kein Duell innerhalb derselben Association

Zwei Teams mit derselben `Association` duerfen **nicht** gegeneinander spielen.
Der Vergleich laeuft rein ueber den `rawValue`-String der Association.

*Konsequenz in Zahlen:* Bei `m` Teams einer Association fallen fuer jedes von
ihnen `m - 1` moegliche Gegner weg.

### R5 - Obergrenze je Association

Kein Team darf mehr als **zwei Gegner aus derselben Association** haben.

*Konsequenz in Zahlen:* Aus R2, R4 und R5 folgen drei harte Schranken fuer die
Zusammensetzung des Feldes, die die Engine vor der Suche prueft:

| Schranke | Bedingung | Herleitung |
| --- | --- | --- |
| A | hoechstens **7** Teams je Association insgesamt | `8m <= 2(36 - m)` => `10m <= 72` => `m <= 7` |
| B | hoechstens **4** Teams je Association **je Topf** | `2k <= 2(9 - k)` => `k <= 4,5` => `k <= 4` |
| C | zwei Toepfe zusammen hoechstens **9** Teams je Association | `2a <= 2(9 - b)` => `a + b <= 9` |

Schranke C kann im normalen Ablauf nie als erste zuschlagen (aus A und B folgt
bereits `a + b <= 8`); sie bleibt als eigenstaendige, einzeln testbare Bedingung
im Code erhalten.

### R6 - Heim- und Auswaertsrecht

Gegen die **beiden Gegner aus einem Topf** hat jedes Team genau **ein Heimspiel
und ein Auswaertsspiel**.

*Konsequenz in Zahlen:* 4 Toepfe x (1 Heim + 1 Auswaerts) = **4 Heimspiele und
4 Auswaertsspiele je Team**. Ueber alle Teams: 36 x 4 = 144 Heimspiele, was
genau der Zahl der Begegnungen entspricht.

### Strukturelle Folge: zehn Teilgraphen

Weil R2 und R6 je Topfpaar formuliert sind, zerfaellt das Gesamtproblem in zehn
unabhaengige Teilgraphen, einen je Topfpaar `(i, j)` mit `i <= j`:

| Typ | Anzahl | Knoten | Kanten je Teilgraph | Kanten gesamt |
| --- | --- | --- | --- | --- |
| Same-Pot (`i == j`) | 4 | 9 | 9 | 36 |
| Cross-Pot (`i < j`) | 6 | 9 + 9 | 18 | 108 |
| **Summe** | **10** | | | **144** |

In jedem dieser Teilgraphen hat jeder beteiligte Knoten exakt den Grad zwei.
Diese Eigenschaft traegt den gesamten Phase-B-Algorithmus (siehe Abschnitt 4).

---

## 2. Getroffene Annahmen und Vereinfachungen

Die Engine bildet die oben genannten sechs Regeln ab - **und sonst nichts**. Die
folgenden Punkte sind bewusst **nicht** modelliert.

### Nicht modelliert

- **Keine Setzlisten-Berechnung.** Die Topfzuordnung ist Eingabe (`Team.pot`).
  Koeffizienten, Titelverteidiger-Sonderregeln oder Qualifikationspfade spielen
  keine Rolle.
- **Keine Termin- oder Kalenderrestriktionen.** Es gibt keine Spieltage, keine
  Ansetzung, keine Reihenfolge der acht Partien eines Teams als Spielplan. Die
  Engine liefert *wer gegen wen* und *wer zu Hause*, nicht *wann*.
- **Keine Reisebeschraenkungen und keine Laenderpaar-Sperren** ueber R4 hinaus.
  Politisch oder sicherheitsbedingt gesperrte Begegnungen zwischen Teams
  *verschiedener* Associations existieren im Modell nicht.
- **Keine TV-Slots, keine Stadion- oder Stadtkonflikte.** Zwei Klubs derselben
  Stadt werden nicht gesondert behandelt; sie fallen nur unter R4, wenn sie
  dieselbe Association haben.
- **Keine Obergrenze fuer Gegner aus derselben Association je Topf.** R5 gilt
  ueber alle acht Gegner zusammen, nicht zusaetzlich innerhalb eines Topfes.
- **Kein Nachziehen und kein Neustart.** Die reale Auslosung zieht Kugeln und
  verwirft Ziehungen, die nicht passen. Die Engine sucht stattdessen direkt eine
  vollstaendige gueltige Gesamtloesung und praesentiert sie anschliessend als
  Ziehreihenfolge (Phase C). Die Ereignisliste ist eine **Darstellung** des
  fertigen Ergebnisses, keine Aufzeichnung eines Ziehvorgangs mit Fehlversuchen.
- **Keine Gleichverteilung ueber alle gueltigen Auslosungen.** Der Zufall wirkt
  auf die Kandidatenreihenfolge der Suche, nicht auf die Loesungsmenge. Zwei
  gueltige Gesamtergebnisse haben damit **nicht** notwendig dieselbe
  Wahrscheinlichkeit. Fuer eine Demo- und Erklaersimulation ist das
  unproblematisch, fuer statistische Aussagen ueber Auslosungswahrscheinlichkeiten
  ist die Engine **nicht** geeignet.
- **Keine Persistenz, keine Lokalisierung, kein Foundation.** `Team.name` wird
  von der Engine nirgends ausgewertet; er ist reine Anzeigeinformation.

### Die Heim/Auswaerts-Lesart

R6 laesst sich auf mehrere Arten formulieren. Im Projekt gilt die Lesart
**"je Topf genau ein Heim- und ein Auswaertsspiel"**. Das ist eine bewusste
Festlegung, keine Ableitung.

Ihr Vorteil ist entscheidend fuer die Architektur: Weil die Bedingung je
Topfpaar formuliert ist, laesst sich jeder der zehn Teilgraphen einzeln
orientieren. Jeder Teilgraph ist 2-regulaer, zerfaellt also eindeutig in
knotendisjunkte Kreise, und ein konsistent umlaufend orientierter Kreis gibt
jedem seiner Knoten genau eine ausgehende (Heim) und genau eine eingehende
(Auswaerts) Kante. **Phase B ist deshalb nach jeder erfolgreichen Phase A
garantiert loesbar - ohne Suche, ohne Backtracking, in einem Durchlauf.**

Die schwaechere Alternative "insgesamt vier Heim- und vier Auswaertsspiele, egal
aus welchem Topf" waere ebenfalls loesbar, aber weniger aussagekraeftig. Die
staerkere Alternative einer 2-Kanten-Faerbung je Kreis ("abwechselnd heim und
auswaerts") waere **nicht** immer loesbar: Ein Same-Pot-Teilgraph hat neun
Knoten und enthaelt damit zwingend mindestens einen Kreis ungerader Laenge, und
ein ungerader Kreis ist nicht 2-kanten-faerbbar. Die gewaehlte
Kreisorientierung ist von der Paritaet unabhaengig und kennt dieses Problem
nicht.

---

## 3. Determinismus-Vertrag

> Dieselbe Team-Menge und derselbe Seed erzeugen immer dasselbe `DrawResult` -
> identische Paarungen, identisches Heimrecht und identische Ereignisliste in
> identischer Reihenfolge. Die Reihenfolge des uebergebenen Team-Arrays hat
> keinen Einfluss.

Der Vertrag gilt ueber Prozesslaeufe, ueber Build-Konfigurationen (Debug wie
Release) und ueber Plattformen hinweg. Er ruht auf vier Bausteinen.

### 3.1 Kanonische Index-Ordnung

`DrawContext` sortiert die Teams beim Aufbau nach `(pot.rawValue, id.rawValue)`.
Weil die TeamIDs nach der Vorpruefung eindeutig sind, ist das eine echte
Totalordnung: Dieselbe Teammenge ergibt immer dieselbe Index-Belegung, in
welcher Reihenfolge sie auch ankommt. Topf `p` belegt dabei die Indizes
`9 * (p - 1) ..< 9 * p`, also `0..<9`, `9..<18`, `18..<27`, `27..<36`. Ab dem
Aufbau des Contexts rechnet der gesamte Algorithmus nur noch mit `Int`-Indizes;
die Eingabereihenfolge ist damit vergessen.

Auch die Ausgabe ist kanonisch: `teams` nach `(pot, id)`, `matches` aufsteigend
nach dem Index-Paar `(home, away)` - also nicht nach TeamID-String, sondern in
derselben Ordnung wie `teams`.

### 3.2 Eigener Zufallsgenerator

Gemischt wird ausschliesslich mit dem projekteigenen `SplitMix64` und einem
eigenen Fisher-Yates (`deterministicShuffle(using:)`). Die Zufalls-APIs der
Standardbibliothek - `shuffled(using:)`, `next(upperBound:)`,
`random(in:using:)` - sind **verboten**. Grund: Ihre Zahlenfolge ist ein
Implementierungsdetail ohne Zusicherung ueber Swift-Versionen hinweg. Ein
Compiler-Update koennte jedes gespeicherte Seed-Ergebnis entwerten.

`SplitMix64.uniform(upperBound:)` zieht per Rejection-Sampling und ist damit
unverzerrt; ein simples `next() % n` waere zugunsten der kleinen Indizes
schief.

### 3.3 Keine Iteration ueber Set oder Dictionary

Swift randomisiert den Hash-Seed pro Prozesslauf. Eine Entscheidung oder eine
Reihenfolge, die aus einer `Set`- oder `Dictionary`-Iteration entsteht, waere
zwischen zwei Laeufen verschieden. Im gesamten Package wird deshalb nie ueber
diese Typen iteriert; sie dienen ausschliesslich als Nachschlagetabellen fuer
Einzelabfragen. Alle Schleifen laufen ueber Arrays mit fester Indexordnung oder
ueber explizit sortierte Schluessel-Arrays. Aus demselben Grund werden auch
Verbandslisten ueber "sortieren und benachbarte Duplikate ueberspringen"
gebildet statt ueber ein `Set`.

### 3.4 Drei getrennte Zufalls-Streams

Aus dem Master-Seed werden drei Sub-Seeds abgeleitet und daraus drei getrennte
Generatoren gebaut - je einer fuer Phase A, B und C. Das entkoppelt die Phasen:
Verbraucht die Suche in Phase A wegen zweier zusaetzlicher Rueckschritte mehr
Zufallswerte, verschiebt das mit einem einzigen gemeinsamen Generator auch die
Heim/Auswaerts-Verteilung und die Ziehreihenfolge. Fachlich sind die Phasen
unabhaengig, also sind es auch ihre Streams.

### 3.5 Absicherung durch Tests

| Test | Was er absichert |
| --- | --- |
| `Golden Master: Seed 42 auf dem realistischen Feld` | Regressions-Pin auf das **Gesamtergebnis** (siehe unten) |
| `Gleicher Seed liefert dasselbe Ergebnis` | Reproduzierbarkeit des kompletten `DrawResult` |
| `Die Reihenfolge der Eingabe aendert das Ergebnis nicht` | Unabhaengigkeit von der Array-Reihenfolge |
| `Verschiedene Seeds liefern verschiedene Paarungen` | Der Seed wirkt tatsaechlich |
| `Erster Wert fuer Seed 0 entspricht dem Referenz-Testvektor` | `SplitMix64` gegen den oeffentlichen Testvektor `0xE220A8397B1DCDAF` |
| `Erste fuenf Werte fuer Seed 0 bleiben unveraendert` | Regressions-Pin auf die RNG-Folge |
| `Shuffle-Ergebnis fuer Seed 42 bleibt unveraendert` | Regressions-Pin auf den Fisher-Yates |
| `Gleicher Seed liefert dieselbe Ereignisliste` (30 Seeds) | Determinismus der Reveal-Sequenz |
| `Gleicher Seed liefert dieselbe Orientierung` (30 Seeds) | Determinismus des Heimrechts |
| `Alle Fachregeln gelten ueber 200 Seeds` | R1 bis R6 am fertigen Ergebnis, breit gestreut |

**Der Golden Master** ist der Anker des Vertrags. Er pinnt fuer ein festes Feld
und Seed 42 die ersten zehn Paarungen in kanonischer Reihenfolge, die Anzahl der
Ereignisse, die Teamliste und die Paarungszahl. Ohne ihn waere "gleicher Seed,
gleiches Ergebnis" nur *innerhalb eines Prozesslaufs* pruefbar - eine Aenderung
oberhalb des RNG, etwa an der Kandidatenreihenfolge oder an der Reihenfolge der
Topfpaare, lieferte weiterhin deterministische, aber **andere** Ergebnisse, ohne
dass ein Test anschlaegt. Mit ihm faellt genau das auf.

Die gepinnten Werte stehen ausschliesslich im **Test**, nie in der
Produktivlogik: Sie wurden einmalig aus einem echten Lauf abgelesen; die Engine
kennt sie nicht und rechnet sie bei jedem Lauf neu aus. Schlaegt der Test an,
ist das ein bewusster Breaking Change des Determinismus-Vertrags und muss
dokumentiert werden.

---

## 4. Algorithmus in drei Phasen

`DrawEngine.draw(teams:seed:)` fuehrt sechs Schritte aus: Vorpruefung,
Context-Aufbau, Seed-Ableitung, die drei Phasen, kanonische Sortierung und einen
Selbstcheck.

### Schritt 0 - Vorpruefung (`InputValidation`)

Geprueft werden ausschliesslich **notwendige** Bedingungen in fester Reihenfolge:
Teamanzahl, doppelte TeamIDs, Topfgroessen, Verbands-Schranken A/B/C aus
Abschnitt 1. Der Umkehrschluss gilt nicht - eine Eingabe, die hier durchkommt,
kann in der Suche immer noch als `unsolvable` enden. Die Vorpruefung ist ein
schneller Filter vor der teuren Suche, **kein Loesbarkeits-Beweis**.

Die Reihenfolge der Pruefungen ist Teil des Vertrags, damit bei mehreren
gleichzeitigen Maengeln immer derselbe Fehler gemeldet wird. Innerhalb einer
Pruefung wird jeweils der kleinste Kandidat gemeldet (kleinste doppelte TeamID,
kleinster fehlerhafter Topf, alphabetisch erste problematische Association).

### Phase A - Wer gegen wen (`OpponentMatcher`)

Die Gegnersuche ist als **Constraint-Satisfaction-Problem** formuliert: Gesucht
sind 144 ungerichtete Kanten, verteilt auf die zehn Topfpaar-Teilgraphen aus
Abschnitt 1, sodass jeder beteiligte Knoten in seinem Teilgraphen Grad zwei hat
und die Association-Regeln R4 und R5 gelten.

Verfahren: **Tiefensuche mit Backtracking**, ueber einen expliziten Frame-Stack
statt ueber Rekursion.

- **Reihenfolge der Teilprobleme:** Die Topfpaare werden Row-Major abgearbeitet
  (`(0,0), (0,1), ... , (3,3)`). Chronologisches Backtracking nimmt bei einem
  Konflikt immer die *zuletzt* gesetzte Entscheidung zurueck, auch wenn sie mit
  der Ursache nichts zu tun hat. Row-Major haelt zusammen, was sich gegenseitig
  einschraenkt, und begrenzt dieses Thrashing so weit, dass kein Backjumping
  noetig wird.
- **MRV (Minimum Remaining Values):** Innerhalb eines Topfpaars wird immer das
  Team mit der **kleinsten Restauswahl** an Gegnern zuerst belegt. Ein Team ohne
  Kandidaten wird dadurch sofort gewaehlt und fuehrt ohne Umweg zum
  Rueckschritt. Bei Gleichstand gewinnt der kleinste Team-Index.
- **Forward-Checking, zwei Ebenen:**
  1. *Per Team:* Jedes Team des Paars braucht mindestens so viele zulaessige
     Kandidaten, wie ihm Gegner fehlen.
  2. *Aggregiert je Association* (nur bei Cross-Pot-Paaren): Fuer jede
     Association mit offenem Bedarf im Quelltopf wird die Summe der offenen
     Slots gegen das Aufnahmevermoegen des Zieltopfes gestellt. Dieser Check
     betrachtet alle Teams einer Association gemeinsam und findet damit genau
     die Engpaesse, die dem Per-Team-Check entgehen. Bei Same-Pot-Paaren wird er
     ausgelassen, weil dieselbe Kante dort gleichzeitig Bedarf und Angebot waere
     und die Schranke ihre Konservativitaet verloere.

  Beide Checks sind notwendige, keine hinreichenden Bedingungen: Sie schneiden
  Zweige ab, die garantiert scheitern, garantieren aber keine Loesung.
- **Zufall:** Er wirkt ausschliesslich auf die Reihenfolge der Kandidatenliste.
  Die *Menge* der Kandidaten ist vollstaendig deterministisch, gemischt wird mit
  dem eigenen Fisher-Yates.
- **Zustand:** Adjazenz als Bitmasken (`[UInt64]`, ein Bit je moeglichem
  Gegner), dazu Zaehler je Team/Topf, je Team/Association und je Topfpaar. Jede
  Aenderung laeuft ueber `placeEdge` beziehungsweise `undoLastEdge`, damit die
  Zaehler konsistent bleiben.
- **Reissleine:** Jede probierte Kantenplatzierung erhoeht `exploredNodes`.
  Ueberschreitet der Zaehler `Configuration.maxSearchNodes` (Voreinstellung
  2.000.000), bricht die Suche mit `.searchBudgetExceeded` ab. Gemessen ueber
  5000 Seeds liegt der Aufwand bei einem realistischen Testfeld zwischen **144
  und 190** Knoten - 144 ist das Minimum und bedeutet: kein einziger
  Rueckschritt. Das Budget ist damit kein Tuning-Parameter, sondern eine reine
  Terminierungs-Garantie.

### Phase B - Heimrecht (`HomeAwayOrienter`)

Phase A liefert ungerichtete Kanten; offen bleibt, wer das Heimspiel bekommt.
Phase B loest das **ohne jede Suche**:

1. Die 144 Kanten werden nach Topfpaar gruppiert (Row-Major, wie in Phase A).
2. Jeder Teilgraph ist 2-regulaer und zerfaellt damit eindeutig in
   knotendisjunkte einfache Kreise. Die Kreissuche startet beim kleinsten noch
   unbesuchten Knoten, geht zuerst zum kleineren Nachbarn und verlaesst danach
   jeden Knoten ueber den Nachbarn, der nicht der Vorgaenger ist.
3. Jeder Kreis hat mindestens Laenge drei: Schlingen sind ausgeschlossen (kein
   Team spielt gegen sich selbst), Doppelkanten ebenfalls (Phase A setzt kein
   Paar zweimal, und jedes Paar gehoert zu genau einem Topfpaar).
4. Pro Kreis wird **ein Bit** aus dem Generator gezogen; es entscheidet die
   Umlaufrichtung. Der Kreis wird dann durchgehend orientiert
   (`v0 -> v1 -> ... -> vn-1 -> v0`). Jeder Knoten hat damit genau eine
   ausgehende Kante (sein Heimspiel) und genau eine eingehende (sein
   Auswaertsspiel).

**Warum ungerade Kreise kein Problem sind:** Der naheliegende Ansatz waere eine
2-Kanten-Faerbung, also "eine Kante heim, die naechste auswaerts, abwechselnd".
Sie scheitert an ungeraden Kreisen, weil sich beim Rundgang die Farben genau
einmal wiederholen muessten. Ungerade Kreise kommen hier zwingend vor: Ein
Same-Pot-Teilgraph hat neun Knoten, und neun laesst sich nicht in lauter gerade
Kreislaengen zerlegen. Die gewaehlte Kreis*orientierung* ist von der Paritaet
voellig unabhaengig - sie funktioniert fuer jede Kreislaenge ab drei. Genau
deshalb ist Phase B nach jeder erfolgreichen Phase A **immer** loesbar.

Am Ende prueft eine `precondition`, dass jedes Team gegen jeden Topf genau ein
Heim- und ein Auswaertsspiel hat. Diese Zusicherung bleibt bewusst auch im
Release-Build stehen.

### Phase C - Ereignisse fuer die Oberflaeche (`EventSequencer`)

Hier faellt **keine Fachentscheidung mehr**. Die Paarungen stehen nach Phase A
fest, das Heimrecht nach Phase B; Phase C bringt das fertige Ergebnis nur in die
Reihenfolge, in der es praesentiert wird.

Ablauf:

1. `.drawStarted(seed:)`
2. Je Topf `pot1` bis `pot4` in dieser festen Reihenfolge:
   `.potStarted`, dann die neun Teams des Topfes in **gemischter**
   Ziehreihenfolge - je Team ein `.teamDrawn` gefolgt von seinen noch nicht
   enthuellten Paarungen als `.matchRevealed` -, zum Schluss `.potCompleted`.
3. `.drawCompleted`

**Jede Begegnung wird genau einmal enthuellt**, naemlich bei dem der beiden
Teams, das **zuerst** gezogen wird. Beim zweiten ist sie schon bekannt und wird
uebersprungen. Deshalb enthuellt das erste gezogene Team acht Paarungen und das
letzte keine einzige, und deshalb summieren sich die Reveals auf 144 statt auf
36 x 8 = 288. Gemerkt wird das in einer Bitmatrix ueber Team-Indizes.

**Die Reveal-Unterordnung innerhalb eines Teams ist fest, nicht zufaellig:**
Gegner-Topf aufsteigend (erst Topf 1, zuletzt Topf 4), und innerhalb eines
Gegner-Topfes zuerst das Heimspiel des gezogenen Teams, dann das
Auswaertsspiel. Das ist eindeutig, weil jedes Team je Gegner-Topf genau zwei
Gegner hat, davon genau einen zu Hause. Auch diese Reihenfolge auszuwuerfeln
waere zusaetzlicher Zufall ohne fachlichen Gewinn und wuerde den RNG-Verbrauch
von der Ziehreihenfolge abhaengig machen.

Der Zufall dieser Phase besteht damit aus genau vier Mischungen von je neun
Indizes - eine je Topf.

**Laenge der Ereignisliste:** `1 + 2 x 4 + 36 + 144 + 1 = 190` Ereignisse.

### Schritt 5 - Sortierung und Selbstcheck

Die gerichteten Kanten werden nach `(home, away)` auf Index-Ebene sortiert und
erst danach in `Matchup`-Werte uebersetzt. So steht `matches` in derselben
Ordnung wie `teams`.

Zum Schluss laeuft der **unabhaengige** `DrawValidator` ueber das Ergebnis. Er
kennt weder Bitmasken noch Zaehler der Suche und zaehlt alles von vorne neu ab -
genau diese Unabhaengigkeit macht ihn als Kontrollinstanz wertvoll. Der Aufruf
steht in einem `assert` und laeuft deshalb **nur in Debug-Builds**; in Release
waere es doppelte Arbeit fuer ein Ergebnis, das die `precondition`-Zusicherungen
der Phasen bereits absichern.

### Gemessene Laufzeit

Auf einem Apple-Silicon-Mac, gemittelt ueber 1000 Draws mit einem realistischen
36er-Feld:

| Build | Zeit je vollstaendigem Draw |
| --- | --- |
| Release (`-c release`) | rund **0,26 ms** |
| Debug | rund **10,6 ms** |

Der Unterschied kommt ueberwiegend aus dem Debug-only-Selbstcheck des Validators
und den fehlenden Optimierungen. Beide Werte liegen weit unter jeder fuer eine
Oberflaeche relevanten Schwelle.

---

## 5. Fehlerfaelle

Alle Fehler sind Faelle von `DrawError`. `draw(teams:seed:)` nutzt Typed Throws
(`throws(DrawError)`), ein `catch` liefert also direkt einen `DrawError` ohne
Casting.

| Fall | Bedeutung | Wann er auftritt |
| --- | --- | --- |
| `wrongTeamCount(actual: Int)` | Es wurden nicht genau 36 Teams uebergeben. | Vorpruefung, Schritt 1. Meldet die tatsaechliche Anzahl. |
| `duplicateTeamID(TeamID)` | Zwei Teams teilen sich dieselbe TeamID. | Vorpruefung, Schritt 2. Gemeldet wird die kleinste doppelte ID. |
| `wrongPotSize(pot: Pot, actual: Int)` | Ein Topf enthaelt nicht genau neun Teams. | Vorpruefung, Schritt 3. Gemeldet wird der kleinste abweichende Topf. |
| `infeasibleAssociationDistribution(association:reason:)` | Die Verteilung einer Association macht eine gueltige Auslosung rechnerisch unmoeglich. | Vorpruefung, Schritt 4. Associations werden aufsteigend nach `rawValue` geprueft. |
| `unsolvable` | Die Eingabe ist formal gueltig, es existiert aber **beweisbar** keine Loesung. | Phase A: Der Suchraum wurde **vollstaendig** durchlaufen, ohne dass eine Belegung gehalten haette. |
| `searchBudgetExceeded(exploredNodes: Int)` | Die Suche wurde am Knotenbudget abgebrochen. | Phase A: `exploredNodes` hat `Configuration.maxSearchNodes` ueberschritten. |

### `unsolvable` gegen `searchBudgetExceeded`

Der Unterschied ist wichtig und wird bewusst nicht verwischt:

- **`unsolvable`** ist eine **Aussage ueber die Eingabe**. Der Suchraum ist
  erschoepft, die Unloesbarkeit ist bewiesen. Erneutes Aufrufen mit einem
  anderen Seed hilft nicht - der Zufall aendert nur die Reihenfolge, in der der
  Suchraum durchlaufen wird, nicht seinen Inhalt. Die Eingabe muss geaendert
  werden. Beides ist getestet: `Die Unloesbarkeit haengt nicht am Seed` und
  `Die Unloesbarkeit haengt nicht an der Eingabereihenfolge`.
- **`searchBudgetExceeded`** ist eine **Aussage ueber die Suche**. Die
  Unloesbarkeit ist **nicht** bewiesen; es kann durchaus eine Loesung geben, die
  innerhalb des Budgets nicht gefunden wurde. Sinnvolle Reaktionen sind ein
  hoeheres `maxSearchNodes` oder ein anderer Seed. In der Praxis tritt der Fall
  bei einem realistischen Feld nicht auf: Gemessen liegt der Aufwand bei 144 bis
  190 Knoten gegen ein Budget von 2.000.000.

### Was **kein** Fehlerfall ist

Regelverstoesse im **Ergebnis** koennen im Normalbetrieb nicht auftreten - sie
waeren Programmierfehler und werden ueber `precondition` beziehungsweise
`assert` abgefangen, nicht ueber `DrawError`. Wer ein **fremdes** oder von Hand
veraendertes Ergebnis pruefen will, nutzt `DrawValidator.violations(matches:teams:)`
und bekommt eine Liste von `RuleViolation`-Werten (leer = regelkonform).

---

## 6. Offene Fragen

Aus `docs/roadmap.md` uebernommen und weiterhin offen:

- **Soll die App nur iPhone oder auch iPad unterstuetzen?** Betrifft das Package
  nicht direkt (`Package.swift` setzt iOS 17 / macOS 14 als Minimum), wohl aber
  die Oberflaeche darum herum.
- **Welche Teile duerfen vereinfacht werden?** Abschnitt 2 listet, was aktuell
  vereinfacht ist. Ob diese Liste den Anspruch des Projekts trifft, ist eine
  Produktentscheidung und noch nicht getroffen.

Im Zuge der Implementierung neu aufgekommen:

- **Soll die Association-Regel spaeter um echte UEFA-Zusatzregeln erweitert
  werden?** Denkbar waeren Laenderpaar-Sperren zwischen verschiedenen
  Associations oder eine Obergrenze fuer Gegner einer Association *je Topf*.
  Beides waere in Phase A als zusaetzliche Bedingung in `isValidCandidate`
  unterzubringen; die Forward-Checks muessten mitwachsen, sonst steigt der
  Suchaufwand deutlich.
- **Soll `maxSearchNodes` in der Oberflaeche konfigurierbar sein?** Aktuell ist
  es ein Konstruktor-Parameter mit der Voreinstellung 2.000.000 und fachlich
  eine reine Reissleine. Sichtbar zu machen waere nur sinnvoll, wenn eine
  Debug-Ansicht den gemessenen Suchaufwand ebenfalls anzeigt - `exploredNodes`
  ist derzeit **nicht** Teil von `DrawResult` und verlaesst die Engine nur im
  Fehlerfall.
- **Soll `DrawResult` `Codable` werden?** Aktuell sind `Team`, `TeamID`,
  `Association`, `Pot` und `Matchup` `Codable`, `DrawResult` und `DrawEvent`
  dagegen nicht. Fuer Export, Sharing oder das Speichern von QA-Ergebnissen
  waere das noetig.
- **Soll die Engine Zwischenstaende und Ablehnungen ausgeben?**
  `docs/architecture.md` nennt als Ausgang der Draw Engine auch "Ablehnungen und
  Begruendungen". Aktuell liefert sie das nicht: Die Suche findet eine
  vollstaendige Loesung und Phase C stellt sie dar; verworfene Kandidaten
  verlassen die Engine nie. Fuer die geplante Phase 4 der Roadmap
  ("Regelablehnungen erklaeren") waere zu klaeren, ob die Ereignisliste um
  Ablehnungs-Ereignisse erweitert werden soll oder ob die Oberflaeche die
  Begruendung selbst aus den Fachregeln ableitet.

---

## Verwandte Dokumente

- `README.md` (dieses Packages) - Integration, oeffentliche API, Beispiele
- `../AGENTS.md` - Arbeitsregeln des Repositories
- `../docs/architecture.md` - Zielarchitektur der App
- `../docs/roadmap.md` - Phasen und offene Fragen des Gesamtprojekts
