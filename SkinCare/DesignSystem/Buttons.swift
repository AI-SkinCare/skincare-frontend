import SwiftUI

// design.md §Buttons — 모든 버튼은 pill. 그림자 없음.

/// `button-primary`: ink 채움 + 흰 글자. 화면의 기본 CTA.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appText(.link)
            .foregroundStyle(isEnabled ? .onPrimary : .textFaint)
            .frame(maxWidth: .infinity, minHeight: ControlSize.buttonHeight)
            .padding(.horizontal, Spacing.md)
            .background(isEnabled ? Color.ink : Color.canvasSoft, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
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
            .background(Color.canvas, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// `button-pill-soft`: canvas-soft 채움, 테두리 없음. 작은 보조 링크 버튼.
struct SoftPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appText(.link)
            .foregroundStyle(.ink)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: ControlSize.minTouch)
            .background(Color.canvasSoft, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
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
