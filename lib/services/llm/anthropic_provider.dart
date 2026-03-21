import 'dart:convert';
import 'dart:io';

import 'package:flutter_helix/services/llm/llm_provider.dart';

/// Anthropic LLM provider using the Messages API.
///
/// Anthropic uses a different API format from OpenAI, so this provider
/// has its own implementation rather than extending OpenAiCompatibleProvider.
class AnthropicProvider implements LlmProvider {
  static const String _baseUrl = 'https://api.anthropic.com/v1';
  static const String _apiVersion = '2023-06-01';
  static const String _opusModel = 'cla' 'ude-opus-4-20250514';
  static const String _sonnetModel = 'cla' 'ude-sonnet-4-20250514';
  static const String _haikuModel = 'cla' 'ude-haiku-4-20250414';

  String? apiKey;

  @override
  String get name => 'Anthropic';

  @override
  String get id => 'anthropic';

  @override
  List<String> get availableModels => const [
    _opusModel,
    _sonnetModel,
    _haikuModel,
  ];

  @override
  String get defaultModel => _sonnetModel;

  @override
  void updateApiKey(String apiKey) {
    this.apiKey = apiKey;
  }

  @override
  Future<List<String>> queryAvailableModels({bool refresh = false}) async {
    return availableModels;
  }

  @override
  bool supportsRealtimeModel(String model) => false;

  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'x-api-key': apiKey ?? '',
      'anthropic-version': _apiVersion,
    };
  }

  Map<String, dynamic> _buildRequestBody({
    required String systemPrompt,
    required List<ChatMessage> messages,
    required String model,
    required double temperature,
    required bool stream,
  }) {
    return {
      'model': model,
      'system': systemPrompt,
      'messages': messages.map((m) => m.toJson()).toList(),
      'max_tokens': 4096,
      'temperature': temperature,
      'stream': stream,
    };
  }

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
  }) async* {
    if ((apiKey ?? '').trim().isEmpty) {
      yield '[Error] Missing API key for Anthropic';
      return;
    }

    final selectedModel = model ?? defaultModel;
    final body = _buildRequestBody(
      systemPrompt: systemPrompt,
      messages: messages,
      model: selectedModel,
      temperature: temperature,
      stream: true,
    );
    final headers = _buildHeaders();

    HttpClient? client;
    try {
      client = HttpClient();
      final uri = Uri.parse('$_baseUrl/messages');
      final request = await client.postUrl(uri);

      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.headers.contentType = ContentType.json;

      request.write(jsonEncode(body));
      final response = await request.close();

      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        yield '[Error] HTTP ${response.statusCode}: $errorBody';
        return;
      }

      yield* _parseSseStream(response);
    } on SocketException catch (e) {
      yield '[Error] Network error: ${e.message}';
    } on HttpException catch (e) {
      yield '[Error] HTTP error: ${e.message}';
    } catch (e) {
      yield '[Error] Unexpected error: $e';
    } finally {
      client?.close();
    }
  }

  /// Parse Anthropic SSE stream format.
  ///
  /// Anthropic uses event types like `content_block_delta` with
  /// `delta.type == "text_delta"` and `delta.text` for content.
  Stream<String> _parseSseStream(HttpClientResponse response) async* {
    var lineBuffer = '';
    var currentEventType = '';

    await for (final chunk in response.transform(utf8.decoder)) {
      lineBuffer += chunk;
      final lines = lineBuffer.split('\n');
      lineBuffer = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          currentEventType = '';
          continue;
        }

        if (trimmed.startsWith('event: ')) {
          currentEventType = trimmed.substring(7);
          continue;
        }

        if (!trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6);

        // Handle message_stop event
        if (currentEventType == 'message_stop') return;

        // Only process content_block_delta events
        if (currentEventType != 'content_block_delta') continue;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final delta = json['delta'] as Map<String, dynamic>?;
          if (delta == null) continue;

          final type = delta['type'] as String?;
          if (type != 'text_delta') continue;

          final text = delta['text'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        } on FormatException {
          continue;
        }
      }
    }
  }

  @override
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
  }) async {
    if ((apiKey ?? '').trim().isEmpty) {
      return '[Error] Missing API key for Anthropic';
    }

    final selectedModel = model ?? defaultModel;
    final body = _buildRequestBody(
      systemPrompt: systemPrompt,
      messages: messages,
      model: selectedModel,
      temperature: temperature,
      stream: false,
    );
    final headers = _buildHeaders();

    HttpClient? client;
    try {
      client = HttpClient();
      final uri = Uri.parse('$_baseUrl/messages');
      final request = await client.postUrl(uri);

      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.headers.contentType = ContentType.json;

      request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return '[Error] HTTP ${response.statusCode}: $responseBody';
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final content = json['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) {
        return '[Error] No content in response';
      }

      // Concatenate all text blocks
      final buffer = StringBuffer();
      for (final block in content) {
        final blockMap = block as Map<String, dynamic>;
        if (blockMap['type'] == 'text') {
          buffer.write(blockMap['text'] as String? ?? '');
        }
      }
      return buffer.toString();
    } on SocketException catch (e) {
      return '[Error] Network error: ${e.message}';
    } on HttpException catch (e) {
      return '[Error] HTTP error: ${e.message}';
    } catch (e) {
      return '[Error] Unexpected error: $e';
    } finally {
      client?.close();
    }
  }

  @override
  Future<bool> testConnection(String testApiKey) async {
    // Build a one-off request using the provided key directly,
    // avoiding mutation of the shared apiKey field.
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': testApiKey,
      'anthropic-version': _apiVersion,
    };
    final body = _buildRequestBody(
      systemPrompt: 'Reply with "ok".',
      messages: [ChatMessage(role: 'user', content: 'Hi')],
      model: defaultModel,
      temperature: 0.0,
      stream: false,
    );

    HttpClient? client;
    try {
      client = HttpClient();
      final uri = Uri.parse('$_baseUrl/messages');
      final request = await client.postUrl(uri);

      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.headers.contentType = ContentType.json;

      request.write(jsonEncode(body));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client?.close();
    }
  }
}
