import SwiftUI
import SwiftData

@main
struct CopyPastaMacApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(
                viewModel: appState.viewModel,
                clipboardMonitor: appState.clipboardMonitor,
                syncCoordinator: appState.syncCoordinator
            )
            .modelContainer(appState.modelContainer)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(syncCoordinator: appState.syncCoordinator)
        }
    }
}
