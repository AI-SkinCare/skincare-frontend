import SwiftUI

/// SCR-03 홈 (FR-SYS-01)
struct HomeView: View {
    @Environment(\.api) private var api
    @Environment(SessionStore.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var model = HomeModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("\(session.user?.nickname ?? "")님, 안녕하세요.")
                    .appText(.heading4)
                    .foregroundStyle(.ink)
                    .padding(.top, Spacing.md)

                if !model.aiAvailable {
                    NoticeBanner(message: AppCopy.serverMaintenance)
                }

                recentSection

                Button("피부 측정 시작") { router.isCaptureFlowPresented = true }
                    .buttonStyle(.primary)
                    .disabled(!model.aiAvailable)
            }
            .padding(.horizontal, Spacing.screen)
        }
        .background(Color.canvas)
        .refreshable { await model.load(api: api) }
        .task { await model.load(api: api) }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var recentSection: some View {
        if let latest = model.latest {
            NavigationLink(value: AppRoute.report(analysisID: latest.analysisId)) {
                RecentResultCard(item: latest)
            }
            .buttonStyle(.plain)
        } else if model.hasLoaded {
            Text("아직 측정 기록이 없어요. 첫 측정을 시작해 보세요.")
                .appText(.body)
                .foregroundStyle(.textMuted)
                .card(.soft)
        } else if let errorMessage = model.errorMessage {
            ErrorStateView(message: errorMessage) { Task { await model.load(api: api) } }
        } else {
            ProgressView().tint(.ink).frame(maxWidth: .infinity, minHeight: 120)
        }
    }
}

private struct RecentResultCard: View {
    let item: AnalysisListItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("최근 결과")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                if item.isDemo { DemoBadge() }
                Spacer()
                Text(Formatting.date(item.createdAt))
                    .appText(.caption)
                    .foregroundStyle(.textMuted)
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text("\(item.overallScore)")
                    .appText(.heading3)
                    .foregroundStyle(.ink)
                Text("점").appText(.body).foregroundStyle(.textMuted)
                Spacer()
                GradeTag(grade: Grade(score: item.overallScore))
            }
            if !item.concerns.isEmpty {
                FlowLayout {
                    ForEach(item.concerns.filter { $0 != .unknown }, id: \.self) { Chip(title: $0.displayLabel) }
                }
            }
            if item.status.isInProgress {
                Label("추천 작성 중", systemImage: "ellipsis.circle")
                    .appText(.bodySmall)
                    .foregroundStyle(.ink)
            }
        }
        .card(.outlined)
        .accessibilityElement(children: .combine)
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
