import SwiftUI
import SwiftData

struct MenuBarPopover: View {
    @Bindable var viewModel: ClipboardHistoryViewModel
    let clipboardMonitor: MacClipboardMonitor
    let bonjourService: BonjourSyncService

    @Environment(\.modelContext) private var modelContext
    @State private var hasSetup = false
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Filter & Search
            FilterBar(
                selectedFilter: $viewModel.selectedFilter,
                searchText: $viewModel.searchText
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Clipboard items list
            if viewModel.filteredItems.isEmpty {
                emptyState
            } else {
                clipboardList
            }

            Divider()

            // Sync status + bottom bar
            SyncStatusView(bonjourService: bonjourService)

            bottomBar
        }
        .frame(width: 400, height: 540)
        .overlay(alignment: .top) {
            if showCopied {
                Text("Copied!")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.green.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 44)
            }
        }
        .onAppear {
            guard !hasSetup else { return }
            hasSetup = true
            setupServices()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("CopyPasta")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            // Device indicator
            if !bonjourService.discoveredPeers.isEmpty {
                ForEach(bonjourService.discoveredPeers) { peer in
                    HStack(spacing: 4) {
                        Image(systemName: peerIcon(for: peer.name))
                            .font(.caption)
                        Text(peer.name)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.1), in: Capsule())
                    .foregroundStyle(.green)
                }
            }

            Menu {
                Button("Clear Unpinned") {
                    viewModel.clearUnpinned()
                }
                Divider()
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                Divider()
                Button("Quit CopyPasta") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - List

    private var clipboardList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.filteredItems) { item in
                    ClipboardItemRow(
                        item: item,
                        onCopy: {
                            clipboardMonitor.copyToClipboard(item.content)
                            flashCopied()
                        },
                        onTogglePin: {
                            viewModel.togglePin(item)
                        },
                        onDelete: {
                            viewModel.deleteItem(item)
                        }
                    )
                    .contextMenu {
                        Button("Copy") {
                            clipboardMonitor.copyToClipboard(item.content)
                            flashCopied()
                        }
                        Button(item.isPinned ? "Unpin" : "Pin") {
                            viewModel.togglePin(item)
                        }

                        if !bonjourService.discoveredPeers.isEmpty {
                            Divider()
                            Menu("Send to...") {
                                ForEach(bonjourService.discoveredPeers) { peer in
                                    Button(peer.name) {
                                        let message = SyncMessage(from: item)
                                        bonjourService.broadcast(message)
                                    }
                                }
                            }
                        }

                        Divider()
                        Button("Delete", role: .destructive) {
                            viewModel.deleteItem(item)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No clipboard items yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Copy something to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            Text("\(viewModel.items.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if bonjourService.discoveredPeers.isEmpty {
                Label("No devices nearby", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Setup

    private func setupServices() {
        viewModel.configure(modelContext: modelContext)

        // Start clipboard monitoring
        clipboardMonitor.onNewClipboardContent = { content in
            if let item = viewModel.addItem(content: content) {
                // Auto-broadcast to all nearby peers
                let message = SyncMessage(from: item)
                bonjourService.broadcast(message)
            }
        }
        clipboardMonitor.startMonitoring()

        // Start Bonjour sync — receive items from peers
        bonjourService.onItemReceived = { message in
            viewModel.addSyncedItem(message)
            // Auto-copy the latest received item to clipboard
            clipboardMonitor.copyToClipboard(message.content)
        }
        bonjourService.start()
    }

    private func flashCopied() {
        withAnimation(.easeInOut(duration: 0.2)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) { showCopied = false }
        }
    }

    private func peerIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("iphone") || lower.contains("phone") { return "iphone" }
        if lower.contains("ipad") { return "ipad" }
        return "desktopcomputer"
    }
}
