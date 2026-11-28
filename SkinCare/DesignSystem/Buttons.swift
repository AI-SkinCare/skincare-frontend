import SwiftUI

// design.md §Buttons — 모든 버튼은 pill. 그림자 없음.

/// `button-primary`: ink 채움 + 흰 글자. 화면의 기본 CTA.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appText(.link)
            .foregroundStyle(isEnabled ? .onPrimary : .textMuted)
            .frame(maxWidth: .infinity, minHeight: ControlSize.buttonHeight)
            .padding(.horizontal, Spacing.md)
            // 비활성: canvas-soft 카드 위에서도 보이도록 hairline 채움
            .background(isEnabled ? Color.ink : Color.hairline, in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

/// `button-outline`: 흰 바탕 + hairline 테두리. 보조 동작.
struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appText(.link)
            .foregroundStyle(isEnabled ? .ink : .textFaint)
            .frame(maxWidth: .infinity, minHeight: ControlSize.buttonHeight)
            .padding(.horizontal, Spacing.md)
            .background(configuration.isPressed ? Color.canvasSoft : Color.canvas, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 1))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// `button-pill-soft`: canvas-soft 채움, 테두리 없음. 작은 보조 버튼.
struct SoftPillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appText(.link)
            .foregroundStyle(isEnabled ? .ink : .textFaint)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: ControlSize.minTouch)
            .background(Color.canvasSoft, in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
}

extension ButtonStyle where Self == SoftPillButtonStyle {
    static var softPill: SoftPillButtonStyle { SoftPillButtonStyle() }
}

/// 화면 하단 고정 CTA 영역 (스크롤 콘텐츠 위에 흰 바탕 + hairline)
struct BottomActionBar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: Spacing.sm) {
            content
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .background(Color.canvas)
        .overlay(alignment: .top) { Hairline() }
    }
}
