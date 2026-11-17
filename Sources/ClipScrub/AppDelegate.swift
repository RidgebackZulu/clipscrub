import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var clipboardMonitor: ClipboardMonitor!
    private var sleepWakeHandler: SleepWakeHandler!
    private var monitoringState = MonitoringState()
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
                self?.monitoringState.sleeping = true
                self?.applyMonitoringState()
            },
            onWake: { [weak self] in
                self?.monitoringState.sleeping = false
                self?.applyMonitoringState()
            }
        )

        statusBarController.onPauseToggle = { [weak self] paused in
            self?.monitoringState.userPaused = paused
            self?.applyMonitoringState()
        }

        clipboardMonitor.start()
    }

    private func applyMonitoringState() {
        if monitoringState.isPaused {
            clipboardMonitor.pause()
        } else {
            clipboardMonitor.resume()
        }
        statusBarController.setPaused(monitoringState.isPaused)
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
    }
}
