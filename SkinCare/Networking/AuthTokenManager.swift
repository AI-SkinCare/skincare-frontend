import Foundation

/// 액세스 토큰(메모리)과 리프레시 토큰(Keychain/쿠키)을 관리한다.
///
/// 재발급은 single-flight: 여러 요청이 동시에 401을 받아도 `/auth/refresh`는 한 번만 보낸다.
/// 리프레시 토큰은 교체 방식이라 두 번 보내면 재사용으로 판정돼 로그아웃된다 (설계서 §5).
actor AuthTokenManager {
    private let transport: HTTPTransport
    private let store: any RefreshTokenStoring
    private var accessToken: String?
    private var refreshTask: Task<AuthSession, Error>?

    init(transport: HTTPTransport, store: any RefreshTokenStoring) {
        self.transport = transport
        self.store = store
    }

    var currentAccessToken: String? { accessToken }
    var storedRefreshToken: String? { store.load() }

    func apply(_ session: AuthSession) {
        accessToken = session.accessToken
        // 백엔드가 본문으로 리프레시 토큰을 줄 때만 저장 (패치 A2). 쿠키 방식이면 nil.
        if let refreshToken = session.refreshToken {
            store.save(refreshToken)
        }
    }

    func clear() {
        accessToken = nil
        store.clear()
        if let cookieStorage = transport.session.configuration.httpCookieStorage {
            for cookie in cookieStorage.cookies(for: transport.baseURL) ?? [] {
                cookieStorage.deleteCookie(cookie)
            }
        }
    }

    /// `failedToken`으로 보낸 요청이 401을 받았을 때 쓸 토큰. 그새 다른 요청이 재발급했으면 그 토큰을 준다.
    func validAccessToken(after failedToken: String?) async throws -> String {
        if let accessToken, accessToken != failedToken {
            return accessToken
        }
        return try await refresh().accessToken
    }

    func refresh() async throws -> AuthSession {
        if let refreshTask {
            return try await refreshTask.value
        }
        let transport = transport
        let request = AuthAPI.refresh(refreshToken: store.load())
        let task = Task { try await transport.send(request, accessToken: nil) }
        refreshTask = task

        do {
            let session = try await task.value
            refreshTask = nil
            apply(session)
            return session
        } catch {
            refreshTask = nil
            // 네트워크 문제는 토큰이 무효라는 뜻이 아니므로 지우지 않는다.
            if case APIError.network = error { throw error }
            clear()
            throw APIError.sessionExpired
        }
    }
}
