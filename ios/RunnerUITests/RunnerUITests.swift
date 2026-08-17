// ABOUTME: XCUITest validation of the native Helix app shell — tabs, device
// ABOUTME: discovery, recording control, API keys, skills, and fact cards.

import XCTest

final class RunnerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Navigation

    func testAllFiveTabsExist() {
        for tab in ["Assistant", "Device", "Sessions", "Knowledge", "Settings"] {
            XCTAssertTrue(
                app.tabBars.buttons[tab].waitForExistence(timeout: 5),
                "Missing tab: \(tab)"
            )
        }
    }

    // MARK: - Device discovery

    func testDeviceTabShowsScanControls() {
        app.tabBars.buttons["Device"].tap()

        XCTAssertTrue(app.staticTexts["Discovery"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Scan for glasses"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["G1 device"].exists)

        // Scanning on the simulator fails fast (no Bluetooth) — the button must
        // still respond and surface a state change rather than doing nothing.
        app.buttons["Scan for glasses"].tap()
        let scanning = app.buttons["Stop scan"].waitForExistence(timeout: 3)
        let bluetoothOff = app.staticTexts["Bluetooth is not powered on."].waitForExistence(timeout: 3)
        XCTAssertTrue(scanning || bluetoothOff, "Scan button produced no state change")
    }

    func testDeviceTabShowsGlassesDisplayControls() {
        app.tabBars.buttons["Device"].tap()

        XCTAssertTrue(app.staticTexts["Glasses display"].waitForExistence(timeout: 5))
        for control in ["Head-up angle", "Display height", "Display depth", "Auto brightness", "Head-up dashboard"] {
            XCTAssertTrue(
                app.descendants(matching: .any).matching(
                    NSPredicate(format: "label CONTAINS %@", control)
                ).firstMatch.exists,
                "Missing glasses control: \(control)"
            )
        }
    }

    func testSettingsHasInsightsToggle() {
        app.tabBars.buttons["Settings"].tap()

        let toggle = app.switches.matching(
            NSPredicate(format: "label CONTAINS 'Real-time insights'")
        ).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Real-time insights toggle missing")
    }

    // MARK: - Recording control

    func testAssistantHasRecordButtonThatRespondsToTap() {
        app.tabBars.buttons["Assistant"].tap()

        let record = app.buttons["Start listening"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()

        allowSystemPermissionAlertsIfPresent()

        // On the simulator recognition may start (Stop listening appears) or
        // fail with a surfaced error — both prove the control is wired.
        let stop = app.buttons["Stop listening"]
        let started = stop.waitForExistence(timeout: 10)
        if started {
            stop.tap()
            XCTAssertTrue(app.buttons["Start listening"].waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(
                app.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS[c] 'recogni' OR label CONTAINS[c] 'speech' OR label CONTAINS[c] 'denied' OR label CONTAINS[c] 'authoriz'")
                ).firstMatch.waitForExistence(timeout: 5),
                "Record button neither started listening nor surfaced an error"
            )
        }
    }

    // MARK: - Text Q&A

    func testTextQuestionProducesAnswer() {
        app.tabBars.buttons["Assistant"].tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("What is an LLM?")

        let ask = app.buttons["Ask Helix"]
        XCTAssertTrue(ask.waitForExistence(timeout: 3))
        ask.tap()

        // Without an API key the deterministic provider answers instantly.
        let answered = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'transformer attention'")
        ).firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(answered, "No answer appeared for a text question")

        // The answer unlocks the send-to-glasses control.
        XCTAssertTrue(app.buttons["Send current answer to G1"].isEnabled)
    }

    // MARK: - API keys

    func testProviderRowOpensKeySheetAndStoresKey() {
        app.tabBars.buttons["Settings"].tap()

        let openAIRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'OpenAI'")
        ).firstMatch
        XCTAssertTrue(openAIRow.waitForExistence(timeout: 5))
        openAIRow.tap()

        let secureField = app.secureTextFields.firstMatch
        XCTAssertTrue(secureField.waitForExistence(timeout: 5), "Key sheet has no SecureField")
        secureField.tap()
        secureField.typeText("sk-uitest-000")

        app.buttons["Save"].tap()

        let keySet = app.staticTexts["Key set"].waitForExistence(timeout: 5)
        XCTAssertTrue(keySet, "Provider row does not show 'Key set' after saving")

        // Clean up so later runs start from a keyless state.
        openAIRow.tap()
        let removeButton = app.buttons["Remove stored key"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5))
        removeButton.tap()
    }

    func testProviderKeySheetHasEditableModelPickers() {
        app.tabBars.buttons["Settings"].tap()

        let openAIRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'OpenAI'")
        ).firstMatch
        XCTAssertTrue(openAIRow.waitForExistence(timeout: 5))
        openAIRow.tap()

        // Model pickers replace the old read-only labels.
        let smartPicker = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Smart'")
        ).firstMatch
        XCTAssertTrue(smartPicker.waitForExistence(timeout: 5), "Smart model picker missing")

        smartPicker.tap()
        // The menu should offer at least one selectable model option.
        let option = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'gpt-'")
        ).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "No model options presented")
    }

    // MARK: - Skill / prompt configuration

    func testSkillPickerAndCustomSkillEditor() {
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.staticTexts["Assistant skill"].waitForExistence(timeout: 5))

        let customButton = app.buttons["Custom"]
        XCTAssertTrue(customButton.waitForExistence(timeout: 5))
        customButton.tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("UI Test Coach")

        let promptField = app.textFields.element(boundBy: 1)
        XCTAssertTrue(promptField.exists)
        promptField.tap()
        promptField.typeText("Answer tersely for UI test validation.")

        app.buttons["Save"].tap()

        XCTAssertTrue(
            app.staticTexts["UI Test Coach"].waitForExistence(timeout: 5),
            "Custom skill was not activated after saving"
        )
    }

    // MARK: - Fact cards

    func testFactsBucketShowsSwipeableCards() {
        app.tabBars.buttons["Knowledge"].tap()

        let factsSegment = app.buttons["Facts"].firstMatch
        XCTAssertTrue(factsSegment.waitForExistence(timeout: 5))
        factsSegment.tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))

        for fact in ["Water boils at 100C at sea level.", "The G1 HUD uses command 0x4E."] {
            field.tap()
            field.typeText(fact)
            let addButton = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH 'Add'")
            ).firstMatch
            XCTAssertTrue(addButton.waitForExistence(timeout: 3))
            addButton.tap()
        }

        // Facts persist across runs, so match position prefixes, not totals.
        let firstCounter = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH '1 of '")
        ).firstMatch
        XCTAssertTrue(
            firstCounter.waitForExistence(timeout: 5),
            "Fact cards did not render after adding facts"
        )

        let start = firstCounter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 2.0))
        let end = start.withOffset(CGVector(dx: -260, dy: 0))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: 300, thenHoldForDuration: 0.1)

        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH '2 of '")
            ).firstMatch.waitForExistence(timeout: 5),
            "Swiping left did not advance to the next fact card"
        )
    }

    // MARK: - Helpers

    private func allowSystemPermissionAlertsIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 3) else { break }
            for label in ["Allow", "OK", "Allow While Using App"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    break
                }
            }
        }
        app.activate()
    }
}
