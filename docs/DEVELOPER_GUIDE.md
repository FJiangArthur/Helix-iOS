# Helix Developer Guide

## 🚀 Quick Start

### Prerequisites
- **Flutter SDK**: 3.24+ (Dart 3.5+)
- **Development IDE**: VS Code or Android Studio
- **Platform Tools**: Xcode (iOS), Android SDK (Android)
- **API Keys**: OpenAI and/or Anthropic (for AI features)

### Initial Setup

1. **Clone and Setup**
   ```bash
   git clone https://github.com/FJiangArthur/Helix-iOS.git
   cd Helix-iOS
   flutter pub get
   flutter gen-l10n  # Generate localizations
   ```

2. **Run Code Generation**
   ```bash
   # Generate Freezed models and JSON serialization
   flutter packages pub run build_runner build --delete-conflicting-outputs
   ```

3. **Configure API Keys**
   ```bash
   # Copy example settings
   cp settings.local.json.example settings.local.json
   # Edit with your API keys
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

## 📁 Project Structure Deep Dive

### Core Architecture Patterns

#### **Service-Based Architecture**
```
services/
├── [interface].dart          # Abstract service definition
├── implementations/          # Concrete implementations
│   └── [service]_impl.dart  # Production implementation
└── [service]_test.dart      # Service test suite
```

#### **Feature-Based Organization**
```
features/
├── [feature]/
│   ├── domain/              # Business logic layer
│   ├── presentation/        # UI layer (widgets, providers)
│   └── data/               # Data access layer
```

### Key Directories

#### **`lib/core/`** - Shared Infrastructure
- **`utils/`**: Constants, exceptions, logging
- **Purpose**: Foundation classes used across the app
- **Dependencies**: None (pure Dart)

#### **`lib/models/`** - Data Models
- **Pattern**: Freezed + JSON serialization
- **Example**:
  ```dart
  @freezed
  class ConversationModel with _$ConversationModel {
    const factory ConversationModel({
      required String id,
      required String title,
      required DateTime startTime,
      required DateTime lastUpdated,
      required List<String> participants,
      required List<TranscriptionSegment> segments,
    }) = _ConversationModel;

    factory ConversationModel.fromJson(Map<String, dynamic> json) =>
        _$ConversationModelFromJson(json);
  }
  ```

#### **`lib/services/`** - Business Logic
- **Interfaces**: Abstract service definitions
- **Implementations**: Production service code
- **AI Providers**: Pluggable AI service implementations
- **Service Locator**: Dependency injection setup

#### **`lib/ui/`** - User Interface
- **Screens**: Full-page views
- **Widgets**: Reusable UI components
- **Theme**: Centralized styling and theming

## 🔧 Development Workflow

### 1. Adding New Features

#### **Step 1: Create Feature Structure**
```bash
mkdir -p lib/features/my_feature/{domain,presentation,data}
```

#### **Step 2: Define Models (if needed)**
```dart
// lib/models/my_model.dart
@freezed
class MyModel with _$MyModel {
  const factory MyModel({
    required String id,
    required String name,
  }) = _MyModel;

  factory MyModel.fromJson(Map<String, dynamic> json) =>
      _$MyModelFromJson(json);
}
```

#### **Step 3: Create Service Interface**
```dart
// lib/services/my_service.dart
abstract class MyService {
  Future<void> initialize();
  Future<MyModel> getData(String id);
  Stream<MyModel> watchData();
  Future<void> dispose();
}
```

#### **Step 4: Implement Service**
```dart
// lib/services/implementations/my_service_impl.dart
class MyServiceImpl implements MyService {
  static const String _tag = 'MyServiceImpl';
  final LoggingService _logger;
  
  MyServiceImpl({required LoggingService logger}) : _logger = logger;
  
  @override
  Future<void> initialize() async {
    _logger.log(_tag, 'Initializing service', LogLevel.info);
    // Implementation
  }
  
  // ... other methods
}
```

#### **Step 5: Register in Service Locator**
```dart
// lib/services/service_locator.dart
getIt.registerLazySingleton<MyService>(() => MyServiceImpl(
  logger: getIt.get<LoggingService>(),
));
```

#### **Step 6: Create Tests**
```dart
// test/unit/services/my_service_test.dart
void main() {
  group('MyService', () {
    late MyService service;
    late MockLoggingService mockLogger;

    setUp(() {
      mockLogger = MockLoggingService();
      service = MyServiceImpl(logger: mockLogger);
    });

    test('should initialize successfully', () async {
      await service.initialize();
      verify(mockLogger.log(any, any, any)).called(1);
    });
  });
}
```

### 2. Working with AI Services

#### **Understanding the AI Pipeline**
```
User Input → Transcription → AI Analysis → Results Display
    ↓            ↓              ↓              ↓
Audio/Text → Text Segments → Insights/Facts → UI Updates
```

#### **Using the LLM Service**
```dart
// Get service instance
final llmService = ServiceLocator.instance.get<LLMService>();

// Initialize with API keys
await llmService.initialize(
  openAIKey: 'your-openai-key',
  anthropicKey: 'your-anthropic-key',
  preferredProvider: LLMProvider.openai,
);

// Analyze conversation
final result = await llmService.analyzeConversation(
  'Conversation text here',
  type: AnalysisType.comprehensive,
  priority: AnalysisPriority.high,
);

// Handle results
if (result.isCompleted) {
  print('Analysis completed with confidence: ${result.confidence}');
  
  if (result.factChecks != null) {
    for (final fact in result.factChecks!) {
      print('Fact: ${fact.claim} - Status: ${fact.status}');
    }
  }
}
```

#### **Real-Time Fact Checking**
```dart
// Get fact-checking service
final factChecker = ServiceLocator.instance.get<FactCheckingService>();

// Listen to results
factChecker.results.listen((result) {
  switch (result.status) {
    case FactCheckStatus.verified:
      showVerifiedIndicator(result);
      break;
    case FactCheckStatus.disputed:
      showDisputedWarning(result);
      break;
    case FactCheckStatus.uncertain:
      showUncertainIndicator(result);
      break;
  }
});

// Process transcription
await factChecker.processText('The Earth is round');
```

#### **AI Insights Service**
```dart
// Get insights service
final insights = ServiceLocator.instance.get<AIInsightsService>();

// Configure insights types
insights.configure(
  enabled: true,
  enabledTypes: InsightType.actionItems | InsightType.sentiment,
  confidenceThreshold: 0.7,
);

// Listen to insights
insights.insights.listen((insight) {
  switch (insight.category) {
    case InsightCategory.actionItem:
      addActionItemToUI(insight);
      break;
    case InsightCategory.sentiment:
      updateSentimentDisplay(insight);
      break;
    case InsightCategory.suggestion:
      showSuggestion(insight);
      break;
  }
});
```

### 3. State Management with Riverpod

#### **Creating Providers**
```dart
// lib/providers/conversation_providers.dart

// Simple state provider
final conversationIdProvider = StateProvider<String?>((ref) => null);

// Future provider for async operations
final conversationProvider = FutureProvider.family<ConversationModel, String>(
  (ref, id) async {
    final storage = ref.read(conversationStorageProvider);
    return await storage.getConversation(id);
  },
);

// Stream provider for real-time data
final transcriptionStreamProvider = StreamProvider<TranscriptionSegment>(
  (ref) {
    final service = ref.read(transcriptionServiceProvider);
    return service.transcriptionStream;
  },
);

// StateNotifier for complex state
class ConversationStateNotifier extends StateNotifier<ConversationState> {
  ConversationStateNotifier(this._storage) : super(const ConversationState.initial());
  
  final ConversationStorageService _storage;
  
  Future<void> startRecording() async {
    state = const ConversationState.recording();
    // Implementation
  }
}

final conversationStateProvider = StateNotifierProvider<ConversationStateNotifier, ConversationState>(
  (ref) => ConversationStateNotifier(ref.read(conversationStorageProvider)),
);
```

#### **Using Providers in UI**
```dart
class ConversationWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for state changes
    final conversationState = ref.watch(conversationStateProvider);
    
    // Read one-time values
    final conversationId = ref.read(conversationIdProvider);
    
    // Listen to streams
    final transcriptionAsync = ref.watch(transcriptionStreamProvider);
    
    return transcriptionAsync.when(
      data: (segment) => TranscriptionWidget(segment: segment),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
    );
  }
}
```

### 4. Testing Guidelines

#### **Unit Testing Services**
```dart
// test/unit/services/llm_service_test.dart
@GenerateMocks([LoggingService, Dio])
void main() {
  group('LLMService', () {
    late LLMService service;
    late MockLoggingService mockLogger;
    late MockDio mockDio;

    setUp(() {
      mockLogger = MockLoggingService();
      mockDio = MockDio();
      service = LLMServiceImplV2(logger: mockLogger);
    });

    test('should initialize with valid API keys', () async {
      // Arrange
      when(mockDio.get(any, options: anyNamed('options')))
          .thenAnswer((_) async => Response(
                data: {'data': []},
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      // Act
      await service.initialize(openAIKey: 'test-key');

      // Assert
      expect(service.isInitialized, isTrue);
      verify(mockLogger.log(any, contains('initialized'), LogLevel.info));
    });

    test('should handle provider failover', () async {
      // Test failover logic
    });
  });
}
```

#### **Widget Testing**
```dart
// test/widget/conversation_widget_test.dart
void main() {
  group('ConversationWidget', () {
    testWidgets('should display transcription segments', (tester) async {
      // Arrange
      final container = createContainer(
        overrides: [
          transcriptionStreamProvider.overrideWith(
            (ref) => Stream.value(TranscriptionSegment(/* test data */)),
          ),
        ],
      );

      // Act
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ConversationWidget()),
        ),
      );

      // Assert
      expect(find.byType(TranscriptionWidget), findsOneWidget);
    });
  });
}
```

#### **Integration Testing**
```dart
// test/integration/recording_workflow_test.dart
void main() {
  group('Recording Workflow', () {
    testWidgets('should complete full recording workflow', (tester) async {
      // Test end-to-end recording flow
      await tester.pumpWidget(MyApp());
      
      // Start recording
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();
      
      // Verify recording state
      expect(find.text('Recording...'), findsOneWidget);
      
      // Stop recording
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();
      
      // Verify completion
      expect(find.text('Recording saved'), findsOneWidget);
    });
  });
}
```

## 🛠️ Common Development Tasks

### Adding New AI Providers

#### **1. Create Provider Implementation**
```dart
// lib/services/ai_providers/my_ai_provider.dart
class MyAIProvider extends BaseAIProvider {
  @override
  String get name => 'MyAI';
  
  @override
  bool get isAvailable => _isInitialized && _apiKey != null;
  
  @override
  Future<void> initialize(String apiKey) async {
    _apiKey = apiKey;
    // Provider-specific initialization
    _isInitialized = true;
  }
  
  @override
  Future<String> sendCompletion({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1000,
    Map<String, dynamic>? additionalParams,
  }) async {
    // Implementation specific to your AI provider
  }
  
  // Implement other required methods...
}
```

#### **2. Register in LLM Service**
```dart
// lib/services/implementations/llm_service_impl_v2.dart
// Add to constructor
_myAIProvider = MyAIProvider(logger: logger);
_providers[LLMProvider.myai] = _myAIProvider;
```

#### **3. Add Provider Enum**
```dart
// lib/services/llm_service.dart
enum LLMProvider {
  openai,
  anthropic,
  myai,  // Add new provider
  local,
}
```

### Customizing Analysis Types

#### **1. Extend Analysis Types**
```dart
// lib/models/analysis_result.dart
enum AnalysisType {
  factCheck,
  summary,
  actionItems,
  sentiment,
  topics,
  comprehensive,
  customAnalysis,  // Add custom type
}
```

#### **2. Implement Analysis Logic**
```dart
// lib/services/implementations/llm_service_impl_v2.dart
case AnalysisType.customAnalysis:
  final customResult = await providerImpl.sendCompletion(
    prompt: buildCustomAnalysisPrompt(conversationText),
    temperature: 0.3,
  );
  
  return AnalysisResult(
    // ... build custom analysis result
  );
```

### Adding New Insight Types

#### **1. Extend Insight Categories**
```dart
// lib/services/ai_insights_service.dart
enum InsightCategory {
  summary,
  actionItem,
  question,
  sentiment,
  topic,
  suggestion,
  warning,
  opportunity,
  customInsight,  // Add new category
}
```

#### **2. Implement Insight Generation**
```dart
// In AIInsightsService
Future<List<ConversationInsight>> _generateCustomInsights(String text) async {
  // Custom insight generation logic
  final insights = <ConversationInsight>[];
  
  // Your custom analysis logic here
  
  return insights;
}
```

## 🐛 Debugging and Troubleshooting

### Common Issues

#### **1. Service Not Initialized**
```
Error: LLMException: Service not initialized
```
**Solution**: Ensure service initialization in `main.dart`:
```dart
await setupServiceLocator();
final llmService = ServiceLocator.instance.get<LLMService>();
await llmService.initialize(openAIKey: 'your-key');
```

#### **2. Provider Failover Not Working**
**Check**: Provider health monitoring
```dart
final stats = await llmService.getUsageStats();
print('Provider health: ${stats['failureStats']}');
```

#### **3. Audio Permission Issues**
**Check**: Platform-specific permissions
```dart
final audioService = ServiceLocator.instance.get<AudioService>();
final hasPermission = await audioService.requestMicrophonePermission();
if (!hasPermission) {
  // Handle permission denial
}
```

### Logging and Debugging

#### **Enable Debug Logging**
```dart
// In main.dart
final logger = LoggingService.instance;
logger.setLogLevel(LogLevel.debug);
```

#### **Service-Specific Debugging**
```dart
// Check service statistics
final llmStats = await llmService.getUsageStats();
final factCheckStats = factCheckingService.getStatistics();
final insightsStats = aiInsightsService.getStatistics();

print('LLM Service: $llmStats');
print('Fact Checking: $factCheckStats');
print('AI Insights: $insightsStats');
```

### Performance Monitoring

#### **Track Response Times**
```dart
final stopwatch = Stopwatch()..start();
final result = await llmService.analyzeConversation(text);
stopwatch.stop();
print('Analysis took: ${stopwatch.elapsedMilliseconds}ms');
```

#### **Monitor Memory Usage**
```dart
import 'dart:developer' as developer;

void logMemoryUsage() {
  final info = developer.Service.getInfo();
  print('Memory usage: ${info.heapUsage} bytes');
}
```

## 📚 Resources and References

### **Documentation**
- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [Freezed Documentation](https://pub.dev/packages/freezed)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Anthropic API Reference](https://docs.anthropic.com/api/reference)

### **Code Style and Standards**
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use [dart_code_metrics](https://pub.dev/packages/dart_code_metrics) for code quality
- Maintain 80+ character line length
- Use meaningful variable and function names
- Add ABOUTME comments to all new files

### **Development Tools**
- **VS Code Extensions**: Flutter, Dart, Riverpod Snippets
- **Analysis**: `flutter analyze` for code issues
- **Testing**: `flutter test` for unit tests
- **Coverage**: `flutter test --coverage` for test coverage
- **Build**: `flutter build apk/ios` for release builds

### **Useful Commands**
```bash
# Development
flutter run --debug                    # Run in debug mode
flutter hot-restart                    # Full restart
flutter clean && flutter pub get       # Clean build

# Code Generation
flutter packages pub run build_runner build --delete-conflicting-outputs

# Testing
flutter test                          # Run all tests
flutter test test/unit/              # Run unit tests only
flutter test --coverage             # Generate coverage report

# Analysis
flutter analyze                      # Static analysis
dart format .                       # Format code
```

---

*This developer guide covers the core concepts and workflows for contributing to the Helix project. For specific API documentation, refer to the inline documentation in the source code.*