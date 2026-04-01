import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/openai_provider.dart';

void main() {
  group('OpenAiProvider', () {
    test('exposes GPT-5.4 family models', () {
      final provider = OpenAiProvider();

      expect(provider.availableModels, contains('gpt-5.4'));
      expect(provider.availableModels, contains('gpt-5.4-mini'));
      expect(provider.availableModels, contains('gpt-5.4-nano'));
    });

    test('exposes canonical realtime models', () {
      final provider = OpenAiProvider();

      expect(provider.availableModels, contains('gpt-realtime'));
      expect(provider.availableModels, contains('gpt-realtime-mini'));
    });

    test('normalizes legacy realtime aliases to canonical model IDs', () {
      final provider = OpenAiProvider();

      expect(
        provider.normalizeModelId('gpt-4o-mini-realtime'),
        'gpt-realtime-mini',
      );
      expect(
        provider.normalizeModelId('gpt-4o-mini-realtime-preview'),
        'gpt-realtime-mini',
      );
      expect(provider.normalizeModelId('gpt-4o-realtime'), 'gpt-realtime');
      expect(
        provider.normalizeModelId('gpt-4o-realtime-preview'),
        'gpt-realtime',
      );
    });

    test(
      'builds chat request bodies with output caps for answer generation',
      () {
        final provider = OpenAiProvider();

        final body = provider.buildRequestBody(
          systemPrompt: 'You are helpful.',
          messages: [ChatMessage(role: 'user', content: 'Answer briefly.')],
          model: 'gpt-5.4',
          temperature: 0.3,
          stream: true,
          requestOptions: const LlmRequestOptions(
            operationType: AiOperationType.answerGeneration,
            maxOutputTokens: 180,
          ),
        );

        expect(body['max_completion_tokens'], 180);
        expect(body['stream_options'], {'include_usage': true});
      },
    );
  });
}
