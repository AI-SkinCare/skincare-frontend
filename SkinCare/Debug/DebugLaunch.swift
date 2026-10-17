#if DEBUG
import Foundation

/// Debug 빌드 전용 실행 옵션. Xcode 스킴 Arguments 또는 `simctl launch`로 넘긴다.
///
/// - `-MockAPI`: 백엔드 없이 목 응답으로 실행 (자동 로그인 상태)
/// - `-MockAIDown`: 목 응답에서 분석 서버 점검 중
/// - `-MockEmpty`: 목 응답에서 측정 이력 없음
/// - `-StartScreen <이름>`: 해당 화면을 바로 연다. 이름은 `StartScreen` 참고
enum DebugLaunch {
    enum StartScreen: String {
        case login, signup, home, guide, capture, camera, survey
        case reportCompleted = "report-completed"
        case reportQueued = "report-queued"
        case reportGenerating = "report-generating"
        case reportUncertain = "report-uncertain"
        case reportNoConcern = "report-no-concern"
        case reportFailed = "report-failed"
        case recommendation, history, mypage
    }

    private static let arguments = ProcessInfo.processInfo.arguments

    static var usesMockAPI: Bool { arguments.contains("-MockAPI") }
    static var mockAIDown: Bool { arguments.contains("-MockAIDown") }
    static var mockEmpty: Bool { arguments.contains("-MockEmpty") }

    static var startScreen: StartScreen? {
        guard let index = arguments.firstIndex(of: "-StartScreen"), index + 1 < arguments.count else { return nil }
        return StartScreen(rawValue: arguments[index + 1])
    }

    static func makeAPIClient() -> APIClient {
        guard usesMockAPI else { return APIClient() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(
            baseURL: URL(string: "https://mock.skincare.local/api/v1")!,
            session: URLSession(configuration: configuration),
            store: MockTokenStore()
        )
    }

    @MainActor
    static func applyStartScreen(to router: AppRouter) {
        let reportIDs: [StartScreen: String] = [
            .reportCompleted: MockData.completedID, .reportQueued: MockData.queuedID,
            .reportGenerating: MockData.generatingID, .reportUncertain: MockData.uncertainID,
            .reportNoConcern: MockData.noConcernID, .reportFailed: MockData.failedID,
        ]
        switch startScreen {
        case .guide, .capture, .camera, .survey:
            router.isCaptureFlowPresented = true
        case .recommendation:
            router.homePath = [.report(analysisID: MockData.completedID), .recommendation(analysisID: MockData.completedID)]
        case .history:
            router.selectedTab = .history
        case .mypage:
            router.selectedTab = .myPage
        case let screen?:
            if let id = reportIDs[screen] { router.homePath = [.report(analysisID: id)] }
        case nil:
            break
        }
    }
}

private final class MockTokenStore: RefreshTokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String? = "mock-refresh"
    func load() -> String? { lock.withLock { token } }
    func save(_ token: String) { lock.withLock { self.token = token } }
    func clear() { lock.withLock { token = nil } }
}
#endif
