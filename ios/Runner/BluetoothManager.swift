import CoreBluetooth
import Flutter

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothManager(channel: FlutterMethodChannel())
    
    var centralManager: CBCentralManager!
    var pairedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    var connectedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    var currentConnectingDeviceName: String? // Save the name of the currently connecting device
    
    var channel: FlutterMethodChannel!
    
    var blueInfoSink:FlutterEventSink!
    var blueSpeechSink:FlutterEventSink!
    
    var leftPeripheral:CBPeripheral?
    var leftUUIDStr:String?
    var rightPeripheral:CBPeripheral?
    var rightUUIDStr:String?
    
    var UARTServiceUUID:CBUUID
    var UARTRXCharacteristicUUID:CBUUID
    var UARTTXCharacteristicUUID:CBUUID
    
    var leftWChar:CBCharacteristic?
    var rightWChar:CBCharacteristic?
    var leftRChar:CBCharacteristic?
    var rightRChar:CBCharacteristic?
    
    var hasStartedSpeech = false

    init(channel: FlutterMethodChannel) {
        UARTServiceUUID          = CBUUID(string: ServiceIdentifiers.uartServiceUUIDString)
        UARTTXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartTXCharacteristicUUIDString)
        UARTRXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartRXCharacteristicUUIDString)
        
        super.init()
        self.channel = channel
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan(result: @escaping FlutterResult) {
        guard centralManager.state == .poweredOn else {
            result(FlutterError(code: "BluetoothOff", message: "Bluetooth is not powered on.", details: nil))
            return
        }

        centralManager.scanForPeripherals(withServices: nil, options: nil)
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

        currentConnectingDeviceName = deviceName // Save the current device being connected

        centralManager.connect(leftPeripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]) //   options nil
        centralManager.connect(rightPeripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]) //   options nil

        result("Connecting to \(deviceName)...")
    }

    func disconnectFromGlasses(result: @escaping FlutterResult) {
        for (_, devices) in connectedDevices {
            if let leftPeripheral = devices.0 {
                centralManager.cancelPeripheralConnection(leftPeripheral)
            }
            if let rightPeripheral = devices.1 {
                centralManager.cancelPeripheralConnection(rightPeripheral)
            }
        }
        connectedDevices.removeAll()
        result("Disconnected all devices.")
    }

    // MARK: - CBCentralManagerDelegate Methods
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else { return }
        let components = name.components(separatedBy: "_")
        guard components.count > 1, let channelNumber = components[safe: 1] else { return }

        if name.contains("_L_") {
            pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].0 = peripheral // Left device
        } else if name.contains("_R_") {
            pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].1 = peripheral // Right device
        }

        if let leftPeripheral = pairedDevices["Pair_\(channelNumber)"]?.0, let rightPeripheral = pairedDevices["Pair_\(channelNumber)"]?.1 {
            let deviceInfo: [String: String] = [
                "leftDeviceName": leftPeripheral.name ?? "",
                "rightDeviceName": rightPeripheral.name ?? "",
                "channelNumber": channelNumber
            ]
            channel.invokeMethod("foundPairedGlasses", arguments: deviceInfo)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let deviceName = currentConnectingDeviceName else { return }
        guard let peripheralPair = pairedDevices[deviceName] else { return }

        if connectedDevices[deviceName] == nil {
            connectedDevices[deviceName] = (nil, nil)
        }

        if peripheralPair.0 === peripheral {
            connectedDevices[deviceName]?.0 = peripheral // Left device connected

            self.leftPeripheral = peripheral
            self.leftPeripheral?.delegate = self
            self.leftPeripheral?.discoverServices([UARTServiceUUID])

            self.leftUUIDStr = peripheral.identifier.uuidString;

            HelixLogger.bluetooth("Left peripheral connected", level: .info, metadata: [
                "deviceName": deviceName,
                "uuid": self.leftUUIDStr ?? "unknown"
            ])
        } else if peripheralPair.1 === peripheral {
            connectedDevices[deviceName]?.1 = peripheral // Right device connected

            self.rightPeripheral = peripheral
            self.rightPeripheral?.delegate = self
            self.rightPeripheral?.discoverServices([UARTServiceUUID])

            self.rightUUIDStr = peripheral.identifier.uuidString

            HelixLogger.bluetooth("Right peripheral connected", level: .info, metadata: [
                "deviceName": deviceName,
                "uuid": self.rightUUIDStr ?? "unknown"
            ])
        }

        if let leftPeripheral = connectedDevices[deviceName]?.0, let rightPeripheral = connectedDevices[deviceName]?.1 {
            let connectedInfo: [String: String] = [
                "leftDeviceName": leftPeripheral.name ?? "",
                "rightDeviceName": rightPeripheral.name ?? "",
                "status": "connected"
            ]
            channel.invokeMethod("glassesConnected", arguments: connectedInfo)

            HelixLogger.bluetooth("Both peripherals connected successfully", level: .info, metadata: [
                "deviceName": deviceName
            ])

            currentConnectingDeviceName = nil
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?){
        if let error = error {
            HelixLogger.bluetooth("Peripheral disconnected with error", level: .error, metadata: [
                "peripheralName": peripheral.name ?? "unknown",
                "error": error.localizedDescription
            ])
        } else {
            HelixLogger.bluetooth("Peripheral disconnected", level: .info, metadata: [
                "peripheralName": peripheral.name ?? "unknown"
            ])
        }

        central.connect(peripheral, options: nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        HelixLogger.bluetooth("Discovering services for peripheral", level: .debug, metadata: [
            "peripheralName": peripheral.name ?? "unknown"
        ])

        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid .isEqual(UARTServiceUUID){
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        HelixLogger.bluetooth("Discovered characteristics for service", level: .debug, metadata: [
            "peripheralName": peripheral.name ?? "unknown",
            "serviceUUID": service.uuid.uuidString
        ])

        guard let characteristics = service.characteristics else { return }

        if service.uuid.isEqual(UARTServiceUUID){
            for characteristic in characteristics {
                if characteristic.uuid.isEqual(UARTRXCharacteristicUUID){
                    if(peripheral.identifier.uuidString == self.leftUUIDStr){
                        self.leftRChar = characteristic
                    }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                        self.rightRChar = characteristic
                    }
                } else if characteristic.uuid.isEqual(UARTTXCharacteristicUUID){
                    if(peripheral.identifier.uuidString == self.leftUUIDStr){
                        self.leftWChar = characteristic
                    }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                        self.rightWChar = characteristic
                    }
                }
            }
            
            if(peripheral.identifier.uuidString == self.leftUUIDStr){
                if(self.leftRChar != nil && self.leftWChar != nil){
                    self.leftPeripheral?.setNotifyValue(true, for: self.leftRChar!)
                  
                    self.writeData(writeData: Data([0x4d, 0x01]), lr: "L")
                }
            }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                if(self.rightRChar != nil && self.rightWChar != nil){
                    self.rightPeripheral?.setNotifyValue(true, for: self.rightRChar!)
                    self.writeData(writeData: Data([0x4d, 0x01]), lr: "R")
                }
            }
        }
    }
        
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            HelixLogger.error("Failed to subscribe to characteristic", error: error, category: .bluetooth)
            return
        }
        if characteristic.isNotifying {
            HelixLogger.bluetooth("Successfully subscribed to characteristic notifications", level: .info, metadata: [
                "characteristicUUID": characteristic.uuid.uuidString
            ])
        } else {
            HelixLogger.bluetooth("Unsubscribed from characteristic notifications", level: .info, metadata: [
                "characteristicUUID": characteristic.uuid.uuidString
            ])
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            HelixLogger.bluetooth("Bluetooth is powered on", level: .info)
        case .poweredOff:
            HelixLogger.bluetooth("Bluetooth is powered off", level: .warning)
        default:
            HelixLogger.bluetooth("Bluetooth state is unknown or unsupported", level: .warning, metadata: [
                "state": "\(central.state.rawValue)"
            ])
        }
    }
    
    
    func sendData(params:[String:Any]) {
        let flutterData = params["data"] as! FlutterStandardTypedData
        writeData(writeData: flutterData.data, lr: params["lr"] as? String)
    }
    
    func writeData(writeData: Data, cbPeripheral: CBPeripheral? = nil, lr: String? = nil) {
        if lr == "L" {
            if self.leftWChar != nil {
                self.leftPeripheral?.writeValue(writeData, for: self.leftWChar!, type: .withoutResponse)
            }
            return
        }
        if lr == "R" {
            if self.rightWChar != nil {
                self.rightPeripheral?.writeValue(writeData, for: self.rightWChar!, type: .withoutResponse)
            }
            return
        }
        
        if let leftWChar = self.leftWChar {
            self.leftPeripheral?.writeValue(writeData, for: leftWChar, type: .withoutResponse)
        } else {
            HelixLogger.bluetooth("Cannot write data - left characteristic is nil", level: .warning)
        }

        if let rightWChar = self.rightWChar {
            self.rightPeripheral?.writeValue(writeData, for: rightWChar, type: .withoutResponse)
        } else {
            HelixLogger.bluetooth("Cannot write data - right characteristic is nil", level: .warning)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            HelixLogger.error("Failed to write value for characteristic", error: error!, category: .bluetooth)
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            HelixLogger.error("Failed to write value for descriptor", error: error!, category: .bluetooth)
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //print("\(Date()) didUpdateValueFor------\(peripheral.identifier.uuidString)----\(peripheral.name)-----\(characteristic.value)--")
        let data = characteristic.value
        self.getCommandValue(data: data!,cbPeripheral: peripheral)
    }
    
    func getCommandValue(data:Data,cbPeripheral:CBPeripheral? = nil){
        let rspCommand = AG_BLE_REQ(rawValue: (data[0]))
        switch rspCommand{
            case .BLE_REQ_TRANSFER_MIC_DATA:
                 let hexString = data.map { String(format: "%02hhx", $0) }.joined()
                 guard data.count > 2 else {
                     HelixLogger.bluetooth("Insufficient data for MIC_DATA, need at least 3 bytes", level: .warning, metadata: [
                         "dataSize": "\(data.count)"
                     ])
                     break
                 }
                 let effectiveData = data.subdata(in: 2..<data.count)
                 let pcmConverter = PcmConverter()
                 var pcmData = pcmConverter.decode(effectiveData)

                 let inputData = pcmData as Data
                 SpeechStreamRecognizer.shared.appendPCMData(inputData)

                 HelixLogger.bluetooth("Processed MIC_DATA", level: .debug, metadata: [
                     "dataSize": "\(data.count)",
                     "pcmDataSize": "\(inputData.count)"
                 ])

                 break
            default:
                let isLeft = cbPeripheral?.identifier.uuidString == self.leftUUIDStr
                let legStr = isLeft ? "L" : "R"
                var dictionary = [String: Any]()
                dictionary["type"] = "type" // todo
                dictionary["lr"] = legStr
                dictionary["data"] = data

                if let sink = self.blueInfoSink {
                    sink(dictionary)
                } else {
                    HelixLogger.bluetooth("blueInfoSink not ready, dropping data", level: .warning, metadata: [
                        "side": legStr
                    ])
                }
                break
        }
    }
}

// Extension for safe array indexing
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
