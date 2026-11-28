import Foundation
@testable import SkinCare
import Testing

/// 설문은 모든 항목에 답해야 넘어간다. "잘 모르겠어요"도 답으로 치고, 그 값은 서버로 보내지 않는다.
struct SurveyCompletionTests {
    private var basic: Survey {
        var survey = Survey()
        survey.gender = .female
        survey.ageBand = .twenties
        return survey
    }

    @Test("1단계: 성별·연령대만 고르면 피부 타입이 남아서 못 넘어간다")
    func stepOneNeedsSkinType() {
        #expect(!basic.isStepOneComplete(unsure: []))
        #expect(basic.isStepOneComplete(unsure: [.skinType]))
        var withType = basic
        withType.skinType = .oily
        #expect(withType.isStepOneComplete(unsure: []))
    }

    @Test("1단계: 피부 타입을 몰라도 성별·연령대는 꼭 필요")
    func stepOneRequiresBasics() {
        #expect(!Survey().isStepOneComplete(unsure: [.skinType]))
    }

    @Test("2단계: 하나라도 비면 못 넘어가고, 모두 모르겠어요면 넘어간다")
    func stepTwo() {
        #expect(!basic.isStepTwoComplete(unsure: []))
        let allUnsure = Set(SurveyItem.stepTwo)
        #expect(basic.isStepTwoComplete(unsure: allUnsure))
        #expect(!basic.isStepTwoComplete(unsure: allUnsure.subtracting([.stress])))
    }

    @Test("2단계: 값으로 답한 경우")
    func stepTwoValues() {
        var survey = basic
        survey.sleepHours = 7
        survey.waterIntakeLevel = .medium
        survey.sunExposureLevel = .low
        survey.stressLevel = .high
        survey.concerns = [.pore]
        survey.currentProducts = ["수분크림"]
        #expect(survey.isStepTwoComplete(unsure: []))
    }

    @Test("잘 모르겠어요를 고르면 값을 비워서 보내지 않는다")
    func clearRemovesValue() throws {
        var survey = basic
        survey.stressLevel = .high
        survey.clear(.stress)
        #expect(survey.stressLevel == nil)
        let json = try #require(String(bytes: JSONEncoder().encode(survey.sanitized()), encoding: .utf8))
        #expect(!json.contains("stressLevel"))
    }
}
