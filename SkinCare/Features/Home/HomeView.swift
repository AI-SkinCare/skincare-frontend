import SwiftUI

/// SCR-03 홈 (FR-SYS-01)
struct HomeView: View {
    @Environment(\.api) private var api
    @Environment(SessionStore.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var model = HomeModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    TabHeader(title: "홈") { BrandMark(size: 32) }
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(Formatting.dayWithWeekday(.now)).appText(.bodySmall).foregroundStyle(.textMuted)
                        Text("\(session.user?.nickname ?? "")님, 오늘 피부는 어떤가요.")
                            .appText(.title)
                            .foregroundStyle(.ink)
                    }
                }

                if !model.aiAvailable {
                    NoticeBanner(message: AppCopy.serverMaintenance, systemImage: "wrench.and.screwdriver")
                }

                startCard
                recentSection
                metricsGuide
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.canvas)
        .refreshable { await model.load(api: api) }
        .task { await model.load(api: api) }
        .navigationTitle("홈")
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 측정 시작 카드 — 홈의 핵심 행동이라 canvas-soft로 강조 (design.md featured surface)
    private var startCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("1분이면 측정이 끝나요.")
                        .appText(.title)
                        .foregroundStyle(.ink)
                    Text("정면 사진 한 장과 간단한 설문으로\n피부 상태 4가지를 확인해요.")
                        .appText(.bodySmall)
                        .foregroundStyle(.textMuted)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.ink)
                    .frame(width: 48, height: 48)
                    .background(Color.canvas, in: Circle())
                    .accessibilityHidden(true)
            }
            Button("피부 측정 시작") { router.isCaptureFlowPresented = true }
                .buttonStyle(.primary)
                .disabled(!model.aiAvailable)
        }
        .card(.soft)
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                SectionTitle(title: "최근 결과")
                if model.latest != nil {
                    Button { router.selectedTab = .history } label: {
                        HStack(spacing: 2) {
                            Text("전체 보기")
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        }
                        .appText(.bodySmall)
                        .foregroundStyle(.textMuted)
                    }
                    .frame(minHeight: ControlSize.minTouch)
                }
            }

            if let latest = model.latest {
                NavigationLink(value: AppRoute.report(analysisID: latest.analysisId)) {
                    RecentResultCard(item: latest)
                }
                .buttonStyle(PressableStyle())
            } else if model.hasLoaded {
                EmptyStateView(systemImage: "sparkles", title: "아직 측정 기록이 없어요.",
                               message: "첫 측정을 시작해 보세요.")
                    .card(.outlined)
            } else if let errorMessage = model.errorMessage {
                ErrorStateView(message: errorMessage) { Task { await model.load(api: api) } }
                    .card(.outlined)
            } else {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.canvasSoft)
                    .frame(height: 112)
                    .redacted(reason: .placeholder)
            }
        }
    }

    private var metricsGuide: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "이렇게 측정해요")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible(), spacing: Spacing.sm)],
                      spacing: Spacing.sm) {
                ForEach(MetricGuide.all, id: \.metric) { guide in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Image(systemName: guide.icon)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(guide.metric.displayName).appText(.link).foregroundStyle(.ink)
                            Text(guide.detail).appText(.caption).foregroundStyle(.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .card(.outlined, padding: Spacing.md, radius: Radius.sm)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct MetricGuide {
    let metric: Metric
    let icon: String
    let detail: String

    static let all = [
        MetricGuide(metric: .moisture, icon: "drop", detail: "피부 속 촉촉함"),
        MetricGuide(metric: .elasticity, icon: "circle.dotted.and.circle", detail: "탄탄하게 받쳐 주는 힘"),
        MetricGuide(metric: .pigmentation, icon: "circle.lefthalf.filled", detail: "톤·잡티 · 낮을수록 좋아요"),
        MetricGuide(metric: .pore, icon: "circle.grid.3x3", detail: "모공 크기 · 낮을수록 좋아요"),
    ]
}

private struct RecentResultCard: View {
    let item: AnalysisListItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            ScoreRing(score: item.overallScore, size: 64, lineWidth: 6, showsLabel: false)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text(Formatting.dateTime(item.createdAt))
                        .appText(.caption)
                        .foregroundStyle(.textMuted)
                    if item.isDemo { DemoBadge() }
                }
                HStack(spacing: Spacing.xs) {
                    Text("종합 \(item.overallScore)점").appText(.link).foregroundStyle(.ink)
                    GradeTag(grade: Grade(score: item.overallScore))
                }
                if item.status.isInProgress {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini).tint(.ink)
                        Text("맞춤 추천 작성 중").appText(.caption).foregroundStyle(.ink)
                    }
                } else if !item.concerns.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(item.concerns.filter { $0 != .unknown }, id: \.self) { Chip(title: $0.displayLabel) }
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.textFaint)
        }
        .card(.outlined, padding: Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityHint("결과 리포트 열기")
    }
}

@MainActor
@Observable
final class HomeModel {
    private(set) var status: SystemStatus?
    private(set) var latest: AnalysisListItem?
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    /// 상태를 못 받아오면 막지 않는다 — 제출 시 서버가 E3001로 다시 막는다.
    var aiAvailable: Bool { status?.aiAvailable ?? true }

    func load(api: APIClient) async {
        async let statusResult = try? api.send(SystemAPI.status())
        do {
            let page = try await api.send(AnalysisAPI.list(page: 1, size: 1))
            latest = page.items.first
            hasLoaded = true
            errorMessage = nil
        } catch {
            if !hasLoaded { errorMessage = error.userMessage }
        }
        status = await statusResult
    }
}
