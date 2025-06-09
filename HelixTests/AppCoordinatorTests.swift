import XCTest
import Combine
@testable import Helix

@MainActor
class AppCoordinatorTests: XCTestCase {
    var coordinator: AppCoordinator!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        coordinator = AppCoordinator()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        coordinator = nil
        cancellables = nil
        try super.tearDownWithError()
    }
    
    func testAppCoordinatorInitialization() {
        XCTAssertNotNil(coordinator)
        XCTAssertFalse(coordinator.isRecording)
        XCTAssertEqual(coordinator.connectionState, .disconnected)
        XCTAssertEqual(coordinator.batteryLevel, 0.0)
        XCTAssertTrue(coordinator.currentConversation.isEmpty)
        XCTAssertTrue(coordinator.recentAnalysis.isEmpty)
        XCTAssertFalse(coordinator.speakers.isEmpty) // Should have default current user
        XCTAssertFalse(coordinator.isProcessing)
        XCTAssertNil(coordinator.errorMessage)
    }
    
    func testStartStopConversation() {
        // Test starting conversation
        XCTAssertFalse(coordinator.isRecording)
        XCTAssertFalse(coordinator.isProcessing)
        
        coordinator.startConversation()
        
        XCTAssertTrue(coordinator.isRecording)
        XCTAssertTrue(coordinator.isProcessing)
        XCTAssertTrue(coordinator.currentConversation.isEmpty)
        
        // Test stopping conversation
        coordinator.stopConversation()
        
        XCTAssertFalse(coordinator.isRecording)
        XCTAssertFalse(coordinator.isProcessing)
    }
    
    func testMultipleStartConversationCalls() {
        // First call should work
        coordinator.startConversation()
        XCTAssertTrue(coordinator.isRecording)
        
        // Second call should not change state
        coordinator.startConversation()
        XCTAssertTrue(coordinator.isRecording)
        
        coordinator.stopConversation()
    }
    
    func testStopConversationWhenNotRecording() {
        XCTAssertFalse(coordinator.isRecording)
        
        // Should not crash or change state
        coordinator.stopConversation()
        XCTAssertFalse(coordinator.isRecording)
        XCTAssertFalse(coordinator.isProcessing)
    }
    
    func testSpeakerManagement() {
        let initialSpeakerCount = coordinator.speakers.count
        
        // Add a new speaker
        coordinator.addSpeaker(name: "Test Speaker", isCurrentUser: false)
        
        XCTAssertEqual(coordinator.speakers.count, initialSpeakerCount + 1)
        
        let addedSpeaker = coordinator.speakers.last
        XCTAssertEqual(addedSpeaker?.name, "Test Speaker")
        XCTAssertFalse(addedSpeaker?.isCurrentUser ?? true)
    }
    
    func testCurrentUserSpeaker() {
        // Should have a default current user speaker
        let currentUserSpeakers = coordinator.speakers.filter { $0.isCurrentUser }
        XCTAssertEqual(currentUserSpeakers.count, 1)
        XCTAssertEqual(currentUserSpeakers.first?.name, "You")
    }
    
    func testClearConversation() {
        // Add some mock data
        coordinator.addSpeaker(name: "Test Speaker")
        
        // Simulate having conversation data
        let initialSpeakersCount = coordinator.speakers.count
        
        coordinator.clearConversation()
        
        XCTAssertTrue(coordinator.currentConversation.isEmpty)
        XCTAssertTrue(coordinator.recentAnalysis.isEmpty)
        
        // Speakers should remain
        XCTAssertEqual(coordinator.speakers.count, initialSpeakersCount)
    }
    
    func testExportConversation() {
        let export = coordinator.exportConversation()
        
        XCTAssertNotNil(export)
        XCTAssertEqual(export.messages.count, coordinator.currentConversation.count)
        XCTAssertFalse(export.speakers.isEmpty)
        XCTAssertNotNil(export.summary)
    }
    
    func testSettingsUpdate() {
        var newSettings = coordinator.settings
        newSettings.enableFactChecking = false
        newSettings.primaryLanguage = Locale(identifier: "es-ES")
        
        coordinator.updateSettings(newSettings)
        
        XCTAssertEqual(coordinator.settings.enableFactChecking, false)
        XCTAssertEqual(coordinator.settings.primaryLanguage?.identifier, "es-ES")
    }
    
    func testConversationMetrics() {
        XCTAssertEqual(coordinator.conversationDuration, 0)
        XCTAssertEqual(coordinator.messageCount, 0)
        XCTAssertEqual(coordinator.speakerCount, 0)
        
        // These would change if we had actual conversation data
        // In a real test scenario, we would inject mock conversation messages
    }
    
    func testIsConnectedToGlasses() {
        XCTAssertFalse(coordinator.isConnectedToGlasses)
        
        // This would change if we simulated a glasses connection
        // In a real test scenario, we would inject a mock glasses manager
    }
    
    func testGlassesConnectionFlow() {
        // Initial state
        XCTAssertFalse(coordinator.isConnectedToGlasses)
        XCTAssertEqual(coordinator.connectionState, .disconnected)
        
        // Note: In a real test, we would inject mock services
        // to actually test the connection flow without real hardware
        
        coordinator.connectToGlasses()
        
        // Connection would be attempted (but may fail in test environment)
        // The test validates that the method doesn't crash
    }
    
    func testGlassesDisconnection() {
        // Should not crash even if not connected
        XCTAssertNoThrow(coordinator.disconnectFromGlasses())
    }
    
    func testErrorHandling() {
        // Initial state should have no errors
        XCTAssertNil(coordinator.errorMessage)
        
        // Error handling would be tested with mock services
        // that can simulate various error conditions
    }
}

// MARK: - Integration Tests

@MainActor
class AppCoordinatorIntegrationTests: XCTestCase {
    var coordinator: AppCoordinator!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        coordinator = AppCoordinator()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        coordinator = nil
        cancellables = nil
        try super.tearDownWithError()
    }
    
    func testConversationWorkflow() {
        let expectation = XCTestExpectation(description: "Conversation workflow should complete")
        expectation.expectedFulfillmentCount = 3
        
        // Monitor state changes
        coordinator.$isRecording
            .sink { isRecording in
                print("Recording state changed: \(isRecording)")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        coordinator.$isProcessing
            .sink { isProcessing in
                print("Processing state changed: \(isProcessing)")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Start conversation
        coordinator.startConversation()
        
        // Wait briefly then stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.coordinator.stopConversation()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSpeakerWorkflow() {
        let expectation = XCTestExpectation(description: "Speaker workflow should complete")
        
        // Add speaker
        coordinator.addSpeaker(name: "Integration Test Speaker", isCurrentUser: false)
        
        // Verify speaker was added
        let addedSpeaker = coordinator.speakers.first { $0.name == "Integration Test Speaker" }
        XCTAssertNotNil(addedSpeaker)
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSettingsWorkflow() {
        let expectation = XCTestExpectation(description: "Settings workflow should complete")
        
        let originalSettings = coordinator.settings
        
        // Update settings
        var newSettings = originalSettings
        newSettings.enableFactChecking = !originalSettings.enableFactChecking
        newSettings.noiseReductionLevel = 0.8
        
        coordinator.updateSettings(newSettings)
        
        // Verify settings were updated
        XCTAssertEqual(coordinator.settings.enableFactChecking, newSettings.enableFactChecking)
        XCTAssertEqual(coordinator.settings.noiseReductionLevel, 0.8, accuracy: 0.01)
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Mock App Coordinator for UI Tests

class MockAppCoordinator: ObservableObject {
    @Published var isRecording = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var batteryLevel: Float = 0.75
    @Published var currentConversation: [ConversationMessage] = []
    @Published var recentAnalysis: [AnalysisResult] = []
    @Published var speakers: [Speaker] = [Speaker(name: "You", isCurrentUser: true)]
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var settings = AppSettings.default
    
    func startConversation() {
        isRecording = true
        isProcessing = true
        
        // Simulate adding a message after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.addMockMessage()
        }
    }
    
    func stopConversation() {
        isRecording = false
        isProcessing = false
    }
    
    func connectToGlasses() {
        connectionState = .connecting
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.connectionState = .connected
        }
    }
    
    func disconnectFromGlasses() {
        connectionState = .disconnected
    }
    
    func addSpeaker(name: String, isCurrentUser: Bool = false) {
        let speaker = Speaker(name: name, isCurrentUser: isCurrentUser)
        speakers.append(speaker)
    }
    
    func clearConversation() {
        currentConversation.removeAll()
        recentAnalysis.removeAll()
    }
    
    func exportConversation() -> ConversationExport {
        let summary = ConversationSummary(
            messageCount: currentConversation.count,
            speakerCount: speakers.count,
            duration: 300,
            averageConfidence: 0.85,
            startTime: Date().timeIntervalSince1970 - 300,
            endTime: Date().timeIntervalSince1970
        )
        
        return ConversationExport(
            messages: currentConversation,
            speakers: speakers,
            summary: summary,
            exportDate: Date()
        )
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
    }
    
    private func addMockMessage() {
        let message = ConversationMessage(
            content: "This is a mock conversation message for testing purposes.",
            speakerId: speakers.first?.id,
            confidence: 0.9,
            timestamp: Date().timeIntervalSince1970,
            isFinal: true,
            wordTimings: [],
            originalText: "This is a mock conversation message for testing purposes."
        )
        
        currentConversation.append(message)
        isProcessing = false
    }
    
    // Computed properties for compatibility
    var isConnectedToGlasses: Bool {
        connectionState.isConnected
    }
    
    var conversationDuration: TimeInterval {
        guard let first = currentConversation.first,
              let last = currentConversation.last else {
            return 0
        }
        return last.timestamp - first.timestamp
    }
    
    var messageCount: Int {
        currentConversation.count
    }
    
    var speakerCount: Int {
        Set(currentConversation.compactMap { $0.speakerId }).count
    }
}