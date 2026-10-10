import Foundation

/// 설문 (API §4.1). 필수는 gender·ageBand, 나머지는 선택 — 비어 있으면 키를 보내지 않는다.
struct Survey: Codable, Sendable, Equatable {
    var gender: Gender?
    var ageBand: AgeBand?
    var skinType: SkinType?
    var sleepHours: Int?
    var waterIntakeLevel: Level?
    var sunExposureLevel: Level?
    var stressLevel: Level?
    var concerns: [Concern]?
    var currentProducts: [String]?
    var note: String?

    static let maxConcerns = 3
    static let maxProducts = 5
    static let maxProductLength = 30
    static let maxNoteLength = 300
    static let sleepHoursRange = 0...14

    var hasRequiredFields: Bool {
        gender.map { $0 != .unknown } == true && ageBand.map { $0 != .unknown } == true
    }

    /// 서버에서 받은 값 중 앱이 모르는 값은 버리고 보낸다.
    func sanitized() -> Survey {
        var copy = self
        if copy.skinType == .unknown { copy.skinType = nil }
        for keyPath in [\Survey.waterIntakeLevel, \.sunExposureLevel, \.stressLevel] where copy[keyPath: keyPath] == .unknown {
            copy[keyPath: keyPath] = nil
        }
        copy.concerns = concerns?.filter { $0 != .unknown }
        if copy.concerns?.isEmpty == true { copy.concerns = nil }
        if copy.currentProducts?.isEmpty == true { copy.currentProducts = nil }
        if copy.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { copy.note = nil }
        return copy
    }
}

/// POST /analyses, …/recommendation/retry 응답
struct AnalysisSubmission: Decodable, Sendable {
    let analysisId: String
    let status: AnalysisStatus
    let queuePosition: Int?
    let estimatedWaitSec: Int?
}

/// GET /analyses/{id} (API §4.2)
struct AnalysisDetail: Decodable, Sendable {
    let analysisId: String
    let status: AnalysisStatus
    let createdAt: Date
    let completedAt: Date?
    let queuePosition: Int?
    let estimatedWaitSec: Int?
    let measurement: Measurement
    let recommendation: Recommendation
    let survey: Survey?
    let error: APIErrorBody?
}

struct Measurement: Decodable, Sendable {
    let isDemo: Bool
    let confidence: Double
    let calibrationApplied: Bool
    let overallScore: Int
    let summary: [MetricSummary]
    let byRoi: [RoiMetrics]
}

struct MetricSummary: Decodable, Sendable, Identifiable {
    let metric: Metric
    /// 원래 값 (0–100). 색소침착·모공은 높을수록 나쁨
    let value: Int
    /// 좋은 방향으로 통일한 값 — 막대 길이에 쓴다
    let score: Int
    let grade: Grade

    var id: String { metric.rawValue }
}

struct RoiMetrics: Decodable, Sendable, Identifiable {
    let roi: ROI
    let moisture: Int
    let elasticity: Int
    let pigmentation: Int
    let pore: Int
    let overallScore: Int
    let grade: Grade

    var id: String { roi.rawValue }

    func value(of metric: Metric) -> Int? {
        switch metric {
        case .moisture: moisture
        case .elasticity: elasticity
        case .pigmentation: pigmentation
        case .pore: pore
        case .unknown: nil
        }
    }
}

struct CodeLabel<Code: Decodable & Sendable>: Decodable, Sendable {
    let code: Code
    let label: String
}

/// 진행 중이면 `{ "status": "pending" }`만 온다.
struct Recommendation: Decodable, Sendable {
    let status: RecommendationStatus
    let skinType: CodeLabel<SkinType>?
    let concerns: [CodeLabel<Concern>]?
    let ingredients: [Ingredient]?
    let routine: [RoutineStep]?
    let reasoning: [String]?
    let answer: String?
    let inputNotes: [String]?
    let disclaimer: String?
}

struct Ingredient: Decodable, Sendable, Identifiable {
    let name: String
    let purpose: String?
    let priority: Int

    var id: String { "\(priority)-\(name)" }
}

struct RoutineStep: Decodable, Sendable, Identifiable {
    let step: Int
    let time: RoutineTime
    let action: String

    var id: String { "\(time.rawValue)-\(step)" }
}

// MARK: - 이력 · 추이

struct AnalysisListItem: Decodable, Sendable, Identifiable {
    let analysisId: String
    let createdAt: Date
    let status: AnalysisStatus
    let overallScore: Int
    let isDemo: Bool
    let concerns: [Concern]

    var id: String { analysisId }
}

struct PageInfo: Decodable, Sendable {
    let page: Int
    let size: Int
    let totalItems: Int
    let totalPages: Int
}

struct AnalysisPage: Decodable, Sendable {
    let items: [AnalysisListItem]
    let page: PageInfo
}

struct MetricValues: Decodable, Sendable {
    let moisture: Int
    let elasticity: Int
    let pigmentation: Int
    let pore: Int

    subscript(metric: Metric) -> Int {
        switch metric {
        case .moisture: moisture
        case .elasticity: elasticity
        case .pigmentation: pigmentation
        case .pore, .unknown: pore
        }
    }
}

struct TrendPoint: Decodable, Sendable {
    let analysisId: String
    /// "2026-10-15" (KST 날짜)
    let date: String
    let overallScore: Int
    let summary: MetricValues
}

/// delta는 원래 값의 차이 — 색소침착·모공은 음수가 좋아진 것 (API §4.5)
struct TrendDelta: Decodable, Sendable {
    let overallScore: Int
    let moisture: Int
    let elasticity: Int
    let pigmentation: Int
    let pore: Int

    subscript(metric: Metric) -> Int {
        switch metric {
        case .moisture: moisture
        case .elasticity: elasticity
        case .pigmentation: pigmentation
        case .pore, .unknown: pore
        }
    }
}

struct Trend: Decodable, Sendable {
    let current: TrendPoint
    let previous: TrendPoint?
    let delta: TrendDelta?
}
