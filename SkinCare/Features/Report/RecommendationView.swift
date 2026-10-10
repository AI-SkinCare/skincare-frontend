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
        .toolbar(.hidden, for: .tabBar)
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
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                SummaryHeader(recommendation: recommendation)
                IngredientsSection(ingredients: recommendation.ingredients ?? [])
                RoutineSection(steps: recommendation.routine ?? [])
                ReasoningSection(paragraphs: recommendation.reasoning ?? [])
                if let notes = recommendation.inputNotes, !notes.isEmpty {
                    AssumptionsSection(notes: notes)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .safeAreaInset(edge: .bottom) {
            DisclaimerText(text: recommendation.disclaimer)
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.sm)
                .background(Color.canvas)
                .overlay(alignment: .top) { Hairline() }
        }
    }
}

// MARK: - 요약 + 피부 프로필

private struct SummaryHeader: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ProfileChips(recommendation: recommendation)
            if let answer = recommendation.answer, !answer.isEmpty {
                Text(answer)
                    .appText(.bodyLarge)
                    .foregroundStyle(.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 추천 성분

private struct IngredientsSection: View {
    let ingredients: [Ingredient]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "추천 성분", caption: ingredients.isEmpty ? nil : "우선순위 순")
            if ingredients.isEmpty {
                Text("맞춤 성분을 찾지 못했어요. 추천 이유를 확인해 주세요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                    .card(.soft, padding: Spacing.md, radius: Radius.sm)
            }
            ForEach(Array(ingredients.sorted { $0.priority < $1.priority }.enumerated()), id: \.element.id) { index, ingredient in
                HStack(alignment: .top, spacing: Spacing.md) {
                    Text("\(index + 1)")
                        .appText(.link)
                        .foregroundStyle(index == 0 ? .onPrimary : .ink)
                        .frame(width: 32, height: 32)
                        .background(index == 0 ? Color.ink : Color.canvasSoft, in: Circle())
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(ingredient.name).appText(.link).foregroundStyle(.ink)
                        if let purpose = ingredient.purpose, !purpose.isEmpty {
                            Text(purpose).appText(.bodySmall).foregroundStyle(.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 5)
                    Spacer(minLength: 0)
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
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionTitle(title: "관리 루틴")
                PillSegmentedControl(options: [(RoutineTime.morning, "아침"), (RoutineTime.evening, "저녁")], selection: $tab)
                RoutineTimeline(items: tab == .morning ? morning : evening)
                    .id(tab)
                    .transition(.opacity)

                if !periodic.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("주기 관리").appText(.label).foregroundStyle(.textMuted)
                        ForEach(periodic) { item in
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "calendar").font(.system(size: 14)).foregroundStyle(.ink)
                                Text(item.action).appText(.body).foregroundStyle(.ink)
                            }
                        }
                    }
                    .card(.soft, padding: Spacing.md, radius: Radius.sm)
                }
            }
        }
    }
}

private struct RoutineTimeline: View {
    let items: [RoutineStep]

    var body: some View {
        if items.isEmpty {
            Text("이 시간대에는 따로 할 일이 없어요.")
                .appText(.bodySmall)
                .foregroundStyle(.textMuted)
        } else {
            let sorted = items.sorted { $0.step < $1.step }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(spacing: 0) {
                            Text("\(index + 1)")
                                .appText(.label)
                                .foregroundStyle(.ink)
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(Color.ink, lineWidth: 1.5))
                            if index < sorted.count - 1 {
                                Rectangle().fill(Color.hairline).frame(width: 1.5).frame(maxHeight: .infinity)
                            }
                        }
                        Text(item.action)
                            .appText(.body)
                            .foregroundStyle(.ink)
                            .padding(.top, 3)
                            .padding(.bottom, Spacing.lg)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - 추천 이유

private struct ReasoningSection: View {
    let paragraphs: [String]
    private let titles = ["피부 상태와 원인", "성분을 고른 이유", "사용법과 관리"]

    var body: some View {
        if !paragraphs.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionTitle(title: "추천 이유")
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(spacing: Spacing.xs) {
                            Text("0\(index + 1)").appText(.label).foregroundStyle(.textFaint)
                            if index < titles.count {
                                Text(titles[index]).appText(.link).foregroundStyle(.ink)
                            }
                        }
                        ExpandableText(text: paragraph)
                    }
                    .card(.outlined, padding: Spacing.md, radius: Radius.sm)
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
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(text)
                .appText(.body)
                .foregroundStyle(.inkSoft)
                .lineLimit(isExpanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
            if text.count > 80 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 2) {
                        Text(isExpanded ? "접기" : "더 보기")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                }
            }
        }
    }
}

// MARK: - 이렇게 가정했어요

private struct AssumptionsSection: View {
    let notes: [String]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("이렇게 가정했어요").appText(.link).foregroundStyle(.ink)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(minHeight: ControlSize.minTouch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    ForEach(notes, id: \.self) { note in
                        Text("· \(note)").appText(.bodySmall).foregroundStyle(.textMuted)
                    }
                }
                .padding(.bottom, Spacing.sm)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(Color.canvasSoft, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}
