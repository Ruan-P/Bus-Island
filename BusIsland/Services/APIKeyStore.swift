import Foundation
import Security

/// data.go.kr service key storage.
/// - Default key is baked for personal sideload builds (can be overridden in Settings).
/// - Always normalizes to **Decoding** form (raw `+/=`); URL encoding is applied at request time.
public final class APIKeyStore: Sendable {
    public static let shared = APIKeyStore()

    /// Default key placeholder. Configure via Settings / Keychain.
    public static let bakedDefaultKey = ""

    private let service = "com.busisland.BusIsland"
    private let account = "data.go.kr.serviceKey"

    public init() {}

    /// Effective key used by API client (Keychain override → baked default).
    public var serviceKey: String? {
        get {
            if let stored = read(), !stored.isEmpty {
                return Self.normalizedDecodingKey(stored)
            }
            let def = Self.normalizedDecodingKey(Self.bakedDefaultKey)
            return def.isEmpty ? nil : def
        }
        set {
            if let newValue {
                let normalized = Self.normalizedDecodingKey(newValue)
                if normalized.isEmpty {
                    delete()
                } else {
                    save(normalized)
                }
            } else {
                delete()
            }
        }
    }

    public var hasServiceKey: Bool {
        guard let key = serviceKey else { return false }
        return !key.isEmpty
    }

    public var isUsingBakedDefault: Bool {
        read() == nil && !Self.bakedDefaultKey.isEmpty
    }

    /// Convert Encoding key (`%2F`…) to Decoding key if needed.
    public static func normalizedDecodingKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        // Already looks percent-encoded → decode once.
        if trimmed.contains("%") {
            return trimmed.removingPercentEncoding ?? trimmed
        }
        return trimmed
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
