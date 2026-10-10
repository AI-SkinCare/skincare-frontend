import Foundation

/// URLSession으로 요청 한 건을 보내고 `{ success, data, error }`를 풀어준다. 토큰 재발급은 모른다.
struct HTTPTransport: Sendable {
    let baseURL: URL
    let session: URLSession

    func send<Response>(_ request: APIRequest<Response>, accessToken: String?) async throws -> Response {
        let requestID = UUID().uuidString
        let urlRequest = try makeURLRequest(request, accessToken: accessToken, requestID: requestID)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(requestID: requestID)
        }
        let responseID = http.value(forHTTPHeaderField: "X-Request-Id") ?? requestID

        guard (200..<300).contains(http.statusCode) else {
            if let body = try? JSONCoding.decoder().decode(Envelope<EmptyResponse>.self, from: data),
               let error = body.error {
                throw APIError.server(status: http.statusCode, code: error.code,
                                      message: error.message, requestID: responseID)
            }
            throw APIError.invalidResponse(requestID: responseID)
        }

        if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
            return empty
        }
        do {
            let envelope = try JSONCoding.decoder().decode(Envelope<Response>.self, from: data)
            guard let value = envelope.data else { throw APIError.invalidResponse(requestID: responseID) }
            return value
        } catch let error as APIError {
            throw error
        } catch {
            #if DEBUG
            print("[API] 디코딩 실패 \(request.method.rawValue) \(request.path): \(error)")
            #endif
            throw APIError.invalidResponse(requestID: responseID)
        }
    }

    private func makeURLRequest<Response>(
        _ request: APIRequest<Response>, accessToken: String?, requestID: String
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: request.path), resolvingAgainstBaseURL: false)
        if !request.queryItems.isEmpty { components?.queryItems = request.queryItems }
        guard let url = components?.url else { throw APIError.invalidResponse(requestID: requestID) }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(requestID, forHTTPHeaderField: "X-Request-Id")
        urlRequest.setValue("ios", forHTTPHeaderField: "X-Client")
        if let accessToken {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        switch request.body {
        case .none:
            break
        case .json(let data):
            urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = data
        case .multipart(let form):
            urlRequest.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = form.encoded()
        }
        return urlRequest
    }
}

private struct Envelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIErrorBody?
}

enum JSONCoding {
    /// 백엔드 시간은 ISO 8601 UTC. 밀리초가 붙는 경우(`.000Z`)도 받는다.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = try? Date(raw, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(raw, strategy: Date.ISO8601FormatStyle()) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "ISO 8601 날짜가 아님: \(raw)")
        }
        return decoder
    }
}
