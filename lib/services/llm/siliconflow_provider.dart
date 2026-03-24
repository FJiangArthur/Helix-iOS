import 'package:flutter_helix/services/llm/openai_compatible_provider.dart';

/// SiliconFlow LLM aggregator using the OpenAI-compatible API.
///
/// Provides access to multiple open-source models, several of which are
/// permanently free (Qwen2.5-7B, DeepSeek-V2.5, GLM-4-9B).
class SiliconFlowProvider extends OpenAiCompatibleProvider {
  @override
  String get name => 'SiliconFlow';

  @override
  String get id => 'siliconflow';

  @override
  String get baseUrl => 'https://api.siliconflow.cn/v1';

  @override
  List<String> get availableModels => const [
        // Free models
        'Qwen/Qwen2.5-7B-Instruct',
        'deepseek-ai/DeepSeek-V2.5',
        'THUDM/glm-4-9b-chat',
        // Paid models
        'deepseek-ai/DeepSeek-V3',
        'Qwen/Qwen3-8B',
      ];

  @override
  String get defaultModel => 'Qwen/Qwen2.5-7B-Instruct';
}
