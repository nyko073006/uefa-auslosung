import Testing
@testable import DrawEngine

// MARK: - Lokale Testdaten
//
// Bewusst `private` und mit eindeutigem Praefix `matcher...`: Die gemeinsame
// `Fixtures.swift` gehoert einem anderen Arbeitsstrang. `private` schliesst
// Namenskollisionen mit spaeteren Bauteilen dort sicher aus.

/// Verbandscodes je Topf. `[0]` ist Topf 1, `[3]` ist Topf 4.
///
/// Die Verteilung bildet ein realistisches Teilnehmerfeld ab:
/// ENG/ESP/ITA mit je vier Teams (je zwei in Topf 1 und 2), GER/FRA mit je drei,
/// NED/POR/BEL mit je zwei und zwoelf Verbaende mit genau einem Team. Zusammen
/// sind das `3*4 + 2*3 + 3*2 + 12 = 36` Teams.
///
/// Die Verteilung haelt alle Schranken der Vorpruefung ein: hoechstens sieben
/// Teams je Verband insgesamt, hoechstens vier je Topf und hoechstens neun je
/// Topfpaar.
private let matcherAssociationsPerPot: [[String]] = [
    ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "POR"],
    ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "NED"],
    ["GER", "FRA", "NED", "POR", "BEL", "SCO", "AUT", "TUR", "CZE"],
    ["BEL", "SUI", "CRO", "UKR", "SRB", "DEN", "NOR", "GRE", "POL"],
]

/// Baut die 36 Teams des Testfelds.
///
/// Die TeamIDs laufen von "T01" bis "T36". Die fuehrende Null ist wichtig, weil
/// TeamIDs als String verglichen werden: ohne sie waere "T10" kleiner als "T2"
/// und die kanonische Sortierung des `DrawContext` waere schwerer nachzuvollziehen.
private func matcherTeams() -> [Team] {
    var teams: [Team] = []
    teams.reserveCapacity(36)
    var nummer = 1
    for (topfIndex, verbaende) in matcherAssociationsPerPot.enumerated() {
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
private func matcherContext() -> DrawContext {
    DrawContext(teams: matcherTeams())
}

/// Die Seeds, ueber die die Invarianten geprueft werden.
///
/// Dreissig Laeufe decken deutlich verschiedene Kandidatenreihenfolgen ab; ein
/// systematischer Fehler in den Nebenbedingungen faellt damit zuverlaessig auf.
private let matcherSeeds: [UInt64] = (1 ... 30).map { UInt64($0) }

/// Grosszuegiges Knotenbudget fuer die Invarianten-Tests. Ein realistischer Lauf
/// bleibt weit darunter; die Grenze schuetzt nur davor, dass ein Fehler in den
/// Forward-Checks den Test haengen laesst statt ihn scheitern zu lassen.
private let matcherNodeBudget: Int = 200_000

/// Fuehrt einen Matching-Lauf fuer den angegebenen Seed aus.
private func matcherRun(seed: UInt64, maxSearchNodes: Int = matcherNodeBudget) throws -> OpponentMatcher.Outcome {
    var rng = SplitMix64(seed: seed)
    return try OpponentMatcher.match(context: matcherContext(), rng: &rng, maxSearchNodes: maxSearchNodes)
}

// MARK: - Tests

@Suite("OpponentMatcher")
struct OpponentMatcherTests {

    // MARK: Testfeld

    @Test("Das Testfeld besteht die Vorpruefung")
    func testfeldIstGueltig() throws {
        try InputValidation.validate(teams: matcherTeams())
    }

    // MARK: Struktur des Ergebnisses

    @Test("Es entstehen genau 144 verschiedene Paarungen", arguments: matcherSeeds)
    func genau144Kanten(seed: UInt64) throws {
        let ergebnis = try matcherRun(seed: seed)
        #expect(ergebnis.edges.count == 144)
        // Set nur zum Zaehlen, nicht zum Iterieren: die Reihenfolge einer Menge
        // haengt vom Hash-Seed des Prozesslaufs ab und darf nichts entscheiden.
        #expect(Set(ergebnis.edges).count == 144)
    }

    @Test("Jedes Team hat acht Gegner, genau zwei je Topf", arguments: matcherSeeds)
    func achtGegnerZweiJeTopf(seed: UInt64) throws {
        let ergebnis = try matcherRun(seed: seed)
        let kontext = matcherContext()

        var grad = [Int](repeating: 0, count: kontext.teamCount)
        var gradJeTopf = [[Int]](
            repeating: [Int](repeating: 0, count: 4),
            count: kontext.teamCount
        )

        for kante in ergebnis.edges {
            grad[kante.a] += 1
            grad[kante.b] += 1
            gradJeTopf[kante.a][kontext.potIndex[kante.b]] += 1
            gradJeTopf[kante.b][kontext.potIndex[kante.a]] += 1
        }

        for team in 0 ..< kontext.teamCount {
            #expect(grad[team] == 8, "Team \(kontext.teamID(team).rawValue) hat \(grad[team]) Gegner")
            for topf in 0 ..< 4 {
                #expect(
                    gradJeTopf[team][topf] == 2,
                    "Team \(kontext.teamID(team).rawValue) hat \(gradJeTopf[team][topf]) Gegner aus Topf \(topf + 1)"
                )
            }
        }
    }

    // MARK: Verbandsregeln

    @Test("Keine Paarung innerhalb derselben Association", arguments: matcherSeeds)
    func keinVerbandsduell(seed: UInt64) throws {
        let ergebnis = try matcherRun(seed: seed)
        let kontext = matcherContext()

        for kante in ergebnis.edges {
            let heim = kontext.teamID(kante.a).rawValue
            let gast = kontext.teamID(kante.b).rawValue
            let verband = kontext.association(ofTeam: kante.a).rawValue
            #expect(
                !kontext.sameAssociation(kante.a, kante.b),
                "\(heim) gegen \(gast) im Verband \(verband)"
            )
        }
    }

    @Test("Hoechstens zwei Gegner aus derselben Association", arguments: matcherSeeds)
    func hoechstensZweiJeVerband(seed: UInt64) throws {
        let ergebnis = try matcherRun(seed: seed)
        let kontext = matcherContext()

        var zaehler = [[Int]](
            repeating: [Int](repeating: 0, count: kontext.associationCount),
            count: kontext.teamCount
        )
        for kante in ergebnis.edges {
            zaehler[kante.a][kontext.associationIndex[kante.b]] += 1
            zaehler[kante.b][kontext.associationIndex[kante.a]] += 1
        }

        for team in 0 ..< kontext.teamCount {
            let name = kontext.teamID(team).rawValue
            for verband in 0 ..< kontext.associationCount {
                let code = kontext.associations[verband].rawValue
                let anzahl = zaehler[team][verband]
                #expect(anzahl <= 2, "Team \(name) hat \(anzahl) Gegner aus \(code)")
            }
        }
    }

    // MARK: Determinismus

    @Test("Gleicher Seed liefert dieselbe Kantenliste", arguments: matcherSeeds)
    func gleicherSeedGleichesErgebnis(seed: UInt64) throws {
        let ersterLauf = try matcherRun(seed: seed)
        let zweiterLauf = try matcherRun(seed: seed)
        #expect(ersterLauf.edges.sorted() == zweiterLauf.edges.sorted())
        // Auch die Platzierungsreihenfolge selbst muss reproduzierbar sein.
        #expect(ersterLauf.edges == zweiterLauf.edges)
        #expect(ersterLauf.exploredNodes == zweiterLauf.exploredNodes)
    }

    @Test("Verschiedene Seeds liefern verschiedene Kantenmengen")
    func verschiedeneSeedsVerschiedeneErgebnisse() throws {
        let referenz = try matcherRun(seed: matcherSeeds[0]).edges.sorted()
        var unterschiedGefunden = false
        for seed in matcherSeeds.dropFirst() {
            if try matcherRun(seed: seed).edges.sorted() != referenz {
                unterschiedGefunden = true
                break
            }
        }
        #expect(unterschiedGefunden, "Alle Seeds lieferten dieselbe Kantenmenge")
    }

    // MARK: Suchbudget

    @Test("Ein zu kleines Knotenbudget bricht die Suche ab")
    func budgetWirdEingehalten() throws {
        var rng = SplitMix64(seed: 4711)
        do {
            _ = try OpponentMatcher.match(context: matcherContext(), rng: &rng, maxSearchNodes: 5)
            Issue.record("Erwartet war ein Abbruch wegen aufgebrauchten Budgets")
        } catch {
            guard case .searchBudgetExceeded(let knoten) = error else {
                Issue.record("Falscher Fehler: \(error)")
                return
            }
            // Abgebrochen wird beim ersten Knoten oberhalb des Budgets.
            #expect(knoten == 6)
        }
    }

    @Test("Der Suchaufwand bleibt im erwarteten Rahmen", arguments: matcherSeeds)
    func suchaufwandBleibtKlein(seed: UInt64) throws {
        let ergebnis = try matcherRun(seed: seed)
        // Untergrenze: 144 Kanten muessen mindestens einmal gesetzt werden.
        #expect(ergebnis.exploredNodes >= 144)
        // Obergrenze als Regressionsschutz: Gemessen ueber 5000 Seeds liegt der
        // Aufwand bei diesem Testfeld zwischen 144 und 190 Knoten, es wird also
        // kaum zurueckgesetzt. Faellt ein Forward-Check aus, steigt der Wert
        // sofort um Groessenordnungen und der Test schlaegt an.
        #expect(ergebnis.exploredNodes <= 5_000, "Suchaufwand \(ergebnis.exploredNodes) fuer Seed \(seed)")
    }
}
