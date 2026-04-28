import SwiftUI

struct SettingsView: View {
    let syncCoordinator: SyncCoordinator

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoSendToDevices") private var autoSendToDevices = true
    @AppStorage("autoCopyReceived") private var autoCopyReceived = true
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 500
    @AppStorage("monitorInterval") private var monitorInterval = 0.5

    @State private var showingRelaySetup = false

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }

            networkSettings
                .tabItem { Label("Network", systemImage: "wifi") }

            aboutView
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 380)
    }

    // MARK: - General

    private var generalSettings: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)

            Stepper("Max History Items: \(maxHistoryItems)", value: $maxHistoryItems, in: 100...2000, step: 100)

            Slider(value: $monitorInterval, in: 0.25...2.0, step: 0.25) {
                Text("Monitor Interval: \(String(format: "%.2f", monitorInterval))s")
            }

            Toggle("Auto-send new copies to nearby devices", isOn: $autoSendToDevices)
            Toggle("Auto-copy items received from other devices", isOn: $autoCopyReceived)
        }
        .padding()
    }

    // MARK: - Network

    private var networkSettings: some View {
        Form {
            Section("Local Network (Bonjour)") {
                LabeledContent("Status") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(syncCoordinator.bonjour.connectionStatus == .connected ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(syncCoordinator.bonjour.connectionStatus.rawValue)
                    }
                }

                if !syncCoordinator.bonjour.discoveredPeers.isEmpty {
                    LabeledContent("LAN Peers") {
                        VStack(alignment: .trailing, spacing: 4) {
                            ForEach(syncCoordinator.bonjour.discoveredPeers) { peer in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text(peer.name)
                                }
                            }
                        }
                    }
                }
            }

            Section("Internet Relay") {
                if syncCoordinator.relay.isConnected {
                    LabeledContent("Status") {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("Connected")
                        }
                    }

                    if let roomId = syncCoordinator.relay.roomId {
                        LabeledContent("Room") {
                            Text(roomId)
                                .font(.caption.monospaced())
                        }
                    }

                    if !syncCoordinator.relay.roomMembers.isEmpty {
                        LabeledContent("Relay Peers") {
                            VStack(alignment: .trailing, spacing: 4) {
                                ForEach(syncCoordinator.relay.roomMembers) { member in
                                    HStack(spacing: 4) {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .foregroundStyle(.blue)
                                            .font(.caption)
                                        Text(member.deviceName)
                                    }
                                }
                            }
                        }
                    }

                    Button("Disconnect Relay") {
                        syncCoordinator.leaveRelayRoom()
                    }
                } else {
                    LabeledContent("Status") {
                        Text(syncCoordinator.relay.connectionStatus.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    Button("Set Up Relay Sync...") {
                        showingRelaySetup = true
                    }
                }
            }

            Section {
                Text("LAN sync works on the same Wi-Fi. Relay sync works from anywhere over the internet with E2E encryption.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .sheet(isPresented: $showingRelaySetup) {
            RelaySetupView(syncCoordinator: syncCoordinator)
                .frame(width: 400, height: 400)
        }
    }

    // MARK: - About

    private var aboutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("CopyPasta")
                .font(.title)
                .fontWeight(.bold)

            Text("Clipboard History & Sync")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Share your clipboard between iPhone and Mac.\nWorks over Wi-Fi (Bonjour) or the internet (Relay).\nNo accounts needed. E2E encrypted.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
