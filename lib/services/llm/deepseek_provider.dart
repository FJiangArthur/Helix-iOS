import 'package:flutter_helix/services/llm/openai_compatible_provider.dart';

/// DeepSeek LLM provider using the OpenAI-compatible API.
class DeepSeekProvider extends OpenAiCompatibleProvider {
  @override
  String get name => 'DeepSeek';

  @override
  String get id => 'deepseek';

  @override
  String get baseUrl => 'https://api.deepseek.com/v1';

  @override
  List<String> get availableModels => const [
        'deepseek-chat',
        'deepseek-reasoner',
      ];

  @override
  String get defaultModel => 'deepseek-chat';
}
