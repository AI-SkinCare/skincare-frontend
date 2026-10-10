import Foundation

/// 추천 진행 상태 폴링 간격 (화면 설계서 SCR-08, API §4.2).
/// 처음 3분은 3초, 이후 10초, 15분이 지나면 중단. 경과 시간은 분석 제출 시각 기준 (패치 §2 SCR-08).
enum PollingPolicy {
    static let fastInterval: TimeInterval = 3
    static let slowInterval: TimeInterval = 10
    static let slowAfter: TimeInterval = 3 * 60
    static let timeout: TimeInterval = 15 * 60

    /// 다음 조회까지 기다릴 시간. nil이면 폴링을 멈춘다.
    static func interval(elapsed: TimeInterval) -> TimeInterval? {
        switch elapsed {
        case ..<slowAfter: fastInterval
        case ..<timeout: slowInterval
        default: nil
        }
    }
}
