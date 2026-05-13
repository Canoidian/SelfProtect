import SwiftUI
import SelfProtectKit

struct DashboardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedMinutes: TimeInterval = 60
    @State private var showError = false
    @State private var categoryDetail: BlockPreset?
    @State private var showCategoryConfirm = false
    @State private var pendingCategoryToggle: (() -> Void)?

    private let quickDurations: [(label: String, minutes: TimeInterval)] = [
        ("30m", 30), ("1h", 60), ("2h", 120), ("4h", 240), ("8h", 480)
    ]

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                statusSection
                if viewModel.isBlocking {
                    countdownSection
                }
                timerSection
                categorySection
                startSection
                connectionFooter
            }
            .padding(24)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .sheet(item: $categoryDetail) { preset in
            CategoryDetailView(preset: preset)
        }
        .alert("Add Category During Block?", isPresented: $showCategoryConfirm) {
            Button("Cancel", role: .cancel) { pendingCategoryToggle = nil }
            Button("Add", role: .destructive) {
                pendingCategoryToggle?()
                pendingCategoryToggle = nil
            }
        } message: {
            Text("This category will be blocked and cannot be turned off until the block ends.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("SelfProtect")
                .font(.title)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var statusSection: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(viewModel.isBlocking ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 12, height: 12)
            Text(viewModel.isBlocking ? "Blocking Active" : "Not Blocking")
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            if viewModel.isBlocking {
                Text("\(viewModel.totalWebsiteCount) sites  ·  \(viewModel.totalAppCount) apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private var countdownSection: some View {
        VStack(spacing: 4) {
            Text(formattedTime(viewModel.localRemainingSeconds))
                .font(.system(size: 56, weight: .thin, design: .monospaced))
                .foregroundColor(.primary)
                .monospacedDigit()
            Text("remaining")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private var timerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Duration")
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Text(durationLabel)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $selectedMinutes, in: 0...480, step: 5)
                .disabled(viewModel.isBlocking)

            HStack(spacing: 8) {
                ForEach(quickDurations, id: \.label) { item in
                    Button(item.label) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedMinutes = item.minutes
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(selectedMinutes == item.minutes ? .blue : .gray)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Categories")
                .font(.body)
                .foregroundColor(.primary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(PresetData.allPresets) { preset in
                    categoryCard(for: preset)
                }
            }
        }
    }

    private func categoryCard(for preset: BlockPreset) -> some View {
        let isOn = viewModel.categoryProvider.isEnabled(preset)
        return HStack(spacing: 10) {
            Image(systemName: preset.symbolName)
                .font(.body)
                .foregroundColor(isOn ? .blue : .secondary)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(isOn ? Color.blue.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                }

            VStack(alignment: .leading, spacing: 0) {
                Text(preset.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text("\(preset.websites.count) sites, \(preset.apps.count) apps")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 4)

            Button {
                categoryDetail = preset
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("View details")

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    if viewModel.isBlocking && newValue {
                        pendingCategoryToggle = { viewModel.toggleCategoryPreset(preset) }
                        showCategoryConfirm = true
                    } else if !viewModel.isBlocking {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.toggleCategoryPreset(preset)
                        }
                    }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isOn ? Color.blue.opacity(0.3) : Color.gray.opacity(0.15), lineWidth: isOn ? 1 : 0.5)
        }
    }

    private var startSection: some View {
        VStack(spacing: 8) {
            if viewModel.isBlocking {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Block cannot be stopped until timer expires")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Button {
                    Task { await viewModel.startBlockFromDashboard(timerMinutes: selectedMinutes) }
                } label: {
                    Label("Start Block", systemImage: "play.fill")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .disabled(viewModel.isStartingBlock || selectedMinutes == 0)
            }
        }
    }

    private var connectionFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.daemonManager.isConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(viewModel.daemonManager.isConnected ? "Daemon Connected" : "Daemon Disconnected")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var durationLabel: String {
        let total = Int(selectedMinutes)
        let hrs = total / 60
        let mins = total % 60
        if hrs > 0 && mins > 0 { return "\(hrs)h \(mins)m" }
        if hrs > 0 { return "\(hrs)h" }
        if mins > 0 { return "\(mins)m" }
        return "0m"
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct CategoryDetailView: View {
    let preset: BlockPreset
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: preset.symbolName)
                    .font(.title2)
                    .foregroundColor(.primary)
                Text(preset.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
            }

            if !preset.websites.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Websites")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    ForEach(preset.websites.sorted(), id: \.self) { site in
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(site)
                                .font(.subheadline)
                        }
                    }
                }
            }

            let installedApps = preset.apps.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.key) != nil }
            if !installedApps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    ForEach(installedApps.sorted(by: { $0.value < $1.value }), id: \.key) { bundleID, name in
                        HStack(spacing: 6) {
                            Image(systemName: "app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(name)
                                .font(.subheadline)
                            Text(bundleID)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
