/// Ein einzelner Schritt im Ablauf der Auslosung.
///
/// Die Ereignisse werden in der Reihenfolge ihres Auftretens gesammelt und
/// erlauben es, die Auslosung spaeter Schritt fuer Schritt nachzuspielen
/// (z.B. fuer eine Animation in der Oberflaeche), ohne dass die Fachlogik
/// die Darstellung kennen muss.
public enum DrawEvent: Hashable, Sendable {
    /// Die Auslosung beginnt; `seed` ist der Startwert des Zufallsgenerators.
    case drawStarted(seed: UInt64)
    /// Die Ziehung fuer den angegebenen Topf beginnt.
    case potStarted(Pot)
    /// Ein Team wurde aus dem angegebenen Topf gezogen.
    case teamDrawn(team: TeamID, pot: Pot)
    /// Fuer das gezogene Team wurde ein Gegner aufgedeckt.
    ///
    /// `drawnTeamPlaysHome` gibt an, ob das gezogene Team in dieser Paarung
    /// Heimrecht hat; `opponentPot` ist der Topf des Gegners.
    case matchRevealed(drawnTeam: TeamID, opponent: TeamID, opponentPot: Pot, drawnTeamPlaysHome: Bool)
    /// Der angegebene Topf ist vollstaendig ausgelost.
    case potCompleted(Pot)
    /// Die Auslosung ist abgeschlossen.
    case drawCompleted
}
