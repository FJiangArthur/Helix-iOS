import XCTest
import AVFoundation
import Combine
@testable import Helix

class AudioManagerTests: XCTestCase {
    var audioManager: AudioManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        audioManager = AudioManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        audioManager = nil
        cancellables = nil
        try super.tearDownWithError()
    }
    
    func testAudioManagerInitialization() {
        XCTAssertNotNil(audioManager)
        XCTAssertFalse(audioManager.isRecording)
    }
    
    func testAudioConfiguration() throws {
        XCTAssertNoThrow(try audioManager.configure(sampleRate: 16000, bufferDuration: 0.005))
    }
    
    func testStartStopRecording() throws {
        // Test starting recording
        XCTAssertNoThrow(try audioManager.startRecording())
        XCTAssertTrue(audioManager.isRecording)
        
        // Test stopping recording
        audioManager.stopRecording()
        XCTAssertFalse(audioManager.isRecording)
    }
    
    func testAudioPublisherExists() {
        let expectation = XCTestExpectation(description: "Audio publisher should exist")
        
        audioManager.audioPublisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { audio in
                    XCTAssertNotNil(audio.buffer)
                    XCTAssertGreaterThan(audio.sampleRate, 0)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Start recording to generate audio data
        do {
            try audioManager.startRecording()
            
            // Wait briefly for audio data
            wait(for: [expectation], timeout: 2.0)
            
            audioManager.stopRecording()
        } catch {
            XCTFail("Failed to start recording: \(error)")
        }
    }
    
    func testMultipleStartRecordingCalls() throws {
        // First call should succeed
        XCTAssertNoThrow(try audioManager.startRecording())
        XCTAssertTrue(audioManager.isRecording)
        
        // Second call should not throw but should not change state
        XCTAssertNoThrow(try audioManager.startRecording())
        XCTAssertTrue(audioManager.isRecording)
        
        audioManager.stopRecording()
    }
    
    func testStopRecordingWhenNotRecording() {
        XCTAssertFalse(audioManager.isRecording)
        
        // Should not crash or throw
        XCTAssertNoThrow(audioManager.stopRecording())
        XCTAssertFalse(audioManager.isRecording)
    }
    
    func testProcessedAudioProperties() throws {
        let expectation = XCTestExpectation(description: "Audio should have expected properties")
        expectation.expectedFulfillmentCount = 1
        
        audioManager.audioPublisher
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Audio processing failed: \(error)")
                    }
                },
                receiveValue: { audio in
                    XCTAssertGreaterThan(audio.duration, 0)
                    XCTAssertNotEqual(audio.id, UUID())
                    XCTAssertEqual(audio.channelCount, 1) // Mono audio
                    XCTAssertEqual(audio.sampleRate, 16000, accuracy: 100) // Allow some tolerance
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        try audioManager.startRecording()
        wait(for: [expectation], timeout: 3.0)
        audioManager.stopRecording()
    }
}

// MARK: - Mock Audio Manager for Testing

class MockAudioManager: AudioManagerProtocol {
    private let audioSubject = PassthroughSubject<ProcessedAudio, AudioError>()
    private(set) var isRecording = false
    private var configuredSampleRate: Double = 16000
    private var configuredBufferDuration: TimeInterval = 0.005
    
    var audioPublisher: AnyPublisher<ProcessedAudio, AudioError> {
        audioSubject.eraseToAnyPublisher()
    }
    
    func startRecording() throws {
        guard !isRecording else { return }
        isRecording = true
        
        // Simulate audio data
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            self.sendMockAudioData()
        }
    }
    
    func stopRecording() {
        isRecording = false
    }
    
    func configure(sampleRate: Double, bufferDuration: TimeInterval) throws {
        configuredSampleRate = sampleRate
        configuredBufferDuration = bufferDuration
    }
    
    private func sendMockAudioData() {
        guard isRecording else { return }
        
        // Create mock audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: configuredSampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        let processedAudio = ProcessedAudio(
            buffer: buffer,
            timestamp: AVAudioFramePosition(Date().timeIntervalSince1970 * configuredSampleRate),
            sampleRate: configuredSampleRate,
            channelCount: 1
        )
        
        audioSubject.send(processedAudio)
        
        // Continue sending data while recording
        if isRecording {
            DispatchQueue.global().asyncAfter(deadline: .now() + configuredBufferDuration) {
                self.sendMockAudioData()
            }
        }
    }
    
    func simulateError(_ error: AudioError) {
        audioSubject.send(completion: .failure(error))
    }
}