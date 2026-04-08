import '../llm/llm_provider.dart';

/// Per-model pricing in USD. All `*PerMillionUsd` rates are dollars per
/// million tokens; `audioInputPerMinuteUsd` is dollars per minute of audio.
class ModelPricing {
  const ModelPricing({
    this.inputPerMillionUsd,
    this.cachedInputPerMillionUsd,
    this.outputPerMillionUsd,
    this.audioInputPerMillionUsd,
    this.audioInputPerMinuteUsd,
  });

  final double? inputPerMillionUsd;
  final double? cachedInputPerMillionUsd;
  final double? outputPerMillionUsd;
  final double? audioInputPerMillionUsd;
  final double? audioInputPerMinuteUsd;
}

/// Singleton registry of `(providerId, modelId) -> ModelPricing`.
///
/// Source: https://openai.com/api/pricing/ (captured 2026-04-06).
/// Any rate change is a one-line edit here. Do not read from
/// SharedPreferences.
class PricingRegistry {
  PricingRegistry._();
  static final PricingRegistry instance = PricingRegistry._();

  static const Map<String, Map<String, ModelPricing>> _table = {
    'openai': {
      // GPT-5.4 family (Spec A defaults)
      'gpt-5.4': ModelPricing(
        inputPerMillionUsd: 1.25,
        cachedInputPerMillionUsd: 0.125,
        outputPerMillionUsd: 10.0,
      ),
      'gpt-5.4-mini': ModelPricing(
        inputPerMillionUsd: 0.25,
        cachedInputPerMillionUsd: 0.025,
        outputPerMillionUsd: 2.0,
      ),
      'gpt-5.4-nano': ModelPricing(
        inputPerMillionUsd: 0.05,
        cachedInputPerMillionUsd: 0.005,
        outputPerMillionUsd: 0.4,
      ),
      // GPT-4.1 family
      'gpt-4.1': ModelPricing(
        inputPerMillionUsd: 2.0,
        cachedInputPerMillionUsd: 0.5,
        outputPerMillionUsd: 8.0,
      ),
      'gpt-4.1-mini': ModelPricing(
        inputPerMillionUsd: 0.4,
        cachedInputPerMillionUsd: 0.1,
        outputPerMillionUsd: 1.6,
      ),
      'gpt-4.1-nano': ModelPricing(
        inputPerMillionUsd: 0.1,
        cachedInputPerMillionUsd: 0.025,
        outputPerMillionUsd: 0.4,
      ),
      // GPT realtime (chat completion family)
      'gpt-realtime': ModelPricing(
        inputPerMillionUsd: 5.0,
        cachedInputPerMillionUsd: 0.5,
        outputPerMillionUsd: 20.0,
        audioInputPerMillionUsd: 40.0,
      ),
      'gpt-realtime-mini': ModelPricing(
        inputPerMillionUsd: 0.6,
        cachedInputPerMillionUsd: 0.06,
        outputPerMillionUsd: 2.4,
        audioInputPerMillionUsd: 10.0,
      ),
      // Transcription
      'gpt-4o-mini-transcribe': ModelPricing(audioInputPerMillionUsd: 3.0),
      'gpt-4o-transcribe': ModelPricing(audioInputPerMillionUsd: 6.0),
      'gpt-4o-transcribe-diarize': ModelPricing(audioInputPerMillionUsd: 6.0),
      'whisper-1': ModelPricing(audioInputPerMinuteUsd: 0.006),
      // OpenAI Realtime transcription session models — billed per audio minute
      'gpt-4o-mini-realtime': ModelPricing(audioInputPerMinuteUsd: 0.06),
      'gpt-4o-realtime': ModelPricing(audioInputPerMinuteUsd: 0.10),
    },
    'anthropic': {
      'claude-opus-4-20250514': ModelPricing(
        inputPerMillionUsd: 15.0,
        cachedInputPerMillionUsd: 1.5,
        outputPerMillionUsd: 75.0,
      ),
      'claude-sonnet-4-20250514': ModelPricing(
        inputPerMillionUsd: 3.0,
        cachedInputPerMillionUsd: 0.3,
        outputPerMillionUsd: 15.0,
      ),
      'claude-haiku-4-20250414': ModelPricing(
        inputPerMillionUsd: 0.8,
        cachedInputPerMillionUsd: 0.08,
        outputPerMillionUsd: 4.0,
      ),
    },
    'deepseek': {
      'deepseek-chat': ModelPricing(
        inputPerMillionUsd: 0.27,
        cachedInputPerMillionUsd: 0.07,
        outputPerMillionUsd: 1.10,
      ),
      'deepseek-reasoner': ModelPricing(
        inputPerMillionUsd: 0.55,
        cachedInputPerMillionUsd: 0.14,
        outputPerMillionUsd: 2.19,
      ),
    },
    'qwen': {
      'qwen-turbo': ModelPricing(
        inputPerMillionUsd: 0.05,
        outputPerMillionUsd: 0.20,
      ),
      'qwen-plus': ModelPricing(
        inputPerMillionUsd: 0.40,
        outputPerMillionUsd: 1.20,
      ),
      'qwen-max': ModelPricing(
        inputPerMillionUsd: 1.60,
        outputPerMillionUsd: 6.40,
      ),
    },
    'zhipu': {
      'glm-4-flash': ModelPricing(), // free tier
      'glm-4.5-flash': ModelPricing(), // free tier
      'glm-4.7-flash': ModelPricing(), // free tier
      'glm-4': ModelPricing(
        inputPerMillionUsd: 14.0,
        outputPerMillionUsd: 14.0,
      ),
    },
    'apple': {
      'cloud': ModelPricing(), // free
      'on-device': ModelPricing(), // free
    },
  };

  ModelPricing? priceFor(String providerId, String modelId) =>
      _table[providerId]?[modelId];

  double? calculateCostUsd({
    required String providerId,
    required String modelId,
    required LlmUsage usage,
    double? audioSeconds,
  }) {
    final p = priceFor(providerId, modelId);
    if (p == null) return null;

    var total = 0.0;
    if (usage.inputTokens > 0 && p.inputPerMillionUsd != null) {
      final nonCached = (usage.inputTokens - usage.cachedInputTokens).clamp(
        0,
        usage.inputTokens,
      );
      total += nonCached / 1e6 * p.inputPerMillionUsd!;
    }
    if (usage.cachedInputTokens > 0 && p.cachedInputPerMillionUsd != null) {
      total += usage.cachedInputTokens / 1e6 * p.cachedInputPerMillionUsd!;
    }
    if (usage.outputTokens > 0 && p.outputPerMillionUsd != null) {
      total += usage.outputTokens / 1e6 * p.outputPerMillionUsd!;
    }
    if (usage.audioInputTokens > 0 && p.audioInputPerMillionUsd != null) {
      total += usage.audioInputTokens / 1e6 * p.audioInputPerMillionUsd!;
    }
    if (audioSeconds != null &&
        audioSeconds > 0 &&
        p.audioInputPerMinuteUsd != null) {
      total += audioSeconds / 60.0 * p.audioInputPerMinuteUsd!;
    }

    // Apple free entries (no rate fields populated) legitimately return 0.0.
    if (p.inputPerMillionUsd == null &&
        p.outputPerMillionUsd == null &&
        p.audioInputPerMillionUsd == null &&
        p.audioInputPerMinuteUsd == null) {
      return 0.0;
    }
    return total == 0 ? null : total;
  }
}
