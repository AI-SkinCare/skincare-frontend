import Foundation

/// 분석 상태를 목록·카드에 짧게 보여줄 문구 (API 변경사항 §1.4 상태표)
enum AnalysisDisplay {
    enum Tone {
        case progress, neutral, negative
    }

    /// COMPLETED는 nil — 추천 고민 칩을 대신 보여준다.
    static func statusLine(status: AnalysisStatus, recommendation: RecommendationStatus?) -> (text: String, tone: Tone)? {
        switch status {
        case .queued, .generating:
            ("맞춤 추천 작성 중", .progress)
        case .withheld:
            recommendation == .noConcern ? ("추천 보류 · 선택한 고민 없음", .neutral) : ("추천 보류 · 분류 불확실", .neutral)
        case .failed:
            ("추천을 만들지 못했어요", .negative)
        case .completed, .unknown:
            nil
        }
    }
}
