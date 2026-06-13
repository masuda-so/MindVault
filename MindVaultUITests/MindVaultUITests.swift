import XCTest

final class MindVaultUITests: XCTestCase {
    func testLaunchShowsGraphFirst() {
        continueAfterFailure = false
        let app = launchJapaneseApp()

        XCTAssertTrue(app.buttons["MindVaultへようこそ"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["知識グラフ"].waitForExistence(timeout: 20))
    }

    func testNoteEditorDefaultsToPreviewMode() {
        continueAfterFailure = false
        let app = launchJapaneseApp()

        openWelcomeNote(in: app)

        XCTAssertTrue(app.buttons["AI提案"].waitForExistence(timeout: 60))
        app.buttons["AI提案"].tap()
        XCTAssertTrue(app.staticTexts["AIアシスタント"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["未整理メモ"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.textViews["markdownEditor"].exists)
    }

    func testSearchAndSettingsTabsRender() {
        continueAfterFailure = false
        let app = launchJapaneseApp()

        XCTAssertTrue(app.tabBars.buttons["検索"].waitForExistence(timeout: 60))
        app.tabBars.buttons["検索"].tap()
        XCTAssertTrue(app.staticTexts["AIチャット検索"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["ベクトル検索候補"].waitForExistence(timeout: 20))

        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 20))
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["外観"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["プライバシー"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["現在のプラン"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["restorePurchasesButton"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Privacy Policy"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Terms of Use (EULA)"].waitForExistence(timeout: 20))
    }

    private func launchJapaneseApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-MindVaultUseInMemoryStore",
            "-AppleLanguages", "(ja)",
            "-AppleLocale", "ja_JP"
        ]
        app.launch()
        return app
    }

    private func openWelcomeNote(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["MindVaultへようこそ"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.buttons["開く"].waitForExistence(timeout: 20))
        app.buttons["開く"].tap()
    }
}
