import Foundation
import Network

@Observable
final class BonjourSyncService {
    var discoveredPeers: [PeerDevice] = []
    var isRunning = false
    var connectionStatus: ConnectionStatus = .disconnected

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]
    private let serviceType = "_copypasta._tcp"
    private let queue = DispatchQueue(label: "com.copypasta.sync", qos: .userInitiated)

    var onItemReceived: ((SyncMessage) -> Void)?

    enum ConnectionStatus: String {
        case disconnected = "Disconnected"
        case listening = "Listening"
        case connected = "Connected"
        case browsing = "Browsing"
    }

    struct PeerDevice: Identifiable, Hashable {
        let id: String
        let name: String
        let endpoint: NWEndpoint

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: PeerDevice, rhs: PeerDevice) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        startListener()
        startBrowser()
        isRunning = true
    }

    func stop() {
        listener?.cancel()
        browser?.cancel()
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        discoveredPeers.removeAll()
        isRunning = false
        connectionStatus = .disconnected
    }

    // MARK: - Send

    func broadcast(_ message: SyncMessage) {
        guard let data = message.toData() else { return }
        let framedData = frameMessage(data)
        for (_, connection) in connections {
            connection.send(content: framedData, completion: .contentProcessed { error in
                if let error {
                    print("[Sync] Send error: \(error)")
                }
            })
        }
    }

    // MARK: - Listener

    private func startListener() {
        do {
            let txtRecord = NWTXTRecord(["device": DeviceInfo.deviceName, "id": DeviceInfo.deviceID])
            let params = NWParameters.tcp
            params.includePeerToPeer = true

            listener = try NWListener(using: params)
            listener?.service = NWListener.Service(
                name: DeviceInfo.deviceID,
                type: serviceType,
                txtRecord: txtRecord
            )

            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.connectionStatus = .listening
                        print("[Sync] Listener ready")
                    case .failed(let error):
                        print("[Sync] Listener failed: \(error)")
                        self?.connectionStatus = .disconnected
                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener?.start(queue: queue)
        } catch {
            print("[Sync] Failed to create listener: \(error)")
        }
    }

    // MARK: - Browser

    private func startBrowser() {
        let params = NWParameters()
        params.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: params)

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.handleBrowseResults(results)
            }
        }

        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[Sync] Browser ready")
            case .failed(let error):
                print("[Sync] Browser failed: \(error)")
            default:
                break
            }
        }

        browser?.start(queue: queue)
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var peers: [PeerDevice] = []

        for result in results {
            // Don't connect to ourselves
            if case .service(let name, _, _, _) = result.endpoint, name == DeviceInfo.deviceID {
                continue
            }

            var deviceName = "Unknown"
            if case .service(let name, _, _, _) = result.endpoint {
                deviceName = name
            }
            if case .bonjour(let record) = result.metadata {
                if let name = record["device"] {
                    deviceName = name
                }
            }

            let peer = PeerDevice(
                id: deviceName,
                name: deviceName,
                endpoint: result.endpoint
            )
            peers.append(peer)

            // Auto-connect to discovered peers
            if connections[peer.id] == nil {
                connectToPeer(peer)
            }
        }

        discoveredPeers = peers
    }

    // MARK: - Connection handling

    private func connectToPeer(_ peer: PeerDevice) {
        let params = NWParameters.tcp
        params.includePeerToPeer = true

        let connection = NWConnection(to: peer.endpoint, using: params)
        connections[peer.id] = connection

        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("[Sync] Connected to \(peer.name)")
                    self?.connectionStatus = .connected
                    self?.receiveLoop(connection: connection)
                case .failed(let error):
                    print("[Sync] Connection to \(peer.name) failed: \(error)")
                    self?.connections.removeValue(forKey: peer.id)
                case .cancelled:
                    self?.connections.removeValue(forKey: peer.id)
                default:
                    break
                }
            }
        }

        connection.start(queue: queue)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let id = UUID().uuidString

        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("[Sync] Incoming connection ready")
                    self?.connectionStatus = .connected
                    self?.connections[id] = connection
                    self?.receiveLoop(connection: connection)
                case .failed:
                    self?.connections.removeValue(forKey: id)
                case .cancelled:
                    self?.connections.removeValue(forKey: id)
                default:
                    break
                }
            }
        }

        connection.start(queue: queue)
    }

    // MARK: - Message framing

    // Simple length-prefix framing: [4-byte big-endian length][payload]
    private func frameMessage(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        var framed = Data(bytes: &length, count: 4)
        framed.append(data)
        return framed
    }

    private func receiveLoop(connection: NWConnection) {
        // First read the 4-byte length header
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, isComplete, error in
            if let error {
                print("[Sync] Receive error: \(error)")
                return
            }
            if isComplete {
                return
            }
            guard let header, header.count == 4 else {
                self?.receiveLoop(connection: connection)
                return
            }

            let length = header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            // Now read the payload
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] payload, _, isComplete, error in
                if let error {
                    print("[Sync] Payload receive error: \(error)")
                    return
                }

                if let payload, let message = SyncMessage.from(data: payload) {
                    DispatchQueue.main.async {
                        self?.onItemReceived?(message)
                    }
                }

                if !isComplete {
                    self?.receiveLoop(connection: connection)
                }
            }
        }
    }
}
