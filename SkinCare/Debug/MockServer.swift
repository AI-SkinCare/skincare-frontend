#if DEBUG
import Foundation

/// `-MockAPI` 실행 시 백엔드 대신 응답한다. 응답 형식은 API 명세 §3·§4 예시를 따른다.
final class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, body) = MockServer.respond(to: request)
        // 로딩 상태가 보이도록 약간 지연 (URL 로딩 스레드에서 실행되므로 블로킹해도 무방)
        Thread.sleep(forTimeInterval: request.url?.path().hasSuffix("/analyses") == true && request.httpMethod == "POST" ? 1.5 : 0.25)
        guard let url = request.url else { return }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json", "X-Request-Id": "mock-\(UUID().uuidString)"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

enum MockData {
    static let doneID = "01MOCKDONE000000000000000A"
    static let demoID = "01MOCKDEMO000000000000000B"
    static let queuedID = "01MOCKQUEUED00000000000000"
    static let recommendingID = "01MOCKRECOMMENDING00000000"
    static let failedID = "01MOCKFAILED00000000000000"
    static let submittedID = "01MOCKNEW00000000000000000"
}

private enum MockServer {
    nonisolated(unsafe) static var submittedAt = Date()

    static func respond(to request: URLRequest) -> (Int, Data) {
        let path = request.url?.path().replacingOccurrences(of: "/api/v1", with: "") ?? ""
        let method = request.httpMethod ?? "GET"
        let parts = path.split(separator: "/").map(String.init)
        let route = "\(method) " + parts.enumerated().map { index, part in
            // 분석 ID 자리는 {id}로 바꿔서 분기
            index == 1 && parts.first == "analyses" ? "{id}" : part
        }.joined(separator: "/")
        let id = parts.count > 1 ? parts[1] : ""

        switch route {
        case "POST auth/login", "POST auth/refresh":
            return ok(authSession)
        case "POST auth/signup":
            return ok(["userId": 42], status: 201)
        case "POST auth/logout", "DELETE users/me", "DELETE analyses/{id}":
            return (204, Data())
        case "GET users/me":
            return ok(["id": 42, "email": "dohee@example.com", "nickname": "도희",
                       "createdAt": "2026-09-28T02:11:00Z", "analysisCount": 6])
        case "GET system/status":
            return ok(["aiAvailable": !DebugLaunch.mockAIDown, "queueLength": 2, "estimatedWaitSec": 110,
                       "checkedAt": iso(Date())])
        case "GET analyses":
            return ok(analysisList)
        case "POST analyses":
            submittedAt = Date()
            return ok(["analysisId": MockData.submittedID, "status": "queued", "queuePosition": 2, "estimatedWaitSec": 110], status: 202)
        case "POST analyses/{id}/recommendation/retry":
            submittedAt = Date()
            return ok(["analysisId": MockData.submittedID, "status": "queued", "queuePosition": 1, "estimatedWaitSec": 55], status: 202)
        case "GET analyses/{id}/trend":
            return ok(trend(id: id))
        case "GET analyses/{id}":
            return ok(detail(id: id))
        default:
            return (404, json(["success": false, "error": ["code": "E4003", "message": "결과를 찾을 수 없어요."]]))
        }
    }

    // MARK: - 응답 데이터

    private static var authSession: [String: Any] {
        [
            "accessToken": "mock-access", "expiresIn": 3600,
            "user": ["id": 42, "email": "dohee@example.com", "nickname": "도희"],
        ]
    }

    private static var analysisList: [String: Any] {
        if DebugLaunch.mockEmpty {
            return ["items": [], "page": ["page": 1, "size": 20, "totalItems": 0, "totalPages": 0]]
        }
        let day: TimeInterval = 86_400
        let items: [[String: Any]] = [
            item(MockData.doneID, Date().addingTimeInterval(-3_600), "done", 68, false, ["pore", "pigmentation"]),
            item(MockData.queuedID, Date().addingTimeInterval(-day * 3), "queued", 64, false, ["dryness"]),
            item(MockData.failedID, Date().addingTimeInterval(-day * 9), "failed", 59, false, ["pore"]),
            item(MockData.demoID, Date().addingTimeInterval(-day * 16), "done", 61, true, ["wrinkle", "sagging"]),
            item("01MOCKOLD1000000000000000", Date().addingTimeInterval(-day * 24), "done", 55, false, ["acne"]),
            item("01MOCKOLD2000000000000000", Date().addingTimeInterval(-day * 31), "done", 47, false, ["redness", "sensitivity"]),
        ]
        return ["items": items, "page": ["page": 1, "size": 20, "totalItems": items.count, "totalPages": 1]]
    }

    private static func item(_ id: String, _ date: Date, _ status: String, _ score: Int, _ demo: Bool, _ concerns: [String]) -> [String: Any] {
        ["analysisId": id, "createdAt": iso(date), "status": status, "overallScore": score, "isDemo": demo, "concerns": concerns]
    }

    private static func detail(id: String) -> [String: Any] {
        var status = "done"
        var created = Date().addingTimeInterval(-3_600)
        switch id {
        case MockData.queuedID: status = "queued"; created = Date().addingTimeInterval(-20)
        case MockData.recommendingID: status = "recommending"; created = Date().addingTimeInterval(-40)
        case MockData.failedID: status = "failed"
        case MockData.submittedID:
            created = submittedAt
            let elapsed = Date().timeIntervalSince(submittedAt)
            status = elapsed < 8 ? "queued" : elapsed < 16 ? "recommending" : "done"
        default: break
        }
        let isDemo = id == MockData.demoID

        var body: [String: Any] = [
            "analysisId": id, "status": status, "createdAt": iso(created),
            "completedAt": status == "done" ? iso(created.addingTimeInterval(58)) : NSNull(),
            "deviceType": "smartphone",
            "queuePosition": status == "queued" ? 2 : NSNull(),
            "estimatedWaitSec": status == "queued" ? 110 : NSNull(),
            "measurement": measurement(isDemo: isDemo),
            "survey": [
                "gender": "female", "ageBand": "20s", "skinType": "combination", "sleepHours": 6,
                "waterIntakeLevel": "low", "sunExposureLevel": "high", "stressLevel": "medium",
                "concerns": ["pore", "pigmentation"], "currentProducts": ["토너", "수분크림"], "note": "여름에 번들거림이 심해요",
            ],
            "error": NSNull(),
        ]
        switch status {
        case "done": body["recommendation"] = recommendation
        case "failed":
            body["recommendation"] = ["status": "failed"]
            body["error"] = ["code": "E3002", "message": "추천 생성 시간이 초과됐어요."]
        default: body["recommendation"] = ["status": "pending"]
        }
        return body
    }

    private static func measurement(isDemo: Bool) -> [String: Any] {
        [
            "isDemo": isDemo, "confidence": 0.87, "calibrationApplied": !isDemo, "overallScore": 68,
            "summary": [
                ["metric": "moisture", "value": 61, "score": 61, "grade": "normal"],
                ["metric": "elasticity", "value": 78, "score": 78, "grade": "good"],
                ["metric": "pigmentation", "value": 28, "score": 72, "grade": "good"],
                ["metric": "pore", "value": 63, "score": 37, "grade": "care"],
            ],
            "byRoi": isDemo ? [] : [
                roi("forehead", 58, 71, 35, 51, 61, "normal"),
                roi("glabella", 63, 75, 30, 56, 63, "normal"),
                roi("cheek_left", 66, 82, 24, 38, 72, "good"),
                roi("cheek_right", 64, 80, 26, 41, 69, "normal"),
                roi("chin", 52, 74, 33, 72, 55, "normal"),
                roi("eye_left", 49, 66, 29, 20, 67, "normal"),
            ],
            "modelVersion": isDemo ? "stub" : "skin_reg_v1",
        ]
    }

    private static func roi(_ name: String, _ m: Int, _ e: Int, _ p: Int, _ o: Int, _ score: Int, _ grade: String) -> [String: Any] {
        ["roi": name, "moisture": m, "elasticity": e, "pigmentation": p, "pore": o, "overallScore": score, "grade": grade]
    }

    private static var recommendation: [String: Any] { [
        "status": "done",
        "skinType": ["code": "combination", "label": "복합성"],
        "concerns": [["code": "pore", "label": "모공"], ["code": "pigmentation", "label": "미백(색소침착/기미/칙칙함)"]],
        "ingredients": [
            ["name": "나이아신아마이드", "purpose": "피지 분비와 모공 관리에 도움을 줄 수 있어요.", "priority": 1],
            ["name": "판테놀", "purpose": "피부 장벽을 지키는 데 도움을 줄 수 있어요.", "priority": 2],
            ["name": "알로에신", "purpose": "칙칙한 피부 톤 관리에 도움을 줄 수 있어요.", "priority": 3],
            ["name": "히알루론산", "purpose": NSNull(), "priority": 4],
        ],
        "routine": [
            ["step": 1, "time": "morning", "action": "약산성 클렌저로 가볍게 세안해요."],
            ["step": 2, "time": "morning", "action": "가벼운 수분 토너로 결을 정돈해요."],
            ["step": 3, "time": "daily", "action": "나이아신아마이드 세럼을 얇게 펴 발라요."],
            ["step": 4, "time": "morning", "action": "자외선 차단제를 충분히 발라요."],
            ["step": 1, "time": "evening", "action": "저자극 클렌징으로 노폐물을 씻어내요."],
            ["step": 2, "time": "evening", "action": "판테놀 크림으로 마무리해요."],
            ["step": 1, "time": "weekly", "action": "주 1–2회 각질 관리를 해요."],
        ],
        "reasoning": [
            "복합성 피부로 T존의 피지 분비가 많아 모공이 도드라져 보일 수 있어요. 자외선 노출이 많은 생활 습관은 피부 톤이 칙칙해지는 데 영향을 줄 수 있어요. 수분 섭취가 적은 편이라 볼 쪽은 건조함을 느끼기 쉬워요.",
            "나이아신아마이드는 피지 분비와 모공 관리에 도움을 줄 수 있어요. 판테놀은 피부 장벽을 지키는 데 도움을 줄 수 있고, 알로에신은 칙칙한 톤을 관리하는 데 쓰이는 성분이에요.",
            "아침에는 약산성 클렌저로 세안한 뒤 자외선 차단제를 꼭 바르고, 저녁에는 세럼과 크림으로 마무리해 주세요. 하루 물 섭취를 조금 늘리면 피부가 덜 당길 수 있어요.",
        ],
        "answer": "복합성 피부에 모공과 톤이 고민이라면 피지 관리와 자외선 차단을 함께 챙기는 게 좋아요. 나이아신아마이드 세럼을 중심으로 가벼운 보습 루틴을 추천해요. 꾸준히 사용해 보세요.",
        "inputNotes": ["나이는 연령대(20s) 중간값 25세로 추정", "수면 시간 6시간으로 입력됨"],
        "disclaimer": AppCopy.disclaimer,
        "filtered": false, "usedFallback": false, "modelVersion": "rec_sllm_v2",
    ] }

    private static func trend(id: String) -> [String: Any] {
        [
            "current": ["analysisId": id, "date": "2026-10-10", "overallScore": 68,
                        "summary": ["moisture": 61, "elasticity": 78, "pigmentation": 28, "pore": 63]],
            "previous": ["analysisId": MockData.queuedID, "date": "2026-10-07", "overallScore": 64,
                         "summary": ["moisture": 54, "elasticity": 78, "pigmentation": 31, "pore": 60]],
            "delta": ["overallScore": 4, "moisture": 7, "elasticity": 0, "pigmentation": -3, "pore": 3],
        ]
    }

    // MARK: - 유틸

    private static func ok(_ data: Any, status: Int = 200) -> (Int, Data) {
        (status, json(["success": true, "data": data]))
    }

    private static func json(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    private static func iso(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle())
    }
}
#endif
