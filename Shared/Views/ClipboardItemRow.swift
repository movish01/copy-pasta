import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Content type icon
            contentTypeIcon
                .foregroundStyle(iconColor)
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Content preview
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(item.formattedTimestamp)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !item.sourceDevice.isEmpty {
                        Label(item.sourceDevice, systemImage: deviceIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                #if os(macOS)
                if isHovered {
                    actionButtons
                }
                #else
                actionButtons
                #endif
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        #endif
        .onTapGesture {
            onCopy()
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: onCopy) {
            Image(systemName: "doc.on.doc")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .help("Copy to clipboard")

        Button(action: onTogglePin) {
            Image(systemName: item.isPinned ? "pin.slash" : "pin")
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .help(item.isPinned ? "Unpin" : "Pin")

        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundStyle(.red.opacity(0.7))
        }
        .buttonStyle(.borderless)
        .help("Delete")
    }

    private var contentTypeIcon: Image {
        switch item.contentType {
        case .text:
            return Image(systemName: "doc.text")
        case .url:
            return Image(systemName: "link")
        case .code:
            return Image(systemName: "chevron.left.forwardslash.chevron.right")
        case .image:
            return Image(systemName: "photo")
        }
    }

    private var iconColor: Color {
        switch item.contentType {
        case .text: return .blue
        case .url: return .green
        case .code: return .purple
        case .image: return .orange
        }
    }

    private var deviceIcon: String {
        if item.sourceDevice.lowercased().contains("mac") || item.sourceDevice.lowercased().contains("book") {
            return "laptopcomputer"
        }
        return "iphone"
    }
}
