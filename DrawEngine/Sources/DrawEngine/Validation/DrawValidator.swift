/// Ein einzelner Regelverstoss in einem fertigen Auslosungs-Ergebnis.
///
/// Jeder Fall benennt genau eine verletzte Fachregel. Die Faelle sind bewusst
/// unabhaengig voneinander: Eine einzige falsch gesetzte Paarung kann mehrere
/// Verstoesse ausloesen, weil sie mehrere Regeln gleichzeitig bricht. Genau das
/// ist gewollt - der Validator soll das vollstaendige Schadensbild zeigen und
/// nicht beim ersten Fund abbrechen.
public enum RuleViolation: Hashable, Sendable {

    /// Das Ergebnis enthaelt nicht genau 144 Paarungen.
    case wrongMatchCount(actual: Int)

    /// Dieselbe Begegnung kommt mehr als einmal vor.
    ///
    /// Die beiden TeamIDs stehen immer mit der lexikografisch kleineren zuerst,
    /// damit derselbe Verstoss nicht in zwei Schreibweisen auftauchen kann.
    case pairPlayedTwice(TeamID, TeamID)

    /// Ein Team ist in derselben Paarung Heim- und Auswaertsmannschaft.
    case teamPlaysItself(TeamID)

    /// Ein Team hat nicht genau zwei Gegner aus diesem Topf.
    case wrongOpponentCount(team: TeamID, pot: Pot, actual: Int)

    /// Zwei Teams derselben Association spielen gegeneinander.
    ///
    /// Die beiden TeamIDs stehen immer mit der lexikografisch kleineren zuerst.
    case sameAssociationPairing(TeamID, TeamID)

    /// Ein Team hat mehr als zwei Gegner aus derselben Association.
    case associationCapExceeded(team: TeamID, association: Association, count: Int)

    /// Ein Team hat gegen die Gegner aus diesem Topf nicht genau ein Heim- und
    /// ein Auswaertsspiel.
    case homeAwayImbalance(team: TeamID, pot: Pot, home: Int, away: Int)

    /// Eine Paarung nennt eine TeamID, die nicht zum Teilnehmerfeld gehoert.
    case unknownTeam(TeamID)
}

/// Unabhaengige Nachpruefung eines fertigen Auslosungs-Ergebnisses.
///
/// ## Warum es diesen Typ gibt
/// Der Validator ist bewusst **naiv** und **eigenstaendig**: Er kennt weder den
/// Suchzustand des Matchers noch dessen Bitmasken, Zaehler oder Zwischenschritte
/// und uebernimmt von dort keine einzige Zahl. Er sieht nur das Endergebnis -
/// eine Liste von Paarungen und eine Liste von Teams - und zaehlt alles von
/// vorne neu ab. Genau diese Unabhaengigkeit macht ihn als Kontrollinstanz
/// wertvoll: Ein Denkfehler in der Suche kann sich hier nicht wiederholen, weil
/// hier nichts von der Suche wiederverwendet wird.
///
/// ## Vollstaendigkeit statt Abbruch
/// Es werden immer alle Regeln geprueft und alle Verstoesse gesammelt. Auch
/// wenn die Anzahl der Paarungen nicht stimmt, laufen die uebrigen Pruefungen
/// weiter - bei einem kaputten Ergebnis will man das ganze Bild sehen und nicht
/// nur den ersten Fund.
///
/// ## Determinismus
/// Die Ausgabeliste ist vollstaendig deterministisch. Sie folgt einer festen
/// Reihenfolge von acht Pruefschritten, und innerhalb jedes Schritts wird das
/// Teilnehmerfeld in kanonischer Ordnung `(pot, id)` durchlaufen. Paare stehen
/// immer mit der lexikografisch kleineren TeamID zuerst. Es wird nirgends ueber
/// ein `Set` oder ein `Dictionary` iteriert; Dictionaries dienen ausschliesslich
/// als Nachschlagetabellen, weil Swift den Hash-Seed pro Prozesslauf
/// randomisiert.
public enum DrawValidator {

    // MARK: - Konstanten der Fachregeln

    /// Erwartete Anzahl der Paarungen.
    ///
    /// 36 Teams mit je acht Gegnern ergeben `36 * 8 / 2 = 144` Begegnungen. Die
    /// Zahl ist bewusst fest verdrahtet und nicht aus `teams.count` abgeleitet:
    /// Ein Ergebnis mit einer anderen Teamzahl ist kein gueltiges Ergebnis, und
    /// die Abweichung soll gemeldet und nicht wegdefiniert werden.
    private static let expectedMatchCount: Int = 144

    /// Erwartete Anzahl Gegner je Topf, auch im eigenen Topf.
    private static let expectedOpponentsPerPot: Int = 2

    /// Obergrenze fuer Gegner aus derselben Association.
    private static let maxOpponentsPerAssociation: Int = 2

    /// Erwartete Anzahl Heimspiele je Topf.
    private static let expectedHomeMatchesPerPot: Int = 1

    /// Erwartete Anzahl Auswaertsspiele je Topf.
    private static let expectedAwayMatchesPerPot: Int = 1

    /// Die vier Toepfe in fester, aufsteigender Reihenfolge.
    ///
    /// Eigene Konstante statt eines Zugriffs auf die Vorpruefung, damit der
    /// Validator wirklich nichts aus dem uebrigen Auslosungs-Code bezieht.
    private static let potsInOrder: [Pot] = Pot.allCases.sorted()

    // MARK: - Einstieg

    /// Prueft ein Auslosungs-Ergebnis gegen alle Fachregeln.
    ///
    /// Die Reihenfolge der gemeldeten Verstoesse ist Teil des Vertrags:
    /// 1. Anzahl der Paarungen
    /// 2. unbekannte TeamIDs (aufsteigend, ohne Duplikate)
    /// 3. Selbstduelle
    /// 4. doppelte Begegnungen
    /// 5. Paarungen innerhalb derselben Association
    /// 6. Gegnerzahl je Topf
    /// 7. Obergrenze je Association
    /// 8. Heim/Auswaerts-Bilanz je Topf
    ///
    /// - Parameters:
    ///   - matches: Die gerichteten Paarungen des Ergebnisses, Reihenfolge egal.
    ///   - teams: Das Teilnehmerfeld, Reihenfolge egal.
    /// - Returns: Alle gefundenen Verstoesse; leer bedeutet regelkonform.
    public static func violations(matches: [Matchup], teams: [Team]) -> [RuleViolation] {
        let zaehlung = Tally(matches: matches, teams: teams)
        let anzahlTeams = zaehlung.teams.count

        var verstoesse: [RuleViolation] = []

        // Schritt 1: Anzahl der Paarungen.
        if matches.count != expectedMatchCount {
            verstoesse.append(.wrongMatchCount(actual: matches.count))
        }

        // Schritt 2: Unbekannte TeamIDs. Sie haben keinen Platz in der
        // kanonischen Ordnung, deshalb wird hier aufsteigend sortiert und jede
        // ID nur einmal gemeldet, egal wie oft sie vorkommt.
        var bereitsGemeldet: [TeamID] = []
        for id in zaehlung.unknownIDs.sorted() where bereitsGemeldet.last != id {
            bereitsGemeldet.append(id)
            verstoesse.append(.unknownTeam(id))
        }

        // Schritt 3: Selbstduelle.
        for i in 0 ..< anzahlTeams where zaehlung.playsItself[i] {
            verstoesse.append(.teamPlaysItself(zaehlung.teams[i].id))
        }

        // Schritt 4: Doppelte Begegnungen. Nur die obere Dreiecksmatrix, damit
        // jedes Paar genau einmal betrachtet wird.
        for i in 0 ..< anzahlTeams {
            for j in (i + 1) ..< anzahlTeams where zaehlung.pairCount[i][j] > 1 {
                let paar = orderedPair(zaehlung.teams[i].id, zaehlung.teams[j].id)
                verstoesse.append(.pairPlayedTwice(paar.0, paar.1))
            }
        }

        // Schritt 5: Paarungen innerhalb derselben Association.
        for i in 0 ..< anzahlTeams {
            for j in (i + 1) ..< anzahlTeams
            where zaehlung.pairCount[i][j] > 0
                && zaehlung.associationIndex[i] == zaehlung.associationIndex[j] {
                let paar = orderedPair(zaehlung.teams[i].id, zaehlung.teams[j].id)
                verstoesse.append(.sameAssociationPairing(paar.0, paar.1))
            }
        }

        // Schritt 6: Genau zwei Gegner je Topf.
        for i in 0 ..< anzahlTeams {
            for (p, topf) in potsInOrder.enumerated()
            where zaehlung.opponentsPerPot[i][p] != expectedOpponentsPerPot {
                verstoesse.append(
                    .wrongOpponentCount(
                        team: zaehlung.teams[i].id,
                        pot: topf,
                        actual: zaehlung.opponentsPerPot[i][p]
                    )
                )
            }
        }

        // Schritt 7: Hoechstens zwei Gegner aus derselben Association.
        for i in 0 ..< anzahlTeams {
            for (v, verband) in zaehlung.associations.enumerated()
            where zaehlung.opponentsPerAssociation[i][v] > maxOpponentsPerAssociation {
                verstoesse.append(
                    .associationCapExceeded(
                        team: zaehlung.teams[i].id,
                        association: verband,
                        count: zaehlung.opponentsPerAssociation[i][v]
                    )
                )
            }
        }

        // Schritt 8: Je Topf genau ein Heim- und ein Auswaertsspiel.
        for i in 0 ..< anzahlTeams {
            for (p, topf) in potsInOrder.enumerated() {
                let heim = zaehlung.homePerPot[i][p]
                let auswaerts = zaehlung.awayPerPot[i][p]
                guard heim != expectedHomeMatchesPerPot || auswaerts != expectedAwayMatchesPerPot else {
                    continue
                }
                verstoesse.append(
                    .homeAwayImbalance(
                        team: zaehlung.teams[i].id,
                        pot: topf,
                        home: heim,
                        away: auswaerts
                    )
                )
            }
        }

        return verstoesse
    }

    // MARK: - Hilfsfunktionen

    /// Bringt zwei TeamIDs in aufsteigende Reihenfolge.
    ///
    /// Damit ist die Schreibweise eines Paar-Verstosses eindeutig und unabhaengig
    /// davon, welches der beiden Teams in der kanonischen Ordnung frueher kommt.
    private static func orderedPair(_ lhs: TeamID, _ rhs: TeamID) -> (TeamID, TeamID) {
        lhs <= rhs ? (lhs, rhs) : (rhs, lhs)
    }

    // MARK: - Rohzaehlung

    /// Alle aus den Paarungen abgeleiteten Zaehler, einmal frisch berechnet.
    ///
    /// Der Typ ist reine Buchhaltung: Er entscheidet nichts, er zaehlt nur. Die
    /// Bewertung passiert ausschliesslich in `violations(matches:teams:)`.
    /// Saemtliche Zaehler liegen als Arrays ueber Team-Indizes vor, damit die
    /// spaeteren Schleifen eine feste Reihenfolge haben.
    private struct Tally {

        /// Das Teilnehmerfeld, kanonisch sortiert nach `(pot.rawValue, id.rawValue)`.
        let teams: [Team]

        /// Alle vorkommenden Associations, aufsteigend und ohne Duplikate.
        let associations: [Association]

        /// Nullbasierte Topfnummer je Team-Index.
        let potIndex: [Int]

        /// Verbandsnummer je Team-Index, passend zu `associations`.
        let associationIndex: [Int]

        /// Wie oft die Begegnung `i` gegen `j` vorkommt, nur fuer `i < j`
        /// gefuellt. Alle uebrigen Felder bleiben auf 0.
        let pairCount: [[Int]]

        /// Heimspiele je Team gegen Gegner aus Topf `p`.
        let homePerPot: [[Int]]

        /// Auswaertsspiele je Team gegen Gegner aus Topf `p`.
        let awayPerPot: [[Int]]

        /// Ob das Team mindestens einmal gegen sich selbst antritt.
        let playsItself: [Bool]

        /// Alle TeamIDs aus den Paarungen, die im Teilnehmerfeld fehlen,
        /// inklusive Mehrfachnennungen und in Fundreihenfolge.
        let unknownIDs: [TeamID]

        /// Anzahl **verschiedener** Gegner je Team und Topf.
        let opponentsPerPot: [[Int]]

        /// Anzahl **verschiedener** Gegner je Team und Association.
        let opponentsPerAssociation: [[Int]]

        /// Zaehlt ein Ergebnis vollstaendig neu aus.
        ///
        /// - Parameters:
        ///   - matches: Die zu pruefenden Paarungen in beliebiger Reihenfolge.
        ///   - teams: Das Teilnehmerfeld in beliebiger Reihenfolge.
        init(matches: [Matchup], teams eingabe: [Team]) {
            // Kanonische Totalordnung: erst Topf, dann TeamID. Sie bestimmt die
            // Reihenfolge, in der die Verstoesse spaeter gemeldet werden.
            let sortierteTeams: [Team] = eingabe.sorted { lhs, rhs in
                if lhs.pot != rhs.pot { return lhs.pot < rhs.pot }
                return lhs.id < rhs.id
            }
            self.teams = sortierteTeams
            let anzahl = sortierteTeams.count

            // Verbandsliste ueber "sortieren und benachbarte Duplikate
            // ueberspringen". Bewusst kein Set, damit die Nummerierung und damit
            // die Meldereihenfolge reproduzierbar bleibt.
            let alleVerbaende: [Association] = sortierteTeams.map { $0.association }.sorted()
            var eindeutigeVerbaende: [Association] = []
            eindeutigeVerbaende.reserveCapacity(alleVerbaende.count)
            for verband in alleVerbaende where eindeutigeVerbaende.last != verband {
                eindeutigeVerbaende.append(verband)
            }
            self.associations = eindeutigeVerbaende

            // Nachschlagetabellen. Sie werden nur abgefragt, nie iteriert.
            var nummerJeVerband: [Association: Int] = [:]
            nummerJeVerband.reserveCapacity(eindeutigeVerbaende.count)
            for (nummer, verband) in eindeutigeVerbaende.enumerated() {
                nummerJeVerband[verband] = nummer
            }

            var indexJeID: [TeamID: Int] = [:]
            indexJeID.reserveCapacity(anzahl)
            var topfNummern = [Int](repeating: 0, count: anzahl)
            var verbandsNummern = [Int](repeating: 0, count: anzahl)

            for (index, team) in sortierteTeams.enumerated() {
                indexJeID[team.id] = index
                topfNummern[index] = team.pot.rawValue - 1
                guard let nummer = nummerJeVerband[team.association] else {
                    preconditionFailure("Verband \(team.association.rawValue) fehlt in der Verbandsliste")
                }
                verbandsNummern[index] = nummer
            }
            self.potIndex = topfNummern
            self.associationIndex = verbandsNummern

            let topfAnzahl = DrawValidator.potsInOrder.count
            var paare = [[Int]](repeating: [Int](repeating: 0, count: anzahl), count: anzahl)
            var heim = [[Int]](repeating: [Int](repeating: 0, count: topfAnzahl), count: anzahl)
            var auswaerts = [[Int]](repeating: [Int](repeating: 0, count: topfAnzahl), count: anzahl)
            var selbstduell = [Bool](repeating: false, count: anzahl)
            var unbekannte: [TeamID] = []

            for match in matches {
                let heimIndex = indexJeID[match.home]
                let auswaertsIndex = indexJeID[match.away]
                if heimIndex == nil { unbekannte.append(match.home) }
                if auswaertsIndex == nil { unbekannte.append(match.away) }

                // Eine Paarung mit unbekanntem Team ist bereits gemeldet und
                // fliesst in keinen weiteren Zaehler ein - sie hat im
                // Teilnehmerfeld schlicht keinen Platz.
                guard let h = heimIndex, let a = auswaertsIndex else { continue }

                // Ein Selbstduell hat weder einen echten Gegner noch ein
                // sinnvolles Heimrecht. Es wird nur als solches vermerkt und
                // bewusst nicht in die Gegner- und Heim/Auswaerts-Zaehler
                // gerechnet, damit ein Verstoss nicht die Zahlen aller anderen
                // Meldungen verfaelscht.
                if h == a {
                    selbstduell[h] = true
                    continue
                }

                paare[min(h, a)][max(h, a)] += 1
                heim[h][topfNummern[a]] += 1
                auswaerts[a][topfNummern[h]] += 1
            }

            self.pairCount = paare
            self.homePerPot = heim
            self.awayPerPot = auswaerts
            self.playsItself = selbstduell
            self.unknownIDs = unbekannte

            // Verschiedene Gegner je Topf und je Verband. Gezaehlt werden
            // Gegner, nicht Begegnungen: Eine doppelt eingetragene Paarung ist
            // ein eigener Verstoss und soll die Gegnerzahl nicht zusaetzlich
            // verzerren.
            var gegnerTopf = [[Int]](repeating: [Int](repeating: 0, count: topfAnzahl), count: anzahl)
            var gegnerVerband = [[Int]](repeating: [Int](repeating: 0, count: eindeutigeVerbaende.count), count: anzahl)
            for i in 0 ..< anzahl {
                for j in 0 ..< anzahl where j != i {
                    guard paare[min(i, j)][max(i, j)] > 0 else { continue }
                    gegnerTopf[i][topfNummern[j]] += 1
                    gegnerVerband[i][verbandsNummern[j]] += 1
                }
            }
            self.opponentsPerPot = gegnerTopf
            self.opponentsPerAssociation = gegnerVerband
        }
    }
}
