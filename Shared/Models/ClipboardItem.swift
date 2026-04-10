import Foundation
import SwiftData

@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var content: String
    var contentType: ContentType
    var sourceDevice: String
    var timestamp: Date
    var isPinned: Bool
    var isFavorite: Bool

    enum ContentType: String, Codable {
        case text
        case url
        case code
        case image // stored as base64 for simplicity
    }

    init(
        content: String,
        contentType: ContentType = .text,
        sourceDevice: String = "",
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.content = content
        self.contentType = contentType
        self.sourceDevice = sourceDevice
        self.timestamp = Date()
        self.isPinned = isPinned
        self.isFavorite = false
    }

    var preview: String {
        if content.count <= 100 {
            return content
        }
        return String(content.prefix(100)) + "..."
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
