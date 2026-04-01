import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/openai_compatible_provider.dart';

/// OpenRouter provider using the OpenAI-compatible chat completions API.
///
/// OpenRouter exposes a large model catalog behind a single API key. Helix
/// defaults to the auto-router and lets users override the exact model ID.
class OpenRouterProvider extends OpenAiCompatibleProvider {
  static const _preferredPrefixes = [
    'openrouter/',
    'openai/',
    'anthropic/',
    'google/',
    'deepseek/',
    'meta-llama/',
    'qwen/',
    'mistralai/',
  ];

  @override
  String get name => 'OpenRouter';

  @override
  String get id => 'openrouter';

  @override
  String get baseUrl => 'https://openrouter.ai/api/v1';

  @override
  List<String> get availableModels => const ['openrouter/auto'];

  @override
  String get defaultModel => 'openrouter/auto';

  @override
  List<String> filterQueriedModels(List<String> modelIds) {
    final filtered = <String>{};
    if (modelIds.contains(defaultModel)) {
      filtered.add(defaultModel);
    }

    for (final rawId in modelIds) {
      final id = rawId.trim();
      if (id.isEmpty || filtered.contains(id)) continue;
      if (_preferredPrefixes.any(id.startsWith)) {
        filtered.add(id);
      }
      if (filtered.length >= 10) break;
    }

    if (filtered.isEmpty) {
      filtered.addAll(availableModels);
    }

    return filtered.toList();
  }

  @override
  Map<String, dynamic> buildRequestBody({
    required String systemPrompt,
    required List<ChatMessage> messages,
    required String model,
    required double temperature,
    required bool stream,
    List<ToolDefinition>? tools,
    LlmRequestOptions? requestOptions,
  }) {
    final body = super.buildRequestBody(
      systemPrompt: systemPrompt,
      messages: messages,
      model: model,
      temperature: temperature,
      stream: stream,
      tools: tools,
      requestOptions: requestOptions,
    );

    if (requestOptions?.maxOutputTokens != null) {
      body['max_completion_tokens'] = requestOptions!.maxOutputTokens;
    }

    if (requestOptions?.reasoningEffort != null) {
      body['reasoning'] = {'effort': requestOptions!.reasoningEffort};
    }

    return body;
  }
}
