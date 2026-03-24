import 'package:flutter_helix/services/llm/openai_compatible_provider.dart';

/// Zhipu AI (GLM) LLM provider using the OpenAI-compatible API.
class ZhipuProvider extends OpenAiCompatibleProvider {
  @override
  String get name => 'Zhipu AI';

  @override
  String get id => 'zhipu';

  @override
  String get baseUrl => 'https://open.bigmodel.cn/api/paas/v4';

  @override
  List<String> get availableModels => const [
        'glm-4',
        'glm-4-flash',
        'glm-4.5-flash',
        'glm-4.7-flash',
      ];

  @override
  String get defaultModel => 'glm-4-flash';
}
