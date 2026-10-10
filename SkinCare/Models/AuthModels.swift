import Foundation

struct User: Codable, Sendable, Hashable {
    let id: Int
    let email: String
    let nickname: String
}

/// 로그인·재발급 응답 (API §3.2)
struct AuthSession: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int
    let user: User
    /// 패치 A2 합의 후 `X-Client: ios`일 때만 내려온다. 그 전에는 nil (쿠키 방식).
    let refreshToken: String?
}

struct SignupRequest: Encodable, Sendable {
    struct Agreements: Encodable, Sendable {
        let terms: Bool
        let privacy: Bool
        let imageProcessing: Bool
        let over14: Bool
    }

    let email: String
    let password: String
    let nickname: String
    let agreements: Agreements
}

struct SignupResponse: Decodable, Sendable {
    let userId: Int
}

struct Me: Decodable, Sendable {
    let id: Int
    let email: String
    let nickname: String
    let createdAt: Date
    let analysisCount: Int
}

struct SystemStatus: Decodable, Sendable {
    let aiAvailable: Bool
    let queueLength: Int
    let estimatedWaitSec: Int?
    let checkedAt: Date
}
