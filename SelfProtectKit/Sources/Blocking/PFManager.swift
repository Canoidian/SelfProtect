import Foundation

public struct PFManager: Sendable {
    public static let anchorName = "selfprotect"
    public static let tableName = "selfprotect_blocked"

    public init() {}

    public func installBlock(domains: [String]) throws {
        let resolved = resolveDomains(domains)
        guard !resolved.isEmpty else { return }

        try flushAnchor()

        let table = runCommand("/sbin/pfctl -q -t \(Self.tableName) -T add \(resolved.joined(separator: " "))")
        if table != 0 {
            let createTable = runCommand("/sbin/pfctl -q -t \(Self.tableName) -T add 255.255.255.255")
            if createTable != 0 {
                throw PFError.tableCreationFailed
            }
            let retry = runCommand("/sbin/pfctl -q -t \(Self.tableName) -T add \(resolved.joined(separator: " "))")
            if retry != 0 {
                throw PFError.addFailed
            }
        }

        let rules = """
        block out log quick proto {tcp,udp} from any to <\(Self.tableName)>
        block in log quick proto {tcp,udp} from <\(Self.tableName)> to any
        """

        let ruleResult = runCommand("/sbin/pfctl -q -a \(Self.anchorName) -f - 2>/dev/null <<< \"\(rules)\"")
        if ruleResult != 0 {
            let fileBased = writeTempRules(rules)
            guard let path = fileBased else { throw PFError.ruleLoadFailed }
            defer { try? FileManager.default.removeItem(atPath: path) }
            let loadResult = runCommand("/sbin/pfctl -q -a \(Self.anchorName) -f \"\(path)\"")
            if loadResult != 0 {
                throw PFError.ruleLoadFailed
            }
        }

        let enable = runCommand("/sbin/pfctl -q -a \(Self.anchorName) -f /dev/stdin 2>/dev/null; /sbin/pfctl -e 2>/dev/null")
        _ = enable
    }

    public func removeBlock() throws {
        _ = runCommand("/sbin/pfctl -q -a \(Self.anchorName) -F all 2>/dev/null")
        _ = runCommand("/sbin/pfctl -q -t \(Self.tableName) -T flush 2>/dev/null")
    }

    public func flushAnchor() throws {
        _ = runCommand("/sbin/pfctl -q -a \(Self.anchorName) -F all 2>/dev/null")
        _ = runCommand("/sbin/pfctl -q -t \(Self.tableName) -T flush 2>/dev/null")
    }

    public func isBlocking() -> Bool {
        let output = runCommandWithOutput("/sbin/pfctl -q -a \(Self.anchorName) -s rules 2>/dev/null")
        return !output.isEmpty
    }

    private func resolveDomains(_ domains: [String]) -> [String] {
        var ips: Set<String> = []
        for domain in domains {
            let cleaned = domain.lowercased().trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty else { continue }
            let output = runCommandWithOutput("dscacheutil -q host -a name \(cleaned) 2>/dev/null | grep ip_address | awk '{print $2}'")
            let lines = output.split(separator: "\n").map(String.init)
            for ip in lines {
                let trimmed = ip.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    ips.insert(trimmed)
                }
            }
        }
        return Array(ips)
    }

    private func writeTempRules(_ rules: String) -> String? {
        let path = "/tmp/selfprotect_pf_rules.\(UUID().uuidString)"
        do {
            try rules.write(toFile: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            return nil
        }
    }

    private func runCommand(_ cmd: String) -> Int32 {
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", cmd]
        process.standardOutput = nil
        process.standardError = nil
        process.launch()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private func runCommandWithOutput(_ cmd: String) -> String {
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", cmd]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = nil
        process.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

public enum PFError: Error, LocalizedError {
    case tableCreationFailed
    case addFailed
    case ruleLoadFailed

    public var errorDescription: String? {
        switch self {
        case .tableCreationFailed: return "Failed to create pf table"
        case .addFailed: return "Failed to add IPs to pf table"
        case .ruleLoadFailed: return "Failed to load pf rules"
        }
    }
}
