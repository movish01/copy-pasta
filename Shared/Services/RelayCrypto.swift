import CryptoKit
import Foundation

enum RelayCrypto {
    /// Derives a room ID from the passphrase (sent to server — not secret)
    static func roomId(from passphrase: String) -> String {
        let hash = SHA256.hash(data: Data(passphrase.utf8))
        return hash.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// Derives the encryption key from the passphrase (never leaves the device)
    static func deriveKey(from passphrase: String) -> SymmetricKey {
        let inputKey = SymmetricKey(data: SHA256.hash(data: Data(passphrase.utf8)))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            info: Data("copypasta-e2e-v1".utf8),
            outputByteCount: 32
        )
    }

    /// Encrypts data with AES-256-GCM. Returns nonce + ciphertext + tag.
    static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        return sealed.combined!
    }

    /// Decrypts AES-256-GCM data.
    static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }
}
