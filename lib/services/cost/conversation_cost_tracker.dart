import 'package:uuid/uuid.dart';

import '../llm/llm_provider.dart';

class ConversationCostEntry {
  ConversationCostEntry({
    required this.id,
    required this.operationType,
    required this.providerId,
    required this.modelId,
    required this.usage,
    required this.startedAt,
    required this.status,
    this.costUsd,
    this.completedAt,
  });

  final String id;
  final AiOperationType operationType;
  final String providerId;
  final String modelId;
  final LlmUsage usage;
  final DateTime startedAt;
  final String status;
  final double? costUsd;
  final DateTime? completedAt;
}

class ConversationCostTracker {
  final List<ConversationCostEntry> _entries = [];
  final Uuid _uuid = const Uuid();

  List<ConversationCostEntry> get entries => List.unmodifiable(_entries);

  double get totalCostUsd =>
      _entries.fold<double>(0, (sum, entry) => sum + (entry.costUsd ?? 0));

  void reset() {
    _entries.clear();
  }

  void recordCompleted({
    required AiOperationType operationType,
    required String providerId,
    required String modelId,
    required LlmUsage usage,
    required double? costUsd,
    DateTime? startedAt,
    DateTime? completedAt,
    String? status,
  }) {
    _entries.add(
      ConversationCostEntry(
        id: _uuid.v4(),
        operationType: operationType,
        providerId: providerId,
        modelId: modelId,
        usage: usage,
        startedAt: startedAt ?? DateTime.now(),
        completedAt: completedAt ?? DateTime.now(),
        status: status ?? (costUsd == null ? 'usage_only' : 'completed'),
        costUsd: costUsd,
      ),
    );
  }
}

class OpenAiPricingRegistry {
  static const Map<String, _OpenAiPricing> _pricingByModel = {
    'gpt-5.4': _OpenAiPricing(
      inputPerMillionUsd: 1.25,
      cachedInputPerMillionUsd: 0.125,
      outputPerMillionUsd: 10.0,
    ),
    'gpt-5.4-mini': _OpenAiPricing(
      inputPerMillionUsd: 0.25,
      cachedInputPerMillionUsd: 0.025,
      outputPerMillionUsd: 2.0,
    ),
    'gpt-5.4-nano': _OpenAiPricing(
      inputPerMillionUsd: 0.05,
      cachedInputPerMillionUsd: 0.005,
      outputPerMillionUsd: 0.4,
    ),
    'gpt-4o-mini-transcribe': _OpenAiPricing(audioInputPerMillionUsd: 3.0),
  };

  static double? calculateCostUsd({
    required String modelId,
    required LlmUsage usage,
  }) {
    final pricing = _pricingByModel[modelId];
    if (pricing == null) return null;

    var total = 0.0;
    if (usage.inputTokens > 0) {
      final nonCachedInput = (usage.inputTokens - usage.cachedInputTokens)
          .clamp(0, usage.inputTokens);
      total += (nonCachedInput / 1000000) * pricing.inputPerMillionUsd;
    }
    if (usage.cachedInputTokens > 0) {
      total +=
          (usage.cachedInputTokens / 1000000) *
          pricing.cachedInputPerMillionUsd;
    }
    if (usage.outputTokens > 0) {
      total += (usage.outputTokens / 1000000) * pricing.outputPerMillionUsd;
    }
    if (usage.audioInputTokens > 0) {
      total +=
          (usage.audioInputTokens / 1000000) * pricing.audioInputPerMillionUsd;
    }

    return total == 0 ? null : total;
  }
}

class _OpenAiPricing {
  const _OpenAiPricing({
    this.inputPerMillionUsd = 0,
    this.cachedInputPerMillionUsd = 0,
    this.outputPerMillionUsd = 0,
    this.audioInputPerMillionUsd = 0,
  });

  final double inputPerMillionUsd;
  final double cachedInputPerMillionUsd;
  final double outputPerMillionUsd;
  final double audioInputPerMillionUsd;
}
