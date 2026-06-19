# Lyro (macOS)

A lightweight, always-on-top overlay that reads whatever is playing in the **Spotify Mac app** and shows **time-synced, karaoke-style lyrics** on screen.

- **Always on top:** Floating, click-through, translucent card pinned to your screen. Lives on all Spaces and over full-screen apps.
- **Free Lyrics:** Fetches synced lyrics automatically (no API key required).
- **Unobtrusive:** Menu-bar icon for controls. No Dock icon clutter.

## Build & Run

Requires the Swift toolchain (Xcode or Command Line Tools) and macOS 13+.

```bash
./run.sh
```
*(This automatically builds the app, installs it to your `/Applications` folder, and launches it).*

## Permissions

The first time you run it, macOS will ask for permission to read from Spotify:
> **"Lyro" wants to control "Spotify".**

Click **OK**. 
*(If you accidentally decline: go to System Settings ▸ Privacy & Security ▸ Automation, and enable Spotify under Lyro).*

## Controls

Click the menu-bar icon (♫) to access all settings:
- **Click-through (lock):** Uncheck to drag the card to a new spot. Check to lock it and click through the overlay.
- **Position & Size:** Snap the card to a 3x3 grid or drag it anywhere. Adjust the slider to scale text up or down.
- **Background Opacity:** Fade the frosted card from solid down to fully see-through.
- **Show Track Name:** Toggle the "Title — Artist" header line on or off.

*(Your size, opacity, visibility, and position preferences are automatically remembered across relaunches).*
