import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {

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
