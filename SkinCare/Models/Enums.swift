import Foundation

/// 서버가 모르는 열거형 값을 보내도 디코딩이 실패하지 않게 `unknown`으로 받는다 (패치 §3.4).
protocol UnknownCaseDecodable: RawRepresentable, Decodable, CaseIterable where RawValue == String {
    static var unknownCase: Self { get }
}

extension UnknownCaseDecodable {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.unknownCase
    }

    /// `unknown`을 뺀 선택 가능한 값
    static var knownCases: [Self] { allCases.filter { $0 != unknownCase } }
}

// MARK: - 분석 상태 (API §6.1)

enum AnalysisStatus: String, Codable, Sendable, UnknownCaseDecodable {
    case queued, recommending, done, failed, unknown
    static let unknownCase = AnalysisStatus.unknown

    var isInProgress: Bool { self == .queued || self == .recommending }
}

enum RecommendationStatus: String, Codable, Sendable, UnknownCaseDecodable {
    case pending, done, failed, unknown
    static let unknownCase = RecommendationStatus.unknown
}

// MARK: - 지표 · ROI · 등급

enum Metric: String, Codable, Sendable, UnknownCaseDecodable {
    case moisture, elasticity, pigmentation, pore, unknown
    static let unknownCase = Metric.unknown

    var displayName: String {
        switch self {
        case .moisture: "수분"
        case .elasticity: "탄력"
        case .pigmentation: "색소침착"
        case .pore: "모공"
        case .unknown: "기타"
        }
    }

    /// 색소침착·모공은 원래 값이 낮을수록 좋다 (설계서 §4.5)
    var lowerIsBetter: Bool { self == .pigmentation || self == .pore }
}

enum ROI: String, Codable, Sendable, UnknownCaseDecodable {
    case fullFace = "full_face"
    case forehead, glabella
    case eyeLeft = "eye_left"
    case eyeRight = "eye_right"
    case cheekLeft = "cheek_left"
    case cheekRight = "cheek_right"
    case lip, chin, unknown
    static let unknownCase = ROI.unknown

    var displayName: String {
        switch self {
        case .fullFace: "얼굴 전체"
        case .forehead: "이마"
        case .glabella: "미간"
        case .eyeLeft: "왼쪽 눈가"
        case .eyeRight: "오른쪽 눈가"
        case .cheekLeft: "왼쪽 볼"
        case .cheekRight: "오른쪽 볼"
        case .lip: "입가"
        case .chin: "턱"
        case .unknown: "기타 부위"
        }
    }
}

/// 등급은 백엔드가 계산해 내려준다 (설계서 §4.5). 앱은 표시만 한다.
enum Grade: String, Codable, Sendable, UnknownCaseDecodable {
    case good, normal, care, unknown
    static let unknownCase = Grade.unknown

    var label: String {
        switch self {
        case .good: "양호"
        case .normal: "보통"
        case .care: "관리 필요"
        case .unknown: "-"
        }
    }

    /// 종합 점수처럼 서버가 등급을 따로 주지 않는 값의 라벨용. 기준은 API §6.6과 같다.
    init(score: Int) {
        switch score {
        case 70...: self = .good
        case 40..<70: self = .normal
        default: self = .care
        }
    }
}

// MARK: - 피부 프로필 (API §6.3, §6.4)

enum SkinType: String, Codable, Sendable, UnknownCaseDecodable {
    case dry, normal, oily, combination, unknown
    static let unknownCase = SkinType.unknown

    var label: String {
        switch self {
        case .dry: "건성"
        case .normal: "중성"
        case .oily: "지성"
        case .combination: "복합성"
        case .unknown: "알 수 없음"
        }
    }
}

enum Concern: String, Codable, Sendable, UnknownCaseDecodable {
    case pigmentation, pore, wrinkle, acne, redness, dryness, sagging, sensitivity, unknown
    static let unknownCase = Concern.unknown

    /// API §6.4 "화면 표기" — 의료 용어로 읽히지 않는 사용자용 표현
    var displayLabel: String {
        switch self {
        case .pigmentation: "피부 톤·잡티"
        case .pore: "모공"
        case .wrinkle: "주름"
        case .acne: "트러블"
        case .redness: "붉은기"
        case .dryness: "건조·각질"
        case .sagging: "탄력"
        case .sensitivity: "민감함"
        case .unknown: "기타"
        }
    }
}

enum RoutineTime: String, Codable, Sendable, UnknownCaseDecodable {
    case morning, evening, daily, weekly, anytime, unknown
    static let unknownCase = RoutineTime.unknown
}

// MARK: - 설문 (API §6.7)

enum Gender: String, Codable, Sendable, UnknownCaseDecodable {
    case female, male, unknown
    static let unknownCase = Gender.unknown

    var label: String {
        switch self {
        case .female: "여성"
        case .male: "남성"
        case .unknown: "-"
        }
    }
}

enum AgeBand: String, Codable, Sendable, UnknownCaseDecodable {
    case teens = "10s", twenties = "20s", thirties = "30s", forties = "40s"
    case fifties = "50s", sixties = "60s", seventies = "70s", unknown
    static let unknownCase = AgeBand.unknown

    var label: String { self == .unknown ? "-" : "\(rawValue.dropLast())대" }
}

enum Level: String, Codable, Sendable, UnknownCaseDecodable {
    case low, medium, high, unknown
    static let unknownCase = Level.unknown

    var label: String {
        switch self {
        case .low: "적음"
        case .medium: "보통"
        case .high: "많음"
        case .unknown: "-"
        }
    }
}
