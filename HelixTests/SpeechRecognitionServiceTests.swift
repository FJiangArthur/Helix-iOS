import XCTest
import Speech
import AVFoundation
import Combine
@testable import Helix

class SpeechRecognitionServiceTests: XCTestCase {
    var speechService: SpeechRecognitionService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        speechService = SpeechRecognitionService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        speechService?.stopRecognition()
        speechService = nil
        cancellables = nil
        try super.tearDownWithError()
    }
    
    func testSpeechServiceInitialization() {
        XCTAssertNotNil(speechService)
        XCTAssertFalse(speechService.isRecognizing)
    }
    
    func testStartStopRecognition() {
        // Note: These tests may fail in simulator without microphone access
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw XCTSkip("Speech recognition not authorized")
        }
        
        speechService.startStreamingRecognition()
        // Note: isRecognizing might be delayed due to async setup
        
        speechService.stopRecognition()
        XCTAssertFalse(speechService.isRecognizing)
    }
    
    func testTranscriptionPublisher() {
        let expectation = XCTestExpectation(description: "Transcription publisher should exist")
        expectation.isInverted = false // We expect this to be fulfilled
        
        speechService.transcriptionPublisher
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("Transcription error: \(error)")
                    case .finished:
                        print("Transcription finished")
                    }
                },
                receiveValue: { result in
                    XCTAssertNotNil(result.text)
                    XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
                    XCTAssertLessThanOrEqual(result.confidence, 1.0)
                    XCTAssertGreaterThan(result.timestamp, 0)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Start recognition and wait briefly
        speechService.startStreamingRecognition()
        
        // We'll wait a short time, but this test might not produce results in CI
        wait(for: [expectation], timeout: 1.0)
        
        speechService.stopRecognition()
    }
    
    func testLanguageConfiguration() {
        let locale = Locale(identifier: "es-ES")
        XCTAssertNoThrow(speechService.setLanguage(locale))
    }
    
    func testCustomVocabularyAddition() {
        let customWords = ["Helix", "transcription", "Even Realities"]
        XCTAssertNoThrow(speechService.addCustomVocabulary(customWords))
    }
    
    func testAudioBufferProcessing() {
        // Create a mock audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // This should not crash
        XCTAssertNoThrow(speechService.processAudioBuffer(buffer))
    }
}

// MARK: - Mock Speech Recognition Service

class MockSpeechRecognitionService: SpeechRecognitionServiceProtocol {
    let transcriptionSubject = PassthroughSubject<TranscriptionResult, TranscriptionError>()
    private(set) var isRecognizing = false
    private var currentLanguage: Locale = Locale(identifier: "en-US")
    private var customVocabulary: [String] = []
    
    var transcriptionPublisher: AnyPublisher<TranscriptionResult, TranscriptionError> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    func startStreamingRecognition() {
        isRecognizing = true
        
        // Simulate transcription results
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            self.sendMockTranscription()
        }
    }
    
    func stopRecognition() {
        isRecognizing = false
    }
    
    func setLanguage(_ locale: Locale) {
        currentLanguage = locale
    }
    
    func addCustomVocabulary(_ words: [String]) {
        customVocabulary.append(contentsOf: words)
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecognizing else { return }
        
        // Simulate processing delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            self.sendMockTranscription()
        }
    }
    
    private func sendMockTranscription() {
        guard isRecognizing else { return }
        
        let mockTexts = [
            "This is a test transcription.",
            "The weather is nice today.",
            "Artificial intelligence is fascinating.",
            "Even Realities glasses are innovative.",
            "Real-time conversation analysis works well."
        ]
        
        let mockText = mockTexts.randomElement() ?? "Test transcription"
        
        let result = TranscriptionResult(
            text: mockText,
            speakerId: UUID(),
            confidence: Float.random(in: 0.8...0.95),
            isFinal: Bool.random(),
            wordTimings: createMockWordTimings(for: mockText),
            alternatives: ["Alternative transcription"]
        )
        
        transcriptionSubject.send(result)
        
        // Continue if still recognizing
        if isRecognizing {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double.random(in: 1.0...3.0)) {
                self.sendMockTranscription()
            }
        }
    }
    
    private func createMockWordTimings(for text: String) -> [WordTiming] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var timings: [WordTiming] = []
        var currentTime: TimeInterval = 0
        
        for word in words {
            let duration = TimeInterval(word.count) * 0.1 + 0.2
            timings.append(WordTiming(
                word: word,
                startTime: currentTime,
                endTime: currentTime + duration,
                confidence: Float.random(in: 0.8...0.95)
            ))
            currentTime += duration + 0.1
        }
        
        return timings
    }
    
    func simulateError(_ error: TranscriptionError) {
        transcriptionSubject.send(completion: .failure(error))
    }
}