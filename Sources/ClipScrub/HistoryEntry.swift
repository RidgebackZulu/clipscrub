import AppKit

final class HistoryEntry {
    let url: String
    var title: String?
    var descriptionText: String?
    var thumbnail: NSImage?
    var isFetching: Bool

    init(url: String) {
        self.url = url
        self.isFetching = true
    }
}
