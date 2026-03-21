import 'dart:convert';
import 'dart:io';

import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/openai_compatible_provider.dart';

/// OpenAI LLM provider using chat completions for standard models and
/// the Realtime websocket API for realtime-capable models.
class OpenAiProvider extends OpenAiCompatibleProvider {
  @override
  String get name => 'OpenAI';

  @override
  String get id => 'openai';

  @override
  String get baseUrl => 'https://api.openai.com/v1';

  @override
  List<String> get availableModels => const [
    'o3',
    'o3-mini',
    'o4-mini',
    'gpt-4.1',
    'gpt-4.1-mini',
    'gpt-4.1-nano',
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-realtime',
  ];

  @override
  String get defaultModel => 'gpt-4.1';

  @override
  List<String> filterQueriedModels(List<String> modelIds) {
    final filtered =
        modelIds
            .where((id) {
              final lower = id.toLowerCase();
              if (lower.startsWith('whisper') ||
                  lower.startsWith('tts') ||
                  lower.contains('embedding') ||
                  lower.contains('image') ||
                  lower.contains('moderation') ||
                  lower.contains('transcribe')) {
                return false;
              }
              return lower.startsWith('gpt-') ||
                  lower.startsWith('chatgpt-') ||
                  lower.startsWith('o1') ||
                  lower.startsWith('o3') ||
                  lower.startsWith('o4') ||
                  lower.startsWith('o5');
            })
            .toSet()
            .toList()
          ..sort();

    return filtered;
  }

  @override
  bool supportsRealtimeModel(String model) {
    return model.toLowerCase().contains('realtime');
  }

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
  }) {
    final selectedModel = model ?? defaultModel;
    if (!supportsRealtimeModel(selectedModel)) {
      return super.streamResponse(
        systemPrompt: systemPrompt,
        messages: messages,
        model: selectedModel,
        temperature: temperature,
      );
    }

    return _streamRealtimeResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: selectedModel,
    );
  }

  @override
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
  }) async {
    final selectedModel = model ?? defaultModel;
    if (!supportsRealtimeModel(selectedModel)) {
      return super.getResponse(
        systemPrompt: systemPrompt,
        messages: messages,
        model: selectedModel,
        temperature: temperature,
      );
    }

    final buffer = StringBuffer();
    await for (final chunk in streamResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: selectedModel,
      temperature: temperature,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  Stream<String> _streamRealtimeResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    required String model,
  }) async* {
    if ((apiKey ?? '').trim().isEmpty) {
      yield '[Error] Missing OpenAI API key';
      return;
    }

    WebSocket? socket;
    try {
      final uri = Uri.parse(
        'wss://api.openai.com/v1/realtime?model=${Uri.encodeQueryComponent(model)}',
      );
      socket = await WebSocket.connect(
        uri.toString(),
        headers: {
          'Authorization': 'Bearer ${apiKey ?? ''}',
          'OpenAI-Beta': 'realtime=v1',
        },
      );
      socket.pingInterval = const Duration(seconds: 20);

      socket.add(
        jsonEncode({
          'type': 'session.update',
          'session': {'instructions': systemPrompt},
        }),
      );

      socket.add(
        jsonEncode({
          'type': 'conversation.item.create',
          'item': {
            'type': 'message',
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': _buildRealtimeInput(messages)},
            ],
          },
        }),
      );

      socket.add(
        jsonEncode({
          'type': 'response.create',
          'response': {
            'modalities': ['text'],
          },
        }),
      );

      await for (final rawEvent in socket) {
        final payload = rawEvent is List<int>
            ? utf8.decode(rawEvent)
            : rawEvent.toString();
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }

        final type = decoded['type'] as String? ?? '';
        switch (type) {
          case 'response.output_text.delta':
          case 'response.text.delta':
            final delta = decoded['delta'] as String? ?? '';
            if (delta.isNotEmpty) {
              yield delta;
            }
            break;
          case 'response.done':
          case 'response.completed':
            final response = decoded['response'] as Map<String, dynamic>?;
            final status = response?['status'] as String?;
            if (status == 'failed') {
              yield '[Error] ${_extractRealtimeError(decoded)}';
            }
            return;
          case 'error':
            yield '[Error] ${_extractRealtimeError(decoded)}';
            return;
          default:
            break;
        }
      }
    } on SocketException catch (e) {
      yield '[Error] Network error: ${e.message}';
    } on WebSocketException catch (e) {
      yield '[Error] WebSocket error: ${e.message}';
    } on HttpException catch (e) {
      yield '[Error] HTTP error: ${e.message}';
    } catch (e) {
      yield '[Error] Unexpected realtime error: $e';
    } finally {
      await socket?.close();
    }
  }

  String _buildRealtimeInput(List<ChatMessage> messages) {
    final cleanedMessages = messages
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    if (cleanedMessages.isEmpty) {
      return '';
    }

    if (cleanedMessages.length == 1 && cleanedMessages.last.role == 'user') {
      return cleanedMessages.last.content.trim();
    }

    final buffer = StringBuffer();
    for (final message in cleanedMessages) {
      buffer.writeln('${message.role}: ${message.content.trim()}');
    }
    return buffer.toString().trim();
  }

  String _extractRealtimeError(Map<String, dynamic> event) {
    final error = event['error'];
    if (error is Map<String, dynamic>) {
      return (error['message'] as String?) ??
          (error['type'] as String?) ??
          'Unknown realtime error';
    }

    final response = event['response'];
    if (response is Map<String, dynamic>) {
      final details = response['status_details'];
      if (details is Map<String, dynamic>) {
        final error = details['error'];
        if (error is Map<String, dynamic>) {
          return (error['message'] as String?) ??
              (error['type'] as String?) ??
              'Unknown realtime error';
        }
      }
    }

    return 'Unknown realtime error';
  }
}
