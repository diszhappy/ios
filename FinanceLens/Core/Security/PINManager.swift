import Foundation
import CryptoKit

enum PINManager {
    static func setPin(_ pin: String) -> Bool {
        let hash = hashPin(pin)
        return KeychainManager.save(hash, for: .pinHash)
    }

    static func verifyPin(_ pin: String) -> Bool {
        guard let stored = KeychainManager.get(.pinHash) else { return false }
        return hashPin(pin) == stored
    }

    static func hasPin() -> Bool {
        KeychainManager.get(.pinHash) != nil
    }

    static func removePin() {
        KeychainManager.delete(.pinHash)
    }

    private static func hashPin(_ pin: String) -> String {
        let data = Data(pin.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
