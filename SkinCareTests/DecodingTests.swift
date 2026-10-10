import Foundation
import Testing
@testable import SkinCare

/// API 명세 §4.2 예시 응답을 그대로 디코딩한다.
struct DecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONCoding.decoder().decode(type, from: Data(json.utf8))
    }

    @Test("완료된 분석 상세")
    func analysisDetailDone() throws {
        let detail = try decode(AnalysisDetail.self, Fixtures.analysisDone)
        #expect(detail.status == .done)
        #expect(detail.measurement.overallScore == 63)
        #expect(detail.measurement.summary.map(\.metric) == [.moisture, .elasticity, .pigmentation, .pore])
        #expect(detail.measurement.summary[2].value == 38)
        #expect(detail.measurement.summary[2].score == 62)
        #expect(detail.measurement.byRoi.first?.roi == .forehead)
        #expect(detail.recommendation.skinType?.code == .combination)
        #expect(detail.recommendation.concerns?.map(\.code) == [.pore, .pigmentation])
        #expect(detail.recommendation.ingredients?.count == 3)
        #expect(detail.recommendation.routine?.first?.time == .morning)
        #expect(detail.recommendation.reasoning?.count == 3)
        #expect(detail.survey?.gender == .female)
        #expect(detail.survey?.ageBand == .twenties)
    }

    @Test("추천 대기 중이면 recommendation은 status만 온다")
    func analysisDetailPending() throws {
        let detail = try decode(AnalysisDetail.self, Fixtures.analysisPending)
        #expect(detail.status == .queued)
        #expect(detail.status.isInProgress)
        #expect(detail.recommendation.status == .pending)
        #expect(detail.recommendation.ingredients == nil)
        #expect(detail.queuePosition == 2)
        #expect(detail.measurement.isDemo)
        #expect(detail.measurement.byRoi.isEmpty)
    }

    @Test("모르는 열거형 값은 unknown으로 받는다")
    func unknownEnumValues() throws {
        let item = try decode(AnalysisListItem.self, """
        { "analysisId": "01J9", "createdAt": "2026-10-15T09:12:33.000Z", "status": "archived",
          "overallScore": 50, "isDemo": false, "concerns": ["pore", "freckles"] }
        """)
        #expect(item.status == .unknown)
        #expect(item.concerns == [.pore, .unknown])
    }

    @Test("날짜: 밀리초 있음·없음 모두 받는다")
    func dates() throws {
        let withMillis = try decode(SystemStatus.self, """
        { "aiAvailable": true, "queueLength": 0, "estimatedWaitSec": null, "checkedAt": "2026-10-15T09:12:00.123Z" }
        """)
        let withoutMillis = try decode(SystemStatus.self, """
        { "aiAvailable": false, "queueLength": 3, "estimatedWaitSec": 165, "checkedAt": "2026-10-15T09:12:00Z" }
        """)
        #expect(abs(withMillis.checkedAt.timeIntervalSince(withoutMillis.checkedAt) - 0.123) < 0.001)
        #expect(Formatting.dateTime(withoutMillis.checkedAt) == "2026.10.15 18:12")
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
}

enum Fixtures {
    static let analysisDone = """
    {
      "analysisId": "01J9Z3K5V8Q2M4N6P8R0S2T4V6",
      "status": "done",
      "createdAt": "2026-10-15T09:12:33Z",
      "completedAt": "2026-10-15T09:13:31Z",
      "deviceType": "smartphone",
      "queuePosition": null,
      "estimatedWaitSec": null,
      "measurement": {
        "isDemo": false, "confidence": 0.87, "calibrationApplied": true, "overallScore": 63,
        "summary": [
          { "metric": "moisture",     "value": 61, "score": 61, "grade": "normal" },
          { "metric": "elasticity",   "value": 74, "score": 74, "grade": "good" },
          { "metric": "pigmentation", "value": 38, "score": 62, "grade": "normal" },
          { "metric": "pore",         "value": 45, "score": 55, "grade": "normal" }
        ],
        "byRoi": [
          { "roi": "forehead", "moisture": 58, "elasticity": 71, "pigmentation": 35, "pore": 51, "overallScore": 61, "grade": "normal" },
          { "roi": "cheek_left", "moisture": 66, "elasticity": 76, "pigmentation": 41, "pore": 38, "overallScore": 66, "grade": "normal" }
        ],
        "modelVersion": "skin_reg_v1"
      },
      "recommendation": {
        "status": "done",
        "skinType": { "code": "combination", "label": "복합성" },
        "concerns": [
          { "code": "pore", "label": "모공" },
          { "code": "pigmentation", "label": "미백(색소침착/기미/칙칙함)" }
        ],
        "ingredients": [
          { "name": "나이아신아마이드", "purpose": "피지 분비와 모공 관리에 도움을 줄 수 있습니다.", "priority": 1 },
          { "name": "판테놀", "purpose": "피부 장벽을 지키는 데 도움을 줄 수 있습니다.", "priority": 2 },
          { "name": "알로에신", "purpose": null, "priority": 3 }
        ],
        "routine": [
          { "step": 1, "time": "morning", "action": "약산성 클렌저로 가볍게 세안합니다." },
          { "step": 2, "time": "morning", "action": "자외선 차단제를 바릅니다." },
          { "step": 3, "time": "evening", "action": "나이아신아마이드 세럼을 바릅니다." }
        ],
        "reasoning": ["첫째 문단입니다.", "둘째 문단입니다.", "셋째 문단입니다."],
        "answer": "복합성 피부에 모공과 톤이 고민이라면 가벼운 보습이 좋아요. 자외선 차단도 챙겨 주세요. 세 번째 문장입니다.",
        "inputNotes": ["나이는 연령대(20s) 중간값 25세로 추정"],
        "disclaimer": "본 결과는 참고용 정보이며 의학적 진단이나 치료를 대신하지 않습니다. 피부 이상이 지속되면 피부과 전문의와 상담하세요.",
        "filtered": false,
        "usedFallback": false,
        "modelVersion": "rec_sllm_v2"
      },
      "survey": {
        "gender": "female", "ageBand": "20s", "skinType": "combination", "sleepHours": 6,
        "waterIntakeLevel": "low", "sunExposureLevel": "high", "stressLevel": "medium",
        "concerns": ["pore", "pigmentation"], "currentProducts": ["토너", "수분크림"], "note": "여름에 번들거림이 심해요"
      },
      "error": null
    }
    """

    static let analysisPending = """
    {
      "analysisId": "01J9Z3K5V8Q2M4N6P8R0S2T4V6",
      "status": "queued",
      "createdAt": "2026-10-15T09:12:33Z",
      "completedAt": null,
      "deviceType": "smartphone",
      "queuePosition": 2,
      "estimatedWaitSec": 110,
      "measurement": {
        "isDemo": true, "confidence": 0.5, "calibrationApplied": false, "overallScore": 50,
        "summary": [ { "metric": "moisture", "value": 50, "score": 50, "grade": "normal" } ],
        "byRoi": [],
        "modelVersion": "stub"
      },
      "recommendation": { "status": "pending" },
      "survey": { "gender": "male", "ageBand": "30s" },
      "error": null
    }
    """
}
