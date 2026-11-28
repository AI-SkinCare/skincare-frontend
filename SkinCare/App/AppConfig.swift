import Foundation

/// 빌드 설정(Config/*.xcconfig → Info.plist)에서 읽는 값.
enum AppConfig {
    static let apiBaseURL: URL = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              !raw.isEmpty,
              let url = URL(string: raw) else {
            fatalError("Info.plist에 APIBaseURL이 없습니다. Config/*.xcconfig의 API_BASE_URL을 확인하세요.")
        }
        return url
    }()

    /// 비어 있으면 nil — 마이페이지에서 "준비 중"으로 표시한다.
    static let privacyPolicyURL: URL? = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "PrivacyPolicyURL") as? String,
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }()
}
