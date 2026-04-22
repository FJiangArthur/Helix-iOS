import 'dart:convert';
import 'dart:io';

import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/utils/app_logger.dart';

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
  /// Caps at 10 models to keep the selector manageable.
  List<String> filterQueriedModels(List<String> modelIds) {
    final unique = modelIds.toSet().toList()..sort();
    return unique.length > 10 ? unique.sublist(0, 10) : unique;
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
    List<ToolDefinition>? tools,
    LlmRequestOptions? requestOptions,
  }) {
    final allMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => m.toJson()),
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': allMessages,
      'temperature': temperature,
      'stream': stream,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools.map((t) => t.toJson()).toList();
    }

    return body;
  }

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    if ((apiKey ?? '').trim().isEmpty) {
      yield '[Error] Missing API key for $name';
      return;
    }

    final selectedModel = model ?? defaultModel;
    final body = buildRequestBody(
      systemPrompt: systemPrompt,
      messages: messages,
      model: selectedModel,
      temperature: temperature,
      stream: true,
      requestOptions: requestOptions,
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
      yield* _parseSseStream(
        response,
        modelId: selectedModel,
        requestOptions: requestOptions,
        onMetadata: onMetadata,
      );
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

  Stream<String> _parseSseStream(
    HttpClientResponse response, {
    required String modelId,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
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
          _emitUsageMetadata(
            json,
            modelId: modelId,
            requestOptions: requestOptions,
            onMetadata: onMetadata,
          );
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
            _emitUsageMetadata(
              json,
              modelId: modelId,
              requestOptions: requestOptions,
              onMetadata: onMetadata,
            );
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
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async {
    if ((apiKey ?? '').trim().isEmpty) {
      return '[Error] Missing API key for $name';
    }

    final selectedModel = model ?? defaultModel;
    final body = buildRequestBody(
      systemPrompt: systemPrompt,
      messages: messages,
      model: selectedModel,
      temperature: temperature,
      stream: false,
      requestOptions: requestOptions,
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
      _emitUsageMetadata(
        json,
        modelId: selectedModel,
        requestOptions: requestOptions,
        onMetadata: onMetadata,
      );
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
      if (response.statusCode == 200) return true;
      // Surface the real reason so the user can diagnose (wrong key, billing,
      // model access, temperature rejection on newer models, etc.). Body is
      // truncated because OpenAI error payloads include verbose docs links.
      final bodyStr = await response.transform(utf8.decoder).join();
      final truncated = bodyStr.length > 400
          ? '${bodyStr.substring(0, 400)}…'
          : bodyStr;
      // ignore: avoid_print — diagnostic must reach release-mode device logs.
      print(
        '[$name] testConnection failed: HTTP ${response.statusCode} '
        'model=$defaultModel body=$truncated',
      );
      appLogger.w(
        '[$name] testConnection failed: HTTP ${response.statusCode} '
        'model=$defaultModel body=$truncated',
      );
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('[$name] testConnection threw: $e');
      appLogger.w('[$name] testConnection threw: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  @override
  Stream<LlmResponseEvent> streamWithTools({
    required String systemPrompt,
    required List<ChatMessage> messages,
    List<ToolDefinition>? tools,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    // If no tools provided, fall back to wrapping streamResponse as TextDelta.
    if (tools == null || tools.isEmpty) {
      await for (final chunk in streamResponse(
        systemPrompt: systemPrompt,
        messages: messages,
        model: model,
        temperature: temperature,
        requestOptions: requestOptions,
        onMetadata: onMetadata,
      )) {
        yield TextDelta(chunk);
      }
      return;
    }

    if ((apiKey ?? '').trim().isEmpty) {
      yield TextDelta('[Error] Missing API key for $name');
      return;
    }

    final selectedModel = model ?? defaultModel;
    final body = buildRequestBody(
      systemPrompt: systemPrompt,
      messages: messages,
      model: selectedModel,
      temperature: temperature,
      stream: true,
      tools: tools,
      requestOptions: requestOptions,
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

      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        yield TextDelta('[Error] HTTP ${response.statusCode}: $errorBody');
        return;
      }

      yield* _parseSseStreamWithTools(
        response,
        modelId: selectedModel,
        requestOptions: requestOptions,
        onMetadata: onMetadata,
      );
    } on SocketException catch (e) {
      yield TextDelta('[Error] Network error: ${e.message}');
    } on HttpException catch (e) {
      yield TextDelta('[Error] HTTP error: ${e.message}');
    } catch (e) {
      yield TextDelta('[Error] Unexpected error: $e');
    } finally {
      client?.close();
    }
  }

  /// Parse SSE stream, emitting TextDelta and ToolCallRequest events.
  Stream<LlmResponseEvent> _parseSseStreamWithTools(
    HttpClientResponse response, {
    required String modelId,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    // Accumulators for tool calls, keyed by index.
    final toolCallIds = <int, String>{};
    final toolCallNames = <int, String>{};
    final toolCallArgs = <int, StringBuffer>{};

    var lineBuffer = '';

    await for (final chunk in response.transform(utf8.decoder)) {
      lineBuffer += chunk;
      final lines = lineBuffer.split('\n');
      lineBuffer = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6);
        if (data == '[DONE]') {
          // Emit any accumulated tool calls.
          yield* _emitPendingToolCalls(
            toolCallIds,
            toolCallNames,
            toolCallArgs,
          );
          return;
        }

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          _emitUsageMetadata(
            json,
            modelId: modelId,
            requestOptions: requestOptions,
            onMetadata: onMetadata,
          );
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;

          final choice = choices[0] as Map<String, dynamic>;
          final delta = choice['delta'] as Map<String, dynamic>?;
          if (delta == null) {
            // finish_reason present with no delta means stream ending.
            continue;
          }

          // Handle text content.
          final content = delta['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield TextDelta(content);
          }

          // Handle tool calls.
          final toolCalls = delta['tool_calls'] as List<dynamic>?;
          if (toolCalls != null) {
            for (final tc in toolCalls) {
              final tcMap = tc as Map<String, dynamic>;
              final index = tcMap['index'] as int? ?? 0;
              final id = tcMap['id'] as String?;
              final function = tcMap['function'] as Map<String, dynamic>?;

              if (id != null) {
                toolCallIds[index] = id;
              }
              if (function != null) {
                final fnName = function['name'] as String?;
                if (fnName != null) {
                  toolCallNames[index] = fnName;
                }
                final fnArgs = function['arguments'] as String?;
                if (fnArgs != null) {
                  toolCallArgs.putIfAbsent(index, () => StringBuffer());
                  toolCallArgs[index]!.write(fnArgs);
                }
              }
            }
          }
        } on FormatException {
          continue;
        }
      }
    }

    // Process remaining buffer.
    if (lineBuffer.trim().isNotEmpty) {
      final trimmed = lineBuffer.trim();
      if (trimmed.startsWith('data: ')) {
        final data = trimmed.substring(6);
        if (data != '[DONE]') {
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            _emitUsageMetadata(
              json,
              modelId: modelId,
              requestOptions: requestOptions,
              onMetadata: onMetadata,
            );
            final choices = json['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta =
                  (choices[0] as Map<String, dynamic>)['delta']
                      as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield TextDelta(content);
              }
            }
          } on FormatException {
            // Skip malformed JSON
          }
        }
      }
    }

    // Emit any remaining tool calls.
    yield* _emitPendingToolCalls(toolCallIds, toolCallNames, toolCallArgs);
  }

  /// Emit ToolCallRequest events for all accumulated tool calls.
  Stream<LlmResponseEvent> _emitPendingToolCalls(
    Map<int, String> ids,
    Map<int, String> names,
    Map<int, StringBuffer> args,
  ) async* {
    for (final index in names.keys) {
      final id = ids[index] ?? 'call_$index';
      final name = names[index] ?? '';
      final rawArgs = args[index]?.toString() ?? '{}';

      Map<String, dynamic> parsedArgs;
      try {
        parsedArgs = jsonDecode(rawArgs) as Map<String, dynamic>;
      } catch (_) {
        parsedArgs = {};
      }

      yield ToolCallRequest(id: id, name: name, arguments: parsedArgs);
    }
  }

  void _emitUsageMetadata(
    Map<String, dynamic> json, {
    required String modelId,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) {
    if (onMetadata == null) return;

    final usageMap = json['usage'];
    if (usageMap is! Map) return;

    final usage = LlmUsage.fromJson(usageMap.cast<String, dynamic>());
    if (!usage.hasAnyUsage) return;

    onMetadata(
      LlmResponseMetadata(
        providerId: id,
        modelId: modelId,
        usage: usage,
        operationType: requestOptions?.operationType,
      ),
    );
  }
}
