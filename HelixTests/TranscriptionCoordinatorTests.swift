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
}