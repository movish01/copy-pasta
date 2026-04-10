import SwiftUI
import SwiftData

@main
struct CopyPastaiOSApp: App {
    @State private var viewModel = ClipboardHistoryViewModel()
    @State private var bonjourService = BonjourSyncService()

    var body: some Scene {
        WindowGroup {
            MainTabView(
                viewModel: viewModel,
                bonjourService: bonjourService
            )
            .modelContainer(for: ClipboardItem.self)
        }
    }
}
