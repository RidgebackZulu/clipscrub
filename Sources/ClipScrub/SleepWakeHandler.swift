import AppKit

final class SleepWakeHandler {
    private let onSleep: () -> Void
    private let onWake: () -> Void

    init(onSleep: @escaping () -> Void, onWake: @escaping () -> Void) {
        self.onSleep = onSleep
        self.onWake = onWake

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self, selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification, object: nil
        )
        center.addObserver(
            self, selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func handleSleep(_ notification: Notification) {
        onSleep()
    }

    @objc private func handleWake(_ notification: Notification) {
        // 2-second delay to let the system stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.onWake()
        }
    }
}
