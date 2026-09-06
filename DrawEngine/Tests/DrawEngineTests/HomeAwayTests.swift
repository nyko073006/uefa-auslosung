import Testing
@testable import DrawEngine

// MARK: - Lokale Testdaten
//
// Bewusst `private` und mit eindeutigem Praefix `homeAway...`: Die gemeinsame
// `Fixtures.swift` gehoert einem anderen Arbeitsstrang, und die Testdaten der
// anderen Suites sind dort ebenfalls `private`. So sind Namenskollisionen
// ausgeschlossen, ohne dass Dateien fremder Arbeitsstraenge angefasst werden.

/// Verbandscodes je Topf. `[0]` ist Topf 1, `[3]` ist Topf 4.
///
/// Ein realistisches Teilnehmerfeld: ENG/ESP/ITA mit je vier Teams (je zwei in
/// Topf 1 und 2), GER/FRA mit je drei, NED/POR/BEL mit je zwei und zwoelf
/// Verbaende mit genau einem Team. Zusammen `3*4 + 2*3 + 3*2 + 12 = 36` Teams.
private let homeAwayAssociationsPerPot: [[String]] = [
    ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "POR"],
    ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "NED"],
    ["GER", "FRA", "NED", "POR", "BEL", "SCO", "AUT", "TUR", "CZE"],
    ["BEL", "SUI", "CRO", "UKR", "SRB", "DEN", "NOR", "GRE", "POL"],
]

/// Baut die 36 Teams des Testfelds. TeamIDs laufen von "T01" bis "T36"; die
/// fuehrende Null haelt die String-Sortierung mit der Zahlenordnung im Einklang.
private func homeAwayTeams() -> [Team] {
    var teams: [Team] = []
    teams.reserveCapacity(36)
    var nummer = 1
    for (topfIndex, verbaende) in homeAwayAssociationsPerPot.enumerated() {
        guard let topf = Pot(rawValue: topfIndex + 1) else { continue }
        for verband in verbaende {
            let id = nummer < 10 ? "T0\(nummer)" : "T\(nummer)"
            teams.append(
                Team(id: TeamID(id), name: "Team \(id)", association: Association(verband), pot: topf)
            )
            nummer += 1
        }
    }
    return teams
}

/// Der Kontext des Testfelds.
private func homeAwayContext() -> DrawContext {
    DrawContext(teams: homeAwayTeams())
}

/// Die Seeds, ueber die die Invarianten geprueft werden.
///
/// Dreissig Laeufe decken deutlich verschiedene Kantensaetze und damit auch
/// deutlich verschiedene Kreiszerlegungen ab.
private let homeAwaySeeds: [UInt64] = (1 ... 30).map { UInt64($0) }

/// Grosszuegiges Knotenbudget fuer Phase A. Ein realistischer Lauf bleibt weit
/// darunter; die Grenze verhindert nur ein Haengen im Fehlerfall.
private let homeAwayNodeBudget: Int = 200_000

/// Liefert die ungerichteten Kanten aus Phase A fuer den angegebenen Seed.
private func homeAwayEdges(seed: UInt64) throws -> [OpponentMatcher.Edge] {
    var rng = SplitMix64(seed: seed)
    return try OpponentMatcher.match(
        context: homeAwayContext(),
        rng: &rng,
        maxSearchNodes: homeAwayNodeBudget
    ).edges
}

/// Fuehrt die komplette Kette Phase A -> Phase B fuer einen Seed aus.
///
/// Der Generator wird bewusst weiterverwendet statt neu aufgesetzt: Genau so
/// laeuft es spaeter in der Engine, und nur so wird auch geprueft, dass Phase B
/// mit einem beliebigen Generatorzustand zurechtkommt.
private func homeAwayRun(seed: UInt64) throws -> (
    edges: [OpponentMatcher.Edge],
    directed: [HomeAwayOrienter.DirectedEdge]
) {
    var rng = SplitMix64(seed: seed)
    let kanten = try OpponentMatcher.match(
        context: homeAwayContext(),
        rng: &rng,
        maxSearchNodes: homeAwayNodeBudget
    ).edges
    let gerichtet = HomeAwayOrienter.orient(edges: kanten, context: homeAwayContext(), rng: &rng)
    return (kanten, gerichtet)
}

/// Die zehn Topfpaare in Row-Major-Reihenfolge, so wie
/// `HomeAwayOrienter.adjacencyPerPotPair` seine Gruppen ordnet.
private let homeAwayPotPairs: [(i: Int, j: Int)] = {
    var liste: [(i: Int, j: Int)] = []
    for i in 0 ..< 4 {
        for j in i ..< 4 {
            liste.append((i, j))
        }
    }
    return liste
}()

/// Ein handgebauter 2-regulaerer Graph auf neun Knoten: ein Dreieck `0-1-2` und
/// ein Sechseck `3-4-5-6-7-8`.
///
/// Der ungerade Kreis ist der eigentliche Punkt: Eine 2-Kanten-Faerbung
/// ("abwechselnd heim und auswaerts") wuerde an ihm scheitern, die
/// Kreisorientierung nicht.
private let homeAwayOddCycleAdjacency: [[Int]] = [
    [1, 2],
    [0, 2],
    [0, 1],
    [4, 8],
    [3, 5],
    [4, 6],
    [5, 7],
    [6, 8],
    [3, 7],
]

// MARK: - Tests

@Suite("HomeAwayOrienter")
struct HomeAwayTests {

    // MARK: Testfeld

    @Test("Das Testfeld besteht die Vorpruefung")
    func testfeldIstGueltig() throws {
        try InputValidation.validate(teams: homeAwayTeams())
    }

    // MARK: Fachregel Heim/Auswaerts

    @Test("Je Topf genau ein Heim- und ein Auswaertsspiel", arguments: homeAwaySeeds)
    func einHeimUndEinAuswaertsspielJeTopf(seed: UInt64) throws {
        let lauf = try homeAwayRun(seed: seed)
        let kontext = homeAwayContext()

        var heimspiele = [[Int]](repeating: [Int](repeating: 0, count: 4), count: kontext.teamCount)
        var auswaertsspiele = heimspiele

        for kante in lauf.directed {
            heimspiele[kante.home][kontext.potIndex[kante.away]] += 1
            auswaertsspiele[kante.away][kontext.potIndex[kante.home]] += 1
        }

        for team in 0 ..< kontext.teamCount {
            let name = kontext.teamID(team).rawValue
            for topf in 0 ..< 4 {
                #expect(
                    heimspiele[team][topf] == 1,
                    "Team \(name) hat \(heimspiele[team][topf]) Heimspiele gegen Topf \(topf + 1)"
                )
                #expect(
                    auswaertsspiele[team][topf] == 1,
                    "Team \(name) hat \(auswaertsspiele[team][topf]) Auswaertsspiele gegen Topf \(topf + 1)"
                )
            }
        }
    }

    @Test("Insgesamt vier Heim- und vier Auswaertsspiele je Team", arguments: homeAwaySeeds)
    func vierHeimUndVierAuswaertsspiele(seed: UInt64) throws {
        let lauf = try homeAwayRun(seed: seed)
        let kontext = homeAwayContext()

        var heimspiele = [Int](repeating: 0, count: kontext.teamCount)
        var auswaertsspiele = [Int](repeating: 0, count: kontext.teamCount)

        for kante in lauf.directed {
            heimspiele[kante.home] += 1
            auswaertsspiele[kante.away] += 1
        }

        for team in 0 ..< kontext.teamCount {
            let name = kontext.teamID(team).rawValue
            #expect(heimspiele[team] == 4, "Team \(name) hat \(heimspiele[team]) Heimspiele")
            #expect(auswaertsspiele[team] == 4, "Team \(name) hat \(auswaertsspiele[team]) Auswaertsspiele")
        }
    }

    // MARK: Kantenerhalt

    @Test("Die Kantenmenge bleibt exakt erhalten", arguments: homeAwaySeeds)
    func kantenmengeBleibtErhalten(seed: UInt64) throws {
        let lauf = try homeAwayRun(seed: seed)

        #expect(lauf.directed.count == 144)
        // Sortierter Vergleich statt Mengenvergleich: Er faengt zusaetzlich ab,
        // dass eine Kante doppelt orientiert wurde und dafuer eine andere fehlt.
        #expect(lauf.directed.map(\.undirected).sorted() == lauf.edges.sorted())
    }

    @Test("Keine Begegnung wird in beide Richtungen erzeugt", arguments: homeAwaySeeds)
    func keineGegenrichtung(seed: UInt64) throws {
        let lauf = try homeAwayRun(seed: seed)
        // Set nur zum Nachschlagen und Zaehlen, nie zum Iterieren: Die
        // Reihenfolge einer Menge haengt vom Hash-Seed des Prozesslaufs ab.
        let gerichtet = Set(lauf.directed)
        #expect(gerichtet.count == 144)
        for kante in lauf.directed {
            #expect(
                !gerichtet.contains(HomeAwayOrienter.DirectedEdge(home: kante.away, away: kante.home)),
                "Begegnung \(kante.home) gegen \(kante.away) existiert in beiden Richtungen"
            )
        }
    }

    // MARK: Determinismus

    @Test("Gleicher Seed liefert dieselbe Orientierung", arguments: homeAwaySeeds)
    func gleicherSeedGleicheOrientierung(seed: UInt64) throws {
        let ersterLauf = try homeAwayRun(seed: seed)
        let zweiterLauf = try homeAwayRun(seed: seed)
        // Auch die Ausgabereihenfolge selbst muss reproduzierbar sein, nicht nur
        // die Menge der gerichteten Kanten.
        #expect(ersterLauf.directed == zweiterLauf.directed)
    }

    @Test("Verschiedene Seeds orientieren denselben Kantensatz verschieden")
    func verschiedeneSeedsVerschiedeneOrientierung() throws {
        // Derselbe Kantensatz, nur unterschiedliche Zufallsbits: So wird genau
        // die Orientierung geprueft und nicht bloss ein anderes Phase-A-Ergebnis.
        let kanten = try homeAwayEdges(seed: 1)
        let kontext = homeAwayContext()

        var referenzRng = SplitMix64(seed: 1)
        let referenz = HomeAwayOrienter.orient(edges: kanten, context: kontext, rng: &referenzRng)

        var unterschiedGefunden = false
        for seed in homeAwaySeeds.dropFirst() {
            var rng = SplitMix64(seed: seed)
            let orientiert = HomeAwayOrienter.orient(edges: kanten, context: kontext, rng: &rng)
            // Die ungerichteten Kanten sind identisch, also unterscheiden sich
            // die Ergebnisse genau dann, wenn mindestens ein Kreis anders
            // herum orientiert wurde.
            if orientiert != referenz {
                unterschiedGefunden = true
                break
            }
        }
        #expect(unterschiedGefunden, "Alle Seeds orientierten den Kantensatz identisch")
    }

    // MARK: Kreiszerlegung

    @Test("Die Kreise partitionieren die beteiligten Knoten", arguments: homeAwaySeeds)
    func kreisePartitionierenDieKnoten(seed: UInt64) throws {
        let lauf = try homeAwayRun(seed: seed)
        let kontext = homeAwayContext()
        let gruppen = HomeAwayOrienter.adjacencyPerPotPair(edges: lauf.edges, context: kontext)

        #expect(gruppen.count == 10)

        for (gruppenIndex, adjazenz) in gruppen.enumerated() {
            let paar = homeAwayPotPairs[gruppenIndex]
            // Same-Pot: neun Knoten mit Grad zwei ergeben neun Kanten.
            // Cross-Pot: 18 Knoten mit Grad zwei ergeben 18 Kanten.
            let erwarteteKnoten = paar.i == paar.j ? 9 : 18
            let erwarteteKanten = erwarteteKnoten

            var gradSumme = 0
            var beteiligte = 0
            for knoten in 0 ..< kontext.teamCount where !adjazenz[knoten].isEmpty {
                beteiligte += 1
                gradSumme += adjazenz[knoten].count
            }
            #expect(beteiligte == erwarteteKnoten, "Topfpaar \(paar) hat \(beteiligte) beteiligte Knoten")
            #expect(gradSumme / 2 == erwarteteKanten, "Topfpaar \(paar) hat \(gradSumme / 2) Kanten")

            let kreise = HomeAwayOrienter.cycles(inAdjacency: adjazenz)

            // Jeder beteiligte Knoten genau einmal, kein unbeteiligter dabei.
            var vorkommen = [Int](repeating: 0, count: kontext.teamCount)
            var laengenSumme = 0
            for kreis in kreise {
                #expect(kreis.count >= 3, "Kreis der Laenge \(kreis.count) im Topfpaar \(paar)")
                laengenSumme += kreis.count
                for knoten in kreis {
                    vorkommen[knoten] += 1
                }
            }
            #expect(laengenSumme == erwarteteKanten, "Kreislaengen summieren sich zu \(laengenSumme)")

            for knoten in 0 ..< kontext.teamCount {
                let erwartet = adjazenz[knoten].isEmpty ? 0 : 1
                #expect(
                    vorkommen[knoten] == erwartet,
                    "Knoten \(knoten) kommt \(vorkommen[knoten]) mal in den Kreisen von \(paar) vor"
                )
            }
        }
    }

    @Test("Cross-Pot-Kreise sind gerade, Same-Pot-Kreise nicht zwingend", arguments: homeAwaySeeds)
    func crossPotKreiseSindGerade(seed: UInt64) throws {
        let lauf = try homeAwayRun(seed: seed)
        let kontext = homeAwayContext()
        let gruppen = HomeAwayOrienter.adjacencyPerPotPair(edges: lauf.edges, context: kontext)

        for (gruppenIndex, adjazenz) in gruppen.enumerated() {
            let paar = homeAwayPotPairs[gruppenIndex]
            guard paar.i != paar.j else { continue }
            // Ein Cross-Pot-Teilgraph ist bipartit, jeder Kreis wechselt also in
            // jedem Schritt die Seite und hat damit gerade Laenge.
            for kreis in HomeAwayOrienter.cycles(inAdjacency: adjazenz) {
                #expect(kreis.count % 2 == 0, "Ungerader Kreis der Laenge \(kreis.count) im Topfpaar \(paar)")
            }
        }
    }

    @Test("Same-Pot-Teilgraphen enthalten mindestens einen ungeraden Kreis", arguments: homeAwaySeeds)
    func samePotHatUngeradenKreis(seed: UInt64) throws {
        let lauf = try homeAwayRun(seed: seed)
        let kontext = homeAwayContext()
        let gruppen = HomeAwayOrienter.adjacencyPerPotPair(edges: lauf.edges, context: kontext)

        for (gruppenIndex, adjazenz) in gruppen.enumerated() {
            let paar = homeAwayPotPairs[gruppenIndex]
            guard paar.i == paar.j else { continue }
            // Neun Knoten lassen sich nicht in lauter gerade Kreislaengen
            // zerlegen. Ungerade Kreise sind hier also kein Sonderfall, sondern
            // die Regel - und genau deshalb scheidet eine 2-Kanten-Faerbung aus.
            let kreise = HomeAwayOrienter.cycles(inAdjacency: adjazenz)
            let hatUngeraden = kreise.contains { $0.count % 2 == 1 }
            #expect(hatUngeraden, "Topf \(paar.i + 1) ohne ungeraden Kreis")
        }
    }

    // MARK: Ungerader Kreis, handgebaut

    @Test("Die Zerlegung findet Dreieck und Sechseck exakt")
    func handgebauteZerlegung() {
        let kreise = HomeAwayOrienter.cycles(inAdjacency: homeAwayOddCycleAdjacency)
        // Start beim kleinsten unbesuchten Knoten, erster Schritt zum kleineren
        // Nachbarn: Damit ist die Zerlegung eindeutig vorhersagbar.
        #expect(kreise == [[0, 1, 2], [3, 4, 5, 6, 7, 8]])
    }

    @Test("Ein ungerader Kreis wird sauber orientiert", arguments: homeAwaySeeds)
    func ungeraderKreisWirdOrientiert(seed: UInt64) {
        var rng = SplitMix64(seed: seed)
        let gerichtet = HomeAwayOrienter.orientCycles(adjacency: homeAwayOddCycleAdjacency, rng: &rng)

        #expect(gerichtet.count == 9)

        var ausgang = [Int](repeating: 0, count: 9)
        var eingang = [Int](repeating: 0, count: 9)
        for kante in gerichtet {
            ausgang[kante.home] += 1
            eingang[kante.away] += 1
        }

        for knoten in 0 ..< 9 {
            #expect(ausgang[knoten] == 1, "Knoten \(knoten) hat Out-Grad \(ausgang[knoten])")
            #expect(eingang[knoten] == 1, "Knoten \(knoten) hat In-Grad \(eingang[knoten])")
        }

        // Die Orientierung darf keine Kante erfinden und keine verlieren.
        #expect(
            gerichtet.map(\.undirected).sorted() == [
                OpponentMatcher.Edge(0, 1),
                OpponentMatcher.Edge(0, 2),
                OpponentMatcher.Edge(1, 2),
                OpponentMatcher.Edge(3, 4),
                OpponentMatcher.Edge(3, 8),
                OpponentMatcher.Edge(4, 5),
                OpponentMatcher.Edge(5, 6),
                OpponentMatcher.Edge(6, 7),
                OpponentMatcher.Edge(7, 8),
            ].sorted()
        )
    }

    @Test("Beide Umlaufrichtungen kommen vor")
    func beideRichtungenKommenVor() {
        // Pro Kreis wird genau ein Bit gezogen. Ueber genuegend Seeds muessen
        // deshalb beide Orientierungen des Dreiecks auftauchen.
        let dreieck: [[Int]] = [[1, 2], [0, 2], [0, 1]]
        var vorwaerts = false
        var rueckwaerts = false

        for seed in homeAwaySeeds {
            var rng = SplitMix64(seed: seed)
            let gerichtet = HomeAwayOrienter.orientCycles(adjacency: dreieck, rng: &rng)
            if gerichtet.contains(HomeAwayOrienter.DirectedEdge(home: 0, away: 1)) {
                vorwaerts = true
            }
            if gerichtet.contains(HomeAwayOrienter.DirectedEdge(home: 1, away: 0)) {
                rueckwaerts = true
            }
        }

        #expect(vorwaerts, "Die Vorwaertsrichtung kam bei keinem Seed vor")
        #expect(rueckwaerts, "Die Rueckwaertsrichtung kam bei keinem Seed vor")
    }
}
