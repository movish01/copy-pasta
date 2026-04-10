import SwiftUI

struct DevicesView: View {
    let bonjourService: BonjourSyncService

    var body: some View {
        NavigationStack {
            List {
                // This device
                Section("This Device") {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone")
                            .font(.title2)
                            .foregroundStyle(.accent)
                            .frame(width: 44, height: 44)
                            .background(.accent.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(DeviceInfo.deviceName)
                                .font(.headline)
                            Text(DeviceInfo.platform)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                    }
                }

                // Discovered peers
                Section("Nearby Devices") {
                    if bonjourService.discoveredPeers.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Searching...")
                                    .font(.subheadline)
                                Text("Make sure both devices are on the same Wi-Fi network and CopyPasta is running on your Mac")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(bonjourService.discoveredPeers) { peer in
                            HStack(spacing: 12) {
                                Image(systemName: peerIcon(for: peer.name))
                                    .font(.title2)
                                    .foregroundStyle(.accent)
                                    .frame(width: 44, height: 44)
                                    .background(.accent.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(peer.name)
                                        .font(.headline)
                                    Text("Connected via Wi-Fi")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                // How it works
                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(icon: "wifi", text: "Devices find each other automatically on the same Wi-Fi")
                        InfoRow(icon: "bolt.fill", text: "Clipboard items sync instantly — no cloud needed")
                        InfoRow(icon: "lock.fill", text: "Everything stays on your local network")
                        InfoRow(icon: "arrow.left.arrow.right", text: "Swipe left on an item to send it to a specific device")
                    }
                    .padding(.vertical, 4)
                }

                // Status
                Section("Connection") {
                    LabeledContent("Status") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(bonjourService.connectionStatus.rawValue)
                        }
                    }

                    LabeledContent("Service") {
                        Text(bonjourService.isRunning ? "Running" : "Stopped")
                            .foregroundStyle(bonjourService.isRunning ? .green : .red)
                    }
                }
            }
            .navigationTitle("Devices")
        }
    }

    private func peerIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("mac") || lower.contains("book") || lower.contains("imac") { return "laptopcomputer" }
        if lower.contains("ipad") { return "ipad" }
        return "desktopcomputer"
    }

    private var statusColor: Color {
        switch bonjourService.connectionStatus {
        case .connected: return .green
        case .listening, .browsing: return .orange
        case .disconnected: return .red
        }
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.accent)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
