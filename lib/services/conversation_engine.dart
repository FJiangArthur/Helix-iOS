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
  String _currentTranscription = '';
  final List<ConversationTurn> _history = [];
  Timer? _questionDetectionTimer;
  String _pendingQuestion = '';

  // Silence detection state
  Timer? _silenceTimer;
  static const Duration _silenceThreshold = Duration(seconds: 5);
  bool _silenceSuggestionSent = false;

  // Configuration
  bool autoDetectQuestions = true;
  bool autoAnswerQuestions = true; // false = confirm-first

  // Streams
  final _transcriptionController = StreamController<String>.broadcast();
  final _aiResponseController = StreamController<String>.broadcast();
  final _modeController = StreamController<ConversationMode>.broadcast();
  final _questionDetectedController =
      StreamController<DetectedQuestion>.broadcast();
  final _statusController = StreamController<EngineStatus>.broadcast();
  final _proactiveSuggestionController =
      StreamController<ProactiveSuggestion>.broadcast();
  final _coachingController = StreamController<CoachingPrompt>.broadcast();
  final _followUpChipsController = StreamController<List<String>>.broadcast();
  final _providerErrorController =
      StreamController<ProviderErrorState?>.broadcast();
  ProviderErrorState? _lastProviderError;

  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<String> get aiResponseStream => _aiResponseController.stream;
  Stream<ConversationMode> get modeStream => _modeController.stream;
  Stream<DetectedQuestion> get questionDetectedStream =>
      _questionDetectedController.stream;
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
  List<ConversationTurn> get history => List.unmodifiable(_history);
  ProviderErrorState? get lastProviderError => _lastProviderError;

  /// Start the conversation engine
  void start({ConversationMode? mode}) {
    _isActive = true;
    _silenceSuggestionSent = false;
    _pendingQuestion = '';
    _currentTranscription = '';
    _clearProviderError();
    if (mode != null) setMode(mode);
    _statusController.add(EngineStatus.listening);
    appLogger.i('ConversationEngine started in ${_mode.name} mode');
  }

  /// Stop the engine
  void stop() {
    _isActive = false;
    _questionDetectionTimer?.cancel();
    _silenceTimer?.cancel();
    _pendingQuestion = '';
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

    _currentTranscription = text;
    _transcriptionController.add(text);
    _silenceSuggestionSent = false;

    // Reset silence timer on each transcription update
    _resetSilenceTimer();

    // Debounce question detection — wait 1.5s after last update
    if (autoDetectQuestions) {
      _questionDetectionTimer?.cancel();
      _questionDetectionTimer = Timer(
        const Duration(milliseconds: 1500),
        () => _analyzeForQuestions(text),
      );
    }

    // Check for behavioral interview questions (STAR coaching)
    if (_mode == ConversationMode.interview) {
      _checkForBehavioralQuestion(text);
    }
  }

  /// Called when transcription is finalized (recording stops)
  void onTranscriptionFinalized(String text) {
    if (!_isActive) return;
    if (text.trim().isEmpty) return;

    _currentTranscription = text;
    _transcriptionController.add(text);

    // Save to history
    _history.add(
      ConversationTurn(
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
        mode: _mode.name,
        assistantProfileId: _activeAssistantProfile().id,
      ),
    );
    _persistHistory();

    // Immediately check for questions in finalized text
    if (autoDetectQuestions) {
      _analyzeForQuestions(text);
    }

    // Check for behavioral questions in interview mode
    if (_mode == ConversationMode.interview) {
      _checkForBehavioralQuestion(text);
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

    _statusController.add(EngineStatus.thinking);
    await _generateResponse(question);
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

  // ---------------------------------------------------------------------------
  // Core response generation
  // ---------------------------------------------------------------------------

  /// Generate AI response and stream to glasses
  Future<void> _generateResponse(String question) async {
    try {
      _statusController.add(EngineStatus.responding);
      _clearProviderError();

      // Import LlmService dynamically to avoid circular dependency
      final llmService = _getLlmService();
      if (llmService == null) {
        final errorState = ProviderErrorState.missingConfiguration();
        _publishProviderError(errorState);
        _aiResponseController.add(errorState.userFacingMessage);
        _statusController.add(
          _isActive ? EngineStatus.listening : EngineStatus.idle,
        );
        return;
      }

      final systemPrompt = _getSystemPrompt();
      final messages = _buildContextMessages(question);

      final buffer = StringBuffer();
      final glassesConnected = BleManager.isBothConnected();

      await for (final chunk in llmService.streamResponse(
        systemPrompt: systemPrompt,
        messages: messages,
        temperature: SettingsManager.instance.temperature,
      )) {
        buffer.write(chunk);
        _aiResponseController.add(buffer.toString());

        // Stream to glasses HUD only when connected
        if (glassesConnected) {
          await _sendToGlasses(buffer.toString(), isStreaming: true);
        }
      }

      // Send final page to glasses
      if (glassesConnected) {
        await _sendToGlasses(buffer.toString(), isStreaming: false);
      }

      final finalResponse = buffer.toString();

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

      _statusController.add(
        _isActive ? EngineStatus.listening : EngineStatus.idle,
      );

      // Generate smart follow-up chips after response completes
      _generateFollowUpChips(finalResponse);
    } catch (e) {
      appLogger.e('Error generating response', error: e);
      final errorState = ProviderErrorState.fromException(e);
      _publishProviderError(errorState);
      _aiResponseController.add(errorState.userFacingMessage);
      _statusController.add(
        _isActive ? EngineStatus.listening : EngineStatus.idle,
      );
    }
  }

  /// Analyze text for questions
  void _analyzeForQuestions(String text) {
    if (!_isActive || text.trim().isEmpty) return;

    // Simple heuristic: check for question marks and question words
    final hasQuestionMark = text.contains('?') || text.contains('？');
    final isChinese = _language == 'zh';
    final questionWords = isChinese
        ? [
            '什么',
            '怎么',
            '为什么',
            '什么时候',
            '哪里',
            '谁',
            '哪个',
            '能不能',
            '可以',
            '会不会',
            '是不是',
            '有没有',
            '请问',
            '请解释',
            '请描述',
            '告诉我',
            '如何',
            '吗',
            '呢',
            '吧',
          ]
        : [
            'what',
            'how',
            'why',
            'when',
            'where',
            'who',
            'which',
            'can',
            'could',
            'would',
            'should',
            'is',
            'are',
            'do',
            'does',
            'tell me',
            'explain',
            'describe',
          ];

    // Split sentences - support both English and Chinese punctuation
    final sentenceSplitter = isChinese
        ? RegExp(r'[.!?。！？]+')
        : RegExp(r'[.!?]+');
    final sentences = text
        .split(sentenceSplitter)
        .where((s) => s.trim().isNotEmpty)
        .toList();

    String? detectedQuestion;

    // Check the last sentence for question patterns
    if (sentences.isNotEmpty) {
      final lastSentence = sentences.last.trim();
      final lowerLast = lastSentence.toLowerCase();

      if (hasQuestionMark ||
          (isChinese
              ? questionWords.any((w) => lowerLast.contains(w))
              : (questionWords.any((w) => lowerLast.startsWith(w)) ||
                    questionWords.any((w) => lowerLast.startsWith('$w '))))) {
        detectedQuestion = lastSentence;
      }
    }

    // Also check full text for question marks
    if (detectedQuestion == null && hasQuestionMark) {
      final questionSentences = sentences
          .where((s) => s.contains('?') || s.contains('？'))
          .toList();
      if (questionSentences.isNotEmpty) {
        detectedQuestion = questionSentences.last.trim();
      }
    }

    if (detectedQuestion != null && detectedQuestion != _pendingQuestion) {
      _pendingQuestion = detectedQuestion;
      final detected = DetectedQuestion(
        question: detectedQuestion,
        fullContext: text,
        timestamp: DateTime.now(),
      );
      _questionDetectedController.add(detected);

      if (autoAnswerQuestions) {
        // Auto-answer mode: immediately generate response
        askQuestion(detectedQuestion);
      }
    }
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
  static void setLlmServiceGetter(LlmService Function() getter) {
    _llmServiceGetter = getter;
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
    _pendingQuestion = '';
    _persistHistory();
  }

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
    _questionDetectionTimer?.cancel();
    _silenceTimer?.cancel();
    _transcriptionController.close();
    _aiResponseController.close();
    _modeController.close();
    _questionDetectedController.close();
    _statusController.close();
    _proactiveSuggestionController.close();
    _coachingController.close();
    _followUpChipsController.close();
    _providerErrorController.close();
  }
}

/// Conversation modes
enum ConversationMode { general, interview, passive }

/// Engine status
enum EngineStatus { idle, listening, thinking, responding, error }

/// Types of proactive suggestions
enum SuggestionType { topicChange, followUp, insight }

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
