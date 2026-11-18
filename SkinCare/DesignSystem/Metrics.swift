import SwiftUI

/// design.md §Spacing System (8pt 기준, 4pt 반단계)
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    /// 화면 좌우 여백
    static let screen: CGFloat = 20
}

/// design.md §Border Radius Scale. 버튼·칩·배지는 Capsule(rounded.full)을 쓴다.
enum Radius {
    /// 입력창, 작은 카드, 아코디언 행
    static let sm: CGFloat = 16
    /// 콘텐츠 카드
    static let md: CGFloat = 24
}

enum ControlSize {
    /// pill 버튼 높이 (터치 영역 44pt 이상)
    static let buttonHeight: CGFloat = 52
    static let minTouch: CGFloat = 44
}
