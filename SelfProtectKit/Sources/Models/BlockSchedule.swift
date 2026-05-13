import Foundation

public struct BlockSchedule: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var days: Set<Weekday>
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        days: Set<Weekday> = [],
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 17,
        endMinute: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.days = days
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = isEnabled
    }

    public func isActive(at date: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        guard let today = Weekday.from(calendarWeekday: weekday), days.contains(today) else {
            return false
        }
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let nowMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        if startMinutes <= endMinutes {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        } else {
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        }
    }

    public var startTimeString: String {
        String(format: "%02d:%02d", startHour, startMinute)
    }

    public var endTimeString: String {
        String(format: "%02d:%02d", endHour, endMinute)
    }
}

public enum Weekday: String, Codable, CaseIterable, Hashable, Sendable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    public var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    public var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    public static func from(calendarWeekday: Int) -> Weekday? {
        let mapping: [Int: Weekday] = [
            1: .sunday, 2: .monday, 3: .tuesday, 4: .wednesday,
            5: .thursday, 6: .friday, 7: .saturday
        ]
        return mapping[calendarWeekday]
    }
}
