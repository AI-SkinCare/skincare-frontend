import Foundation

/// 고정 문구. 분류 라벨(질환명)은 그대로 쓰되 진단·치료로 표현하지 않는다 (개정 기획, CLAUDE.md).
enum AppCopy {
    static let disclaimer = "본 결과는 참고용 정보이며 의학적 진단이나 치료를 대신하지 않습니다. 피부 이상이 지속되면 피부과 전문의와 상담하세요."
    static let imageConsentShort = "사진은 분석에만 쓰고 저장하지 않아요."
    /// 분류 결과 상시 안내 — 서버 `guidance`가 아직 없을 때(추천 진행 중) 쓴다 (개정 수행계획서 A.3)
    static let classificationNotice = "이미지 모델의 6종 분류 참고 결과이며 의학적 진단이 아닙니다."
    static let explanationTitle = "모델이 참고한 영역"
    static let explanationNotice = "밝을수록 모델 분류 점수에 영향을 준 영역이에요. 원본 사진을 포함하지 않은 참고 지도이며, 병변 위치나 중증도를 나타내지 않아요."
    static let explanationAccessibility = "모델 분류에 영향을 준 영역의 밝기 지도. 병변 위치의 정답이 아닙니다."
    static let explanationUnavailable = "이 사진에서는 참고 영역을 표시하기 어려워요. 분류 결과와 추천은 계속 확인할 수 있어요."
    static let serverMaintenance = "지금은 분석 서버 점검 중이에요. 이력은 볼 수 있어요."
    static let networkError = "인터넷 연결을 확인하고 다시 시도해 주세요."

    static func commonError(requestID: String?) -> String {
        let base = "문제가 생겼어요. 잠시 후 다시 시도해 주세요."
        guard let requestID, !requestID.isEmpty else { return base }
        return "\(base) (문의 시 코드: \(requestID.prefix(8)))"
    }
}
