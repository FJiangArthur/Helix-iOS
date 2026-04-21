import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_helix/services/projects/openai_embeddings_client.dart';

void main() {
  group('OpenAiEmbeddingsClient', () {
    test('posts inputs and parses embeddings into Float32Lists', () async {
      http.BaseRequest? captured;
      final mock = _MockClient((req) async {
        captured = req;
        final body = jsonEncode({
          'data': [
            {'embedding': [0.1, 0.2, 0.3]},
            {'embedding': [0.4, 0.5, 0.6]},
          ],
          'usage': {'prompt_tokens': 42, 'total_tokens': 42},
        });
        return http.Response(body, 200,
            headers: {'content-type': 'application/json'});
      });

      final client = OpenAiEmbeddingsClient(
          apiKey: 'sk-test',
          httpClient: mock,
          model: 'text-embedding-3-small');

      final result = await client.embedBatch(['a', 'b']);
      expect(result.vectors, hasLength(2));
      expect(result.vectors.first, isA<Float32List>());
      expect(result.vectors.first[0], closeTo(0.1, 1e-6));
      expect(result.vectors.last[2], closeTo(0.6, 1e-6));
      expect(result.promptTokens, 42);
      expect(captured!.url.toString(),
          'https://api.openai.com/v1/embeddings');
      expect(captured!.method, 'POST');
    });

    test('throws EmbeddingApiException on non-2xx', () async {
      final mock = _MockClient((_) async =>
          http.Response('{"error":{"message":"bad"}}', 401));
      final client = OpenAiEmbeddingsClient(
          apiKey: 'sk-x', httpClient: mock, model: 'text-embedding-3-small');
      expect(() => client.embedBatch(['a']),
          throwsA(isA<EmbeddingApiException>()));
    });

    test('throws if inputs is empty', () async {
      final client = OpenAiEmbeddingsClient(
          apiKey: 'sk-x', model: 'text-embedding-3-small');
      expect(() => client.embedBatch(const []),
          throwsA(isA<ArgumentError>()));
    });
  });
}

class _MockClient extends http.BaseClient {
  _MockClient(this._handler);
  final Future<http.Response> Function(http.BaseRequest) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Read the body so assertions can inspect it if needed later.
    await request.finalize().toBytes();
    final resp = await _handler(request);
    return http.StreamedResponse(
      Stream.value(resp.bodyBytes),
      resp.statusCode,
      headers: resp.headers,
      request: request,
    );
  }
}
