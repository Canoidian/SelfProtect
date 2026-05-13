import Foundation

public struct HostsManager: Sendable {
    public static let startMarker = "## SELFPROTECT-START"
    public static let endMarker = "## SELFPROTECT-END"
    public static let hostsPath = "/etc/hosts"

    public init() {}

    public func isBlocking() -> Bool {
        guard let content = try? String(contentsOfFile: Self.hostsPath, encoding: .utf8) else {
            return false
        }
        return content.contains(Self.startMarker)
    }

    public func installBlock(domains: [String]) throws {
        var content = try String(contentsOfFile: Self.hostsPath, encoding: .utf8)
        removeExistingBlock(in: &content)
        content += "\n\(Self.startMarker)\n"
        for domain in domains {
            let normalized = domain.lowercased().trimmingCharacters(in: .whitespaces)
            guard !normalized.isEmpty else { continue }
            content += "0.0.0.0 \(normalized)\n"
            content += "0.0.0.0 www.\(normalized)\n"
        }
        content += "\(Self.endMarker)\n"
        try content.write(toFile: Self.hostsPath, atomically: true, encoding: .utf8)
    }

    public func removeBlock() throws {
        var content = try String(contentsOfFile: Self.hostsPath, encoding: .utf8)
        removeExistingBlock(in: &content)
        try content.write(toFile: Self.hostsPath, atomically: true, encoding: .utf8)
    }

    public func getBlockedDomains() -> [String] {
        guard let content = try? String(contentsOfFile: Self.hostsPath, encoding: .utf8) else {
            return []
        }
        return extractBlockedDomains(from: content)
    }

    private func removeExistingBlock(in content: inout String) {
        guard let startRange = content.range(of: Self.startMarker),
              let endRange = content.range(of: Self.endMarker) else {
            return
        }
        let removalRange = startRange.lowerBound..<content.index(after: endRange.upperBound)
        content.removeSubrange(removalRange)
        content = content.trimmingCharacters(in: .newlines) + "\n"
    }

    private func extractBlockedDomains(from content: String) -> [String] {
        guard let startRange = content.range(of: Self.startMarker),
              let endRange = content.range(of: Self.endMarker) else {
            return []
        }
        let block = content[startRange.upperBound..<endRange.lowerBound]
        return block.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("0.0.0.0 ") else { return nil }
            let domain = trimmed.dropFirst(8).trimmingCharacters(in: .whitespaces)
            if domain.hasPrefix("www.") { return nil }
            return domain.isEmpty ? nil : domain
        }
    }
}
