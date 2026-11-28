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
    var avoidIngredients: [String]?
    var symptomProfile: SymptomProfile?
    var captureView: String?

    static let maxConcerns = 3
    static let maxProducts = 5
    static let maxProductLength = 30
    static let maxNoteLength = 300
    static let maxAvoidIngredients = 30
    static let maxIngredientLength = 100
    static let sleepHoursRange = 0...14

    var hasRequiredFields: Bool {
        gender.map { $0 != .unknown } == true && ageBand.map { $0 != .unknown } == true
    }

    /// 설문 항목에 답했는지. "잘 모르겠어요"(`unsure`)를 고른 것도 답한 것으로 본다 — 서버에는 그 키를 보내지 않는다.
    func isAnswered(_ item: SurveyItem, unsure: Set<SurveyItem>) -> Bool {
        if unsure.contains(item) { return true }
        switch item {
        case .skinType: return skinType.map { $0 != .unknown } == true
        case .sleepHours: return sleepHours != nil
        case .waterIntake: return waterIntakeLevel.map { $0 != .unknown } == true
        case .sunExposure: return sunExposureLevel.map { $0 != .unknown } == true
        case .stress: return stressLevel.map { $0 != .unknown } == true
        case .concerns: return concerns?.contains { $0 != .unknown } == true
        case .currentProducts: return currentProducts?.isEmpty == false
        }
    }

    /// 1단계: 성별·연령대(필수, "모르겠어요" 없음) + 피부 타입
    func isStepOneComplete(unsure: Set<SurveyItem>) -> Bool {
        hasRequiredFields && SurveyItem.stepOne.allSatisfy { isAnswered($0, unsure: unsure) }
    }

    /// 2단계: 추가 요청(자유 입력)을 뺀 모든 항목
    func isStepTwoComplete(unsure: Set<SurveyItem>) -> Bool {
        SurveyItem.stepTwo.allSatisfy { isAnswered($0, unsure: unsure) }
    }

    /// "잘 모르겠어요"를 고르면 그 항목 값을 비운다 (서버에 보내지 않음).
    mutating func clear(_ item: SurveyItem) {
        switch item {
        case .skinType: skinType = nil
        case .sleepHours: sleepHours = nil
        case .waterIntake: waterIntakeLevel = nil
        case .sunExposure: sunExposureLevel = nil
        case .stress: stressLevel = nil
        case .concerns: concerns = nil
        case .currentProducts: currentProducts = nil
        }
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
        copy.avoidIngredients = avoidIngredients?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if copy.avoidIngredients?.isEmpty == true { copy.avoidIngredients = nil }
        if copy.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { copy.note = nil }
        copy.symptomProfile = symptomProfile?.sanitized()
        return copy
    }

    /// 피부 상태는 매 분석에서 달라질 수 있어 직전 답변을 복사하지 않는다.
    func defaultsForNewAnalysis() -> Survey {
        var copy = sanitized()
        copy.symptomProfile = nil
        copy.captureView = nil
        return copy
    }
}

/// 설문에서 "잘 모르겠어요"로 넘길 수 있는 항목 (앱 화면 상태 — 서버로 보내지 않음)
enum SurveyItem: Hashable, Sendable {
    case skinType, sleepHours, waterIntake, sunExposure, stress, concerns, currentProducts

    static let stepOne: [SurveyItem] = [.skinType]
    static let stepTwo: [SurveyItem] = [.sleepHours, .waterIntake, .sunExposure, .stress, .concerns, .currentProducts]
}

/// 이미지 분류 결과 (DenseNet121 6종). 진단이 아닌 **참고 결과**다.
struct Disease: Decodable, Sendable, Equatable {
    /// 분류 라벨(한글) — 건선·아토피·여드름·정상·주사·지루. 화면에 그대로 표시한다.
    let label: String
    let labelEn: DiseaseClass
    /// 모델 분류 점수 0–1. 앱에서는 100점 만점으로 표시한다.
    let confidence: Double
    /// 점수가 AI 임계값(0.6) 미만이면 true
    let uncertain: Bool
    /// 6종 라벨(한글) → 0–1
    let probabilities: [String: Double]
    let modelVersion: String?
    let explanation: ClassificationExplanation?

    init(label: String, labelEn: DiseaseClass, confidence: Double, uncertain: Bool,
         probabilities: [String: Double], modelVersion: String? = nil,
         explanation: ClassificationExplanation? = nil) {
        self.label = label
        self.labelEn = labelEn
        self.confidence = confidence
        self.uncertain = uncertain
        self.probabilities = probabilities
        self.modelVersion = modelVersion
        self.explanation = explanation
    }

    private enum CodingKeys: String, CodingKey {
        case label, labelEn, confidence, uncertain, probabilities, modelVersion, explanation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        labelEn = try container.decode(DiseaseClass.self, forKey: .labelEn)
        confidence = try container.decode(Double.self, forKey: .confidence)
        uncertain = try container.decode(Bool.self, forKey: .uncertain)
        probabilities = (try? container.decode([String: Double].self, forKey: .probabilities)) ?? [:]
        modelVersion = try? container.decodeIfPresent(String.self, forKey: .modelVersion)
        // A malformed optional visualization must not hide the classification.
        explanation = try? container.decodeIfPresent(ClassificationExplanation.self, forKey: .explanation)
    }

    var confidencePoints: String? { Self.points(confidence) }

    /// 표시 순서(건선·아토피·여드름·정상·주사·지루)대로 정렬한 점수. 모르는 라벨은 뒤에 붙인다.
    var orderedProbabilities: [(label: String, score: Double)] {
        let scores = probabilities.filter { Self.scoreTenths($0.value) != nil }
        let known = DiseaseClass.displayOrder.compactMap { key in scores[key].map { (key, $0) } }
        let extra = scores.filter { !DiseaseClass.displayOrder.contains($0.key) }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { ($0.key, $0.value) }
        return known + extra
    }

    static func scoreTenths(_ value: Double) -> Int? {
        guard value.isFinite, (0...1).contains(value) else { return nil }
        return Int((value * 1000).rounded())
    }

    static func points(_ value: Double) -> String? {
        scoreTenths(value).map(pointsFromTenths)
    }

    static func pointsFromTenths(_ tenths: Int) -> String {
        "\(tenths / 10).\(tenths % 10)점"
    }
}

struct ClassificationExplanation: Decodable, Sendable, Equatable {
    let available: Bool
    let method: String
    let targetLabel: String
    let modelVersion: String
    let heatmapPngBase64: String?
    let interpretation: String?
    let unavailableReason: String?

    func heatmapData(for disease: Disease) -> Data? {
        guard available, method == "grad_cam", targetLabel == disease.label,
              modelVersion == disease.modelVersion,
              let encoded = heatmapPngBase64, encoded.utf8.count <= 120_000,
              let data = Data(base64Encoded: encoded), data.count >= 33, data.count <= 90_000 else { return nil }
        let bytes = [UInt8](data.prefix(33))
        guard Array(bytes.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10],
              Array(bytes[12..<16]) == [73, 72, 68, 82],
              Array(bytes[16..<20]) == [0, 0, 1, 0], Array(bytes[20..<24]) == [0, 0, 1, 0],
              bytes[24] == 8, bytes[25] == 0 else { return nil }
        return data
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
    let generation: GenerationMetadata?

    var canDisplayRecommendation: Bool {
        status == .completed && recommendationStatus == .generated && recommendation != nil
            && generation?.preventsRecommendation != true
    }

    enum CodingKeys: String, CodingKey {
        case analysisId, status, disease, recommendationStatus, recommendation, guidance, error
        case queuePosition, estimatedWaitSec, createdAt, completedAt, survey, generation
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
        generation = try container.decodeIfPresent(GenerationMetadata.self, forKey: .generation)
    }
}

struct GenerationMetadata: Decodable, Sendable {
    let origin: GenerationOrigin?
    let qualityStatus: String?
    let evidenceStatus: String?
    let qualityIssues: [String]?

    var preventsRecommendation: Bool {
        origin == .notGenerated || qualityStatus == "withheld" || evidenceStatus == "withheld"
    }

    var sourceNotice: String? {
        switch origin {
        case .model: "AI가 작성한 추천이에요. 성분을 펼치면 출처가 저장됐는지 확인할 수 있어요."
        case .sourceCards: "근거 자료를 바탕으로 구성한 대체 안내예요. 모델이 생성한 답변과 구별해 제공해요."
        case .ruleFallback: "기본 관리 규칙으로 구성한 대체 안내예요."
        default: nil
        }
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
    var purposeSource: String?
    var purposeStatus: String?
    var evidence: IngredientEvidence?

    var id: String { "\(priority)-\(name)" }
}

extension Ingredient {
    init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        name = try fields.decode(String.self, forKey: .name)
        priority = try fields.decode(Int.self, forKey: .priority)
        purpose = try fields.decodeIfPresent(String.self, forKey: .purpose)
        purposeSource = try fields.decodeIfPresent(String.self, forKey: .purposeSource)
        purposeStatus = try fields.decodeIfPresent(String.self, forKey: .purposeStatus)
        evidence = try? fields.decode(IngredientEvidence.self, forKey: .evidence)
    }

    private enum CodingKeys: String, CodingKey { case name, priority, purpose, purposeSource, purposeStatus, evidence }
}

struct IngredientEvidence: Decodable, Sendable {
    let claimId: String
    let version: String?
    let effect, limitations: String
    let usageConditions: [String]
    let sources: [EvidenceSource]

    var canDisplay: Bool {
        !claimId.isEmpty && !effect.isEmpty && !limitations.isEmpty &&
        !usageConditions.isEmpty && sources.contains { $0.webURL != nil }
    }
}

struct EvidenceSource: Decodable, Sendable {
    let title, url: String
    let summary: String?

    var webURL: URL? {
        guard !title.isEmpty, let link = URLComponents(string: url), link.scheme?.lowercased() == "https",
              let host = link.host, !host.isEmpty, link.user == nil, link.password == nil else { return nil }
        return link.url
    }
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
