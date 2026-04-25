import SwiftUI
import SwiftData

@main
struct CopyPastaMacApp: App {
    @State private var viewModel = ClipboardHistoryViewModel()
    @State private var clipboardMonitor = MacClipboardMonitor()
    @State private var syncCoordinator = SyncCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(
                viewModel: viewModel,
                clipboardMonitor: clipboardMonitor,
                syncCoordinator: syncCoordinator
            )
            .modelContainer(for: ClipboardItem.self)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(syncCoordinator: syncCoordinator)
        }
    }
}
