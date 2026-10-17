import SwiftUI

/// 촬영 흐름 컨테이너. 탭을 가리는 전체 화면, 상단 "닫기"로 홈에 돌아간다 (화면 설계서 §1).
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
            if model.isSubmitting {
                MeasuringOverlay().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isSubmitting)
        .alert($model.alert)
        .task { await model.loadInitial(api: api) }
        #if DEBUG
        .onAppear { applyDebugStartScreen() }
        #endif
    }

    #if DEBUG
    private func applyDebugStartScreen() {
        switch DebugLaunch.startScreen {
        case .capture, .camera: model.path = model.startsWithGuide ? [.capture] : []
        case .survey: model.path = model.startsWithGuide ? [.capture, .survey] : [.survey]
        default: break
        }
    }
    #endif
}

extension View {
    /// 촬영 흐름 각 화면의 "닫기" 버튼
    func captureCloseButton() -> some View {
        modifier(CaptureCloseButton())
    }
}

private struct CaptureCloseButton: ViewModifier {
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.isCaptureFlowPresented = false } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.ink)
                .accessibilityLabel("닫기")
            }
        }
    }
}

/// 촬영 흐름 단계 표시 (가이드 → 촬영 → 설문)
struct CaptureStepIndicator: View {
    let current: Int
    private let titles = ["촬영", "설문"]

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, _ in
                Capsule()
                    .fill(index <= current ? Color.ink : Color.canvasSoft)
                    .frame(height: 4)
            }
        }
        .animation(.easeOut(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel("\(titles.count)단계 중 \(current + 1)단계, \(titles[min(current, titles.count - 1)])")
    }
}

// MARK: - SCR-04 촬영 가이드 (FR-CAP-01)

struct CaptureGuideView: View {
    let onNext: () -> Void
    @AppStorage(LocalSettings.hideCaptureGuideKey) private var hidesGuide = false

    private let rules: [(icon: String, title: String, detail: String)] = [
        ("person.crop.square", "정면을 봐 주세요", "얼굴 전체가 화면 가운데에 오도록 찍어요."),
        ("sun.max", "자연광에서 찍어 주세요", "그늘이나 역광을 피하고 밝은 곳에서 찍어요."),
        ("eyeglasses", "화장과 안경은 벗어 주세요", "맨얼굴일 때 더 정확하게 분석돼요."),
        ("comb", "앞머리를 넘겨 주세요", "이마가 가려지지 않게 정리해요."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "이렇게 찍어 주세요.", subtitle: "정확한 분석을 위한 네 가지예요.")

                VStack(spacing: 0) {
                    ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                        HStack(spacing: Spacing.md) {
                            Image(systemName: rule.icon)
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(.ink)
                                .frame(width: 48, height: 48)
                                .background(Color.canvasSoft, in: Circle())
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.title).appText(.link).foregroundStyle(.ink)
                                Text(rule.detail).appText(.bodySmall).foregroundStyle(.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Spacing.md)
                        .accessibilityElement(children: .combine)
                        if index < rules.count - 1 { Hairline().padding(.leading, 64) }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .card(.outlined, padding: 0)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.xs)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button {
                    hidesGuide.toggle()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: hidesGuide ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(hidesGuide ? .ink : .hairline)
                            .font(.system(size: 18))
                        Text("다음부터 보지 않기").appText(.bodySmall).foregroundStyle(.textMuted)
                        Spacer()
                    }
                    .frame(minHeight: ControlSize.minTouch)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(hidesGuide ? .isSelected : [])

                Button("촬영하러 가기", action: onNext)
                    .buttonStyle(.primary)
            }
        }
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .captureCloseButton()
    }
}

// MARK: - SCR-07 분석 중

struct MeasuringOverlay: View {
    @State private var pulses = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                ForEach(0..<2) { index in
                    Circle()
                        .stroke(Color.hairline, lineWidth: 1)
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulses ? 1.6 : 1)
                        .opacity(pulses ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(Double(index) * 0.9),
                            value: pulses
                        )
                }
                BrandMark(size: 88)
            }
            .frame(height: 200)

            VStack(spacing: Spacing.xs) {
                Text("사진을 분석하고 있어요.")
                    .appText(.title)
                    .foregroundStyle(.ink)
                Text("보통 몇 초면 끝나요. 화면을 닫지 말아 주세요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
            }
            .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas)
        .ignoresSafeArea()
        .onAppear { pulses = true }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
