import SwiftUI

/// 측정 흐름 컨테이너. 탭을 가리는 전체 화면, 상단 "닫기"로 홈에 돌아간다 (화면 설계서 §1).
struct CaptureFlowView: View {
    @Environment(\.api) private var api
    @State private var model = CaptureFlowModel(
        startsWithGuide: !UserDefaults.standard.bool(forKey: LocalSettings.hideCaptureGuideKey)
    )

    var body: some View {
        NavigationStack(path: $model.path) {
            Group {
                if model.startsWithGuide {
                    CaptureGuideView { model.path.append(.capture) }
                } else {
                    CaptureView()
                }
            }
            .navigationDestination(for: CaptureFlowModel.Step.self) { step in
                switch step {
                case .capture: CaptureView()
                case .survey: SurveyView()
                }
            }
        }
        .environment(model)
        .overlay {
            if model.isSubmitting { MeasuringOverlay() }
        }
        .alert($model.alert)
        .task { await model.loadInitial(api: api) }
    }
}

extension View {
    /// 측정 흐름 각 화면의 "닫기" 버튼
    func captureCloseButton() -> some View {
        modifier(CaptureCloseButton())
    }
}

private struct CaptureCloseButton: ViewModifier {
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { router.isCaptureFlowPresented = false }
                    .foregroundStyle(.ink)
            }
        }
    }
}

// MARK: - SCR-04 촬영 가이드 (FR-CAP-01)

struct CaptureGuideView: View {
    let onNext: () -> Void
    @AppStorage(LocalSettings.hideCaptureGuideKey) private var hidesGuide = false

    private let rules: [(icon: String, title: String, detail: String)] = [
        ("face.smiling", "정면을 봐 주세요", "얼굴 전체가 화면 가운데에 오도록 찍어요."),
        ("sun.max", "자연광에서 찍어 주세요", "그늘이나 역광은 피하고 밝은 곳에서 찍어요."),
        ("eyeglasses", "화장과 안경은 벗어 주세요", "맨 얼굴일 때 더 정확하게 측정돼요."),
        ("comb", "앞머리를 정리해 주세요", "이마가 가려지지 않게 넘겨 주세요."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("이렇게 찍어 주세요.")
                .appText(.heading4)
                .foregroundStyle(.ink)

            VStack(spacing: Spacing.sm) {
                ForEach(rules, id: \.title) { rule in
                    HStack(spacing: Spacing.md) {
                        Image(systemName: rule.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(.ink)
                            .frame(width: 48, height: 48)
                            .background(Color.canvasSoft, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(rule.title).appText(.link).foregroundStyle(.ink)
                            Text(rule.detail).appText(.bodySmall).foregroundStyle(.textMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .card(.outlined, padding: Spacing.md, radius: Radius.sm)
                    .accessibilityElement(children: .combine)
                }
            }

            Spacer()

            Toggle("다음부터 보지 않기", isOn: $hidesGuide)
                .appText(.bodySmall)
                .foregroundStyle(.ink)
                .tint(.ink)

            Button("다음", action: onNext)
                .buttonStyle(.primary)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.md)
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .captureCloseButton()
    }
}

// MARK: - SCR-07 측정 중

struct MeasuringOverlay: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .controlSize(.large)
                .tint(.ink)
            Text("피부 상태를 측정하고 있어요")
                .appText(.title)
                .foregroundStyle(.ink)
            Text("잠시만 기다려 주세요.")
                .appText(.bodySmall)
                .foregroundStyle(.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas.opacity(0.97))
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
