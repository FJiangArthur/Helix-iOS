import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_helix/services/factcheck/tavily_search_provider.dart';

void main() {
  group('TavilySearchProvider', () {
    test('returns empty list when api key is empty', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final p = TavilySearchProvider(apiKey: '', httpClient: client);
      final r = await p.search('hello');
      expect(r, isEmpty);
    });

    test('returns empty list on non-200', () async {
      final client = MockClient(
        (req) async => http.Response('nope', 401),
      );
      final p = TavilySearchProvider(apiKey: 'tvly-x', httpClient: client);
      final r = await p.search('hello');
      expect(r, isEmpty);
    });

    test('returns empty list on bad JSON', () async {
      final client = MockClient((_) async => http.Response('not json', 200));
      final p = TavilySearchProvider(apiKey: 'tvly-x', httpClient: client);
      final r = await p.search('hello');
      expect(r, isEmpty);
    });

    test('parses results correctly and posts expected body', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'url': 'https://example.com/a',
                'title': 'A',
                'content': 'Snippet A',
                'score': 0.9,
              },
              {
                'url': 'https://example.com/b',
                'title': 'B',
                'content': 'Snippet B',
              },
              {
                // Missing url/title should be dropped.
                'title': '',
                'url': '',
                'content': 'drop me',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final p = TavilySearchProvider(apiKey: 'tvly-key', httpClient: client);
      final r = await p.search('iphone launch year', maxResults: 3);

      expect(r, hasLength(2));
      expect(r[0].url, 'https://example.com/a');
      expect(r[0].title, 'A');
      expect(r[0].snippet, 'Snippet A');
      expect(r[0].score, 0.9);
      expect(r[1].score, isNull);

      // Request inspection.
      expect(
        captured.url.toString(),
        'https://api.tavily.com/search',
      );
      expect(captured.method, 'POST');
      expect(captured.headers['Content-Type'], 'application/json');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['api_key'], 'tvly-key');
      expect(body['query'], 'iphone launch year');
      expect(body['max_results'], 3);
      expect(body['include_answer'], false);
    });

    test('network exception is swallowed to empty list', () async {
      final client = MockClient((_) async {
        throw Exception('boom');
      });
      final p = TavilySearchProvider(apiKey: 'tvly-x', httpClient: client);
      final r = await p.search('hello');
      expect(r, isEmpty);
    });
  });
}
