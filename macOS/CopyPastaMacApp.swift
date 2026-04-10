import SwiftUI
import SwiftData

@main
struct CopyPastaMacApp: App {
    @State private var viewModel = ClipboardHistoryViewModel()
    @State private var clipboardMonitor = MacClipboardMonitor()
    @State private var bonjourService = BonjourSyncService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(
                viewModel: viewModel,
                clipboardMonitor: clipboardMonitor,
                bonjourService: bonjourService
            )
            .modelContainer(for: ClipboardItem.self)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(bonjourService: bonjourService)
        }
    }
}
