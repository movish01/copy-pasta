import SwiftUI
import SwiftData

@main
struct CopyPastaiOSApp: App {
    @State private var viewModel = ClipboardHistoryViewModel()
    @State private var syncCoordinator = SyncCoordinator()

    var body: some Scene {
        WindowGroup {
            MainTabView(
                viewModel: viewModel,
                syncCoordinator: syncCoordinator
            )
            .modelContainer(for: ClipboardItem.self)
        }
    }
}
