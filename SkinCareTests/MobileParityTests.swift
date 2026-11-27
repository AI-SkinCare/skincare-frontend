import Foundation
@testable import SkinCare
import Testing

private final class TestResources {}

struct MobileParityTests {
    @Test(arguments: ["front", "side"])
    func selectedAngleIsSentInThePhotoUpload(_ angle: String) {
        var answers = Survey()
        answers.captureView = angle
        let isSide = angle == "side"
        let bytes: [UInt8] = isSide ? [0x89, 0x50, 0x4e, 0x47] : [0xff, 0xd8, 0xff]
        let request = AnalysisAPI.submit(image: Data(bytes), format: isSide ? .png : .jpeg, survey: answers)
        guard case let .multipart(form) = request.body else {
            Issue.record("Expected a multipart photo upload")
            return
        }
        let payload = String(decoding: form.encoded(), as: UTF8.self)
        #expect(payload.contains("name=\"survey\""))
        #expect(payload.contains("\"captureView\":\"\(angle)\""))
        #expect(payload.contains(isSide ? "Content-Type: image/png" : "Content-Type: image/jpeg"))
    }

    @Test func sideResultAndFreshSurvey() throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: TestResources.self)
        #endif
        let url = try #require(bundle.url(forResource: "parity-side-result", withExtension: "json"))
        let result = try JSONCoding.decoder().decode(AnalysisView.self, from: Data(contentsOf: url))
        #expect(result.canDisplayRecommendation)
        #expect(result.disease.modelVersion == "dinov2_linear_875acf74c4")
        #expect(result.disease.confidencePercent == "79%")
        #expect(result.recommendation?.ingredients?.map(\.name) == ["글리세린", "세라마이드"])
        let evidence = try #require(result.recommendation?.ingredients?.first?.evidence)
        #expect(evidence.canDisplay && evidence.claimId == "E_GLY_MOIST")
        #expect(evidence.usageConditions.contains("무향의 완제품 보습제를 제품 표시대로 사용한다."))
        #expect(evidence.sources.contains { $0.webURL?.absoluteString == "https://pubmed.ncbi.nlm.nih.gov/18025807/" })
        #expect(result.recommendation?.ingredients?.last?.evidence == nil)
        #expect(result.recommendation?.routine?.map(\.time) == [.anytime, .anytime])
        let survey = try #require(result.survey)
        #expect(survey.captureView == "side")
        let next = survey.defaultsForNewAnalysis()
        #expect(next.captureView == nil && next.symptomProfile == nil)
        #expect(next.concerns == [.dryness] && next.skinType == .dry)
        let catalog = try #require(CareCatalog.bundled)
        #expect(catalog.generalSources[catalog.key("ceramide NP")]?.webURL?.lastPathComponent == "33984185")
        #expect(catalog.matched(["글리세롤"], avoiding: []).first?.labelNames["글리세린"] == "glycerin")
        #expect(catalog.care["여드름"] != nil && catalog.diet["general"] != nil)
        #expect(!catalog.matched(["Zinc Oxide"], avoiding: []).isEmpty)
        #expect(catalog.matched(["Zinc Oxide"], avoiding: ["GLYCERIN"]).isEmpty)
        #expect(catalog.matched(["Zinc Oxide"], avoiding: nil).isEmpty)
    }

    @Test func malformedEvidenceStillDisplaysTheIngredient() throws {
        let raw = Data(#"{"name":"글리세린","priority":1,"evidence":{"usageConditions":"wrong"}}"#.utf8)
        let ingredient = try JSONDecoder().decode(Ingredient.self, from: raw)
        #expect(ingredient.name == "글리세린" && ingredient.evidence == nil)
        for url in ["file:///tmp/file", "http://example.org", "https://user@example.org", "/relative"] {
            #expect(EvidenceSource(title: "원문", url: url, summary: nil).webURL == nil)
        }
    }

    @Test func bothServersMustBeReadyForSideUpload() throws {
        for (ai, side, allowed) in [(true, nil as Bool?, false), (true, false, false),
                                    (false, true, false), (true, true, true)] {
            var status: [String: Any] = ["aiAvailable": ai, "queueLength": 0]
            if let side { status["sideCaptureAvailable"] = side }
            let data = try JSONSerialization.data(withJSONObject: status)
            let value = try JSONDecoder().decode(SystemStatus.self, from: data)
            #expect(value.canAnalyzeSide == allowed)
        }
    }
}
