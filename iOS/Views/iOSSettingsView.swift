import SwiftUI

struct iOSSettingsView: View {
    let bonjourService: BonjourSyncService

    @AppStorage("enableBonjour") private var enableBonjour = true
    @AppStorage("autoCapture") private var autoCapture = true
    @AppStorage("autoCopyReceived") private var autoCopyReceived = true
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 500

    var body: some View {
        NavigationStack {
            Form {
                Section("Clipboard") {
                    Toggle("Auto-capture on foreground", isOn: $autoCapture)
                    Toggle("Auto-copy received items", isOn: $autoCopyReceived)
                    Stepper("Max history: \(maxHistoryItems)", value: $maxHistoryItems, in: 100...2000, step: 100)
                }

                Section("Network") {
                    Toggle("LAN Discovery (Bonjour)", isOn: $enableBonjour)
                        .onChange(of: enableBonjour) { _, newValue in
                            if newValue { bonjourService.start() } else { bonjourService.stop() }
                        }
                }

                Section {
                    Text("CopyPasta syncs your clipboard between devices on the same Wi-Fi network. No accounts, no cloud — everything is local and private.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Device", value: DeviceInfo.deviceName)
                    LabeledContent("Device ID", value: String(DeviceInfo.deviceID.prefix(8)) + "...")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
