import SwiftUI

struct SkinKnowledgeView: View {
    @Environment(\.api) private var api
    @State private var query = ""
    @State private var kind = "guide"
    @State private var result: KnowledgeResult?
    @State private var failure: String?
    @State private var loading = false

    var body: some View {
        List {
            Section {
                Picker("자료 종류", selection: $kind) {
                    Text("관리 안내").tag("guide")
                    Text("연구 문헌").tag("research")
                    Text("제품 라벨").tag("label")
                }.pickerStyle(.segmented)
                TextField("성분명이나 질문 입력", text: $query)
                    .onChange(of: query) { _, value in if value.count > 160 { query = String(value.prefix(160)) } }
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                Button("검색") { Task { await search() } }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
            }.disabled(loading)
            if loading { ProgressView("자료 검색 중") }
            if let failure { Text(failure) }
            if let result {
                Section {
                    Text(result.answer)
                    if let source = result.sources.first(where: { $0.id == result.answerSourceId }) {
                        sourceLink(source, "답변 출처 · " + source.publisher)
                    }
                    Text("자료 수집일 · " + result.asOf).font(.footnote)
                }
                ForEach(result.sources) { source in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(source.publisher).font(.caption)
                        sourceLink(source, source.title)
                        if source.id != result.answerSourceId { Text(source.text).font(.footnote) }
                    }
                }
            }
        }
        .navigationTitle("피부 자료 검색")
        .onChange(of: kind) { _, _ in result = nil; failure = nil }
        .onChange(of: query) { _, _ in result = nil; failure = nil }
    }

    @ViewBuilder private func sourceLink(_ source: KnowledgeResult.Source, _ label: String) -> some View {
        if let url = EvidenceSource(title: source.title, url: source.url, summary: nil).webURL {
            Link(label, destination: url)
        }
    }

    @MainActor private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !loading, term.count >= 2 else { return }
        loading = true
        result = nil
        failure = nil
        defer { loading = false }
        do { result = try await api.send(KnowledgeAPI.search(term, kind: kind)) }
        catch { failure = error.userMessage }
    }
}
