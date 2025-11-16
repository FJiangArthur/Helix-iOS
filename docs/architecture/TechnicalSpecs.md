# Helix Technical Specifications

## 1. System Architecture

### 1.1 Proven Clean Architecture
- **Flutter Framework**: Cross-platform with iOS focus
- **Direct Service Communication**: No complex state management
- **Incremental Development**: Each phase builds working functionality
- **Stream-based Data Flow**: Real-time updates via Dart Streams

### 1.2 Current Module Structure (Implemented)
```
lib/
├── main.dart                       # App entry point
├── app.dart                        # MaterialApp with error boundaries
├── services/
│   ├── audio_service.dart          # Clean audio interface
│   └── implementations/
│       └── audio_service_impl.dart # flutter_sound implementation
├── models/
│   └── audio_configuration.dart    # Freezed immutable config
├── screens/
│   ├── recording_screen.dart       # Main recording UI
│   └── file_management_screen.dart # File list and playback
└── core/utils/
    └── exceptions.dart             # Audio-specific exceptions
```

### 1.3 Future Module Structure (Planned)
```
lib/
├── services/
│   ├── transcription_service.dart  # Speech-to-text interface
│   ├── llm_service.dart            # AI analysis interface
│   ├── glasses_service.dart        # Bluetooth glasses interface
│   └── implementations/            # Concrete implementations
├── models/
│   ├── conversation_model.dart     # Conversation data
│   ├── transcription_model.dart    # STT results
│   └── analysis_model.dart         # AI analysis results
├── screens/
│   ├── conversation_screen.dart    # Real-time conversation
│   ├── analysis_screen.dart        # AI insights display
│   └── settings_screen.dart        # App configuration
└── utils/
    ├── bluetooth_manager.dart      # Glasses connectivity
    └── storage_manager.dart        # Local data persistence
```

## 2. Audio Processing Specifications

### 2.1 Current Audio Implementation (Proven)
```dart
// AudioService interface - Clean and focused
abstract class AudioService {
  bool get isRecording;
  bool get hasPermission;
  Stream<double> get audioLevelStream;
  Stream<Duration> get recordingDurationStream;
  
  Future<void> initialize(AudioConfiguration config);
  Future<bool> requestPermission();
  Future<void> startRecording();
  Future<void> stopRecording();
}

// AudioConfiguration - Immutable with Freezed
@freezed
class AudioConfiguration with _$AudioConfiguration {
  const factory AudioConfiguration({
    @Default(16000) int sampleRate,    // 16kHz for speech
    @Default(1) int channels,          // Mono recording
    @Default(AudioQuality.medium) AudioQuality quality,
    @Default(AudioFormat.wav) AudioFormat format,
  }) = _AudioConfiguration;
}
```

### 2.2 Audio Processing Implementation
```dart
// AudioServiceImpl - Direct flutter_sound integration
class AudioServiceImpl implements AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  
  // Real-time monitoring via flutter_sound streams
  void _startSimpleMonitoring() {
    _recorder.onProgress?.listen((progress) {
      // Real audio level from decibels
      _currentAudioLevel = ((progress.decibels! + 60) / 60).clamp(0.0, 1.0);
      _audioLevelStreamController.add(_currentAudioLevel);
      
      // Real recording duration
      _recordingDurationStreamController.add(progress.duration);
    });
  }
}
```

### 2.3 Proven Performance Metrics
- **Sample Rate**: 16kHz (optimal for speech recognition)
- **Audio Latency**: <100ms capture to UI update
- **Memory Usage**: <50MB sustained operation
- **File Format**: WAV (PCM 16-bit) for compatibility
- **Real-time Updates**: 30fps audio level visualization

## 3. Future Implementation Specifications

### 3.1 Phase 2: Speech-to-Text (Steps 6-9)
```dart
// TranscriptionService interface - Simple and focused
abstract class TranscriptionService {
  bool get isListening;
  Stream<TranscriptionResult> get transcriptionStream;
  
  Future<void> startListening();
  Future<void> stopListening();
  Future<void> setLanguage(String languageCode);
}

// TranscriptionResult - Immutable data model
@freezed
class TranscriptionResult with _$TranscriptionResult {
  const factory TranscriptionResult({
    required String text,
    required bool isFinal,
    required double confidence,
    required DateTime timestamp,
    String? speakerId,  // Basic speaker identification
  }) = _TranscriptionResult;
}

// Implementation using speech_to_text package
class TranscriptionServiceImpl implements TranscriptionService {
  final SpeechToText _speech = SpeechToText();
  
  Future<void> startListening() async {
    await _speech.listen(
      onResult: (result) {
        final transcription = TranscriptionResult(
          text: result.recognizedWords,
          isFinal: result.finalResult,
          confidence: result.confidence,
          timestamp: DateTime.now(),
        );
        _transcriptionController.add(transcription);
      },
    );
  }
}
```

### 3.2 Phase 3: Data Management (Steps 10-12)
```dart
// ConversationService - Simple conversation management
abstract class ConversationService {
  Stream<List<Conversation>> get conversationsStream;
  
  Future<Conversation> createConversation(String title);
  Future<void> addSegment(String conversationId, TranscriptionSegment segment);
  Future<void> saveConversation(Conversation conversation);
  Future<List<Conversation>> searchConversations(String query);
}

// Conversation model - Clean data structure
@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    required String title,
    required DateTime startTime,
    DateTime? endTime,
    required List<TranscriptionSegment> segments,
    Map<String, dynamic>? metadata,
  }) = _Conversation;
}
```

## 4. Phase 4: AI Analysis (Steps 13-15)

### 4.1 LLM Service Design
```dart
// LLMService - Simple AI integration
abstract class LLMService {
  Future<AnalysisResult> analyzeConversation(List<TranscriptionSegment> segments);
  Future<FactCheckResult> checkFact(String claim);
  Future<String> summarizeConversation(Conversation conversation);
}

// AnalysisResult - Clean data model
@freezed
class AnalysisResult with _$AnalysisResult {
  const factory AnalysisResult({
    required String summary,
    required List<String> keyTopics,
    required List<String> actionItems,
    required double confidence,
    required DateTime timestamp,
  }) = _AnalysisResult;
}

// FactCheckResult - Simple verification model
@freezed
class FactCheckResult with _$FactCheckResult {
  const factory FactCheckResult({
    required String claim,
    required bool isAccurate,
    required String explanation,
    required double confidence,
    List<String>? sources,
  }) = _FactCheckResult;
}

// Implementation with direct HTTP calls
class LLMServiceImpl implements LLMService {
  final http.Client _client = http.Client();
  
  Future<AnalysisResult> analyzeConversation(List<TranscriptionSegment> segments) async {
    final prompt = _buildAnalysisPrompt(segments);
    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [{'role': 'user', 'content': prompt}],
        'max_tokens': 500,
      }),
    );
    return _parseAnalysisResponse(response.body);
  }
}
```

## 5. Phase 5: Smart Glasses Integration (Steps 16-18)

### 5.1 Glasses Service Design
```dart
// GlassesService - Simple Bluetooth integration
abstract class GlassesService {
  bool get isConnected;
  Stream<ConnectionState> get connectionStream;
  Stream<double> get batteryStream;
  
  Future<void> connect();
  Future<void> disconnect();
  Future<void> displayText(String text);
  Future<void> clearDisplay();
}

// ConnectionState - Simple state model
@freezed
class ConnectionState with _$ConnectionState {
  const factory ConnectionState.disconnected() = _Disconnected;
  const factory ConnectionState.connecting() = _Connecting;
  const factory ConnectionState.connected() = _Connected;
  const factory ConnectionState.error(String message) = _Error;
}

// Implementation with flutter_bluetooth_serial
class GlassesServiceImpl implements GlassesService {
  BluetoothConnection? _connection;
  
  Future<void> connect() async {
    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    final glasses = devices.firstWhere(
      (device) => device.name?.contains('Even Realities') ?? false,
    );
    
    _connection = await BluetoothConnection.toAddress(glasses.address);
    _connectionController.add(const ConnectionState.connected());
  }
  
  Future<void> displayText(String text) async {
    if (_connection?.isConnected ?? false) {
      _connection!.output.add(Uint8List.fromList(text.codeUnits));
    }
  }
}
```

## 6. Implementation Roadmap

### 6.1 Development Phases
```yaml
Phase 1 (Completed): Audio Foundation
  - Steps 1-5: Basic audio recording with UI
  - Status: ✅ Proven working on iOS devices
  - Duration: 1 week

Phase 2 (Planned): Speech-to-Text  
  - Steps 6-9: Real-time transcription
  - Dependencies: speech_to_text package
  - Duration: 1-2 weeks

Phase 3 (Planned): Data Management
  - Steps 10-12: Conversation organization
  - Dependencies: sqflite, path_provider
  - Duration: 1-2 weeks

Phase 4 (Planned): AI Analysis
  - Steps 13-15: LLM integration
  - Dependencies: http, OpenAI/Anthropic APIs
  - Duration: 2-3 weeks

Phase 5 (Planned): Glasses Integration
  - Steps 16-18: Bluetooth and HUD
  - Dependencies: flutter_bluetooth_serial, Even Realities SDK
  - Duration: 2-3 weeks
```

### 6.2 Quality Assurance Strategy
```yaml
Build Verification:
  - Each step must compile without errors
  - All existing functionality must continue working
  - New features must be manually tested

Testing Approach:
  - Unit tests for service interfaces
  - Widget tests for UI components  
  - Device testing on real iOS hardware
  - User acceptance testing for each phase

Performance Monitoring:
  - Memory usage tracking
  - Battery impact measurement
  - Audio latency verification
  - UI responsiveness validation
```

## 7. Deployment Strategy

### 7.1 Incremental Deployment
- **Phase releases**: Each phase is independently deployable
- **Feature flags**: Enable/disable features during development
- **TestFlight distribution**: Continuous beta testing with users
- **App Store updates**: Regular incremental improvements

### 7.2 Technology Dependencies
```yaml
Current (Proven):
  - Flutter 3.24+, Dart 3.5+
  - flutter_sound ^9.2.13
  - permission_handler ^10.2.0
  - freezed_annotation ^2.4.1

Phase 2 Additions:
  - speech_to_text ^6.6.0

Phase 3 Additions:
  - sqflite ^2.3.0
  - path_provider ^2.1.1

Phase 4 Additions:
  - http ^1.1.0
  - dio ^5.4.0 (for advanced API features)

Phase 5 Additions:
  - flutter_bluetooth_serial ^0.4.0
  - Even Realities SDK (when available)
```

## 8. Lessons Learned & Best Practices

### 8.1 Architecture Principles
- **Simplicity wins**: Direct service-to-UI communication beats complex state management
- **Incremental is safer**: Build working features before adding complexity
- **Real data flows**: Use actual streams and data, not mock implementations
- **Clean interfaces**: Well-defined service contracts enable easy testing

### 8.2 Development Guidelines
- **Build before adding**: Each feature must work before moving to the next
- **Test on devices**: Simulator testing is insufficient for audio/Bluetooth features
- **Keep dependencies minimal**: Only add packages when actually needed
- **Document as you go**: Keep specs updated with actual implementation