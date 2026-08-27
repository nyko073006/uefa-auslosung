import XCTest
@testable import DrawEngine

final class DrawEngineTests: XCTestCase {
    func testEngineIsReadyByDefault() {
        let engine = DrawEngine()

        XCTAssertTrue(engine.isReady)
    }
}

