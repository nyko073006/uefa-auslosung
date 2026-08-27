// RevealSequencerTests.swift
//
// Geprueft wird die Praesentationslogik: Vollstaendigkeit und Reihenfolge der
// Enthuellung. Regeln, Constraint-Erfuellung und Algorithmus gehoeren zur Engine
// und werden hier bewusst nicht getestet.

import XCTest
@testable import UEFADrawApp

final class RevealSequencerTests: XCTestCase {

    func testSequenceEndsWithDrawCompleted() {
        let steps = RevealSequencer.steps(for: DrawFixtures.mini().run)

        XCTAssertEqual(steps.last, .drawCompleted)
        XCTAssertEqual(steps.filter { $0 == .drawCompleted }.count, 1)
    }

    func testEveryTeamIsDrawnAndCompletedExactlyOnce() {
        let mini = DrawFixtures.mini()
        let steps = RevealSequencer.steps(for: mini.run)

        for team in mini.run.setup.allTeams {
            let drawn = steps.filter { $0 == .teamDrawn(team.id) }.count
            let completed = steps.filter { $0 == .teamCompleted(team.id) }.count

            XCTAssertEqual(drawn, 1, "Team \(team.name) wurde \(drawn)-mal gezogen.")
            XCTAssertEqual(completed, 1, "Team \(team.name) wurde \(completed)-mal beendet.")
        }
    }

    func testRevealCountMatchesMatchupCountPerTeam() {
        let mini = DrawFixtures.mini()
        let steps = RevealSequencer.steps(for: mini.run)

        for team in mini.run.setup.allTeams {
            let expected = mini.run.matchups(for: team.id).count
            let actual = revealCount(in: steps, forTeam: team.id, run: mini.run)

            XCTAssertEqual(
                actual, expected,
                "Team \(team.name): \(actual) Enthuellungen statt \(expected)."
            )
        }
    }

    func testPotIsOpenedBeforeItsFirstTeam() {
        let mini = DrawFixtures.mini()
        let steps = RevealSequencer.steps(for: mini.run)

        guard let firstPotOpen = steps.firstIndex(of: .potOpened(1)),
              let firstTeamDrawn = steps.firstIndex(of: .teamDrawn(mini.teamA.id)) else {
            return XCTFail("Erwartete Schritte fehlen.")
        }

        XCTAssertLessThan(firstPotOpen, firstTeamDrawn)
    }

    func testRejectionAppearsBeforeTheAcceptanceOfTheSameTeam() {
        let mini = DrawFixtures.mini()
        let steps = RevealSequencer.steps(for: mini.run)

        let rejectionIndex = steps.firstIndex {
            if case .candidateRejected(let candidate, _) = $0 {
                return candidate == mini.teamB.id
            }
            return false
        }
        let revealIndex = steps.firstIndex {
            if case .opponentRevealed(let opponent, _, _) = $0 {
                return opponent == mini.teamC.id
            }
            return false
        }

        guard let rejectionIndex, let revealIndex else {
            return XCTFail("Ablehnung oder Enthuellung fehlt in der Sequenz.")
        }
        XCTAssertLessThan(rejectionIndex, revealIndex)
    }

    func testFallbackRevealsFromMatchupsWhenTraceIsEmpty() {
        let run = DrawFixtures.miniWithoutTrace()
        let steps = RevealSequencer.steps(for: run)

        let reveals = steps.filter {
            if case .opponentRevealed = $0 { return true }
            return false
        }

        XCTAssertEqual(reveals.count, run.matchups.count)
        XCTAssertFalse(steps.contains {
            if case .candidateRejected = $0 { return true }
            return false
        })
    }

    func testOpponentsOfATeamAppearInAscendingPotOrder() async {
        let run = await SampleTeams.previewRun(seed: 7)
        let steps = RevealSequencer.steps(for: run)

        var currentTeam: Team.ID?
        var lastPot = Int.min

        for step in steps {
            switch step {
            case .teamDrawn(let id):
                currentTeam = id
                lastPot = Int.min
            case .opponentRevealed(_, _, let fromPot):
                XCTAssertNotNil(currentTeam)
                XCTAssertGreaterThanOrEqual(
                    fromPot, lastPot,
                    "Toepfe muessen je Team aufsteigend enthuellt werden."
                )
                lastPot = fromPot
            default:
                break
            }
        }
    }

    // MARK: - Hilfen

    private func revealCount(
        in steps: [RevealStep],
        forTeam teamID: Team.ID,
        run: DrawRun
    ) -> Int {
        var isInsideTeam = false
        var count = 0

        for step in steps {
            switch step {
            case .teamDrawn(let id):
                isInsideTeam = (id == teamID)
            case .opponentRevealed where isInsideTeam:
                count += 1
            case .teamCompleted(let id) where id == teamID:
                isInsideTeam = false
            default:
                break
            }
        }
        return count
    }
}
