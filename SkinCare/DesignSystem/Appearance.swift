import UIKit

/// UIKit 기본 컴포넌트(내비게이션 바, 탭 바, 세그먼트)를 design.md 토큰에 맞춘다. 앱 시작 시 한 번 호출.
enum Appearance {
    @MainActor
    static func apply() {
        let ink = UIColor(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255, alpha: 1)
        let muted = UIColor(red: 0x70 / 255, green: 0x70 / 255, blue: 0x70 / 255, alpha: 1)
        let faint = UIColor(red: 0xAD / 255, green: 0xAD / 255, blue: 0xAD / 255, alpha: 1)

        // 내비게이션 바: 흰 바탕, 구분선 없음, Pretendard
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = .white
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [.font: font("Pretendard-SemiBold", 17), .foregroundColor: ink]
        navigation.largeTitleTextAttributes = [.font: font("Pretendard-Bold", 30), .foregroundColor: ink]
        let backImage = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
        navigation.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        navigation.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = ink

        // 탭 바: 흰 바탕 + hairline, 선택 ink / 비선택 faint
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = .white
        tab.shadowColor = UIColor(red: 0xF0 / 255, green: 0xF0 / 255, blue: 0xF0 / 255, alpha: 1)
        for layout in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            layout.normal.iconColor = faint
            layout.normal.titleTextAttributes = [.font: font("Pretendard-Medium", 11), .foregroundColor: faint]
            layout.selected.iconColor = ink
            layout.selected.titleTextAttributes = [.font: font("Pretendard-SemiBold", 11), .foregroundColor: ink]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: font("Pretendard-SemiBold", 14), .foregroundColor: ink], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.font: font("Pretendard-Medium", 14), .foregroundColor: muted], for: .normal)
    }

    private static func font(_ name: String, _ size: CGFloat) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }
}
