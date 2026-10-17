import Foundation
import Observation

enum AppTab: Hashable {
    case home, history, myPage
}

/// 탭 안에서 push 하는 화면 (패치 §2 화면 목록)
enum AppRoute: Hashable {
    case report(analysisID: String)
    case recommendation(analysisID: String)
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath: [AppRoute] = []
    var historyPath: [AppRoute] = []
    /// 측정 흐름(SCR-04~07)은 탭을 가리는 전체 화면으로 띄운다.
    var isCaptureFlowPresented = false

    /// 분석 제출 직후: 촬영 흐름을 닫고 홈 탭에서 결과 리포트를 연다.
    func showReport(analysisID: String) {
        isCaptureFlowPresented = false
        selectedTab = .home
        homePath = [.report(analysisID: analysisID)]
    }

    func reset() {
        selectedTab = .home
        homePath = []
        historyPath = []
        isCaptureFlowPresented = false
    }
}
