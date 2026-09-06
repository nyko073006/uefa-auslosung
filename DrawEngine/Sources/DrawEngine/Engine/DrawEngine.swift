/// Die oeffentliche Einstiegs-API der Auslosung.
///
/// `DrawEngine` ist die einzige Stelle, an der ein Aufrufer arbeitet: Er
/// uebergibt 36 Teams und einen Seed und bekommt ein vollstaendiges
/// `DrawResult` zurueck. Alle Bauteile darunter - Vorpruefung, Index-Kontext,
/// Gegnersuche, Heimrecht und Ereignisliste - sind `internal` und gehen den
/// Aufrufer nichts an.
///
/// ## Determinismus-Vertrag
/// Gleiche Team-Menge und gleicher Seed erzeugen immer dasselbe `DrawResult`,
/// unabhaengig von der Reihenfolge des uebergebenen Arrays. Der Vertrag beruht
/// auf drei Bausteinen:
///
/// - `DrawContext` sortiert die Teams kanonisch nach `(pot, id)`. Damit hat
///   dieselbe Teammenge immer dieselbe Index-Belegung, egal wie sie ankommt.
/// - Gemischt wird ausschliesslich mit dem eigenen `SplitMix64` und dem eigenen
///   Fisher-Yates. Die Zufalls-APIs der Stdlib sind bewusst nicht im Spiel,
///   weil ihre Zahlenfolge ueber Swift-Versionen hinweg nicht garantiert ist.
/// - Es wird nirgends ueber ein `Set` oder ein `Dictionary` iteriert. Swift
///   randomisiert den Hash-Seed pro Prozesslauf, jede Iteration daraus wuerde
///   den Determinismus lautlos zerstoeren.
///
/// Der Vertrag gilt auch ueber Prozesslaeufe und Build-Konfigurationen hinweg:
/// Debug und Release liefern fuer denselben Seed dasselbe Ergebnis.
public struct DrawEngine: Sendable {

    // MARK: - Konfiguration

    /// Stellschrauben der Auslosung.
    public struct Configuration: Sendable {

        /// Obergrenze fuer die Anzahl ausprobierter Kantenplatzierungen in der
        /// Gegnersuche, summiert ueber alle Neustarts.
        ///
        /// Ein realistisches Teilnehmerfeld bleibt weit darunter - gemessen
        /// wurden Werte im Bereich von 144 bis rund 200. Die Grenze ist kein
        /// Tuning-Parameter, sondern eine Reissleine: Sie stellt sicher, dass
        /// auch eine pathologische Eingabe garantiert terminiert und mit
        /// `.searchBudgetExceeded` abbricht, statt den Aufrufer haengen zu
        /// lassen.
        ///
        /// Weil die Suche in Neustarts laeuft (siehe `OpponentMatcher.match`),
        /// kauft ein groesseres Budget zusaetzliche Versuche mit neuer
        /// Kandidatenreihenfolge und nicht nur mehr Enumeration desselben
        /// Zweiges. Fuer ein sehr dicht besetztes, aber loesbares Feld kann ein
        /// hoeherer Wert deshalb tatsaechlich den Ausschlag geben.
        public var maxSearchNodes: Int

        /// Erzeugt eine Konfiguration.
        ///
        /// - Parameter maxSearchNodes: Knotenbudget der Gegnersuche.
        public init(maxSearchNodes: Int = 2_000_000) {
            self.maxSearchNodes = maxSearchNodes
        }
    }

    /// Die verwendete Konfiguration.
    public let configuration: Configuration

    /// Erzeugt eine Engine.
    ///
    /// - Parameter configuration: Stellschrauben; die Voreinstellung passt fuer
    ///   den Regelfall.
    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    // MARK: - Auslosung

    /// Fuehrt eine vollstaendige Auslosung durch.
    ///
    /// Gleiche Team-Menge und gleicher Seed erzeugen immer dasselbe
    /// `DrawResult`, unabhaengig von der Reihenfolge des uebergebenen Arrays.
    ///
    /// Ablauf:
    /// 1. Vorpruefung der Eingabe (`InputValidation`)
    /// 2. kanonischer Index-Kontext (`DrawContext`)
    /// 3. Ableitung dreier getrennter Zufalls-Streams aus dem Seed
    /// 4. Phase A Gegner, Phase B Heimrecht, Phase C Ereignisse
    /// 5. Uebersetzung der Kanten in `Matchup`-Werte, kanonisch sortiert
    /// 6. Selbstcheck durch den unabhaengigen `DrawValidator` (nur in Debug)
    ///
    /// - Parameters:
    ///   - teams: Genau 36 Teams mit eindeutigen IDs, neun je Topf, in
    ///     beliebiger Reihenfolge.
    ///   - seed: Startwert des Zufallsgenerators.
    /// - Returns: Das vollstaendige Ergebnis mit kanonisch sortierten Teams und
    ///   Paarungen sowie der Ereignisliste in Auftrittsreihenfolge.
    /// - Throws: `DrawError`, wenn die Eingabe die Vorpruefung nicht besteht,
    ///   wenn keine Loesung existiert oder wenn das Knotenbudget der Suche
    ///   aufgebraucht ist.
    public func draw(teams: [Team], seed: UInt64) throws(DrawError) -> DrawResult {

        // Schritt 1: Notwendige Bedingungen pruefen, bevor irgendetwas gerechnet
        // wird. Was hier durchfaellt, koennte auch die Suche nicht loesen.
        try InputValidation.validate(teams: teams)

        // Schritt 2: Kanonische Index-Repraesentation. Ab hier arbeitet der
        // gesamte Algorithmus mit Indizes 0 ..< 36 statt mit Team-Werten, und
        // die Eingabereihenfolge ist vergessen.
        let kontext = DrawContext(teams: teams)

        // Schritt 3: Drei Sub-Seeds aus dem Master-Seed ableiten und daraus drei
        // getrennte Generatoren bauen.
        //
        // Getrennte Streams verhindern, dass eine Aenderung im
        // Backtracking-Verlauf (variabler RNG-Verbrauch in Phase A) auch die
        // Ergebnisse von Phase B und C verschiebt. Mit einem einzigen Generator
        // haetten schon zwei zusaetzlich zurueckgenommene Kanten in Phase A eine
        // voellig andere Heim/Auswaerts-Verteilung und Ziehreihenfolge zur
        // Folge - die Phasen waeren ueber den Generatorzustand aneinander
        // gekoppelt, obwohl sie fachlich unabhaengig sind.
        var master = SplitMix64(seed: seed)
        let seedA = master.next()
        let seedB = master.next()
        let seedC = master.next()
        var rngA = SplitMix64(seed: seedA)
        var rngB = SplitMix64(seed: seedB)
        var rngC = SplitMix64(seed: seedC)

        // Schritt 4a - Phase A: Wer gegen wen. Ergebnis sind 144 ungerichtete
        // Kanten in der Platzierungsreihenfolge der Suche.
        let zuordnung = try OpponentMatcher.match(
            context: kontext,
            rng: &rngA,
            maxSearchNodes: configuration.maxSearchNodes
        )

        // Schritt 4b - Phase B: Heimrecht. Jede Kante bekommt eine Richtung,
        // sodass jedes Team je Topf genau ein Heim- und ein Auswaertsspiel hat.
        let gerichteteKanten = HomeAwayOrienter.orient(
            edges: zuordnung.edges,
            context: kontext,
            rng: &rngB
        )

        // Schritt 4c - Phase C: Der Ablauf als Ereignisliste, mit der die
        // Oberflaeche die Auslosung nachspielen kann.
        let ereignisse = EventSequencer.events(
            directedEdges: gerichteteKanten,
            context: kontext,
            seed: seed,
            rng: &rngC
        )

        // Schritt 5: Kanten in Modell-Typen uebersetzen und kanonisch sortieren.
        //
        // Sortiert wird ueber die Team-Indizes und nicht ueber die TeamID-
        // Strings: Die Index-Ordnung ist genau die kanonische Team-Ordnung
        // `(pot, id)`, damit stehen die Paarungen in `matches` in derselben
        // Reihenfolge wie die Teams in `teams`. `DirectedEdge` ist `Comparable`
        // mit der Totalordnung `(home, away)`, das Sortieren passiert also noch
        // auf den Indizes und erst danach die Uebersetzung.
        let paarungen: [Matchup] = gerichteteKanten.sorted().map { kante in
            Matchup(home: kontext.teamID(kante.home), away: kontext.teamID(kante.away))
        }

        // Schritt 6: Selbstcheck durch die unabhaengige Nachpruefung.
        //
        // Bewusst nur `assert` und nicht `precondition`: Der Validator rechnet
        // das komplette Ergebnis ein zweites Mal durch, und zwar absichtlich mit
        // einem voellig anderen Verfahren. In Debug-Builds und in den Tests ist
        // dieses zweite Paar Augen jede Mikrosekunde wert, in Release waere es
        // doppelte Arbeit fuer ein Ergebnis, das durch die Preconditions der
        // Phasen bereits abgesichert ist.
        assert(
            DrawValidator.violations(matches: paarungen, teams: kontext.teams).isEmpty,
            "Selbstcheck fehlgeschlagen: Das erzeugte Ergebnis verletzt die Fachregeln"
        )

        return DrawResult(
            seed: seed,
            teams: kontext.teams,
            matches: paarungen,
            events: ereignisse
        )
    }
}
