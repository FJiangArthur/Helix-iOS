import 'package:flutter_helix/services/llm/anthropic_provider.dart';
import 'package:flutter_helix/services/llm/deepseek_provider.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/openai_provider.dart';
import 'package:flutter_helix/services/llm/qwen_provider.dart';
import 'package:flutter_helix/services/llm/zhipu_provider.dart';

/// Central manager for LLM providers.
///
/// Handles provider registration, API key management, and routing
/// requests to the active provider. Implemented as a singleton.
class LlmService {
  LlmService._();

  static LlmService? _instance;
  static LlmService get instance => _instance ??= LlmService._();

  final Map<String, LlmProvider> _providers = {};
  final Map<String, String> _apiKeys = {};
  String _activeProviderId = 'openai';
  String? _activeModel;

  /// All registered providers.
  Map<String, LlmProvider> get providers => Map.unmodifiable(_providers);

  /// The currently active provider ID.
  String get activeProviderId => _activeProviderId;

  /// The currently active model, or the provider's default if not set.
  /// Returns null if no provider is registered yet.
  String? get activeModel =>
      _activeModel ?? _providers[_activeProviderId]?.defaultModel;

  /// Register a provider. Replaces any existing provider with the same ID.
  void registerProvider(LlmProvider provider) {
    _providers[provider.id] = provider;
  }

  /// Set the API key for a provider.
  ///
  /// Also sets the key on the provider instance if it supports it.
  void setApiKey(String providerId, String apiKey) {
    _apiKeys[providerId] = apiKey;

    final provider = _providers[providerId];
    provider?.updateApiKey(apiKey);
  }

  /// Get the stored API key for a provider, if any.
  String? getApiKey(String providerId) => _apiKeys[providerId];

  /// Set the active provider and optionally a specific model.
  ///
  /// Throws [ArgumentError] if the provider ID is not registered.
  void setActiveProvider(String providerId, {String? model}) {
    if (!_providers.containsKey(providerId)) {
      throw ArgumentError('Provider "$providerId" is not registered.');
    }
    _activeProviderId = providerId;
    _activeModel = model;
  }

  /// The currently active provider instance.
  ///
  /// Throws [StateError] if no provider is registered for the active ID.
  LlmProvider get activeProvider {
    final provider = _providers[_activeProviderId];
    if (provider == null) {
      throw StateError(
        'No provider registered for "$_activeProviderId". '
        'Call initializeDefaults() first.',
      );
    }
    return provider;
  }

  /// Stream a response using the active provider and model.
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    double temperature = 0.7,
  }) {
    return activeProvider.streamResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: _activeModel,
      temperature: temperature,
    );
  }

  /// Stream a response with optional tool calling using the active provider.
  Stream<LlmResponseEvent> streamWithTools({
    required String systemPrompt,
    required List<ChatMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.7,
  }) {
    return activeProvider.streamWithTools(
      systemPrompt: systemPrompt,
      messages: messages,
      tools: tools,
      model: _activeModel,
      temperature: temperature,
    );
  }

  /// Get a complete response using the active provider and model.
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
  }) {
    return activeProvider.getResponse(
      systemPrompt: systemPrompt,
      messages: messages,
      model: _activeModel,
    );
  }

  /// Test the connection for a specific provider with the given API key.
  Future<bool> testConnection(String providerId, String apiKey) {
    final provider = _providers[providerId];
    if (provider == null) {
      throw ArgumentError('Provider "$providerId" is not registered.');
    }
    return provider.testConnection(apiKey);
  }

  /// Query the currently available models for a provider.
  Future<List<String>> queryAvailableModels(
    String providerId, {
    bool refresh = false,
  }) async {
    final provider = _providers[providerId];
    if (provider == null) {
      throw ArgumentError('Provider "$providerId" is not registered.');
    }
    return provider.queryAvailableModels(refresh: refresh);
  }

  /// Initialize all built-in providers.
  void initializeDefaults() {
    registerProvider(OpenAiProvider());
    registerProvider(AnthropicProvider());
    registerProvider(DeepSeekProvider());
    registerProvider(QwenProvider());
    registerProvider(ZhipuProvider());
  }
}
