import SwiftUI

struct SyncStatusView: View {
    let bonjourService: BonjourSyncService

    var body: some View {
        HStack(spacing: 12) {
            // LAN status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(lanStatusColor)
                    .frame(width: 8, height: 8)
                Text(bonjourService.connectionStatus.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !bonjourService.discoveredPeers.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.caption2)
                    Text("\(bonjourService.discoveredPeers.count) nearby")
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
        switch bonjourService.connectionStatus {
        case .connected: return .green
        case .listening, .browsing: return .yellow
        case .disconnected: return .red
        }
    }
}
