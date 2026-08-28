/// Vorpruefung der Eingabedaten einer Auslosung.
///
/// `InputValidation` prueft ausschliesslich **notwendige** Bedingungen: Wenn eine
/// von ihnen verletzt ist, kann es garantiert keine gueltige Auslosung geben.
/// Der Umkehrschluss gilt nicht - eine Eingabe, die hier durchkommt, kann in
/// der Suche immer noch als `unsolvable` enden. Die Pruefung ist damit ein
/// schneller Filter vor der teuren Suche, kein Loesbarkeits-Beweis.
///
/// Determinismus: Alle Pruefungen laufen ueber Arrays in fester Reihenfolge
/// oder ueber explizit sortierte Schluessel. Es wird nie ueber ein `Set` oder
/// ein `Dictionary` iteriert, weil Swift den Hash-Seed pro Prozesslauf
/// randomisiert und der gemeldete Fehler sonst zwischen Laeufen springen
/// koennte.
internal enum InputValidation {

    // MARK: - Konstanten der Fachregeln

    /// Anzahl der Teams einer Auslosung.
    internal static let expectedTeamCount: Int = 36

    /// Anzahl der Teams je Topf.
    internal static let expectedPotSize: Int = 9

    /// Die vier Toepfe in aufsteigender, fester Reihenfolge (pot1 ... pot4).
    ///
    /// Bewusst explizit sortiert statt auf die Deklarationsreihenfolge von
    /// `Pot.allCases` zu vertrauen. Index `i` dieses Arrays entspricht dem
    /// Index `i` in allen `countsPerPot`-Arrays dieses Typs.
    internal static let potsInOrder: [Pot] = Pot.allCases.sorted()

    // MARK: - Gesamtpruefung

    /// Prueft eine Teamliste auf alle notwendigen Bedingungen.
    ///
    /// Die Reihenfolge der Pruefungen ist Teil des Vertrags, damit der gemeldete
    /// Fehler bei mehreren gleichzeitigen Maengeln vorhersagbar bleibt:
    /// 1. Teamanzahl, 2. doppelte TeamIDs, 3. Topfgroessen,
    /// 4. Verbands-Verteilung (Associations aufsteigend nach `rawValue`).
    ///
    /// - Parameter teams: Die zu pruefende Teamliste in beliebiger Reihenfolge.
    /// - Throws: Den ersten verletzten Fehlerfall als `DrawError`.
    internal static func validate(teams: [Team]) throws(DrawError) -> Void {
        try checkTeamCount(teams)
        try checkDuplicateIDs(teams)
        try checkPotSizes(teams)
        try checkAssociationFeasibility(teams)
    }

    // MARK: - Einzelpruefungen

    /// Schritt 1: Es muessen genau 36 Teams sein.
    ///
    /// - Throws: `.wrongTeamCount(actual:)` mit der tatsaechlichen Anzahl.
    internal static func checkTeamCount(_ teams: [Team]) throws(DrawError) -> Void {
        guard teams.count == expectedTeamCount else {
            throw .wrongTeamCount(actual: teams.count)
        }
    }

    /// Schritt 2: Keine TeamID darf doppelt vorkommen.
    ///
    /// Geprueft wird ueber die aufsteigend sortierte ID-Liste und einen Vergleich
    /// benachbarter Eintraege. Damit ist die gemeldete ID immer die kleinste
    /// doppelte ID - im Gegensatz zu einer Pruefung ueber `Set`-Iteration, deren
    /// Ergebnis vom Hash-Seed des Prozesslaufs abhinge.
    ///
    /// - Throws: `.duplicateTeamID(_:)` mit der kleinsten doppelten TeamID.
    internal static func checkDuplicateIDs(_ teams: [Team]) throws(DrawError) -> Void {
        let sortedIDs: [TeamID] = teams.map { $0.id }.sorted()
        guard sortedIDs.count > 1 else { return }
        for i in 1 ..< sortedIDs.count where sortedIDs[i] == sortedIDs[i - 1] {
            throw .duplicateTeamID(sortedIDs[i])
        }
    }

    /// Schritt 3: Jeder Topf muss genau neun Teams enthalten.
    ///
    /// Die Toepfe werden in der festen Reihenfolge pot1 ... pot4 geprueft, damit
    /// bei mehreren falschen Topfgroessen immer der kleinste Topf gemeldet wird.
    ///
    /// - Throws: `.wrongPotSize(pot:actual:)` fuer den ersten abweichenden Topf.
    internal static func checkPotSizes(_ teams: [Team]) throws(DrawError) -> Void {
        let counts: [Int] = potCounts(of: teams)
        for (i, pot) in potsInOrder.enumerated() where counts[i] != expectedPotSize {
            throw .wrongPotSize(pot: pot, actual: counts[i])
        }
    }

    /// Schritt 4: Notwendige Bedingungen fuer jede Association.
    ///
    /// Die Associations werden aufsteigend nach `rawValue` durchlaufen, damit bei
    /// mehreren problematischen Verbaenden immer derselbe gemeldet wird. Pro
    /// Association werden die drei Schranken in fester Reihenfolge geprueft:
    /// Gesamtanzahl, Anzahl je Topf, Anzahl je Topfpaar.
    ///
    /// - Throws: `.infeasibleAssociationDistribution(association:reason:)`.
    internal static func checkAssociationFeasibility(_ teams: [Team]) throws(DrawError) -> Void {
        let associations: [Association] = sortedAssociations(of: teams)
        for association in associations {
            let counts: [Int] = potCounts(of: association, in: teams)
            try checkAssociationTotal(association: association, countsPerPot: counts)
            try checkPotShares(association: association, countsPerPot: counts)
            try checkPotPairs(association: association, countsPerPot: counts)
        }
    }

    // MARK: - Die drei Verbands-Schranken

    /// Schranke A: Hoechstens sieben Teams je Association insgesamt.
    ///
    /// Herleitung: Die `m` Teams der Association brauchen zusammen `8 * m`
    /// Gegner-Plaetze. Besetzen koennen diese nur die `36 - m` Teams anderer
    /// Verbaende (Duelle im eigenen Verband sind verboten), und jedes dieser
    /// Teams darf hoechstens zwei Gegner aus der Association haben, liefert also
    /// hoechstens zwei Plaetze:
    ///
    ///     8 * m <= 2 * (36 - m)   =>   10 * m <= 72   =>   m <= 7,2   =>   m <= 7
    ///
    /// - Parameters:
    ///   - association: Der gepruefte Verband, nur fuer die Fehlermeldung.
    ///   - countsPerPot: Vier Zaehler, Index `i` gehoert zu `potsInOrder[i]`.
    /// - Throws: `.tooManyTeamsTotal(count:)` als Grund, wenn `m > 7`.
    internal static func checkAssociationTotal(
        association: Association,
        countsPerPot: [Int]
    ) throws(DrawError) -> Void {
        precondition(countsPerPot.count == potsInOrder.count, "countsPerPot braucht genau vier Eintraege")
        var total = 0
        for count in countsPerPot { total += count }
        guard total <= 7 else {
            throw .infeasibleAssociationDistribution(
                association: association,
                reason: .tooManyTeamsTotal(count: total)
            )
        }
    }

    /// Schranke B: Hoechstens vier Teams einer Association je Topf.
    ///
    /// Herleitung: Ein Topf hat neun Teams. Jedes der `k` Teams der Association
    /// in diesem Topf braucht genau zwei Gegner aus genau diesem Topf, also
    /// `2 * k` Plaetze. Liefern koennen diese nur die `9 - k` uebrigen Teams des
    /// Topfes, jedes mit hoechstens zwei Gegnern aus der Association:
    ///
    ///     2 * k <= 2 * (9 - k)   =>   2 * k <= 9   =>   k <= 4,5   =>   k <= 4
    ///
    /// Die Toepfe werden in fester Reihenfolge geprueft, damit der Fehler
    /// deterministisch ist.
    ///
    /// - Throws: `.tooManyTeamsInPot(pot:count:)` als Grund, wenn `k > 4`.
    internal static func checkPotShares(
        association: Association,
        countsPerPot: [Int]
    ) throws(DrawError) -> Void {
        precondition(countsPerPot.count == potsInOrder.count, "countsPerPot braucht genau vier Eintraege")
        for (i, pot) in potsInOrder.enumerated() where countsPerPot[i] > 4 {
            throw .infeasibleAssociationDistribution(
                association: association,
                reason: .tooManyTeamsInPot(pot: pot, count: countsPerPot[i])
            )
        }
    }

    /// Schranke C: Zwei Toepfe zusammen tragen hoechstens neun Teams einer Association.
    ///
    /// Herleitung: Seien `a` Teams der Association in Topf A und `b` Teams in
    /// Topf B (A ungleich B). Die `a` Teams brauchen je zwei Gegner aus Topf B,
    /// zusammen also `2 * a` Plaetze. Zulaessig sind dafuer nur die `9 - b`
    /// Teams aus Topf B, die nicht zur Association gehoeren, jedes mit
    /// hoechstens zwei Gegnern aus der Association:
    ///
    ///     2 * a <= 2 * (9 - b)   =>   a + b <= 9
    ///
    /// Geprueft werden alle Topfpaare `(i, j)` mit `i < j` in fester Reihenfolge.
    /// Da die Bedingung in `a` und `b` symmetrisch ist, genuegt eine Richtung.
    ///
    /// Hinweis: Nach Schranke A gilt bereits `a + b <= m <= 7`, nach Schranke B
    /// gilt `a <= 4` und `b <= 4`, also `a + b <= 8`. Diese Schranke kann im
    /// Ablauf von `validate(teams:)` daher nie als erste zuschlagen. Sie bleibt
    /// trotzdem als eigenstaendige, einzeln testbare Bedingung erhalten: Sie ist
    /// die Schranke, die aus der Topfpaar-Sicht folgt, und sie schuetzt den Code
    /// gegen spaetere Aenderungen an den anderen beiden Schranken.
    ///
    /// - Throws: `.potPairOverflow(potA:potB:total:)` als Grund, wenn `a + b > 9`.
    internal static func checkPotPairs(
        association: Association,
        countsPerPot: [Int]
    ) throws(DrawError) -> Void {
        precondition(countsPerPot.count == potsInOrder.count, "countsPerPot braucht genau vier Eintraege")
        for i in 0 ..< potsInOrder.count {
            for j in (i + 1) ..< potsInOrder.count {
                let total = countsPerPot[i] + countsPerPot[j]
                guard total <= 9 else {
                    throw .infeasibleAssociationDistribution(
                        association: association,
                        reason: .potPairOverflow(
                            potA: potsInOrder[i],
                            potB: potsInOrder[j],
                            total: total
                        )
                    )
                }
            }
        }
    }

    // MARK: - Hilfsfunktionen (deterministisch, ohne Set-/Dictionary-Iteration)

    /// Zaehlt die Teams je Topf. Index `i` gehoert zu `potsInOrder[i]`.
    internal static func potCounts(of teams: [Team]) -> [Int] {
        var counts = [Int](repeating: 0, count: potsInOrder.count)
        for team in teams {
            counts[team.pot.rawValue - 1] += 1
        }
        return counts
    }

    /// Zaehlt die Teams einer bestimmten Association je Topf.
    /// Index `i` gehoert zu `potsInOrder[i]`.
    internal static func potCounts(of association: Association, in teams: [Team]) -> [Int] {
        var counts = [Int](repeating: 0, count: potsInOrder.count)
        for team in teams where team.association == association {
            counts[team.pot.rawValue - 1] += 1
        }
        return counts
    }

    /// Liefert alle vorkommenden Associations aufsteigend sortiert und ohne
    /// Duplikate.
    ///
    /// Bewusst ueber "sortieren und benachbarte Duplikate ueberspringen" statt
    /// ueber ein `Set`: Ein `Set` haette keine stabile Reihenfolge, und die
    /// Reihenfolge bestimmt hier, welcher Fehler zuerst gemeldet wird.
    internal static func sortedAssociations(of teams: [Team]) -> [Association] {
        let alle: [Association] = teams.map { $0.association }.sorted()
        var eindeutige: [Association] = []
        eindeutige.reserveCapacity(alle.count)
        for association in alle where eindeutige.last != association {
            eindeutige.append(association)
        }
        return eindeutige
    }
}
