// ABOUTME: Singleton service that generates daily journal entries from conversations.
// ABOUTME: Reads all conversations for a date, sends to LLM for narrative generation, stores in DB.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_logger.dart';
import 'database/helix_database.dart';
import 'llm/llm_provider.dart';
import 'llm/llm_service.dart';
import 'settings_manager.dart';

class DailyMemoryService {
  static DailyMemoryService? _instance;
  static DailyMemoryService get instance =>
      _instance ??= DailyMemoryService._();
  DailyMemoryService._();

  static const _uuid = Uuid();

  /// Generate a daily memory for the given date.
  /// Reads all conversations from that day, sends to LLM for narrative generation.
  Future<void> generateDailyMemory({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = _formatDate(targetDate);

    final db = HelixDatabase.instance;

    // Check if already generated
    final existing = await db.dailyMemoryDao.getDailyMemory(dateStr);
    if (existing != null) {
      appLogger.d('[DailyMemory] Memory for $dateStr already exists, skipping');
      return;
    }

    // Load conversations for the day
    final conversations =
        await db.conversationDao.getConversationsForDate(targetDate);
    if (conversations.isEmpty) {
      appLogger.d('[DailyMemory] No conversations found for $dateStr');
      return;
    }

    appLogger.i(
      '[DailyMemory] Generating memory for $dateStr '
      '(${conversations.length} conversations)',
    );

    // Build context from conversations
    final contextParts = <String>[];
    final conversationIds = <String>[];

    for (final conv in conversations) {
      conversationIds.add(conv.id);

      final segments =
          await db.conversationDao.getSegmentsForConversation(conv.id);
      final topics =
          await db.conversationDao.getTopicsForConversation(conv.id);

      final startTime = DateTime.fromMillisecondsSinceEpoch(conv.startedAt);
      final timeStr =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

      final sb = StringBuffer();
      sb.writeln('--- Conversation at $timeStr ---');
      if (conv.title != null && conv.title!.isNotEmpty) {
        sb.writeln('Title: ${conv.title}');
      }
      if (conv.summary != null && conv.summary!.isNotEmpty) {
        sb.writeln('Summary: ${conv.summary}');
      }
      if (conv.sentiment != null && conv.sentiment!.isNotEmpty) {
        sb.writeln('Sentiment: ${conv.sentiment}');
      }
      if (topics.isNotEmpty) {
        sb.writeln(
          'Topics: ${topics.map((t) => '${t.label} (${t.summary})').join(', ')}',
        );
      }

      // Include transcript excerpts (limit to avoid token overflow)
      if (segments.isNotEmpty) {
        sb.writeln('Transcript excerpt:');
        final segmentsToInclude =
            segments.length > 20 ? segments.sublist(0, 20) : segments;
        for (final seg in segmentsToInclude) {
          final speaker = seg.speakerLabel ?? 'Unknown';
          sb.writeln('  [$speaker]: ${seg.text_}');
        }
        if (segments.length > 20) {
          sb.writeln('  ... (${segments.length - 20} more segments)');
        }
      }

      contextParts.add(sb.toString());
    }

    final conversationContext = contextParts.join('\n\n');

    // Build prompt
    final isChinese = SettingsManager.instance.language == 'zh';
    final systemPrompt = isChinese
        ? _systemPromptChinese
        : _systemPromptEnglish;
    final userMessage = isChinese
        ? '以下是$dateStr的对话记录：\n\n$conversationContext'
        : 'Here are the conversations from $dateStr:\n\n$conversationContext';

    try {
      final llm = LlmService.instance;
      final response = await llm.getResponse(
        systemPrompt: systemPrompt,
        messages: [
          ChatMessage(role: 'user', content: userMessage),
        ],
      );

      // Parse JSON response
      final parsed = _parseResponse(response);
      final narrative = parsed['narrative'] as String? ?? response;
      final themes = (parsed['themes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      // Insert into database
      await db.dailyMemoryDao.insertDailyMemory(
        DailyMemoriesCompanion(
          id: Value(_uuid.v4()),
          date: Value(dateStr),
          narrative: Value(narrative),
          themes: Value(jsonEncode(themes)),
          conversationIds: Value(jsonEncode(conversationIds)),
          generatedAt:
              Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      appLogger.i(
        '[DailyMemory] Generated memory for $dateStr '
        '(${themes.length} themes)',
      );
    } catch (e, st) {
      appLogger.e(
        '[DailyMemory] Failed to generate memory for $dateStr',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Check and generate memory for yesterday (called on app launch or background).
  Future<void> checkAndGenerateYesterday() async {
    if (!SettingsManager.instance.dailyMemoryEnabled) return;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await generateDailyMemory(date: yesterday);
  }

  /// Force-regenerate a memory for the given date (deletes existing first).
  Future<void> regenerateMemory({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = _formatDate(targetDate);
    final db = HelixDatabase.instance;

    final existing = await db.dailyMemoryDao.getDailyMemory(dateStr);
    if (existing != null) {
      await db.dailyMemoryDao.deleteDailyMemory(dateStr);
    }
    await generateDailyMemory(date: targetDate);
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Attempt to parse JSON from the LLM response. Falls back gracefully.
  Map<String, dynamic> _parseResponse(String response) {
    // Try to extract JSON from the response (LLMs sometimes wrap in markdown)
    var jsonStr = response.trim();

    // Strip markdown code fences if present
    final jsonBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = jsonBlockRegex.firstMatch(jsonStr);
    if (match != null) {
      jsonStr = match.group(1)!.trim();
    }

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // If the whole response isn't JSON, treat it as a plain narrative
    }

    return {'narrative': response.trim(), 'themes': <String>[]};
  }

  // ---------------------------------------------------------------------------
  // Prompts
  // ---------------------------------------------------------------------------

  static const _systemPromptEnglish = '''
You are a personal journal assistant. Given a day's conversation transcripts, generate a concise daily memory entry.

Respond with a JSON object containing:
- "narrative": A 2-4 sentence personal journal entry summarizing the day's conversations in first person. Be warm and reflective. Mention key people, topics, and outcomes.
- "themes": An array of 1-5 short theme tags (e.g., "work", "planning", "health", "family", "learning").

Example response:
{
  "narrative": "Had a productive morning discussing the project timeline with Sarah. We agreed on the new deadline and I felt good about the team's direction. Later caught up with Mom about weekend plans.",
  "themes": ["work", "planning", "family"]
}

Respond ONLY with the JSON object, no other text.''';

  static const _systemPromptChinese = '''
你是一个个人日记助手。根据一天的对话记录，生成一条简洁的每日记忆条目。

用JSON对象回复，包含：
- "narrative": 一段2-4句的第一人称日记，总结当天的对话。语气温暖、有思考。提及关键人物、话题和结果。
- "themes": 1-5个简短的主题标签数组（如"工作"、"计划"、"健康"、"家庭"、"学习"）。

示例回复：
{
  "narrative": "上午和Sarah讨论了项目时间线，很有成效。我们商定了新的截止日期，我对团队的方向感觉很好。后来和妈妈聊了周末计划。",
  "themes": ["工作", "计划", "家庭"]
}

只回复JSON对象，不要其他文字。''';
}
