import SwiftUI

// MARK: - 카드 (design.md §Cards & Containers)

enum CardStyle {
    /// 흰 바탕 + hairline-soft 테두리 (Level 2)
    case outlined
    /// canvas-soft 채움, 테두리 없음 (Level 1) — 강조 카드
    case soft
}

extension View {
    func card(_ style: CardStyle = .outlined, padding: CGFloat = Spacing.lg, radius: CGFloat = Radius.md) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style == .soft ? Color.canvasSoft : Color.canvas, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if style == .outlined {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.hairlineSoft, lineWidth: 1)
                }
            }
    }
}

// MARK: - 브랜드

/// 앱 아이콘 squircle (design.md `app-icon-squircle`, 30% radius)
struct BrandMark: View {
    var size: CGFloat = 56

    var body: some View {
        Image("BrandMark")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).strokeBorder(Color.hairlineSoft, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// 화면 상단 제목 + 가벼운 부제. 제목은 마침표로 끝나는 문장 (design.md §Principles).
struct ScreenHeader: View {
    let title: String
    var subtitle: String?
    var eyebrow: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let eyebrow {
                Text(eyebrow).appText(.bodySmall).foregroundStyle(.textMuted)
            }
            Text(title)
                .appText(.heading3)
                .foregroundStyle(.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .appText(.bodyLarge)
                    .foregroundStyle(.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct SectionTitle: View {
    let title: String
    var caption: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .appText(.title)
                .foregroundStyle(.ink)
            Spacer()
            if let caption {
                Text(caption).appText(.caption).foregroundStyle(.textMuted)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 입력창 (design.md §Inputs & Forms)

/// field 채움, 평소 테두리 없음, 포커스 시 2pt ink 링.
struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: prompt)
            } else {
                TextField("", text: $text, prompt: prompt)
                    .keyboardType(keyboard)
            }
        }
        .textContentType(contentType)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .appText(.body)
        .foregroundStyle(.ink)
        .focused($isFocused)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: ControlSize.buttonHeight)
        .background(Color.field, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(Color.ink, lineWidth: isFocused ? 2 : 0)
        }
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var prompt: Text {
        Text(placeholder).foregroundStyle(.textFaint)
    }
}

// MARK: - 칩 · 배지

/// 고민 칩 등 표시용 칩
struct Chip: View {
    let title: String
    var isSelected = false
    /// canvas-soft 카드 위에 놓일 때 true — 배경을 흰색으로 바꿔 구분되게 한다
    var isOnSoftSurface = false

    var body: some View {
        Text(title)
            .appText(.label)
            .foregroundStyle(isSelected ? .onPrimary : .ink)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(isSelected ? Color.ink : isOnSoftSurface ? Color.canvas : Color.canvasSoft, in: Capsule())
    }
}

/// 선택 칩 버튼 (설문 선택지)
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    var isFullWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appText(isSelected ? .link : .body)
                .foregroundStyle(isSelected ? .onPrimary : .ink)
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: ControlSize.minTouch)
                .background(isSelected ? Color.ink : Color.canvasSoft, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 눌림 효과만 주는 버튼 스타일
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 점수 막대

/// 0–100 막대
struct ProgressBar: View {
    let value: Int
    var color: Color = .ink
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.canvasSoft)
                Capsule().fill(color)
                    .frame(width: max(height, proxy.size.width * CGFloat(min(max(value, 0), 100)) / 100))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - 세그먼트 (design.md `segmented-control`)

/// canvas-soft 트랙 + 흰 pill 활성 옵션. 디자인 시스템에서 유일하게 그림자를 쓰는 요소.
struct PillSegmentedControl<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .appText(isSelected ? .link : .body)
                        .foregroundStyle(isSelected ? .ink : .textMuted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.canvas)
                                    .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.canvasSoft, in: Capsule())
    }
}

// MARK: - 리스트 행

/// 설정·메뉴 행. 카드 안에서 hairline으로 구분한다.
struct MenuRow<Trailing: View>: View {
    let title: String
    var systemImage: String?
    var role: ButtonRole?
    let action: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(role == .destructive ? .negative : .ink)
                        .frame(width: 24)
                }
                Text(title)
                    .appText(.body)
                    .foregroundStyle(role == .destructive ? .negative : .ink)
                Spacer()
                trailing
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension MenuRow where Trailing == EmptyView {
    init(title: String, systemImage: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(title: title, systemImage: systemImage, role: role, action: action) { EmptyView() }
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Color.hairlineSoft).frame(height: 1)
    }
}

// MARK: - 안내 배너 · 면책

/// 안내 배너. design.md는 색 띠를 쓰지 않으므로 canvas-soft + 아이콘으로 표시한다.
struct NoticeBanner: View {
    let message: String
    var systemImage = "exclamationmark.circle"

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.ink)
                .padding(.top, 1)
            Text(message)
                .appText(.bodySmall)
                .foregroundStyle(.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(.soft, padding: Spacing.md, radius: Radius.sm)
        .accessibilityElement(children: .combine)
    }
}

/// 면책 문구. 접거나 숨기지 않는다 (FR-REP-02).
struct DisclaimerText: View {
    var text: String?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .medium))
                .padding(.top, 2)
            Text(text ?? AppCopy.disclaimer)
                .appText(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 상태 화면

struct LoadingStateView: View {
    var body: some View {
        ProgressView()
            .tint(.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.ink)
                .frame(width: 64, height: 64)
                .background(Color.canvasSoft, in: Circle())
            Text(title).appText(.title).foregroundStyle(.ink)
            if let message {
                Text(message).appText(.bodySmall).foregroundStyle(.textMuted).multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.ink)
                .frame(width: 56, height: 56)
                .background(Color.canvasSoft, in: Circle())
            Text(message)
                .appText(.body)
                .foregroundStyle(.textMuted)
                .multilineTextAlignment(.center)
            Button("다시 시도", action: retry)
                .buttonStyle(.softPill)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 줄 바꿈되는 가로 배치 (칩 목록용)
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(proposal: proposal, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Row {
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            if !row.items.isEmpty, row.width + spacing + size.width > maxWidth {
                let nextY = row.y + row.height + spacing
                rows.append(Row(y: nextY))
                row = rows[rows.count - 1]
            }
            let x = row.items.isEmpty ? 0 : row.width + spacing
            row.items.append((index, x, size))
            row.width = x + size.width
            row.height = max(row.height, size.height)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

// MARK: - 탭 제목

/// 탭 루트 화면(홈·이력·마이) 상단 제목. 시스템 큰 제목 대신 직접 그려 Pretendard로 통일한다.
struct TabHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .appText(.tabTitle)
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
        .frame(minHeight: 52)
    }
}

extension TabHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}
