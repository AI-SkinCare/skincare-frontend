import Foundation
@testable import SkinCare
import Testing

struct GenerationTests {
    private func analysis(status: String, recommendationStatus: String, origin: String,
                          quality: String = "pass", recommendation: String = "{}") throws -> AnalysisView {
        let body = """
        {"analysisId":"test","status":"\(status)","recommendationStatus":"\(recommendationStatus)",
        "disease":{"label":"아토피","labelEn":"atopic","confidence":0.9,"uncertain":false,"probabilities":{}},
        "recommendation":\(recommendation),"guidance":["회피 조건에 맞는 근거가 없습니다."],
        "createdAt":"2026-11-12T00:00:00Z",
        "generation":{"origin":"\(origin)","qualityStatus":"\(quality)","qualityIssues":["evidence_no_eligible_claims"]}}
        """
        return try JSONCoding.decoder().decode(AnalysisView.self, from: Data(body.utf8))
    }

    @Test func qualityRejectedEndsPollingWithoutSuccessOrRetry() throws {
        let item = try analysis(status: "WITHHELD", recommendationStatus: "quality_rejected",
                                origin: "not_generated", recommendation: "null")
        #expect(!item.status.isInProgress)
        #expect(item.error == nil)
        #expect(!item.canDisplayRecommendation)
        #expect(item.generation?.origin == .notGenerated)
        #expect(item.recommendationStatus == .qualityRejected)
        #expect(AnalysisDisplay.withheldTitle(item.recommendationStatus).contains("기준"))
        #expect(!AnalysisDisplay.withheldTitle(item.recommendationStatus).contains("불확실"))
    }

    @Test func contradictoryCompletedDoesNotShowRecommendation() throws {
        let item = try analysis(status: "COMPLETED", recommendationStatus: "generated", origin: "not_generated")
        #expect(!item.canDisplayRecommendation)
        let withheld = try analysis(status: "COMPLETED", recommendationStatus: "generated", origin: "model", quality: "withheld")
        #expect(!withheld.canDisplayRecommendation)
    }

    @Test func sourceCardsHaveTheirOwnNotice() throws {
        let item = try analysis(status: "COMPLETED", recommendationStatus: "generated", origin: "source_cards")
        #expect(item.canDisplayRecommendation)
        #expect(item.generation?.sourceNotice?.contains("대체 안내") == true)
    }

    @Test func futureOriginDoesNotBreakDecoding() throws {
        let item = try analysis(status: "WITHHELD", recommendationStatus: "future_status", origin: "future_origin")
        #expect(item.generation?.origin == .unknown)
        #expect(item.recommendationStatus == .unknown)
        #expect(!item.canDisplayRecommendation)
    }

    @Test func avoidIngredientsAreActuallyEncoded() throws {
        var survey = Survey(gender: .female, ageBand: .thirties)
        survey.avoidIngredients = [" 살리실산 ", "레티놀"]
        let data = try JSONEncoder().encode(survey.sanitized())
        let decoded = try JSONDecoder().decode(Survey.self, from: data)
        #expect(decoded.avoidIngredients == ["살리실산", "레티놀"])
    }
}
