import XCTest
@testable import ClipScrub

final class MonitoringStateTests: XCTestCase {
    func testManualPauseSurvivesSleepAndWake() {
        var state = MonitoringState()
        state.userPaused = true
        state.sleeping = true
        state.sleeping = false
        XCTAssertTrue(state.isPaused)
    }

    func testRunningMonitorResumesAfterWake() {
        var state = MonitoringState()
        XCTAssertFalse(state.isPaused)
        state.sleeping = true
        XCTAssertTrue(state.isPaused)
        state.sleeping = false
        XCTAssertFalse(state.isPaused)
    }

    func testResumeWhileSleepingWaitsForWake() {
        var state = MonitoringState()
        state.sleeping = true
        state.userPaused = true
        state.userPaused = false
        XCTAssertTrue(state.isPaused)
        state.sleeping = false
        XCTAssertFalse(state.isPaused)
    }
}
