import Foundation
import CoreBluetooth
import Combine

protocol GlassesManagerProtocol {
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var batteryLevel: AnyPublisher<Float, Never> { get }
    var displayCapabilities: AnyPublisher<DisplayCapabilities, Never> { get }
    
    func connect() -> AnyPublisher<Void, GlassesError>
    func disconnect()
    func displayText(_ text: String, at position: HUDPosition) -> AnyPublisher<Void, GlassesError>
    func displayContent(_ content: HUDContent) -> AnyPublisher<Void, GlassesError>
    func clearDisplay()
    func updateDisplaySettings(_ settings: DisplaySettings)
    func sendGestureCommand(_ command: GestureCommand)
    func startBatteryMonitoring()
    func stopBatteryMonitoring()
}

enum ConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting
    case connected
    case error(GlassesError)
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
    
    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.scanning, .scanning),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case let (.error(e1), .error(e2)):
            return e1.localizedDescription == e2.localizedDescription
        default:
            return false
        }
    }
}

struct DisplayCapabilities {
    let maxTextLength: Int
    let supportedPositions: [HUDPosition]
    let supportedColors: [HUDColor]
    let maxConcurrentDisplays: Int
    let refreshRate: Float
    let resolution: DisplayResolution
    
    static let `default` = DisplayCapabilities(
        maxTextLength: 280,
        supportedPositions: [
            HUDPosition(x: 0.5, y: 0.1, alignment: .center, fontSize: .medium),
            HUDPosition(x: 0.1, y: 0.5, alignment: .left, fontSize: .small),
            HUDPosition(x: 0.9, y: 0.5, alignment: .right, fontSize: .small)
        ],
        supportedColors: [.white, .green, .red, .blue, .yellow],
        maxConcurrentDisplays: 3,
        refreshRate: 60.0,
        resolution: DisplayResolution(width: 640, height: 400)
    )
}

struct DisplayResolution {
    let width: Int
    let height: Int
}

struct HUDPosition {
    let x: Float // 0.0 to 1.0 (left to right)
    let y: Float // 0.0 to 1.0 (top to bottom)
    let alignment: TextAlignment
    let fontSize: FontSize
    
    static let topCenter = HUDPosition(x: 0.5, y: 0.1, alignment: .center, fontSize: .medium)
    static let bottomCenter = HUDPosition(x: 0.5, y: 0.9, alignment: .center, fontSize: .small)
    static let topLeft = HUDPosition(x: 0.1, y: 0.1, alignment: .left, fontSize: .small)
    static let topRight = HUDPosition(x: 0.9, y: 0.1, alignment: .right, fontSize: .small)
}

enum TextAlignment: String, CaseIterable {
    case left = "left"
    case center = "center"
    case right = "right"
}

enum FontSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var pointSize: Float {
        switch self {
        case .small: return 12.0
        case .medium: return 16.0
        case .large: return 20.0
        }
    }
}

struct HUDContent {
    let id: String
    let text: String
    let style: HUDStyle
    let position: HUDPosition
    let duration: TimeInterval?
    let priority: DisplayPriority
    let animation: HUDAnimation?
    
    init(id: String = UUID().uuidString, text: String, style: HUDStyle = HUDStyle(), position: HUDPosition = .topCenter, duration: TimeInterval? = nil, priority: DisplayPriority = .medium, animation: HUDAnimation? = nil) {
        self.id = id
        self.text = text
        self.style = style
        self.position = position
        self.duration = duration
        self.priority = priority
        self.animation = animation
    }
}

struct HUDStyle {
    let color: HUDColor
    let backgroundColor: HUDColor?
    let fontSize: FontSize
    let isBold: Bool
    let isItalic: Bool
    let opacity: Float
    
    init(color: HUDColor = .white, backgroundColor: HUDColor? = nil, fontSize: FontSize = .medium, isBold: Bool = false, isItalic: Bool = false, opacity: Float = 1.0) {
        self.color = color
        self.backgroundColor = backgroundColor
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.opacity = opacity
    }
    
    static let factCheck = HUDStyle(color: .red, fontSize: .medium, isBold: true)
    static let summary = HUDStyle(color: .blue, fontSize: .small)
    static let actionItem = HUDStyle(color: .yellow, fontSize: .small, isBold: true)
    static let notification = HUDStyle(color: .green, fontSize: .small)
}

enum HUDColor: String, CaseIterable {
    case white = "white"
    case black = "black"
    case red = "red"
    case green = "green"
    case blue = "blue"
    case yellow = "yellow"
    case orange = "orange"
    case purple = "purple"
    
    var rgbValues: (r: Float, g: Float, b: Float) {
        switch self {
        case .white: return (1.0, 1.0, 1.0)
        case .black: return (0.0, 0.0, 0.0)
        case .red: return (1.0, 0.0, 0.0)
        case .green: return (0.0, 1.0, 0.0)
        case .blue: return (0.0, 0.0, 1.0)
        case .yellow: return (1.0, 1.0, 0.0)
        case .orange: return (1.0, 0.5, 0.0)
        case .purple: return (0.5, 0.0, 1.0)
        }
    }
}

enum DisplayPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var displayDuration: TimeInterval {
        switch self {
        case .low: return 3.0
        case .medium: return 5.0
        case .high: return 8.0
        case .critical: return 12.0
        }
    }
}

struct HUDAnimation {
    let type: AnimationType
    let duration: TimeInterval
    let easing: EasingFunction
    
    enum AnimationType {
        case fadeIn
        case fadeOut
        case slideIn(direction: SlideDirection)
        case slideOut(direction: SlideDirection)
        case scale(from: Float, to: Float)
        case none
    }
    
    enum SlideDirection {
        case left, right, up, down
    }
    
    enum EasingFunction {
        case linear
        case easeIn
        case easeOut
        case easeInOut
    }
    
    static let fadeIn = HUDAnimation(type: .fadeIn, duration: 0.3, easing: .easeOut)
    static let fadeOut = HUDAnimation(type: .fadeOut, duration: 0.3, easing: .easeIn)
    static let slideInFromTop = HUDAnimation(type: .slideIn(direction: .up), duration: 0.4, easing: .easeOut)
}

struct DisplaySettings {
    let brightness: Float // 0.0 to 1.0
    let contrast: Float // 0.0 to 1.0
    let autoAdjustBrightness: Bool
    let defaultPosition: HUDPosition
    let maxDisplayTime: TimeInterval
    let enableAnimations: Bool
    
    static let `default` = DisplaySettings(
        brightness: 0.8,
        contrast: 0.9,
        autoAdjustBrightness: true,
        defaultPosition: .topCenter,
        maxDisplayTime: 10.0,
        enableAnimations: true
    )
}

enum GestureCommand {
    case tap
    case doubleTap
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case longPress
    case dismiss
    case next
    case previous
    case confirm
    case cancel
}

enum GlassesError: Error {
    case bluetoothUnavailable
    case deviceNotFound
    case connectionFailed
    case authenticationFailed
    case communicationTimeout
    case displayError(String)
    case batteryLow
    case firmwareUpdateRequired
    case hardwareError
    case serviceUnavailable
    
    var localizedDescription: String {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available or disabled"
        case .deviceNotFound:
            return "Even Realities glasses not found"
        case .connectionFailed:
            return "Failed to connect to glasses"
        case .authenticationFailed:
            return "Authentication with glasses failed"
        case .communicationTimeout:
            return "Communication timeout with glasses"
        case .displayError(let message):
            return "Display error: \(message)"
        case .batteryLow:
            return "Glasses battery is low"
        case .firmwareUpdateRequired:
            return "Firmware update required"
        case .hardwareError:
            return "Hardware error detected"
        case .serviceUnavailable:
            return "Glasses service unavailable"
        }
    }
}

class GlassesManager: NSObject, GlassesManagerProtocol {
    private let centralManager: CBCentralManager
    private var peripheral: CBPeripheral?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]
    
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)
    private let batteryLevelSubject = CurrentValueSubject<Float, Never>(0.0)
    private let displayCapabilitiesSubject = CurrentValueSubject<DisplayCapabilities, Never>(.default)
    
    private var displayQueue: [HUDContent] = []
    private var currentDisplays: [String: HUDContent] = [:]
    private var displaySettings = DisplaySettings.default
    
    private let processingQueue = DispatchQueue(label: "glasses.processing", qos: .userInteractive)
    private var cancellables = Set<AnyCancellable>()
    
    // Even Realities specific UUIDs (example UUIDs - replace with actual ones)
    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    private let displayCharacteristicUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABD")
    private let batteryCharacteristicUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABE")
    private let gestureCharacteristicUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABF")
    
    var connectionState: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }
    
    var batteryLevel: AnyPublisher<Float, Never> {
        batteryLevelSubject.eraseToAnyPublisher()
    }
    
    var displayCapabilities: AnyPublisher<DisplayCapabilities, Never> {
        displayCapabilitiesSubject.eraseToAnyPublisher()
    }
    
    override init() {
        centralManager = CBCentralManager()
        super.init()
        centralManager.delegate = self
        
        setupDisplayTimer()
    }
    
    func connect() -> AnyPublisher<Void, GlassesError> {
        return Future<Void, GlassesError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.serviceUnavailable))
                return
            }
            
            self.processingQueue.async {
                guard self.centralManager.state == .poweredOn else {
                    promise(.failure(.bluetoothUnavailable))
                    return
                }
                
                self.connectionStateSubject.send(.scanning)
                
                // Start scanning for Even Realities glasses
                self.centralManager.scanForPeripherals(
                    withServices: [self.serviceUUID],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
                )
                
                // Set timeout for scanning
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    if self.connectionStateSubject.value == .scanning {
                        self.centralManager.stopScan()
                        promise(.failure(.deviceNotFound))
                    }
                }
                
                // Store promise for completion when connected
                self.connectionPromise = promise
            }
        }
        .eraseToAnyPublisher()
    }
    
    func disconnect() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let peripheral = self.peripheral {
                self.centralManager.cancelPeripheralConnection(peripheral)
            }
            
            self.peripheral = nil
            self.characteristics.removeAll()
            self.connectionStateSubject.send(.disconnected)
            
            print("Disconnected from glasses")
        }
    }
    
    func displayText(_ text: String, at position: HUDPosition) -> AnyPublisher<Void, GlassesError> {
        let content = HUDContent(text: text, position: position)
        return displayContent(content)
    }
    
    func displayContent(_ content: HUDContent) -> AnyPublisher<Void, GlassesError> {
        return Future<Void, GlassesError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.serviceUnavailable))
                return
            }
            
            self.processingQueue.async {
                guard self.connectionStateSubject.value.isConnected else {
                    promise(.failure(.connectionFailed))
                    return
                }
                
                // Add to display queue
                self.displayQueue.append(content)
                self.processDisplayQueue()
                
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func clearDisplay() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.displayQueue.removeAll()
            self.currentDisplays.removeAll()
            
            let clearCommand = GlassesCommand.clearDisplay
            self.sendCommand(clearCommand)
        }
    }
    
    func updateDisplaySettings(_ settings: DisplaySettings) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.displaySettings = settings
            
            let settingsCommand = GlassesCommand.updateSettings(settings)
            self.sendCommand(settingsCommand)
        }
    }
    
    func sendGestureCommand(_ command: GestureCommand) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let gestureCommand = GlassesCommand.gesture(command)
            self.sendCommand(gestureCommand)
        }
    }
    
    func startBatteryMonitoring() {
        guard let characteristic = characteristics[batteryCharacteristicUUID],
              let peripheral = peripheral else { return }
        
        peripheral.setNotifyValue(true, for: characteristic)
        print("Started battery monitoring")
    }
    
    func stopBatteryMonitoring() {
        guard let characteristic = characteristics[batteryCharacteristicUUID],
              let peripheral = peripheral else { return }
        
        peripheral.setNotifyValue(false, for: characteristic)
        print("Stopped battery monitoring")
    }
    
    // Private properties for connection handling
    private var connectionPromise: ((Result<Void, GlassesError>) -> Void)?
    
    private func setupDisplayTimer() {
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateDisplays()
            }
            .store(in: &cancellables)
    }
    
    private func processDisplayQueue() {
        guard !displayQueue.isEmpty else { return }
        
        // Sort by priority
        displayQueue.sort { $0.priority.rawValue > $1.priority.rawValue }
        
        let maxConcurrent = displayCapabilitiesSubject.value.maxConcurrentDisplays
        
        while currentDisplays.count < maxConcurrent && !displayQueue.isEmpty {
            let content = displayQueue.removeFirst()
            currentDisplays[content.id] = content
            
            let displayCommand = GlassesCommand.displayContent(content)
            sendCommand(displayCommand)
        }
    }
    
    private func updateDisplays() {
        let now = Date().timeIntervalSince1970
        var expiredDisplays: [String] = []
        
        for (id, content) in currentDisplays {
            if let duration = content.duration,
               now - content.timestamp > duration {
                expiredDisplays.append(id)
            }
        }
        
        for id in expiredDisplays {
            currentDisplays.removeValue(forKey: id)
            let clearCommand = GlassesCommand.clearContent(id)
            sendCommand(clearCommand)
        }
        
        // Process queue if we have capacity
        if currentDisplays.count < displayCapabilitiesSubject.value.maxConcurrentDisplays {
            processDisplayQueue()
        }
    }
    
    private func sendCommand(_ command: GlassesCommand) {
        guard let peripheral = peripheral,
              let characteristic = characteristics[displayCharacteristicUUID] else {
            print("Cannot send command: peripheral or characteristic not available")
            return
        }
        
        do {
            let data = try command.encode()
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        } catch {
            print("Failed to encode command: \(error)")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension GlassesManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth powered on")
        case .poweredOff:
            connectionStateSubject.send(.error(.bluetoothUnavailable))
        case .unsupported:
            connectionStateSubject.send(.error(.bluetoothUnavailable))
        case .unauthorized:
            connectionStateSubject.send(.error(.bluetoothUnavailable))
        case .resetting:
            connectionStateSubject.send(.disconnected)
        case .unknown:
            break
        @unknown default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        
        // Check if this is an Even Realities device
        if isEvenRealitiesDevice(peripheral, advertisementData: advertisementData) {
            self.peripheral = peripheral
            peripheral.delegate = self
            
            central.stopScan()
            connectionStateSubject.send(.connecting)
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        
        connectionStateSubject.send(.connected)
        connectionPromise?(.success(()))
        connectionPromise = nil
        
        // Discover services
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to peripheral: \(error?.localizedDescription ?? "Unknown error")")
        
        connectionStateSubject.send(.error(.connectionFailed))
        connectionPromise?(.failure(.connectionFailed))
        connectionPromise = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(error?.localizedDescription ?? "Intentional disconnect")")
        
        self.peripheral = nil
        characteristics.removeAll()
        connectionStateSubject.send(.disconnected)
    }
    
    private func isEvenRealitiesDevice(_ peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
        // Check device name
        if let name = peripheral.name?.lowercased(),
           name.contains("even") || name.contains("realities") {
            return true
        }
        
        // Check advertisement data for Even Realities specific identifiers
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           serviceUUIDs.contains(serviceUUID) {
            return true
        }
        
        return false
    }
}

// MARK: - CBPeripheralDelegate

extension GlassesManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([
                    displayCharacteristicUUID,
                    batteryCharacteristicUUID,
                    gestureCharacteristicUUID
                ], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            self.characteristics[characteristic.uuid] = characteristic
            
            // Enable notifications for battery and gesture characteristics
            if characteristic.uuid == batteryCharacteristicUUID ||
               characteristic.uuid == gestureCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        print("Discovered \(characteristics.count) characteristics")
        
        // Request initial battery level
        if let batteryCharacteristic = self.characteristics[batteryCharacteristicUUID] {
            peripheral.readValue(for: batteryCharacteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating characteristic value: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        switch characteristic.uuid {
        case batteryCharacteristicUUID:
            handleBatteryUpdate(data)
        case gestureCharacteristicUUID:
            handleGestureUpdate(data)
        default:
            break
        }
    }
    
    private func handleBatteryUpdate(_ data: Data) {
        guard let batteryLevel = data.first else { return }
        
        let level = Float(batteryLevel) / 100.0
        batteryLevelSubject.send(level)
        
        print("Battery level: \(Int(level * 100))%")
        
        if level < 0.15 {
            connectionStateSubject.send(.error(.batteryLow))
        }
    }
    
    private func handleGestureUpdate(_ data: Data) {
        // Parse gesture data and handle accordingly
        // This would be implemented based on Even Realities protocol
        print("Received gesture data: \(data)")
    }
}

// MARK: - Glasses Command Protocol

enum GlassesCommand {
    case displayContent(HUDContent)
    case clearContent(String)
    case clearDisplay
    case updateSettings(DisplaySettings)
    case gesture(GestureCommand)
    
    func encode() throws -> Data {
        // This would implement the actual Even Realities protocol
        // For now, return placeholder data
        let commandData: [String: Any]
        
        switch self {
        case .displayContent(let content):
            commandData = [
                "type": "display",
                "id": content.id,
                "text": content.text,
                "position": [
                    "x": content.position.x,
                    "y": content.position.y
                ],
                "style": [
                    "color": content.style.color.rawValue,
                    "fontSize": content.style.fontSize.rawValue
                ]
            ]
        case .clearContent(let id):
            commandData = [
                "type": "clear",
                "id": id
            ]
        case .clearDisplay:
            commandData = [
                "type": "clearAll"
            ]
        case .updateSettings(let settings):
            commandData = [
                "type": "settings",
                "brightness": settings.brightness,
                "contrast": settings.contrast
            ]
        case .gesture(let gesture):
            commandData = [
                "type": "gesture",
                "command": "\(gesture)"
            ]
        }
        
        return try JSONSerialization.data(withJSONObject: commandData)
    }
}

// MARK: - Extensions

extension HUDContent {
    var timestamp: TimeInterval {
        Date().timeIntervalSince1970
    }
}