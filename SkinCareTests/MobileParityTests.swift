import Foundation
@testable import SkinCare
import Testing

private final class TestResources {}

struct MobileParityTests {
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
        #expect(result.recommendation?.routine?.map(\.time) == [.anytime, .anytime])
        let survey = try #require(result.survey)
        #expect(survey.captureView == "side")
        let next = survey.defaultsForNewAnalysis()
        #expect(next.captureView == nil && next.symptomProfile == nil)
        #expect(next.concerns == [.dryness] && next.skinType == .dry)
        let catalog = try #require(CareCatalog.bundled)
        #expect(catalog.care["여드름"] != nil && catalog.diet["general"] != nil)
        #expect(!catalog.matched(["Zinc Oxide"], avoiding: []).isEmpty)
        #expect(catalog.matched(["Zinc Oxide"], avoiding: ["GLYCERIN"]).isEmpty)
        #expect(catalog.matched(["Zinc Oxide"], avoiding: nil).isEmpty)
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
