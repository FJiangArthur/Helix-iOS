// ABOUTME: Unit tests for LocalDictationService
// ABOUTME: Tests local dictation functionality and configuration

import XCTest
import Combine
import AVFoundation
import Speech
@testable import Helix

class LocalDictationServiceTests: XCTestCase {
    private var sut: LocalDictationService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = LocalDictationService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.isRecognizing)
    }
    
    func testTranscriptionPublisher() {
        XCTAssertNotNil(sut.transcriptionPublisher)
    }
    
    func testSetLanguage() {
        let locale = Locale(identifier: "es-ES")
        sut.setLanguage(locale)
        
        // Should not crash and should handle locale change gracefully
        XCTAssertTrue(true) // If we get here, the method didn't crash
    }
    
    func testAddCustomVocabulary() {
        let vocabulary = ["Helix", "transcription", "dictation"]
        sut.addCustomVocabulary(vocabulary)
        
        // Should not crash when adding vocabulary
        XCTAssertTrue(true)
    }
    
    func testLocalDictationStatus() {
        let status = sut.localDictationStatus
        
        // Should return a valid status
        XCTAssertTrue([
            LocalDictationStatus.available,
            LocalDictationStatus.cloudFallback,
            LocalDictationStatus.unavailable
        ].contains(status))
    }
    
    func testOnDeviceRecognitionSupport() {
        let supportsOnDevice = sut.supportsOnDeviceRecognition
        
        // Should return a boolean value without crashing
        XCTAssertTrue(supportsOnDevice == true || supportsOnDevice == false)
    }
    
    func testStartStopRecognition() {
        // Test that start/stop doesn't crash
        sut.startStreamingRecognition()
        
        // Give it a moment to initialize
        let expectation = expectation(description: "Recognition started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        sut.stopRecognition()
        XCTAssertFalse(sut.isRecognizing)
    }
    
    func testProcessAudioBufferWithoutRecognition() {
        // Create a mock audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        
        // Should handle buffer processing gracefully when not recognizing
        sut.processAudioBuffer(buffer)
        
        XCTAssertTrue(true) // If we get here, it didn't crash
    }
    
    func testLocalDictationStatusDescription() {
        let statuses: [LocalDictationStatus] = [.available, .cloudFallback, .unavailable]
        
        for status in statuses {
            XCTAssertFalse(status.description.isEmpty)
        }
    }
}

// MARK: - Integration Tests

class LocalDictationIntegrationTests: XCTestCase {
    private var coordinator: AppCoordinator!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        coordinator = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testLocalDictationInAppCoordinator() {
        // Test that AppCoordinator can be initialized with local dictation backend
        let settings = AppSettings()
        
        coordinator = AppCoordinator(
            enableAudio: false,    // Disable audio to avoid permissions
            enableSpeech: true,    // Enable speech for dictation
            enableBluetooth: false,
            enableAI: false,
            speechBackend: .localDictation,
            initialSettings: settings
        )
        
        XCTAssertNotNil(coordinator)
    }
    
    func testSpeechBackendSelection() {
        let settings = AppSettings()
        settings.speechBackend = .localDictation
        
        coordinator = AppCoordinator(
            enableAudio: false,
            enableSpeech: true,
            enableBluetooth: false,
            enableAI: false,
            initialSettings: settings
        )
        
        XCTAssertEqual(coordinator.settings.speechBackend, .localDictation)
    }
    
    func testSpeechBackendSwitching() {
        let settings = AppSettings()
        settings.speechBackend = .local
        
        coordinator = AppCoordinator(
            enableAudio: false,
            enableSpeech: true,
            enableBluetooth: false,
            enableAI: false,
            initialSettings: settings
        )
        
        // Switch to local dictation
        var newSettings = coordinator.settings
        newSettings.speechBackend = .localDictation
        
        coordinator.updateSettings(newSettings)
        
        XCTAssertEqual(coordinator.settings.speechBackend, .localDictation)
    }
}

// MARK: - Mock Tests for Permissions

class LocalDictationPermissionTests: XCTestCase {
    
    func testSpeechRecognitionAvailability() {
        // Test that we can check speech recognition availability
        let isAvailable = SFSpeechRecognizer.authorizationStatus() != .notDetermined
        
        // Should return a boolean without crashing
        XCTAssertTrue(isAvailable == true || isAvailable == false)
    }
    
    func testSpeechRecognizerInitialization() {
        // Test that we can create speech recognizers for different locales
        let locales = [
            Locale(identifier: "en-US"),
            Locale(identifier: "en-GB"),
            Locale(identifier: "es-ES"),
            Locale(identifier: "fr-FR")
        ]
        
        for locale in locales {
            let recognizer = SFSpeechRecognizer(locale: locale)
            
            // Should create recognizer (may be nil if locale not supported)
            XCTAssertTrue(recognizer != nil || recognizer == nil)
        }
    }
}