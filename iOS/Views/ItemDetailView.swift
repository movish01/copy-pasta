import SwiftUI

struct ItemDetailView: View {
    let item: ClipboardItem
    let bonjourService: BonjourSyncService
    let onCopy: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingSendSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Metadata
                    HStack(spacing: 16) {
                        Label(item.contentType.rawValue.capitalized, systemImage: typeIcon)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1), in: Capsule())

                        if !item.sourceDevice.isEmpty {
                            Label(item.sourceDevice, systemImage: deviceIcon)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(item.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Full content
                    Text(item.content)
                        .font(item.contentType == .code ? .system(.body, design: .monospaced) : .body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )

                    // Stats
                    HStack {
                        Text("\(item.content.count) characters")
                        if item.content.contains("\n") {
                            Text("\(item.content.components(separatedBy: "\n").count) lines")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                    // Actions
                    HStack(spacing: 12) {
                        Button(action: {
                            onCopy()
                            dismiss()
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        if !bonjourService.discoveredPeers.isEmpty {
                            Button(action: {
                                let message = SyncMessage(from: item)
                                bonjourService.broadcast(message)
                                dismiss()
                            }) {
                                Label("Send", systemImage: "paperplane.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var typeIcon: String {
        switch item.contentType {
        case .text: return "doc.text"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        }
    }

    private var deviceIcon: String {
        let lower = item.sourceDevice.lowercased()
        if lower.contains("mac") || lower.contains("book") { return "laptopcomputer" }
        return "iphone"
    }
}
