import Foundation

/// 백엔드 실패 응답 `{ success: false, error: { code, message } }`.
struct APIErrorBody: Decodable, Sendable, Equatable {
    let code: String
    let message: String
}

enum APIError: Error, Sendable {
    /// 백엔드가 에러 코드와 함께 실패를 돌려줌 (API 명세 §1.2)
    case server(status: Int, code: String, message: String, requestID: String?)
    /// 토큰 재발급 실패 — 다시 로그인해야 함
    case sessionExpired
    case network(URLError)
    /// 형식을 알 수 없는 응답
    case invalidResponse(requestID: String?)

    var code: String? {
        if case .server(_, let code, _, _) = self { return code }
        return nil
    }

    /// 화면에 그대로 보여줄 문장. 서버 message는 사용자용 문장이라 그대로 쓴다 (API 명세 §1.1).
    var userMessage: String {
        switch self {
        case .server(_, let code, let message, let requestID):
            return code == "E4001" ? AppCopy.commonError(requestID: requestID) : message
        case .sessionExpired:
            return "로그인이 만료됐어요. 다시 로그인해 주세요."
        case .network:
            return AppCopy.networkError
        case .invalidResponse(let requestID):
            return AppCopy.commonError(requestID: requestID)
        }
    }
}

extension Error {
    var userMessage: String {
        (self as? APIError)?.userMessage ?? AppCopy.commonError(requestID: nil)
    }
}
