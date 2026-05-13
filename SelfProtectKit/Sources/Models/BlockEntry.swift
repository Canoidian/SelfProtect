import Foundation

public struct WebsiteBlock: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let domain: String

    public init(id: UUID = UUID(), domain: String) {
        self.id = id
        self.domain = domain.lowercased().trimmingCharacters(in: .whitespaces)
    }
}

public struct AppBlock: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let bundleID: String
    public let displayName: String

    public init(id: UUID = UUID(), bundleID: String, displayName: String) {
        self.id = id
        self.bundleID = bundleID
        self.displayName = displayName
    }
}
