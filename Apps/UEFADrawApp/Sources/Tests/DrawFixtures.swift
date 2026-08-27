// DrawFixtures.swift
//
// Kleines, handgeschriebenes Ergebnis fuer praezise Assertions.
// Bewusst winzig (2 Toepfe, 4 Teams), damit die Erwartungen ablesbar bleiben.

import Foundation
@testable import UEFADrawApp

enum DrawFixtures {

    static let england = Association(id: "ENG", name: "England")
    static let spanien = Association(id: "ESP", name: "Spanien")

    struct Mini {
        let run: DrawRun
        let teamA: Team
        let teamB: Team
        let teamC: Team
        let teamD: Team
    }

    /// Zwei Toepfe mit je zwei Teams, jedes Team bekommt genau einen Gegner.
    /// Team A hat zusaetzlich eine abgelehnte Kandidatur im Trace.
    static func mini(seed: UInt64 = 42) -> Mini {
        let teamA = Team(name: "A-Team", association: england, potIndex: 1)
        let teamB = Team(name: "B-Team", association: spanien, potIndex: 1)
        let teamC = Team(name: "C-Team", association: england, potIndex: 2)
        let teamD = Team(name: "D-Team", association: spanien, potIndex: 2)

        let setup = DrawSetup(
            pots: [
                Pot(id: 1, teams: [teamA, teamB]),
                Pot(id: 2, teams: [teamC, teamD])
            ],
            enabledConstraintIDs: []
        )

        let matchups = [
            Matchup(teamID: teamA.id, opponentID: teamC.id, venue: .home, opponentPot: 2),
            Matchup(teamID: teamC.id, opponentID: teamA.id, venue: .away, opponentPot: 1),
            Matchup(teamID: teamB.id, opponentID: teamD.id, venue: .home, opponentPot: 2),
            Matchup(teamID: teamD.id, opponentID: teamB.id, venue: .away, opponentPot: 1)
        ]

        let trace = [
            DrawTraceEntry(
                teamID: teamA.id,
                candidateID: teamB.id,
                candidatePot: 1,
                outcome: .rejected(reason: "Beispielbegruendung aus der Engine.")
            ),
            DrawTraceEntry(
                teamID: teamA.id, candidateID: teamC.id, candidatePot: 2,
                outcome: .accepted(venue: .home)
            ),
            DrawTraceEntry(
                teamID: teamB.id, candidateID: teamD.id, candidatePot: 2,
                outcome: .accepted(venue: .home)
            ),
            DrawTraceEntry(
                teamID: teamC.id, candidateID: teamA.id, candidatePot: 1,
                outcome: .accepted(venue: .away)
            ),
            DrawTraceEntry(
                teamID: teamD.id, candidateID: teamB.id, candidatePot: 1,
                outcome: .accepted(venue: .away)
            )
        ]

        return Mini(
            run: DrawRun(setup: setup, matchups: matchups, trace: trace, seed: seed),
            teamA: teamA,
            teamB: teamB,
            teamC: teamC,
            teamD: teamD
        )
    }

    /// Derselbe Aufbau, aber ohne Trace - prueft den Fallback des Sequencers.
    static func miniWithoutTrace() -> DrawRun {
        let mini = mini()
        return DrawRun(
            setup: mini.run.setup,
            matchups: mini.run.matchups,
            trace: [],
            seed: mini.run.seed
        )
    }
}
