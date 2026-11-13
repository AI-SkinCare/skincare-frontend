import Foundation
@testable import SkinCare
import Testing

struct ClassificationExplanationTests {
    private func decode(_ explanation: Any?) throws -> Disease {
        var body: [String: Any] = ["label": "아토피", "labelEn": "atopic", "confidence": 0.9,
                                  "uncertain": false, "probabilities": [:], "modelVersion": "test-model"]
        body["explanation"] = explanation
        return try JSONDecoder().decode(Disease.self, from: JSONSerialization.data(withJSONObject: body))
    }

    private func explanation(target: String = "아토피", version: String = "test-model",
                             available: Bool = true, colorType: UInt8 = 0) -> [String: Any] {
        // Metadata fixture only; the actual UI decoder must also decode PNG pixels.
        var bytes: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
                             0, 0, 1, 0, 0, 0, 1, 0, 8, colorType, 0, 0, 0, 0, 0, 0, 0]
        if !available { bytes = [] }
        return ["available": available, "method": "grad_cam", "targetLabel": target,
                "modelVersion": version, "heatmapPngBase64": Data(bytes).base64EncodedString()]
    }

    @Test func legacyAndMalformedOptionalDataKeepClassification() throws {
        #expect(try decode(nil).explanation == nil)
        let malformed = try decode(["available": "incorrect"])
        #expect(malformed.label == "아토피" && malformed.explanation == nil)
    }

    @Test func matchingMapCanBeDisplayed() throws {
        let disease = try decode(explanation())
        #expect(disease.explanation?.heatmapData(for: disease) != nil)
    }

    @Test func differentTargetOrModelNeverShowsASavedMap() throws {
        for value in [explanation(target: "건선"), explanation(version: "other-model")] {
            let disease = try decode(value)
            #expect(disease.explanation?.heatmapData(for: disease) == nil)
        }
    }

    @Test func unavailableColorOverlayAndOversizedDataAreNotDisplayed() throws {
        var oversized = explanation()
        oversized["heatmapPngBase64"] = String(repeating: "A", count: 120_001)
        for value in [explanation(available: false), explanation(colorType: 2), oversized] {
            let disease = try decode(value)
            #expect(disease.explanation?.heatmapData(for: disease) == nil)
        }
    }
}
