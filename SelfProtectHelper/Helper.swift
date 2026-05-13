import Foundation
import SelfProtectKit

class Helper: NSObject, HelperProtocol {
    private var currentSession: BlockSession?
    private var storedConfig: BlockSession?
    private var checkTimer: Timer?
    private var appKillTimer: Timer?
    private let hostsManager = HostsManager()
    private let pfManager = PFManager()
    private let statePath = "/var/db/SelfProtect/state.json"
    private let configPath = "/var/db/SelfProtect/config.json"
    private let stateDir = "/var/db/SelfProtect"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override init() {
        super.init()
        ensureStateDirectory()
        loadState()
        loadConfig()
        checkSchedules()
    }

    func startBlock(configData: Data, reply: @escaping (Data?) -> Void) {
        do {
            let session = try decoder.decode(BlockSession.self, from: configData)
            currentSession = session
            storedConfig = session

            ensureStateDirectory()

            if !session.domainList.isEmpty {
                try hostsManager.installBlock(domains: session.domainList)
                try pfManager.installBlock(domains: session.domainList)
                flushDNS()
            }

            if !session.bundleIDList.isEmpty {
                let appBlocker = AppBlocker(blockedBundleIDs: session.bundleIDList)
                appBlocker.killBlockedApps()
            }

            saveState()
            saveConfig()
            startTimers()
            reply(buildStatusData())
        } catch {
            reply(nil)
        }
    }

    func stopBlock(reply: @escaping (Bool, String?) -> Void) {
        let isScheduleActive = storedConfig?.schedules.contains { $0.isActive() } ?? false
        if isScheduleActive {
            reply(false, "Cannot stop block while schedule is active")
            return
        }
        do {
            try hostsManager.removeBlock()
            try pfManager.removeBlock()
            flushDNS()
        } catch {
            currentSession = nil
            stopTimers()
            try? FileManager.default.removeItem(atPath: statePath)
            reply(false, error.localizedDescription)
            return
        }
        currentSession = nil
        stopTimers()
        try? FileManager.default.removeItem(atPath: statePath)
        reply(true, nil)
    }

    func getStatus(reply: @escaping (Data) -> Void) {
        reply(buildStatusData())
    }

    func updateConfig(configData: Data, reply: @escaping (Bool, String?) -> Void) {
        do {
            let config = try decoder.decode(BlockSession.self, from: configData)
            storedConfig = config

            ensureStateDirectory()
            saveConfig()

            let scheduleActive = config.schedules.contains { $0.isActive() }
            let timerActive = currentSession?.timerEndDate.map { Date() < $0 } ?? false

            if scheduleActive || timerActive {
                let domains = scheduleActive ? config.domainList : (currentSession?.domainList ?? [])
                let bundleIDs = scheduleActive ? config.bundleIDList : (currentSession?.bundleIDList ?? [])
                if !domains.isEmpty {
                    try hostsManager.installBlock(domains: domains)
                    try pfManager.installBlock(domains: domains)
                    flushDNS()
                }
                if !bundleIDs.isEmpty {
                    let appBlocker = AppBlocker(blockedBundleIDs: bundleIDs)
                    appBlocker.killBlockedApps()
                }
            } else {
                try hostsManager.removeBlock()
                try pfManager.removeBlock()
                flushDNS()
            }

            startTimers()
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    private func buildStatusData() -> Data {
        let session = currentSession ?? storedConfig
        var status: BlockStatus

        if let session {
            let scheduleActive = session.schedules.contains { $0.isActive() }
            let timerActive = session.timerEndDate.map { Date() < $0 } ?? false
            let isBlocking = scheduleActive || timerActive

            var remaining: TimeInterval = 0
            var activeScheduleNames: [String] = []

            if scheduleActive {
                var maxRemaining: TimeInterval = 0
                for schedule in session.schedules where schedule.isActive() {
                    let endMinutes = schedule.endHour * 60 + schedule.endMinute
                    let now = Date()
                    let nowMinutes = Calendar.current.component(.hour, from: now) * 60 + Calendar.current.component(.minute, from: now)
                    var diffMinutes = endMinutes - nowMinutes
                    if diffMinutes < 0 { diffMinutes += 1440 }
                    let scheduleRemaining = TimeInterval(diffMinutes * 60)
                    if scheduleRemaining > maxRemaining { maxRemaining = scheduleRemaining }
                    activeScheduleNames.append("\(schedule.startTimeString)-\(schedule.endTimeString)")
                }
                remaining = maxRemaining
            } else if let timerEnd = session.timerEndDate {
                remaining = max(timerEnd.timeIntervalSinceNow, 0)
            }

            status = BlockStatus(
                isBlocking: isBlocking,
                activeWebsites: session.domainList,
                activeApps: session.bundleIDList,
                timerEndDate: session.timerEndDate,
                activeScheduleNames: activeScheduleNames,
                remainingSeconds: remaining
            )
        } else {
            status = BlockStatus(isBlocking: false)
        }

        return (try? encoder.encode(status)) ?? Data()
    }

    private func installBlock(for config: BlockSession) {
        guard !config.domainList.isEmpty || !config.bundleIDList.isEmpty else { return }
        if !config.domainList.isEmpty {
            try? hostsManager.installBlock(domains: config.domainList)
            try? pfManager.installBlock(domains: config.domainList)
            flushDNS()
        }
        if !config.bundleIDList.isEmpty {
            let appBlocker = AppBlocker(blockedBundleIDs: config.bundleIDList)
            appBlocker.killBlockedApps()
        }
    }

    private func removeBlock() {
        try? hostsManager.removeBlock()
        try? pfManager.removeBlock()
        flushDNS()
    }

    private func checkSchedules() {
        guard let config = storedConfig else { return }
        let scheduleActive = config.schedules.contains { $0.isActive() }
        let timerActive = currentSession?.timerEndDate.map { Date() < $0 } ?? false

        if scheduleActive && currentSession == nil {
            let configSession = BlockSession(
                websites: config.websites,
                apps: config.apps,
                timerEndDate: nil,
                schedules: config.schedules
            )
            currentSession = configSession
            installBlock(for: config)
            saveState()
            startTimers()
        } else if !scheduleActive && !timerActive {
            currentSession = nil
            removeBlock()
            stopTimers()
            try? FileManager.default.removeItem(atPath: statePath)
        } else if scheduleActive || timerActive {
            let ids = currentSession?.bundleIDList ?? config.bundleIDList
            if !ids.isEmpty {
                let appBlocker = AppBlocker(blockedBundleIDs: ids)
                appBlocker.killBlockedApps()
            }
        }
    }

    private func runAppKiller() {
        let ids = currentSession?.bundleIDList ?? storedConfig?.bundleIDList ?? []
        guard !ids.isEmpty else { return }
        let appBlocker = AppBlocker(blockedBundleIDs: ids)
        appBlocker.killBlockedApps()
    }

    private func startTimers() {
        stopTimers()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkSchedules()
        }
        appKillTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.runAppKiller()
        }
    }

    private func stopTimers() {
        checkTimer?.invalidate()
        checkTimer = nil
        appKillTimer?.invalidate()
        appKillTimer = nil
    }

    private func ensureStateDirectory() {
        try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    private func saveState() {
        guard let session = currentSession else { return }
        if let data = try? encoder.encode(session) {
            try? data.write(to: URL(fileURLWithPath: statePath), options: .atomic)
        }
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: statePath)),
              let session = try? decoder.decode(BlockSession.self, from: data) else { return }
        currentSession = session
        let scheduleActive = session.schedules.contains { $0.isActive() }
        let timerActive = session.timerEndDate.map { Date() < $0 } ?? false
        if scheduleActive || timerActive {
            installBlock(for: session)
            startTimers()
        } else {
            try? FileManager.default.removeItem(atPath: statePath)
        }
    }

    private func saveConfig() {
        guard let config = storedConfig else { return }
        if let data = try? encoder.encode(config) {
            try? data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
        }
    }

    private func loadConfig() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let config = try? decoder.decode(BlockSession.self, from: data) else { return }
        storedConfig = config
    }

    private func flushDNS() {
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", "dscacheutil -flushcache; killall -HUP mDNSResponder"]
        process.launch()
        process.waitUntilExit()
    }
}
