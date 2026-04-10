import Foundation
import AppKit
import Combine

@Observable
final class MacClipboardMonitor {
    var isMonitoring = false
    private var timer: Timer?
    private var lastChangeCount: Int = 0

    var onNewClipboardContent: ((String) -> Void)?

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Update change count so we don't re-capture our own paste
        lastChangeCount = pasteboard.changeCount
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if let content = pasteboard.string(forType: .string) {
            DispatchQueue.main.async { [weak self] in
                self?.onNewClipboardContent?(content)
            }
        }
    }
}
