import Foundation

final class HistoryManager {
    private let capacity = 10
    private var buffer: [HistoryEntry] = []

    /// Add a cleaned URL to history (newest first). Returns the new entry.
    @discardableResult
    func add(_ url: String) -> HistoryEntry {
        let entry = HistoryEntry(url: url)
        buffer.insert(entry, at: 0)
        if buffer.count > capacity {
            buffer.removeLast()
        }
        return entry
    }

    /// All entries, newest first
    var entries: [HistoryEntry] {
        buffer
    }

    var isEmpty: Bool {
        buffer.isEmpty
    }
}
