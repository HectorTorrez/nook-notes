<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="Blink icon">
</p>

<h1 align="center">Blink</h1>

<p align="center">A tiny, glassy, floating notes window for macOS. Open it, jot it down, get back to work.</p>

<p align="center">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-yellow.svg"></a>
</p>

---

## Features

**Writing**
- Rich text with headings, bold, italic, underline, strikethrough, inline code, block quotes, links, and three list styles (bullet, numbered, checklist).
- Markdown input shortcuts: type `# `, `- `, `1. `, or `[] ` at the start of a line.
- Click a checklist marker to check or uncheck it.
- Find in the current note (`⌘F`), continuous spell checking, smart punctuation, and autocorrect — all configurable.
- Undo/redo for typing **and formatting**, plus Clear Formatting.
- Text size 12–28 pt, font family (System, Serif, Rounded, Monospaced), accent colors, and adjustable glass opacity.

**Organizing**
- Workspaces keep separate sets of notes; existing notes start in **Personal**.
- Pin notes, duplicate them, move them between workspaces, and cycle with `⌥⌘↑` / `⌥⌘↓`.
- Search the current workspace or every workspace from the notes browser.
- Deleted notes go to a persistent Trash. Restore them, delete permanently, or empty the trash.
- Notes sort pinned-first, then by most recently edited.

**macOS integration**
- Floating window with an optional always-on-top toggle.
- Global `⌃⌥B` shortcut to show/hide Blink from anywhere.
- Menu bar extra for Show Blink, New Note, Settings, and Quit.
- Launch at login.
- Window position and size persist across launches.

**Your data**
- Notes autosave to a single local JSON file.
- Daily backups (14 days) before overwriting.
- Corrupt files are moved aside, never overwritten; storage errors are visible in the app.
- Export a note or all notes as Markdown, RTF, or HTML; import Markdown, text, RTF, and HTML.
- Copy Note preserves rich formatting; Copy as Markdown (⇧⌘M) produces GitHub-flavored Markdown.
- No accounts, no telemetry, no network calls.

## Install

### Download

1. Download `Blink.zip` from the [latest release](https://github.com/HectorTorrez/nook-notes/releases/latest).
2. Unzip it and drag **Blink.app** into your **Applications** folder.
3. If macOS blocks an unnotarized build, either:
   - Right-click **Blink.app** → **Open** → **Open**, or
   - Run `xattr -dr com.apple.quarantine /Applications/Blink.app` in Terminal.

Maintainers can produce a signed, notarized, and stapled build with
[`RELEASING.md`](RELEASING.md).

### Build from source

Requires Xcode 26 or later.

```bash
git clone https://github.com/HectorTorrez/nook-notes.git
cd nook-notes
./apps/macos/scripts/install.sh
```

The script builds a Release version and copies it to `/Applications/Blink.app`.
Set `INSTALL_DIR` to install somewhere else, for example
`INSTALL_DIR=~/Applications ./apps/macos/scripts/install.sh`.

## Where your notes live

Blink stores every workspace, note, and trash entry in:

```
~/Library/Application Support/Blink/notes.json
```

Daily backups are written to:

```
~/Library/Application Support/Blink/Backups/notes-YYYY-MM-DD.json
```

If the main file cannot be read, Blink moves it aside as
`notes.corrupt-<timestamp>.json` and tells you where it went. If it cannot even
move the file, saving is blocked so nothing is overwritten.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Actions panel | `⌘K` |
| New note | `⌘N` |
| Browse notes | `⌘P` |
| Duplicate note | `⇧⌘D` |
| Copy note (rich + plain) | `⇧⌘C` |
| Copy as Markdown | `⇧⌘M` |
| Delete note → Trash | `⇧⌘⌫` |
| Trash panel | `⌥⌘T` |
| Pin/unpin note | `⌥⌘P` |
| Next/previous note | `⌥⌘↓` / `⌥⌘↑` |
| Workspaces | `⇧⌘O` |
| Show/hide Blink globally | `⌃⌥B` |
| Bold / italic / underline | `⌘B` / `⌘I` / `⌘U` |
| Strikethrough | `⇧⌘S` |
| Heading 1/2/3 | `⌥⌘1` / `⌥⌘2` / `⌥⌘3` |
| Bullet / numbered / task list | `⇧⌘8` / `⇧⌘7` / `⇧⌘9` |
| Toggle checklist | `⌃⌘K` |
| Clear formatting | `⌥⌘C` |
| Increase/decrease indent | `⌘]` / `⌘[` |
| Find / find next / find previous | `⌘F` / `⌘G` / `⇧⌘G` |
| Increase/decrease/actual text size | `⌘=` / `⌘-` / `⌘0` |

## Development

Open `apps/macos/Blink.xcodeproj` in Xcode and press **Run**.

Run the unit tests locally before merging (there is no hosted CI gate):

```bash
./apps/macos/scripts/test.sh
```

The suite covers storage/backups, trash, editor formatting and undo,
Markdown import/export, paste sanitization, and note/workspace state.

To regenerate the app icon after editing the drawing code:

```bash
swift apps/macos/scripts/generate-icon.swift
```

To package a local release zip:

```bash
./apps/macos/scripts/install.sh --zip   # writes apps/macos/dist/Blink.zip
```

For a signed, notarized, stapled release, see [`RELEASING.md`](RELEASING.md).

## Project structure

```
.
├── apps/
│   ├── macos/          # Blink macOS app (SwiftUI + AppKit editor)
│   │   ├── Blink/      # App sources, settings, editor, and assets
│   │   ├── BlinkTests/ # Swift Testing coverage
│   │   ├── Blink.xcodeproj
│   │   └── scripts/    # install, test, release, icon generation
│   └── landing/        # Static landing page
├── assets/             # Shared brand assets
├── RELEASING.md
└── LICENSE
```

## License

[MIT](LICENSE).
