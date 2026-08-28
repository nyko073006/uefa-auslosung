/// Fehler, die bei der Vorpruefung oder waehrend der Auslosung auftreten koennen.
public enum DrawError: Error, Hashable, Sendable {
    /// Es wurden nicht genau 36 Teams uebergeben.
    case wrongTeamCount(actual: Int)
    /// Ein Topf enthaelt nicht genau neun Teams.
    case wrongPotSize(pot: Pot, actual: Int)
    /// Zwei Teams teilen sich dieselbe TeamID.
    case duplicateTeamID(TeamID)
    /// Die Verteilung einer Association macht eine gueltige Auslosung
    /// rechnerisch unmoeglich; `reason` nennt die verletzte Schranke.
    case infeasibleAssociationDistribution(association: Association, reason: InfeasibilityReason)
    /// Die Eingabe ist formal gueltig, es existiert aber keine Loesung.
    case unsolvable
    /// Die Suche wurde abgebrochen, weil das Knotenbudget aufgebraucht war.
    case searchBudgetExceeded(exploredNodes: Int)
}

/// Begruendung, warum die Verteilung einer Association nicht loesbar ist.
///
/// Alle Schranken folgen aus den Fachregeln: 36 Teams, vier Toepfe mit je neun
/// Teams, acht Gegner pro Team (genau zwei aus jedem Topf), kein Duell gegen
/// die eigene Association und hoechstens zwei Gegner aus derselben Association.
public enum InfeasibilityReason: Hashable, Sendable {
    /// Mehr als sieben Teams einer Association insgesamt.
    ///
    /// Herleitung: Die `m` Teams der Association brauchen zusammen `8 * m`
    /// Gegner-Plaetze, die ausschliesslich von den `36 - m` uebrigen Teams
    /// gedeckt werden koennen. Jedes dieser Teams darf hoechstens zwei Gegner
    /// aus der Association haben, liefert also hoechstens zwei Plaetze:
    /// `8 * m <= 2 * (36 - m)`  =>  `10 * m <= 72`  =>  `m <= 7`.
    case tooManyTeamsTotal(count: Int)

    /// Mehr als vier Teams einer Association in einem Topf.
    ///
    /// Herleitung: Ein Topf hat neun Teams. Jedes der `k` Teams der Association
    /// in diesem Topf braucht zwei Gegner aus genau diesem Topf, also `2 * k`
    /// Plaetze. Decken koennen sie nur die `9 - k` uebrigen Teams des Topfes,
    /// jedes mit hoechstens zwei Gegnern aus der Association:
    /// `2 * k <= 2 * (9 - k)`  =>  `k <= 4.5`  =>  `k <= 4`.
    case tooManyTeamsInPot(pot: Pot, count: Int)

    /// Zwei Toepfe zusammen tragen mehr als neun Teams einer Association.
    ///
    /// Herleitung: Mit `a` Teams der Association in Topf A und `b` Teams in
    /// Topf B (A ungleich B) brauchen die `a` Teams je zwei Gegner aus Topf B,
    /// also `2 * a` Plaetze. Zulaessig sind dafuer nur die `9 - b` Teams aus
    /// Topf B, die nicht zur Association gehoeren, jedes mit hoechstens zwei
    /// Gegnern aus der Association:
    /// `2 * a <= 2 * (9 - b)`  =>  `a + b <= 9`.
    case potPairOverflow(potA: Pot, potB: Pot, total: Int)
}
