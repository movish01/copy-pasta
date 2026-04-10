import SwiftUI

struct SettingsView: View {
    let bonjourService: BonjourSyncService

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("enableBonjour") private var enableBonjour = true
    @AppStorage("autoSendToDevices") private var autoSendToDevices = true
    @AppStorage("autoCopyReceived") private var autoCopyReceived = true
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 500
    @AppStorage("monitorInterval") private var monitorInterval = 0.5

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }

            networkSettings
                .tabItem { Label("Network", systemImage: "wifi") }

            aboutView
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 450, height: 320)
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
                Toggle("Enable LAN Discovery", isOn: $enableBonjour)
                    .onChange(of: enableBonjour) { _, newValue in
                        if newValue { bonjourService.start() } else { bonjourService.stop() }
                    }

                if bonjourService.isRunning {
                    LabeledContent("Status") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(bonjourService.connectionStatus == .connected ? .green : .orange)
                                .frame(width: 8, height: 8)
                            Text(bonjourService.connectionStatus.rawValue)
                        }
                    }

                    LabeledContent("Nearby Devices") {
                        if bonjourService.discoveredPeers.isEmpty {
                            Text("Searching...")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .trailing, spacing: 4) {
                                ForEach(bonjourService.discoveredPeers) { peer in
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
            }

            Section {
                Text("CopyPasta uses Bonjour to discover devices on the same Wi-Fi network. No internet or accounts needed — everything stays local.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - About

    private var aboutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(.accent)

            Text("CopyPasta")
                .font(.title)
                .fontWeight(.bold)

            Text("Clipboard History & Local Sync")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Share your clipboard between iPhone and Mac over Wi-Fi.\nNo accounts, no cloud — just local network magic.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
