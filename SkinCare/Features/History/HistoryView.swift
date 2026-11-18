import SwiftUI

/// SCR-10 이력 (FR-HIS-01, 03). 최신순 20건 단위 무한 스크롤, ⋯ 메뉴·스와이프로 삭제.
struct HistoryView: View {
    @Environment(\.api) private var api
    @Environment(AppRouter.self) private var router
    @State private var model = HistoryModel()
    @State private var pendingDelete: AnalysisListItem?

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(title: "이력")
                .padding(.horizontal, Spacing.screen)
            content
        }
        .background(Color.canvas)
        .navigationTitle("이력")
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.reload(api: api) }
        .confirmationDialog(
            "이 분석 기록을 삭제할까요?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { item in
            Button("삭제", role: .destructive) { Task { await model.delete(item, api: api) } }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("삭제한 기록은 되돌릴 수 없어요.")
        }
        .alert($model.alert)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if model.items.isEmpty, model.hasLoaded {
                VStack(spacing: Spacing.lg) {
                    EmptyStateView(systemImage: "clock.arrow.circlepath", title: "아직 분석 기록이 없어요.",
                                   message: "분석하면 여기에 기록이 쌓여요.")
                    Button("피부 분석 시작") { router.isCaptureFlowPresented = true }
                        .buttonStyle(.primary)
                        .padding(.horizontal, Spacing.xxl)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.items.isEmpty, let errorMessage = model.errorMessage {
                ErrorStateView(message: errorMessage) { Task { await model.reload(api: api) } }
            } else if model.items.isEmpty {
                LoadingStateView()
            } else {
                list
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(model.sections, id: \.title) { section in
                Section {
                    ForEach(section.items) { item in
                        row(item)
                    }
                } header: {
                    Text(section.title)
                        .appText(.label)
                        .foregroundStyle(.textMuted)
                        .padding(.top, Spacing.xs)
                }
            }
            if model.isLoadingMore {
                ProgressView().tint(.ink).frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.canvas)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listSectionSpacing(Spacing.xs)
        .refreshable { await model.reload(api: api) }
    }

    private func row(_ item: AnalysisListItem) -> some View {
        // 리스트 기본 화살표(카드 밖)를 숨기고, 화살표는 카드 안에 그린다.
        ZStack {
            NavigationLink(value: AppRoute.report(analysisID: item.analysisId)) { EmptyView() }
                .opacity(0)
            HistoryRow(item: item) { pendingDelete = item }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.canvas)
        .listRowInsets(EdgeInsets(top: Spacing.xxs, leading: Spacing.screen, bottom: Spacing.xxs, trailing: Spacing.screen))
        .swipeActions {
            Button("삭제") { pendingDelete = item }
                .tint(.negative)
        }
        .onAppear {
            if item.id == model.items.last?.id { Task { await model.loadMore(api: api) } }
        }
    }
}

private struct HistoryRow: View {
    let item: AnalysisListItem
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            DiseaseTile(disease: item.disease, size: 52)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: Spacing.xs) {
                    Text(item.disease.label).appText(.link).foregroundStyle(.ink)
                    Text(Formatting.shortDay(item.createdAt)).appText(.caption).foregroundStyle(.textMuted)
                }
                AnalysisStatusLine(status: item.status, recommendationStatus: item.recommendationStatus, concerns: item.concerns)
            }

            Spacer(minLength: 0)

            Menu {
                Button("삭제", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.textFaint)
                    .frame(width: 32, height: ControlSize.minTouch)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("더 보기")

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.textFaint)
                .accessibilityHidden(true)
        }
        .card(.outlined, padding: Spacing.md, radius: Radius.sm)
        .contentShape(Rectangle())
    }
}

@MainActor
@Observable
final class HistoryModel {
    struct MonthSection {
        let title: String
        let items: [AnalysisListItem]
    }

    private(set) var items: [AnalysisListItem] = []
    private(set) var hasLoaded = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    var alert: AlertItem?

    private var page = 0
    private var totalPages = 1

    /// 월별 묶음 (최신순 유지)
    var sections: [MonthSection] {
        var result: [MonthSection] = []
        for item in items {
            let title = Formatting.yearMonth(item.createdAt)
            if let last = result.last, last.title == title {
                result[result.count - 1] = MonthSection(title: title, items: last.items + [item])
            } else {
                result.append(MonthSection(title: title, items: [item]))
            }
        }
        return result
    }

    func reload(api: APIClient) async {
        do {
            let result = try await api.send(AnalysisAPI.list(page: 1))
            items = result.items
            page = result.page.page
            totalPages = result.page.totalPages
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = error.userMessage
        }
    }

    func loadMore(api: APIClient) async {
        guard !isLoadingMore, page < totalPages else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await api.send(AnalysisAPI.list(page: page + 1))
            let existing = Set(items.map(\.id))
            items += result.items.filter { !existing.contains($0.id) }
            page = result.page.page
            totalPages = result.page.totalPages
        } catch {
            alert = AlertItem(message: error.userMessage)
        }
    }

    func delete(_ item: AnalysisListItem, api: APIClient) async {
        do {
            _ = try await api.send(AnalysisAPI.delete(id: item.analysisId))
            withAnimation { items.removeAll { $0.id == item.id } }
        } catch {
            alert = AlertItem(message: error.userMessage)
        }
    }
}
