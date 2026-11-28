import Foundation
import Observation

/// SCR-08 결과 리포트 상태 + 추천 진행 폴링 (API 변경사항 §1.4).
@MainActor
@Observable
final class ReportModel {
    let analysisID: String

    private(set) var analysis: AnalysisView?
    private(set) var errorMessage: String?
    /// 30분이 지나도 끝나지 않음
    private(set) var pollingTimedOut = false
    /// 150초 이후 지연 안내
    private(set) var showsDelayNotice = false
    private(set) var aiAvailable = true
    private(set) var isRetrying = false
    /// 값이 바뀌면 화면이 폴링을 다시 시작한다 (추천 재요청 후).
    private(set) var pollGeneration = 0
    var alert: AlertItem?

    init(analysisID: String) {
        self.analysisID = analysisID
    }

    /// 화면이 보이고 앱이 포그라운드일 때만 돈다. 화면이 사라지거나 백그라운드로 가면 취소된다 (패치 §2 SCR-08).
    /// 앱 이탈은 서버 작업 취소가 아니다 — 다시 들어오면 같은 ID로 이어서 조회한다.
    func poll(api: APIClient) async {
        var checkedSystemStatus = false
        while !Task.isCancelled {
            await fetch(api: api)
            guard let analysis, analysis.status.isInProgress else {
                showsDelayNotice = false
                return
            }
            if !checkedSystemStatus, let status = try? await api.send(SystemAPI.status()) {
                aiAvailable = status.aiAvailable
                checkedSystemStatus = true
            }
            // 기준은 분석 제출 시각 — 화면 재진입마다 리셋되지 않는다.
            let elapsed = Date().timeIntervalSince(analysis.createdAt)
            showsDelayNotice = PollingPolicy.showsDelayNotice(elapsed: elapsed)
            guard let interval = PollingPolicy.interval(elapsed: elapsed) else {
                pollingTimedOut = true
                return
            }
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    /// FAILED 분석의 추천만 다시 요청한다. 사진·분류는 다시 하지 않는다.
    func retryRecommendation(api: APIClient) async {
        isRetrying = true
        defer { isRetrying = false }
        do {
            analysis = try await api.send(AnalysisAPI.retryRecommendation(id: analysisID))
            pollingTimedOut = false
            pollGeneration += 1
        } catch {
            alert = AlertItem(message: error.userMessage)
        }
    }

    private func fetch(api: APIClient) async {
        do {
            analysis = try await api.send(AnalysisAPI.detail(id: analysisID))
            errorMessage = nil
        } catch let error as APIError where error.code == "E4003" {
            errorMessage = "결과를 찾을 수 없어요."
        } catch {
            // 폴링 중 일시적 오류는 이전 결과를 계속 보여준다.
            if analysis == nil { errorMessage = error.userMessage }
        }
    }
}
