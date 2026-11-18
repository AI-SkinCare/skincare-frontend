import Foundation

/// 자가 응답. nil은 미응답, false와 none은 명시적인 답변이다.
struct SymptomProfile: Codable, Sendable, Equatable {
    var itch: ItchFrequency?
    var flaking: FlakingPattern?
    var recurringRedness: Bool?
    var visiblePlugs: Bool?
    var onset: SymptomOnset?
    var areas: [SymptomArea]?

    func sanitized() -> Self? {
        var copy = self
        if copy.itch == .unknown { copy.itch = nil }
        if copy.flaking == .unknown { copy.flaking = nil }
        if copy.onset == .unknown { copy.onset = nil }
        var seen = Set<SymptomArea>()
        copy.areas = copy.areas?.filter { $0 != .unknown && seen.insert($0).inserted }
        if copy.areas?.isEmpty == true { copy.areas = nil }
        return copy == Self() ? nil : copy
    }
}

enum ItchFrequency: String, Codable, Sendable, UnknownCaseDecodable {
    case none, occasional, frequent, unknown
    static let unknownCase = ItchFrequency.unknown

    var label: String {
        switch self {
        case .none: "없었어요"
        case .occasional: "가끔"
        case .frequent: "자주"
        case .unknown: "잘 모르겠어요"
        }
    }
}

enum FlakingPattern: String, Codable, Sendable, UnknownCaseDecodable {
    case none, dry, greasy, both, unknown
    static let unknownCase = FlakingPattern.unknown

    var label: String {
        switch self {
        case .none: "없었어요"
        case .dry: "건조해 보였어요"
        case .greasy: "기름져 보였어요"
        case .both: "둘 다 있었어요"
        case .unknown: "잘 모르겠어요"
        }
    }
}

enum SymptomOnset: String, Codable, Sendable, UnknownCaseDecodable {
    case underOneWeek = "under_one_week"
    case oneToFourWeeks = "one_to_four_weeks"
    case overFourWeeks = "over_four_weeks"
    case unknown
    static let unknownCase = SymptomOnset.unknown

    var label: String {
        switch self {
        case .underOneWeek: "1주 미만"
        case .oneToFourWeeks: "1~4주 전"
        case .overFourWeeks: "4주 넘음"
        case .unknown: "잘 모르겠어요"
        }
    }
}

enum SymptomArea: String, Codable, Sendable, UnknownCaseDecodable {
    case forehead
    case hairlineScalp = "hairline_scalp"
    case eyebrows
    case aroundNose = "around_nose"
    case cheeks
    case jawChin = "jaw_chin"
    case unknown
    static let unknownCase = SymptomArea.unknown

    var label: String {
        switch self {
        case .forehead: "이마"
        case .hairlineScalp: "머리카락 경계·두피"
        case .eyebrows: "눈썹 주변"
        case .aroundNose: "코 주변"
        case .cheeks: "볼"
        case .jawChin: "턱"
        case .unknown: "잘 모르겠어요"
        }
    }
}
