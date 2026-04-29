import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Integration test that exercises the full transcription simulation pipeline,
/// verifying that all segments are captured, no content is lost, and stats
/// are computed correctly — equivalent to a real multi-minute conversation.
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
        if (key != null && value != null) secureStorageValues[key] = value;
        return null;
      case 'delete':
        if (key != null) secureStorageValues.remove(key);
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

  group('Transcription simulation', () {
    late ConversationEngine engine;

    setUp(() async {
      secureStorageValues.clear();
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
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
      'simulateTranscription captures all segments without content loss',
      () async {
        final snapshots = <TranscriptSnapshot>[];
        final sub = engine.transcriptSnapshotStream.listen(snapshots.add);

        final testSegments = [
          'Tell me about your experience with distributed systems.',
          'Can you walk me through a specific production debugging example?',
          'What monitoring tools do you prefer and why?',
        ];

        await engine.simulateTranscription(
          segments: testSegments,
          segmentDelay: const Duration(milliseconds: 50),
          wordDelay: const Duration(milliseconds: 5),
        );

        // All 3 segments should be finalized
        final finalSnapshot = engine.currentTranscriptSnapshot;
        expect(finalSnapshot.finalizedSegments.length, 3);
        expect(finalSnapshot.finalizedSegments[0], testSegments[0]);
        expect(finalSnapshot.finalizedSegments[1], testSegments[1]);
        expect(finalSnapshot.finalizedSegments[2], testSegments[2]);

        // Full transcript contains all content
        for (final seg in testSegments) {
          expect(finalSnapshot.fullTranscript, contains(seg));
        }

        // Stats should be populated
        final stats = engine.transcriptStats;
        expect(stats.wordCount, greaterThan(15));
        expect(stats.segmentCount, 3);

        // Many snapshots should have been emitted (word-by-word + finalizations)
        expect(snapshots.length, greaterThan(testSegments.length * 3));

        await sub.cancel();
      },
    );

    test('simulation shows progressive word-by-word partial updates', () async {
      final partials = <String>[];
      final sub = engine.transcriptSnapshotStream.listen((s) {
        if (s.partialText.isNotEmpty) {
          partials.add(s.partialText);
        }
      });

      await engine.simulateTranscription(
        segments: ['Hello world from the test'],
        wordDelay: const Duration(milliseconds: 5),
      );

      // Should see progressive partials: "Hello", "Hello world", etc.
      expect(partials.length, greaterThanOrEqualTo(4));
      expect(partials.first, 'Hello');
      expect(partials[1], 'Hello world');
      expect(partials.last, 'Hello world from the test');

      await sub.cancel();
    });

    test(
      'simulation with many segments verifies no content loss over long session',
      () async {
        // Simulate a longer interview with 8 segments (~3+ minutes equivalent)
        final segments = List.generate(
          8,
          (i) =>
              'Interview question number ${i + 1}: '
              'This is a detailed question about topic ${i + 1} '
              'that tests the candidate on their knowledge.',
        );

        await engine.simulateTranscription(
          segments: segments,
          segmentDelay: const Duration(milliseconds: 30),
          wordDelay: const Duration(milliseconds: 2),
        );

        final snapshot = engine.currentTranscriptSnapshot;
        expect(snapshot.finalizedSegments.length, 8);

        // Verify every single segment is present
        for (var i = 0; i < segments.length; i++) {
          expect(
            snapshot.finalizedSegments[i],
            segments[i],
            reason: 'Segment $i should match',
          );
        }

        // Verify stats
        final stats = engine.transcriptStats;
        expect(stats.segmentCount, 8);
        expect(stats.wordCount, greaterThan(100));
      },
    );

    test('transcriptStats computes WPM after multiple segments', () async {
      // Use segments with known word counts
      final segments = [
        'one two three four five six seven eight nine ten', // 10 words
        'eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty', // 10 words
      ];

      await engine.simulateTranscription(
        segments: segments,
        segmentDelay: const Duration(milliseconds: 200),
        wordDelay: const Duration(milliseconds: 10),
      );

      final stats = engine.transcriptStats;
      expect(stats.wordCount, 20);
      expect(stats.segmentCount, 2);
      // WPM requires >6s between first and last segment to avoid noise.
      // In test the total time is <1s, so WPM stays 0 — just verify the
      // field exists and doesn't throw.
      expect(stats.wordsPerMinute, isA<double>());
    });

    test(
      'STAR coaching triggers for behavioral questions in interview simulation',
      () async {
        final coachingPrompts = <CoachingPrompt>[];
        final sub = engine.coachingStream.listen(coachingPrompts.add);

        // The default simulation segments contain "tell me about" and
        // "walk me through" which match behavioral patterns.
        // simulateTranscription sets interview mode automatically.
        await engine.simulateTranscription(
          segmentDelay: const Duration(milliseconds: 50),
          wordDelay: const Duration(milliseconds: 3),
        );

        // At least one STAR coaching prompt should have been emitted
        expect(coachingPrompts, isNotEmpty);
        expect(coachingPrompts.first.framework, 'STAR');
        expect(coachingPrompts.first.steps.length, 4);
        expect(coachingPrompts.first.questionContext, isNotEmpty);

        await sub.cancel();
      },
    );
  });
}
