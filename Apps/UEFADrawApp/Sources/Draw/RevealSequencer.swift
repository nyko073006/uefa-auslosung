// RevealSequencer.swift
//
// Uebersetzt ein fertiges Engine-Ergebnis in eine Enthuellungs-Sequenz.
//
// Die Engine ist eine Pure Function mit Seed - es troepfelt nichts "live" herein.
// Wie bei einer echten TV-Auslosung steht das Resultat laengst fest und nur die
// Enthuellung wird inszeniert. Hier passiert deshalb ausschliesslich Umsortieren
// bereits vorhandener Daten: keine Regel, keine Bewertung, keine Zufallsentscheidung.

import Foundation

/// Ein Schritt der Enthuellung.
enum RevealStep: Hashable, Sendable {
    case potOpened(Int)
    case teamDrawn(Team.ID)
    /// Abgelehnter Kandidat samt engine-formulierter Begruendung.
    case candidateRejected(candidate: Team.ID, reason: String)
    case opponentRevealed(opponent: Team.ID, venue: Venue, fromPot: Int)
    case teamCompleted(Team.ID)
    case drawCompleted
}

enum RevealSequencer {

    /// Baut die Sequenz in Topf- und Team-Reihenfolge des Setups.
    ///
    /// Fuer jedes Team werden die Trace-Eintraege in Engine-Reihenfolge abgespielt,
    /// damit Ablehnungen dort erscheinen, wo sie tatsaechlich aufgetreten sind.
    static func steps(for run: DrawRun) -> [RevealStep] {
        var steps: [RevealStep] = []
        var openPot: Int?

        let traceByTeam = Dictionary(grouping: run.trace, by: \.teamID)
        let matchupLookup = Dictionary(grouping: run.matchups, by: \.teamID)

        for team in run.setup.allTeams {
            if openPot != team.potIndex {
                openPot = team.potIndex
                steps.append(.potOpened(team.potIndex))
            }

            steps.append(.teamDrawn(team.id))

            let entries = traceByTeam[team.id] ?? []
            if entries.isEmpty {
                // Kein Trace vorhanden: dann direkt aus den Paarungen enthuellen.
                let fallback = (matchupLookup[team.id] ?? [])
                    .sorted { $0.opponentPot < $1.opponentPot }
                for matchup in fallback {
                    steps.append(
                        .opponentRevealed(
                            opponent: matchup.opponentID,
                            venue: matchup.venue,
                            fromPot: matchup.opponentPot
                        )
                    )
                }
            } else {
                for entry in entries {
                    switch entry.outcome {
                    case .rejected(let reason):
                        steps.append(.candidateRejected(candidate: entry.candidateID, reason: reason))
                    case .accepted(let venue):
                        steps.append(
                            .opponentRevealed(
                                opponent: entry.candidateID,
                                venue: venue,
                                fromPot: entry.candidatePot
                            )
                        )
                    }
                }
            }

            steps.append(.teamCompleted(team.id))
        }

        steps.append(.drawCompleted)
        return steps
    }
}
