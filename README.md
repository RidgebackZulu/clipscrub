# ClipScrub

A macOS menu bar app that automatically strips tracking parameters from URLs you copy to the clipboard.

Copy a link riddled with `utm_source`, `fbclid`, `igsh`, etc. — ClipScrub silently replaces it with the clean version in milliseconds.

## What it strips

- **UTM tags** — `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content`, etc.
- **Facebook/Meta** — `fbclid`, `fb_action_ids`, `fb_ref`, etc.
- **Instagram** — `igsh`, `igshid`, `ig_rid`, `ig_mid`
- **Twitter/X** — `s`, `t` (domain-scoped), `ref_src`, `ref_url`
- **Google** — `gclid`, `gclsrc`, `dclid`, `ved`, `sxsrf`, `sclient`, etc.
- **TikTok** — `_t`, `_r`, `is_from_webapp`, `sender_device`
- **YouTube** — `si`, `feature`, `pp`
- **LinkedIn** — `trackingId`, `refId`, `trk`, `lipi`
- **Microsoft** — `msclkid`, `ocid`, `cvid`
- **Reddit** — `share_id`, `ref`, `ref_source`
- **Email/Marketing** — Mailchimp, HubSpot, Marketo, Olytics, etc.

Full list in [`Sources/ClipScrub/URLSanitizer.swift`](Sources/ClipScrub/URLSanitizer.swift).

## Features

- **Menu bar app** — no Dock icon, no windows. Just a link icon in your menu bar.
- **Clipboard history** — last 10 cleaned URLs with page titles, descriptions, and thumbnails (fetched from Open Graph tags).
- **Click to copy** — click any history entry to copy the clean URL.
- **Pause/Resume** — toggle monitoring on/off from the menu.
- **Launch at Login** — installs a LaunchAgent so it starts automatically.
- **Sound on Clean** — subtle tick sound when a URL is cleaned (toggleable).
- **Fetch Page Info** — fetches page title, description, and thumbnail for cleaned URLs (toggleable). Uses Twitter's oEmbed API for X/Twitter links.

## Download

**[Download ClipScrub v1.0](https://github.com/RidgebackZulu/clipscrub/releases/latest)** (Apple Silicon, 70KB zip)

### Install

1. Download `ClipScrub-v1.0-arm64.zip` from the link above
2. Double-click the zip to unzip it
3. Drag `ClipScrub.app` into your `/Applications` folder
4. Open it — if macOS says it's from an unidentified developer, right-click the app and choose **Open**, then click **Open** again in the dialog
5. A link icon appears in your menu bar — ClipScrub is now running

That's it. Copy any URL and tracking parameters are stripped automatically.

### Optional: Start at login

Click the link icon in your menu bar > **Settings** > **Launch at Login**

### Uninstall

1. Click the link icon in your menu bar > **Quit ClipScrub**
2. Delete `ClipScrub.app` from your Applications folder
3. If you enabled Launch at Login, click **Help** > **How to Uninstall** > **Remove Launch Agent Now** before quitting (or manually delete `~/Library/LaunchAgents/com.clipscrub.agent.plist`)

### Requirements

- macOS 13 (Ventura) or later
- Apple Silicon Mac (M1, M2, M3, M4)

---

## Build from source

Requires Xcode command line tools (Swift 5.9+).

```bash
./build.sh
```

This compiles a release binary, creates `ClipScrub.app`, and signs it with an ad-hoc signature.

To install manually after building:

```bash
cp -r ClipScrub.app /Applications/
open /Applications/ClipScrub.app
```

### Run tests

```bash
swift test
```

## Architecture

```
Sources/ClipScrub/
  main.swift               — Entry point
  AppDelegate.swift        — App lifecycle, wires components together
  URLSanitizer.swift       — Pure function: URL -> cleaned URL (no side effects)
  ClipboardMonitor.swift   — 1s DispatchSourceTimer polling NSPasteboard.changeCount
  MetadataFetcher.swift    — Fetches OG tags, twitter: tags, Twitter oEmbed API
  HistoryEntry.swift       — Model: url, title, description, thumbnail
  HistoryManager.swift     — Ring buffer of last 10 entries
  HistoryMenuItemView.swift — Custom NSView for rich menu items
  StatusBarController.swift — NSStatusItem menu bar UI
  SleepWakeHandler.swift   — Pauses on sleep, resumes on wake
  LaunchAgentManager.swift — Install/remove ~/Library/LaunchAgents plist
```

## How it works

1. A `DispatchSourceTimer` fires every 1 second on a background queue
2. It checks `NSPasteboard.general.changeCount` — an integer comparison, effectively free
3. If the clipboard changed, it reads the string and checks if it's a URL
4. If it's a URL, it runs it through `URLSanitizer` which strips known tracking parameters
5. If anything was stripped, it writes the clean URL back and updates the internal change counter (to avoid re-processing its own write)
6. The cleaned URL is added to history, and metadata is fetched in the background
7. Non-URL clipboard content is never touched
