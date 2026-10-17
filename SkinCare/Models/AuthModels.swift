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
    /// `X-Client: ios`일 때 내려온다 (패치 A2, 백엔드 반영 완료). 쿠키 `refresh_token`도 함께 온다.
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
    /// 첫 헬스체크 전이면 null
    let checkedAt: Date?
}
