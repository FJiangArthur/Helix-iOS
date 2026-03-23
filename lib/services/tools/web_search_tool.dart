import 'dart:convert';
import 'dart:io';

import '../llm/llm_provider.dart';

/// Web search tool definition for LLM function calling.
class WebSearchTool {
  static const definition = ToolDefinition(
    name: 'web_search',
    description:
        'Search the web for current information. Use for fact-checking, '
        'finding recent events, or answering questions that need up-to-date data.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'The search query',
        },
      },
      'required': ['query'],
    },
  );

  /// Execute a web search and return results as text.
  static Future<String> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query'] as String? ?? '';
    if (query.isEmpty) return 'No search query provided';

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final uri = Uri.parse(
        'https://api.duckduckgo.com/'
        '?q=${Uri.encodeComponent(query)}&format=json&no_html=1',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        return 'Search request failed with status ${response.statusCode}';
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10), onTimeout: () => '');
      final json = jsonDecode(body) as Map<String, dynamic>;

      final parts = <String>[];

      // Abstract text (main summary)
      final abstractText = json['AbstractText'] as String? ?? '';
      if (abstractText.isNotEmpty) {
        final source = json['AbstractSource'] as String? ?? '';
        parts.add('Summary: $abstractText');
        if (source.isNotEmpty) parts.add('Source: $source');
      }

      // Related topics
      final relatedTopics = json['RelatedTopics'] as List<dynamic>? ?? [];
      var topicCount = 0;
      for (final topic in relatedTopics) {
        if (topicCount >= 5) break;
        if (topic is Map<String, dynamic>) {
          final text = topic['Text'] as String? ?? '';
          if (text.isNotEmpty) {
            parts.add('- $text');
            topicCount++;
          }
        }
      }

      if (parts.isEmpty) {
        return 'No results found for "$query"';
      }

      return parts.join('\n');
    } on SocketException catch (e) {
      return 'Network error during search: ${e.message}';
    } catch (e) {
      return 'Search error: $e';
    } finally {
      client?.close();
    }
  }
}
