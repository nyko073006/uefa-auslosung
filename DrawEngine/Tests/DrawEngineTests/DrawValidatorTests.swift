import Testing
@testable import DrawEngine

// MARK: - Lokale Testdaten
//
// Bewusst `private` und mit eindeutigem Praefix `validator...`: Die gemeinsame
// `Fixtures.swift` enthaelt bislang kein Teilnehmerfeld und gehoert einem
// anderen Arbeitsstrang. `private` schliesst Namenskollisionen mit spaeteren
// Bauteilen dort sicher aus.

/// Verbandscodes je Topf. `[0]` ist Topf 1, `[3]` ist Topf 4.
///
/// Die Verteilung bildet ein realistisches Teilnehmerfeld ab: ENG/ESP/ITA mit je
/// vier Teams (je zwei in Topf 1 und 2), GER/FRA mit je drei, NED/POR/BEL mit je
/// zwei und zwoelf Verbaende mit genau einem Team. Zusammen sind das
/// `3*4 + 2*3 + 3*2 + 12 = 36` Teams.
///
/// Wichtig fuer die Mutations-Tests: Mindestens ein Verband (hier ENG) hat mehr
/// als drei Teams. Nur dann laesst sich ein dritter Gegner aus derselben
/// Association ueberhaupt konstruieren.
private let validatorAssociationsPerPot: [[String]] = [
    ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "POR"],
    ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "NED"],
    ["GER", "FRA", "NED", "POR", "BEL", "SCO", "AUT", "TUR", "CZE"],
    ["BEL", "SUI", "CRO", "UKR", "SRB", "DEN", "NOR", "GRE", "POL"],
]

/// Baut die 36 Teams des Testfelds.
///
/// Die TeamIDs laufen von "T01" bis "T36". Die fuehrende Null ist wichtig, weil
/// TeamIDs als String verglichen werden: ohne sie waere "T10" kleiner als "T2"
/// und die kanonische Sortierung waere schwerer nachzuvollziehen.
private func validatorTeams() -> [Team] {
    var teams: [Team] = []
    teams.reserveCapacity(36)
    var nummer = 1
    for (topfIndex, verbaende) in validatorAssociationsPerPot.enumerated() {
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

/// Die Seeds, ueber die die Invarianten geprueft werden.
private let validatorSeeds: [UInt64] = (1 ... 10).map { UInt64($0) }

/// Der Verband mit vier Teams. Grundlage der beiden Verbands-Mutationen.
private let validatorBigAssociation = Association("ENG")

/// Fuehrt eine vollstaendige Auslosung aus.
private func validatorDraw(seed: UInt64 = 2026) throws -> DrawResult {
    try DrawEngine().draw(teams: validatorTeams(), seed: seed)
}

// MARK: - Hilfsfunktionen fuer die Mutationen
//
// Alle Helfer arbeiten ausschliesslich auf Arrays und in fester Reihenfolge.
// Ein `Set` waere hier bequem, wuerde aber die Reihenfolge der Mutation vom
// Hash-Seed des Prozesslaufs abhaengig machen.

/// Alle Gegner eines Teams, aufsteigend sortiert.
private func validatorOpponents(of id: TeamID, in matches: [Matchup]) -> [TeamID] {
    var gegner: [TeamID] = []
    for match in matches {
        if match.home == id {
            gegner.append(match.away)
        } else if match.away == id {
            gegner.append(match.home)
        }
    }
    return gegner.sorted()
}

/// Der Topf eines Teams, oder `nil` bei unbekannter ID.
private func validatorPot(of id: TeamID, in teams: [Team]) -> Pot? {
    for team in teams where team.id == id { return team.pot }
    return nil
}

/// Der Index der Paarung zwischen zwei Teams, unabhaengig vom Heimrecht.
private func validatorMatchIndex(of lhs: TeamID, against rhs: TeamID, in matches: [Matchup]) -> Int? {
    for (index, match) in matches.enumerated() {
        if (match.home == lhs && match.away == rhs) || (match.home == rhs && match.away == lhs) {
            return index
        }
    }
    return nil
}

/// Tauscht den Gegner einer Paarung aus und behaelt das Heimrecht des Teams bei.
///
/// So bleibt die Mutation minimal: Nur die Gegnerschaft aendert sich, die
/// Heim/Auswaerts-Rolle des betrachteten Teams nicht.
private func validatorReplacingOpponent(
    in match: Matchup,
    of team: TeamID,
    with opponent: TeamID
) -> Matchup {
    if match.home == team {
        return Matchup(home: team, away: opponent)
    }
    return Matchup(home: opponent, away: team)
}

// MARK: - Tests: DrawValidator

@Suite("DrawValidator")
struct DrawValidatorTests {

    // MARK: Gueltiges Ergebnis

    @Test("Ein gueltiges Ergebnis hat keine Verstoesse", arguments: validatorSeeds)
    func gueltigesErgebnisIstSauber(seed: UInt64) throws {
        let ergebnis = try validatorDraw(seed: seed)
        let verstoesse = DrawValidator.violations(matches: ergebnis.matches, teams: ergebnis.teams)
        #expect(verstoesse.isEmpty)
    }

    @Test("Die Eingabereihenfolge der Teams aendert das Pruefergebnis nicht")
    func teamReihenfolgeIstEgal() throws {
        let ergebnis = try validatorDraw()
        var mischer = SplitMix64(seed: 99)
        let gemischt = ergebnis.teams.deterministicallyShuffled(using: &mischer)
        #expect(DrawValidator.violations(matches: ergebnis.matches, teams: gemischt).isEmpty)
    }

    @Test("Zwei Pruefungen derselben Mutation liefern dieselbe Liste")
    func ausgabeIstDeterministisch() throws {
        let ergebnis = try validatorDraw()
        var kaputt = ergebnis.matches
        kaputt.removeLast()
        let erste = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)
        let zweite = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)
        #expect(erste == zweite)
        #expect(!erste.isEmpty)
    }

    // MARK: Einzelne Regelverstoesse

    @Test("Eine fehlende Paarung meldet wrongMatchCount")
    func fehlendePaarung() throws {
        let ergebnis = try validatorDraw()
        var kaputt = ergebnis.matches
        kaputt.removeLast()

        let verstoesse = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)
        #expect(verstoesse.contains(.wrongMatchCount(actual: 143)))
    }

    @Test("Eine doppelte Begegnung meldet pairPlayedTwice")
    func doppelteBegegnung() throws {
        let ergebnis = try validatorDraw()

        // Die erste Paarung wird ueber die zweite geschrieben. Damit kommt sie
        // doppelt vor, die Gesamtzahl bleibt aber bei 144 - der Verstoss ist
        // also wirklich die Dopplung und nicht die Anzahl.
        var kaputt = ergebnis.matches
        kaputt[1] = kaputt[0]

        let verstoesse = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)
        let erste = ergebnis.matches[0]
        let kleinere = min(erste.home, erste.away)
        let groessere = max(erste.home, erste.away)

        #expect(kaputt.count == 144)
        #expect(!verstoesse.contains(.wrongMatchCount(actual: 144)))
        #expect(verstoesse.contains(.pairPlayedTwice(kleinere, groessere)))
    }

    @Test("Vertauschtes Heimrecht meldet homeAwayImbalance fuer beide Teams")
    func vertauschtesHeimrecht() throws {
        let ergebnis = try validatorDraw()
        let original = ergebnis.matches[0]

        var kaputt = ergebnis.matches
        kaputt[0] = Matchup(home: original.away, away: original.home)

        let topfDesHeimteams = try #require(validatorPot(of: original.home, in: ergebnis.teams))
        let topfDesGasts = try #require(validatorPot(of: original.away, in: ergebnis.teams))

        let verstoesse = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)

        // Das urspruengliche Heimteam hat gegen den Topf des Gasts nun zwei
        // Auswaertsspiele und kein Heimspiel, beim Gast ist es genau umgekehrt.
        #expect(
            verstoesse.contains(
                .homeAwayImbalance(team: original.home, pot: topfDesGasts, home: 0, away: 2)
            )
        )
        #expect(
            verstoesse.contains(
                .homeAwayImbalance(team: original.away, pot: topfDesHeimteams, home: 2, away: 0)
            )
        )
    }

    @Test("Eine Paarung im selben Verband meldet sameAssociationPairing")
    func paarungImSelbenVerband() throws {
        let ergebnis = try validatorDraw()
        let verbandsTeams = ergebnis.teams
            .filter { $0.association == validatorBigAssociation }
            .map { $0.id }
            .sorted()
        try #require(verbandsTeams.count >= 2)
        let erstes = verbandsTeams[0]
        let zweites = verbandsTeams[1]

        var kaputt = ergebnis.matches
        kaputt[0] = Matchup(home: erstes, away: zweites)

        let verstoesse = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)
        #expect(kaputt.count == 144)
        #expect(verstoesse.contains(.sameAssociationPairing(erstes, zweites)))
    }

    @Test("Ein dritter Gegner aus einem Verband meldet associationCapExceeded")
    func verbandsObergrenze() throws {
        let ergebnis = try validatorDraw()

        // Ein Team, das selbst nicht zum grossen Verband gehoert. Sonst waeren
        // die neuen Paarungen zusaetzlich Duelle im eigenen Verband und der Test
        // wuerde zwei Regeln gleichzeitig verletzen.
        let betroffen = try #require(
            ergebnis.teams.first(where: { $0.association != validatorBigAssociation })
        ).id
        let verbandsTeams = ergebnis.teams
            .filter { $0.association == validatorBigAssociation }
            .map { $0.id }
            .sorted()

        var kaputt = ergebnis.matches
        let bisherigeGegner = validatorOpponents(of: betroffen, in: kaputt)
        var freieVerbandsTeams = verbandsTeams.filter { !bisherigeGegner.contains($0) }
        var anzahlVerbandsGegner = bisherigeGegner.filter { verbandsTeams.contains($0) }.count

        // So lange Gegner aus anderen Verbaenden gegen freie Teams des grossen
        // Verbands austauschen, bis die Obergrenze von zwei ueberschritten ist.
        while anzahlVerbandsGegner < 3 {
            let ersatz = freieVerbandsTeams.removeFirst()
            let opfer = try #require(
                kaputt.firstIndex(where: { match in
                    let gegner: TeamID
                    if match.home == betroffen {
                        gegner = match.away
                    } else if match.away == betroffen {
                        gegner = match.home
                    } else {
                        return false
                    }
                    return !verbandsTeams.contains(gegner)
                })
            )
            kaputt[opfer] = validatorReplacingOpponent(in: kaputt[opfer], of: betroffen, with: ersatz)
            anzahlVerbandsGegner += 1
        }

        let verstoesse = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)
        #expect(kaputt.count == 144)
        #expect(
            verstoesse.contains(
                .associationCapExceeded(team: betroffen, association: validatorBigAssociation, count: 3)
            )
        )
    }

    @Test("Ein Selbstduell meldet teamPlaysItself")
    func selbstduell() throws {
        let ergebnis = try validatorDraw()
        let team = ergebnis.matches[0].home

        var kaputt = ergebnis.matches
        kaputt[0] = Matchup(home: team, away: team)

        let verstoesse = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)
        #expect(verstoesse.contains(.teamPlaysItself(team)))
    }

    @Test("Eine unbekannte TeamID meldet unknownTeam")
    func unbekanntesTeam() throws {
        let ergebnis = try validatorDraw()
        let fremd = TeamID("ZZZ")

        var kaputt = ergebnis.matches
        kaputt[0] = Matchup(home: fremd, away: ergebnis.matches[0].away)

        let verstoesse = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)
        #expect(verstoesse.contains(.unknownTeam(fremd)))

        // Auch bei mehrfachem Vorkommen wird die unbekannte ID nur einmal
        // gemeldet.
        var mehrfach = kaputt
        mehrfach[1] = Matchup(home: mehrfach[1].home, away: fremd)
        let zweiteRunde = DrawValidator.violations(matches: mehrfach, teams: ergebnis.teams)
        let anzahlMeldungen = zweiteRunde.filter { $0 == .unknownTeam(fremd) }.count
        #expect(anzahlMeldungen == 1)
    }

    @Test("Ein umgehaengter Gegner meldet wrongOpponentCount fuer alle drei Teams")
    func falscheGegnerzahlImTopf() throws {
        let ergebnis = try validatorDraw()

        // Ein Team aus Topf 1 verliert einen seiner beiden Gegner aus Topf 4 und
        // bekommt stattdessen einen dritten Gegner aus Topf 3.
        let betroffen = try #require(ergebnis.teams.first(where: { $0.pot == .pot1 }))
        let alleGegner = validatorOpponents(of: betroffen.id, in: ergebnis.matches)
        let gegnerAusTopf4 = alleGegner.filter { validatorPot(of: $0, in: ergebnis.teams) == .pot4 }
        try #require(gegnerAusTopf4.count == 2)
        let verlorenerGegner = gegnerAusTopf4[0]

        let neuerGegner = try #require(
            ergebnis.teams.first(where: { kandidat in
                kandidat.pot == .pot3
                    && kandidat.association != betroffen.association
                    && !alleGegner.contains(kandidat.id)
            })
        )

        var kaputt = ergebnis.matches
        let index = try #require(
            validatorMatchIndex(of: betroffen.id, against: verlorenerGegner, in: kaputt)
        )
        kaputt[index] = validatorReplacingOpponent(
            in: kaputt[index],
            of: betroffen.id,
            with: neuerGegner.id
        )

        let verstoesse = DrawValidator.violations(matches: kaputt, teams: ergebnis.teams)
        #expect(kaputt.count == 144)
        #expect(verstoesse.contains(.wrongOpponentCount(team: betroffen.id, pot: .pot4, actual: 1)))
        #expect(verstoesse.contains(.wrongOpponentCount(team: betroffen.id, pot: .pot3, actual: 3)))
        #expect(verstoesse.contains(.wrongOpponentCount(team: verlorenerGegner, pot: .pot1, actual: 1)))
        #expect(verstoesse.contains(.wrongOpponentCount(team: neuerGegner.id, pot: .pot1, actual: 3)))
    }
}

// MARK: - Tests: DrawEngine

@Suite("DrawEngine")
struct DrawEngineTests {

    // MARK: Form des Ergebnisses

    @Test("Das Ergebnis hat 36 Teams, 144 Paarungen und 190 Ereignisse", arguments: validatorSeeds)
    func ergebnisHatDieErwarteteForm(seed: UInt64) throws {
        let ergebnis = try validatorDraw(seed: seed)
        #expect(ergebnis.seed == seed)
        #expect(ergebnis.teams.count == 36)
        #expect(ergebnis.matches.count == 144)
        #expect(ergebnis.events.count == 190)
        #expect(ergebnis.events.first == .drawStarted(seed: seed))
        #expect(ergebnis.events.last == .drawCompleted)
    }

    @Test("Die Teams sind kanonisch nach Topf und TeamID sortiert", arguments: validatorSeeds)
    func teamsSindKanonischSortiert(seed: UInt64) throws {
        let ergebnis = try validatorDraw(seed: seed)
        for i in 1 ..< ergebnis.teams.count {
            let vorheriges = ergebnis.teams[i - 1]
            let aktuelles = ergebnis.teams[i]
            let sortiert = vorheriges.pot < aktuelles.pot
                || (vorheriges.pot == aktuelles.pot && vorheriges.id < aktuelles.id)
            #expect(sortiert)
        }
    }

    @Test("Die Paarungen sind kanonisch nach Team-Index sortiert", arguments: validatorSeeds)
    func paarungenSindKanonischSortiert(seed: UInt64) throws {
        let ergebnis = try validatorDraw(seed: seed)
        let kontext = DrawContext(teams: ergebnis.teams)

        var vorherigesPaar: (Int, Int)? = nil
        for match in ergebnis.matches {
            let heim = try #require(kontext.index(of: match.home))
            let auswaerts = try #require(kontext.index(of: match.away))
            if let vorher = vorherigesPaar {
                let aufsteigend = vorher.0 < heim || (vorher.0 == heim && vorher.1 < auswaerts)
                #expect(aufsteigend)
            }
            vorherigesPaar = (heim, auswaerts)
        }
    }

    // MARK: Determinismus

    @Test("Gleicher Seed liefert dasselbe Ergebnis", arguments: validatorSeeds)
    func gleicherSeedGleichesErgebnis(seed: UInt64) throws {
        let erstes = try validatorDraw(seed: seed)
        let zweites = try validatorDraw(seed: seed)
        #expect(erstes == zweites)
    }

    @Test("Die Reihenfolge der Eingabe aendert das Ergebnis nicht", arguments: validatorSeeds)
    func eingabereihenfolgeIstEgal(seed: UInt64) throws {
        let ausOriginalreihenfolge = try validatorDraw(seed: seed)

        var mischer = SplitMix64(seed: seed &* 7919 &+ 13)
        let gemischteTeams = validatorTeams().deterministicallyShuffled(using: &mischer)
        try #require(gemischteTeams != validatorTeams())

        let ausMischung = try DrawEngine().draw(teams: gemischteTeams, seed: seed)
        #expect(ausOriginalreihenfolge == ausMischung)
    }

    @Test("Verschiedene Seeds liefern verschiedene Paarungen")
    func verschiedeneSeedsVerschiedeneErgebnisse() throws {
        var gesehen: [[Matchup]] = []
        for seed in validatorSeeds {
            let ergebnis = try validatorDraw(seed: seed)
            #expect(!gesehen.contains(ergebnis.matches))
            gesehen.append(ergebnis.matches)
        }
    }

    // MARK: Fehlerfaelle

    @Test("Eine ungueltige Eingabe wird vor der Suche abgewiesen")
    func ungueltigeEingabeWirdAbgewiesen() {
        let zuWenige = Array(validatorTeams().dropLast())
        #expect(throws: DrawError.wrongTeamCount(actual: 35)) {
            _ = try DrawEngine().draw(teams: zuWenige, seed: 1)
        }
    }

    @Test("Ein zu kleines Knotenbudget bricht mit searchBudgetExceeded ab")
    func knotenbudgetGreift() {
        let engine = DrawEngine(configuration: DrawEngine.Configuration(maxSearchNodes: 5))
        #expect(throws: DrawError.searchBudgetExceeded(exploredNodes: 6)) {
            _ = try engine.draw(teams: validatorTeams(), seed: 1)
        }
    }

    @Test("Die Voreinstellung der Konfiguration ist grosszuegig genug")
    func voreinstellungReichtAus() throws {
        #expect(DrawEngine().configuration.maxSearchNodes == 2_000_000)
        #expect(throws: Never.self) {
            _ = try DrawEngine().draw(teams: validatorTeams(), seed: 4711)
        }
    }
}
