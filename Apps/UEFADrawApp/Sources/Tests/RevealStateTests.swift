// RevealStateTests.swift
//
// Der Reducer fuehrt nur Buch. Genau das wird hier geprueft.

import XCTest
@testable import UEFADrawApp

final class RevealStateTests: XCTestCase {

    func testTeamDrawnResetsOpponentsAndRejection() {
        let mini = DrawFixtures.mini()
        var state = RevealState()

        state.apply(.teamDrawn(mini.teamA.id))
        state.apply(.opponentRevealed(opponent: mini.teamC.id, venue: .home, fromPot: 2))
        state.apply(.candidateRejected(candidate: mini.teamB.id, reason: "x"))

        XCTAssertEqual(state.revealedOpponents.count, 1)
        XCTAssertNotNil(state.activeRejection)

        state.apply(.teamDrawn(mini.teamB.id))

        XCTAssertEqual(state.currentTeamID, mini.teamB.id)
        XCTAssertTrue(state.revealedOpponents.isEmpty)
        XCTAssertNil(state.activeRejection)
    }

    func testRevealClearsActiveRejection() {
        let mini = DrawFixtures.mini()
        var state = RevealState()

        state.apply(.teamDrawn(mini.teamA.id))
        state.apply(.candidateRejected(candidate: mini.teamB.id, reason: "Beispiel"))
        XCTAssertEqual(state.activeRejection?.candidate, mini.teamB.id)

        state.apply(.opponentRevealed(opponent: mini.teamC.id, venue: .home, fromPot: 2))
        XCTAssertNil(state.activeRejection)
    }

    func testCompletedTeamsAreRecordedOnceAndInOrder() {
        let mini = DrawFixtures.mini()
        var state = RevealState()

        state.apply(.teamCompleted(mini.teamA.id))
        state.apply(.teamCompleted(mini.teamB.id))
        state.apply(.teamCompleted(mini.teamA.id))

        XCTAssertEqual(state.completedTeamIDs, [mini.teamA.id, mini.teamB.id])
    }

    func testDrawCompletedSetsFlagAndClearsCurrentTeam() {
        let mini = DrawFixtures.mini()
        var state = RevealState()

        state.apply(.teamDrawn(mini.teamA.id))
        state.apply(.drawCompleted)

        XCTAssertTrue(state.isCompleted)
        XCTAssertNil(state.currentTeamID)
    }

    func testReduceEqualsIncrementalApply() {
        let steps = RevealSequencer.steps(for: DrawFixtures.mini().run)

        var incremental = RevealState()
        for step in steps {
            incremental.apply(step)
        }

        let reduced = RevealState.reduce(steps[...])

        XCTAssertEqual(incremental, reduced)
        XCTAssertEqual(reduced.stepIndex, steps.count)
    }

    func testReduceOfPrefixMatchesPartialPlayback() {
        let steps = RevealSequencer.steps(for: DrawFixtures.mini().run)
        let cut = steps.count / 2

        var partial = RevealState()
        for step in steps.prefix(cut) {
            partial.apply(step)
        }

        XCTAssertEqual(partial, RevealState.reduce(steps[0..<cut]))
    }

    func testRevealedCountByPotCountsOnlyCurrentTeam() {
        let mini = DrawFixtures.mini()
        var state = RevealState()

        state.apply(.teamDrawn(mini.teamA.id))
        state.apply(.opponentRevealed(opponent: mini.teamC.id, venue: .home, fromPot: 2))
        state.apply(.opponentRevealed(opponent: mini.teamD.id, venue: .away, fromPot: 2))

        XCTAssertEqual(state.revealedCountByPot[2], 2)
        XCTAssertNil(state.revealedCountByPot[1])
    }
}
