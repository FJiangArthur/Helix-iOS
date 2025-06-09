import XCTest
import CoreBluetooth
import Combine
@testable import Helix

class GlassesManagerTests: XCTestCase {
    var glassesManager: MockGlassesManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        glassesManager = MockGlassesManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        glassesManager = nil
        cancellables = nil
        try super.tearDownWithError()
    }
    
    func testGlassesManagerInitialization() {
        XCTAssertNotNil(glassesManager)
        
        let expectation = XCTestExpectation(description: "Initial state should be disconnected")
        
        glassesManager.connectionState
            .sink { state in
                XCTAssertEqual(state, .disconnected)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGlassesConnection() {
        let expectation = XCTestExpectation(description: "Connection should succeed")
        
        // Monitor connection state changes
        var stateChanges: [ConnectionState] = []
        
        glassesManager.connectionState
            .sink { state in
                stateChanges.append(state)
                if case .connected = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        glassesManager.connect()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Connection failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    // Connection succeeded
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify state progression
        XCTAssertTrue(stateChanges.contains(.scanning))
        XCTAssertTrue(stateChanges.contains(.connecting))
        XCTAssertTrue(stateChanges.contains(.connected))
    }
    
    func testDisplayText() {
        let expectation = XCTestExpectation(description: "Display text should succeed")
        
        // First connect
        glassesManager.simulateConnection()
        
        let testText = "Test message for glasses"
        let position = HUDPosition.topCenter
        
        glassesManager.displayText(testText, at: position)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Display failed: \(error)")
                    } else {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    // Display succeeded
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDisplayContent() {
        let expectation = XCTestExpectation(description: "Display content should succeed")
        
        glassesManager.simulateConnection()
        
        let content = HUDContent(
            text: "Test HUD content",
            style: HUDStyle.factCheck,
            position: .topCenter,
            duration: 5.0,
            priority: .high
        )
        
        glassesManager.displayContent(content)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Display content failed: \(error)")
                    } else {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    // Display succeeded
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testBatteryMonitoring() {
        let expectation = XCTestExpectation(description: "Battery level should be received")
        
        glassesManager.simulateConnection()
        
        glassesManager.batteryLevel
            .sink { level in
                XCTAssertGreaterThanOrEqual(level, 0.0)
                XCTAssertLessThanOrEqual(level, 1.0)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        glassesManager.startBatteryMonitoring()
        glassesManager.simulateBatteryLevel(0.75)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDisplayCapabilities() {
        let expectation = XCTestExpectation(description: "Display capabilities should be received")
        
        glassesManager.displayCapabilities
            .sink { capabilities in
                XCTAssertGreaterThan(capabilities.maxTextLength, 0)
                XCTAssertGreaterThan(capabilities.maxConcurrentDisplays, 0)
                XCTAssertFalse(capabilities.supportedPositions.isEmpty)
                XCTAssertFalse(capabilities.supportedColors.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testClearDisplay() {
        glassesManager.simulateConnection()
        
        // This should not throw or crash
        XCTAssertNoThrow(glassesManager.clearDisplay())
    }
    
    func testGestureCommands() {
        glassesManager.simulateConnection()
        
        let gestures: [GestureCommand] = [.tap, .swipeLeft, .swipeRight, .dismiss]
        
        for gesture in gestures {
            XCTAssertNoThrow(glassesManager.sendGestureCommand(gesture))
        }
    }
    
    func testDisplaySettings() {
        glassesManager.simulateConnection()
        
        let settings = DisplaySettings(
            brightness: 0.8,
            contrast: 0.9,
            autoAdjustBrightness: true,
            defaultPosition: .topCenter,
            maxDisplayTime: 10.0,
            enableAnimations: true
        )
        
        XCTAssertNoThrow(glassesManager.updateDisplaySettings(settings))
    }
    
    func testDisconnection() {
        let expectation = XCTestExpectation(description: "Disconnection should complete")
        
        glassesManager.simulateConnection()
        
        glassesManager.connectionState
            .sink { state in
                if case .disconnected = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        glassesManager.disconnect()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testConnectionFailure() {
        let expectation = XCTestExpectation(description: "Connection failure should be handled")
        
        glassesManager.shouldFailConnection = true
        
        glassesManager.connect()
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Connection should have failed")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 3.0)
    }
}

// MARK: - Mock Glasses Manager

class MockGlassesManager: GlassesManagerProtocol {
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let batteryLevelSubject = CurrentValueSubject<Float, Never>(0.0)
    private let displayCapabilitiesSubject = CurrentValueSubject<DisplayCapabilities, Never>(.default)
    
    var shouldFailConnection = false
    var connectionDelay: TimeInterval = 1.0
    
    var connectionState: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    var batteryLevel: AnyPublisher<Float, Never> {
        batteryLevelSubject.eraseToAnyPublisher()
    }
    
    var displayCapabilities: AnyPublisher<DisplayCapabilities, Never> {
        displayCapabilitiesSubject.eraseToAnyPublisher()
    }
    
    func connect() -> AnyPublisher<Void, GlassesError> {
        return Future<Void, GlassesError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.serviceUnavailable))
                return
            }
            
            if self.shouldFailConnection {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.connectionStateSubject.send(.error(.deviceNotFound))
                    promise(.failure(.deviceNotFound))
                }
                return
            }
            
            // Simulate connection process
            self.connectionStateSubject.send(.scanning)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.connectionStateSubject.send(.connecting)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + self.connectionDelay) {
                self.connectionStateSubject.send(.connected)
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func disconnect() {
        connectionStateSubject.send(.disconnected)
    }
    
    func displayText(_ text: String, at position: HUDPosition) -> AnyPublisher<Void, GlassesError> {
        let content = HUDContent(text: text, position: position)
        return displayContent(content)
    }
    
    func displayContent(_ content: HUDContent) -> AnyPublisher<Void, GlassesError> {
        return Future<Void, GlassesError> { promise in
            // Simulate display processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.connectionStateSubject.value.isConnected {
                    promise(.success(()))
                } else {
                    promise(.failure(.connectionFailed))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func clearDisplay() {
        // Simulate clearing display
        print("Mock: Clearing display")
    }
    
    func updateDisplaySettings(_ settings: DisplaySettings) {
        // Simulate updating settings
        print("Mock: Updating display settings")
    }
    
    func sendGestureCommand(_ command: GestureCommand) {
        // Simulate sending gesture command
        print("Mock: Sending gesture command: \(command)")
    }
    
    func startBatteryMonitoring() {
        // Simulate starting battery monitoring
        print("Mock: Starting battery monitoring")
    }
    
    func stopBatteryMonitoring() {
        // Simulate stopping battery monitoring
        print("Mock: Stopping battery monitoring")
    }
    
    // MARK: - Test Helper Methods
    
    func simulateConnection() {
        connectionStateSubject.send(.connected)
    }
    
    func simulateBatteryLevel(_ level: Float) {
        batteryLevelSubject.send(level)
    }
    
    func simulateError(_ error: GlassesError) {
        connectionStateSubject.send(.error(error))
    }
}