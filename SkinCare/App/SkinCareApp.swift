import SwiftUI

@main
struct SkinCareApp: App {
    @State private var session = SessionStore(api: APIClient())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(\.api, session.api)
                .tint(.ink)
        }
    }
}

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            switch session.state {
            case .launching:
                SplashView()
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                MainTabView()
            }
        }
        .background(Color.canvas)
        .animation(.default, value: session.state)
        .task { await session.restore() }
        .task { await session.observeSessionExpiry() }
    }
}

private struct SplashView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Text("스킨케어")
                .appText(.heading3)
                .foregroundStyle(.ink)
            ProgressView().tint(.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 환경값

private struct APIClientKey: EnvironmentKey {
    /// 앱에서는 항상 RootView가 SessionStore의 클라이언트를 주입한다. 기본값은 미리보기용.
    static let defaultValue = APIClient()
}

extension EnvironmentValues {
    var api: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
