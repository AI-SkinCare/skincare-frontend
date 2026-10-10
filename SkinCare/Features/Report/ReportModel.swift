import Foundation
import Observation

/// SCR-08 결과 리포트 상태 + 추천 진행 폴링 (FR-ANA-03, 04).
@MainActor
@Observable
final class ReportModel {
    let analysisID: String

    private(set) var detail: AnalysisDetail?
    private(set) var errorMessage: String?
    private(set) var pollingTimedOut = false
    private(set) var aiAvailable = true
    /// 직전 완료 분석이 있으면 "이전 측정과 비교"를 보여준다.
    private(set) var hasPrevious = false
    private(set) var isRetrying = false
    /// 값이 바뀌면 화면이 폴링을 다시 시작한다 (추천 재요청 후).
    private(set) var pollGeneration = 0
    var alert: AlertItem?

    private var didCheckTrend = false

    init(analysisID: String) {
        self.analysisID = analysisID
    }

    /// 화면이 보이고 앱이 포그라운드일 때만 돈다. 화면이 사라지거나 백그라운드로 가면 취소된다 (패치 §2 SCR-08).
    func poll(api: APIClient) async {
        var checkedSystemStatus = false
        while !Task.isCancelled {
            await fetch(api: api)
            guard let detail, detail.status.isInProgress else {
                await checkTrendIfNeeded(api: api)
                return
            }
            if !checkedSystemStatus, let status = try? await api.send(SystemAPI.status()) {
                aiAvailable = status.aiAvailable
                checkedSystemStatus = true
            }
            // 15분 기준은 분석 제출 시각 — 화면 재진입마다 리셋되지 않는다.
            guard let interval = PollingPolicy.interval(elapsed: Date().timeIntervalSince(detail.createdAt)) else {
                pollingTimedOut = true
                return
            }
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    func retryRecommendation(api: APIClient) async {
        isRetrying = true
        defer { isRetrying = false }
        do {
            _ = try await api.send(AnalysisAPI.retryRecommendation(id: analysisID))
            pollingTimedOut = false
            pollGeneration += 1
        } catch {
            alert = AlertItem(message: error.userMessage)
        }
    }

    private func fetch(api: APIClient) async {
        do {
            detail = try await api.send(AnalysisAPI.detail(id: analysisID))
            errorMessage = nil
        } catch let error as APIError where error.code == "E4003" {
            errorMessage = "결과를 찾을 수 없어요."
        } catch {
            // 폴링 중 일시적 오류는 이전 결과를 계속 보여준다.
            if detail == nil { errorMessage = error.userMessage }
        }
    }

    private func checkTrendIfNeeded(api: APIClient) async {
        guard !didCheckTrend, detail?.status == .done else { return }
        didCheckTrend = true
        hasPrevious = (try? await api.send(AnalysisAPI.trend(id: analysisID)))?.previous != nil
    }
}
