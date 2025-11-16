# Integration Testing Guide

Guide to writing and running integration tests for the Helix iOS application.

## What is Integration Testing?

Integration tests verify that multiple components work correctly together. They test the interactions and data flow between different parts of the system.

## When to Write Integration Tests

Write integration tests when:
- Testing interactions between services
- Verifying data flows through multiple layers
- Testing feature workflows
- Validating system behavior with real (or realistic) dependencies

## Test Structure

### Basic Integration Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Feature Integration Tests', () {
    late ServiceA serviceA;
    late ServiceB serviceB;

    setUp(() async {
      serviceA = ServiceA();
      serviceB = ServiceB();

      await serviceA.initialize();
      await serviceB.initialize();
    });

    tearDown(() {
      serviceA.dispose();
      serviceB.dispose();
    });

    test('services work together correctly', () async {
      // Arrange
      final data = TestData();

      // Act
      await serviceA.processData(data);
      final result = await serviceB.getData();

      // Assert
      expect(result, isNotNull);
      expect(result.isValid, isTrue);
    });
  });
}
```

## Audio-Transcription Integration

### Testing Audio Flow

```dart
group('Audio-Transcription Integration', () {
  late AudioService audioService;
  late TranscriptionService transcriptionService;

  setUp(() async {
    audioService = AudioService();
    transcriptionService = NativeTranscriptionService.instance;

    await audioService.initialize();
    await transcriptionService.initialize();
  });

  test('audio data flows to transcription service', () async {
    // Create stream subscription
    final segments = <TranscriptionSegment>[];
    final subscription = transcriptionService.transcriptStream
        .listen(segments.add);

    // Start services
    await audioService.startRecording();
    await transcriptionService.start();

    // Simulate audio data
    audioService.simulateAudioData(testAudioData);

    // Wait for processing
    await Future.delayed(Duration(seconds: 2));

    // Stop services
    await transcriptionService.stop();
    await audioService.stopRecording();

    // Verify transcription received data
    expect(segments, isNotEmpty);

    await subscription.cancel();
  });
});
```

## AI Services Integration

### Testing AI Analysis Pipeline

```dart
group('AI Analysis Pipeline', () {
  late TranscriptionService transcriptionService;
  late AICoordinator aiCoordinator;

  setUp(() {
    transcriptionService = NativeTranscriptionService.instance;
    aiCoordinator = AICoordinator.instance;

    aiCoordinator.configure(
      enabled: true,
      sentiment: true,
      factCheck: true,
      claimDetection: true,
    );
  });

  test('transcription triggers AI analysis', () async {
    // Mock API responses
    final mockProvider = MockAIProvider();
    when(mockProvider.analyze(any))
        .thenAnswer((_) async => TestAIResponse());

    // Start transcription
    await transcriptionService.initialize();

    // Create analysis expectation
    final analyses = <Map<String, dynamic>>[];

    // Simulate transcription
    final testSegment = TranscriptionSegment(
      text: 'Test statement about facts',
      confidence: 0.95,
      timestamp: DateTime.now(),
      isFinal: true,
    );

    // Trigger AI analysis
    final result = await aiCoordinator.analyzeText(testSegment.text);

    // Verify analysis
    expect(result, isNotNull);
    expect(result.containsKey('sentiment'), isTrue);
    expect(result.containsKey('factCheck'), isTrue);
  });
});
```

## Multi-Service Integration

### Testing Complete Workflows

```dart
group('Complete Recording Workflow', () {
  late AudioService audioService;
  late TranscriptionService transcriptionService;
  late AICoordinator aiCoordinator;
  late ConversationInsights insights;

  setUp(() async {
    // Initialize all services
    audioService = AudioService();
    transcriptionService = NativeTranscriptionService.instance;
    aiCoordinator = AICoordinator.instance;
    insights = ConversationInsights();

    await audioService.initialize();
    await transcriptionService.initialize();

    aiCoordinator.configure(enabled: true, sentiment: true);
  });

  tearDown(() {
    audioService.dispose();
    transcriptionService.dispose();
    aiCoordinator.dispose();
    insights.dispose();
  });

  test('complete workflow from recording to insights', () async {
    // 1. Start recording
    await audioService.startRecording();
    await transcriptionService.start();

    // 2. Simulate audio data
    for (int i = 0; i < 5; i++) {
      audioService.simulateChunk(testAudioChunk);
      await Future.delayed(Duration(milliseconds: 100));
    }

    // 3. Stop recording
    await transcriptionService.stop();
    await audioService.stopRecording();

    // 4. Get transcription
    final stats = transcriptionService.getStats();
    expect(stats.segmentCount, greaterThan(0));

    // 5. Analyze with AI
    final segments = await transcriptionService.getSegments();
    final fullText = segments.map((s) => s.text).join(' ');
    final analysis = await aiCoordinator.analyzeText(fullText);

    // 6. Generate insights
    final conversationInsights = insights.generate(segments, analysis);

    // 7. Verify complete workflow
    expect(stats.segmentCount, greaterThan(0));
    expect(analysis, isNotNull);
    expect(conversationInsights, isNotNull);
    expect(conversationInsights.summary, isNotEmpty);
  });
});
```

## State Management Integration

### Testing State Propagation

```dart
group('State Management Integration', () {
  testWidgets('state updates propagate through app', (tester) async {
    await pumpWidgetWithProviders(
      tester,
      MyApp(),
    );

    // Verify initial state
    expect(find.text('Not Recording'), findsOneWidget);

    // Trigger state change
    await tester.tap(find.byIcon(Icons.mic));
    await tester.pumpAndSettle();

    // Verify state propagated to UI
    expect(find.text('Recording'), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);

    // Trigger another state change
    await tester.tap(find.byIcon(Icons.stop));
    await tester.pumpAndSettle();

    // Verify final state
    expect(find.text('Not Recording'), findsOneWidget);
  });
});
```

## Database Integration

### Testing Persistence

```dart
group('Data Persistence Integration', () {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('settings persist across sessions', () async {
    final settingsService = SettingsService(prefs);

    // Save settings
    await settingsService.setSetting('ai_enabled', true);
    await settingsService.setSetting('transcription_mode', 'native');

    // Simulate app restart
    final newService = SettingsService(prefs);

    // Verify settings persisted
    expect(await newService.getSetting('ai_enabled'), isTrue);
    expect(
      await newService.getSetting('transcription_mode'),
      equals('native'),
    );
  });
});
```

## Network Integration

### Testing API Integration

```dart
group('API Integration', () {
  late Dio httpClient;
  late ApiService apiService;

  setUp(() {
    httpClient = Dio();
    apiService = ApiService(httpClient);
  });

  test('API request and response flow', () async {
    // Note: Use mock server for integration tests
    final mockServer = MockWebServer();
    mockServer.enqueue(MockResponse()
      ..statusCode = 200
      ..body = jsonEncode({'result': 'success'}));

    final response = await apiService.sendRequest(
      endpoint: '/analyze',
      data: {'text': 'test'},
    );

    expect(response.statusCode, equals(200));
    expect(response.data['result'], equals('success'));

    mockServer.shutdown();
  });
});
```

## Performance Integration Tests

### Measuring Integration Performance

```dart
group('Performance Integration', () {
  test('transcription pipeline meets performance requirements', () async {
    final stopwatch = Stopwatch()..start();

    // Initialize services
    final audio = AudioService();
    final transcription = NativeTranscriptionService.instance;

    await audio.initialize();
    await transcription.initialize();

    // Perform operations
    await audio.startRecording();
    await transcription.start();

    // Simulate data processing
    for (int i = 0; i < 100; i++) {
      audio.simulateChunk(testAudioChunk);
    }

    await transcription.stop();
    await audio.stopRecording();

    stopwatch.stop();

    // Verify performance
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(5000), // Should complete in under 5 seconds
    );
  });
});
```

## Best Practices

### 1. Test Realistic Scenarios

```dart
test('handles real-world audio quality variations', () async {
  final testCases = [
    AudioChunkFactory.createNoise(bytes: 1024), // Noisy audio
    AudioChunkFactory.createSilence(bytes: 1024), // Silence
    AudioChunkFactory.create(sampleRate: 8000), // Low quality
    AudioChunkFactory.create(sampleRate: 44100), // High quality
  ];

  for (final audioData in testCases) {
    final result = await transcriptionService.process(audioData);
    expect(result, isNotNull);
  }
});
```

### 2. Handle Async Properly

```dart
test('handles concurrent operations correctly', () async {
  // Start multiple operations
  final futures = [
    service1.operation1(),
    service2.operation2(),
    service3.operation3(),
  ];

  // Wait for all to complete
  final results = await Future.wait(futures);

  // Verify all succeeded
  expect(results.every((r) => r.isSuccess), isTrue);
});
```

### 3. Clean Up Resources

```dart
tearDown(() async {
  // Close streams
  await streamSubscription?.cancel();

  // Dispose services
  audioService.dispose();
  transcriptionService.dispose();

  // Clear caches
  cache.clear();

  // Close databases
  await database.close();
});
```

### 4. Use Appropriate Timeouts

```dart
test('service responds within acceptable time', () async {
  final result = await service.fetchData().timeout(
    Duration(seconds: 5),
    onTimeout: () => throw TimeoutException('Service too slow'),
  );

  expect(result, isNotNull);
});
```

## Running Integration Tests

### Local Development

```bash
# Run all integration tests
flutter test integration_test

# Run specific integration test
flutter test integration_test/audio_transcription_integration_test.dart

# Run with verbose output
flutter test integration_test --verbose
```

### On Device

```bash
# Run on iOS device
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_integration_test.dart \
  -d <device-id>
```

### CI/CD

Integration tests run automatically in CI/CD pipeline on:
- Pull requests
- Merges to main
- Before releases

## Troubleshooting

### Tests Timeout

- Increase timeout values
- Check for deadlocks
- Verify all async operations complete
- Add logging to identify bottlenecks

### Flaky Tests

- Add explicit waits
- Ensure proper initialization
- Check for race conditions
- Verify cleanup is complete

### Resource Leaks

- Monitor memory usage
- Verify all streams are closed
- Check all subscriptions are cancelled
- Ensure dispose() is called

## Additional Resources

- [Main Testing Guide](./TESTING_GUIDE.md)
- [E2E Testing Guide](../../integration_test/e2e/README.md)
- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
