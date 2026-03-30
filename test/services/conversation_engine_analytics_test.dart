import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/settings_manager.dart';

import '../helpers/test_helpers.dart';
import '../helpers/stream_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConversationEngine engine;
  late FakeJsonProvider provider;
  late StreamRecorder recorder;

  setUpAll(() => installPlatformMocks());
  tearDownAll(() => removePlatformMocks());

  setUp(() async {
    final result = await setupTestEngine();
    engine = result.engine;
    provider = result.provider;
    recorder = StreamRecorder(engine);
  });

  tearDown(() {
    recorder.dispose();
    teardownTestEngine(engine);
  });

  group('B9 - Sentiment analysis triggers every 3rd segment', () {
    test('sentiment emitted after 3 finalized segments', () async {
      SettingsManager.instance.sentimentMonitorEnabled = true;
      engine.autoDetectQuestions = false;
      engine.start();

      // The sentiment analysis calls getResponse, so enqueue the score.
      provider.enqueueResponse('0.7');

      // Finalize 3 segments with delays to allow the _analyticsRunning guard
      // to clear between runs. Each analytics run increments the counter.
      engine.onTranscriptionFinalized('First segment about the project.');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      engine.onTranscriptionFinalized('Second segment discussing timelines.');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      engine.onTranscriptionFinalized('Third segment wrapping up the review.');
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(recorder.sentiments, isNotEmpty);
      expect(recorder.sentiments.first, closeTo(0.7, 0.01));
    });

    test('sentiment does NOT trigger after only 2 segments', () async {
      SettingsManager.instance.sentimentMonitorEnabled = true;
      engine.autoDetectQuestions = false;
      engine.start();

      provider.enqueueResponse('0.5');

      // Finalize only 2 segments — counter won't be divisible by 3
      engine.onTranscriptionFinalized('First segment about the project.');
      engine.onTranscriptionFinalized('Second segment discussing timelines.');

      // Wait briefly and verify no sentiment was emitted
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(recorder.sentiments, isEmpty);
    });
  });

  group('B10 - Entity extraction triggers every 2nd segment', () {
    test('entity emitted after 2 finalized segments', () async {
      SettingsManager.instance.entityMemoryEnabled = true;
      SettingsManager.instance.sentimentMonitorEnabled = false;
      engine.autoDetectQuestions = false;
      engine.start();

      // Enqueue entity extraction response
      provider.enqueueResponse(
        '[{"name": "John Smith", "title": "CEO", "company": "Acme"}]',
      );

      // Finalize 2 segments with delay for _analyticsRunning guard
      engine.onTranscriptionFinalized(
        'John Smith joined us for the quarterly review.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      engine.onTranscriptionFinalized(
        'He mentioned Acme is expanding to three new markets.',
      );
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(recorder.entities, isNotEmpty);
      expect(recorder.entities.first.name, 'John Smith');
    });

    test('entity does NOT trigger after only 1 segment', () async {
      SettingsManager.instance.entityMemoryEnabled = true;
      SettingsManager.instance.sentimentMonitorEnabled = false;
      engine.autoDetectQuestions = false;
      engine.start();

      provider.enqueueResponse(
        '[{"name": "Jane Doe", "title": "CTO", "company": "Beta"}]',
      );

      // Only 1 segment — counter won't be divisible by 2
      engine.onTranscriptionFinalized('Jane Doe presented the roadmap.');

      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(recorder.entities, isEmpty);
    });
  });

  group('E8 - Sentiment returns unparseable text', () {
    test('no crash and no emission on unparseable sentiment', () async {
      SettingsManager.instance.sentimentMonitorEnabled = true;
      engine.autoDetectQuestions = false;
      engine.start();

      // Return text that cannot be parsed as a valid sentiment score
      provider.enqueueResponse('The sentiment seems neutral overall');

      engine.onTranscriptionFinalized('First segment about the weather.');
      engine.onTranscriptionFinalized('Second segment about lunch plans.');
      engine.onTranscriptionFinalized('Third segment about the weekend.');

      // Wait for background analytics to complete
      await Future<void>.delayed(const Duration(seconds: 1));

      // The engine should not crash and should not emit anything
      expect(recorder.sentiments, isEmpty);
    });

    test('no crash on empty response from LLM', () async {
      SettingsManager.instance.sentimentMonitorEnabled = true;
      engine.autoDetectQuestions = false;
      engine.start();

      provider.enqueueResponse('');

      engine.onTranscriptionFinalized('Alpha segment.');
      engine.onTranscriptionFinalized('Beta segment.');
      engine.onTranscriptionFinalized('Gamma segment.');

      await Future<void>.delayed(const Duration(seconds: 1));

      expect(recorder.sentiments, isEmpty);
    });
  });

  group('E9 - Entity extraction returns empty array', () {
    test('no emission when entity extraction returns empty array', () async {
      SettingsManager.instance.entityMemoryEnabled = true;
      SettingsManager.instance.sentimentMonitorEnabled = false;
      engine.autoDetectQuestions = false;
      engine.start();

      provider.enqueueResponse('[]');

      engine.onTranscriptionFinalized('We talked about the budget.');
      engine.onTranscriptionFinalized('No specific people were mentioned.');

      await Future<void>.delayed(const Duration(seconds: 1));

      expect(recorder.entities, isEmpty);
    });

    test('no emission when response has no valid names', () async {
      SettingsManager.instance.entityMemoryEnabled = true;
      SettingsManager.instance.sentimentMonitorEnabled = false;
      engine.autoDetectQuestions = false;
      engine.start();

      // Entities with empty names should be filtered out
      provider.enqueueResponse(
        '[{"name": "", "title": "Manager", "company": "Corp"}]',
      );

      engine.onTranscriptionFinalized('Someone mentioned a manager.');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      engine.onTranscriptionFinalized('But we did not catch the name.');

      await Future<void>.delayed(const Duration(seconds: 1));

      expect(recorder.entities, isEmpty);
    });
  });

  group('Analytics counters reset on start', () {
    test('counters reset when engine restarts', () async {
      SettingsManager.instance.sentimentMonitorEnabled = true;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.autoDetectQuestions = false;

      // First session: finalize 2 segments (counter at 2, not yet at 3)
      engine.start();
      engine.onTranscriptionFinalized('Segment one.');
      engine.onTranscriptionFinalized('Segment two.');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      engine.stop();

      // Second session: counter should reset, so need 3 fresh segments
      provider.enqueueResponse('-0.3');
      engine.start();
      recorder.clear();

      engine.onTranscriptionFinalized('Fresh segment one.');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      engine.onTranscriptionFinalized('Fresh segment two.');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      engine.onTranscriptionFinalized('Fresh segment three.');
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(recorder.sentiments, isNotEmpty);
      expect(recorder.sentiments.first, closeTo(-0.3, 0.01));
    });
  });
}
