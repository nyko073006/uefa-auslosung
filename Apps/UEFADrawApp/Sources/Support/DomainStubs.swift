// DomainStubs.swift
//
// ACHTUNG - TEMPORAERE DATEI.
//
// Minimale Stubs der in docs/architecture.md definierten Domain-Typen, damit App/
// vor Fertigstellung der Draw-Engine kompiliert und die SwiftUI-Previews laufen.
//
// Diese Typen gehoeren fachlich der Engine (Branch feature/draw-engine), nicht der UI.
// BEIM MERGE: diese Datei ersatzlos loeschen und stattdessen das Domain-Modul importieren.
// Es sind reine Datentraeger - hier steht bewusst keinerlei Verhalten und keine Regel.

import Foundation

/// Nationaler Verband eines Teams, z.B. "ENG" / "England".
struct Association: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Ein teilnehmendes Team mit seiner Topf-Zuordnung.
struct Team: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var name: String
    var association: Association
    var potIndex: Int

    init(id: UUID = UUID(), name: String, association: Association, potIndex: Int) {
        self.id = id
        self.name = name
        self.association = association
        self.potIndex = potIndex
    }
}

/// Ein Lostopf. Die Anzahl der Teams pro Topf ist eine Regel und gehoert der Engine.
struct Pot: Identifiable, Hashable, Sendable, Codable {
    let id: Int
    var teams: [Team]

    init(id: Int, teams: [Team]) {
        self.id = id
        self.teams = teams
    }
}

/// Heim- oder Auswaertsspiel aus Sicht des betrachteten Teams.
enum Venue: String, Hashable, Sendable, Codable, CaseIterable {
    case home
    case away

    var symbolName: String {
        switch self {
        case .home: "house.fill"
        case .away: "airplane"
        }
    }

    var shortLabel: String {
        switch self {
        case .home: "H"
        case .away: "A"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .home: "Heimspiel"
        case .away: "Auswaertsspiel"
        }
    }
}

/// Eine Paarung aus Sicht von `teamID`.
struct Matchup: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let teamID: Team.ID
    let opponentID: Team.ID
    let venue: Venue
    let opponentPot: Int

    init(
        id: UUID = UUID(),
        teamID: Team.ID,
        opponentID: Team.ID,
        venue: Venue,
        opponentPot: Int
    ) {
        self.id = id
        self.teamID = teamID
        self.opponentID = opponentID
        self.venue = venue
        self.opponentPot = opponentPot
    }
}
