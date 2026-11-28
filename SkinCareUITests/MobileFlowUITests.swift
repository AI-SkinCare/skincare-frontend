import XCTest

final class MobileFlowUITests: XCTestCase {
    @MainActor
    private func launch(_ screen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-MockAPI", "-StartScreen", screen]
        app.launch()
        return app
    }

    @MainActor
    func testCaptureRequiresExplicitAngleBeforeOpeningPhotoSources() {
        let app = launch("capture")
        let front = app.buttons["정면"].firstMatch
        let side = app.buttons["측면"].firstMatch
        let album = app.buttons["capture-album"].firstMatch
        XCTAssertTrue(front.waitForExistence(timeout: 12))
        XCTAssertFalse(front.isSelected)
        XCTAssertFalse(side.isSelected)
        for _ in 0..<3 where !album.exists { app.swipeUp() }
        XCTAssertTrue(album.exists)
        XCTAssertFalse(album.isEnabled)
        if !side.isHittable { app.swipeDown() }
        side.tap()
        XCTAssertTrue(side.isSelected)
        XCTAssertTrue(album.isEnabled)
        front.tap()
        XCTAssertTrue(front.isSelected)
        XCTAssertFalse(side.isSelected)
    }

    @MainActor
    func testGeneratedReportShowsIngredientsRoutineAndCare() {
        let app = launch("recommendation")
        XCTAssertTrue(app.navigationBars["맞춤 추천"].waitForExistence(timeout: 15))
        for title in ["추천 성분", "관리 루틴", "일상 관리", "식습관 메모"] {
            let element = app.staticTexts[title].firstMatch
            for _ in 0..<8 {
                if element.exists && element.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(element.exists, title)
        }
    }

    @MainActor
    func testSearchShowsCitedPassage() {
        let app = launch("home")
        let open = app.buttons["피부 자료 검색"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 12))
        if !open.isHittable { app.swipeUp() }
        open.tap()
        let field = app.textFields["성분명이나 질문 입력"]
        XCTAssertTrue(field.waitForExistence(timeout: 6))
        field.tap()
        field.typeText("diary")
        app.buttons["knowledge-search-submit"].tap()
        let answer = app.staticTexts["사용한 제품과 피부 편안함을 같은 날짜에 기록할 수 있어요."]
        XCTAssertTrue(answer.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        let citation = app.descendants(matching: .any).matching(identifier: "knowledge-answer-source").firstMatch
        XCTAssertTrue(citation.exists, app.debugDescription)
        XCTAssertEqual(citation.label, "답변 출처 · SkinCare")
    }

    @MainActor
    func testHistoricalIngredientHasLabeledGeneralSource() {
        let app = launch("recommendation")
        let button = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "세라마이드 근거 보기")).firstMatch
        for _ in 0..<6 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(button.isHittable)
        button.tap()
        XCTAssertTrue(app.staticTexts["일반 참고자료"].firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["이 결과에는 성분별 출처가 저장되어 있지 않아요."].firstMatch.exists)
    }

    @MainActor
    func testShowsClassificationScoreAndExplanation() {
        let app = launch("report-uncertain")
        XCTAssertTrue(app.navigationBars["분석 결과"].waitForExistence(timeout: 15))
        let summary = app.descendants(matching: .any).matching(identifier: "classification-summary").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("55.0점 / 100점"))
        let reason = app.staticTexts["왜 이렇게 분류했나요?"].firstMatch
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        let detail = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "46.0점 차이")).firstMatch
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(app.staticTexts["분류가 불확실해 판단을 보류했어요."].exists)
        XCTAssertTrue(app.staticTexts["이 결과에는 표시할 수 있는 참고 영역 지도가 없어요."].exists)
    }

    @MainActor
    func testWithheldReportHasNoRecommendationLink() {
        let app = launch("report-no-concern")
        XCTAssertTrue(app.navigationBars["분석 결과"].waitForExistence(timeout: 15))
        let message = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "자동 추천을 만들지 않았어요")).firstMatch
        for _ in 0..<6 {
            if message.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(message.exists)
        XCTAssertFalse(app.buttons["추천 자세히 보기"].exists)
    }
}
