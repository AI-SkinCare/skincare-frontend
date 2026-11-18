import CoreGraphics
@testable import SkinCare
import Testing

/// 얼굴이 가이드 안에 들어왔는지 판정 (카메라·앨범 공통)
struct FaceAlignmentTests {
    /// 300×400 가이드 (화면 좌표 예시)
    private let guide = CGRect(x: 50, y: 100, width: 300, height: 400)

    /// 가이드 중심 기준으로 크기 비율·이동을 준 얼굴
    private func face(sizeRatio: Double, shiftX: Double = 0, shiftY: Double = 0, yaw: Double? = nil, roll: Double? = nil)
        -> FaceAlignment.Face {
        let width = guide.width * sizeRatio
        let height = guide.height * sizeRatio
        let rect = CGRect(x: guide.midX - width / 2 + shiftX, y: guide.midY - height / 2 + shiftY, width: width, height: height)
        return FaceAlignment.Face(rect: rect, yaw: yaw, roll: roll)
    }

    @Test("가운데 적당한 크기면 통과")
    func aligned() {
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.6)], guide: guide) == .aligned)
    }

    @Test("얼굴 없음 · 여러 명")
    func faceCount() {
        #expect(FaceAlignment.evaluate(faces: [], guide: guide) == .noFace)
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.6), face(sizeRatio: 0.5)], guide: guide) == .multipleFaces)
    }

    @Test("너무 멀거나 가까움")
    func size() {
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.3)], guide: guide) == .tooFar)
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.95)], guide: guide) == .tooClose)
    }

    @Test("가운데에서 벗어남")
    func offCenter() {
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.6, shiftX: 80)], guide: guide) == .offCenter)
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.6, shiftY: -120)], guide: guide) == .offCenter)
        // 조금 벗어난 건 괜찮다
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.6, shiftX: 20)], guide: guide) == .aligned)
    }

    @Test("고개를 돌리거나 기울이면 정면 아님")
    func frontal() {
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.6, yaw: 45)], guide: guide) == .notFrontal)
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.6, roll: 30)], guide: guide) == .notFrontal)
        // 카메라 roll은 세로 화면 정면에서 90·270 근처로 온다
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.6, roll: 90)], guide: guide) == .aligned)
        #expect(FaceAlignment.evaluate(faces: [face(sizeRatio: 0.6, roll: 275)], guide: guide) == .aligned)
    }

    @Test("좌표계가 90° 돌아가도(카메라 메타데이터) 같은 판정")
    func rotationInvariant() {
        let rotatedGuide = CGRect(x: guide.minY, y: guide.minX, width: guide.height, height: guide.width)
        let original = face(sizeRatio: 0.6, shiftX: 20)
        let rotated = FaceAlignment.Face(
            rect: CGRect(x: original.rect.minY, y: original.rect.minX, width: original.rect.height, height: original.rect.width)
        )
        #expect(FaceAlignment.evaluate(faces: [rotated], guide: rotatedGuide)
            == FaceAlignment.evaluate(faces: [original], guide: guide))
    }
}
