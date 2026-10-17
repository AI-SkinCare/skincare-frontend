import Foundation

/// 앱 전체에서 하나만 쓰는 API 클라이언트. 401(E1001)이면 토큰을 재발급하고 원 요청을 한 번 다시 보낸다.
final class APIClient: Sendable {
    let tokens: AuthTokenManager
    /// 재발급까지 실패해 다시 로그인해야 할 때 이벤트가 온다.
    let sessionExpiredEvents: AsyncStream<Void>

    private let transport: HTTPTransport
    private let sessionExpiredContinuation: AsyncStream<Void>.Continuation

    init(
        baseURL: URL = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        store: any RefreshTokenStoring = KeychainRefreshTokenStore()
    ) {
        transport = HTTPTransport(baseURL: baseURL, session: session)
        tokens = AuthTokenManager(transport: transport, store: store)
        (sessionExpiredEvents, sessionExpiredContinuation) = AsyncStream.makeStream(of: Void.self)
    }

    func send<Response>(_ request: APIRequest<Response>) async throws -> Response {
        guard request.requiresAuth else {
            return try await transport.send(request, accessToken: nil)
        }

        let token = await tokens.currentAccessToken
        do {
            return try await transport.send(request, accessToken: token)
        } catch APIError.server(let status, let code, _, _) where status == 401 && code == "E1001" {
            let freshToken: String
            do {
                freshToken = try await tokens.validAccessToken(after: token)
            } catch APIError.sessionExpired {
                sessionExpiredContinuation.yield()
                throw APIError.sessionExpired
            }
            return try await transport.send(request, accessToken: freshToken)
        }
    }
}
