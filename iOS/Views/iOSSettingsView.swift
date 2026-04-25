import SwiftUI

struct iOSSettingsView: View {
    let syncCoordinator: SyncCoordinator

    @AppStorage("autoCapture") private var autoCapture = true
    @AppStorage("autoCopyReceived") private var autoCopyReceived = true
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 500

    @State private var showingRelaySetup = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Clipboard") {
                    Toggle("Auto-capture on foreground", isOn: $autoCapture)
                    Toggle("Auto-copy received items", isOn: $autoCopyReceived)
                    Stepper("Max history: \(maxHistoryItems)", value: $maxHistoryItems, in: 100...2000, step: 100)
                }

                Section("Local Network") {
                    LabeledContent("Bonjour") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(syncCoordinator.bonjour.connectionStatus == .connected ? .green : .orange)
                                .frame(width: 8, height: 8)
                            Text(syncCoordinator.bonjour.connectionStatus.rawValue)
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

                        LabeledContent("Peers") {
                            Text("\(syncCoordinator.relay.roomMembers.count)")
                        }

                        Button("Disconnect Relay", role: .destructive) {
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
                    Text("LAN sync works on the same Wi-Fi. Relay sync works from anywhere with E2E encryption — no accounts needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Device", value: DeviceInfo.deviceName)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingRelaySetup) {
                RelaySetupView(syncCoordinator: syncCoordinator)
            }
        }
    }
}
