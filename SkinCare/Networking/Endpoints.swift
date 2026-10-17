import Foundation

// 백엔드 API (docs/new_common/api변경사항.md §1)

enum AuthAPI {
    private struct Credentials: Encodable { let email: String; let password: String }
    private struct RefreshBody: Encodable { let refreshToken: String }

    static func signup(_ body: SignupRequest) -> APIRequest<SignupResponse> {
        APIRequest(method: .post, path: "/auth/signup", body: .encoding(body), requiresAuth: false)
    }

    static func login(email: String, password: String) -> APIRequest<AuthSession> {
        APIRequest(method: .post, path: "/auth/login",
                   body: .encoding(Credentials(email: email, password: password)), requiresAuth: false)
    }

    /// 쿠키 방식이면 본문 없이, 본문 방식(패치 A2)이면 저장된 토큰을 본문으로 보낸다.
    static func refresh(refreshToken: String?) -> APIRequest<AuthSession> {
        APIRequest(method: .post, path: "/auth/refresh",
                   body: refreshToken.map { .encoding(RefreshBody(refreshToken: $0)) } ?? .none,
                   requiresAuth: false)
    }

    static func logout(refreshToken: String?) -> APIRequest<EmptyResponse> {
        APIRequest(method: .post, path: "/auth/logout",
                   body: refreshToken.map { .encoding(RefreshBody(refreshToken: $0)) } ?? .none)
    }
}

enum UsersAPI {
    static func me() -> APIRequest<Me> {
        APIRequest(method: .get, path: "/users/me")
    }

    static func deleteMe() -> APIRequest<EmptyResponse> {
        APIRequest(method: .delete, path: "/users/me")
    }
}

enum AnalysisAPI {
    /// 사진 + 설문 제출 → 이미지 분류 → 추천 대기열 등록. 202 + AnalysisView
    static func submit(imageJPEG: Data, survey: Survey) -> APIRequest<AnalysisView> {
        var form = MultipartFormData()
        form.addFile(name: "image", filename: "face.jpg", mimeType: "image/jpeg", data: imageJPEG)
        let surveyJSON = (try? JSONEncoder().encode(survey.sanitized())).flatMap { String(data: $0, encoding: .utf8) }
        form.addField(name: "survey", value: surveyJSON ?? "{}")
        return APIRequest(method: .post, path: "/analyses", body: .multipart(form))
    }

    static func detail(id: String) -> APIRequest<AnalysisView> {
        APIRequest(method: .get, path: "/analyses/\(id)")
    }

    /// FAILED 분석만 가능. 저장된 분류로 추천만 다시 만든다.
    static func retryRecommendation(id: String) -> APIRequest<AnalysisView> {
        APIRequest(method: .post, path: "/analyses/\(id)/recommendation/retry")
    }

    static func list(page: Int, size: Int = 20) -> APIRequest<AnalysisPage> {
        APIRequest(method: .get, path: "/analyses",
                   queryItems: [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "size", value: "\(size)")])
    }

    static func delete(id: String) -> APIRequest<EmptyResponse> {
        APIRequest(method: .delete, path: "/analyses/\(id)")
    }
}

enum SystemAPI {
    static func status() -> APIRequest<SystemStatus> {
        APIRequest(method: .get, path: "/system/status", requiresAuth: false)
    }
}
