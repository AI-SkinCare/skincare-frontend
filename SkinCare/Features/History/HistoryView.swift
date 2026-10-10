import SwiftUI

/// SCR-10 이력 (FR-HIS-01, 03). 최신순 20건 단위 무한 스크롤, ⋯ 메뉴·스와이프로 삭제.
struct HistoryView: View {
    @Environment(\.api) private var api
    @State private var model = HistoryModel()
    @State private var pendingDelete: AnalysisListItem?

    var body: some View {
        Group {
            if model.items.isEmpty, model.hasLoaded {
                Text("아직 측정 기록이 없어요.")
                    .appText(.body)
                    .foregroundStyle(.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.items.isEmpty, let errorMessage = model.errorMessage {
                ErrorStateView(message: errorMessage) { Task { await model.reload(api: api) } }
            } else if model.items.isEmpty {
                LoadingStateView()
            } else {
                list
            }
        }
        .background(Color.canvas)
        .navigationTitle("측정 이력")
        .task { await model.reload(api: api) }
        .confirmationDialog(
            "이 측정 기록을 삭제할까요?",
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

    private var list: some View {
        List {
            ForEach(model.items) { item in
                NavigationLink(value: AppRoute.report(analysisID: item.analysisId)) {
                    HistoryRow(item: item) { pendingDelete = item }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.screen, bottom: Spacing.xs, trailing: Spacing.screen))
                .swipeActions {
                    Button("삭제") { pendingDelete = item }
                        .tint(.gradeCare)
                }
                .onAppear {
                    if item.id == model.items.last?.id { Task { await model.loadMore(api: api) } }
                }
            }
            if model.isLoadingMore {
                ProgressView().tint(.ink).frame(maxWidth: .infinity).listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable { await model.reload(api: api) }
    }
}

private struct HistoryRow: View {
    let item: AnalysisListItem
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text(Formatting.dateTime(item.createdAt))
                        .appText(.caption)
                        .foregroundStyle(.textMuted)
                    if item.isDemo { DemoBadge() }
                }
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text("\(item.overallScore)점").appText(.title).foregroundStyle(.ink)
                    GradeTag(grade: Grade(score: item.overallScore))
                }
                if !item.concerns.isEmpty {
                    FlowLayout {
                        ForEach(item.concerns.filter { $0 != .unknown }, id: \.self) { Chip(title: $0.displayLabel) }
                    }
                }
                if let statusText {
                    Text(statusText).appText(.bodySmall).foregroundStyle(.textMuted)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button("삭제", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.textMuted)
                    .frame(width: ControlSize.minTouch, height: ControlSize.minTouch)
            }
            .accessibilityLabel("더 보기")
        }
        .card(.outlined, padding: Spacing.md, radius: Radius.sm)
    }

    private var statusText: String? {
        switch item.status {
        case .queued, .recommending: "추천 작성 중"
        case .failed: "추천을 만들지 못했어요"
        default: nil
        }
    }
}

@MainActor
@Observable
final class HistoryModel {
    private(set) var items: [AnalysisListItem] = []
    private(set) var hasLoaded = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?
    var alert: AlertItem?

    private var page = 0
    private var totalPages = 1

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
            items.removeAll { $0.id == item.id }
        } catch {
            alert = AlertItem(message: error.userMessage)
        }
    }
}
