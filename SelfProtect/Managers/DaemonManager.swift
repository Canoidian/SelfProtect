import Foundation
import SelfProtectKit

@MainActor
class DaemonManager: ObservableObject {
    @Published var isConnected = false
    private var connection: NSXPCConnection?
    private var reconnectTimer: Timer?
    private var isReconnecting = false
    private var connectionAttempts = 0
    private let daemonPlistPath = "/Library/LaunchDaemons/com.selfprotect.helper.plist"
    private let installedHelperPath = "/Library/PrivilegedHelperTools/com.selfprotect.helper"
    private var hasAttemptedInstall = false

    var proxy: HelperProtocol? {
        connection?.remoteObjectProxy as? HelperProtocol
    }

    func connect() {
        disconnect()
        connectionAttempts += 1
        if !hasAttemptedInstall {
            hasAttemptedInstall = true
            if FileManager.default.fileExists(atPath: installedHelperPath) &&
               FileManager.default.fileExists(atPath: daemonPlistPath) {
                isConnected = false
            } else {
                installDaemon()
            }
        }
        let conn = NSXPCConnection(machServiceName: helperMachServiceName)
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.isConnected = false
                self?.scheduleReconnect()
            }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.isConnected = false
            }
        }
        conn.resume()
        connection = conn
        isConnected = true
        isReconnecting = false
    }

    func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        connection?.invalidationHandler = nil
        connection?.interruptionHandler = nil
        connection?.invalidate()
        connection = nil
        isConnected = false
    }

    func scheduleReconnect() {
        guard !isReconnecting else { return }
        isReconnecting = true
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.connect()
            }
        }
    }

    private func installDaemon() {
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/SelfProtectHelper")
        guard FileManager.default.fileExists(atPath: helperURL.path) else {
            return
        }

        let helperSrc = helperURL.path
        let helperDest = installedHelperPath
        let plistPath = daemonPlistPath
        let scriptPath = "/tmp/install_selfprotect_helper.sh"

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.selfprotect.helper</string>
            <key>MachServices</key>
            <dict>
                <key>com.selfprotect.helper.xpc</key>
                <true/>
            </dict>
            <key>Program</key>
            <string>\(helperDest)</string>
            <key>KeepAlive</key>
            <true/>
            <key>RunAtLoad</key>
            <true/>
            <key>ThrottleInterval</key>
            <integer>5</integer>
        </dict>
        </plist>
        """

        let shellScript = """
        #!/bin/bash
        set -e
        mkdir -p /Library/PrivilegedHelperTools
        cp -f '\(helperSrc)' '\(helperDest)'
        chmod 755 '\(helperDest)'
        chown root:wheel '\(helperDest)'
        cat > '\(plistPath)' << 'PLEND'
        \(plistContent)
        PLEND
        chmod 644 '\(plistPath)'
        chown root:wheel '\(plistPath)'
        /bin/launchctl bootout system/com.selfprotect.helper 2>/dev/null || true
        /bin/launchctl bootstrap system '\(plistPath)'
        """

        do {
            try shellScript.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
        } catch {
            return
        }

        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e",
            "do shell script \"bash \(scriptPath)\" with administrator privileges"]
        process.launch()
        process.waitUntilExit()
    }

    func startBlock(session: BlockSession) async throws -> BlockStatus {
        guard let proxy else { throw DaemonError.notConnected }
        let data = try JSONEncoder().encode(session)
        return try await withCheckedThrowingContinuation { continuation in
            proxy.startBlock(configData: data) { responseData in
                if let responseData {
                    do {
                        let status = try JSONDecoder().decode(BlockStatus.self, from: responseData)
                        continuation.resume(returning: status)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: DaemonError.failedToStart)
                }
            }
        }
    }

    func stopBlock() async throws {
        guard let proxy else { throw DaemonError.notConnected }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.stopBlock { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: DaemonError.failedWithMessage(errorMessage ?? "Unknown error"))
                }
            }
        }
    }

    func getStatus() async throws -> BlockStatus {
        guard let proxy else { throw DaemonError.notConnected }
        return try await withCheckedThrowingContinuation { continuation in
            proxy.getStatus { data in
                do {
                    let status = try JSONDecoder().decode(BlockStatus.self, from: data)
                    continuation.resume(returning: status)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func updateConfig(session: BlockSession) async throws {
        guard let proxy else { throw DaemonError.notConnected }
        let data = try JSONEncoder().encode(session)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.updateConfig(configData: data) { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: DaemonError.failedWithMessage(errorMessage ?? "Unknown error"))
                }
            }
        }
    }
}

enum DaemonError: LocalizedError {
    case failedToStart
    case failedWithMessage(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .failedToStart: return "Failed to start blocking"
        case .failedWithMessage(let msg): return msg
        case .notConnected: return "Not connected to helper daemon"
        }
    }
}
