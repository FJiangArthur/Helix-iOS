import 'dart:convert';
import 'dart:io';

import 'package:flutter_helix/services/llm/llm_provider.dart';

/// Base class for OpenAI-compatible API providers.
///
/// Handles the common SSE streaming logic for providers that follow the
/// OpenAI chat completions API format (OpenAI, DeepSeek, Qwen, Zhipu).
abstract class OpenAiCompatibleProvider implements LlmProvider {
  /// The base URL for the API (without trailing slash).
  String get baseUrl;

  /// The API key for authentication.
  String? apiKey;
  List<String>? _queriedModelsCache;

  @override
  void updateApiKey(String apiKey) {
    this.apiKey = apiKey;
    _queriedModelsCache = null;
  }

  /// Build request headers. Override for providers with custom headers.
  Map<String, String> buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${apiKey ?? ''}',
    };
  }

  @override
  Future<List<String>> queryAvailableModels({bool refresh = false}) async {
    if (!refresh &&
        _queriedModelsCache != null &&
        _queriedModelsCache!.isNotEmpty) {
      return List<String>.unmodifiable(_queriedModelsCache!);
    }

    final remoteModels = await _fetchRemoteModels();
    final fallbackModels = [...availableModels]..sort();
    final resolvedModels = remoteModels.isEmpty
        ? fallbackModels
        : filterQueriedModels(remoteModels);

    _queriedModelsCache = resolvedModels.isEmpty
        ? fallbackModels
        : resolvedModels;
    return List<String>.unmodifiable(_queriedModelsCache!);
  }

  /// Allows subclasses to trim unsupported or irrelevant remote model IDs.
  List<String> filterQueriedModels(List<String> modelIds) {
    final unique = modelIds.toSet().toList()..sort();
    return unique;
  }

  @override
  bool supportsRealtimeModel(String model) => false;

  Future<List<String>> _fetchRemoteModels() async {
    if ((apiKey ?? '').trim().isEmpty) {
      return [];
    }

    HttpClient? client;
    try {
      client = HttpClient();
      final uri = Uri.parse('$baseUrl/models');
      final request = await client.getUrl(uri);
      final headers = buildHeaders();

      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      final response = await request.close();
      if (response.statusCode != 200) {
        return [];
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? const [];

      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => (item['id'] as String?)?.trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    } finally {
      client?.close();
    }
  }

  /// Build the request body. Override if a provider needs custom fields.
  Map<String, dynamic> buildRequestBody({
    required String systemPrompt,
    required List<ChatMessage> messages,
    required String model,
    required double temperature,
    required bool stream,
  }) {
    final allMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => m.toJson()),
    ];

    return {
      'model': model,
      'messages': allMessages,
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
    final selectedModel = model ?? defaultModel;
    final body = buildRequestBody(
      systemPrompt: systemPrompt,
      messages: messages,
      model: selectedModel,
      temperature: temperature,
      stream: true,
    );
    final headers = buildHeaders();
    final url = '$baseUrl/chat/completions';

    HttpClient? client;
    try {
      client = HttpClient();
      final uri = Uri.parse(url);
      final request = await client.postUrl(uri);

      // Set headers
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.headers.contentType = ContentType.json;

      // Write body
      request.write(jsonEncode(body));
      final response = await request.close();

      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        yield '[Error] HTTP ${response.statusCode}: $errorBody';
        return;
      }

      // Parse SSE stream
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

  /// Parse the SSE byte stream and yield content deltas.
  Stream<String> _parseSseStream(HttpClientResponse response) async* {
    // Buffer for incomplete lines across chunks
    var lineBuffer = '';

    await for (final chunk in response.transform(utf8.decoder)) {
      lineBuffer += chunk;
      final lines = lineBuffer.split('\n');
      // Keep the last potentially incomplete line in the buffer
      lineBuffer = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (!trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6); // Remove 'data: ' prefix
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;

          final delta =
              (choices[0] as Map<String, dynamic>)['delta']
                  as Map<String, dynamic>?;
          if (delta == null) continue;

          final content = delta['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } on FormatException {
          // Skip malformed JSON lines
          continue;
        }
      }
    }

    // Process any remaining data in the buffer
    if (lineBuffer.trim().isNotEmpty) {
      final trimmed = lineBuffer.trim();
      if (trimmed.startsWith('data: ')) {
        final data = trimmed.substring(6);
        if (data != '[DONE]') {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final choices = json['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta =
                  (choices[0] as Map<String, dynamic>)['delta']
                      as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          } on FormatException {
            // Skip malformed JSON
          }
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
    final selectedModel = model ?? defaultModel;
    final body = buildRequestBody(
      systemPrompt: systemPrompt,
      messages: messages,
      model: selectedModel,
      temperature: temperature,
      stream: false,
    );
    final headers = buildHeaders();
    final url = '$baseUrl/chat/completions';

    HttpClient? client;
    try {
      client = HttpClient();
      final uri = Uri.parse(url);
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
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return '[Error] No choices in response';
      }

      final message =
          (choices[0] as Map<String, dynamic>)['message']
              as Map<String, dynamic>?;
      return (message?['content'] as String?) ?? '';
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
      'Authorization': 'Bearer $testApiKey',
    };
    final body = buildRequestBody(
      systemPrompt: 'Reply with "ok".',
      messages: [ChatMessage(role: 'user', content: 'Hi')],
      model: defaultModel,
      temperature: 0.0,
      stream: false,
    );
    final url = '$baseUrl/chat/completions';

    HttpClient? client;
    try {
      client = HttpClient();
      final uri = Uri.parse(url);
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
