import Foundation

/// 추천 진행 상태 폴링 간격 (API 변경사항 §1.4).
/// 처음 3분은 3초, 이후 10초, 150초가 지나면 지연 안내, 최대 30분. 경과 시간은 분석 제출 시각 기준 (패치 §2 SCR-08).
enum PollingPolicy {
    static let fastInterval: TimeInterval = 3
    static let slowInterval: TimeInterval = 10
    static let slowAfter: TimeInterval = 3 * 60
    static let delayNoticeAfter: TimeInterval = 150
    static let timeout: TimeInterval = 30 * 60

    /// "평소보다 오래 걸리고 있어요" 안내를 보여줄지
    static func showsDelayNotice(elapsed: TimeInterval) -> Bool {
        elapsed >= delayNoticeAfter
    }

    /// 다음 조회까지 기다릴 시간. nil이면 폴링을 멈춘다.
    static func interval(elapsed: TimeInterval) -> TimeInterval? {
        switch elapsed {
        case ..<slowAfter: fastInterval
        case ..<timeout: slowInterval
        default: nil
        }
    }
}
