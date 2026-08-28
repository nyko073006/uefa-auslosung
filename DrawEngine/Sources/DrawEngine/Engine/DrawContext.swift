/// Stabile Index-Repraesentation der Teilnehmer einer Auslosung.
///
/// Der eigentliche Auslosungs-Algorithmus arbeitet nicht mit `Team`-Werten,
/// sondern mit `Int`-Indizes `0 ..< 36`. Der `DrawContext` stellt genau diese
/// Abbildung her und ist damit die Grundlage des Determinismus: Alle spaeteren
/// Schleifen laufen ueber Index-Bereiche in fester Reihenfolge, nie ueber
/// `Set` oder `Dictionary`.
///
/// ## Invariante der kanonischen Sortierung
/// `teams` ist aufsteigend sortiert nach `(pot.rawValue, id.rawValue)`. Weil
/// jeder Topf genau neun Teams enthaelt, gilt daraus folgend:
///
/// - Topf 1 belegt die Indizes `0 ..< 9`
/// - Topf 2 belegt die Indizes `9 ..< 18`
/// - Topf 3 belegt die Indizes `18 ..< 27`
/// - Topf 4 belegt die Indizes `27 ..< 36`
///
/// Allgemein belegt Topf `p` (1-basiert) die Indizes `9 * (p - 1) ..< 9 * p`.
/// Die Sortierung ist eine echte Totalordnung, weil TeamIDs nach der
/// Validierung eindeutig sind. Deshalb liefert dieselbe Teammenge in beliebiger
/// Eingabereihenfolge immer denselben Context.
///
/// ## Bewusst kein Suchzustand
/// Der Context ist unveraenderlich und enthaelt ausschliesslich die
/// Index-Abbildung. Zaehler, Bitmasken und alles andere, was sich waehrend der
/// Suche aendert, gehoert in den Matcher, nicht hierher.
internal struct DrawContext: Sendable {

    // MARK: - Gespeicherte Daten

    /// Alle Teams, kanonisch sortiert nach `(pot.rawValue, id.rawValue)`.
    internal let teams: [Team]

    /// Alle vorkommenden Associations, aufsteigend nach `rawValue` sortiert und
    /// ohne Duplikate. Der Index in dieses Array ist die Verbandsnummer.
    internal let associations: [Association]

    /// Verbandsnummer je Team-Index (36 Eintraege).
    ///
    /// `associationIndex[i]` ist der Index in `associations` fuer `teams[i]`.
    /// Zwei Teams gehoeren genau dann zum selben Verband, wenn ihre Eintraege
    /// hier uebereinstimmen - ein Int-Vergleich statt eines String-Vergleichs.
    internal let associationIndex: [Int]

    /// Nullbasierte Topfnummer je Team-Index (36 Eintraege).
    ///
    /// `potIndex[i]` ist `teams[i].pot.rawValue - 1`, also ein Wert aus `0 ... 3`.
    /// Praktisch als direkter Array-Index fuer topfbezogene Zaehler im Matcher.
    internal let potIndex: [Int]

    /// Startindex jedes Topfes plus ein abschliessender Endindex (5 Eintraege).
    ///
    /// `potStart[p] ..< potStart[p + 1]` ist der Index-Bereich von Topf `p + 1`.
    /// Bei gueltiger Eingabe ist das `[0, 9, 18, 27, 36]`.
    private let potStart: [Int]

    /// Nachschlagetabelle TeamID -> Index.
    ///
    /// Wird ausschliesslich fuer Einzelabfragen benutzt und nie iteriert, damit
    /// die zufaellige Hash-Reihenfolge nirgends in eine Entscheidung einfliesst.
    private let indexByTeamID: [TeamID: Int]

    // MARK: - Abgeleitete Groessen

    /// Anzahl der Teams (bei gueltiger Eingabe 36).
    internal var teamCount: Int { teams.count }

    /// Anzahl der verschiedenen Associations.
    internal var associationCount: Int { associations.count }

    // MARK: - Aufbau

    /// Baut den Context aus einer bereits validierten Teamliste.
    ///
    /// Die Eingabereihenfolge ist egal, sie wird kanonisch sortiert. Die Liste
    /// muss `InputValidation.validate(teams:)` bestanden haben; hier wird nur
    /// noch die Teamanzahl als `precondition` abgesichert, weil ein falsch
    /// dimensionierter Context ein Programmierfehler waere und kein Fehlerfall
    /// der Fachlogik.
    ///
    /// - Parameter teams: Genau 36 Teams mit eindeutigen IDs.
    internal init(teams eingabe: [Team]) {
        precondition(
            eingabe.count == InputValidation.expectedTeamCount,
            "DrawContext erwartet genau \(InputValidation.expectedTeamCount) validierte Teams"
        )

        // Kanonische Totalordnung: erst Topf, dann TeamID. Da die IDs eindeutig
        // sind, ist das Ergebnis eindeutig und unabhaengig von der Eingabe-
        // reihenfolge und vom verwendeten Sortierverfahren.
        let sortierteTeams: [Team] = eingabe.sorted { lhs, rhs in
            if lhs.pot != rhs.pot { return lhs.pot < rhs.pot }
            return lhs.id < rhs.id
        }
        self.teams = sortierteTeams

        // Verbandsliste: sortieren und benachbarte Duplikate ueberspringen.
        // Bewusst kein Set, damit die Nummerierung reproduzierbar bleibt.
        let sortierteVerbaende: [Association] = InputValidation.sortedAssociations(of: sortierteTeams)
        self.associations = sortierteVerbaende

        // Nachschlagetabelle Verband -> Nummer. Nur fuer den Aufbau, wird nicht
        // gespeichert und nie iteriert.
        var nummerJeVerband: [Association: Int] = [:]
        nummerJeVerband.reserveCapacity(sortierteVerbaende.count)
        for (nummer, verband) in sortierteVerbaende.enumerated() {
            nummerJeVerband[verband] = nummer
        }

        var verbandsIndizes = [Int](repeating: 0, count: sortierteTeams.count)
        var topfIndizes = [Int](repeating: 0, count: sortierteTeams.count)
        var idZuIndex: [TeamID: Int] = [:]
        idZuIndex.reserveCapacity(sortierteTeams.count)

        for (index, team) in sortierteTeams.enumerated() {
            // Der Verband stammt aus derselben Liste, aus der die Tabelle
            // aufgebaut wurde; ein fehlender Eintrag waere ein Programmierfehler.
            guard let nummer = nummerJeVerband[team.association] else {
                preconditionFailure("Verband \(team.association.rawValue) fehlt in der Verbandsliste")
            }
            verbandsIndizes[index] = nummer
            topfIndizes[index] = team.pot.rawValue - 1
            idZuIndex[team.id] = index
        }

        self.associationIndex = verbandsIndizes
        self.potIndex = topfIndizes
        self.indexByTeamID = idZuIndex

        // Topfgrenzen als Praefixsummen der tatsaechlichen Topfgroessen. Bei
        // validierter Eingabe ergibt das [0, 9, 18, 27, 36].
        let topfGroessen: [Int] = InputValidation.potCounts(of: sortierteTeams)
        var grenzen = [Int](repeating: 0, count: topfGroessen.count + 1)
        for p in 0 ..< topfGroessen.count {
            grenzen[p + 1] = grenzen[p] + topfGroessen[p]
        }
        self.potStart = grenzen
    }

    // MARK: - Abbildung Index -> Team

    /// Die TeamID des Teams an diesem Index.
    internal func teamID(_ index: Int) -> TeamID {
        teams[index].id
    }

    /// Der Topf des Teams an diesem Index.
    internal func potOfTeam(_ index: Int) -> Pot {
        InputValidation.potsInOrder[potIndex[index]]
    }

    /// Die Association des Teams an diesem Index.
    internal func association(ofTeam index: Int) -> Association {
        associations[associationIndex[index]]
    }

    // MARK: - Abbildung Team -> Index

    /// Der Index dieser TeamID, oder `nil`, wenn sie nicht teilnimmt.
    ///
    /// Einzelabfrage in der Nachschlagetabelle; es wird nichts iteriert.
    internal func index(of id: TeamID) -> Int? {
        indexByTeamID[id]
    }

    // MARK: - Topf-Bereiche

    /// Der zusammenhaengende Index-Bereich aller Teams dieses Topfes.
    ///
    /// Ergibt sich direkt aus der kanonischen Sortierung: `0 ..< 9` fuer Topf 1,
    /// `9 ..< 18` fuer Topf 2, `18 ..< 27` fuer Topf 3, `27 ..< 36` fuer Topf 4.
    internal func teamIndices(inPot pot: Pot) -> Range<Int> {
        let p = pot.rawValue - 1
        return potStart[p] ..< potStart[p + 1]
    }

    /// Prueft, ob zwei Team-Indizes zum selben Verband gehoeren.
    ///
    /// Bequemlichkeit fuer den Matcher: Teams derselben Association duerfen
    /// nicht gegeneinander spielen.
    internal func sameAssociation(_ lhs: Int, _ rhs: Int) -> Bool {
        associationIndex[lhs] == associationIndex[rhs]
    }
}
