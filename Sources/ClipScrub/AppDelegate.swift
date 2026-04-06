import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var clipboardMonitor: ClipboardMonitor!
    private var sleepWakeHandler: SleepWakeHandler!
    private let historyManager = HistoryManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (backup — Info.plist LSUIElement handles this in .app bundle)
        NSApp.setActivationPolicy(.accessory)

        statusBarController = StatusBarController(historyManager: historyManager)

        clipboardMonitor = ClipboardMonitor(historyManager: historyManager) { [weak self] in
            self?.statusBarController.refreshMenu()
        }

        statusBarController.setMonitor(clipboardMonitor)

        sleepWakeHandler = SleepWakeHandler(
            onSleep: { [weak self] in
                self?.clipboardMonitor.pause()
                self?.statusBarController.setPaused(true)
            },
            onWake: { [weak self] in
                self?.clipboardMonitor.resume()
                self?.statusBarController.setPaused(false)
            }
        )

        statusBarController.onPauseToggle = { [weak self] paused in
            if paused {
                self?.clipboardMonitor.pause()
            } else {
                self?.clipboardMonitor.resume()
            }
        }

        clipboardMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
    }
}
