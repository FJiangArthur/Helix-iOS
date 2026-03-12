import CoreBluetooth
import Flutter

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static var _shared: BluetoothManager?
    static var shared: BluetoothManager { _shared! }

    private static let restorationIdentifier = "com.evencompanion.bluetooth.central"
    private static let storedDeviceNameKey = "com.evencompanion.bluetooth.deviceName"
    private static let storedLeftUUIDKey = "com.evencompanion.bluetooth.leftUUID"
    private static let storedRightUUIDKey = "com.evencompanion.bluetooth.rightUUID"

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
    private let defaults = UserDefaults.standard

    private var deviceNameByPeripheralId: [UUID: String] = [:]
    private var sideByPeripheralId: [UUID: String] = [:]

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

        for characteristic in characteristics {
            if characteristic.uuid.isEqual(UARTRXCharacteristicUUID) {
                if peripheral.identifier.uuidString == leftUUIDStr {
                    leftRChar = characteristic
                } else if peripheral.identifier.uuidString == rightUUIDStr {
                    rightRChar = characteristic
                }
            } else if characteristic.uuid.isEqual(UARTTXCharacteristicUUID) {
                if peripheral.identifier.uuidString == leftUUIDStr {
                    leftWChar = characteristic
                } else if peripheral.identifier.uuidString == rightUUIDStr {
                    rightWChar = characteristic
                }
            }
        }

        if peripheral.identifier.uuidString == leftUUIDStr, leftRChar != nil, leftWChar != nil {
            leftPeripheral?.setNotifyValue(true, for: leftRChar!)
            writeData(writeData: Data([0x4d, 0x01]), lr: "L")
        } else if peripheral.identifier.uuidString == rightUUIDStr, rightRChar != nil, rightWChar != nil {
            rightPeripheral?.setNotifyValue(true, for: rightRChar!)
            writeData(writeData: Data([0x4d, 0x01]), lr: "R")
        }
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
        if lr == "L" {
            if let leftWChar = leftWChar {
                leftPeripheral?.writeValue(writeData, for: leftWChar, type: .withoutResponse)
            }
            return
        }

        if lr == "R" {
            if let rightWChar = rightWChar {
                rightPeripheral?.writeValue(writeData, for: rightWChar, type: .withoutResponse)
            }
            return
        }

        if let leftWChar = leftWChar {
            leftPeripheral?.writeValue(writeData, for: leftWChar, type: .withoutResponse)
        } else {
            print("writeData leftWChar is nil, cannot write data to left peripheral.")
        }

        if let rightWChar = rightWChar {
            rightPeripheral?.writeValue(writeData, for: rightWChar, type: .withoutResponse)
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
        let rspCommand = AG_BLE_REQ(rawValue: data[0])
        switch rspCommand {
        case .BLE_REQ_TRANSFER_MIC_DATA:
            guard data.count > 2 else {
                print("Warning: Insufficient data for MIC_DATA, need at least 3 bytes")
                break
            }
            let effectiveData = data.subdata(in: 2..<data.count)
            let pcmConverter = PcmConverter()
            let pcmData = pcmConverter.decode(effectiveData)
            SpeechStreamRecognizer.shared.appendPCMData(pcmData as Data)
        default:
            let isLeft = cbPeripheral?.identifier.uuidString == leftUUIDStr
            let legStr = isLeft ? "L" : "R"
            let dictionary: [String: Any] = [
                "type": "type",
                "lr": legStr,
                "data": data
            ]

            if let sink = blueInfoSink {
                sink(dictionary)
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
        guard let deviceName = storedDeviceName(),
              let leftUUID = storedPeripheralUUID(for: BluetoothManager.storedLeftUUIDKey),
              let rightUUID = storedPeripheralUUID(for: BluetoothManager.storedRightUUIDKey) else {
            return
        }

        if peripheral.identifier == leftUUID {
            registerPeripheral(peripheral, deviceName: deviceName, side: "L")
        } else if peripheral.identifier == rightUUID {
            registerPeripheral(peripheral, deviceName: deviceName, side: "R")
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

        if let leftPeripheral = connectedDevices[deviceName]?.0,
           let rightPeripheral = connectedDevices[deviceName]?.1 {
            persistConnectedDevice(deviceName: deviceName, left: leftPeripheral, right: rightPeripheral)
            channel.invokeMethod("glassesConnected", arguments: [
                "leftDeviceName": leftPeripheral.name ?? "",
                "rightDeviceName": rightPeripheral.name ?? "",
                "status": "connected"
            ])
        }
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
        defaults.set(deviceName, forKey: BluetoothManager.storedDeviceNameKey)
        defaults.set(left.identifier.uuidString, forKey: BluetoothManager.storedLeftUUIDKey)
        defaults.set(right.identifier.uuidString, forKey: BluetoothManager.storedRightUUIDKey)
    }

    private func clearStoredConnection() {
        defaults.removeObject(forKey: BluetoothManager.storedDeviceNameKey)
        defaults.removeObject(forKey: BluetoothManager.storedLeftUUIDKey)
        defaults.removeObject(forKey: BluetoothManager.storedRightUUIDKey)
    }

    private func storedDeviceName() -> String? {
        defaults.string(forKey: BluetoothManager.storedDeviceNameKey)
    }

    private func storedPeripheralUUID(for key: String) -> UUID? {
        guard let value = defaults.string(forKey: key) else { return nil }
        return UUID(uuidString: value)
    }

    private func restorePersistedConnectionIfNeeded() {
        guard let deviceName = storedDeviceName(),
              let leftUUID = storedPeripheralUUID(for: BluetoothManager.storedLeftUUIDKey),
              let rightUUID = storedPeripheralUUID(for: BluetoothManager.storedRightUUIDKey) else {
            return
        }

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
