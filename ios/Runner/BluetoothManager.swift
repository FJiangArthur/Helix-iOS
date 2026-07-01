import CoreBluetooth
import Security
import os.log

private let bleLog = OSLog(subsystem: "com.helix.ble", category: "errors")

struct StoredBluetoothConnection: Codable, Equatable {
    let deviceName: String
    let leftPeripheralID: UUID
    let rightPeripheralID: UUID

    func encoded() -> Data {
        // This payload is tiny and schema-stable, so encoding should be deterministic.
        try! JSONEncoder().encode(self)
    }
}

protocol BluetoothConnectionSecureStore {
    func read(for account: String) -> Data?
    @discardableResult
    func save(_ data: Data, for account: String) -> Bool
    func delete(for account: String)
}

final class BluetoothConnectionKeychainStore: BluetoothConnectionSecureStore {
    private let service = "com.evencompanion.bluetooth"

    func read(for account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    func save(_ data: Data, for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus != errSecItemNotFound {
            return false
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    func delete(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class BluetoothConnectionPersistence {
    static let storedDeviceNameKey = "com.evencompanion.bluetooth.deviceName"
    static let storedLeftUUIDKey = "com.evencompanion.bluetooth.leftUUID"
    static let storedRightUUIDKey = "com.evencompanion.bluetooth.rightUUID"
    static let secureStoreAccount = "persistedConnection"

    private let defaults: UserDefaults
    private let secureStore: BluetoothConnectionSecureStore

    init(
        defaults: UserDefaults = .standard,
        secureStore: BluetoothConnectionSecureStore = BluetoothConnectionKeychainStore()
    ) {
        self.defaults = defaults
        self.secureStore = secureStore
    }

    func save(_ connection: StoredBluetoothConnection) {
        persistToDefaults(connection)
        _ = secureStore.save(connection.encoded(), for: Self.secureStoreAccount)
    }

    func load() -> StoredBluetoothConnection? {
        if let connection = loadFromDefaults() {
            _ = secureStore.save(connection.encoded(), for: Self.secureStoreAccount)
            return connection
        }

        guard let data = secureStore.read(for: Self.secureStoreAccount),
              let connection = try? JSONDecoder().decode(StoredBluetoothConnection.self, from: data) else {
            return nil
        }

        persistToDefaults(connection)
        return connection
    }

    func clear() {
        defaults.removeObject(forKey: Self.storedDeviceNameKey)
        defaults.removeObject(forKey: Self.storedLeftUUIDKey)
        defaults.removeObject(forKey: Self.storedRightUUIDKey)
        secureStore.delete(for: Self.secureStoreAccount)
    }

    private func loadFromDefaults() -> StoredBluetoothConnection? {
        guard let deviceName = defaults.string(forKey: Self.storedDeviceNameKey),
              let leftUUIDString = defaults.string(forKey: Self.storedLeftUUIDKey),
              let rightUUIDString = defaults.string(forKey: Self.storedRightUUIDKey),
              let leftUUID = UUID(uuidString: leftUUIDString),
              let rightUUID = UUID(uuidString: rightUUIDString) else {
            return nil
        }

        return StoredBluetoothConnection(
            deviceName: deviceName,
            leftPeripheralID: leftUUID,
            rightPeripheralID: rightUUID
        )
    }

    private func persistToDefaults(_ connection: StoredBluetoothConnection) {
        defaults.set(connection.deviceName, forKey: Self.storedDeviceNameKey)
        defaults.set(connection.leftPeripheralID.uuidString, forKey: Self.storedLeftUUIDKey)
        defaults.set(connection.rightPeripheralID.uuidString, forKey: Self.storedRightUUIDKey)
    }
}

struct BluetoothManagerFailure: Error, LocalizedError, Equatable {
    let code: String
    let message: String

    var errorDescription: String? { message }
}

typealias BluetoothOperationCompletion = (Result<Any?, BluetoothManagerFailure>) -> Void
typealias BluetoothManagerEventHandler = (_ eventName: String, _ arguments: Any?) -> Void
typealias BluetoothInfoEventHandler = (_ payload: [String: Any]) -> Void

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothManager()

    private static let restorationIdentifier = "com.evencompanion.bluetooth.central"

    @discardableResult
    static func configure(
        eventHandler: BluetoothManagerEventHandler? = nil,
        infoEventHandler: BluetoothInfoEventHandler? = nil
    ) -> BluetoothManager {
        let instance = BluetoothManager.shared
        instance.onEvent = eventHandler
        instance.onInfoEvent = infoEventHandler
        if eventHandler != nil {
            instance.markEventHandlerReady()
        }
        return instance
    }

    var centralManager: CBCentralManager!
    var pairedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    var connectedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]

    var onEvent: BluetoothManagerEventHandler?
    var onInfoEvent: BluetoothInfoEventHandler?

    var userInitiatedDisconnect = false
    private var reconnectAttemptsByPeripheral: [UUID: Int] = [:]
    private var connectionTimeoutWorkItems: [UUID: DispatchWorkItem] = [:]
    private var reportedConnectionFailurePeripheralIds = Set<UUID>()
    private var pendingConnectionPeripherals: [UUID: CBPeripheral] = [:]
    private static let maxReconnectAttempts = 10
    private static let connectionTimeoutSeconds: TimeInterval = 30
    private let connectionPersistence = BluetoothConnectionPersistence()

    private var deviceNameByPeripheralId: [UUID: String] = [:]
    private var sideByPeripheralId: [UUID: String] = [:]
    private var discoveredNameByPeripheralId: [UUID: String] = [:]
    private var discoveredRSSIByPeripheralId: [UUID: Int] = [:]
    private var discoveredConnectableByPeripheralId: [UUID: Bool] = [:]
    private lazy var pcmConverter = PcmConverter()
    private lazy var rnnoiseProcessor = RNNoiseProcessor()
    /// Whether noise reduction is applied to incoming glasses audio.
    var noiseReductionEnabled = false

    /// Queued glassesConnected events that fired before a native event handler was ready.
    private var pendingConnectionEvents: [[String: String]] = []
    /// Whether the native event handler has signaled readiness.
    private var eventHandlerReady = false

    var leftPeripheral: CBPeripheral?
    var leftUUIDStr: String?
    var rightPeripheral: CBPeripheral?
    var rightUUIDStr: String?

    var UARTServiceUUID: CBUUID
    var UARTRXCharacteristicUUID: CBUUID
    var UARTTXCharacteristicUUID: CBUUID

    var leftWChar: CBCharacteristic?
    var rightWChar: CBCharacteristic?
    var leftRChar: CBCharacteristic?
    var rightRChar: CBCharacteristic?

    private override init() {
        UARTServiceUUID = CBUUID(string: ServiceIdentifiers.uartServiceUUIDString)
        UARTTXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartTXCharacteristicUUIDString)
        UARTRXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartRXCharacteristicUUIDString)

        super.init()
        self.centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: BluetoothManager.restorationIdentifier,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    private func emitEvent(_ eventName: String, arguments: Any? = nil) {
        DispatchQueue.main.async {
            self.onEvent?(eventName, arguments)
        }
    }

    func startScan(result: @escaping BluetoothOperationCompletion) {
        guard centralManager.state == .poweredOn else {
            result(.failure(BluetoothManagerFailure(code: "BluetoothOff", message: "Bluetooth is not powered on.")))
            return
        }

        pairedDevices.removeAll()
        discoveredNameByPeripheralId.removeAll()
        discoveredRSSIByPeripheralId.removeAll()
        discoveredConnectableByPeripheralId.removeAll()

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        result(.success("Scanning for devices..."))
    }

    func stopScan(result: @escaping BluetoothOperationCompletion) {
        if centralManager.state == .poweredOn {
            centralManager.stopScan()
        }
        result(.success("Scan stopped"))
    }

    func connectToDevice(deviceName: String, result: @escaping BluetoothOperationCompletion) {
        guard centralManager.state == .poweredOn else {
            result(.failure(BluetoothManagerFailure(code: "BluetoothOff", message: "Bluetooth is not powered on.")))
            return
        }

        centralManager.stopScan()

        guard let peripheralPair = pairedDevices[deviceName] else {
            result(.failure(BluetoothManagerFailure(code: "DeviceNotFound", message: "Device not found")))
            return
        }

        guard let leftPeripheral = peripheralPair.0, let rightPeripheral = peripheralPair.1 else {
            result(.failure(BluetoothManagerFailure(code: "PeripheralNotFound", message: "One or both peripherals are not found")))
            return
        }

        userInitiatedDisconnect = false
        registerPeripheral(leftPeripheral, deviceName: deviceName, side: "L")
        registerPeripheral(rightPeripheral, deviceName: deviceName, side: "R")
        emitEvent("glassesConnecting", arguments: ["deviceName": deviceName])

        connectPeripheralWithTimeout(leftPeripheral, deviceName: deviceName, side: "L")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self, weak rightPeripheral] in
            guard let self, let rightPeripheral else { return }
            guard !self.userInitiatedDisconnect else { return }
            guard self.deviceNameByPeripheralId[rightPeripheral.identifier] == deviceName else { return }
            guard rightPeripheral.state != .connected else { return }
            self.connectPeripheralWithTimeout(rightPeripheral, deviceName: deviceName, side: "R")
        }

        result(.success("Connecting to \(deviceName)..."))
    }

    func disconnectFromGlasses(result: @escaping BluetoothOperationCompletion) {
        userInitiatedDisconnect = true
        clearStoredConnection()

        for (_, devices) in connectedDevices {
            if centralManager.state == .poweredOn, let leftPeripheral = devices.0 {
                centralManager.cancelPeripheralConnection(leftPeripheral)
            }
            if centralManager.state == .poweredOn, let rightPeripheral = devices.1 {
                centralManager.cancelPeripheralConnection(rightPeripheral)
            }
        }

        connectedDevices.removeAll()
        reconnectAttemptsByPeripheral.removeAll()
        reportedConnectionFailurePeripheralIds.removeAll()
        pendingConnectionPeripherals.removeAll()
        cancelAllConnectionTimeouts()
        resetActivePeripherals()
        emitEvent("glassesDisconnected", arguments: ["status": "disconnected"])
        result(.success("Disconnected all devices."))
    }

    // MARK: - CBCentralManagerDelegate Methods
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard let name = advertisedName ?? peripheral.name else { return }
        guard let parsedName = parseG1PeripheralName(name) else { return }

        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? true
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []

        #if DEBUG
        let uuidList = serviceUUIDs.map(\.uuidString).joined(separator: ",")
        print(
            "didDiscoverG1 name=\(name) side=\(parsedName.side) "
                + "channel=\(parsedName.channelNumber) rssi=\(RSSI.intValue) "
                + "connectable=\(isConnectable) services=[\(uuidList)] "
                + "id=\(peripheral.identifier.uuidString)"
        )
        #endif

        guard isConnectable else { return }

        let channelNumber = parsedName.channelNumber
        let side = parsedName.side
        let pairKey = "Pair_\(channelNumber)"
        discoveredNameByPeripheralId[peripheral.identifier] = name
        discoveredRSSIByPeripheralId[peripheral.identifier] = RSSI.intValue
        discoveredConnectableByPeripheralId[peripheral.identifier] = isConnectable

        if side == "L" {
            pairedDevices[pairKey, default: (nil, nil)].0 = peripheral
            registerPeripheral(peripheral, deviceName: pairKey, side: "L")
        } else if side == "R" {
            pairedDevices[pairKey, default: (nil, nil)].1 = peripheral
            registerPeripheral(peripheral, deviceName: pairKey, side: "R")
        }

        if let leftPeripheral = pairedDevices[pairKey]?.0, let rightPeripheral = pairedDevices[pairKey]?.1 {
            let deviceInfo: [String: String] = [
                "leftDeviceName": discoveredNameByPeripheralId[leftPeripheral.identifier] ?? leftPeripheral.name ?? "",
                "rightDeviceName": discoveredNameByPeripheralId[rightPeripheral.identifier] ?? rightPeripheral.name ?? "",
                "channelNumber": channelNumber,
                "leftPeripheralId": leftPeripheral.identifier.uuidString,
                "rightPeripheralId": rightPeripheral.identifier.uuidString,
                "leftRssi": "\(discoveredRSSIByPeripheralId[leftPeripheral.identifier] ?? 0)",
                "rightRssi": "\(discoveredRSSIByPeripheralId[rightPeripheral.identifier] ?? 0)",
                "leftConnectable": "\(discoveredConnectableByPeripheralId[leftPeripheral.identifier] ?? true)",
                "rightConnectable": "\(discoveredConnectableByPeripheralId[rightPeripheral.identifier] ?? true)"
            ]
            emitEvent("foundPairedGlasses", arguments: deviceInfo)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        cancelConnectionTimeout(for: peripheral)
        pendingConnectionPeripherals.removeValue(forKey: peripheral.identifier)
        reconnectAttemptsByPeripheral[peripheral.identifier] = 0
        #if DEBUG
        print("didConnectPeripheral id=\(peripheral.identifier.uuidString) name=\(peripheral.name ?? "")")
        #endif
        handleConnectedPeripheral(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        cancelConnectionTimeout(for: peripheral)
        pendingConnectionPeripherals.removeValue(forKey: peripheral.identifier)
        reconnectAttemptsByPeripheral[peripheral.identifier] = 0

        let deviceName = deviceNameByPeripheralId[peripheral.identifier] ?? ""
        let side = sideByPeripheralId[peripheral.identifier] ?? ""
        let errorMessage = error?.localizedDescription ?? "CoreBluetooth did not provide a failure reason."
        reportedConnectionFailurePeripheralIds.insert(peripheral.identifier)

        #if DEBUG
        print("didFailToConnectPeripheral side=\(side) deviceName=\(deviceName) error=\(errorMessage)")
        #endif
        os_log(
            "didFailToConnect side=%{public}s device=%{public}s error=%{public}s",
            log: bleLog,
            type: .error,
            side,
            deviceName,
            errorMessage
        )

        markPeripheralDisconnected(peripheral)
        emitEvent("glassesDisconnected", arguments: [
            "deviceName": deviceName,
            "disconnectedSide": side,
            "status": "connectFailed",
            "error": errorMessage
        ])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cancelConnectionTimeout(for: peripheral)
        pendingConnectionPeripherals.removeValue(forKey: peripheral.identifier)
        #if DEBUG
        print("\(Date()) didDisconnectPeripheral-----peripheral-----\(peripheral)--")

        if let error = error {
            print("Disconnect error: \(error.localizedDescription)")
        } else {
            print("Disconnected without error.")
        }
        #endif

        if let error = error {
            os_log("didDisconnect: %{public}s", log: bleLog, type: .error, error.localizedDescription)
        }

        if reportedConnectionFailurePeripheralIds.remove(peripheral.identifier) != nil {
            markPeripheralDisconnected(peripheral)
            return
        }

        markPeripheralDisconnected(peripheral)
        emitEvent("glassesDisconnected", arguments: [
            "deviceName": deviceNameByPeripheralId[peripheral.identifier] ?? "",
            "disconnectedSide": sideByPeripheralId[peripheral.identifier] ?? "",
            "status": "disconnected",
            "error": error?.localizedDescription ?? NSNull()
        ] as [String: Any])

        // During explicit user-driven connection attempts, do not immediately
        // reconnect from a disconnect callback. It obscures the original
        // failure and can issue commands while CoreBluetooth is resetting.
        reconnectAttemptsByPeripheral[peripheral.identifier] = 0
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        for peripheral in restoredPeripherals {
            restoreRegistration(for: peripheral)
            handleConnectedPeripheral(peripheral)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            #if DEBUG
            print("Bluetooth is powered on.")
            #endif
            restorePersistedConnectionIfNeeded()
        case .poweredOff:
            #if DEBUG
            print("Bluetooth is powered off.")
            #endif
            cancelAllConnectionTimeouts()
            pendingConnectionPeripherals.removeAll()
            reconnectAttemptsByPeripheral.removeAll()
            emitEvent("glassesDisconnected", arguments: ["status": "poweredOff"])
        default:
            #if DEBUG
            print("Bluetooth state is unknown or unsupported.")
            #endif
            cancelAllConnectionTimeouts()
            pendingConnectionPeripherals.removeAll()
            reconnectAttemptsByPeripheral.removeAll()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            #if DEBUG
            print("didDiscoverServices error: \(error.localizedDescription)")
            #endif
            return
        }

        guard let services = peripheral.services else { return }
        for service in services where service.uuid.isEqual(UARTServiceUUID) {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            #if DEBUG
            print("didDiscoverCharacteristicsFor error: \(error.localizedDescription)")
            #endif
            return
        }

        guard let characteristics = service.characteristics else { return }
        guard service.uuid.isEqual(UARTServiceUUID) else { return }

        let side = sideByPeripheralId[peripheral.identifier]

        for characteristic in characteristics {
            if characteristic.uuid.isEqual(UARTRXCharacteristicUUID) {
                if side == "L" {
                    leftRChar = characteristic
                } else if side == "R" {
                    rightRChar = characteristic
                }
            } else if characteristic.uuid.isEqual(UARTTXCharacteristicUUID) {
                if side == "L" {
                    leftWChar = characteristic
                } else if side == "R" {
                    rightWChar = characteristic
                }
            }
        }

        #if DEBUG
        print(
            "didDiscoverCharacteristics side=\(side ?? "?") "
                + "leftPeripheral=\(leftPeripheral != nil) rightPeripheral=\(rightPeripheral != nil) "
                + "leftWChar=\(leftWChar != nil) rightWChar=\(rightWChar != nil) "
                + "leftRChar=\(leftRChar != nil) rightRChar=\(rightRChar != nil)"
        )
        #endif

        if side == "L",
           let leftRChar,
           leftWChar != nil {
            leftPeripheral?.setNotifyValue(true, for: leftRChar)
            writeData(writeData: Data([0x4d, 0x01]), lr: "L")
        } else if side == "R",
                  let rightRChar,
                  rightWChar != nil {
            rightPeripheral?.setNotifyValue(true, for: rightRChar)
            writeData(writeData: Data([0x4d, 0x01]), lr: "R")
        }

        // Notify Dart that this side is ready (characteristics discovered).
        notifyGlassesConnectedIfReady(side: side)
    }

    /// Sends glassesConnected to Dart once a side's write characteristic is ready.
    ///
    /// Called from didDiscoverCharacteristics so the Dart layer only marks a
    /// side as connected after it can actually receive BLE writes.
    private func notifyGlassesConnectedIfReady(side: String?) {
        guard let side = side,
              let deviceName = (side == "L"
                  ? deviceNameByPeripheralId[leftPeripheral?.identifier ?? UUID()]
                  : deviceNameByPeripheralId[rightPeripheral?.identifier ?? UUID()]) else {
            return
        }

        // Only notify once the write characteristic is available.
        let sideReady = (side == "L" && leftWChar != nil) ||
                        (side == "R" && rightWChar != nil)
        guard sideReady else { return }

        let currentPair = connectedDevices[deviceName]
        let bothCharacteristicsReady = leftWChar != nil && rightWChar != nil

        var args: [String: String]
        if bothCharacteristicsReady,
           let leftP = currentPair?.0, let rightP = currentPair?.1 {
            persistConnectedDevice(deviceName: deviceName, left: leftP, right: rightP)
            #if DEBUG
            print("glassesConnected both sides deviceName=\(deviceName)")
            #endif
            args = [
                "leftDeviceName": leftP.name ?? "",
                "rightDeviceName": rightP.name ?? "",
                "status": "connected"
            ]
        } else {
            #if DEBUG
            print("glassesConnected partial side=\(side) deviceName=\(deviceName)")
            #endif
            args = [
                "leftDeviceName": currentPair?.0?.name ?? "",
                "rightDeviceName": currentPair?.1?.name ?? "",
                "connectedSide": side,
                "partial": "true",
                "status": "connected"
            ]
        }

        if eventHandlerReady {
            emitEvent("glassesConnected", arguments: args)
        } else {
            #if DEBUG
            print("glassesConnected queued (native event handler not ready yet)")
            #endif
            pendingConnectionEvents.append(args)
        }
    }

    /// Called after the native event handler is registered.
    /// Replays any connection events that fired before the handler was ready.
    func markEventHandlerReady() {
        eventHandlerReady = true
        for args in pendingConnectionEvents {
            #if DEBUG
            print("glassesConnected replayed: \(args)")
            #endif
            emitEvent("glassesConnected", arguments: args)
        }
        pendingConnectionEvents.removeAll()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            #if DEBUG
            print("subscribe fail: \(error.localizedDescription)")
            #endif
            os_log("subscribe failed: %{public}s; uuid=%{public}s", log: bleLog, type: .error, error.localizedDescription, characteristic.uuid.uuidString)
            return
        }
        #if DEBUG
        print(characteristic.isNotifying ? "subscribe success" : "subscribe cancel")
        #endif
    }

    func sendData(params: [String: Any]) {
        let payload: Data?
        if let data = params["data"] as? Data {
            payload = data
        } else if let data = params["data"] as? NSData {
            payload = data as Data
        } else if let bytes = params["data"] as? [UInt8] {
            payload = Data(bytes)
        } else {
            payload = nil
        }

        guard let payload else { return }
        writeData(writeData: payload, lr: params["lr"] as? String)
    }

    func writeData(writeData: Data, cbPeripheral: CBPeripheral? = nil, lr: String? = nil) {
        // [G1DBG] Hex dump every outbound BLE write so we can trace the exact
        // bytes reaching the glasses in Xcode Console.  Filter with "[G1DBG]".
        // Gated behind #if DEBUG — this fires on every BLE write (10+ /sec
        // during streaming) and was a thermal/perf contributor in release.
        // See .planning/todos/pending/2026-04-08-tier2-reduce-debug-logging-
        // release-and-ble.md.
        #if DEBUG
        let hex = writeData.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")
        let cmd = writeData.first.map { String(format: "0x%02x", $0) } ?? "??"
        NSLog("[G1DBG] TX lr=\(lr ?? "both") cmd=\(cmd) len=\(writeData.count) hex=\(hex)")

        print(
            "writeData lr=\(lr ?? "both") bytes=\(writeData.count) "
                + "leftPeripheral=\(leftPeripheral != nil) rightPeripheral=\(rightPeripheral != nil) "
                + "leftWChar=\(leftWChar != nil) rightWChar=\(rightWChar != nil)"
        )
        #endif

        let cmdByte: UInt8 = writeData.first ?? 0

        if lr == "L" {
            if let leftWChar = leftWChar {
                if let leftPeripheral = leftPeripheral {
                    leftPeripheral.writeValue(writeData, for: leftWChar, type: .withoutResponse)
                } else {
                    #if DEBUG
                    print("writeData leftPeripheral is nil, cannot write data to left side.")
                    #endif
                    reportWriteFailed(reason: "leftPeripheral_nil", cmd: cmdByte)
                }
            } else {
                #if DEBUG
                print("writeData leftWChar is nil, cannot write data to left peripheral.")
                #endif
                reportWriteFailed(reason: "leftWChar_nil", cmd: cmdByte)
            }
            return
        }

        if lr == "R" {
            if let rightWChar = rightWChar {
                if let rightPeripheral = rightPeripheral {
                    rightPeripheral.writeValue(writeData, for: rightWChar, type: .withoutResponse)
                } else {
                    #if DEBUG
                    print("writeData rightPeripheral is nil, cannot write data to right side.")
                    #endif
                    reportWriteFailed(reason: "rightPeripheral_nil", cmd: cmdByte)
                }
            } else {
                #if DEBUG
                print("writeData rightWChar is nil, cannot write data to right peripheral.")
                #endif
                reportWriteFailed(reason: "rightWChar_nil", cmd: cmdByte)
            }
            return
        }

        if let leftWChar = leftWChar {
            if let leftPeripheral = leftPeripheral {
                leftPeripheral.writeValue(writeData, for: leftWChar, type: .withoutResponse)
            } else {
                #if DEBUG
                print("writeData leftPeripheral is nil, cannot write data to left side.")
                #endif
                reportWriteFailed(reason: "leftPeripheral_nil", cmd: cmdByte)
            }
        } else {
            #if DEBUG
            print("writeData leftWChar is nil, cannot write data to left peripheral.")
            #endif
            reportWriteFailed(reason: "leftWChar_nil", cmd: cmdByte)
        }

        if let rightWChar = rightWChar {
            if let rightPeripheral = rightPeripheral {
                rightPeripheral.writeValue(writeData, for: rightWChar, type: .withoutResponse)
            } else {
                #if DEBUG
                print("writeData rightPeripheral is nil, cannot write data to right side.")
                #endif
                reportWriteFailed(reason: "rightPeripheral_nil", cmd: cmdByte)
            }
        } else {
            #if DEBUG
            print("writeData rightWChar is nil, cannot write data to right peripheral.")
            #endif
            reportWriteFailed(reason: "rightWChar_nil", cmd: cmdByte)
        }
    }

    private func reportWriteFailed(reason: String, cmd: UInt8) {
        os_log("writeData: %{public}s nil; cmd=0x%{public}02x", log: bleLog, type: .error, reason, cmd)
        emitEvent("bleWriteFailed", arguments: [
            "reason": reason,
            "cmd": Int(cmd)
        ])
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            #if DEBUG
            print("\(Date()) didWriteValueFor----characteristic---\(characteristic)---- \(error!)")
            #endif
            os_log("didWriteValueFor error: %{public}s", log: bleLog, type: .error, error!.localizedDescription)
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            #if DEBUG
            print("\(Date()) didWriteValueFor----------- \(error!)")
            #endif
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, !data.isEmpty else { return }
        getCommandValue(data: data, cbPeripheral: peripheral)
    }

    func getCommandValue(data: Data, cbPeripheral: CBPeripheral? = nil) {
        guard !data.isEmpty else {
            #if DEBUG
            print("Warning: Received empty BLE payload")
            #endif
            return
        }

        // [G1DBG] Hex dump every inbound RX packet (except mic audio which is
        // too noisy).  0xF4 packets are the glasses' own debug stream — dump
        // them as ASCII so the firmware's internal messages are visible.
        // Gated behind #if DEBUG — fires on every inbound BLE notification
        // and was a thermal/perf contributor in release. See todo
        // 2026-04-08-tier2-reduce-debug-logging-release-and-ble.md.
        #if DEBUG
        if data[0] != 0xF1 {
            let side = sideByPeripheralId[cbPeripheral?.identifier ?? UUID()] ?? "?"
            let hex = data.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")
            let cmd = String(format: "0x%02x", data[0])
            NSLog("[G1DBG] RX side=\(side) cmd=\(cmd) len=\(data.count) hex=\(hex)")
            if data[0] == 0xF4, data.count > 1 {
                let body = data.subdata(in: 1..<data.count)
                let trimmed = body.prefix(while: { $0 != 0 })
                if let text = String(data: trimmed, encoding: .utf8), !text.isEmpty {
                    NSLog("[G1DBG] RX side=\(side) DEBUG: \(text)")
                }
            }
        }
        #endif

        let rspCommand = AG_BLE_REQ(rawValue: data[0])
        switch rspCommand {
        case .BLE_REQ_TRANSFER_MIC_DATA:
            guard data.count > 2 else {
                #if DEBUG
                print("Warning: Insufficient data for MIC_DATA, need at least 3 bytes")
                #endif
                break
            }
            let effectiveData = data.subdata(in: 2..<data.count)
            let decodedPcm = pcmConverter.decode(effectiveData) as Data
            // Apply noise reduction if enabled and RNNoise is available
            let pcmData: Data
            if noiseReductionEnabled, rnnoiseProcessor.isAvailable {
                pcmData = rnnoiseProcessor.processPCM16(decodedPcm) as Data
            } else {
                pcmData = decodedPcm
            }
            SpeechStreamRecognizer.shared.appendPCMData(pcmData)
        default:
            let legStr = sideByPeripheralId[cbPeripheral?.identifier ?? UUID()] ?? "L"
            let hexString = data.map { String(format: "%02x", $0) }.joined(separator: " ")
            let notifyIndex = data.count > 1 ? Int(data[1]) : -1
            let command = Int(data[0])
            let dictionary: [String: Any] = [
                "type": rspCommand == .BLE_REQ_DEVICE_ORDER ? "deviceOrder" : "type",
                "lr": legStr,
                "data": data,
                "command": command,
                "notifyIndex": notifyIndex,
                "payloadLength": data.count,
                "hexString": hexString
            ]

            if let onInfoEvent {
                DispatchQueue.main.async {
                    onInfoEvent(dictionary)
                }
            } else {
                #if DEBUG
                print("Bluetooth info event handler not ready, dropping data")
                #endif
            }
        }
    }

    private func connectionOptions() -> [String: NSNumber] {
        return [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ]
    }

    private func registerPeripheral(_ peripheral: CBPeripheral, deviceName: String, side: String) {
        deviceNameByPeripheralId[peripheral.identifier] = deviceName
        sideByPeripheralId[peripheral.identifier] = side

        var pair = pairedDevices[deviceName] ?? (nil, nil)
        if side == "L" {
            pair.0 = peripheral
        } else {
            pair.1 = peripheral
        }
        pairedDevices[deviceName] = pair
    }

    private func restoreRegistration(for peripheral: CBPeripheral) {
        guard let storedConnection = connectionPersistence.load() else {
            return
        }

        if peripheral.identifier == storedConnection.leftPeripheralID {
            registerPeripheral(peripheral, deviceName: storedConnection.deviceName, side: "L")
        } else if peripheral.identifier == storedConnection.rightPeripheralID {
            registerPeripheral(peripheral, deviceName: storedConnection.deviceName, side: "R")
        }
    }

    private func handleConnectedPeripheral(_ peripheral: CBPeripheral) {
        guard let deviceName = deviceNameByPeripheralId[peripheral.identifier],
              let side = sideByPeripheralId[peripheral.identifier] else {
            restoreRegistration(for: peripheral)
            guard let restoredDeviceName = deviceNameByPeripheralId[peripheral.identifier],
                  let restoredSide = sideByPeripheralId[peripheral.identifier] else {
                return
            }
            connectPeripheral(peripheral, deviceName: restoredDeviceName, side: restoredSide)
            return
        }

        connectPeripheral(peripheral, deviceName: deviceName, side: side)
    }

    private func connectPeripheral(_ peripheral: CBPeripheral, deviceName: String, side: String) {
        var pair = connectedDevices[deviceName] ?? (nil, nil)
        if side == "L" {
            pair.0 = peripheral
            leftPeripheral = peripheral
            leftUUIDStr = peripheral.identifier.uuidString
        } else {
            pair.1 = peripheral
            rightPeripheral = peripheral
            rightUUIDStr = peripheral.identifier.uuidString
        }
        connectedDevices[deviceName] = pair

        peripheral.delegate = self
        peripheral.discoverServices([UARTServiceUUID])
        #if DEBUG
        print(
            "connectPeripheral side=\(side) deviceName=\(deviceName) "
                + "leftConnected=\(pair.0 != nil) rightConnected=\(pair.1 != nil)"
        )
        #endif
        // glassesConnected is deferred to didDiscoverCharacteristics so the
        // Dart side only marks a side as ready once its write characteristic
        // has been discovered. Sending the event here would race with
        // characteristic discovery, causing writes to fail with nil wChar.
    }

    private func markPeripheralDisconnected(_ peripheral: CBPeripheral) {
        guard let deviceName = deviceNameByPeripheralId[peripheral.identifier],
              let side = sideByPeripheralId[peripheral.identifier] else {
            return
        }

        if var pair = connectedDevices[deviceName] {
            if side == "L" {
                pair.0 = nil
                leftPeripheral = nil
                leftUUIDStr = nil
                leftWChar = nil
                leftRChar = nil
            } else {
                pair.1 = nil
                rightPeripheral = nil
                rightUUIDStr = nil
                rightWChar = nil
                rightRChar = nil
            }

            if pair.0 == nil && pair.1 == nil {
                connectedDevices.removeValue(forKey: deviceName)
            } else {
                connectedDevices[deviceName] = pair
            }
        }
    }

    private func persistConnectedDevice(deviceName: String, left: CBPeripheral, right: CBPeripheral) {
        connectionPersistence.save(
            StoredBluetoothConnection(
                deviceName: deviceName,
                leftPeripheralID: left.identifier,
                rightPeripheralID: right.identifier
            )
        )
    }

    private func clearStoredConnection() {
        connectionPersistence.clear()
    }

    private func restorePersistedConnectionIfNeeded() {
        guard let storedConnection = connectionPersistence.load() else {
            return
        }

        let deviceName = storedConnection.deviceName
        let leftUUID = storedConnection.leftPeripheralID
        let rightUUID = storedConnection.rightPeripheralID

        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [leftUUID, rightUUID])
        guard !peripherals.isEmpty else { return }

        emitEvent("glassesConnecting", arguments: ["deviceName": deviceName])

        for peripheral in peripherals {
            if peripheral.identifier == leftUUID {
                registerPeripheral(peripheral, deviceName: deviceName, side: "L")
            } else if peripheral.identifier == rightUUID {
                registerPeripheral(peripheral, deviceName: deviceName, side: "R")
            }

            if peripheral.state == .connected {
                handleConnectedPeripheral(peripheral)
            } else {
                let side = peripheral.identifier == leftUUID ? "L" : "R"
                connectPeripheralWithTimeout(peripheral, deviceName: deviceName, side: side)
            }
        }
    }

    private func connectPeripheralWithTimeout(_ peripheral: CBPeripheral, deviceName: String, side: String) {
        #if DEBUG
        print(
            "connectStart side=\(side) deviceName=\(deviceName) "
                + "state=\(peripheralStateName(peripheral.state)) "
                + "id=\(peripheral.identifier.uuidString) name=\(peripheral.name ?? "")"
        )
        #endif
        reportedConnectionFailurePeripheralIds.remove(peripheral.identifier)
        pendingConnectionPeripherals[peripheral.identifier] = peripheral

        if peripheral.state == .connected {
            handleConnectedPeripheral(peripheral)
            return
        }

        guard centralManager.state == .poweredOn else {
            pendingConnectionPeripherals.removeValue(forKey: peripheral.identifier)
            emitEvent("glassesDisconnected", arguments: [
                "deviceName": deviceName,
                "disconnectedSide": side,
                "status": "connectFailed",
                "error": "Bluetooth changed to \(centralStateName(centralManager.state)) before connecting."
            ])
            return
        }

        scheduleConnectionTimeout(for: peripheral, deviceName: deviceName, side: side)
        if peripheral.state == .connecting {
            return
        }
        centralManager.connect(peripheral, options: connectionOptions())
    }

    private func scheduleConnectionTimeout(for peripheral: CBPeripheral, deviceName: String, side: String) {
        cancelConnectionTimeout(for: peripheral)

        let workItem = DispatchWorkItem { [weak self, weak peripheral] in
            guard let self, let peripheral else { return }

            if peripheral.state == .connected {
                #if DEBUG
                print("connectTimeoutRecovered side=\(side) deviceName=\(deviceName) peripheral=\(peripheral.identifier.uuidString)")
                #endif
                self.connectionTimeoutWorkItems.removeValue(forKey: peripheral.identifier)
                self.pendingConnectionPeripherals.removeValue(forKey: peripheral.identifier)
                self.handleConnectedPeripheral(peripheral)
                return
            }

            guard peripheral.state == .connecting else {
                self.connectionTimeoutWorkItems.removeValue(forKey: peripheral.identifier)
                self.pendingConnectionPeripherals.removeValue(forKey: peripheral.identifier)
                return
            }

            #if DEBUG
            print("connectTimeout side=\(side) deviceName=\(deviceName) peripheral=\(peripheral.identifier.uuidString)")
            #endif
            os_log(
                "connectTimeout side=%{public}s device=%{public}s peripheral=%{public}s",
                log: bleLog,
                type: .error,
                side,
                deviceName,
                peripheral.identifier.uuidString
            )

            self.reportedConnectionFailurePeripheralIds.insert(peripheral.identifier)
            if self.centralManager.state == .poweredOn {
                self.centralManager.cancelPeripheralConnection(peripheral)
            }
            self.markPeripheralDisconnected(peripheral)
            self.emitEvent("glassesDisconnected", arguments: [
                "deviceName": deviceName,
                "disconnectedSide": side,
                "status": "connectTimeout",
                "error": "Timed out while connecting to the \(side) side of the glasses."
            ])
            self.connectionTimeoutWorkItems.removeValue(forKey: peripheral.identifier)
            self.pendingConnectionPeripherals.removeValue(forKey: peripheral.identifier)
        }

        connectionTimeoutWorkItems[peripheral.identifier] = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + BluetoothManager.connectionTimeoutSeconds,
            execute: workItem
        )
    }

    private func cancelConnectionTimeout(for peripheral: CBPeripheral) {
        connectionTimeoutWorkItems.removeValue(forKey: peripheral.identifier)?.cancel()
    }

    private func cancelAllConnectionTimeouts() {
        for workItem in connectionTimeoutWorkItems.values {
            workItem.cancel()
        }
        connectionTimeoutWorkItems.removeAll()
    }

    private func peripheralStateName(_ state: CBPeripheralState) -> String {
        switch state {
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .disconnecting:
            return "disconnecting"
        @unknown default:
            return "unknown"
        }
    }

    private func centralStateName(_ state: CBManagerState) -> String {
        switch state {
        case .unknown:
            return "unknown"
        case .resetting:
            return "resetting"
        case .unsupported:
            return "unsupported"
        case .unauthorized:
            return "unauthorized"
        case .poweredOff:
            return "poweredOff"
        case .poweredOn:
            return "poweredOn"
        @unknown default:
            return "unknown"
        }
    }

    private func parseG1PeripheralName(_ name: String) -> (channelNumber: String, side: String)? {
        let components = name.split(separator: "_").map(String.init)
        guard let sideIndex = components.firstIndex(where: { $0 == "L" || $0 == "R" }) else {
            return nil
        }

        let side = components[sideIndex]
        let previousIndex = sideIndex > 0 ? sideIndex - 1 : nil
        let nextIndex = sideIndex + 1 < components.count ? sideIndex + 1 : nil

        if let previousIndex {
            let candidate = components[previousIndex]
            if isLikelyChannelNumber(candidate) {
                return (candidate, side)
            }
        }

        if let nextIndex {
            let candidate = components[nextIndex]
            if isLikelyChannelNumber(candidate) {
                return (candidate, side)
            }
        }

        if let previousIndex {
            return (components[previousIndex], side)
        }
        if let nextIndex {
            return (components[nextIndex], side)
        }
        return nil
    }

    private func isLikelyChannelNumber(_ value: String) -> Bool {
        return !value.isEmpty && value.allSatisfy { $0.isNumber }
    }

    private func resetActivePeripherals() {
        leftPeripheral = nil
        rightPeripheral = nil
        leftUUIDStr = nil
        rightUUIDStr = nil
        leftWChar = nil
        rightWChar = nil
        leftRChar = nil
        rightRChar = nil
    }
}

// Extension for safe array indexing
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
