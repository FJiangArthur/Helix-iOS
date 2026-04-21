// ABOUTME: Minimal OpenAI /v1/embeddings client for Project RAG.
// ABOUTME: Batch-embed inputs, returns Float32Lists + usage metadata.

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

abstract class EmbeddingClient {
  Future<EmbeddingBatchResult> embedBatch(List<String> inputs);
  Future<Float32List> embed(String input);
}

class EmbeddingApiException implements Exception {
  EmbeddingApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'EmbeddingApiException($statusCode): $message';
}

class EmbeddingBatchResult {
  const EmbeddingBatchResult({
    required this.vectors,
    required this.promptTokens,
  });
  final List<Float32List> vectors;
  final int promptTokens;
}

class OpenAiEmbeddingsClient implements EmbeddingClient {
  OpenAiEmbeddingsClient({
    required this.apiKey,
    required this.model,
    http.Client? httpClient,
    this.baseUrl = 'https://api.openai.com/v1',
  }) : _http = httpClient ?? http.Client();

  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client _http;

  @override
  Future<EmbeddingBatchResult> embedBatch(List<String> inputs) async {
    if (inputs.isEmpty) {
      throw ArgumentError('inputs must be non-empty');
    }
    final uri = Uri.parse('$baseUrl/embeddings');
    final body = jsonEncode({'model': model, 'input': inputs});
    final resp = await _http.post(uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: body);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EmbeddingApiException(resp.statusCode, resp.body);
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List).cast<Map<String, dynamic>>();
    final vectors = <Float32List>[];
    for (final entry in data) {
      final emb = (entry['embedding'] as List).cast<num>();
      final v = Float32List(emb.length);
      for (var i = 0; i < emb.length; i++) {
        v[i] = emb[i].toDouble();
      }
      vectors.add(v);
    }
    final usage = decoded['usage'] as Map<String, dynamic>?;
    return EmbeddingBatchResult(
      vectors: vectors,
      promptTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  /// Single-input convenience.
  @override
  Future<Float32List> embed(String input) async {
    final result = await embedBatch([input]);
    return result.vectors.single;
  }

  void close() => _http.close();
}
