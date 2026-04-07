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
      // Smart models (Spec A default smart)
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
      // Light models (Spec A default light)
      'gpt-5.4-nano': ModelPricing(
        inputPerMillionUsd: 0.05,
        cachedInputPerMillionUsd: 0.005,
        outputPerMillionUsd: 0.4,
      ),
      // Transcription
      'gpt-4o-mini-transcribe': ModelPricing(audioInputPerMillionUsd: 3.0),
      'gpt-4o-transcribe': ModelPricing(audioInputPerMillionUsd: 6.0),
      'whisper-1': ModelPricing(audioInputPerMinuteUsd: 0.006),
      // OpenAI Realtime — billed per audio minute
      'gpt-4o-mini-realtime': ModelPricing(audioInputPerMinuteUsd: 0.06),
      'gpt-4o-realtime': ModelPricing(audioInputPerMinuteUsd: 0.10),
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
