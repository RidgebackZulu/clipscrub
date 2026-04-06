import AppKit

final class HistoryMenuItemView: NSView {
    private let entry: HistoryEntry
    private let index: Int
    private let showFullURL: Bool

    private let thumbnailView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let urlLabel = NSTextField(labelWithString: "")
    private let descLabel = NSTextField(labelWithString: "")

    private static let menuWidth: CGFloat = 320
    private static let thumbnailSize: CGFloat = 32
    private static let padding: CGFloat = 8
    private static let textGap: CGFloat = 1

    init(entry: HistoryEntry, index: Int, showFullURL: Bool) {
        self.entry = entry
        self.index = index
        self.showFullURL = showFullURL
        super.init(frame: .zero)
        setupViews()
        layoutContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        // Thumbnail
        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 4
        thumbnailView.layer?.masksToBounds = true

        for label in [titleLabel, urlLabel, descLabel] {
            label.maximumNumberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            label.cell?.wraps = false
            label.cell?.isScrollable = false
            label.cell?.usesSingleLineMode = true
            label.cell?.truncatesLastVisibleLine = true
        }

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        urlLabel.font = .systemFont(ofSize: 11)
        urlLabel.textColor = .secondaryLabelColor
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .tertiaryLabelColor
    }

    private func layoutContent() {
        subviews.forEach { $0.removeFromSuperview() }

        let hasMeta = entry.title != nil || entry.descriptionText != nil
        let hasThumb = entry.thumbnail != nil
        let pad = Self.padding
        let thumbSize = Self.thumbnailSize

        var textX = pad + 16 // room for index number
        var totalHeight: CGFloat

        // Thumbnail
        if hasThumb {
            thumbnailView.image = entry.thumbnail
            thumbnailView.frame = NSRect(x: textX, y: 0, width: thumbSize, height: thumbSize)
            addSubview(thumbnailView)
            textX += thumbSize + pad
        }

        let textWidth = Self.menuWidth - textX - pad

        let titleLineHeight: CGFloat = 16
        let smallLineHeight: CGFloat = 14

        if hasMeta {
            // Rich layout: title + URL + description (single line each, truncated)
            let rawTitle = entry.title ?? displayURL()
            let titleStr = rawTitle.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: "")
            titleLabel.stringValue = "\(index). \(titleStr)"
            titleLabel.frame = NSRect(x: textX, y: 0, width: textWidth, height: titleLineHeight)

            urlLabel.stringValue = displayURL()
            urlLabel.frame = NSRect(x: textX, y: 0, width: textWidth, height: smallLineHeight)

            var lines: [(NSTextField, CGFloat)] = [
                (titleLabel, titleLineHeight),
                (urlLabel, smallLineHeight),
            ]

            if let desc = entry.descriptionText, !desc.isEmpty {
                // Strip newlines and hard-truncate to guarantee single line
                let oneLine = desc
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: "")
                    .prefix(120)
                descLabel.stringValue = String(oneLine)
                descLabel.frame = NSRect(x: textX, y: 0, width: textWidth, height: smallLineHeight)
                lines.append((descLabel, smallLineHeight))
            }

            // Stack from bottom up
            totalHeight = pad
            for (label, height) in lines.reversed() {
                label.frame = NSRect(x: textX, y: totalHeight, width: textWidth, height: height)
                addSubview(label)
                totalHeight += height + Self.textGap
            }
            totalHeight += pad - Self.textGap

            // Ensure at least thumbnail height + padding
            if hasThumb {
                totalHeight = max(totalHeight, thumbSize + pad * 2)
            }

            // Vertically center thumbnail
            if hasThumb {
                thumbnailView.frame.origin.y = (totalHeight - thumbSize) / 2
            }
        } else {
            // Simple layout: URL only (no metadata yet)
            titleLabel.stringValue = "\(index). \(displayURL())"
            titleLabel.font = .systemFont(ofSize: 13)
            titleLabel.frame = NSRect(x: textX, y: pad, width: textWidth, height: 16)
            titleLabel.sizeToFit()
            titleLabel.frame.size.width = textWidth
            addSubview(titleLabel)
            totalHeight = titleLabel.frame.height + pad * 2
        }

        self.frame = NSRect(x: 0, y: 0, width: Self.menuWidth, height: totalHeight)
    }

    private func displayURL() -> String {
        if showFullURL { return entry.url }
        var display = entry.url
        if display.hasPrefix("https://") { display = String(display.dropFirst(8)) }
        else if display.hasPrefix("http://") { display = String(display.dropFirst(7)) }
        if display.count > 45 { display = String(display.prefix(42)) + "..." }
        return display
    }

    override func mouseUp(with event: NSEvent) {
        guard let menuItem = enclosingMenuItem,
              let url = menuItem.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        menuItem.menu?.cancelTracking()
    }

    override func draw(_ dirtyRect: NSRect) {
        if enclosingMenuItem?.isHighlighted == true {
            NSColor.selectedContentBackgroundColor.set()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 4, yRadius: 4).fill()
            // Switch text to white when highlighted
            titleLabel.textColor = .white
            urlLabel.textColor = NSColor.white.withAlphaComponent(0.7)
            descLabel.textColor = NSColor.white.withAlphaComponent(0.5)
        } else {
            titleLabel.textColor = .labelColor
            urlLabel.textColor = .secondaryLabelColor
            descLabel.textColor = .tertiaryLabelColor
        }
        super.draw(dirtyRect)
    }
}
