import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/app_logger.dart';
import 'web_search_provider.dart';

/// Tavily REST search provider.
///
/// Endpoint: `POST https://api.tavily.com/search`
/// Body: `{api_key, query, max_results, include_answer: false}`
/// Response shape (we only consume what we need):
/// `{"results": [{"url": ..., "title": ..., "content": ..., "score": ...}]}`
///
/// On any failure (network, non-200, malformed JSON) this returns an empty
/// list and logs at debug level — active fact-checking must never break the
/// primary answer path.
class TavilySearchProvider implements WebSearchProvider {
  TavilySearchProvider({required this.apiKey, http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  static final Uri _endpoint = Uri.parse('https://api.tavily.com/search');

  final String apiKey;
  final http.Client _client;

  @override
  Future<List<WebSearchResult>> search(
    String query, {
    int maxResults = 3,
  }) async {
    if (apiKey.isEmpty || query.trim().isEmpty) {
      return const [];
    }
    try {
      final response = await _client.post(
        _endpoint,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'api_key': apiKey,
          'query': query,
          'max_results': maxResults,
          'include_answer': false,
        }),
      );
      if (response.statusCode != 200) {
        appLogger.d(
          '[Tavily] non-200 ${response.statusCode}: '
          '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
        );
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final raw = decoded['results'];
      if (raw is! List) return const [];
      final results = <WebSearchResult>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final url = (entry['url'] ?? '').toString().trim();
        final title = (entry['title'] ?? '').toString().trim();
        final content = (entry['content'] ?? '').toString().trim();
        if (url.isEmpty || title.isEmpty) continue;
        final scoreRaw = entry['score'];
        final score = scoreRaw is num ? scoreRaw.toDouble() : null;
        results.add(
          WebSearchResult(
            url: url,
            title: title,
            snippet: content,
            score: score,
          ),
        );
      }
      return results;
    } catch (e) {
      appLogger.d('[Tavily] search failed: $e');
      return const [];
    }
  }
}
