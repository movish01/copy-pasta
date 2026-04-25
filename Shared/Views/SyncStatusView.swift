import SwiftUI

struct SyncStatusView: View {
    let syncCoordinator: SyncCoordinator

    var body: some View {
        HStack(spacing: 12) {
            // LAN status
            HStack(spacing: 4) {
                Circle()
                    .fill(lanStatusColor)
                    .frame(width: 8, height: 8)
                Text("LAN")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Relay status
            HStack(spacing: 4) {
                Circle()
                    .fill(relayStatusColor)
                    .frame(width: 8, height: 8)
                Text("Relay")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !syncCoordinator.allPeers.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption2)
                    Text("\(syncCoordinator.allPeers.count)")
                        .font(.caption2)
                }
                .foregroundStyle(.green)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var lanStatusColor: Color {
        switch syncCoordinator.bonjour.connectionStatus {
        case .connected: return .green
        case .listening, .browsing: return .yellow
        case .disconnected: return .red
        }
    }

    private var relayStatusColor: Color {
        switch syncCoordinator.relay.connectionStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }
}
