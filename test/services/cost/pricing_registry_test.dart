import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_helix/services/cost/pricing_registry.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';

void main() {
  final registry = PricingRegistry.instance;

  test('OpenAI gpt-5.4 input pricing', () {
    final cost = registry.calculateCostUsd(
      providerId: 'openai',
      modelId: 'gpt-5.4',
      usage: const LlmUsage(inputTokens: 1000000),
    );
    expect(cost, closeTo(1.25, 1e-9));
  });

  test('OpenAI Realtime per-minute (90s at 0.06/min == 0.09)', () {
    final cost = registry.calculateCostUsd(
      providerId: 'openai',
      modelId: 'gpt-4o-mini-realtime',
      usage: const LlmUsage(),
      audioSeconds: 90,
    );
    expect(cost, closeTo(0.09, 1e-9));
  });

  test('Apple on-device returns 0.0 (Free, not null)', () {
    final cost = registry.calculateCostUsd(
      providerId: 'apple',
      modelId: 'on-device',
      usage: const LlmUsage(),
    );
    expect(cost, 0.0);
  });

  test('DeepSeek pricing is registered (sync with settings model list)', () {
    expect(registry.priceFor('deepseek', 'deepseek-chat'), isNotNull);
    final cost = registry.calculateCostUsd(
      providerId: 'deepseek',
      modelId: 'deepseek-chat',
      usage: const LlmUsage(inputTokens: 1000000),
    );
    expect(cost, closeTo(0.27, 1e-9));
  });

  test('Unknown provider/model returns null', () {
    expect(registry.priceFor('madeup', 'no-such-model'), isNull);
    final cost = registry.calculateCostUsd(
      providerId: 'madeup',
      modelId: 'no-such-model',
      usage: const LlmUsage(inputTokens: 1000),
    );
    expect(cost, isNull);
  });
}
