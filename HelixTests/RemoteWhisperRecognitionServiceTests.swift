import XCTest
import AVFoundation
import Combine
@testable import Helix

class RemoteWhisperRecognitionServiceTests: XCTestCase {
    var whisperService: RemoteWhisperRecognitionService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        whisperService = RemoteWhisperRecognitionService(apiKey: "test-api-key")
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        whisperService?.stopRecognition()
        whisperService = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertNotNil(whisperService)
        XCTAssertFalse(whisperService.isRecognizing)
    }
    
    func testStartRecognitionWithoutAPIKey() {
        // Test with empty API key
        whisperService = RemoteWhisperRecognitionService(apiKey: "")
        
        let expectation = XCTestExpectation(description: "Should fail without API key")
        
        whisperService.transcriptionPublisher
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTAssertEqual(error, .serviceUnavailable)
                    expectation.fulfill()
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        whisperService.startStreamingRecognition()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStartStopRecognition() {
        XCTAssertFalse(whisperService.isRecognizing)
        
        whisperService.startStreamingRecognition()
        XCTAssertTrue(whisperService.isRecognizing)
        
        whisperService.stopRecognition()
        XCTAssertFalse(whisperService.isRecognizing)
    }
    
    func testAudioBufferProcessing() {
        // Create mock audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // Fill with some mock audio data
        if let audioData = buffer.floatChannelData {
            for frame in 0..<Int(buffer.frameLength) {
                audioData[0][frame] = sin(2.0 * .pi * Float(frame) / 100.0) * 0.1 // Sine wave
            }
        }
        
        whisperService.startStreamingRecognition()
        
        // Should not crash
        XCTAssertNoThrow(whisperService.processAudioBuffer(buffer))
        
        whisperService.stopRecognition()
    }
    
    func testAudioBufferIgnoredWhenNotRecognizing() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // Should not crash even when not recognizing
        XCTAssertNoThrow(whisperService.processAudioBuffer(buffer))
    }
    
    func testLanguageConfiguration() {
        let locale = Locale(identifier: "es-ES")
        XCTAssertNoThrow(whisperService.setLanguage(locale))
    }
    
    func testCustomVocabularyConfiguration() {
        let words = ["Helix", "transcription", "OpenAI"]
        XCTAssertNoThrow(whisperService.addCustomVocabulary(words))
    }
    
    func testChunkProcessingTimer() {
        let expectation = XCTestExpectation(description: "Should process audio chunks periodically")
        expectation.expectedFulfillmentCount = 2 // Expect at least 2 chunks
        
        // Mock a successful response for testing
        let mockService = MockRemoteWhisperService(apiKey: "test-key")
        
        mockService.transcriptionPublisher
            .sink(receiveCompletion: { _ in }, receiveValue: { result in
                XCTAssertNotNil(result.text)
                expectation.fulfill()
            })
            .store(in: &cancellables)
        
        mockService.startStreamingRecognition()
        
        // Simulate audio buffers
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        for _ in 0..<5 {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
            buffer.frameLength = 1024
            mockService.processAudioBuffer(buffer)
        }
        
        wait(for: [expectation], timeout: 5.0)
        mockService.stopRecognition()
    }
    
    func testWAVDataConversion() {
        // Create audio buffer with known data
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100)!
        buffer.frameLength = 100
        
        // Fill with test data
        if let audioData = buffer.floatChannelData {
            for frame in 0..<Int(buffer.frameLength) {
                audioData[0][frame] = Float(frame) / Float(buffer.frameLength) * 0.5
            }
        }
        
        // This is testing internal functionality, so we'd need to expose the method or test indirectly
        // For now, just verify it doesn't crash during processing
        whisperService.startStreamingRecognition()
        XCTAssertNoThrow(whisperService.processAudioBuffer(buffer))
        whisperService.stopRecognition()
    }
    
    func testMultipleStartStopCycles() {
        for _ in 0..<3 {
            whisperService.startStreamingRecognition()
            XCTAssertTrue(whisperService.isRecognizing)
            
            whisperService.stopRecognition()
            XCTAssertFalse(whisperService.isRecognizing)
        }
    }
    
    func testStartWhenAlreadyRunning() {
        whisperService.startStreamingRecognition()
        XCTAssertTrue(whisperService.isRecognizing)
        
        // Starting again should not crash
        whisperService.startStreamingRecognition()
        XCTAssertTrue(whisperService.isRecognizing)
        
        whisperService.stopRecognition()
    }
    
    func testStopWhenNotRunning() {
        XCTAssertFalse(whisperService.isRecognizing)
        
        // Stopping when not running should not crash
        XCTAssertNoThrow(whisperService.stopRecognition())
        XCTAssertFalse(whisperService.isRecognizing)
    }
}

// MARK: - Mock Remote Whisper Service for Testing

class MockRemoteWhisperService: SpeechRecognitionServiceProtocol {
    private let transcriptionSubject = PassthroughSubject<TranscriptionResult, TranscriptionError>()
    private(set) var isRecognizing = false
    private let apiKey: String
    private var chunkTimer: Timer?
    
    var transcriptionPublisher: AnyPublisher<TranscriptionResult, TranscriptionError> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func startStreamingRecognition() {
        guard !isRecognizing else { return }
        guard !apiKey.isEmpty else {
            transcriptionSubject.send(completion: .failure(.serviceUnavailable))
            return
        }
        
        isRecognizing = true
        
        // Start timer to simulate periodic chunk processing
        chunkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.simulateWhisperResponse()
        }
    }
    
    func stopRecognition() {
        guard isRecognizing else { return }
        isRecognizing = false
        chunkTimer?.invalidate()
        chunkTimer = nil
        
        // Send final result
        simulateWhisperResponse(isFinal: true)
    }
    
    func setLanguage(_ locale: Locale) {
        // Mock implementation
    }
    
    func addCustomVocabulary(_ words: [String]) {
        // Mock implementation
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRecognizing else { return }
        // Mock processing - in real implementation this would accumulate audio
    }
    
    private func simulateWhisperResponse(isFinal: Bool = false) {
        guard isRecognizing || isFinal else { return }
        
        let mockTexts = [
            "This is a test transcription from Whisper.",
            "Remote speech recognition is working.",
            "OpenAI Whisper API integration successful.",
            "Chunk-based audio processing complete."
        ]
        
        let mockText = mockTexts.randomElement() ?? "Mock transcription"
        
        let result = TranscriptionResult(
            text: mockText,
            confidence: 0.95, // Whisper typically has high confidence
            isFinal: isFinal,
            wordTimings: createMockWordTimings(for: mockText),
            alternatives: []
        )
        
        transcriptionSubject.send(result)
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
                confidence: 1.0 // Whisper doesn't provide word-level confidence
            ))
            currentTime += duration + 0.1
        }
        
        return timings
    }
}