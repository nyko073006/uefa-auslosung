import Testing
@testable import DrawEngine

// MARK: - Lokale Testdaten
//
// Bewusst `private` und mit eindeutigem Praefix `eventSeq...`: Die gemeinsame
// `Fixtures.swift` gehoert einem anderen Arbeitsstrang, und die Testdaten der
// anderen Suites sind dort ebenfalls `private`. So sind Namenskollisionen
// ausgeschlossen, ohne dass Dateien fremder Arbeitsstraenge angefasst werden.

/// Verbandscodes je Topf. `[0]` ist Topf 1, `[3]` ist Topf 4.
///
/// Ein realistisches Teilnehmerfeld: ENG/ESP/ITA mit je vier Teams (je zwei in
/// Topf 1 und 2), GER/FRA mit je drei, NED/POR/BEL mit je zwei und zwoelf
/// Verbaende mit genau einem Team. Zusammen `3*4 + 2*3 + 3*2 + 12 = 36` Teams.
private let eventSeqAssociationsPerPot: [[String]] = [
    ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "POR"],
    ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "NED"],
    ["GER", "FRA", "NED", "POR", "BEL", "SCO", "AUT", "TUR", "CZE"],
    ["BEL", "SUI", "CRO", "UKR", "SRB", "DEN", "NOR", "GRE", "POL"],
]

/// Baut die 36 Teams des Testfelds. TeamIDs laufen von "T01" bis "T36"; die
/// fuehrende Null haelt die String-Sortierung mit der Zahlenordnung im Einklang.
private func eventSeqTeams() -> [Team] {
    var teams: [Team] = []
    teams.reserveCapacity(36)
    var nummer = 1
    for (topfIndex, verbaende) in eventSeqAssociationsPerPot.enumerated() {
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
private func eventSeqContext() -> DrawContext {
    DrawContext(teams: eventSeqTeams())
}

/// Die Seeds, ueber die die Invarianten geprueft werden.
private let eventSeqSeeds: [UInt64] = (1 ... 30).map { UInt64($0) }

/// Grosszuegiges Knotenbudget fuer Phase A. Ein realistischer Lauf bleibt weit
/// darunter; die Grenze verhindert nur ein Haengen im Fehlerfall.
private let eventSeqNodeBudget: Int = 200_000

/// Ergebnis eines kompletten Laufs Phase A -> Phase B -> Phase C.
private struct EventSeqRun {

    /// Der Kontext, mit dem der Lauf erzeugt wurde.
    let context: DrawContext

    /// Die gerichteten Begegnungen aus Phase B.
    let directed: [HomeAwayOrienter.DirectedEdge]

    /// Die Ereignisliste aus Phase C.
    let events: [DrawEvent]
}

/// Fuehrt die komplette Kette Phase A -> Phase B -> Phase C fuer einen Seed aus.
///
/// Der Generator wird ueber alle drei Phasen hinweg weiterverwendet statt neu
/// aufgesetzt: Genau so laeuft es spaeter in der Engine, und nur so wird auch
/// geprueft, dass Phase C mit einem beliebigen Generatorzustand zurechtkommt.
private func eventSeqRun(seed: UInt64) throws -> EventSeqRun {
    let kontext = eventSeqContext()
    var rng = SplitMix64(seed: seed)

    let kanten = try OpponentMatcher.match(
        context: kontext,
        rng: &rng,
        maxSearchNodes: eventSeqNodeBudget
    ).edges
    let gerichtet = HomeAwayOrienter.orient(edges: kanten, context: kontext, rng: &rng)
    let ereignisse = EventSequencer.events(
        directedEdges: gerichtet,
        context: kontext,
        seed: seed,
        rng: &rng
    )
    return EventSeqRun(context: kontext, directed: gerichtet, events: ereignisse)
}

// MARK: - Zerlegung der Ereignisliste

/// Eine einzelne Enthuellung innerhalb eines Team-Blocks, auf Indizes uebersetzt.
private struct EventSeqReveal {
    let opponent: Int
    let opponentPot: Pot
    let drawnTeamPlaysHome: Bool
}

/// Ein Block der Ereignisliste: ein `.teamDrawn` und die darauf folgenden Reveals.
private struct EventSeqBlock {
    let team: Int
    let pot: Pot
    let reveals: [EventSeqReveal]
}

/// Zerlegt eine Ereignisliste in die Bloecke der gezogenen Teams.
///
/// Nebenbei wird geprueft, dass jedes `.matchRevealed` zum umschliessenden
/// `.teamDrawn` gehoert - sonst waere die Zuordnung Block zu Reveal nicht
/// eindeutig und alle darauf aufbauenden Pruefungen waertlos.
private func eventSeqBlocks(_ events: [DrawEvent], context: DrawContext) throws -> [EventSeqBlock] {
    var bloecke: [EventSeqBlock] = []
    var offenesTeam: Int?
    var offenerTopf: Pot = .pot1
    var reveals: [EventSeqReveal] = []

    for ereignis in events {
        switch ereignis {
        case let .teamDrawn(gezogen, topf):
            if let team = offenesTeam {
                bloecke.append(EventSeqBlock(team: team, pot: offenerTopf, reveals: reveals))
            }
            offenesTeam = try #require(context.index(of: gezogen), "Unbekannte TeamID \(gezogen.rawValue)")
            offenerTopf = topf
            reveals = []

        case let .matchRevealed(gezogen, gegner, gegnerTopf, heim):
            let team = try #require(offenesTeam, "Reveal ausserhalb eines Team-Blocks")
            let gezogenerIndex = try #require(context.index(of: gezogen), "Unbekannte TeamID \(gezogen.rawValue)")
            #expect(gezogenerIndex == team, "Reveal gehoert nicht zum umschliessenden gezogenen Team")
            let gegnerIndex = try #require(context.index(of: gegner), "Unbekannte TeamID \(gegner.rawValue)")
            reveals.append(
                EventSeqReveal(opponent: gegnerIndex, opponentPot: gegnerTopf, drawnTeamPlaysHome: heim)
            )

        case .potCompleted:
            if let team = offenesTeam {
                bloecke.append(EventSeqBlock(team: team, pot: offenerTopf, reveals: reveals))
                offenesTeam = nil
                reveals = []
            }

        default:
            break
        }
    }

    #expect(offenesTeam == nil, "Am Ende der Liste war noch ein Team-Block offen")
    return bloecke
}

/// Die Ziehreihenfolge als reine Liste der gezogenen TeamIDs.
private func eventSeqDrawOrder(_ events: [DrawEvent]) -> [TeamID] {
    var reihenfolge: [TeamID] = []
    for ereignis in events {
        if case let .teamDrawn(team, _) = ereignis {
            reihenfolge.append(team)
        }
    }
    return reihenfolge
}

// MARK: - Tests

@Suite("EventSequencer")
struct EventSequenceTests {

    // MARK: Testfeld

    @Test("Das Testfeld besteht die Vorpruefung")
    func testfeldIstGueltig() throws {
        try InputValidation.validate(teams: eventSeqTeams())
    }

    // MARK: Rekonstruktion

    @Test("Die Reveals rekonstruieren exakt die gerichteten Kanten", arguments: eventSeqSeeds)
    func revealsRekonstruierenDieKanten(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)

        var rekonstruiert: [HomeAwayOrienter.DirectedEdge] = []
        for ereignis in lauf.events {
            guard case let .matchRevealed(gezogen, gegner, _, heim) = ereignis else { continue }
            let team = try #require(lauf.context.index(of: gezogen))
            let gegnerIndex = try #require(lauf.context.index(of: gegner))
            rekonstruiert.append(
                heim
                    ? HomeAwayOrienter.DirectedEdge(home: team, away: gegnerIndex)
                    : HomeAwayOrienter.DirectedEdge(home: gegnerIndex, away: team)
            )
        }

        #expect(rekonstruiert.count == 144)
        // Sortierter Vergleich statt Mengenvergleich: Er faengt zusaetzlich ab,
        // dass eine Begegnung doppelt enthuellt wurde und dafuer eine andere fehlt.
        #expect(rekonstruiert.sorted() == lauf.directed.sorted())
    }

    @Test("Der gemeldete Gegner-Topf stimmt mit dem Kontext ueberein", arguments: eventSeqSeeds)
    func gegnerTopfStimmt(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)

        for ereignis in lauf.events {
            guard case let .matchRevealed(_, gegner, gegnerTopf, _) = ereignis else { continue }
            let gegnerIndex = try #require(lauf.context.index(of: gegner))
            #expect(
                lauf.context.potOfTeam(gegnerIndex) == gegnerTopf,
                "Gegner \(gegner.rawValue) wird mit Topf \(gegnerTopf.rawValue) gemeldet"
            )
        }
    }

    // MARK: Struktur der Ereignisliste

    @Test("Die Liste beginnt mit drawStarted und endet mit drawCompleted", arguments: eventSeqSeeds)
    func klammerungDerGesamtliste(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)

        #expect(lauf.events.first == .drawStarted(seed: seed))
        #expect(lauf.events.last == .drawCompleted)

        // Beide Klammern duerfen nur je einmal vorkommen, sonst waere die Liste
        // als Animationsskript nicht eindeutig zu lesen.
        var starts = 0
        var enden = 0
        for ereignis in lauf.events {
            if case .drawStarted = ereignis { starts += 1 }
            if case .drawCompleted = ereignis { enden += 1 }
        }
        #expect(starts == 1)
        #expect(enden == 1)
    }

    @Test("Die Topf-Klammern schliessen korrekt und jeder Topf kommt einmal vor", arguments: eventSeqSeeds)
    func topfKlammerung(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)

        var offenerTopf: Pot?
        var gestartet: [Pot] = []
        var beendet: [Pot] = []

        for ereignis in lauf.events {
            switch ereignis {
            case let .potStarted(topf):
                #expect(offenerTopf == nil, "Topf \(topf.rawValue) startet, waehrend ein anderer offen ist")
                offenerTopf = topf
                gestartet.append(topf)

            case let .potCompleted(topf):
                #expect(offenerTopf == topf, "Topf \(topf.rawValue) wird geschlossen, ohne offen zu sein")
                offenerTopf = nil
                beendet.append(topf)

            case let .teamDrawn(_, topf):
                #expect(offenerTopf == topf, "Team wird ausserhalb seines offenen Topfes gezogen")

            case .matchRevealed:
                #expect(offenerTopf != nil, "Reveal ausserhalb eines offenen Topfes")

            default:
                break
            }
        }

        #expect(offenerTopf == nil, "Am Ende der Liste war noch ein Topf offen")
        #expect(gestartet == InputValidation.potsInOrder)
        #expect(beendet == InputValidation.potsInOrder)
    }

    @Test("Genau 36 gezogene Teams, jedes genau einmal, in Topf-Reihenfolge", arguments: eventSeqSeeds)
    func jedesTeamGenauEinmalInTopfReihenfolge(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)
        let bloecke = try eventSeqBlocks(lauf.events, context: lauf.context)

        #expect(bloecke.count == lauf.context.teamCount)

        var vorkommen = [Int](repeating: 0, count: lauf.context.teamCount)
        for block in bloecke {
            vorkommen[block.team] += 1
            // Der gemeldete Topf muss der echte Topf des Teams sein - sonst
            // waere die Blockreihenfolge zwar sortiert, aber falsch etikettiert.
            #expect(
                lauf.context.potOfTeam(block.team) == block.pot,
                "Team \(lauf.context.teamID(block.team).rawValue) wird im falschen Topf gezogen"
            )
        }
        for team in 0 ..< lauf.context.teamCount {
            #expect(
                vorkommen[team] == 1,
                "Team \(lauf.context.teamID(team).rawValue) wurde \(vorkommen[team]) mal gezogen"
            )
        }

        // Die Bloecke liegen in Topf-Reihenfolge pot1 ... pot4, je neun Stueck.
        for (position, block) in bloecke.enumerated() {
            let erwartet = InputValidation.potsInOrder[position / InputValidation.expectedPotSize]
            #expect(block.pot == erwartet, "Block \(position) gehoert zu Topf \(block.pot.rawValue)")
        }
    }

    @Test("Die Liste hat die vorhergesagte Laenge", arguments: eventSeqSeeds)
    func vorhergesagteLaenge(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)
        let erwartet = EventSequencer.expectedEventCount(
            context: lauf.context,
            matchCount: lauf.directed.count
        )
        // 1 + 2*4 + 36 + 144 + 1
        #expect(erwartet == 190)
        #expect(lauf.events.count == erwartet)
    }

    // MARK: Vollstaendigkeit

    @Test("Nach seinem Block sind alle acht Paarungen eines Teams enthuellt", arguments: eventSeqSeeds)
    func achtPaarungenNachJedemBlock(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)
        let bloecke = try eventSeqBlocks(lauf.events, context: lauf.context)

        let anzahlTeams = lauf.context.teamCount
        var enthuellt = [[Bool]](
            repeating: [Bool](repeating: false, count: anzahlTeams),
            count: anzahlTeams
        )

        for block in bloecke {
            for reveal in block.reveals {
                #expect(
                    !enthuellt[block.team][reveal.opponent],
                    "Paarung \(block.team) gegen \(reveal.opponent) wurde doppelt enthuellt"
                )
                enthuellt[block.team][reveal.opponent] = true
                enthuellt[reveal.opponent][block.team] = true
            }

            var anzahl = 0
            for gegner in 0 ..< anzahlTeams where enthuellt[block.team][gegner] { anzahl += 1 }
            #expect(
                anzahl == 8,
                "Team \(lauf.context.teamID(block.team).rawValue) hat nach seinem Block \(anzahl) Paarungen"
            )
        }

        // Summe ueber alle Bloecke: jede der 144 Begegnungen genau einmal, nicht
        // 36 * 8 = 288. Das ist der Kern der Ueberspring-Regel.
        var summe = 0
        for block in bloecke { summe += block.reveals.count }
        #expect(summe == 144)
    }

    @Test("Das erste gezogene Team enthuellt acht, das letzte keine Paarung", arguments: eventSeqSeeds)
    func ersterUndLetzterBlock(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)
        let bloecke = try eventSeqBlocks(lauf.events, context: lauf.context)

        let erster = try #require(bloecke.first)
        let letzter = try #require(bloecke.last)
        // Beim allerersten Team ist noch nichts bekannt, beim allerletzten alles.
        #expect(erster.reveals.count == 8)
        #expect(letzter.reveals.count == 0)
    }

    // MARK: Reveal-Unterordnung

    @Test("Innerhalb eines Blocks: Gegner-Topf aufsteigend, Heim vor Auswaerts", arguments: eventSeqSeeds)
    func revealUnterordnung(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)
        let bloecke = try eventSeqBlocks(lauf.events, context: lauf.context)

        for block in bloecke {
            let name = lauf.context.teamID(block.team).rawValue
            for position in 1 ..< max(block.reveals.count, 1) {
                let vorher = block.reveals[position - 1]
                let jetzt = block.reveals[position]

                #expect(
                    vorher.opponentPot <= jetzt.opponentPot,
                    "Block \(name): Topf \(vorher.opponentPot.rawValue) vor \(jetzt.opponentPot.rawValue)"
                )
                if vorher.opponentPot == jetzt.opponentPot {
                    // Verboten ist genau der Uebergang auswaerts -> heim.
                    #expect(
                        !(vorher.drawnTeamPlaysHome == false && jetzt.drawnTeamPlaysHome == true),
                        "Block \(name): Auswaertsspiel vor Heimspiel gegen Topf \(jetzt.opponentPot.rawValue)"
                    )
                }
            }
        }
    }

    @Test("Ein voller Block zeigt genau die feste Unterordnung", arguments: eventSeqSeeds)
    func vollerBlockZeigtDieFesteOrdnung(seed: UInt64) throws {
        let lauf = try eventSeqRun(seed: seed)
        let bloecke = try eventSeqBlocks(lauf.events, context: lauf.context)

        // Der erste Block ist der einzige, in dem garantiert alle acht Paarungen
        // vorkommen. Dort muss die Unterordnung vollstaendig sichtbar sein:
        // Topf 1 heim, Topf 1 auswaerts, Topf 2 heim, ... , Topf 4 auswaerts.
        let erster = try #require(bloecke.first)
        #expect(erster.reveals.count == 8)

        for (position, reveal) in erster.reveals.enumerated() {
            let erwarteterTopf = InputValidation.potsInOrder[position / 2]
            #expect(reveal.opponentPot == erwarteterTopf, "Reveal \(position) meldet Topf \(reveal.opponentPot.rawValue)")
            #expect(
                reveal.drawnTeamPlaysHome == (position % 2 == 0),
                "Reveal \(position) hat drawnTeamPlaysHome == \(reveal.drawnTeamPlaysHome)"
            )
        }
    }

    // MARK: Determinismus

    @Test("Gleicher Seed liefert dieselbe Ereignisliste", arguments: eventSeqSeeds)
    func gleicherSeedGleicheListe(seed: UInt64) throws {
        let ersterLauf = try eventSeqRun(seed: seed)
        let zweiterLauf = try eventSeqRun(seed: seed)
        // Auch die Reihenfolge selbst, nicht nur die Menge der Ereignisse.
        #expect(ersterLauf.events == zweiterLauf.events)
    }

    @Test("Verschiedene Seeds liefern eine andere Ziehreihenfolge")
    func verschiedeneSeedsVerschiedeneZiehreihenfolge() throws {
        // Dasselbe fertige Ergebnis, nur ein anderer Generatorzustand fuer die
        // Ziehreihenfolge: So wird genau Phase C geprueft und nicht bloss ein
        // anderes Ergebnis aus Phase A oder B.
        let kontext = eventSeqContext()
        var aufbauRng = SplitMix64(seed: 1)
        let kanten = try OpponentMatcher.match(
            context: kontext,
            rng: &aufbauRng,
            maxSearchNodes: eventSeqNodeBudget
        ).edges
        let gerichtet = HomeAwayOrienter.orient(edges: kanten, context: kontext, rng: &aufbauRng)

        var referenzRng = SplitMix64(seed: 1)
        let referenz = eventSeqDrawOrder(
            EventSequencer.events(directedEdges: gerichtet, context: kontext, seed: 1, rng: &referenzRng)
        )
        #expect(referenz.count == 36)

        var unterschiedGefunden = false
        for seed in eventSeqSeeds.dropFirst() {
            var rng = SplitMix64(seed: seed)
            let reihenfolge = eventSeqDrawOrder(
                EventSequencer.events(directedEdges: gerichtet, context: kontext, seed: seed, rng: &rng)
            )
            if reihenfolge != referenz {
                unterschiedGefunden = true
                break
            }
        }
        #expect(unterschiedGefunden, "Alle Seeds zogen die Teams in derselben Reihenfolge")
    }

    @Test("Die Ziehreihenfolge ist nicht die kanonische Index-Reihenfolge")
    func ziehreihenfolgeIstGemischt() throws {
        // Ohne diesen Test wuerde ein vergessener Aufruf von
        // `deterministicShuffle` nicht auffallen: Die Ereignisliste waere
        // weiterhin vollstaendig und in Topf-Reihenfolge, nur eben ungemischt.
        let kontext = eventSeqContext()
        let kanonisch: [TeamID] = (0 ..< kontext.teamCount).map { kontext.teamID($0) }

        var abweichungGefunden = false
        for seed in eventSeqSeeds {
            let lauf = try eventSeqRun(seed: seed)
            if eventSeqDrawOrder(lauf.events) != kanonisch {
                abweichungGefunden = true
                break
            }
        }
        #expect(abweichungGefunden, "Kein Seed wich von der kanonischen Reihenfolge ab")
    }

    @Test("Phase C verbraucht genau acht Ziehungen je Topf", arguments: eventSeqSeeds)
    func rngVerbrauch(seed: UInt64) throws {
        // Wichtig fuer alle, die den Generator hinterher weiterverwenden: Phase C
        // zieht ausschliesslich fuer die Ziehreihenfolge, und zwar je Topf die
        // acht Schritte eines Fisher-Yates ueber neun Elemente. Anders als in den
        // Phasen A und B haengt der Verbrauch damit nicht vom Ergebnis ab.
        //
        // Theoretisch koennte das Rejection-Sampling in `uniform` einen Wert
        // verwerfen und zusaetzlich ziehen. Die Wahrscheinlichkeit dafuer liegt
        // bei Obergrenzen bis neun in der Groessenordnung 1e-18 je Ziehung; fuer
        // die hier fest verdrahteten Seeds tritt der Fall nicht ein.
        let kontext = eventSeqContext()
        var aufbauRng = SplitMix64(seed: seed)
        let kanten = try OpponentMatcher.match(
            context: kontext,
            rng: &aufbauRng,
            maxSearchNodes: eventSeqNodeBudget
        ).edges
        let gerichtet = HomeAwayOrienter.orient(edges: kanten, context: kontext, rng: &aufbauRng)

        var rng = aufbauRng
        _ = EventSequencer.events(directedEdges: gerichtet, context: kontext, seed: seed, rng: &rng)

        var referenz = aufbauRng
        for _ in 0 ..< (8 * InputValidation.potsInOrder.count) {
            _ = referenz.next()
        }
        #expect(rng.state == referenz.state)
    }

    @Test("Der Seed steht unveraendert im Startereignis", arguments: eventSeqSeeds)
    func seedStehtImStartereignis(seed: UInt64) throws {
        // Der Seed wird durchgereicht und nicht etwa aus dem Generatorzustand
        // abgeleitet - sonst waere die Liste nicht mehr selbstbeschreibend.
        let lauf = try eventSeqRun(seed: seed)
        guard case let .drawStarted(gemeldeterSeed) = try #require(lauf.events.first) else {
            Issue.record("Erstes Ereignis ist kein drawStarted")
            return
        }
        #expect(gemeldeterSeed == seed)
    }
}
