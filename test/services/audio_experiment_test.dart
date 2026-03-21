// ABOUTME: Integration tests for the audio experiment harness.
// ABOUTME: Tests text simulation mode (no native deps) and validates
// ABOUTME: the experiment result structure with honest metrics.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/audio_experiment_harness.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub out secure storage used by SettingsManager
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStorageValues = <String, String>{};

  late ConversationEngine engine;
  late AudioExperimentHarness harness;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final arguments =
          (call.arguments as Map?)?.cast<Object?, Object?>() ?? {};
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
    });

    SharedPreferences.setMockInitialValues({});
    engine = ConversationEngine.instance;
  });

  setUp(() {
    engine.stop();
    harness = AudioExperimentHarness(engine: engine);
  });

  tearDownAll(() {
    engine.stop();
  });

  group('AudioExperimentHarness', () {
    test('simulation experiment captures all segments', () async {
      final segments = [
        'Hello, welcome to the quarterly business review.',
        'Revenue grew by fifteen percent compared to last quarter.',
        'The team did an outstanding job on the infrastructure migration.',
      ];

      final result = await harness.runSimulationExperiment(
        segments: segments,
        segmentDelay: const Duration(milliseconds: 50),
        wordDelay: const Duration(milliseconds: 5),
      );

      expect(result.segmentCount, equals(3));
      expect(result.wordCount, greaterThan(15));
      expect(result.finalTranscript, contains('quarterly'));
      expect(result.finalTranscript, contains('infrastructure'));
      expect(result.audioFile, equals('<simulation>'));
      expect(result.transcriptionDuration.inMilliseconds, greaterThan(0));
      expect(result.firstPartialLatencyMs, greaterThanOrEqualTo(0));
      expect(result.wordErrorRate, isNull);
    });

    test('simulation experiment measures timing', () async {
      final segments = [
        'This is a short test segment for timing measurement.',
      ];

      final result = await harness.runSimulationExperiment(
        segments: segments,
        segmentDelay: const Duration(milliseconds: 20),
        wordDelay: const Duration(milliseconds: 10),
      );

      // Should complete reasonably quickly
      expect(result.transcriptionDuration.inMilliseconds, lessThan(5000));
      expect(result.events, isNotEmpty);
      expect(result.firstPartialLatencyMs, greaterThanOrEqualTo(0));
    });

    test('ExperimentResult serializes to JSON with honest metrics', () async {
      final result = await harness.runSimulationExperiment(
        segments: ['Hello world, this is a test.'],
        segmentDelay: const Duration(milliseconds: 20),
        wordDelay: const Duration(milliseconds: 5),
      );

      final json = result.toJson();
      expect(json['audioFile'], equals('<simulation>'));
      expect(json['segmentCount'], equals(1));
      expect(json['wordCount'], greaterThan(0));
      expect(json['firstPartialLatencyMs'], isA<int>());
      expect(json['transcriptionDurationMs'], isA<int>());
      expect(json['events'], isA<List>());
      // No realtimeRatio — it was removed as a misleading metric
      expect(json.containsKey('realtimeRatio'), isFalse);
      // wordErrorRate absent for simulation (no ground truth)
      expect(json.containsKey('wordErrorRate'), isFalse);
    });

    test('AudioFixture parses category and groundTruth', () {
      final fixture = AudioFixture.fromJson({
        'name': 'test_sample',
        'file': 'test_sample.wav',
        'durationSeconds': 5.0,
        'sizeBytes': 160000,
        'category': 'conversation',
        'groundTruth': 'Hello world.',
      });

      expect(fixture.category, equals('conversation'));
      expect(fixture.groundTruth, equals('Hello world.'));
    });

    test('AudioFixture handles missing optional fields', () {
      final fixture = AudioFixture.fromJson({
        'name': 'test_sample',
        'file': 'test_sample.wav',
        'durationSeconds': 5.0,
        'sizeBytes': 160000,
      });

      expect(fixture.category, equals('unknown'));
      expect(fixture.groundTruth, isNull);
    });

    test('manifest loads when fixture directory exists', () async {
      final projectRoot = _findProjectRoot();
      final manifestFile = File('$projectRoot/test/fixtures/audio/manifest.json');

      if (!manifestFile.existsSync()) {
        // Skip if fixtures haven't been set up yet
        print('Skipping manifest test — run ./scripts/setup_audio_fixtures.sh first');
        return;
      }

      final fixtures = await harness.loadManifest(projectRoot: projectRoot);
      expect(fixtures, isNotEmpty);
      expect(fixtures.first.name, isNotEmpty);
      expect(fixtures.first.durationSeconds, greaterThan(0));
      expect(fixtures.first.category, isNotEmpty);
    });

    test('multi-segment simulation tracks event timeline', () async {
      final segments = [
        'First, let me explain the current architecture.',
        'We have a microservices backend with three main services.',
        'The frontend communicates through a GraphQL gateway.',
        'Each service has its own database and message queue.',
      ];

      final result = await harness.runSimulationExperiment(
        segments: segments,
        segmentDelay: const Duration(milliseconds: 30),
        wordDelay: const Duration(milliseconds: 5),
      );

      expect(result.segmentCount, greaterThanOrEqualTo(4));
      expect(result.wordCount, greaterThan(20));

      // Events should be in chronological order
      for (var i = 1; i < result.events.length; i++) {
        expect(
          result.events[i].elapsed.inMilliseconds,
          greaterThanOrEqualTo(result.events[i - 1].elapsed.inMilliseconds),
        );
      }
    });

    test('empty segments produce minimal result', () async {
      final result = await harness.runSimulationExperiment(
        segments: [],
        segmentDelay: const Duration(milliseconds: 10),
        wordDelay: const Duration(milliseconds: 5),
      );

      // No new segments added by simulation itself
      expect(result.audioFile, equals('<simulation>'));
      expect(result.transcriptionDuration.inMilliseconds, lessThan(1000));
    });
  });
}

String _findProjectRoot() {
  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return Directory.current.path;
}
