import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/answered_question.dart';
import '../models/assistant_profile.dart';
import '../utils/app_logger.dart';
import 'bitmap_hud/bitmap_hud_service.dart';
import 'cloud_pipeline_service.dart';
import 'cost/conversation_cost_tracker.dart';
import 'cost/pricing_registry.dart';
import 'cost/session_cost_snapshot.dart';
import 'database/helix_database.dart' as database_pkg;
import 'session_context_manager.dart';
import 'text_paginator.dart';
import 'hud_controller.dart';
import 'hud_stream_session.dart';
import 'provider_error_state.dart';
import 'proto.dart';
import 'glasses_protocol.dart';
import 'latency_tracker.dart';
import 'llm/llm_service.dart';
import 'prompt_assembler.dart';
import 'llm/llm_provider.dart';
import 'factcheck/cited_fact_check_result.dart';
import 'factcheck/tavily_search_provider.dart';
import 'factcheck/web_search_provider.dart';
import 'tools/tool_executor.dart';
import 'tools/web_search_tool.dart';
import 'conversation_listening_session.dart';
import 'entity_memory.dart';
import 'knowledge_base.dart';
import 'projects/active_project_controller.dart';
import 'projects/project_context_formatter.dart';
import 'projects/project_rag_service.dart';
import 'settings_manager.dart';
import 'translation_service.dart';
import 'text_service.dart';
import 'evenai.dart';
import '../ble_manager.dart';

/// Drives the conversation intelligence pipeline:
/// Transcription → Question Detection → AI Response → Glasses Display
///
/// Includes proactive suggestions, STAR coaching for interviews,
/// conversation summaries, and smart follow-up chips.
class ConversationEngine {
  static const String _storageKey = 'conversation_history';
  static const int _maxStoredTurns = 100;

  static ConversationEngine? _instance;
  static ConversationEngine get instance =>
      _instance ??= ConversationEngine._();

  ConversationEngine._() {
    _loadHistory();
  }

  // State
  ConversationMode _mode = ConversationMode.general;
  bool _isActive = false;
  TranscriptSource _transcriptSource = TranscriptSource.phone;
  String _currentTranscription = '';
  String _partialTranscription = '';
  final List<TranscriptSegment> _finalizedSegments = [];
  final List<ConversationTurn> _history = [];
  Timer? _analysisTimer;
  int _analysisToken = 0;
  int _responseToken = 0;
  bool _isGeneratingResponse = false;
  bool _sessionStopHandled = false;
  String _lastHandledQuestionKey = '';
  DateTime? _lastHandledQuestionTime;
  QuestionDetectionResult? _latestQuestionDetection;
  String? _lastSavedConversationId;
  final ConversationCostTracker _conversationCostTracker =
      ConversationCostTracker();

  Stream<SessionCostSnapshot> get costSnapshots =>
      _conversationCostTracker.snapshots;
  SessionCostSnapshot get currentCostSnapshot =>
      _conversationCostTracker.current;

  // Knowledge Base context cache
  String _cachedKbContext = '';
  DateTime? _lastKbContextRefresh;

  // Proactive mode context manager
  final SessionContextManager _sessionContextManager = SessionContextManager();

  // Persist debounce
  DateTime? _lastPersistTime;
  static const _persistDebounce = Duration(seconds: 30);

  // Silence detection state
  Timer? _silenceTimer;
  static const Duration _silenceThreshold = Duration(seconds: 5);
  static const Duration _responseFlushInterval = Duration(milliseconds: 75);
  static const int _responseFlushThreshold = 14;
  bool _silenceSuggestionSent = false;
  String _realtimeResponseBuffer = '';
  String _latestAssistantResponse = '';
  DateTime? _latestAssistantResponseTimestamp;
  String _lastEmittedSnapshot = '';
  String _lastEmittedPartial = '';
  DateTime? _silenceTimerTarget;
  DateTime? _analysisTimerTarget;
  DateTime? _lastGlassesFlush;
  static const _minFlushInterval = Duration(milliseconds: 200);

  // Progressive sentence finalization: track how many complete sentences
  // from the current Apple recognition segment we've already finalized.
  int _segmentSentencesFinalized = 0;
  static final _sentenceBoundary = RegExp(r'(?<=[.?!])\s+');

  // Configuration — read through SettingsManager so tests can set values there.
  bool get autoDetectQuestions => SettingsManager.instance.autoDetectQuestions;
  set autoDetectQuestions(bool v) =>
      SettingsManager.instance.autoDetectQuestions = v;
  bool get answerAll => SettingsManager.instance.answerAll;
  set answerAll(bool v) => SettingsManager.instance.answerAll = v;

  // Streams
  final _transcriptionController = StreamController<String>.broadcast();
  final _transcriptSnapshotController =
      StreamController<TranscriptSnapshot>.broadcast();
  final _aiResponseController = StreamController<String>.broadcast();
  final _modeController = StreamController<ConversationMode>.broadcast();
  final _questionDetectedController =
      StreamController<DetectedQuestion>.broadcast();
  final _questionDetectionController =
      StreamController<QuestionDetectionResult>.broadcast();
  final _sessionSavedController = StreamController<String>.broadcast();
  final _statusController = StreamController<EngineStatus>.broadcast();
  final _proactiveSuggestionController =
      StreamController<ProactiveSuggestion>.broadcast();
  final _coachingController = StreamController<CoachingPrompt>.broadcast();
  final _followUpChipsController = StreamController<List<String>>.broadcast();
  final _providerErrorController =
      StreamController<ProviderErrorState?>.broadcast();
  final _postConversationController =
      StreamController<Map<String, dynamic>?>.broadcast();
  final _factCheckAlertController = StreamController<String>.broadcast();
  final _citedFactCheckController =
      StreamController<CitedFactCheckResult>.broadcast();
  final _projectCitationsController =
      StreamController<List<RetrievedChunk>>.broadcast();

  /// Emits the citation sources used for the most recent project-enriched response.
  Stream<List<RetrievedChunk>> get projectCitationsStream =>
      _projectCitationsController.stream;

  /// Optional override for the web search provider, used by tests to inject
  /// a fake without hitting the network. When null, `_activeFactCheck`
  /// constructs a `TavilySearchProvider` from the stored Tavily API key.
  @visibleForTesting
  WebSearchProvider? webSearchProviderOverride;
  final _translationController = StreamController<String>.broadcast();
  StreamSubscription<String>? _translationSubscription;
  final _sentimentController = StreamController<double>.broadcast();
  final _entityController = StreamController<EntityInfo>.broadcast();
  int _sentimentSegmentCounter = 0;
  int _entitySegmentCounter = 0;
  ProviderErrorState? _lastProviderError;

  /// System prompt for the current mode and language, used by realtime sessions.
  String get systemPrompt => _getSystemPrompt();

  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<TranscriptSnapshot> get transcriptSnapshotStream =>
      _transcriptSnapshotController.stream;
  Stream<String> get aiResponseStream => _aiResponseController.stream;
  Stream<ConversationMode> get modeStream => _modeController.stream;
  Stream<DetectedQuestion> get questionDetectedStream =>
      _questionDetectedController.stream;
  Stream<QuestionDetectionResult> get questionDetectionStream =>
      _questionDetectionController.stream;
  Stream<String> get sessionSavedStream => _sessionSavedController.stream;
  Stream<EngineStatus> get statusStream => _statusController.stream;
  Stream<ProactiveSuggestion> get proactiveSuggestionStream =>
      _proactiveSuggestionController.stream;
  Stream<CoachingPrompt> get coachingStream => _coachingController.stream;
  Stream<List<String>> get followUpChipsStream =>
      _followUpChipsController.stream;
  Stream<ProviderErrorState?> get providerErrorStream =>
      _providerErrorController.stream;
  Stream<Map<String, dynamic>?> get postConversationAnalysisStream =>
      _postConversationController.stream;
  Stream<String> get factCheckAlertStream => _factCheckAlertController.stream;
  Stream<CitedFactCheckResult> get citedFactCheckStream =>
      _citedFactCheckController.stream;
  Stream<String> get translationStream => _translationController.stream;
  Stream<double> get sentimentStream => _sentimentController.stream;
  Stream<EntityInfo> get entityStream => _entityController.stream;

  ConversationMode get mode => _mode;
  bool get isActive => _isActive;
  String get currentTranscription => _currentTranscription;

  /// Answered questions tracked during the current proactive session.
  List<AnsweredQuestion> get answeredQuestions =>
      _sessionContextManager.answeredQuestions;
  TranscriptSnapshot get currentTranscriptSnapshot => TranscriptSnapshot(
    source: _transcriptSource,
    partialText: _partialTranscription,
    finalizedSegments: List.unmodifiable(
      _finalizedSegments.map((s) => s.text).toList(),
    ),
    finalizedTimelineEntries: List.unmodifiable(
      _copyTranscriptSegments(_finalizedSegments),
    ),
    fullTranscript: _currentTranscription,
  );
  List<ConversationTurn> get history => List.unmodifiable(_history);
  ProviderErrorState? get lastProviderError => _lastProviderError;
  QuestionDetectionResult? get latestQuestionDetection =>
      _latestQuestionDetection;

  /// Compute live transcript statistics for UI display.
  TranscriptStats get transcriptStats {
    final words = _currentTranscription
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final segments = _finalizedSegments.length;
    // Estimate WPM from finalized segments with timestamps
    double wpm = 0;
    if (_finalizedSegments.length >= 2) {
      final first = _finalizedSegments.first.timestamp;
      final last = _finalizedSegments.last.timestamp;
      final minutes = last.difference(first).inSeconds / 60.0;
      if (minutes > 0.1) {
        wpm = words / minutes;
      }
    }
    return TranscriptStats(
      wordCount: words,
      segmentCount: segments,
      wordsPerMinute: wpm.roundToDouble(),
      questionCount: _history.where((t) => t.role == 'user').length,
    );
  }

  /// Start the conversation engine
  void start({
    ConversationMode? mode,
    TranscriptSource source = TranscriptSource.phone,
  }) {
    // WS-B Fix 1: idempotent re-entry. If the engine is already active for the
    // same source, do NOT wipe the live transcript — just refresh status and
    // optionally update the mode. This prevents native restarts, audio
    // interruptions, or double-tap startSession calls from blanking the live
    // page mid-session.
    if (_isActive && _transcriptSource == source) {
      if (mode != null) setMode(mode);
      _statusController.add(EngineStatus.listening);
      appLogger.i(
        'ConversationEngine.start() re-entered while active; '
        'preserving live state (source=${source.name})',
      );
      return;
    }
    if (_isActive && _transcriptSource != source) {
      appLogger.w(
        'ConversationEngine.start() source change mid-session '
        '(${_transcriptSource.name} -> ${source.name}); resetting live state',
      );
    }
    _cancelInFlightResponse();
    _isGeneratingResponse = false;
    _resetLiveSessionState(clearConversationHistory: true);
    _isActive = true;
    _sessionStopHandled = false;
    _transcriptSource = source;
    _silenceSuggestionSent = false;
    _analysisToken = 0;
    _segmentSentencesFinalized = 0;
    _sentimentSegmentCounter = 0;
    _entitySegmentCounter = 0;
    _analyticsRunning = false;
    _conversationCostTracker.reset();
    _clearProviderError();
    _lastSavedConversationId = null;
    if (mode != null) setMode(mode);
    if (!answerAll) {
      _sessionContextManager.startSession();
    }
    _emitTranscriptSnapshot();
    _statusController.add(EngineStatus.listening);
    // Suppress heartbeat during active conversation (BLE mic data is enough).
    BleManager.get().updateHeartbeatMode(true);
    // Pause bitmap HUD refresh during conversation (text HUD takes precedence).
    BitmapHudService.instance.setConversationActive(true);
    appLogger.i('ConversationEngine started in ${_mode.name} mode');
  }

  /// Stop the engine
  void stop() {
    _cancelInFlightResponse();
    _isGeneratingResponse = false;
    _isActive = false;
    _analysisToken++;
    _analysisTimer?.cancel();
    _silenceTimer?.cancel();
    _translationSubscription?.cancel();
    _translationSubscription = null;
    _segmentSentencesFinalized = 0;
    _lastEmittedSnapshot = '';
    _lastEmittedPartial = '';
    _clearProviderError();
    _sessionContextManager.reset();
    LatencyTracker.instance.resetSessionRetries();
    _ensureTranscriptHistorySnapshot();
    // Force-persist on stop regardless of debounce
    _lastPersistTime = null;
    _persistHistory();
    // Restore idle heartbeat now that conversation ended.
    BleManager.get().updateHeartbeatMode(false);
    if (!BleManager.isBothConnected()) {
      BleManager.get().stopSendBeatHeart();
    }
    // Resume bitmap HUD refresh.
    BitmapHudService.instance.setConversationActive(false);
    _statusController.add(EngineStatus.idle);
    appLogger.i('ConversationEngine stopped');

    if (_sessionStopHandled) {
      return;
    }
    _sessionStopHandled = true;

    final hasTranscript = _finalizedSegments.isNotEmpty;
    final hasAnalysisContext =
        _history.length > 1 && _finalizedSegments.length > 1;

    // Trigger post-conversation analysis asynchronously if there is
    // meaningful history and the session produced finalized segments.
    if (hasAnalysisContext) {
      final stopToken = _analysisToken;
      getPostConversationAnalysis()
          .then((result) {
            if (stopToken == _analysisToken) {
              _postConversationController.add(result);
            }
          })
          .catchError((e) {
            appLogger.e('Post-conversation analysis failed', error: e);
            if (stopToken == _analysisToken) {
              _postConversationController.add(null);
            }
          });
    }

    // Save any session that produced finalized transcript segments, even when
    // the websocket or downstream analysis failed before an assistant answer.
    // Audio-only sessions (no transcript) are saved when the audio file path
    // arrives via attachLatestAudioFilePath().
    if (hasTranscript) {
      _saveAndProcessConversation();
    }
  }

  /// Save the current conversation to the database and trigger the cloud pipeline.
  Future<void> _saveAndProcessConversation() async {
    try {
      final db = database_pkg.HelixDatabase.instance;
      final conversationId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      _lastSavedConversationId = conversationId;

      // Save conversation record
      await db.conversationDao.insertConversation(
        database_pkg.ConversationsCompanion.insert(
          id: conversationId,
          startedAt: now - (_finalizedSegments.length * 5000),
          endedAt: drift.Value(now),
          mode: drift.Value(_mode.name),
          source: drift.Value('glasses'),
        ),
      );

      final timelineEntries = _buildPersistedTimelineEntries();

      // Save timeline entries in chronological order so transcript and
      // assistant replies remain part of the same persisted session.
      for (int i = 0; i < timelineEntries.length; i++) {
        final seg = timelineEntries[i];
        await db.conversationDao.insertSegment(
          database_pkg.ConversationSegmentsCompanion.insert(
            id: const Uuid().v4(),
            conversationId: conversationId,
            segmentIndex: i,
            text_: seg.text,
            speakerLabel: drift.Value(seg.speakerLabel),
            startedAt: seg.timestamp.millisecondsSinceEpoch,
          ),
        );
      }

      appLogger.i(
        'Saved conversation $conversationId with ${timelineEntries.length} timeline entries',
      );
      _sessionSavedController.add(conversationId);

      for (final entry in _conversationCostTracker.entries) {
        await db
            .into(db.conversationAiCostEntries)
            .insert(
              database_pkg.ConversationAiCostEntriesCompanion.insert(
                id: entry.id,
                conversationId: conversationId,
                operationType: entry.operationType.name,
                providerId: entry.providerId,
                modelId: entry.modelId,
                inputTokens: drift.Value(entry.usage.inputTokens),
                outputTokens: drift.Value(entry.usage.outputTokens),
                cachedInputTokens: drift.Value(entry.usage.cachedInputTokens),
                audioInputTokens: drift.Value(entry.usage.audioInputTokens),
                audioOutputTokens: drift.Value(entry.usage.audioOutputTokens),
                costUsd: drift.Value(entry.costUsd),
                status: drift.Value(entry.status),
                startedAt: entry.startedAt.millisecondsSinceEpoch,
                completedAt: drift.Value(
                  entry.completedAt?.millisecondsSinceEpoch,
                ),
                modelRole: drift.Value(entry.modelRole?.name),
              ),
            );
      }

      // Write per-session cost totals onto the Conversations row.
      final snap = _conversationCostTracker.current;
      int micros(double usd) => (usd * 1e6).round();
      await (db.update(db.conversations)
            ..where((c) => c.id.equals(conversationId)))
          .write(
            database_pkg.ConversationsCompanion(
              costSmartUsdMicros: drift.Value(micros(snap.smartUsd)),
              costLightUsdMicros: drift.Value(micros(snap.lightUsd)),
              costTranscriptionUsdMicros: drift.Value(
                micros(snap.transcriptionUsd),
              ),
              costTotalUsdMicros: drift.Value(micros(snap.totalUsd)),
            ),
          );

      // Trigger cloud pipeline asynchronously
      CloudPipelineService.instance.processConversation(conversationId);
    } catch (e) {
      appLogger.e('Failed to save conversation to database', error: e);
    }
  }

  List<TranscriptSegment> _buildPersistedTimelineEntries() {
    final entries = <TranscriptSegment>[
      ..._finalizedSegments.map(
        (segment) => TranscriptSegment(
          text: segment.text,
          timestamp: segment.timestamp,
          speakerLabel: segment.speakerLabel,
        ),
      ),
      ..._history
          .where((turn) => turn.role == 'assistant')
          .map(
            (turn) => TranscriptSegment(
              text: turn.content,
              timestamp: turn.timestamp,
              speakerLabel: 'assistant',
            ),
          ),
    ];

    final latestResponse = _latestAssistantResponse.trim();
    final hasPersistedAssistantTurn = entries.any(
      (entry) =>
          entry.speakerLabel == 'assistant' &&
          _normalizeQuestion(entry.text) == _normalizeQuestion(latestResponse),
    );
    if (latestResponse.isNotEmpty && !hasPersistedAssistantTurn) {
      entries.add(
        TranscriptSegment(
          text: latestResponse,
          timestamp:
              _latestAssistantResponseTimestamp ??
              (_finalizedSegments.isNotEmpty
                  ? _finalizedSegments.last.timestamp
                  : DateTime.now()),
          speakerLabel: 'assistant',
        ),
      );
    }

    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return entries;
  }

  Future<void> attachLatestAudioFilePath(String? path) async {
    final trimmedPath = path?.trim();
    if (trimmedPath == null || trimmedPath.isEmpty) {
      return;
    }

    try {
      final db = database_pkg.HelixDatabase.instance;
      var conversationId = _lastSavedConversationId;

      // If no conversation was saved (e.g. transcription failed, audio-only
      // fallback), create a minimal conversation record for the recording.
      if (conversationId == null) {
        conversationId = const Uuid().v4();
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.conversationDao.insertConversation(
          database_pkg.ConversationsCompanion.insert(
            id: conversationId,
            startedAt: now,
            endedAt: drift.Value(now),
            mode: drift.Value(_mode.name),
            source: drift.Value('phone'),
            audioFilePath: drift.Value(trimmedPath),
          ),
        );
        _lastSavedConversationId = conversationId;
        appLogger.i(
          'Created audio-only conversation $conversationId',
        );
        _sessionSavedController.add(conversationId);
        return;
      }

      await db.conversationDao.updateConversation(
        database_pkg.ConversationsCompanion(
          id: drift.Value(conversationId),
          audioFilePath: drift.Value(trimmedPath),
        ),
      );
    } catch (error) {
      appLogger.e('Failed to attach audio path to conversation', error: error);
    }
  }

  /// Set conversation mode
  void setMode(ConversationMode mode) {
    _mode = mode;
    _modeController.add(mode);
    appLogger.d('Mode changed to ${mode.name}');
  }

  /// Called when new transcription text arrives from speech recognition.
  ///
  /// Apple's recognizer sends the full buffer text on each partial callback.
  /// We split it into sentences and progressively finalize complete ones,
  /// keeping only the trailing incomplete sentence as the live partial.
  void onTranscriptionUpdate(String text) {
    if (!_isActive) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // While generating a response, suppress incoming partial updates.
    // The native recognizer may still emit buffered results after pause —
    // processing them here would clear the active answer flag and schedule
    // a competing analysis cycle that cancels the in-flight response.
    if (_isGeneratingResponse) return;

    // Clear active answer flag so touchpad reverts to pause/analyze
    EvenAI.hasActiveAnswer = false;

    // Split by sentence boundaries and progressively finalize complete ones.
    // Wrapped in try-catch so a regex or split issue can never kill the
    // event pipeline — fall back to the original behavior (full text as partial).
    try {
      _progressiveUpdate(trimmed);
    } catch (e) {
      appLogger.w('[Engine] Sentence split failed, using full text: $e');
      _partialTranscription = trimmed;
      _emitTranscriptSnapshot();
    }

    _silenceSuggestionSent = false;
    _resetSilenceTimer();

    if (autoDetectQuestions && answerAll) {
      _scheduleTranscriptAnalysis();
    }
    if (_mode == ConversationMode.interview &&
        _partialTranscription.isNotEmpty) {
      _checkForBehavioralQuestion(_partialTranscription);
    }
  }

  void onTranscriptionUsage({
    required String providerId,
    required String modelId,
    required LlmUsage usage,
  }) {
    // Apple zero-cost transcription emits empty usage; we still want to
    // record it so the breakdown shows "Free" for Apple sessions.
    if (!usage.hasAnyUsage && providerId != 'apple') return;
    final costUsd = PricingRegistry.instance.calculateCostUsd(
      providerId: providerId,
      modelId: modelId,
      usage: usage,
    );
    _conversationCostTracker.recordCompleted(
      operationType: AiOperationType.transcription,
      providerId: providerId,
      modelId: modelId,
      usage: usage,
      costUsd: costUsd,
      modelRole: ModelRole.transcription,
    );
  }

  /// Split [trimmed] by sentence boundaries. Complete sentences are finalized,
  /// the trailing incomplete sentence becomes the live partial.
  void _progressiveUpdate(String trimmed) {
    final parts = trimmed.split(_sentenceBoundary);

    // All parts except the last are complete sentences.
    final completeCount = parts.length > 1 ? parts.length - 1 : 0;

    // Finalize any NEW complete sentences we haven't finalized yet.
    for (int i = _segmentSentencesFinalized; i < completeCount; i++) {
      final sentence = parts[i].trim();
      if (sentence.isNotEmpty) {
        _finalizedSegments.add(
          TranscriptSegment(text: sentence, timestamp: DateTime.now()),
        );
        appLogger.d(
          '[Engine] Progressive finalize '
          '(segmentChars=${sentence.length})',
        );
      }
    }
    if (completeCount > _segmentSentencesFinalized) {
      _segmentSentencesFinalized = completeCount;
    }

    // Cap finalized segments at 200 to bound memory for long sessions.
    if (_finalizedSegments.length > 200) {
      _compactAndCapSegments();
    }

    // The last part is the in-progress sentence.
    _partialTranscription = parts.last.trim();
    _emitTranscriptSnapshot();
  }

  // Guards against concurrent compaction (one Future in flight at a time)
  // and backs off after consecutive failures to avoid retry storms.
  bool _compactionInFlight = false;
  int _compactionConsecutiveFailures = 0;
  static const int _compactionBackoffThreshold = 3;

  /// Archives the oldest 100 segments via [SessionContextManager] and removes
  /// them from [_finalizedSegments] to bound memory during long sessions.
  ///
  /// BUG-005 fix: segments are only removed AFTER archiving completes
  /// (success or documented fallback). If the LLM service is unavailable
  /// or summarization raises an unexpected error, segments are retained
  /// and will be retried on the next cap-trigger.
  void _compactAndCapSegments() {
    if (_compactionInFlight) {
      appLogger.d('[Engine] Compaction already in flight, skipping');
      return;
    }
    if (_compactionConsecutiveFailures >= _compactionBackoffThreshold) {
      // Backoff: retry only every 50th cap-trigger after hitting the threshold,
      // so a broken LLM config does not spin forever. Segments are retained
      // (capped list simply grows beyond 200 until retry succeeds).
      if (_finalizedSegments.length %
              (50 * (_compactionConsecutiveFailures + 1)) !=
          0) {
        return;
      }
    }

    final llmService = _getLlmService();
    if (llmService == null) {
      // No LLM available — retain segments, do not silently drop.
      appLogger.w(
        '[Engine] Compaction skipped: no LLM service available; '
        'retaining ${_finalizedSegments.length} segments',
      );
      return;
    }

    final toArchive = List<TranscriptSegment>.from(
      _finalizedSegments.sublist(0, 100),
    );
    _compactionInFlight = true;

    // Await-async pattern: do the archive first, then remove. On unexpected
    // failure (compactOldSegments catches LLM errors internally but the
    // Future itself could still fail on programmer error), retain segments.
    _sessionContextManager
        .compactOldSegments(toArchive, llmService)
        .then((_) {
          // Only remove segments once archiving has a home for them.
          // Additional safety: verify the first 100 are still the same
          // segments we started archiving (no reentrant modification).
          final stillSafeToRemove =
              _finalizedSegments.length >= 100 &&
              identical(_finalizedSegments[0], toArchive[0]) &&
              identical(_finalizedSegments[99], toArchive[99]);
          if (stillSafeToRemove) {
            _finalizedSegments.removeRange(0, 100);
            appLogger.d(
              '[Engine] Compacted: archived 100, '
              '${_finalizedSegments.length} remaining',
            );
          } else {
            appLogger.w(
              '[Engine] Segment list mutated during compaction; '
              'archive succeeded but skipping range removal this cycle',
            );
          }
          _compactionConsecutiveFailures = 0;
        })
        .catchError((e, st) {
          _compactionConsecutiveFailures++;
          appLogger.w(
            '[Engine] Compaction failed (consecutive=$_compactionConsecutiveFailures), '
            'retaining segments: $e',
          );
        })
        .whenComplete(() {
          _compactionInFlight = false;
        });
  }

  /// Called when transcription is finalized (segment ends or recording stops).
  ///
  /// Complete sentences have already been finalized progressively by
  /// [onTranscriptionUpdate]. This only needs to finalize the trailing
  /// incomplete sentence (the current partial).
  void onTranscriptionFinalized(
    String text, {
    DateTime? segmentTimestamp,
    String? speakerLabel,
  }) {
    if (!_isActive) return;

    // Phase 0 instrumentation: marker (a) — speech endpoint detected.
    // Advances the turn counter so downstream markers correlate.
    LatencyTracker.instance.beginTurn();
    LatencyTracker.instance.record(
      LatencyMarker.speechEndpoint,
      extra: {'charCount': text.length},
    );

    // Finalize the trailing partial sentence, not the full buffer text
    // (complete sentences were already finalized by onTranscriptionUpdate).
    final toFinalize = _partialTranscription.trim().isNotEmpty
        ? _partialTranscription.trim()
        : text.trim();

    if (toFinalize.isNotEmpty &&
        (_finalizedSegments.isEmpty ||
            _finalizedSegments.last.text != toFinalize)) {
      _finalizedSegments.add(
        TranscriptSegment(
          text: toFinalize,
          timestamp: segmentTimestamp ?? DateTime.now(),
          speakerLabel: speakerLabel,
        ),
      );
    }
    _partialTranscription = '';
    _segmentSentencesFinalized = 0;
    _emitTranscriptSnapshot();

    // Check for behavioral questions in interview mode
    if (_mode == ConversationMode.interview) {
      _checkForBehavioralQuestion(toFinalize);
    }

    // Live translation of finalized segment
    if (SettingsManager.instance.translationEnabled && toFinalize.isNotEmpty) {
      _translateSegment(toFinalize);
    }

    // Sentiment and entity analysis (serialized, non-blocking).
    // These run sequentially to avoid overwhelming the LLM API with parallel
    // requests alongside translation and question analysis.
    _runBackgroundAnalytics();

    // Analyze finalized text immediately.
    if (autoDetectQuestions && answerAll) {
      _scheduleTranscriptAnalysis(immediate: true);
    }
  }

  /// Translate a finalized transcript segment and emit results to [translationStream].
  void _translateSegment(String text) {
    final targetLang = SettingsManager.instance.translationTargetLanguage;
    _translationSubscription?.cancel();

    final buffer = StringBuffer();
    _translationController.add(''); // signal start
    _translationSubscription = TranslationService.instance
        .translate(text, targetLang)
        .listen(
          (chunk) {
            buffer.write(chunk);
            _translationController.add(buffer.toString());
          },
          onDone: () {
            final result = buffer.toString().trim();
            if (result.isNotEmpty) {
              _translationController.add(result);
              // Push translation to glasses HUD
              HudController.instance.updateDisplay(result);
            }
          },
          onError: (e) {
            appLogger.e('[Engine] Translation error', error: e);
          },
        );
  }

  /// Handle AI response text from the OpenAI Realtime API conversation mode.
  void onRealtimeResponse(String text, {required bool isFinal}) {
    if (text.isNotEmpty) {
      _realtimeResponseBuffer += text;
      _latestAssistantResponse = _realtimeResponseBuffer;
      _latestAssistantResponseTimestamp = DateTime.now();
      _streamToGlasses(text, isStreaming: true);
      _aiResponseController.add(_realtimeResponseBuffer);
      _statusController.add(EngineStatus.responding);
    }

    if (isFinal) {
      final fullResponse = _realtimeResponseBuffer.trim();
      if (fullResponse.isNotEmpty) {
        _streamToGlasses('', isStreaming: false);
        _history.add(
          ConversationTurn(
            role: 'assistant',
            content: fullResponse,
            timestamp: DateTime.now(),
            mode: _mode.name,
            assistantProfileId: _activeAssistantProfile().id,
          ),
        );
        _persistHistory();
        _aiResponseController.add(fullResponse);
      }
      _realtimeResponseBuffer = '';
      _statusController.add(
        _isActive ? EngineStatus.listening : EngineStatus.idle,
      );
    }
  }

  /// User explicitly asks a question (Direct Q&A mode)
  /// Works even when engine is not actively listening (standalone text mode)
  Future<void> askQuestion(String question) async {
    if (question.trim().isEmpty) return;

    await TextService.get.stopTextSendingByOS();
    await HudController.instance.beginQuickAsk(
      source: 'ConversationEngine.askQuestion',
    );
    _clearProviderError();

    _history.add(
      ConversationTurn(
        role: 'user',
        content: question,
        timestamp: DateTime.now(),
        mode: _mode.name,
        assistantProfileId: _activeAssistantProfile().id,
      ),
    );
    _persistHistory();

    _aiResponseController.add('');
    final responseToken = _beginResponseCycle();
    _statusController.add(EngineStatus.thinking);
    // User-initiated asks (send button, follow-up chip, response tools:
    // summarize/rephrase/translate/factcheck) must execute even when the
    // OpenAI Realtime transcription backend is active. Without the bypass,
    // `_generateResponse` short-circuits at the realtime guard and every
    // manual action silently no-ops. The auto-answer path in
    // `_handleDetectedQuestion` already passes `bypassRealtimeGuard: true`
    // for the same reason.
    await _generateResponse(
      question,
      responseToken: responseToken,
      bypassRealtimeGuard: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Feature 1: Proactive Suggestions (silence detection)
  // ---------------------------------------------------------------------------

  /// Reset the silence timer; fires after 5s of no new transcription.
  /// Reuses the running timer to avoid cancel/recreate churn (called 5-10x/sec).
  void _resetSilenceTimer() {
    final newTarget = DateTime.now().add(_silenceThreshold);
    if (_silenceTimer?.isActive == true) {
      _silenceTimerTarget = newTarget;
      return;
    }
    _silenceTimerTarget = newTarget;
    _silenceTimer = Timer(_silenceThreshold, _onSilenceCheck);
  }

  void _onSilenceCheck() {
    final remaining = _silenceTimerTarget!.difference(DateTime.now());
    if (remaining > Duration.zero) {
      _silenceTimer = Timer(remaining, _onSilenceCheck);
      return;
    }
    _onSilenceDetected();
  }

  /// Called when no transcription update has arrived for [_silenceThreshold]
  void _onSilenceDetected() {
    if (!_isActive || _silenceSuggestionSent) return;
    if (_currentTranscription.trim().isEmpty) return;
    // When answerAll is off (on-demand mode), silence does NOT trigger automatic suggestions.
    if (!answerAll) return;

    _silenceSuggestionSent = true;
    _generateProactiveSuggestion();
  }

  /// Use the LLM to generate a proactive suggestion based on the conversation
  Future<void> _generateProactiveSuggestion() async {
    if (SettingsManager.instance.usesOpenAIRealtimeSession) {
      return;
    }
    final llmService = _getLlmService();
    if (llmService == null) return;

    // Determine suggestion type based on conversation state
    final recentTurns = _history.length > 4
        ? _history.sublist(_history.length - 4)
        : _history;
    final context = recentTurns
        .map((t) => '${t.role}: ${t.content}')
        .join('\n');
    final isChinese = _language == 'zh';

    final prompt = isChinese
        ? '''根据以下对话，生成一个简短的建议帮助用户继续对话。
从以下三种类型中选择最合适的一种：
1. "topic_change" — 建议一个相关的有趣话题
2. "follow_up" — 建议一个后续问题
3. "insight" — 分享一个关于当前话题的有趣事实

用以下JSON格式回复（不要使用markdown代码块）：
{"type": "类型", "text": "建议内容"}

对话内容：
$context
当前话题：$_currentTranscription'''
        : '''Based on this conversation, generate a brief suggestion to help the user continue.
Pick the most appropriate type:
1. "topic_change" — suggest an interesting related topic
2. "follow_up" — suggest a follow-up question to keep things going
3. "insight" — share a relevant fact or insight about the current topic

Reply in this exact JSON format (no markdown code blocks):
{"type": "the_type", "text": "your suggestion"}

Conversation:
$context
Current topic: $_currentTranscription''';

    try {
      final response = await llmService.getResponse(
        systemPrompt: isChinese
            ? '你是一个对话助手。只用JSON格式回复。'
            : 'You are a conversation assistant. Reply only in JSON format.',
        messages: [ChatMessage(role: 'user', content: prompt)],
        model: SettingsManager.instance.resolvedLightModel,
      );

      final parsed = _parseProactiveSuggestion(response);
      if (parsed != null) {
        _proactiveSuggestionController.add(parsed);
      }
    } catch (e) {
      appLogger.e('Failed to generate proactive suggestion', error: e);
    }
  }

  /// Parse the LLM response into a ProactiveSuggestion
  ProactiveSuggestion? _parseProactiveSuggestion(String response) {
    try {
      // Strip markdown code fences if present
      var cleaned = response.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\n?```$'), '');
        cleaned = cleaned.trim();
      }
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final type = json['type'] as String? ?? 'follow_up';
      final text = json['text'] as String? ?? '';
      if (text.isEmpty) return null;

      SuggestionType suggestionType;
      switch (type) {
        case 'topic_change':
          suggestionType = SuggestionType.topicChange;
          break;
        case 'insight':
          suggestionType = SuggestionType.insight;
          break;
        case 'follow_up':
        default:
          suggestionType = SuggestionType.followUp;
      }

      return ProactiveSuggestion(
        type: suggestionType,
        text: text,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      appLogger.d('Could not parse proactive suggestion: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 2: Interview STAR Coaching
  // ---------------------------------------------------------------------------

  /// Behavioral question patterns that trigger STAR coaching
  static final _behavioralPatterns = [
    RegExp(r'tell me about a time', caseSensitive: false),
    RegExp(r'describe a situation', caseSensitive: false),
    RegExp(r'give me an example', caseSensitive: false),
    RegExp(r'give an example', caseSensitive: false),
    RegExp(r'walk me through', caseSensitive: false),
    RegExp(r'how did you handle', caseSensitive: false),
    RegExp(r'have you ever', caseSensitive: false),
    RegExp(r'describe a time when', caseSensitive: false),
    RegExp(r'can you share an example', caseSensitive: false),
  ];

  static final _behavioralPatternsChinese = [
    RegExp(r'请描述一个'),
    RegExp(r'举个例子'),
    RegExp(r'请举例说明'),
    RegExp(r'分享一个经历'),
    RegExp(r'你是如何处理'),
    RegExp(r'请讲述一次'),
    RegExp(r'能分享一下'),
  ];

  /// Check if the transcription contains a behavioral question and emit coaching
  void _checkForBehavioralQuestion(String text) {
    final isChinese = _language == 'zh';
    final patterns = isChinese
        ? _behavioralPatternsChinese
        : _behavioralPatterns;

    for (final pattern in patterns) {
      if (pattern.hasMatch(text)) {
        // Extract the specific question context
        final match = pattern.firstMatch(text);
        final questionContext = text.substring(match!.start).trim();

        final coaching = isChinese
            ? CoachingPrompt(
                framework: 'STAR',
                prompt: 'STAR方法回答这个行为面试题：',
                steps: [
                  'S（情境）：简要描述你遇到的具体场景',
                  'T（任务）：你需要完成什么任务或目标',
                  'A（行动）：你具体采取了哪些步骤',
                  'R（结果）：取得了什么可量化的成果',
                ],
                questionContext: questionContext,
                timestamp: DateTime.now(),
              )
            : CoachingPrompt(
                framework: 'STAR',
                prompt: 'Use the STAR method for this behavioral question:',
                steps: [
                  'S (Situation): Set the scene briefly',
                  'T (Task): What was your responsibility',
                  'A (Action): Specific steps you took',
                  'R (Result): Measurable outcome achieved',
                ],
                questionContext: questionContext,
                timestamp: DateTime.now(),
              );

        _coachingController.add(coaching);
        appLogger.d(
          'STAR coaching triggered '
          '(questionChars=${questionContext.length})',
        );

        // Push a compact STAR reminder to glasses HUD
        if (_glassesConnectionChecker()) {
          final hudText = coaching.steps.join('\n');
          _streamToGlasses(hudText, isStreaming: false);
        }
        break;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Feature 3: Conversation Summary
  // ---------------------------------------------------------------------------

  /// Generate a brief summary of the current conversation so far.
  /// Returns null if no conversation history exists or LLM is unavailable.
  Future<String?> getSummary() async {
    if (_history.isEmpty) return null;

    final llmService = _getLlmService();
    if (llmService == null) return null;

    final isChinese = _language == 'zh';
    final recentHistory = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : _history;

    final transcript = recentHistory
        .map((t) => '${t.role == 'user' ? 'User' : 'AI'}: ${t.content}')
        .join('\n');

    final prompt = isChinese
        ? '''请用3-5个要点总结以下对话：

$transcript

格式：
- 主要讨论话题
- 关键信息和结论
- 待跟进的问题（如有）'''
        : '''Summarize this conversation in 3-5 bullet points:

$transcript

Format:
- Main topics discussed
- Key takeaways and conclusions
- Open questions to follow up on (if any)''';

    try {
      final response = await llmService.getResponse(
        systemPrompt: isChinese
            ? '你是一个简洁的对话总结助手。用要点格式总结。'
            : 'You are a concise conversation summarizer. Use bullet points.',
        messages: [ChatMessage(role: 'user', content: prompt)],
        model: SettingsManager.instance.resolvedLightModel,
      );
      return response;
    } catch (e) {
      appLogger.e('Failed to generate summary', error: e);
      return null;
    }
  }

  /// Generate a structured post-conversation analysis.
  /// Returns null if no conversation history exists or LLM is unavailable.
  Future<Map<String, dynamic>?> getPostConversationAnalysis() async {
    if (_history.length < 2) return null;

    final llmService = _getLlmService();
    if (llmService == null) return null;

    final isChinese = _language == 'zh';
    final recentHistory = _history.length > 30
        ? _history.sublist(_history.length - 30)
        : _history;

    final transcript = recentHistory
        .map((t) => '${t.role == 'user' ? 'User' : 'AI'}: ${t.content}')
        .join('\n');

    final prompt = isChinese
        ? '''分析以下对话并返回结构化JSON：

$transcript

返回格式（不要使用markdown代码块）：
{"summary": "简要总结", "topics": ["话题1", "话题2"], "actionItems": ["待办1"], "sentiment": "积极/中性/消极"}'''
        : '''Analyze this conversation and return structured JSON:

$transcript

Return format (no markdown code blocks):
{"summary": "brief summary", "topics": ["topic1", "topic2"], "actionItems": ["action1"], "sentiment": "positive/neutral/negative"}''';

    try {
      final response = await llmService.getResponse(
        systemPrompt: isChinese
            ? '你是一个对话分析助手。只用JSON格式回复。'
            : 'You are a conversation analysis assistant. Reply only in JSON format.',
        messages: [ChatMessage(role: 'user', content: prompt)],
        model: SettingsManager.instance.resolvedLightModel,
      );

      final cleaned = _stripMarkdownCodeFence(response);
      final result = jsonDecode(cleaned) as Map<String, dynamic>;
      return result;
    } catch (e) {
      appLogger.e('Failed to generate post-conversation analysis', error: e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Proactive Mode: Manual trigger analysis
  // ---------------------------------------------------------------------------

  /// Trigger a full-session on-demand analysis.
  ///
  /// Called from [forceQuestionAnalysis] when answerAll is off or directly
  /// from the app UI "Analyze" button.
  Future<void> triggerOnDemandAnalysis() async {
    if (!_isActive || answerAll) return;

    _cancelInFlightResponse();
    _clearProviderError();
    _statusController.add(EngineStatus.thinking);

    final settings = SettingsManager.instance;
    final context = _sessionContextManager.buildContextWindow(
      recentSegments: _finalizedSegments,
      partialTranscription: _partialTranscription,
      providerId: settings.activeProviderId,
    );

    if (context.trim().isEmpty) {
      _statusController.add(EngineStatus.listening);
      return;
    }

    final answeredSummary = _sessionContextManager
        .buildAnsweredQuestionsSummary();
    final proactiveSystemPrompt = _getSystemPrompt();

    final messages = [
      ChatMessage(
        role: 'user',
        content:
            '''$context

${answeredSummary.isNotEmpty ? 'PREVIOUSLY ANSWERED:\n$answeredSummary\n' : ''}
Analyze this conversation. Identify unanswered questions, factual claims to verify, or provide contextual insights. Do NOT repeat previously answered questions.
Respond with a JSON preamble on the first line: {"action": "answer"|"fact_check"|"insight", "target": "the question or claim"}
Then your response text.''',
      ),
    ];

    final responseToken = _beginResponseCycle();
    await _generateResponse(
      'proactive analysis',
      overrideMessages: messages,
      overrideSystemPrompt: proactiveSystemPrompt,
      responseToken: responseToken,
    );
  }

  /// Parse the JSON preamble from a proactive response and record it
  /// as an answered question so it won't be repeated.
  void _trackProactiveAnswer(String response) {
    String? parsedAction;
    String? parsedTarget;

    // Try to extract JSON preamble from first line
    final firstNewline = response.indexOf('\n');
    final firstLine = firstNewline > 0
        ? response.substring(0, firstNewline).trim()
        : response.trim();

    try {
      if (firstLine.startsWith('{')) {
        final preamble = jsonDecode(firstLine) as Map<String, dynamic>;
        parsedAction = preamble['action'] as String?;
        parsedTarget = preamble['target'] as String?;
      }
    } on FormatException {
      // Expected: LLM may not produce valid JSON preamble. Proceed with defaults.
    } on TypeError catch (e) {
      appLogger.d('[Engine] Proactive preamble type mismatch: $e');
    }

    _sessionContextManager.addAnsweredQuestion(
      AnsweredQuestion(
        question: parsedTarget ?? 'proactive analysis',
        answer: response,
        timestamp: DateTime.now(),
        action: parsedAction ?? 'insight',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Feature 4: Smart Follow-up Chips
  // ---------------------------------------------------------------------------

  /// Generate contextual follow-up suggestions after an AI response.
  /// Called automatically after each response completes.
  Future<void> _generateFollowUpChips(String aiResponse) async {
    final llmService = _getLlmService();
    if (llmService == null) return;

    final isChinese = _language == 'zh';

    final prompt = isChinese
        ? '''基于这个AI回复，生成2-3个简短的后续问题建议，用户可以点击继续对话。
每个建议不超过10个字。用JSON数组格式回复（不要使用markdown代码块）。

AI回复：$aiResponse

示例格式：["深入讲讲", "举个例子", "如何应用？"]'''
        : '''Based on this AI response, generate 2-3 short follow-up question chips the user can tap to continue the conversation.
Each chip should be under 8 words. Reply as a JSON array only (no markdown code blocks).

AI response: $aiResponse

Example format: ["Tell me more", "Give an example", "How do I apply this?"]''';

    try {
      final response = await llmService.getResponse(
        systemPrompt: isChinese
            ? '你只输出JSON数组，不要其他内容。'
            : 'Output only a JSON array, nothing else.',
        messages: [ChatMessage(role: 'user', content: prompt)],
        model: SettingsManager.instance.resolvedLightModel,
      );

      final chips = _parseFollowUpChips(response);
      if (chips.isNotEmpty) {
        _followUpChipsController.add(chips);
      }
    } catch (e) {
      appLogger.d('Failed to generate follow-up chips: $e');
    }
  }

  /// Parse the LLM response into a list of follow-up chip strings
  List<String> _parseFollowUpChips(String response) {
    try {
      var cleaned = response.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceAll(RegExp(r'\n?```$'), '');
        cleaned = cleaned.trim();
      }
      final decoded = jsonDecode(cleaned) as List<dynamic>;
      return decoded
          .map((e) => (e as String).trim())
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();
    } catch (e) {
      appLogger.d('Could not parse follow-up chips: $e');
      return [];
    }
  }

  Future<void> _backgroundFactCheck(String answer) async {
    if (answer.trim().length < 20) return; // too short to fact-check

    final llmService = _getLlmService();
    if (llmService == null) return;

    final isChinese = _language == 'zh';
    final prompt = isChinese
        ? '检查以下回答的事实准确性。如果所有内容正确，只回复"OK"。如果有错误，用一句话说明纠正。\n\n$answer'
        : 'Check this answer for factual accuracy. If all claims are correct, respond with just "OK". If any claim is wrong, state the correction in one sentence.\n\n$answer';

    try {
      final response = await llmService.getResponse(
        systemPrompt: isChinese
            ? '你是事实核查员。只回复"OK"或一句纠正。'
            : 'You are a fact checker. Reply only with "OK" or a one-sentence correction.',
        messages: [ChatMessage(role: 'user', content: prompt)],
        model: SettingsManager.instance.resolvedLightModel,
      );

      final trimmed = response.trim();
      if (trimmed.toUpperCase() != 'OK' && trimmed.isNotEmpty) {
        appLogger.d(
          '[FactCheck] Correction received '
          '(chars=${trimmed.length})',
        );
        _factCheckAlertController.add(trimmed);
      }
    } catch (e) {
      appLogger.d('Background fact-check failed: $e');
    }
  }

  /// Merged post-response analysis: generates follow-up chips and runs a
  /// fact-check in a single LLM call instead of two separate calls.
  Future<void> _postResponseAnalysis(String question, String response) async {
    if (response.trim().length < 20) return;

    final llmService = _getLlmService();
    if (llmService == null) return;

    final isChinese = _language == 'zh';

    final prompt = isChinese
        ? '''给定以下问答：
Q: $question
A: $response

返回JSON（不要markdown代码块）：
{"chips": ["建议1", "建议2"], "factCheck": "如果有错误写纠正内容，否则写null"}

chips: 2-3个简短后续建议（每个不超过10字）
factCheck: 检查回答中的事实，如果正确写null，如果有错写一句纠正'''
        : '''Given this Q&A:
Q: $question
A: $response

Return JSON (no markdown code blocks):
{"chips": ["suggestion1", "suggestion2"], "factCheck": "any corrections or null"}

chips: 2-3 short follow-up suggestions (under 8 words each)
factCheck: check answer for factual accuracy — "null" if correct, one-sentence correction if wrong''';

    try {
      final result = await llmService.getResponse(
        systemPrompt: isChinese
            ? '只输出JSON，不要其他内容。'
            : 'Output only JSON, nothing else.',
        messages: [ChatMessage(role: 'user', content: prompt)],
        model: SettingsManager.instance.resolvedLightModel,
      );

      final cleaned = _stripMarkdownCodeFence(result);
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;

      // Emit follow-up chips
      final rawChips = decoded['chips'];
      if (rawChips is List) {
        final chips = rawChips
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .take(3)
            .toList();
        if (chips.isNotEmpty) {
          _followUpChipsController.add(chips);
        }
      }

      // Emit fact-check alert if needed
      final factCheck = decoded['factCheck'];
      if (factCheck is String) {
        final trimmed = factCheck.trim();
        if (trimmed.isNotEmpty &&
            trimmed.toLowerCase() != 'null' &&
            trimmed.toUpperCase() != 'OK') {
          appLogger.d(
            '[FactCheck] Correction received '
            '(chars=${trimmed.length})',
          );
          _factCheckAlertController.add(trimmed);
        }
      }
    } catch (e) {
      appLogger.d('Post-response analysis failed, falling back: $e');
      // Fallback: run the original separate calls
      _generateFollowUpChips(response);
      unawaited(_backgroundFactCheck(response));
    }
  }

  /// WS-E: active, web-grounded fact-check.
  ///
  /// Flow:
  /// 1. Gate on `activeFactCheckEnabled` + Tavily key (or injected override).
  /// 2. Web search — reuse the final response as the query (YAGNI v1).
  /// 3. Light-LLM verify with sources inline, parse JSON verdict.
  /// 4. Emit `CitedFactCheckResult` on `_citedFactCheckController`.
  ///
  /// Failures degrade silently to no emission — never affects the primary
  /// answer path. The gate lives inside this method (not at the call site)
  /// so tests can exercise the full pipeline with an injected provider.
  @visibleForTesting
  Future<void> activeFactCheckForTest(String question, String response) =>
      _activeFactCheck(question, response);

  Future<void> _activeFactCheck(String question, String finalResponse) async {
    if (finalResponse.trim().length < 20) return;

    final settings = SettingsManager.instance;
    if (!settings.activeFactCheckEnabled) return;

    WebSearchProvider? provider = webSearchProviderOverride;
    if (provider == null) {
      final key = await settings.tavilyApiKey;
      if (key == null || key.trim().isEmpty) return;
      provider = TavilySearchProvider(apiKey: key.trim());
    }

    final llmService = _getLlmService();
    if (llmService == null) return;

    try {
      final searchResults = await provider.search(
        finalResponse,
        maxResults: settings.activeFactCheckMaxResults,
      );
      if (searchResults.isEmpty) {
        appLogger.d('[ActiveFactCheck] no search results, skipping');
        return;
      }

      final sourcesBuf = StringBuffer();
      for (var i = 0; i < searchResults.length; i++) {
        final r = searchResults[i];
        sourcesBuf.writeln('[${i + 1}] ${r.title}');
        sourcesBuf.writeln(r.url);
        final snippet = r.snippet.length > 480
            ? '${r.snippet.substring(0, 480)}…'
            : r.snippet;
        sourcesBuf.writeln(snippet);
        sourcesBuf.writeln();
      }

      final prompt =
          '''You are fact-checking an AI answer against web sources.

Question: $question
Answer: $finalResponse

Sources:
$sourcesBuf
Reply with JSON only (no markdown code fence):
{"verdict": "supported" | "contradicted" | "unclear",
 "correction": "one-sentence correction or null",
 "citedIndices": [1, 2]}

- "supported" = sources agree with the answer.
- "contradicted" = at least one source clearly contradicts the answer; put the correction in "correction".
- "unclear" = sources are off-topic or ambiguous.
- "citedIndices" = 1-based indices of the sources that informed your verdict.''';

      final raw = await llmService.getResponse(
        systemPrompt: 'Output only JSON, nothing else.',
        messages: [ChatMessage(role: 'user', content: prompt)],
        model: settings.resolvedLightModel,
      );

      final cleaned = _stripMarkdownCodeFence(raw);
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final verdict = factCheckVerdictFromString(
        decoded['verdict'] as String?,
      );
      final rawCorrection = decoded['correction'];
      String? correction;
      if (rawCorrection is String) {
        final t = rawCorrection.trim();
        if (t.isNotEmpty && t.toLowerCase() != 'null') {
          correction = t;
        }
      }

      final citedSet = <int>{};
      final citedRaw = decoded['citedIndices'];
      if (citedRaw is List) {
        for (final v in citedRaw) {
          if (v is int) citedSet.add(v);
          if (v is num) citedSet.add(v.toInt());
        }
      }

      final sources = <CitedSource>[];
      for (var i = 0; i < searchResults.length; i++) {
        if (citedSet.isNotEmpty && !citedSet.contains(i + 1)) continue;
        final r = searchResults[i];
        sources.add(
          CitedSource(
            url: r.url,
            title: r.title,
            snippet: r.snippet,
            score: r.score,
          ),
        );
      }
      // If the LLM returned no indices, fall back to showing all sources.
      if (sources.isEmpty) {
        for (final r in searchResults) {
          sources.add(
            CitedSource(
              url: r.url,
              title: r.title,
              snippet: r.snippet,
              score: r.score,
            ),
          );
        }
      }

      final result = CitedFactCheckResult(
        verdict: verdict,
        correction: correction,
        sources: sources,
      );
      appLogger.d(
        '[ActiveFactCheck] verdict=${verdict.name} '
        'sources=${sources.length} correction=${correction != null}',
      );
      _citedFactCheckController.add(result);
    } catch (e) {
      appLogger.d('[ActiveFactCheck] failed: $e');
    }
  }

  void _emitTranscriptSnapshot() {
    _currentTranscription = _composeFullTranscript();
    if (_currentTranscription == _lastEmittedSnapshot &&
        _partialTranscription == _lastEmittedPartial) {
      return; // nothing changed
    }
    _lastEmittedSnapshot = _currentTranscription;
    _lastEmittedPartial = _partialTranscription;
    final snapshot = TranscriptSnapshot(
      source: _transcriptSource,
      partialText: _partialTranscription,
      finalizedSegments: List.unmodifiable(
        _finalizedSegments.map((s) => s.text).toList(),
      ),
      finalizedTimelineEntries: List.unmodifiable(
        _copyTranscriptSegments(_finalizedSegments),
      ),
      fullTranscript: _currentTranscription,
    );
    _transcriptionController.add(snapshot.fullTranscript);
    _transcriptSnapshotController.add(snapshot);
  }

  String _composeFullTranscript() {
    final parts = <String>[
      ..._finalizedSegments
          .map((s) => s.text)
          .where((text) => text.trim().isNotEmpty),
    ];
    if (_partialTranscription.trim().isNotEmpty) {
      parts.add(_partialTranscription.trim());
    }
    return parts.join('\n');
  }

  void _scheduleTranscriptAnalysis({bool immediate = false}) {
    if (!autoDetectQuestions) return;
    if (SettingsManager.instance.usesOpenAIRealtimeSession) return;

    final token = ++_analysisToken;

    if (immediate) {
      _analysisTimer?.cancel();
      _analyzeRecentTranscriptWindow(token);
      return;
    }

    final newTarget = DateTime.now().add(const Duration(milliseconds: 1500));
    if (_analysisTimer?.isActive == true) {
      _analysisTimerTarget = newTarget;
      return;
    }
    _analysisTimerTarget = newTarget;
    _analysisTimer = Timer(const Duration(milliseconds: 1500), () {
      final remaining = _analysisTimerTarget!.difference(DateTime.now());
      if (remaining > const Duration(milliseconds: 100)) {
        _analysisTimer = Timer(
          remaining,
          () => _analyzeRecentTranscriptWindow(token),
        );
        return;
      }
      _analyzeRecentTranscriptWindow(token);
    });
  }

  String _buildRecentTranscriptWindow() {
    final segments = _finalizedSegments.length > 8
        ? _finalizedSegments.sublist(_finalizedSegments.length - 8)
        : _finalizedSegments;
    final parts = <String>[];
    for (var i = 0; i < segments.length; i++) {
      if (i > 0) {
        final gap = segments[i].timestamp.difference(segments[i - 1].timestamp);
        if (gap.inMilliseconds > 1000) {
          final seconds = (gap.inMilliseconds / 1000).toStringAsFixed(1);
          parts.add('[${seconds}s pause]');
        }
      }
      parts.add(segments[i].text);
    }
    if (_partialTranscription.trim().isNotEmpty) {
      parts.add(_partialTranscription.trim());
    }

    final window = parts.join('\n');
    if (window.length <= 2000) {
      return window;
    }
    return window.substring(window.length - 2000);
  }

  Future<void> _analyzeRecentTranscriptWindow(int token) async {
    if (!_isActive || token != _analysisToken) return;

    final window = _buildRecentTranscriptWindow();
    if (window.trim().isEmpty) return;

    final llmService = _getLlmService();
    if (llmService == null) {
      if (_lastProviderError?.kind != ProviderErrorKind.missingConfiguration) {
        final errorState = ProviderErrorState.missingConfiguration();
        _publishProviderError(errorState);
        _aiResponseController.add(errorState.userFacingMessage);
      }
      return;
    }

    try {
      final response = await llmService.getResponse(
        systemPrompt: _getListeningAnalysisSystemPrompt(),
        messages: [
          ChatMessage(
            role: 'user',
            content: _buildListeningAnalysisPrompt(window),
          ),
        ],
        model: SettingsManager.instance.resolvedLightModel,
        requestOptions: const LlmRequestOptions(
          operationType: AiOperationType.questionDetection,
          maxOutputTokens: 120,
          reasoningEffort: 'low',
        ),
        onMetadata: _recordLlmMetadata,
      );
      if (!_isActive || token != _analysisToken) return;

      final detection = _parseQuestionDetection(response, window);
      if (detection == null) {
        return;
      }

      final questionKey = _normalizeQuestion(detection.question);
      if (questionKey.isEmpty) {
        return;
      }
      final now = DateTime.now();
      if (questionKey == _lastHandledQuestionKey &&
          _lastHandledQuestionTime != null &&
          now.difference(_lastHandledQuestionTime!).inSeconds < 45) {
        return;
      }

      _lastHandledQuestionKey = questionKey;
      _lastHandledQuestionTime = now;
      _latestQuestionDetection = detection;
      _clearProviderError();
      _questionDetectionController.add(detection);
      _questionDetectedController.add(
        DetectedQuestion(
          question: detection.question,
          fullContext: window,
          timestamp: detection.timestamp,
        ),
      );

      // Phase 0 instrumentation: marker (b) — question detection fires.
      LatencyTracker.instance.record(
        LatencyMarker.questionDetected,
        extra: {
          'source': 'auto',
          'questionLength': detection.question.length,
        },
      );

      _recordDetectedQuestionTurn(detection);

      _aiResponseController.add('');
      if (answerAll) {
        final session = ConversationListeningSession.instance;
        final shouldPause = session.isRunning;
        if (shouldPause) session.pauseTranscription();
        final responseToken = _beginResponseCycle();
        _statusController.add(EngineStatus.thinking);
        _isGeneratingResponse = true;
        try {
          await _generateResponse(
            detection.question,
            overrideMessages: _buildAutoAnswerMessages(
              detection,
              transcriptWindow: window,
            ),
            responseToken: responseToken,
          );
        } finally {
          _isGeneratingResponse = false;
          if (shouldPause) session.resumeTranscription();
        }
      }
    } catch (error) {
      appLogger.e('Failed to analyze transcript window', error: error);
      final errorState = ProviderErrorState.fromException(error);
      _publishProviderError(errorState);
      _aiResponseController.add(errorState.userFacingMessage);
    }
  }

  String _buildListeningAnalysisPrompt(String window) {
    final isChinese = _language == 'zh';
    final historyContext = _buildRecentQaContext();
    if (isChinese) {
      return '''分析下面这段最近对话，判断另一人(OTHER)是否提出了佩戴者需要帮助回答的问题。

要求：
- 如果没有明确问题，返回 shouldRespond=false，并把 question 和 questionExcerpt 设为空字符串。
- 如果有问题，question 提炼成一句话。
- questionExcerpt 必须尽量直接复制最近对话窗口里对应问题的原文片段；如果做不到就返回空字符串。
- 使用时间间隔标记 [X.Xs pause] 来推断说话人轮次——较长停顿通常表示说话人切换。
- askedBy 设为 "other"（对方提问）或 "wearer"（佩戴者提问）。

最近问答历史：
$historyContext

最近对话窗口：
$window''';
    }

    return '''Analyze this recent conversation window and decide whether the OTHER PERSON has asked a question that the WEARER needs help answering.

Rules:
- If there is no clear question, return shouldRespond=false and leave question and questionExcerpt empty.
- If there is a question, extract it as one sentence.
- questionExcerpt should be a verbatim excerpt from the recent conversation window when possible. If you cannot quote it exactly, return an empty string.
- Use timing gap markers [X.Xs pause] to infer speaker turns — longer pauses often indicate a speaker change.
- Set askedBy to "other" (the other person asked) or "wearer" (the glasses wearer asked).

Recent Q/A memory:
$historyContext

Recent conversation window:
$window''';
  }

  String _buildRecentQaContext() {
    if (_history.isEmpty) {
      return _language == 'zh' ? '无' : 'None';
    }

    final recentTurns = _history.length > 6
        ? _history.sublist(_history.length - 6)
        : _history;
    return recentTurns
        .map((turn) => '${turn.role}: ${turn.content}')
        .join('\n');
  }

  String _getListeningAnalysisSystemPrompt() {
    final isChinese = _language == 'zh';
    final profileInstruction = _activeAssistantProfile().promptDirective(
      isChinese: isChinese,
    );
    if (isChinese) {
      return '''你是一个实时对话分析助手。这段文字记录了一场两人对话。佩戴者(WEARER)戴着AI眼镜需要帮助。另一人(OTHER)是他们的对话对象。

阅读最近对话窗口，判断另一人(OTHER)是否提出了佩戴者可能需要帮助回答的问题。

规则：
- 只有当另一人(OTHER)提出问题时才设置 shouldRespond=true
- 如果佩戴者(WEARER)提出问题，那是在问对方的——不要回答
- 使用时间间隔 [X.Xs pause] 作为说话人轮次的线索——较长的停顿通常表示不同的说话人

只输出 JSON，不要 markdown，不要额外解释。
JSON 格式必须是：
{"shouldRespond": true/false, "question": "...", "questionExcerpt": "...", "askedBy": "other"|"wearer"}

$profileInstruction''';
    }

    return '''You are a live conversation analysis assistant. This transcript captures a two-person conversation. The WEARER has AI glasses and needs help. The OTHER PERSON is who they are talking to.

Read the latest conversation window and decide if the OTHER PERSON has asked a question that the WEARER might need help answering right now.

Rules:
- Only set shouldRespond=true when the OTHER PERSON asks a question
- If the WEARER asks a question, they are directing it at the other person — do NOT answer it
- Use timing gaps [X.Xs pause] as hints for speaker turns — longer pauses often indicate a different speaker
- Output JSON only. No markdown and no extra commentary.

JSON shape: {"shouldRespond": true/false, "question": "...", "questionExcerpt": "...", "askedBy": "other"|"wearer"}

If the question is just social small talk or does not need AI help, set shouldAnswer=false and category to "social", "phatic", or "small_talk".
Examples that should NOT be answered: "How are you?", "How's your day going?", "How's your experience?"

Extended JSON shape: {"shouldRespond": true/false, "shouldAnswer": true/false, "category": "...", "reason": "...", "question": "...", "questionExcerpt": "...", "askedBy": "other"|"wearer"}

$profileInstruction''';
  }

  QuestionDetectionResult? _parseQuestionDetection(
    String response,
    String window,
  ) {
    try {
      final cleaned = _stripMarkdownCodeFence(response);
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final shouldRespond = decoded['shouldRespond'] == true;
      if (!shouldRespond) {
        return null;
      }

      final shouldAnswer = decoded['shouldAnswer'];
      if (shouldAnswer == false) {
        return null;
      }

      final question = (decoded['question'] as String? ?? '').trim();
      if (question.isEmpty) {
        return null;
      }

      final askedBy = (decoded['askedBy'] as String? ?? 'other').trim();
      if (askedBy == 'wearer') {
        return null;
      }

      return QuestionDetectionResult(
        question: question,
        questionExcerpt: _resolveQuestionExcerpt(
          window,
          (decoded['questionExcerpt'] as String? ?? '').trim(),
          question,
        ),
        timestamp: DateTime.now(),
        askedBy: askedBy,
      );
    } catch (error) {
      appLogger.d('Could not parse question detection: $error');
      return null;
    }
  }

  String _resolveQuestionExcerpt(
    String window,
    String excerptCandidate,
    String question,
  ) {
    for (final candidate in [excerptCandidate, question]) {
      final excerpt = candidate.trim();
      if (excerpt.isEmpty) continue;

      final exactIndex = window.indexOf(excerpt);
      if (exactIndex >= 0) {
        return window.substring(exactIndex, exactIndex + excerpt.length);
      }

      final lowercaseWindow = window.toLowerCase();
      final lowercaseExcerpt = excerpt.toLowerCase();
      final fuzzyIndex = lowercaseWindow.indexOf(lowercaseExcerpt);
      if (fuzzyIndex >= 0) {
        return window.substring(fuzzyIndex, fuzzyIndex + excerpt.length);
      }
    }

    return '';
  }

  List<TranscriptSegment> _copyTranscriptSegments(
    Iterable<TranscriptSegment> segments,
  ) {
    return segments
        .map(
          (segment) => TranscriptSegment(
            text: segment.text,
            timestamp: segment.timestamp,
            speakerLabel: segment.speakerLabel,
          ),
        )
        .toList(growable: false);
  }

  void _recordDetectedQuestionTurn(QuestionDetectionResult detection) {
    final normalizedQuestion = _normalizeQuestion(detection.question);
    final lastUserTurn = _history.reversed.cast<ConversationTurn?>().firstWhere(
      (turn) => turn?.role == 'user',
      orElse: () => null,
    );
    if (lastUserTurn != null &&
        _normalizeQuestion(lastUserTurn.content) == normalizedQuestion) {
      return;
    }

    _history.add(
      ConversationTurn(
        role: 'user',
        content: detection.question,
        timestamp: detection.timestamp,
        mode: _mode.name,
        assistantProfileId: _activeAssistantProfile().id,
      ),
    );
    _persistHistory();
  }

  bool _looksLikeQuestionText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.contains('?') || trimmed.contains('？')) {
      return true;
    }

    final lowered = trimmed.toLowerCase();
    if (RegExp(
      r'^(what|when|where|why|who|whom|whose|which|how|can|could|would|should|do|does|did|is|are|am|will|have|has|had|may)\b',
    ).hasMatch(lowered)) {
      return true;
    }

    // Chinese question markers (吗/呢/吧 at end, or question words anywhere)
    if (RegExp(r'[吗嘛呢吧]$').hasMatch(trimmed) ||
        RegExp(r'(什么|怎么|为什么|哪里|哪个|谁|几|多少|是否|能否|如何|何时|何处)').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  String _extractNearbyQuestionText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final explicitQuestions = RegExp(
      r'[^?？]*[?？]',
    ).allMatches(trimmed).toList();
    if (explicitQuestions.isNotEmpty) {
      return explicitQuestions.last.group(0)!.trim();
    }

    return trimmed;
  }

  QuestionDetectionResult? _buildManualQuestionDetection(
    String transcriptWindow,
  ) {
    final currentDetection = _latestQuestionDetection;
    if (currentDetection != null) {
      final excerpt = _resolveQuestionExcerpt(
        transcriptWindow,
        currentDetection.questionExcerpt,
        currentDetection.question,
      );
      if (excerpt.isNotEmpty ||
          transcriptWindow.toLowerCase().contains(
            currentDetection.question.toLowerCase(),
          )) {
        return QuestionDetectionResult(
          question: currentDetection.question,
          questionExcerpt: excerpt,
          timestamp: DateTime.now(),
          askedBy: currentDetection.askedBy,
          // TODO(plan-A): remove shim once feat/2026-04-06-priority-rework
          // Phase 1a lands and merges. Manual builder always means user
          // explicitly triggered a Q&A request.
          priority: QuestionPriority.manual,
        );
      }
    }

    final candidates = <TranscriptSegment>[
      ..._finalizedSegments.reversed,
      if (_partialTranscription.trim().isNotEmpty)
        TranscriptSegment(
          text: _partialTranscription.trim(),
          timestamp: DateTime.now(),
        ),
    ];

    for (final segment in candidates) {
      if (!_looksLikeQuestionText(segment.text)) {
        continue;
      }
      final question = _extractNearbyQuestionText(segment.text);
      if (question.isEmpty) {
        continue;
      }
      return QuestionDetectionResult(
        question: question,
        questionExcerpt: _resolveQuestionExcerpt(
          transcriptWindow,
          segment.text,
          question,
        ),
        timestamp: DateTime.now(),
        // TODO(plan-A): remove shim once feat/2026-04-06-priority-rework
        // Phase 1a lands and merges.
        priority: QuestionPriority.manual,
      );
    }

    return null;
  }

  Future<void> _runManualContextualQa() async {
    debugPrint('[Engine] _runManualContextualQa called, isActive=$_isActive, '
        'segments=${_finalizedSegments.length}, partial="${_partialTranscription.length > 40 ? _partialTranscription.substring(0, 40) : _partialTranscription}"');
    if (!_isActive) {
      debugPrint('[Engine] _runManualContextualQa aborted: not active');
      return;
    }

    _analysisTimer?.cancel();
    _analysisToken++;
    _clearProviderError();
    _cancelInFlightResponse();

    final transcriptWindow = _buildRecentTranscriptWindow();
    debugPrint('[Engine] _runManualContextualQa transcriptWindow length=${transcriptWindow.length}');
    if (transcriptWindow.trim().isEmpty) {
      debugPrint('[Engine] _runManualContextualQa aborted: empty transcript window');
      _statusController.add(
        _isActive ? EngineStatus.listening : EngineStatus.idle,
      );
      return;
    }

    final detection = _buildManualQuestionDetection(transcriptWindow) ??
        // Fallback: the user explicitly pressed Q&A but no question pattern
        // was detected (e.g. Chinese text without '？', or statements only).
        // Use the tail of the transcript as the question so the LLM can
        // still generate a contextual answer.
        QuestionDetectionResult(
          question: _finalizedSegments.isNotEmpty
              ? _finalizedSegments.last.text
              : transcriptWindow.length > 200
                  ? transcriptWindow.substring(transcriptWindow.length - 200)
                  : transcriptWindow,
          questionExcerpt: '',
          timestamp: DateTime.now(),
        );

    _latestQuestionDetection = detection;
    _questionDetectionController.add(detection);
    _questionDetectedController.add(
      DetectedQuestion(
        question: detection.question,
        fullContext: transcriptWindow,
        timestamp: detection.timestamp,
      ),
    );

    // Phase 0 instrumentation: marker (b) — question detection fires
    // (manual / on-demand path).
    LatencyTracker.instance.record(
      LatencyMarker.questionDetected,
      extra: {
        'source': 'manual',
        'questionLength': detection.question.length,
      },
    );

    _recordDetectedQuestionTurn(detection);

    _aiResponseController.add('');
    // NB: previously paused the listening session for the duration of the
    // Q&A LLM call to avoid feedback when voice responses are enabled.
    // That had the (much worse) side effect of dropping the user's live
    // speech for several seconds on every Q&A press.  We now keep the
    // recognizer running throughout — any voice-response feedback should
    // be handled in the voice assistant pipeline, not by killing all
    // transcription.

    final responseToken = _beginResponseCycle();
    _statusController.add(EngineStatus.thinking);
    _isGeneratingResponse = true;
    try {
      await _generateResponse(
        detection.question,
        overrideMessages: _buildAutoAnswerMessages(
          detection,
          transcriptWindow: transcriptWindow,
        ),
        responseToken: responseToken,
        bypassRealtimeGuard: true,
      );
    } finally {
      _isGeneratingResponse = false;
      // Re-arm the analysis timer so auto-detection resumes after a
      // manual Q&A attempt (whether it succeeded or failed).  Without
      // this, the timer cancelled at the top of this method is never
      // rescheduled until new speech arrives — which the user perceives
      // as "transcription stopped working."
      if (_isActive &&
          autoDetectQuestions &&
          answerAll) {
        _scheduleTranscriptAnalysis();
      }
    }
  }

  String _normalizeQuestion(String value) {
    final lowered = value.toLowerCase().trim();
    if (lowered.isEmpty) return '';
    return lowered
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _stripMarkdownCodeFence(String value) {
    var cleaned = value.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceAll(RegExp(r'^```\w*\n?'), '');
      cleaned = cleaned.replaceAll(RegExp(r'\n?```$'), '');
    }
    return cleaned.trim();
  }

  // ---------------------------------------------------------------------------
  // Core response generation
  // ---------------------------------------------------------------------------

  /// Generate AI response and stream to glasses.
  ///
  /// When [overrideMessages] and [overrideSystemPrompt] are provided, they
  /// are used instead of the default context-building logic. This allows
  /// proactive mode to supply its own full-session context.
  Future<void> _generateResponse(
    String question, {
    required int responseToken,
    List<ChatMessage>? overrideMessages,
    String? overrideSystemPrompt,
    bool bypassRealtimeGuard = false,
  }) async {
    if (SettingsManager.instance.usesOpenAIRealtimeSession &&
        !bypassRealtimeGuard) {
      return;
    }
    Timer? flushTimer;
    _lastGlassesFlush = null; // reset rate limit for new response
    try {
      if (!_isResponseCurrent(responseToken)) return;
      _statusController.add(EngineStatus.responding);
      _clearProviderError();

      // Import LlmService dynamically to avoid circular dependency
      final llmService = _getLlmService();
      if (llmService == null) {
        if (!_isResponseCurrent(responseToken)) return;
        final errorState = ProviderErrorState.missingConfiguration();
        _publishProviderError(errorState);
        _aiResponseController.add(errorState.userFacingMessage);
        if (_isResponseCurrent(responseToken)) {
          _statusController.add(
            _isActive ? EngineStatus.listening : EngineStatus.idle,
          );
        }
        return;
      }

      // Phase 1: compose [base system prompt] + [user_prep XML block] in
      // a stable order so OpenAI prompt caching discounts the repeated
      // prefix. assembleSystemPrompt returns the base unchanged when
      // session-prep is disabled or empty.
      final baseSystemPrompt = overrideSystemPrompt ?? _getSystemPrompt();
      // Project RAG enrichment: if an active project is selected, retrieve
      // relevant chunks and prepend them as PROJECT CONTEXT. On any failure
      // (controller not yet loaded, retrieval API down, missing key), fall
      // through silently — user still gets a general-knowledge answer.
      var effectiveBasePrompt = baseSystemPrompt;
      try {
        final activeProjectId =
            ActiveProjectController.instance.activeProjectId;
        if (activeProjectId != null) {
          final rag = await ProjectRagService.instance
              .retrieve(projectId: activeProjectId, query: question);
          if (rag.chunks.isNotEmpty) {
            effectiveBasePrompt =
                ProjectContextFormatter.prepend(baseSystemPrompt, rag.chunks);
            _projectCitationsController.add(rag.chunks);
          }
        }
      } catch (e) {
        appLogger.w('[ConversationEngine] project retrieval failed: $e');
      }
      final systemPrompt = PromptAssembler.assembleSystemPrompt(
        effectiveBasePrompt,
      );
      final messages = overrideMessages ?? _buildContextMessages(question);

      var responseText = '';
      var pendingDelta = '';
      Future<void> flushChain = Future<void>.value();
      final glassesConnected = _glassesConnectionChecker();

      bool firstHudFlushRecorded = false;
      Future<void> flushPendingDelta() {
        flushTimer?.cancel();
        flushTimer = null;
        flushChain = flushChain.then((_) async {
          if (pendingDelta.isEmpty) return;
          if (!_isResponseCurrent(responseToken)) {
            pendingDelta = '';
            return;
          }

          pendingDelta = '';
          _aiResponseController.add(responseText);
          _lastGlassesFlush = DateTime.now();

          if (glassesConnected) {
            await _streamToGlasses(responseText, isStreaming: true);
            // Phase 0 instrumentation: marker (e) — first HUD page pushed.
            // Only the first flush-with-glasses per turn counts; subsequent
            // flushes are downstream page updates, not "first page."
            if (!firstHudFlushRecorded) {
              firstHudFlushRecorded = true;
              LatencyTracker.instance.record(
                LatencyMarker.hudFirstPage,
                extra: {'chars': responseText.length},
              );
            }
          }
        });
        return flushChain;
      }

      void scheduleFlush() {
        if (flushTimer != null) return;
        flushTimer = Timer(_responseFlushInterval, () {
          unawaited(flushPendingDelta());
        });
      }

      final useTools = SettingsManager.instance.webSearchEnabled;
      final tools = useTools ? [WebSearchTool.definition] : <ToolDefinition>[];

      // Tool call loop: stream response, execute any tool calls, re-stream
      var toolMessages = List<ChatMessage>.from(messages);
      const maxToolRounds = 3;
      bool firstTokenRecorded = false;
      for (var round = 0; round <= maxToolRounds; round++) {
        ToolCallRequest? pendingToolCall;

        // Phase 0 instrumentation: marker (c) — LLM request sent.
        // Logged per tool-call round so tool-call retries are visible in the
        // trace. The 'firstTokenRecorded' guard ensures marker (d) fires
        // exactly once per turn regardless of round count.
        LatencyTracker.instance.record(
          LatencyMarker.llmRequestSent,
          extra: {'round': round, 'toolsEnabled': useTools},
        );

        await for (final event in llmService.streamWithTools(
          systemPrompt: systemPrompt,
          messages: toolMessages,
          tools: tools.isEmpty ? null : tools,
          temperature: SettingsManager.instance.temperature,
          model: SettingsManager.instance.resolvedSmartModel,
          requestOptions: LlmRequestOptions(
            operationType: AiOperationType.answerGeneration,
            maxOutputTokens: _answerOutputTokenLimit(),
            reasoningEffort: 'medium',
          ),
          onMetadata: _recordLlmMetadata,
        )) {
          if (!_isResponseCurrent(responseToken)) return;

          switch (event) {
            case TextDelta(:final text):
              // Phase 0 instrumentation: marker (d) — first LLM token received.
              if (!firstTokenRecorded && text.isNotEmpty) {
                firstTokenRecorded = true;
                LatencyTracker.instance.record(
                  LatencyMarker.llmFirstToken,
                  extra: {'round': round},
                );
              }
              if (responseText.isEmpty && text.startsWith('[Error]')) {
                // Diagnostic for Q&A-on-live-session failure — see todo
                // 2026-04-08-qa-button-on-live-session-fails-assistant-
                // request-failed.md. Capture raw error + guard state +
                // engine context so the unknown-bucket fallback in
                // ProviderErrorState can be mapped to a pattern or a
                // root-cause fix. Gated behind kDebugMode per the
                // release-logging cleanup todo.
                if (kDebugMode) {
                  debugPrint(
                    '[ConversationEngine] _generateResponse received [Error] '
                    'delta: "$text" '
                    '(bypassRealtimeGuard=$bypassRealtimeGuard '
                    'mode=${_mode.name} isActive=$_isActive '
                    'glassesConnected=$glassesConnected '
                    'webSearchEnabled=$useTools '
                    'msgCount=${toolMessages.length} '
                    'round=$round)',
                  );
                }
                final errorState = ProviderErrorState.fromException(text);
                _publishProviderError(errorState);
                _statusController.add(
                  _isActive ? EngineStatus.listening : EngineStatus.idle,
                );
                return;
              }
              responseText += text;
              _latestAssistantResponse = responseText;
              _latestAssistantResponseTimestamp = DateTime.now();
              pendingDelta += text;
              if (_shouldFlushBufferedResponse(pendingDelta)) {
                await flushPendingDelta();
              } else {
                scheduleFlush();
              }
            case ToolCallRequest():
              pendingToolCall = event;
            case UsageMetadata():
              // Usage metadata is delivered through the callback path.
              break;
          }
        }

        // If no tool call was requested, we're done streaming
        if (pendingToolCall == null) break;

        // Execute the tool call and feed result back for next round
        await flushPendingDelta();
        final toolResult = await ToolExecutor.execute(
          pendingToolCall.name,
          pendingToolCall.arguments,
        );
        // Add assistant's tool call and tool result to messages for next round
        toolMessages = List.from(toolMessages)
          ..add(ChatMessage(role: 'assistant', content: responseText))
          ..add(
            ChatMessage(
              role: 'user',
              content: '[Tool result for ${pendingToolCall.name}]: $toolResult',
            ),
          );
        responseText = ''; // Reset for next round's text
      }

      await flushPendingDelta();
      if (!_isResponseCurrent(responseToken)) {
        return;
      }

      // Send final page to glasses and enable touchpad scrolling
      if (glassesConnected) {
        await _streamToGlasses(responseText, isStreaming: false);
        EvenAI.hasActiveAnswer = true;
      }

      final finalResponse = responseText;

      // In on-demand mode, parse the JSON preamble and track the answered Q.
      if (!answerAll) {
        _trackProactiveAnswer(finalResponse);
      }

      // Save AI response to history
      _history.add(
        ConversationTurn(
          role: 'assistant',
          content: finalResponse,
          timestamp: DateTime.now(),
          mode: _mode.name,
          assistantProfileId: _activeAssistantProfile().id,
        ),
      );
      _persistHistory();

      if (_isResponseCurrent(responseToken)) {
        _statusController.add(
          _isActive ? EngineStatus.listening : EngineStatus.idle,
        );
      }

      // Merged post-response analysis: follow-up chips + fact-check in one call
      unawaited(_postResponseAnalysis(question, finalResponse));
      // WS-E: additive web-grounded active fact-check (no-op unless enabled).
      unawaited(_activeFactCheck(question, finalResponse));
    } catch (e) {
      if (!_isResponseCurrent(responseToken)) {
        return;
      }
      appLogger.e('Error generating response', error: e);
      final errorState = ProviderErrorState.fromException(e);
      _publishProviderError(errorState);
      _aiResponseController.add(errorState.userFacingMessage);
      if (_isResponseCurrent(responseToken)) {
        _statusController.add(
          _isActive ? EngineStatus.listening : EngineStatus.idle,
        );
      }
    } finally {
      flushTimer?.cancel();
    }
  }

  bool _shouldFlushBufferedResponse(String pendingDelta) {
    if (pendingDelta.isEmpty) return false;

    // Rate-limit BLE writes to avoid saturating the connection
    if (_lastGlassesFlush != null &&
        DateTime.now().difference(_lastGlassesFlush!) < _minFlushInterval) {
      return false;
    }

    if (pendingDelta.length >= _responseFlushThreshold) {
      return true;
    }
    if (pendingDelta.contains('\n') || pendingDelta.contains('\r')) {
      return true;
    }

    final trimmed = pendingDelta.trimRight();
    if (trimmed.isEmpty) {
      return false;
    }

    return trimmed.endsWith('.') ||
        trimmed.endsWith('!') ||
        trimmed.endsWith('?') ||
        trimmed.endsWith('。') ||
        trimmed.endsWith('！') ||
        trimmed.endsWith('？');
  }

  int _answerOutputTokenLimit() {
    final maxSentences = SettingsManager.instance.maxResponseSentences;
    return (maxSentences * 120).clamp(120, 720);
  }

  void _recordLlmMetadata(LlmResponseMetadata metadata) {
    if (!metadata.usage.hasAnyUsage || metadata.operationType == null) {
      return;
    }

    _conversationCostTracker.recordCompleted(
      operationType: metadata.operationType!,
      providerId: metadata.providerId,
      modelId: metadata.modelId,
      usage: metadata.usage,
      costUsd: PricingRegistry.instance.calculateCostUsd(
        providerId: metadata.providerId,
        modelId: metadata.modelId,
        usage: metadata.usage,
      ),
      modelRole: metadata.modelRole,
    );
  }

  /// Build context messages for the LLM
  List<ChatMessage> _buildContextMessages(
    String currentQuestion, {
    String? transcriptWindow,
  }) {
    final messages = <ChatMessage>[];

    // Add recent conversation history (last 20 turns)
    final recentHistory = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : _history;

    for (final turn in recentHistory) {
      messages.add(
        ChatMessage(
          role: turn.role,
          content: turn.content,
          timestamp: turn.timestamp,
        ),
      );
    }

    final trimmedWindow = transcriptWindow?.trim() ?? '';
    if (trimmedWindow.isNotEmpty) {
      messages.add(
        ChatMessage(
          role: 'user',
          content: _buildTranscriptContextPrompt(
            transcriptWindow: trimmedWindow,
            question: currentQuestion,
          ),
        ),
      );
      return messages;
    }

    // Add current question if not already in history
    if (messages.isEmpty || messages.last.content != currentQuestion) {
      messages.add(ChatMessage(role: 'user', content: currentQuestion));
    }

    return messages;
  }

  List<ChatMessage> _buildAutoAnswerMessages(
    QuestionDetectionResult detection, {
    required String transcriptWindow,
  }) {
    final recentHistory = _history.length > 20
        ? _history.sublist(_history.length - 20)
        : _history;
    final messages = <ChatMessage>[];

    for (final turn in recentHistory) {
      final isCurrentDetectedQuestion =
          turn.role == 'user' &&
          _normalizeQuestion(turn.content) ==
              _normalizeQuestion(detection.question);
      if (isCurrentDetectedQuestion) {
        continue;
      }
      messages.add(
        ChatMessage(
          role: turn.role,
          content: turn.content,
          timestamp: turn.timestamp,
        ),
      );
    }

    messages.add(
      ChatMessage(
        role: 'user',
        content: _buildTranscriptContextPrompt(
          transcriptWindow: transcriptWindow,
          question: detection.question,
          questionExcerpt: detection.questionExcerpt,
        ),
      ),
    );
    return messages;
  }

  String _buildTranscriptContextPrompt({
    required String transcriptWindow,
    required String question,
    String? questionExcerpt,
  }) {
    final excerpt = questionExcerpt?.trim() ?? '';
    if (_language == 'zh') {
      return '''最近对话上下文：
$transcriptWindow

${excerpt.isNotEmpty ? '原始提问片段：$excerpt\n' : ''}需要回答的问题：
$question

请基于最近对话上下文，直接给出佩戴者可以说出口的回答。''';
    }

    return '''Recent conversation context:
$transcriptWindow

${excerpt.isNotEmpty ? 'Verbatim question excerpt: $excerpt\n' : ''}Question to answer:
$question

Answer the detected question directly using the recent conversation context above.''';
  }

  /// Get the current language setting
  String get _language => SettingsManager.instance.language;

  /// Get system prompt for current mode, localized to selected language
  /// Returns cached KB context, refreshing asynchronously every 60 seconds.
  String _getKbContext() {
    final now = DateTime.now();
    if (_lastKbContextRefresh == null ||
        now.difference(_lastKbContextRefresh!).inSeconds > 60) {
      _lastKbContextRefresh = now;
      UserKnowledgeBase.instance
          .buildContextSummary()
          .then((ctx) {
            _cachedKbContext = ctx;
          })
          .catchError((_) {});
    }
    return _cachedKbContext;
  }

  String _getSystemPrompt() {
    final isChinese = _language == 'zh';
    final langInstruction = isChinese
        ? '\n\nIMPORTANT: Always respond in Chinese (中文). Use natural, conversational Chinese.'
        : '';
    final profile = _activeAssistantProfile();
    final profileInstruction = profile.promptDirective(isChinese: isChinese);
    final maxSentences = SettingsManager.instance.maxResponseSentences;

    final persona = profile.systemPrompt?.trim().isNotEmpty == true
        ? profile.systemPrompt!.trim()
        : _defaultPersona(isChinese);
    final rules = _modeRules(isChinese, maxSentences);

    // For interview/technical profiles, always prepend STAR coaching context
    final interviewPrefix = (profile.engineModeName == 'interview')
        ? _interviewCoachingPrefix(isChinese)
        : '';

    final kbContext = _getKbContext();
    final contextBlock = kbContext.isNotEmpty ? '\n\n$kbContext' : '';
    return '$interviewPrefix$persona\n\n$rules$langInstruction\n\n$profileInstruction$contextBlock';
  }

  String _defaultPersona(bool isChinese) {
    if (isChinese) {
      return '你是智能眼镜上的对话伙伴，帮助用户进行更好的对话。';
    }
    return 'You are a conversation companion on smart glasses helping the user have better conversations.';
  }

  String _interviewCoachingPrefix(bool isChinese) {
    if (isChinese) {
      return '你是智能眼镜上的面试教练。直接给出用户应该说的话。\n\n';
    }
    return 'You are an interview coach on smart glasses. Output exactly what the user should say.\n\n';
  }

  String _modeRules(bool isChinese, int maxSentences) {
    if (isChinese) {
      return '规则：最多$maxSentences句话。直接给出答案，禁止说"你可以说"或"这是建议"。用自然口语，不用列表格式。';
    }
    return 'Rules: Max $maxSentences sentences. Give the answer directly — never write "you could say" or "here\'s a suggestion". Use natural spoken language, no lists or formatting.';
  }

  /// Send text to glasses HUD with proper pagination.
  ///
  /// Always sends a full-canvas frame (`0x31` while streaming, `0x40` when
  /// complete) with `pos: 0`. The G1 firmware does not reliably support
  /// append-at-`pos` semantics — see docs/research/ and the G1 BLE protocol
  /// notes ("no append on pos, no scroll command"). A previous attempt to
  /// stream deltas (commit 10905f7) caused the left lens to get stuck on the
  /// EvenAI listening screen because L's `requestList` ACK pipeline timed out
  /// on the malformed delta packets while R happened to settle on the first
  /// full-canvas frame.
  Future<void> _sendToGlasses(String text, {required bool isStreaming}) async {
    final paginator = TextPaginator.instance;
    paginator.paginateText(text);

    final screenCode = HudDisplayState.aiFrame(isStreaming: isStreaming);
    final currentPage = paginator.pageCount > 0 ? paginator.pageCount : 1;

    try {
      await Proto.sendEvenAIData(
        paginator.currentPageText.isNotEmpty ? paginator.currentPageText : text,
        newScreen: screenCode,
        pos: 0,
        current_page_num: currentPage,
        max_page_num: paginator.pageCount,
      );
    } catch (e) {
      appLogger.e('Failed to send to glasses', error: e);
    }
  }

  // ---- HUD line-streaming (flag-gated, default off) -----------------------
  HudStreamSession? _hudStreamSession;
  String _hudStreamAccumulated = '';
  HudPacketSink Function()? _hudPacketSinkFactoryForTest;

  /// Test seam: inject a custom HudPacketSink factory used by the line-
  /// streaming path. Set to null to restore the production [ProtoHudPacketSink].
  static void setHudPacketSinkFactoryForTest(
    HudPacketSink Function()? factory,
  ) {
    instance._hudPacketSinkFactoryForTest = factory;
  }

  /// Test seam: emit a conversation-saved event. Used by integration tests
  /// that need to verify downstream listeners (e.g. SessionPrepService)
  /// respond to the conversation-end boundary without driving a full
  /// persist-to-database flow.
  @visibleForTesting
  void debugEmitSessionSaved(String conversationId) {
    _sessionSavedController.add(conversationId);
  }

  /// Test seam: count of finalized segments (BUG-005 regression tests).
  @visibleForTesting
  int get debugFinalizedSegmentCount => _finalizedSegments.length;

  /// Test seam: consecutive compaction failure counter (BUG-005 regression).
  @visibleForTesting
  int get debugCompactionConsecutiveFailures =>
      _compactionConsecutiveFailures;

  /// Test seam: whether a compaction Future is in flight.
  @visibleForTesting
  bool get debugCompactionInFlight => _compactionInFlight;

  /// Test seam: append a finalized segment without going through the full
  /// transcription pipeline (BUG-005 regression tests need 200+ segments).
  @visibleForTesting
  void debugAppendFinalizedSegment(TranscriptSegment seg) {
    _finalizedSegments.add(seg);
  }

  /// Test seam: invoke the cap/compaction routine directly.
  @visibleForTesting
  void debugTriggerCompactAndCap() => _compactAndCapSegments();

  /// Test seam: drive the streaming HUD path directly. Production callers
  /// should not use this — it exists so unit tests can exercise the
  /// HudStreamSession routing without spinning up a full LLM stream.
  @visibleForTesting
  Future<void> debugStreamToGlasses(
    String text, {
    required bool isStreaming,
  }) =>
      _streamToGlasses(text, isStreaming: isStreaming);

  /// Test seam: clear any active line-streaming session (mirrors what
  /// `_beginResponseCycle` does for a new response).
  @visibleForTesting
  void debugResetHudStreamSession() => _resetHudStreamSession();

  Future<void> _streamToGlasses(String text, {required bool isStreaming}) {
    if (!SettingsManager.instance.hudLineStreamingEnabled) {
      return _glassesSender(text, isStreaming: isStreaming);
    }
    return _streamToGlassesViaSession(text, isStreaming: isStreaming);
  }

  Future<void> _streamToGlassesViaSession(
    String text, {
    required bool isStreaming,
  }) async {
    if (!isStreaming) {
      final session = _hudStreamSession;
      _hudStreamSession = null;
      _hudStreamAccumulated = '';
      if (session == null) {
        // No active session — fall through to legacy sender so the final
        // text-HUD path still wins for non-streaming writes.
        await _glassesSender(text, isStreaming: false);
        return;
      }
      await session.finish();
      return;
    }

    // Streaming branch.
    if (_hudStreamSession == null) {
      final factory = _hudPacketSinkFactoryForTest;
      final HudPacketSink sink = factory != null
          ? factory()
          : const ProtoHudPacketSink();
      _hudStreamSession = HudStreamSession(sink: sink);
      _hudStreamAccumulated = '';
    }

    // Compute delta. The LLM streaming loop passes accumulated snapshots
    // (each call's `text` extends the previous). The realtime API path passes
    // raw deltas. Detect snapshot-mode via prefix check; otherwise treat the
    // input as a raw delta to append.
    String delta;
    if (text.startsWith(_hudStreamAccumulated)) {
      delta = text.substring(_hudStreamAccumulated.length);
      _hudStreamAccumulated = text;
    } else {
      delta = text;
      _hudStreamAccumulated = _hudStreamAccumulated + text;
    }
    if (delta.isEmpty) return;
    await _hudStreamSession!.appendDelta(delta);
  }

  void _resetHudStreamSession() {
    if (!SettingsManager.instance.hudLineStreamingEnabled) return;
    final old = _hudStreamSession;
    _hudStreamSession = null;
    _hudStreamAccumulated = '';
    if (old != null) {
      unawaited(old.cancel());
    }
  }

  /// Get LlmService instance (lazy to avoid import cycles)
  LlmService? _getLlmService() {
    try {
      return _llmServiceGetter?.call();
    } on StateError catch (e) {
      // Expected: no provider registered yet (user hasn't configured API key).
      appLogger.d('[Engine] LLM service unavailable: ${e.message}');
      return null;
    }
  }

  // Setter for dependency injection
  static LlmService Function()? _llmServiceGetter;
  late Future<void> Function(String text, {required bool isStreaming})
  _glassesSender = _sendToGlasses;
  bool Function() _glassesConnectionChecker = BleManager.isBothConnected;

  static void setLlmServiceGetter(LlmService Function() getter) {
    _llmServiceGetter = getter;
  }

  static void setGlassesSender(
    Future<void> Function(String text, {required bool isStreaming}) sender,
  ) {
    instance._glassesSender = sender;
  }

  static void setGlassesConnectionChecker(bool Function() checker) {
    instance._glassesConnectionChecker = checker;
  }

  static void resetTestHooks() {
    instance._glassesSender = instance._sendToGlasses;
    instance._glassesConnectionChecker = BleManager.isBothConnected;
  }

  /// Load persisted history from SharedPreferences
  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        final turns = jsonList
            .map((e) => ConversationTurn.fromJson(e as Map<String, dynamic>))
            .toList();
        _history.addAll(turns);
        appLogger.d('Loaded ${turns.length} conversation turns from storage');
      }
    } catch (e) {
      appLogger.e('Failed to load conversation history', error: e);
    }
  }

  /// Persist current history to SharedPreferences.
  ///
  /// Debounced to at most once per 30 seconds to avoid excessive disk I/O
  /// during active conversations. [stop()] resets the debounce so the final
  /// state is always persisted.
  Future<void> _persistHistory() async {
    final now = DateTime.now();
    if (_lastPersistTime != null &&
        now.difference(_lastPersistTime!) < _persistDebounce) {
      return;
    }
    _lastPersistTime = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only the last _maxStoredTurns
      final turnsToStore = _history.length > _maxStoredTurns
          ? _history.sublist(_history.length - _maxStoredTurns)
          : _history;
      final jsonString = json.encode(
        turnsToStore.map((t) => t.toJson()).toList(),
      );
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      appLogger.e('Failed to persist conversation history', error: e);
    }
  }

  /// Clear all history.
  ///
  /// WS-B Fix 2: when a live session is active, only clear the stored
  /// conversation history and persist — do NOT wipe the in-memory live
  /// transcript/snapshot. This prevents the History tab "Clear history"
  /// button (or any other mid-session caller) from blanking the Home
  /// live page. Callers that truly need to reset live state mid-session
  /// can pass [force]: true.
  void clearHistory({bool force = false}) {
    if (_isActive && !force) {
      _history.clear();
      _lastPersistTime = null; // bypass debounce for clearHistory
      _persistHistory();
      appLogger.i(
        'ConversationEngine.clearHistory() while active: cleared stored '
        'history only; live transcript preserved',
      );
      return;
    }
    _resetLiveSessionState(clearConversationHistory: true);
    _lastPersistTime = null; // bypass debounce for clearHistory
    _persistHistory();
  }

  void _resetLiveSessionState({required bool clearConversationHistory}) {
    if (clearConversationHistory) {
      _history.clear();
    }
    _analysisTimer?.cancel();
    _silenceTimer?.cancel();
    _translationSubscription?.cancel();
    _translationSubscription = null;
    _currentTranscription = '';
    _partialTranscription = '';
    _finalizedSegments.clear();
    _realtimeResponseBuffer = '';
    _latestAssistantResponse = '';
    _latestAssistantResponseTimestamp = null;
    _lastHandledQuestionKey = '';
    _lastHandledQuestionTime = null;
    _latestQuestionDetection = null;
    _sessionStopHandled = false;
    _lastEmittedSnapshot = '__session_reset__';
    _lastEmittedPartial = '__session_reset__';
    _followUpChipsController.add(const []);
    _aiResponseController.add('');
    _postConversationController.add(null);
    _emitTranscriptSnapshot();
  }

  void _ensureTranscriptHistorySnapshot() {
    if (_history.isNotEmpty || _finalizedSegments.isEmpty) {
      return;
    }

    final transcript = _finalizedSegments
        .map((segment) => segment.text.trim())
        .where((segment) => segment.isNotEmpty)
        .join('\n\n');
    if (transcript.isEmpty) {
      return;
    }

    _history.add(
      ConversationTurn(
        role: 'user',
        content: transcript,
        timestamp: _finalizedSegments.first.timestamp,
        mode: _mode.name,
        assistantProfileId: SettingsManager.instance.assistantProfileId,
      ),
    );
  }

  int _beginResponseCycle() {
    _latestAssistantResponse = '';
    _latestAssistantResponseTimestamp = null;
    _responseToken++;
    _resetHudStreamSession();
    return _responseToken;
  }

  void _cancelInFlightResponse() {
    _responseToken++;
    _resetHudStreamSession();
  }

  bool _isResponseCurrent(int token) => token == _responseToken;

  void _publishProviderError(ProviderErrorState state) {
    _lastProviderError = state;
    _providerErrorController.add(state);
  }

  AssistantProfile _activeAssistantProfile() {
    return SettingsManager.instance.resolveAssistantProfile();
  }

  void _clearProviderError() {
    _lastProviderError = null;
    _providerErrorController.add(null);
  }

  // ---------------------------------------------------------------------------
  // Periodic Analysis Helpers
  // ---------------------------------------------------------------------------

  bool _analyticsRunning = false;

  /// Timeout for each individual background analytics call to prevent
  /// permanent lockout if an LLM call hangs.
  static const _analyticsTimeout = Duration(seconds: 30);

  /// Runs sentiment analysis then entity extraction sequentially so they
  /// never overlap with each other. Skips if a prior run is still in-flight.
  /// Each call is individually guarded by [_analyticsTimeout] to prevent
  /// a hung LLM call from permanently disabling analytics.
  Future<void> _runBackgroundAnalytics() async {
    if (_analyticsRunning) return;
    _analyticsRunning = true;
    try {
      await _maybeTriggerSentimentAnalysis().timeout(
        _analyticsTimeout,
        onTimeout: () {
          appLogger.w('[Engine] Sentiment analysis timed out');
        },
      );
      await _maybeTriggerEntityExtraction().timeout(
        _analyticsTimeout,
        onTimeout: () {
          appLogger.w('[Engine] Entity extraction timed out');
        },
      );
    } finally {
      _analyticsRunning = false;
    }
  }

  /// Joins the last [count] finalized segment texts, or returns null if
  /// there are fewer than [count] segments available.
  String? _recentSegmentText(int count) {
    if (_finalizedSegments.length < count) return null;
    return _finalizedSegments
        .skip(_finalizedSegments.length - count)
        .map((s) => s.text)
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // Sentiment Analysis
  // ---------------------------------------------------------------------------

  /// Analyze the sentiment of recent conversation segments.
  /// Called every 3rd finalized segment when sentimentMonitorEnabled is true.
  Future<void> _maybeTriggerSentimentAnalysis() async {
    if (!SettingsManager.instance.sentimentMonitorEnabled) return;

    _sentimentSegmentCounter++;
    if (_sentimentSegmentCounter % 3 != 0) return;

    final recentText = _recentSegmentText(3);
    if (recentText == null) return;

    await _runSentimentAnalysis(recentText);
  }

  Future<void> _runSentimentAnalysis(String text) async {
    final llm = _getLlmService();
    if (llm == null) return;

    try {
      final response = await llm.getResponse(
        systemPrompt:
            'You are a sentiment analyzer. Rate the sentiment of the given text '
            'from -1.0 (very negative) to 1.0 (very positive). '
            'Reply with ONLY a single number, nothing else.',
        messages: [ChatMessage(role: 'user', content: text)],
        model: SettingsManager.instance.resolvedLightModel,
      );

      // Guard: engine may have stopped while awaiting the LLM response.
      if (!_isActive) return;

      // LLMs sometimes wrap the number in text like "The sentiment is 0.5".
      // Extract the first decimal number from the response.
      final numMatch = RegExp(r'-?\d+\.?\d*').firstMatch(response.trim());
      final parsed = numMatch != null
          ? double.tryParse(numMatch.group(0)!)
          : null;
      if (parsed != null && parsed >= -1.0 && parsed <= 1.0) {
        _sentimentController.add(parsed);
      } else {
        appLogger.d(
          '[Engine] Sentiment response unparseable: '
          '"${response.trim().length > 60 ? '${response.trim().substring(0, 60)}...' : response.trim()}"',
        );
      }
    } catch (e) {
      appLogger.w('[Engine] Sentiment analysis failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Entity Extraction
  // ---------------------------------------------------------------------------

  /// Extract entities from recent conversation segments.
  /// Called every 2nd finalized segment when entityMemoryEnabled is true.
  Future<void> _maybeTriggerEntityExtraction() async {
    if (!SettingsManager.instance.entityMemoryEnabled) return;

    _entitySegmentCounter++;
    if (_entitySegmentCounter % 2 != 0) return;

    final recentText = _recentSegmentText(2);
    if (recentText == null) return;

    await _runEntityExtraction(recentText);
  }

  Future<void> _runEntityExtraction(String text) async {
    final llm = _getLlmService();
    if (llm == null) return;

    try {
      final response = await llm.getResponse(
        systemPrompt:
            'Extract any person or company names from the given text. '
            'For each, provide: name, title (if mentioned), company (if mentioned). '
            'Reply as a JSON array: [{"name":"...","title":"...","company":"..."}]. '
            'If no entities are found, reply with an empty array: []',
        messages: [ChatMessage(role: 'user', content: text)],
        model: SettingsManager.instance.resolvedLightModel,
      );

      // Guard: engine may have stopped while awaiting the LLM response.
      if (!_isActive) return;

      final trimmed = response.trim();
      // Find the JSON array in the response
      final startIndex = trimmed.indexOf('[');
      final endIndex = trimmed.lastIndexOf(']');
      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) return;

      final jsonStr = trimmed.substring(startIndex, endIndex + 1);
      final decoded = jsonDecode(jsonStr) as List<dynamic>;

      final memory = EntityMemory.instance;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final name = (item['name'] as String?)?.trim();
          if (name == null || name.isEmpty) continue;

          final entity = EntityInfo(
            name: name,
            title: (item['title'] as String?)?.trim(),
            company: (item['company'] as String?)?.trim(),
            lastMentioned: DateTime.now(),
          );
          memory.addEntity(entity);
          _entityController.add(entity);
        }
      }
      await memory.save();
    } catch (e) {
      appLogger.w('[Engine] Entity extraction failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _analysisTimer?.cancel();
    _silenceTimer?.cancel();
    _transcriptionController.close();
    _transcriptSnapshotController.close();
    _aiResponseController.close();
    _modeController.close();
    _questionDetectedController.close();
    _questionDetectionController.close();
    _sessionSavedController.close();
    _statusController.close();
    _proactiveSuggestionController.close();
    _coachingController.close();
    _followUpChipsController.close();
    _providerErrorController.close();
    _postConversationController.close();
    _factCheckAlertController.close();
    _citedFactCheckController.close();
    _projectCitationsController.close();
    _translationSubscription?.cancel();
    _translationController.close();
    _sentimentController.close();
    _entityController.close();
  }

  /// Manually trigger a contextual Q&A pass from the latest transcript.
  ///
  /// This bypasses the realtime-session auto-analysis guard and always tries
  /// to answer the nearest current question using the smart answer path.
  Future<void> forceQuestionAnalysis() async {
    // Phase 0 instrumentation: marker (f) — user hit the touchpad retry.
    // Retry-rate is the single-best proxy for product health (see design doc
    // "push the button to retry" evidence). Logged as its own marker so it
    // is visible in the trace even without a preceding speech-endpoint event.
    LatencyTracker.instance.record(
      LatencyMarker.retryPressed,
      extra: {'answerAll': answerAll},
    );
    LatencyTracker.instance.recordManualRetry();

    if (!answerAll) {
      await triggerOnDemandAnalysis();
    } else {
      await _runManualContextualQa();
    }
  }

  /// Entry point for the QA button (Live Activity, BLE touchpad, etc).
  ///
  /// TODO(plan-A): remove shim once feat/2026-04-06-priority-rework Phase 1a
  /// lands and merges. Plan A introduces the canonical
  /// `handleQAButtonPressed()` on `ConversationEngine`; until then this
  /// thin wrapper just forwards to the existing manual contextual Q&A path.
  Future<void> handleQAButtonPressed() async {
    await _runManualContextualQa();
  }

  /// Simulate a multi-segment transcription session for testing the full
  /// pipeline on the simulator (which has no real microphone).
  /// Each segment is emitted as partial updates then finalized, with gaps
  /// matching real-world behavior (25s segment restarts).
  Future<void> simulateTranscription({
    List<String>? segments,
    Duration segmentDelay = const Duration(milliseconds: 800),
    Duration wordDelay = const Duration(milliseconds: 60),
  }) async {
    final testSegments =
        segments ??
        const [
          'So tell me about your experience with distributed systems and how you handled scaling challenges at your previous company.',
          'That sounds interesting. Can you walk me through a specific example where you had to debug a production issue under pressure?',
          'What tools and methodologies do you use for monitoring and observability in a microservices architecture?',
          'How do you approach mentoring junior engineers while still delivering on your own technical work?',
        ];

    if (!_isActive) {
      start(mode: ConversationMode.interview, source: TranscriptSource.phone);
    }
    _statusController.add(EngineStatus.listening);

    for (var i = 0; i < testSegments.length; i++) {
      final segment = testSegments[i];
      final words = segment.split(' ');

      // Simulate word-by-word partial updates
      for (var w = 1; w <= words.length; w++) {
        final partial = words.sublist(0, w).join(' ');
        onTranscriptionUpdate(partial);
        await Future<void>.delayed(wordDelay);
      }

      // Finalize the segment
      onTranscriptionFinalized(segment, segmentTimestamp: DateTime.now());
      appLogger.i(
        '[Simulation] Segment ${i + 1}/${testSegments.length} finalized: ${segment.length} chars',
      );

      if (i < testSegments.length - 1) {
        await Future<void>.delayed(segmentDelay);
      }
    }
  }
}

/// Conversation modes
enum ConversationMode { general, interview }

enum TranscriptSource { phone, glasses }

/// Engine status
enum EngineStatus { idle, listening, thinking, responding, error }

/// Types of proactive suggestions
enum SuggestionType { topicChange, followUp, insight }

class TranscriptSnapshot {
  const TranscriptSnapshot({
    required this.source,
    required this.partialText,
    required this.finalizedSegments,
    required this.finalizedTimelineEntries,
    required this.fullTranscript,
  });

  final TranscriptSource source;
  final String partialText;
  final List<String> finalizedSegments;
  final List<TranscriptSegment> finalizedTimelineEntries;
  final String fullTranscript;
}

class TranscriptSegment {
  final String text;
  final DateTime timestamp;
  String? speakerLabel; // "me" or "other"
  TranscriptSegment({
    required this.text,
    required this.timestamp,
    this.speakerLabel,
  });
}

/// Origin / priority of a detected question.
///
/// TODO(plan-A): remove shim once feat/2026-04-06-priority-rework Phase 1a
/// lands and merges — at that point this enum will be the canonical version
/// already defined by Plan A and we can drop this duplicate.
enum QuestionPriority {
  /// User explicitly asked (via tap, voice command, or QA button).
  manual,

  /// Background auto-detection from conversation transcript.
  autoDetected,

  /// Fact-check pass over an existing answer.
  factCheck,
}

class QuestionDetectionResult {
  const QuestionDetectionResult({
    required this.question,
    required this.questionExcerpt,
    required this.timestamp,
    this.askedBy = 'other',
    this.priority = QuestionPriority.autoDetected,
  });

  final String question;
  final String questionExcerpt;
  final DateTime timestamp;
  final String askedBy;

  /// TODO(plan-A): remove shim once feat/2026-04-06-priority-rework Phase 1a
  /// lands and merges. Default is `autoDetected` to match the dominant
  /// detection path today (the engine's parser path).
  final QuestionPriority priority;
}

/// A proactive suggestion emitted when silence is detected
class ProactiveSuggestion {
  final SuggestionType type;
  final String text;
  final DateTime timestamp;

  ProactiveSuggestion({
    required this.type,
    required this.text,
    required this.timestamp,
  });

  /// Human-readable label for the suggestion type
  String get typeLabel {
    switch (type) {
      case SuggestionType.topicChange:
        return 'Topic Idea';
      case SuggestionType.followUp:
        return 'Follow Up';
      case SuggestionType.insight:
        return 'Insight';
    }
  }

  /// Icon hint for the suggestion type
  String get typeIcon {
    switch (type) {
      case SuggestionType.topicChange:
        return 'swap_horiz';
      case SuggestionType.followUp:
        return 'reply';
      case SuggestionType.insight:
        return 'lightbulb';
    }
  }
}

/// A detected question from conversation
class DetectedQuestion {
  final String question;
  final String fullContext;
  final DateTime timestamp;

  DetectedQuestion({
    required this.question,
    required this.fullContext,
    required this.timestamp,
  });
}

/// STAR method coaching prompt for behavioral interview questions
class CoachingPrompt {
  final String framework; // e.g. "STAR"
  final String prompt; // e.g. "Use the STAR method..."
  final List<String> steps; // The 4 STAR steps with descriptions
  final String questionContext; // The detected behavioral question
  final DateTime timestamp;

  CoachingPrompt({
    required this.framework,
    required this.prompt,
    required this.steps,
    required this.questionContext,
    required this.timestamp,
  });
}

/// A single turn in the conversation
class ConversationTurn {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final String? mode;
  final String? assistantProfileId;

  ConversationTurn({
    required this.role,
    required this.content,
    required this.timestamp,
    this.mode,
    this.assistantProfileId,
  });

  factory ConversationTurn.fromJson(Map<String, dynamic> json) {
    return ConversationTurn(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      mode: json['mode'] as String?,
      assistantProfileId: json['assistantProfileId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'mode': mode,
    'assistantProfileId': assistantProfileId,
  };
}

/// Live transcript statistics for UI dashboards.
class TranscriptStats {
  final int wordCount;
  final int segmentCount;
  final double wordsPerMinute;
  final int questionCount;

  const TranscriptStats({
    required this.wordCount,
    required this.segmentCount,
    required this.wordsPerMinute,
    required this.questionCount,
  });
}
