/// Bestimmt die 144 Paarungen einer Auslosung als Constraint-Satisfaction-Problem.
///
/// ## Modell
/// Die Fachregel "jedes Team bekommt genau zwei Gegner aus jedem Topf" zerlegt
/// das Problem in zehn unabhaengig formulierbare Teilgraphen, einen je Topfpaar
/// `(i, j)` mit `i <= j`:
///
/// - **Same-Pot** (`i == j`): neun Knoten, jeder mit Grad zwei - also ein
///   2-regulaerer Graph mit neun Kanten (eine Zerlegung in Kreise).
/// - **Cross-Pot** (`i < j`): bipartit mit neun plus neun Knoten, jeder Knoten
///   mit Grad zwei - also 18 Kanten.
///
/// In Summe `4 * 9 + 6 * 18 = 144` Kanten. Genau das sind die 144 Begegnungen.
/// Die Heim-/Auswaertsverteilung ist hier bewusst noch kein Thema: sie ist eine
/// Orientierung der bereits gefundenen Kanten und gehoert in einen eigenen
/// Schritt.
///
/// ## Nebenbedingungen
/// - Keine Kante innerhalb derselben Association.
/// - Kein Team mit mehr als zwei Gegnern aus derselben Association.
/// - Keine Kante doppelt, keine Kante von einem Team zu sich selbst.
///
/// ## Verfahren
/// Tiefensuche mit Backtracking, MRV-Heuristik (kleinste Restauswahl zuerst)
/// und drei Forward-Checks, die aussichtslose Zweige abschneiden, bevor sie
/// aufgezaehlt werden. Der Zufall steckt ausschliesslich in der Reihenfolge der
/// Kandidaten: Sie wird mit dem projekteigenen Fisher-Yates aus dem uebergebenen
/// `SplitMix64` gemischt. Gleicher Seed und gleiche Eingabe liefern damit immer
/// exakt dieselbe Kantenliste.
///
/// Die Forward-Checks wirken bewusst **global** ueber alle Toepfe und alle
/// Topfpaare, nicht nur ueber das gerade bearbeitete. Grund: Die Fachregel
/// "hoechstens zwei Gegner je Association" koppelt alle Topfpaare, die einen
/// Topf teilen. Ein Check, der nur das aktuelle Paar ansieht, uebersieht genau
/// die Sackgassen, die weiter hinten in der Bearbeitungsreihenfolge liegen -
/// und das chronologische Backtracking re-exploriert dann vollstaendige,
/// voellig unbeteiligte Teilprobleme.
///
/// Zusaetzlich laeuft die Suche in **Neustarts** (siehe `match`). Der Aufwand
/// ist stark zweigipflig: Ein Lauf findet die Loesung entweder in der
/// Groessenordnung von 150 Knoten, oder er verrennt sich und kommt auch mit dem
/// Vielfachen des Budgets nicht mehr heraus. Gegen genau dieses Profil hilft
/// kein groesseres Budget, sondern eine neue Kandidatenreihenfolge.
///
/// ## Determinismus
/// Der gesamte Suchzustand liegt in Arrays mit fester Indexordnung. Es wird
/// nirgends ueber ein `Set` oder ein `Dictionary` iteriert, weil Swift den
/// Hash-Seed pro Prozesslauf randomisiert und die Suche sonst bei gleichem Seed
/// unterschiedliche Ergebnisse liefern koennte.
internal enum OpponentMatcher {

    // MARK: - Fachliche Konstanten

    /// Gegner, die jedes Team aus jedem einzelnen Topf bekommt - auch aus dem
    /// eigenen. Vier Toepfe mal zwei Gegner ergibt die acht Gegner je Team.
    internal static let opponentsPerPot: Int = 2

    /// Obergrenze fuer Gegner aus derselben Association je Team.
    internal static let maxOpponentsPerAssociation: Int = 2

    /// Gesamtzahl der zu findenden Kanten (144 bei 36 Teams).
    internal static var totalEdgeCount: Int {
        InputValidation.expectedTeamCount * opponentsPerPot * InputValidation.potsInOrder.count / 2
    }

    // MARK: - Ergebnistypen

    /// Eine ungerichtete Paarung zweier Team-Indizes.
    ///
    /// Die Normalisierung `a < b` passiert im Initialisierer. Dadurch sind
    /// "A gegen B" und "B gegen A" derselbe Wert, und die Symmetrie der
    /// Auslosung ist keine Zusicherung des Aufrufers mehr, sondern eine
    /// Eigenschaft des Typs. Die Richtung (Heimrecht) wird spaeter beim Bau der
    /// `Matchup`-Werte vergeben.
    internal struct Edge: Hashable, Comparable, Sendable {

        /// Kleinerer der beiden Team-Indizes.
        internal let a: Int

        /// Groesserer der beiden Team-Indizes.
        internal let b: Int

        /// Erzeugt eine Kante aus zwei verschiedenen Team-Indizes in beliebiger
        /// Reihenfolge.
        internal init(_ erster: Int, _ zweiter: Int) {
            precondition(erster != zweiter, "Eine Kante darf ein Team nicht mit sich selbst verbinden")
            if erster < zweiter {
                a = erster
                b = zweiter
            } else {
                a = zweiter
                b = erster
            }
        }

        /// Totalordnung ueber `(a, b)`. Beide Teilvergleiche zusammen sind
        /// eindeutig, weil eine Kante durch ihr Indexpaar vollstaendig bestimmt ist.
        internal static func < (lhs: Edge, rhs: Edge) -> Bool {
            if lhs.a != rhs.a { return lhs.a < rhs.a }
            return lhs.b < rhs.b
        }
    }

    /// Ergebnis eines Matching-Laufs.
    internal struct Outcome: Sendable {

        /// Die 144 gefundenen Paarungen **in Platzierungsreihenfolge** der Suche.
        ///
        /// Die Reihenfolge ist bei gleichem Seed reproduzierbar, aber bewusst
        /// nicht kanonisch sortiert: Sie bildet ab, in welcher Reihenfolge die
        /// Suche die Kanten gesetzt hat. Wer eine kanonische Liste braucht,
        /// sortiert selbst - `Edge` ist `Comparable`.
        internal let edges: [Edge]

        /// Anzahl der ausprobierten Kantenplatzierungen inklusive der wieder
        /// zurueckgenommenen. Ein Mass fuer den Suchaufwand: 144 bedeutet, dass
        /// die Suche ohne einen einzigen Rueckschritt durchgelaufen ist.
        internal let exploredNodes: Int
    }

    // MARK: - Neustart-Strategie

    /// Knotenbudget des ersten Suchversuchs.
    ///
    /// Ein gesunder Lauf braucht rund 150 Knoten. Wer nach dem Vierzehnfachen
    /// davon noch nichts gefunden hat, hat sich in aller Regel verrannt und
    /// kommt auch mit dem Hundertfachen nicht mehr heraus. Dann ist ein
    /// Neustart mit frischer Kandidatenreihenfolge billiger als Weitersuchen.
    internal static let restartNodeBudget: Int = 2_000

    /// Wie oft dasselbe Versuchsbudget wiederholt wird, bevor es sich verdoppelt.
    ///
    /// Reine Verdopplung waere fuer das zweigipflige Aufwandsprofil zu grob: Sie
    /// verbraucht das Gesamtbudget in wenigen, immer teureren Versuchen, obwohl
    /// mehr *verschiedene* Kandidatenreihenfolgen die weitaus bessere Waehrung
    /// sind. Die Wiederholung je Stufe erhoeht die Zahl der Versuche etwa um den
    /// Faktor drei, ohne die Vollstaendigkeit aufzugeben: Weil das Budget
    /// weiterhin unbeschraenkt waechst, wird jeder endliche Suchraum irgendwann
    /// vollstaendig durchlaufen.
    internal static let restartsPerBudgetLevel: Int = 3

    // MARK: - Einstieg

    /// Sucht eine gueltige Gegner-Zuordnung fuer alle Teams des Kontexts.
    ///
    /// ## Neustarts
    /// Die Suche laeuft nicht als ein einziger Durchgang, sondern als Folge von
    /// Versuchen mit wachsendem Teilbudget. Reisst das Teilbudget eines
    /// Versuchs, beginnt der naechste mit einer frisch abgeleiteten
    /// Kandidatenreihenfolge von vorne. Der Grund ist das gemessene
    /// Aufwandsprofil: Entweder findet ein Versuch die Loesung in der
    /// Groessenordnung von 150 Knoten, oder er findet sie auch nach Millionen
    /// Knoten nicht mehr. Ein groesseres Budget hilft dagegen nicht, eine andere
    /// Reihenfolge schon.
    ///
    /// Die Vollstaendigkeit bleibt erhalten:
    /// - Laeuft ein Versuch seinen Suchraum vollstaendig und erfolglos durch,
    ///   wird sofort `.unsolvable` gemeldet und **nicht** neu gestartet.
    ///   Unloesbarkeit ist eine Eigenschaft der Eingabe; die
    ///   Kandidatenreihenfolge aendert die Reihenfolge der Zweige, nicht deren
    ///   Anzahl. Ein einziger vollstaendiger Durchlauf ist also bereits der
    ///   Widerspruchsbeweis.
    /// - Das Teilbudget waechst unbeschraenkt. Ein endlicher Suchraum wird damit
    ///   irgendwann in einem Versuch vollstaendig durchlaufen, sofern das
    ///   Gesamtbudget reicht.
    ///
    /// Determinismus: Alle Versuchs-Generatoren stammen aus einem einzigen
    /// Strom, der aus genau einem `next()` auf `rng` abgeleitet wird. `rng`
    /// schreitet damit unabhaengig von der Zahl der Versuche um genau einen
    /// Schritt fort, und die Phasen B und C bleiben vom Suchverlauf entkoppelt.
    ///
    /// - Parameters:
    ///   - context: Die validierte Index-Repraesentation der Teilnehmer.
    ///   - rng: Generator fuer die Kandidatenreihenfolge. Sein Zustand schreitet
    ///     um genau einen Schritt fort, damit derselbe Generator anschliessend
    ///     weiterverwendet werden kann.
    ///   - maxSearchNodes: Obergrenze fuer `exploredNodes` **ueber alle Versuche
    ///     zusammen**. Schuetzt vor einer Suche, die bei einer pathologischen
    ///     Eingabe praktisch nicht terminiert.
    /// - Returns: Die 144 Kanten und den gemessenen Suchaufwand (Summe ueber
    ///   alle Versuche).
    /// - Throws: `.unsolvable`, wenn ein Versuch seinen Suchraum vollstaendig und
    ///   erfolglos durchlaufen hat; `.searchBudgetExceeded(exploredNodes:)`, wenn
    ///   das Gesamtbudget vorher aufgebraucht war.
    internal static func match(
        context: DrawContext,
        rng: inout SplitMix64,
        maxSearchNodes: Int
    ) throws(DrawError) -> Outcome {
        precondition(
            context.teamCount <= UInt64.bitWidth,
            "Die Adjazenz-Bitmasken fassen hoechstens \(UInt64.bitWidth) Teams"
        )

        // Genau ein Zugriff auf den uebergebenen Generator, egal wie viele
        // Versuche folgen. Alles Weitere kommt aus dem abgeleiteten Strom.
        var neustartStream = SplitMix64(seed: rng.next())

        var verbrauchteKnoten = 0
        var versuchsbudget = restartNodeBudget
        var versucheAufDieserStufe = 0

        while true {
            var versuchsRng = SplitMix64(seed: neustartStream.next())

            // Absolute Obergrenze dieses Versuchs, gemessen am Gesamtzaehler.
            // Das Gesamtbudget hat immer Vorrang.
            let grenzeDesVersuchs = min(maxSearchNodes, verbrauchteKnoten &+ versuchsbudget)

            var suche = Search(context: context)
            suche.exploredNodes = verbrauchteKnoten

            let ausgang = attempt(
                &suche,
                rng: &versuchsRng,
                attemptLimit: grenzeDesVersuchs,
                totalLimit: maxSearchNodes
            )
            verbrauchteKnoten = suche.exploredNodes

            switch ausgang {
            case .solution(let kanten):
                return Outcome(edges: kanten, exploredNodes: verbrauchteKnoten)

            case .exhausted:
                // Vollstaendig durchsuchter Raum ohne Treffer. Ein Neustart
                // wuerde denselben Raum in anderer Reihenfolge noch einmal
                // durchlaufen und wieder nichts finden.
                throw DrawError.unsolvable

            case .totalLimitReached:
                throw DrawError.searchBudgetExceeded(exploredNodes: verbrauchteKnoten)

            case .attemptLimitReached:
                versucheAufDieserStufe += 1
                if versucheAufDieserStufe >= restartsPerBudgetLevel {
                    versucheAufDieserStufe = 0
                    // Sicherung gegen den Ueberlauf; praktisch unerreichbar,
                    // weil das Gesamtbudget lange vorher greift.
                    versuchsbudget = versuchsbudget > Int.max / 2 ? Int.max : versuchsbudget * 2
                }
            }
        }
    }

    // MARK: - Ein einzelner Suchversuch

    /// Ausgang eines einzelnen Suchversuchs.
    private enum AttemptOutcome {

        /// Vollstaendige Belegung gefunden.
        case solution([Edge])

        /// Der Suchraum wurde vollstaendig und erfolglos durchlaufen.
        case exhausted

        /// Nur das Teilbudget dieses Versuchs ist aufgebraucht.
        case attemptLimitReached

        /// Das Gesamtbudget ist aufgebraucht.
        case totalLimitReached
    }

    /// Fuehrt genau einen Suchversuch aus.
    ///
    /// Der Knotenzaehler in `suche` laeuft ueber alle Versuche hinweg weiter; er
    /// wird vom Aufrufer vorbelegt und hier nur erhoeht. Beide Grenzen sind
    /// deshalb absolute Werte dieses Gesamtzaehlers, keine Restwerte.
    private static func attempt(
        _ suche: inout Search,
        rng: inout SplitMix64,
        attemptLimit: Int,
        totalLimit: Int
    ) -> AttemptOutcome {

        // Der Frame-Stack ersetzt die Rekursion. Zwei Gruende: Erstens bleibt die
        // Suchtiefe (144 Entscheidungen plus Fehlversuche) unabhaengig vom
        // Stack-Limit des Threads, zweitens wird das Zuruecknehmen einer Kante zu
        // einem expliziten Schritt statt zu einem impliziten Nebeneffekt des
        // Funktionsaustritts.
        var frames: [Frame] = []
        frames.reserveCapacity(totalEdgeCount)

        naechsteEntscheidung: while true {

            // Schritt 1: Das erste Topfpaar, das noch Kanten braucht. Sind alle
            // vollstaendig, ist die Loesung fertig.
            guard let paarIndex = suche.firstIncompletePotPairIndex() else {
                return .solution(suche.placedEdges)
            }
            let paar = potPairsInOrder[paarIndex]

            // Schritt 2: MRV - das Team mit der kleinsten Restauswahl zuerst.
            let team = suche.teamWithFewestCandidates(in: paar)

            // Schritt 3: Kandidaten aufsteigend sammeln und mischen. Nur hier
            // wirkt der Zufall; die Menge der Kandidaten selbst ist deterministisch.
            var kandidaten = suche.candidateList(for: team, in: paar)
            kandidaten.deterministicShuffle(using: &rng)
            frames.append(Frame(team: team, candidates: kandidaten, nextIndex: 0, potPairIndex: paarIndex))

            while let oberster = frames.last {

                // Schritt 6: Kandidaten erschoepft. Der Frame faellt weg, und die
                // Kante des darunter liegenden Frames wird zurueckgenommen, damit
                // dort der naechste Kandidat probiert werden kann. Weil der Stack
                // die Topfpaar-Grenzen nicht kennt, laeuft das Zuruecksetzen
                // automatisch auch ueber sie hinweg.
                guard oberster.nextIndex < oberster.candidates.count else {
                    frames.removeLast()
                    if !frames.isEmpty { suche.undoLastEdge() }
                    continue
                }

                // Schritt 4: Naechsten Kandidaten festlegen und Kante setzen.
                let gegner = oberster.candidates[oberster.nextIndex]
                frames[frames.count - 1].nextIndex += 1

                suche.exploredNodes += 1
                // Schritt 8: Budget zuerst pruefen, damit auch eine entartete
                // Eingabe garantiert terminiert. Das Gesamtbudget hat Vorrang,
                // damit ein aufgebrauchtes Gesamtbudget nie als blosses
                // Versuchsende durchgeht.
                if suche.exploredNodes > totalLimit { return .totalLimitReached }
                if suche.exploredNodes > attemptLimit { return .attemptLimitReached }

                suche.placeEdge(oberster.team, gegner)

                // Schritt 5: Haelt der Zustand den Forward-Checks stand, geht es
                // eine Ebene tiefer. Sonst wird die Kante sofort zurueckgezogen
                // und derselbe Frame probiert den naechsten Kandidaten.
                if suche.forwardChecksPass() {
                    continue naechsteEntscheidung
                }
                suche.undoLastEdge()
            }

            // Schritt 7: Der Stack ist leer. Damit wurde der gesamte Suchraum
            // durchlaufen, ohne dass eine Belegung gehalten haette.
            return .exhausted
        }
    }
}

// MARK: - Topfpaare

/// Ein Topfpaar `(i, j)` mit `i <= j`, beide Topfnummern nullbasiert.
private struct PotPair {

    /// Nullbasierte Nummer des ersten Topfes.
    let i: Int

    /// Nullbasierte Nummer des zweiten Topfes, nie kleiner als `i`.
    let j: Int

    /// Wahr, wenn beide Seiten derselbe Topf sind.
    var isSamePot: Bool { i == j }

    /// Die beteiligten Topfnummern - bei einem Same-Pot-Paar nur eine, sonst zwei.
    ///
    /// Wird ueberall dort benutzt, wo ueber alle Teams des Paars gelaufen wird.
    /// Ohne diese Unterscheidung wuerde bei `i == j` jedes Team doppelt geprueft.
    var involvedPots: [Int] { i == j ? [i] : [i, j] }

    /// Zielanzahl der Kanten dieses Teilgraphen.
    ///
    /// Same-Pot: neun Knoten mit Grad zwei ergeben `9 * 2 / 2 = 9` Kanten.
    /// Cross-Pot: die neun Knoten je Seite mit Grad zwei ergeben `9 * 2 = 18`
    /// Kanten, weil jede Kante genau einen Knoten je Seite verbraucht.
    var targetEdgeCount: Int {
        let proSeite = InputValidation.expectedPotSize * OpponentMatcher.opponentsPerPot
        return isSamePot ? proSeite / 2 : proSeite
    }
}

/// Alle Topfpaare in Row-Major-Reihenfolge:
/// `(0,0), (0,1), (0,2), (0,3), (1,1), (1,2), (1,3), (2,2), (2,3), (3,3)`.
///
/// Warum genau diese Reihenfolge? Chronologisches Backtracking nimmt bei einem
/// Konflikt immer die zuletzt gesetzte Entscheidung zurueck, auch wenn diese mit
/// der Konfliktursache nichts zu tun hat. Es re-exploriert damit alle
/// dazwischenliegenden, voneinander unabhaengigen Teilprobleme. Row-Major haelt
/// zusammen, was sich gegenseitig einschraenkt: Alle Paare eines Topfes stehen
/// direkt hintereinander, ein Konflikt liegt also nahe an seiner Ursache.
///
/// Wichtig: Das allein genuegt **nicht**. Die Verbandsobergrenze koppelt jedes
/// Topfpaar mit jedem anderen, das einen Topf mit ihm teilt, und diese Kopplung
/// laesst sich durch keine Reihenfolge aufloesen. Gegen das Thrashing wirken
/// deshalb die global rechnenden Forward-Checks (`forwardChecksPass`) und die
/// Neustarts in `OpponentMatcher.match`; die Reihenfolge hier ist nur die
/// billigste zusaetzliche Hilfe.
private let potPairsInOrder: [PotPair] = {
    var liste: [PotPair] = []
    let anzahlToepfe = InputValidation.potsInOrder.count
    liste.reserveCapacity(anzahlToepfe * (anzahlToepfe + 1) / 2)
    for i in 0 ..< anzahlToepfe {
        for j in i ..< anzahlToepfe {
            liste.append(PotPair(i: i, j: j))
        }
    }
    return liste
}()

// MARK: - Frame des Suchstacks

/// Eine Entscheidungsebene der Tiefensuche.
///
/// Ein Frame steht fuer genau ein Team, dem in genau einem Topfpaar ein Gegner
/// zugewiesen werden soll. Sobald der Frame eine Kante gesetzt hat, gehoert ihm
/// die jeweils oberste Kante des Kanten-Stacks - deshalb genuegt beim
/// Zuruecknehmen `undoLastEdge()` ohne weitere Buchhaltung.
private struct Frame {

    /// Team-Index, fuer den hier entschieden wird.
    let team: Int

    /// Zulaessige Gegner zum Zeitpunkt der Frame-Erzeugung, bereits gemischt.
    let candidates: [Int]

    /// Position des naechsten noch nicht probierten Kandidaten.
    var nextIndex: Int

    /// Index des Topfpaars in `potPairsInOrder`, zu dem die Entscheidung gehoert.
    let potPairIndex: Int
}

// MARK: - Suchzustand

/// Veraenderlicher Zustand der Tiefensuche.
///
/// Alle Felder sind Arrays fester Groesse und werden ausschliesslich ueber
/// Indizes angesprochen. Jede Aenderung laeuft ueber `placeEdge` beziehungsweise
/// `undoLastEdge`, damit die Zaehler untereinander konsistent bleiben.
private struct Search {

    // MARK: Unveraenderliche Kennzahlen

    /// Nullbasierte Topfnummer je Team-Index.
    let potOfTeam: [Int]

    /// Verbandsnummer je Team-Index.
    let associationOfTeam: [Int]

    /// Anzahl der verschiedenen Associations.
    let associationCount: Int

    /// Index-Bereich je Topf, also `[0..<9, 9..<18, 18..<27, 27..<36]`.
    let potRanges: [Range<Int>]

    /// Nachschlagetabelle Topfnummer x Topfnummer -> Index in `potPairsInOrder`.
    let potPairIndexTable: [[Int]]

    // MARK: Veraenderlicher Zustand

    /// Bitmaske der bereits zugeteilten Gegner je Team.
    ///
    /// Bit `k` in `adjacency[t]` bedeutet: Team `k` ist schon Gegner von Team `t`.
    /// Die Maske ist symmetrisch gepflegt und macht den Test "schon gepaart?" zu
    /// einer einzelnen Bitoperation.
    var adjacency: [UInt64]

    /// Bereits zugeteilte Gegner je Team und Topf (36 x 4), Zielwert ueberall zwei.
    var potOpponentCount: [[Int]]

    /// Bereits zugeteilte Gegner je Team und Association (36 x Verbandszahl),
    /// Obergrenze zwei.
    var assocOpponentCount: [[Int]]

    /// Gesetzte Kanten je Topfpaar, verglichen mit `PotPair.targetEdgeCount`.
    var potPairEdgeCount: [Int]

    /// Alle gesetzten Kanten in Platzierungsreihenfolge; zugleich der Undo-Stack.
    var placedEdges: [OpponentMatcher.Edge]

    /// Zaehler fuer probierte Kantenplatzierungen inklusive der verworfenen.
    var exploredNodes: Int

    // MARK: - Aufbau

    /// Legt den leeren Suchzustand fuer einen Kontext an.
    init(context: DrawContext) {
        let teamCount = context.teamCount
        let potCount = InputValidation.potsInOrder.count

        potOfTeam = context.potIndex
        associationOfTeam = context.associationIndex
        associationCount = context.associationCount

        var bereiche: [Range<Int>] = []
        bereiche.reserveCapacity(potCount)
        for topf in InputValidation.potsInOrder {
            bereiche.append(context.teamIndices(inPot: topf))
        }
        potRanges = bereiche

        // Umkehrung von `potPairsInOrder`: Aus zwei Topfnummern wird in einem
        // Schritt der Paarindex, ohne die Liste zu durchsuchen.
        var tabelle = [[Int]](repeating: [Int](repeating: 0, count: potCount), count: potCount)
        for (index, paar) in potPairsInOrder.enumerated() {
            tabelle[paar.i][paar.j] = index
            tabelle[paar.j][paar.i] = index
        }
        potPairIndexTable = tabelle

        adjacency = [UInt64](repeating: 0, count: teamCount)
        potOpponentCount = [[Int]](repeating: [Int](repeating: 0, count: potCount), count: teamCount)
        assocOpponentCount = [[Int]](
            repeating: [Int](repeating: 0, count: context.associationCount),
            count: teamCount
        )
        potPairEdgeCount = [Int](repeating: 0, count: potPairsInOrder.count)
        placedEdges = []
        placedEdges.reserveCapacity(OpponentMatcher.totalEdgeCount)
        exploredNodes = 0
    }

    // MARK: - Kante setzen und zuruecknehmen

    /// Setzt die Kante zwischen zwei Teams und zieht alle Zaehler nach.
    ///
    /// Der Aufrufer muss `isValidCandidate` vorher geprueft haben; hier wird
    /// nichts mehr validiert.
    mutating func placeEdge(_ u: Int, _ v: Int) {
        adjacency[u] |= UInt64(1) << UInt64(v)
        adjacency[v] |= UInt64(1) << UInt64(u)
        potOpponentCount[u][potOfTeam[v]] += 1
        potOpponentCount[v][potOfTeam[u]] += 1
        assocOpponentCount[u][associationOfTeam[v]] += 1
        assocOpponentCount[v][associationOfTeam[u]] += 1
        potPairEdgeCount[potPairIndexTable[potOfTeam[u]][potOfTeam[v]]] += 1
        placedEdges.append(OpponentMatcher.Edge(u, v))
    }

    /// Nimmt die zuletzt gesetzte Kante vollstaendig zurueck.
    ///
    /// Weil Kanten nur am Ende angehaengt und nur von dort entfernt werden, ist
    /// der Zustand nach dem Undo exakt derselbe wie vor dem zugehoerigen
    /// `placeEdge`. Genau darauf beruht die Annahme, dass die im Frame
    /// gespeicherten Kandidaten nach einem Rueckschritt weiterhin gueltig sind.
    mutating func undoLastEdge() {
        guard let kante = placedEdges.popLast() else { return }
        let u = kante.a
        let v = kante.b
        adjacency[u] &= ~(UInt64(1) << UInt64(v))
        adjacency[v] &= ~(UInt64(1) << UInt64(u))
        potOpponentCount[u][potOfTeam[v]] -= 1
        potOpponentCount[v][potOfTeam[u]] -= 1
        assocOpponentCount[u][associationOfTeam[v]] -= 1
        assocOpponentCount[v][associationOfTeam[u]] -= 1
        potPairEdgeCount[potPairIndexTable[potOfTeam[u]][potOfTeam[v]]] -= 1
    }

    // MARK: - Abfragen zum Zustand

    /// Index des ersten Topfpaars in Row-Major-Reihenfolge, das noch Kanten
    /// braucht, oder `nil`, wenn alle vollstaendig sind.
    func firstIncompletePotPairIndex() -> Int? {
        for index in 0 ..< potPairsInOrder.count
        where potPairEdgeCount[index] < potPairsInOrder[index].targetEdgeCount {
            return index
        }
        return nil
    }

    /// Der Topf, aus dem die Gegner dieses Teams innerhalb des Paars stammen.
    ///
    /// Bei einem Cross-Pot-Paar ist das die jeweils andere Seite, bei einem
    /// Same-Pot-Paar der eigene Topf.
    func candidatePot(for team: Int, in paar: PotPair) -> Int {
        potOfTeam[team] == paar.i ? paar.j : paar.i
    }

    /// Wie viele Gegner diesem Team aus dem angegebenen Topf noch fehlen.
    func openSlots(for team: Int, towards topf: Int) -> Int {
        OpponentMatcher.opponentsPerPot - potOpponentCount[team][topf]
    }

    /// Prueft, ob `v` fuer `u` ein zulaessiger Gegner ist.
    ///
    /// Die Bedingungen sind bewusst symmetrisch formuliert: Sie gelten fuer das
    /// Paar, nicht fuer eine Richtung. Deshalb ist die Funktion unabhaengig
    /// davon, welches der beiden Teams gerade das "aktive" ist.
    func isValidCandidate(_ u: Int, _ v: Int) -> Bool {
        if u == v { return false }
        if adjacency[u] & (UInt64(1) << UInt64(v)) != 0 { return false }

        let verbandU = associationOfTeam[u]
        let verbandV = associationOfTeam[v]
        if verbandU == verbandV { return false }

        let obergrenze = OpponentMatcher.maxOpponentsPerAssociation
        if assocOpponentCount[u][verbandV] >= obergrenze { return false }
        if assocOpponentCount[v][verbandU] >= obergrenze { return false }

        if potOpponentCount[u][potOfTeam[v]] >= OpponentMatcher.opponentsPerPot { return false }
        if potOpponentCount[v][potOfTeam[u]] >= OpponentMatcher.opponentsPerPot { return false }

        return true
    }

    /// Anzahl der zulaessigen Gegner fuer `team` im angegebenen Topf.
    func candidateCount(for team: Int, inPot topf: Int) -> Int {
        var anzahl = 0
        for gegner in potRanges[topf] where isValidCandidate(team, gegner) {
            anzahl += 1
        }
        return anzahl
    }

    /// Alle zulaessigen Gegner fuer `team` innerhalb des Paars, aufsteigend nach
    /// Team-Index.
    ///
    /// Die aufsteigende Reihenfolge ist die deterministische Ausgangsbasis; erst
    /// das anschliessende Mischen im Aufrufer bringt den Zufall hinein.
    func candidateList(for team: Int, in paar: PotPair) -> [Int] {
        let zielTopf = candidatePot(for: team, in: paar)
        var liste: [Int] = []
        liste.reserveCapacity(InputValidation.expectedPotSize)
        for gegner in potRanges[zielTopf] where isValidCandidate(team, gegner) {
            liste.append(gegner)
        }
        return liste
    }

    // MARK: - Variablenauswahl (MRV)

    /// Das Team des Paars mit der kleinsten Restauswahl an Gegnern.
    ///
    /// MRV (Minimum Remaining Values) greift die knappste Entscheidung zuerst
    /// auf: Wo am wenigsten Auswahl bleibt, faellt ein Fehlschlag am fruehesten
    /// auf und kostet am wenigsten. Ein Team mit null Kandidaten wird dadurch
    /// sofort gewaehlt und fuehrt ohne Umweg zum Rueckschritt.
    ///
    /// Bei Gleichstand gewinnt der kleinste Team-Index. Das ergibt sich hier
    /// ohne Zusatzlogik, weil die Schleife die Indizes aufsteigend durchlaeuft
    /// (bei Cross-Pot zuerst Topf `i`, dessen Indizes alle kleiner sind als die
    /// von Topf `j`) und nur ein echt kleinerer Zaehler den Favoriten ersetzt.
    func teamWithFewestCandidates(in paar: PotPair) -> Int {
        var bestesTeam = -1
        var besteAnzahl = Int.max

        for topf in paar.involvedPots {
            for team in potRanges[topf] {
                let zielTopf = candidatePot(for: team, in: paar)
                guard openSlots(for: team, towards: zielTopf) > 0 else { continue }
                let anzahl = candidateCount(for: team, inPot: zielTopf)
                if anzahl < besteAnzahl {
                    besteAnzahl = anzahl
                    bestesTeam = team
                }
            }
        }

        guard bestesTeam >= 0 else {
            // Unerreichbar: Ein unvollstaendiges Topfpaar hat immer offene Slots.
            // Bei Same-Pot verbraucht jede Kante zwei der 18 Slots, bei Cross-Pot
            // je einen der 18 Slots pro Seite. Solange die Kantenzahl unter dem
            // Ziel liegt, bleibt auf jeder Seite mindestens ein Slot offen.
            preconditionFailure("Unvollstaendiges Topfpaar ohne Team mit offenen Slots")
        }
        return bestesTeam
    }

    // MARK: - Forward-Checks

    /// Prueft, ob der aktuelle Zustand ueberhaupt noch vervollstaendigt werden kann.
    ///
    /// Alle drei Checks sind notwendige Bedingungen, keine hinreichenden: Sie
    /// schneiden Zweige ab, die garantiert scheitern, garantieren aber keine
    /// Loesung. Genau das ist der Zweck - je frueher ein aussichtsloser Zweig
    /// auffaellt, desto weniger Enumeration.
    ///
    /// Entscheidend ist, dass alle drei **global** rechnen und nicht nur ueber
    /// das gerade bearbeitete Topfpaar. Die Verbandsobergrenze von zwei zaehlt
    /// je Team ueber alle Toepfe zusammen; eine Kante in Topfpaar (1,2) kann
    /// deshalb ein Team in Topf 4 unbedienbar machen. Ein topfpaar-lokaler Check
    /// sieht das erst, wenn die Bearbeitungsreihenfolge dort angekommen ist -
    /// also viele hundert Entscheidungen zu spaet, und das chronologische
    /// Backtracking re-exploriert bis dahin alle dazwischenliegenden,
    /// unbeteiligten Teilprobleme.
    func forwardChecksPass() -> Bool {
        guard perTeamCheckPasses() else { return false }
        guard globalAssociationCheckPasses() else { return false }

        // Der topfpaar-genaue Verbands-Check bleibt zusaetzlich erhalten: Er ist
        // in der Angebotsschaetzung schaerfer als der globale, weil er nur die
        // offenen Slots in Richtung des Quelltopfs zaehlt statt aller offenen
        // Slots. Beide Schranken schneiden verschiedene Sackgassen weg.
        //
        // Fuer Same-Pot-Paare (`i == j`) entfaellt er: Dort waere dieselbe Kante
        // gleichzeitig Bedarf und Angebot, die Schranke waere nicht mehr
        // konservativ und koennte gueltige Zustaende verwerfen.
        for paar in potPairsInOrder where !paar.isSamePot {
            guard associationSupplyCheckPasses(from: paar.i, to: paar.j) else { return false }
            guard associationSupplyCheckPasses(from: paar.j, to: paar.i) else { return false }
        }
        return true
    }

    /// Check (a): Jedes Team braucht in **jedem** Topf mindestens so viele
    /// zulaessige Kandidaten, wie ihm dort Gegner fehlen.
    ///
    /// Das ist die lokale Konsistenz einer einzelnen Variablen. Sie faengt den
    /// haeufigsten Fehlschlag ab: ein Team, dessen Auswahl durch die zuletzt
    /// gesetzte Kante unter seinen Restbedarf gefallen ist.
    ///
    /// Die Bedingung ist unabhaengig davon notwendig, welches Topfpaar gerade
    /// bearbeitet wird: Die Kandidatenmenge eines Teams schrumpft im Verlauf der
    /// Suche nur, sie waechst nie wieder. Wer heute zu wenige Kandidaten hat,
    /// hat sie auch spaeter nicht.
    func perTeamCheckPasses() -> Bool {
        for team in 0 ..< potOfTeam.count {
            for topf in 0 ..< potRanges.count {
                let offen = openSlots(for: team, towards: topf)
                guard offen > 0 else { continue }
                if candidateCount(for: team, inPot: topf) < offen { return false }
            }
        }
        return true
    }

    /// Check (c): Aggregierter Verbands-Abgleich je Association und Zieltopf,
    /// ueber alle Toepfe hinweg.
    ///
    /// Fuer eine Association X und einen Topf P gilt: Jedes Team aus X - egal in
    /// welchem Topf es steht - braucht genau zwei Gegner aus P, und diese Gegner
    /// koennen nur Teams aus P sein, die nicht zu X gehoeren. Jedes solche Team
    /// `w` kann hoechstens `2 - assocOpponentCount[w][X]` weitere X-Gegner
    /// aufnehmen und ohnehin nur so viele, wie es ueberhaupt noch offene Slots
    /// hat. Der Bedarf ist die Summe der offenen Slots aller X-Teams in Richtung
    /// P.
    ///
    /// Im Ausgangszustand faellt die Schranke auf die geschlossene Form
    /// `m + k <= 9` zusammen (`m` Teams der Association insgesamt, `k` davon in
    /// Topf P). Sie ist damit strikt schaerfer als alle drei Schranken der
    /// Vorpruefung: Aufsummiert ueber die vier Toepfe liefert sie `m <= 7`, mit
    /// `m >= k` liefert sie `k <= 4`, und wegen `m >= a + b` deckt sie auch
    /// `a + b <= 9` ab.
    ///
    /// Genau dieser Check ist der Grund, warum eine unloesbare
    /// Verbandsverteilung auffaellt, bevor die Suche sie durch Enumeration
    /// widerlegen muesste.
    ///
    /// Determinismus: Die Schleifen laufen ueber Int-Bereiche mit fester Ordnung,
    /// nie ueber eine Menge von Associations.
    func globalAssociationCheckPasses() -> Bool {
        let potCount = potRanges.count
        let teamCount = potOfTeam.count

        // Bedarf je (Association, Zieltopf), flach ausgelegt statt verschachtelt:
        // eine einzige Allokation je Aufruf statt einer je Association.
        var bedarf = [Int](repeating: 0, count: associationCount * potCount)
        for team in 0 ..< teamCount {
            let verband = associationOfTeam[team]
            for topf in 0 ..< potCount {
                let offen = openSlots(for: team, towards: topf)
                if offen > 0 { bedarf[verband * potCount + topf] += offen }
            }
        }

        for verband in 0 ..< associationCount {
            for topf in 0 ..< potCount {
                let benoetigt = bedarf[verband * potCount + topf]
                guard benoetigt > 0 else { continue }

                var angebot = 0
                for w in potRanges[topf] where associationOfTeam[w] != verband {
                    let restkapazitaet = OpponentMatcher.maxOpponentsPerAssociation
                        - assocOpponentCount[w][verband]
                    guard restkapazitaet > 0 else { continue }

                    var offeneSlots = 0
                    for quelle in 0 ..< potCount { offeneSlots += openSlots(for: w, towards: quelle) }

                    angebot += min(restkapazitaet, offeneSlots)
                    // Sobald das Angebot reicht, ist der genaue Wert unerheblich.
                    if angebot >= benoetigt { break }
                }

                if angebot < benoetigt { return false }
            }
        }
        return true
    }

    /// Check (b): Aggregierter Verbands-Abgleich fuer eine Richtung eines
    /// Cross-Pot-Paars.
    ///
    /// Fuer jede Association X mit offenem Bedarf im Quelltopf wird der Bedarf
    /// (Summe der offenen Slots aller X-Teams) gegen das Angebot im Zieltopf
    /// gestellt. Jedes Team `w` des Zieltopfes kann hoechstens
    /// `min(eigene offene Slots, Restkapazitaet fuer X)` Gegner aus X aufnehmen;
    /// Teams aus X selbst zaehlen gar nicht, weil sie nicht gegeneinander
    /// spielen duerfen.
    ///
    /// Er betrachtet alle X-Teams gemeinsam statt jedes fuer sich und findet
    /// damit genau die Engpaesse, die dem Per-Team-Check entgehen. Gegenueber
    /// dem globalen Check (c) ist er in der Angebotsschaetzung schaerfer, weil er
    /// nur die offenen Slots in Richtung `quelle` zaehlt statt aller offenen
    /// Slots des Teams; dafuer sieht er nur ein Topfpaar. Die beiden ergaenzen
    /// sich, deshalb laufen beide.
    func associationSupplyCheckPasses(from quelle: Int, to ziel: Int) -> Bool {
        var bedarfJeVerband = [Int](repeating: 0, count: associationCount)
        for team in potRanges[quelle] {
            let offen = openSlots(for: team, towards: ziel)
            if offen > 0 { bedarfJeVerband[associationOfTeam[team]] += offen }
        }

        // Schleife ueber Verbandsnummern, also ueber einen Int-Bereich mit fester
        // Ordnung - bewusst nicht ueber eine Menge von Associations.
        for verband in 0 ..< associationCount {
            let bedarf = bedarfJeVerband[verband]
            guard bedarf > 0 else { continue }

            var angebot = 0
            for w in potRanges[ziel] where associationOfTeam[w] != verband {
                let offen = openSlots(for: w, towards: quelle)
                guard offen > 0 else { continue }
                let restkapazitaet = OpponentMatcher.maxOpponentsPerAssociation - assocOpponentCount[w][verband]
                angebot += min(offen, restkapazitaet)
                // Sobald das Angebot reicht, ist der genaue Wert unerheblich.
                if angebot >= bedarf { break }
            }

            if angebot < bedarf { return false }
        }
        return true
    }
}
