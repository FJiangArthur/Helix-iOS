import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_logger.dart';
import 'database/helix_database.dart';
import 'llm/llm_provider.dart';
import 'llm/llm_service.dart';
import 'pipeline_prompts.dart';
import 'settings_manager.dart';

/// Processing stage for tracking pipeline progress.
enum PipelineStage {
  pending,
  topicSegmentation,
  summarization,
  toneAnalysis,
  factExtraction,
  actionItemDetection,
  completed,
  failed,
}

/// Orchestrates post-conversation LLM processing.
///
/// After a conversation stops, this service runs a multi-stage pipeline:
/// topic segmentation -> summarization -> tone analysis -> fact extraction -> action items.
/// For short conversations (<500 words), all stages are combined into a single LLM call.
class CloudPipelineService {
  static CloudPipelineService? _instance;
  static CloudPipelineService get instance =>
      _instance ??= CloudPipelineService._();
  CloudPipelineService._();

  static const _uuid = Uuid();

  final _processingController = StreamController<String>.broadcast();

  /// Emits conversation IDs as they complete processing.
  Stream<String> get onProcessingComplete => _processingController.stream;

  /// Set of conversation IDs currently being processed (prevents double-runs).
  final Set<String> _inProgress = {};

  /// Whether a conversation is currently being processed.
  bool isProcessing(String conversationId) =>
      _inProgress.contains(conversationId);

  /// Queue a conversation for processing.
  ///
  /// The conversation must already exist in the database with its segments.
  /// This method is safe to call multiple times for the same conversation;
  /// concurrent runs for the same ID are deduplicated.
  Future<void> processConversation(String conversationId) async {
    final settings = SettingsManager.instance;
    if (!settings.cloudProcessingEnabled) {
      appLogger.i('[Pipeline] Cloud processing disabled, skipping');
      return;
    }

    if (_inProgress.contains(conversationId)) {
      appLogger.i('[Pipeline] Already processing $conversationId, skipping');
      return;
    }

    _inProgress.add(conversationId);

    try {
      final db = HelixDatabase.instance;

      // Load segments
      final segments =
          await db.conversationDao.getSegmentsForConversation(conversationId);
      if (segments.isEmpty) {
        appLogger.w('[Pipeline] No segments for conversation $conversationId');
        return;
      }

      // Build numbered transcript
      final transcriptLines = <String>[];
      for (var i = 0; i < segments.length; i++) {
        final speaker = segments[i].speakerLabel ?? 'Speaker';
        transcriptLines.add('[$i] $speaker: ${segments[i].text_}');
      }
      final transcript = transcriptLines.join('\n');

      final wordCount = transcript.split(RegExp(r'\s+')).length;
      final isChinese = settings.language == 'zh';

      appLogger.i(
        '[Pipeline] Processing conversation $conversationId '
        '($wordCount words, ${segments.length} segments)',
      );

      if (wordCount < 500) {
        await _runCombinedPipeline(conversationId, transcript, isChinese);
      } else {
        await _runStagedPipeline(
            conversationId, transcript, segments, isChinese);
      }

      // Mark conversation as processed
      await db.conversationDao.updateConversation(
        ConversationsCompanion(
          id: Value(conversationId),
          isProcessed: const Value(true),
        ),
      );

      appLogger.i('[Pipeline] Completed processing for $conversationId');
      _processingController.add(conversationId);
    } catch (e, st) {
      appLogger.e(
        '[Pipeline] Failed to process $conversationId',
        error: e,
        stackTrace: st,
      );
    } finally {
      _inProgress.remove(conversationId);
    }
  }

  // ---------------------------------------------------------------------------
  // Combined pipeline (short conversations)
  // ---------------------------------------------------------------------------

  Future<void> _runCombinedPipeline(
    String conversationId,
    String transcript,
    bool isChinese,
  ) async {
    appLogger.d('[Pipeline] Running combined pipeline');

    final prompt =
        PipelinePrompts.combinedAnalysis(transcript, chinese: isChinese);
    final systemPrompt = isChinese
        ? '你是一个对话分析助手。只返回纯JSON，不要使用markdown代码块，不要添加任何额外文本。'
        : 'You are a conversation analyst. Return pure JSON only. No markdown code blocks, no extra text.';

    final response = await _callLlm(systemPrompt, prompt);
    final json = _parseJson(response);
    if (json == null) {
      appLogger.w('[Pipeline] Failed to parse combined analysis response');
      return;
    }

    final db = HelixDatabase.instance;

    // --- Title, summary, sentiment ---
    final title = json['title'] as String? ?? '';
    final summary = json['summary'] as String? ?? '';
    final sentiment = _normalizeSentiment(json['sentiment'] as String?);
    final toneAnalysis = json['toneAnalysis'] as Map<String, dynamic>?;

    await db.conversationDao.updateConversation(
      ConversationsCompanion(
        id: Value(conversationId),
        title: Value(title),
        summary: Value(summary),
        sentiment: Value(sentiment),
        toneAnalysis:
            Value(toneAnalysis != null ? jsonEncode(toneAnalysis) : null),
      ),
    );

    // --- Topics ---
    final topics = _extractList(json, 'topics');
    await _storeTopics(conversationId, topics);

    // --- Facts ---
    final settings = SettingsManager.instance;
    if (settings.factsExtractionEnabled) {
      final facts = _extractList(json, 'facts');
      await _storeFacts(conversationId, facts);
    }

    // --- Action items ---
    final actionItems = _extractList(json, 'actionItems');
    await _storeActionItems(conversationId, actionItems);
  }

  // ---------------------------------------------------------------------------
  // Staged pipeline (longer conversations)
  // ---------------------------------------------------------------------------

  Future<void> _runStagedPipeline(
    String conversationId,
    String transcript,
    List<ConversationSegment> segments,
    bool isChinese,
  ) async {
    final db = HelixDatabase.instance;
    final systemPrompt = isChinese
        ? '你是一个对话分析助手。只返回纯JSON，不要使用markdown代码块，不要添加任何额外文本。'
        : 'You are a conversation analyst. Return pure JSON only. No markdown code blocks, no extra text.';

    // Stage 1: Topic segmentation
    appLogger.d('[Pipeline] Stage 1: Topic segmentation');
    List<Map<String, dynamic>> topics = [];
    try {
      final topicPrompt =
          PipelinePrompts.topicSegmentation(transcript, chinese: isChinese);
      final topicResponse = await _callLlm(systemPrompt, topicPrompt);
      final topicJson = _parseJson(topicResponse);
      if (topicJson != null) {
        topics = _extractList(topicJson, 'topics');
        await _storeTopics(conversationId, topics);
      }
    } catch (e) {
      appLogger.w('[Pipeline] Topic segmentation failed', error: e);
    }

    // Stage 2: Summarization
    appLogger.d('[Pipeline] Stage 2: Summarization');
    try {
      final summaryPrompt = PipelinePrompts.summarization(
        transcript,
        topics,
        chinese: isChinese,
      );
      final summaryResponse = await _callLlm(systemPrompt, summaryPrompt);
      final summaryJson = _parseJson(summaryResponse);
      if (summaryJson != null) {
        final title = summaryJson['title'] as String? ?? '';
        final summary = summaryJson['summary'] as String? ?? '';

        // Update per-topic summaries if available
        final topicSummaries =
            summaryJson['topicSummaries'] as Map<String, dynamic>?;
        if (topicSummaries != null) {
          for (final topic in topics) {
            final label = topic['label'] as String?;
            if (label != null && topicSummaries.containsKey(label)) {
              topic['summary'] = topicSummaries[label];
            }
          }
        }

        await db.conversationDao.updateConversation(
          ConversationsCompanion(
            id: Value(conversationId),
            title: Value(title),
            summary: Value(summary),
          ),
        );
      }
    } catch (e) {
      appLogger.w('[Pipeline] Summarization failed', error: e);
    }

    // Stage 3: Tone analysis
    appLogger.d('[Pipeline] Stage 3: Tone analysis');
    try {
      final tonePrompt =
          PipelinePrompts.toneAnalysis(transcript, chinese: isChinese);
      final toneResponse = await _callLlm(systemPrompt, tonePrompt);
      final toneJson = _parseJson(toneResponse);
      if (toneJson != null) {
        final sentiment =
            _normalizeSentiment(toneJson['sentiment'] as String?);
        final toneAnalysis = toneJson['toneAnalysis'] as Map<String, dynamic>?;

        await db.conversationDao.updateConversation(
          ConversationsCompanion(
            id: Value(conversationId),
            sentiment: Value(sentiment),
            toneAnalysis:
                Value(toneAnalysis != null ? jsonEncode(toneAnalysis) : null),
          ),
        );
      }
    } catch (e) {
      appLogger.w('[Pipeline] Tone analysis failed', error: e);
    }

    // Stage 4: Fact extraction
    final settings = SettingsManager.instance;
    if (settings.factsExtractionEnabled) {
      appLogger.d('[Pipeline] Stage 4: Fact extraction');
      try {
        final existingFacts = await db.factsDao.getConfirmedFacts(limit: 50);
        final existingFactStrings =
            existingFacts.map((f) => f.content).toList();

        final factPrompt = PipelinePrompts.factExtraction(
          transcript,
          existingFactStrings,
          chinese: isChinese,
        );
        final factResponse = await _callLlm(systemPrompt, factPrompt);
        final factJson = _parseJson(factResponse);
        if (factJson != null) {
          final facts = _extractList(factJson, 'facts');
          await _storeFacts(conversationId, facts);
        }
      } catch (e) {
        appLogger.w('[Pipeline] Fact extraction failed', error: e);
      }
    } else {
      appLogger.d('[Pipeline] Stage 4: Fact extraction skipped (disabled)');
    }

    // Stage 5: Action item detection
    appLogger.d('[Pipeline] Stage 5: Action item detection');
    try {
      final actionPrompt =
          PipelinePrompts.actionItemDetection(transcript, chinese: isChinese);
      final actionResponse = await _callLlm(systemPrompt, actionPrompt);
      final actionJson = _parseJson(actionResponse);
      if (actionJson != null) {
        final actionItems = _extractList(actionJson, 'actionItems');
        await _storeActionItems(conversationId, actionItems);
      }
    } catch (e) {
      appLogger.w('[Pipeline] Action item detection failed', error: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Storage helpers
  // ---------------------------------------------------------------------------

  Future<void> _storeTopics(
    String conversationId,
    List<Map<String, dynamic>> topics,
  ) async {
    final db = HelixDatabase.instance;
    for (var i = 0; i < topics.length; i++) {
      final t = topics[i];
      final label = t['label'] as String? ?? 'Topic ${i + 1}';
      final summary = t['summary'] as String? ?? '';
      final indices = t['segmentIndices'] as List<dynamic>? ?? [];
      final segmentRange = indices.join(',');

      try {
        await db.conversationDao.insertTopic(
          TopicsCompanion.insert(
            id: _uuid.v4(),
            conversationId: conversationId,
            label: label,
            summary: Value(summary),
            segmentRange: Value(segmentRange),
            sortOrder: Value(i),
          ),
        );
      } catch (e) {
        appLogger.w(
          '[Pipeline] Failed to insert topic '
          '(labelChars=${label.length})',
          error: e,
        );
      }
    }
  }

  Future<void> _storeFacts(
    String conversationId,
    List<Map<String, dynamic>> facts,
  ) async {
    final db = HelixDatabase.instance;
    for (final f in facts) {
      final category = _normalizeFactCategory(f['category'] as String?);
      final content = f['content'] as String? ?? '';
      final quote = f['quote'] as String?;
      final confidence = _parseDouble(f['confidence'], fallback: 0.7);

      if (content.isEmpty) continue;

      final dedupeKey = _generateDedupeKey(content);

      // Check for existing fact with same dedupe key
      try {
        final existing = await db.factsDao.getFactsByDedupeKey(dedupeKey);
        if (existing.isNotEmpty) {
          appLogger.d(
            '[Pipeline] Skipping duplicate fact '
            '(contentChars=${content.length})',
          );
          continue;
        }

        await db.factsDao.insertFact(
          FactsCompanion.insert(
            id: _uuid.v4(),
            conversationId: Value(conversationId),
            category: category,
            content: content,
            sourceQuote: Value(quote),
            confidence: Value(confidence),
            status: const Value('pending'),
            dedupeKey: Value(dedupeKey),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (e) {
        appLogger.w('[Pipeline] Failed to insert fact', error: e);
      }
    }
  }

  Future<void> _storeActionItems(
    String conversationId,
    List<Map<String, dynamic>> actionItems,
  ) async {
    final db = HelixDatabase.instance;
    for (final item in actionItems) {
      final content = item['content'] as String? ?? '';
      if (content.isEmpty) continue;

      int? dueDate;
      final dueDateStr = item['dueDate'] as String?;
      if (dueDateStr != null && dueDateStr != 'null') {
        try {
          dueDate = DateTime.parse(dueDateStr).millisecondsSinceEpoch;
        } catch (_) {
          // Ignore invalid date strings
        }
      }

      try {
        await db.todoDao.insertTodo(
          TodosCompanion.insert(
            id: _uuid.v4(),
            conversationId: Value(conversationId),
            content: content,
            dueDate: Value(dueDate),
            createdAt: DateTime.now().millisecondsSinceEpoch,
            source: const Value('auto'),
          ),
        );
      } catch (e) {
        appLogger.w('[Pipeline] Failed to insert action item', error: e);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // LLM call helper
  // ---------------------------------------------------------------------------

  Future<String> _callLlm(String systemPrompt, String userPrompt) {
    return LlmService.instance.getResponse(
      systemPrompt: systemPrompt,
      messages: [ChatMessage(role: 'user', content: userPrompt)],
      model: SettingsManager.instance.resolvedLightModel,
    );
  }

  // ---------------------------------------------------------------------------
  // JSON parsing
  // ---------------------------------------------------------------------------

  /// Parse a JSON string from an LLM response, handling common issues:
  /// - Markdown code blocks (```json ... ```)
  /// - Leading/trailing whitespace and text
  /// - Trailing commas
  static Map<String, dynamic>? _parseJson(String raw) {
    var cleaned = raw.trim();

    // Strip markdown code blocks
    final codeBlockPattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final codeBlockMatch = codeBlockPattern.firstMatch(cleaned);
    if (codeBlockMatch != null) {
      cleaned = codeBlockMatch.group(1)!.trim();
    }

    // If response starts with text before JSON, try to find the JSON object
    if (!cleaned.startsWith('{')) {
      final jsonStart = cleaned.indexOf('{');
      if (jsonStart == -1) return null;
      cleaned = cleaned.substring(jsonStart);
    }

    // Find the matching closing brace
    var braceDepth = 0;
    var jsonEnd = -1;
    for (var i = 0; i < cleaned.length; i++) {
      if (cleaned[i] == '{') {
        braceDepth++;
      } else if (cleaned[i] == '}') {
        braceDepth--;
        if (braceDepth == 0) {
          jsonEnd = i;
          break;
        }
      }
    }
    if (jsonEnd != -1) {
      cleaned = cleaned.substring(0, jsonEnd + 1);
    }

    // Remove trailing commas before } or ]
    cleaned = cleaned.replaceAll(RegExp(r',\s*([}\]])'), r'$1');

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      appLogger.w('[Pipeline] JSON parse error: $e');
      appLogger.d(
        '[Pipeline] Raw response omitted for privacy '
        '(chars=${raw.length})',
      );
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Normalization helpers
  // ---------------------------------------------------------------------------

  /// Ensure sentiment is one of the allowed values.
  static String _normalizeSentiment(String? raw) {
    if (raw == null) return 'neutral';
    final lower = raw.toLowerCase().trim();
    if (lower.contains('positive')) return 'positive';
    if (lower.contains('negative')) return 'negative';
    return 'neutral';
  }

  /// Ensure fact category is one of the allowed values.
  static String _normalizeFactCategory(String? raw) {
    const allowed = {
      'preference',
      'relationship',
      'habit',
      'opinion',
      'goal',
      'biographical',
      'skill',
    };
    if (raw == null) return 'biographical';
    final lower = raw.toLowerCase().trim();
    return allowed.contains(lower) ? lower : 'biographical';
  }

  /// Parse a double from a JSON value that might be int, double, or String.
  static double _parseDouble(dynamic value, {double fallback = 0.5}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely extract a list of maps from a JSON map by [key].
  static List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> json,
    String key,
  ) {
    final raw = json[key];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  /// Generate a normalized dedupe key for a fact's content.
  ///
  /// Strips punctuation, removes common stop words, sorts remaining words,
  /// and joins them. Two facts with the same meaning should produce similar keys.
  static String _generateDedupeKey(String content) {
    const stopwords = {
      'the', 'a', 'an', 'is', 'are', 'was', 'were', 'his', 'her', 'their',
      'my', 'your', 'its', 'he', 'she', 'they', 'it', 'this', 'that',
      'has', 'have', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
      'should', 'may', 'might', 'can', 'be', 'been', 'being', 'to', 'of',
      'in', 'for', 'on', 'with', 'at', 'by', 'from', 'as', 'into', 'about',
      'and', 'or', 'but', 'not', 'no', 'so', 'if', 'then', 'than', 'very',
      // Chinese stop words
      '的', '了', '是', '在', '有', '和', '就', '不', '人', '都', '一',
      '个', '上', '也', '很', '到', '说', '要', '去', '你', '会', '着',
      '没有', '看', '好', '自己', '这',
    };
    final words = content
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !stopwords.contains(w))
        .toList()
      ..sort();
    return words.join(' ');
  }

  /// Clean up resources.
  void dispose() {
    _processingController.close();
  }
}
