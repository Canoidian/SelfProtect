import AppKit
import SwiftUI

@MainActor
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private weak var viewModel: AppViewModel?
    private var updateTimer: Timer?

    func setup(with viewModel: AppViewModel) {
        self.viewModel = viewModel

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "shield.checkered", accessibilityDescription: "SelfProtect")
        statusItem?.button?.imagePosition = .imageLeft
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(showMenu)

        rebuildMenu()
        updateStatusItem()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatusItem() }
        }
    }

    @objc private func showMenu() {
        statusItem?.menu = nil
        rebuildMenu()
        statusItem?.button?.performClick(nil)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let titleItem = NSMenuItem(title: "SelfProtect", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "SelfProtect",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13), .foregroundColor: NSColor.secondaryLabelColor]
        )
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        if viewModel?.pomodoroIsRunning == true {
            let remaining = max(viewModel?.pomodoroEndDate?.timeIntervalSinceNow ?? 0, 0)
            let total = Int(remaining)
            let label = viewModel?.pomodoroPhase == .work ? "Focus" : "Break"
            let timerItem = NSMenuItem(title: "\(label) \(String(format: "%02d:%02d", total/60, total%60))", action: nil, keyEquivalent: "")
            timerItem.isEnabled = false
            menu.addItem(timerItem)

            let stopPomo = NSMenuItem(title: "Stop Pomodoro", action: #selector(stopPomodoro), keyEquivalent: "")
            stopPomo.target = self
            menu.addItem(stopPomo)
        } else {
            let startPomo = NSMenuItem(title: "Start Pomodoro (25min)", action: #selector(startPomodoro25), keyEquivalent: "")
            startPomo.target = self
            menu.addItem(startPomo)

            let quickFocus = NSMenuItem(title: "Quick Focus", action: nil, keyEquivalent: "")
            let focusMenu = NSMenu()
            let f15 = NSMenuItem(title: "15 minutes", action: #selector(startQuickFocus), keyEquivalent: "")
            f15.target = self
            focusMenu.addItem(f15)
            let f30 = NSMenuItem(title: "30 minutes", action: #selector(startQuickFocus30), keyEquivalent: "")
            f30.target = self
            focusMenu.addItem(f30)
            let f60 = NSMenuItem(title: "60 minutes", action: #selector(startQuickFocus60), keyEquivalent: "")
            f60.target = self
            focusMenu.addItem(f60)
            menu.setSubmenu(focusMenu, for: quickFocus)
            menu.addItem(quickFocus)
        }

        menu.addItem(NSMenuItem.separator())

        if let vm = viewModel, vm.isBlocking {
            let remaining = vm.localRemainingSeconds
            let total = Int(remaining)
            let hrs = total / 3600
            let mins = (total % 3600) / 60
            let secs = total % 60
            let timeStr = hrs > 0 ? String(format: "%dh%02dm", hrs, mins) : String(format: "%dm%02ds", mins, secs)
            let blockItem = NSMenuItem(title: "Block Active · \(timeStr) remaining", action: nil, keyEquivalent: "")
            blockItem.isEnabled = false
            menu.addItem(blockItem)
        } else {
            let startBlock = NSMenuItem(title: "Start 1h Block", action: #selector(startBlock1h), keyEquivalent: "")
            startBlock.target = self
            menu.addItem(startBlock)
        }

        menu.addItem(NSMenuItem.separator())

        let showItem = NSMenuItem(title: "Show SelfProtect", action: #selector(showApp), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func updateStatusItem() {
        guard let vm = viewModel else { return }

        if vm.pomodoroIsRunning {
            let remaining = max(vm.pomodoroEndDate?.timeIntervalSinceNow ?? 0, 0)
            let total = Int(remaining)
            let label = vm.pomodoroPhase == .work ? "F" : "B"
            statusItem?.button?.image = nil
            if total < 60 {
                statusItem?.button?.title = "\(label) \(total)s"
            } else {
                statusItem?.button?.title = "\(label) \(total/60)m"
            }
            statusItem?.button?.imagePosition = .noImage
        } else if vm.isBlocking {
            let remaining = vm.localRemainingSeconds
            let total = Int(remaining)
            let hrs = total / 3600
            let mins = (total % 3600) / 60
            let secs = total % 60
            statusItem?.button?.image = nil
            if hrs > 0 {
                statusItem?.button?.title = "\(hrs)h\(mins)m"
            } else if mins > 0 {
                statusItem?.button?.title = "\(mins)m\(secs)s"
            } else {
                statusItem?.button?.title = "\(secs)s"
            }
            statusItem?.button?.imagePosition = .noImage
        } else {
            statusItem?.button?.image = NSImage(systemSymbolName: "shield", accessibilityDescription: "SelfProtect")
            statusItem?.button?.title = ""
            statusItem?.button?.imagePosition = .imageLeft
        }
    }

    @objc private func startPomodoro25() {
        viewModel?.startPomodoro()
        updateStatusItem()
    }

    @objc private func startQuickFocus() {
        viewModel?.pomodoroWorkMinutes = 15
        viewModel?.startPomodoro()
        updateStatusItem()
    }

    @objc private func startQuickFocus30() {
        viewModel?.pomodoroWorkMinutes = 30
        viewModel?.startPomodoro()
        updateStatusItem()
    }

    @objc private func startQuickFocus60() {
        viewModel?.pomodoroWorkMinutes = 60
        viewModel?.startPomodoro()
        updateStatusItem()
    }

    @objc private func stopPomodoro() {
        viewModel?.stopPomodoro()
        updateStatusItem()
    }

    @objc private func startBlock1h() {
        guard let vm = viewModel else { return }
        Task { @MainActor in
            vm.timerDuration = 60
            await vm.startBlockFromDashboard(timerMinutes: 60)
            updateStatusItem()
        }
    }

    @objc private func showApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
        updateStatusItem()
    }
}
