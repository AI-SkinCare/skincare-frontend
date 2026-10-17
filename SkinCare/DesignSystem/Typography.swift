import SwiftUI

/// design.md §Typography를 Pretendard로 옮긴 토큰 (패치 §2 §5).
/// 굵기 매핑: 652 → Bold, 600 → SemiBold, 456 → Medium, 300 → Light. 크기는 pt, Dynamic Type을 따른다.
enum AppTextStyle {
    case display    // 44 / Bold / 1.1 — 결과 화면 분류 라벨
    case tabTitle   // 30 / Bold / 1.2 — 탭 루트 제목 (홈·이력·마이)
    case heading3   // 28 / Bold / 1.2 — 화면 대표 제목 (웹 32px를 모바일·한글 폭에 맞춤)
    case heading4   // 24 / Bold / 1.25 — 화면 제목
    case title      // 20 / SemiBold / 1.3 — 섹션 제목, 강조 행
    case bodyLarge  // 20 / Light / 1.38 — 리드 문단
    case body       // 16 / Medium / 1.38
    case bodySmall  // 14 / Medium / 1.43 — 보조 문구
    case link       // 16 / SemiBold / 1.38 — 버튼 라벨
    case label      // 12 / SemiBold / 1.33 — 배지·칩
    case caption    // 12 / Medium / 1.33 — 메타 정보

    fileprivate var spec: (font: String, size: CGFloat, lineHeight: CGFloat, relativeTo: Font.TextStyle) {
        switch self {
        case .display: ("Pretendard-Bold", 44, 1.1, .largeTitle)
        case .tabTitle: ("Pretendard-Bold", 30, 1.2, .largeTitle)
        case .heading3: ("Pretendard-Bold", 28, 1.2, .largeTitle)
        case .heading4: ("Pretendard-Bold", 24, 1.25, .title)
        case .title: ("Pretendard-SemiBold", 20, 1.3, .title3)
        case .bodyLarge: ("Pretendard-Light", 20, 1.38, .title3)
        case .body: ("Pretendard-Medium", 16, 1.38, .body)
        case .bodySmall: ("Pretendard-Medium", 14, 1.43, .subheadline)
        case .link: ("Pretendard-SemiBold", 16, 1.38, .body)
        case .label: ("Pretendard-SemiBold", 12, 1.33, .caption)
        case .caption: ("Pretendard-Medium", 12, 1.33, .caption)
        }
    }

    var font: Font {
        Font.custom(spec.font, size: spec.size, relativeTo: spec.relativeTo)
    }
}

extension Font {
    enum PretendardWeight: String {
        case light = "Pretendard-Light", regular = "Pretendard-Regular", medium = "Pretendard-Medium"
        case semibold = "Pretendard-SemiBold", bold = "Pretendard-Bold"
    }

    /// 크기가 레이아웃에 비례해야 하는 곳(타일 안 라벨 등)에서만 쓴다. 그 밖에는 `appText(_:)` 토큰을 쓴다.
    static func pretendard(_ weight: PretendardWeight, size: CGFloat) -> Font {
        .custom(weight.rawValue, size: size)
    }
}

extension View {
    /// 글꼴 + 행간. letter-spacing은 쓰지 않는다 (design.md).
    func appText(_ style: AppTextStyle) -> some View {
        let spec = style.spec
        return font(style.font)
            .lineSpacing(max(0, (spec.lineHeight - 1) * spec.size))
    }
}
