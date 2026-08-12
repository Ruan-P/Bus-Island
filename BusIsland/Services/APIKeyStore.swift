import Foundation
import Security

/// Persists the data.go.kr service key in Keychain (not source / not IPA plaintext defaults).
public final class APIKeyStore: Sendable {
    public static let shared = APIKeyStore()

    private let service = "com.busisland.BusIsland"
    private let account = "data.go.kr.serviceKey"

    public init() {}

    public var serviceKey: String? {
        get { read() }
        set {
            if let newValue, !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                save(newValue.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                delete()
            }
        }
    }

    public var hasServiceKey: Bool {
        guard let key = serviceKey else { return false }
        return !key.isEmpty
    }

    private func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func save(_ value: String) {
        delete()
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
