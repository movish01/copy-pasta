import Foundation

@Observable
final class SyncCoordinator {
    let bonjour = BonjourSyncService()
    let relay = RelaySyncService()

    var onItemReceived: ((SyncMessage) -> Void)?

    // Deduplication — track recently seen message IDs
    private var recentIds: Set<UUID> = []
    private var recentIdTimestamps: [(UUID, Date)] = []
    private let maxRecentIds = 200

    var allPeers: [PeerInfo] {
        var peers: [PeerInfo] = []
        for p in bonjour.discoveredPeers {
            peers.append(PeerInfo(id: p.id, name: p.name, platform: "", connectionType: .lan))
        }
        for m in relay.roomMembers {
            // Don't duplicate if same device is on both LAN and relay
            if !peers.contains(where: { $0.name == m.deviceName }) {
                peers.append(PeerInfo(id: m.deviceId, name: m.deviceName, platform: m.platform, connectionType: .relay))
            }
        }
        return peers
    }

    var hasAnyConnection: Bool {
        !bonjour.discoveredPeers.isEmpty || relay.isConnected
    }

    struct PeerInfo: Identifiable {
        let id: String
        let name: String
        let platform: String
        let connectionType: ConnectionType
    }

    enum ConnectionType {
        case lan
        case relay
    }

    // MARK: - Lifecycle

    func start() {
        bonjour.onItemReceived = { [weak self] message in
            self?.handleReceived(message, via: "Bonjour")
        }
        bonjour.start()

        relay.onItemReceived = { [weak self] message in
            self?.handleReceived(message, via: "Relay")
        }
        // Auto-reconnect relay if passphrase was previously saved
        relay.autoReconnect()
    }

    func stop() {
        bonjour.stop()
        relay.leaveRoom()
    }

    // MARK: - Broadcasting

    func broadcast(_ message: SyncMessage) {
        // Track this ID so we don't echo it back
        trackId(message.id)

        // Send on both transports
        bonjour.broadcast(message)
        if relay.isConnected {
            relay.broadcast(message)
        }
    }

    // MARK: - Relay Room

    func joinRelayRoom(passphrase: String) {
        relay.joinRoom(passphrase: passphrase)
    }

    func leaveRelayRoom() {
        relay.leaveRoom()
    }

    // MARK: - Dedup

    private func handleReceived(_ message: SyncMessage, via transport: String) {
        // Skip if already received via other transport
        guard !recentIds.contains(message.id) else {
            print("[SyncCoord] Dedup: skipping \(message.id) already received")
            return
        }

        trackId(message.id)
        onItemReceived?(message)
    }

    private func trackId(_ id: UUID) {
        recentIds.insert(id)
        recentIdTimestamps.append((id, Date()))
        pruneOldIds()
    }

    private func pruneOldIds() {
        guard recentIdTimestamps.count > maxRecentIds else { return }
        let overflow = recentIdTimestamps.count - maxRecentIds
        let removed = recentIdTimestamps.prefix(overflow)
        recentIdTimestamps.removeFirst(overflow)
        for (id, _) in removed {
            recentIds.remove(id)
        }
    }
}
