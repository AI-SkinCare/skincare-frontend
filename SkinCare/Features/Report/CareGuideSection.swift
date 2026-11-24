import SwiftUI

struct CareGuideSection: View {
    let analysis: AnalysisView
    var body: some View {
        if analysis.canDisplayRecommendation, !analysis.disease.uncertain, let catalog = CareCatalog.bundled {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let advice = catalog.care[analysis.disease.label] { card("일상 관리", advice) }
                if let advice = catalog.diet[analysis.disease.label] { card("식습관 메모", advice) }
                else if let general = catalog.diet["general"] { card("식습관 메모", general, source: "세계보건기구 자료") }
                Text("추천 성분이 든 제품 예시").appText(.title)
                let names = analysis.recommendation?.ingredients?.map(\.name) ?? []
                let matches = catalog.matched(names, avoiding: analysis.survey?.avoidIngredients)
                if matches.isEmpty { Text("추천 성분과 회피 조건을 함께 확인한 제품이 없어요.") }
                ForEach(matches, id: \.name) { product in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(product.name).bold()
                        Text("일치한 추천 성분 · " + product.matches.filter { names.map(catalog.key).contains($0) }.joined(separator: ", "))
                        Text(product.category + " · 구매 전 국내 포장의 전성분을 확인해 주세요.")
                        Link("제조사 성분표", destination: product.source)
                    }
                }
            }
        }
    }
    private func card(_ title: String, _ advice: CareCatalog.Advice, source: String = "미국피부과학회 자료") -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline)
            Text(advice.body)
            Link(source, destination: advice.source)
        }
    }
}
