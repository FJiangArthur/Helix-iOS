import 'package:flutter_helix/services/llm/openai_compatible_provider.dart';

/// Alibaba Qwen LLM provider using the DashScope OpenAI-compatible API.
class QwenProvider extends OpenAiCompatibleProvider {
  @override
  String get name => 'Qwen';

  @override
  String get id => 'qwen';

  @override
  String get baseUrl =>
      'https://dashscope.aliyuncs.com/compatible-mode/v1';

  @override
  List<String> get availableModels => const [
        'qwen-plus',
        'qwen-turbo',
        'qwen-max',
      ];

  @override
  String get defaultModel => 'qwen-plus';
}
