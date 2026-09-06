/// Leitet aus dem fertigen Auslosungsergebnis die Reveal-Sequenz ab, mit der
/// eine Oberflaeche die Ziehung Schritt fuer Schritt nachspielen kann.
///
/// ## Aufgabe
/// Hier faellt keine Fachentscheidung mehr. Die Paarungen stehen nach Phase A
/// fest, das Heimrecht nach Phase B. Phase C bringt dieses fertige Ergebnis nur
/// noch in die Reihenfolge, in der es praesentiert wird: erst der Topf, dann das
/// gezogene Team, dann dessen noch nicht enthuellte Paarungen.
///
/// ## Ablauf
/// 1. `.drawStarted(seed:)`
/// 2. Je Topf `pot1 ... pot4` in dieser festen Reihenfolge:
///    `.potStarted`, die neun Teams des Topfes in gemischter Ziehreihenfolge,
///    je Team `.teamDrawn` und danach seine Reveals, zum Schluss `.potCompleted`.
/// 3. `.drawCompleted`
///
/// ## Eine Paarung wird genau einmal enthuellt
/// Jede Begegnung hat zwei Beteiligte, aber nur einen Auftritt: Sie wird bei dem
/// der beiden Teams gezeigt, das **zuerst** gezogen wird. Beim zweiten Team ist
/// sie schon bekannt und wird uebersprungen. Genau deshalb enthuellen die frueh
/// gezogenen Teams viele Paarungen und die spaeten kaum noch eine - und genau
/// deshalb summieren sich die Reveals ueber alle 36 Bloecke auf 144 statt auf
/// `36 * 8 = 288`. Gemerkt wird das in einer Bitmatrix ueber Team-Indizes; es
/// wird nirgends ueber ein `Set` oder ein `Dictionary` iteriert.
///
/// ## Die Reveal-Unterordnung ist bewusst fest, nicht zufaellig
/// Innerhalb eines gezogenen Teams braucht es eine Regel, in welcher Reihenfolge
/// dessen Paarungen erscheinen - ohne sie waere die Sequenz unterspezifiziert und
/// damit nicht reproduzierbar. Festgelegt ist:
///
/// - **Gegner-Topf aufsteigend**, also erst die Gegner aus Topf 1, zuletzt die
///   aus Topf 4.
/// - **Innerhalb eines Gegner-Topfes zuerst das Heimspiel**, dann das
///   Auswaertsspiel des gezogenen Teams.
///
/// Das ist eindeutig, weil jedes Team je Gegner-Topf genau zwei Gegner hat, davon
/// genau einen zu Hause. Die Alternative - auch diese Reihenfolge auszuwuerfeln -
/// waere zusaetzlicher Zufall ohne fachlichen Gewinn und wuerde den
/// RNG-Verbrauch von der Ziehreihenfolge abhaengig machen.
///
/// ## Zufall
/// Der Generator wird ausschliesslich fuer die Ziehreihenfolge der Teams je Topf
/// benutzt: vier Mischungen von je neun Indizes mit dem projekteigenen
/// Fisher-Yates. Alles andere ist fest verdrahtet.
internal enum EventSequencer {

    // MARK: - Einstieg

    /// Baut die vollstaendige Ereignisliste einer Auslosung.
    ///
    /// - Parameters:
    ///   - directedEdges: Die 144 gerichteten Begegnungen aus Phase B. Die
    ///     Reihenfolge ist egal, das Ergebnis haengt nicht von ihr ab.
    ///   - context: Die Index-Repraesentation der Teilnehmer, gebraucht fuer
    ///     TeamIDs, Toepfe und die Teams je Topf.
    ///   - seed: Startwert der Auslosung. Er wird hier nur in das
    ///     `.drawStarted`-Ereignis geschrieben und **nicht** verwendet, um einen
    ///     Generator zu erzeugen - gemischt wird mit `rng`.
    ///   - rng: Generator fuer die Ziehreihenfolge je Topf. Sein Zustand
    ///     schreitet fort; ueblicherweise ist es derselbe Generator, der schon
    ///     durch Phase A und B gelaufen ist.
    /// - Returns: Die Ereignisse in Auftrittsreihenfolge.
    internal static func events(
        directedEdges: [HomeAwayOrienter.DirectedEdge],
        context: DrawContext,
        seed: UInt64,
        rng: inout SplitMix64
    ) -> [DrawEvent] {
        precondition(
            context.teamCount <= UInt64.bitWidth,
            "Die Enthuellungs-Bitmatrix fasst hoechstens \(UInt64.bitWidth) Teams"
        )

        let gegnerJeTeam = opponentTable(directedEdges: directedEdges, context: context)
        checkOpponentTable(gegnerJeTeam, context: context)

        var ereignisse: [DrawEvent] = []
        ereignisse.reserveCapacity(expectedEventCount(context: context, matchCount: directedEdges.count))
        ereignisse.append(.drawStarted(seed: seed))

        // Bit `k` in `enthuellt[t]` heisst: Die Paarung `t` gegen `k` ist bereits
        // gezeigt worden. Die Matrix wird symmetrisch gepflegt, damit die Abfrage
        // von beiden Seiten aus dasselbe ergibt.
        var enthuellt = [UInt64](repeating: 0, count: context.teamCount)
        var anzahlEnthuellt = 0

        for topf in InputValidation.potsInOrder {
            ereignisse.append(.potStarted(topf))

            // Der einzige Zufall dieser Phase. Die Indizes des Topfes liegen dank
            // der kanonischen Sortierung des Contexts zusammenhaengend und
            // aufsteigend vor, die Mischung startet also von einer festen Basis.
            var ziehreihenfolge = Array(context.teamIndices(inPot: topf))
            ziehreihenfolge.deterministicShuffle(using: &rng)

            for team in ziehreihenfolge {
                ereignisse.append(.teamDrawn(team: context.teamID(team), pot: topf))

                // Die Liste ist bereits nach Gegner-Topf und Heimrecht sortiert;
                // hier wird nur noch uebersprungen, was schon zu sehen war.
                for eintrag in gegnerJeTeam[team] {
                    let maske = UInt64(1) << UInt64(eintrag.opponent)
                    if enthuellt[team] & maske != 0 { continue }

                    enthuellt[team] |= maske
                    enthuellt[eintrag.opponent] |= UInt64(1) << UInt64(team)
                    anzahlEnthuellt += 1

                    ereignisse.append(
                        .matchRevealed(
                            drawnTeam: context.teamID(team),
                            opponent: context.teamID(eintrag.opponent),
                            opponentPot: eintrag.opponentPot,
                            drawnTeamPlaysHome: eintrag.drawnTeamPlaysHome
                        )
                    )
                }
            }

            ereignisse.append(.potCompleted(topf))
        }

        ereignisse.append(.drawCompleted)

        // Jede Begegnung genau einmal: Weniger hiesse, dass eine Paarung nie
        // gezeigt wurde, mehr ist durch die Bitmatrix ausgeschlossen. Ein
        // Fehlschlag deutet auf eine doppelte Kante in der Eingabe hin.
        precondition(
            anzahlEnthuellt == directedEdges.count,
            "\(anzahlEnthuellt) enthuellte Paarungen bei \(directedEdges.count) Begegnungen"
        )
        return ereignisse
    }

    /// Erwartete Laenge der Ereignisliste.
    ///
    /// Sie ist vollstaendig vorhersagbar: `.drawStarted` und `.drawCompleted`
    /// einmal, je Topf ein `.potStarted` und ein `.potCompleted`, je Team ein
    /// `.teamDrawn` und je Begegnung ein `.matchRevealed`. Bei 36 Teams und 144
    /// Begegnungen sind das `1 + 8 + 36 + 144 + 1 = 190` Ereignisse.
    internal static func expectedEventCount(context: DrawContext, matchCount: Int) -> Int {
        1 + 2 * InputValidation.potsInOrder.count + context.teamCount + matchCount + 1
    }

    // MARK: - Gegnertabelle

    /// Ein Gegner eines Teams mit allem, was das Reveal-Ereignis braucht.
    ///
    /// Bewusst aus Sicht des **gezogenen** Teams formuliert: `drawnTeamPlaysHome`
    /// gilt fuer das Team, dem diese Zeile gehoert, nicht fuer den Gegner. Die
    /// Kante `home -> away` erzeugt deshalb zwei Eintraege mit umgekehrtem Flag.
    private struct OpponentEntry {

        /// Team-Index des Gegners.
        let opponent: Int

        /// Topf des Gegners.
        let opponentPot: Pot

        /// Wahr, wenn das gezogene Team in dieser Paarung Heimrecht hat.
        let drawnTeamPlaysHome: Bool
    }

    /// Baut je Team die Liste seiner acht Gegner in Reveal-Reihenfolge.
    ///
    /// Sortiert wird nach `(Gegner-Topf aufsteigend, Heimspiel zuerst,
    /// Gegner-Index aufsteigend)`. Die ersten beiden Kriterien sind die fachliche
    /// Festlegung, das dritte macht die Ordnung formal total - es greift bei
    /// gueltiger Eingabe nie, weil je Gegner-Topf genau ein Heim- und ein
    /// Auswaertsspiel steht.
    private static func opponentTable(
        directedEdges: [HomeAwayOrienter.DirectedEdge],
        context: DrawContext
    ) -> [[OpponentEntry]] {
        var tabelle = [[OpponentEntry]](repeating: [], count: context.teamCount)

        for kante in directedEdges {
            tabelle[kante.home].append(
                OpponentEntry(
                    opponent: kante.away,
                    opponentPot: context.potOfTeam(kante.away),
                    drawnTeamPlaysHome: true
                )
            )
            tabelle[kante.away].append(
                OpponentEntry(
                    opponent: kante.home,
                    opponentPot: context.potOfTeam(kante.home),
                    drawnTeamPlaysHome: false
                )
            )
        }

        for team in 0 ..< context.teamCount {
            tabelle[team].sort { lhs, rhs in
                if lhs.opponentPot != rhs.opponentPot { return lhs.opponentPot < rhs.opponentPot }
                // `true` vor `false`: das Heimspiel des gezogenen Teams zuerst.
                if lhs.drawnTeamPlaysHome != rhs.drawnTeamPlaysHome { return lhs.drawnTeamPlaysHome }
                return lhs.opponent < rhs.opponent
            }
        }
        return tabelle
    }

    // MARK: - Zusicherungen

    /// Prueft, dass die Gegnertabelle die Fachregeln der Phasen A und B abbildet.
    ///
    /// Alle drei Punkte sind hier Vorbedingungen, keine Ergebnisse: Phase A
    /// garantiert zwei Gegner je Topf, Phase B genau ein Heimspiel davon. Die
    /// Pruefung kostet einen Durchlauf ueber 36 mal 8 Eintraege und faengt einen
    /// Fehler dort ab, wo er noch erklaerbar ist - statt spaeter als
    /// unvollstaendige Reveal-Sequenz.
    private static func checkOpponentTable(_ table: [[OpponentEntry]], context: DrawContext) {
        let anzahlToepfe = InputValidation.potsInOrder.count
        let gegnerJeTopf = OpponentMatcher.opponentsPerPot

        for team in 0 ..< context.teamCount {
            precondition(
                table[team].count == anzahlToepfe * gegnerJeTopf,
                "Team \(team) hat \(table[team].count) Gegner statt \(anzahlToepfe * gegnerJeTopf)"
            )

            var gegnerProTopf = [Int](repeating: 0, count: anzahlToepfe)
            var heimspieleProTopf = [Int](repeating: 0, count: anzahlToepfe)
            for eintrag in table[team] {
                let topf = eintrag.opponentPot.rawValue - 1
                gegnerProTopf[topf] += 1
                if eintrag.drawnTeamPlaysHome { heimspieleProTopf[topf] += 1 }
            }

            for topf in 0 ..< anzahlToepfe {
                precondition(
                    gegnerProTopf[topf] == gegnerJeTopf,
                    "Team \(team) hat \(gegnerProTopf[topf]) Gegner aus Topf \(topf + 1) statt \(gegnerJeTopf)"
                )
                precondition(
                    heimspieleProTopf[topf] == 1,
                    "Team \(team) hat \(heimspieleProTopf[topf]) Heimspiele gegen Topf \(topf + 1) statt 1"
                )
            }
        }
    }
}
