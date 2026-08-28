import Testing
@testable import DrawEngine

// MARK: - Lokaler Team-Builder
//
// Bewusst `private` und damit nur in dieser Datei sichtbar: Die gemeinsame
// `Fixtures.swift` gehoert einem anderen Arbeitsstrang, und `private` schliesst
// Namenskollisionen mit den dortigen Bauteilen sicher aus.

/// Baut ein einzelnes Team. Der Anzeigename ist fuer die Pruefungen ohne
/// Bedeutung und wird nur aus der ID abgeleitet.
private func testTeam(id: String, association: String, pot: Pot) -> Team {
    Team(id: TeamID(id), name: "Team \(id)", association: Association(association), pot: pot)
}

/// Zweistellige, lexikographisch aufsteigende TeamID: "T01" ... "T36".
///
/// Die fuehrende Null ist wichtig: TeamIDs werden als String verglichen, und
/// ohne sie waere "T10" kleiner als "T2".
private func testTeamID(_ nummer: Int) -> String {
    nummer < 10 ? "T0\(nummer)" : "T\(nummer)"
}

/// Baut eine Teamliste aus der Beschreibung "Verbandscodes je Topf".
///
/// `verbaendeJeTopf[0]` sind die Verbaende der Teams in Topf 1, `[1]` die in
/// Topf 2 und so weiter. Die Laenge der inneren Arrays bestimmt die Topfgroesse,
/// wodurch sich auch fehlerhafte Eingaben bequem beschreiben lassen. Die
/// TeamIDs werden fortlaufend vergeben und sind damit immer eindeutig.
private func testTeams(verbaendeJeTopf: [[String]]) -> [Team] {
    let toepfe: [Pot] = Pot.allCases.sorted()
    var teams: [Team] = []
    var nummer = 1
    for (topfIndex, codes) in verbaendeJeTopf.enumerated() {
        for code in codes {
            teams.append(testTeam(id: testTeamID(nummer), association: code, pot: toepfe[topfIndex]))
            nummer += 1
        }
    }
    return teams
}

/// Neun Verbandscodes "V1" ... "V9" fuer eine unauffaellige Standardbelegung.
private let standardVerbaende: [String] = (1 ... 9).map { "V\($0)" }

/// 36 gueltige Teams: Jeder Topf enthaelt je ein Team der Verbaende V1 ... V9.
///
/// Damit hat jede Association vier Teams insgesamt und genau eines je Topf -
/// alle drei Schranken sind mit deutlichem Abstand eingehalten.
private func gueltigeTeams() -> [Team] {
    testTeams(verbaendeJeTopf: Array(repeating: standardVerbaende, count: 4))
}

/// 36 Teams mit einer realistischen, ungleichen Verbandsverteilung.
///
/// Groesster Verband ist ENG mit sechs Teams (Schranke: hoechstens sieben),
/// hoechste Topfbelegung ist zwei (Schranke: hoechstens vier).
private func realistischeTeams() -> [Team] {
    testTeams(verbaendeJeTopf: [
        ["ENG", "ENG", "ESP", "ESP", "GER", "ITA", "FRA", "POR", "NED"],
        ["ENG", "ENG", "ESP", "GER", "GER", "ITA", "FRA", "POR", "BEL"],
        ["ENG", "ESP", "GER", "ITA", "ITA", "FRA", "AUT", "CZE", "SUI"],
        ["ENG", "ESP", "GER", "ITA", "FRA", "SCO", "UKR", "SRB", "CRO"],
    ])
}

// MARK: - Pruefung der Eingabedaten

@Suite("InputValidation: notwendige Bedingungen der Eingabe")
struct InputValidationTests {

    // MARK: Schritt 1 - Teamanzahl

    @Test("Eine falsche Teamanzahl wird mit der tatsaechlichen Anzahl gemeldet", arguments: [35, 37])
    func falscheTeamanzahl(anzahl: Int) {
        var teams = gueltigeTeams()
        if anzahl < teams.count {
            teams.removeLast(teams.count - anzahl)
        } else {
            for nummer in (teams.count + 1) ... anzahl {
                teams.append(testTeam(id: testTeamID(nummer), association: "V9", pot: .pot4))
            }
        }
        #expect(teams.count == anzahl)
        #expect(throws: DrawError.wrongTeamCount(actual: anzahl)) {
            try InputValidation.validate(teams: teams)
        }
    }

    // MARK: Schritt 2 - doppelte TeamIDs

    @Test("Eine doppelte TeamID wird gemeldet, und zwar die lexikographisch kleinste")
    func doppelteTeamID() {
        var teams = gueltigeTeams()
        let ersteID = teams[0].id
        // Team 6 bekommt die ID von Team 1. Topfgroessen und Verbandsverteilung
        // bleiben gueltig, damit wirklich nur die Duplikat-Pruefung anschlaegt.
        teams[5] = Team(
            id: ersteID,
            name: teams[5].name,
            association: teams[5].association,
            pot: teams[5].pot
        )
        #expect(throws: DrawError.duplicateTeamID(ersteID)) {
            try InputValidation.validate(teams: teams)
        }
    }

    // MARK: Schritt 3 - Topfgroessen

    @Test("Ein zu kleiner Topf wird gemeldet")
    func topfZuKlein() {
        // Topf 1 hat acht, Topf 2 zehn Teams: insgesamt weiter 36, damit die
        // Anzahlpruefung passiert wird und wirklich die Topfgroesse anschlaegt.
        let teams = testTeams(verbaendeJeTopf: [
            Array(standardVerbaende.dropLast()),
            standardVerbaende + ["V0"],
            standardVerbaende,
            standardVerbaende,
        ])
        #expect(teams.count == 36)
        #expect(throws: DrawError.wrongPotSize(pot: .pot1, actual: 8)) {
            try InputValidation.validate(teams: teams)
        }
    }

    @Test("Ein zu grosser Topf wird gemeldet")
    func topfZuGross() {
        let teams = testTeams(verbaendeJeTopf: [
            standardVerbaende + ["V0"],
            Array(standardVerbaende.dropLast()),
            standardVerbaende,
            standardVerbaende,
        ])
        #expect(teams.count == 36)
        #expect(throws: DrawError.wrongPotSize(pot: .pot1, actual: 10)) {
            try InputValidation.validate(teams: teams)
        }
    }

    // MARK: Schritt 4a - Gesamtanzahl je Association

    @Test("Acht Teams einer Association sind rechnerisch unmoeglich")
    func zuVieleTeamsProVerband() {
        // XXX hat zwei Teams in jedem Topf, also acht insgesamt. Je Topf sind
        // zwei Teams unbedenklich (Schranke vier), erst die Gesamtzahl acht
        // verletzt die Schranke sieben.
        let topf = ["XXX", "XXX", "V3", "V4", "V5", "V6", "V7", "V8", "V9"]
        let teams = testTeams(verbaendeJeTopf: Array(repeating: topf, count: 4))
        #expect(throws: DrawError.infeasibleAssociationDistribution(
            association: Association("XXX"),
            reason: .tooManyTeamsTotal(count: 8)
        )) {
            try InputValidation.validate(teams: teams)
        }
    }

    // MARK: Schritt 4b - Anzahl je Topf

    @Test("Fuenf Teams einer Association in einem Topf sind rechnerisch unmoeglich")
    func zuVieleTeamsImTopf() {
        // YYY steckt mit fuenf Teams komplett in Topf 1. Gesamtzahl fuenf ist
        // erlaubt (Schranke sieben), erst die Topfbelegung fuenf verletzt die
        // Schranke vier.
        let teams = testTeams(verbaendeJeTopf: [
            ["YYY", "YYY", "YYY", "YYY", "YYY", "V6", "V7", "V8", "V9"],
            standardVerbaende,
            standardVerbaende,
            standardVerbaende,
        ])
        #expect(teams.count == 36)
        #expect(throws: DrawError.infeasibleAssociationDistribution(
            association: Association("YYY"),
            reason: .tooManyTeamsInPot(pot: .pot1, count: 5)
        )) {
            try InputValidation.validate(teams: teams)
        }
    }

    // MARK: Schritt 4c - Topfpaare

    /// Die Topfpaar-Schranke `a + b <= 9` wird direkt gegen `checkPotPairs`
    /// getestet und nicht ueber `validate(teams:)`.
    ///
    /// Grund: Ueber `validate(teams:)` ist dieser Fall nicht erreichbar. Damit
    /// `a + b > 9` gilt, muesste mindestens einer der beiden Zaehler groesser
    /// als vier sein - das faengt aber schon Schranke B
    /// (`tooManyTeamsInPot`, hoechstens vier je Topf) ab, und die laeuft vorher.
    /// Zusaetzlich waere die Gesamtzahl `a + b > 9` groesser als sieben und
    /// damit bereits von Schranke A (`tooManyTeamsTotal`) abgefangen, die noch
    /// frueher laeuft. Die Schranke bleibt trotzdem im Code: Sie ist die
    /// Bedingung, die aus der Topfpaar-Sicht folgt, und sichert die Herleitung
    /// gegen spaetere Aenderungen an den anderen beiden Schranken ab.
    @Test("Ein Topfpaar mit zusammen mehr als neun Teams wird als potPairOverflow gemeldet")
    func topfpaarUeberlauf() {
        let verband = Association("ZZZ")
        // a = 4 in Topf 1, b = 6 in Topf 2 ergibt a + b = 10 > 9.
        #expect(throws: DrawError.infeasibleAssociationDistribution(
            association: verband,
            reason: .potPairOverflow(potA: .pot1, potB: .pot2, total: 10)
        )) {
            try InputValidation.checkPotPairs(association: verband, countsPerPot: [4, 6, 0, 0])
        }
    }

    @Test("Ein Topfpaar mit genau neun Teams ist noch zulaessig")
    func topfpaarGrenzfall() {
        // a + b == 9 ist die Gleichheit in `2 * a <= 2 * (9 - b)` und damit
        // gerade noch erfuellbar.
        #expect(throws: Never.self) {
            try InputValidation.checkPotPairs(association: Association("ZZZ"), countsPerPot: [4, 5, 0, 0])
        }
    }

    @Test("Ein spaeteres Topfpaar wird ebenfalls erkannt")
    func topfpaarUeberlaufSpaeteresPaar() {
        let verband = Association("ZZZ")
        // Nur das Paar (Topf 3, Topf 4) ueberschreitet die Schranke.
        #expect(throws: DrawError.infeasibleAssociationDistribution(
            association: verband,
            reason: .potPairOverflow(potA: .pot3, potB: .pot4, total: 11)
        )) {
            try InputValidation.checkPotPairs(association: verband, countsPerPot: [0, 0, 5, 6])
        }
    }

    // MARK: Gueltige Eingaben

    @Test("Eine gleichmaessige Verteilung wird akzeptiert")
    func gueltigeVerteilungWirftNicht() {
        #expect(throws: Never.self) {
            try InputValidation.validate(teams: gueltigeTeams())
        }
    }

    @Test("Eine realistische, ungleiche Verteilung wird akzeptiert")
    func realistischeVerteilungWirftNicht() {
        let teams = realistischeTeams()
        #expect(teams.count == 36)
        #expect(throws: Never.self) {
            try InputValidation.validate(teams: teams)
        }
    }

    @Test("Sieben Teams einer Association sind der erlaubte Grenzfall")
    func siebenTeamsSindErlaubt() {
        // Grenzfall der Schranke A: m = 7 erfuellt 8 * m <= 2 * (36 - m) noch,
        // verteilt auf hoechstens zwei Teams je Topf.
        let teams = testTeams(verbaendeJeTopf: [
            ["GRZ", "GRZ", "V3", "V4", "V5", "V6", "V7", "V8", "V9"],
            ["GRZ", "GRZ", "V3", "V4", "V5", "V6", "V7", "V8", "V9"],
            ["GRZ", "GRZ", "V3", "V4", "V5", "V6", "V7", "V8", "V9"],
            ["GRZ", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9"],
        ])
        #expect(throws: Never.self) {
            try InputValidation.validate(teams: teams)
        }
    }

    // MARK: Reihenfolge der Pruefungen

    @Test("Die Teamanzahl wird vor allen anderen Bedingungen geprueft")
    func anzahlSchlaegtDuplikat() {
        // Eingabe mit doppelter ID UND falscher Anzahl: Gemeldet wird die Anzahl.
        var teams = gueltigeTeams()
        teams[5] = Team(id: teams[0].id, name: teams[5].name, association: teams[5].association, pot: teams[5].pot)
        teams.removeLast()
        #expect(throws: DrawError.wrongTeamCount(actual: 35)) {
            try InputValidation.validate(teams: teams)
        }
    }

    @Test("Die Verbandsliste ist sortiert und ohne Duplikate")
    func verbandslisteIstKanonisch() {
        let verbaende = InputValidation.sortedAssociations(of: realistischeTeams())
        #expect(verbaende == verbaende.sorted())
        #expect(Set(verbaende).count == verbaende.count)
        #expect(verbaende.map { $0.rawValue } == [
            "AUT", "BEL", "CRO", "CZE", "ENG", "ESP", "FRA", "GER",
            "ITA", "NED", "POR", "SCO", "SRB", "SUI", "UKR",
        ])
    }
}

// MARK: - Index-Repraesentation

@Suite("DrawContext: kanonische Index-Abbildung")
struct DrawContextTests {

    @Test("Die Teams liegen in kanonischer Sortierung nach Topf und TeamID")
    func kanonischeSortierung() {
        let context = DrawContext(teams: realistischeTeams())
        for i in 1 ..< context.teamCount {
            let vorher = context.teams[i - 1]
            let jetzt = context.teams[i]
            let istSortiert = vorher.pot < jetzt.pot || (vorher.pot == jetzt.pot && vorher.id < jetzt.id)
            #expect(istSortiert, "Index \(i) verletzt die kanonische Sortierung")
        }
    }

    @Test("Jeder Topf belegt seinen festen Index-Block", arguments: zip(
        [Pot.pot1, .pot2, .pot3, .pot4],
        [0 ..< 9, 9 ..< 18, 18 ..< 27, 27 ..< 36]
    ))
    func topfBloecke(pot: Pot, erwarteterBereich: Range<Int>) {
        let context = DrawContext(teams: realistischeTeams())
        #expect(context.teamIndices(inPot: pot) == erwarteterBereich)
        for index in erwarteterBereich {
            #expect(context.potOfTeam(index) == pot)
            #expect(context.potIndex[index] == pot.rawValue - 1)
        }
    }

    @Test("teamID und index(of:) sind zueinander invers")
    func indexAbbildungIstInvers() throws {
        let context = DrawContext(teams: realistischeTeams())
        for index in 0 ..< context.teamCount {
            #expect(context.index(of: context.teamID(index)) == index)
        }
        for team in realistischeTeams() {
            let index = try #require(context.index(of: team.id))
            #expect(context.teamID(index) == team.id)
        }
    }

    @Test("Eine unbekannte TeamID liefert nil")
    func unbekannteTeamID() {
        let context = DrawContext(teams: realistischeTeams())
        #expect(context.index(of: TeamID("GIBTESNICHT")) == nil)
    }

    @Test("Die Verbandsnummern passen zur sortierten Verbandsliste")
    func verbandsIndizes() {
        let context = DrawContext(teams: realistischeTeams())
        #expect(context.associationCount == 15)
        #expect(context.associations == context.associations.sorted())
        for index in 0 ..< context.teamCount {
            #expect(context.association(ofTeam: index) == context.teams[index].association)
        }
        // Gleiche Nummer genau dann, wenn gleicher Verband.
        for a in 0 ..< context.teamCount {
            for b in 0 ..< context.teamCount {
                let gleicherVerband = context.teams[a].association == context.teams[b].association
                #expect(context.sameAssociation(a, b) == gleicherVerband)
            }
        }
    }

    @Test("Der Context ist unabhaengig von der Eingabereihenfolge", arguments: [0, 1, 42, 4_711] as [UInt64])
    func reihenfolgeUnabhaengig(seed: UInt64) {
        let referenz = DrawContext(teams: realistischeTeams())

        var rng = SplitMix64(seed: seed)
        let permutiert = realistischeTeams().deterministicallyShuffled(using: &rng)
        let context = DrawContext(teams: permutiert)

        #expect(context.teams == referenz.teams)
        #expect(context.associations == referenz.associations)
        #expect(context.associationIndex == referenz.associationIndex)
        #expect(context.potIndex == referenz.potIndex)
        for index in 0 ..< referenz.teamCount {
            #expect(context.index(of: referenz.teamID(index)) == index)
        }
    }
}
