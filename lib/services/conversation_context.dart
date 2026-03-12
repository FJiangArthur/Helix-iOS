import '../services/llm/llm_provider.dart';

/// A single turn in a conversation (user speech or AI response).
class ConversationTurn {
  final String role; // 'user', 'assistant'
  final String content;
  final DateTime timestamp;
  final String? mode; // conversation mode active when this turn was recorded

  ConversationTurn({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.mode,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Manages conversation history and provides context for LLM requests.
///
/// Tracks conversation turns and the current live transcription, and
/// generates system prompts based on the active conversation mode.
class ConversationContext {
  ConversationContext._();

  static ConversationContext? _instance;
  static ConversationContext get instance =>
      _instance ??= ConversationContext._();

  final List<ConversationTurn> _history = [];
  String _currentTranscription = '';
  String _mode = 'general';

  // ---------------------------------------------------------------------------
  // System Prompts
  // ---------------------------------------------------------------------------

  static const Map<String, String> _systemPrompts = {
    'general':
        'You are a helpful AI assistant displayed on smart glasses. '
        'Keep responses concise (2-3 sentences max) since they display on a '
        'small HUD. Be conversational and helpful.',
    'interview':
        'You are an interview coach on smart glasses. When you detect '
        'interview questions, suggest strong answers using the STAR method '
        '(Situation, Task, Action, Result). Keep responses brief and '
        'actionable. Focus on key talking points, not full scripts.',
    'passive':
        'You are a conversation intelligence assistant on smart glasses. '
        'Monitor the conversation and when questions arise, provide brief, '
        'accurate answers. Keep responses to 1-2 sentences. Only respond '
        'when there\'s a clear question or when you can add significant value.',
  };

  // ---------------------------------------------------------------------------
  // Mode
  // ---------------------------------------------------------------------------

  /// Current conversation mode ('general', 'interview', 'passive').
  String get mode => _mode;

  set mode(String value) {
    if (_systemPrompts.containsKey(value)) {
      _mode = value;
    }
  }

  // ---------------------------------------------------------------------------
  // History Management
  // ---------------------------------------------------------------------------

  /// Add a new conversation turn.
  void addTurn(String role, String content) {
    _history.add(ConversationTurn(
      role: role,
      content: content,
      mode: _mode,
    ));
  }

  /// Update the current live transcription (replaces previous partial text).
  void updateTranscription(String text) {
    _currentTranscription = text;
  }

  /// Get the current live transcription.
  String get currentTranscription => _currentTranscription;

  /// Build a list of [ChatMessage]s suitable for sending to the LLM.
  ///
  /// Returns the last [maxTurns] turns. If there is a non-empty live
  /// transcription it is appended as the latest user message.
  List<ChatMessage> getContextMessages({int maxTurns = 20}) {
    final recentHistory = _history.length <= maxTurns
        ? _history
        : _history.sublist(_history.length - maxTurns);

    final messages = recentHistory
        .map((turn) => ChatMessage(
              role: turn.role,
              content: turn.content,
              timestamp: turn.timestamp,
            ))
        .toList();

    // Append live transcription as the most recent user input if present.
    if (_currentTranscription.isNotEmpty) {
      messages.add(ChatMessage(
        role: 'user',
        content: _currentTranscription,
      ));
    }

    return messages;
  }

  /// Get the system prompt for the current [mode].
  String getSystemPrompt() {
    return _systemPrompts[_mode] ?? _systemPrompts['general']!;
  }

  /// Clear all history and the current transcription.
  void clear() {
    _history.clear();
    _currentTranscription = '';
  }

  /// Full transcript of all turns joined by newlines.
  String get fullTranscript {
    final buffer = StringBuffer();
    for (final turn in _history) {
      buffer.writeln('${turn.role}: ${turn.content}');
    }
    if (_currentTranscription.isNotEmpty) {
      buffer.writeln('user: $_currentTranscription');
    }
    return buffer.toString().trimRight();
  }

  /// Read-only access to the conversation history.
  List<ConversationTurn> get history => List.unmodifiable(_history);
}
