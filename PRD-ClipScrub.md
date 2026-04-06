# PRD: ClipScrub — macOS Clipboard URL Sanitizer

## Overview

ClipScrub is a lightweight macOS menu bar utility that monitors the system clipboard in real-time and automatically strips tracking parameters (UTM tags, `fbclid`, `igsh`, etc.) from copied URLs. It runs as a persistent background daemon with a native macOS status bar (menu bar) icon providing clipboard history, controls, and settings.

**Target platform:** macOS 13+ (Ventura and later), Apple Silicon (arm64). Intel compatibility is nice-to-have but not required.

**Language:** Swift. Use AppKit directly — no SwiftUI, no Electron, no Python. This must be a native compiled binary for minimal resource usage.

---

## Goals

1. Zero-friction URL cleaning — user copies a link, the clipboard silently contains the clean version within milliseconds.
2. Extremely low CPU/memory footprint — undetectable in Activity Monitor during idle; negligible spike when processing a copy event.
3. Native macOS citizen — menu bar icon, proper sleep/wake handling, LaunchAgent auto-start, no Dock icon.

---

## Architecture

### Application Type

- **macOS menu bar app (LSUIElement = true)** — no Dock icon, no main window. The only UI is the NSStatusItem menu bar icon and its dropdown menu.
- Distributed as a standalone `.app` bundle that the user drags to `/Applications/`.
- A companion LaunchAgent plist handles auto-start on login.

### Clipboard Monitoring Strategy

**Do NOT use a tight polling loop.** Use the following approach:

1. Use `NSPasteboard.general.changeCount` to detect clipboard changes.
2. Poll `changeCount` on a **1-second `DispatchSourceTimer`** (not `Timer` — it doesn't fire during menu tracking).
3. Only perform work when `changeCount` has incremented since last check.
4. When a change is detected:
   - Read the clipboard string.
   - Check if it matches a URL pattern (starts with `http://` or `https://`, or matches a known short-domain pattern).
   - If it's a URL, run it through the sanitizer.
   - If the sanitizer modified the URL, write the clean URL back to the clipboard and increment the internal `changeCount` tracker to avoid re-processing our own write.
   - Log the clean URL to the history ring buffer (max 10 entries).
   - If the sanitizer did NOT modify the URL (no tracking params found), do nothing — do not write back to clipboard, do not add to history.
5. If the clipboard content is not a URL, ignore it entirely. Never touch non-URL clipboard content.

### Sleep/Wake Handling

- Subscribe to `NSWorkspace.willSleepNotification` and `NSWorkspace.didWakeNotification`.
- On `willSleep`: pause the `DispatchSourceTimer`. Set an internal `isPaused = true` flag.
- On `didWake`: resume the timer after a 2-second delay (allow the system to stabilize). Re-read `changeCount` to avoid processing stale data. Set `isPaused = false`.
- The menu bar icon should visually indicate paused state (e.g., grayed-out icon or a small "zzz" badge).

### Power/Lid Close

macOS `willSleepNotification` fires when the lid is closed (which triggers system sleep). This covers the lid-close requirement. No additional handling is needed beyond the sleep/wake notifications above.

---

## URL Sanitizer Engine

### Parameters to Strip

Remove these query parameters (case-insensitive match on parameter name):

**Universal trackers:**
- `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content`, `utm_id`, `utm_source_platform`, `utm_creative_format`, `utm_marketing_tactic`

**Platform-specific:**
- Facebook/Meta: `fbclid`, `fb_action_ids`, `fb_action_types`, `fb_ref`, `fb_source`
- Instagram: `igsh`, `igshid`, `ig_rid`, `ig_mid`
- Twitter/X: `s` (only on `x.com` or `twitter.com` domains), `t` (only on `x.com` or `twitter.com` domains), `ref_src`, `ref_url`
- Google: `gclid`, `gclsrc`, `dclid`, `gs_lcp`, `gs_mss`, `ei`, `sei`, `ved`, `uact`, `oq`, `sclient`, `sourceid`, `sxsrf`, `source`, `biw`, `bih`
- TikTok: `_t`, `_r`, `is_from_webapp`, `sender_device`, `is_copy_url`
- YouTube: `si`, `feature`, `pp`, `embeds_referring_euri`, `source_ve_path`
- LinkedIn: `trackingId`, `refId`, `trk`, `lipi`, `lici`
- Microsoft: `msclkid`, `ocid`, `cvid`
- Reddit: `share_id`, `ref`, `ref_source`
- General: `mc_cid`, `mc_eid` (Mailchimp), `oly_enc_id`, `oly_anon_id` (Omeda/Olytics), `vero_id`, `_hsenc`, `_hsmi` (HubSpot), `mkt_tok` (Marketo), `wickedid`, `twclid`

### Sanitizer Rules

1. Parse the URL using `URLComponents`.
2. Remove matching query parameters from `queryItems`.
3. If `queryItems` is now empty, remove the `?` entirely (set `queryItems = nil`, not `queryItems = []` — the latter leaves a trailing `?` in Swift).
4. If the URL has a fragment (`#`) that appears to be tracking (e.g., contains only base64-like characters after the `#`), leave it alone — fragments are often needed for page navigation. Only strip fragments if they match known tracking patterns.
5. Return the cleaned URL string.
6. **Domain-scoped parameters:** Some parameters like `s` and `t` are too generic to strip globally. Only strip these when the URL domain matches the associated platform (see list above).

### URL Detection Heuristic

A clipboard string is treated as a URL if:
- It starts with `http://` or `https://`
- OR it matches a known short-URL domain pattern (`t.co/`, `bit.ly/`, `goo.gl/`, `youtu.be/`, `redd.it/`, `vm.tiktok.com/`)

Do NOT attempt to sanitize non-URL clipboard content. Do NOT attempt to resolve short URLs — just clean their parameters if present.

---

## Menu Bar UI

### Icon

- Use an `NSStatusItem` with a template image (so it auto-adapts to light/dark mode).
- Icon design: a small clipboard with a sparkle/checkmark, or a simple link chain icon. Use an SF Symbol if a suitable one exists (`link`, `link.badge.plus`, `clipboard`, etc.). Prefer `paperclip` or `link` SF Symbol as the base.
- **Active state:** normal icon appearance.
- **Paused state:** icon should appear dimmed/grayed or have a small pause indicator.

### Dropdown Menu Structure

When the user clicks the menu bar icon, show this menu:

```
──────────────────────────────────
ClipScrub                    v1.0
──────────────────────────────────
✓ Running                [status]
  12 URLs cleaned today  [counter]
──────────────────────────────────
Recent Cleaned URLs:
  1. instagram.com/reel/DWtq4d0g...   [copy]
  2. x.com/elonmusk/status/18392...   [copy]
  3. youtube.com/watch?v=dQw4w9W...   [copy]
  ...up to 10 items
──────────────────────────────────
⏸ Pause ClipScrub  /  ▶ Resume
──────────────────────────────────
Settings                       ▶
  ☑ Launch at Login
  ☑ Sound on Clean (subtle tick)
  Show Full URLs / Truncated
──────────────────────────────────
Help                           ▶
  How to Uninstall
  About ClipScrub
──────────────────────────────────
Quit ClipScrub
──────────────────────────────────
```

### Menu Behaviors

**Status section:**
- Show "Running" or "Paused" with appropriate icon/color.
- Show daily cleaned URL count (resets at midnight). Store in-memory only, no persistence needed.

**Clipboard History (Recent Cleaned URLs):**
- Show the last 10 cleaned URLs.
- Each entry shows the domain + truncated path (max ~40 chars), with the full clean URL as the tooltip on hover.
- Clicking an entry copies the clean URL back to the clipboard.
- If no URLs have been cleaned yet, show "No URLs cleaned yet" in gray/disabled text.
- History is in-memory only — cleared on app quit. No persistence between sessions.

**Pause/Resume:**
- Toggles the clipboard monitoring on/off.
- Updates the menu item text and the status bar icon appearance.
- When paused, the timer continues to run but the handler skips processing (to allow instant resume without timer teardown/setup).

**Settings submenu:**
- **Launch at Login:** Toggle installs/removes the LaunchAgent plist at `~/Library/LaunchAgents/com.clipscrub.agent.plist`. The plist should point to the app's executable.
- **Sound on Clean:** When enabled, play a very subtle system sound (`NSSound(named: "Tink")` or similar) when a URL is cleaned. Default: ON.
- **Show Full URLs / Truncated:** Toggle between showing full clean URLs vs truncated versions in the history list. Default: Truncated.

**Help submenu:**
- **How to Uninstall:** Show an alert dialog with these steps:
  1. Click "Quit ClipScrub" from the menu bar
  2. Remove ClipScrub.app from /Applications
  3. Delete `~/Library/LaunchAgents/com.clipscrub.agent.plist`
  4. (Optional) Offer a "Remove LaunchAgent Now" button that deletes the plist for them.
- **About ClipScrub:** Standard macOS about panel with version number.

**Quit:**
- Gracefully stop the timer, clean up, and call `NSApp.terminate(nil)`.

---

## Performance Requirements

These are hard requirements, not guidelines.

| Metric | Target |
|--------|--------|
| Idle CPU | 0.0% (timer fires once/sec, checks one integer, returns) |
| CPU during URL clean | < 0.1% spike, < 5ms wall time |
| Memory (RSS) | < 15 MB |
| Startup time | < 500ms to menu bar icon visible |
| Binary size | < 5 MB |
| Battery impact | Undetectable — should never appear in "Apps Using Significant Energy" |

### Performance Implementation Notes

- The 1-second poll interval is the right balance. Do NOT poll faster than 1 second.
- `changeCount` is an integer comparison — effectively free.
- URL parsing with `URLComponents` is lightweight and does not allocate heavily.
- The parameter strip list should be stored in a `Set<String>` for O(1) lookup.
- Domain-scoped parameters should be stored in a `Dictionary<String, Set<String>>` mapping domain patterns to parameter sets.
- History is a fixed-size ring buffer (array of 10 structs), not a growing array.
- No networking. No analytics. No telemetry. No update checks. No file I/O during normal operation.
- Do not use `NSTimer` on the main run loop — use `DispatchSourceTimer` on a background queue so the timer fires even during menu interaction.

---

## Build & Distribution

### Build
- Xcode project or Swift Package Manager — either is fine.
- Minimum deployment target: macOS 13.0 (Ventura).
- Architecture: arm64 (Apple Silicon). Universal binary is nice-to-have.
- Sign with ad-hoc signature (`codesign -s -`) for local use. No notarization required for personal use.
- Hardened runtime should be enabled.

### Project Structure

```
ClipScrub/
├── ClipScrub.xcodeproj (or Package.swift)
├── Sources/
│   ├── AppDelegate.swift          # Entry point, NSApplication setup
│   ├── StatusBarController.swift  # NSStatusItem, menu construction
│   ├── ClipboardMonitor.swift     # DispatchSourceTimer, changeCount polling
│   ├── URLSanitizer.swift         # Pure function: URL string → cleaned URL string
│   ├── HistoryManager.swift       # Ring buffer of last 10 cleaned URLs
│   ├── SleepWakeHandler.swift     # NSWorkspace notification observers
│   └── LaunchAgentManager.swift   # Install/remove LaunchAgent plist
├── Resources/
│   └── Assets.xcassets            # Menu bar icon (template image)
├── Info.plist                     # LSUIElement = true, bundle ID, etc.
└── README.md
```

### LaunchAgent Plist

The app should be able to generate and install this at `~/Library/LaunchAgents/com.clipscrub.agent.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clipscrub.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/ClipScrub.app/Contents/MacOS/ClipScrub</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
```

---

## Testing Checklist

Before considering this complete, verify:

- [ ] Copy a URL with `utm_source`, `utm_medium`, `utm_campaign` → clipboard contains clean URL
- [ ] Copy an Instagram reel link with `igsh` and `utm_source=ig_web_copy_link` → both params stripped, `?` removed entirely
- [ ] Copy an X/Twitter link with `?s=20&t=xxxx` → both stripped
- [ ] Copy a YouTube link with `?v=xxxx&si=yyyy` → `si` stripped, `v` preserved
- [ ] Copy a URL with no tracking params → clipboard is untouched (no rewrite)
- [ ] Copy plain text (not a URL) → clipboard is untouched
- [ ] Copy an image → clipboard is untouched
- [ ] Close laptop lid → monitor pauses (check with logging)
- [ ] Open laptop lid → monitor resumes within 3 seconds
- [ ] Click Pause → monitor stops cleaning; click Resume → monitor resumes
- [ ] Click a history item → clean URL is copied to clipboard
- [ ] History shows max 10 items, oldest drops off
- [ ] Enable "Launch at Login" → plist appears at `~/Library/LaunchAgents/`
- [ ] Disable "Launch at Login" → plist is removed
- [ ] App does not appear in Dock
- [ ] Activity Monitor shows < 15 MB memory, 0.0% CPU when idle
- [ ] Reboot → app auto-starts if Launch at Login was enabled
- [ ] Quit from menu → app exits cleanly

---

## Out of Scope (v1)

These are explicitly not part of v1. Do not build them:

- Resolving/unshortening short URLs (t.co, bit.ly, etc.)
- Configurable parameter lists in the UI (hardcode the list; it's in the source)
- Sync across devices
- Any form of networking, analytics, or telemetry
- Sparkle/auto-update framework
- Mac App Store distribution
- Notification Center alerts
- Global keyboard shortcut to manually trigger sanitization
- Persistent history across app restarts
