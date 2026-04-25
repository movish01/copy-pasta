import Foundation
import CryptoKit

@Observable
final class RelaySyncService {
    var isConnected = false
    var connectionStatus: ConnectionStatus = .disconnected
    var roomMembers: [RoomMember] = []
    var roomId: String?

    var onItemReceived: ((SyncMessage) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var encryptionKey: SymmetricKey?
    private var pingTimer: Timer?
    private var reconnectAttempts = 0
    private var shouldReconnect = false
    private var currentPassphrase: String?
    private let session = URLSession(configuration: .default)

    enum ConnectionStatus: String {
        case disconnected = "Relay Off"
        case connecting = "Connecting..."
        case connected = "Relay Connected"
        case error = "Relay Error"
    }

    struct RoomMember: Identifiable, Codable, Hashable {
        let deviceId: String
        let deviceName: String
        let platform: String
        var id: String { deviceId }
    }

    // MARK: - Public API

    func joinRoom(passphrase: String) {
        currentPassphrase = passphrase
        shouldReconnect = true
        reconnectAttempts = 0

        // Derive room ID and encryption key
        roomId = RelayCrypto.roomId(from: passphrase)
        encryptionKey = RelayCrypto.deriveKey(from: passphrase)

        // Save passphrase to Keychain for auto-reconnect
        KeychainHelper.save(key: "relayPassphrase", value: passphrase)

        connect()
    }

    func leaveRoom() {
        shouldReconnect = false
        currentPassphrase = nil
        roomId = nil
        encryptionKey = nil
        roomMembers = []

        KeychainHelper.delete(key: "relayPassphrase")

        sendMessage(["type": "leave"])
        disconnect()
    }

    func broadcast(_ message: SyncMessage) {
        guard isConnected, let key = encryptionKey, let data = message.toData() else { return }

        do {
            let encrypted = try RelayCrypto.encrypt(data, using: key)
            let payload = encrypted.base64EncodedString()
            sendMessage(["type": "relay", "payload": payload])
        } catch {
            print("[Relay] Encrypt error: \(error)")
        }
    }

    /// Attempt to reconnect using saved passphrase from Keychain
    func autoReconnect() {
        guard roomId == nil, let saved = KeychainHelper.load(key: "relayPassphrase") else { return }
        joinRoom(passphrase: saved)
    }

    // MARK: - Connection

    private func connect() {
        disconnect()

        DispatchQueue.main.async { self.connectionStatus = .connecting }

        let url = RelayConfig.serverURL
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Send join message
        guard let rid = roomId else { return }
        sendMessage([
            "type": "join",
            "roomId": rid,
            "deviceId": DeviceInfo.deviceID,
            "deviceName": DeviceInfo.deviceName,
            "platform": DeviceInfo.platform,
        ])

        receiveLoop()
        startPingTimer()
    }

    private func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = .disconnected
        }
    }

    // MARK: - Send

    private func sendMessage(_ dict: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(text)) { error in
            if let error {
                print("[Relay] Send error: \(error)")
            }
        }
    }

    // MARK: - Receive

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(.string(let text)):
                self.handleMessage(text)
                self.receiveLoop()

            case .success(.data(let data)):
                if let text = String(data: data, encoding: .utf8) {
                    self.handleMessage(text)
                }
                self.receiveLoop()

            case .failure(let error):
                print("[Relay] Receive error: \(error)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.connectionStatus = .error
                }
                self.attemptReconnect()

            @unknown default:
                self.receiveLoop()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "joined":
            handleJoined(json)
        case "peer_joined":
            handlePeerJoined(json)
        case "peer_left":
            handlePeerLeft(json)
        case "relay":
            handleRelay(json)
        case "pong":
            break
        case "error":
            let msg = json["message"] as? String ?? "Unknown error"
            print("[Relay] Server error: \(msg)")
            DispatchQueue.main.async { self.connectionStatus = .error }
        default:
            break
        }
    }

    private func handleJoined(_ json: [String: Any]) {
        reconnectAttempts = 0

        var members: [RoomMember] = []
        if let list = json["members"] as? [[String: String]] {
            for m in list {
                if let did = m["deviceId"], did != DeviceInfo.deviceID {
                    members.append(RoomMember(
                        deviceId: did,
                        deviceName: m["deviceName"] ?? "Unknown",
                        platform: m["platform"] ?? "Unknown"
                    ))
                }
            }
        }

        DispatchQueue.main.async {
            self.roomMembers = members
            self.isConnected = true
            self.connectionStatus = .connected
        }

        print("[Relay] Joined room with \(members.count) other member(s)")
    }

    private func handlePeerJoined(_ json: [String: Any]) {
        guard let did = json["deviceId"] as? String, did != DeviceInfo.deviceID else { return }
        let member = RoomMember(
            deviceId: did,
            deviceName: json["deviceName"] as? String ?? "Unknown",
            platform: json["platform"] as? String ?? "Unknown"
        )

        DispatchQueue.main.async {
            if !self.roomMembers.contains(where: { $0.deviceId == did }) {
                self.roomMembers.append(member)
            }
        }
    }

    private func handlePeerLeft(_ json: [String: Any]) {
        guard let did = json["deviceId"] as? String else { return }
        DispatchQueue.main.async {
            self.roomMembers.removeAll { $0.deviceId == did }
        }
    }

    private func handleRelay(_ json: [String: Any]) {
        guard let payload = json["payload"] as? String,
              let encrypted = Data(base64Encoded: payload),
              let key = encryptionKey else { return }

        do {
            let decrypted = try RelayCrypto.decrypt(encrypted, using: key)
            if let message = SyncMessage.from(data: decrypted) {
                DispatchQueue.main.async {
                    self.onItemReceived?(message)
                }
            }
        } catch {
            print("[Relay] Decrypt error: \(error)")
        }
    }

    // MARK: - Ping / Reconnect

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendMessage(["type": "ping"])
        }
    }

    private func attemptReconnect() {
        guard shouldReconnect, currentPassphrase != nil else { return }

        reconnectAttempts += 1
        let delay = min(Double(1 << reconnectAttempts), 30.0) // 1, 2, 4, 8, 16, 30, 30...

        print("[Relay] Reconnecting in \(delay)s (attempt \(reconnectAttempts))")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldReconnect else { return }
            self.connect()
        }
    }
}
