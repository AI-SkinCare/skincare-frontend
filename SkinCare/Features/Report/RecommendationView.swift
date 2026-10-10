import SwiftUI

/// SCR-09 추천 상세 (FR-REP-02). 면책 문구는 화면 맨 아래 고정, 접기·닫기 없음.
struct RecommendationView: View {
    let analysisID: String
    @Environment(\.api) private var api
    @State private var detail: AnalysisDetail?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let recommendation = detail?.recommendation, recommendation.status == .done {
                content(recommendation)
            } else if let errorMessage {
                ErrorStateView(message: errorMessage) { Task { await load() } }
            } else if detail != nil {
                ErrorStateView(message: "아직 추천이 준비되지 않았어요.") { Task { await load() } }
            } else {
                LoadingStateView()
            }
        }
        .background(Color.canvas)
        .navigationTitle("맞춤 추천")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            detail = try await api.send(AnalysisAPI.detail(id: analysisID))
            errorMessage = nil
        } catch {
            errorMessage = error.userMessage
        }
    }

    private func content(_ recommendation: Recommendation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionTitle(title: "피부 프로필")
                    ProfileChips(recommendation: recommendation)
                }
                IngredientsSection(ingredients: recommendation.ingredients ?? [])
                RoutineSection(steps: recommendation.routine ?? [])
                ReasoningSection(paragraphs: recommendation.reasoning ?? [])
                if let notes = recommendation.inputNotes, !notes.isEmpty {
                    AssumptionsSection(notes: notes)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            DisclaimerText(text: recommendation.disclaimer)
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.sm)
                .background(Color.canvas)
                .overlay(alignment: .top) { Rectangle().fill(Color.hairlineSoft).frame(height: 1) }
        }
    }
}

// MARK: - 추천 성분

private struct IngredientsSection: View {
    let ingredients: [Ingredient]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "추천 성분")
            if ingredients.isEmpty {
                Text("맞춤 성분을 찾지 못했어요. 추천 이유를 확인해 주세요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
            }
            ForEach(Array(ingredients.sorted { $0.priority < $1.priority }.enumerated()), id: \.element.id) { index, ingredient in
                HStack(alignment: .top, spacing: Spacing.md) {
                    Text("\(index + 1)")
                        .appText(.link)
                        .foregroundStyle(.onPrimary)
                        .frame(width: 28, height: 28)
                        .background(Color.ink, in: Circle())
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(ingredient.name).appText(.link).foregroundStyle(.ink)
                        if let purpose = ingredient.purpose, !purpose.isEmpty {
                            Text(purpose).appText(.bodySmall).foregroundStyle(.textMuted)
                        }
                    }
                }
                .card(.outlined, padding: Spacing.md, radius: Radius.sm)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - 관리 루틴

/// 아침/저녁 탭. daily는 두 탭 모두, weekly·anytime은 "주기 관리" 묶음 (SCR-09). 비어 있으면 숨김.
private struct RoutineSection: View {
    let steps: [RoutineStep]
    @State private var tab: RoutineTime = .morning

    private var morning: [RoutineStep] { steps.filter { $0.time == .morning || $0.time == .daily } }
    private var evening: [RoutineStep] { steps.filter { $0.time == .evening || $0.time == .daily } }
    private var periodic: [RoutineStep] { steps.filter { $0.time == .weekly || $0.time == .anytime } }

    var body: some View {
        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionTitle(title: "관리 루틴")
                Picker("시간대", selection: $tab) {
                    Text("아침").tag(RoutineTime.morning)
                    Text("저녁").tag(RoutineTime.evening)
                }
                .pickerStyle(.segmented)

                stepList(tab == .morning ? morning : evening)

                if !periodic.isEmpty {
                    Text("주기 관리")
                        .appText(.link)
                        .foregroundStyle(.ink)
                        .padding(.top, Spacing.xs)
                    stepList(periodic)
                }
            }
        }
    }

    @ViewBuilder
    private func stepList(_ items: [RoutineStep]) -> some View {
        if items.isEmpty {
            Text("이 시간대에는 따로 할 일이 없어요.")
                .appText(.bodySmall)
                .foregroundStyle(.textMuted)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(items.sorted { $0.step < $1.step }.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Text("\(index + 1)").appText(.link).foregroundStyle(.textMuted).frame(width: 20)
                        Text(item.action).appText(.body).foregroundStyle(.ink)
                    }
                }
            }
            .card(.soft, padding: Spacing.md, radius: Radius.sm)
        }
    }
}

// MARK: - 추천 이유

private struct ReasoningSection: View {
    let paragraphs: [String]
    private let titles = ["① 피부 상태와 원인", "② 성분을 고른 이유", "③ 사용법과 관리"]

    var body: some View {
        if !paragraphs.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionTitle(title: "추천 이유")
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        if index < titles.count {
                            Text(titles[index]).appText(.link).foregroundStyle(.ink)
                        }
                        ExpandableText(text: paragraph)
                    }
                }
            }
        }
    }
}

/// 긴 문단은 3줄까지 보이고 "더 보기"
private struct ExpandableText: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(text)
                .appText(.body)
                .foregroundStyle(.inkSoft)
                .lineLimit(isExpanded ? nil : 3)
            if text.count > 80 {
                Button(isExpanded ? "접기" : "더 보기") { withAnimation { isExpanded.toggle() } }
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
            }
        }
    }
}

// MARK: - 이렇게 가정했어요

private struct AssumptionsSection: View {
    let notes: [String]
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ForEach(notes, id: \.self) { note in
                    Text("· \(note)").appText(.bodySmall).foregroundStyle(.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.xs)
        } label: {
            Text("이렇게 가정했어요").appText(.link).foregroundStyle(.ink)
        }
        .tint(.ink)
        .card(.soft, padding: Spacing.md, radius: Radius.sm)
    }
}
