import Foundation
import Testing
@testable import SkinCare

/// docs/new_common/api변경사항.md §1.4 예시 응답을 그대로 디코딩한다.
struct DecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONCoding.decoder().decode(type, from: Data(json.utf8))
    }

    @Test("COMPLETED: 분류 + 추천 + 안내문")
    func completed() throws {
        let analysis = try decode(AnalysisView.self, Fixtures.completed)
        #expect(analysis.status == .completed)
        #expect(!analysis.status.isInProgress)
        #expect(analysis.disease.label == "아토피")
        #expect(analysis.disease.labelEn == .atopic)
        #expect(analysis.disease.confidencePercent == "90%")
        #expect(analysis.disease.orderedProbabilities.map(\.label) == ["건선", "아토피", "여드름", "정상", "주사", "지루"])
        #expect(analysis.recommendationStatus == .generated)
        #expect(analysis.recommendation?.skinType?.code == .dry)
        #expect(analysis.recommendation?.concerns?.map(\.code) == [.sensitivity])
        #expect(analysis.recommendation?.ingredients?.count == 2)
        #expect(analysis.recommendation?.ingredients?.last?.purpose == nil)
        #expect(analysis.recommendation?.routine?.first?.time == .anytime)
        #expect(analysis.guidance.count == 2)
        #expect(analysis.survey?.ageBand == .twenties)
    }

    @Test("QUEUED: 추천·추천 상태 null, guidance 빈 배열, 대기 순번")
    func queued() throws {
        let analysis = try decode(AnalysisView.self, Fixtures.queued)
        #expect(analysis.status == .queued)
        #expect(analysis.status.isInProgress)
        #expect(analysis.recommendationStatus == nil)
        #expect(analysis.recommendation == nil)
        #expect(analysis.guidance.isEmpty)
        #expect(analysis.queuePosition == 2)
        #expect(analysis.completedAt == nil)
    }

    @Test("WITHHELD: 보류 사유별 추천 상태", arguments: [("uncertain", RecommendationStatus.uncertain),
                                                      ("no_concern", RecommendationStatus.noConcern)])
    func withheld(raw: String, expected: RecommendationStatus) throws {
        let analysis = try decode(AnalysisView.self, Fixtures.withheld(recommendationStatus: raw))
        #expect(analysis.status == .withheld)
        #expect(analysis.recommendationStatus == expected)
        #expect(analysis.recommendation == nil)
        #expect(analysis.disease.uncertain == (raw == "uncertain"))
    }

    @Test("FAILED: error 객체")
    func failed() throws {
        let analysis = try decode(AnalysisView.self, Fixtures.failed)
        #expect(analysis.status == .failed)
        #expect(analysis.error?.code == "E3002")
    }

    @Test("이력 항목")
    func listItem() throws {
        let page = try decode(AnalysisPage.self, """
        { "items": [ { "analysisId": "01J9", "createdAt": "2026-10-16T09:12:33Z", "status": "WITHHELD",
                       "recommendationStatus": "no_concern", "disease": \(Fixtures.diseaseNormal), "concerns": [] } ],
          "page": { "page": 1, "size": 20, "totalItems": 1, "totalPages": 1 } }
        """)
        #expect(page.items.first?.disease.label == "정상")
        #expect(page.items.first?.recommendationStatus == .noConcern)
    }

    @Test("모르는 열거형 값은 unknown으로 받는다")
    func unknownEnumValues() throws {
        let page = try decode(AnalysisPage.self, """
        { "items": [ { "analysisId": "01J9", "createdAt": "2026-10-16T09:12:33Z", "status": "ARCHIVED",
                       "recommendationStatus": "skipped", "disease": \(Fixtures.diseaseNormal), "concerns": ["pore", "freckles"] } ],
          "page": { "page": 1, "size": 20, "totalItems": 1, "totalPages": 1 } }
        """)
        let item = try #require(page.items.first)
        #expect(item.status == .unknown)
        #expect(item.recommendationStatus == .unknown)
        #expect(item.concerns == [.pore, .unknown])
    }

    @Test("날짜: 밀리초 있음·없음, checkedAt null")
    func dates() throws {
        let withMillis = try decode(SystemStatus.self, """
        { "aiAvailable": true, "queueLength": 0, "estimatedWaitSec": null, "checkedAt": "2026-10-15T09:12:00.123Z" }
        """)
        let withoutMillis = try decode(SystemStatus.self, """
        { "aiAvailable": false, "queueLength": 3, "estimatedWaitSec": 165, "checkedAt": "2026-10-15T09:12:00Z" }
        """)
        let beforeHealthCheck = try decode(SystemStatus.self, """
        { "aiAvailable": false, "queueLength": 0, "estimatedWaitSec": null, "checkedAt": null }
        """)
        let millis = try #require(withMillis.checkedAt)
        let plain = try #require(withoutMillis.checkedAt)
        #expect(abs(millis.timeIntervalSince(plain) - 0.123) < 0.001)
        #expect(Formatting.dateTime(plain) == "2026.10.15 18:12")
        #expect(beforeHealthCheck.checkedAt == nil)
    }

    @Test("설문 인코딩: 빈 값은 보내지 않는다")
    func surveyEncoding() throws {
        var survey = Survey(gender: .female, ageBand: .twenties)
        survey.concerns = []
        survey.note = "  "
        survey.skinType = .unknown
        let json = try #require(String(data: JSONEncoder().encode(survey.sanitized()), encoding: .utf8))
        #expect(json.contains("\"gender\":\"female\""))
        #expect(json.contains("\"ageBand\":\"20s\""))
        #expect(!json.contains("concerns"))
        #expect(!json.contains("note"))
        #expect(!json.contains("skinType"))
    }

    @Test("모델 분류 점수 백분율")
    func percent() {
        #expect(Disease.percent(0.554) == "55%")
        #expect(Disease.percent(1.2) == "100%")
        #expect(Disease.percent(-0.1) == "0%")
    }
}

enum Fixtures {
    static let diseaseAtopic = """
    { "label": "아토피", "labelEn": "atopic", "confidence": 0.9, "uncertain": false,
      "probabilities": { "건선": 0.02, "아토피": 0.9, "여드름": 0.02, "정상": 0.02, "주사": 0.02, "지루": 0.02 },
      "modelVersion": "densenet121_s2_3ea9506", "inferenceMs": 45 }
    """

    static let diseaseNormal = """
    { "label": "정상", "labelEn": "normal", "confidence": 0.9, "uncertain": false,
      "probabilities": { "건선": 0.02, "아토피": 0.02, "여드름": 0.02, "정상": 0.9, "주사": 0.02, "지루": 0.02 },
      "modelVersion": "densenet121_s2_3ea9506", "inferenceMs": 45 }
    """

    static let diseaseUncertain = """
    { "label": "아토피", "labelEn": "atopic", "confidence": 0.55, "uncertain": true,
      "probabilities": { "건선": 0.09, "아토피": 0.55, "여드름": 0.09, "정상": 0.09, "주사": 0.09, "지루": 0.09 },
      "modelVersion": "densenet121_s2_3ea9506", "inferenceMs": 45 }
    """

    static let completed = """
    {
      "analysisId": "01J9Z3K5V8Q2M4N6P8R0S2T4V6",
      "status": "COMPLETED",
      "disease": \(diseaseAtopic),
      "recommendationStatus": "generated",
      "recommendation": {
        "skinType": { "code": "dry", "label": "건성" },
        "concerns": [{ "code": "sensitivity", "label": "민감성(트러블/자극감)" }],
        "ingredients": [{ "name": "쑥잎 추출물", "purpose": "진정에 도움을 줄 수 있어요.", "priority": 1 },
                        { "name": "대나무추출물", "purpose": null, "priority": 2 }],
        "routine": [{ "step": 1, "time": "anytime", "action": "자극이 적은 제품을 써요." }],
        "reasoning": ["첫째", "둘째", "셋째"],
        "answer": "요약", "inputNotes": ["나이 추정"], "disclaimer": "참고 정보",
        "filtered": true, "usedFallback": false, "modelVersion": "rec_sllm_v2", "inferenceMs": 47038
      },
      "guidance": [
        "이미지 모델의 6종 분류 참고 결과이며 의학적 진단이 아닙니다. 분류 점수만으로 다른 질환을 배제할 수 없습니다.",
        "성분 추천은 화장품 수준의 보조 관리 정보입니다. 질환 확인과 치료는 피부과 전문의와 상담하세요."
      ],
      "error": null,
      "queuePosition": null,
      "estimatedWaitSec": null,
      "createdAt": "2026-10-16T09:12:33Z",
      "completedAt": "2026-10-16T09:13:21Z",
      "survey": { "gender": "female", "ageBand": "20s", "skinType": "dry", "concerns": ["sensitivity"] }
    }
    """

    static let queued = """
    {
      "analysisId": "01J9Z3K5V8Q2M4N6P8R0S2T4V6", "status": "QUEUED", "disease": \(diseaseAtopic),
      "recommendationStatus": null, "recommendation": null, "guidance": [], "error": null,
      "queuePosition": 2, "estimatedWaitSec": 90, "createdAt": "2026-10-16T09:12:33Z", "completedAt": null,
      "survey": { "gender": "male", "ageBand": "30s" }
    }
    """

    static func withheld(recommendationStatus: String) -> String {
        """
        {
          "analysisId": "01J9Z3K5V8Q2M4N6P8R0S2T4V6", "status": "WITHHELD",
          "disease": \(recommendationStatus == "uncertain" ? diseaseUncertain : diseaseNormal),
          "recommendationStatus": "\(recommendationStatus)", "recommendation": null,
          "guidance": ["이미지 모델의 6종 분류 참고 결과이며 의학적 진단이 아닙니다."], "error": null,
          "queuePosition": null, "estimatedWaitSec": null,
          "createdAt": "2026-10-16T09:12:33Z", "completedAt": "2026-10-16T09:12:34Z", "survey": { "gender": "female", "ageBand": "20s" }
        }
        """
    }

    static let failed = """
    {
      "analysisId": "01J9Z3K5V8Q2M4N6P8R0S2T4V6", "status": "FAILED", "disease": \(diseaseAtopic),
      "recommendationStatus": null, "recommendation": null, "guidance": [],
      "error": { "code": "E3002", "message": "추천 생성 시간이 초과됐어요." },
      "queuePosition": null, "estimatedWaitSec": null,
      "createdAt": "2026-10-16T09:12:33Z", "completedAt": "2026-10-16T09:14:43Z", "survey": { "gender": "female", "ageBand": "20s" }
    }
    """
}
