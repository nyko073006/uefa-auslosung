// PlaybackControllerTests.swift
//
// Geprueft wird die Steuerung, nicht das Timing: Pause haelt den Cursor,
// ein Schritt bewegt genau einen Schritt, Replay setzt zurueck, und das
// Ueberspringen liefert exakt denselben Endzustand wie das Abspielen.

import XCTest
@testable import UEFADrawApp

@MainActor
final class PlaybackControllerTests: XCTestCase {

    private func makeController() -> (PlaybackController, [RevealStep]) {
        let steps = RevealSequencer.steps(for: DrawFixtures.mini().run)
        return (PlaybackController(steps: steps), steps)
    }

    func testStartsAtBeginning() {
        let (controller, steps) = makeController()

        XCTAssertEqual(controller.progress, 0)
        XCTAssertTrue(controller.canStepForward)
        XCTAssertFalse(controller.isFinished)
        XCTAssertEqual(controller.steps.count, steps.count)
    }

    func testStepForwardAdvancesExactlyOneStep() {
        let (controller, steps) = makeController()

        controller.setSpeed(.manual)
        controller.stepForward()

        XCTAssertEqual(controller.state.stepIndex, 1)

        var expected = RevealState()
        expected.apply(steps[0])
        XCTAssertEqual(controller.state, expected)
    }

    func testManualModePauses() {
        let (controller, _) = makeController()

        controller.setSpeed(.manual)

        XCTAssertTrue(controller.isPaused)
        XCTAssertEqual(controller.speed, .manual)
    }

    func testPauseHoldsTheCursor() {
        let (controller, _) = makeController()

        controller.setSpeed(.manual)
        controller.stepForward()
        controller.stepForward()
        let held = controller.state.stepIndex

        controller.pause()

        XCTAssertTrue(controller.isPaused)
        XCTAssertEqual(controller.state.stepIndex, held)
    }

    func testSkipToEndMatchesFullReduction() {
        let (controller, steps) = makeController()

        controller.skipToEnd()

        XCTAssertTrue(controller.isFinished)
        XCTAssertEqual(controller.progress, 1)
        XCTAssertEqual(controller.state, RevealState.reduce(steps[...]))
        XCTAssertTrue(controller.state.isCompleted)
    }

    func testSteppingThroughEverythingEqualsSkipToEnd() {
        let (stepped, steps) = makeController()
        let skipped = PlaybackController(steps: steps)

        stepped.setSpeed(.manual)
        while stepped.canStepForward {
            stepped.stepForward()
        }
        skipped.skipToEnd()

        XCTAssertEqual(stepped.state, skipped.state)
    }

    func testReplayResetsToStart() {
        let (controller, _) = makeController()

        controller.setSpeed(.manual)
        controller.stepForward()
        controller.stepForward()
        XCTAssertEqual(controller.state.stepIndex, 2)

        controller.replay()

        XCTAssertEqual(controller.progress, 0)
        XCTAssertEqual(controller.state, RevealState())
        XCTAssertTrue(controller.canStepForward)
    }

    func testReplayReproducesTheIdenticalState() {
        let (controller, _) = makeController()

        controller.setSpeed(.manual)
        controller.skipToEnd()
        let firstPass = controller.state

        controller.replay()
        controller.skipToEnd()

        XCTAssertEqual(controller.state, firstPass)
    }

    func testCompletionIsReportedExactlyOnce() {
        let (controller, _) = makeController()
        var completions = 0
        controller.onCompleted = { completions += 1 }

        controller.setSpeed(.manual)
        while controller.canStepForward {
            controller.stepForward()
        }
        controller.skipToEnd()

        XCTAssertEqual(completions, 1)
    }

    func testSpeedDoesNotChangeTheOrderOfSteps() {
        let (slow, steps) = makeController()
        let fast = PlaybackController(steps: steps)

        slow.setSpeed(.slow)
        fast.setSpeed(.fast)
        slow.skipToEnd()
        fast.skipToEnd()

        XCTAssertEqual(slow.state, fast.state)
        XCTAssertEqual(slow.steps, fast.steps)
    }
}
