import Foundation

struct LaunchAgentManager {
    static let plistPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/com.clipscrub.agent.plist").path
    }()

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistPath)
    }

    static func install() {
        let appPath = Bundle.main.bundlePath
        let execPath = "\(appPath)/Contents/MacOS/ClipScrub"

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.clipscrub.agent</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(execPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """

        // Ensure LaunchAgents directory exists
        let dir = (plistPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
    }

    static func uninstall() {
        try? FileManager.default.removeItem(atPath: plistPath)
    }
}
