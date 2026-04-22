import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/app_logger.dart';
import 'cited_fact_check_result.dart';

/// One-shot fact-checker using the OpenAI Responses API with the built-in
/// `web_search` tool.
///
/// Docs: https://developers.openai.com/api/docs/guides/tools-web-search
///
/// Unlike the Tavily path (search → light-LLM verify as two separate calls),
/// this fact-checker issues a single `/v1/responses` call. The model is
/// instructed to search the web if it feels it is necessary to verify the
/// answer, then return a JSON verdict in the same shape as the Tavily verify
/// prompt. Citations come back as `url_citation` annotations on the output
/// message and are converted into [CitedSource] entries.
///
/// Failure policy matches [TavilySearchProvider]: any network or parse
/// failure resolves to `null` (caller emits nothing). Active fact-checking
/// must never break the primary answer path.
class OpenAiWebSearchFactChecker {
  OpenAiWebSearchFactChecker({
    required this.apiKey,
    this.model = 'gpt-4.1-mini',
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  static final Uri _endpoint = Uri.parse('https://api.openai.com/v1/responses');

  final String apiKey;
  final String model;
  final http.Client _client;

  /// Run a fact-check. Returns `null` on any failure.
  Future<CitedFactCheckResult?> check({
    required String question,
    required String answer,
  }) async {
    if (apiKey.isEmpty || answer.trim().length < 20) return null;

    final instructions = '''You are fact-checking an AI answer.

Question: $question
Answer: $answer

If you feel it is necessary, use the web_search tool to verify factual
claims in the answer. Then respond with JSON only (no markdown fence):

{"verdict": "supported" | "contradicted" | "unclear",
 "correction": "one-sentence correction or null"}

- "supported"    = web sources agree with the answer, or the claims are
                   well-known and uncontroversial.
- "contradicted" = at least one source clearly contradicts the answer;
                   put the correction in "correction".
- "unclear"      = sources are off-topic, ambiguous, or the claim cannot
                   be verified.

Only the JSON object, nothing else.''';

    try {
      final response = await _client.post(
        _endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'input': instructions,
          'tools': [
            {'type': 'web_search'},
          ],
        }),
      );

      if (response.statusCode != 200) {
        final body = response.body;
        appLogger.d(
          '[OpenAiFactCheck] non-200 ${response.statusCode}: '
          '${body.length > 200 ? body.substring(0, 200) : body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final outputText = _extractOutputText(decoded);
      if (outputText == null || outputText.trim().isEmpty) {
        appLogger.d('[OpenAiFactCheck] empty output_text');
        return null;
      }

      final verdictJson = _parseVerdictJson(outputText);
      if (verdictJson == null) {
        appLogger.d(
          '[OpenAiFactCheck] could not parse JSON verdict from: '
          '${outputText.length > 200 ? outputText.substring(0, 200) : outputText}',
        );
        return null;
      }

      final verdict = factCheckVerdictFromString(
        verdictJson['verdict'] as String?,
      );
      String? correction;
      final rawCorrection = verdictJson['correction'];
      if (rawCorrection is String) {
        final t = rawCorrection.trim();
        if (t.isNotEmpty && t.toLowerCase() != 'null') {
          correction = t;
        }
      }

      final sources = _extractCitations(decoded);

      appLogger.d(
        '[OpenAiFactCheck] verdict=${verdict.name} '
        'sources=${sources.length} correction=${correction != null}',
      );

      return CitedFactCheckResult(
        verdict: verdict,
        correction: correction,
        sources: sources,
      );
    } catch (e) {
      appLogger.d('[OpenAiFactCheck] failed: $e');
      return null;
    }
  }

  /// Pull all text from `output[].content[].text` where type is `output_text`.
  String? _extractOutputText(Map<String, dynamic> body) {
    // Prefer the convenience field if present (some SDKs surface it).
    final direct = body['output_text'];
    if (direct is String && direct.trim().isNotEmpty) return direct;

    final output = body['output'];
    if (output is! List) return null;
    final buf = StringBuffer();
    for (final item in output) {
      if (item is! Map) continue;
      if (item['type'] != 'message') continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final c in content) {
        if (c is! Map) continue;
        if (c['type'] == 'output_text') {
          final t = c['text'];
          if (t is String) buf.write(t);
        }
      }
    }
    final result = buf.toString();
    return result.isEmpty ? null : result;
  }

  /// Pull `url_citation` annotations from every message block.
  List<CitedSource> _extractCitations(Map<String, dynamic> body) {
    final output = body['output'];
    if (output is! List) return const [];
    final seen = <String>{};
    final sources = <CitedSource>[];
    for (final item in output) {
      if (item is! Map) continue;
      if (item['type'] != 'message') continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final c in content) {
        if (c is! Map) continue;
        final annotations = c['annotations'];
        if (annotations is! List) continue;
        for (final a in annotations) {
          if (a is! Map) continue;
          if (a['type'] != 'url_citation') continue;
          final url = (a['url'] ?? '').toString().trim();
          if (url.isEmpty || !seen.add(url)) continue;
          final title = (a['title'] ?? '').toString().trim();
          sources.add(
            CitedSource(
              url: url,
              title: title.isEmpty ? url : title,
              snippet: '',
            ),
          );
        }
      }
    }
    return sources;
  }

  /// Extract the first top-level JSON object from a possibly chatty response.
  Map<String, dynamic>? _parseVerdictJson(String text) {
    final trimmed = text.trim();
    // Strip a markdown fence if the model ignored instructions.
    final cleaned = trimmed
        .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
        .replaceAll(RegExp(r'\s*```$'), '')
        .trim();
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through to substring scan.
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}
