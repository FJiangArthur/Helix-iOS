import XCTest
import Combine
@testable import Helix

class LLMServiceTests: XCTestCase {
    var llmService: LLMService!
    var mockOpenAIProvider: MockLLMProvider!
    var mockAnthropicProvider: MockLLMProvider!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockOpenAIProvider = MockLLMProvider(provider: .openai)
        mockAnthropicProvider = MockLLMProvider(provider: .anthropic)
        
        llmService = LLMService(
            providers: [
                .openai: mockOpenAIProvider,
                .anthropic: mockAnthropicProvider
            ]
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        llmService = nil
        mockOpenAIProvider = nil
        mockAnthropicProvider = nil
        cancellables = nil
        try super.tearDownWithError()
    }
    
    func testFactCheckingService() {
        let expectation = XCTestExpectation(description: "Fact checking should complete")
        
        let claim = "The United States has 50 states"
        
        llmService.factCheck(claim, context: nil)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fact checking failed: \(error)")
                    }
                },
                receiveValue: { result in
                    XCTAssertEqual(result.claim, claim)
                    XCTAssertTrue(result.isAccurate)
                    XCTAssertGreaterThan(result.confidence, 0.5)
                    XCTAssertNotNil(result.explanation)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConversationSummarization() {
        let expectation = XCTestExpectation(description: "Summarization should complete")
        
        let messages = createMockConversationMessages()
        
        llmService.summarizeConversation(messages)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Summarization failed: \(error)")
                    }
                },
                receiveValue: { summary in
                    XCTAssertFalse(summary.isEmpty)
                    XCTAssertLessThan(summary.count, 500) // Summary should be concise
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testClaimDetection() {
        let expectation = XCTestExpectation(description: "Claim detection should complete")
        
        let text = "The Earth has a population of 8 billion people. Water boils at 100 degrees Celsius."
        
        llmService.detectClaims(in: text)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Claim detection failed: \(error)")
                    }
                },
                receiveValue: { claims in
                    XCTAssertGreaterThan(claims.count, 0)
                    
                    for claim in claims {
                        XCTAssertFalse(claim.text.isEmpty)
                        XCTAssertGreaterThan(claim.confidence, 0.0)
                        XCTAssertLessThanOrEqual(claim.confidence, 1.0)
                    }
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testActionItemExtraction() {
        let expectation = XCTestExpectation(description: "Action item extraction should complete")
        
        let messages = createMockActionItemMessages()
        
        llmService.extractActionItems(from: messages)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Action item extraction failed: \(error)")
                    }
                },
                receiveValue: { actionItems in
                    XCTAssertGreaterThan(actionItems.count, 0)
                    
                    for item in actionItems {
                        XCTAssertFalse(item.description.isEmpty)
                        XCTAssertNotNil(item.id)
                    }
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConversationAnalysis() {
        let expectation = XCTestExpectation(description: "Conversation analysis should complete")
        
        let context = createMockConversationContext()
        
        llmService.analyzeConversation(context)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Conversation analysis failed: \(error)")
                    }
                },
                receiveValue: { result in
                    XCTAssertEqual(result.type, context.analysisType)
                    XCTAssertGreaterThan(result.confidence, 0.0)
                    XCTAssertLessThanOrEqual(result.confidence, 1.0)
                    XCTAssertNotNil(result.content)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testProviderFailover() {
        let expectation = XCTestExpectation(description: "Provider failover should work")
        
        // Make the primary provider fail
        mockOpenAIProvider.shouldFail = true
        
        let context = createMockConversationContext()
        
        llmService.analyzeConversation(context)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Analysis should succeed with failover: \(error)")
                    }
                },
                receiveValue: { result in
                    // Should succeed with Anthropic provider
                    XCTAssertEqual(result.provider, .anthropic)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testRateLimiting() {
        let expectation = XCTestExpectation(description: "Rate limiting should work")
        expectation.expectedFulfillmentCount = 5
        
        // Send multiple rapid requests
        for _ in 0..<5 {
            let context = createMockConversationContext()
            
            llmService.analyzeConversation(context)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            // Some requests might be rate limited
                            if case .rateLimitExceeded = error {
                                expectation.fulfill()
                            }
                        }
                    },
                    receiveValue: { _ in
                        expectation.fulfill()
                    }
                )
                .store(in: &cancellables)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockConversationMessages() -> [ConversationMessage] {
        let speaker1 = UUID()
        let speaker2 = UUID()
        
        return [
            ConversationMessage(
                content: "Let's discuss the quarterly results.",
                speakerId: speaker1,
                confidence: 0.9,
                timestamp: Date().timeIntervalSince1970 - 300,
                isFinal: true,
                wordTimings: [],
                originalText: "Let's discuss the quarterly results."
            ),
            ConversationMessage(
                content: "Revenue increased by 15% this quarter.",
                speakerId: speaker2,
                confidence: 0.85,
                timestamp: Date().timeIntervalSince1970 - 250,
                isFinal: true,
                wordTimings: [],
                originalText: "Revenue increased by 15% this quarter."
            ),
            ConversationMessage(
                content: "That's excellent news! What drove the growth?",
                speakerId: speaker1,
                confidence: 0.92,
                timestamp: Date().timeIntervalSince1970 - 200,
                isFinal: true,
                wordTimings: [],
                originalText: "That's excellent news! What drove the growth?"
            )
        ]
    }
    
    private func createMockActionItemMessages() -> [ConversationMessage] {
        return [
            ConversationMessage(
                content: "We need to follow up with the client by Friday.",
                speakerId: UUID(),
                confidence: 0.9,
                timestamp: Date().timeIntervalSince1970,
                isFinal: true,
                wordTimings: [],
                originalText: "We need to follow up with the client by Friday."
            ),
            ConversationMessage(
                content: "Please send me the report after the meeting.",
                speakerId: UUID(),
                confidence: 0.88,
                timestamp: Date().timeIntervalSince1970,
                isFinal: true,
                wordTimings: [],
                originalText: "Please send me the report after the meeting."
            )
        ]
    }
    
    private func createMockConversationContext() -> ConversationContext {
        let messages = createMockConversationMessages()
        let speakers = [
            Speaker(name: "Alice", isCurrentUser: false),
            Speaker(name: "Bob", isCurrentUser: true)
        ]
        
        return ConversationContext(
            messages: messages,
            speakers: speakers,
            analysisType: .factCheck
        )
    }
}

// MARK: - Mock LLM Provider

class MockLLMProvider: LLMProviderProtocol {
    let provider: LLMProvider
    var shouldFail = false
    var delay: TimeInterval = 0.5
    
    init(provider: LLMProvider) {
        self.provider = provider
    }
    
    func analyze(_ context: ConversationContext) -> AnyPublisher<AnalysisResult, LLMError> {
        return Future<AnalysisResult, LLMError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.serviceUnavailable))
                return
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + self.delay) {
                if self.shouldFail {
                    promise(.failure(.networkError(URLError(.networkConnectionLost))))
                    return
                }
                
                let result = self.createMockAnalysisResult(for: context)
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func isAvailable() -> Bool {
        return !shouldFail
    }
    
    func estimateCost(for context: ConversationContext) -> Float {
        return 0.01 // Mock cost
    }
    
    private func createMockAnalysisResult(for context: ConversationContext) -> AnalysisResult {
        let content: AnalysisContent
        
        switch context.analysisType {
        case .factCheck:
            let factCheckResult = FactCheckResult(
                claim: "Mock claim",
                isAccurate: true,
                explanation: "This is a mock explanation",
                sources: [],
                confidence: 0.85,
                alternativeInfo: nil,
                category: .general,
                severity: .minor
            )
            content = .factCheck(factCheckResult)
            
        case .summarization:
            content = .summary("This is a mock summary of the conversation.")
            
        case .actionItems:
            let actionItems = [
                ActionItem(description: "Follow up with client"),
                ActionItem(description: "Send report")
            ]
            content = .actionItems(actionItems)
            
        case .sentiment:
            let sentimentAnalysis = SentimentAnalysis(
                overallSentiment: .positive,
                speakerSentiments: [:],
                emotionalTone: .casual,
                confidence: 0.8
            )
            content = .sentiment(sentimentAnalysis)
            
        case .keyTopics:
            content = .topics(["Business", "Growth", "Revenue"])
            
        case .translation:
            let translation = TranslationResult(
                originalText: "Original text",
                translatedText: "Translated text",
                sourceLanguage: "en",
                targetLanguage: "es",
                confidence: 0.9
            )
            content = .translation(translation)
            
        case .clarification:
            content = .text("Mock clarification text")
        }
        
        return AnalysisResult(
            type: context.analysisType,
            content: content,
            confidence: 0.85,
            provider: provider
        )
    }
}