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
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  });

  /// Get a complete response (non-streaming).
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
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
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
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
  }
}

enum AiOperationType { transcription, questionDetection, answerGeneration }

class LlmRequestOptions {
  const LlmRequestOptions({
    this.operationType,
    this.maxOutputTokens,
    this.reasoningEffort,
  });

  final AiOperationType? operationType;
  final int? maxOutputTokens;
  final String? reasoningEffort;
}

class LlmUsage {
  const LlmUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedInputTokens = 0,
    this.audioInputTokens = 0,
    this.audioOutputTokens = 0,
  });

  factory LlmUsage.fromJson(Map<String, dynamic> json) {
    final inputDetails =
        _asMap(json['input_token_details']) ??
        _asMap(json['prompt_tokens_details']) ??
        _asMap(json['inputTokenDetails']);
    final outputDetails =
        _asMap(json['output_token_details']) ??
        _asMap(json['completion_tokens_details']) ??
        _asMap(json['outputTokenDetails']);

    return LlmUsage(
      inputTokens: _readInt(json, const [
        'input_tokens',
        'prompt_tokens',
        'inputTokens',
      ]),
      outputTokens: _readInt(json, const [
        'output_tokens',
        'completion_tokens',
        'outputTokens',
      ]),
      cachedInputTokens: _readInt(inputDetails, const [
        'cached_tokens',
        'cachedTokens',
      ]),
      audioInputTokens: _readInt(inputDetails, const [
        'audio_tokens',
        'audioTokens',
      ]),
      audioOutputTokens: _readInt(outputDetails, const [
        'audio_tokens',
        'audioTokens',
      ]),
    );
  }

  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;
  final int audioInputTokens;
  final int audioOutputTokens;

  bool get hasAnyUsage =>
      inputTokens > 0 ||
      outputTokens > 0 ||
      cachedInputTokens > 0 ||
      audioInputTokens > 0 ||
      audioOutputTokens > 0;
}

class LlmResponseMetadata {
  const LlmResponseMetadata({
    required this.providerId,
    required this.modelId,
    required this.usage,
    this.operationType,
  });

  final String providerId;
  final String modelId;
  final LlmUsage usage;
  final AiOperationType? operationType;
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
  ToolCallRequest({
    required this.id,
    required this.name,
    required this.arguments,
  });
}

class UsageMetadata extends LlmResponseEvent {
  UsageMetadata(this.metadata);

  final LlmResponseMetadata metadata;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}

int _readInt(Map<String, dynamic>? json, List<String> keys) {
  if (json == null) return 0;
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
  }
  return 0;
}
