# Flutter Sound 库技术调研报告

## 核心判断

✅ **值得深度集成** - flutter_sound 是 Flutter 生态中最成熟的音频录制库，拥有完整的跨平台支持和强大的功能集

## 关键洞察

- **数据结构**: FlutterSoundRecorder/Player 采用事件流架构，通过 Stream 实现实时音频级别监控
- **复杂度**: 初始化和权限管理需要严格的顺序，但核心录制 API 相对简洁
- **风险点**: 权限处理、平台差异、音频会话管理是主要坑点

---

## 1. 库标识与基础信息

### 官方信息
- **Package Name**: `flutter_sound`
- **Repository**: https://github.com/canardoux/flutter_sound
- **Current Version**: 推荐使用最新稳定版
- **Platform Support**: iOS, Android, Web, macOS, Windows, Linux

### 核心能力概述
flutter_sound 是一个全功能音频处理库，支持：
- 高质量音频录制和播放
- 多种音频编解码器 (AAC, MP3, WAV, PCM等)
- 实时音频流处理
- 音频级别监控和可视化
- 背景录制支持
- 跨平台一致性API

---

## 2. 接口规范与核心API

### 主要类定义

```dart
// 核心录制器类
class FlutterSoundRecorder {
  // 初始化和生命周期
  Future<FlutterSoundRecorder?> openRecorder({bool isBGService = false});
  Future<void> closeRecorder();
  
  // 录制控制
  Future<String?> startRecorder({
    String? toFile,
    Codec codec = Codec.defaultCodec,
    int? sampleRate,
    int? numChannels,
    int? bitRate,
    AudioSource audioSource = AudioSource.microphone,
    StreamSink<Uint8List>? toStream,  // 流模式
  });
  
  Future<String?> stopRecorder();
  
  // 实时监控
  Future<void> setSubscriptionDuration(Duration duration);
  Stream<RecordingProgress>? get onProgress;
  
  // 状态查询
  bool get isRecording;
  bool get isInited;
}

// 播放器类
class FlutterSoundPlayer {
  Future<FlutterSoundPlayer?> openPlayer();
  Future<void> closePlayer();
  
  Future<void> startPlayer({
    String? fromURI,
    Uint8List? fromDataBuffer,
    Codec codec = Codec.defaultCodec,
  });
  
  Future<void> stopPlayer();
  Stream<PlaybackDisposition>? get onProgress;
}
```

### 关键数据模型

```dart
class RecordingProgress {
  Duration duration;        // 录制时长
  double? decibels;        // 音频级别 (dB)
}

class PlaybackDisposition {
  Duration duration;       // 播放时长
  Duration position;       // 当前位置
}

enum Codec {
  aacADTS,    // AAC格式 (推荐用于语音)
  aacMP4,     // AAC/MP4 (iOS推荐)
  pcm16,      // PCM 16位 (流处理)
  pcm16WAV,   // WAV格式
  opusOGG,    // Opus编码
}
```

---

## 3. 基础使用指南

### 3.1 依赖添加

```yaml
dependencies:
  flutter_sound: ^9.2.13
  permission_handler: ^10.4.3
  path_provider: ^2.1.1
  audio_session: ^0.1.16  # iOS音频会话管理
```

### 3.2 权限配置

**Android (android/app/src/main/AndroidManifest.xml):**
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

**iOS (ios/Runner/Info.plist):**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>此应用需要访问麦克风进行录音功能</string>
```

### 3.3 基础录制实现

```dart
class AudioRecorderService {
  FlutterSoundRecorder? _recorder;
  StreamSubscription? _progressSubscription;
  
  // 1. 初始化
  Future<bool> initRecorder() async {
    try {
      // 请求麦克风权限
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return false;
      }
      
      // 初始化录制器
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
      
      // 设置进度监听间隔
      await _recorder!.setSubscriptionDuration(
        const Duration(milliseconds: 100)
      );
      
      return true;
    } catch (e) {
      print('录制器初始化失败: $e');
      return false;
    }
  }
  
  // 2. 开始录制
  Future<bool> startRecording(String filePath) async {
    try {
      await _recorder!.startRecorder(
        toFile: filePath,
        codec: Platform.isIOS ? Codec.aacADTS : Codec.aacADTS,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
        audioSource: AudioSource.microphone,
      );
      
      // 监听录制进度
      _progressSubscription = _recorder!.onProgress?.listen((progress) {
        // 更新UI：录制时长、音频级别
        _updateRecordingProgress(progress.duration, progress.decibels);
      });
      
      return true;
    } catch (e) {
      print('开始录制失败: $e');
      return false;
    }
  }
  
  // 3. 停止录制
  Future<String?> stopRecording() async {
    try {
      final recordedFilePath = await _recorder!.stopRecorder();
      _progressSubscription?.cancel();
      return recordedFilePath;
    } catch (e) {
      print('停止录制失败: $e');
      return null;
    }
  }
  
  // 4. 清理资源
  Future<void> dispose() async {
    _progressSubscription?.cancel();
    await _recorder?.closeRecorder();
  }
}
```

---

## 4. 进阶技巧与最佳实践

### 4.1 实时音频流处理

对于需要实时处理音频数据的场景（如实时转录），使用流模式：

```dart
class RealtimeAudioProcessor {
  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List>? _audioController;
  StreamSubscription? _audioSubscription;
  
  Future<void> startRealtimeRecording() async {
    _audioController = StreamController<Uint8List>();
    
    // 监听音频数据流
    _audioSubscription = _audioController!.stream.listen((audioData) {
      // 处理实时音频数据
      _processAudioChunk(audioData);
    });
    
    await _recorder!.startRecorder(
      toStream: _audioController!.sink,  // 关键：输出到流
      codec: Codec.pcm16,               // PCM格式适合流处理
      numChannels: 1,
      sampleRate: 16000,                // 16kHz适合语音识别
      bufferSize: 8192,                 // 缓冲区大小
    );
  }
  
  void _processAudioChunk(Uint8List audioData) {
    // 发送到语音识别服务
    // 或进行实时音频分析
  }
}
```

### 4.2 高级音频会话管理 (iOS)

```dart
import 'package:audio_session/audio_session.dart';

class AdvancedAudioService {
  late AudioSession _audioSession;
  
  Future<void> setupAudioSession() async {
    _audioSession = await AudioSession.instance;
    
    // 配置音频会话
    await _audioSession.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: 
        AVAudioSessionCategoryOptions.allowBluetooth |
        AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.measurement,
      avAudioSessionRouteSharingPolicy: 
        AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
    ));
  }
  
  Future<void> activateSession() async {
    await _audioSession.setActive(true);
  }
  
  Future<void> deactivateSession() async {
    await _audioSession.setActive(false);
  }
}
```

### 4.3 音频级别可视化

```dart
class WaveformVisualizer extends StatefulWidget {
  final double? audioLevel;  // 从 RecordingProgress.decibels 获取
  
  @override
  _WaveformVisualizerState createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 100),
      vsync: this,
    );
  }
  
  @override
  void didUpdateWidget(WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.audioLevel != oldWidget.audioLevel) {
      // 根据音频级别更新动画
      final normalizedLevel = _normalizeAudioLevel(widget.audioLevel);
      _animationController.animateTo(normalizedLevel);
    }
  }
  
  double _normalizeAudioLevel(double? decibels) {
    if (decibels == null) return 0.0;
    // 将分贝值转换为0-1范围
    // 典型范围: -60dB (静音) 到 0dB (最大)
    return ((decibels + 60) / 60).clamp(0.0, 1.0);
  }
}
```

---

## 5. 巧妙用法和创新模式

### 5.1 背景录制服务

利用 flutter_sound 的 `isBGService` 参数实现后台录制：

```dart
class BackgroundRecorderService {
  static const String _channelId = 'audio_recorder_service';
  FlutterSoundRecorder? _recorder;
  
  Future<void> startBackgroundRecording() async {
    // 初始化后台服务录制器
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder(isBGService: true);  // 关键参数
    
    // 创建前台服务通知
    await _createForegroundNotification();
    
    await _recorder!.startRecorder(
      toFile: await _getBackgroundRecordingPath(),
      codec: Codec.aacADTS,
    );
  }
  
  Future<void> _createForegroundNotification() async {
    // 配置前台服务通知，确保系统不会杀死录制进程
  }
}
```

### 5.2 智能音频检测

结合音频级别监控实现语音活动检测：

```dart
class VoiceActivityDetector {
  static const double _silenceThreshold = -40.0;  // 静音阈值
  static const Duration _silenceTimeout = Duration(seconds: 2);
  
  Timer? _silenceTimer;
  bool _isVoiceActive = false;
  
  void onAudioLevel(double? decibels) {
    if (decibels == null) return;
    
    if (decibels > _silenceThreshold) {
      // 检测到语音
      if (!_isVoiceActive) {
        _isVoiceActive = true;
        _onVoiceStart();
      }
      _silenceTimer?.cancel();
    } else {
      // 静音状态
      _silenceTimer?.cancel();
      _silenceTimer = Timer(_silenceTimeout, () {
        if (_isVoiceActive) {
          _isVoiceActive = false;
          _onVoiceEnd();
        }
      });
    }
  }
  
  void _onVoiceStart() {
    // 语音开始 - 可以启动转录服务
  }
  
  void _onVoiceEnd() {
    // 语音结束 - 可以处理录制结果
  }
}
```

### 5.3 多段录音拼接

```dart
class SegmentedRecorder {
  List<String> _recordingSegments = [];
  int _currentSegmentIndex = 0;
  
  Future<void> startNewSegment() async {
    final segmentPath = await _getSegmentPath(_currentSegmentIndex);
    await _recorder!.startRecorder(toFile: segmentPath);
    _recordingSegments.add(segmentPath);
    _currentSegmentIndex++;
  }
  
  Future<String> combineSegments() async {
    // 使用 FFmpeg 或其他工具合并音频段
    final combinedPath = await _getCombinedPath();
    await _mergeAudioFiles(_recordingSegments, combinedPath);
    
    // 清理临时文件
    for (final segment in _recordingSegments) {
      await File(segment).delete();
    }
    
    return combinedPath;
  }
}
```

---

## 6. 注意事项与常见陷阱

### 6.1 权限处理最佳实践

```dart
class PermissionHandler {
  static Future<bool> requestMicrophonePermission() async {
    // 1. 检查当前权限状态
    final current = await Permission.microphone.status;
    
    if (current == PermissionStatus.granted) {
      return true;
    }
    
    // 2. 首次请求
    if (current == PermissionStatus.denied) {
      final result = await Permission.microphone.request();
      return result == PermissionStatus.granted;
    }
    
    // 3. 永久拒绝的处理
    if (current == PermissionStatus.permanentlyDenied) {
      // 引导用户到设置页面
      await _showPermissionDialog();
      return false;
    }
    
    return false;
  }
  
  static Future<void> _showPermissionDialog() async {
    // 显示对话框指导用户手动开启权限
    // 可以使用 openAppSettings() 跳转到设置
  }
}
```

### 6.2 内存管理

```dart
class AudioMemoryManager {
  // 错误示例：不释放资源
  // ❌ 内存泄漏风险
  void badExample() async {
    final recorder = FlutterSoundRecorder();
    await recorder.openRecorder();
    // 忘记调用 closeRecorder()
  }
  
  // 正确示例：确保资源释放
  // ✅ 良好的资源管理
  Future<void> goodExample() async {
    FlutterSoundRecorder? recorder;
    try {
      recorder = FlutterSoundRecorder();
      await recorder.openRecorder();
      
      // 进行录制操作...
      
    } finally {
      // 无论成功还是失败都要释放资源
      await recorder?.closeRecorder();
    }
  }
}
```

### 6.3 平台特定问题

**iOS相关:**
```dart
// iOS需要特别注意音频会话配置
if (Platform.isIOS) {
  // 使用 AAC 格式获得最佳兼容性
  codec = Codec.aacADTS;
  
  // 确保音频会话正确配置
  await _audioSession.setActive(true);
  
  // 处理音频中断 (电话、闹钟等)
  _audioSession.interruptionEventStream.listen((event) {
    if (event.begin) {
      // 暂停录制
      _pauseRecording();
    } else {
      // 恢复录制
      _resumeRecording();
    }
  });
}
```

**Android相关:**
```dart
// Android需要处理更复杂的权限和后台限制
if (Platform.isAndroid) {
  // 检查 Android 版本
  if (await _getAndroidSDKVersion() >= 29) {
    // Android 10+ 需要额外的存储权限处理
    await Permission.storage.request();
  }
  
  // 处理后台录制限制
  if (await _isBackgroundRecording()) {
    await _requestBackgroundPermissions();
  }
}
```

---

## 7. 真实代码片段集锦

### 7.1 完整的录制器实现 (来自生产项目)

```dart
// 基于 BasedHardware/omi 项目的实现
class ProductionAudioRecorder {
  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List>? _controller;
  
  Future<bool> startRecording({
    required Function(Uint8List bytes) onByteReceived,
    Function()? onRecording,
    Function()? onStop,
  }) async {
    try {
      await Permission.microphone.request();
      
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder(isBGService: false);
      
      _controller = StreamController<Uint8List>();
      _controller!.stream.listen(onByteReceived);
      
      await _recorder!.startRecorder(
        toStream: _controller!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        bufferSize: 8192,
      );
      
      onRecording?.call();
      return true;
    } catch (e) {
      print('录制启动失败: $e');
      return false;
    }
  }
  
  Future<void> stopRecording() async {
    await _recorder?.stopRecorder();
    await _recorder?.closeRecorder();
    await _controller?.close();
  }
}
```

### 7.2 实时转录集成 (来自 Google Speech 示例)

```dart
// 基于 felixjunghans/google_speech 的实现
class SpeechToTextIntegration {
  FlutterSoundRecorder? _recorder;
  StreamController<List<int>>? _audioStream;
  SpeechToText? _speechService;
  
  Future<void> startRealtimeTranscription() async {
    await Permission.microphone.request();
    
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    
    _audioStream = StreamController<List<int>>();
    
    // 配置语音识别服务
    final serviceAccount = ServiceAccount.fromString(_apiKey);
    _speechService = SpeechToText.viaServiceAccount(serviceAccount);
    
    // 开始流式识别
    final recognitionConfig = RecognitionConfig(
      encoding: AudioEncoding.LINEAR16,
      model: RecognitionModel.latest_short,
      enableAutomaticPunctuation: true,
      languageCode: 'zh-CN',
    );
    
    final responses = _speechService!.streamingRecognize(
      StreamingRecognitionConfig(
        config: recognitionConfig,
        interimResults: true,
      ),
      _audioStream!.stream,
    );
    
    responses.listen((response) {
      if (response.results.isNotEmpty) {
        final transcript = response.results.first.alternatives.first.transcript;
        _onTranscriptionReceived(transcript);
      }
    });
    
    // 开始录制到流
    await _recorder!.startRecorder(
      toStream: _audioStream!.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );
  }
}
```

### 7.3 语音消息UI组件 (来自聊天应用)

```dart
// 基于多个聊天应用项目的最佳实践
class VoiceMessageRecorder extends StatefulWidget {
  final Function(String filePath) onRecordingComplete;
  
  @override
  _VoiceMessageRecorderState createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder> 
    with TickerProviderStateMixin {
  FlutterSoundRecorder? _recorder;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  double _audioLevel = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _waveController = AnimationController(
      duration: Duration(milliseconds: 100),
      vsync: this,
    );
  }
  
  Future<void> _initializeRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;
    
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    await _recorder!.setSubscriptionDuration(Duration(milliseconds: 50));
  }
  
  Future<void> _startRecording() async {
    if (_recorder == null) return;
    
    final tempDir = await getTemporaryDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
    final filePath = '${tempDir.path}/$fileName';
    
    await _recorder!.startRecorder(
      toFile: filePath,
      codec: Codec.aacADTS,
      bitRate: 32000,  // 优化文件大小
      sampleRate: 22050,
    );
    
    // 监听录制进度
    _recorder!.onProgress?.listen((progress) {
      setState(() {
        _recordingDuration = progress.duration;
        _audioLevel = progress.decibels ?? 0.0;
      });
      
      // 根据音频级别调整波形动画
      final normalizedLevel = (_audioLevel + 50) / 50;
      _waveController.animateTo(normalizedLevel.clamp(0.0, 1.0));
    });
    
    setState(() {
      _isRecording = true;
    });
  }
  
  Future<void> _stopRecording() async {
    final filePath = await _recorder!.stopRecorder();
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
    
    if (filePath != null) {
      widget.onRecordingComplete(filePath);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _waveController]),
        builder: (context, child) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording ? Colors.red : Colors.blue,
              boxShadow: _isRecording ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 20 * _pulseController.value,
                  spreadRadius: 10 * _pulseController.value,
                ),
              ] : null,
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 30 + (10 * _waveController.value),
            ),
          );
        },
      ),
    );
  }
  
  @override
  void dispose() {
    _recorder?.closeRecorder();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }
}
```

---

## 8. 性能优化技巧

### 8.1 音频格式选择

```dart
class AudioFormatOptimizer {
  static Codec getOptimalCodec({
    required bool isRealtimeProcessing,
    required bool isStorage,
    required Platform platform,
  }) {
    if (isRealtimeProcessing) {
      // 实时处理优选 PCM，无压缩延迟
      return Codec.pcm16;
    }
    
    if (isStorage) {
      if (Platform.isIOS) {
        // iOS 优选 AAC，系统原生支持
        return Codec.aacADTS;
      } else {
        // Android 通用 AAC
        return Codec.aacADTS;
      }
    }
    
    // 默认选择
    return Codec.aacADTS;
  }
  
  static Map<String, dynamic> getOptimalSettings({
    required bool isVoiceRecording,
    required bool isHighQuality,
  }) {
    if (isVoiceRecording) {
      return {
        'sampleRate': 16000,    // 语音足够
        'bitRate': 32000,       // 压缩文件大小
        'numChannels': 1,       // 单声道
      };
    }
    
    if (isHighQuality) {
      return {
        'sampleRate': 44100,    // CD质量
        'bitRate': 128000,      // 高比特率
        'numChannels': 2,       // 立体声
      };
    }
    
    return {
      'sampleRate': 22050,     // 平衡选择
      'bitRate': 64000,
      'numChannels': 1,
    };
  }
}
```

### 8.2 内存优化

```dart
class MemoryOptimizedRecorder {
  // 使用对象池减少 GC 压力
  static final _recorderPool = <FlutterSoundRecorder>[];
  
  static Future<FlutterSoundRecorder> borrowRecorder() async {
    if (_recorderPool.isNotEmpty) {
      return _recorderPool.removeLast();
    }
    
    final recorder = FlutterSoundRecorder();
    await recorder.openRecorder();
    return recorder;
  }
  
  static void returnRecorder(FlutterSoundRecorder recorder) {
    if (_recorderPool.length < 3) {  // 限制池大小
      _recorderPool.add(recorder);
    } else {
      recorder.closeRecorder();
    }
  }
  
  // 大文件录制时的内存管理
  static Future<void> recordLargeFile({
    required String filePath,
    required Duration maxDuration,
  }) async {
    final recorder = await borrowRecorder();
    
    try {
      // 设置较大的缓冲区减少 I/O
      await recorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
        bufferSize: 16384,  // 增大缓冲区
      );
      
      // 定期检查文件大小，避免内存耗尽
      Timer.periodic(Duration(seconds: 30), (timer) async {
        final file = File(filePath);
        if (await file.exists()) {
          final size = await file.length();
          if (size > 100 * 1024 * 1024) {  // 100MB 限制
            timer.cancel();
            await recorder.stopRecorder();
          }
        }
      });
      
    } finally {
      returnRecorder(recorder);
    }
  }
}
```

---

## 9. 引用来源

### 官方文档来源
- **Context7 Library**: `/canardoux/flutter_sound` - 官方 flutter_sound 库文档
- **GitHub Repository**: https://github.com/canardoux/flutter_sound
- **Pub.dev Package**: https://pub.dev/packages/flutter_sound

### 真实项目代码来源
1. **BasedHardware/omi** - 实时音频流处理实现
   - License: MIT
   - URL: https://github.com/BasedHardware/omi

2. **maxkrieger/voiceliner** - 音频录制和播放管理
   - License: AGPL-3.0  
   - URL: https://github.com/maxkrieger/voiceliner

3. **felixjunghans/google_speech** - 语音识别集成示例
   - License: MIT
   - URL: https://github.com/felixjunghans/google_speech

4. **RivaanRanawat/flutter-whatsapp-clone** - 聊天应用音频消息
   - URL: https://github.com/RivaanRanawat/flutter-whatsapp-clone

5. **netease-kit/nim-uikit-flutter** - 企业级音频录制UI
   - License: MIT
   - URL: https://github.com/netease-kit/nim-uikit-flutter

### 社区最佳实践来源
- **chn-sunch/flutter_mycommunity_app** - 社区应用音频功能实现
- **SankethBK/diaryvault** - 日记应用录音功能
- **ahmedelbagory332/full_chat_flutter_app** - 全功能聊天应用

---

## 10. 针对你的 AudioService 实现建议

### 立即修复的关键问题

1. **替换假计时器实现**:
```dart
// ❌ 当前的假实现
Timer.periodic(Duration(seconds: 1), (timer) {
  // 假的计时逻辑
});

// ✅ 正确实现
_recorder!.onProgress?.listen((progress) {
  _updateTimer(progress.duration);
  _updateAudioLevel(progress.decibels);
});
```

2. **实现真实权限处理**:
```dart
Future<bool> requestMicrophonePermission() async {
  final status = await Permission.microphone.request();
  return status == PermissionStatus.granted;
}
```

3. **添加真实音频级别监控**:
```dart
Stream<double> get audioLevels {
  return _recorder?.onProgress?.map((progress) {
    return _normalizeDecibels(progress.decibels);
  }) ?? Stream.empty();
}
```

### 架构改进建议

基于 Linus 的"好品味"原则，你的 AudioService 应该：
1. **消除特殊情况** - 统一处理所有录制状态
2. **简化数据结构** - 用 Stream 替代复杂的状态管理
3. **减少层级复杂度** - 直接使用 flutter_sound API，不要过度封装

这份调研报告应该能帮助你完全重构 AudioService 实现，解决当前的所有阻塞问题。