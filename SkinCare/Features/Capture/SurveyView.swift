import SwiftUI

/// SCR-06 설문 (FR-SUR-01). 1단계 필수, 2단계 선택.
struct SurveyView: View {
    @Environment(\.api) private var api
    @Environment(AppRouter.self) private var router
    @Environment(CaptureFlowModel.self) private var model
    @State private var step = 1

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                CaptureStepIndicator(current: 1)
                if step == 1 {
                    ScreenHeader(title: "기본 정보를 알려 주세요.", subtitle: "추천 성분을 고르는 데 쓰여요.")
                    SurveyStepOne(survey: $model.survey)
                        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                } else {
                    ScreenHeader(title: "생활 습관을 알려 주세요.", subtitle: "모두 선택 사항이에요. 알려 주시면 추천이 더 정확해져요.")
                    SurveyStepTwo(survey: $model.survey)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                if step == 1 {
                    Button("다음") { withAnimation(.easeInOut(duration: 0.25)) { step = 2 } }
                        .buttonStyle(.primary)
                        .disabled(!model.survey.hasRequiredFields)
                } else {
                    Button("측정 시작") { Task { await model.submit(api: api, router: router) } }
                        .buttonStyle(.primary)
                        .disabled(!model.canSubmit)
                }
            }
        }
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(step == 2)
        .toolbar {
            if step == 2 {
                ToolbarItem(placement: .topBarLeading) {
                    Button { withAnimation(.easeInOut(duration: 0.25)) { step = 1 } } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.ink)
                    .accessibilityLabel("이전 단계")
                }
            }
        }
        .captureCloseButton()
    }
}

// MARK: - 1단계: 성별(필수) · 연령대(필수) · 피부 타입

private struct SurveyStepOne: View {
    @Binding var survey: Survey

    private let fourColumns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            SurveyQuestion(title: "성별", isRequired: true) {
                HStack(spacing: Spacing.xs) {
                    ForEach(Gender.knownCases, id: \.self) { gender in
                        ChoiceChip(title: gender.label, isSelected: survey.gender == gender, isFullWidth: true) {
                            survey.gender = gender
                        }
                    }
                }
            }
            SurveyQuestion(title: "연령대", isRequired: true) {
                LazyVGrid(columns: fourColumns, spacing: Spacing.xs) {
                    ForEach(AgeBand.knownCases, id: \.self) { band in
                        ChoiceChip(title: band.label, isSelected: survey.ageBand == band, isFullWidth: true) {
                            survey.ageBand = band
                        }
                    }
                }
            }
            SurveyQuestion(title: "피부 타입") {
                FlowLayout {
                    ForEach(SkinType.knownCases, id: \.self) { type in
                        ChoiceChip(title: type.label, isSelected: survey.skinType == type) { survey.skinType = type }
                    }
                    ChoiceChip(title: "잘 모르겠어요", isSelected: survey.skinType == nil) { survey.skinType = nil }
                }
            }
        }
    }
}

// MARK: - 2단계: 수면 · 수분 · 자외선 · 스트레스 · 고민 · 사용 제품 · 추가 요청

private struct SurveyStepTwo: View {
    @Binding var survey: Survey
    @State private var productInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            SurveyQuestion(title: "하루 수면 시간") {
                if let hours = survey.sleepHours {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(hours)").appText(.heading4).foregroundStyle(.ink)
                                .contentTransition(.numericText())
                            Text("시간").appText(.body).foregroundStyle(.textMuted)
                            Spacer()
                            Button("지우기") { withAnimation { survey.sleepHours = nil } }
                                .appText(.bodySmall)
                                .foregroundStyle(.textMuted)
                        }
                        Slider(
                            value: Binding(get: { Double(hours) }, set: { survey.sleepHours = Int($0.rounded()) }),
                            in: Double(Survey.sleepHoursRange.lowerBound)...Double(Survey.sleepHoursRange.upperBound),
                            step: 1
                        )
                        .tint(.ink)
                        .accessibilityValue("\(hours)시간")
                    }
                    .card(.soft, padding: Spacing.md, radius: Radius.sm)
                } else {
                    Button {
                        withAnimation { survey.sleepHours = 7 }
                    } label: {
                        Label("입력하기", systemImage: "plus")
                    }
                    .buttonStyle(.softPill)
                }
            }

            levelQuestion("수분 섭취", keyPath: \.waterIntakeLevel)
            levelQuestion("자외선 노출", keyPath: \.sunExposureLevel)
            levelQuestion("스트레스", keyPath: \.stressLevel)

            SurveyQuestion(title: "피부 고민", caption: "\(survey.concerns?.count ?? 0) / \(Survey.maxConcerns)") {
                FlowLayout {
                    ForEach(Concern.knownCases, id: \.self) { concern in
                        let selected = survey.concerns?.contains(concern) == true
                        ChoiceChip(title: concern.displayLabel, isSelected: selected) { toggle(concern) }
                    }
                }
            }

            SurveyQuestion(title: "사용 중인 제품", caption: "\(survey.currentProducts?.count ?? 0) / \(Survey.maxProducts)") {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        AppTextField(placeholder: "예: 수분크림", text: $productInput)
                            .onSubmit(addProduct)
                        Button("추가", action: addProduct)
                            .buttonStyle(.softPill)
                            .disabled(!canAddProduct)
                    }
                    if let products = survey.currentProducts, !products.isEmpty {
                        FlowLayout {
                            ForEach(products, id: \.self) { product in
                                Button { withAnimation { survey.currentProducts?.removeAll { $0 == product } } } label: {
                                    HStack(spacing: 6) {
                                        Text(product)
                                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    }
                                    .appText(.label)
                                    .foregroundStyle(.ink)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(Color.canvasSoft, in: Capsule())
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityLabel("\(product) 삭제")
                            }
                        }
                    }
                }
            }

            SurveyQuestion(title: "추가로 알려 주실 내용", caption: "\(survey.note?.count ?? 0) / \(Survey.maxNoteLength)") {
                TextField("", text: noteBinding, prompt: Text("예: 여름에 번들거림이 심해요").foregroundStyle(.textFaint), axis: .vertical)
                    .lineLimit(3...6)
                    .appText(.body)
                    .padding(Spacing.md)
                    .background(Color.field, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }
        }
    }

    private func levelQuestion(_ title: String, keyPath: WritableKeyPath<Survey, Level?>) -> some View {
        SurveyQuestion(title: title) {
            HStack(spacing: Spacing.xs) {
                ForEach(Level.knownCases, id: \.self) { level in
                    ChoiceChip(title: level.label, isSelected: survey[keyPath: keyPath] == level, isFullWidth: true) {
                        // 다시 누르면 선택 해제
                        survey[keyPath: keyPath] = survey[keyPath: keyPath] == level ? nil : level
                    }
                }
            }
        }
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { survey.note ?? "" },
            set: { survey.note = String($0.prefix(Survey.maxNoteLength)) }
        )
    }

    private var canAddProduct: Bool {
        let trimmed = productInput.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && (survey.currentProducts?.count ?? 0) < Survey.maxProducts
    }

    private func addProduct() {
        guard canAddProduct else { return }
        let product = String(productInput.trimmingCharacters(in: .whitespaces).prefix(Survey.maxProductLength))
        var products = survey.currentProducts ?? []
        if !products.contains(product) { products.append(product) }
        withAnimation { survey.currentProducts = products }
        productInput = ""
    }

    private func toggle(_ concern: Concern) {
        var concerns = survey.concerns ?? []
        if let index = concerns.firstIndex(of: concern) {
            concerns.remove(at: index)
        } else if concerns.count < Survey.maxConcerns {
            concerns.append(concern)
        }
        survey.concerns = concerns
    }
}

private struct SurveyQuestion<Content: View>: View {
    let title: String
    var isRequired = false
    var caption: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(title).appText(.link).foregroundStyle(.ink)
                if isRequired {
                    Text("필수").appText(.caption).foregroundStyle(.textMuted)
                }
                Spacer()
                if let caption { Text(caption).appText(.caption).foregroundStyle(.textFaint) }
            }
            content
        }
    }
}
