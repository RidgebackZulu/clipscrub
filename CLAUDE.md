# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ClipScrub — a macOS menu bar utility (NSStatusItem) that monitors the clipboard and automatically strips tracking parameters from copied URLs. Native Swift + AppKit, no SwiftUI. See `PRD-ClipScrub.md` for the full product requirements.

## Key Constraints

- **AppKit only** — no SwiftUI, no Electron, no Python
- **LSUIElement = true** — no Dock icon, no main window
- **macOS 13+ (Ventura)**, Apple Silicon (arm64)
- **No networking, analytics, telemetry, or file I/O during normal operation**
- Clipboard polling via `DispatchSourceTimer` on a background queue (not `NSTimer`), 1-second interval, checking `NSPasteboard.general.changeCount`
- After writing a cleaned URL back to clipboard, increment internal changeCount tracker to avoid re-processing own writes
- Set `queryItems = nil` (not `[]`) when all params are removed — `[]` leaves a trailing `?`
- Domain-scoped params (e.g., `s` and `t` only on twitter.com/x.com) stored in `Dictionary<String, Set<String>>`; global params in `Set<String>`

## Build

```bash
# Xcode
xcodebuild -project ClipScrub.xcodeproj -scheme ClipScrub -configuration Release build

# Or if using SPM
swift build -c release

# Ad-hoc signing for local use
codesign -s - ClipScrub.app
```

## Architecture

```
Sources/
  AppDelegate.swift          — Entry point, NSApplication setup
  StatusBarController.swift  — NSStatusItem, menu construction
  ClipboardMonitor.swift     — DispatchSourceTimer, changeCount polling
  URLSanitizer.swift         — Pure function: URL string → cleaned URL string
  HistoryManager.swift       — Fixed-size ring buffer (10 entries)
  SleepWakeHandler.swift     — NSWorkspace sleep/wake notification observers
  LaunchAgentManager.swift   — Install/remove ~/Library/LaunchAgents plist
```

- `URLSanitizer` is a pure function with no side effects — ideal for unit testing
- `ClipboardMonitor` owns the timer and coordinates with `URLSanitizer` and `HistoryManager`
- Sleep/wake pauses and resumes monitoring (2-second delay on wake)

## Performance Targets

| Metric | Target |
|--------|--------|
| Idle CPU | 0.0% |
| Memory (RSS) | < 15 MB |
| Binary size | < 5 MB |
| URL clean time | < 5ms |
