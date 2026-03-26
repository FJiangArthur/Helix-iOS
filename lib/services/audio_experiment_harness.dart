// ABOUTME: Experimentation harness for testing transcription pipeline with
// ABOUTME: real voice audio files. Feeds audio through the native speech
// ABOUTME: recognizer or the text simulator, collecting honest timing metrics.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../utils/app_logger.dart';
import 'conversation_engine.dart';
import 'conversation_listening_session.dart';

/// Result from a single audio experiment run.
class ExperimentResult {
  final String audioFile;
  final Duration audioDuration;
  final Duration transcriptionDuration;
  final int firstPartialLatencyMs;
  final List<TranscriptEvent> events;
  final String finalTranscript;
  final int segmentCount;
  final int wordCount;
  final double? wordErrorRate;

  ExperimentResult({
    required this.audioFile,
    required this.audioDuration,
    required this.transcriptionDuration,
    required this.firstPartialLatencyMs,
    required this.events,
    required this.finalTranscript,
    required this.segmentCount,
    required this.wordCount,
    this.wordErrorRate,
  });

  Map<String, dynamic> toJson() => {
    'audioFile': audioFile,
    'audioDurationMs': audioDuration.inMilliseconds,
    'transcriptionDurationMs': transcriptionDuration.inMilliseconds,
    'firstPartialLatencyMs': firstPartialLatencyMs,
    'finalTranscript': finalTranscript,
    'segmentCount': segmentCount,
    'wordCount': wordCount,
    if (wordErrorRate != null) 'wordErrorRate': wordErrorRate,
    'eventCount': events.length,
    'events': events.map((e) => e.toJson()).toList(),
  };

  @override
  String toString() {
    final wer = wordErrorRate != null
        ? ', WER=${(wordErrorRate! * 100).toStringAsFixed(1)}%'
        : '';
    return 'ExperimentResult('
        'file=${audioFile.split("/").last}, '
        'audio=${audioDuration.inSeconds}s, '
        'transcription=${transcriptionDuration.inMilliseconds}ms, '
        'firstPartial=${firstPartialLatencyMs}ms, '
        'segments=$segmentCount, '
        'words=$wordCount$wer)';
  }
}

/// A single transcription event with timing.
class TranscriptEvent {
  final String text;
  final bool isFinal;
  final int timestampMs;
  final int? segmentId;
  final Duration elapsed;

  TranscriptEvent({
    required this.text,
    required this.isFinal,
    required this.timestampMs,
    this.segmentId,
    required this.elapsed,
  });

  Map<String, dynamic> toJson() => {
    'text': text.length > 200 ? '${text.substring(0, 200)}...' : text,
    'isFinal': isFinal,
    'elapsedMs': elapsed.inMilliseconds,
    if (segmentId != null) 'segmentId': segmentId,
  };
}

/// Manifest entry for an audio fixture.
class AudioFixture {
  final String name;
  final String file;
  final double durationSeconds;
  final int sizeBytes;
  final String category;
  final String? groundTruth;

  AudioFixture({
    required this.name,
    required this.file,
    required this.durationSeconds,
    required this.sizeBytes,
    this.category = 'unknown',
    this.groundTruth,
  });

  factory AudioFixture.fromJson(Map<String, dynamic> json) => AudioFixture(
    name: json['name'] as String,
    file: json['file'] as String,
    durationSeconds: (json['durationSeconds'] as num).toDouble(),
    sizeBytes: json['sizeBytes'] as int,
    category: json['category'] as String? ?? 'unknown',
    groundTruth: json['groundTruth'] as String?,
  );
}

/// Harness for running audio transcription experiments.
///
/// Supports two modes:
/// 1. **Native file transcription** — sends audio file path to iOS
///    SpeechStreamRecognizer via the existing ConversationListeningSession
///    event channel (no duplicate subscription).
/// 2. **Text simulation** — uses ConversationEngine.simulateTranscription()
///    for pure Dart testing without native audio.
class AudioExperimentHarness {
  static const _methodChannel = MethodChannel('method.bluetooth');
  static const _fixtureDir = 'test/fixtures/audio';

  final ConversationEngine _engine;

  AudioExperimentHarness({ConversationEngine? engine})
      : _engine = engine ?? ConversationEngine.instance;

  /// Load the audio fixture manifest.
  Future<List<AudioFixture>> loadManifest({String? projectRoot}) async {
    final root = projectRoot ?? _findProjectRoot();
    final manifestFile = File('$root/$_fixtureDir/manifest.json');

    if (!manifestFile.existsSync()) {
      appLogger.w('[Experiment] No manifest found. Run: ./scripts/setup_audio_fixtures.sh');
      return [];
    }

    final json = jsonDecode(await manifestFile.readAsString()) as List;
    return json
        .cast<Map<String, dynamic>>()
        .map(AudioFixture.fromJson)
        .toList();
  }

  /// Run a transcription experiment using a native audio file.
  ///
  /// Stops any active listening session first, then triggers native file
  /// transcription. Events flow through the existing eventSpeechRecognize
  /// channel — no duplicate subscription is created.
  ///
  /// [filePath] — absolute path to a WAV file (16kHz mono preferred).
  /// [language] — language code ("EN", "CN", "JP", etc.)
  /// [groundTruth] — expected transcript text for WER calculation.
  /// [timeout]  — max wait time for transcription to complete.
  Future<ExperimentResult> runNativeExperiment({
    required String filePath,
    String language = 'EN',
    String? groundTruth,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    appLogger.i('[Experiment] Starting native experiment: ${filePath.split("/").last}');

    final events = <TranscriptEvent>[];
    final stopwatch = Stopwatch()..start();
    final completer = Completer<void>();
    int? firstPartialMs;
    Timer? completionTimer;

    // Get audio duration from file metadata
    final audioDuration = await _getAudioDuration(filePath);

    // 1. Stop any active session to avoid event mixing
    final session = ConversationListeningSession.instance;
    if (session.isRunning) {
      await session.stopSession();
    }
    _engine.stop();

    // 2. Start a fresh session — events flow through the existing channel
    await session.startSession(source: TranscriptSource.phone);

    // 3. Listen to engine's transcript snapshots (not raw events)
    final sub = _engine.transcriptSnapshotStream.listen((snapshot) {
      final text = snapshot.partialText.isNotEmpty
          ? snapshot.partialText
          : snapshot.fullTranscript;
      final isFinal = snapshot.partialText.isEmpty && text.isNotEmpty;

      if (text.isNotEmpty) {
        firstPartialMs ??= stopwatch.elapsed.inMilliseconds;

        events.add(TranscriptEvent(
          text: text,
          isFinal: isFinal,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          elapsed: stopwatch.elapsed,
        ));

        final preview = text.length > 80 ? '${text.substring(0, 80)}...' : text;
        appLogger.d('[Experiment] ${isFinal ? "FINAL" : "partial"} '
            '[${stopwatch.elapsed.inMilliseconds}ms]: $preview');
      }

      // Debounce completion: after a final event, wait 2s for trailing events
      if (isFinal) {
        completionTimer?.cancel();
        completionTimer = Timer(const Duration(seconds: 2), () {
          if (!completer.isCompleted) completer.complete();
        });
      }
    });

    try {
      // 4. Trigger native file transcription (events flow through existing channel)
      await _methodChannel.invokeMethod('transcribeAudioFile', {
        'filePath': filePath,
        'language': language,
      });

      // 5. Wait for completion or timeout
      await completer.future.timeout(timeout, onTimeout: () {
        appLogger.w('[Experiment] Timeout after ${timeout.inSeconds}s');
      });
    } finally {
      completionTimer?.cancel();
      await sub.cancel();
      stopwatch.stop();
      _engine.stop();
    }

    final finalText = events
        .where((e) => e.isFinal)
        .map((e) => e.text)
        .join(' ');

    final wer = groundTruth != null ? _computeWER(groundTruth, finalText) : null;

    final result = ExperimentResult(
      audioFile: filePath,
      audioDuration: audioDuration,
      transcriptionDuration: stopwatch.elapsed,
      firstPartialLatencyMs: firstPartialMs ?? 0,
      events: events,
      finalTranscript: finalText,
      segmentCount: events.where((e) => e.isFinal).length,
      wordCount: finalText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      wordErrorRate: wer,
    );

    appLogger.i('[Experiment] $result');
    return result;
  }

  /// Run a text-based simulation experiment (no native audio needed).
  ///
  /// Uses ConversationEngine.simulateTranscription() to feed pre-transcribed
  /// text through the full pipeline, measuring question detection and AI
  /// response timing.
  Future<ExperimentResult> runSimulationExperiment({
    required List<String> segments,
    Duration segmentDelay = const Duration(milliseconds: 200),
    Duration wordDelay = const Duration(milliseconds: 40),
  }) async {
    appLogger.i('[Experiment] Starting simulation experiment: ${segments.length} segments');

    final events = <TranscriptEvent>[];
    final stopwatch = Stopwatch()..start();
    int? firstPartialMs;

    // Capture transcript snapshots as events
    final sub = _engine.transcriptSnapshotStream.listen((snapshot) {
      final text = snapshot.partialText.isNotEmpty
          ? snapshot.partialText
          : snapshot.fullTranscript;
      if (text.isNotEmpty) {
        firstPartialMs ??= stopwatch.elapsed.inMilliseconds;
      }
      events.add(TranscriptEvent(
        text: text,
        isFinal: snapshot.partialText.isEmpty,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        elapsed: stopwatch.elapsed,
      ));
    });

    try {
      await _engine.simulateTranscription(
        segments: segments,
        segmentDelay: segmentDelay,
        wordDelay: wordDelay,
      );
    } finally {
      await sub.cancel();
      stopwatch.stop();
      _engine.stop();
    }

    final snapshot = _engine.currentTranscriptSnapshot;

    return ExperimentResult(
      audioFile: '<simulation>',
      audioDuration: Duration(
        milliseconds: (segments.length * segmentDelay.inMilliseconds) +
            (segments.join(' ').split(' ').length * wordDelay.inMilliseconds),
      ),
      transcriptionDuration: stopwatch.elapsed,
      firstPartialLatencyMs: firstPartialMs ?? 0,
      events: events,
      finalTranscript: snapshot.fullTranscript,
      segmentCount: snapshot.finalizedSegments.length,
      wordCount: snapshot.fullTranscript
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length,
    );
  }

  /// Run all fixture audio files and produce a summary report.
  Future<List<ExperimentResult>> runAllFixtures({
    String language = 'EN',
    String? projectRoot,
  }) async {
    final root = projectRoot ?? _findProjectRoot();
    final fixtures = await loadManifest(projectRoot: root);

    if (fixtures.isEmpty) {
      appLogger.w('[Experiment] No fixtures found. Run setup_audio_fixtures.sh first.');
      return [];
    }

    final results = <ExperimentResult>[];

    for (final fixture in fixtures) {
      final filePath = '$root/$_fixtureDir/${fixture.file}';
      try {
        final result = await runNativeExperiment(
          filePath: filePath,
          language: language,
          groundTruth: fixture.groundTruth,
        );
        results.add(result);
      } catch (e) {
        appLogger.e('[Experiment] Failed on ${fixture.name}: $e');
      }
    }

    _printSummary(results);
    return results;
  }

  /// Save experiment results to a JSON file.
  Future<String> saveResults(
    List<ExperimentResult> results, {
    String? outputPath,
    String? projectRoot,
  }) async {
    final root = projectRoot ?? _findProjectRoot();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final path = outputPath ?? '$root/test/fixtures/audio/results_$timestamp.json';

    final json = const JsonEncoder.withIndent('  ').convert({
      'timestamp': DateTime.now().toIso8601String(),
      'results': results.map((r) => r.toJson()).toList(),
    });

    await File(path).writeAsString(json);
    appLogger.i('[Experiment] Results saved to: $path');
    return path;
  }

  void _printSummary(List<ExperimentResult> results) {
    if (results.isEmpty) return;

    appLogger.i('\n═══ Experiment Summary ═══');
    appLogger.i('Total files: ${results.length}');

    for (final r in results) {
      final name = r.audioFile.split('/').last;
      final wer = r.wordErrorRate != null
          ? ', WER=${(r.wordErrorRate! * 100).toStringAsFixed(1)}%'
          : '';
      appLogger.i('  $name: ${r.wordCount} words, '
          '${r.segmentCount} segments, '
          'firstPartial=${r.firstPartialLatencyMs}ms, '
          '${r.transcriptionDuration.inMilliseconds}ms total$wer');
    }

    final avgFirstPartial = results
        .map((r) => r.firstPartialLatencyMs)
        .reduce((a, b) => a + b) / results.length;
    appLogger.i('Average first-partial latency: ${avgFirstPartial.toStringAsFixed(0)}ms');
    appLogger.i('═══════════════════════════\n');
  }

  /// Compute Word Error Rate using minimum edit distance.
  double _computeWER(String reference, String hypothesis) {
    final ref = _normalizeForWER(reference).split(' ').where((w) => w.isNotEmpty).toList();
    final hyp = _normalizeForWER(hypothesis).split(' ').where((w) => w.isNotEmpty).toList();

    if (ref.isEmpty) return hyp.isEmpty ? 0.0 : 1.0;

    // Levenshtein distance at word level
    final n = ref.length;
    final m = hyp.length;
    final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));

    for (var i = 0; i <= n; i++) dp[i][0] = i;
    for (var j = 0; j <= m; j++) dp[0][j] = j;

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = ref[i - 1] == hyp[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,     // deletion
          dp[i][j - 1] + 1,     // insertion
          dp[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return dp[n][m] / n;
  }

  String _normalizeForWER(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<Duration> _getAudioDuration(String filePath) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'quiet',
        '-show_entries', 'format=duration',
        '-of', 'csv=p=0',
        filePath,
      ]);
      final seconds = double.tryParse(result.stdout.toString().trim()) ?? 0;
      return Duration(milliseconds: (seconds * 1000).round());
    } catch (_) {
      return Duration.zero;
    }
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
}
