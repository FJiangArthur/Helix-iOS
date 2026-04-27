import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/conversation_listening_session.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStorageValues = <String, String>{};

  Future<Object?> secureStorageHandler(MethodCall call) async {
    final arguments = (call.arguments as Map?)?.cast<Object?, Object?>() ?? {};
    final key = arguments['key'] as String?;

    switch (call.method) {
      case 'read':
        return key == null ? null : secureStorageValues[key];
      case 'write':
        final value = arguments['value'] as String?;
        if (key != null && value != null) {
          secureStorageValues[key] = value;
        }
        return null;
      case 'delete':
        if (key != null) {
          secureStorageValues.remove(key);
        }
        return null;
      case 'deleteAll':
        secureStorageValues.clear();
        return null;
      case 'containsKey':
        return key != null && secureStorageValues.containsKey(key);
      case 'readAll':
        return Map<String, String>.from(secureStorageValues);
      default:
        return null;
    }
  }

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, secureStorageHandler);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  group('ConversationListeningSession', () {
    late ConversationEngine engine;

    setUp(() async {
      secureStorageValues.clear();
      SharedPreferences.setMockInitialValues({
        'transcriptionBackend': 'appleCloud',
      });
      await SettingsManager.instance.initialize();
      SettingsManager.instance.transcriptionBackend = 'appleCloud';
      SettingsManager.instance.transcriptionModel = 'gpt-4o-mini-transcribe';
      engine = ConversationEngine.instance;
      engine.stop();
      engine.clearHistory(force: true);
      engine.autoDetectQuestions = false;
    });

    tearDown(() {
      engine.autoDetectQuestions = true;
      engine.stop();
      engine.clearHistory(force: true);
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

    test(
      'openai realtime session start forwards stored key and prompt settings',
      () async {
        final speechEvents = StreamController<dynamic>.broadcast();
        final methodCalls = <(String, Object?)>[];

        SettingsManager.instance.transcriptionBackend = 'openai';
        SettingsManager.instance.openAISessionMode = 'realtime';
        SettingsManager.instance.transcriptionModel = 'gpt-4o-mini-transcribe';
        SettingsManager.instance.openAIRealtimePrompt =
            'Answer only questions.';
        SettingsManager.instance.noiseReduction = false;
        SettingsManager.instance.vadSensitivity = 0.7;
        await SettingsManager.instance.setApiKey('openai', 'sk-live-test');

        final session = ConversationListeningSession.test(
          speechEvents: speechEvents.stream,
          engine: engine,
          finalizationTimeout: const Duration(milliseconds: 10),
          invokeMethod: (method, [arguments]) async {
            methodCalls.add((method, arguments));
            return null;
          },
        );

        await session.startSession(source: TranscriptSource.phone);

        expect(methodCalls.single.$1, 'startEvenAI');
        final startArgs = Map<String, dynamic>.from(
          methodCalls.single.$2! as Map,
        );
        expect(startArgs['backend'], 'openai');
        expect(startArgs['sessionMode'], 'realtime');
        expect(startArgs['source'], 'microphone');
        expect(startArgs['apiKey'], 'sk-live-test');
        expect(startArgs['model'], 'gpt-4o-mini-transcribe');
        expect(startArgs['noiseReduction'], isFalse);
        expect(startArgs['vadSensitivity'], 0.7);
        final prompt = startArgs['systemPrompt'] as String;
        expect(prompt, contains('Answer only questions.'));
        expect(prompt, contains('§Q§'));
        expect(prompt, contains('§A§'));
        expect(prompt, contains('§END§'));

        await session.stopSession();
        await speechEvents.close();
      },
    );

    test('openai batch transport forwards native chunk duration key', () async {
      final speechEvents = StreamController<dynamic>.broadcast();
      final methodCalls = <(String, Object?)>[];

      SettingsManager.instance.transcriptionBackend = 'openai';
      SettingsManager.instance.openAISessionMode = 'transcription';
      SettingsManager.instance.transcriptionTransport = '48kHz Batch Proc';
      SettingsManager.instance.transcriptionModel = 'gpt-4o-mini-transcribe';
      SettingsManager.instance.whisperChunkDurationSec = 3;
      SettingsManager.instance.noiseReduction = true;
      await SettingsManager.instance.setApiKey('openai', 'sk-live-test');

      final session = ConversationListeningSession.test(
        speechEvents: speechEvents.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async {
          methodCalls.add((method, arguments));
          return null;
        },
      );

      await session.startSession(source: TranscriptSource.phone);

      final startArgs = Map<String, dynamic>.from(
        methodCalls.single.$2! as Map,
      );
      expect(startArgs['backend'], 'whisper');
      expect(startArgs['chunkDurationSec'], 3.0);
      expect(startArgs.containsKey('whisperChunkDurationSec'), isFalse);
      expect(startArgs['noiseReduction'], isTrue);

      await session.stopSession();
      await speechEvents.close();
    });

    test(
      'openai realtime session wraps default engine prompt with delimited contract',
      () async {
        final speechEvents = StreamController<dynamic>.broadcast();
        final methodCalls = <(String, Object?)>[];

        SettingsManager.instance.transcriptionBackend = 'openai';
        SettingsManager.instance.openAISessionMode = 'realtime';
        SettingsManager.instance.transcriptionModel = 'gpt-4o-mini-transcribe';
        SettingsManager.instance.openAIRealtimePrompt = null;
        await SettingsManager.instance.setApiKey('openai', 'sk-live-test');

        final session = ConversationListeningSession.test(
          speechEvents: speechEvents.stream,
          engine: engine,
          finalizationTimeout: const Duration(milliseconds: 10),
          invokeMethod: (method, [arguments]) async {
            methodCalls.add((method, arguments));
            return null;
          },
        );

        await session.startSession(source: TranscriptSource.phone);

        final startArgs = Map<String, dynamic>.from(
          methodCalls.single.$2! as Map,
        );
        final prompt = startArgs['systemPrompt'] as String;
        expect(prompt, contains('§Q§'));
        expect(prompt, contains('§A§'));
        expect(prompt, contains('§END§'));
        expect(prompt, contains('Give the answer directly'));

        await session.stopSession();
        await speechEvents.close();
      },
    );

    test('duplicate partials are filtered before reaching the engine', () async {
      final speechEvents = StreamController<dynamic>.broadcast();
      final session = ConversationListeningSession.test(
        speechEvents: speechEvents.stream,
        engine: engine,
        finalizationTimeout: const Duration(milliseconds: 10),
        invokeMethod: (method, [arguments]) async => null,
      );

      final snapshots = <TranscriptSnapshot>[];
      final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

      await session.startSession(source: TranscriptSource.phone);
      // engine.start() emits an initial empty snapshot
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final baselineCount = snapshots.length;

      // Emit the same partial 20 times (simulating Apple recognizer flooding)
      for (var i = 0; i < 20; i++) {
        speechEvents.add({'script': 'Islam is fine.', 'isFinal': false});
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Only ONE new snapshot should have been emitted (dedup filters the rest)
      expect(snapshots.length - baselineCount, 1);
      expect(snapshots.last.partialText, 'Islam is fine.');

      // Now emit different text — this should go through.
      // "Islam is fine. I think" has a sentence boundary, so the engine
      // will finalize "Islam is fine." and set partial to "I think".
      speechEvents.add({'script': 'Islam is fine. I think', 'isFinal': false});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(snapshots.last.partialText, 'I think');
      expect(snapshots.last.finalizedSegments, contains('Islam is fine.'));

      final afterSentenceSplit = snapshots.length;

      // Then flood the same text again
      for (var i = 0; i < 15; i++) {
        speechEvents.add({
          'script': 'Islam is fine. I think',
          'isFinal': false,
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // No new snapshots — duplicates filtered (partial is still "I think")
      expect(snapshots.length, afterSentenceSplit);

      await session.stopSession();
      await sub.cancel();
      await speechEvents.close();
    });

    test(
      'dedup resets after finalization so new segment partials pass through',
      () async {
        final speechEvents = StreamController<dynamic>.broadcast();
        final session = ConversationListeningSession.test(
          speechEvents: speechEvents.stream,
          engine: engine,
          finalizationTimeout: const Duration(milliseconds: 10),
          invokeMethod: (method, [arguments]) async => null,
        );

        final snapshots = <TranscriptSnapshot>[];
        final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

        await session.startSession(source: TranscriptSource.phone);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final baselineCount = snapshots.length;

        // Segment 1: partial then finalize
        speechEvents.add({'script': 'Hello world', 'isFinal': false});
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(snapshots.length - baselineCount, 1);

        speechEvents.add({
          'script': 'Hello world',
          'isFinal': true,
          'segmentId': 1,
        });
        await Future<void>.delayed(const Duration(milliseconds: 5));

        // Finalization emits an update (the text passes because isFinal
        // resets _lastEmittedPartial) plus the finalized snapshot.
        final snapshotsAfterFinal = snapshots.length;

        // Segment 2: new text after segment restart
        speechEvents.add({'script': 'What', 'isFinal': false});
        await Future<void>.delayed(const Duration(milliseconds: 5));

        expect(snapshots.length, greaterThan(snapshotsAfterFinal));
        expect(snapshots.last.partialText, 'What');
        expect(snapshots.last.finalizedSegments, ['Hello world']);

        await session.stopSession();
        await sub.cancel();
        await speechEvents.close();
      },
    );

    test(
      'multi-segment conversation preserves all finalized segments',
      () async {
        final speechEvents = StreamController<dynamic>.broadcast();
        final session = ConversationListeningSession.test(
          speechEvents: speechEvents.stream,
          engine: engine,
          finalizationTimeout: const Duration(milliseconds: 10),
          invokeMethod: (method, [arguments]) async => null,
        );

        await session.startSession(source: TranscriptSource.phone);

        // Simulate 3 segments (like 25s restart timer would produce)
        final segments = [
          'From the Middle East, colonization efforts',
          'What do you mean? That was by Muslim traders',
          'Islam is fine. I don\'t have a problem',
        ];

        for (final seg in segments) {
          speechEvents.add({'script': seg, 'isFinal': false});
          await Future<void>.delayed(const Duration(milliseconds: 5));
          speechEvents.add({
            'script': seg,
            'isFinal': true,
            'segmentId': segments.indexOf(seg) + 1,
          });
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }

        // Progressive sentence splitting detects boundaries within each
        // segment's text, so "What do you mean? That was..." becomes 2
        // segments, and "Islam is fine. I don't..." becomes 2 more.
        final snapshot = engine.currentTranscriptSnapshot;
        expect(snapshot.finalizedSegments.length, 5);
        expect(snapshot.finalizedSegments[0], segments[0]);
        expect(snapshot.finalizedSegments[1], 'What do you mean?');
        expect(snapshot.finalizedSegments[2], 'That was by Muslim traders');
        expect(snapshot.finalizedSegments[3], 'Islam is fine.');
        expect(snapshot.finalizedSegments[4], "I don't have a problem");

        // Full transcript should contain all content
        expect(snapshot.fullTranscript, contains('colonization'));
        expect(snapshot.fullTranscript, contains('Muslim traders'));
        expect(snapshot.fullTranscript, contains('Islam is fine'));

        await session.stopSession();
        await speechEvents.close();
      },
    );

    test(
      'normal stop and restart keep the speech stream attached for the next session',
      () async {
        var listenCount = 0;
        var cancelCount = 0;
        final speechEvents = StreamController<dynamic>.broadcast(
          onListen: () => listenCount++,
          onCancel: () => cancelCount++,
        );
        final session = ConversationListeningSession.test(
          speechEvents: speechEvents.stream,
          engine: engine,
          finalizationTimeout: const Duration(milliseconds: 10),
          invokeMethod: (method, [arguments]) async => null,
        );

        await session.startSession(source: TranscriptSource.phone);
        speechEvents.add({'script': 'First run', 'isFinal': false});
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await session.stopSession();

        await session.startSession(source: TranscriptSource.phone);
        speechEvents.add({'script': 'Second run', 'isFinal': false});
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await session.stopSession();

        expect(listenCount, 1);
        expect(cancelCount, 0);
        expect(engine.currentTranscriptSnapshot.finalizedSegments, [
          'Second run',
        ]);

        await speechEvents.close();
      },
    );
  });
}
