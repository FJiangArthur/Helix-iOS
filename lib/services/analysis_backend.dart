import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class ExtractedFact {
  final String category;
  final String content;
  final String? sourceQuote;
  final double confidence;

  const ExtractedFact({
    required this.category,
    required this.content,
    this.sourceQuote,
    this.confidence = 1.0,
  });

  factory ExtractedFact.fromMap(Map<String, dynamic> map) {
    return ExtractedFact(
      category: map['category'] as String? ?? 'unknown',
      content: map['content'] as String? ?? '',
      sourceQuote: map['sourceQuote'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class ExtractedRelationship {
  final String entityA;
  final String entityB;
  final String type;
  final String? description;

  const ExtractedRelationship({
    required this.entityA,
    required this.entityB,
    required this.type,
    this.description,
  });

  factory ExtractedRelationship.fromMap(Map<String, dynamic> map) {
    return ExtractedRelationship(
      entityA: map['entityA'] as String? ?? '',
      entityB: map['entityB'] as String? ?? '',
      type: map['type'] as String? ?? '',
      description: map['description'] as String?,
    );
  }
}

class BatchAnalysisResult {
  final List<ExtractedFact> facts;
  final List<ExtractedRelationship> relationships;
  final Map<String, dynamic> profileUpdates;
  final List<String> topics;

  const BatchAnalysisResult({
    this.facts = const [],
    this.relationships = const [],
    this.profileUpdates = const {},
    this.topics = const [],
  });

  static const empty = BatchAnalysisResult();

  /// Parse a JSON string into a [BatchAnalysisResult].
  ///
  /// Strips markdown code fences and handles malformed input gracefully by
  /// returning an empty result.
  factory BatchAnalysisResult.fromJson(String raw) {
    try {
      // Strip markdown code fences (```json ... ``` or ``` ... ```)
      var cleaned = raw.trim();
      final fencePattern = RegExp(r'^```(?:json)?\s*\n?', multiLine: true);
      final closeFence = RegExp(r'\n?```\s*$', multiLine: true);
      cleaned = cleaned.replaceAll(fencePattern, '');
      cleaned = cleaned.replaceAll(closeFence, '');
      cleaned = cleaned.trim();

      final map = jsonDecode(cleaned) as Map<String, dynamic>;

      final facts = (map['facts'] as List<dynamic>?)
              ?.map((e) =>
                  ExtractedFact.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];

      final relationships = (map['relationships'] as List<dynamic>?)
              ?.map((e) =>
                  ExtractedRelationship.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];

      final profileUpdates =
          (map['profileUpdates'] as Map<String, dynamic>?) ?? {};

      final topics = (map['topics'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      return BatchAnalysisResult(
        facts: facts,
        relationships: relationships,
        profileUpdates: profileUpdates,
        topics: topics,
      );
    } catch (e) {
      dev.log('BatchAnalysisResult.fromJson failed: $e',
          name: 'analysis_backend');
      return BatchAnalysisResult.empty;
    }
  }
}

// ---------------------------------------------------------------------------
// Abstract interface
// ---------------------------------------------------------------------------

abstract class AnalysisProvider {
  String get id;
  String get displayName;
  bool get isAvailable;

  Future<BatchAnalysisResult> analyze({
    required List<TranscriptSegment> segments,
    required String userProfileJson,
  });
}

// ---------------------------------------------------------------------------
// Cloud implementation (delegates to LlmService)
// ---------------------------------------------------------------------------

class CloudAnalysisProvider implements AnalysisProvider {
  @override
  String get id => 'cloud';

  @override
  String get displayName => 'Cloud LLM';

  @override
  bool get isAvailable {
    try {
      // Accessing activeProvider will throw StateError if none is registered.
      LlmService.instance.activeProvider;
      return true;
    } catch (_) {
      return false;
    }
  }

  static const _systemPrompt = '''
You are a knowledge extraction engine. Analyse the provided conversation transcript and user profile, then reply ONLY with valid JSON (no markdown, no commentary) using this exact schema:

{
  "facts": [
    {
      "category": "<preference|relationship|habit|opinion|goal|biographical|skill>",
      "content": "<concise fact>",
      "sourceQuote": "<verbatim excerpt or null>",
      "confidence": <0.0-1.0>
    }
  ],
  "relationships": [
    {
      "entityA": "<name>",
      "entityB": "<name or org>",
      "type": "<works_at|reports_to|collaborates_with>",
      "description": "<optional context>"
    }
  ],
  "profileUpdates": {
    "<key>": "<value>"
  },
  "topics": ["<topic1>", "<topic2>"]
}

Rules:
- Only include facts with confidence >= 0.6.
- If nothing can be extracted, return empty arrays / objects.
- Do NOT wrap the JSON in code fences.
''';

  @override
  Future<BatchAnalysisResult> analyze({
    required List<TranscriptSegment> segments,
    required String userProfileJson,
  }) async {
    if (segments.isEmpty) {
      return BatchAnalysisResult.empty;
    }

    final transcript = segments
        .map((s) =>
            '[${s.timestamp.toIso8601String()}] ${s.speakerLabel ?? "unknown"}: ${s.text}')
        .join('\n');

    final userMessage = '''
=== USER PROFILE ===
$userProfileJson

=== TRANSCRIPT ===
$transcript
''';

    final response = await LlmService.instance.getResponse(
      systemPrompt: _systemPrompt,
      messages: [ChatMessage(role: 'user', content: userMessage)],
      model: SettingsManager.instance.resolvedLightModel,
    );

    return BatchAnalysisResult.fromJson(response);
  }
}
