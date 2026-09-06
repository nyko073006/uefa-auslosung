import Testing
@testable import DrawEngine

// MARK: - Lokale Helfer
//
// Alle Helfer sind `private` und tragen den Praefix `dense...`, damit sie mit
// den Helfern der uebrigen Testdateien nicht kollidieren koennen.

/// Ergebnis eines Seed-Durchlaufs ueber ein Feld.
private struct DenseLauf {

    /// Seeds, die eine vollstaendige Auslosung geliefert haben.
    var erfolgreich: [UInt64] = []

    /// Seeds, die mit `.searchBudgetExceeded` abgebrochen sind.
    var budgetAbbrueche: [UInt64] = []

    /// Seeds, die mit `.unsolvable` abgebrochen sind.
    var unloesbar: [UInt64] = []

    /// Seeds mit einem anderen Fehler, als Klartext fuer die Fehlermeldung.
    var sonstigeFehler: [String] = []
}

/// Lost ein Feld ueber einen Seed-Bereich aus und sammelt die Ausgaenge.
///
/// Es wird bewusst gesammelt statt je Seed geprueft: Ein einzelner Fehlschlag
/// sagt wenig, die Quote sagt alles. Genau daran ist der urspruengliche Fehler
/// aufgefallen - 63 von 300 Seeds.
private func denseLauf(_ teams: [Team], seeds: ClosedRange<UInt64>) -> DenseLauf {
    var lauf = DenseLauf()
    let engine = DrawEngine()
    for seed in seeds {
        do {
            let ergebnis = try engine.draw(teams: teams, seed: seed)
            let verstoesse = DrawValidator.violations(matches: ergebnis.matches, teams: ergebnis.teams)
            if verstoesse.isEmpty && ergebnis.matches.count == 144 {
                lauf.erfolgreich.append(seed)
            } else {
                lauf.sonstigeFehler.append("Seed \(seed): \(verstoesse.count) Regelverstoesse")
            }
        } catch {
            switch error {
            case .searchBudgetExceeded:
                lauf.budgetAbbrueche.append(seed)
            case .unsolvable:
                lauf.unloesbar.append(seed)
            default:
                lauf.sonstigeFehler.append("Seed \(seed): \(error)")
            }
        }
    }
    return lauf
}

/// Zaehlt die Teams je Verband und Topf, ohne ueber ein Dictionary zu iterieren.
///
/// Geliefert wird das Maximum je Topf und das Maximum insgesamt - genau die
/// beiden Kennzahlen, an denen sich die Dichte eines Feldes ablesen laesst.
private func denseDichte(_ teams: [Team]) -> (maxJeTopf: Int, maxGesamt: Int) {
    let verbaende = InputValidation.sortedAssociations(of: teams)
    var maxJeTopf = 0
    var maxGesamt = 0
    for verband in verbaende {
        let zaehler = InputValidation.potCounts(of: verband, in: teams)
        var gesamt = 0
        for anzahl in zaehler {
            gesamt += anzahl
            if anzahl > maxJeTopf { maxJeTopf = anzahl }
        }
        if gesamt > maxGesamt { maxGesamt = gesamt }
    }
    return (maxJeTopf, maxGesamt)
}

// MARK: - Tests

/// Regressionstests fuer dicht besetzte Verbandsverteilungen.
///
/// ## Hintergrund
/// Bis einschliesslich der vorigen Fassung liefen die Forward-Checks nur ueber
/// das gerade bearbeitete Topfpaar, und die Suche kannte keine Neustarts. Auf
/// dem echten Feld der Ligaphase 2025/26 scheiterten dadurch 63 von 300 Seeds
/// mit `searchBudgetExceeded`, obwohl die uebrigen Seeds dieselbe Eingabe in 144
/// bis 166 Knoten loesten. Ein fuenfzigfach groesseres Budget half nicht.
///
/// Die alte Testsuite konnte das nicht sehen, weil jedes ihrer loesbaren
/// Fixtures hoechstens zwei Teams je Verband und Topf hatte. Diese Suite schafft
/// den fehlenden Druck: Sie lost ausschliesslich Felder aus, die dichter besetzt
/// sind als `Fixtures.realistic36`.
@Suite("Dicht besetzte Verbandsverteilungen")
struct DenseFieldTests {

    // MARK: Die Fixtures sind wirklich dicht

    /// Nagelt fest, dass die neuen Fixtures den Druck aufbauen, fuer den sie da
    /// sind. Ohne diesen Test koennte eine spaetere Aenderung die Verteilung
    /// entschaerfen, und die Tests darunter wuerden weiter gruen laufen, ohne
    /// noch irgendetwas zu pruefen.
    @Test("Das echte Feld 2025/26 ist dichter besetzt als das alte Fixture")
    func echtesFeldIstDichterAlsDasAlteFixture() throws {
        try InputValidation.validate(teams: Fixtures.ligaphase2526)

        let echt = denseDichte(Fixtures.ligaphase2526)
        let alt = denseDichte(Fixtures.realistic36)

        // Das alte Fixture: hoechstens zwei je Topf, hoechstens vier insgesamt.
        #expect(alt.maxJeTopf == 2)
        #expect(alt.maxGesamt == 4)

        // Das echte Feld: ENG steht drei Mal in Topf 1 und sechs Mal insgesamt.
        #expect(echt.maxJeTopf == 3)
        #expect(echt.maxGesamt == 6)
        #expect(InputValidation.potCounts(of: Association("ENG"), in: Fixtures.ligaphase2526) == [3, 1, 1, 1])
    }

    @Test("Auch das Feld 2024/25 und die kuenstlich dichten Felder bestehen die Vorpruefung")
    func weitereFelderBestehenDieVorpruefung() throws {
        try InputValidation.validate(teams: Fixtures.ligaphase2425)
        try InputValidation.validate(teams: Fixtures.dense5)
        try InputValidation.validate(teams: Fixtures.unsolvableDense)

        // Fuenf Teams je Verband, mehr als jedes echte Feld.
        #expect(denseDichte(Fixtures.dense5).maxGesamt == 5)
        // GER und ITA mit je fuenf Teams.
        #expect(denseDichte(Fixtures.ligaphase2425).maxGesamt == 5)
    }

    // MARK: Der eigentliche Regressionstest

    /// Der Test, der den Blocker faengt.
    ///
    /// Ohne globale Forward-Checks und Neustarts scheitern hier 63 der 300
    /// Seeds. Die Erwartung ist bewusst hart formuliert - kein einziger Seed
    /// darf abbrechen -, weil ein loesbares Feld unabhaengig vom Seed loesbar
    /// bleiben muss.
    @Test("Das echte Feld 2025/26 laeuft ueber 300 Seeds vollstaendig durch", .timeLimit(.minutes(1)))
    func ligaphase2526LaeuftUeberAlleSeeds() {
        let lauf = denseLauf(Fixtures.ligaphase2526, seeds: 1 ... 300)
        let anzahl = lauf.budgetAbbrueche.count
        let erste = lauf.budgetAbbrueche.prefix(10)

        #expect(
            lauf.budgetAbbrueche.isEmpty,
            "\(anzahl) Seeds brachen mit searchBudgetExceeded ab, erste: \(erste)"
        )
        #expect(lauf.unloesbar.isEmpty, "Das Feld ist loesbar, gemeldet wurde unsolvable bei \(lauf.unloesbar.prefix(10))")
        #expect(lauf.sonstigeFehler.isEmpty, "\(lauf.sonstigeFehler.prefix(3))")
        #expect(lauf.erfolgreich.count == 300)
    }

    @Test("Das echte Feld 2024/25 laeuft ueber 200 Seeds vollstaendig durch", .timeLimit(.minutes(1)))
    func ligaphase2425LaeuftUeberAlleSeeds() {
        let lauf = denseLauf(Fixtures.ligaphase2425, seeds: 1 ... 200)
        #expect(lauf.budgetAbbrueche.isEmpty, "Budgetabbrueche bei \(lauf.budgetAbbrueche.prefix(10))")
        #expect(lauf.erfolgreich.count == 200)
    }

    /// Deckt den Befund ab, dass ein nachweislich loesbares Feld mitten im
    /// erlaubten Eingaberaum seedabhaengig scheiterte: Mit der alten Suche
    /// lieferten von acht Seeds nur drei ein Ergebnis.
    @Test("Ein loesbares Feld mit fuenf Teams je Verband haengt nicht am Seed", .timeLimit(.minutes(2)))
    func dichtesLoesbaresFeldHaengtNichtAmSeed() {
        let lauf = denseLauf(Fixtures.dense5, seeds: 1 ... 60)
        let anzahl = lauf.budgetAbbrueche.count
        let erste = lauf.budgetAbbrueche.prefix(10)

        #expect(
            lauf.budgetAbbrueche.isEmpty,
            "\(anzahl) von 60 Seeds brachen mit searchBudgetExceeded ab, erste: \(erste)"
        )
        #expect(lauf.erfolgreich.count == 60)
    }

    // MARK: Unloesbarkeit wird als solche gemeldet

    /// Deckt den Befund ab, dass unloesbare Felder mit spaet sichtbarem
    /// Widerspruch frueher als `searchBudgetExceeded` gemeldet wurden. Der
    /// Aufrufer konnte damit nicht mehr unterscheiden, ob seine Teamliste
    /// unloesbar oder die Engine nur zu langsam war.
    @Test("Ein unloesbares Feld mit Widerspruch in Topf 4 meldet unsolvable", .timeLimit(.minutes(1)))
    func unloesbaresDichtesFeldMeldetUnsolvable() {
        let lauf = denseLauf(Fixtures.unsolvableDense, seeds: 1 ... 12)

        #expect(
            lauf.budgetAbbrueche.isEmpty,
            "\(lauf.budgetAbbrueche.count) Seeds meldeten searchBudgetExceeded statt unsolvable"
        )
        #expect(lauf.erfolgreich.isEmpty, "Das Feld ist beweisbar unloesbar, es kam trotzdem ein Ergebnis")
        #expect(lauf.unloesbar.count == 12)
    }

    // MARK: Determinismus auf dem echten Feld

    @Test("Auf dem echten Feld haengt das Ergebnis nicht an der Eingabereihenfolge", arguments: [UInt64(1), 14, 16])
    func echtesFeldIstReihenfolgeUnabhaengig(seed: UInt64) throws {
        let ausOriginal = try DrawEngine().draw(teams: Fixtures.ligaphase2526, seed: seed)

        var mischer = SplitMix64(seed: seed ^ 0x5A5A_5A5A_5A5A_5A5A)
        let gemischt = Fixtures.ligaphase2526.deterministicallyShuffled(using: &mischer)
        try #require(gemischt != Fixtures.ligaphase2526)

        let ausMischung = try DrawEngine().draw(teams: gemischt, seed: seed)
        #expect(ausOriginal == ausMischung)
    }

    /// Ein einzelner, namentlich benannter Seed aus der Fehlerliste.
    ///
    /// Gegen die alte, topfpaar-lokale Suche brach Seed 14 auf diesem Feld mit
    /// `searchBudgetExceeded(exploredNodes: 2000001)` ab. Er steht hier einzeln,
    /// damit ein Fehlschlag sofort den bekannten Fall benennt, statt in der
    /// Sammelmeldung des 300-Seed-Tests unterzugehen.
    @Test("Seed 14 auf dem echten Feld liefert ein regelkonformes Ergebnis")
    func seed14AufDemEchtenFeld() throws {
        let ergebnis = try DrawEngine().draw(teams: Fixtures.ligaphase2526, seed: 14)
        #expect(ergebnis.matches.count == 144)
        #expect(DrawValidator.violations(matches: ergebnis.matches, teams: ergebnis.teams).isEmpty)
    }

    // MARK: Suchaufwand

    /// Regressionsschutz gegen ein Zurueckrutschen in die Enumeration.
    ///
    /// Das Gegenstueck zu `OpponentMatcherTests.suchaufwandBleibtKlein`, aber auf
    /// dem echten Feld statt auf dem entschaerften Fixture. Alle fuenf Seeds
    /// stammen aus der Fehlerliste der alten Fassung; dort lief jeder von ihnen
    /// ins Budget von zwei Millionen Knoten.
    @Test("Der Suchaufwand bleibt auch auf dem echten Feld klein", arguments: [UInt64(1), 14, 16, 61, 103])
    func suchaufwandAufDemEchtenFeld(seed: UInt64) throws {
        var rng = SplitMix64(seed: seed)
        let ergebnis = try OpponentMatcher.match(
            context: DrawContext(teams: Fixtures.ligaphase2526),
            rng: &rng,
            maxSearchNodes: 2_000_000
        )
        #expect(ergebnis.edges.count == 144)
        #expect(ergebnis.exploredNodes >= 144)
        #expect(
            ergebnis.exploredNodes <= 20_000,
            "Suchaufwand \(ergebnis.exploredNodes) fuer Seed \(seed)"
        )
    }

    // MARK: Das Budget wirkt jetzt als Reissleine

    /// Vor dem Fix war ein groesseres Budget wirkungslos: Ein betroffener Seed
    /// scheiterte auch beim Fuenfzigfachen des Budgets, weil die Suche immer
    /// denselben Zweig neu aufzaehlte. Mit den Neustarts kauft mehr Budget
    /// zusaetzliche Versuche mit neuer Kandidatenreihenfolge - `maxSearchNodes`
    /// ist damit wieder die Reissleine, die die Doku verspricht.
    @Test("Ein winziges Budget bricht ab, ein normales nicht")
    func budgetWirktAlsReissleine() throws {
        let winzig = DrawEngine(configuration: .init(maxSearchNodes: 20))
        #expect(throws: DrawError.self) {
            try winzig.draw(teams: Fixtures.ligaphase2526, seed: 14)
        }

        let normal = try DrawEngine().draw(teams: Fixtures.ligaphase2526, seed: 14)
        #expect(normal.matches.count == 144)
    }
}
