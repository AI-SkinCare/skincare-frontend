import SwiftUI

struct CareGuideSection: View {
    let analysis: AnalysisView
    var body: some View {
        if analysis.canDisplayRecommendation, !analysis.disease.uncertain, let catalog = CareCatalog.bundled {
            VStack(alignment: .leading, spacing: Spacing.md) {
                let selection = "사진의 ‘\(analysis.disease.label)’ 분류에 연결한 자료예요."
                if let advice = catalog.care[analysis.disease.label] { card("일상 관리", advice, reason: selection) }
                if let advice = catalog.diet[analysis.disease.label] {
                    card("식습관 메모", advice, reason: selection + " 설문에는 식사 기록이 없어요.")
                } else if let general = catalog.diet["general"] {
                    card("식습관 메모", general, reason: "이 분류에는 별도의 식습관 자료가 없어 일반 식생활 지침을 표시해요.", source: "세계보건기구 자료")
                }
                NavigationLink("식습관 자료 더 보기") {
                    SkinKnowledgeView(query: catalog.diet[analysis.disease.label] == nil ? "균형 식단" : analysis.disease.label + " 식습관")
                }
                Text("추천 성분이 든 제품 예시").appText(.title)
                let names = analysis.recommendation?.ingredients?.map(\.name) ?? []
                let matches = catalog.matched(names, avoiding: analysis.survey?.avoidIngredients)
                if matches.isEmpty {
                    Text(analysis.survey?.avoidIngredients == nil ? "이 기록에는 회피 성분 응답이 없어 제품을 표시하지 않아요." : "추천 성분과 회피 조건을 함께 확인한 제품이 없어요.")
                }
                ForEach(matches, id: \.name) { product in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(product.name).bold()
                        let matched = product.matches.filter { names.map(catalog.key).contains($0) }
                        Text("일치한 추천 성분 · " + matched.joined(separator: ", "))
                        Text("제조사 표기 · " + matched.compactMap { product.labelNames[$0] }.joined(separator: " / "))
                        if let avoid = analysis.survey?.avoidIngredients {
                            Text(avoid.isEmpty ? "설문에 등록한 회피 성분이 없어요." : "성분표에서 제외를 확인한 설문 성분 · " + avoid.joined(separator: ", "))
                        }
                        Text(product.category + " · 구매 전 국내 포장의 전성분을 확인해 주세요.")
                        Link("제조사 성분표", destination: product.source)
                        NavigationLink("제품 라벨 검색") { SkinKnowledgeView(query: product.name, kind: "label") }
                    }
                }
            }
        }
    }
    private func card(_ title: String, _ advice: CareCatalog.Advice, reason: String, source: String = "미국피부과학회 자료") -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline)
            Text(advice.body)
            Text(reason).font(.footnote)
            Link(source, destination: advice.source)
        }
    }
}
