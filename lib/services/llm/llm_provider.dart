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
