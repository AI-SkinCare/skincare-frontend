import SwiftUI

/// 분류 라벨(질환명) 타일. 라벨은 모두 3글자 이하라 그대로 넣는다. 불확실하면 흐리게.
struct DiseaseTile: View {
    let disease: Disease
    var size: CGFloat = 56

    var body: some View {
        Text(disease.label)
            .font(Font.custom("Pretendard-Bold", size: size * 0.27))
            .foregroundStyle(disease.uncertain ? .textMuted : .ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 4)
            .frame(width: size, height: size)
            .background(Color.canvasSoft, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// 이력·홈 카드의 상태 한 줄 (진행 중·보류·실패). 완료면 추천 고민 칩.
struct AnalysisStatusLine: View {
    let status: AnalysisStatus
    let recommendationStatus: RecommendationStatus?
    let concerns: [Concern]

    var body: some View {
        if let line = AnalysisDisplay.statusLine(status: status, recommendation: recommendationStatus) {
            HStack(spacing: 6) {
                if line.tone == .progress { ProgressView().controlSize(.mini).tint(.ink) }
                Text(line.text)
                    .appText(.caption)
                    .foregroundStyle(line.tone == .negative ? .negative : line.tone == .progress ? .ink : .textMuted)
            }
        } else if !concerns.filter({ $0 != .unknown }).isEmpty {
            Text(concerns.filter { $0 != .unknown }.map(\.displayLabel).joined(separator: " · "))
                .appText(.caption)
                .foregroundStyle(.textMuted)
                .lineLimit(1)
        }
    }
}
