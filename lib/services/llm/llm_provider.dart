/// Abstract interface for LLM providers.
///
/// Each provider (OpenAI, Anthropic, etc.) implements this interface
/// to provide streaming and non-streaming text generation.
abstract class LlmProvider {
  /// Human-readable name of the provider (e.g., "OpenAI").
  String get name;

  /// Unique identifier for the provider (e.g., "openai").
  String get id;

  /// List of available model identifiers.
  List<String> get availableModels;

  /// Default model to use when none is specified.
  String get defaultModel;

  /// Update the provider API key, if the provider uses one.
  void updateApiKey(String apiKey) {}

  /// Query the provider for the latest available models.
  ///
  /// Providers without a remote models endpoint can fall back to the
  /// statically declared [availableModels].
  Future<List<String>> queryAvailableModels({bool refresh = false}) async {
    return availableModels;
  }

  /// Whether the given model should use a realtime transport.
  bool supportsRealtimeModel(String model) => false;

  /// Stream a response from the LLM. Yields chunks of text as they arrive.
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
  });

  /// Get a complete response (non-streaming).
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
  });

  /// Test if the API key is valid by making a lightweight request.
  Future<bool> testConnection(String apiKey);

  /// Stream response with optional tool calling.
  /// Default implementation wraps streamResponse into TextDelta events.
  Stream<LlmResponseEvent> streamWithTools({
    required String systemPrompt,
    required List<ChatMessage> messages,
    List<ToolDefinition>? tools,
    String? model,
    double temperature = 0.7,
  }) async* {
    await for (final chunk in streamResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: model,
      temperature: temperature,
    )) {
      yield TextDelta(chunk);
    }
  }
}

/// Represents a single message in a chat conversation.
class ChatMessage {
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final DateTime timestamp;

  ChatMessage({required this.role, required this.content, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Definition of a tool the LLM can call.
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters; // JSON Schema

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

/// Events emitted during a tool-calling response stream.
sealed class LlmResponseEvent {}

class TextDelta extends LlmResponseEvent {
  final String text;
  TextDelta(this.text);
}

class ToolCallRequest extends LlmResponseEvent {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  ToolCallRequest({required this.id, required this.name, required this.arguments});
}
