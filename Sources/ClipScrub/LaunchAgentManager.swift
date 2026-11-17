import Foundation

struct LaunchAgentManager {
    static let plistPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/com.clipscrub.agent.plist").path
    }()

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    static func plistData(executablePath: String) throws -> Data {
        let plist: [String: Any] = [
            "Label": "com.clipscrub.agent",
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    static func install() throws {
        let execPath = "\(Bundle.main.bundlePath)/Contents/MacOS/ClipScrub"
        let data = try plistData(executablePath: execPath)
        let dir = (plistPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
    }

    static func uninstall() {
        try? FileManager.default.removeItem(atPath: plistPath)
    }
}
