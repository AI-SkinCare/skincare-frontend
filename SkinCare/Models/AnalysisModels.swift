import Foundation

// API 변경사항(docs/new_common/api변경사항.md) §1.3·§1.4 기준

/// 설문. 필수는 gender·ageBand, 나머지는 선택 — 비어 있으면 키를 보내지 않는다.
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

/// 이미지 분류 결과 (DenseNet121 6종). 진단이 아닌 **참고 결과**다.
struct Disease: Decodable, Sendable, Equatable {
    /// 분류 라벨(한글) — 건선·아토피·여드름·정상·주사·지루. 화면에 그대로 표시한다.
    let label: String
    let labelEn: DiseaseClass
    /// 모델 분류 점수 0–1. 질환 확률이 아니다 — 화면엔 백분율 + "모델 분류 점수"로 표기
    let confidence: Double
    /// 점수가 AI 임계값(0.6) 미만이면 true
    let uncertain: Bool
    /// 6종 라벨(한글) → 0–1
    let probabilities: [String: Double]

    /// "90%"
    var confidencePercent: String { Self.percent(confidence) }

    /// 표시 순서(건선·아토피·여드름·정상·주사·지루)대로 정렬한 점수. 모르는 라벨은 뒤에 붙인다.
    var orderedProbabilities: [(label: String, score: Double)] {
        let known = DiseaseClass.displayOrder.compactMap { key in probabilities[key].map { (key, $0) } }
        let extra = probabilities.filter { !DiseaseClass.displayOrder.contains($0.key) }
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
        return known + extra
    }

    static func percent(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }
}

/// 분석 응답. `POST /analyses`, 재요청, `GET /analyses/{id}`가 모두 이 형태다.
struct AnalysisView: Decodable, Sendable {
    let analysisId: String
    let status: AnalysisStatus
    let disease: Disease
    /// COMPLETED·WITHHELD일 때만 값이 있다
    let recommendationStatus: RecommendationStatus?
    /// COMPLETED일 때만 값이 있다
    let recommendation: Recommendation?
    /// COMPLETED·WITHHELD일 때 안내 문장, 그 밖에는 빈 배열
    let guidance: [String]
    /// FAILED일 때 (E3001·E3002·E3003·E4001)
    let error: APIErrorBody?
    /// QUEUED일 때만
    let queuePosition: Int?
    let estimatedWaitSec: Int?
    let createdAt: Date
    let completedAt: Date?
    let survey: Survey?

    enum CodingKeys: String, CodingKey {
        case analysisId, status, disease, recommendationStatus, recommendation, guidance, error
        case queuePosition, estimatedWaitSec, createdAt, completedAt, survey
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        analysisId = try container.decode(String.self, forKey: .analysisId)
        status = try container.decode(AnalysisStatus.self, forKey: .status)
        disease = try container.decode(Disease.self, forKey: .disease)
        recommendationStatus = try container.decodeIfPresent(RecommendationStatus.self, forKey: .recommendationStatus)
        recommendation = try container.decodeIfPresent(Recommendation.self, forKey: .recommendation)
        guidance = try container.decodeIfPresent([String].self, forKey: .guidance) ?? []
        error = try container.decodeIfPresent(APIErrorBody.self, forKey: .error)
        queuePosition = try container.decodeIfPresent(Int.self, forKey: .queuePosition)
        estimatedWaitSec = try container.decodeIfPresent(Int.self, forKey: .estimatedWaitSec)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        survey = try container.decodeIfPresent(Survey.self, forKey: .survey)
    }
}

struct CodeLabel<Code: Decodable & Sendable>: Decodable, Sendable {
    let code: Code
    let label: String
}

/// 성분 추천 (Qwen2.5 + rec_sllm_v2). COMPLETED일 때만 온다.
struct Recommendation: Decodable, Sendable {
    let skinType: CodeLabel<SkinType>?
    let concerns: [CodeLabel<Concern>]?
    /// 개수 가변. purpose가 null이면 성분명만 표시
    let ingredients: [Ingredient]?
    let routine: [RoutineStep]?
    /// 생성된 설명 — 검증된 근거로 표시하지 않는다. 개수 고정 아님
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

// MARK: - 이력

/// `GET /analyses` 항목
struct AnalysisListItem: Decodable, Sendable, Identifiable {
    let analysisId: String
    let createdAt: Date
    let status: AnalysisStatus
    let recommendationStatus: RecommendationStatus?
    let disease: Disease
    /// COMPLETED면 추천 고민 코드, 아니면 빈 배열
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
