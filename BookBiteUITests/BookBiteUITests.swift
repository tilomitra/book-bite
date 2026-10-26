//
//  BookBiteUITests.swift
//  BookBiteUITests
//
//  Created by Tilo Mitra on 2025-08-14.
//

import XCTest

final class BookBiteUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAppLaunchAndSearch() throws {
        let app = XCUIApplication()
        app.launch()
        
        let searchTab = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTab.exists)
        searchTab.tap()
        
        let searchField = app.searchFields.element
        XCTAssertTrue(searchField.exists)
        
        searchField.tap()
        searchField.typeText("Manager")
        
        let firstResult = app.cells.firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 5.0))
        
        firstResult.tap()
        
        XCTAssertTrue(app.staticTexts["The Manager's Path"].waitForExistence(timeout: 3.0))
    }
    
    @MainActor
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        let discoverTab = app.tabBars.buttons["Discover"]
        let searchTab = app.tabBars.buttons["Search"]
        let libraryTab = app.tabBars.buttons["Library"]

        XCTAssertTrue(discoverTab.exists)
        XCTAssertTrue(searchTab.exists)
        XCTAssertTrue(libraryTab.exists)

        // Discover and Library use a serif header instead of a navigation bar title
        discoverTab.tap()
        XCTAssertTrue(app.staticTexts["Discover"].waitForExistence(timeout: 3.0))

        libraryTab.tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 3.0))
        app.buttons["Account and settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3.0))
        app.buttons["Done"].tap()

        searchTab.tap()
        XCTAssertTrue(app.searchFields.element.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
