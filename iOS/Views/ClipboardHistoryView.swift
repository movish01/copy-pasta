import SwiftUI
import SwiftData
import UIKit

struct ClipboardHistoryView: View {
    @Bindable var viewModel: ClipboardHistoryViewModel
    let syncCoordinator: SyncCoordinator
    @Binding var showingCopiedToast: Bool
    @Binding var toastMessage: String

    @State private var showingDetail: ClipboardItem?
    @State private var showingClearConfirm = false
    @State private var showingSendSheet: ClipboardItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FilterBar(
                    selectedFilter: $viewModel.selectedFilter,
                    searchText: $viewModel.searchText
                )
                .padding(.horizontal)
                .padding(.top, 8)

                SyncStatusView(syncCoordinator: syncCoordinator)

                Divider()

                if viewModel.filteredItems.isEmpty {
                    emptyState
                } else {
                    itemsList
                }
            }
            .navigationTitle("CopyPasta")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: {
                            showingClearConfirm = true
                        }) {
                            Label("Clear Unpinned", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { addFromClipboard() }) {
                        Label("Capture Clipboard", systemImage: "plus.circle")
                    }
                }
            }
            .alert("Clear History", isPresented: $showingClearConfirm) {
                Button("Clear", role: .destructive) {
                    viewModel.clearUnpinned()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove all unpinned items? Pinned items are kept.")
            }
            .sheet(item: $showingDetail) { item in
                ItemDetailView(
                    item: item,
                    syncCoordinator: syncCoordinator,
                    onCopy: { copyToClipboard(item.content) }
                )
            }
            .sheet(item: $showingSendSheet) { item in
                SendToDeviceSheet(item: item, syncCoordinator: syncCoordinator)
            }
        }
    }

    // MARK: - Items list

    private var itemsList: some View {
        List {
            ForEach(viewModel.filteredItems) { item in
                ClipboardItemRow(
                    item: item,
                    onCopy: { copyToClipboard(item.content) },
                    onTogglePin: { viewModel.togglePin(item) },
                    onDelete: { viewModel.deleteItem(item) }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowSeparator(.hidden)
                .contentShape(Rectangle())
                .onTapGesture {
                    showingDetail = item
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteItem(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        viewModel.togglePin(item)
                    } label: {
                        Label(
                            item.isPinned ? "Unpin" : "Pin",
                            systemImage: item.isPinned ? "pin.slash" : "pin"
                        )
                    }
                    .tint(.orange)

                    if !syncCoordinator.allPeers.isEmpty {
                        Button {
                            showingSendSheet = item
                        } label: {
                            Label("Send", systemImage: "paperplane")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Clipboard Items", systemImage: "clipboard")
        } description: {
            Text("Copy something or tap + to capture your current clipboard")
        } actions: {
            Button("Capture Clipboard") {
                addFromClipboard()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        toastMessage = "Copied!"
        withAnimation { showingCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { showingCopiedToast = false }
        }
    }

    private func addFromClipboard() {
        if UIPasteboard.general.hasStrings,
           let content = UIPasteboard.general.string {
            if let item = viewModel.addItem(content: content) {
                let message = SyncMessage(from: item)
                syncCoordinator.broadcast(message)
            }
        }
    }
}

// MARK: - Send to Device Sheet

struct SendToDeviceSheet: View {
    let item: ClipboardItem
    let syncCoordinator: SyncCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var sent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sending:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.preview)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .padding(.horizontal)

                if syncCoordinator.allPeers.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Looking for devices...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                } else {
                    VStack(spacing: 12) {
                        ForEach(syncCoordinator.allPeers) { peer in
                            Button(action: {
                                let message = SyncMessage(from: item)
                                syncCoordinator.broadcast(message)
                                sent = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    dismiss()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: peerIcon(for: peer))
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(peer.connectionType == .lan ? .green.opacity(0.1) : .blue.opacity(0.1))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(peer.name)
                                            .font(.headline)
                                        Text(peer.connectionType == .lan ? "LAN" : "Relay")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if sent {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Send to Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func peerIcon(for peer: SyncCoordinator.PeerInfo) -> String {
        let lower = peer.name.lowercased()
        if lower.contains("mac") || lower.contains("book") || lower.contains("imac") { return "laptopcomputer" }
        if lower.contains("ipad") { return "ipad" }
        if lower.contains("iphone") { return "iphone" }
        return "desktopcomputer"
    }
}
