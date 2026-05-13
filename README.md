# SelfProtect

A native macOS blocker for distracting websites and applications. Unbreakable timers, recurring schedules, Pomodoro focus sessions, category presets, and per-item allowlists — all behind a single menu bar icon. Built with SwiftUI — no Electron, no WebKit, no bloat.

## Features

### Blocking Engine

| Layer | Method | Bypass Resistance |
|---|---|---|
| **Websites** | `/etc/hosts` (DNS) + `pfctl` (kernel packet filter) | Survives browser DoH, incognito, and reboot |
| **Apps** | `pkill` from root-privileged daemon | Cannot be escaped while daemon runs |
| **DNS Cache** | `dscacheutil -flushcache; killall -HUP mDNSResponder` | Immediate生效 |

The daemon re-enforces blocking every 5 seconds — killed apps stay killed.

### Timer Blocks
- Set a duration (slider or presets: 30m / 1h / 2h / 4h / 8h)
- **No stop button** — once started, the block cannot be interrupted. Quitting the app, force-killing the process, or rebooting does nothing. The timer must expire.
- During an active block, category toggles are disabled and adding new items requires a confirmation dialog.
- Timer and schedule stacking: timer extends beyond schedule windows; schedule always takes priority.

### Recurring Schedules
- Define block windows by day of week + time range (e.g. Mon–Fri 9:00–17:00)
- Active schedules **lock themselves** — cannot be modified, toggled, or deleted while running
- Schedules use your current block configuration (websites, apps, categories, allowlists). Changes sync automatically to the daemon.
- Multiple schedules supported simultaneously.

### Category Presets
Seven one-tap presets, each with 10–20+ websites and app bundle IDs:

| Category | Example Blocked Items |
|---|---|
| Social Media | facebook.com, instagram.com, x.com, linkedin.com, tiktok.com, reddit.com |
| Entertainment | youtube.com, netflix.com, spotify.com, twitch.tv, disneyplus.com |
| Gaming | steamcommunity.com, discord.com, epicgames.com, roblox.com |
| News | cnn.com, nytimes.com, wsj.com, reuters.com, bloomberg.com |
| Shopping | amazon.com, ebay.com, etsy.com, walmart.com, target.com |
| Video Streaming | youtube.com, netflix.com, hulu.com, crunchyroll.com |
| Productivity Busters | reddit.com, twitter.com, facebook.com, instagram.com, pinterest.com |

- Category details are expandable — shows every website and app in the preset.
- **Only apps you actually have installed** are listed (checked via `NSWorkspace`).
- Each item inside a category has an individual **Allow** toggle — exclude specific apps/sites from the category block.

### Allowlist
- Per-domain and per-bundle-ID allowlisting
- Allowed items are excluded from category blocks when building the block session
- Persisted in config file

### Pomodoro Timer
- Configurable work duration (1–120 min, step 5) and break duration (1–30 min, step 1)
- Starts a work session → counts down → notification + "Glass" chime → auto-starts break → notification + chime → next work cycle
- Runs entirely in the menu bar — close the app window and the timer keeps going
- Menu bar shows `F 24m` (Focus) or `B 4m` (Break) with live countdown
- Quick presets from the menu: 25 min Pomodoro, and a submenu with 15 / 30 / 60 min Quick Focus

### Menu Bar
- Shield icon — **outline** when idle, **filled** during an active block
- Live countdown: blocks show `1h30m`, `24m12s`, or `45s`; Pomodoro shows `F 24m` / `B 4m`
- Shield updates every second via a dedicated timer (no click required)
- Menu items:
  - **Start Pomodoro (25min)** — full work/break cycle
  - **Quick Focus ▶** — submenu: 15 / 30 / 60 minutes
  - **Start 1h Block** — quick timer block
  - **Block Active · 2h30m remaining** (disabled, shown during active block)
  - **Show SelfProtect** — brings window to front
  - **Quit** — Cmd+Q

### Dock Icon
- Can be hidden via **Settings → Appearance → Hide Dock Icon**
- App continues running in the menu bar only — no dock icon, no window on launch

### Import / Export
- Export your entire configuration (websites, apps, schedules, allowlists, category toggles, appearance preferences) as a `.selfprotect` JSON file
- Import merges into your current configuration
- File format is plain JSON — human-readable, versioned

### UI Design
- Three tabs: **Dashboard**, **Block List**, **Settings**
- Apple-minimal design language — `.ultraThinMaterial` glass panels, no custom gradients, no accent color abuse
- System accent color used only for toggle switches and selection borders
- All settings rows use consistent `HStack` layout with left-aligned text labels

### Persistence
- All user data saved to `~/Library/Application Support/SelfProtect/config.json`:
  - Websites, apps, schedules, allowlists, enabled category presets
  - Pomodoro durations, appearance preferences, dock icon setting
- Survives app deletion, updates, and reinstalls
- Daemon state stored separately at `/var/db/SelfProtect/state.json` (root-owned)
- Schedule-only config stored at `/var/db/SelfProtect/config.json`

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac
- Administrator access (one-time, for daemon installation)

## Installation

```bash
# Install via .pkg
open SelfProtect.pkg

# Or just drag SelfProtect.app to /Applications
```

### First Launch

1. Open SelfProtect.
2. An admin password dialog appears — this installs the privileged helper daemon.
3. Bottom-left shows **"Daemon Connected"** once ready.
4. Add websites/apps, toggle a category, set a schedule or timer.

## Building from Source

### With Xcode (recommended)

```bash
# Install XcodeGen (optional)
brew install xcodegen

# Generate and open project
xcodegen generate
open SelfProtect.xcodeproj

# Build: Cmd+B, select SelfProtect scheme
```

### With CLI (Xcode not required)

```bash
./build.sh
```

Produces `.build/SelfProtect.app` and `.build/SelfProtect.pkg`.

The build script handles the full compilation chain:
1. Builds `SelfProtectKit` as a static library (via `swiftc`, with a VFS overlay to work around CLT module-map issues)
2. Builds `SelfProtectHelper` (links `SelfProtectKit`)
3. Builds the SwiftUI app (links both)
4. Assembles the `.app` bundle with Info.plist, launch daemon plist, helper binary, and app icon
5. Ad-hoc code-signs the bundle
6. Packages into a `.pkg` installer

## Project Structure

```
SelfProtect/
├── build.sh                          # Full build script (CLI)
├── project.yml                       # XcodeGen project spec
├── CHANGELOG.md
├── README.md
│
├── SelfProtectKit/                   # Shared Swift Package
│   ├── Package.swift
│   └── Sources/
│       ├── Models/                   # BlockEntry, BlockSession, BlockSchedule, BlockPreset
│       ├── IPC/                      # HelperProtocol (XPC interface definition)
│       ├── Blocking/                 # HostsManager, PFManager, AppBlocker
│       └── Presets/                  # PresetData (7 category definitions)
│
├── SelfProtect/                      # SwiftUI App
│   ├── SelfProtectApp.swift          # @main — sets up daemon, status bar, window
│   ├── ContentView.swift             # 3-tab layout (Dashboard, Block List, Settings)
│   ├── Info.plist
│   ├── SelfProtect.entitlements
│   ├── Views/
│   │   ├── DashboardView.swift       # Status, countdown, timer slider, categories, start/stop
│   │   ├── BlockListView.swift       # Combined websites + apps + categories with segmented picker
│   │   └── SettingsView.swift        # Pomodoro, Appearance, Schedules, Import/Export, General, Daemon, About
│   ├── ViewModels/
│   │   └── AppViewModel.swift        # Central state: block lists, timers, pomodoro, persistence
│   ├── Managers/
│   │   ├── DaemonManager.swift       # XPC connection + daemon installation (osascript)
│   │   ├── StatusBarController.swift # NSStatusItem, menu, live countdown
│   │   └── CategoryProvider.swift    # Toggle state for category presets
│   ├── Library/LaunchDaemons/
│   │   └── com.selfprotect.helper.plist
│   └── Resources/
│       ├── AppIcon.icns
│       └── AppIcon.appiconset/       # All PNG sizes 16×16 → 1024×1024
│
├── SelfProtectHelper/                # Privileged XPC Daemon (runs as root)
│   ├── main.swift                    # NSXPCListener, mach service registration
│   ├── Helper.swift                  # startBlock, stopBlock, updateConfig, schedule evaluation
│   ├── Info.plist
│   └── SelfProtectHelper.entitlements
│
└── .build/                           # Build output (gitignored)
    ├── SelfProtect.app
    └── SelfProtect.pkg
```

## Architecture

```
┌─────────────────────────────────┐         XPC (Mach)          ┌──────────────────────────────────────┐
│   SelfProtect (sandboxed)       │◄──────────────────────────►│  SelfProtectHelper (launch daemon)    │
│                                 │  com.selfprotect.helper.xpc │                                      │
│   SwiftUI app (user context)    │                            │  Runs as root via launchd             │
│   Reads/writes config.json      │                            │  Reads/writes state.json (root-owned) │
│   Communicates via DaemonManager│                            │  Installed at:                        │
│   Installs daemon via osascript │                            │    /Library/PrivilegedHelperTools/     │
│                                 │                            │    /Library/LaunchDaemons/             │
└─────────────────────────────────┘                            └──────────────────────────────────────┘
                                                                         │
                                                                         ▼
                                                              ┌─────────────────────┐
                                                              │  Blocking Layer     │
                                                              │  ┌───────────────┐  │
                                                              │  │ /etc/hosts    │  │  DNS-level
                                                              │  └───────────────┘  │
                                                              │  ┌───────────────┐  │
                                                              │  │ pfctl anchor  │  │  Kernel-level
                                                              │  └───────────────┘  │
                                                              │  ┌───────────────┐  │
                                                              │  │ pkill -9      │  │  Process-level
                                                              │  └───────────────┘  │
                                                              └─────────────────────┘
```

### Daemon Lifecycle

1. **App launch** → `DaemonManager.connect()` → checks if daemon is installed
2. If not installed → `osascript` with admin privileges:
   - Copies helper binary to `/Library/PrivilegedHelperTools/com.selfprotect.helper`
   - Writes launch daemon plist to `/Library/LaunchDaemons/com.selfprotect.helper.plist`
   - Runs `launchctl bootstrap system` to load it
3. Daemon starts → creates `NSXPCListener(machServiceName:)` → registeres mach service
4. App's XPC connection finds the service → establishes IPC
5. Daemon stores block config separately from active sessions → evaluates schedules every 30s
6. On schedule activation without a timer → creates implied session, installs blocks
7. On schedule deactivation → removes blocks, clears implied session

### Block Config Sync

Every time the user modifies their block list (add/remove website, toggle category, toggle allowlist, edit schedule), the app automatically calls `updateConfig()` on the daemon. The daemon re-evaluates schedules immediately using the new configuration. Schedules (not timers) use the most recent config — changes take effect at the next schedule evaluation.

## Security

- **Daemon installation** requires admin password once — uses standard macOS authorization dialog
- **Blocking persistence** — daemon continues running after app quit, user logout, and reboot
- **No data collection** — no telemetry, no analytics, no network requests
- **VPN bypass** — VPNs route traffic outside pfctl's scope. This is inherent to all network-level blockers (SelfControl, Focus, Cold Turkey). No known workaround.

## Known Limitations

- VPN connections bypass pfctl/hosts blocking (inherent)
- Private Relay is disabled while pfctl rules are active (same as SelfControl)
- First launch requires admin password
- Requires macOS 14+

## License

MIT
