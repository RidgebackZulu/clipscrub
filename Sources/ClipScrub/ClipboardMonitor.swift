import AppKit

final class ClipboardMonitor {
    private let historyManager: HistoryManager
    private let onClean: () -> Void
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.clipscrub.clipboard", qos: .utility)
    private var lastChangeCount: Int = 0
    private var isPaused = false
    private(set) var dailyCleanCount = 0
    private var lastResetDate: Date = Date()

    var soundEnabled = true
    var fetchMetadata = true

    init(historyManager: HistoryManager, onClean: @escaping () -> Void) {
        self.historyManager = historyManager
        self.onClean = onClean
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 1, repeating: 1.0)
        source.setEventHandler { [weak self] in
            self?.checkClipboard()
        }
        source.resume()
        timer = source
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        // Re-read changeCount to avoid processing stale data
        lastChangeCount = NSPasteboard.general.changeCount
        isPaused = false
    }

    private func checkClipboard() {
        guard !isPaused else { return }

        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let content = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard URLSanitizer.isURL(trimmed) else { return }
        guard let cleaned = URLSanitizer.sanitize(trimmed) else { return }

        // Write cleaned URL back to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cleaned, forType: .string)
        // Track our own write to avoid re-processing
        lastChangeCount = NSPasteboard.general.changeCount

        let entry = historyManager.add(cleaned)
        incrementDailyCount()

        if soundEnabled {
            DispatchQueue.main.async {
                NSSound(named: "Tink")?.play()
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.onClean()
        }

        if fetchMetadata {
            MetadataFetcher.fetch(url: cleaned) { [weak self] result in
                entry.title = result.title
                entry.descriptionText = result.description
                entry.thumbnail = result.image
                entry.isFetching = false
                self?.onClean()
            }
        } else {
            entry.isFetching = false
        }
    }

    private func incrementDailyCount() {
        if !Calendar.current.isDateInToday(lastResetDate) {
            dailyCleanCount = 0
            lastResetDate = Date()
        }
        dailyCleanCount += 1
    }
}
