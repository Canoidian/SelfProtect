import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        TabView {
            DashboardView(viewModel: viewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "house")
                }

            BlockListView(viewModel: viewModel)
                .tabItem {
                    Label("Block List", systemImage: "list.bullet")
                }

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .background(.ultraThinMaterial)
        .task {
            viewModel.daemonManager.connect()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}
