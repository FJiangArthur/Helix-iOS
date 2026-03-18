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

    test(
      'openai realtime start forwards stored key and system prompt',
      () async {
        final speechEvents = StreamController<dynamic>.broadcast();
        final methodCalls = <(String, Object?)>[];

        SettingsManager.instance.transcriptionBackend = 'openaiRealtime';
        SettingsManager.instance.transcriptionModel = 'gpt-4o-mini-transcribe';
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
        expect(startArgs['backend'], 'openaiRealtime');
        expect(startArgs['source'], 'microphone');
        expect(startArgs['apiKey'], 'sk-live-test');
        expect(startArgs['model'], 'gpt-4o-mini-transcribe');
        expect(startArgs['systemPrompt'], isA<String>());
        expect((startArgs['systemPrompt'] as String).trim(), isNotEmpty);

        await session.stopSession();
        await speechEvents.close();
      },
    );
  });
}
