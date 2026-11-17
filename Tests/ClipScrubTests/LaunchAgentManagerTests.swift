import XCTest
@testable import ClipScrub

final class LaunchAgentManagerTests: XCTestCase {
    func testSpecialCharactersRoundTripInExecutablePath() throws {
        let path = "/Users/test/Apps & Tools/<local>/\"ClipScrub\".app/Contents/MacOS/ClipScrub"
        let data = try LaunchAgentManager.plistData(executablePath: path)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["ProgramArguments"] as? [String], [path])
        XCTAssertEqual(plist["Label"] as? String, "com.clipscrub.agent")
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["KeepAlive"] as? Bool, false)
    }
}
