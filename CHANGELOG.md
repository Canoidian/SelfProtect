# Changelog

## v1.0.0 — 2026-05-13

### Core Blocking
- Dual-layer website blocking (`/etc/hosts` + `pfctl` packet filter)
- App blocking via `pkill` from privileged root daemon
- Unbreakable timer blocks — no stop button, cannot be disabled once started
- Recurring schedules by day of week + time range
- Schedule lock — cannot be modified while actively blocking
- Timer and schedule can run simultaneously (schedule takes priority)

### UI (SwiftUI)
- 3-tab layout: Dashboard, Block List, Settings
- Apple-minimal design with `.ultraThinMaterial` liquid glass backgrounds
- Dashboard: status indicator, countdown timer, duration slider, category toggles
- Block List: combined websites + apps + categories with segmented picker
- Categories section shows "Allow" per-item toggles to exclude specific apps/sites
- Only installed apps displayed in category details
- Settings: Pomodoro, Schedules, Import/Export, Appearance, General, Daemon, About
- Confirmation dialog when adding items during active block

### Menu Bar
- Shield icon (outline idle, filled during block)
- Live countdown timer during blocks and Pomodoro sessions
- Quick Pomodoro (25min) and Quick Focus submenu (15/30/60min)
- Start 1h Block shortcut
- Show SelfProtect / Quit

### Pomodoro Timer
- Configurable work (1-120min) and break (1-30min) durations
- Auto-cycling: work → notification + chime → break → notification + chime → work
- Menu bar shows remaining time with phase indicator

### Architecture
- Privileged helper daemon installed via `launchctl bootstrap system`
- XPC communication between sandboxed app and root daemon
- State persisted to `~/Library/Application Support/SelfProtect/config.json`
- Daemon runs independently — quitting the app does not stop blocking
- 7 category presets (Social Media, Entertainment, Gaming, News, Shopping, Video Streaming, Productivity Busters)

### Persistence
- Websites, apps, schedules, allowlists, enabled presets, and Pomodoro config all saved to JSON
- Schedules survive app deletion and reinstall
- Config file located at `~/Library/Application Support/SelfProtect/config.json`

### Known Limitations
- VPN bypasses pfctl/hosts blocking (inherent limitation)
- Requires macOS 14+ (Sonoma)
- First launch requires admin password for daemon installation
