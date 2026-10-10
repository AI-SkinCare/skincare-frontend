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
        .task(id: PollKey(isActive: scenePhase == .active, generation: model.pollGeneration)) {
            guard scenePhase == .active else { return }
            await model.poll(api: api)
        }
        .alert($model.alert)
    }

    private func content(_ detail: AnalysisDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header(detail)
                ScoreGauge(score: detail.measurement.overallScore)
                    .frame(maxWidth: .infinity)
                MetricBarsSection(summary: detail.measurement.summary)
                if !detail.measurement.byRoi.isEmpty {
                    RoiSection(regions: detail.measurement.byRoi)
                }
                RecommendationSummarySection(model: model, detail: detail)
                footer
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.lg)
        }
    }

    private func header(_ detail: AnalysisDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(Formatting.dateTime(detail.createdAt))
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                if detail.measurement.isDemo { DemoBadge() }
            }
            if detail.measurement.isDemo {
                NoticeBanner(message: AppCopy.demoReportNotice, systemImage: "info.circle")
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if model.hasPrevious {
                NavigationLink(value: AppRoute.trend(analysisID: model.analysisID)) {
                    Text("이전 측정과 비교")
                }
                .buttonStyle(.outline)
            }
            DisclaimerText(text: model.detail?.recommendation.disclaimer)
        }
    }
}

// MARK: - 종합 점수

private struct ScoreGauge: View {
    let score: Int

    var body: some View {
        let grade = Grade(score: score)
        ZStack {
            Circle()
                .stroke(Color.canvasSoft, lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(Color.ink, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: Spacing.xxs) {
                Text("\(score)")
                    .appText(.heading1)
                    .foregroundStyle(.ink)
                GradeTag(grade: grade)
            }
        }
        .frame(width: 184, height: 184)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("종합 점수")
        .accessibilityValue("100점 만점에 \(score)점, \(grade.label)")
    }
}

// MARK: - 지표 4종

private struct MetricBarsSection: View {
    let summary: [MetricSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionTitle(title: "지표별 상태")
            ForEach(summary.filter { $0.metric != .unknown }) { item in
                MetricBarRow(item: item)
            }
        }
    }
}

private struct MetricBarRow: View {
    let item: MetricSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(item.metric.displayName).appText(.link).foregroundStyle(.ink)
                Spacer()
                GradeTag(grade: item.grade)
            }
            // 막대 길이는 score(좋은 방향 통일)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.canvasSoft)
                    Capsule().fill(Color.ink)
                        .frame(width: proxy.size.width * CGFloat(min(max(item.score, 0), 100)) / 100)
                }
            }
            .frame(height: 8)
            HStack(spacing: Spacing.xs) {
                Text("측정값 \(item.value)")
                if item.metric.lowerIsBetter {
                    Text("· 낮을수록 좋아요")
                }
            }
            .appText(.caption)
            .foregroundStyle(.textMuted)
        }
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "부위별 상태")
            ForEach(regions.filter { $0.roi != .unknown }) { region in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Button {
                        withAnimation { toggle(region.id) }
                    } label: {
                        HStack {
                            Text(region.roi.displayName).appText(.body).foregroundStyle(.ink)
                            Spacer()
                            GradeTag(grade: region.grade)
                            Image(systemName: expanded.contains(region.id) ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.textMuted)
                        }
                        .frame(minHeight: ControlSize.minTouch)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if expanded.contains(region.id) {
                        ForEach(metrics, id: \.self) { metric in
                            if let value = region.value(of: metric) {
                                HStack {
                                    Text(metric.displayName)
                                    Spacer()
                                    Text("\(value)")
                                }
                                .appText(.bodySmall)
                                .foregroundStyle(.textMuted)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xxs)
                .background(Color.canvasSoft, in: RoundedRectangle(cornerRadius: Radius.sm))
            }
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionTitle(title: "맞춤 추천")
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        let recommendation = detail.recommendation
        if detail.status == .failed || recommendation.status == .failed {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("추천을 만들지 못했어요.")
                    .appText(.body)
                    .foregroundStyle(.ink)
                Button(model.isRetrying ? "요청 중…" : "다시 시도") {
                    Task { await model.retryRecommendation(api: api) }
                }
                .buttonStyle(.softPill)
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if model.pollingTimedOut {
                Text("시간이 오래 걸리고 있어요. 이력에서 나중에 확인할 수 있어요.")
                    .appText(.body)
                    .foregroundStyle(.ink)
            } else {
                HStack(spacing: Spacing.sm) {
                    ProgressView().tint(.ink)
                    Text(pendingMessage)
                        .appText(.body)
                        .foregroundStyle(.ink)
                }
                if !model.aiAvailable {
                    Text("서버가 돌아오면 이어서 작성돼요.")
                        .appText(.bodySmall)
                        .foregroundStyle(.textMuted)
                }
            }
            Text("측정 결과는 위에서 계속 볼 수 있어요.")
                .appText(.caption)
                .foregroundStyle(.textMuted)
        }
        .card(.soft)
    }

    private var pendingMessage: String {
        if detail.status == .recommending {
            return "추천 이유를 정리하고 있어요 (보통 1분 이내)"
        }
        var parts = ["맞춤 추천을 작성하고 있어요"]
        if let position = detail.queuePosition { parts.append("대기 \(position)번째") }
        if let wait = detail.estimatedWaitSec { parts.append(Formatting.waitTime(seconds: wait)) }
        return parts.joined(separator: " · ")
    }

    private func doneCard(_ recommendation: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ProfileChips(recommendation: recommendation)

            if let answer = recommendation.answer, !answer.isEmpty {
                Text(Formatting.leadingSentences(answer))
                    .appText(.body)
                    .foregroundStyle(.ink)
            }

            let ingredients = (recommendation.ingredients ?? []).sorted { $0.priority < $1.priority }
            if ingredients.isEmpty {
                Text("맞춤 성분을 찾지 못했어요. 추천 이유를 확인해 주세요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
            } else {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("추천 성분").appText(.bodySmall).foregroundStyle(.textMuted)
                    ForEach(Array(ingredients.prefix(3).enumerated()), id: \.element.id) { index, ingredient in
                        Text("\(index + 1). \(ingredient.name)")
                            .appText(.link)
                            .foregroundStyle(.ink)
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
        FlowLayout {
            if let skinType = recommendation.skinType?.code, skinType != .unknown {
                Chip(title: skinType.label, isSelected: true)
            }
            ForEach((recommendation.concerns ?? []).map(\.code).filter { $0 != .unknown }, id: \.self) { concern in
                Chip(title: concern.displayLabel)
            }
        }
    }
}
