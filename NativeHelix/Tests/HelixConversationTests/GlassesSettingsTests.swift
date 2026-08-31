import XCTest
import HelixCore
import HelixPersistence

final class GlassesSettingsTests: XCTestCase {
    func testGlassesFieldsDecodeWithDefaultsFromLegacyJSON() throws {
        // Persisted settings from before the glasses fields existed.
        let legacy = #"{"maxResponseSentences": 5, "llmProvider": "openAI"}"#
        let settings = try JSONDecoder().decode(HelixSettings.self, from: Data(legacy.utf8))

        XCTAssertEqual(settings.maxResponseSentences, 5)
        XCTAssertEqual(settings.headUpAngle, 30)
        XCTAssertEqual(settings.displayHeight, 4)
        XCTAssertEqual(settings.displayDepth, 4)
        XCTAssertEqual(settings.brightness, 30)
        XCTAssertTrue(settings.autoBrightness)
        XCTAssertTrue(settings.glassesNotificationsEnabled)
        XCTAssertTrue(settings.dashboardEnabled)
    }

    func testGlassesFieldsRoundTripThroughCodable() throws {
        let original = HelixSettings(headUpAngle: 45, displayHeight: 7, displayDepth: 2, brightness: 12, autoBrightness: false)
        let decoded = try JSONDecoder().decode(HelixSettings.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }

    func testGlassesFieldsClampToFirmwareRanges() {
        let settings = HelixSettings(headUpAngle: 99, displayHeight: 99, displayDepth: 99, brightness: 99)
        XCTAssertEqual(settings.headUpAngle, 60)
        XCTAssertEqual(settings.displayHeight, 8)
        XCTAssertEqual(settings.displayDepth, 9)
        XCTAssertEqual(settings.brightness, 63)
    }

    func testConversationControlMutationPreservesGlassesFields() async {
        let manager = NativeSettingsManager(
            settingsStore: InMemorySettingsStore(),
            secretStore: InMemorySecretStore()
        )

        _ = await manager.updateGlassesDisplay(headUpAngle: 50, displayHeight: 7, brightness: 10, autoBrightness: false)

        // Regression guard (peer-review I7): mutating a conversation control must
        // not reset the glasses configuration.
        let after = await manager.updateConversationControls(autoAnswer: false)

        XCTAssertFalse(after.autoAnswer)
        XCTAssertEqual(after.headUpAngle, 50)
        XCTAssertEqual(after.displayHeight, 7)
        XCTAssertEqual(after.brightness, 10)
        XCTAssertFalse(after.autoBrightness)
    }

    func testUpdateGlassesDisplayClampsAndPersists() async {
        let manager = NativeSettingsManager(
            settingsStore: InMemorySettingsStore(),
            secretStore: InMemorySecretStore()
        )

        let updated = await manager.updateGlassesDisplay(headUpAngle: 200, displayDepth: -3, dashboardEnabled: false)

        XCTAssertEqual(updated.headUpAngle, 60)
        XCTAssertEqual(updated.displayDepth, 0)
        XCTAssertFalse(updated.dashboardEnabled)

        let reloaded = await manager.settings()
        XCTAssertEqual(reloaded, updated)
    }
}
