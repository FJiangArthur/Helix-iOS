import XCTest
import Combine
@testable import Helix

class ConversationViewModelTests: XCTestCase {
    var viewModel: ConversationViewModel!
    var mockCoordinator: MockTranscriptionCoordinator!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockCoordinator = MockTranscriptionCoordinator()
        viewModel = ConversationViewModel(transcriptionCoordinator: mockCoordinator)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        viewModel = nil
        mockCoordinator = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(viewModel.messages.count, 0)
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.liveTranscription)
    }
    
    func testStartStopRecording() {
        viewModel.start()
        
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertTrue(viewModel.isProcessing)
        XCTAssertEqual(viewModel.messages.count, 0) // Messages should be cleared
        XCTAssertNil(viewModel.liveTranscription)
        
        viewModel.stop()
        
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertNil(viewModel.liveTranscription)
    }
    
    func testLiveTranscriptionUpdates() {
        let expectation = XCTestExpectation(description: "Live transcription should update")
        
        viewModel.$liveTranscription
            .sink { liveTranscription in
                if liveTranscription == "Hello" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Send partial transcription
        let partialMessage = ConversationMessage(
            content: "Hello",
            speakerId: UUID(),
            confidence: 0.8,
            timestamp: Date().timeIntervalSince1970,
            isFinal: false,
            wordTimings: [],
            originalText: "Hello"
        )
        
        let update = ConversationUpdate(
            message: partialMessage,
            speaker: nil,
            isNewSpeaker: false,
            timestamp: Date().timeIntervalSince1970
        )
        
        mockCoordinator.simulateUpdate(update)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFinalTranscriptionAddsMessage() {
        let expectation = XCTestExpectation(description: "Final transcription should add message")
        
        viewModel.$messages
            .sink { messages in
                if messages.count == 1 && messages[0].content == "Hello world" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Send final transcription
        let finalMessage = ConversationMessage(
            content: "Hello world",
            speakerId: UUID(),
            confidence: 0.9,
            timestamp: Date().timeIntervalSince1970,
            isFinal: true,
            wordTimings: [],
            originalText: "Hello world"
        )
        
        let update = ConversationUpdate(
            message: finalMessage,
            speaker: nil,
            isNewSpeaker: false,
            timestamp: Date().timeIntervalSince1970
        )
        
        mockCoordinator.simulateUpdate(update)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPartialToFinalTranscriptionFlow() {
        let expectLive = XCTestExpectation(description: "Should receive live transcription")
        let expectFinal = XCTestExpectation(description: "Should receive final message")
        let expectLiveCleared = XCTestExpectation(description: "Live transcription should be cleared")
        
        var liveUpdateCount = 0
        var messageUpdateCount = 0
        
        viewModel.$liveTranscription
            .sink { liveTranscription in
                if liveTranscription == "Hello" {
                    liveUpdateCount += 1
                    expectLive.fulfill()
                } else if liveTranscription == nil && liveUpdateCount > 0 {
                    expectLiveCleared.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.$messages
            .sink { messages in
                if messages.count == 1 && messages[0].content == "Hello world" {
                    messageUpdateCount += 1
                    expectFinal.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Send partial transcription
        let partialMessage = ConversationMessage(
            content: "Hello",
            speakerId: UUID(),
            confidence: 0.7,
            timestamp: Date().timeIntervalSince1970,
            isFinal: false,
            wordTimings: [],
            originalText: "Hello"
        )
        
        let partialUpdate = ConversationUpdate(
            message: partialMessage,
            speaker: nil,
            isNewSpeaker: false,
            timestamp: Date().timeIntervalSince1970
        )
        
        mockCoordinator.simulateUpdate(partialUpdate)
        
        // Send final transcription
        let finalMessage = ConversationMessage(
            content: "Hello world",
            speakerId: UUID(),
            confidence: 0.9,
            timestamp: Date().timeIntervalSince1970,
            isFinal: true,
            wordTimings: [],
            originalText: "Hello world"
        )
        
        let finalUpdate = ConversationUpdate(
            message: finalMessage,
            speaker: nil,
            isNewSpeaker: false,
            timestamp: Date().timeIntervalSince1970
        )
        
        mockCoordinator.simulateUpdate(finalUpdate)
        
        wait(for: [expectLive, expectFinal, expectLiveCleared], timeout: 2.0)
    }
    
    func testErrorHandling() {
        let expectation = XCTestExpectation(description: "Error should be handled")
        
        viewModel.$errorMessage
            .sink { errorMessage in
                if errorMessage == "Test error" {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockCoordinator.simulateError(TranscriptionError.recognitionFailed(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])))
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testProcessingStateManagement() {
        viewModel.start()
        XCTAssertTrue(viewModel.isProcessing)
        
        // Simulate receiving a transcription (should clear processing state)
        let message = ConversationMessage(
            content: "Test",
            speakerId: UUID(),
            confidence: 0.8,
            timestamp: Date().timeIntervalSince1970,
            isFinal: true,
            wordTimings: [],
            originalText: "Test"
        )
        
        let update = ConversationUpdate(
            message: message,
            speaker: nil,
            isNewSpeaker: false,
            timestamp: Date().timeIntervalSince1970
        )
        
        mockCoordinator.simulateUpdate(update)
        
        XCTAssertFalse(viewModel.isProcessing)
    }
    
    func testMultipleMessages() {
        let expectation = XCTestExpectation(description: "Should handle multiple messages")
        expectation.expectedFulfillmentCount = 3
        
        viewModel.$messages
            .sink { messages in
                if !messages.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Send multiple final messages
        for i in 1...3 {
            let message = ConversationMessage(
                content: "Message \(i)",
                speakerId: UUID(),
                confidence: 0.8,
                timestamp: Date().timeIntervalSince1970,
                isFinal: true,
                wordTimings: [],
                originalText: "Message \(i)"
            )
            
            let update = ConversationUpdate(
                message: message,
                speaker: nil,
                isNewSpeaker: false,
                timestamp: Date().timeIntervalSince1970
            )
            
            mockCoordinator.simulateUpdate(update)
        }
        
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(viewModel.messages.count, 3)
    }
}

// MARK: - Mock Transcription Coordinator

class MockTranscriptionCoordinator: TranscriptionCoordinatorProtocol {
    private let conversationSubject = PassthroughSubject<ConversationUpdate, TranscriptionError>()
    
    var conversationPublisher: AnyPublisher<ConversationUpdate, TranscriptionError> {
        conversationSubject.eraseToAnyPublisher()
    }
    
    func startConversationTranscription() {
        // Mock implementation
    }
    
    func stopConversationTranscription() {
        // Mock implementation
    }
    
    func addSpeaker(_ speaker: Speaker) {
        // Mock implementation
    }
    
    func trainSpeaker(_ speakerId: UUID, with samples: [AVAudioPCMBuffer]) {
        // Mock implementation
    }
    
    // Test helper methods
    func simulateUpdate(_ update: ConversationUpdate) {
        conversationSubject.send(update)
    }
    
    func simulateError(_ error: TranscriptionError) {
        conversationSubject.send(completion: .failure(error))
    }
}