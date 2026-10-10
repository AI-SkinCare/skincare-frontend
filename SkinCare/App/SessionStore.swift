import Foundation
import Observation

/// 로그인 상태. 앱 시작 시 저장된 토큰으로 재발급을 시도해 로그인을 복원한다 (패치 §3.3 "토큰").
@MainActor
@Observable
final class SessionStore {
    enum State: Equatable {
        case launching
        case signedOut
        case signedIn(User)
    }

    private(set) var state: State = .launching
    let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var user: User? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    func restore() async {
        do {
            let session = try await api.tokens.refresh()
            state = .signedIn(session.user)
        } catch {
            state = .signedOut
        }
    }

    /// 재발급 실패 이벤트를 받으면 로그인 화면으로 보낸다.
    func observeSessionExpiry() async {
        for await _ in api.sessionExpiredEvents {
            state = .signedOut
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await api.send(AuthAPI.login(email: email, password: password))
        await api.tokens.apply(session)
        state = .signedIn(session.user)
    }

    func signOut() async {
        let refreshToken = await api.tokens.storedRefreshToken
        _ = try? await api.send(AuthAPI.logout(refreshToken: refreshToken))
        await api.tokens.clear()
        state = .signedOut
    }

    /// 회원 탈퇴 (FR-AUTH-04). 성공하면 기기에 남은 토큰·설정도 지운다.
    func deleteAccount() async throws {
        _ = try await api.send(UsersAPI.deleteMe())
        await api.tokens.clear()
        LocalSettings.reset()
        state = .signedOut
    }
}

/// 기기 로컬 설정 (UserDefaults). 패치 §2 SCR-04.
enum LocalSettings {
    static let hideCaptureGuideKey = "hideCaptureGuide"

    static func reset() {
        UserDefaults.standard.removeObject(forKey: hideCaptureGuideKey)
    }
}
