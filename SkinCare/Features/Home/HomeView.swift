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
                flowGuide
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

    /// 분석 시작 카드 — 홈의 핵심 행동이라 canvas-soft로 강조 (design.md featured surface)
    private var startCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("사진 한 장이면 충분해요.")
                        .appText(.title)
                        .foregroundStyle(.ink)
                    Text("정면 사진과 간단한 설문으로 피부 이미지를\n분류하고 맞는 성분을 추천해요.")
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
            Button("피부 분석 시작") { router.isCaptureFlowPresented = true }
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
                EmptyStateView(systemImage: "sparkles", title: "아직 분석 기록이 없어요.",
                               message: "첫 분석을 시작해 보세요.")
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

    /// 분석 흐름 안내: 촬영 → 6종 분류 → 성분 추천 (개정 수행계획서 1.1)
    private var flowGuide: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "이렇게 분석해요")
            VStack(spacing: 0) {
                ForEach(Array(FlowStep.all.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        Image(systemName: step.icon)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.ink)
                            .frame(width: 40, height: 40)
                            .background(Color.canvasSoft, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).appText(.link).foregroundStyle(.ink)
                            Text(step.detail).appText(.caption).foregroundStyle(.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 2)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, Spacing.sm)
                    .accessibilityElement(children: .combine)
                    if index < FlowStep.all.count - 1 { Hairline().padding(.leading, 56) }
                }
            }
            .padding(.horizontal, Spacing.md)
            .card(.outlined, padding: 0, radius: Radius.sm)
        }
    }
}

private struct FlowStep {
    let icon: String
    let title: String
    let detail: String

    static let all = [
        FlowStep(icon: "camera.viewfinder", title: "정면 사진 촬영", detail: "얼굴을 원 안에 맞춰 찍고 간단한 설문에 답해요."),
        FlowStep(icon: "square.grid.3x2", title: "6종 이미지 분류",
                 detail: "건선 · 아토피 · 여드름 · 정상 · 주사 · 지루 중 가장 가까운 결과를 보여줘요."),
        FlowStep(icon: "drop", title: "성분 · 관리법 추천", detail: "분류 결과와 설문을 바탕으로 맞는 성분과 루틴을 추천해요."),
    ]
}

private struct RecentResultCard: View {
    let item: AnalysisListItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            DiseaseTile(disease: item.disease, size: 60)
            VStack(alignment: .leading, spacing: 6) {
                Text(Formatting.dateTime(item.createdAt))
                    .appText(.caption)
                    .foregroundStyle(.textMuted)
                HStack(spacing: Spacing.xs) {
                    Text(item.disease.label).appText(.link).foregroundStyle(.ink)
                    Text("모델 분류 점수 \(item.disease.confidencePercent)").appText(.caption).foregroundStyle(.textMuted)
                }
                AnalysisStatusLine(status: item.status, recommendationStatus: item.recommendationStatus, concerns: item.concerns)
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
