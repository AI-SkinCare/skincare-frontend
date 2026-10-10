import SwiftUI

/// SCR-08 결과 리포트 (FR-REP-01). 측정 결과는 바로 보여주고, 추천은 진행 상태에 따라 바뀐다.
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
            if let detail = model.detail {
                content(detail)
            } else if let errorMessage = model.errorMessage {
                ErrorStateView(message: errorMessage) { Task { await model.poll(api: api) } }
            } else {
                LoadingStateView()
            }
        }
        .background(Color.canvas)
        .navigationTitle("측정 결과")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: PollKey(isActive: scenePhase == .active, generation: model.pollGeneration)) {
            guard scenePhase == .active else { return }
            await model.poll(api: api)
        }
        .alert($model.alert)
    }

    private func content(_ detail: AnalysisDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScoreHero(detail: detail)
                MetricGridSection(summary: detail.measurement.summary)
                if !detail.measurement.byRoi.isEmpty {
                    RoiSection(regions: detail.measurement.byRoi)
                }
                RecommendationSummarySection(model: model, detail: detail)
                footer
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.xl)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if model.hasPrevious {
                NavigationLink(value: AppRoute.trend(analysisID: model.analysisID)) {
                    Label("이전 측정과 비교", systemImage: "chart.line.uptrend.xyaxis")
                }
                .buttonStyle(.outline)
            }
            DisclaimerText(text: model.detail?.recommendation.disclaimer)
        }
    }
}

// MARK: - 종합 점수

private struct ScoreHero: View {
    let detail: AnalysisDetail

    private var grade: Grade { Grade(score: detail.measurement.overallScore) }

    /// 등급별 한 줄 요약. 문구 규칙상 상태를 단정하지 않는다.
    private var summary: String {
        switch grade {
        case .good: "전반적으로 좋은 상태예요."
        case .normal: "조금만 관리하면 더 좋아질 수 있어요."
        case .care, .unknown: "꾸준한 관리가 도움이 될 수 있어요."
        }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.xs) {
                Text(Formatting.dateTime(detail.createdAt))
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                if detail.measurement.isDemo { DemoBadge() }
            }

            ScoreRing(score: detail.measurement.overallScore, size: 188)

            VStack(spacing: Spacing.xs) {
                GradeTag(grade: grade, isFilled: true)
                Text(summary)
                    .appText(.title)
                    .foregroundStyle(.ink)
                    .multilineTextAlignment(.center)
            }

            if detail.measurement.isDemo {
                NoticeBanner(message: AppCopy.demoReportNotice, systemImage: "info.circle")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }
}

// MARK: - 지표 4종

private struct MetricGridSection: View {
    let summary: [MetricSummary]
    private let columns = [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "지표별 상태", caption: "100점에 가까울수록 좋아요")
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(summary.filter { $0.metric != .unknown }) { item in
                    MetricTile(item: item)
                }
            }
        }
    }
}

private struct MetricTile: View {
    let item: MetricSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(item.metric.displayName).appText(.bodySmall).foregroundStyle(.textMuted)
                Spacer()
                GradeTag(grade: item.grade)
            }
            Text("\(item.score)")
                .appText(.heading4)
                .foregroundStyle(.ink)
            // 막대 길이는 score(좋은 방향 통일)
            ProgressBar(value: item.score)
            Text(item.metric.lowerIsBetter ? "측정값 \(item.value) · 낮을수록 좋아요" : "측정값 \(item.value)")
                .appText(.caption)
                .foregroundStyle(.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .card(.outlined, padding: Spacing.md, radius: Radius.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.metric.displayName)
        .accessibilityValue(
            "점수 \(item.score)점, \(item.grade.label), 측정값 \(item.value)\(item.metric.lowerIsBetter ? ", 낮을수록 좋음" : "")"
        )
    }
}

// MARK: - 부위별

/// TODO: 얼굴 도식 위 ROI 점 표시 (SCR-08). 1차는 목록으로 보여준다.
private struct RoiSection: View {
    let regions: [RoiMetrics]
    @State private var expanded: Set<String> = []

    private let metrics: [Metric] = [.moisture, .elasticity, .pigmentation, .pore]

    var body: some View {
        let visible = regions.filter { $0.roi != .unknown }
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "부위별 상태")
            VStack(spacing: 0) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, region in
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { toggle(region.id) }
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Text(region.roi.displayName).appText(.body).foregroundStyle(.ink)
                                Spacer()
                                Text("\(region.overallScore)").appText(.link).foregroundStyle(.ink)
                                GradeTag(grade: region.grade)
                                    .frame(width: 72, alignment: .leading)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.textFaint)
                                    .rotationEffect(.degrees(expanded.contains(region.id) ? 180 : 0))
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(expanded.contains(region.id) ? "접기" : "지표 펼치기")

                        if expanded.contains(region.id) {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Spacing.xs) {
                                ForEach(metrics, id: \.self) { metric in
                                    if let value = region.value(of: metric) {
                                        HStack {
                                            Text(metric.displayName).foregroundStyle(.textMuted)
                                            Spacer()
                                            Text("\(value)").foregroundStyle(.ink)
                                        }
                                        .appText(.bodySmall)
                                        .padding(.horizontal, Spacing.sm)
                                        .padding(.vertical, Spacing.xs)
                                        .background(Color.canvasSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                            .padding(.bottom, Spacing.md)
                            .transition(.opacity)
                        }
                    }
                    if index < visible.count - 1 { Hairline() }
                }
            }
            .padding(.horizontal, Spacing.md)
            .card(.outlined, padding: 0, radius: Radius.sm)
        }
    }

    private func toggle(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }
}

// MARK: - 추천 요약

private struct RecommendationSummarySection: View {
    let model: ReportModel
    let detail: AnalysisDetail
    @Environment(\.api) private var api

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "맞춤 추천")
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        let recommendation = detail.recommendation
        if detail.status == .failed || recommendation.status == .failed {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.circle").font(.system(size: 18)).foregroundStyle(.ink)
                    Text("추천을 만들지 못했어요.").appText(.link).foregroundStyle(.ink)
                }
                Text("측정 결과는 그대로 있어요. 다시 시도하면 추천을 새로 작성해요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                Button {
                    Task { await model.retryRecommendation(api: api) }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if model.isRetrying { ProgressView().tint(.onPrimary) }
                        Text("다시 시도")
                    }
                }
                .buttonStyle(.primary)
                .disabled(model.isRetrying)
            }
            .card(.soft)
        } else if detail.status.isInProgress {
            pendingCard
        } else if recommendation.status == .done {
            doneCard(recommendation)
        }
    }

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if model.pollingTimedOut {
                Text("시간이 오래 걸리고 있어요.")
                    .appText(.link)
                    .foregroundStyle(.ink)
                Text("이력에서 나중에 확인할 수 있어요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
            } else {
                HStack(spacing: Spacing.sm) {
                    ProgressView().tint(.ink)
                    Text(detail.status == .recommending ? "추천 이유를 정리하고 있어요." : "맞춤 추천을 작성하고 있어요.")
                        .appText(.link)
                        .foregroundStyle(.ink)
                }
                HStack(spacing: Spacing.xs) {
                    ForEach(pendingDetails, id: \.self) { Chip(title: $0) }
                }
                if !model.aiAvailable {
                    Text("서버가 돌아오면 이어서 작성돼요.")
                        .appText(.bodySmall)
                        .foregroundStyle(.textMuted)
                }
            }
            Hairline()
            Text("기다리는 동안 위에서 측정 결과를 볼 수 있어요.")
                .appText(.caption)
                .foregroundStyle(.textMuted)
        }
        .card(.soft)
    }

    private var pendingDetails: [String] {
        if detail.status == .recommending { return ["보통 1분 이내"] }
        var details: [String] = []
        if let position = detail.queuePosition { details.append("대기 \(position)번째") }
        if let wait = detail.estimatedWaitSec { details.append(Formatting.waitTime(seconds: wait)) }
        return details
    }

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

            NavigationLink(value: AppRoute.recommendation(analysisID: detail.analysisId)) {
                Text("추천 자세히 보기")
            }
            .buttonStyle(.primary)
        }
        .card(.outlined)
    }
}

/// 피부 타입·고민 칩 (화면 표기는 API §6.4 "화면 표기" 열).
/// 서버 label(AI 라벨)은 "여드름" 같은 질환명이 있어 쓰지 않고, 모르는 코드는 표시하지 않는다.
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
