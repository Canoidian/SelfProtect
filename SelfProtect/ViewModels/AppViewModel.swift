import Foundation
import AppKit
import UniformTypeIdentifiers
import UserNotifications
import SelfProtectKit

extension UTType {
    static let selfprotectFileType = UTType(filenameExtension: "selfprotect") ?? .json
}

enum PomodoroPhase: String, Codable {
    case work, `break`
}

@MainActor
class AppViewModel: ObservableObject {
    let daemonManager: DaemonManager
    let categoryProvider: CategoryProvider

    @Published var websites: [WebsiteBlock] = []
    @Published var apps: [AppBlock] = []
    @Published var schedules: [BlockSchedule] = []
    @Published var timerDuration: TimeInterval = 0
    @Published var blockStatus: BlockStatus?
    @Published var isStartingBlock = false
    @Published var errorMessage: String?
    @Published var blockEndDate: Date?
    @Published var allowlistedAppIDs: Set<String> = []
    @Published var allowlistedDomains: Set<String> = []
    @Published var showMenuBarTimer: Bool = true
    @Published var hideDockIcon: Bool = false {
        didSet {
            NSApp.setActivationPolicy(hideDockIcon ? .accessory : .regular)
        }
    }

    @Published var pomodoroWorkMinutes: Double = 25
    @Published var pomodoroBreakMinutes: Double = 5
    @Published var pomodoroIsRunning = false
    @Published var pomodoroPhase: PomodoroPhase = .work
    @Published var pomodoroEndDate: Date?
    @Published var pomodoroCycleCount = 0

    private var statusTimer: Timer?
    private var countdownTimer: Timer?
    private var pomodoroTimer: Timer?

    var isBlocking: Bool { blockStatus?.isBlocking ?? false }

    var localRemainingSeconds: TimeInterval {
        guard let end = blockEndDate else { return blockStatus?.remainingSeconds ?? 0 }
        return max(end.timeIntervalSinceNow, 0)
    }

    var totalWebsiteCount: Int {
        let fromList = websites.count
        let fromCategories = categoryProvider.allSelectedWebsites.count
        return fromList + fromCategories
    }

    var totalAppCount: Int {
        let fromList = apps.count
        let fromCategories = categoryProvider.allSelectedApps.count
        return fromList + fromCategories
    }

    private let configPath: String = {
        let dir = "\(NSHomeDirectory())/Library/Application Support/SelfProtect"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return "\(dir)/config.json"
    }()

    init(daemonManager: DaemonManager, categoryProvider: CategoryProvider) {
        self.daemonManager = daemonManager
        self.categoryProvider = categoryProvider
        loadConfig()
        Task {
            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    private func loadConfig() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let sites = json["websites"] as? [String] {
            websites = sites.map { WebsiteBlock(domain: $0) }
        }
        if let appData = json["apps"] as? [[String: String]] {
            apps = appData.compactMap { d in
                guard let bid = d["bundleID"], let name = d["displayName"] else { return nil }
                return AppBlock(bundleID: bid, displayName: name)
            }
        }
        if let scheduleData = json["schedules"] as? [[String: Any]] {
            schedules = scheduleData.compactMap { s in
                guard let rawDays = s["days"] as? [String],
                      let startHour = s["startHour"] as? Int,
                      let startMinute = s["startMinute"] as? Int,
                      let endHour = s["endHour"] as? Int,
                      let endMinute = s["endMinute"] as? Int else { return nil }
                return BlockSchedule(
                    days: Set(rawDays.compactMap { Weekday(rawValue: $0) }),
                    startHour: startHour,
                    startMinute: startMinute,
                    endHour: endHour,
                    endMinute: endMinute,
                    isEnabled: s["isEnabled"] as? Bool ?? true
                )
            }
        }
        if let allowlisted = json["allowlistedAppIDs"] as? [String] {
            allowlistedAppIDs = Set(allowlisted)
        }
        if let allowlistedDom = json["allowlistedDomains"] as? [String] {
            allowlistedDomains = Set(allowlistedDom)
        }
        if let smbt = json["showMenuBarTimer"] as? Bool { showMenuBarTimer = smbt }
        if let hdi = json["hideDockIcon"] as? Bool {
            hideDockIcon = hdi
            NSApp.setActivationPolicy(hdi ? .accessory : .regular)
        }
        if let wd = json["pomodoroWorkMinutes"] as? Double { pomodoroWorkMinutes = wd }
        if let bd = json["pomodoroBreakMinutes"] as? Double { pomodoroBreakMinutes = bd }
        if let enabledPresetIDs = json["enabledPresets"] as? [String] {
            let uuids = enabledPresetIDs.compactMap { UUID(uuidString: $0) }
            categoryProvider.enabledPresets = Set(uuids)
        }
    }

    func saveConfig() {
        let dict: [String: Any] = [
            "websites": websites.map { $0.domain },
            "apps": apps.map { ["bundleID": $0.bundleID, "displayName": $0.displayName] },
            "schedules": schedules.map { s in
                [
                    "days": s.days.map { $0.rawValue },
                    "startHour": s.startHour,
                    "startMinute": s.startMinute,
                    "endHour": s.endHour,
                    "endMinute": s.endMinute,
                    "isEnabled": s.isEnabled
                ] as [String: Any]
            },
            "allowlistedAppIDs": Array(allowlistedAppIDs),
            "allowlistedDomains": Array(allowlistedDomains),
            "showMenuBarTimer": showMenuBarTimer,
            "hideDockIcon": hideDockIcon,
            "pomodoroWorkMinutes": pomodoroWorkMinutes,
            "pomodoroBreakMinutes": pomodoroBreakMinutes,
            "enabledPresets": categoryProvider.enabledPresets.map { $0.uuidString }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return }
        try? data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }

    func startPomodoro() {
        pomodoroPhase = .work
        pomodoroCycleCount = 0
        pomodoroEndDate = Date().addingTimeInterval(pomodoroWorkMinutes * 60)
        pomodoroIsRunning = true
        objectWillChange.send()
        saveConfig()
        pomodoroTimer?.invalidate()
        pomodoroTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickPomodoro() }
        }
    }

    func stopPomodoro() {
        pomodoroIsRunning = false
        pomodoroTimer?.invalidate()
        pomodoroTimer = nil
        objectWillChange.send()
    }

    private func tickPomodoro() {
        guard pomodoroIsRunning, let end = pomodoroEndDate else { return }
        if Date() >= end {
            let wasWork = pomodoroPhase == .work
            if wasWork {
                pomodoroPhase = .break
                pomodoroEndDate = Date().addingTimeInterval(pomodoroBreakMinutes * 60)
                pomodoroCycleCount += 1
                sendPomodoroNotification(title: "Work session complete", body: "Time for a \(Int(pomodoroBreakMinutes)) min break")
                playChime()
            } else {
                pomodoroPhase = .work
                pomodoroEndDate = Date().addingTimeInterval(pomodoroWorkMinutes * 60)
                sendPomodoroNotification(title: "Break over", body: "Time to focus for \(Int(pomodoroWorkMinutes)) min")
                playChime()
            }
        }
        objectWillChange.send()
    }

    private func sendPomodoroNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func playChime() {
        NSSound(named: "Glass")?.play()
    }

    func toggleCategoryPreset(_ preset: BlockPreset) {
        categoryProvider.togglePreset(preset)
        saveConfig()
        Task { await syncConfig() }
    }

    private func buildConfigSession() -> BlockSession {
        var allWebsites = websites
        var allApps = apps
        for websiteDomain in categoryProvider.allSelectedWebsites {
            guard !allowlistedDomains.contains(websiteDomain) else { continue }
            if !allWebsites.contains(where: { $0.domain == websiteDomain }) {
                allWebsites.append(WebsiteBlock(domain: websiteDomain))
            }
        }
        for (bundleID, displayName) in categoryProvider.allSelectedApps {
            guard !allowlistedAppIDs.contains(bundleID) else { continue }
            if !allApps.contains(where: { $0.bundleID == bundleID }) {
                allApps.append(AppBlock(bundleID: bundleID, displayName: displayName))
            }
        }
        return BlockSession(
            websites: allWebsites,
            apps: allApps,
            timerEndDate: nil,
            schedules: schedules.filter { $0.isEnabled }
        )
    }

    private func syncConfig() async {
        guard daemonManager.isConnected else { return }
        let config = buildConfigSession()
        do {
            try await daemonManager.updateConfig(session: config)
        } catch {}
    }

    func startPolling() {
        stopPolling()
        Task { await syncConfig() }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshStatus()
            }
        }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickCountdown()
            }
        }
    }

    func stopPolling() {
        statusTimer?.invalidate()
        statusTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        pomodoroTimer?.invalidate()
        pomodoroTimer = nil
    }

    private func tickCountdown() {
        if let end = blockEndDate, Date() >= end {
            let noScheduleActive = !schedules.filter { $0.isEnabled }.contains { $0.isActive() }
            if noScheduleActive {
                blockStatus = nil
                blockEndDate = nil
            }
        }
        objectWillChange.send()
    }

    func refreshStatus() async {
        guard daemonManager.isConnected else { return }
        do {
            let status = try await daemonManager.getStatus()
            blockStatus = status
            if !status.isBlocking {
                blockEndDate = nil
            }
        } catch {}
    }

    func addWebsite(_ domain: String) {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !websites.contains(where: { $0.domain == trimmed }) else { return }
        websites.append(WebsiteBlock(domain: trimmed))
        saveConfig()
        Task { await syncConfig() }
    }

    func removeWebsite(_ id: UUID) {
        websites.removeAll { $0.id == id }
        saveConfig()
        Task { await syncConfig() }
    }

    func toggleAllowlistedDomain(_ domain: String) {
        if allowlistedDomains.contains(domain) {
            allowlistedDomains.remove(domain)
        } else {
            allowlistedDomains.insert(domain)
        }
        saveConfig()
        Task { await syncConfig() }
    }

    func toggleAllowlistedApp(_ bundleID: String) {
        if allowlistedAppIDs.contains(bundleID) {
            allowlistedAppIDs.remove(bundleID)
        } else {
            allowlistedAppIDs.insert(bundleID)
        }
        saveConfig()
        Task { await syncConfig() }
    }

    func addApp(bundleID: String, displayName: String) {
        let bid = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bid.isEmpty, !apps.contains(where: { $0.bundleID == bid }) else { return }
        apps.append(AppBlock(bundleID: bid, displayName: displayName))
        saveConfig()
        Task { await syncConfig() }
    }

    func removeApp(_ id: UUID) {
        apps.removeAll { $0.id == id }
        saveConfig()
        Task { await syncConfig() }
    }

    func addSchedule(_ schedule: BlockSchedule) {
        schedules.append(schedule)
        saveConfig()
        Task { await syncConfig() }
    }

    func removeSchedule(_ id: UUID) {
        schedules.removeAll { $0.id == id }
        saveConfig()
        Task { await syncConfig() }
    }

    func updateSchedule(_ schedule: BlockSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
            saveConfig()
            Task { await syncConfig() }
        }
    }

    func startBlockFromDashboard(timerMinutes: TimeInterval) async {
        isStartingBlock = true
        defer { isStartingBlock = false }

        var allWebsites = websites
        var allApps = apps

        for websiteDomain in categoryProvider.allSelectedWebsites {
            guard !allowlistedDomains.contains(websiteDomain) else { continue }
            if !allWebsites.contains(where: { $0.domain == websiteDomain }) {
                allWebsites.append(WebsiteBlock(domain: websiteDomain))
            }
        }

        for (bundleID, displayName) in categoryProvider.allSelectedApps {
            guard !allowlistedAppIDs.contains(bundleID) else { continue }
            if !allApps.contains(where: { $0.bundleID == bundleID }) {
                allApps.append(AppBlock(bundleID: bundleID, displayName: displayName))
            }
        }

        var timerEndDate: Date?
        if timerMinutes > 0 {
            timerEndDate = Date().addingTimeInterval(timerMinutes * 60)
        }

        let session = BlockSession(
            websites: allWebsites,
            apps: allApps,
            timerEndDate: timerEndDate,
            schedules: schedules.filter { $0.isEnabled }
        )

        do {
            let status = try await daemonManager.startBlock(session: session)
            blockStatus = status
            blockEndDate = timerEndDate
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func quickBlock(minutes: TimeInterval) async {
        await startBlockFromDashboard(timerMinutes: minutes)
    }

    func extendBlock(additionalMinutes: TimeInterval) async {
        guard isBlocking, additionalMinutes > 0 else { return }
        let currentEnd = blockStatus?.timerEndDate ?? Date()
        let newEnd = currentEnd.addingTimeInterval(additionalMinutes * 60)
        blockEndDate = newEnd
        let allWebsites = websites.map { WebsiteBlock(domain: $0.domain) }
        let allApps = apps.map { AppBlock(bundleID: $0.bundleID, displayName: $0.displayName) }
        let session = BlockSession(
            websites: allWebsites + categoryProvider.allSelectedWebsites.map { WebsiteBlock(domain: $0) },
            apps: allApps,
            timerEndDate: newEnd,
            schedules: schedules.filter { $0.isEnabled }
        )
        do {
            try await daemonManager.updateConfig(session: session)
            blockStatus?.timerEndDate = newEnd
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportBlocklist() -> URL? {
        let exportDict: [String: Any] = [
            "version": 1,
            "websites": websites.map { $0.domain },
            "apps": apps.map { $0.bundleID },
            "schedules": schedules.map { schedule in
                [
                    "days": schedule.days.map { $0.rawValue },
                    "startHour": schedule.startHour,
                    "startMinute": schedule.startMinute,
                    "endHour": schedule.endHour,
                    "endMinute": schedule.endMinute,
                    "isEnabled": schedule.isEnabled
                ] as [String: Any]
            }
        ]

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.selfprotectFileType]
        panel.nameFieldStringValue = "blocklist.selfprotect"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            let data = try JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted)
            try data.write(to: url)
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func importBlocklist() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.selfprotectFileType, .json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            if let websites = json["websites"] as? [String] {
                for domain in websites {
                    addWebsite(domain)
                }
            }
            if let appBundleIDs = json["apps"] as? [String] {
                for bundleID in appBundleIDs {
                    if !apps.contains(where: { $0.bundleID == bundleID }) {
                        let name = bundleID.components(separatedBy: ".").last ?? bundleID
                        apps.append(AppBlock(bundleID: bundleID, displayName: name))
                    }
                }
            }
            if let schedulesJSON = json["schedules"] as? [[String: Any]] {
                for s in schedulesJSON {
                    guard let rawDays = s["days"] as? [String],
                          let startHour = s["startHour"] as? Int,
                          let startMinute = s["startMinute"] as? Int,
                          let endHour = s["endHour"] as? Int,
                          let endMinute = s["endMinute"] as? Int else { continue }
                    let days = Set(rawDays.compactMap { Weekday(rawValue: $0) })
                    let isEnabled = s["isEnabled"] as? Bool ?? true
                    let schedule = BlockSchedule(
                        days: days,
                        startHour: startHour,
                        startMinute: startMinute,
                        endHour: endHour,
                        endMinute: endMinute,
                        isEnabled: isEnabled
                    )
                    if !schedules.contains(where: { $0 == schedule }) {
                        schedules.append(schedule)
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
