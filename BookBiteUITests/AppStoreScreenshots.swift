import XCTest

/// Captures the raw screens for the App Store screenshots (design/app-store).
/// Run on iPhone 17 Pro Max with the status bar overridden:
///   TEST_RUNNER_SCREENSHOT_DIR=$PWD/design/app-store/raw xcodebuild test ... \
///     -only-testing:BookBiteUITests/AppStoreScreenshots
/// Skipped unless SCREENSHOT_DIR is set, so it never runs with the normal UI tests.
final class AppStoreScreenshots: XCTestCase {
    private var dir: URL!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        guard let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("SCREENSHOT_DIR not set")
        }
        dir = URL(fileURLWithPath: path)
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES", "-readerTheme", "paper"]
        app.launchEnvironment["BOOKBITE_SERVER_URL"] = "https://book-bite.onrender.com/api"
    }

    private func snap(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
    }

    private func settle(_ seconds: TimeInterval = 3) {
        _ = app.wait(for: .unknown, timeout: seconds)
    }

    @MainActor
    func testCaptureScreens() throws {
        app.launch()

        // Discover
        XCTAssertTrue(app.staticTexts["IDEA OF THE DAY"].waitForExistence(timeout: 40)
                      || app.staticTexts["Idea of the day"].exists)
        settle(6)
        snap("discover")

        // Book page: Atomic Habits via search
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.element
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Atomic Habits")
        let result = app.cells.firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 20))
        settle(2)
        result.tap()
        let read = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read summary' OR label BEGINSWITH 'Continue reading' OR label BEGINSWITH 'Read again'")).firstMatch
        XCTAssertTrue(read.waitForExistence(timeout: 40))
        settle(5)
        snap("detail")

        // Key ideas deck
        let keep = app.buttons["Keep idea"].firstMatch
        for _ in 0..<6 where !(keep.exists && keep.isHittable) {
            app.swipeUp(velocity: .slow)
        }
        settle(2)
        snap("keyideas-raw")
        if keep.exists && keep.isHittable { keep.tap() }
        settle(1)
        snap("keyideas")

        // Reader
        app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast); app.swipeDown(velocity: .fast)
        settle(1)
        if read.isHittable { read.tap() }
        settle(6)
        snap("reader")
        app.swipeUp(velocity: .slow)
        settle(2)
        snap("reader-scrolled")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        settle(1)

        // Ask
        app.tabBars.buttons["Ask"].tap()
        settle(8)
        snap("ask-home")
        let pill = app.buttons.matching(NSPredicate(format: "label CONTAINS 'on your mind'")).firstMatch
        if pill.waitForExistence(timeout: 5) { pill.tap() } else { app.staticTexts["What’s on your mind?"].tap() }
        let input = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.typeText("My team keeps missing deadlines and I end up doing the work myself")
        settle(4)
        snap("ask-compose")
        app.buttons["Ask"].firstMatch.tap()
        settle(25)
        snap("ask-answer")
        app.swipeUp(velocity: .slow)
        settle(2)
        snap("ask-answer-scrolled")

        // Library
        app.terminate()
        app.launch()
        app.tabBars.buttons["Library"].tap()
        settle(8)
        snap("library")
    }
}
