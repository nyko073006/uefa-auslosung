// TeamSchedule.swift
//
// Anzeige-Ableitung aus einem `DrawRun`: der Spielplan eines Teams.
//
// Reine Umformung bereits feststehender Daten - Gruppieren, Sortieren, Zaehlen.
// Hier wird nichts entschieden und nichts bewertet.

import Foundation

/// Ein Gegner im Spielplan eines Teams, angereichert um die Anzeigedaten.
struct ScheduledOpponent: Identifiable, Hashable, Sendable {
    let id: UUID
    let team: Team
    let venue: Venue
    let fromPot: Int
}

/// Die acht Gegner eines Teams, nach Topf sortiert.
struct TeamSchedule: Identifiable, Hashable, Sendable {
    let team: Team
    let opponents: [ScheduledOpponent]

    var id: Team.ID { team.id }

    var homeCount: Int { opponents.filter { $0.venue == .home }.count }
    var awayCount: Int { opponents.filter { $0.venue == .away }.count }

    /// Gegner gruppiert nach Herkunftstopf, aufsteigend.
    var opponentsByPot: [(pot: Int, opponents: [ScheduledOpponent])] {
        Dictionary(grouping: opponents, by: \.fromPot)
            .sorted { $0.key < $1.key }
            .map { (pot: $0.key, opponents: $0.value) }
    }

    /// Verteilung der Gegner nach Verband. Eine Auszaehlung des Vorhandenen -
    /// bewusst ohne Urteil darueber, ob eine Anzahl zulaessig ist.
    var associationBreakdown: [(association: Association, count: Int)] {
        Dictionary(grouping: opponents, by: \.team.association)
            .map { (association: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                lhs.count == rhs.count
                    ? lhs.association.id < rhs.association.id
                    : lhs.count > rhs.count
            }
    }
}

extension DrawRun {

    /// Baut die Spielplaene aller Teams in Topf- und Namensreihenfolge.
    func schedules() -> [TeamSchedule] {
        let lookup = setup.teamsByID

        return setup.allTeams.map { team in
            let opponents = matchups(for: team.id).compactMap { matchup -> ScheduledOpponent? in
                guard let opponent = lookup[matchup.opponentID] else { return nil }
                return ScheduledOpponent(
                    id: matchup.id,
                    team: opponent,
                    venue: matchup.venue,
                    fromPot: matchup.opponentPot
                )
            }
            .sorted { lhs, rhs in
                lhs.fromPot == rhs.fromPot
                    ? lhs.team.name < rhs.team.name
                    : lhs.fromPot < rhs.fromPot
            }

            return TeamSchedule(team: team, opponents: opponents)
        }
    }
}
