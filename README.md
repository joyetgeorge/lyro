# Lyro (macOS)

A lightweight, always-on-top overlay that reads whatever is playing in the
**Spotify Mac app** and shows **time-synced, karaoke-style lyrics** on screen.

- Native Swift (AppKit + SwiftUI), no Xcode project required.
- Reads the current track + playhead from Spotify over AppleScript.
- Fetches synced (LRC) lyrics from [lrclib.net](https://lrclib.net) — free, no API key.
- Floating, click-through, translucent card pinned to the bottom (or top) of the
  screen; lives on all Spaces and over full-screen apps.
- Menu-bar icon (♫) for all controls. No Dock icon.

## Build & run

```bash
./run.sh          # builds, installs to /Applications, and launches
# or
./build.sh        # just builds Lyro.app (no install)
open Lyro.app
```

`run.sh` copies the built app to `/Applications` (falling back to
`~/Applications`), registers it with Launch Services, and launches that copy —
so it's discoverable in Spotlight & Launchpad.

Requires the Swift toolchain (Xcode or Command Line Tools) and macOS 13+.

## Reopening after quitting

The app lives in the menu bar only (no Dock icon), so after **Quit** you reopen
it like any other app: search for **Lyro** in **Spotlight** /
**Launchpad**, or double-click it in `/Applications`. It carries a proper app
icon so it's easy to spot.

> **Not showing in Spotlight?** It is *not* marked `LSUIElement` (that flag would
> hide it from Spotlight), so the usual cause is a stale system index. Rebuild it
> with `sudo mdutil -i on /System/Volumes/Data && sudo mdutil -E /System/Volumes/Data`.

## First-run permission

The first time it runs, macOS shows:

> **"Lyro" wants to control "Spotify".**

Click **OK**. (If you miss it: System Settings ▸ Privacy & Security ▸
**Automation** ▸ enable Spotify under Lyro, then choose
**Reload Lyrics** from the menu-bar icon.)

No permission is needed for network access or the overlay window itself.

## Menu-bar controls (♫ icon)

| Item | Effect |
|------|--------|
| *(top two rows)* | Current track + lyrics status |
| **Click-through (lock)** | When checked, mouse clicks pass through the overlay. Uncheck to drag the card to a new spot. |
| **Show Track Name** | Toggle the "Title — Artist" header line on or off. |
| **Position** | Snap the card to any of nine screen positions (a 3×3 grid). Or uncheck the lock and drag it anywhere — your spot is remembered across relaunches. |
| **Size** | Slider to scale the whole card (and its text) larger or smaller. |
| **Background Opacity** | Slider to fade the frosted card from solid down to fully see-through (just floating lyrics). |
| **Reload Lyrics** (⌘R) | Re-fetch lyrics for the current track. |
| **Quit Lyro** (⌘Q) | Exit. |

All of these (size, opacity, track-name visibility, position) are remembered
across relaunches.

The active lyric line animates with a spring-driven slide, scale, and gradient
pop as the song advances, so it stays lively and easy to follow.

## How it works

- `SpotifyController` polls Spotify once a second via `osascript`
  (`player state`, `current track`, `player position`).
- `LyricsService` requests lyrics from lrclib's `/api/get` (exact signature
  match), falling back to `/api/search` when that misses, then parses the LRC
  timestamps.
- `LyricsViewModel` anchors the last known playhead to a monotonic clock and
  interpolates 10×/second, so the highlighted line stays in sync between polls.
- `OverlayView` (SwiftUI) renders previous / current / next lines in a
  translucent card; `AppDelegate` hosts it in a borderless, screen-saver-level
  `NSWindow`.
