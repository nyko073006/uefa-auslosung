/// Eine gerichtete Paarung: `home` empfaengt `away`.
///
/// Die Richtung ist bedeutungstragend. Die fachliche Symmetrie der Auslosung
/// ("A gegen B" heisst auch "B gegen A") wird nicht durch zwei Matchups
/// abgebildet, sondern durch genau ein Matchup pro Begegnung, dessen Richtung
/// das Heimrecht festlegt. Bei 36 Teams mit je acht Gegnern ergeben sich damit
/// 144 Matchups, davon vier Heimspiele und vier Auswaertsspiele pro Team.
public struct Matchup: Hashable, Sendable, Codable {
    /// Team mit Heimrecht.
    public let home: TeamID
    /// Team, das auswaerts antritt.
    public let away: TeamID

    /// Erzeugt eine gerichtete Paarung.
    public init(home: TeamID, away: TeamID) {
        self.home = home
        self.away = away
    }
}
