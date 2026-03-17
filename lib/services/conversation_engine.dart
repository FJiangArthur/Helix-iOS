import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/assistant_profile.dart';
import '../utils/app_logger.dart';
import 'text_paginator.dart';
import 'hud_controller.dart';
import 'provider_error_state.dart';
import 'proto.dart';
import 'glasses_protocol.dart';
import 'llm/llm_service.dart';
import 'llm/llm_provider.dart';
import 'settings_manager.dart';
import 'text_service.dart';
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
  final List<String> _finalizedSegments = [];
  final List<ConversationTurn> _history = [];
  Timer? _analysisTimer;
  int _analysisToken = 0;
  int _responseToken = 0;
  String _lastHandledQuestionKey = '';
  QuestionDetectionResult? _latestQuestionDetection;

  // Silence detection state
  Timer? _silenceTimer;
  static const Duration _silenceThreshold = Duration(seconds: 5);
  static const Duration _responseFlushInterval = Duration(milliseconds: 75);
  static const int _responseFlushThreshold = 14;
  bool _silenceSuggestionSent = false;
  String _realtimeResponseBuffer = '';

  // Configuration
  bool autoDetectQuestions = true;
  bool autoAnswerQuestions = true; // false = confirm-first

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

  ConversationMode get mode => _mode;
  bool get isActive => _isActive;
  String get currentTranscription => _currentTranscription;
  TranscriptSnapshot get currentTranscriptSnapshot => TranscriptSnapshot(
    source: _transcriptSource,
    partialText: _partialTranscription,
    finalizedSegments: List.unmodifiable(_finalizedSegments),
    fullTranscript: _currentTranscription,
  );
  List<ConversationTurn> get history => List.unmodifiable(_history);
  ProviderErrorState? get lastProviderError => _lastProviderError;
  QuestionDetectionResult? get latestQuestionDetection =>
      _latestQuestionDetection;

  /// Start the conversation engine
  void start({
    ConversationMode? mode,
    TranscriptSource source = TranscriptSource.phone,
  }) {
    _cancelInFlightResponse();
    _isActive = true;
    _transcriptSource = source;
    _silenceSuggestionSent = false;
    _analysisToken = 0;
    _lastHandledQuestionKey = '';
    _latestQuestionDetection = null;
    _currentTranscription = '';
    _partialTranscription = '';
    _finalizedSegments.clear();
    _clearProviderError();
    if (mode != null) setMode(mode);
    _emitTranscriptSnapshot();
    _statusController.add(EngineStatus.listening);
    appLogger.i('ConversationEngine started in ${_mode.name} mode');
  }

  /// Stop the engine
  void stop() {
    _cancelInFlightResponse();
    _isActive = false;
    _analysisToken++;
    _analysisTimer?.cancel();
    _silenceTimer?.cancel();
    _clearProviderError();
    _statusController.add(EngineStatus.idle);
    appLogger.i('ConversationEngine stopped');
  }

  /// Set conversation mode
  void setMode(ConversationMode mode) {
    _mode = mode;
    _modeController.add(mode);
    appLogger.d('Mode changed to ${mode.name}');
  }

  /// Called when new transcription text arrives from speech recognition
  void onTranscriptionUpdate(String text) {
    if (!_isActive) return;

    _partialTranscription = text.trim();
    _emitTranscriptSnapshot();
    _silenceSuggestionSent = false;

    // Reset silence timer on each transcription update
    _resetSilenceTimer();

    // Analyze a stable transcript window after 1.5s of silence.
    if (autoDetectQuestions) {
      _scheduleTranscriptAnalysis();
    }

    // Check for behavioral interview questions (STAR coaching)
    if (_mode == ConversationMode.interview &&
        _partialTranscription.isNotEmpty) {
      _checkForBehavioralQuestion(_partialTranscription);
    }
  }

  /// Called when transcription is finalized (recording stops)
  void onTranscriptionFinalized(String text) {
    if (!_isActive) return;
    final normalized = text.trim();
    if (normalized.isEmpty) return;

    if (_finalizedSegments.isEmpty || _finalizedSegments.last != normalized) {
      _finalizedSegments.add(normalized);
    }
    _partialTranscription = '';
    _emitTranscriptSnapshot();

    // Check for behavioral questions in interview mode
    if (_mode == ConversationMode.interview) {
      _checkForBehavioralQuestion(normalized);
    }

    // Analyze finalized text immediately.
    if (autoDetectQuestions) {
      _scheduleTranscriptAnalysis(immediate: true);
    }
  }

  /// Handle AI response text from the OpenAI Realtime API conversation mode.
  void onRealtimeResponse(String text, {required bool isFinal}) {
    if (text.isNotEmpty) {
      _realtimeResponseBuffer += text;
      _streamToGlasses(text, isStreaming: true);
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

  /// Reset the silence timer; fires after 5s of no new transcription
  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceThreshold, _onSilenceDetected);
  }

  /// Called when no transcription update has arrived for [_silenceThreshold]
  void _onSilenceDetected() {
    if (!_isActive || _silenceSuggestionSent) return;
    if (_currentTranscription.trim().isEmpty) return;

    _silenceSuggestionSent = true;
    _generateProactiveSuggestion();
  }

  /// Use the LLM to generate a proactive suggestion based on the conversation
  Future<void> _generateProactiveSuggestion() async {
    if (SettingsManager.instance.transcriptionBackend == 'openaiRealtime') {
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
      );
      return response;
    } catch (e) {
      appLogger.e('Failed to generate summary', error: e);
      return null;
    }
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

  void _emitTranscriptSnapshot() {
    _currentTranscription = _composeFullTranscript();
    final snapshot = TranscriptSnapshot(
      source: _transcriptSource,
      partialText: _partialTranscription,
      finalizedSegments: List.unmodifiable(_finalizedSegments),
      fullTranscript: _currentTranscription,
    );
    _transcriptionController.add(snapshot.fullTranscript);
    _transcriptSnapshotController.add(snapshot);
  }

  String _composeFullTranscript() {
    final parts = <String>[
      ..._finalizedSegments.where((segment) => segment.trim().isNotEmpty),
    ];
    if (_partialTranscription.trim().isNotEmpty) {
      parts.add(_partialTranscription.trim());
    }
    return parts.join('\n');
  }

  void _scheduleTranscriptAnalysis({bool immediate = false}) {
    if (!autoDetectQuestions) return;

    final token = ++_analysisToken;
    _analysisTimer?.cancel();
    if (immediate) {
      _analyzeRecentTranscriptWindow(token);
      return;
    }

    _analysisTimer = Timer(
      const Duration(milliseconds: 1500),
      () => _analyzeRecentTranscriptWindow(token),
    );
  }

  String _buildRecentTranscriptWindow() {
    final segments = _finalizedSegments.length > 3
        ? _finalizedSegments.sublist(_finalizedSegments.length - 3)
        : _finalizedSegments;
    final parts = <String>[...segments];
    if (_partialTranscription.trim().isNotEmpty) {
      parts.add(_partialTranscription.trim());
    }

    final window = parts.join('\n');
    if (window.length <= 800) {
      return window;
    }
    return window.substring(window.length - 800);
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
      );
      if (!_isActive || token != _analysisToken) return;

      final detection = _parseQuestionDetection(response, window);
      if (detection == null) {
        return;
      }

      final questionKey = _normalizeQuestion(detection.question);
      if (questionKey.isEmpty || questionKey == _lastHandledQuestionKey) {
        return;
      }

      _lastHandledQuestionKey = questionKey;
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
        final responseToken = _beginResponseCycle();
        _statusController.add(EngineStatus.thinking);
        await _generateResponse(
          detection.question,
          responseToken: responseToken,
        );
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
      return '''分析下面这段最近对话，判断是否出现了一个值得立即帮助用户回答的问题。

要求：
- 如果没有明确问题，返回 shouldRespond=false，并把 question 和 questionExcerpt 设为空字符串。
- 如果有问题，question 提炼成一句话。
- questionExcerpt 必须尽量直接复制最近对话窗口里对应问题的原文片段；如果做不到就返回空字符串。

最近问答历史：
$historyContext

最近对话窗口：
$window''';
    }

    return '''Analyze this recent conversation window and decide whether there is a clear question worth answering right now.

Rules:
- If there is no clear question, return shouldRespond=false and leave question and questionExcerpt empty.
- If there is a question, extract it as one sentence.
- questionExcerpt should be a verbatim excerpt from the recent conversation window when possible. If you cannot quote it exactly, return an empty string.

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
      return '''你是一个实时对话分析助手。你负责阅读最近对话窗口，判断是否需要帮助用户回答问题。

只输出 JSON，不要 markdown，不要额外解释。
JSON 格式必须是：
{"shouldRespond": true/false, "question": "...", "questionExcerpt": "..."}

$profileInstruction''';
    }

    return '''You are a live conversation analysis assistant. Read the latest conversation window and decide whether the user needs help answering a question right now.

Output JSON only. No markdown and no extra commentary.
The JSON shape must be:
{"shouldRespond": true/false, "question": "...", "questionExcerpt": "..."}

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

      return QuestionDetectionResult(
        question: question,
        questionExcerpt: _resolveQuestionExcerpt(
          window,
          (decoded['questionExcerpt'] as String? ?? '').trim(),
          question,
        ),
        timestamp: DateTime.now(),
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

  /// Generate AI response and stream to glasses
  Future<void> _generateResponse(
    String question, {
    required int responseToken,
  }) async {
    if (SettingsManager.instance.transcriptionBackend == 'openaiRealtime') {
      return;
    }
    Timer? flushTimer;
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

      final systemPrompt = _getSystemPrompt();
      final messages = _buildContextMessages(question);

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

      await for (final chunk in llmService.streamResponse(
        systemPrompt: systemPrompt,
        messages: messages,
        temperature: SettingsManager.instance.temperature,
      )) {
        if (!_isResponseCurrent(responseToken)) {
          return;
        }

        responseText += chunk;
        pendingDelta += chunk;

        if (_shouldFlushBufferedResponse(pendingDelta)) {
          await flushPendingDelta();
        } else {
          scheduleFlush();
        }
      }

      await flushPendingDelta();
      if (!_isResponseCurrent(responseToken)) {
        return;
      }

      // Send final page to glasses
      if (glassesConnected) {
        await _streamToGlasses(responseText, isStreaming: false);
      }

      final finalResponse = responseText;

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

      // Generate smart follow-up chips after response completes
      _generateFollowUpChips(finalResponse);
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
  String _getSystemPrompt() {
    final isChinese = _language == 'zh';
    final langInstruction = isChinese
        ? '\n\nIMPORTANT: Always respond in Chinese (中文). Use natural, conversational Chinese.'
        : '';
    final profileInstruction = _activeAssistantProfile().promptDirective(
      isChinese: isChinese,
    );

    late final String basePrompt;
    switch (_mode) {
      case ConversationMode.interview:
        if (isChinese) {
          basePrompt = '''你是一位显示在智能眼镜上的精英面试教练。你的任务是帮助用户出色地回答面试问题。

回答格式：
- **核心观点**：要传达的主要信息（1句话）
- **STAR框架**：
  - S（情境）：简要背景描述
  - T（任务）：你负责什么
  - A（行动）：你采取的具体步骤
- R（结果）：可量化的成果
- **关键词**：3-4个有力的动词（领导、优化、交付等）

回答控制在100字以内。用户需要快速浏览你的回答然后自然地表达。简洁有力，直接可行。''';
        } else {
          basePrompt =
              '''You are an elite interview coach displayed on smart glasses during a live interview. Your job is to help the user answer interview questions brilliantly.

FORMAT YOUR RESPONSES AS:
- **Key Point**: The main message to convey (1 sentence)
- **STAR Framework**:
  - S (Situation): Brief context to set up
  - T (Task): What you were responsible for
  - A (Action): Specific steps you took
- R (Result): Measurable outcome
- **Power Words**: 3-4 strong verbs to use (led, optimized, delivered, etc.)

Keep responses under 100 words. The user needs to glance at your response and speak naturally. No fluff. Be direct and actionable. Focus on what to say RIGHT NOW.''';
        }
        break;

      case ConversationMode.passive:
        if (isChinese) {
          basePrompt = '''你是一个显示在智能眼镜上的实时对话智能助手。你在后台默默监听对话，在能提供价值时介入。

你的角色：
- 准确简洁地回答事实性问题
- 建议后续话题以保持对话有趣
- 在话题允许时提供相关背景或数据
- 当有人说了事实性错误时委婉地指出

每次回答最多1-2句话。只在真正有用时发言。质量优于数量。''';
        } else {
          basePrompt =
              '''You are a real-time conversation intelligence assistant displayed on smart glasses. You silently monitor conversations and jump in when you can add value.

YOUR ROLE:
- Answer factual questions accurately and briefly
- Suggest follow-up questions to keep conversations interesting
- Provide relevant context or data when the topic allows it
- Flag when someone says something factually incorrect (diplomatically suggest the correction)

Keep responses to 1-2 sentences MAX. Only speak when you have something genuinely useful to add. Quality over quantity. The user should feel like having a brilliant friend whispering in their ear.''';
        }
        break;

      case ConversationMode.general:
        if (isChinese) {
          basePrompt =
              '''你是Even Companion，一个显示在智能眼镜上的对话智能伙伴。你帮助人们进行更好的对话——更有趣、更吸引人、更令人难忘。

你的能力：
- 用简短、准确、对话式的方式回答问题
- 当对话停滞时建议有趣的后续话题
- 提供快速的事实、数据或背景来丰富讨论
- 帮助清晰有力地表达想法
- 被问到时提供开场白和破冰话题

风格规则：
- 每次回答最多2-3句话（显示在小HUD上）
- 温暖、机智、像人一样——不要像机器人
- 建议用户说的话时，使用可以直接说出来的自然语言
- 优先考虑有用性而非全面性''';
        } else {
          basePrompt =
              '''You are Even Companion, a conversation intelligence companion displayed on smart glasses. You help people have better conversations — more interesting, more engaging, more memorable.

YOUR SUPERPOWERS:
- Answer questions with brief, accurate, conversational responses
- Suggest interesting follow-up topics when conversation stalls
- Provide quick facts, data, or context to enrich discussions
- Help articulate ideas clearly and persuasively
- Offer conversation starters and icebreakers when asked

STYLE RULES:
- Max 2-3 sentences per response (it displays on a small HUD)
- Be warm, witty, and human — not robotic
- When suggesting what to say, use natural language the user can speak directly
- Prioritize being helpful over being comprehensive''';
        }
        break;
    }

    return '$basePrompt$langInstruction\n\n$profileInstruction';
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
    } catch (e) {
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

  /// Persist current history to SharedPreferences
  Future<void> _persistHistory() async {
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
    _history.clear();
    _currentTranscription = '';
    _partialTranscription = '';
    _finalizedSegments.clear();
    _lastHandledQuestionKey = '';
    _latestQuestionDetection = null;
    _emitTranscriptSnapshot();
    _persistHistory();
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
  }
}

/// Conversation modes
enum ConversationMode { general, interview, passive }

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

class QuestionDetectionResult {
  const QuestionDetectionResult({
    required this.question,
    required this.questionExcerpt,
    required this.timestamp,
  });

  final String question;
  final String questionExcerpt;
  final DateTime timestamp;
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
