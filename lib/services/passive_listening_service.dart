import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';

import 'analysis_backend.dart';
import 'analysis_orchestrator.dart';
import 'conversation_engine.dart';
import 'knowledge_base.dart';
import 'local_analysis_service.dart';
import 'settings_manager.dart';

// ---------------------------------------------------------------------------
// Event model
// ---------------------------------------------------------------------------

/// A transcript event received from the native passive audio pipeline.
class PassiveTranscriptEvent {
  final String text;
  final bool isFinal;
  final int timestampMs;
  final String language;

  const PassiveTranscriptEvent({
    required this.text,
    required this.isFinal,
    required this.timestampMs,
    required this.language,
  });

  @override
  String toString() =>
      'PassiveTranscriptEvent("$text", isFinal=$isFinal, ts=$timestampMs, lang=$language)';
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Dart coordinator for all-day passive listening mode.
///
/// Bridges to the native `PassiveAudioMonitor` via platform channels, emits
/// [PassiveTranscriptEvent]s, runs local NER on final transcripts, and
/// periodically flushes buffered segments to the analysis backend.
class PassiveListeningService {
  PassiveListeningService._();

  static PassiveListeningService? _instance;
  static PassiveListeningService get instance =>
      _instance ??= PassiveListeningService._();

  /// Reset singleton (for testing).
  static void resetInstance() => _instance = null;

  // ---------------------------------------------------------------------------
  // Platform channels
  // ---------------------------------------------------------------------------

  static const _methodChannel = MethodChannel('method.passiveAudio');
  static const _eventChannel = EventChannel('eventPassiveTranscription');

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _isActive = false;
  bool get isActive => _isActive;

  StreamSubscription<dynamic>? _eventSubscription;
  final List<TranscriptSegment> _pendingSegments = [];
  Timer? _batchTimer;

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  final _transcriptController =
      StreamController<PassiveTranscriptEvent>.broadcast();

  /// Stream of transcript events from passive listening.
  Stream<PassiveTranscriptEvent> get transcriptStream =>
      _transcriptController.stream;

  // ---------------------------------------------------------------------------
  // Dependency injection hooks (for testing)
  // ---------------------------------------------------------------------------

  /// Override to supply a custom [LocalAnalysisService] (useful in tests).
  LocalAnalysisService Function() localAnalysisFactory =
      () => LocalAnalysisService();

  /// Override to supply a custom [UserKnowledgeBase] (useful in tests).
  UserKnowledgeBase Function() knowledgeBaseFactory =
      () => UserKnowledgeBase.instance;

  /// Override to supply a custom [AnalysisOrchestrator] builder (useful in tests).
  AnalysisOrchestrator Function(UserKnowledgeBase kb)?
      analysisOrchestratorFactory;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Start passive listening. Invokes native PassiveAudioMonitor.
  Future<void> start() async {
    if (_isActive) return;
    _isActive = true;

    final settings = SettingsManager.instance;
    await _methodChannel.invokeMethod<void>('startPassiveListening', {
      'language': settings.language,
      'vadThreshold': _dbToLinear(settings.vadThreshold),
    });

    // Listen to event channel
    _eventSubscription =
        _eventChannel.receiveBroadcastStream().listen(_onTranscript);

    // Start batch analysis timer
    _startBatchTimer();
  }

  /// Stop passive listening and flush remaining segments.
  Future<void> stop() async {
    _isActive = false;
    _batchTimer?.cancel();
    _batchTimer = null;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _methodChannel.invokeMethod<void>('stopPassiveListening');
    // Flush remaining segments
    await _flushBatch();
  }

  /// Pause passive listening (audio capture paused on native side).
  void pause() {
    _methodChannel.invokeMethod<void>('pausePassiveListening');
    _batchTimer?.cancel();
    _batchTimer = null;
  }

  /// Resume passive listening after a pause.
  void resume() {
    _methodChannel.invokeMethod<void>('resumePassiveListening');
    _startBatchTimer();
  }

  // ---------------------------------------------------------------------------
  // Transcript handling
  // ---------------------------------------------------------------------------

  void _onTranscript(dynamic event) {
    if (event is! Map) return;

    final text = event['script'] as String? ?? '';
    final isFinal = event['isFinal'] as bool? ?? false;
    final timestampMs = event['timestampMs'] as int? ?? 0;
    final language = event['language'] as String? ?? '';

    final passiveEvent = PassiveTranscriptEvent(
      text: text,
      isFinal: isFinal,
      timestampMs: timestampMs,
      language: language,
    );
    _transcriptController.add(passiveEvent);

    // On final transcript, process locally and buffer for batch
    if (isFinal && text.trim().isNotEmpty) {
      _processLocally(text, language);
      _pendingSegments.add(TranscriptSegment(
        text: text,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Local analysis (NER via NLTagger)
  // ---------------------------------------------------------------------------

  Future<void> _processLocally(String text, String language) async {
    try {
      final analysis = await localAnalysisFactory().analyze(text);
      final kb = knowledgeBaseFactory();
      for (final entity in analysis.entities) {
        await kb.addOrUpdateEntity(
          name: entity.name,
          type: _mapNLType(entity.type),
          source: 'passive',
        );
      }
    } catch (_) {
      // Non-fatal: local analysis failure shouldn't stop passive listening
    }
  }

  // ---------------------------------------------------------------------------
  // Batch analysis
  // ---------------------------------------------------------------------------

  void _startBatchTimer() {
    _batchTimer?.cancel();
    final minutes = SettingsManager.instance.batchAnalysisIntervalMinutes;
    _batchTimer = Timer.periodic(Duration(minutes: minutes), (_) => _flushBatch());
  }

  /// Flush pending segments to the analysis backend.
  Future<void> _flushBatch() async {
    if (_pendingSegments.isEmpty) return;
    final segments = List<TranscriptSegment>.from(_pendingSegments);
    _pendingSegments.clear();

    final backend = SettingsManager.instance.analysisBackend;
    if (backend == 'cloud') {
      try {
        final kb = knowledgeBaseFactory();
        final orchestrator = analysisOrchestratorFactory?.call(kb) ??
            AnalysisOrchestrator(
              kb: kb,
              provider: CloudAnalysisProvider(),
            );
        await orchestrator.processSegments(segments);
      } catch (_) {
        // Non-fatal
      }
    }
    // 'llama' and 'foundation' backends will be added later
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Map NLTagger entity types to knowledge-base entity types.
  String _mapNLType(String nlType) {
    switch (nlType) {
      case 'PersonalName':
        return 'person';
      case 'PlaceName':
        return 'place';
      case 'OrganizationName':
        return 'company';
      default:
        return 'topic';
    }
  }

  /// Convert a dB threshold to linear amplitude.
  double _dbToLinear(double db) => pow(10.0, db / 20.0).toDouble();

  // ---------------------------------------------------------------------------
  // Visible-for-testing accessors
  // ---------------------------------------------------------------------------

  /// Pending segment count (visible for testing).
  int get pendingSegmentCount => _pendingSegments.length;

  /// Flush pending segments (visible for testing).
  Future<void> flushBatchForTest() => _flushBatch();

  /// Inject a transcript event (visible for testing).
  void onTranscriptForTest(dynamic event) => _onTranscript(event);

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  /// Clean up resources. After calling this, [instance] will create a fresh
  /// instance on next access.
  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _transcriptController.close();
    _pendingSegments.clear();
    _instance = null;
  }
}
