#if DEBUG
import Foundation

/// `-MockAPI` 실행 시 백엔드 대신 응답한다. 응답 형식은 docs/new_common/api변경사항.md §1을 따른다.
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
    static let completedID = "01MOCKCOMPLETED00000000000"
    static let queuedID = "01MOCKQUEUED00000000000000"
    static let generatingID = "01MOCKGENERATING0000000000"
    static let uncertainID = "01MOCKUNCERTAIN00000000000"
    static let noConcernID = "01MOCKNOCONCERN00000000000"
    static let failedID = "01MOCKFAILED00000000000000"
    static let submittedID = "01MOCKNEW00000000000000000"
}

private enum MockServer {
    nonisolated(unsafe) static var submittedAt = Date()
    nonisolated(unsafe) static var retriedAt: Date?

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
            return ok(["aiAvailable": !DebugLaunch.mockAIDown, "queueLength": 2, "estimatedWaitSec": 90,
                       "checkedAt": iso(Date())])
        case "GET analyses":
            return ok(analysisList)
        case "POST analyses":
            submittedAt = Date()
            return ok(analysisView(id: MockData.submittedID), status: 202)
        case "POST analyses/{id}/recommendation/retry":
            guard id == MockData.failedID else {
                return (409, json(["success": false, "error": ["code": "E4005", "message": "지금은 다시 요청할 수 없어요."]]))
            }
            retriedAt = Date()
            return ok(analysisView(id: id), status: 202)
        case "GET analyses/{id}":
            return ok(analysisView(id: id))
        default:
            return (404, json(["success": false, "error": ["code": "E4003", "message": "결과를 찾을 수 없어요."]]))
        }
    }

    // MARK: - 응답 데이터

    private static var authSession: [String: Any] {
        [
            "accessToken": "mock-access", "expiresIn": 3600, "refreshToken": "mock-refresh",
            "user": ["id": 42, "email": "dohee@example.com", "nickname": "도희"],
        ]
    }

    private static let classes = ["건선", "아토피", "여드름", "정상", "주사", "지루"]
    private static let classesEn = ["psoriasis", "atopic", "acne", "normal", "rosacea", "seborrheic"]

    private static func disease(_ label: String, _ confidence: Double) -> [String: Any] {
        let rest = (1 - confidence) / 5
        var probabilities: [String: Double] = [:]
        for name in classes { probabilities[name] = name == label ? confidence : rest }
        let index = classes.firstIndex(of: label) ?? 0
        return [
            "label": label, "labelEn": classesEn[index], "confidence": confidence, "uncertain": confidence < 0.6,
            "probabilities": probabilities, "modelVersion": "densenet121_s2_3ea9506", "inferenceMs": 45,
        ]
    }

    private static var analysisList: [String: Any] {
        if DebugLaunch.mockEmpty {
            return ["items": [], "page": ["page": 1, "size": 20, "totalItems": 0, "totalPages": 0]]
        }
        let day: TimeInterval = 86_400
        let items: [[String: Any]] = [
            item(MockData.completedID, Date().addingTimeInterval(-3_600), "COMPLETED", "generated", disease("아토피", 0.9), ["sensitivity"]),
            item(MockData.generatingID, Date().addingTimeInterval(-day * 2), "GENERATING", nil, disease("여드름", 0.82), []),
            item(MockData.noConcernID, Date().addingTimeInterval(-day * 6), "WITHHELD", "no_concern", disease("정상", 0.9), []),
            item(MockData.uncertainID, Date().addingTimeInterval(-day * 12), "WITHHELD", "uncertain", disease("아토피", 0.55), []),
            item(MockData.failedID, Date().addingTimeInterval(-day * 20), "FAILED", nil, disease("주사", 0.78), []),
            item("01MOCKOLD1000000000000000", Date().addingTimeInterval(-day * 33), "COMPLETED", "generated",
                 disease("지루", 0.71), ["sensitivity", "dryness"]),
        ]
        return ["items": items, "page": ["page": 1, "size": 20, "totalItems": items.count, "totalPages": 1]]
    }

    private static func item(_ id: String, _ date: Date, _ status: String, _ recommendationStatus: String?,
                             _ disease: [String: Any], _ concerns: [String]) -> [String: Any] {
        ["analysisId": id, "createdAt": iso(date), "status": status,
         "recommendationStatus": recommendationStatus ?? NSNull(), "disease": disease, "concerns": concerns]
    }

    /// 분석별 상태. 새로 제출한 분석은 QUEUED(5초) → GENERATING(12초) → COMPLETED로 진행한다.
    private static func analysisView(id: String) -> [String: Any] {
        var status = "COMPLETED"
        var created = Date().addingTimeInterval(-3_600)
        var classification = disease("아토피", 0.9)

        switch id {
        case MockData.queuedID: status = "QUEUED"; created = Date().addingTimeInterval(-20)
        case MockData.generatingID: status = "GENERATING"; created = Date().addingTimeInterval(-40); classification = disease("여드름", 0.82)
        case MockData.uncertainID: status = "WITHHELD"; classification = disease("아토피", 0.55)
        case MockData.noConcernID: status = "WITHHELD"; classification = disease("정상", 0.9)
        case MockData.failedID:
            classification = disease("주사", 0.78)
            if let retriedAt {
                let elapsed = Date().timeIntervalSince(retriedAt)
                status = elapsed < 3 ? "QUEUED" : elapsed < 8 ? "GENERATING" : "COMPLETED"
                created = retriedAt
            } else {
                status = "FAILED"
            }
        case MockData.submittedID:
            created = submittedAt
            let elapsed = Date().timeIntervalSince(submittedAt)
            status = elapsed < 5 ? "QUEUED" : elapsed < 12 ? "GENERATING" : "COMPLETED"
        default: break
        }

        let isFinal = ["COMPLETED", "WITHHELD", "FAILED"].contains(status)
        var recommendationStatus: Any = NSNull()
        switch (status, id) {
        case ("COMPLETED", _): recommendationStatus = "generated"
        case ("WITHHELD", MockData.noConcernID): recommendationStatus = "no_concern"
        case ("WITHHELD", _): recommendationStatus = "uncertain"
        default: break
        }

        return [
            "analysisId": id,
            "status": status,
            "disease": classification,
            "recommendationStatus": recommendationStatus,
            "recommendation": status == "COMPLETED" ? recommendation : NSNull(),
            "guidance": ["COMPLETED", "WITHHELD"].contains(status) ? guidance : [],
            "error": status == "FAILED" ? ["code": "E3002", "message": "추천 생성 시간이 초과됐어요. 다시 요청해 주세요."] : NSNull(),
            "queuePosition": status == "QUEUED" ? 2 : NSNull(),
            "estimatedWaitSec": status == "QUEUED" ? 90 : NSNull(),
            "createdAt": iso(created),
            "completedAt": isFinal ? iso(created.addingTimeInterval(48)) : NSNull(),
            "survey": [
                "gender": "female", "ageBand": "20s", "skinType": "dry", "sleepHours": 6,
                "waterIntakeLevel": "low", "sunExposureLevel": "high", "stressLevel": "medium",
                "concerns": ["sensitivity"], "currentProducts": ["토너", "수분크림"], "note": "볼이 자주 붉어지고 당겨요",
            ],
        ]
    }

    private static let guidance = [
        "이미지 모델의 6종 분류 참고 결과이며 의학적 진단이 아닙니다. 분류 점수만으로 다른 질환을 배제할 수 없습니다.",
        "성분 추천은 화장품 수준의 보조 관리 정보입니다. 질환 확인과 치료는 피부과 전문의와 상담하세요.",
    ]

    private static var recommendation: [String: Any] {
        [
            "skinType": ["code": "dry", "label": "건성"],
            "concerns": [["code": "sensitivity", "label": "민감성(트러블/자극감)"]],
            "ingredients": [
                ["name": "쑥잎 추출물", "purpose": "예민해진 피부를 진정시키는 데 도움을 줄 수 있어요.", "priority": 1],
                ["name": "판테놀", "purpose": "피부 장벽을 지키는 데 도움을 줄 수 있어요.", "priority": 2],
                ["name": "세라마이드", "purpose": "수분이 빠져나가지 않게 잡아 주는 데 도움을 줄 수 있어요.", "priority": 3],
                ["name": "대나무추출물", "purpose": NSNull(), "priority": 4],
            ],
            "routine": [
                ["step": 1, "time": "morning", "action": "미온수로 가볍게 세안해요."],
                ["step": 2, "time": "daily", "action": "향료가 적은 진정 토너로 결을 정돈해요."],
                ["step": 3, "time": "morning", "action": "자극이 적은 자외선 차단제를 발라요."],
                ["step": 1, "time": "evening", "action": "저자극 클렌저로 부드럽게 씻어내요."],
                ["step": 2, "time": "evening", "action": "세라마이드 크림으로 보습을 마무리해요."],
                ["step": 1, "time": "anytime", "action": "뜨거운 물과 강한 각질 제거는 피해요."],
            ],
            "reasoning": [
                "건성 피부에 민감함을 고민으로 골라 주셨어요. 수분 섭취가 적고 자외선 노출이 많은 편이라 피부가 쉽게 당기고 예민해질 수 있어요.",
                "쑥잎 추출물과 판테놀은 예민해진 피부를 진정시키고 장벽을 지키는 데 쓰이는 성분이에요. 세라마이드는 보습을 오래 유지하는 데 도움을 줄 수 있어요.",
                "아침에는 자극이 적은 자외선 차단제를, 저녁에는 보습 크림으로 마무리해 주세요. 새 제품은 팔 안쪽에 먼저 발라 보고 사용하는 것이 좋아요.",
            ],
            "answer": "건성이면서 민감함이 고민이라면 진정과 보습을 함께 챙기는 게 좋아요. 쑥잎 추출물과 판테놀이 들어간 순한 제품으로 루틴을 단순하게 유지해 보세요. 자외선 차단도 잊지 마세요.",
            "inputNotes": ["나이는 연령대(20s) 중간값 25세로 추정"],
            "disclaimer": AppCopy.disclaimer,
            "filtered": true, "usedFallback": false, "modelVersion": "rec_sllm_v2", "inferenceMs": 47_038,
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
