import SwiftUI

/// 카메라·앨범 공통 얼굴 타원 가이드
enum FaceGuideLayout {
    /// 화면 너비 68%, 세로 4:3, 위 안내 문구와 아래 버튼 사이 가운데. 전체 화면(안전 영역 무시) 좌표.
    static func guideRect(in size: CGSize) -> CGRect {
        let width = size.width * 0.68
        let height = width * 4 / 3
        return CGRect(x: (size.width - width) / 2, y: size.height * 0.46 - height / 2, width: width, height: height)
    }
}

/// 타원 바깥을 어둡게 하고 타원 테두리를 그린다. 맞으면 실선, 아니면 점선.
struct FaceGuideOverlay: View {
    let guide: CGRect
    var isAligned = false

    var body: some View {
        ZStack {
            Path { path in
                path.addRect(CGRect(x: -1000, y: -1000, width: 4000, height: 4000))
                path.addEllipse(in: guide)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            Ellipse()
                .stroke(.white.opacity(isAligned ? 1 : 0.85),
                        style: StrokeStyle(lineWidth: isAligned ? 4 : 2.5, dash: isAligned ? [] : [10, 8]))
                .frame(width: guide.width, height: guide.height)
                .position(x: guide.midX, y: guide.midY)
                .animation(.easeOut(duration: 0.2), value: isAligned)

            if isAligned {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.ink)
                    .frame(width: 32, height: 32)
                    .background(.white, in: Circle())
                    .position(x: guide.midX, y: guide.maxY)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAligned)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 가이드 위쪽 안내 문구 (현재 판정 이유를 보여준다)
struct FaceGuideMessage: View {
    let result: FaceAlignment.Result

    var body: some View {
        Text(result.message)
            .appText(.title)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(.black.opacity(result.isAligned ? 0 : 0.25), in: Capsule())
            .contentTransition(.opacity)
            .animation(.easeOut(duration: 0.2), value: result)
            .accessibilityLabel(result.message)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// 원형 셔터 버튼. 얼굴이 맞을 때만 켜진다.
struct ShutterButton: View {
    let isEnabled: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(.white.opacity(isEnabled ? 1 : 0.4), lineWidth: 4).frame(width: 80, height: 80)
                Circle().fill(.white.opacity(isEnabled ? 1 : 0.3)).frame(width: 64, height: 64)
                    .scaleEffect(isBusy ? 0.85 : 1)
                if isBusy { ProgressView().tint(.ink) }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isBusy)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
        .accessibilityLabel("촬영")
        .accessibilityHint(isEnabled ? "" : "얼굴을 원 안에 맞추면 촬영할 수 있어요")
    }
}
