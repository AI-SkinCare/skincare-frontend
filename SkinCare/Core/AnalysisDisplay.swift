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
            (withheldTitle(recommendation), .neutral)
        case .failed:
            ("추천을 만들지 못했어요", .negative)
        case .completed, .unknown:
            nil
        }
    }

    static func withheldTitle(_ status: RecommendationStatus?) -> String {
        switch status {
        case .noConcern: "추천 보류 · 선택한 고민 없음"
        case .uncertain: "추천 보류 · 분류 불확실"
        case .qualityRejected: "추천 보류 · 추천 기준 미충족"
        default: "추천을 제공하지 않았어요"
        }
    }

    static func classificationReason(_ disease: Disease) -> String {
        let unavailable = "이 결과에서는 분류 후보별 점수를 비교할 수 없어요."
        guard let score = disease.probabilities[disease.label],
              let selected = Disease.scoreTenths(score), selected == Disease.scoreTenths(disease.confidence),
              let runnerUp = disease.orderedProbabilities.filter({ $0.label != disease.label }).max(by: { $0.score < $1.score }),
              score >= runnerUp.score, let other = Disease.scoreTenths(runnerUp.score) else { return unavailable }

        let result = "‘\(disease.label)’ \(Disease.pointsFromTenths(selected)), 다음 후보 ‘\(runnerUp.label)’ \(Disease.pointsFromTenths(other))"
        if selected == other { return result + "으로 표시 점수가 같아요." }
        return result + "으로 \(Disease.pointsFromTenths(selected - other)) 차이가 났어요."
    }

    static func classificationContext(_ disease: Disease, captureView: String?) -> String? {
        let photo: String? = switch captureView {
        case "front": "정면 사진"
        case "side": "측면 사진"
        default: nil
        }
        let version = disease.modelVersion ?? ""
        let model: String? = if version.hasPrefix("densenet121") {
            "DenseNet121"
        } else if version.hasPrefix("dinov2") {
            "DINOv2"
        } else {
            nil
        }
        let parts = [photo, model].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
