import Foundation
import SwiftData

@MainActor
@Observable
final class AppState {
    let viewModel = ClipboardHistoryViewModel()
    let clipboardMonitor = MacClipboardMonitor()
    let syncCoordinator = SyncCoordinator()
    let modelContainer: ModelContainer

    init() {
        modelContainer = try! ModelContainer(for: ClipboardItem.self)
        viewModel.configure(modelContext: modelContainer.mainContext)

        clipboardMonitor.onNewClipboardContent = { [weak self] content in
            guard let self else { return }
            if let item = self.viewModel.addItem(content: content) {
                let message = SyncMessage(from: item)
                self.syncCoordinator.broadcast(message)
            }
        }
        clipboardMonitor.startMonitoring()

        syncCoordinator.onItemReceived = { [weak self] message in
            guard let self else { return }
            self.viewModel.addSyncedItem(message)
            self.clipboardMonitor.copyToClipboard(message.content)
        }
        syncCoordinator.start()
    }
}
