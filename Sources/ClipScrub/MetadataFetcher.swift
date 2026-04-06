import AppKit

struct MetadataResult {
    var title: String?
    var description: String?
    var imageURL: String?
    var image: NSImage?
}

final class MetadataFetcher {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()

    /// Domains that need the oEmbed fallback (JS-rendered, no server-side OG tags)
    private static let oEmbedDomains: Set<String> = [
        "x.com", "twitter.com", "mobile.twitter.com", "mobile.x.com",
    ]

    /// Fetch Open Graph metadata for a URL. Completion is called on the main queue.
    static func fetch(url urlString: String, completion: @escaping (MetadataResult) -> Void) {
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { completion(MetadataResult()) }
            return
        }

        let host = url.host?.lowercased() ?? ""

        // X/Twitter renders everything client-side — no OG tags in HTML.
        // Use their public oEmbed API instead.
        if oEmbedDomains.contains(host) || oEmbedDomains.contains(where: { host.hasSuffix(".\($0)") }) {
            fetchTwitterOEmbed(url: url, completion: completion)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                DispatchQueue.main.async { completion(MetadataResult()) }
                return
            }

            var tags = parseOGTags(from: html)
            // Merge twitter: tags as fallback for sites that use those instead of og:
            let twitterTags = parseTwitterTags(from: html)
            for (key, value) in twitterTags where tags[key] == nil {
                tags[key] = value
            }

            var result = MetadataResult(
                title: tags["title"],
                description: tags["description"],
                imageURL: tags["image"]
            )

            // Also try <title> tag as fallback
            if result.title == nil {
                result.title = parseHTMLTitle(from: html)
            }

            // If we have an image URL, fetch the thumbnail
            if let imageURLString = result.imageURL,
               let imageURL = resolveURL(imageURLString, relativeTo: url) {
                fetchThumbnail(from: imageURL) { image in
                    result.image = image
                    DispatchQueue.main.async { completion(result) }
                }
            } else {
                DispatchQueue.main.async { completion(result) }
            }
        }.resume()
    }

    // MARK: - Twitter/X oEmbed

    /// Fetch tweet metadata via Twitter's public oEmbed endpoint.
    /// Returns author name as title and tweet text as description.
    private static func fetchTwitterOEmbed(url: URL, completion: @escaping (MetadataResult) -> Void) {
        // oEmbed requires twitter.com domain
        let twitterURL = url.absoluteString
            .replacingOccurrences(of: "://x.com/", with: "://twitter.com/")
            .replacingOccurrences(of: "://mobile.x.com/", with: "://twitter.com/")
            .replacingOccurrences(of: "://mobile.twitter.com/", with: "://twitter.com/")

        guard let encodedURL = twitterURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let oembedURL = URL(string: "https://publish.twitter.com/oembed?url=\(encodedURL)") else {
            DispatchQueue.main.async { completion(MetadataResult()) }
            return
        }

        session.dataTask(with: oembedURL) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion(MetadataResult()) }
                return
            }

            let authorName = json["author_name"] as? String
            let html = json["html"] as? String ?? ""

            // Extract tweet text from <blockquote><p>...</p></blockquote>
            let tweetText = parseTweetText(from: html)

            // Build title as "@handle" or author name
            var title: String?
            if let name = authorName {
                // Try to extract @handle from the HTML (— @handle pattern)
                let handlePattern = #"&mdash; .*?\(@(\w+)\)"#
                if let regex = try? NSRegularExpression(pattern: handlePattern),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range(at: 1), in: html) {
                    title = "\(name) (@\(html[range]))"
                } else {
                    title = name
                }
            }

            // Fetch profile image: https://unavatar.io/twitter/{handle}
            let handle = extractHandle(from: url)
            if let handle = handle,
               let avatarURL = URL(string: "https://unavatar.io/twitter/\(handle)") {
                fetchThumbnail(from: avatarURL) { image in
                    let result = MetadataResult(title: title, description: tweetText, imageURL: nil, image: image)
                    DispatchQueue.main.async { completion(result) }
                }
            } else {
                let result = MetadataResult(title: title, description: tweetText)
                DispatchQueue.main.async { completion(result) }
            }
        }.resume()
    }

    /// Extract tweet text from oEmbed HTML blockquote
    private static func parseTweetText(from html: String) -> String? {
        // Pattern: <p ...>TWEET TEXT</p> inside the blockquote
        let pattern = #"<p[^>]*>(.*?)</p>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }

        // Strip HTML tags from the tweet text
        var text = String(html[range])
        let tagPattern = #"<[^>]+>"#
        if let tagRegex = try? NSRegularExpression(pattern: tagPattern) {
            text = tagRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        text = decodeHTMLEntities(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Extract @handle from a twitter/x URL path (e.g., /NASA/status/123 → "NASA")
    private static func extractHandle(from url: URL) -> String? {
        let components = url.pathComponents
        // Path is typically ["/" , "handle", "status", "id"]
        guard components.count >= 2 else { return nil }
        let handle = components[1]
        return handle.isEmpty || handle == "i" ? nil : handle
    }

    // MARK: - OG Tag Parsing

    /// Parse og:* meta tags from HTML. Returns dict like ["title": "...", "description": "...", "image": "..."]
    static func parseOGTags(from html: String) -> [String: String] {
        var tags: [String: String] = [:]

        // Pattern 1: property="og:X" ... content="Y"
        let pattern1 = #"<meta\s+[^>]*?property\s*=\s*["']og:(\w+)["'][^>]*?content\s*=\s*["']([^"']*)["']"#
        // Pattern 2: content="Y" ... property="og:X" (reversed attribute order)
        let pattern2 = #"<meta\s+[^>]*?content\s*=\s*["']([^"']*)["'][^>]*?property\s*=\s*["']og:(\w+)["']"#

        if let regex1 = try? NSRegularExpression(pattern: pattern1, options: .caseInsensitive) {
            let matches = regex1.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let keyRange = Range(match.range(at: 1), in: html),
                   let valueRange = Range(match.range(at: 2), in: html) {
                    let key = String(html[keyRange]).lowercased()
                    if tags[key] == nil { // first occurrence wins
                        tags[key] = String(html[valueRange])
                    }
                }
            }
        }

        if let regex2 = try? NSRegularExpression(pattern: pattern2, options: .caseInsensitive) {
            let matches = regex2.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let valueRange = Range(match.range(at: 1), in: html),
                   let keyRange = Range(match.range(at: 2), in: html) {
                    let key = String(html[keyRange]).lowercased()
                    if tags[key] == nil {
                        tags[key] = String(html[valueRange])
                    }
                }
            }
        }

        return tags
    }

    /// Parse twitter:* meta tags (name="twitter:title" content="...") as fallback
    static func parseTwitterTags(from html: String) -> [String: String] {
        var tags: [String: String] = [:]
        // name="twitter:X" ... content="Y"
        let pattern1 = #"<meta\s+[^>]*?name\s*=\s*["']twitter:(\w+)["'][^>]*?content\s*=\s*["']([^"']*)["']"#
        let pattern2 = #"<meta\s+[^>]*?content\s*=\s*["']([^"']*)["'][^>]*?name\s*=\s*["']twitter:(\w+)["']"#

        for (pattern, keyGroup, valueGroup) in [(pattern1, 1, 2), (pattern2, 2, 1)] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
                    if let keyRange = Range(match.range(at: keyGroup), in: html),
                       let valueRange = Range(match.range(at: valueGroup), in: html) {
                        let key = String(html[keyRange]).lowercased()
                        if tags[key] == nil { tags[key] = String(html[valueRange]) }
                    }
                }
            }
        }
        return tags
    }

    /// Fallback: parse <title>...</title>
    static func parseHTMLTitle(from html: String) -> String? {
        let pattern = #"<title[^>]*>([^<]+)</title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        let title = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : decodeHTMLEntities(title)
    }

    // MARK: - Image Fetching

    private static func fetchThumbnail(from url: URL, completion: @escaping (NSImage?) -> Void) {
        session.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = NSImage(data: data) else {
                completion(nil)
                return
            }
            completion(resizeImage(image, to: NSSize(width: 32, height: 32)))
        }.resume()
    }

    private static func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let resized = NSImage(size: size)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        return resized
    }

    private static func resolveURL(_ string: String, relativeTo base: URL) -> URL? {
        if string.hasPrefix("http://") || string.hasPrefix("https://") {
            return URL(string: string)
        }
        if string.hasPrefix("//") {
            return URL(string: "https:" + string)
        }
        return URL(string: string, relativeTo: base)
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&#x27;", "'"), ("&#x2F;", "/"), ("&nbsp;", " "),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }
}
