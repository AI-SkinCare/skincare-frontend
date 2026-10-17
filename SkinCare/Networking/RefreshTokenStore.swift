import Foundation
import Security

protocol RefreshTokenStoring: Sendable {
    func load() -> String?
    func save(_ token: String)
    func clear()
}

/// 리프레시 토큰을 Keychain(이 기기 전용)에 저장한다. 패치 문서 §3.1.
struct KeychainRefreshTokenStore: RefreshTokenStoring {
    private let service = "com.aiskincare.skincare.auth"
    private let account = "refreshToken"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String) {
        clear()
        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
