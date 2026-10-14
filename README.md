<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="Blink icon">
</p>

<h1 align="center">Blink</h1>

<p align="center">A tiny, glassy, floating notes window for macOS. Open it, jot it down, get back to work.</p>

---

## Features

- Minimal translucent window that stays out of your way
- Workspaces keep separate sets of notes. Existing notes start in Personal
- Multiple notes with quick search and switching
- Adjustable accent color, font size, and background opacity
- Keyboard-first: `⌘K` opens the action panel for creating, browsing, copying, deleting, and restoring notes
- Notes save automatically as you type

## Where your notes live

Blink stores every workspace and its notes in a single JSON file on your Mac:

```
~/Library/Application Support/Blink/notes.json
```

Back it up, sync it, or delete it to start fresh. If the file ever becomes unreadable, Blink moves it aside as `notes.corrupt-<timestamp>.json` instead of overwriting it.

## Requirements

- macOS 15 (Sequoia) or later
- Apple Silicon or Intel Mac

## Install

### Option 1: Download

1. Download `Blink.zip` from the [latest release](https://github.com/HectorTorrez/nook-notes/releases/latest).
2. Unzip it and drag **Blink.app** into your **Applications** folder.
3. Blink isn't notarized by Apple yet, so the first time you open it macOS will block it. Either:
   - Right-click **Blink.app** → **Open** → **Open**, or
   - Run `xattr -dr com.apple.quarantine /Applications/Blink.app` in Terminal.

### Option 2: Build from source

Requires Xcode 26 or later.

```bash
git clone https://github.com/HectorTorrez/nook-notes.git
cd nook-notes
./apps/macos/scripts/install.sh
```

The script builds a Release version and copies it to `/Applications/Blink.app`. Set `INSTALL_DIR` to install somewhere else, for example `INSTALL_DIR=~/Applications ./apps/macos/scripts/install.sh`.

## Development

Open `apps/macos/Blink.xcodeproj` in Xcode and press **Run**.

To regenerate the app icon after editing the drawing code:

```bash
swift apps/macos/scripts/generate-icon.swift
```

To package a universal `Blink.zip` for a release:

```bash
./apps/macos/scripts/install.sh --zip   # writes apps/macos/dist/Blink.zip
```

## Project structure

```
.
├── apps/
│   ├── macos/          # Blink macOS app (SwiftUI)
│   │   ├── Blink/      # App sources and assets
│   │   ├── Blink.xcodeproj
│   │   └── scripts/    # install + icon generation
│   └── landing/        # Landing page (coming soon)
└── assets/             # Shared brand assets
```
