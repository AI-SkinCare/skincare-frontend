import CoreGraphics
import XCTest

final class ProductionSideUITests: XCTestCase {
    private let baseURL = URL(string: "https://skincare.doi2.my/api/v1")!

    @MainActor
    func testProductionSidePhoto() async throws {
        let status = try await request("GET", "/system/status")
        XCTAssertEqual(status["aiAvailable"] as? Bool, true)
        XCTAssertEqual(status["sideCaptureAvailable"] as? Bool, true)
        let random = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let email = "ios-side-\(random.prefix(12))@example.invalid"
        let password = "T\(random.prefix(12))a1!"
        let credentials = ["email": email, "password": password]
        _ = try await request("POST", "/auth/signup", body: [
            "email": email, "password": password, "nickname": "측면검증",
            "agreements": ["terms": true, "privacy": true, "imageProcessing": true, "over14": true]
        ])
        do {
            let session = try await request("POST", "/auth/login", body: credentials)
            let token = try XCTUnwrap(session["accessToken"] as? String)
            try await verifyFlow(email: email, password: password, token: token)
        } catch {
            await cleanUp(credentials)
            throw error
        }
        await cleanUp(credentials)
    }

    @MainActor
    private func verifyFlow(email: String, password: String, token: String) async throws {
        let app = XCUIApplication()
        app.launch()
        let emailField = app.textFields.firstMatch
        try tap(emailField, in: app)
        emailField.typeText(email)
        let passwordField = app.secureTextFields.firstMatch
        try tap(passwordField, in: app)
        passwordField.typeText(password)
        try tap(app.buttons["로그인"], in: app)
        print("PRODUCTION_SIDE_STEP login submitted")
        try tap(app.buttons["피부 분석 시작"], in: app)
        try tap(app.buttons["촬영하러 가기"], in: app)
        let front = app.buttons["정면"].firstMatch
        let side = app.buttons["측면"].firstMatch
        try reveal(side, in: app)
        XCTAssertFalse(front.isSelected)
        XCTAssertFalse(side.isSelected)
        let album = app.buttons["capture-album"].firstMatch
        XCTAssertFalse(album.isEnabled)
        side.tap()
        XCTAssertTrue(side.isSelected)
        try tap(album, in: app)
        try selectPhoto(in: app)
        print("PRODUCTION_SIDE_STEP album photo selected")
        let usePhoto = app.buttons["이 사진 사용"].firstMatch
        try tap(usePhoto, in: app, allowScroll: false)
        try tap(app.buttons["다음"], in: app, allowScroll: false)
        print("PRODUCTION_SIDE_STEP photo validated")

        for value in ["여성", "30대", "건성"] {
            try tap(app.buttons[value], in: app)
        }
        try tap(app.buttons["다음"], in: app)
        try tap(app.buttons["잘 모르겠어요"].firstMatch, in: app)
        let levels = app.buttons.matching(identifier: "모르겠어요")
        for index in 0..<3 {
            try tap(levels.element(boundBy: index), in: app)
        }
        try tap(app.buttons["건조·각질"], in: app)
        try tap(app.buttons.matching(identifier: "없음·잘 모르겠어요").element(boundBy: 1), in: app)
        try tap(app.buttons["분석 시작"], in: app)
        print("PRODUCTION_SIDE_STEP analysis submitted")
        XCTAssertTrue(app.navigationBars["분석 결과"].waitForExistence(timeout: 45))
        let label = app.staticTexts["정상"].firstMatch
        try reveal(label, in: app)
        keepScreenshot(app, name: "ProductionClassification")
        let sideHint = app.staticTexts["측면 사진 · 시험 기능"].firstMatch
        try reveal(sideHint, in: app)
        let more = app.buttons["추천 자세히 보기"].firstMatch
        try reveal(more, in: app, timeout: 155)

        let history = try await request("GET", "/analyses?page=1&size=2", token: token)
        let items = try XCTUnwrap(history["items"] as? [[String: Any]])
        XCTAssertEqual(items.count, 1)
        let id = try XCTUnwrap(items.first?["analysisId"] as? String)
        let detail = try await request("GET", "/analyses/\(id)", token: token)
        let survey = try XCTUnwrap(detail["survey"] as? [String: Any])
        let disease = try XCTUnwrap(detail["disease"] as? [String: Any])
        XCTAssertEqual(survey["captureView"] as? String, "side")
        XCTAssertEqual(survey["gender"] as? String, "female")
        XCTAssertEqual(survey["ageBand"] as? String, "30s")
        XCTAssertEqual(survey["skinType"] as? String, "dry")
        XCTAssertEqual(survey["concerns"] as? [String], ["dryness"])
        XCTAssertEqual(disease["modelVersion"] as? String, "dinov2_linear_875acf74c4")
        XCTAssertEqual(disease["label"] as? String, "정상")
        XCTAssertEqual(detail["status"] as? String, "COMPLETED")
        XCTAssertEqual(detail["recommendationStatus"] as? String, "generated")

        more.tap()
        XCTAssertTrue(app.navigationBars["맞춤 추천"].waitForExistence(timeout: 15))
        try reveal(app.staticTexts["추천 성분"], in: app)
        let recommendation = try XCTUnwrap(detail["recommendation"] as? [String: Any])
        let ingredients = try XCTUnwrap(recommendation["ingredients"] as? [[String: Any]])
        let routine = try XCTUnwrap(recommendation["routine"] as? [[String: Any]])
        let names = try ingredients.map { try XCTUnwrap($0["name"] as? String) }
        XCTAssertFalse(names.isEmpty)
        XCTAssertFalse(routine.isEmpty)
        for name in names { try reveal(app.staticTexts[name].firstMatch, in: app) }
        keepScreenshot(app, name: "ProductionIngredients")
        try reveal(app.staticTexts["관리 루틴"], in: app)
        try verifyRoutine(routine, in: app)
        keepScreenshot(app, name: "ProductionRoutine")

        let proof: [String: Any] = [
            "target": "team-ios", "captureView": "side", "model": try XCTUnwrap(disease["modelVersion"]),
            "label": try XCTUnwrap(disease["label"]), "score": try XCTUnwrap(disease["confidence"]),
            "status": try XCTUnwrap(detail["status"]), "recommendationStatus": try XCTUnwrap(detail["recommendationStatus"]),
            "generation": detail["generation"] ?? NSNull(), "ingredients": names, "routine": routine
        ]
        let encoded = try JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys])
        print("PRODUCTION_SIDE_PROOF \(String(decoding: encoded, as: UTF8.self))")
        let attachment = XCTAttachment(data: encoded, uniformTypeIdentifier: "public.json")
        attachment.name = "ProductionProof"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func selectPhoto(in app: XCUIApplication) throws {
        // simctl adds the only new photo; the picker lists that newest item first.
        let picker = app.scrollViews["photosView_content_scroll_view"].firstMatch
        let photo = picker.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        guard photo.waitForExistence(timeout: 15) else {
            throw ValidationError.controlNotVisible("Most recent photo in the system picker", app.debugDescription)
        }
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    private func verifyRoutine(_ steps: [[String: Any]], in app: XCUIApplication) throws {
        let timeSet = Set(steps.compactMap { $0["time"] as? String })
        if !timeSet.isDisjoint(with: ["morning", "evening", "daily"]) {
            for (time, title) in [("morning", "아침"), ("evening", "저녁")] {
                try tap(app.buttons[title], in: app)
                let actions = steps.filter { ($0["time"] as? String) == time || ($0["time"] as? String) == "daily" }
                if actions.isEmpty { try reveal(app.staticTexts["이 시간대에는 따로 할 일이 없어요."], in: app) }
                for step in actions {
                    try reveal(app.staticTexts[try XCTUnwrap(step["action"] as? String)].firstMatch, in: app)
                }
            }
        }
        for (time, title) in [("weekly", "주간 관리"), ("anytime", "시간대 무관")] {
            if timeSet.contains(time) {
                try reveal(app.staticTexts[title], in: app)
                for step in steps where step["time"] as? String == time {
                    try reveal(app.staticTexts[try XCTUnwrap(step["action"] as? String)].firstMatch, in: app)
                }
            }
        }
        XCTAssertTrue(timeSet.isSubset(of: ["morning", "evening", "daily", "weekly", "anytime"]))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 15, allowScroll: Bool = true) throws {
        if !element.exists, !element.waitForExistence(timeout: min(timeout, 15)), timeout > 15 {
            _ = element.waitForExistence(timeout: timeout - 15)
        }
        if allowScroll {
            for _ in 0..<8 where !element.isHittable {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.49, dy: 0.72)).press(
                    forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.49, dy: 0.45))
                )
            }
        }
        guard element.exists && element.isHittable else {
            throw ValidationError.controlNotVisible(element.description, app.debugDescription)
        }
    }

    @MainActor
    private func tap(_ element: XCUIElement, in app: XCUIApplication, allowScroll: Bool = true) throws {
        try reveal(element, in: app, allowScroll: allowScroll)
        let predicate = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        guard XCTWaiter.wait(for: [predicate], timeout: 12) == .completed else {
            throw ValidationError.controlNotVisible(element.description, app.debugDescription)
        }
        element.tap()
    }

    @MainActor
    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func cleanUp(_ credentials: [String: String]) async {
        do {
            let session = try await request("POST", "/auth/login", body: credentials)
            let token = try XCTUnwrap(session["accessToken"] as? String)
            _ = try await request("DELETE", "/users/me", token: token)
            print("PRODUCTION_SIDE_STEP synthetic test account deleted")
        } catch {
            XCTFail("Could not delete the synthetic test account: \(error)")
        }
    }

    @MainActor
    private func request(
        _ method: String, _ path: String, token: String? = nil, body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        var request = URLRequest(url: try XCTUnwrap(URL(string: baseURL.absoluteString + path)), timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("ios", forHTTPHeaderField: "X-Client")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = try XCTUnwrap(response as? HTTPURLResponse).statusCode
        guard (200..<300).contains(status) else {
            throw ValidationError.http(method, path, status)
        }
        if data.isEmpty { return [:] }
        let envelope = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return envelope["data"] as? [String: Any] ?? [:]
    }

    private enum ValidationError: Error {
        case http(String, String, Int)
        case controlNotVisible(String, String)
    }
}
