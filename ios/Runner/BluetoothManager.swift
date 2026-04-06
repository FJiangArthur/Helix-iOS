import CoreBluetooth
import Flutter
import Security

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

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static var _shared: BluetoothManager?
    static var shared: BluetoothManager { _shared! }

    private static let restorationIdentifier = "com.evencompanion.bluetooth.central"

    static func configure(channel: FlutterMethodChannel) -> BluetoothManager {
        let instance = BluetoothManager(channel: channel)
        _shared = instance
        return instance
    }

    var centralManager: CBCentralManager!
    var pairedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    var connectedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]

    var channel: FlutterMethodChannel!

    var blueInfoSink: FlutterEventSink?
    var blueSpeechSink: FlutterEventSink?

    var userInitiatedDisconnect = false
    private var reconnectAttemptsByPeripheral: [UUID: Int] = [:]
    private static let maxReconnectAttempts = 10
    private let connectionPersistence = BluetoothConnectionPersistence()

    private var deviceNameByPeripheralId: [UUID: String] = [:]
    private var sideByPeripheralId: [UUID: String] = [:]
    private lazy var pcmConverter = PcmConverter()
    private lazy var rnnoiseProcessor = RNNoiseProcessor()
    /// Whether noise reduction is applied to incoming glasses audio.
    var noiseReductionEnabled = false

    /// Queued glassesConnected events that fired before Dart was ready.
    private var pendingConnectionEvents: [[String: String]] = []
    /// Whether the Dart method handler has signaled readiness.
    private var dartHandlerReady = false

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

    private init(channel: FlutterMethodChannel) {
        UARTServiceUUID = CBUUID(string: ServiceIdentifiers.uartServiceUUIDString)
        UARTTXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartTXCharacteristicUUIDString)
        UARTRXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartRXCharacteristicUUIDString)

        super.init()
        self.channel = channel
        self.centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: BluetoothManager.restorationIdentifier,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    func startScan(result: @escaping FlutterResult) {
        guard centralManager.state == .poweredOn else {
            result(FlutterError(code: "BluetoothOff", message: "Bluetooth is not powered on.", details: nil))
            return
        }

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        result("Scanning for devices...")
    }

    func stopScan(result: @escaping FlutterResult) {
        centralManager.stopScan()
        result("Scan stopped")
    }

    func connectToDevice(deviceName: String, result: @escaping FlutterResult) {
        centralManager.stopScan()

        guard let peripheralPair = pairedDevices[deviceName] else {
            result(FlutterError(code: "DeviceNotFound", message: "Device not found", details: nil))
            return
        }

        guard let leftPeripheral = peripheralPair.0, let rightPeripheral = peripheralPair.1 else {
            result(FlutterError(code: "PeripheralNotFound", message: "One or both peripherals are not found", details: nil))
            return
        }

        userInitiatedDisconnect = false
        registerPeripheral(leftPeripheral, deviceName: deviceName, side: "L")
        registerPeripheral(rightPeripheral, deviceName: deviceName, side: "R")
        channel.invokeMethod("glassesConnecting", arguments: ["deviceName": deviceName])

        centralManager.connect(leftPeripheral, options: connectionOptions())
        centralManager.connect(rightPeripheral, options: connectionOptions())

        result("Connecting to \(deviceName)...")
    }

    func disconnectFromGlasses(result: @escaping FlutterResult) {
        userInitiatedDisconnect = true
        clearStoredConnection()

        for (_, devices) in connectedDevices {
            if let leftPeripheral = devices.0 {
                centralManager.cancelPeripheralConnection(leftPeripheral)
            }
            if let rightPeripheral = devices.1 {
                centralManager.cancelPeripheralConnection(rightPeripheral)
            }
        }

        connectedDevices.removeAll()
        reconnectAttemptsByPeripheral.removeAll()
        resetActivePeripherals()
        channel.invokeMethod("glassesDisconnected", arguments: ["status": "disconnected"])
        result("Disconnected all devices.")
    }

    // MARK: - CBCentralManagerDelegate Methods
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else { return }
        let components = name.components(separatedBy: "_")
        guard components.count > 1, let channelNumber = components[safe: 1] else { return }

        let pairKey = "Pair_\(channelNumber)"
        if name.contains("_L_") {
            pairedDevices[pairKey, default: (nil, nil)].0 = peripheral
            registerPeripheral(peripheral, deviceName: pairKey, side: "L")
        } else if name.contains("_R_") {
            pairedDevices[pairKey, default: (nil, nil)].1 = peripheral
            registerPeripheral(peripheral, deviceName: pairKey, side: "R")
        }

        if let leftPeripheral = pairedDevices[pairKey]?.0, let rightPeripheral = pairedDevices[pairKey]?.1 {
            let deviceInfo: [String: String] = [
                "leftDeviceName": leftPeripheral.name ?? "",
                "rightDeviceName": rightPeripheral.name ?? "",
                "channelNumber": channelNumber
            ]
            channel.invokeMethod("foundPairedGlasses", arguments: deviceInfo)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        reconnectAttemptsByPeripheral[peripheral.identifier] = 0
        print("didConnectPeripheral id=\(peripheral.identifier.uuidString) name=\(peripheral.name ?? "")")
        handleConnectedPeripheral(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("\(Date()) didDisconnectPeripheral-----peripheral-----\(peripheral)--")

        if let error = error {
            print("Disconnect error: \(error.localizedDescription)")
        } else {
            print("Disconnected without error.")
        }

        markPeripheralDisconnected(peripheral)
        channel.invokeMethod("glassesDisconnected", arguments: [
            "deviceName": deviceNameByPeripheralId[peripheral.identifier] ?? "",
            "disconnectedSide": sideByPeripheralId[peripheral.identifier] ?? "",
            "status": "disconnected"
        ])

        if userInitiatedDisconnect {
            reconnectAttemptsByPeripheral[peripheral.identifier] = 0
            return
        }

        let currentAttempts = reconnectAttemptsByPeripheral[peripheral.identifier] ?? 0
        if currentAttempts >= BluetoothManager.maxReconnectAttempts {
            print("Max reconnect attempts reached for \(peripheral.identifier)")
            reconnectAttemptsByPeripheral[peripheral.identifier] = 0
            return
        }

        reconnectAttemptsByPeripheral[peripheral.identifier] = currentAttempts + 1
        channel.invokeMethod("glassesConnecting", arguments: [
            "deviceName": deviceNameByPeripheralId[peripheral.identifier] ?? ""
        ])
        central.connect(peripheral, options: connectionOptions())
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
            print("Bluetooth is powered on.")
            restorePersistedConnectionIfNeeded()
        case .poweredOff:
            print("Bluetooth is powered off.")
            channel.invokeMethod("glassesDisconnected", arguments: ["status": "poweredOff"])
        default:
            print("Bluetooth state is unknown or unsupported.")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("didDiscoverServices error: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }
        for service in services where service.uuid.isEqual(UARTServiceUUID) {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("didDiscoverCharacteristicsFor error: \(error.localizedDescription)")
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

        print(
            "didDiscoverCharacteristics side=\(side ?? "?") "
                + "leftPeripheral=\(leftPeripheral != nil) rightPeripheral=\(rightPeripheral != nil) "
                + "leftWChar=\(leftWChar != nil) rightWChar=\(rightWChar != nil) "
                + "leftRChar=\(leftRChar != nil) rightRChar=\(rightRChar != nil)"
        )

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
            print("glassesConnected both sides deviceName=\(deviceName)")
            args = [
                "leftDeviceName": leftP.name ?? "",
                "rightDeviceName": rightP.name ?? "",
                "status": "connected"
            ]
        } else {
            print("glassesConnected partial side=\(side) deviceName=\(deviceName)")
            args = [
                "leftDeviceName": currentPair?.0?.name ?? "",
                "rightDeviceName": currentPair?.1?.name ?? "",
                "connectedSide": side,
                "partial": "true",
                "status": "connected"
            ]
        }

        if dartHandlerReady {
            channel.invokeMethod("glassesConnected", arguments: args)
        } else {
            print("glassesConnected queued (Dart not ready yet)")
            pendingConnectionEvents.append(args)
        }
    }

    /// Called by Dart after its method handler is registered.
    /// Replays any connection events that fired before Dart was ready.
    func onDartReady() {
        dartHandlerReady = true
        for args in pendingConnectionEvents {
            print("glassesConnected replayed: \(args)")
            channel.invokeMethod("glassesConnected", arguments: args)
        }
        pendingConnectionEvents.removeAll()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("subscribe fail: \(error.localizedDescription)")
            return
        }
        print(characteristic.isNotifying ? "subscribe success" : "subscribe cancel")
    }

    func sendData(params: [String: Any]) {
        guard let flutterData = params["data"] as? FlutterStandardTypedData else { return }
        writeData(writeData: flutterData.data, lr: params["lr"] as? String)
    }

    func writeData(writeData: Data, cbPeripheral: CBPeripheral? = nil, lr: String? = nil) {
        // [G1DBG] Hex dump every outbound BLE write so we can trace the exact
        // bytes reaching the glasses in Xcode Console.  Filter with "[G1DBG]".
        let hex = writeData.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")
        let cmd = writeData.first.map { String(format: "0x%02x", $0) } ?? "??"
        NSLog("[G1DBG] TX lr=\(lr ?? "both") cmd=\(cmd) len=\(writeData.count) hex=\(hex)")

        print(
            "writeData lr=\(lr ?? "both") bytes=\(writeData.count) "
                + "leftPeripheral=\(leftPeripheral != nil) rightPeripheral=\(rightPeripheral != nil) "
                + "leftWChar=\(leftWChar != nil) rightWChar=\(rightWChar != nil)"
        )

        if lr == "L" {
            if let leftWChar = leftWChar {
                if let leftPeripheral = leftPeripheral {
                    leftPeripheral.writeValue(writeData, for: leftWChar, type: .withoutResponse)
                } else {
                    print("writeData leftPeripheral is nil, cannot write data to left side.")
                }
            } else {
                print("writeData leftWChar is nil, cannot write data to left peripheral.")
            }
            return
        }

        if lr == "R" {
            if let rightWChar = rightWChar {
                if let rightPeripheral = rightPeripheral {
                    rightPeripheral.writeValue(writeData, for: rightWChar, type: .withoutResponse)
                } else {
                    print("writeData rightPeripheral is nil, cannot write data to right side.")
                }
            } else {
                print("writeData rightWChar is nil, cannot write data to right peripheral.")
            }
            return
        }

        if let leftWChar = leftWChar {
            if let leftPeripheral = leftPeripheral {
                leftPeripheral.writeValue(writeData, for: leftWChar, type: .withoutResponse)
            } else {
                print("writeData leftPeripheral is nil, cannot write data to left side.")
            }
        } else {
            print("writeData leftWChar is nil, cannot write data to left peripheral.")
        }

        if let rightWChar = rightWChar {
            if let rightPeripheral = rightPeripheral {
                rightPeripheral.writeValue(writeData, for: rightWChar, type: .withoutResponse)
            } else {
                print("writeData rightPeripheral is nil, cannot write data to right side.")
            }
        } else {
            print("writeData rightWChar is nil, cannot write data to right peripheral.")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("\(Date()) didWriteValueFor----characteristic---\(characteristic)---- \(error!)")
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            print("\(Date()) didWriteValueFor----------- \(error!)")
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, !data.isEmpty else { return }
        getCommandValue(data: data, cbPeripheral: peripheral)
    }

    func getCommandValue(data: Data, cbPeripheral: CBPeripheral? = nil) {
        guard !data.isEmpty else {
            print("Warning: Received empty BLE payload")
            return
        }

        // [G1DBG] Hex dump every inbound RX packet (except mic audio which is
        // too noisy).  0xF4 packets are the glasses' own debug stream — dump
        // them as ASCII so the firmware's internal messages are visible.
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

        let rspCommand = AG_BLE_REQ(rawValue: data[0])
        switch rspCommand {
        case .BLE_REQ_TRANSFER_MIC_DATA:
            guard data.count > 2 else {
                print("Warning: Insufficient data for MIC_DATA, need at least 3 bytes")
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

            if let sink = blueInfoSink {
                DispatchQueue.main.async {
                    sink(dictionary)
                }
            } else {
                print("blueInfoSink not ready, dropping data")
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
        print(
            "connectPeripheral side=\(side) deviceName=\(deviceName) "
                + "leftConnected=\(pair.0 != nil) rightConnected=\(pair.1 != nil)"
        )
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

        channel.invokeMethod("glassesConnecting", arguments: ["deviceName": deviceName])

        for peripheral in peripherals {
            if peripheral.identifier == leftUUID {
                registerPeripheral(peripheral, deviceName: deviceName, side: "L")
            } else if peripheral.identifier == rightUUID {
                registerPeripheral(peripheral, deviceName: deviceName, side: "R")
            }

            if peripheral.state == .connected {
                handleConnectedPeripheral(peripheral)
            } else if peripheral.state != .connecting {
                centralManager.connect(peripheral, options: connectionOptions())
            }
        }
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
