import '../models/answered_question.dart';
import '../utils/app_logger.dart';
import 'conversation_engine.dart';
import 'llm/llm_provider.dart';
import 'llm/llm_service.dart';

/// Manages full-session context with recency weighting for proactive mode.
///
/// Implements a three-tier context window:
/// 1. **Session overview** — rolling summary of the earliest portions.
/// 2. **Earlier conversation (summarized)** — archived chunk summaries.
/// 3. **Recent conversation (verbatim)** — last ~5 minutes of full transcript.
///
/// Also tracks answered questions to prevent the LLM from repeating itself.
class SessionContextManager {
  final List<_SummarizedChunk> _archivedChunks = [];
  final List<AnsweredQuestion> _answeredQuestions = [];
  String _rollingSummary = '';
  DateTime? _sessionStart;

  /// Token budget per provider (conservative estimates of context window).
  static const Map<String, int> _providerContextBudgets = {
    'openai': 100000,
    'anthropic': 150000,
    'deepseek': 50000,
    'qwen': 25000,
    'zhipu': 100000,
    'siliconflow': 25000,
  };

  /// Reserved tokens for system prompt + answered questions + response.
  static const int _reservedTokens = 4000;

  /// Approximate duration of "recent" verbatim window.
  static const Duration _recentWindow = Duration(minutes: 5);

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  void startSession() {
    _sessionStart = DateTime.now();
    _archivedChunks.clear();
    _answeredQuestions.clear();
    _rollingSummary = '';
  }

  void reset() {
    _sessionStart = null;
    _archivedChunks.clear();
    _answeredQuestions.clear();
    _rollingSummary = '';
  }

  DateTime? get sessionStart => _sessionStart;

  // ---------------------------------------------------------------------------
  // Three-tier context building
  // ---------------------------------------------------------------------------

  /// Builds a context window from all available transcript data, sized to
  /// fit within the token budget for the given [providerId].
  String buildContextWindow({
    required List<TranscriptSegment> recentSegments,
    required String partialTranscription,
    required String providerId,
  }) {
    final totalBudget =
        _providerContextBudgets[providerId] ?? 25000;
    final usableBudget = totalBudget - _reservedTokens;
    if (usableBudget <= 0) return '';

    // 60% for recent verbatim, 40% for summarized + overview
    final recentBudget = (usableBudget * 0.6).round();
    final archiveBudget = (usableBudget * 0.4).round();

    // --- Recent verbatim (last ~5 minutes) ---
    final now = DateTime.now();
    final recentCutoff = now.subtract(_recentWindow);

    final recentParts = <String>[];
    for (final seg in recentSegments) {
      if (seg.timestamp.isAfter(recentCutoff)) {
        recentParts.add(seg.text);
      }
    }
    if (partialTranscription.trim().isNotEmpty) {
      recentParts.add(partialTranscription.trim());
    }

    var recentVerbatim = recentParts.join('\n');
    final recentTokens = _estimateTokens(recentVerbatim);
    if (recentTokens > recentBudget) {
      recentVerbatim = _truncateToTokenBudget(recentVerbatim, recentBudget);
    }

    // --- Earlier summarized chunks ---
    final archiveParts = <String>[];
    var archiveTokensUsed = 0;
    for (final chunk in _archivedChunks.reversed) {
      final chunkText = '[${_formatTime(chunk.timestamp)}] ${chunk.summary}';
      final chunkTokens = _estimateTokens(chunkText);
      if (archiveTokensUsed + chunkTokens > archiveBudget) break;
      archiveParts.insert(0, chunkText);
      archiveTokensUsed += chunkTokens;
    }
    final archiveText = archiveParts.join('\n');

    // --- Session overview ---
    final overviewText = _rollingSummary;

    // --- Compose the three tiers ---
    final buffer = StringBuffer();
    if (overviewText.isNotEmpty) {
      buffer.writeln('[SESSION OVERVIEW]');
      buffer.writeln(overviewText);
      buffer.writeln();
    }
    if (archiveText.isNotEmpty) {
      buffer.writeln('[EARLIER CONVERSATION (summarized)]');
      buffer.writeln(archiveText);
      buffer.writeln();
    }
    if (recentVerbatim.isNotEmpty) {
      buffer.writeln('[RECENT CONVERSATION (verbatim)]');
      buffer.writeln(recentVerbatim);
    }

    return buffer.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Answered questions
  // ---------------------------------------------------------------------------

  void addAnsweredQuestion(AnsweredQuestion qa) {
    _answeredQuestions.add(qa);
  }

  List<AnsweredQuestion> get answeredQuestions =>
      List.unmodifiable(_answeredQuestions);

  String buildAnsweredQuestionsSummary() {
    if (_answeredQuestions.isEmpty) return '';

    final lines = _answeredQuestions.map((qa) {
      final actionLabel = qa.action.toUpperCase();
      return '- [$actionLabel] ${qa.question} → ${_truncate(qa.answer, 120)}';
    });
    return lines.join('\n');
  }

  /// Checks whether a question has already been answered (fuzzy match).
  bool isQuestionAlreadyAnswered(String question) {
    final normalized = _normalizeForComparison(question);
    if (normalized.isEmpty) return false;

    for (final qa in _answeredQuestions) {
      final existing = _normalizeForComparison(qa.question);
      if (existing.isEmpty) continue;
      // Simple containment check — good enough for dedup.
      if (normalized.contains(existing) || existing.contains(normalized)) {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Rolling summarization for long sessions
  // ---------------------------------------------------------------------------

  /// Summarizes [segments] into a compact chunk and adds it to the archive.
  ///
  /// This is called when the engine caps finalized segments to free memory.
  /// The [llm] service is used for summarization; if it fails the raw text
  /// is stored as-is.
  Future<void> compactOldSegments(
    List<TranscriptSegment> segments,
    LlmService llm,
  ) async {
    if (segments.isEmpty) return;

    final rawText = segments.map((s) => s.text).join('\n');
    final timestamp = segments.first.timestamp;

    try {
      final summary = await llm.getResponse(
        systemPrompt:
            'Summarize this conversation excerpt in 2-3 sentences. Be concise.',
        messages: [
          ChatMessage(
            role: 'user',
            content: 'Summarize:\n$rawText',
          ),
        ],
      );
      _archivedChunks.add(_SummarizedChunk(
        summary: summary.trim(),
        timestamp: timestamp,
        segmentCount: segments.length,
      ));

      // Roll the oldest archived chunks into the rolling summary when there
      // are more than 10 archived chunks.
      if (_archivedChunks.length > 10) {
        await _rollOldestChunks(llm);
      }
    } catch (e) {
      appLogger.w('[SessionContextManager] Summarization failed, '
          'storing raw excerpt: $e');
      // Fallback: store a truncated raw version.
      _archivedChunks.add(_SummarizedChunk(
        summary: _truncate(rawText, 500),
        timestamp: timestamp,
        segmentCount: segments.length,
      ));
    }
  }

  Future<void> _rollOldestChunks(LlmService llm) async {
    if (_archivedChunks.length <= 5) return;

    final toRoll = _archivedChunks.sublist(0, 5);
    final combinedText = toRoll.map((c) => c.summary).join('\n');

    try {
      final existingOverview =
          _rollingSummary.isNotEmpty ? 'Previous overview:\n$_rollingSummary\n\n' : '';
      final summary = await llm.getResponse(
        systemPrompt:
            'Merge these conversation summaries into one concise overview '
            '(3-5 sentences max).',
        messages: [
          ChatMessage(
            role: 'user',
            content: '${existingOverview}New summaries:\n$combinedText',
          ),
        ],
      );
      _rollingSummary = summary.trim();
      _archivedChunks.removeRange(0, 5);
    } catch (e) {
      appLogger.w('[SessionContextManager] Rolling summary failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Token estimation helpers
  // ---------------------------------------------------------------------------

  /// Rough token estimate: English words ~1.3 tokens each,
  /// CJK characters ~0.7 tokens each.
  static int _estimateTokens(String text) {
    if (text.isEmpty) return 0;

    // Count CJK characters
    final cjkCount =
        RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]').allMatches(text).length;
    // Count non-CJK words
    final nonCjk = text.replaceAll(
      RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]'),
      '',
    );
    final wordCount =
        nonCjk.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return ((wordCount * 1.3) + (cjkCount * 0.7)).round();
  }

  /// Truncate [text] so that its estimated token count fits within [budget].
  static String _truncateToTokenBudget(String text, int budget) {
    final words = text.split(RegExp(r'(\s+)'));
    final buffer = StringBuffer();
    var tokens = 0;
    for (final word in words) {
      final wordTokens = _estimateTokens(word);
      if (tokens + wordTokens > budget) break;
      buffer.write(word);
      tokens += wordTokens;
    }
    return buffer.toString().trim();
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String _normalizeForComparison(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// An archived chunk of conversation that has been summarized.
class _SummarizedChunk {
  final String summary;
  final DateTime timestamp;
  final int segmentCount;

  _SummarizedChunk({
    required this.summary,
    required this.timestamp,
    required this.segmentCount,
  });
}
