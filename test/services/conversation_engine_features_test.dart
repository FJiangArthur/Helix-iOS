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

  group('B6 - Follow-up chips generation after response', () {
    test('follow-up chips emitted after question-answer cycle', () async {
      // Disable analytics to avoid extra LLM calls competing for queue
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.autoDetectQuestions = true;
      engine.answerAll = true;
      engine.start();

      // Queue order for the full detection -> response -> post-analysis pipeline:
      // 1) getResponse: question detection
      // 2) streamWithTools: the AI answer (must be >= 20 chars for post-analysis)
      // 3) getResponse: post-response analysis (chips + factCheck)
      provider.enqueueResponse(
        '{"shouldRespond": true, "question": "What is Flutter used for?", '
        '"questionExcerpt": "What is Flutter used for?", "askedBy": "other"}',
      );
      provider.enqueueStreamResponse(FakeStreamResponse([
        'Flutter is a cross-platform ',
        'UI toolkit by Google for building ',
        'natively compiled applications.',
      ]));
      provider.enqueueResponse(
        '{"chips": ["Tell me more", "Give an example"], "factCheck": null}',
      );

      final chipsFuture = waitForStream<List<String>>(
        engine.followUpChipsStream,
        timeout: const Duration(seconds: 8),
      );

      // Finalize a question segment to kick off detection
      engine.onTranscriptionFinalized(
        'What is Flutter used for?',
      );

      final chips = await chipsFuture;
      expect(chips, hasLength(2));
      expect(chips, contains('Tell me more'));
      expect(chips, contains('Give an example'));
    });
  });

  group('B7 - Post-response analysis with no fact-check', () {
    test('factCheck null does NOT emit to factCheckAlertStream', () async {
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.autoDetectQuestions = true;
      engine.answerAll = true;
      engine.start();

      // Detection -> Answer -> Post-analysis with factCheck: null
      provider.enqueueResponse(
        '{"shouldRespond": true, "question": "When was Dart created?", '
        '"questionExcerpt": "When was Dart created?", "askedBy": "other"}',
      );
      provider.enqueueStreamResponse(FakeStreamResponse([
        'Dart was created by Google ',
        'and first appeared in 2011.',
      ]));
      provider.enqueueResponse(
        '{"chips": ["More details"], "factCheck": null}',
      );

      // Subscribe to factCheckAlertStream before triggering
      final factChecks = <String>[];
      final factCheckSub = engine.factCheckAlertStream.listen(factChecks.add);

      final chipsFuture = waitForStream<List<String>>(
        engine.followUpChipsStream,
        timeout: const Duration(seconds: 8),
      );

      engine.onTranscriptionFinalized('When was Dart created?');

      // Wait for chips to confirm the pipeline completed
      await chipsFuture;

      // Give a moment for any straggler events
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(factChecks, isEmpty);
      await factCheckSub.cancel();
    });

    test('factCheck "null" string does NOT emit alert', () async {
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.autoDetectQuestions = true;
      engine.answerAll = true;
      engine.start();

      provider.enqueueResponse(
        '{"shouldRespond": true, "question": "What color is the sky?", '
        '"questionExcerpt": "What color is the sky?", "askedBy": "other"}',
      );
      provider.enqueueStreamResponse(FakeStreamResponse([
        'The sky appears blue due to ',
        'Rayleigh scattering of sunlight.',
      ]));
      // The LLM might return the literal string "null" instead of JSON null
      provider.enqueueResponse(
        '{"chips": ["Why is it blue?"], "factCheck": "null"}',
      );

      final factChecks = <String>[];
      final factCheckSub = engine.factCheckAlertStream.listen(factChecks.add);

      final chipsFuture = waitForStream<List<String>>(
        engine.followUpChipsStream,
        timeout: const Duration(seconds: 8),
      );

      engine.onTranscriptionFinalized('What color is the sky?');
      await chipsFuture;
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // "null" (lowercase string) is explicitly filtered out
      expect(factChecks, isEmpty);
      await factCheckSub.cancel();
    });
  });

  group('B8 - Fact-check correction emitted', () {
    test('factCheck correction emitted to factCheckAlertStream', () async {
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.autoDetectQuestions = true;
      engine.answerAll = true;
      engine.start();

      // Detection -> Answer -> Post-analysis with a factual correction
      provider.enqueueResponse(
        '{"shouldRespond": true, "question": "When did humans land on the moon?", '
        '"questionExcerpt": "When did humans land on the moon?", "askedBy": "other"}',
      );
      provider.enqueueStreamResponse(FakeStreamResponse([
        'Humans first landed on the moon ',
        'in 1968 during the Apollo mission.',
      ]));
      provider.enqueueResponse(
        '{"chips": [], "factCheck": "The year was actually 1969, not 1968"}',
      );

      final correctionFuture = waitForStream<String>(
        engine.factCheckAlertStream,
        timeout: const Duration(seconds: 8),
      );

      engine.onTranscriptionFinalized(
        'When did humans land on the moon?',
      );

      final correction = await correctionFuture;
      expect(correction, contains('1969'));
      expect(correction, contains('1968'));
    });

    test('factCheck "OK" does NOT emit correction', () async {
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.autoDetectQuestions = true;
      engine.answerAll = true;
      engine.start();

      provider.enqueueResponse(
        '{"shouldRespond": true, "question": "Is water H2O?", '
        '"questionExcerpt": "Is water H2O?", "askedBy": "other"}',
      );
      provider.enqueueStreamResponse(FakeStreamResponse([
        'Yes, water is chemically ',
        'known as H2O or dihydrogen monoxide.',
      ]));
      // "OK" is explicitly filtered out by the engine
      provider.enqueueResponse(
        '{"chips": ["More chemistry facts"], "factCheck": "OK"}',
      );

      final factChecks = <String>[];
      final factCheckSub = engine.factCheckAlertStream.listen(factChecks.add);

      final chipsFuture = waitForStream<List<String>>(
        engine.followUpChipsStream,
        timeout: const Duration(seconds: 8),
      );

      engine.onTranscriptionFinalized('Is water H2O?');
      await chipsFuture;
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(factChecks, isEmpty);
      await factCheckSub.cancel();
    });
  });

  group('Follow-up chips edge cases', () {
    test('empty chips array does NOT emit to followUpChipsStream', () async {
      SettingsManager.instance.sentimentMonitorEnabled = false;
      SettingsManager.instance.entityMemoryEnabled = false;
      engine.autoDetectQuestions = true;
      engine.answerAll = true;
      engine.start();

      provider.enqueueResponse(
        '{"shouldRespond": true, "question": "What is 2+2?", '
        '"questionExcerpt": "What is 2+2?", "askedBy": "other"}',
      );
      provider.enqueueStreamResponse(FakeStreamResponse([
        'The answer to two plus two is four.',
      ]));
      // Empty chips array
      provider.enqueueResponse(
        '{"chips": [], "factCheck": null}',
      );

      final chipEvents = <List<String>>[];
      final chipSub = engine.followUpChipsStream.listen(chipEvents.add);

      engine.onTranscriptionFinalized('What is 2+2?');

      // Wait for the full pipeline to run
      await Future<void>.delayed(const Duration(seconds: 3));

      // Empty chips list should not be emitted
      expect(chipEvents, isEmpty);
      await chipSub.cancel();
    });
  });
}
