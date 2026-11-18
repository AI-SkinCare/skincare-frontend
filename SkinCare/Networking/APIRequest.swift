import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

enum RequestBody: Sendable {
    case none
    case json(Data)
    case multipart(MultipartFormData)

    static func encoding(_ value: some Encodable) -> RequestBody {
        // 앱이 정의한 요청 구조체만 넣으므로 인코딩 실패는 발생하지 않는다.
        .json((try? JSONEncoder().encode(value)) ?? Data())
    }
}

/// 백엔드 API 한 건. 응답 타입은 `{ success, data }`의 `data` 부분.
struct APIRequest<Response: Decodable & Sendable>: Sendable {
    var method: HTTPMethod
    var path: String
    var queryItems: [URLQueryItem] = []
    var body: RequestBody = .none
    var requiresAuth = true
}

/// 204 No Content 등 본문이 없는 응답.
struct EmptyResponse: Decodable, Sendable {}
