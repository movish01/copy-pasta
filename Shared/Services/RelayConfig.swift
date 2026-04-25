import Foundation

enum RelayConfig {
    static var serverURL: URL {
        if let custom = UserDefaults.standard.string(forKey: "relayServerURL"),
           let url = URL(string: custom) {
            return url
        }
        return URL(string: "wss://copypasta-relay.onrender.com")!
    }
}
