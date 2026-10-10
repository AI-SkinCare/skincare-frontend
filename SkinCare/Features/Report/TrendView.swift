import SwiftUI

/// SCR-11 추이 비교 (FR-HIS-02). 좋아짐은 초록 ▲, 나빠짐은 주황 ▼.
/// delta는 원래 값의 차이라 색소침착·모공은 값이 줄면 좋아진 것이다 (API §4.5).
struct TrendView: View {
    let analysisID: String
    @Environment(\.api) private var api
    @State private var trend: Trend?
    @State private var errorMessage: String?

    private let metrics: [Metric] = [.moisture, .elasticity, .pigmentation, .pore]

    var body: some View {
        Group {
            if let trend {
                content(trend)
            } else if let errorMessage {
                ErrorStateView(message: errorMessage) { Task { await load() } }
            } else {
                LoadingStateView()
            }
        }
        .background(Color.canvas)
        .navigationTitle("이전 측정과 비교")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            trend = try await api.send(AnalysisAPI.trend(id: analysisID))
            errorMessage = nil
        } catch {
            errorMessage = error.userMessage
        }
    }

    @ViewBuilder
    private func content(_ trend: Trend) -> some View {
        if let previous = trend.previous, let delta = trend.delta {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack {
                        legend(color: .textFaint, title: "이전 \(Formatting.apiDate(previous.date))")
                        legend(color: .ink, title: "현재 \(Formatting.apiDate(trend.current.date))")
                    }
                    TrendRow(title: "종합 점수", previous: previous.overallScore, current: trend.current.overallScore,
                             delta: delta.overallScore, lowerIsBetter: false)
                    ForEach(metrics, id: \.self) { metric in
                        TrendRow(title: metric.displayName, previous: previous.summary[metric],
                                 current: trend.current.summary[metric], delta: delta[metric],
                                 lowerIsBetter: metric.lowerIsBetter)
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.lg)
            }
        } else {
            Text("비교할 이전 측정이 없습니다.")
                .appText(.body)
                .foregroundStyle(.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func legend(color: Color, title: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Capsule().fill(color).frame(width: 16, height: 6)
            Text(title).appText(.caption).foregroundStyle(.textMuted)
        }
    }
}

private struct TrendRow: View {
    let title: String
    let previous: Int
    let current: Int
    let delta: Int
    let lowerIsBetter: Bool

    private var improved: Bool? {
        guard delta != 0 else { return nil }
        return lowerIsBetter ? delta < 0 : delta > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(title).appText(.link).foregroundStyle(.ink)
                if lowerIsBetter {
                    Text("낮을수록 좋아요").appText(.caption).foregroundStyle(.textMuted)
                }
                Spacer()
                change
            }
            bar(value: previous, color: .textFaint)
            bar(value: current, color: .ink)
        }
        .card(.outlined, padding: Spacing.md, radius: Radius.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("이전 \(previous), 현재 \(current), \(changeDescription)")
    }

    @ViewBuilder
    private var change: some View {
        switch improved {
        case .some(true):
            Text("▲ \(abs(delta))").appText(.label).foregroundStyle(.gradeGood)
        case .some(false):
            Text("▼ \(abs(delta))").appText(.label).foregroundStyle(.gradeCare)
        case .none:
            Text("변화 없음").appText(.label).foregroundStyle(.textMuted)
        }
    }

    private var changeDescription: String {
        switch improved {
        case .some(true): "\(abs(delta)) 좋아짐"
        case .some(false): "\(abs(delta)) 나빠짐"
        case .none: "변화 없음"
        }
    }

    private func bar(value: Int, color: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.canvasSoft)
                    Capsule().fill(color).frame(width: proxy.size.width * CGFloat(min(max(value, 0), 100)) / 100)
                }
            }
            .frame(height: 8)
            Text("\(value)").appText(.caption).foregroundStyle(.textMuted).frame(width: 28, alignment: .trailing)
        }
    }
}
