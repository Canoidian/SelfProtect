import Foundation

public struct BlockPreset: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let symbolName: String
    public let websites: [String]
    public let apps: [String: String]

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        websites: [String],
        apps: [String: String]
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.websites = websites
        self.apps = apps
    }
}
