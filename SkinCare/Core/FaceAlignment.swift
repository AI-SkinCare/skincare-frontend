import CoreGraphics

/// 얼굴이 타원 가이드 안에 제대로 들어왔는지 판정한다. 카메라(실시간)와 앨범(위치 맞추기)이 같이 쓴다.
/// 얼굴 사각형과 가이드는 **같은 좌표계**면 된다 (화면 좌표, 카메라 메타데이터 좌표 모두 가능).
/// 카메라 메타데이터 좌표는 화면과 90° 돌아가 있어도 판정이 같도록 회전에 영향받지 않는 값만 쓴다.
enum FaceAlignment {
    struct Face: Equatable {
        let rect: CGRect
        /// 좌우로 고개를 돌린 각도(도). 모르면 nil
        var yaw: Double?
        /// 기울인 각도(도). 모르면 nil
        var roll: Double?
    }

    enum Result: Equatable {
        case aligned
        case noFace
        case multipleFaces
        case tooFar
        case tooClose
        case offCenter
        case notFrontal
        case notSide

        var isAligned: Bool { self == .aligned }

        var message: String {
            switch self {
            case .aligned: "좋아요. 그대로 찍어 주세요"
            case .noFace: "얼굴을 원 안에 맞춰 주세요"
            case .multipleFaces: "한 사람만 나오게 해 주세요"
            case .tooFar: "조금 더 가까이 와 주세요"
            case .tooClose: "조금 뒤로 물러나 주세요"
            case .offCenter: "얼굴을 원 가운데로 맞춰 주세요"
            case .notFrontal: "정면을 봐 주세요"
            case .notSide: "한쪽 볼과 코 윤곽이 보이게 얼굴을 돌려 주세요"
            }
        }
    }

    /// 얼굴 크기 = sqrt(얼굴 넓이 / 가이드 넓이). 얼굴 감지 사각형은 이마~턱이라 가이드(머리 전체)보다 작다.
    static let minSizeRatio = 0.42
    static let maxSizeRatio = 0.9
    /// 얼굴 중심이 가이드 중심에서 벗어날 수 있는 정도 (가이드 반지름 대비, 타원 거리)
    static let maxCenterOffset = 0.28
    /// 얼굴 사각형이 가이드 밖으로 나가도 되는 여유 (가이드 크기 대비)
    static let overflowTolerance = 0.12
    static let maxYaw = 20.0
    static let maxRoll = 15.0

    static func evaluate(faces: [Face], guide: CGRect, side: Bool = false) -> Result {
        guard guide.width > 0, guide.height > 0 else { return .noFace }
        guard let face = faces.first else { return .noFace }
        guard faces.count == 1 else { return .multipleFaces }

        if let yaw = face.yaw {
            let turn = abs(yaw.truncatingRemainder(dividingBy: 360))
            let angle = min(turn, 360 - turn)
            if side && angle < maxYaw { return .notSide }
            if !side && angle > maxYaw { return .notFrontal }
        }
        if let roll = face.roll, abs(normalized(roll)) > maxRoll { return .notFrontal }

        let sizeRatio = ((face.rect.width * face.rect.height) / (guide.width * guide.height)).squareRoot()
        if sizeRatio < minSizeRatio { return .tooFar }
        if sizeRatio > maxSizeRatio { return .tooClose }

        let offsetX = (face.rect.midX - guide.midX) / (guide.width / 2)
        let offsetY = (face.rect.midY - guide.midY) / (guide.height / 2)
        if (offsetX * offsetX + offsetY * offsetY).squareRoot() > maxCenterOffset { return .offCenter }

        let allowed = guide.insetBy(dx: -guide.width * overflowTolerance, dy: -guide.height * overflowTolerance)
        if !allowed.contains(face.rect) { return .offCenter }

        return .aligned
    }

    /// 카메라 roll은 0–360으로 오므로 -180–180으로 바꾼다. 세로 화면에서 정면이면 0 또는 90/270 근처라 90 단위로 접는다.
    private static func normalized(_ roll: Double) -> Double {
        var value = roll.truncatingRemainder(dividingBy: 90)
        if value > 45 { value -= 90 }
        if value < -45 { value += 90 }
        return value
    }
}
