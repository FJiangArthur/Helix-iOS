import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/cost/conversation_cost_tracker.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';

void main() {
  group('ConversationCostTracker', () {
    test('accumulates completed operation costs', () {
      final tracker = ConversationCostTracker();

      tracker.recordCompleted(
        operationType: AiOperationType.questionDetection,
        providerId: 'openai',
        modelId: 'gpt-5.4-mini',
        usage: const LlmUsage(inputTokens: 120, outputTokens: 20),
        costUsd: 0.0012,
      );
      tracker.recordCompleted(
        operationType: AiOperationType.answerGeneration,
        providerId: 'openai',
        modelId: 'gpt-5.4',
        usage: const LlmUsage(inputTokens: 450, outputTokens: 90),
        costUsd: 0.0185,
      );

      expect(tracker.totalCostUsd, closeTo(0.0197, 0.000001));
      expect(tracker.entries, hasLength(2));
    });
  });
}
