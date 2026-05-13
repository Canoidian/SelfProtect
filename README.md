# SelfProtect

A native macOS app blocker and website blocker. Blocks distracting websites and applications with unbreakable timers, recurring schedules, and category presets. Built with SwiftUI — no Electron, no web views, no bloat.

## Features

### Blocking
- **Websites** — dual-layer blocking via `/etc/hosts` and `pfctl` packet filter. Works across all browsers, incognito mode, and DNS-over-HTTPS.
- **Apps** — force-terminates blocked applications via `pkill` from a root-privileged daemon.
- **Category presets** — one-tap to block Social Media, Entertainment, Gaming, News, Shopping, Video Streaming, or Productivity Busters. Each preset includes 10–20+ websites and app bundle IDs.
- **Allowlist** — exclude specific websites or apps from category blocks.

### Timer & Schedule
- **Unbreakable timer** — once started, the block cannot be stopped early. No stop button. Quitting the app does nothing. Rebooting does nothing. The timer must expire.
- **Recurring schedules** — set block windows by day of week and time range. Active schedules lock themselves — can't be modified while running.
- **Schedule + timer stacking** — timer extends beyond schedule windows, schedule always takes priority.

### Pomodoro Timer
- Configurable work (1–120min) and break (1–30min) durations.
- Auto-cycling with macOS notifications and system chime.
- Menu bar countdown showing remaining time.
- Quick presets: 25min Pomodoro, 15/30/60min Focus.

### Menu Bar
- Shield icon — outline when idle, filled when blocking.
- Live countdown during blocks and Pomodoro sessions.
- Quick-start block (1h) and Pomodoro from the menu.

### Import / Export
- Export your entire configuration (websites, apps, schedules, allowlists) as a `.selfprotect` JSON file.
- Import and merge configurations from other machines.

### Persistence
- All settings saved to `~/Library/Application Support/SelfProtect/config.json`.
- Survives app deletion, updates, and reinstalls.
- Daemon stores active block state separately at `/var/db/SelfProtect/`.

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac
- Administrator access (required once for daemon installation)

## Installation

### Via .pkg (recommended)

```bash
open SelfProtect.pkg
```

Follow the installer — it copies the app to `/Applications/SelfProtect.app`.

### Via .app bundle

Drag `SelfProtect.app` to your Applications folder.

### First launch

1. Open SelfProtect.
2. A dialog will prompt for your admin password — this installs the privileged helper daemon that enforces blocking.
3. Once installed, the daemon status in the bottom-left corner shows "Daemon Connected."
4. Add websites or apps to block, or toggle a category preset, then start a timer or set up a schedule.

## Building from Source

### Prerequisites

- Xcode 16+ (Command Line Tools alone are not sufficient)
- [XcodeGen](https://github.com/nicoverbruggen/xcodegen) (optional, for `.xcodeproj` generation)

### Quick build (CLI)

```bash
./build.sh
```

Creates `SelfProtect.app` and `SelfProtect.pkg` in `.build/`.

### Xcode project

```bash
xcodegen generate
open SelfProtect.xcodeproj
```

Then select the `SelfProtect` scheme and press Cmd+B.

## Project Structure

```
SelfProtect/
├── SelfProtectKit/        # Shared Swift package
│   ├── Models/            # BlockEntry, BlockSession, BlockSchedule, BlockPreset
│   ├── IPC/               # HelperProtocol (XPC interface)
│   ├── Blocking/          # HostsManager, PFManager, AppBlocker
│   └── Presets/           # 7 category presets
├── SelfProtect/           # SwiftUI app (sandboxed UI)
│   ├── Views/             # Dashboard, Block List, Settings
│   ├── ViewModels/        # AppViewModel
│   └── Managers/          # DaemonManager (XPC), StatusBarController, CategoryProvider
├── SelfProtectHelper/     # Privileged XPC daemon (runs as root)
│   ├── main.swift         # XPC listener
│   └── Helper.swift       # Blocking enforcement, schedule evaluation
├── build.sh               # Build script for .app + .pkg
├── project.yml            # XcodeGen project specification
└── CHANGELOG.md
```

## Architecture

```
┌──────────────────────────┐     XPC (Mach Service)     ┌──────────────────────────────┐
│   SelfProtect (sandbox)  │◄──────────────────────────►│  SelfProtectHelper (daemon)   │
│   SwiftUI app            │   com.selfprotect.helper.xpc│  Runs as root via launchd     │
│   User-facing UI         │                            │  Modifies /etc/hosts + pfctl  │
│   Block list management  │                            │  Kills blocked apps (pkill)   │
└──────────────────────────┘                            └──────────────────────────────┘
                                                                       │
                                                                       ▼
                                                              launchctl bootstrap system
                                                              /Library/LaunchDaemons/
```

The helper daemon is installed to `/Library/PrivilegedHelperTools/com.selfprotect.helper` and registered as a system launch daemon. It runs independently — the app can be quit without affecting active blocks.

## Security

- The helper daemon requires admin privileges to install (one-time).
- Blocking is enforced at the kernel level (pfctl) — cannot be bypassed by browser settings, incognito mode, or DNS-over-HTTPS.
- VPN connections may bypass pfctl rules (inherent limitation shared with all network-level blockers).
- The app does not collect or transmit any data.

## License

MIT
