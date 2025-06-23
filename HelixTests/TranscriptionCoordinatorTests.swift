import XCTest
import AVFoundation
import Combine
@testable import Helix

// Mocks
class MockSpeakerDiarization: SpeakerDiarizationEngineProtocol {
    func identifySpeaker(in buffer: AVAudioPCMBuffer) -> SpeakerIdentification? { nil }
    func trainSpeakerModel(samples: [AVAudioPCMBuffer], speakerId: UUID) -> Bool { true }
    func addSpeaker(id: UUID, name: String?, isCurrentUser: Bool) {}
    func removeSpeaker(id: UUID) {}
    func getCurrentSpeakers() -> [Speaker] { [] }
    func resetSpeakerModels() {}
}

class MockVAD: VoiceActivityDetectorProtocol {
    func detectVoiceActivity(in buffer: AVAudioPCMBuffer) -> VoiceActivityResult {
        return VoiceActivityResult(hasVoice: true, confidence: 1.0,
                                   energy: 0, spectralCentroid: 0,
                                   zeroCrossingRate: 0,
                                   timestamp: Date().timeIntervalSince1970)
    }
    func updateBackground(with buffer: AVAudioPCMBuffer) {}
    func setSensitivity(_ sensitivity: Float) {}
}

class MockNoiseReducer: NoiseReductionProcessorProtocol {
    func processBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer { buffer }
    func updateNoiseProfile(_ buffer: AVAudioPCMBuffer) {}
    func setReductionLevel(_ level: Float) {}
}

class TranscriptionCoordinatorTests: XCTestCase {
    var audioManager: MockAudioManager!
    var speechService: MockSpeechRecognitionService!
    var diarizer: MockSpeakerDiarization!
    var vad: MockVAD!
    var noise: MockNoiseReducer!
    var coordinator: TranscriptionCoordinator!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        audioManager = MockAudioManager()
        speechService = MockSpeechRecognitionService()
        diarizer = MockSpeakerDiarization()
        vad = MockVAD()
        noise = MockNoiseReducer()
        coordinator = TranscriptionCoordinator(
            audioManager: audioManager,
            speechRecognizer: speechService,
            speakerDiarization: diarizer,
            voiceActivityDetector: vad,
            transcriptionProcessor: TranscriptionProcessor(),
            noiseReducer: noise
        )
        cancellables = []
    }

    override func tearDown() {
        coordinator.stopConversationTranscription()
        cancellables = nil
        super.tearDown()
    }

    func testConversationPublisherReceivesUpdates() {
        let expect = expectation(description: "Expect conversation update")
        
        coordinator.conversationPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: { update in
                XCTAssertEqual(update.message.content, "Hello world")
                XCTAssertNil(update.speaker)
                XCTAssertFalse(update.isNewSpeaker)
                expect.fulfill()
            })
            .store(in: &cancellables)
        
        // Send a transcription result
        let result = TranscriptionResult(text: "Hello world", speakerId: nil,
                                         confidence: 0.9, isFinal: true)
        speechService.transcriptionSubject.send(result)
        
        wait(for: [expect], timeout: 1.0)
    }

    func testAddSpeakerAndReceiveUpdate() {
        let speakerId = UUID()
        let speaker = Speaker(id: speakerId, name: "Alice", isCurrentUser: false)
        coordinator.addSpeaker(speaker)

        let expect = expectation(description: "Expect update with speaker info")
        
        coordinator.conversationPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: { update in
                XCTAssertEqual(update.message.content, "Test")
                XCTAssertNotNil(update.speaker)
                XCTAssertEqual(update.speaker?.id, speakerId)
                // Since speaker was pre-added, isNewSpeaker should be false
                XCTAssertFalse(update.isNewSpeaker)
                expect.fulfill()
            })
            .store(in: &cancellables)

        let result = TranscriptionResult(text: "Test", speakerId: speakerId,
                                         confidence: 0.8, isFinal: true)
        speechService.transcriptionSubject.send(result)
        
        wait(for: [expect], timeout: 1.0)
    }
    
    // MARK: - Streaming Transcription Tests
    
    func testPartialTranscriptionHandling() {
        let expectPartial = expectation(description: "Expect partial transcription")
        let expectFinal = expectation(description: "Expect final transcription")
        
        var updateCount = 0
        coordinator.conversationPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: { update in
                updateCount += 1
                
                if updateCount == 1 {
                    // First update should be partial
                    XCTAssertFalse(update.message.isFinal)
                    XCTAssertEqual(update.message.content, "Hello")
                    expectPartial.fulfill()
                } else if updateCount == 2 {
                    // Second update should be final
                    XCTAssertTrue(update.message.isFinal)
                    XCTAssertEqual(update.message.content, "Hello world")
                    expectFinal.fulfill()
                }
            })
            .store(in: &cancellables)
        
        // Send partial result first
        let partialResult = TranscriptionResult(text: "Hello", confidence: 0.7, isFinal: false)
        speechService.transcriptionSubject.send(partialResult)
        
        // Send final result
        let finalResult = TranscriptionResult(text: "Hello world", confidence: 0.9, isFinal: true)
        speechService.transcriptionSubject.send(finalResult)
        
        wait(for: [expectPartial, expectFinal], timeout: 2.0)
    }
    
    func testEmptyTranscriptionFiltering() {
        let expect = expectation(description: "Should not receive empty transcription")
        expect.isInverted = true // We expect this NOT to be fulfilled
        
        coordinator.conversationPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                expect.fulfill() // This should not happen
            })
            .store(in: &cancellables)
        
        // Send empty transcription
        let emptyResult = TranscriptionResult(text: "", confidence: 0.0, isFinal: true)
        speechService.transcriptionSubject.send(emptyResult)
        
        // Send whitespace-only transcription
        let whitespaceResult = TranscriptionResult(text: "   \n\t   ", confidence: 0.0, isFinal: true)
        speechService.transcriptionSubject.send(whitespaceResult)
        
        wait(for: [expect], timeout: 1.0)
    }
    
    func testShortPartialTranscriptionFiltering() {
        let expect = expectation(description: "Should not receive very short partial transcription")
        expect.isInverted = true
        
        coordinator.conversationPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                expect.fulfill()
            })
            .store(in: &cancellables)
        
        // Send very short partial result (should be filtered)
        let shortPartial = TranscriptionResult(text: "a", confidence: 0.5, isFinal: false)
        speechService.transcriptionSubject.send(shortPartial)
        
        wait(for: [expect], timeout: 1.0)
    }
    
    func testLongPartialTranscriptionPassing() {
        let expect = expectation(description: "Should receive longer partial transcription")
        
        coordinator.conversationPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: { update in
                XCTAssertFalse(update.message.isFinal)
                XCTAssertEqual(update.message.content, "hello world")
                expect.fulfill()
            })
            .store(in: &cancellables)
        
        // Send longer partial result (should pass through)
        let longPartial = TranscriptionResult(text: "hello world", confidence: 0.7, isFinal: false)
        speechService.transcriptionSubject.send(longPartial)
        
        wait(for: [expect], timeout: 1.0)
    }
    
    func testPartialTranscriptionThrottling() {
        let expectFirst = expectation(description: "Expect first partial")
        let expectSecond = expectation(description: "Expect throttled partial")
        expectSecond.isInverted = true // Should not be fulfilled due to throttling
        
        var updateCount = 0
        coordinator.conversationPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: { update in
                updateCount += 1
                if updateCount == 1 {
                    expectFirst.fulfill()
                } else if updateCount == 2 {
                    expectSecond.fulfill()
                }
            })
            .store(in: &cancellables)
        
        // Send two partial results quickly (second should be throttled)
        let partial1 = TranscriptionResult(text: "hello", confidence: 0.7, isFinal: false)
        let partial2 = TranscriptionResult(text: "hello wo", confidence: 0.7, isFinal: false)
        
        speechService.transcriptionSubject.send(partial1)
        speechService.transcriptionSubject.send(partial2) // Should be throttled
        
        wait(for: [expectFirst, expectSecond], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testTranscriptionError() {
        let expect = expectation(description: "Expect error completion")
        
        coordinator.conversationPublisher
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTAssertNotNil(error)
                    expect.fulfill()
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        // Simulate error
        speechService.transcriptionSubject.send(completion: .failure(.recognitionFailed(NSError(domain: "test", code: 1))))
        
        wait(for: [expect], timeout: 1.0)
    }
    
    // MARK: - Audio Processing Tests
    
    func testAudioProcessingFlow() {
        coordinator.startConversationTranscription()
        XCTAssertTrue(audioManager.isRecording)
        
        // Simulate audio data
        audioManager.simulateAudioFrame()
        
        coordinator.stopConversationTranscription()
        XCTAssertFalse(audioManager.isRecording)
    }
    
    func testVoiceActivityDetection() {
        let expect = expectation(description: "Expect voice activity processing")
        
        coordinator.conversationPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                expect.fulfill()
            })
            .store(in: &cancellables)
        
        coordinator.startConversationTranscription()
        
        // Simulate voice activity with audio
        audioManager.simulateVoiceActivity()
        
        // Simulate transcription result
        let result = TranscriptionResult(text: "Voice detected", confidence: 0.8, isFinal: true)
        speechService.transcriptionSubject.send(result)
        
        wait(for: [expect], timeout: 1.0)
        coordinator.stopConversationTranscription()
    }
}