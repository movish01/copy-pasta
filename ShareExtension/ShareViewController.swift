import UIKit
import Social
import SwiftData
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }

            for attachment in attachments {
                // Handle plain text
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, error in
                        if let text = data as? String {
                            self?.saveClipboardItem(content: text, type: .text)
                        }
                        self?.close()
                    }
                    return
                }

                // Handle URLs
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] data, error in
                        if let url = data as? URL {
                            self?.saveClipboardItem(content: url.absoluteString, type: .url)
                        }
                        self?.close()
                    }
                    return
                }
            }
        }

        close()
    }

    private func saveClipboardItem(content: String, type: ClipboardItem.ContentType) {
        // Save to shared UserDefaults (app group) so the main app picks it up
        let defaults = UserDefaults(suiteName: "group.com.copypasta.shared")
        var pending = defaults?.array(forKey: "pendingItems") as? [[String: String]] ?? []
        pending.append([
            "content": content,
            "type": type.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        defaults?.set(pending, forKey: "pendingItems")
    }

    private func close() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
