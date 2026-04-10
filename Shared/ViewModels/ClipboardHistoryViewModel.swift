import Foundation
import SwiftData
import SwiftUI
import Combine

@Observable
final class ClipboardHistoryViewModel {
    var items: [ClipboardItem] = []
    var searchText: String = ""
    var selectedFilter: FilterType = .all

    private var modelContext: ModelContext?

    enum FilterType: String, CaseIterable {
        case all = "All"
        case pinned = "Pinned"
        case text = "Text"
        case urls = "URLs"
        case thisDevice = "This Device"
    }

    var filteredItems: [ClipboardItem] {
        var result = items

        switch selectedFilter {
        case .all:
            break
        case .pinned:
            result = result.filter { $0.isPinned }
        case .text:
            result = result.filter { $0.contentType == .text }
        case .urls:
            result = result.filter { $0.contentType == .url }
        case .thisDevice:
            result = result.filter { $0.sourceDevice == DeviceInfo.deviceName }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Pinned items first, then by timestamp
        return result.sorted { a, b in
            if a.isPinned != b.isPinned {
                return a.isPinned
            }
            return a.timestamp > b.timestamp
        }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchItems()
    }

    func fetchItems() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        do {
            items = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch items: \(error)")
        }
    }

    @discardableResult
    func addItem(content: String, contentType: ClipboardItem.ContentType = .text) -> ClipboardItem? {
        guard let modelContext else { return nil }

        // Don't add duplicate of the most recent item
        if let latest = items.first, latest.content == content {
            return nil
        }

        // Don't add empty content
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Auto-detect content type
        let detectedType = detectContentType(trimmed)

        let item = ClipboardItem(
            content: trimmed,
            contentType: detectedType,
            sourceDevice: DeviceInfo.deviceName
        )

        modelContext.insert(item)
        try? modelContext.save()
        fetchItems()

        // Enforce max history (keep last 500 items)
        enforceHistoryLimit()

        return item
    }

    func addSyncedItem(_ message: SyncMessage) {
        guard let modelContext else { return }

        // Check if this item already exists
        let existingID = message.id
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.id == existingID }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            return
        }

        let item = ClipboardItem(
            content: message.content,
            contentType: ClipboardItem.ContentType(rawValue: message.contentType) ?? .text,
            sourceDevice: message.sourceDevice
        )
        // Preserve the original ID and timestamp
        item.id = message.id
        item.timestamp = message.timestamp

        modelContext.insert(item)
        try? modelContext.save()
        fetchItems()
    }

    func deleteItem(_ item: ClipboardItem) {
        guard let modelContext else { return }
        modelContext.delete(item)
        try? modelContext.save()
        fetchItems()
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        try? modelContext?.save()
        fetchItems()
    }

    func toggleFavorite(_ item: ClipboardItem) {
        item.isFavorite.toggle()
        try? modelContext?.save()
        fetchItems()
    }

    func clearUnpinned() {
        guard let modelContext else { return }
        let unpinned = items.filter { !$0.isPinned }
        for item in unpinned {
            modelContext.delete(item)
        }
        try? modelContext.save()
        fetchItems()
    }

    private func detectContentType(_ content: String) -> ClipboardItem.ContentType {
        if let url = URL(string: content), url.scheme != nil {
            return .url
        }
        // Simple code detection heuristics
        let codeIndicators = ["func ", "class ", "import ", "var ", "let ", "def ", "function ", "const ", "=>", "->", "{{", "}}", "();"]
        if codeIndicators.contains(where: { content.contains($0) }) && content.contains("\n") {
            return .code
        }
        return .text
    }

    private func enforceHistoryLimit(maxItems: Int = 500) {
        guard let modelContext else { return }
        let unpinned = items.filter { !$0.isPinned }.sorted { $0.timestamp > $1.timestamp }
        if unpinned.count > maxItems {
            let toDelete = unpinned.suffix(from: maxItems)
            for item in toDelete {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }
}
