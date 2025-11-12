# Even Realities G1 智能眼镜集成技术研究报告

## 概述

本报告基于对 Even Realities 官方演示应用 [EvenDemoApp](https://github.com/even-realities/EvenDemoApp) 的深入分析，为 Helix 项目集成 G1 智能眼镜提供技术指导和最佳实践。

## 1. 项目架构概览

### 1.1 代码库结构
```
lib/
├── ble_manager.dart          # 核心蓝牙管理器（单例模式）
├── controllers/              # 控制器层
│   ├── evenai_model_controller.dart  # AI 模型控制器
│   └── bmp_update_manager.dart       # 图像更新管理
├── models/                   # 数据模型
│   └── evenai_model.dart     # 基础 AI 模型
├── services/                 # 服务层
│   ├── ble.dart             # BLE 事件处理
│   ├── proto.dart           # 通信协议实现
│   ├── evenai_proto.dart    # AI 数据协议
│   ├── text_service.dart    # 文本流服务
│   ├── api_services.dart    # API 服务
│   └── features_services.dart # 功能服务
├── utils/                   # 工具类
├── views/                   # UI 视图层
└── main.dart               # 应用入口点

android/app/src/main/kotlin/com/example/demo_ai_even/bluetooth/
├── BleManager.kt           # 原生蓝牙管理器
├── BleChannelHelper.kt     # Flutter 通道助手
└── model/
    ├── BleDevice.kt        # 蓝牙设备模型
    └── BlePairDevice.kt    # 配对设备模型
```

## 2. 核心技术架构

### 2.1 技术栈依赖

基于 `pubspec.yaml` 分析：

```yaml
dependencies:
  flutter: ^3.5.3
  get: ^4.6.6                # 状态管理
  dio: ^5.4.3+1             # HTTP 网络请求
  crclib: ^3.0.0            # CRC 校验
  fluttertoast: ^8.2.8      # Toast 通知
```

**重要发现**：
- **不使用第三方蓝牙包**：完全基于 `MethodChannel` 和原生实现
- **状态管理**：使用 GetX 而非 Riverpod
- **简洁依赖**：只包含核心功能，无冗余包

### 2.2 蓝牙通信架构

#### Flutter 端 (lib/ble_manager.dart)
```dart
class BleManager {
  static BleManager? _instance;
  static const _channel = MethodChannel('method.bluetooth');
  static const _eventBleReceive = "eventBleReceive";
  
  // 事件流监听
  final eventBleReceive = const EventChannel(_eventBleReceive)
      .receiveBroadcastStream(_eventBleReceive)
      .map((ret) => BleReceive.fromMap(ret));

  // 核心连接方法
  Future<void> connectToGlasses(String deviceName) async {
    await _channel.invokeMethod('connectToGlasses', {'deviceName': deviceName});
    connectionStatus = 'Connecting...';
  }
  
  // 数据传输核心方法
  static Future<bool> requestList(
    List<Uint8List> sendList, {
    String? lr,  // "L" 或 "R" 指定左右眼镜
    int? timeoutMs,
  }) async {
    // 支持同时向左右眼镜发送，或指定单边
    if (lr != null) {
      return await _requestList(sendList, lr, timeoutMs: timeoutMs);
    } else {
      var rets = await Future.wait([
        _requestList(sendList, "L", keepLast: true, timeoutMs: timeoutMs),
        _requestList(sendList, "R", keepLast: true, timeoutMs: timeoutMs),
      ]);
      return rets.length == 2 && rets[0] && rets[1];
    }
  }
}
```

#### Android 端 (android/app/src/main/kotlin/.../BleManager.kt)
```kotlin
@SuppressLint("MissingPermission")
class BleManager private constructor() : CoroutineScope by MainScope() {
    companion object {
        val instance: BleManager by lazy { BleManager() }
    }
    
    private lateinit var bluetoothManager: BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter
        get() = bluetoothManager.adapter
    
    private val bleDevices: MutableList<BleDevice> = mutableListOf()
    private var connectedDevice: BlePairDevice? = null
    
    // GATT 回调处理连接状态
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                // 处理连接成功逻辑
            }
        }
    }
}
```

## 3. G1 特定通信协议

### 3.1 文本流传输协议

#### 核心协议实现 (lib/services/proto.dart)
```dart
class Proto {
  static int _evenaiSeq = 0;
  
  // AI 文本数据传输 - 核心方法
  static Future<bool> sendEvenAIData(String text, {
    int? timeoutMs,
    required int newScreen,     // 屏幕类型 (0x01)
    required int pos,           // 状态位 (0x70)
    required int current_page_num,
    required int max_page_num
  }) async {
    // 1. 编码文本数据
    var data = utf8.encode(text);
    var syncSeq = _evenaiSeq & 0xff;
    
    // 2. 构建多包数据列表
    List<Uint8List> dataList = EvenaiProto.evenaiMultiPackListV2(0x4E,
        data: data,
        syncSeq: syncSeq,
        newScreen: newScreen,
        pos: pos,
        current_page_num: current_page_num,
        max_page_num: max_page_num);
    
    // 3. 先发送到左眼镜
    bool isSuccess = await BleManager.requestList(dataList,
        lr: "L", timeoutMs: timeoutMs ?? 2000);
    
    if (!isSuccess) return false;
    
    // 4. 再发送到右眼镜
    isSuccess = await BleManager.requestList(dataList,
        lr: "R", timeoutMs: timeoutMs ?? 2000);
    
    return isSuccess;
  }
}
```

#### 文本分页服务 (lib/services/text_service.dart)
```dart
class TextService {
  static TextService get = TextService._();
  Timer? timer;
  bool isRunning = false;
  List<String> list = [];
  int currentPage = 0;
  
  // 核心文本传输方法
  void startSendText(String content) {
    if (content.isEmpty) return;
    
    // 1. 文本分行处理（每页最多5行）
    list = EvenAIDataMethod.measureStringList(content);
    currentPage = 0;
    isRunning = true;
    
    // 2. 处理不同文本长度
    if (list.length < 4) {
      // 短文本特殊处理
      doSendText(content, 0x81, 0x71, 0x70);
    } else if (list.length <= 5) {
      // 中等文本处理
      doSendText(content, 0x01, 0x70, 0x70);
    } else {
      // 长文本分页传输
      startTextPages();
    }
  }
  
  // 分页传输逻辑
  void startTextPages() {
    timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (currentPage >= getTotalPages()) {
        timer.cancel();
        isRunning = false;
        return;
      }
      
      // 获取当前页文本（5行）
      String pageText = getCurrentPageText();
      doSendText(pageText, 0x01, 0x70, 0x70);
      currentPage++;
    });
  }
}
```

### 3.2 协议包结构

#### 多包传输协议 (lib/services/evenai_proto.dart)
```dart
class EvenaiProto {
  static List<Uint8List> evenaiMultiPackListV2(
    int cmd, {
    int len = 191,                    // 每包最大长度
    required Uint8List data,          // 数据内容
    required int syncSeq,             // 同步序列号
    required int newScreen,           // 屏幕参数
    required int pos,                 // 位置参数
    required int current_page_num,    // 当前页码
    required int max_page_num,        // 总页数
  }) {
    List<Uint8List> packList = [];
    
    // 计算需要的包数量
    int totalPacks = (data.length + len - 1) ~/ len;
    
    for (int i = 0; i < totalPacks; i++) {
      // 构建每个数据包
      int start = i * len;
      int end = (start + len > data.length) ? data.length : start + len;
      
      Uint8List packet = Uint8List.fromList([
        cmd,                          // 命令字
        totalPacks,                   // 总包数
        i + 1,                        // 当前包序号
        syncSeq,                      // 同步序列
        newScreen,                    // 屏幕参数
        pos,                          // 位置参数
        current_page_num,             // 当前页
        max_page_num,                 // 总页数
        ...data.sublist(start, end)   // 数据内容
      ]);
      
      packList.add(packet);
    }
    
    return packList;
  }
}
```

## 4. 设备连接与状态管理

### 4.1 设备配对流程

#### 连接初始化 (lib/views/home_page.dart)
```dart
class HomePage extends StatelessWidget {
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: BleManager.get().getPairedGlasses().length,
      itemBuilder: (context, index) {
        final glasses = BleManager.get().getPairedGlasses()[index];
        return GestureDetector(
          onTap: () async {
            // 构建连接设备名
            String channelNumber = glasses['channelNumber']!;
            await BleManager.get().connectToGlasses("Pair_$channelNumber");
            _refreshPage();
          },
          child: Container(
            // 设备信息显示
          ),
        );
      },
    );
  }
}
```

### 4.2 状态管理模式

#### GetX 控制器实现 (lib/controllers/evenai_model_controller.dart)
```dart
class EvenaiModelController extends GetxController {
  var items = <EvenaiModel>[].obs;      // 响应式列表
  var selectedIndex = Rxn<int>();       // 响应式选择索引
  
  void addItem(String title, String content) {
    final newItem = EvenaiModel(
      title: title, 
      content: content, 
      createdTime: DateTime.now()
    );
    items.insert(0, newItem);           // 插入到列表开头
  }
  
  void removeItem(int index) {
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      if (selectedIndex.value == index) {
        selectedIndex.value = null;
      }
    }
  }
}
```

#### 依赖注入使用
```dart
// 服务中获取控制器
final controller = Get.find<EvenaiModelController>();
controller.addItem(title, content);

// 视图中初始化
@override
void initState() {
  super.initState();
  controller = Get.find<EvenaiModelController>();
}
```

## 5. 实际使用示例

### 5.1 文本发送到眼镜
```dart
// 文本页面实现 (lib/views/features/text_page.dart)
GestureDetector(
  onTap: !BleManager.get().isConnected && tfController.text.isNotEmpty
    ? null
    : () async {
        String content = tfController.text;
        TextService.get.startSendText(content);  // 开始文本传输
      },
  child: Container(
    child: Text("Send Text"),
  ),
)
```

### 5.2 图像传输示例
```dart
// BMP 图像发送 (lib/views/features/bmp_page.dart)
GestureDetector(
  onTap: () async {
    if (BleManager.get().isConnected == false) return;
    FeaturesServices().sendBmp("assets/images/image_1.bmp");
  },
  child: Container(
    child: Text("Send Image"),
  ),
)
```

## 6. 关键技术洞察

### 6.1 架构设计原则

**1. 分层架构清晰**
- **Flutter 层**：UI 和业务逻辑
- **Platform Channel**：跨平台通信桥梁
- **原生层**：底层蓝牙 GATT 操作

**2. 双眼镜同步通信**
- 必须同时向左右眼镜发送数据
- 使用 `Future.wait()` 确保同步完成
- 任一眼镜失败则整体失败

**3. 分包传输机制**
- 大数据自动分包，每包最大 191 字节
- 包含序列号和总包数，支持重传
- 支持超时和重试机制

### 6.2 性能优化策略

**1. 文本分页显示**
```dart
// 8秒间隔分页显示，避免眼镜显示过载
Timer.periodic(const Duration(seconds: 8), (timer) {
  // 发送下一页内容
});
```

**2. 连接状态监控**
```dart
// 实时监控连接状态
final eventBleReceive = const EventChannel(_eventBleReceive)
    .receiveBroadcastStream(_eventBleReceive)
    .map((ret) => BleReceive.fromMap(ret));
```

**3. 单例模式管理**
```dart
// BleManager 使用单例模式，避免多实例冲突
class BleManager {
  static BleManager? _instance;
  static BleManager get() {
    return _instance ??= BleManager._();
  }
}
```

## 7. 对 Helix 项目的集成建议

### 7.1 核心架构调整

**替换蓝牙包依赖**
```yaml
# 当前 Helix 使用
dependencies:
  flutter_bluetooth_serial: ^0.4.0

# 建议改为 MethodChannel 方式
# 移除第三方蓝牙包，使用原生实现
```

**状态管理统一**
```dart
// 保持 Helix 现有的 Riverpod
// 但可以参考 GetX 的响应式模式

class GlassesStateNotifier extends StateNotifier<GlassesState> {
  void connectToGlasses(String deviceName) async {
    state = state.copyWith(status: ConnectionStatus.connecting);
    // 实现连接逻辑
  }
}
```

### 7.2 集成实现步骤

**步骤 1：原生蓝牙实现**
```kotlin
// android/app/src/main/kotlin/.../GlassesManager.kt
class GlassesManager {
    companion object {
        const val CHANNEL = "com.helix.glasses/bluetooth"
    }
    
    fun connectToG1Glasses(deviceName: String): Boolean {
        // 实现 G1 连接逻辑
    }
}
```

**步骤 2：Flutter 桥接层**
```dart
// lib/core/glasses/glasses_manager.dart
class GlassesManager {
  static const _channel = MethodChannel('com.helix.glasses/bluetooth');
  
  Future<bool> connectToGlasses(String deviceName) async {
    return await _channel.invokeMethod('connectToGlasses', {
      'deviceName': deviceName
    });
  }
  
  Future<bool> streamText(String text) async {
    // 实现文本流传输
  }
}
```

**步骤 3：会话数据传输**
```dart
// lib/features/conversation/services/glasses_streaming_service.dart
class GlassesStreamingService {
  final GlassesManager _glassesManager;
  
  Stream<void> streamConversation(Stream<String> transcriptionStream) async* {
    await for (final transcript in transcriptionStream) {
      // 分析文本并发送到眼镜
      final analysisResult = await _aiService.analyzeText(transcript);
      await _glassesManager.streamText(analysisResult.summary);
    }
  }
}
```

### 7.3 具体集成代码

**Glasses Manager 实现**
```dart
// lib/core/glasses/glasses_manager_impl.dart
class GlassesManagerImpl implements GlassesManager {
  static const _channel = MethodChannel('method.helix.glasses');
  
  @override
  Future<bool> connectToGlasses(String deviceName) async {
    try {
      final result = await _channel.invokeMethod('connectToGlasses', {
        'deviceName': 'Pair_$deviceName'
      });
      return result as bool;
    } catch (e) {
      throw GlassesConnectionException('Failed to connect: $e');
    }
  }
  
  @override
  Future<bool> sendConversationUpdate(ConversationUpdate update) async {
    final text = _formatForDisplay(update);
    return await _sendEvenAIData(
      text: text,
      newScreen: 0x01,
      pos: 0x70,
      currentPage: 1,
      maxPage: 1,
    );
  }
  
  String _formatForDisplay(ConversationUpdate update) {
    return '''
💬 ${update.speaker}: ${update.text}
🤖 AI: ${update.aiInsight}
''';
  }
}
```

## 8. 重要注意事项

### 8.1 硬件兼容性
- **设备命名规范**：G1 设备名格式为 `Pair_[channel]`
- **双眼镜架构**：必须同时连接左右眼镜
- **连接超时**：建议 2000ms 超时设置

### 8.2 性能限制
- **文本长度**：每次传输最多 5 行文本
- **传输间隔**：建议 8 秒间隔避免过载
- **包大小限制**：每包最大 191 字节

### 8.3 错误处理
```dart
// 连接失败重试机制
Future<bool> connectWithRetry(String deviceName, {int maxRetries = 3}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      return await connectToGlasses(deviceName);
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: 2 << i)); // 指数退避
    }
  }
  return false;
}
```

## 9. 总结

Even Realities G1 集成的核心是：

1. **原生蓝牙实现**：不依赖第三方包，直接使用 MethodChannel
2. **双眼镜同步**：必须同时向左右眼镜发送数据
3. **分包协议**：支持大数据分包传输，包含重传机制
4. **分页显示**：长文本自动分页，8 秒间隔显示
5. **状态管理**：使用响应式状态管理，实时更新连接状态

对于 Helix 项目，建议将现有的 `flutter_bluetooth_serial` 替换为原生 MethodChannel 实现，并按照 Even Realities 的协议标准实现 G1 集成。

## 引用来源

- [EvenDemoApp GitHub Repository](https://github.com/even-realities/EvenDemoApp)
- [Flutter MethodChannel Documentation](https://docs.flutter.dev/platform-integration/platform-channels)
- [Android BluetoothGatt API](https://developer.android.com/reference/android/bluetooth/BluetoothGatt)