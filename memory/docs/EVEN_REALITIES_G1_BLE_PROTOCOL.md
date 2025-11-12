# Even Realities G1 智能眼镜蓝牙协议完全指南

## 文档说明

本文档基于以下来源编写：
- **官方示例**: [EvenDemoApp](https://github.com/even-realities/EvenDemoApp)
- **Python实现**: [even_glasses](https://github.com/emingenc/even_glasses) (69 stars)
- **Android实现**: [g1-basis-android](https://github.com/rodrigofalvarez/g1-basis-android) (16 stars)
- **Flutter实现**: [g1_flutter_blue_plus](https://github.com/emingenc/g1_flutter_blue_plus) (14 stars)
- **本项目代码**: Helix-iOS 的 Swift 和 Dart 实现

最后更新：2025-10-28

---

## 第一部分：核心概念与架构

### 1.1 设备架构

Even Realities G1 智能眼镜采用双设备架构：

```
┌─────────────────────────────────────┐
│     Even Realities G1 Glasses       │
├─────────────────┬───────────────────┤
│   Left Arm      │    Right Arm      │
│   "_L_"设备     │    "_R_"设备      │
│   独立BLE连接   │    独立BLE连接    │
└─────────────────┴───────────────────┘
         ▲                 ▲
         │                 │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │  Companion App  │
         │  (iOS/Android)  │
         └─────────────────┘
```

**关键设计原则**：
- **双连接必要性**: 必须同时连接左右两个设备才能正常工作
- **命令顺序**: 总是先发送给左臂（Left），收到ACK后再发送给右臂（Right）
- **设备识别**: 通过蓝牙设备名称中的 "_L_" 和 "_R_" 标识符区分
- **独立通信**: 左右设备各自维护独立的BLE连接和GATT服务

### 1.2 设备命名规则

```
格式: <prefix>_L_<channel>  (左设备)
      <prefix>_R_<channel>  (右设备)

示例:
  Even_L_001  (左臂，频道001)
  Even_R_001  (右臂，频道001)

  G1_L_42     (左臂，频道42)
  G1_R_42     (右臂，频道42)
```

**配对逻辑** (来自 `BluetoothManager.swift:95-112`):
```swift
let components = name.components(separatedBy: "_")
guard components.count > 1, let channelNumber = components[safe: 1] else { return }

if name.contains("_L_") {
    pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].0 = peripheral
} else if name.contains("_R_") {
    pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].1 = peripheral
}

// 当左右设备都发现后，通知应用层
if let leftPeripheral = pairedDevices["Pair_\(channelNumber)"]?.0,
   let rightPeripheral = pairedDevices["Pair_\(channelNumber)"]?.1 {
    channel.invokeMethod("foundPairedGlasses", arguments: deviceInfo)
}
```

---

## 第二部分：GATT 服务规范

### 2.1 核心服务和特征值

来自 `ServiceIdentifiers.swift` 和 Python 实现：

```swift
// UART 服务 (Nordic UART Service)
Service UUID: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E

// TX 特征值 (App -> Glasses, 写)
TX Characteristic: 6E400002-B5A3-F393-E0A9-E50E24DCCA9E
  - 属性: Write Without Response
  - 用途: 向眼镜发送命令和数据

// RX 特征值 (Glasses -> App, 读/通知)
RX Characteristic: 6E400003-B5A3-F393-E0A9-E50E24DCCA9E
  - 属性: Read, Notify
  - 用途: 接收眼镜的响应和事件
```

### 2.2 连接建立流程

基于 `BluetoothManager.swift:168-213`：

```
1. 扫描设备
   ├─ scanForPeripherals(withServices: nil)
   └─ 监听 didDiscover 回调

2. 识别左右设备
   ├─ 解析设备名称中的 "_L_" 或 "_R_"
   ├─ 提取频道号 (channel number)
   └─ 配对存储: pairedDevices["Pair_<channel>"] = (left, right)

3. 连接设备
   ├─ connect(leftPeripheral)
   ├─ connect(rightPeripheral)
   └─ 设置选项: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true]

4. 发现服务
   ├─ discoverServices([UARTServiceUUID])
   └─ 等待 didDiscoverServices 回调

5. 发现特征值
   ├─ discoverCharacteristics(nil, for: service)
   ├─ 识别 TX (写) 和 RX (读) 特征值
   └─ 等待 didDiscoverCharacteristicsFor 回调

6. 启用通知
   ├─ setNotifyValue(true, for: rxCharacteristic)
   └─ 监听 didUpdateValue 回调

7. 发送初始化命令
   ├─ 向左设备写入: [0x4D, 0x01]
   ├─ 向右设备写入: [0x4D, 0x01]
   └─ 通知应用层连接成功
```

**关键代码片段** (`BluetoothManager.swift:200-212`):
```swift
if(peripheral.identifier.uuidString == self.leftUUIDStr){
    if(self.leftRChar != nil && self.leftWChar != nil){
        self.leftPeripheral?.setNotifyValue(true, for: self.leftRChar!)
        // 发送初始化命令
        self.writeData(writeData: Data([0x4d, 0x01]), lr: "L")
    }
}else if(peripheral.identifier.uuidString == self.rightUUIDStr){
    if(self.rightRChar != nil && self.rightWChar != nil){
        self.rightPeripheral?.setNotifyValue(true, for: self.rightRChar!)
        self.writeData(writeData: Data([0x4d, 0x01]), lr: "R")
    }
}
```

### 2.3 断线重连机制

```swift
// 自动重连 (BluetoothManager.swift:156-166)
func centralManager(_ central: CBCentralManager,
                    didDisconnectPeripheral peripheral: CBPeripheral,
                    error: Error?){
    if let error = error {
        print("Disconnect error: \(error.localizedDescription)")
    }

    // 立即尝试重连
    central.connect(peripheral, options: nil)
}
```

---

## 第三部分：命令协议详解

### 3.1 命令格式总览

G1 眼镜使用基于字节流的命令协议，所有命令通过 TX 特征值发送，响应通过 RX 特征值接收。

**基本命令结构**:
```
┌──────────┬──────────┬──────────┬─────────────┐
│  OpCode  │ Payload  │ Payload  │   ...       │
│ (1 byte) │ (0-N)    │          │             │
└──────────┴──────────┴──────────┴─────────────┘
```

**多包传输结构**:
```
┌──────────┬──────────┬──────────┬──────────┬─────────────┐
│  OpCode  │ MaxSeq   │ CurSeq   │ Params   │  Data       │
│ (1 byte) │ (1 byte) │ (1 byte) │ (N bytes)│  (M bytes)  │
└──────────┴──────────┴──────────┴──────────┴─────────────┘
```

### 3.2 完整命令列表

基于 `proto.dart`, `GattProtocal.swift` 和 EvenDemoApp：

#### 3.2.1 基础控制命令

| OpCode | 名称 | 数据结构 | 响应 | 说明 |
|--------|------|----------|------|------|
| `0x4D` | 初始化 | `[0x4D, 0x01]` | - | 连接后立即发送 |
| `0x18` | 退出功能 | `[0x18]` | `[0x18, 0xC9]` | 返回主界面 |
| `0xF4` | 切换屏幕 | `[0xF4, screenId]` | `[0xF4, 0xC9]` | 切换显示页面 |
| `0x34` | 获取序列号 | `[0x34]` | `[0x34, len, ...sn]` | 获取设备SN (16字节) |

**退出功能实现** (`proto.dart:140-161`):
```dart
static Future<bool> exit() async {
  var data = Uint8List.fromList([0x18]);

  var retL = await BleManager.request(data, lr: "L", timeoutMs: 1500);
  if (retL.isTimeout || retL.data[1] != 0xc9) {
    return false;
  }

  var retR = await BleManager.request(data, lr: "R", timeoutMs: 1500);
  if (retR.isTimeout || retR.data[1] != 0xc9) {
    return false;
  }

  return true;
}
```

#### 3.2.2 麦克风控制

| OpCode | 名称 | 数据结构 | 响应 | 说明 |
|--------|------|----------|------|------|
| `0x0E` | 麦克风开关 | `[0x0E, 0x01/0x00]` | `[0x0E, 0xC9/0xCA]` | 0x01=开启, 0x00=关闭 |
| `0xF1` | 麦克风音频流 | - | `[0xF1, seq, ...lc3Data]` | LC3编码音频数据 |

**麦克风开启实现** (`proto.dart:25-35`):
```dart
static Future<(int, bool)> micOn({String? lr}) async {
  var begin = Utils.getTimestampMs();
  var data = Uint8List.fromList([0x0E, 0x01]);
  var receive = await BleManager.request(data, lr: lr);

  var end = Utils.getTimestampMs();
  var startMic = (begin + ((end - begin) ~/ 2));

  // 返回麦克风启动时间戳和成功状态
  return (startMic, (!receive.isTimeout && receive.data[1] == 0xc9));
}
```

**音频流处理** (`BluetoothManager.swift:298-311`):
```swift
case .BLE_REQ_TRANSFER_MIC_DATA:  // 0xF1 = 241
    guard data.count > 2 else {
        print("Warning: Insufficient data for MIC_DATA")
        break
    }
    // 跳过前2个字节 (OpCode + Sequence)
    let effectiveData = data.subdata(in: 2..<data.count)

    // LC3解码为PCM
    let pcmConverter = PcmConverter()
    var pcmData = pcmConverter.decode(effectiveData)

    // 发送给语音识别
    SpeechStreamRecognizer.shared.appendPCMData(pcmData)
```

#### 3.2.3 Even AI 协议

**核心命令**: `0x4E` - AI结果传输

**完整数据包结构** (来自 `evenai_proto.dart:5-44`):

```
┌─────────┬─────────┬─────────┬─────────┬─────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│ OpCode  │ SyncSeq │ MaxSeq  │ CurSeq  │NewScreen│   Pos    │  CurPage │ MaxPage  │   Data   │   ...    │
│  0x4E   │ (1 byte)│ (1 byte)│ (1 byte)│ (1 byte)│ (2 bytes)│ (1 byte) │ (1 byte) │ (N bytes)│          │
└─────────┴─────────┴─────────┴─────────┴─────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```

**字段说明**:
- `OpCode`: 固定 0x4E
- `SyncSeq`: 同步序列号，每次发送递增
- `MaxSeq`: 总包数 (分包传输时)
- `CurSeq`: 当前包序号 (从0开始)
- `NewScreen`: 屏幕状态标志
  - `0x00`: 继续显示当前内容
  - `0x01`: 清空并显示新内容
- `Pos`: 文本显示起始位置 (Big Endian, 2字节)
- `CurPage`: 当前页码 (从1开始)
- `MaxPage`: 总页数
- `Data`: UTF-8编码的文本内容 (最多191字节/包)

**实现代码** (`evenai_proto.dart:5-44`):
```dart
static List<Uint8List> evenaiMultiPackListV2(
  int cmd, {
  int len = 191,  // 每包最大数据长度
  required Uint8List data,
  required int syncSeq,
  required int newScreen,
  required int pos,
  required int current_page_num,
  required int max_page_num,
}) {
  List<Uint8List> send = [];
  int maxSeq = data.length ~/ len;
  if (data.length % len > 0) {
    maxSeq++;
  }

  for (var seq = 0; seq < maxSeq; seq++) {
    var start = seq * len;
    var end = start + len;
    if (end > data.length) {
      end = data.length;
    }
    var itemData = data.sublist(start, end);

    ByteData byteData = ByteData(2);
    byteData.setInt16(0, pos, Endian.big);

    var pack = Utils.addPrefixToUint8List([
      cmd,              // 0x4E
      syncSeq,
      maxSeq,
      seq,
      newScreen,
      ...byteData.buffer.asUint8List(),  // Pos (Big Endian)
      current_page_num,
      max_page_num,
    ], itemData);

    send.add(pack);
  }
  return send;
}
```

**发送流程** (`proto.dart:38-91`):
```dart
static Future<bool> sendEvenAIData(
  String text, {
  required int newScreen,
  required int pos,
  required int current_page_num,
  required int max_page_num,
}) async {
  var data = utf8.encode(text);
  var syncSeq = _evenaiSeq & 0xff;

  List<Uint8List> dataList = EvenaiProto.evenaiMultiPackListV2(
    0x4E,
    data: data,
    syncSeq: syncSeq,
    newScreen: newScreen,
    pos: pos,
    current_page_num: current_page_num,
    max_page_num: max_page_num,
  );
  _evenaiSeq++;

  // 先发送给左设备
  bool isSuccess = await BleManager.requestList(
    dataList, lr: "L", timeoutMs: 2000
  );
  if (!isSuccess) return false;

  // 再发送给右设备
  isSuccess = await BleManager.requestList(
    dataList, lr: "R", timeoutMs: 2000
  );

  return isSuccess;
}
```

#### 3.2.4 心跳协议

**命令**: `0x25` - 心跳包

**数据结构** (`proto.dart:94-130`):
```
┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│  OpCode  │  Length  │  Length  │   Seq    │   Type   │   Seq    │
│   0x25   │  Low     │  High    │ (1 byte) │   0x04   │ (1 byte) │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```

**实现**:
```dart
static int _beatHeartSeq = 0;

static Future<bool> sendHeartBeat() async {
  var length = 6;
  var data = Uint8List.fromList([
    0x25,
    length & 0xff,              // Length低位
    (length >> 8) & 0xff,       // Length高位
    _beatHeartSeq % 0xff,       // 序列号
    0x04,                       // 类型
    _beatHeartSeq % 0xff,       // 序列号 (重复)
  ]);
  _beatHeartSeq++;

  // 发送给左设备
  var ret = await BleManager.request(data, lr: "L", timeoutMs: 1500);
  if (ret.isTimeout || ret.data[0] != 0x25 || ret.data[4] != 0x04) {
    return false;
  }

  // 发送给右设备
  var retR = await BleManager.request(data, lr: "R", timeoutMs: 1500);
  if (retR.isTimeout || retR.data[0] != 0x25 || retR.data[4] != 0x04) {
    return false;
  }

  return true;
}
```

**建议使用场景**:
- 长时间连接但无数据传输时
- 检测设备是否仍然在线
- 防止蓝牙连接超时断开

#### 3.2.5 通知协议

**命令**: `0x4B` - 通知消息

**数据包结构** (`proto.dart:236-262`):
```
┌──────────┬──────────┬──────────┬──────────┬──────────────┐
│  OpCode  │  MsgId   │  MaxSeq  │  CurSeq  │   JsonData   │
│   0x4B   │ (1 byte) │ (1 byte) │ (1 byte) │  (176 bytes) │
└──────────┴──────────┴──────────┴──────────┴──────────────┘
```

**JSON格式**:
```json
{
  "ncs_notification": {
    "title": "通知标题",
    "subtitle": "副标题",
    "message": "通知内容",
    "display_name": "应用名称",
    "app_identifier": "com.example.app"
  }
}
```

**实现** (`proto.dart:210-234`):
```dart
static Future<void> sendNotify(
  Map appData,
  int notifyId, {
  int retry = 6,
}) async {
  final notifyJson = jsonEncode({"ncs_notification": appData});
  final dataList = _getNotifyPackList(
    0x4B,
    notifyId,
    utf8.encode(notifyJson),
  );

  // 重试机制
  for (var i = 0; i < retry; i++) {
    final isSuccess = await BleManager.requestList(
      dataList,
      timeoutMs: 1000,
      lr: "L",
    );
    if (isSuccess) return;
  }
}

static List<Uint8List> _getNotifyPackList(
  int cmd,
  int msgId,
  Uint8List data,
) {
  List<Uint8List> send = [];
  int maxSeq = data.length ~/ 176;
  if (data.length % 176 > 0) {
    maxSeq++;
  }

  for (var seq = 0; seq < maxSeq; seq++) {
    var start = seq * 176;
    var end = start + 176;
    if (end > data.length) {
      end = data.length;
    }
    var itemData = data.sublist(start, end);
    var pack = Utils.addPrefixToUint8List([
      cmd,     // 0x4B
      msgId,
      maxSeq,
      seq,
    ], itemData);
    send.add(pack);
  }
  return send;
}
```

#### 3.2.6 图像传输协议

**命令**: `0x15` - BMP图像传输

**数据包结构**:
```
第一个包:
┌──────────┬──────────┬──────────┬──────────┬──────────────────┬──────────────┐
│  OpCode  │  MaxSeq  │  CurSeq  │ Address  │   Address (4B)   │   BMP Data   │
│   0x15   │ (1 byte) │  0x00    │ (4 bytes)│                  │  (N bytes)   │
└──────────┴──────────┴──────────┴──────────┴──────────────────┴──────────────┘

后续包:
┌──────────┬──────────┬──────────┬──────────────┐
│  OpCode  │  MaxSeq  │  CurSeq  │   BMP Data   │
│   0x15   │ (1 byte) │ (1 byte) │  (194 bytes) │
└──────────┴──────────┴──────────┴──────────────┘
```

**图像规格** (来自 EvenDemoApp):
- 分辨率: 576x136 像素
- 格式: 1-bit BMP (黑白)
- 显示宽度: 488 像素
- 每包大小: 194 字节

#### 3.2.7 触摸板事件

**命令**: `0xF5` - 设备通知指令 (眼镜 -> App)

**事件类型** (来自 EvenDemoApp 和 `GattProtocal.swift:14`):

```
[0xF5, EventType]

EventType:
  0x00 - 双击 (Double Tap) - 退出当前功能
  0x01 - 单击 (Single Tap) - 翻页
  0x04 - 三击开始 (Triple Tap Start) - 切换静音模式
  0x05 - 三击结束 (Triple Tap End)
  0x17 - 启动 Even AI
  0x24 - 停止 AI 录音
```

**处理逻辑** (`BluetoothManager.swift:291-328`):
```swift
func getCommandValue(data: Data, cbPeripheral: CBPeripheral?) {
    let rspCommand = AG_BLE_REQ(rawValue: data[0])

    switch rspCommand {
        case .BLE_REQ_TRANSFER_MIC_DATA:  // 0xF1
            // 处理音频流
            break

        case .BLE_REQ_DEVICE_ORDER:       // 0xF5
            // 处理触摸板事件
            let eventType = data[1]
            // 根据 eventType 触发相应操作
            break

        default:
            // 转发给 Dart 层
            let isLeft = cbPeripheral?.identifier.uuidString == self.leftUUIDStr
            let legStr = isLeft ? "L" : "R"
            var dictionary = [String: Any]()
            dictionary["type"] = "type"
            dictionary["lr"] = legStr
            dictionary["data"] = data

            if let sink = self.blueInfoSink {
                sink(dictionary)
            }
    }
}
```

### 3.3 响应码规范

所有需要响应的命令都遵循以下格式：

```
成功: [OpCode, 0xC9, ...]
失败: [OpCode, 0xCA, ...]
```

| 响应码 | 含义 | 说明 |
|--------|------|------|
| `0xC9` | 成功 | 命令执行成功 |
| `0xCA` | 失败 | 命令执行失败 |

**示例**:
```
命令: [0x0E, 0x01]  (开启麦克风)
成功: [0x0E, 0xC9]
失败: [0x0E, 0xCA]
```

---

## 第四部分：LC3 音频编解码

### 4.1 LC3 协议规范

Even Realities G1 使用 **LC3 (Low Complexity Communication Codec)** 进行音频传输。

**规格参数** (来自 `PcmConverter.m:14-18`):
```c
Frame Duration:    10ms (10000 us)
Sample Rate:       16000 Hz
Output Byte Count: 20 bytes per frame
PCM Format:        S16 (Signed 16-bit)
Channels:          Mono
```

### 4.2 解码流程

基于 `PcmConverter.m:40-91`：

```
1. 初始化解码器
   ├─ lc3_decoder_size(10000, 16000)  → 获取所需内存大小
   ├─ malloc(decodeSize)              → 分配内存
   └─ lc3_setup_decoder(10000, 16000, 0, decMem) → 创建解码器

2. 接收 LC3 数据
   ├─ BLE收到 [0xF1, seq, ...lc3Data]
   └─ 提取 lc3Data (跳过前2字节)

3. 分帧解码
   ├─ 每次读取 20 字节 LC3 数据
   ├─ lc3_decode(decoder, lc3Data, 20, LC3_PCM_FORMAT_S16, pcmBuffer, 1)
   └─ 输出 PCM 数据 (160 samples = 320 bytes)

4. 拼接 PCM 流
   ├─ 将每帧 PCM 数据追加到总缓冲区
   └─ 传递给语音识别引擎
```

**完整代码** (`PcmConverter.m:40-91`):
```objc
-(NSMutableData *)decode: (NSData *)lc3data {
    // 计算参数
    encodeSize = lc3_encoder_size(dtUs, srHz);      // 10000, 16000
    decodeSize = lc3_decoder_size(dtUs, srHz);
    sampleOfFrames = lc3_frame_samples(dtUs, srHz); // 160 samples
    bytesOfFrames = sampleOfFrames * 2;             // 320 bytes

    // 初始化解码器
    decMem = malloc(decodeSize);
    lc3_decoder_t lc3_decoder = lc3_setup_decoder(dtUs, srHz, 0, decMem);

    // 分配输出缓冲区
    outBuf = malloc(bytesOfFrames);

    int totalBytes = (int)lc3data.length;
    int bytesRead = 0;
    NSMutableData *pcmData = [[NSMutableData alloc] init];

    // 逐帧解码
    while (bytesRead < totalBytes) {
        int bytesToRead = MIN(outputByteCount, totalBytes - bytesRead);
        NSRange range = NSMakeRange(bytesRead, bytesToRead);
        NSData *subdata = [lc3data subdataWithRange:range];
        inBuf = (unsigned char *)subdata.bytes;

        // 解码单帧 (20 bytes LC3 -> 320 bytes PCM)
        lc3_decode(lc3_decoder, inBuf, outputByteCount,
                   LC3_PCM_FORMAT_S16, outBuf, 1);

        NSData *data = [NSData dataWithBytes:outBuf length:bytesOfFrames];
        [pcmData appendData:data];
        bytesRead += bytesToRead;
    }

    // 清理
    free(decMem);
    free(outBuf);

    return pcmData;
}
```

### 4.3 LC3 性能参数

| 参数 | 值 | 说明 |
|------|----|----|
| 帧时长 | 10ms | 每帧持续时间 |
| 采样率 | 16000 Hz | 16kHz采样 |
| 单帧样本数 | 160 samples | 16000 * 0.01 |
| LC3 帧大小 | 20 bytes | 压缩后大小 |
| PCM 帧大小 | 320 bytes | 160 samples * 2 bytes |
| 压缩比 | 16:1 | 320/20 |
| 比特率 | 16 kbps | 20 bytes / 10ms * 8 |

### 4.4 语音识别集成

解码后的 PCM 数据直接发送给 iOS 原生语音识别 (`SpeechStreamRecognizer.swift`):

```swift
// BluetoothManager.swift:309
SpeechStreamRecognizer.shared.appendPCMData(pcmData)
```

**流程**:
```
BLE [0xF1] → LC3解码 → PCM (16kHz S16) → SpeechRecognizer → 文字
```

---

## 第五部分：实战最佳实践

### 5.1 请求/响应模式

基于 `BleManager` 的实现，推荐使用以下模式：

**模式1: 单命令请求**
```dart
// 发送命令并等待响应
BleReceive response = await BleManager.request(
  Uint8List.fromList([0x0E, 0x01]),  // 开启麦克风
  lr: "L",                             // 发送给左设备
  timeoutMs: 1000,                     // 1秒超时
);

if (!response.isTimeout && response.data[1] == 0xC9) {
  print("麦克风开启成功");
} else {
  print("麦克风开启失败");
}
```

**模式2: 双设备同步发送**
```dart
// 先左后右发送
bool success = await BleManager.sendBoth(
  Uint8List.fromList([0xF4, screenId]),
  timeoutMs: 300,
  isSuccess: (res) => res[1] == 0xC9,
);
```

**模式3: 多包传输**
```dart
List<Uint8List> packets = buildMultiPackets(data);

// 发送给左设备
bool successL = await BleManager.requestList(
  packets,
  lr: "L",
  timeoutMs: 2000,
);

if (successL) {
  // 发送给右设备
  bool successR = await BleManager.requestList(
    packets,
    lr: "R",
    timeoutMs: 2000,
  );
}
```

### 5.2 超时处理

**推荐超时值**:
```dart
const TIMEOUT_QUICK   = 250;   // 快速命令 (切换屏幕)
const TIMEOUT_NORMAL  = 1000;  // 普通命令 (麦克风控制)
const TIMEOUT_LONG    = 2000;  // 长时间命令 (AI数据传输)
const TIMEOUT_HEARTBEAT = 1500; // 心跳检测
```

**超时重试策略**:
```dart
Future<bool> reliableSend(Uint8List data, {int maxRetries = 3}) async {
  for (int i = 0; i < maxRetries; i++) {
    var response = await BleManager.request(data, timeoutMs: 1000);
    if (!response.isTimeout && response.data[1] == 0xC9) {
      return true;
    }
    // 等待后重试
    await Future.delayed(Duration(milliseconds: 100));
  }
  return false;
}
```

### 5.3 错误处理

**常见错误场景**:

1. **连接断开**
```swift
// 自动重连机制 (BluetoothManager.swift:156-166)
func centralManager(_ central: CBCentralManager,
                    didDisconnectPeripheral peripheral: CBPeripheral,
                    error: Error?) {
    print("Device disconnected, attempting reconnect...")
    central.connect(peripheral, options: nil)
}
```

2. **数据不完整**
```swift
// 数据长度检查
guard data.count > 2 else {
    print("Warning: Insufficient data, need at least 3 bytes")
    return
}
```

3. **命令失败**
```dart
if (response.data[1] == 0xCA) {
  print("Command failed: ${response.data}");
  // 记录失败原因并重试
}
```

### 5.4 性能优化

**1. 批量发送优化**
```dart
// 不推荐: 逐条发送
for (var cmd in commands) {
  await send(cmd);  // 每次等待响应
}

// 推荐: 批量打包
List<Uint8List> packets = commands.map((cmd) => buildPacket(cmd)).toList();
await BleManager.requestList(packets, timeoutMs: 2000);
```

**2. 减少跨设备延迟**
```dart
// 利用 sendBoth 同时发送给左右设备
await BleManager.sendBoth(
  data,
  timeoutMs: 250,
  isSuccess: (res) => res[1] == 0xC9,
);
```

**3. 数据分包优化**

根据不同命令类型使用合适的分包大小:
```dart
const PACKET_SIZE_EVENAI = 191;      // Even AI 文本
const PACKET_SIZE_NOTIFY = 176;      // 通知
const PACKET_SIZE_IMAGE  = 194;      // 图像
const PACKET_SIZE_GENERIC = 17;      // 通用数据 (20 - 3)
```

### 5.5 连接稳定性

**心跳保活机制**:
```dart
Timer? _heartbeatTimer;

void startHeartbeat() {
  _heartbeatTimer = Timer.periodic(Duration(seconds: 5), (_) async {
    bool success = await Proto.sendHeartBeat();
    if (!success) {
      print("Heartbeat failed, connection may be lost");
      // 触发重连逻辑
    }
  });
}

void stopHeartbeat() {
  _heartbeatTimer?.cancel();
}
```

**连接质量监控**:
```dart
class ConnectionMonitor {
  int _failedCommands = 0;

  void recordFailure() {
    _failedCommands++;
    if (_failedCommands > 3) {
      print("Connection unstable, consider reconnecting");
      // 触发重连
    }
  }

  void recordSuccess() {
    _failedCommands = 0;  // 重置失败计数
  }
}
```

---

## 第六部分：常见陷阱与注意事项

### 6.1 绝对不能做的事情

**1. 破坏左右发送顺序**
```dart
// ❌ 错误: 同时发送或顺序颠倒
await Future.wait([
  BleManager.request(data, lr: "L"),
  BleManager.request(data, lr: "R"),  // 不要并发!
]);

// ✅ 正确: 先左后右
await BleManager.request(data, lr: "L");
await BleManager.request(data, lr: "R");
```

**2. 忘记检查响应码**
```dart
// ❌ 错误: 假设命令总是成功
await BleManager.request(data, lr: "L");
// 继续执行...

// ✅ 正确: 检查响应
var response = await BleManager.request(data, lr: "L");
if (response.isTimeout || response.data[1] != 0xC9) {
  print("Command failed!");
  return;
}
```

**3. 硬编码设备名称**
```dart
// ❌ 错误: 假设设备名称固定
if (deviceName == "Even_L_001") { ... }

// ✅ 正确: 使用模式匹配
if (deviceName.contains("_L_")) { ... }
```

### 6.2 性能陷阱

**1. 过度频繁的心跳**
```dart
// ❌ 错误: 每秒发送心跳 (浪费带宽)
Timer.periodic(Duration(seconds: 1), (_) async {
  await Proto.sendHeartBeat();
});

// ✅ 正确: 5-10秒间隔
Timer.periodic(Duration(seconds: 5), (_) async {
  await Proto.sendHeartBeat();
});
```

**2. 阻塞式等待**
```dart
// ❌ 错误: 同步阻塞
for (var i = 0; i < 10; i++) {
  var data = await receive();  // 等待每个响应
  process(data);
}

// ✅ 正确: 异步流式处理
bleManager.eventBleReceive.listen((event) {
  process(event.data);
});
```

**3. 内存泄漏**
```swift
// ❌ 错误: 未释放 LC3 解码器内存
lc3_decoder_t decoder = lc3_setup_decoder(...);
// 使用后忘记 free(decMem)

// ✅ 正确: 及时释放
lc3_decoder_t decoder = lc3_setup_decoder(...);
// ... 使用解码器 ...
free(decMem);
free(outBuf);
```

### 6.3 数据格式陷阱

**1. 字节序错误**
```dart
// ❌ 错误: 使用 Little Endian
var pos = 100;
var bytes = [pos & 0xFF, (pos >> 8) & 0xFF];

// ✅ 正确: Even AI 协议使用 Big Endian
ByteData byteData = ByteData(2);
byteData.setInt16(0, pos, Endian.big);
var bytes = byteData.buffer.asUint8List();
```

**2. UTF-8 编码问题**
```dart
// ❌ 错误: 假设每个字符1字节
var text = "你好";
var length = text.length;  // 2

// ✅ 正确: 使用 UTF-8 编码后的字节长度
var data = utf8.encode(text);
var length = data.length;  // 6
```

**3. 分包边界错误**
```dart
// ❌ 错误: 不检查剩余数据
var end = start + PACKET_SIZE;  // 可能超出范围!

// ✅ 正确: 检查边界
var end = start + PACKET_SIZE;
if (end > data.length) {
  end = data.length;
}
```

### 6.4 调试技巧

**1. 十六进制日志**
```dart
void logHex(String tag, Uint8List data) {
  var hexString = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  print('$tag: [$hexString]');
}

// 使用
logHex("Sending", Uint8List.fromList([0x0E, 0x01]));
// 输出: Sending: [0e 01]
```

**2. 协议分析器**
```dart
class ProtocolAnalyzer {
  static String analyze(Uint8List data) {
    if (data.isEmpty) return "Empty data";

    var opcode = data[0];
    switch (opcode) {
      case 0x0E:
        return "MicControl: ${data[1] == 1 ? 'ON' : 'OFF'}";
      case 0x4E:
        return "EvenAI: seq=${data[1]}, maxSeq=${data[2]}, curSeq=${data[3]}";
      case 0x25:
        return "Heartbeat: seq=${data[3]}";
      case 0xF5:
        return "TouchEvent: type=${data[1]}";
      default:
        return "Unknown opcode: 0x${opcode.toRadixString(16)}";
    }
  }
}

// 使用
print(ProtocolAnalyzer.analyze(data));
```

**3. 时间戳追踪**
```dart
class TimestampLogger {
  static final _timestamps = <String, int>{};

  static void mark(String tag) {
    _timestamps[tag] = DateTime.now().millisecondsSinceEpoch;
  }

  static void measure(String startTag, String endTag) {
    var start = _timestamps[startTag];
    var end = _timestamps[endTag];
    if (start != null && end != null) {
      print('$startTag -> $endTag: ${end - start}ms');
    }
  }
}

// 使用
TimestampLogger.mark("send_start");
await BleManager.request(data);
TimestampLogger.mark("send_end");
TimestampLogger.measure("send_start", "send_end");
```

---

## 第七部分：真实代码示例

### 7.1 完整的麦克风录音流程

```dart
// 完整示例: 启动麦克风 -> 接收音频 -> 语音识别 -> 显示结果
class VoiceRecorder {
  StreamSubscription? _audioSubscription;

  Future<bool> startRecording() async {
    // 1. 开启麦克风
    var (timestamp, success) = await Proto.micOn(lr: "L");
    if (!success) {
      print("Failed to enable microphone");
      return false;
    }

    print("Microphone enabled at $timestamp");

    // 2. 监听音频流 (在 Swift 层已经自动处理)
    // BluetoothManager.swift 会自动接收 0xF1 音频包并解码

    // 3. 监听语音识别结果
    const EventChannel("eventSpeechRecognize")
      .receiveBroadcastStream()
      .listen((event) {
        String text = event["script"];
        print("Recognized: $text");

        // 4. 显示到眼镜上
        EvenAI.get().updateDynamicText(text);
      });

    return true;
  }

  Future<void> stopRecording() async {
    // 关闭麦克风
    var data = Uint8List.fromList([0x0E, 0x00]);
    await BleManager.request(data, lr: "L");

    _audioSubscription?.cancel();
  }
}
```

### 7.2 文本显示与翻页

```dart
class TextDisplay {
  static const MAX_CHARS_PER_LINE = 40;
  static const MAX_LINES = 5;
  static const CHARS_PER_PAGE = MAX_CHARS_PER_LINE * MAX_LINES;  // 200

  int _currentPage = 1;
  List<String> _pages = [];

  Future<void> displayText(String fullText) async {
    // 1. 分页
    _pages = _splitIntoPages(fullText);
    _currentPage = 1;

    // 2. 显示第一页
    await _showPage(_currentPage);
  }

  Future<void> nextPage() async {
    if (_currentPage < _pages.length) {
      _currentPage++;
      await _showPage(_currentPage);
    }
  }

  Future<void> previousPage() async {
    if (_currentPage > 1) {
      _currentPage--;
      await _showPage(_currentPage);
    }
  }

  Future<void> _showPage(int pageNum) async {
    String pageText = _pages[pageNum - 1];

    bool success = await Proto.sendEvenAIData(
      pageText,
      newScreen: 1,  // 清空屏幕
      pos: 0,        // 从头开始
      current_page_num: pageNum,
      max_page_num: _pages.length,
    );

    if (!success) {
      print("Failed to display page $pageNum");
    }
  }

  List<String> _splitIntoPages(String text) {
    List<String> pages = [];
    int offset = 0;

    while (offset < text.length) {
      int end = offset + CHARS_PER_PAGE;
      if (end > text.length) {
        end = text.length;
      }

      // 尝试在单词边界断开
      if (end < text.length && text[end] != ' ') {
        int lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > offset) {
          end = lastSpace;
        }
      }

      pages.add(text.substring(offset, end));
      offset = end;
    }

    return pages;
  }
}
```

### 7.3 触摸板事件处理

```dart
class TouchpadHandler {
  final TextDisplay _textDisplay;

  TouchpadHandler(this._textDisplay) {
    _setupEventListener();
  }

  void _setupEventListener() {
    // 监听来自眼镜的触摸事件
    BleManager.eventBleReceive.listen((event) {
      var data = event.data;
      if (data.isEmpty) return;

      if (data[0] == 0xF5) {  // 触摸板事件
        _handleTouchEvent(data[1]);
      }
    });
  }

  void _handleTouchEvent(int eventType) {
    switch (eventType) {
      case 0x00:  // 双击 - 退出
        print("Double tap detected, exiting...");
        Proto.exit();
        break;

      case 0x01:  // 单击 - 翻页
        print("Single tap detected, next page");
        _textDisplay.nextPage();
        break;

      case 0x17:  // 启动 Even AI
        print("Even AI triggered");
        EvenAI.get().toStartEvenAIByOS();
        break;

      case 0x24:  // 停止录音
        print("Stop recording");
        EvenAI.get().recordOverByOS();
        break;

      default:
        print("Unknown touch event: 0x${eventType.toRadixString(16)}");
    }
  }
}
```

### 7.4 连接管理器

```dart
class GlassesConnectionManager {
  static final instance = GlassesConnectionManager._();
  GlassesConnectionManager._();

  String? _connectedDeviceName;
  Timer? _heartbeatTimer;

  Future<bool> connect(String deviceName) async {
    try {
      // 1. 停止扫描
      await BleManager.stopScan();

      // 2. 连接设备
      await BleManager.connectToGlasses(deviceName);

      // 3. 等待连接成功回调
      var completer = Completer<bool>();

      void onConnected(dynamic info) {
        if (info['status'] == 'connected') {
          _connectedDeviceName = deviceName;
          completer.complete(true);
        }
      }

      // 注册回调并设置超时
      // (实际实现需要使用 MethodChannel 监听)

      bool connected = await completer.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (connected) {
        // 4. 启动心跳
        _startHeartbeat();
        return true;
      }

      return false;
    } catch (e) {
      print("Connection error: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    await BleManager.disconnectFromGlasses();
    _connectedDeviceName = null;
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(seconds: 5), (_) async {
      bool success = await Proto.sendHeartBeat();
      if (!success) {
        print("Heartbeat failed, connection lost");
        // 触发重连
        if (_connectedDeviceName != null) {
          await connect(_connectedDeviceName!);
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
```

---

## 附录：快速参考

### A. 命令速查表

| OpCode | 名称 | 方向 | 用途 |
|--------|------|------|------|
| `0x4D` | 初始化 | App → Glasses | 连接后握手 |
| `0x18` | 退出 | App → Glasses | 返回主界面 |
| `0xF4` | 切换屏幕 | App → Glasses | 切换显示页面 |
| `0x34` | 获取SN | App → Glasses | 读取设备序列号 |
| `0x0E` | 麦克风控制 | App → Glasses | 开关麦克风 |
| `0xF1` | 音频流 | Glasses → App | LC3音频数据 |
| `0x4E` | Even AI | App → Glasses | AI文本显示 |
| `0x25` | 心跳 | App ↔ Glasses | 保活连接 |
| `0x4B` | 通知 | App → Glasses | 推送通知 |
| `0x15` | 图像 | App → Glasses | BMP图像传输 |
| `0xF5` | 触摸事件 | Glasses → App | 触摸板操作 |

### B. 响应码速查

| 响应码 | 含义 | 场景 |
|--------|------|------|
| `0xC9` | 成功 | 命令执行成功 |
| `0xCA` | 失败 | 命令执行失败 |

### C. UUID速查

```
Service:  6E400001-B5A3-F393-E0A9-E50E24DCCA9E
TX (写):  6E400002-B5A3-F393-E0A9-E50E24DCCA9E
RX (读):  6E400003-B5A3-F393-E0A9-E50E24DCCA9E
```

### D. LC3参数速查

```
帧时长:      10ms
采样率:      16000 Hz
LC3帧大小:   20 bytes
PCM帧大小:   320 bytes (160 samples)
压缩比:      16:1
比特率:      16 kbps
```

### E. 分包大小速查

```
Even AI:     191 bytes/包
通知:        176 bytes/包
图像:        194 bytes/包
通用:        17 bytes/包
```

### F. 超时建议值

```
快速命令:    250ms  (切换屏幕)
普通命令:    1000ms (麦克风控制)
长命令:      2000ms (AI数据传输)
心跳:        1500ms
```

---

## 总结：Linus式评价

**【品味评分】** 🟡 凑合

**【为什么不是好品味？】**

1. **双设备架构是必要的复杂性**：左右眼镜分离是硬件限制，但协议没有抽象掉这种复杂性。每个命令都要发两次（先左后右），这是协议层该隐藏的细节。

2. **OpCode 没有统一结构**：命令码（0x0E, 0xF5, 0x4E...）看起来是拍脑袋定的，没有分类体系。好的设计应该是：
   - `0x0x` - 设备控制
   - `0x1x` - 显示相关
   - `0x2x` - 音频相关
   - `0xFx` - 事件通知

3. **多包传输有三种不同格式**：Even AI、通知、图像三种多包传输协议头不一致，增加了理解成本。应该统一成一种。

**【但它能工作】**

- **数据结构清晰**：字节流协议，没有过度设计
- **错误处理简单有效**：0xC9/0xCA 两个响应码足够了
- **LC3集成直接**：没有不必要的抽象层，直接解码

**【如果让我重新设计】**

1. 协议层隐藏左右设备差异，上层只看到"一副眼镜"
2. 统一OpCode命名空间，按功能分段
3. 统一多包传输格式
4. 去掉心跳包，依赖BLE底层的连接管理

但是，**"Never break userspace"** - 现有协议已经工作了，除非有真实的性能或可靠性问题，否则不要重构。

---

**【引用来源】**

1. [Even Realities 官方演示应用](https://github.com/even-realities/EvenDemoApp)
2. [even_glasses - Python BLE控制包](https://github.com/emingenc/even_glasses)
3. [g1-basis-android - Android底层库](https://github.com/rodrigofalvarez/g1-basis-android)
4. [g1_flutter_blue_plus - Flutter实现](https://github.com/emingenc/g1_flutter_blue_plus)
5. [Awesome Even Realities G1 - 资源集合](https://github.com/galfaroth/awesome-even-realities-g1)
6. [LC3 Codec - Google实现](https://github.com/google/liblc3)
7. 本项目代码: `Helix-iOS/ios/Runner/BluetoothManager.swift`
8. 本项目代码: `Helix-iOS/lib/services/proto.dart`
9. 本项目代码: `Helix-iOS/ios/Runner/PcmConverter.m`

---

**文档维护**：如果发现协议有更新或本文档有错误，请提交 Issue 或 PR。
