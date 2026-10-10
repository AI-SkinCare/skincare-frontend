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
        .toolbar(.hidden, for: .tabBar)
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
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    overall(previous: previous, current: trend.current, delta: delta.overallScore)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            SectionTitle(title: "지표별 변화")
                            legend(color: .hairline, title: "이전")
                            legend(color: .ink, title: "현재")
                        }
                        ForEach(metrics, id: \.self) { metric in
                            TrendRow(title: metric.displayName, previous: previous.summary[metric],
                                     current: trend.current.summary[metric], delta: delta[metric],
                                     lowerIsBetter: metric.lowerIsBetter)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
            }
        } else {
            EmptyStateView(systemImage: "chart.line.uptrend.xyaxis", title: "비교할 이전 측정이 없습니다.",
                           message: "측정을 한 번 더 하면 변화를 볼 수 있어요.")
                .frame(maxHeight: .infinity)
        }
    }

    private func overall(previous: TrendPoint, current: TrendPoint, delta: Int) -> some View {
        VStack(spacing: Spacing.md) {
            Text("\(Formatting.apiDate(previous.date)) → \(Formatting.apiDate(current.date))")
                .appText(.bodySmall)
                .foregroundStyle(.textMuted)
            HStack(alignment: .center, spacing: Spacing.lg) {
                scoreColumn(title: "이전", score: previous.overallScore, isCurrent: false)
                Image(systemName: "arrow.right").font(.system(size: 18, weight: .medium)).foregroundStyle(.textFaint)
                scoreColumn(title: "현재", score: current.overallScore, isCurrent: true)
            }
            DeltaBadge(delta: delta, lowerIsBetter: false, isLarge: true)
        }
        .frame(maxWidth: .infinity)
        .card(.soft)
        .accessibilityElement(children: .combine)
    }

    private func scoreColumn(title: String, score: Int, isCurrent: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title).appText(.caption).foregroundStyle(.textMuted)
            Text("\(score)")
                .appText(.heading3)
                .foregroundStyle(isCurrent ? .ink : .textFaint)
        }
    }

    private func legend(color: Color, title: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Capsule().fill(color).frame(width: 14, height: 6)
            Text(title).appText(.caption).foregroundStyle(.textMuted)
        }
    }
}

/// 변화량 배지. 좋아짐 ▲ 초록, 나빠짐 ▼ 주황, 변화 없음 회색.
private struct DeltaBadge: View {
    let delta: Int
    let lowerIsBetter: Bool
    var isLarge = false

    private var improved: Bool? {
        guard delta != 0 else { return nil }
        return lowerIsBetter ? delta < 0 : delta > 0
    }

    var body: some View {
        Group {
            switch improved {
            case .some(true): Text("▲ \(abs(delta)) 좋아졌어요").foregroundStyle(.gradeGood)
            case .some(false): Text("▼ \(abs(delta)) 나빠졌어요").foregroundStyle(.gradeCare)
            case .none: Text("변화 없음").foregroundStyle(.textMuted)
            }
        }
        .appText(isLarge ? .link : .label)
    }
}

private struct TrendRow: View {
    let title: String
    let previous: Int
    let current: Int
    let delta: Int
    let lowerIsBetter: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).appText(.link).foregroundStyle(.ink)
                if lowerIsBetter {
                    Text("낮을수록 좋아요").appText(.caption).foregroundStyle(.textFaint)
                }
                Spacer()
                DeltaBadge(delta: delta, lowerIsBetter: lowerIsBetter)
            }
            bar(value: previous, color: .hairline)
            bar(value: current, color: .ink)
        }
        .card(.outlined, padding: Spacing.md, radius: Radius.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("이전 \(previous), 현재 \(current)")
    }

    private func bar(value: Int, color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            ProgressBar(value: value, color: color, height: 8)
            Text("\(value)")
                .appText(.caption)
                .foregroundStyle(color == .ink ? .ink : .textMuted)
                .frame(width: 26, alignment: .trailing)
        }
    }
}
