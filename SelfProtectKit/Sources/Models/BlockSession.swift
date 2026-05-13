import Foundation

public struct BlockSession: Codable, Sendable {
    public var websites: [WebsiteBlock]
    public var apps: [AppBlock]
    public var timerEndDate: Date?
    public var schedules: [BlockSchedule]
    public let startDate: Date

    public init(
        websites: [WebsiteBlock] = [],
        apps: [AppBlock] = [],
        timerEndDate: Date? = nil,
        schedules: [BlockSchedule] = []
    ) {
        self.websites = websites
        self.apps = apps
        self.timerEndDate = timerEndDate
        self.schedules = schedules
        self.startDate = Date()
    }

    public var domainList: [String] {
        websites.map { $0.domain }
    }

    public var bundleIDList: [String] {
        apps.map { $0.bundleID }
    }
}

public struct BlockStatus: Codable, Sendable {
    public var isBlocking: Bool
    public var activeWebsites: [String]
    public var activeApps: [String]
    public var timerEndDate: Date?
    public var activeScheduleNames: [String]
    public var remainingSeconds: TimeInterval

    public init(
        isBlocking: Bool = false,
        activeWebsites: [String] = [],
        activeApps: [String] = [],
        timerEndDate: Date? = nil,
        activeScheduleNames: [String] = [],
        remainingSeconds: TimeInterval = 0
    ) {
        self.isBlocking = isBlocking
        self.activeWebsites = activeWebsites
        self.activeApps = activeApps
        self.timerEndDate = timerEndDate
        self.activeScheduleNames = activeScheduleNames
        self.remainingSeconds = remainingSeconds
    }
}
