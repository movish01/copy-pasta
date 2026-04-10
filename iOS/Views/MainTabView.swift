import SwiftUI
import SwiftData
import UIKit

struct MainTabView: View {
    @Bindable var viewModel: ClipboardHistoryViewModel
    let bonjourService: BonjourSyncService

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasSetup = false
    @State private var showingCopiedToast = false
    @State private var toastMessage = "Copied!"

    var body: some View {
        TabView {
            ClipboardHistoryView(
                viewModel: viewModel,
                bonjourService: bonjourService,
                showingCopiedToast: $showingCopiedToast,
                toastMessage: $toastMessage
            )
            .tabItem {
                Label("Clipboard", systemImage: "doc.on.clipboard")
            }

            DevicesView(bonjourService: bonjourService)
                .tabItem {
                    Label("Devices", systemImage: "wifi")
                }

            iOSSettingsView(bonjourService: bonjourService)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .overlay(alignment: .top) {
            if showingCopiedToast {
                CopiedToast(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .onAppear {
            guard !hasSetup else { return }
            hasSetup = true
            setupServices()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkClipboardOnForeground()
                viewModel.fetchItems()
            }
        }
    }

    private func setupServices() {
        viewModel.configure(modelContext: modelContext)

        // Start Bonjour sync
        bonjourService.onItemReceived = { message in
            viewModel.addSyncedItem(message)
            // Auto-copy received items to clipboard
            UIPasteboard.general.string = message.content
            showToast("Received from \(message.sourceDevice)")
        }
        bonjourService.start()

        // Check clipboard on first launch
        checkClipboardOnForeground()
    }

    private func checkClipboardOnForeground() {
        if UIPasteboard.general.hasStrings,
           let content = UIPasteboard.general.string {
            if let item = viewModel.addItem(content: content) {
                let message = SyncMessage(from: item)
                bonjourService.broadcast(message)
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showingCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showingCopiedToast = false }
        }
    }
}

struct CopiedToast: View {
    var message: String = "Copied!"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.green.gradient, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.top, 8)
    }
}
