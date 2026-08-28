import Testing
@testable import DrawEngine

// MARK: - Lokale Helfer
//
// Alle Helfer sind `private` und tragen den Praefix `e2e...`. Damit koennen sie
// nicht mit den Helfern der anderen Testdateien kollidieren, die sich denselben
// Namensraum teilen.

/// Seeds fuer die Determinismus-Tests: Randwerte und ein paar auffaellige Muster.
///
/// `0` und `.max` sind bewusst dabei, weil ein Seed am Rand des Wertebereichs
/// die typischen Fehler in Mischfunktionen aufdeckt (etwa ein Zustand, der auf
/// null haengen bleibt).
private let e2eDeterminismSeeds: [UInt64] = [0, 1, 42, 0xDEAD_BEEF, .max]

/// Seeds fuer den grossen Regel-Durchlauf.
private let e2eRuleSeeds: [UInt64] = (0 ..< 200).map(UInt64.init)

/// Seeds fuer die Abfrage-Tests auf `DrawResult`.
private let e2eQuerySeeds: [UInt64] = [0, 7, 42, 4711, 2026]

/// Seeds fuer die grobe Laufzeitschranke.
private let e2ePerformanceSeeds: [UInt64] = (1 ... 20).map(UInt64.init)

/// Die erwartete Anzahl Paarungen: 36 Teams mal acht Gegner, halbiert.
private let e2eExpectedMatchCount = 144

/// Fuehrt eine vollstaendige Auslosung auf dem realistischen Feld aus.
private func e2eDraw(seed: UInt64) throws -> DrawResult {
    try DrawEngine().draw(teams: Fixtures.realistic36, seed: seed)
}

/// Nachschlagetabelle TeamID -> Topf.
///
/// Wird ausschliesslich fuer Einzelabfragen benutzt und nie iteriert, damit die
/// zufaellige Hash-Reihenfolge in keine Entscheidung einfliesst.
private func e2ePotByTeam(_ teams: [Team]) -> [TeamID: Pot] {
    var tabelle: [TeamID: Pot] = [:]
    tabelle.reserveCapacity(teams.count)
    for team in teams {
        tabelle[team.id] = team.pot
    }
    return tabelle
}

/// Nachschlagetabelle TeamID -> Association. Ebenfalls nur zum Nachschlagen.
private func e2eAssociationByTeam(_ teams: [Team]) -> [TeamID: Association] {
    var tabelle: [TeamID: Association] = [:]
    tabelle.reserveCapacity(teams.count)
    for team in teams {
        tabelle[team.id] = team.association
    }
    return tabelle
}

/// Alle vorkommenden Verbaende, aufsteigend sortiert und ohne Duplikate.
///
/// Bewusst ueber Sortierung statt ueber ein `Set` gebildet: Nur so ist die
/// Reihenfolge, in der die Verbandsobergrenze geprueft wird, reproduzierbar.
private let e2eSortedAssociations: [Association] = {
    let sortiert = Fixtures.realistic36.map(\.association).sorted()
    var eindeutig: [Association] = []
    for verband in sortiert where eindeutig.last != verband {
        eindeutig.append(verband)
    }
    return eindeutig
}()

/// Kurzschreibweise einer Paarung fuer den Golden-Master-Vergleich.
private func e2eLabel(_ match: Matchup) -> String {
    "\(match.home.rawValue)-\(match.away.rawValue)"
}

// MARK: - Tests

@Suite("DrawEngine: Ende-zu-Ende")
struct DrawEngineE2ETests {

    // MARK: Determinismus

    @Test(
        "Gleicher Seed liefert dasselbe Ergebnis, inklusive Ereignisliste",
        arguments: e2eDeterminismSeeds
    )
    func gleicherSeedGleichesErgebnis(seed: UInt64) throws {
        let erstesErgebnis = try e2eDraw(seed: seed)
        let zweitesErgebnis = try e2eDraw(seed: seed)

        // `DrawResult` ist `Equatable` ueber alle vier Felder, der Vergleich
        // deckt also Teams, Paarungen und Ereignisse in einem Rutsch ab.
        #expect(erstesErgebnis == zweitesErgebnis)

        // Zusaetzlich einzeln, damit ein Fehlschlag sofort zeigt, welches Feld
        // auseinanderlaeuft.
        #expect(erstesErgebnis.seed == zweitesErgebnis.seed)
        #expect(erstesErgebnis.teams == zweitesErgebnis.teams)
        #expect(erstesErgebnis.matches == zweitesErgebnis.matches)
        #expect(erstesErgebnis.events == zweitesErgebnis.events)
    }

    @Test(
        "Die Reihenfolge der Eingabe aendert das Ergebnis nicht",
        arguments: e2eDeterminismSeeds
    )
    func eingabereihenfolgeIstEgal(seed: UInt64) throws {
        let ausOriginalreihenfolge = try e2eDraw(seed: seed)

        // Permutiert wird mit dem eigenen Fisher-Yates auf einem eigenen,
        // vom Auslosungs-Seed unabhaengigen Generator. Die Stdlib-Variante
        // `shuffled()` waere hier nicht reproduzierbar.
        var mischer = SplitMix64(seed: seed ^ 0xA5A5_A5A5_A5A5_A5A5)
        let gemischteTeams = Fixtures.realistic36.deterministicallyShuffled(using: &mischer)

        // Die Permutation muss wirklich eine sein, sonst prueft der Test nichts.
        try #require(gemischteTeams != Fixtures.realistic36)
        try #require(gemischteTeams.count == Fixtures.realistic36.count)

        let ausMischung = try DrawEngine().draw(teams: gemischteTeams, seed: seed)

        // Das prueft die Kanonisierung im DrawContext: Er sortiert die Teams
        // nach `(pot, id)`, bevor irgendetwas gerechnet wird.
        #expect(ausOriginalreihenfolge == ausMischung)
    }

    @Test("Verschiedene Seeds liefern verschiedene Paarungen")
    func verschiedeneSeedsUnterscheidenSich() throws {
        let ersteAuslosung = try e2eDraw(seed: 1)
        let zweiteAuslosung = try e2eDraw(seed: 2)

        #expect(ersteAuslosung.matches != zweiteAuslosung.matches)
        #expect(ersteAuslosung != zweiteAuslosung)

        // Das Teilnehmerfeld ist dasselbe, nur die Paarungen unterscheiden sich.
        #expect(ersteAuslosung.teams == zweiteAuslosung.teams)
    }

    // MARK: Fachregeln ueber viele Seeds

    @Test(
        "Alle Fachregeln gelten ueber 200 Seeds",
        .timeLimit(.minutes(1)),
        arguments: e2eRuleSeeds
    )
    func alleRegelnGelten(seed: UInt64) throws {
        let ergebnis = try e2eDraw(seed: seed)

        // Erstes Paar Augen: die unabhaengige Nachpruefung.
        let verstoesse = DrawValidator.violations(matches: ergebnis.matches, teams: ergebnis.teams)
        #expect(verstoesse.isEmpty, "Validator meldet: \(verstoesse)")
        #expect(ergebnis.matches.count == e2eExpectedMatchCount)
        #expect(ergebnis.teams.count == 36)

        // Zweites Paar Augen: die Kernregeln noch einmal direkt aus dem
        // Ergebnis, ohne den Validator. Faende der Validator eine Regel gar
        // nicht erst, wuerde dieser Block sie trotzdem finden.
        let topfJeTeam = e2ePotByTeam(ergebnis.teams)
        let verbandJeTeam = e2eAssociationByTeam(ergebnis.teams)

        // Befunde werden gesammelt und einmal geprueft, statt in der inneren
        // Schleife hunderttausende Einzelpruefungen abzusetzen.
        var befunde: [String] = []

        for team in ergebnis.teams {
            var gegnerJeTopf = [Int](repeating: 0, count: 4)
            var heimJeTopf = [Int](repeating: 0, count: 4)
            var auswaertsJeTopf = [Int](repeating: 0, count: 4)
            var gegnerJeVerband: [Association: Int] = [:]

            for match in ergebnis.matches(involving: team.id) {
                let spieltHeim = match.home == team.id
                let gegnerID = spieltHeim ? match.away : match.home

                if gegnerID == team.id {
                    befunde.append("\(team.id.rawValue) spielt gegen sich selbst")
                    continue
                }
                guard let gegnerTopf = topfJeTeam[gegnerID], let gegnerVerband = verbandJeTeam[gegnerID] else {
                    befunde.append("Unbekannter Gegner \(gegnerID.rawValue)")
                    continue
                }

                let topfIndex = gegnerTopf.rawValue - 1
                gegnerJeTopf[topfIndex] += 1
                if spieltHeim {
                    heimJeTopf[topfIndex] += 1
                } else {
                    auswaertsJeTopf[topfIndex] += 1
                }

                if gegnerVerband == team.association {
                    befunde.append(
                        "\(team.id.rawValue) spielt gegen \(gegnerID.rawValue) aus demselben Verband \(gegnerVerband.rawValue)"
                    )
                }
                gegnerJeVerband[gegnerVerband, default: 0] += 1
            }

            // Genau zwei Gegner aus jedem Topf, auch aus dem eigenen.
            if gegnerJeTopf != [2, 2, 2, 2] {
                befunde.append("\(team.id.rawValue) hat Gegner je Topf \(gegnerJeTopf) statt [2, 2, 2, 2]")
            }
            // Je Topf genau ein Heim- und ein Auswaertsspiel, in Summe vier zu vier.
            if heimJeTopf != [1, 1, 1, 1] {
                befunde.append("\(team.id.rawValue) hat Heimspiele je Topf \(heimJeTopf) statt [1, 1, 1, 1]")
            }
            if auswaertsJeTopf != [1, 1, 1, 1] {
                befunde.append("\(team.id.rawValue) hat Auswaertsspiele je Topf \(auswaertsJeTopf) statt [1, 1, 1, 1]")
            }

            // Obergrenze: hoechstens zwei Gegner aus derselben Association.
            // Iteriert wird ueber die sortierte Verbandsliste, nie ueber das
            // Dictionary.
            for verband in e2eSortedAssociations {
                let anzahl = gegnerJeVerband[verband] ?? 0
                if anzahl > 2 {
                    befunde.append(
                        "\(team.id.rawValue) hat \(anzahl) Gegner aus \(verband.rawValue)"
                    )
                }
            }
        }

        #expect(befunde.isEmpty, "\(befunde.count) Befunde, erste: \(befunde.prefix(5).joined(separator: " | "))")
    }

    // MARK: Abfragen auf dem Ergebnis

    @Test(
        "matches(involving:), opponents(of:in:), homeMatches und awayMatches liefern die erwarteten Anzahlen",
        arguments: e2eQuerySeeds
    )
    func abfragenAufDemErgebnis(seed: UInt64) throws {
        let ergebnis = try e2eDraw(seed: seed)
        var befunde: [String] = []

        for team in ergebnis.teams {
            let beteiligt = ergebnis.matches(involving: team.id)
            if beteiligt.count != 8 {
                befunde.append("\(team.id.rawValue): \(beteiligt.count) Paarungen statt 8")
            }

            for topf in Pot.allCases {
                let gegner = ergebnis.opponents(of: team.id, in: topf)
                if gegner.count != 2 {
                    befunde.append("\(team.id.rawValue) in Topf \(topf.rawValue): \(gegner.count) Gegner statt 2")
                }
                // Aufsteigend sortiert und ohne Dopplung, wie dokumentiert.
                if gegner.count == 2 && !(gegner[0] < gegner[1]) {
                    befunde.append("\(team.id.rawValue) in Topf \(topf.rawValue): Gegner nicht aufsteigend sortiert")
                }
                if gegner.contains(team.id) {
                    befunde.append("\(team.id.rawValue) steht in der eigenen Gegnerliste")
                }
            }

            let heimspiele = ergebnis.homeMatches(of: team.id)
            let auswaertsspiele = ergebnis.awayMatches(of: team.id)
            if heimspiele.count != 4 {
                befunde.append("\(team.id.rawValue): \(heimspiele.count) Heimspiele statt 4")
            }
            if auswaertsspiele.count != 4 {
                befunde.append("\(team.id.rawValue): \(auswaertsspiele.count) Auswaertsspiele statt 4")
            }
            // Heim- und Auswaertsspiele zerlegen die acht Paarungen vollstaendig
            // und ueberschneidungsfrei.
            if heimspiele.count + auswaertsspiele.count != beteiligt.count {
                befunde.append("\(team.id.rawValue): Heim plus Auswaerts ergibt nicht die Gesamtzahl")
            }
        }

        #expect(befunde.isEmpty, "\(befunde.count) Befunde, erste: \(befunde.prefix(5).joined(separator: " | "))")
    }

    // MARK: Symmetrie

    @Test(
        "Jede Begegnung steht genau einmal in matches, zaehlt aber fuer beide Teams",
        arguments: e2eQuerySeeds
    )
    func symmetrieOhneGegenrichtung(seed: UInt64) throws {
        let ergebnis = try e2eDraw(seed: seed)
        var befunde: [String] = []

        // Zaehlt Begegnungen ungerichtet. Der Schluessel traegt immer die
        // lexikografisch kleinere TeamID zuerst. Reine Nachschlagetabelle, es
        // wird nur ueber `matches` iteriert.
        var anzahlJePaar: [Matchup: Int] = [:]
        anzahlJePaar.reserveCapacity(ergebnis.matches.count)
        for match in ergebnis.matches {
            let schluessel = match.home < match.away
                ? Matchup(home: match.home, away: match.away)
                : Matchup(home: match.away, away: match.home)
            anzahlJePaar[schluessel, default: 0] += 1
        }

        for match in ergebnis.matches {
            let schluessel = match.home < match.away
                ? Matchup(home: match.home, away: match.away)
                : Matchup(home: match.away, away: match.home)

            // Genau ein Eintrag je Begegnung: weder ein Duplikat in derselben
            // Richtung noch ein zusaetzlicher Eintrag in der Gegenrichtung.
            let anzahl = anzahlJePaar[schluessel] ?? 0
            if anzahl != 1 {
                befunde.append("\(e2eLabel(match)) kommt \(anzahl) mal vor")
            }
            if ergebnis.matches.contains(Matchup(home: match.away, away: match.home)) {
                befunde.append("Zu \(e2eLabel(match)) existiert zusaetzlich die Gegenrichtung")
            }

            // Beide Teams zaehlen dieselbe Begegnung als ihre Paarung.
            if !ergebnis.matches(involving: match.home).contains(match) {
                befunde.append("\(match.home.rawValue) zaehlt \(e2eLabel(match)) nicht als eigene Paarung")
            }
            if !ergebnis.matches(involving: match.away).contains(match) {
                befunde.append("\(match.away.rawValue) zaehlt \(e2eLabel(match)) nicht als eigene Paarung")
            }
        }

        // 144 gerichtete Eintraege, die 144 verschiedene Begegnungen abbilden.
        #expect(ergebnis.matches.count == e2eExpectedMatchCount)
        #expect(anzahlJePaar.count == e2eExpectedMatchCount)
        #expect(befunde.isEmpty, "\(befunde.count) Befunde, erste: \(befunde.prefix(5).joined(separator: " | "))")
    }

    // MARK: Golden Master

    /// Regressions-Pin fuer den Determinismus-Vertrag.
    ///
    /// Schlaegt dieser Test an, hat sich der Algorithmus oder die RNG-Nutzung
    /// geaendert - das ist ein bewusster Breaking Change und muss dokumentiert
    /// werden.
    ///
    /// Das ist ausdruecklich **kein** hartkodiertes Auslosungs-Ergebnis in der
    /// Produktivlogik, sondern ein Test-Pin: Die Werte wurden einmalig aus einem
    /// echten Lauf der Engine abgelesen und hier festgeschrieben. Die Engine
    /// selbst kennt sie nicht, sie rechnet sie bei jedem Lauf neu aus. Ohne
    /// diesen Pin waere die Zusage "gleicher Seed, gleiches Ergebnis" nur
    /// innerhalb eines Prozesslaufs pruefbar; mit ihm faellt auch eine
    /// unbeabsichtigte Aenderung ueber Commits, Compiler-Versionen und
    /// Build-Konfigurationen hinweg auf.
    ///
    /// ## Bewusster Breaking Change am Determinismus-Vertrag
    /// Die Werte wurden einmal neu abgelesen, nachdem die Gegnersuche auf global
    /// rechnende Forward-Checks und Neustarts umgestellt wurde (Fix fuer den
    /// Blocker "Phase A thrasht auf dem echten Feld 2025/26"). Beide Aenderungen
    /// verschieben, an welcher Stelle der Suche wie viele Zufallszahlen
    /// verbraucht werden, und damit auch die gefundene Loesung. Das ist erwartet
    /// und einmalig: Der Vertrag "gleicher Seed, gleiches Ergebnis" gilt
    /// weiterhin, nur eben gegen die neue Fassung.
    ///
    /// Vor der Umstellung begannen die Paarungen mit
    /// `P1T1-P1T7, P1T1-P2T8, P1T1-P3T3, P1T1-P4T5, P1T2-P1T3, ...`.
    @Test("Golden Master: Seed 42 auf dem realistischen Feld")
    func goldenMaster() throws {
        let ergebnis = try e2eDraw(seed: 42)

        let erwarteteErstePaarungen: [String] = [
            "P1T1-P1T5",
            "P1T1-P2T6",
            "P1T1-P3T1",
            "P1T1-P4T1",
            "P1T2-P1T7",
            "P1T2-P2T8",
            "P1T2-P3T7",
            "P1T2-P4T3",
            "P1T3-P1T2",
            "P1T3-P2T1",
        ]
        let erwarteteEreignisAnzahl = 190

        let tatsaechlicheErstePaarungen = ergebnis.matches.prefix(10).map(e2eLabel)
        #expect(tatsaechlicheErstePaarungen == erwarteteErstePaarungen)
        #expect(ergebnis.events.count == erwarteteEreignisAnzahl)

        // Die Rahmendaten muessen ebenfalls stimmen, sonst waere ein bestandener
        // Pin bei veraendertem Feld nicht aussagekraeftig.
        #expect(ergebnis.seed == 42)
        #expect(ergebnis.teams == Fixtures.realistic36.sorted { lhs, rhs in
            lhs.pot != rhs.pot ? lhs.pot < rhs.pot : lhs.id < rhs.id
        })
        #expect(ergebnis.matches.count == e2eExpectedMatchCount)
    }

    // MARK: Laufzeit

    /// Grobe Schranke gegen katastrophale Regressionen.
    ///
    /// Keine Messgenauigkeit, keine Mikro-Optimierung: Der Test soll nur
    /// anschlagen, wenn eine Aenderung die Auslosung um Groessenordnungen
    /// verlangsamt, etwa durch exponentielles Backtracking. Gemessen wird mit
    /// `ContinuousClock` aus der Standardbibliothek, damit kein Foundation
    /// noetig ist.
    @Test("20 Auslosungen laufen zusammen in unter fuenf Sekunden", .timeLimit(.minutes(1)))
    func laufzeitBleibtImRahmen() throws {
        var ergebnisse: [DrawResult] = []
        ergebnisse.reserveCapacity(e2ePerformanceSeeds.count)

        let dauer = try ContinuousClock().measure {
            for seed in e2ePerformanceSeeds {
                ergebnisse.append(try e2eDraw(seed: seed))
            }
        }

        #expect(ergebnisse.count == e2ePerformanceSeeds.count)
        #expect(dauer < .seconds(5), "20 Auslosungen brauchten \(dauer)")
    }
}
