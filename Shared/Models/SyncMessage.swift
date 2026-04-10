import Foundation

struct SyncMessage: Codable {
    let id: UUID
    let content: String
    let contentType: String
    let sourceDevice: String
    let timestamp: Date
    let action: Action

    enum Action: String, Codable {
        case add
        case delete
        case pin
        case unpin
    }

    init(from item: ClipboardItem, action: Action = .add) {
        self.id = item.id
        self.content = item.content
        self.contentType = item.contentType.rawValue
        self.sourceDevice = item.sourceDevice
        self.timestamp = item.timestamp
        self.action = action
    }

    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func from(data: Data) -> SyncMessage? {
        try? JSONDecoder().decode(SyncMessage.self, from: data)
    }
}
