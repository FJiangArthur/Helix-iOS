import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';

/// Phase 0 instrumentation for the prep-on-your-face design doc.
///
/// Logs 6 timestamp markers per conversation turn to a local JSONL file so
/// Phase 0 can produce a p50/p95/p99 latency baseline, and Phase 2 can measure
/// against it. Intentionally minimal — single responsibility, no network, no
/// remote telemetry. Disk-only, reset on demand.
///
/// Marker IDs (stable — referenced by the baseline capture script):
/// - `speechEndpoint`   — (a) speech endpoint detected
/// - `questionDetected` — (b) question detection fires
/// - `llmRequestSent`   — (c) LLM streamResponse() call initiated
/// - `llmFirstToken`    — (d) first LLM token arrived
/// - `hudFirstPage`     — (e) first HUD page/line pushed to BLE
/// - `retryPressed`     — (f) user hit the right touchpad to retry
///
/// Each entry is one JSON object per line with fields:
///   `{"ts": unix_ms, "turn": int, "marker": id, "extra": {...}}`
///
/// A "turn" is a counter that advances when `speechEndpoint` fires.
enum LatencyMarker {
  speechEndpoint,
  questionDetected,
  llmRequestSent,
  llmFirstToken,
  hudFirstPage,
  retryPressed,
}

class LatencyTracker {
  LatencyTracker._();

  static final LatencyTracker instance = LatencyTracker._();

  /// When false, record() is a no-op. Default on for now; can be gated by a
  /// SettingsManager flag later without touching callers.
  bool enabled = true;

  int _turnCounter = 0;
  File? _sink;
  Future<void>? _openFuture;

  // Retry-rate metric (Phase 0b): lifetime + per-session counters for
  // manual-retry events. Surfaced on the dashboard in Phase 2 or later;
  // Phase 0 only needs to capture.
  int _sessionManualRetries = 0;
  int _lifetimeManualRetries = 0;

  int get sessionManualRetries => _sessionManualRetries;
  int get lifetimeManualRetries => _lifetimeManualRetries;

  /// Increment retry counters. Called from [ConversationEngine.forceQuestionAnalysis]
  /// alongside the retryPressed marker so the metric survives even when
  /// on-disk logging is disabled.
  void recordManualRetry() {
    _sessionManualRetries += 1;
    _lifetimeManualRetries += 1;
  }

  /// Reset per-session retry counter. Called on conversation end.
  void resetSessionRetries() {
    _sessionManualRetries = 0;
  }

  /// Advance the turn counter. Called when a new speech endpoint is detected.
  /// Returns the new turn id so callers can correlate markers across awaits.
  int beginTurn() {
    _turnCounter += 1;
    return _turnCounter;
  }

  int get currentTurn => _turnCounter;

  /// Record [marker] with the current timestamp. Optional [extra] is merged
  /// into the JSON entry (numeric/string values only — callers must not pass
  /// non-JSON-serializable data).
  ///
  /// Fire-and-forget — never throws to the caller. Disk errors are logged
  /// via [appLogger.w] and drop the entry silently.
  void record(
    LatencyMarker marker, {
    Map<String, Object?>? extra,
    int? turn,
  }) {
    if (!enabled) return;

    final entry = <String, Object?>{
      'ts': DateTime.now().millisecondsSinceEpoch,
      'turn': turn ?? _turnCounter,
      'marker': marker.name,
      if (extra != null && extra.isNotEmpty) 'extra': extra,
    };
    final line = '${jsonEncode(entry)}\n';

    // Fire-and-forget write. Open-on-first-use, then append.
    _writeLine(line).catchError((e) {
      appLogger.w('[LatencyTracker] failed to write marker ${marker.name}: $e');
    });
  }

  // Writes are serialized so overlapping record() calls never race on the
  // shared file handle — File.writeAsString isn't reentrant-safe on all
  // platforms and on the iOS simulator we saw one of two rapid writes fall
  // on the floor. The chain is a Future<void> that each record() awaits
  // before appending its own line.
  Future<void> _writeChain = Future<void>.value();

  Future<void> _writeLine(String line) async {
    final sink = await _ensureSink();
    if (sink == null) return;
    final previous = _writeChain;
    final completer = Future<void>(() async {
      await previous;
      // flush: true ensures the line is on disk before the future resolves,
      // which lets tests deterministically read it back.
      await sink.writeAsString(line, mode: FileMode.append, flush: true);
    });
    _writeChain = completer.catchError((_) {});
    await completer;
  }

  Future<File?> _ensureSink() async {
    if (_sink != null) return _sink;
    _openFuture ??= _openSink();
    await _openFuture;
    return _sink;
  }

  Future<void> _openSink() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'latency_markers.jsonl'));
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      _sink = file;
      appLogger.d('[LatencyTracker] sink opened at ${file.path}');
    } catch (e) {
      appLogger.w('[LatencyTracker] failed to open sink: $e');
    }
  }

  /// Test/debug seam: clear the on-disk log. Safe to call at app start.
  Future<void> resetLog() async {
    try {
      final sink = await _ensureSink();
      if (sink != null && await sink.exists()) {
        await sink.writeAsString('');
      }
      _turnCounter = 0;
    } catch (e) {
      appLogger.w('[LatencyTracker] failed to reset log: $e');
    }
  }

  /// Read back all logged entries. Primarily for the baseline-capture tool
  /// and regression tests.
  Future<List<Map<String, Object?>>> readEntries() async {
    final sink = await _ensureSink();
    if (sink == null || !await sink.exists()) return const [];
    final raw = await sink.readAsString();
    final out = <Map<String, Object?>>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        out.add(jsonDecode(trimmed) as Map<String, Object?>);
      } catch (_) {
        // Skip malformed lines — never fail readback on a single bad row.
      }
    }
    return out;
  }
}
