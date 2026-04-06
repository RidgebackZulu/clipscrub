import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let historyManager: HistoryManager
    private var isPaused = false
    private var showFullURLs = false
    private var clipboardMonitor: ClipboardMonitor?

    var onPauseToggle: ((Bool) -> Void)?

    init(historyManager: HistoryManager) {
        self.historyManager = historyManager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "link", accessibilityDescription: "ClipScrub")
        }

        buildMenu()
    }

    func setMonitor(_ monitor: ClipboardMonitor) {
        self.clipboardMonitor = monitor
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        updateIcon()
        buildMenu()
    }

    func refreshMenu() {
        DispatchQueue.main.async { [weak self] in
            self?.buildMenu()
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.appearsDisabled = isPaused
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Header
        let header = NSMenuItem(title: "ClipScrub", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(NSMenuItem.separator())

        // Status
        let status = isPaused ? "Paused" : "Running"
        let statusItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        if !isPaused {
            statusItem.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
            statusItem.image?.isTemplate = true
        }
        menu.addItem(statusItem)

        // Daily count
        let count = clipboardMonitor?.dailyCleanCount ?? 0
        let countItem = NSMenuItem(title: "\(count) URL\(count == 1 ? "" : "s") cleaned today", action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        menu.addItem(countItem)

        menu.addItem(NSMenuItem.separator())

        // History
        let historyHeader = NSMenuItem(title: "Recent Cleaned URLs:", action: nil, keyEquivalent: "")
        historyHeader.isEnabled = false
        menu.addItem(historyHeader)

        if historyManager.isEmpty {
            let empty = NSMenuItem(title: "  No URLs cleaned yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (i, entry) in historyManager.entries.enumerated() {
                let item = NSMenuItem()
                item.view = HistoryMenuItemView(entry: entry, index: i + 1, showFullURL: showFullURLs)
                item.representedObject = entry.url
                item.toolTip = entry.url
                item.target = self
                item.action = #selector(copyHistoryItem(_:))
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Pause/Resume
        let pauseTitle = isPaused ? "▶ Resume ClipScrub" : "⏸ Pause ClipScrub"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        // Settings submenu
        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAgentManager.isInstalled ? .on : .off
        settingsMenu.addItem(launchItem)

        let soundItem = NSMenuItem(title: "Sound on Clean", action: #selector(toggleSound(_:)), keyEquivalent: "")
        soundItem.target = self
        soundItem.state = (clipboardMonitor?.soundEnabled ?? true) ? .on : .off
        settingsMenu.addItem(soundItem)

        let urlDisplayItem = NSMenuItem(title: "Show Full URLs", action: #selector(toggleURLDisplay(_:)), keyEquivalent: "")
        urlDisplayItem.target = self
        urlDisplayItem.state = showFullURLs ? .on : .off
        settingsMenu.addItem(urlDisplayItem)

        let fetchItem = NSMenuItem(title: "Fetch Page Info", action: #selector(toggleFetchMetadata(_:)), keyEquivalent: "")
        fetchItem.target = self
        fetchItem.state = (clipboardMonitor?.fetchMetadata ?? true) ? .on : .off
        settingsMenu.addItem(fetchItem)

        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)

        // Help submenu
        let helpItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        let helpMenu = NSMenu()

        let uninstallItem = NSMenuItem(title: "How to Uninstall", action: #selector(showUninstallHelp), keyEquivalent: "")
        uninstallItem.target = self
        helpMenu.addItem(uninstallItem)

        let aboutItem = NSMenuItem(title: "About ClipScrub", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        helpMenu.addItem(aboutItem)

        helpItem.submenu = helpMenu
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit ClipScrub", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    private func truncateURL(_ urlString: String, maxLength: Int) -> String {
        // Strip scheme for display
        var display = urlString
        if display.hasPrefix("https://") { display = String(display.dropFirst(8)) }
        else if display.hasPrefix("http://") { display = String(display.dropFirst(7)) }

        if display.count <= maxLength { return display }
        return String(display.prefix(maxLength - 3)) + "..."
    }

    // MARK: - Actions

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    @objc private func togglePause() {
        isPaused.toggle()
        onPauseToggle?(isPaused)
        updateIcon()
        buildMenu()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if LaunchAgentManager.isInstalled {
            LaunchAgentManager.uninstall()
        } else {
            LaunchAgentManager.install()
        }
        buildMenu()
    }

    @objc private func toggleSound(_ sender: NSMenuItem) {
        clipboardMonitor?.soundEnabled.toggle()
        buildMenu()
    }

    @objc private func toggleURLDisplay(_ sender: NSMenuItem) {
        showFullURLs.toggle()
        buildMenu()
    }

    @objc private func toggleFetchMetadata(_ sender: NSMenuItem) {
        clipboardMonitor?.fetchMetadata.toggle()
        buildMenu()
    }

    @objc private func showUninstallHelp() {
        let alert = NSAlert()
        alert.messageText = "How to Uninstall ClipScrub"
        alert.informativeText = """
        1. Click "Quit ClipScrub" from the menu bar
        2. Remove ClipScrub.app from /Applications
        3. The Launch Agent (if enabled) will be removed automatically

        Or click "Remove Launch Agent Now" to clean up the login item.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Remove Launch Agent Now")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            LaunchAgentManager.uninstall()
            buildMenu()
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "ClipScrub",
            .applicationVersion: "1.0",
            .version: "1",
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
