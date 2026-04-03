import XCTest
@testable import Even_Companion

final class RunnerTests: XCTestCase {

    func testBluetoothConnectionPersistenceFallsBackToSecureStoreAfterReinstall() {
        let defaultsSuite = "BluetoothConnectionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            defaults.removePersistentDomain(forName: defaultsSuite)
        }

        let secureStore = InMemoryBluetoothConnectionSecureStore()
        let persistence = BluetoothConnectionPersistence(
            defaults: defaults,
            secureStore: secureStore
        )
        let expected = StoredBluetoothConnection(
            deviceName: "Pair_7",
            leftPeripheralID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            rightPeripheralID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        )

        XCTAssertTrue(secureStore.save(expected.encoded(), for: BluetoothConnectionPersistence.secureStoreAccount))

        let restored = persistence.load()

        XCTAssertEqual(restored, expected)
        XCTAssertEqual(
            defaults.string(forKey: BluetoothConnectionPersistence.storedDeviceNameKey),
            expected.deviceName
        )
        XCTAssertEqual(
            defaults.string(forKey: BluetoothConnectionPersistence.storedLeftUUIDKey),
            expected.leftPeripheralID.uuidString
        )
        XCTAssertEqual(
            defaults.string(forKey: BluetoothConnectionPersistence.storedRightUUIDKey),
            expected.rightPeripheralID.uuidString
        )
    }

    func testBluetoothConnectionPersistenceBackfillsSecureStoreFromDefaults() {
        let defaultsSuite = "BluetoothConnectionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            defaults.removePersistentDomain(forName: defaultsSuite)
        }

        let expected = StoredBluetoothConnection(
            deviceName: "Pair_5",
            leftPeripheralID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            rightPeripheralID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        )
        defaults.set(expected.deviceName, forKey: BluetoothConnectionPersistence.storedDeviceNameKey)
        defaults.set(expected.leftPeripheralID.uuidString, forKey: BluetoothConnectionPersistence.storedLeftUUIDKey)
        defaults.set(expected.rightPeripheralID.uuidString, forKey: BluetoothConnectionPersistence.storedRightUUIDKey)

        let secureStore = InMemoryBluetoothConnectionSecureStore()
        let persistence = BluetoothConnectionPersistence(
            defaults: defaults,
            secureStore: secureStore
        )

        let restored = persistence.load()

        XCTAssertEqual(restored, expected)
        XCTAssertEqual(
            secureStore.read(for: BluetoothConnectionPersistence.secureStoreAccount),
            expected.encoded()
        )
    }

    func testBluetoothConnectionPersistenceClearRemovesDefaultsAndSecureStore() {
        let defaultsSuite = "BluetoothConnectionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defaults.removePersistentDomain(forName: defaultsSuite)
        defer {
            defaults.removePersistentDomain(forName: defaultsSuite)
        }

        let secureStore = InMemoryBluetoothConnectionSecureStore()
        let persistence = BluetoothConnectionPersistence(
            defaults: defaults,
            secureStore: secureStore
        )
        let stored = StoredBluetoothConnection(
            deviceName: "Pair_8",
            leftPeripheralID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            rightPeripheralID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        )

        persistence.save(stored)
        persistence.clear()

        XCTAssertNil(persistence.load())
        XCTAssertNil(defaults.string(forKey: BluetoothConnectionPersistence.storedDeviceNameKey))
        XCTAssertNil(defaults.string(forKey: BluetoothConnectionPersistence.storedLeftUUIDKey))
        XCTAssertNil(defaults.string(forKey: BluetoothConnectionPersistence.storedRightUUIDKey))
        XCTAssertNil(secureStore.read(for: BluetoothConnectionPersistence.secureStoreAccount))
    }

    func testAudioResamplerUpsamplesPCM16Data() {
        let input = [Int16](0..<8)
        let inputData = input.withUnsafeBufferPointer { Data(buffer: $0) }

        let output = AudioResampler.resample(
            pcm16Data: inputData,
            fromRate: 16000,
            toRate: 24000
        )

        let outputSamples = output.withUnsafeBytes {
            Array($0.bindMemory(to: Int16.self))
        }

        XCTAssertEqual(outputSamples.count, 12)
        XCTAssertEqual(outputSamples.first, input.first)
        XCTAssertEqual(outputSamples.last, input.last)
    }

    func testRealtimeTranscriberFailsFastWithoutApiKey() {
        let transcriber = OpenAIRealtimeTranscriber()
        let expectation = expectation(description: "Missing API key surfaces immediately")

        transcriber.start(
            apiKey: "",
            model: "gpt-4o-mini-transcribe",
            language: "en"
        ) { result in
            switch result {
            case .success:
                XCTFail("Expected failure for missing API key")
            case .failure(let error):
                guard let transcriberError = error as? OpenAIRealtimeTranscriber.TranscriberError else {
                    XCTFail("Unexpected error type: \(error)")
                    expectation.fulfill()
                    return
                }
                XCTAssertEqual(
                    transcriberError.errorDescription,
                    "OpenAI API key is required for realtime transcription"
                )
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testConversationSessionConfigIncludesInstructionsAndTextModalities() {
        let transcriber = OpenAIRealtimeTranscriber()
        transcriber.debugConfigureForTesting(
            mode: .conversation,
            language: "ja",
            systemPrompt: "Coach me for interviews."
        )

        let event = transcriber.debugSessionConfigEvent()

        XCTAssertEqual(event["type"] as? String, "session.update")
        let session = event["session"] as? [String: Any]
        XCTAssertEqual(session?["instructions"] as? String, "Coach me for interviews.")
        XCTAssertEqual(session?["modalities"] as? [String], ["text"])

        let transcription = session?["input_audio_transcription"] as? [String: Any]
        XCTAssertEqual(transcription?["model"] as? String, "gpt-4o-mini-transcribe")
        XCTAssertEqual(transcription?["language"] as? String, "ja")
    }

    func testHandleMessageRoutesTranscriptAndResponseCallbacks() {
        let transcriber = OpenAIRealtimeTranscriber()
        let expectation = expectation(description: "Callbacks invoked")
        expectation.expectedFulfillmentCount = 4

        var transcriptEvents: [(String, Bool)] = []
        var responseEvents: [(String, Bool)] = []

        transcriber.onTranscript = { text, isFinal in
            transcriptEvents.append((text, isFinal))
            expectation.fulfill()
        }
        transcriber.onResponse = { text, isFinal in
            responseEvents.append((text, isFinal))
            expectation.fulfill()
        }

        transcriber.debugHandleMessage(
            #"{"type":"conversation.item.input_audio_transcription.delta","delta":"Hello"}"#
        )
        transcriber.debugHandleMessage(
            #"{"type":"conversation.item.input_audio_transcription.completed","transcript":"Hello there"}"#
        )
        transcriber.debugHandleMessage(
            #"{"type":"response.text.delta","delta":"Hi"}"#
        )
        transcriber.debugHandleMessage(
            #"{"type":"response.text.done"}"#
        )

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(transcriptEvents.map(\.0), ["Hello", "Hello there"])
        XCTAssertEqual(transcriptEvents.map(\.1), [false, true])
        XCTAssertEqual(responseEvents.map(\.0), ["Hi", ""])
        XCTAssertEqual(responseEvents.map(\.1), [false, true])
    }

    func testHandleMessageMapsAuthenticationErrorsToFriendlyCopy() {
        let transcriber = OpenAIRealtimeTranscriber()
        let expectation = expectation(description: "Auth error surfaces friendly copy")

        var capturedError: String?
        transcriber.onError = { message in
            capturedError = message
            expectation.fulfill()
        }

        transcriber.debugHandleMessage(
            #"{"type":"error","error":{"message":"HTTP 401 unauthorized"}}"#
        )

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(capturedError, "OpenAI API key is invalid or expired")
    }
}

private final class InMemoryBluetoothConnectionSecureStore: BluetoothConnectionSecureStore {
    private var storage: [String: Data] = [:]

    func read(for account: String) -> Data? {
        storage[account]
    }

    @discardableResult
    func save(_ data: Data, for account: String) -> Bool {
        storage[account] = data
        return true
    }

    func delete(for account: String) {
        storage.removeValue(forKey: account)
    }
}
