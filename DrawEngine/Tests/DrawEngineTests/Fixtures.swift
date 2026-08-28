import Testing
@testable import DrawEngine

/// Gemeinsame Testdaten fuer das Testtarget.
///
/// Hier liegt genau das, was mehrere Testdateien teilen koennen: ein
/// realistisches Teilnehmerfeld und ein Baukasten fuer eigene Felder. Die
/// aelteren Testdateien bringen ihre eigenen, `private` deklarierten Helfer mit
/// (Praefixe `validator...`, `matcher...`, `eventSeq...`, `homeAway...`); die
/// bleiben unangetastet, weil sie andere Verteilungen pruefen und ihre Namen
/// ohnehin nicht kollidieren koennen.
///
/// ## Determinismus
/// Beide Bausteine sind reine Funktionen ueber Arrays. Es wird nirgends ueber
/// ein `Set` oder ein `Dictionary` iteriert, damit die erzeugte Teamliste nicht
/// vom Hash-Seed des Prozesslaufs abhaengt.
enum Fixtures {

    // MARK: - Realistisches Teilnehmerfeld

    /// Verbandscodes je Topf. `[0]` ist Topf 1, `[3]` ist Topf 4.
    ///
    /// Die Verteilung bildet ein realistisches Champions-League-Feld ab:
    ///
    /// - ENG, ESP und ITA mit je vier Teams, verteilt auf Topf 1 und Topf 2
    ///   (je zwei pro Topf) - das entspricht den starken Ligen, deren Meister
    ///   und Spitzenteams in den vorderen Toepfen landen.
    /// - GER und FRA mit je drei Teams (Topf 1 bis 3).
    /// - NED, POR und BEL mit je zwei Teams.
    /// - Zwoelf Verbaende mit genau einem Team.
    ///
    /// Zusammen `3*4 + 2*3 + 3*2 + 12*1 = 36` Teams, neun je Topf.
    ///
    /// Die Verteilung haelt alle notwendigen Bedingungen aus `InputValidation`
    /// ein: hoechstens sieben Teams je Verband insgesamt (Maximum hier: vier),
    /// hoechstens vier je Topf (Maximum hier: zwei) und hoechstens neun je
    /// Topf-Paar (Maximum hier: vier).
    static let realisticPotLayout: [[String]] = [
        ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "POR"],
        ["ENG", "ENG", "ESP", "ESP", "ITA", "ITA", "GER", "FRA", "NED"],
        ["GER", "FRA", "NED", "POR", "BEL", "SCO", "AUT", "TUR", "CZE"],
        ["BEL", "SUI", "CRO", "UKR", "SRB", "DEN", "NOR", "GRE", "POL"],
    ]

    /// Das realistische Feld aus 36 Teams, gebaut aus `realisticPotLayout`.
    ///
    /// Die TeamIDs laufen von "P1T1" bis "P4T9", die Namen sind der Verbandscode
    /// mit laufender Nummer ("ENG1" bis "ENG4", "GER1" bis "GER3", ...).
    static let realistic36: [Team] = Fixtures.makeTeams(potLayout: Fixtures.realisticPotLayout)

    // MARK: - Echte Teilnehmerfelder

    /// Verbandsverteilung der echten Ligaphase 2025/26.
    ///
    /// Warum dieses Feld zusaetzlich zu `realisticPotLayout` gebraucht wird:
    /// `realisticPotLayout` haelt je Verband hoechstens **zwei** Teams pro Topf
    /// und **vier** insgesamt. Das echte Feld ist deutlich dichter - ENG steht
    /// drei Mal allein in Topf 1 und sechs Mal insgesamt. Genau in diesem
    /// Bereich kippte der Suchaufwand frueher von rund 150 Knoten auf ueber
    /// zwei Millionen, und genau deshalb konnte die Testsuite den Fehler nicht
    /// sehen, obwohl sie gruen war.
    ///
    /// Verteilung: ENG sechs, ESP fuenf, GER vier, ITA vier, FRA drei, POR zwei,
    /// NED zwei, BEL zwei, dazu acht Verbaende mit je einem Team.
    static let ligaphase2526PotLayout: [[String]] = [
        ["FRA", "ESP", "ENG", "GER", "ENG", "ITA", "ENG", "GER", "ESP"],
        ["ENG", "GER", "ESP", "POR", "ITA", "ESP", "ITA", "GER", "BEL"],
        ["ENG", "NED", "NED", "ITA", "POR", "GRE", "CZE", "NOR", "FRA"],
        ["DEN", "FRA", "TUR", "BEL", "AZE", "ESP", "ENG", "CYP", "KAZ"],
    ]

    /// Das echte Feld der Ligaphase 2025/26 aus 36 Teams.
    static let ligaphase2526: [Team] = Fixtures.makeTeams(potLayout: Fixtures.ligaphase2526PotLayout)

    /// Verbandsverteilung der echten Ligaphase 2024/25.
    ///
    /// Zweites echtes Feld mit einer anderen Art von Dichte: Hier haben GER und
    /// ITA je fuenf Teams, dafuer ist Topf 1 weniger einseitig besetzt als
    /// 2025/26.
    static let ligaphase2425PotLayout: [[String]] = [
        ["ESP", "GER", "ENG", "ITA", "FRA", "ENG", "POR", "GER", "NED"],
        ["ESP", "GER", "ENG", "ITA", "ESP", "POR", "ENG", "ITA", "GER"],
        ["NED", "ITA", "AUT", "ESP", "BEL", "CZE", "SUI", "SCO", "FRA"],
        ["ITA", "GER", "SRB", "FRA", "UKR", "CRO", "SVK", "SUI", "ENG"],
    ]

    /// Das echte Feld der Ligaphase 2024/25 aus 36 Teams.
    static let ligaphase2425: [Team] = Fixtures.makeTeams(potLayout: Fixtures.ligaphase2425PotLayout)

    // MARK: - Kuenstlich dichte Felder

    /// Loesbares Feld mit fuenf Teams je Verband, deutlich dichter als jedes
    /// echte Champions-League-Feld.
    ///
    /// Es haelt alle drei Schranken der Vorpruefung ein (hoechstens sieben Teams
    /// je Verband, hoechstens vier je Topf, hoechstens neun je Topfpaar) und
    /// liegt damit mitten in dem Eingaberaum, den die oeffentliche API als
    /// gueltig annimmt. Vor der Umstellung auf globale Forward-Checks und
    /// Neustarts scheiterte es bei fuenf von acht Seeds mit
    /// `searchBudgetExceeded`, obwohl es nachweislich loesbar ist.
    static let dense5PotLayout: [[String]] = [
        ["A05", "A10", "A07", "A06", "A10", "A06", "A11", "A02", "A08"],
        ["A07", "A06", "A06", "A01", "A12", "A11", "A01", "A03", "A04"],
        ["A01", "A03", "A01", "A05", "A03", "A03", "A03", "A01", "A09"],
        ["A04", "A12", "A09", "A06", "A12", "A02", "A12", "A12", "A10"],
    ]

    /// Das loesbare Feld mit fuenf Teams je Verband.
    static let dense5: [Team] = Fixtures.makeTeams(potLayout: Fixtures.dense5PotLayout)

    /// Beweisbar unloesbares Feld, das die Vorpruefung besteht.
    ///
    /// Verband A00 hat vier Teams in Topf 4 und sechs insgesamt. Innerhalb von
    /// Topf 4 brauchen die vier A00-Teams je zwei Gegner, die alle aus den fuenf
    /// uebrigen Topf-4-Teams kommen muessen - das verbraucht acht der zehn
    /// A00-Plaetze dort. Die A00-Teams aus Topf 1 und Topf 3 brauchen zusammen
    /// aber noch einmal vier solche Plaetze, und nur zwei sind uebrig.
    ///
    /// Kompakt gerechnet: Jedes der sechs A00-Teams braucht genau zwei Gegner
    /// aus Topf 4, macht zwoelf Plaetze. Liefern koennen sie nur die fuenf
    /// Nicht-A00-Teams aus Topf 4 mit je hoechstens zwei, also zehn. Wegen
    /// `12 > 10` existiert keine Loesung.
    ///
    /// Die Vorpruefung laesst das Feld durch: A00 hat sechs Teams (Schranke
    /// sieben), hoechstens vier je Topf (Schranke vier) und hoechstens fuenf je
    /// Topfpaar (Schranke neun).
    static let unsolvableDensePotLayout: [[String]] = [
        ["S03", "S06", "A00", "S05", "S15", "S20", "S25", "S19", "S18"],
        ["A01", "S21", "S23", "S13", "S10", "S07", "A01", "S04", "S22"],
        ["S11", "S14", "S01", "S17", "S00", "S24", "A00", "A01", "S02"],
        ["S09", "S16", "A00", "A00", "A00", "S08", "A01", "A00", "S12"],
    ]

    /// Das beweisbar unloesbare, aber vorpruefungs-taugliche Feld.
    static let unsolvableDense: [Team] = Fixtures.makeTeams(potLayout: Fixtures.unsolvableDensePotLayout)

    // MARK: - Baukasten

    /// Baut eine Teamliste aus Verbandscodes je Topf.
    ///
    /// Der aeussere Index bestimmt den Topf (`[0]` ist Topf 1), der innere die
    /// Position im Topf. Daraus entstehen TeamIDs der Form `P<topf>T<position>`,
    /// also "P1T1" bis "P4T9". Der Name ist der Verbandscode mit einer ueber
    /// alle Toepfe laufenden Nummer, damit zwei Teams desselben Verbands im
    /// Klartext unterscheidbar bleiben.
    ///
    /// So lassen sich Fehler-Fixtures kompakt bauen: Wer eine unloesbare
    /// Verteilung braucht, aendert nur die Codes; wer einen zu kleinen Topf
    /// braucht, laesst in einem inneren Array Eintraege weg.
    ///
    /// - Parameter potLayout: Bis zu vier Arrays mit Verbandscodes. Fuer
    ///   sortierfreundliche IDs sollte kein Topf mehr als neun Eintraege haben,
    ///   sonst waere "P1T10" lexikografisch kleiner als "P1T2".
    /// - Returns: Die Teams in der Reihenfolge des Layouts (Topf fuer Topf).
    static func makeTeams(potLayout: [[String]]) -> [Team] {
        precondition(
            potLayout.count <= Pot.allCases.count,
            "Es gibt nur \(Pot.allCases.count) Toepfe, das Layout hat \(potLayout.count) Eintraege"
        )

        // Reine Nachschlagetabelle fuer die laufende Nummer je Verband. Sie wird
        // nur gelesen und geschrieben, nie iteriert - die Ausgabereihenfolge
        // haengt allein an der Reihenfolge des Layouts.
        var laufendeNummerJeVerband: [Association: Int] = [:]

        var teams: [Team] = []
        teams.reserveCapacity(potLayout.reduce(0) { $0 + $1.count })

        for (topfIndex, verbandscodes) in potLayout.enumerated() {
            guard let topf = Pot(rawValue: topfIndex + 1) else {
                preconditionFailure("Kein Topf zur Nummer \(topfIndex + 1)")
            }
            for (position, code) in verbandscodes.enumerated() {
                let verband = Association(code)
                let nummer = (laufendeNummerJeVerband[verband] ?? 0) + 1
                laufendeNummerJeVerband[verband] = nummer
                teams.append(
                    Team(
                        id: TeamID("P\(topfIndex + 1)T\(position + 1)"),
                        name: "\(code)\(nummer)",
                        association: verband,
                        pot: topf
                    )
                )
            }
        }
        return teams
    }
}
