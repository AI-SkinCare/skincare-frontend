import SwiftUI

// design.md §Colors. 화면 코드에서 hex를 직접 쓰지 말고 이 토큰을 쓴다.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension ShapeStyle where Self == Color {
    // Brand & Accent
    /// 브랜드 색. 기본 CTA, 제목, 본문
    static var ink: Color { Color(hex: 0x141414) }
    static var inkSoft: Color { Color(hex: 0x262626) }
    /// 유일한 유채색 강조. 결정이 필요한 곳에만, CTA에는 쓰지 않는다
    static var accentBlue: Color { Color(hex: 0x0066FF) }
    static var onPrimary: Color { Color(hex: 0xFFFFFF) }

    // Surface
    static var canvas: Color { Color(hex: 0xFFFFFF) }
    static var canvasSoft: Color { Color(hex: 0xF3F3F3) }
    static var field: Color { Color(hex: 0xF0F0F0) }
    static var hairlineSoft: Color { Color(hex: 0xF0F0F0) }
    static var hairline: Color { Color(hex: 0xE0E0E0) }

    // Text
    static var textMuted: Color { Color(hex: 0x707070) }
    static var textFaint: Color { Color(hex: 0xADADAD) }

    // Semantic — 앱 추가 (design.md §App Additions). 등급 점·라벨·추이 화살표에만 쓴다.
    static var gradeGood: Color { Color(hex: 0x1E9E5A) }
    static var gradeNormal: Color { Color(hex: 0xE0A400) }
    static var gradeCare: Color { Color(hex: 0xEE6A1F) }
}

extension Grade {
    var color: Color {
        switch self {
        case .good: .gradeGood
        case .normal: .gradeNormal
        case .care: .gradeCare
        case .unknown: .textFaint
        }
    }
}
