import SwiftUI
import ServiceManagement
import SelfProtectKit

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var launchAtLogin = false
    @State private var showNotifications = true
    @State private var showAddSchedule = false
    @State private var editingSchedule: BlockSchedule?
    @State private var showError = false
    @State private var lastExportURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                pomodoroSection
                appearanceSection
                schedulesSection
                importExportSection
                generalSection
                daemonSection
                aboutSection
            }
            .padding(32)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .sheet(isPresented: $showAddSchedule) {
            ScheduleEditorView { schedule in
                viewModel.addSchedule(schedule)
            }
        }
        .sheet(item: $editingSchedule) { schedule in
            ScheduleEditorView(editSchedule: schedule) { updated in
                viewModel.updateSchedule(updated)
            }
        }
        .task {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var headerView: some View {
        VStack(spacing: 4) {
            Image(systemName: "gearshape")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Settings")
                .font(.title)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
    }

    private var schedulesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Schedules")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    showAddSchedule = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                if viewModel.schedules.isEmpty {
                    HStack {
                        Text("No schedules configured")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(14)
                } else {
                    ForEach(Array(viewModel.schedules.enumerated()), id: \.element.id) { index, schedule in
                        ScheduleRowView(schedule: schedule) {
                            editingSchedule = schedule
                        } onDelete: {
                            viewModel.removeSchedule(schedule.id)
                        } onToggle: {
                            var updated = schedule
                            updated.isEnabled.toggle()
                            viewModel.updateSchedule(updated)
                        }
                        .padding(.horizontal, 4)
                        if index < viewModel.schedules.count - 1 {
                            Divider().padding(.leading, 4)
                        }
                    }
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

    private var importExportSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import / Export")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 10)

            HStack(spacing: 16) {
                Button {
                    _ = viewModel.exportBlocklist()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button {
                    viewModel.importBlocklist()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

    private var pomodoroSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pomodoro")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                if viewModel.pomodoroIsRunning {
                    Text("Running")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Work Duration")
                            .font(.body)
                        Text("\(Int(viewModel.pomodoroWorkMinutes)) minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Stepper("", value: $viewModel.pomodoroWorkMinutes, in: 1...120, step: 5)
                        .labelsHidden()
                        .disabled(viewModel.pomodoroIsRunning)
                }
                .padding(14)

                Divider().padding(.leading, 14)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Break Duration")
                            .font(.body)
                        Text("\(Int(viewModel.pomodoroBreakMinutes)) minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Stepper("", value: $viewModel.pomodoroBreakMinutes, in: 1...30, step: 1)
                        .labelsHidden()
                        .disabled(viewModel.pomodoroIsRunning)
                }
                .padding(14)

                Divider().padding(.leading, 14)

                HStack {
                    if viewModel.pomodoroIsRunning {
                        Button(role: .destructive) {
                            viewModel.stopPomodoro()
                        } label: {
                            Label("Stop Pomodoro", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    } else {
                        Button {
                            viewModel.startPomodoro()
                        } label: {
                            Label("Start Pomodoro", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    Spacer()
                    Text(viewModel.pomodoroIsRunning
                         ? "\(viewModel.pomodoroPhase == .work ? "Focus" : "Break") · Cycle \(viewModel.pomodoroCycleCount + 1)"
                         : "Timer appears in menu bar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

    private var appearanceSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Appearance")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Timer in Menu Bar")
                            .font(.body)
                        Text("Display countdown during active block or Pomodoro")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.showMenuBarTimer },
                        set: { viewModel.showMenuBarTimer = $0; viewModel.saveConfig() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                .padding(14)

                Divider().padding(.leading, 14)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide Dock Icon")
                            .font(.body)
                        Text("App runs from menu bar only — no dock icon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.hideDockIcon },
                        set: { viewModel.hideDockIcon = $0; viewModel.saveConfig() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                .padding(14)

                Divider().padding(.leading, 14)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu Bar Icon")
                            .font(.body)
                        Text("Shows shield outline when idle, filled when active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "shield")
                        .foregroundColor(.secondary)
                    Image(systemName: "shield.fill")
                        .foregroundColor(.blue)
                }
                .padding(14)
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

    private var generalSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("General")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.body)
                        Text("Automatically start SelfProtect when you log in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                .padding(14)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                        viewModel.errorMessage = error.localizedDescription
                    }
                }

                Divider().padding(.leading, 14)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.body)
                        Text("Show notifications when blocking starts or ends")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $showNotifications)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
                .padding(14)
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

    private var daemonSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Daemon")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Helper Daemon")
                            .font(.body)
                        Text("com.selfprotect.helper")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.daemonManager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.daemonManager.isConnected ? "Connected" : "Disconnected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)

                Divider().padding(.leading, 14)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Version")
                            .font(.body)
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("About")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 10)

            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)

                Text("SelfProtect")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Blocks distracting websites and applications with scheduled timers and category presets.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

}

struct ScheduleRowView: View {
    let schedule: BlockSchedule
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void

    private let dayLetters: [(Weekday, String)] = [
        (.sunday, "S"), (.monday, "M"), (.tuesday, "T"),
        (.wednesday, "W"), (.thursday, "T"), (.friday, "F"), (.saturday, "S")
    ]

    var isActive: Bool { schedule.isEnabled && schedule.isActive() }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(dayLetters, id: \.0) { (day, letter) in
                        Text(letter)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(schedule.days.contains(day) ? (isActive ? .white : .primary) : .secondary)
                            .frame(width: 24, height: 24)
                            .background {
                                Circle()
                                    .fill(schedule.days.contains(day)
                                        ? (isActive ? Color.secondary.opacity(0.3) : Color(nsColor: .controlBackgroundColor))
                                        : Color.gray.opacity(0.1))
                            }
                    }
                }

                HStack(spacing: 4) {
                    if isActive {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(schedule.startTimeString) - \(schedule.endTimeString)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            Spacer()

            if isActive {
                Text("Active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in if !isActive { onToggle() } }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(isActive)

            if !isActive {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .opacity(schedule.isEnabled ? 1 : 0.5)
    }
}

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let editSchedule: BlockSchedule?
    let onSave: (BlockSchedule) -> Void

    @State private var selectedDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var startDate: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endDate: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var isEnabled = true

    init(editSchedule: BlockSchedule? = nil, onSave: @escaping (BlockSchedule) -> Void) {
        self.editSchedule = editSchedule
        self.onSave = onSave
        if let schedule = editSchedule {
            _selectedDays = State(initialValue: schedule.days)
            _isEnabled = State(initialValue: schedule.isEnabled)
            if let start = Calendar.current.date(bySettingHour: schedule.startHour, minute: schedule.startMinute, second: 0, of: Date()) {
                _startDate = State(initialValue: start)
            }
            if let end = Calendar.current.date(bySettingHour: schedule.endHour, minute: schedule.endMinute, second: 0, of: Date()) {
                _endDate = State(initialValue: end)
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(editSchedule == nil ? "Add Schedule" : "Edit Schedule")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Days")
                    .font(.headline)
                HStack(spacing: 6) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Button {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        } label: {
                            Text(day.shortName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule()
                                        .fill(selectedDays.contains(day)
                                            ? Color.blue
                                            : Color.gray.opacity(0.12))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Time")
                        .font(.headline)
                    DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Time")
                        .font(.headline)
                    DatePicker("", selection: $endDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }

            Toggle("Schedule Enabled", isOn: $isEnabled)
                .toggleStyle(.switch)

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Button("Save") {
                    let calendar = Calendar.current
                    let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
                    let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
                    let schedule = BlockSchedule(
                        id: editSchedule?.id ?? UUID(),
                        days: selectedDays,
                        startHour: startComponents.hour ?? 9,
                        startMinute: startComponents.minute ?? 0,
                        endHour: endComponents.hour ?? 17,
                        endMinute: endComponents.minute ?? 0,
                        isEnabled: isEnabled
                    )
                    onSave(schedule)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .disabled(selectedDays.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
