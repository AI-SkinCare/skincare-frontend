import Foundation

/// 고정 문구 (화면 설계서 §4). 새 문구는 문구 규칙(진단·치료·질환명 금지)을 지킨다.
enum AppCopy {
    static let disclaimer = "본 결과는 참고용 정보이며 의학적 진단이나 치료를 대신하지 않습니다. 피부 이상이 지속되면 피부과 전문의와 상담하세요."
    static let demoNotice = "측정 모델 준비 중이라 예시 수치를 보여드려요. 실제 피부 상태와 관계없어요."
    static let demoReportNotice = "측정 모델 준비 중이라 예시 수치를 보여드려요. 추천은 설문 응답만 반영했어요."
    static let imageConsent = "촬영한 사진은 피부 상태 측정에만 사용하며, 측정이 끝나면 바로 삭제되어 저장되지 않아요."
    static let imageConsentShort = "사진은 측정에만 쓰고 저장하지 않아요."
    static let serverMaintenance = "지금은 분석 서버 점검 중이에요. 이력은 볼 수 있어요."
    static let networkError = "인터넷 연결을 확인하고 다시 시도해 주세요."

    static func commonError(requestID: String?) -> String {
        let base = "문제가 생겼어요. 잠시 후 다시 시도해 주세요."
        guard let requestID, !requestID.isEmpty else { return base }
        return "\(base) (문의 시 코드: \(requestID.prefix(8)))"
    }
}
