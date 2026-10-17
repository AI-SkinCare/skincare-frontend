import Foundation
@testable import SkinCare
import Testing

/// 토큰 재발급 single-flight (설계서 §5, 패치 TC-IOS-05). URLProtocol 스텁을 공유하므로 직렬 실행.
@Suite(.serialized)
struct APIClientTests {
    private let baseURL = URL(string: "https://api.test/api/v1")!

    private func makeClient(store: MemoryTokenStore = MemoryTokenStore()) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(baseURL: baseURL, session: URLSession(configuration: configuration), store: store)
    }

    private func session(accessToken: String, refreshToken: String? = nil) -> AuthSession {
        AuthSession(accessToken: accessToken, expiresIn: 3600,
                    user: User(id: 1, email: "a@b.c", nickname: "테스트"), refreshToken: refreshToken)
    }

    @Test("동시에 여러 요청이 401을 받아도 재발급은 한 번만 보낸다")
    func refreshIsSingleFlight() async throws {
        let counter = RequestCounter()
        StubURLProtocol.handler = { request in
            if request.url?.path().hasSuffix("/auth/refresh") == true {
                counter.incrementRefresh()
                Thread.sleep(forTimeInterval: 0.2) // 다른 요청들이 그 사이에 401을 받게
                let user = #"{"id":1,"email":"a@b.c","nickname":"테스트"}"#
                let session = #"{"accessToken":"new","expiresIn":3600,"user":"# + user + #","refreshToken":"r2"}"#
                return .json(200, #"{"success":true,"data":"# + session + "}")
            }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer new" {
                let status = #"{"aiAvailable":true,"queueLength":0,"estimatedWaitSec":null,"checkedAt":"2026-10-15T09:12:00Z"}"#
                return .json(200, #"{"success":true,"data":"# + status + "}")
            }
            return .json(401, #"{"success":false,"error":{"code":"E1001","message":"토큰 만료"}}"#)
        }

        let store = MemoryTokenStore(token: "r1")
        let client = makeClient(store: store)
        await client.tokens.apply(session(accessToken: "old"))

        let request = APIRequest<SystemStatus>(method: .get, path: "/system/status") // 인증 필요한 요청으로 사용
        async let first = client.send(request)
        async let second = client.send(request)
        async let third = client.send(request)
        let results = try await [first, second, third]

        #expect(results.count == 3)
        #expect(counter.refreshCount == 1)
        #expect(await client.tokens.currentAccessToken == "new")
        #expect(store.load() == "r2") // 본문으로 받은 리프레시 토큰은 교체 저장 (패치 A2)
    }

    @Test("재발급이 실패하면 sessionExpired, 저장된 토큰을 지운다")
    func refreshFailureExpiresSession() async throws {
        StubURLProtocol.handler = { _ in
            .json(401, #"{"success":false,"error":{"code":"E1001","message":"토큰 만료"}}"#)
        }
        let store = MemoryTokenStore(token: "r1")
        let client = makeClient(store: store)
        await client.tokens.apply(session(accessToken: "old"))

        await #expect {
            _ = try await client.send(APIRequest<SystemStatus>(method: .get, path: "/system/status"))
        } throws: { error in
            if case APIError.sessionExpired = error { return true }
            return false
        }
        #expect(store.load() == nil)
        #expect(await client.tokens.currentAccessToken == nil)
    }

    @Test("에러 응답은 서버 code·message·요청 ID로 바뀐다")
    func serverErrorMapping() async throws {
        StubURLProtocol.handler = { _ in
            .json(422, #"{"success":false,"error":{"code":"E2001","message":"얼굴을 찾지 못했어요. 정면에서 다시 찍어 주세요.","detail":null}}"#,
                  headers: ["X-Request-Id": "abcdef0123456789"])
        }
        let client = makeClient()
        await #expect {
            _ = try await client.send(SystemAPI.status())
        } throws: { error in
            guard case APIError.server(let status, let code, let message, let requestID) = error else { return false }
            return status == 422 && code == "E2001" && message.hasPrefix("얼굴을") && requestID == "abcdef0123456789"
        }
    }

    @Test("E4001은 요청 ID 앞 8자리를 붙인 공통 문구")
    func commonErrorMessage() {
        let error = APIError.server(status: 500, code: "E4001", message: "내부 오류", requestID: "abcdef0123456789")
        #expect(error.userMessage == "문제가 생겼어요. 잠시 후 다시 시도해 주세요. (문의 시 코드: abcdef01)")
    }

    @Test("204 응답은 EmptyResponse")
    func noContent() async throws {
        StubURLProtocol.handler = { _ in .json(204, "") }
        let client = makeClient()
        await client.tokens.apply(session(accessToken: "t"))
        _ = try await client.send(AnalysisAPI.delete(id: "01J9"))
    }
}

// MARK: - 스텁

struct StubResponse {
    let status: Int
    let body: Data
    let headers: [String: String]

    static func json(_ status: Int, _ body: String, headers: [String: String] = [:]) -> StubResponse {
        StubResponse(status: status, body: Data(body.utf8), headers: headers.merging(["Content-Type": "application/json"]) { $1 })
    }
}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> StubResponse)?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else { return }
        let stub = handler(request)
        guard let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1",
                                             headerFields: stub.headers) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var refreshes = 0

    var refreshCount: Int { lock.withLock { refreshes } }

    func incrementRefresh() {
        lock.withLock { refreshes += 1 }
    }
}

final class MemoryTokenStore: RefreshTokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func load() -> String? { lock.withLock { token } }
    func save(_ token: String) { lock.withLock { self.token = token } }
    func clear() { lock.withLock { token = nil } }
}
