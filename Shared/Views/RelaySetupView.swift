import SwiftUI

struct RelaySetupView: View {
    let syncCoordinator: SyncCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var passphrase = ""
    @State private var isConnecting = false

    // Word list for random passphrase generation
    private let words = [
        "tiger", "ocean", "seven", "lamp", "cloud", "river", "stone", "maple",
        "frost", "coral", "blaze", "drift", "spark", "grove", "crystal", "ember",
        "horizon", "velvet", "thunder", "breeze", "summit", "cascade", "aurora",
        "zenith", "prism", "echo", "nova", "atlas", "pixel", "orbit", "cipher",
        "nexus", "pulse", "vortex", "quartz", "lunar", "solar", "delta", "omega",
        "falcon", "phoenix", "marble", "harbor", "meadow", "canyon", "island",
        "rocket", "comet", "galaxy", "nebula", "photon"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 40))
                        .foregroundStyle(.accent)

                    Text("Relay Sync")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter the same passphrase on both devices to connect them over the internet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 20)

                // Passphrase input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passphrase")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("e.g. tiger-ocean-seven-lamp", text: $passphrase)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button(action: generatePassphrase) {
                        Label("Generate Random Phrase", systemImage: "dice")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 24)

                // Security note
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("All messages are end-to-end encrypted. The server never sees your clipboard content.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Connect button
                Button(action: connect) {
                    if isConnecting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(passphrase.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .navigationTitle("Relay Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    private func generatePassphrase() {
        let selected = (0..<4).map { _ in words.randomElement()! }
        passphrase = selected.joined(separator: "-")
    }

    private func connect() {
        let phrase = passphrase.trimmingCharacters(in: .whitespaces)
        guard !phrase.isEmpty else { return }

        isConnecting = true
        syncCoordinator.joinRelayRoom(passphrase: phrase)

        // Dismiss after a brief delay to let the connection start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isConnecting = false
            dismiss()
        }
    }
}
