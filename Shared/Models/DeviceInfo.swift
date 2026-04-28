import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum DeviceInfo {
    static var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return UIDevice.current.name
        #endif
    }

    static var deviceID: String {
        let key = "com.copypasta.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }

    static var platform: String {
        #if os(macOS)
        return "macOS"
        #else
        return "iOS"
        #endif
    }
}
