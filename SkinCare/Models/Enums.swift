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

// MARK: - 분석 상태 (API 변경사항 §1.4)

/// 분석 작업 상태. 분석 `status`만 대문자다.
enum AnalysisStatus: String, Codable, Sendable, UnknownCaseDecodable {
    case queued = "QUEUED"
    case generating = "GENERATING"
    case completed = "COMPLETED"
    /// 추천 보류 — 오류가 아니다. 재요청 불가
    case withheld = "WITHHELD"
    case failed = "FAILED"
    case unknown
    static let unknownCase = AnalysisStatus.unknown

    /// 폴링을 계속할 상태
    var isInProgress: Bool { self == .queued || self == .generating }
}

/// AI 추천 결과 상태. COMPLETED·WITHHELD일 때만 값이 있다.
enum RecommendationStatus: String, Codable, Sendable, UnknownCaseDecodable {
    case generated
    /// 분류가 불확실해 보류 → 재촬영·상담 안내
    case uncertain
    /// 정상 분류 + 고른 고민 없음 → 설문에서 고민 선택 안내
    case noConcern = "no_concern"
    case unknown
    static let unknownCase = RecommendationStatus.unknown
}

// MARK: - 이미지 분류 (DenseNet121 6종)

/// 분류 라벨 영문 코드. 화면에는 서버의 한글 `label`을 그대로 쓴다 (팀 결정).
enum DiseaseClass: String, Codable, Sendable, UnknownCaseDecodable {
    case psoriasis, atopic, acne, normal, rosacea, seborrheic, unknown
    static let unknownCase = DiseaseClass.unknown

    /// `probabilities` 키 순서 (API 변경사항 §1.4 "위 순서")
    static let displayOrder = ["건선", "아토피", "여드름", "정상", "주사", "지루"]
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

/// 설문 고민 8종. 정상으로 분류되면 고른 고민이 추천 대상이 된다.
enum Concern: String, Codable, Sendable, UnknownCaseDecodable {
    case pigmentation, pore, wrinkle, acne, redness, dryness, sagging, sensitivity, unknown
    static let unknownCase = Concern.unknown

    /// API §6.4 "화면 표기"
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
