import SwiftUI

struct DevicesView: View {
    let syncCoordinator: SyncCoordinator

    @State private var showingRelaySetup = false

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

                // LAN Peers
                Section("Nearby (LAN)") {
                    if syncCoordinator.bonjour.discoveredPeers.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Searching...")
                                    .font(.subheadline)
                                Text("Both devices must be on the same Wi-Fi")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(syncCoordinator.bonjour.discoveredPeers) { peer in
                            HStack(spacing: 12) {
                                Image(systemName: lanPeerIcon(for: peer.name))
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                    .frame(width: 44, height: 44)
                                    .background(.green.opacity(0.1))
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

                // Relay Peers
                Section("Relay (Internet)") {
                    if syncCoordinator.relay.isConnected {
                        if syncCoordinator.relay.roomMembers.isEmpty {
                            Text("Connected — waiting for other devices to join")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(syncCoordinator.relay.roomMembers) { member in
                                HStack(spacing: 12) {
                                    Image(systemName: relayPeerIcon(for: member))
                                        .font(.title2)
                                        .foregroundStyle(.blue)
                                        .frame(width: 44, height: 44)
                                        .background(.blue.opacity(0.1))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.deviceName)
                                            .font(.headline)
                                        Text("Connected via relay (\(member.platform))")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }

                                    Spacer()

                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Text("Relay sync lets you connect devices from anywhere — no same Wi-Fi needed.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Button("Set Up Relay Sync") {
                                showingRelaySetup = true
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // How it works
                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(icon: "wifi", color: .green, text: "LAN: Auto-discovers devices on the same Wi-Fi")
                        InfoRow(icon: "antenna.radiowaves.left.and.right", color: .blue, text: "Relay: Connect from anywhere with a passphrase")
                        InfoRow(icon: "lock.fill", color: .purple, text: "Relay messages are end-to-end encrypted")
                        InfoRow(icon: "bolt.fill", color: .orange, text: "LAN is faster; relay works from anywhere")
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Devices")
            .sheet(isPresented: $showingRelaySetup) {
                RelaySetupView(syncCoordinator: syncCoordinator)
            }
        }
    }

    private func lanPeerIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("mac") || lower.contains("book") || lower.contains("imac") { return "laptopcomputer" }
        if lower.contains("ipad") { return "ipad" }
        return "desktopcomputer"
    }

    private func relayPeerIcon(for member: RelaySyncService.RoomMember) -> String {
        let lower = member.deviceName.lowercased()
        if lower.contains("mac") || lower.contains("book") { return "laptopcomputer" }
        if lower.contains("ipad") { return "ipad" }
        if lower.contains("iphone") { return "iphone" }
        return "desktopcomputer"
    }
}

struct InfoRow: View {
    let icon: String
    var color: Color = .accent
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
