import SwiftUI

@main
struct SelfProtectApp: App {
    @StateObject private var daemonManager = DaemonManager()
    @StateObject private var categoryProvider = CategoryProvider()
    @State private var viewModel: AppViewModel?
    private let statusBar = StatusBarController()

    var body: some Scene {
        WindowGroup {
            if let vm = viewModel {
                ContentView(viewModel: vm)
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .onChange(of: (viewModel?.pomodoroIsRunning ?? false)) { _, _ in
            statusBar.updateStatusItem()
        }
    }

    init() {
        let dm = DaemonManager()
        let cp = CategoryProvider()
        let vm = AppViewModel(daemonManager: dm, categoryProvider: cp)
        _daemonManager = StateObject(wrappedValue: dm)
        _categoryProvider = StateObject(wrappedValue: cp)
        _viewModel = State(initialValue: vm)
        statusBar.setup(with: vm)
    }
}
