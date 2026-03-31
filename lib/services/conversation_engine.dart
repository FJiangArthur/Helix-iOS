import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/answered_question.dart';
import '../models/assistant_profile.dart';
import '../utils/app_logger.dart';
import 'bitmap_hud/bitmap_hud_service.dart';
import 'cloud_pipeline_service.dart';
import 'database/helix_database.dart' as database_pkg;
import 'session_context_manager.dart';
import 'text_paginator.dart';
import 'hud_controller.dart';
import 'provider_error_state.dart';
import 'proto.dart';
import 'glasses_protocol.dart';
import 'llm/llm_service.dart';
import 'llm/llm_provider.dart';
import 'tools/tool_executor.dart';
import 'tools/web_search_tool.dart';
import 'conversation_listening_session.dart';
import 'entity_memory.dart';
import 'knowledge_base.dart';
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
  String _lastHandledQuestionKey = '';
  DateTime? _lastHandledQuestionTime;
  QuestionDetectionResult? _latestQuestionDetection;

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
  set autoDetectQuestions(bool v) => SettingsManager.instance.autoDetectQuestions = v;
  bool get autoAnswerQuestions => SettingsManager.instance.autoAnswerQuestions;
  set autoAnswerQuestions(bool v) => SettingsManager.instance.autoAnswerQuestions = v;

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
  Stream<String> get factCheckAlertStream =>
      _factCheckAlertController.stream;
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
    _cancelInFlightResponse();
    _resetLiveSessionState(clearConversationHistory: true);
    _isActive = true;
    _transcriptSource = source;
    _silenceSuggestionSent = false;
    _analysisToken = 0;
    _segmentSentencesFinalized = 0;
    _sentimentSegmentCounter = 0;
    _entitySegmentCounter = 0;
    _analyticsRunning = false;
    _clearProviderError();
    if (mode != null) setMode(mode);
    if (_mode == ConversationMode.proactive) {
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
    // Force-persist on stop regardless of debounce
    _lastPersistTime = null;
    _persistHistory();
    // Restore idle heartbeat now that conversation ended.
    BleManager.get().updateHeartbeatMode(false);
    // Resume bitmap HUD refresh.
    BitmapHudService.instance.setConversationActive(false);
    _statusController.add(EngineStatus.idle);
    appLogger.i('ConversationEngine stopped');

    // Trigger post-conversation analysis asynchronously if there is
    // meaningful history and the session produced finalized segments.
    if (_history.length > 1 && _finalizedSegments.length > 1) {
      final stopToken = _analysisToken;
      getPostConversationAnalysis().then((result) {
        if (stopToken == _analysisToken) {
          _postConversationController.add(result);
        }
      }).catchError((e) {
        appLogger.e('Post-conversation analysis failed', error: e);
        if (stopToken == _analysisToken) {
          _postConversationController.add(null);
        }
      });

      // V2.2: Save conversation to SQLite and trigger cloud pipeline
      _saveAndProcessConversation();
    }
  }

  /// Save the current conversation to the database and trigger the cloud pipeline.
  Future<void> _saveAndProcessConversation() async {
    try {
      final db = database_pkg.HelixDatabase.instance;
      final conversationId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;

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

      // Save segments
      for (int i = 0; i < _finalizedSegments.length; i++) {
        final seg = _finalizedSegments[i];
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

      appLogger.i('Saved conversation $conversationId with ${_finalizedSegments.length} segments');

      // Trigger cloud pipeline asynchronously
      CloudPipelineService.instance.processConversation(conversationId);
    } catch (e) {
      appLogger.e('Failed to save conversation to database', error: e);
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

    if (autoDetectQuestions && _mode != ConversationMode.proactive) {
      _scheduleTranscriptAnalysis();
    }
    if (_mode == ConversationMode.interview &&
        _partialTranscription.isNotEmpty) {
      _checkForBehavioralQuestion(_partialTranscription);
    }
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
        _finalizedSegments.add(TranscriptSegment(
          text: sentence,
          timestamp: DateTime.now(),
        ));
        appLogger.d('[Engine] Progressive finalize: "$sentence"');
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

  /// Archives the oldest 100 segments via [SessionContextManager] and removes
  /// them from [_finalizedSegments] to bound memory during long sessions.
  void _compactAndCapSegments() {
    final toArchive = _finalizedSegments.sublist(0, 100);
    // Fire-and-forget: summarization runs in the background.
    final llmService = _getLlmService();
    if (llmService != null) {
      _sessionContextManager
          .compactOldSegments(toArchive, llmService)
          .catchError((e) {
        appLogger.w('[Engine] Background segment compaction failed: $e');
      });
    }
    _finalizedSegments.removeRange(0, 100);
    appLogger.d('[Engine] Capped segments: archived 100, '
        '${_finalizedSegments.length} remaining');
  }

  /// Called when transcription is finalized (segment ends or recording stops).
  ///
  /// Complete sentences have already been finalized progressively by
  /// [onTranscriptionUpdate]. This only needs to finalize the trailing
  /// incomplete sentence (the current partial).
  void onTranscriptionFinalized(String text, {DateTime? segmentTimestamp, String? speakerLabel}) {
    if (!_isActive) return;

    // Finalize the trailing partial sentence, not the full buffer text
    // (complete sentences were already finalized by onTranscriptionUpdate).
    final toFinalize = _partialTranscription.trim().isNotEmpty
        ? _partialTranscription.trim()
        : text.trim();

    if (toFinalize.isNotEmpty &&
        (_finalizedSegments.isEmpty ||
            _finalizedSegments.last.text != toFinalize)) {
      _finalizedSegments.add(TranscriptSegment(
        text: toFinalize,
        timestamp: segmentTimestamp ?? DateTime.now(),
        speakerLabel: speakerLabel,
      ));
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
    if (autoDetectQuestions && _mode != ConversationMode.proactive) {
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
    await _generateResponse(question, responseToken: responseToken);
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
    // In proactive mode, silence does NOT trigger automatic suggestions.
    if (_mode == ConversationMode.proactive) return;

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
        appLogger.d('STAR coaching triggered for: $questionContext');

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

  /// Trigger a full-session proactive analysis.
  ///
  /// Called from [forceQuestionAnalysis] when in proactive mode or directly
  /// from the app UI "Analyze" button.
  Future<void> triggerProactiveAnalysis() async {
    if (!_isActive || _mode != ConversationMode.proactive) return;

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

    final answeredSummary =
        _sessionContextManager.buildAnsweredQuestionsSummary();
    final proactiveSystemPrompt = _getSystemPrompt();

    final messages = [
      ChatMessage(
        role: 'user',
        content: '''$context

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

    _sessionContextManager.addAnsweredQuestion(AnsweredQuestion(
      question: parsedTarget ?? 'proactive analysis',
      answer: response,
      timestamp: DateTime.now(),
      action: parsedAction ?? 'insight',
    ));
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
        appLogger.d('[FactCheck] Correction: $trimmed');
        _factCheckAlertController.add(trimmed);
      }
    } catch (e) {
      appLogger.d('Background fact-check failed: $e');
    }
  }

  /// Merged post-response analysis: generates follow-up chips and runs a
  /// fact-check in a single LLM call instead of two separate calls.
  Future<void> _postResponseAnalysis(
    String question,
    String response,
  ) async {
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
          appLogger.d('[FactCheck] Correction: $trimmed');
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
        _analysisTimer = Timer(remaining, () => _analyzeRecentTranscriptWindow(token));
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

      _aiResponseController.add('');
      if (autoAnswerQuestions) {
        final session = ConversationListeningSession.instance;
        final shouldPause = session.isRunning;
        if (shouldPause) session.pauseTranscription();
        final responseToken = _beginResponseCycle();
        _statusController.add(EngineStatus.thinking);
        try {
          await _generateResponse(
            detection.question,
            responseToken: responseToken,
          );
        } finally {
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
  }) async {
    if (SettingsManager.instance.usesOpenAIRealtimeSession) {
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

      final systemPrompt = overrideSystemPrompt ?? _getSystemPrompt();
      final messages = overrideMessages ?? _buildContextMessages(question);

      var responseText = '';
      var pendingDelta = '';
      Future<void> flushChain = Future<void>.value();
      final glassesConnected = _glassesConnectionChecker();

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
      for (var round = 0; round <= maxToolRounds; round++) {
        ToolCallRequest? pendingToolCall;

        await for (final event in llmService.streamWithTools(
          systemPrompt: systemPrompt,
          messages: toolMessages,
          tools: tools.isEmpty ? null : tools,
          temperature: SettingsManager.instance.temperature,
          model: SettingsManager.instance.resolvedSmartModel,
        )) {
          if (!_isResponseCurrent(responseToken)) return;

          switch (event) {
            case TextDelta(:final text):
              if (responseText.isEmpty && text.startsWith('[Error]')) {
                final errorState = ProviderErrorState.fromException(text);
                _publishProviderError(errorState);
                _statusController.add(
                    _isActive ? EngineStatus.listening : EngineStatus.idle);
                return;
              }
              responseText += text;
              pendingDelta += text;
              if (_shouldFlushBufferedResponse(pendingDelta)) {
                await flushPendingDelta();
              } else {
                scheduleFlush();
              }
            case ToolCallRequest():
              pendingToolCall = event;
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
          ..add(ChatMessage(role: 'user', content: '[Tool result for ${pendingToolCall.name}]: $toolResult'));
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

      // In proactive mode, parse the JSON preamble and track the answered Q.
      if (_mode == ConversationMode.proactive) {
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

  /// Build context messages for the LLM
  List<ChatMessage> _buildContextMessages(String currentQuestion) {
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

    // Add current question if not already in history
    if (messages.isEmpty || messages.last.content != currentQuestion) {
      messages.add(ChatMessage(role: 'user', content: currentQuestion));
    }

    return messages;
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
      UserKnowledgeBase.instance.buildContextSummary().then((ctx) {
        _cachedKbContext = ctx;
      }).catchError((_) {});
    }
    return _cachedKbContext;
  }

  String _getSystemPrompt() {
    final isChinese = _language == 'zh';
    final langInstruction = isChinese
        ? '\n\nIMPORTANT: Always respond in Chinese (中文). Use natural, conversational Chinese.'
        : '';
    final profileInstruction = _activeAssistantProfile().promptDirective(
      isChinese: isChinese,
    );
    final maxSentences = SettingsManager.instance.maxResponseSentences;

    late final String basePrompt;
    switch (_mode) {
      case ConversationMode.interview:
        if (isChinese) {
          basePrompt = '''你是智能眼镜上的面试教练。直接给出用户应该说的话。

规则：最多$maxSentences句话。直接输出应说的内容，禁止说"你可以说"或"建议回答"。只用可以直接开口说的自然语言。''';
        } else {
          basePrompt =
              '''You are an interview coach on smart glasses. Output exactly what the user should say.

Rules: Max $maxSentences sentences. Never write "you could say" or "try saying" — output the answer directly as speakable text.''';
        }
        break;

      case ConversationMode.passive:
        if (isChinese) {
          basePrompt = '''你是智能眼镜上的对话助手，默默监听并在有用时介入。

规则：最多$maxSentences句话。直接陈述事实或纠正。禁止说"你可以说"。不废话，不加前缀。''';
        } else {
          basePrompt =
              '''You are a conversation assistant on smart glasses, silently listening and chiming in when useful.

Rules: Max $maxSentences sentences. State facts or corrections directly. Never write "you could say" or any preamble. No filler.''';
        }
        break;

      case ConversationMode.general:
        if (isChinese) {
          basePrompt = '''你是智能眼镜上的对话伙伴，帮助用户进行更好的对话。

规则：最多$maxSentences句话。直接给出答案，禁止说"你可以说"或"这是建议"。用自然口语，不用列表格式。''';
        } else {
          basePrompt =
              '''You are a conversation companion on smart glasses helping the user have better conversations.

Rules: Max $maxSentences sentences. Give the answer directly — never write "you could say" or "here's a suggestion". Use natural spoken language, no lists or formatting.''';
        }
        break;

      case ConversationMode.proactive:
        if (isChinese) {
          basePrompt = '''你是智能眼镜上的主动对话智能助手。
你正在监听一场实时对话，并在用户请求时提供分析。

你的任务（选择最合适的一个）：
1. ANSWER：如果有未解答的问题需要帮助回答
2. FACT_CHECK：如果有可能不正确的事实性声明
3. INSIGHT：如果你能提供有帮助的背景信息或知识

规则：
- 简洁明了（最多$maxSentences句话）
- 不要重复已经回答过的问题
- 聚焦于对话中最近和最相关的部分
- 用JSON前缀开头：{"action": "answer"|"fact_check"|"insight", "target": "..."}''';
        } else {
          basePrompt =
              '''You are a proactive conversation intelligence assistant on smart glasses.
You are listening to a live conversation and providing analysis when the user requests it.

Your tasks (pick the most appropriate):
1. ANSWER: If there are unanswered questions the wearer needs help with
2. FACT_CHECK: If there are factual claims that may be incorrect
3. INSIGHT: If you can provide helpful context or information

Rules:
- Be concise (max $maxSentences sentences)
- Do NOT repeat previously answered questions
- Focus on the most recent and relevant parts of the conversation
- Start your response with a JSON preamble: {"action": "answer"|"fact_check"|"insight", "target": "..."}''';
        }
        break;
    }

    final kbContext = _getKbContext();
    final contextBlock = kbContext.isNotEmpty ? '\n\n$kbContext' : '';
    return '$basePrompt$langInstruction\n\n$profileInstruction$contextBlock';
  }

  /// Send text to glasses HUD with proper pagination
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

  Future<void> _streamToGlasses(String text, {required bool isStreaming}) {
    return _glassesSender(text, isStreaming: isStreaming);
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

  /// Clear all history
  void clearHistory() {
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
    _lastHandledQuestionKey = '';
    _lastHandledQuestionTime = null;
    _latestQuestionDetection = null;
    _lastEmittedSnapshot = '__session_reset__';
    _lastEmittedPartial = '__session_reset__';
    _followUpChipsController.add(const []);
    _aiResponseController.add('');
    _postConversationController.add(null);
    _emitTranscriptSnapshot();
  }

  int _beginResponseCycle() {
    _responseToken++;
    return _responseToken;
  }

  void _cancelInFlightResponse() {
    _responseToken++;
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
      await _maybeTriggerSentimentAnalysis().timeout(_analyticsTimeout,
          onTimeout: () {
        appLogger.w('[Engine] Sentiment analysis timed out');
      });
      await _maybeTriggerEntityExtraction().timeout(_analyticsTimeout,
          onTimeout: () {
        appLogger.w('[Engine] Entity extraction timed out');
      });
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
      final parsed = numMatch != null ? double.tryParse(numMatch.group(0)!) : null;
      if (parsed != null && parsed >= -1.0 && parsed <= 1.0) {
        _sentimentController.add(parsed);
      } else {
        appLogger.d('[Engine] Sentiment response unparseable: '
            '"${response.trim().length > 60 ? '${response.trim().substring(0, 60)}...' : response.trim()}"');
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
    _statusController.close();
    _proactiveSuggestionController.close();
    _coachingController.close();
    _followUpChipsController.close();
    _providerErrorController.close();
    _postConversationController.close();
    _factCheckAlertController.close();
    _translationSubscription?.cancel();
    _translationController.close();
    _sentimentController.close();
    _entityController.close();
  }

  /// Manually trigger question analysis from glasses button press.
  /// Bypasses the realtime-session guard in [_scheduleTranscriptAnalysis] so
  /// that the user can still request a local LLM analysis even when using
  /// OpenAI Realtime mode.
  ///
  /// In proactive mode, routes to [triggerProactiveAnalysis] instead.
  void forceQuestionAnalysis() {
    if (!_isActive) return;
    if (_mode == ConversationMode.proactive) {
      triggerProactiveAnalysis();
      return;
    }
    final token = ++_analysisToken;
    _analyzeRecentTranscriptWindow(token);
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
    final testSegments = segments ?? const [
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
      appLogger.i('[Simulation] Segment ${i + 1}/${testSegments.length} finalized: ${segment.length} chars');

      if (i < testSegments.length - 1) {
        await Future<void>.delayed(segmentDelay);
      }
    }
  }
}

/// Conversation modes
enum ConversationMode { general, interview, passive, proactive }

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
    required this.fullTranscript,
  });

  final TranscriptSource source;
  final String partialText;
  final List<String> finalizedSegments;
  final String fullTranscript;
}

class TranscriptSegment {
  final String text;
  final DateTime timestamp;
  String? speakerLabel; // "me" or "other"
  TranscriptSegment({required this.text, required this.timestamp, this.speakerLabel});
}

class QuestionDetectionResult {
  const QuestionDetectionResult({
    required this.question,
    required this.questionExcerpt,
    required this.timestamp,
    this.askedBy = 'other',
  });

  final String question;
  final String questionExcerpt;
  final DateTime timestamp;
  final String askedBy;
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
