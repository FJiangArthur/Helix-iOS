import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/analysis_backend.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ---------- BatchAnalysisResult.fromJson ----------

  group('BatchAnalysisResult.fromJson', () {
    test('parses valid JSON with facts, relationships, profileUpdates, topics',
        () {
      const raw = '''
{
  "facts": [
    {
      "category": "preference",
      "content": "Prefers dark mode",
      "sourceQuote": "I always use dark mode",
      "confidence": 0.9
    }
  ],
  "relationships": [
    {
      "entityA": "Alice",
      "entityB": "Acme Corp",
      "type": "works_at",
      "description": "Senior engineer"
    }
  ],
  "profileUpdates": {
    "preferredTheme": "dark"
  },
  "topics": ["UI preferences", "workplace"]
}
''';

      final result = BatchAnalysisResult.fromJson(raw);

      expect(result.facts, hasLength(1));
      expect(result.facts.first.category, 'preference');
      expect(result.facts.first.content, 'Prefers dark mode');
      expect(result.facts.first.sourceQuote, 'I always use dark mode');
      expect(result.facts.first.confidence, 0.9);

      expect(result.relationships, hasLength(1));
      expect(result.relationships.first.entityA, 'Alice');
      expect(result.relationships.first.entityB, 'Acme Corp');
      expect(result.relationships.first.type, 'works_at');
      expect(result.relationships.first.description, 'Senior engineer');

      expect(result.profileUpdates, {'preferredTheme': 'dark'});
      expect(result.topics, ['UI preferences', 'workplace']);
    });

    test('handles malformed JSON gracefully (returns empty result)', () {
      final result = BatchAnalysisResult.fromJson('not valid json {{{');

      expect(result.facts, isEmpty);
      expect(result.relationships, isEmpty);
      expect(result.profileUpdates, isEmpty);
      expect(result.topics, isEmpty);
    });

    test('strips markdown code fences', () {
      const raw = '''
```json
{
  "facts": [
    {"category": "goal", "content": "Learn Rust", "confidence": 0.8}
  ],
  "relationships": [],
  "profileUpdates": {},
  "topics": ["programming"]
}
```
''';

      final result = BatchAnalysisResult.fromJson(raw);

      expect(result.facts, hasLength(1));
      expect(result.facts.first.category, 'goal');
      expect(result.facts.first.content, 'Learn Rust');
      expect(result.topics, ['programming']);
    });
  });

  // ---------- CloudAnalysisProvider ----------

  group('CloudAnalysisProvider', () {
    late FakeJsonProvider fakeProvider;

    setUp(() async {
      installPlatformMocks();
      await initTestSettings();
    });

    tearDown(() {
      removePlatformMocks();
    });

    test('analyze sends segments to LLM and parses result', () async {
      final responseJson = '''
{
  "facts": [
    {"category": "biographical", "content": "Lives in SF", "confidence": 0.95}
  ],
  "relationships": [],
  "profileUpdates": {"city": "San Francisco"},
  "topics": ["location"]
}
''';
      fakeProvider =
          await configureFakeLlm(responses: [responseJson]);

      final provider = CloudAnalysisProvider();
      final segments = [
        TranscriptSegment(
          text: 'I moved to San Francisco last year.',
          timestamp: DateTime(2026, 3, 1),
          speakerLabel: 'me',
        ),
      ];

      final result = await provider.analyze(
        segments: segments,
        userProfileJson: '{"name": "Test User"}',
      );

      expect(result.facts, hasLength(1));
      expect(result.facts.first.content, 'Lives in SF');
      expect(result.profileUpdates['city'], 'San Francisco');
      expect(result.topics, ['location']);

      // Verify LLM was called
      expect(fakeProvider.getResponseCallCount, 1);
      expect(fakeProvider.capturedSystemPrompts.first,
          contains('knowledge extraction engine'));
      expect(fakeProvider.capturedMessages.first.first.content,
          contains('San Francisco'));
    });

    test('isAvailable returns true when provider is registered', () async {
      await configureFakeLlm();

      final provider = CloudAnalysisProvider();
      expect(provider.isAvailable, isTrue);
    });

    test('empty segments list returns empty result without calling LLM',
        () async {
      fakeProvider = await configureFakeLlm(responses: ['should not be used']);

      final provider = CloudAnalysisProvider();
      final result = await provider.analyze(
        segments: [],
        userProfileJson: '{}',
      );

      expect(result.facts, isEmpty);
      expect(result.relationships, isEmpty);
      expect(result.topics, isEmpty);
      expect(fakeProvider.getResponseCallCount, 0);
    });
  });
}
