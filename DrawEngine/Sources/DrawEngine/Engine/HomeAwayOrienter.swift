/// Vergibt das Heimrecht, indem die ungerichteten Paarungen aus Phase A zu
/// gerichteten Begegnungen orientiert werden.
///
/// ## Aufgabe
/// Phase A (`OpponentMatcher`) liefert 144 ungerichtete Kanten. Offen bleibt,
/// wer von beiden das Heimspiel bekommt. Die Fachregel dafuer lautet: Jedes Team
/// hat gegen die beiden Gegner aus einem Topf genau ein Heim- und ein
/// Auswaertsspiel. Ueber alle vier Toepfe ergeben sich damit automatisch vier
/// Heim- und vier Auswaertsspiele je Team.
///
/// ## Warum das immer ohne Backtracking geht
/// Der entscheidende Punkt ist, dass die Regel je Topfpaar formuliert ist. Man
/// kann die 144 Kanten deshalb in die zehn Topfpaar-Teilgraphen `(i, j)` mit
/// `i <= j` zerlegen und jeden fuer sich orientieren.
///
/// 1. **Jeder Topfpaar-Teilgraph ist 2-regulaer.** Jedes beteiligte Team hat in
///    ihm exakt zwei Gegner - genau das hat Phase A erzwungen. Ein Graph, in dem
///    jeder Knoten Grad zwei hat, zerfaellt eindeutig in knotendisjunkte
///    einfache Kreise. Das ist kein Zufall der Eingabe, sondern eine
///    Struktureigenschaft: Verfolgt man von einem Knoten aus einen Weg und
///    verlaesst jeden Knoten ueber die jeweils andere Kante, kann man nie
///    steckenbleiben und nie verzweigen, also schliesst sich der Weg.
///
/// 2. **Jeder Kreis hat mindestens Laenge drei.** Ein Kreis der Laenge zwei
///    waere eine Doppelkante. Die ist ausgeschlossen, weil Phase A dasselbe Paar
///    nie zweimal setzt und jedes Paar zu genau einem Topfpaar gehoert. Eine
///    Schlinge (Laenge eins) ist ausgeschlossen, weil kein Team gegen sich
///    selbst spielt.
///
/// 3. **Ein konsistent orientierter Kreis loest die Aufgabe.** Richtet man einen
///    Kreis `v0 -> v1 -> ... -> vn-1 -> v0` durchgehend in eine Richtung, hat
///    jeder Knoten darin genau eine ausgehende Kante (sein Heimspiel) und genau
///    eine eingehende (sein Auswaertsspiel). Da die Kreise eines Teilgraphen
///    knotendisjunkt sind, gilt das anschliessend fuer jedes beteiligte Team im
///    ganzen Teilgraphen.
///
/// 4. **Das funktioniert fuer jede Kreislaenge, auch fuer ungerade.** Die
///    naheliegende Alternative waere eine 2-Kanten-Faerbung ("eine Kante heim,
///    die andere auswaerts, abwechselnd"). Die scheitert an ungeraden Kreisen:
///    Ein Kreis ungerader Laenge ist nicht 2-kanten-faerbbar, weil sich beim
///    Rundgang die Farben genau einmal wiederholen muessten. Ungerade Kreise
///    kommen hier zwingend vor: Ein Same-Pot-Teilgraph hat neun Knoten, und neun
///    laesst sich nicht in lauter gerade Kreislaengen zerlegen. Die
///    Kreisorientierung kennt dieses Problem nicht - sie ist von der Paritaet
///    voellig unabhaengig.
///
/// Zusammen heisst das: Nach einer erfolgreichen Phase A ist Phase B **immer**
/// loesbar, in einem einzigen Durchlauf, ohne jede Suche und ohne Rueckschritte.
/// Der Zufall steckt ausschliesslich in der Wahl der Umlaufrichtung je Kreis -
/// ein Bit vom Generator, mehr braucht es nicht.
///
/// ## Determinismus
/// Die Gruppen werden in Row-Major-Reihenfolge der Topfpaare durchlaufen, die
/// Kreise je Gruppe beim kleinsten noch unbesuchten Knoten begonnen und die
/// Nachbarlisten aufsteigend gehalten. Damit ist auch die Reihenfolge, in der
/// die Zufallsbits verbraucht werden, eindeutig festgelegt. Es wird nirgends
/// ueber ein `Set` oder ein `Dictionary` iteriert.
internal enum HomeAwayOrienter {

    // MARK: - Ergebnistyp

    /// Eine gerichtete Begegnung zwischen zwei Team-Indizes.
    ///
    /// Im Gegensatz zu `OpponentMatcher.Edge` ist die Reihenfolge hier
    /// bedeutungstragend und wird deshalb bewusst **nicht** normalisiert:
    /// `home` hat Heimrecht, `away` tritt auswaerts an. Der Typ ist die direkte
    /// Vorstufe eines `Matchup`, in dem statt der Indizes die TeamIDs stehen.
    internal struct DirectedEdge: Hashable, Comparable, Sendable {

        /// Team-Index mit Heimrecht.
        internal let home: Int

        /// Team-Index, das auswaerts antritt.
        internal let away: Int

        /// Erzeugt eine gerichtete Begegnung.
        internal init(home: Int, away: Int) {
            precondition(home != away, "Ein Team kann nicht gegen sich selbst antreten")
            self.home = home
            self.away = away
        }

        /// Die zugehoerige ungerichtete Kante.
        ///
        /// Damit laesst sich pruefen, dass die Orientierung genau die Kanten aus
        /// Phase A abbildet - keine erfunden, keine verloren.
        internal var undirected: OpponentMatcher.Edge {
            OpponentMatcher.Edge(home, away)
        }

        /// Totalordnung ueber `(home, away)`. Beide Teilvergleiche zusammen sind
        /// eindeutig, weil eine gerichtete Kante durch ihr geordnetes Indexpaar
        /// vollstaendig bestimmt ist.
        internal static func < (lhs: DirectedEdge, rhs: DirectedEdge) -> Bool {
            if lhs.home != rhs.home { return lhs.home < rhs.home }
            return lhs.away < rhs.away
        }
    }

    // MARK: - Einstieg

    /// Orientiert alle ungerichteten Kanten einer Auslosung.
    ///
    /// - Parameters:
    ///   - edges: Die 144 ungerichteten Paarungen aus Phase A. Die Reihenfolge
    ///     ist egal, das Ergebnis haengt nicht von ihr ab.
    ///   - context: Die Index-Repraesentation der Teilnehmer, gebraucht fuer die
    ///     Topfzuordnung der Teams.
    ///   - rng: Generator fuer die Umlaufrichtung je Kreis. Sein Zustand
    ///     schreitet fort, damit derselbe Generator weiterverwendet werden kann.
    /// - Returns: Die gerichteten Begegnungen, gruppiert nach Topfpaar in
    ///   Row-Major-Reihenfolge und darin in Kreisreihenfolge. Die Liste ist
    ///   bewusst nicht kanonisch sortiert; `DirectedEdge` ist `Comparable`, wer
    ///   eine kanonische Reihenfolge braucht, ruft `.sorted()` auf.
    internal static func orient(
        edges: [OpponentMatcher.Edge],
        context: DrawContext,
        rng: inout SplitMix64
    ) -> [DirectedEdge] {
        let gruppen = adjacencyPerPotPair(edges: edges, context: context)

        var ergebnis: [DirectedEdge] = []
        ergebnis.reserveCapacity(edges.count)

        // Row-Major-Reihenfolge der Topfpaare, weil `gruppen` genau so aufgebaut
        // ist. Sie legt fest, in welcher Reihenfolge die Zufallsbits gezogen
        // werden, und ist damit Teil des Determinismus.
        for adjazenz in gruppen {
            ergebnis.append(contentsOf: orientCycles(adjacency: adjazenz, rng: &rng))
        }

        checkHomeAwayBalance(ergebnis, context: context)
        return ergebnis
    }

    // MARK: - Gruppierung nach Topfpaar

    /// Baut je Topfpaar eine Adjazenzliste ueber alle Team-Indizes.
    ///
    /// Das Ergebnis hat einen Eintrag je Topfpaar in Row-Major-Reihenfolge, also
    /// `(0,0), (0,1), (0,2), (0,3), (1,1), ... , (3,3)`. Jeder Eintrag ist ein
    /// Array der Laenge `context.teamCount`: Teams, die an diesem Topfpaar nicht
    /// beteiligt sind, haben dort eine leere Nachbarliste, alle anderen genau
    /// zwei Nachbarn.
    ///
    /// Die Nachbarlisten werden aufsteigend sortiert. Das ist die Grundlage
    /// dafuer, dass die Kreissuche bei gleichem Kantensatz immer denselben Weg
    /// nimmt - unabhaengig davon, in welcher Reihenfolge Phase A die Kanten
    /// gesetzt hat.
    internal static func adjacencyPerPotPair(
        edges: [OpponentMatcher.Edge],
        context: DrawContext
    ) -> [[[Int]]] {
        let leereAdjazenz = [[Int]](repeating: [], count: context.teamCount)
        var gruppen = [[[Int]]](repeating: leereAdjazenz, count: potPairCount)

        for kante in edges {
            let index = potPairIndexTable[context.potIndex[kante.a]][context.potIndex[kante.b]]
            gruppen[index][kante.a].append(kante.b)
            gruppen[index][kante.b].append(kante.a)
        }

        // Nach dem Einfuegen sortieren statt sortiert einzufuegen: Ein Team kann
        // in einer Kante die kleinere und in der naechsten die groessere Seite
        // sein, die Anhaengereihenfolge ist also nicht schon aufsteigend.
        for index in 0 ..< gruppen.count {
            for knoten in 0 ..< context.teamCount where gruppen[index][knoten].count > 1 {
                gruppen[index][knoten].sort()
            }
        }
        return gruppen
    }

    // MARK: - Kreiszerlegung

    /// Zerlegt einen 2-regulaeren Graphen in seine knotendisjunkten Kreise.
    ///
    /// Erwartet wird eine Adjazenzliste ueber `0 ..< adjacency.count`, in der
    /// jeder Knoten entweder gar keinen Nachbarn hat (nicht beteiligt) oder
    /// genau zwei, aufsteigend sortiert. Die Vorbedingungen werden geprueft.
    ///
    /// Der Ablauf ist vollstaendig deterministisch:
    /// - Gestartet wird beim **kleinsten** noch unbesuchten beteiligten Knoten.
    /// - Der erste Schritt geht zum **kleineren** der beiden Nachbarn, also zu
    ///   `adjacency[start][0]`, weil die Liste aufsteigend ist.
    /// - Danach wird jeder Knoten ueber den Nachbarn verlassen, der nicht der
    ///   Vorgaenger ist. Weil jeder Knoten genau zwei Nachbarn hat, ist dieser
    ///   Nachbar eindeutig.
    /// - Der Kreis endet, sobald der Startknoten wieder erreicht ist.
    ///
    /// - Returns: Die Kreise als Knotenlisten in Umlaufreihenfolge. Jeder
    ///   beteiligte Knoten kommt in genau einem Kreis genau einmal vor.
    internal static func cycles(inAdjacency adjacency: [[Int]]) -> [[Int]] {
        checkTwoRegular(adjacency)

        var besucht = [Bool](repeating: false, count: adjacency.count)
        var kreise: [[Int]] = []

        for start in 0 ..< adjacency.count {
            guard !adjacency[start].isEmpty, !besucht[start] else { continue }

            var kreis: [Int] = [start]
            besucht[start] = true

            var vorgaenger = start
            var aktuell = adjacency[start][0]

            while aktuell != start {
                // Unerreichbar bei 2-regulaerer Eingabe: Ein bereits besuchter
                // Knoten ungleich dem Start haette drei Kanten - zwei aus seinem
                // ersten Durchlauf und die, ueber die wir gerade kommen.
                precondition(!besucht[aktuell], "Knoten \(aktuell) waere zweimal Teil eines Kreises")
                besucht[aktuell] = true
                kreis.append(aktuell)

                let nachbarn = adjacency[aktuell]
                let weiter = nachbarn[0] == vorgaenger ? nachbarn[1] : nachbarn[0]
                vorgaenger = aktuell
                aktuell = weiter
            }

            // Ergibt sich aus Punkt 2 der Begruendung oben: keine Schlingen,
            // keine Doppelkanten, also mindestens ein Dreieck.
            precondition(kreis.count >= 3, "Kreis der Laenge \(kreis.count) ist bei einfachen Graphen unmoeglich")
            kreise.append(kreis)
        }
        return kreise
    }

    /// Zerlegt einen 2-regulaeren Graphen in Kreise und orientiert jeden Kreis
    /// konsistent in eine zufaellig gewaehlte Umlaufrichtung.
    ///
    /// Pro Kreis wird genau **ein** Bit aus dem Generator gezogen. Mehr braucht
    /// es nicht: Ein Kreis hat exakt zwei konsistente Orientierungen, und beide
    /// erfuellen die Fachregel gleich gut. Die Anzahl der verbrauchten Bits
    /// haengt damit nur von der Kreiszerlegung ab, nicht von der Kreislaenge.
    ///
    /// - Returns: Je Kreis dessen Kanten in Umlaufreihenfolge, also
    ///   `v0 -> v1`, `v1 -> v2`, ... , `vn-1 -> v0`.
    internal static func orientCycles(
        adjacency: [[Int]],
        rng: inout SplitMix64
    ) -> [DirectedEdge] {
        let kreise = cycles(inAdjacency: adjacency)

        var ergebnis: [DirectedEdge] = []
        for kreis in kreise {
            // Ein Kreis hat genau zwei konsistente Richtungen. Das unterste Bit
            // eines SplitMix64-Wertes entscheidet, welche davon genommen wird.
            let umkehren = rng.next() & 1 == 1
            let umlauf = umkehren ? Array(kreis.reversed()) : kreis

            for position in 0 ..< umlauf.count {
                let heim = umlauf[position]
                let auswaerts = umlauf[(position + 1) % umlauf.count]
                ergebnis.append(DirectedEdge(home: heim, away: auswaerts))
            }
        }
        return ergebnis
    }

    // MARK: - Topfpaar-Indizes

    /// Anzahl der Topfpaare `(i, j)` mit `i <= j`, bei vier Toepfen also zehn.
    private static let potPairCount: Int = {
        let anzahlToepfe = InputValidation.potsInOrder.count
        return anzahlToepfe * (anzahlToepfe + 1) / 2
    }()

    /// Nachschlagetabelle Topfnummer x Topfnummer -> Index des Topfpaars.
    ///
    /// Die Nummerierung ist Row-Major und damit identisch zu der, nach der
    /// Phase A ihre Teilgraphen ordnet: `(0,0)` ist 0, `(0,1)` ist 1, ... ,
    /// `(3,3)` ist 9. Die Tabelle ist symmetrisch, die Reihenfolge der beiden
    /// Topfnummern spielt beim Nachschlagen also keine Rolle.
    private static let potPairIndexTable: [[Int]] = {
        let anzahlToepfe = InputValidation.potsInOrder.count
        var tabelle = [[Int]](
            repeating: [Int](repeating: 0, count: anzahlToepfe),
            count: anzahlToepfe
        )
        var index = 0
        for i in 0 ..< anzahlToepfe {
            for j in i ..< anzahlToepfe {
                tabelle[i][j] = index
                tabelle[j][i] = index
                index += 1
            }
        }
        return tabelle
    }()

    // MARK: - Zusicherungen

    /// Prueft die Vorbedingungen der Kreiszerlegung.
    ///
    /// Alle drei Punkte sind Struktureigenschaften, die aus einer erfolgreichen
    /// Phase A folgen. Sie hier zu pruefen ist billig (Grad zwei heisst: zwei
    /// Vergleiche je Knoten) und faengt einen Fehler an der Stelle ab, an der er
    /// noch erklaerbar ist - statt spaeter als schiefe Heim-/Auswaertsbilanz.
    private static func checkTwoRegular(_ adjacency: [[Int]]) {
        for knoten in 0 ..< adjacency.count {
            let nachbarn = adjacency[knoten]
            if nachbarn.isEmpty { continue }

            precondition(
                nachbarn.count == 2,
                "Knoten \(knoten) hat Grad \(nachbarn.count) statt 2"
            )
            // Deckt zwei Faelle in einem Vergleich ab: aufsteigend sortiert und
            // keine Doppelkante (die waere `nachbarn[0] == nachbarn[1]`).
            precondition(
                nachbarn[0] < nachbarn[1],
                "Knoten \(knoten) hat unsortierte Nachbarn oder eine Doppelkante"
            )
            precondition(
                nachbarn[0] != knoten && nachbarn[1] != knoten,
                "Knoten \(knoten) hat eine Schlinge"
            )
            for nachbar in nachbarn {
                precondition(
                    adjacency[nachbar].contains(knoten),
                    "Adjazenz ist nicht symmetrisch: \(knoten) kennt \(nachbar), aber nicht umgekehrt"
                )
            }
        }
    }

    /// Prueft die Fachregel am fertigen Ergebnis: je Team und Topf genau ein
    /// Heim- und ein Auswaertsspiel.
    ///
    /// Das ist die Zusicherung, um die es in Phase B ueberhaupt geht. Sie kostet
    /// einen Durchlauf ueber 144 Kanten und bleibt deshalb bewusst auch im
    /// Release-Build stehen.
    private static func checkHomeAwayBalance(_ edges: [DirectedEdge], context: DrawContext) {
        let anzahlToepfe = InputValidation.potsInOrder.count
        var heimspiele = [[Int]](
            repeating: [Int](repeating: 0, count: anzahlToepfe),
            count: context.teamCount
        )
        var auswaertsspiele = heimspiele

        for kante in edges {
            heimspiele[kante.home][context.potIndex[kante.away]] += 1
            auswaertsspiele[kante.away][context.potIndex[kante.home]] += 1
        }

        for team in 0 ..< context.teamCount {
            for topf in 0 ..< anzahlToepfe {
                precondition(
                    heimspiele[team][topf] == 1,
                    "Team \(team) hat \(heimspiele[team][topf]) Heimspiele gegen Topf \(topf + 1) statt 1"
                )
                precondition(
                    auswaertsspiele[team][topf] == 1,
                    "Team \(team) hat \(auswaertsspiele[team][topf]) Auswaertsspiele gegen Topf \(topf + 1) statt 1"
                )
            }
        }
    }
}
