import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/openrouter_provider.dart';

void main() {
  group('OpenRouterProvider', () {
    test('defaults to the auto router model', () {
      final provider = OpenRouterProvider();

      expect(provider.defaultModel, 'openrouter/auto');
      expect(provider.availableModels, contains('openrouter/auto'));
    });

    test('builds request bodies with output caps and reasoning effort', () {
      final provider = OpenRouterProvider();

      final body = provider.buildRequestBody(
        systemPrompt: 'You are helpful.',
        messages: [ChatMessage(role: 'user', content: 'Think and answer.')],
        model: 'openrouter/auto',
        temperature: 0.2,
        stream: true,
        requestOptions: const LlmRequestOptions(
          operationType: AiOperationType.answerGeneration,
          maxOutputTokens: 160,
          reasoningEffort: 'medium',
        ),
      );

      expect(body['max_completion_tokens'], 160);
      expect(body['reasoning'], {'effort': 'medium'});
    });

    test(
      'prioritizes common routed model prefixes when filtering remote IDs',
      () {
        final provider = OpenRouterProvider();

        final filtered = provider.filterQueriedModels([
          'some-random/model',
          'openai/gpt-4.1-mini',
          'openrouter/auto',
          'anthropic/claude-sonnet-4',
        ]);

        expect(filtered.first, 'openrouter/auto');
        expect(filtered, contains('openai/gpt-4.1-mini'));
        expect(filtered, contains('anthropic/claude-sonnet-4'));
        expect(filtered, isNot(contains('some-random/model')));
      },
    );
  });
}
