import SwiftUI

/// 사용자 회피 조건은 자동으로 지우거나 대체 성분으로 바꾸지 않는다.
struct AvoidIngredientsField: View {
    @Binding var ingredients: [String]?
    @State private var input = ""

    private var name: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canAdd: Bool {
        !name.isEmpty && name.count <= Survey.maxIngredientLength
            && (ingredients?.count ?? 0) < Survey.maxAvoidIngredients
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("피해야 하는 성분 (선택)").appText(.link)
            Text("알고 있는 성분명을 하나씩 입력해 주세요. 알레르기를 판별하는 기능은 아니에요.")
                .appText(.bodySmall).foregroundStyle(.textMuted)
            HStack(spacing: Spacing.xs) {
                AppTextField(placeholder: "예: 살리실산", text: $input).onSubmit(add)
                Button("추가", action: add).buttonStyle(.softPill).disabled(!canAdd)
            }
            if name.count > Survey.maxIngredientLength {
                Text("성분명은 100자 이내로 입력해 주세요.").appText(.caption)
            }
            Text("\(ingredients?.count ?? 0) / \(Survey.maxAvoidIngredients)").appText(.caption)
            ForEach(ingredients ?? [], id: \.self) { ingredient in
                HStack {
                    Text(ingredient).appText(.bodySmall)
                    Spacer()
                    Button("삭제") { ingredients?.removeAll { $0 == ingredient } }
                        .buttonStyle(.softPill)
                        .accessibilityLabel("회피 성분 \(ingredient) 삭제")
                }
            }
        }
    }

    private func add() {
        guard canAdd else { return }
        var values = ingredients ?? []
        if !values.contains(name) { values.append(name) }
        ingredients = values
        input = ""
    }
}
