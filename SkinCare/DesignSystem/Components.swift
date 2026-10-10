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
            .background(style == .soft ? Color.canvasSoft : Color.canvas, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                if style == .outlined {
                    RoundedRectangle(cornerRadius: radius).strokeBorder(Color.hairlineSoft, lineWidth: 1)
                }
            }
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
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: ControlSize.buttonHeight)
        .background(Color.field, in: RoundedRectangle(cornerRadius: Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sm)
                .strokeBorder(Color.ink, lineWidth: isFocused ? 2 : 0)
        }
    }

    private var prompt: Text {
        Text(placeholder).foregroundStyle(.textFaint)
    }
}

// MARK: - 칩 · 배지

/// 고민 칩 등. 선택형이면 선택 시 ink 채움.
struct Chip: View {
    let title: String
    var isSelected = false

    var body: some View {
        Text(title)
            .appText(.label)
            .foregroundStyle(isSelected ? .onPrimary : .ink)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(isSelected ? Color.ink : Color.canvasSoft, in: Capsule())
    }
}

/// 선택 칩 버튼 (설문 선택지)
struct ChoiceChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appText(.bodySmall)
                .foregroundStyle(isSelected ? .onPrimary : .ink)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: ControlSize.minTouch)
                .background(isSelected ? Color.ink : Color.canvasSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// "데모 값" 배지 (FR-MEA-04). 실측처럼 보이면 안 되므로 눈에 띄게 ink 채움.
struct DemoBadge: View {
    var body: some View {
        Text("데모 값")
            .appText(.label)
            .foregroundStyle(.onPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(Color.ink, in: Capsule())
            .accessibilityLabel("데모 값, 실제 측정값이 아님")
    }
}

/// 등급 점 + 글자 라벨. 색만으로 구분하지 않는다 (화면 설계서 §5).
struct GradeTag: View {
    let grade: Grade

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Circle().fill(grade.color).frame(width: 8, height: 8)
            Text(grade.label).appText(.label).foregroundStyle(.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("등급 \(grade.label)")
    }
}

// MARK: - 안내 배너 · 면책

/// 안내 배너. design.md는 색 띠를 쓰지 않으므로 canvas-soft + 아이콘으로 표시한다.
struct NoticeBanner: View {
    let message: String
    var systemImage = "exclamationmark.circle"

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .foregroundStyle(.ink)
            Text(message)
                .appText(.bodySmall)
                .foregroundStyle(.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card(.soft, padding: Spacing.md, radius: Radius.sm)
    }
}

/// 면책 문구. 접거나 숨기지 않는다 (FR-REP-02).
struct DisclaimerText: View {
    var text: String?

    var body: some View {
        Text(text ?? AppCopy.disclaimer)
            .appText(.caption)
            .foregroundStyle(.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
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

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
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

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .appText(.title)
            .foregroundStyle(.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
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
