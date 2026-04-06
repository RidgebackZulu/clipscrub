import Foundation

struct URLSanitizer {
    /// Parameters stripped from all URLs
    static let globalParams: Set<String> = [
        // UTM
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_source_platform", "utm_creative_format", "utm_marketing_tactic",
        // Facebook/Meta
        "fbclid", "fb_action_ids", "fb_action_types", "fb_ref", "fb_source",
        // Instagram
        "igsh", "igshid", "ig_rid", "ig_mid",
        // Twitter/X (non-domain-scoped)
        "ref_src", "ref_url",
        // Google
        "gclid", "gclsrc", "dclid", "gs_lcp", "gs_mss", "ei", "sei", "ved",
        "uact", "oq", "sclient", "sourceid", "sxsrf", "source", "biw", "bih",
        // TikTok
        "_t", "_r", "is_from_webapp", "sender_device", "is_copy_url",
        // YouTube
        "si", "feature", "pp", "embeds_referring_euri", "source_ve_path",
        // LinkedIn
        "trackingid", "refid", "trk", "lipi", "lici",
        // Microsoft
        "msclkid", "ocid", "cvid",
        // Reddit
        "share_id", "ref", "ref_source",
        // Mailchimp
        "mc_cid", "mc_eid",
        // Omeda/Olytics
        "oly_enc_id", "oly_anon_id",
        // HubSpot
        "vero_id", "_hsenc", "_hsmi",
        // Marketo
        "mkt_tok",
        // Other
        "wickedid", "twclid",
    ]

    /// Parameters stripped only when the URL matches certain domains
    static let domainScopedParams: [String: Set<String>] = [
        "twitter.com": ["s", "t"],
        "x.com": ["s", "t"],
        "mobile.twitter.com": ["s", "t"],
        "mobile.x.com": ["s", "t"],
    ]

    /// Returns the cleaned URL string, or nil if no changes were needed.
    static func sanitize(_ urlString: String) -> String? {
        guard var components = URLComponents(string: urlString) else { return nil }
        guard let queryItems = components.queryItems, !queryItems.isEmpty else { return nil }

        let host = components.host?.lowercased() ?? ""

        // Build set of params to remove for this URL
        var paramsToRemove = globalParams

        for (domain, params) in domainScopedParams {
            if host == domain || host.hasSuffix(".\(domain)") {
                paramsToRemove.formUnion(params)
            }
        }

        let cleaned = queryItems.filter { item in
            !paramsToRemove.contains(item.name.lowercased())
        }

        // Nothing was removed
        if cleaned.count == queryItems.count { return nil }

        // Set nil (not []) to avoid trailing `?`
        components.queryItems = cleaned.isEmpty ? nil : cleaned

        return components.string
    }

    /// Check if a string looks like a URL we should try to sanitize
    static func isURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return true
        }
        let shortDomains = ["t.co/", "bit.ly/", "goo.gl/", "youtu.be/", "redd.it/", "vm.tiktok.com/"]
        return shortDomains.contains { trimmed.hasPrefix($0) }
    }
}
