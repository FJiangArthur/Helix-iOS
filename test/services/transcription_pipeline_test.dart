import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/conversation_listening_session.dart';

import '../helpers/speech_event_emitter.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConversationEngine engine;
  late FakeJsonProvider provider;

  setUpAll(() {
    installPlatformMocks();
  });

  tearDownAll(() {
    removePlatformMocks();
  });

  setUp(() async {
    final result = await setupTestEngine();
    engine = result.engine;
    provider = result.provider;
    engine.autoDetectQuestions = false;
  });

  tearDown(() {
    teardownTestEngine(engine);
  });

  // ---------------------------------------------------------------------------
  // A2 [P0]: Progressive sentence splitting (partial → final)
  // ---------------------------------------------------------------------------
  group('A2 — progressive sentence splitting', () {
    test('partial updates split sentences and final event finalizes remainder',
        () async {
      final emitter = SpeechEventEmitter();
      final session = ConversationListeningSession.test(
        speechEvents: emitter.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      final snapshots = <TranscriptSnapshot>[];
      final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

      await session.startSession(source: TranscriptSource.phone);

      // Feed progressive partials that contain sentence boundaries.
      // "First sentence." is complete, "Second sentence." is complete,
      // "Third in progress" is trailing partial.
      emitter.emitPartial('First sentence.');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      emitter.emitPartial('First sentence. Second sentence.');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      emitter.emitPartial(
          'First sentence. Second sentence. Third in progress');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // At this point the engine should have progressively finalized
      // "First sentence." and "Second sentence." while "Third in progress"
      // remains as the partial.
      final preFinalize = snapshots.last;
      expect(preFinalize.finalizedSegments, contains('First sentence.'));
      expect(preFinalize.finalizedSegments, contains('Second sentence.'));
      expect(preFinalize.partialText, 'Third in progress');

      // Now finalize the full text — the trailing partial gets finalized.
      emitter.emitFinal(
          'First sentence. Second sentence. Third in progress');
      await Future<void>.delayed(const Duration(milliseconds: 15));

      final postFinalize = engine.currentTranscriptSnapshot;
      expect(postFinalize.partialText, isEmpty);
      expect(
        postFinalize.finalizedSegments,
        containsAll([
          'First sentence.',
          'Second sentence.',
          'Third in progress',
        ]),
      );
      expect(postFinalize.finalizedSegments.length, 3);

      await session.stopSession();
      await sub.cancel();
      emitter.close();
    });
  });

  // ---------------------------------------------------------------------------
  // A5 [P1]: Speaker diarization labels propagated through segments
  // ---------------------------------------------------------------------------
  group('A5 — speaker diarization labels', () {
    test('speaker labels from events are preserved through finalization',
        () async {
      final emitter = SpeechEventEmitter();
      final session = ConversationListeningSession.test(
        speechEvents: emitter.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      await session.startSession(source: TranscriptSource.phone);

      // Speaker 1 says something, then finalize.
      emitter.emitPartial('Hello from speaker one', speaker: 'Speaker_1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      emitter.emitFinal('Hello from speaker one', speaker: 'Speaker_1');
      await Future<void>.delayed(const Duration(milliseconds: 15));

      // Speaker 2 says something, then finalize.
      emitter.emitPartial('And hello from speaker two', speaker: 'Speaker_2');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      emitter.emitFinal('And hello from speaker two', speaker: 'Speaker_2');
      await Future<void>.delayed(const Duration(milliseconds: 15));

      final snapshot = engine.currentTranscriptSnapshot;

      // Both segments should be finalized with their text preserved.
      expect(snapshot.finalizedSegments, contains('Hello from speaker one'));
      expect(
          snapshot.finalizedSegments, contains('And hello from speaker two'));
      expect(snapshot.finalizedSegments.length, 2);

      // The full transcript should contain both speakers' text.
      expect(snapshot.fullTranscript, contains('Hello from speaker one'));
      expect(
          snapshot.fullTranscript, contains('And hello from speaker two'));

      // Verify the session did not crash and partial is cleared.
      expect(snapshot.partialText, isEmpty);

      await session.stopSession();
      emitter.close();
    });

    test('different speakers in rapid succession do not lose segments',
        () async {
      final emitter = SpeechEventEmitter();
      final session = ConversationListeningSession.test(
        speechEvents: emitter.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      await session.startSession(source: TranscriptSource.phone);
      expect(engine.isActive, isTrue);

      // Simulate three separate speech segments from alternating speakers.
      // Use feedTranscript-style partial-then-final for each segment.
      emitter.emitPartial('Question from interviewer', speaker: 'Speaker_1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      emitter.emitFinal('Question from interviewer', speaker: 'Speaker_1');
      await Future<void>.delayed(const Duration(milliseconds: 25));

      emitter.emitPartial('Answer from candidate', speaker: 'Speaker_2');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      emitter.emitFinal('Answer from candidate', speaker: 'Speaker_2');
      await Future<void>.delayed(const Duration(milliseconds: 25));

      emitter.emitPartial('Follow up question', speaker: 'Speaker_1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      emitter.emitFinal('Follow up question', speaker: 'Speaker_1');
      await Future<void>.delayed(const Duration(milliseconds: 25));

      final snapshot = engine.currentTranscriptSnapshot;
      expect(snapshot.finalizedSegments.length, 3);
      expect(snapshot.finalizedSegments[0], 'Question from interviewer');
      expect(snapshot.finalizedSegments[1], 'Answer from candidate');
      expect(snapshot.finalizedSegments[2], 'Follow up question');

      await session.stopSession();
      emitter.close();
    });
  });

  // ---------------------------------------------------------------------------
  // A_partial_dedup: Partial transcription updates are properly streamed
  // ---------------------------------------------------------------------------
  group('A_partial_dedup — partial transcription streaming', () {
    test('incremental partials are emitted to transcriptionStream', () async {
      final emitter = SpeechEventEmitter();
      final session = ConversationListeningSession.test(
        speechEvents: emitter.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      final partials = <String>[];
      final sub = engine.transcriptionStream.listen(partials.add);

      await session.startSession(source: TranscriptSource.phone);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Emit incrementally growing partials.
      emitter.emitPartial('The');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      emitter.emitPartial('The quick');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      emitter.emitPartial('The quick brown');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      emitter.emitPartial('The quick brown fox');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Each unique partial should have been emitted.
      expect(partials, contains('The'));
      expect(partials, contains('The quick'));
      expect(partials, contains('The quick brown'));
      expect(partials, contains('The quick brown fox'));

      // Finalize.
      emitter.emitFinal('The quick brown fox');
      await Future<void>.delayed(const Duration(milliseconds: 15));

      final snapshot = engine.currentTranscriptSnapshot;
      expect(snapshot.partialText, isEmpty);
      expect(snapshot.finalizedSegments, contains('The quick brown fox'));

      await session.stopSession();
      await sub.cancel();
      emitter.close();
    });

    test('duplicate partials are deduplicated', () async {
      final emitter = SpeechEventEmitter();
      final session = ConversationListeningSession.test(
        speechEvents: emitter.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      final snapshots = <TranscriptSnapshot>[];
      final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

      await session.startSession(source: TranscriptSource.phone);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final baselineCount = snapshots.length;

      // Flood identical partials.
      for (var i = 0; i < 10; i++) {
        emitter.emitPartial('Same text repeated');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Only one new snapshot should appear (dedup filters the rest).
      expect(snapshots.length - baselineCount, 1);
      expect(snapshots.last.partialText, 'Same text repeated');

      await session.stopSession();
      await sub.cancel();
      emitter.close();
    });

    test('feedTranscript helper emits partials then final', () async {
      final emitter = SpeechEventEmitter();
      final session = ConversationListeningSession.test(
        speechEvents: emitter.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      await session.startSession(source: TranscriptSource.phone);

      // Use the feedTranscript helper which emits word-by-word partials
      // followed by a final event.
      await emitter.feedTranscript(
        'Hello world from the emitter',
        partialInterval: const Duration(milliseconds: 10),
        speaker: 'Speaker_1',
      );
      // Allow extra time for finalization timeout to complete.
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final snapshot = engine.currentTranscriptSnapshot;
      expect(snapshot.partialText, isEmpty);
      expect(snapshot.finalizedSegments,
          contains('Hello world from the emitter'));

      await session.stopSession();
      emitter.close();
    });
  });

  // ---------------------------------------------------------------------------
  // A_error: Transcription error event is handled gracefully
  // ---------------------------------------------------------------------------
  group('A_error — transcription error handling', () {
    test('error event does not crash session and engine continues', () async {
      final emitter = SpeechEventEmitter();
      final session = ConversationListeningSession.test(
        speechEvents: emitter.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      await session.startSession(source: TranscriptSource.phone);

      // Send some valid text first.
      emitter.emitPartial('Some valid text before error');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Emit an error event.
      emitter.emitError('Recognition failed: timeout');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Session should still be running.
      expect(session.isRunning, isTrue);

      // Engine should still be active.
      expect(engine.isActive, isTrue);

      // Should be able to continue receiving transcription after error.
      emitter.emitPartial('Text after error');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final snapshot = engine.currentTranscriptSnapshot;
      expect(snapshot.partialText, 'Text after error');

      await session.stopSession();
      emitter.close();
    });

    test('error is published on session error stream', () async {
      final emitter = SpeechEventEmitter();
      final session = ConversationListeningSession.test(
        speechEvents: emitter.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      await session.startSession(source: TranscriptSource.phone);

      // Listen for errors.
      final errorFuture = session.errorStream
          .where((message) => message != null)
          .cast<String>()
          .first;

      emitter.emitError('Network unavailable');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final errorMessage = await errorFuture.timeout(
        const Duration(milliseconds: 100),
      );
      expect(errorMessage, 'Network unavailable');
      expect(session.currentError, 'Network unavailable');

      // Session should still be running despite the error.
      expect(session.isRunning, isTrue);

      await session.stopSession();
      emitter.close();
    });

    test('stream error (not event error) finalizes pending text', () async {
      final speechEvents = StreamController<dynamic>.broadcast();
      final session = ConversationListeningSession.test(
        speechEvents: speechEvents.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      await session.startSession(source: TranscriptSource.phone);

      // Send partial text, then trigger a stream-level error.
      speechEvents.add({'script': 'Pending text before crash', 'isFinal': false});
      await Future<void>.delayed(const Duration(milliseconds: 5));

      speechEvents.addError(Exception('stream died'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // The pending text should have been finalized as a safety net.
      final snapshot = engine.currentTranscriptSnapshot;
      expect(snapshot.finalizedSegments, contains('Pending text before crash'));

      await session.stopSession();
      await speechEvents.close();
    });
  });
}
