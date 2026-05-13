import SwiftUI
import AppKit
import SelfProtectKit

struct BlockListView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedSegment: BlockListSegment = .websites
    @State private var newDomain = ""
    @State private var newBundleID = ""
    @State private var newDisplayName = ""
    @State private var websiteSearchText = ""
    @State private var appSearchText = ""
    @State private var installedApps: [(bundleID: String, displayName: String)] = []
    @State private var showError = false
    @State private var showBlockConfirm = false
    @State private var pendingBlockAction: (() -> Void)?

    enum BlockListSegment: String, CaseIterable {
        case websites = "Websites"
        case apps = "Apps"
        case categories = "Categories"
    }

    var filteredWebsites: [WebsiteBlock] {
        if websiteSearchText.isEmpty { return viewModel.websites }
        return viewModel.websites.filter { $0.domain.localizedCaseInsensitiveContains(websiteSearchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Block List", systemImage: "list.bullet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Picker("", selection: $selectedSegment) {
                ForEach(BlockListSegment.allCases, id: \.self) { seg in
                    Text(seg.rawValue).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider().padding(.top, 8)

            contentSection
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert("Add While Blocking?", isPresented: $showBlockConfirm) {
            Button("Cancel", role: .cancel) { pendingBlockAction = nil }
            Button("Add", role: .destructive) {
                pendingBlockAction?()
                pendingBlockAction = nil
            }
        } message: {
            Text("This item will now be blocked and cannot be turned off until the block ends.")
        }
        .task {
            installedApps = AppBlocker.scanInstalledApps()
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch selectedSegment {
        case .websites:
            websitesContent
        case .apps:
            appsContent
        case .categories:
            categoriesContent
        }
    }

    private var websitesContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Enter domain (e.g. facebook.com)", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addDomain() }
                Button("Add") { addDomain() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            .padding(.horizontal)
            .padding(.vertical, 10)

            if filteredWebsites.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No websites blocked")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredWebsites) { site in
                        HStack(spacing: 10) {
                            Text(site.domain)
                                .font(.body)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.removeWebsite(filteredWebsites[index].id)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var appsContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Bundle ID (e.g. com.apple.Safari)", text: $newBundleID)
                    .textFieldStyle(.roundedBorder)
                TextField("Display Name", text: $newDisplayName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                Button("Add") {
                    let bid = newBundleID
                    let name = newDisplayName
                    if viewModel.isBlocking {
                        pendingBlockAction = { [bid, name] in
                            viewModel.addApp(bundleID: bid, displayName: name)
                        }
                        showBlockConfirm = true
                    } else {
                        viewModel.addApp(bundleID: bid, displayName: name)
                        newBundleID = ""
                        newDisplayName = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            TextField("Search installed apps...", text: $appSearchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            if installedApps.isEmpty {
                ProgressView("Scanning installed apps...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let filtered = appSearchText.isEmpty
                    ? installedApps
                    : installedApps.filter { $0.displayName.localizedCaseInsensitiveContains(appSearchText) }

                List {
                    ForEach(filtered, id: \.bundleID) { app in
                        let isBlocked = viewModel.apps.contains(where: { $0.bundleID == app.bundleID })
                        HStack(spacing: 10) {
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "app")
                                    .frame(width: 20, height: 20)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(app.displayName)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { isBlocked },
                                set: { newValue in
                                    if newValue {
                                        viewModel.addApp(bundleID: app.bundleID, displayName: app.displayName)
                                    } else if let a = viewModel.apps.first(where: { $0.bundleID == app.bundleID }) {
                                        viewModel.removeApp(a.id)
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var categoriesContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Toggle a category to block all related websites and apps. Use \"Allow\" to exclude specific items.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                    ForEach(PresetData.allPresets) { preset in
                        CategoryCardView(
                            preset: preset,
                            isOn: viewModel.categoryProvider.isEnabled(preset),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    viewModel.toggleCategoryPreset(preset)
                                }
                            },
                            isBlocking: viewModel.isBlocking,
                            allowlistedDomains: viewModel.allowlistedDomains,
                            allowlistedAppIDs: viewModel.allowlistedAppIDs,
                            onToggleDomainAllow: { domain in
                                viewModel.toggleAllowlistedDomain(domain)
                            },
                            onToggleAppAllow: { bundleID in
                                viewModel.toggleAllowlistedApp(bundleID)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 16)
        }
    }

    private func addDomain() {
        let domain = newDomain
        if viewModel.isBlocking {
            pendingBlockAction = { [domain] in
                viewModel.addWebsite(domain)
                newDomain = ""
            }
            showBlockConfirm = true
        } else {
            viewModel.addWebsite(domain)
            newDomain = ""
        }
    }
}

struct CategoryCardView: View {
    let preset: BlockPreset
    let isOn: Bool
    let onToggle: () -> Void
    var isBlocking = false
    var allowlistedDomains: Set<String> = []
    var allowlistedAppIDs: Set<String> = []
    var onToggleDomainAllow: ((String) -> Void)?
    var onToggleAppAllow: ((String) -> Void)?

    @State private var showDetail = false
    @State private var showCategoryConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: preset.symbolName)
                    .font(.title3)
                    .foregroundColor(isOn ? .blue : .secondary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(isOn ? Color.blue.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                    }

                Text(preset.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: Binding(get: { isOn }, set: { newValue in
                    if isBlocking && newValue {
                        showCategoryConfirm = true
                    } else if !isBlocking {
                        onToggle()
                    }
                }))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            HStack(spacing: 16) {
                Label("\(preset.websites.count) sites", systemImage: "globe")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("\(preset.apps.count) apps", systemImage: "app")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if showDetail {
                Divider()

                if !preset.websites.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Websites")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        ForEach(preset.websites.sorted(), id: \.self) { site in
                            HStack(spacing: 4) {
                                let allowed = allowlistedDomains.contains(site)
                                Image(systemName: allowed ? "checkmark.circle.fill" : "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(allowed ? .green : .secondary)
                                Text(site)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                                Button(allowed ? "Allowed" : "Allow") {
                                    onToggleDomainAllow?(site)
                                }
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                let installedApps = preset.apps.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.key) != nil }
                if !installedApps.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apps")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        ForEach(installedApps.sorted(by: { $0.value < $1.value }), id: \.key) { bundleID, name in
                            HStack(spacing: 4) {
                                let allowed = allowlistedAppIDs.contains(bundleID)
                                Image(systemName: allowed ? "checkmark.circle.fill" : "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(allowed ? .green : .secondary)
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                                Button(allowed ? "Allowed" : "Allow") {
                                    onToggleAppAllow?(bundleID)
                                }
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetail.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(showDetail ? "Hide details" : "Show details")
                        .font(.caption)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .rotationEffect(.degrees(showDetail ? 180 : 0))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(alignment: .center) {
            Group {
                if isOn {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isOn ? Color.clear : Color.gray.opacity(0.15), lineWidth: isOn ? 0 : 0.5)
        }
        .alert("Add Category During Block?", isPresented: $showCategoryConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Add", role: .destructive) { onToggle() }
        } message: {
            Text("This category will be blocked and cannot be turned off until the block ends.")
        }
    }
}
