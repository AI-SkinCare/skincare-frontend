import SwiftUI

/// 로그인 후 하단 탭: 홈 · 이력 · 마이 (화면 설계서 §1)
struct MainTabView: View {
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack(path: $router.homePath) {
                HomeView().appRouteDestinations()
            }
            .tabItem { Label("홈", systemImage: router.selectedTab == .home ? "house.fill" : "house") }
            .tag(AppTab.home)

            NavigationStack(path: $router.historyPath) {
                HistoryView().appRouteDestinations()
            }
            .tabItem { Label("이력", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(AppTab.history)

            NavigationStack {
                MyPageView()
            }
            .tabItem { Label("마이", systemImage: router.selectedTab == .myPage ? "person.fill" : "person") }
            .tag(AppTab.myPage)
        }
        .environment(router)
        .fullScreenCover(isPresented: $router.isCaptureFlowPresented) {
            CaptureFlowView()
                .environment(router)
        }
        #if DEBUG
        .onAppear { DebugLaunch.applyStartScreen(to: router) }
        #endif
    }
}

extension View {
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .report(let id): ReportView(analysisID: id)
            case .recommendation(let id): RecommendationView(analysisID: id)
            }
        }
    }
}
