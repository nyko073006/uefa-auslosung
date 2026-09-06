/// Das vollstaendige Ergebnis einer Auslosung.
///
/// Der Wert ist rein datenhaltend und deterministisch: Aus demselben `seed` und
/// derselben Teamliste entsteht immer dasselbe Ergebnis. `teams` und `matches`
/// liegen in kanonischer Sortierung vor, damit zwei Laeufe byteweise
/// vergleichbar sind.
public struct DrawResult: Equatable, Sendable {
    /// Startwert des Zufallsgenerators, mit dem diese Auslosung erzeugt wurde.
    public let seed: UInt64
    /// Alle 36 Teams, kanonisch sortiert nach Topf aufsteigend, dann nach TeamID.
    public let teams: [Team]
    /// Alle 144 gerichteten Paarungen, kanonisch sortiert nach (home, away).
    public let matches: [Matchup]
    /// Der Ablauf der Auslosung in Auftrittsreihenfolge.
    public let events: [DrawEvent]

    /// Erzeugt ein Ergebnis. Die Sortierung von `teams` und `matches` liegt in
    /// der Verantwortung des erzeugenden Codes (Engine) und wird hier nicht
    /// nachtraeglich veraendert.
    public init(seed: UInt64, teams: [Team], matches: [Matchup], events: [DrawEvent]) {
        self.seed = seed
        self.teams = teams
        self.matches = matches
        self.events = events
    }

    /// Alle Paarungen, an denen das Team beteiligt ist (erwartet: acht Stueck).
    ///
    /// Die Reihenfolge entspricht der Reihenfolge in `matches` und ist damit
    /// deterministisch.
    public func matches(involving id: TeamID) -> [Matchup] {
        let allMatches: [Matchup] = self.matches
        return allMatches.filter { $0.home == id || $0.away == id }
    }

    /// Die beiden Gegner des Teams aus dem angegebenen Topf, aufsteigend sortiert.
    ///
    /// Intern wird ein Dictionary nur zum Nachschlagen des Topfes verwendet;
    /// iteriert wird ausschliesslich ueber die sortierten Arrays, damit die
    /// Ausgabe nicht von Hash-Seeds abhaengt.
    public func opponents(of id: TeamID, in pot: Pot) -> [TeamID] {
        var potByTeam: [TeamID: Pot] = [:]
        potByTeam.reserveCapacity(teams.count)
        for team in teams {
            potByTeam[team.id] = team.pot
        }

        var opponents: [TeamID] = []
        let allMatches: [Matchup] = self.matches
        for match in allMatches {
            let opponent: TeamID
            if match.home == id {
                opponent = match.away
            } else if match.away == id {
                opponent = match.home
            } else {
                continue
            }
            if potByTeam[opponent] == pot {
                opponents.append(opponent)
            }
        }
        return opponents.sorted()
    }

    /// Die Heimspiele des Teams (erwartet: vier Stueck), Reihenfolge wie in `matches`.
    public func homeMatches(of id: TeamID) -> [Matchup] {
        let allMatches: [Matchup] = self.matches
        return allMatches.filter { $0.home == id }
    }

    /// Die Auswaertsspiele des Teams (erwartet: vier Stueck), Reihenfolge wie in `matches`.
    public func awayMatches(of id: TeamID) -> [Matchup] {
        let allMatches: [Matchup] = self.matches
        return allMatches.filter { $0.away == id }
    }
}
