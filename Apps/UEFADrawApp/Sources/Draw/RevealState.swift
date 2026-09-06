// RevealState.swift
//
// Der aus `[RevealStep]` reduzierte Anzeigezustand.
//
// Namensgebung mit Absicht: die Domain besitzt laut docs/architecture.md bereits
// `DrawState`. Das Praefix `Reveal` haelt die Praesentationsschicht kollisionsfrei.
//
// Der Reducer fuehrt ausschliesslich Buch. Er entscheidet nichts, prueft keine Regel
// und vergleicht keine Zaehlung gegen einen Schwellwert - er schreibt nur mit,
// was die Engine bereits entschieden hat.

import Foundation

/// Ein bereits aufgedeckter Gegner des laufenden Teams.
struct RevealedOpponent: Identifiable, Hashable, Sendable {
    let id: Team.ID
    let venue: Venue
    let fromPot: Int
}

/// Eine angezeigte Ablehnung. `reason` stammt wortwoertlich aus der Engine.
struct RevealedRejection: Hashable, Sendable {
    let candidate: Team.ID
    let reason: String
}

struct RevealState: Hashable, Sendable {

    /// Bis zu welchem Schritt (exklusiv) wurde reduziert.
    private(set) var stepIndex: Int = 0

    private(set) var openPot: Int?
    private(set) var currentTeamID: Team.ID?
    private(set) var revealedOpponents: [RevealedOpponent] = []
    private(set) var activeRejection: RevealedRejection?
    private(set) var completedTeamIDs: [Team.ID] = []
    private(set) var isCompleted: Bool = false

    /// Zaehlt, wie viele Gegner je Topf schon aufgedeckt sind.
    var revealedCountByPot: [Int: Int] {
        revealedOpponents.reduce(into: [:]) { partial, opponent in
            partial[opponent.fromPot, default: 0] += 1
        }
    }

    // MARK: - Reducer

    mutating func apply(_ step: RevealStep) {
        stepIndex += 1

        switch step {
        case .potOpened(let pot):
            openPot = pot
            activeRejection = nil

        case .teamDrawn(let teamID):
            currentTeamID = teamID
            revealedOpponents = []
            activeRejection = nil

        case .candidateRejected(let candidate, let reason):
            activeRejection = RevealedRejection(candidate: candidate, reason: reason)

        case .opponentRevealed(let opponent, let venue, let fromPot):
            revealedOpponents.append(
                RevealedOpponent(id: opponent, venue: venue, fromPot: fromPot)
            )
            activeRejection = nil

        case .teamCompleted(let teamID):
            if !completedTeamIDs.contains(teamID) {
                completedTeamIDs.append(teamID)
            }
            activeRejection = nil

        case .drawCompleted:
            isCompleted = true
            currentTeamID = nil
            activeRejection = nil
        }
    }

    /// Baut den Zustand von vorn auf. Grundlage fuer Replay und spaeteres Scrubbing.
    static func reduce(_ steps: ArraySlice<RevealStep>) -> RevealState {
        var state = RevealState()
        for step in steps {
            state.apply(step)
        }
        return state
    }
}
