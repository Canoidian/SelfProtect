import Foundation

public struct AppBlocker: Sendable {
    private let blockedBundleIDs: [String]

    public init(blockedBundleIDs: [String]) {
        self.blockedBundleIDs = blockedBundleIDs
    }

    public func killBlockedApps() {
        for bundleID in blockedBundleIDs {
            let sanitized = bundleID.replacingOccurrences(of: "'", with: "'\\''")
            let cmd = "pkill -f '\(sanitized)' 2>/dev/null; "
                + "pgrep -x '\(sanitized)' 2>/dev/null | while read pid; do "
                + "kill -9 $pid 2>/dev/null; done"
            let process = Process()
            process.launchPath = "/bin/sh"
            process.arguments = ["-c", cmd]
            process.launch()
            process.waitUntilExit()
        }
    }

    public static func scanInstalledApps() -> [(bundleID: String, displayName: String)] {
        var apps: [(String, String)] = []
        let paths = [
            "/Applications",
            "\(NSHomeDirectory())/Applications",
            "/System/Applications"
        ]
        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isApplicationKey],
                options: .skipsSubdirectoryDescendants
            ) else { continue }
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                if let bundle = Bundle(url: fileURL),
                   let bundleID = bundle.bundleIdentifier {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    if !apps.contains(where: { $0.0 == bundleID }) {
                        apps.append((bundleID, name))
                    }
                }
            }
        }
        return apps.sorted { $0.1.lowercased() < $1.1.lowercased() }
    }
}
