//
//  HelixTests.swift
//  HelixTests
//

import Testing
import XCTest
@testable import Helix

struct HelixTests {
    @Test func basicAppInitialization() async throws {
        // Test that the app can initialize without crashing
        let coordinator = AppCoordinator()
        #expect(coordinator != nil)
    }
    
    @Test func audioManagerCreation() async throws {
        let audioManager = AudioManager()
        #expect(audioManager != nil)
        #expect(!audioManager.isRecording)
    }
    
    @Test func speechRecognitionServiceCreation() async throws {
        let speechService = SpeechRecognitionService()
        #expect(speechService != nil)
        #expect(!speechService.isRecognizing)
    }
    
    @Test func glassesManagerCreation() async throws {
        let glassesManager = GlassesManager()
        #expect(glassesManager != nil)
    }
    
    @Test func hudContentCreation() async throws {
        let content = HUDContent(
            text: "Test message",
            style: HUDStyle(),
            position: HUDPosition.topCenter
        )
        
        #expect(content.text == "Test message")
        #expect(!content.id.isEmpty)
    }
    
    @Test func conversationMessageCreation() async throws {
        let message = ConversationMessage(
            content: "Test conversation message",
            speakerId: UUID(),
            confidence: 0.9,
            timestamp: Date().timeIntervalSince1970,
            isFinal: true,
            wordTimings: [],
            originalText: "Test conversation message"
        )
        
        #expect(message.content == "Test conversation message")
        #expect(message.confidence == 0.9)
        #expect(message.isFinal == true)
    }
    
    @Test func speakerCreation() async throws {
        let speaker = Speaker(name: "Test Speaker", isCurrentUser: false)
        
        #expect(speaker.name == "Test Speaker")
        #expect(speaker.isCurrentUser == false)
        #expect(speaker.id != UUID()) // Should have a valid UUID
    }
    
    @Test func appSettingsDefaults() async throws {
        let settings = AppSettings.default
        
        #expect(settings.enableFactChecking == true)
        #expect(settings.enableAutoSummary == true)
        #expect(settings.primaryLanguage?.identifier == "en-US")
        #expect(settings.noiseReductionLevel == 0.5)
    }
    
    @Test func factCheckResultCreation() async throws {
        let result = FactCheckResult(
            claim: "Test claim",
            isAccurate: true,
            explanation: "Test explanation",
            sources: [],
            confidence: 0.85,
            alternativeInfo: nil,
            category: .general,
            severity: .minor
        )
        
        #expect(result.claim == "Test claim")
        #expect(result.isAccurate == true)
        #expect(result.confidence == 0.85)
        #expect(result.category == .general)
    }
    
    @Test func analysisResultCreation() async throws {
        let factCheck = FactCheckResult(
            claim: "Test",
            isAccurate: true,
            explanation: "Explanation",
            sources: [],
            confidence: 0.8,
            alternativeInfo: nil,
            category: .general,
            severity: .minor
        )
        
        let result = AnalysisResult(
            type: .factCheck,
            content: .factCheck(factCheck),
            confidence: 0.8,
            provider: .openai
        )
        
        #expect(result.type == .factCheck)
        #expect(result.confidence == 0.8)
        #expect(result.provider == .openai)
    }
    
    @Test func hudPositionConstants() async throws {
        #expect(HUDPosition.topCenter.x == 0.5)
        #expect(HUDPosition.topCenter.y == 0.1)
        #expect(HUDPosition.topCenter.alignment == .center)
        
        #expect(HUDPosition.topLeft.x == 0.1)
        #expect(HUDPosition.topLeft.alignment == .left)
        
        #expect(HUDPosition.topRight.x == 0.9)
        #expect(HUDPosition.topRight.alignment == .right)
    }
}

// MARK: - Integration Test Suite

class HelixIntegrationTests: XCTestCase {
    
    func testCompleteSystemInitialization() {
        let coordinator = AppCoordinator()
        
        XCTAssertNotNil(coordinator)
        XCTAssertFalse(coordinator.isRecording)
        XCTAssertEqual(coordinator.connectionState, .disconnected)
        XCTAssertTrue(coordinator.currentConversation.isEmpty)
        XCTAssertFalse(coordinator.speakers.isEmpty) // Should have default user
    }
    
    func testAudioToTranscriptionPipeline() {
        let audioManager = MockAudioManager()
        let speechService = MockSpeechRecognitionService()
        
        XCTAssertNotNil(audioManager)
        XCTAssertNotNil(speechService)
        
        // Test that services can be initialized together
        XCTAssertFalse(audioManager.isRecording)
        XCTAssertFalse(speechService.isRecognizing)
    }
    
    func testLLMToGlassesPipeline() {
        let llmService = LLMService(providers: [:])
        let glassesManager = MockGlassesManager()
        
        XCTAssertNotNil(llmService)
        XCTAssertNotNil(glassesManager)
    }
    
    func testEndToEndDataFlow() {
        // This test validates that all the data structures
        // can flow through the complete pipeline
        
        // 1. Create audio data
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        let processedAudio = ProcessedAudio(
            buffer: buffer,
            timestamp: 0,
            sampleRate: 16000,
            channelCount: 1
        )
        XCTAssertNotNil(processedAudio)
        
        // 2. Create transcription result
        let transcription = TranscriptionResult(
            text: "Test transcription",
            confidence: 0.9,
            isFinal: true
        )
        XCTAssertNotNil(transcription)
        
        // 3. Create conversation message
        let message = ConversationMessage(from: transcription)
        XCTAssertEqual(message.content, "Test transcription")
        
        // 4. Create analysis result
        let factCheck = FactCheckResult(
            claim: "Test claim",
            isAccurate: true,
            explanation: "Explanation",
            sources: [],
            confidence: 0.8,
            alternativeInfo: nil,
            category: .general,
            severity: .minor
        )
        
        let analysis = AnalysisResult(
            type: .factCheck,
            content: .factCheck(factCheck),
            confidence: 0.8
        )
        XCTAssertNotNil(analysis)
        
        // 5. Create HUD content
        let hudContent = HUDContentFactory.createFactCheckDisplay(factCheck)
        XCTAssertNotNil(hudContent)
        XCTAssertFalse(hudContent.text.isEmpty)
    }
}
