import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../utils/app_logger.dart';
import '../database/helix_database.dart';
import '../llm/llm_provider.dart';
import '../llm/llm_service.dart';
import '../settings_manager.dart';

/// Extracts personal facts from conversation transcripts using the LLM and
/// stores them as pending entries in the database for user review.
class FactExtractionService {
  static FactExtractionService? _instance;
  static FactExtractionService get instance =>
      _instance ??= FactExtractionService._();

  FactExtractionService._();

  static const _uuid = Uuid();

  // Common English stop-words used for dedupe key generation.
  static const _stopWords = <String>{
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'shall',
    'should', 'may', 'might', 'must', 'can', 'could', 'i', 'me', 'my',
    'we', 'our', 'you', 'your', 'he', 'she', 'it', 'they', 'them', 'this',
    'that', 'of', 'in', 'to', 'for', 'with', 'on', 'at', 'from', 'by',
    'about', 'as', 'into', 'through', 'during', 'before', 'after', 'and',
    'but', 'or', 'not', 'no', 'so', 'if', 'then', 'than', 'too', 'very',
    'just', 'also', 'like', 'really', 'actually', 'basically',
  };

  /// Run fact extraction on the given [transcript] from [conversationId].
  ///
  /// Skips silently when fact extraction is disabled in settings or the
  /// transcript is too short to be meaningful.
  Future<int> extractFacts(
    String conversationId,
    String transcript,
  ) async {
    if (!SettingsManager.instance.factsExtractionEnabled) return 0;
    if (transcript.trim().length < 40) return 0;

    try {
      final existingFacts = await _loadExistingFacts();
      final prompt = _buildSystemPrompt(existingFacts);

      final response = await LlmService.instance.getResponse(
        systemPrompt: prompt,
        messages: [
          ChatMessage(role: 'user', content: transcript),
        ],
        model: SettingsManager.instance.resolvedLightModel,
      );

      final parsed = _parseResponse(response);
      if (parsed.isEmpty) return 0;

      int inserted = 0;
      final dao = HelixDatabase.instance.factsDao;

      for (final raw in parsed) {
        final content = (raw['content'] as String?)?.trim() ?? '';
        if (content.isEmpty) continue;

        final category = _normalizeCategory(raw['category'] as String? ?? '');
        final quote = (raw['quote'] as String?)?.trim();
        final confidence =
            ((raw['confidence'] as num?)?.toDouble() ?? 0.5).clamp(0.0, 1.0);

        final dedupeKey = _generateDedupeKey(content);
        if (await _isDuplicate(dedupeKey)) continue;

        await dao.insertFact(FactsCompanion(
          id: Value(_uuid.v4()),
          conversationId: Value(conversationId),
          category: Value(category),
          content: Value(content),
          sourceQuote: Value(quote),
          confidence: Value(confidence),
          status: const Value('pending'),
          dedupeKey: Value(dedupeKey),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
        inserted++;
      }

      appLogger.i('[FactExtraction] Extracted $inserted new facts '
          'from conversation $conversationId');
      return inserted;
    } catch (e, st) {
      appLogger.e('[FactExtraction] Extraction failed',
          error: e, stackTrace: st);
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Prompt
  // ---------------------------------------------------------------------------

  String _buildSystemPrompt(List<String> existingFacts) {
    final language = SettingsManager.instance.language;
    final isZh = language.startsWith('zh');

    final existingBlock = existingFacts.isEmpty
        ? ''
        : '\n\nAlready known facts (DO NOT re-extract these):\n'
            '${existingFacts.map((f) => '- $f').join('\n')}';

    if (isZh) {
      return '''你是一个个人信息提取助手。从用户的对话记录中识别关于用户本人的事实。

规则：
1. 只提取关于用户（说话者）的信息，不要提取关于AI助手的信息
2. 每个事实应简洁明了（一句话）
3. category必须是以下之一：preference, relationship, habit, opinion, goal, biographical, skill
4. confidence取值0.0-1.0，表示该事实的确定程度
5. quote引用原文中支持该事实的关键句子
6. 返回JSON数组格式，无其他文字

返回格式：
[{"category": "...", "content": "...", "quote": "...", "confidence": 0.8}]

如果没有可提取的个人事实，返回空数组 []$existingBlock''';
    }

    return '''You are a personal fact extraction assistant. Identify facts about the USER from their conversation transcript.

Rules:
1. Only extract facts about the USER (the speaker), never about the AI assistant
2. Each fact should be a single concise sentence
3. category must be one of: preference, relationship, habit, opinion, goal, biographical, skill
4. confidence is 0.0-1.0 indicating how certain the fact is
5. quote should reference the key sentence from the transcript supporting the fact
6. Return a JSON array only, no other text

Return format:
[{"category": "...", "content": "...", "quote": "...", "confidence": 0.8}]

If no personal facts can be extracted, return an empty array []$existingBlock''';
  }

  Future<List<String>> _loadExistingFacts() async {
    final dao = HelixDatabase.instance.factsDao;
    final confirmed = await dao.getConfirmedFacts(limit: 50);
    return confirmed.map((f) => f.content).toList();
  }

  // ---------------------------------------------------------------------------
  // Response parsing
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _parseResponse(String response) {
    try {
      // Strip markdown code fences if present.
      var cleaned = response.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
        cleaned = cleaned.trim();
      }

      // Find the JSON array within the response.
      final startIdx = cleaned.indexOf('[');
      final endIdx = cleaned.lastIndexOf(']');
      if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) return [];

      final jsonStr = cleaned.substring(startIdx, endIdx + 1);
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .where((m) => m.containsKey('content'))
          .toList();
    } catch (e) {
      appLogger.w('[FactExtraction] Failed to parse LLM response: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Deduplication
  // ---------------------------------------------------------------------------

  String _generateDedupeKey(String content) {
    final lower = content.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final tokens = lower
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList()
      ..sort();
    return tokens.join('_');
  }

  Future<bool> _isDuplicate(String dedupeKey) async {
    final dao = HelixDatabase.instance.factsDao;
    final matches = await dao.getFactsByDedupeKey(dedupeKey);
    // Consider it a duplicate if any non-rejected match exists.
    return matches.any((f) => f.status != 'rejected');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _normalizeCategory(String raw) {
    final lower = raw.toLowerCase().trim();
    const valid = {
      'preference', 'relationship', 'habit', 'opinion', 'goal',
      'biographical', 'skill',
    };
    return valid.contains(lower) ? lower : 'biographical';
  }
}
