// ABOUTME: Test utilities and helpers for consistent test setup
// ABOUTME: Provides mock data, widget wrappers, and common test patterns

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';

import 'package:flutter_helix/services/audio_service.dart';
import 'package:flutter_helix/services/transcription_service.dart';
import 'package:flutter_helix/services/llm_service.dart';
import 'package:flutter_helix/services/glasses_service.dart';
import 'package:flutter_helix/services/settings_service.dart';
import 'package:flutter_helix/models/transcription_segment.dart';
import 'package:flutter_helix/models/analysis_result.dart';
import 'package:flutter_helix/core/utils/logging_service.dart';

import 'test_helpers.mocks.dart';

// Generate mocks for all services
@GenerateMocks([
  AudioService,
  TranscriptionService,
  LLMService,
  GlassesService,
  SettingsService,
  LoggingService,
])
void main() {}

/// Test utilities and data factories for Helix tests
class TestHelpers {
  /// Creates a MaterialApp wrapper with mock providers for widget testing
  static Widget createTestApp({
    Widget? child,
    List<Widget> children = const [],
    MockAudioService? audioService,
    MockTranscriptionService? transcriptionService,
    MockLLMService? llmService,
    MockGlassesService? glassesService,
    MockSettingsService? settingsService,
  }) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          Provider<AudioService>(
            create: (_) => audioService ?? MockAudioService(),
          ),
          Provider<TranscriptionService>(
            create: (_) => transcriptionService ?? MockTranscriptionService(),
          ),
          Provider<LLMService>(
            create: (_) => llmService ?? MockLLMService(),
          ),
          Provider<GlassesService>(
            create: (_) => glassesService ?? MockGlassesService(),
          ),
          Provider<SettingsService>(
            create: (_) => settingsService ?? MockSettingsService(),
          ),
        ],
        child: child ?? Scaffold(
          body: Column(children: children),
        ),
      ),
    );
  }

  /// Creates a test TranscriptionSegment with default values
  static TranscriptionSegment createTestSegment({
    String? speaker,
    String? text,
    DateTime? timestamp,
    double? confidence,
  }) {
    return TranscriptionSegment(
      speaker: speaker ?? 'Test Speaker',
      text: text ?? 'This is a test transcription segment',
      timestamp: timestamp ?? DateTime.now(),
      confidence: confidence ?? 0.95,
    );
  }

  /// Creates a test AnalysisResult with default values
  static AnalysisResult createTestAnalysisResult({
    String? summary,
    List<FactCheckResult>? factChecks,
    List<ActionItemResult>? actionItems,
    SentimentAnalysisResult? sentiment,
    double? confidence,
  }) {
    return AnalysisResult(
      summary: summary ?? 'Test analysis summary',
      keyPoints: ['Key point 1', 'Key point 2'],
      decisions: ['Decision 1'],
      questions: ['Question 1'],
      topics: ['Test Topic'],
      factChecks: factChecks ?? [createTestFactCheck()],
      actionItems: actionItems ?? [createTestActionItem()],
      sentiment: sentiment ?? createTestSentiment(),
      confidence: confidence ?? 0.88,
    );
  }

  /// Creates a test FactCheckResult
  static FactCheckResult createTestFactCheck({
    String? claim,
    FactCheckStatus? status,
    double? confidence,
    List<String>? sources,
    String? explanation,
  }) {
    return FactCheckResult(
      claim: claim ?? 'Test claim to be fact-checked',
      status: status ?? FactCheckStatus.verified,
      confidence: confidence ?? 0.92,
      sources: sources ?? ['Test Source 1', 'Test Source 2'],
      explanation: explanation ?? 'This claim has been verified by multiple sources.',
    );
  }

  /// Creates a test ActionItemResult
  static ActionItemResult createTestActionItem({
    String? id,
    String? description,
    String? assignee,
    DateTime? dueDate,
    ActionItemPriority? priority,
    double? confidence,
    ActionItemStatus? status,
  }) {
    return ActionItemResult(
      id: id ?? 'test-action-1',
      description: description ?? 'Test action item description',
      assignee: assignee,
      dueDate: dueDate,
      priority: priority ?? ActionItemPriority.medium,
      confidence: confidence ?? 0.87,
      status: status ?? ActionItemStatus.pending,
    );
  }

  /// Creates a test SentimentAnalysisResult
  static SentimentAnalysisResult createTestSentiment({
    SentimentType? overallSentiment,
    double? confidence,
    Map<String, double>? emotions,
  }) {
    return SentimentAnalysisResult(
      overallSentiment: overallSentiment ?? SentimentType.positive,
      confidence: confidence ?? 0.84,
      emotions: emotions ?? {
        'happiness': 0.7,
        'excitement': 0.6,
        'curiosity': 0.8,
        'concern': 0.2,
      },
    );
  }

  /// Creates test audio data for testing
  static List<int> createTestAudioData({
    int durationSeconds = 5,
    int sampleRate = 16000,
  }) {
    final totalSamples = durationSeconds * sampleRate;
    return List.generate(totalSamples, (index) {
      // Generate simple sine wave for testing
      final frequency = 440; // A4 note
      final amplitude = 32767; // 16-bit max
      final value = (amplitude * 0.5 * 
          (1 + (index * frequency * 2 * 3.14159 / sampleRate).sin())).round();
      return value;
    });
  }

  /// Waits for widget animations to complete
  static Future<void> pumpAndSettle(WidgetTester tester, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await tester.pumpAndSettle(timeout);
  }

  /// Finds widget by its semantic label
  static Finder findBySemantic(String label) {
    return find.bySemanticsLabel(label);
  }

  /// Verifies that a widget exists and is visible
  static void expectWidgetVisible(Finder finder) {
    expect(finder, findsOneWidget);
    expect(tester.widget(finder), isA<Widget>());
  }

  /// Common test timeout duration
  static const testTimeout = Duration(seconds: 30);

  /// Audio levels for testing various scenarios
  static const double lowAudioLevel = 0.1;
  static const double mediumAudioLevel = 0.5;
  static const double highAudioLevel = 0.9;

  /// Test API keys for different providers
  static const String testOpenAIKey = 'sk-test-openai-key-1234567890';
  static const String testAnthropicKey = 'sk-ant-test-anthropic-key-1234567890';

  /// Test device information for Bluetooth testing
  static const String testGlassesDeviceId = 'test-glasses-device-001';
  static const String testGlassesDeviceName = 'Test Even Realities G1';
  static const int testGlassesRSSI = -45;
  static const double testGlassesBattery = 0.85;
}

/// Extension methods for common test operations
extension WidgetTesterExtensions on WidgetTester {
  /// Enters text into a TextField by its key
  Future<void> enterTextByKey(String key, String text) async {
    await enterText(find.byKey(ValueKey(key)), text);
    await pump();
  }

  /// Taps a widget by its key
  Future<void> tapByKey(String key) async {
    await tap(find.byKey(ValueKey(key)));
    await pump();
  }

  /// Taps a widget by its text
  Future<void> tapByText(String text) async {
    await tap(find.text(text));
    await pump();
  }

  /// Verifies a text widget exists
  void expectText(String text) {
    expect(find.text(text), findsOneWidget);
  }

  /// Verifies a widget by key exists
  void expectWidgetByKey(String key) {
    expect(find.byKey(ValueKey(key)), findsOneWidget);
  }

  /// Scrolls until a widget is visible
  Future<void> scrollUntilVisible(
    Finder finder,
    Finder scrollable, {
    double delta = 100.0,
  }) async {
    await scrollUntilVisible(finder, scrollable, scrollDelta: delta);
  }
}

/// Mock data constants for consistent testing
class TestData {
  static const List<String> sampleSpeakers = [
    'Alice Johnson',
    'Bob Smith', 
    'Carol Davis',
    'David Wilson',
  ];

  static const List<String> sampleTexts = [
    'Hello, welcome to our meeting today.',
    'I think we should focus on the quarterly results.',
    'The new product launch is scheduled for next month.',
    'We need to review the budget allocation.',
    'Has everyone had a chance to review the documents?',
  ];

  static const List<String> sampleTopics = [
    'Business Meeting',
    'Product Development',
    'Budget Planning',
    'Team Collaboration',
    'Technical Discussion',
  ];

  static const List<String> sampleFactClaims = [
    'The quarterly revenue increased by 15%',
    'Our customer satisfaction score is above 90%',
    'The new feature has been adopted by 75% of users',
    'Market research shows growing demand',
  ];

  static const List<String> sampleActionItems = [
    'Review and approve the budget proposal',
    'Schedule follow-up meeting with stakeholders',
    'Prepare presentation for board meeting',
    'Update project timeline and deliverables',
  ];
}