// ABOUTME: XCUITest validation of the native Helix app shell — tabs, device
// ABOUTME: discovery, recording control, API keys, skills, and fact cards.

import XCTest

final class RunnerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--helix-ui-testing")
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

    func testQuestionSensitivityControlUpdatesMultilingualDetectionCopy() {
        app.tabBars.buttons["Settings"].tap()

        let heading = app.staticTexts["Question sensitivity"]
        if !heading.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "Question sensitivity control missing")

        let sensitive = app.buttons["Sensitive"]
        XCTAssertTrue(sensitive.waitForExistence(timeout: 5), "Sensitive option missing")
        sensitive.tap()

        XCTAssertTrue(
            app.staticTexts[
                "Also picks up indirect and statement-form questions; may include more false positives."
            ].waitForExistence(timeout: 5),
            "Sensitivity selection did not update its explanatory copy"
        )
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'English' AND label CONTAINS '中文' AND label CONTAINS 'Español'")
            ).firstMatch.exists,
            "The control does not explain multilingual behavior"
        )
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
        // Use a per-run question so a previous durable QA memory cannot turn
        // this run's owned receipt into the truthful "Already in Knowledge"
        // state and hide the Undo/Remove actions under test.
        let question = "What is an LLM for UI QA \(UUID().uuidString.prefix(8))?"
        field.typeText(question)

        let ask = app.buttons["Ask Helix"]
        XCTAssertTrue(ask.waitForExistence(timeout: 3))
        ask.tap()

        // Without an API key the deterministic provider answers instantly.
        let answered = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'transformer attention'")
        ).firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(answered, "No answer appeared for a text question")

        XCTAssertTrue(
            app.otherElements["assistant-chat-thread"].exists,
            "The answer did not render in the message-driven chat thread"
        )
        XCTAssertTrue(app.staticTexts["You"].exists, "Typed question is not attributed to the user")

        // Simulator has no G1. The UI must say so rather than claim delivery.
        let offline = app.buttons["G1 offline"]
        XCTAssertTrue(offline.exists)
        XCTAssertFalse(offline.isEnabled)

        // The keyless deterministic answer is a product-flow fixture, not
        // trusted knowledge. It must not auto-save, while an explicit manual
        // save remains available.
        XCTAssertFalse(
            app.buttons["Undo auto-save"].waitForExistence(timeout: 1),
            "A deterministic placeholder entered the automatic save window"
        )
        let save = app.buttons["Save to Knowledge"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        XCTAssertTrue(
            app.buttons["Remove from Knowledge"].waitForExistence(timeout: 8),
            "Explicit note save did not reach durable internal Knowledge"
        )

        let chatAttachment = XCTAttachment(screenshot: app.screenshot())
        chatAttachment.name = "Assistant chat with answer and Knowledge receipt"
        chatAttachment.lifetime = .keepAlways
        add(chatAttachment)

        // Relaunch instead of trying to tap through the software keyboard. The
        // composer deliberately remains focused after submission, which covers
        // the tab bar on compact-height simulator layouts. Relaunching also
        // verifies that the explicit Knowledge capture was actually durable.
        app.terminate()
        app.launch()

        let knowledgeTab = app.tabBars.buttons["Knowledge"]
        XCTAssertTrue(knowledgeTab.waitForExistence(timeout: 5))
        knowledgeTab.tap()
        XCTAssertTrue(app.navigationBars["Knowledge"].waitForExistence(timeout: 5))
        let memories = app.buttons["Memories"]
        XCTAssertTrue(memories.waitForExistence(timeout: 5))
        memories.tap()
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "Question: \(question)")
            ).firstMatch.waitForExistence(timeout: 5),
            "Captured note is not visible in Knowledge memories"
        )
    }

    func testThinkDeeperUsesProductionPathAndTruthfulFallbackIdentity() {
        app.tabBars.buttons["Assistant"].tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("What is an LLM?")
        app.buttons["Ask Helix"].tap()

        let initialAnswer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'transformer attention'")
        ).firstMatch
        XCTAssertTrue(initialAnswer.waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["deterministic-native"].waitForExistence(timeout: 5),
            "Keyless automatic answer did not expose its truthful fallback identity"
        )

        let thinkDeeper = app.buttons["Think deeper"].firstMatch
        XCTAssertTrue(thinkDeeper.waitForExistence(timeout: 5), "Think deeper is not reachable in production")
        thinkDeeper.tap()

        XCTAssertTrue(
            app.staticTexts.matching(identifier: "deterministic-native").element(boundBy: 1)
                .waitForExistence(timeout: 10),
            "Keyless deep answer did not expose its truthful fallback identity"
        )
        XCTAssertEqual(
            app.buttons.matching(identifier: "Think deeper").count,
            1,
            "A deeper answer must not offer a recursive Think deeper action"
        )
    }

    func testMultiSpeakerChatSupportsIdentityEditingAndSessionSave() {
        app.terminate()
        app.launchArguments.append("--helix-ui-speaker-fixture")
        app.launch()

        app.tabBars.buttons["Assistant"].tap()

        XCTAssertTrue(
            app.otherElements["assistant-chat-thread"].waitForExistence(timeout: 5),
            "Speaker fixture did not render in the message-driven chat thread"
        )
        XCTAssertTrue(
            app.staticTexts["Alice owns the launch review."].waitForExistence(timeout: 5),
            "Named source transcript is missing"
        )
        XCTAssertTrue(
            app.staticTexts["I will send the revised deck by noon."].waitForExistence(timeout: 5),
            "Unknown-source transcript is missing"
        )

        let sourceSpeaker = app.buttons["Edit speaker name for Source speaker Alice"]
        let unknownSpeaker = app.buttons["Edit speaker name for Unknown speaker"]
        XCTAssertTrue(sourceSpeaker.waitForExistence(timeout: 5), "Source-provided identity is not rendered")
        XCTAssertTrue(unknownSpeaker.waitForExistence(timeout: 5), "Unknown identity is not editable")

        unknownSpeaker.tap()
        let nameAlert = app.alerts["Name speaker"]
        XCTAssertTrue(nameAlert.waitForExistence(timeout: 5), "Speaker editor did not open")
        let nameField = nameAlert.textFields["Speaker name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Speaker editor has no name field")
        nameField.typeText("Bob")
        nameAlert.buttons["Save"].tap()

        let bobSpeaker = app.buttons["Edit speaker name for Bob"]
        XCTAssertTrue(bobSpeaker.waitForExistence(timeout: 5), "Renamed speaker did not render as Bob")
        XCTAssertTrue(sourceSpeaker.exists, "Renaming one turn changed the other source identity")

        bobSpeaker.tap()
        XCTAssertTrue(nameAlert.waitForExistence(timeout: 5), "Speaker editor did not reopen")
        nameAlert.buttons["Mark as Me"].tap()
        XCTAssertTrue(
            app.buttons["Edit speaker name for You"].waitForExistence(timeout: 5),
            "Mark as Me did not canonicalize the speaker to You"
        )
        XCTAssertTrue(sourceSpeaker.exists, "Mark as Me changed the other source identity")

        let chatAttachment = XCTAttachment(screenshot: app.screenshot())
        chatAttachment.name = "Multi-speaker chat after rename and Mark as Me"
        chatAttachment.lifetime = .keepAlways
        add(chatAttachment)

        let saveSession = app.buttons["Save current session"]
        XCTAssertTrue(saveSession.waitForExistence(timeout: 5), "Conversation is not saveable")
        for _ in 0..<4 where !saveSession.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(saveSession.isHittable, "Save session control could not be reached")
        saveSession.tap()

        app.tabBars.buttons["Sessions"].tap()
        XCTAssertTrue(
            app.staticTexts["Alice owns the launch review."].waitForExistence(timeout: 8),
            "Saved multi-speaker conversation did not appear in Sessions"
        )
    }

    func testNewConversationClearsRuntimeAndOldMessagesDoNotReturn() {
        app.tabBars.buttons["Assistant"].tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("What is an LLM?")
        app.buttons["Ask Helix"].tap()

        let oldAnswer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'transformer attention'")
        ).firstMatch
        XCTAssertTrue(oldAnswer.waitForExistence(timeout: 10))

        let newConversation = app.buttons["New conversation"]
        XCTAssertTrue(newConversation.waitForExistence(timeout: 5))
        newConversation.tap()
        let confirm = app.buttons["Start New Conversation"]
        if !confirm.waitForExistence(timeout: 2) {
            // The first tap can dismiss the software keyboard.
            newConversation.tap()
        }
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Start a conversation"].waitForExistence(timeout: 5))
        XCTAssertTrue(oldAnswer.waitForNonExistence(timeout: 5), "Old answer returned after reset")

        let freshField = app.textFields.firstMatch
        freshField.tap()
        freshField.typeText("What is an LLM?")
        app.buttons["Ask Helix"].tap()
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'transformer attention'")
            ).firstMatch.waitForExistence(timeout: 10),
            "The same question could not be asked in the new conversation"
        )
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
