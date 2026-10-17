import SwiftUI

/// SCR-08 결과 리포트. 이미지 분류 참고 결과를 바로 보여주고, 추천은 진행 상태에 따라 바뀐다.
struct ReportView: View {
    @Environment(\.api) private var api
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: ReportModel

    init(analysisID: String) {
        _model = State(initialValue: ReportModel(analysisID: analysisID))
    }

    private struct PollKey: Equatable {
        let isActive: Bool
        let generation: Int
    }

    var body: some View {
        Group {
            if let analysis = model.analysis {
                content(analysis)
            } else if let errorMessage = model.errorMessage {
                ErrorStateView(message: errorMessage) { Task { await model.poll(api: api) } }
            } else {
                LoadingStateView()
            }
        }
        .background(Color.canvas)
        .navigationTitle("분석 결과")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: PollKey(isActive: scenePhase == .active, generation: model.pollGeneration)) {
            guard scenePhase == .active else { return }
            await model.poll(api: api)
        }
        .alert($model.alert)
    }

    private func content(_ analysis: AnalysisView) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ClassificationHero(analysis: analysis)
                GuidanceBox(lines: analysis.guidance)
                ScoreBreakdown(disease: analysis.disease)
                RecommendationSection(model: model, analysis: analysis)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xl)
        }
    }
}

// MARK: - 분류 참고 결과

/// 분류 라벨(질환명)을 그대로 크게 보여준다. 점수는 "모델 분류 점수"로만 표기 (질환 확률 아님).
private struct ClassificationHero: View {
    let analysis: AnalysisView

    var body: some View {
        let disease = analysis.disease
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Text("이미지 분류 참고 결과").appText(.bodySmall).foregroundStyle(.textMuted)
                Spacer()
                Text(Formatting.dateTime(analysis.createdAt)).appText(.caption).foregroundStyle(.textFaint)
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(disease.label)
                    .font(Font.custom("Pretendard-Bold", size: 44, relativeTo: .largeTitle))
                    .foregroundStyle(disease.uncertain ? .textMuted : .ink)
                if disease.uncertain {
                    Chip(title: "판단 보류")
                }
            }

            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("모델 분류 점수").appText(.caption).foregroundStyle(.textMuted)
                    Text(disease.confidencePercent).appText(.title).foregroundStyle(.ink)
                }
                Spacer()
            }

            if disease.uncertain {
                Text("모델이 확신하지 못한 결과예요. 밝은 곳에서 정면으로 다시 찍으면 더 정확해질 수 있어요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(.soft)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("이미지 분류 참고 결과 \(disease.label), 모델 분류 점수 \(disease.confidencePercent)\(disease.uncertain ? ", 판단 보류" : "")")
    }
}

/// 상시 안내문. 서버 `guidance`가 없을 때(진행 중)는 기본 문구를 쓴다.
private struct GuidanceBox: View {
    let lines: [String]

    var body: some View {
        let items = lines.isEmpty ? [AppCopy.classificationNotice] : lines
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(items, id: \.self) { line in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.top, 2)
                    Text(line)
                        .appText(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .foregroundStyle(.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 6종 모델 분류 점수. 표시 순서는 서버 순서(건선·아토피·여드름·정상·주사·지루), 최고 점수만 ink.
private struct ScoreBreakdown: View {
    let disease: Disease

    var body: some View {
        let rows = disease.orderedProbabilities
        let top = rows.max { $0.score < $1.score }?.label
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "6종 모델 분류 점수", caption: "질환 확률이 아니에요")
            VStack(spacing: Spacing.sm) {
                ForEach(rows, id: \.label) { row in
                    let isTop = row.label == top
                    HStack(spacing: Spacing.sm) {
                        Text(row.label)
                            .appText(isTop ? .link : .body)
                            .foregroundStyle(isTop ? .ink : .textMuted)
                            .frame(width: 52, alignment: .leading)
                        ProgressBar(value: Int((row.score * 100).rounded()), color: isTop ? .ink : .hairline, height: 8)
                        Text(Disease.percent(row.score))
                            .appText(.caption)
                            .foregroundStyle(isTop ? .ink : .textMuted)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(row.label)
                    .accessibilityValue("모델 분류 점수 \(Disease.percent(row.score))")
                }
            }
            .card(.outlined, padding: Spacing.md, radius: Radius.sm)
        }
    }
}

// MARK: - 맞춤 추천 (상태별)

private struct RecommendationSection: View {
    let model: ReportModel
    let analysis: AnalysisView
    @Environment(\.api) private var api
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "맞춤 추천")
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch analysis.status {
        case .queued, .generating:
            pendingCard
        case .completed:
            if let recommendation = analysis.recommendation {
                doneCard(recommendation)
            }
        case .withheld:
            withheldCard
        case .failed:
            failedCard
        case .unknown:
            EmptyView()
        }
    }

    // 진행 중

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if model.pollingTimedOut {
                Text("시간이 오래 걸리고 있어요.").appText(.link).foregroundStyle(.ink)
                Text("이력에서 나중에 확인할 수 있어요.").appText(.bodySmall).foregroundStyle(.textMuted)
            } else {
                HStack(spacing: Spacing.sm) {
                    ProgressView().tint(.ink)
                    Text(analysis.status == .generating ? "성분과 관리법을 정리하고 있어요." : "맞춤 추천을 기다리고 있어요.")
                        .appText(.link)
                        .foregroundStyle(.ink)
                }
                let details = pendingDetails
                if !details.isEmpty {
                    Text(details.joined(separator: " · "))
                        .appText(.bodySmall)
                        .foregroundStyle(.textMuted)
                }
                if model.showsDelayNotice {
                    Text("평소보다 오래 걸리고 있어요. 조금만 더 기다려 주세요.")
                        .appText(.bodySmall)
                        .foregroundStyle(.textMuted)
                }
                if !model.aiAvailable {
                    Text("서버가 돌아오면 이어서 작성돼요.").appText(.bodySmall).foregroundStyle(.textMuted)
                }
            }
            Hairline()
            Text("화면을 나가도 추천은 계속 만들어져요. 이력에서 다시 볼 수 있어요.")
                .appText(.caption)
                .foregroundStyle(.textMuted)
        }
        .card(.soft)
    }

    private var pendingDetails: [String] {
        if analysis.status == .generating { return ["보통 1분 이내"] }
        var details: [String] = []
        if let position = analysis.queuePosition { details.append("대기 \(position)번째") }
        if let wait = analysis.estimatedWaitSec { details.append(Formatting.waitTime(seconds: wait)) }
        return details
    }

    // 보류 — 오류가 아니다

    @ViewBuilder
    private var withheldCard: some View {
        if analysis.recommendationStatus == .noConcern {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("추천할 고민을 찾지 못했어요", systemImage: "checkmark.circle")
                    .appText(.link)
                    .foregroundStyle(.ink)
                Text("정상으로 분류됐고 설문에서 고른 피부 고민이 없어서 자동 추천을 만들지 않았어요. 관리하고 싶은 고민을 골라 다시 분석해 보세요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("고민 골라서 다시 분석") { router.isCaptureFlowPresented = true }
                    .buttonStyle(.primary)
            }
            .card(.soft)
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("분류가 불확실해 추천을 보류했어요", systemImage: "questionmark.circle")
                    .appText(.link)
                    .foregroundStyle(.ink)
                Text("밝은 곳에서 정면으로 다시 찍어 보세요. 피부 상태가 걱정된다면 피부과 전문의와 상담하는 것이 좋아요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("다시 촬영하기") { router.isCaptureFlowPresented = true }
                    .buttonStyle(.primary)
            }
            .card(.soft)
        }
    }

    // 실패

    private var failedCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("추천을 만들지 못했어요", systemImage: "exclamationmark.circle")
                .appText(.link)
                .foregroundStyle(.ink)
            Text(analysis.error?.message ?? "분류 결과는 그대로 있어요. 다시 시도하면 추천만 새로 만들어요.")
                .appText(.bodySmall)
                .foregroundStyle(.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await model.retryRecommendation(api: api) }
            } label: {
                HStack(spacing: Spacing.xs) {
                    if model.isRetrying { ProgressView().tint(.onPrimary) }
                    Text("추천 다시 요청")
                }
            }
            .buttonStyle(.primary)
            .disabled(model.isRetrying)
        }
        .card(.soft)
    }

    // 완료

    private func doneCard(_ recommendation: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ProfileChips(recommendation: recommendation)

            if let answer = recommendation.answer, !answer.isEmpty {
                Text(Formatting.leadingSentences(answer))
                    .appText(.body)
                    .foregroundStyle(.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let ingredients = (recommendation.ingredients ?? []).sorted { $0.priority < $1.priority }
            if ingredients.isEmpty {
                Text("맞춤 성분을 찾지 못했어요. 추천 이유를 확인해 주세요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("추천 성분").appText(.label).foregroundStyle(.textMuted)
                    ForEach(Array(ingredients.prefix(3).enumerated()), id: \.element.id) { index, ingredient in
                        HStack(spacing: Spacing.sm) {
                            Text("\(index + 1)")
                                .appText(.label)
                                .foregroundStyle(index == 0 ? .onPrimary : .ink)
                                .frame(width: 22, height: 22)
                                .background(index == 0 ? Color.ink : Color.canvasSoft, in: Circle())
                            Text(ingredient.name).appText(.link).foregroundStyle(.ink)
                        }
                    }
                }
            }

            NavigationLink(value: AppRoute.recommendation(analysisID: analysis.analysisId)) {
                Text("추천 자세히 보기")
            }
            .buttonStyle(.primary)
        }
        .card(.outlined)
    }
}

/// 피부 타입·고민 칩. 고민은 `Concern.displayLabel`로 표시하고 모르는 코드는 숨긴다.
struct ProfileChips: View {
    let recommendation: Recommendation

    var body: some View {
        FlowLayout(spacing: 6) {
            if let skinType = recommendation.skinType?.code, skinType != .unknown {
                Chip(title: skinType.label, isSelected: true)
            }
            ForEach((recommendation.concerns ?? []).map(\.code).filter { $0 != .unknown }, id: \.self) { concern in
                Chip(title: concern.displayLabel)
            }
        }
    }
}
