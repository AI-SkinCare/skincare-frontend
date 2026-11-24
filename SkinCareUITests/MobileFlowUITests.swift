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
