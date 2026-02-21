# ZoomIt for Mac

A free, open-source macOS presentation toolkit inspired by Microsoft's [ZoomIt](https://learn.microsoft.com/en-us/sysinternals/downloads/zoomit) for Windows. Zoom, annotate, time your breaks, and auto-type demo code — all from your menu bar.

> **Note:** This is an unofficial, community-built tool. It is not affiliated with or endorsed by Microsoft. "ZoomIt" is a Microsoft Sysinternals tool created by Mark Russinovich.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🔍 Zoom (macOS Built-In)
ZoomIt for Mac leverages macOS Accessibility Zoom for smooth screen magnification.

**One-time setup:** System Settings → Accessibility → Zoom → enable "Use keyboard shortcuts to zoom"

| Shortcut | Action |
|----------|--------|
| **⌥⌘8** | Toggle zoom on/off |
| **⌥⌘=** | Zoom in |
| **⌥⌘−** | Zoom out |
| **Ctrl+Scroll** | Smooth zoom |

### ✏️ Draw Mode (`Ctrl+1`)
Draw on your screen with a transparent overlay — perfect for highlighting code or UI during presentations.

- **Drawing tools:** Arrow (key `1`), Rectangle (key `2`), Freeform pen (key `3`)
- **Colors:** `R` Red, `B` Blue, `G` Green, `P` Purple
- **Ctrl+Z** to undo, **E** to erase all
- Press **Esc** to exit

### ⏱️ Break Timer (`Ctrl+2`)
Full-screen countdown timer with a circular progress ring.

- Enter duration in minutes when prompted
- Color changes as time runs down (blue → yellow → red)
- **Ctrl+↑/↓** to adjust time while running
- Press **Esc** to dismiss early

### ⌨️ DemoType (`Ctrl+3`)
Pre-load text snippets and paste them one block at a time into any app — great for live coding demos.

1. Create a text file with `[start]...[end]` blocks:
   ```
   [start]
   console.log("Hello, World!");
   [end]
   [start]
   const greeting = (name) => `Hello, ${name}!`;
   [end]
   ```
2. Set the file path in **Settings**
3. Place your cursor in any text input (editor, terminal, browser, etc.)
4. Press **Ctrl+3** — the first block is copied to your clipboard
5. Press **⌘V** to paste, then **Ctrl+3** for the next block
6. Press **Esc** to cancel at any time

### ⚙️ Menu Bar App
- Lives in the macOS menu bar — no Dock icon, always accessible
- Quick access to all modes and settings from the status menu

## Installation

### Option 1: Download (Easiest)
1. Go to [Releases](../../releases) and download the latest `.zip`
2. Unzip and drag **ZoomIt for Mac.app** to your Applications folder
3. Right-click → **Open** on first launch (required for unsigned apps)

### Option 2: Build from Source
Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/aprildunnam/zoomit-for-mac.git
cd zoomit-for-mac
chmod +x build.sh
./build.sh
```

This creates `ZoomIt for Mac.app` in the project directory.

```bash
# Run directly
open "ZoomIt for Mac.app"

# Or install to Applications
cp -r "ZoomIt for Mac.app" /Applications/
```

## Requirements

- **macOS 13.0** (Ventura) or later
- **Accessibility Zoom** — enable in System Settings → Accessibility → Zoom (for zoom features)

## Keyboard Shortcut Reference

| Mode | Shortcut | Notes |
|------|----------|-------|
| Zoom On/Off | `⌥⌘8` | macOS built-in |
| Zoom In/Out | `⌥⌘=` / `⌥⌘−` | macOS built-in |
| Smooth Zoom | `Ctrl+Scroll` | macOS built-in |
| Draw Mode | `Ctrl+1` | |
| Break Timer | `Ctrl+2` | |
| DemoType | `Ctrl+3` | |
| Cancel/Exit | `Esc` | Works in all modes |

## Security & Privacy

- **Fully offline** — ZoomIt for Mac makes no network connections and collects no data
- **Clipboard access** — DemoType copies text blocks to your clipboard so you can paste them. Your previous clipboard contents are restored when you press Esc
- **Unsandboxed** — required for system-wide keyboard shortcuts and AppleScript integration. The app only reads the DemoType text file you configure in Settings
- **No Accessibility required** — keyboard shortcuts use Carbon APIs that work without Accessibility permission. DemoType uses clipboard mode by default (copy + you paste with ⌘V)

## Troubleshooting

### "ZoomIt for Mac" can't be opened because Apple cannot check it for malicious software
This happens because the app is not notarized with an Apple Developer certificate. To open it:
1. **Right-click** (or Control-click) the app → choose **Open**
2. Click **Open** in the dialog that appears
3. You only need to do this once — macOS remembers your choice

Alternatively: System Settings → Privacy & Security → scroll down → click **Open Anyway**.

### Global shortcuts not working
Make sure no other app is using `Ctrl+1`, `Ctrl+2`, or `Ctrl+3`. Some apps (like certain IDEs) may capture these shortcuts.

### Zoom not working
Zoom uses macOS built-in Accessibility Zoom, which must be enabled once:
1. System Settings → Accessibility → Zoom
2. Enable **"Use keyboard shortcuts to zoom"**

## How It Works

ZoomIt for Mac is a pure Swift/AppKit application. It uses:
- **Carbon `RegisterEventHotKey`** for system-wide keyboard shortcuts (works without Accessibility permission)
- **macOS Accessibility Zoom** for screen magnification (built into the OS)
- **NSWindow overlays** for drawing annotations
- **NSPasteboard** for DemoType clipboard integration

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Disclaimer

This project is not affiliated with, endorsed by, or connected to Microsoft or Microsoft Sysinternals. It is an independent, open-source tool inspired by the functionality of the Windows ZoomIt utility.
