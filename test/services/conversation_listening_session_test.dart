import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/conversation_listening_session.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationListeningSession', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'transcriptionBackend': 'appleCloud',
      });
      await SettingsManager.instance.initialize();
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
      engine.autoDetectQuestions = false;
    });

    tearDown(() {
      engine.autoDetectQuestions = true;
      engine.stop();
    });

    test(
      'partial updates appear immediately and stop finalizes pending text',
      () async {
        final speechEvents = StreamController<dynamic>.broadcast();
        final methodCalls = <(String, Object?)>[];
        final session = ConversationListeningSession.test(
          speechEvents: speechEvents.stream,
          engine: engine,
          finalizationTimeout: const Duration(milliseconds: 10),
          invokeMethod: (method, [arguments]) async {
            methodCalls.add((method, arguments));
            return null;
          },
        );

        final snapshots = <TranscriptSnapshot>[];
        final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

        await session.startSession(source: TranscriptSource.phone);
        speechEvents.add({'script': 'Hello from the phone', 'isFinal': false});
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(snapshots.last.source, TranscriptSource.phone);
        expect(snapshots.last.partialText, 'Hello from the phone');
        expect(snapshots.last.finalizedSegments, isEmpty);

        await session.stopSession();

        expect(engine.currentTranscriptSnapshot.partialText, '');
        expect(engine.currentTranscriptSnapshot.finalizedSegments, [
          'Hello from the phone',
        ]);
        expect(methodCalls.length, 2);
        expect(methodCalls.first.$1, 'startEvenAI');
        expect(methodCalls.first.$2, isA<Map>());
        final startArgs = methodCalls.first.$2! as Map;
        expect(startArgs['language'], 'EN');
        expect(startArgs['source'], 'microphone');
        expect(methodCalls.last.$1, 'stopEvenAI');

        await sub.cancel();
        await speechEvents.close();
      },
    );

    test(
      'stream errors finalize the latest transcript and keep glasses source',
      () async {
        final speechEvents = StreamController<dynamic>.broadcast();
        final session = ConversationListeningSession.test(
          speechEvents: speechEvents.stream,
          engine: engine,
          finalizationTimeout: const Duration(milliseconds: 10),
          invokeMethod: (method, [arguments]) async => null,
        );

        await session.startSession(source: TranscriptSource.glasses);
        speechEvents.add({
          'script': 'What should I say next?',
          'isFinal': false,
        });
        await Future<void>.delayed(const Duration(milliseconds: 5));
        speechEvents.addError(Exception('speech failure'));
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(
          engine.currentTranscriptSnapshot.source,
          TranscriptSource.glasses,
        );
        expect(engine.currentTranscriptSnapshot.finalizedSegments, [
          'What should I say next?',
        ]);

        await session.stopSession();
        expect(engine.currentTranscriptSnapshot.finalizedSegments, [
          'What should I say next?',
        ]);

        await speechEvents.close();
      },
    );

    test(
      'stop waits for the latest utterance after an earlier segment finalized',
      () async {
        final speechEvents = StreamController<dynamic>.broadcast();
        final session = ConversationListeningSession.test(
          speechEvents: speechEvents.stream,
          engine: engine,
          finalizationTimeout: const Duration(milliseconds: 10),
          invokeMethod: (method, [arguments]) async => null,
        );

        await session.startSession(source: TranscriptSource.phone);
        speechEvents.add({'script': 'First sentence', 'isFinal': true});
        await Future<void>.delayed(const Duration(milliseconds: 5));
        speechEvents.add({'script': 'Second sentence', 'isFinal': false});
        await Future<void>.delayed(const Duration(milliseconds: 5));

        await session.stopSession();

        expect(engine.currentTranscriptSnapshot.partialText, '');
        expect(engine.currentTranscriptSnapshot.finalizedSegments, [
          'First sentence',
          'Second sentence',
        ]);

        await speechEvents.close();
      },
    );

    test('start failures publish an error and stop the engine', () async {
      final speechEvents = StreamController<dynamic>.broadcast();
      final session = ConversationListeningSession.test(
        speechEvents: speechEvents.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async {
          if (method == 'startEvenAI') {
            throw PlatformException(
              code: 'SpeechStartFailed',
              message: 'Not permitted to record audio',
            );
          }
          return null;
        },
      );

      final errorFuture = session.errorStream
          .where((message) => message != null)
          .cast<String>()
          .first;

      await expectLater(
        () => session.startSession(source: TranscriptSource.phone),
        throwsA(isA<PlatformException>()),
      );

      expect(
        await errorFuture.timeout(const Duration(milliseconds: 50)),
        'Not permitted to record audio',
      );
      expect(session.currentError, 'Not permitted to record audio');
      expect(engine.isActive, isFalse);
      expect(session.isRunning, isFalse);

      await speechEvents.close();
    });
  });
}
