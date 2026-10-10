import SwiftUI

/// design.md §Typography를 Pretendard로 옮긴 토큰 (패치 §2 §5).
/// 굵기 매핑: 652 → Bold, 600 → SemiBold, 456 → Medium, 300 → Light. 크기는 pt, Dynamic Type을 따른다.
enum AppTextStyle {
    case heading1   // 56 / Bold / 1.0 — 종합 점수 숫자
    case heading3   // 32 / Bold / 1.13 — 인증 화면 제목
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
        case .heading1: ("Pretendard-Bold", 56, 1.0, .largeTitle)
        case .heading3: ("Pretendard-Bold", 32, 1.13, .largeTitle)
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

extension View {
    /// 글꼴 + 행간. letter-spacing은 쓰지 않는다 (design.md).
    func appText(_ style: AppTextStyle) -> some View {
        let spec = style.spec
        return font(style.font)
            .lineSpacing(max(0, (spec.lineHeight - 1) * spec.size))
    }
}
