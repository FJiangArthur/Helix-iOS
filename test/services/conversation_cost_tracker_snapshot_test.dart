import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_helix/services/cost/conversation_cost_tracker.dart';
import 'package:flutter_helix/services/cost/session_cost_snapshot.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';

void main() {
  group('ConversationCostTracker snapshot stream', () {
    late ConversationCostTracker tracker;

    setUp(() {
      tracker = ConversationCostTracker();
    });

    tearDown(() {
      tracker.dispose();
    });

    test('records smart cost', () {
      tracker.recordCompleted(
        operationType: AiOperationType.answerGeneration,
        providerId: 'openai',
        modelId: 'gpt-5.4',
        usage: const LlmUsage(inputTokens: 1, outputTokens: 1),
        costUsd: 0.01,
        modelRole: ModelRole.smart,
      );
      expect(tracker.current.smartUsd, closeTo(0.01, 1e-9));
      expect(tracker.current.totalUsd, closeTo(0.01, 1e-9));
    });

    test('records light cost', () {
      tracker.recordCompleted(
        operationType: AiOperationType.questionDetection,
        providerId: 'openai',
        modelId: 'gpt-5.4-nano',
        usage: const LlmUsage(inputTokens: 1, outputTokens: 1),
        costUsd: 0.002,
        modelRole: ModelRole.light,
      );
      expect(tracker.current.lightUsd, closeTo(0.002, 1e-9));
      expect(tracker.current.totalUsd, closeTo(0.002, 1e-9));
    });

    test('Apple zero-cost transcription does not increment unpriced', () {
      tracker.recordCompleted(
        operationType: AiOperationType.transcription,
        providerId: 'apple',
        modelId: 'cloud',
        usage: const LlmUsage(),
        costUsd: 0.0,
        modelRole: ModelRole.transcription,
      );
      expect(tracker.current.transcriptionUsd, 0.0);
      expect(tracker.current.unpricedCallCount, 0);
    });

    test('null cost increments unpricedCallCount', () {
      tracker.recordCompleted(
        operationType: AiOperationType.answerGeneration,
        providerId: 'deepseek',
        modelId: 'deepseek-chat',
        usage: const LlmUsage(inputTokens: 5, outputTokens: 5),
        costUsd: null,
        modelRole: ModelRole.smart,
      );
      expect(tracker.current.unpricedCallCount, 1);
      expect(tracker.current.totalUsd, 0.0);
    });

    test('null modelRole buckets into smart', () {
      tracker.recordCompleted(
        operationType: AiOperationType.answerGeneration,
        providerId: 'openai',
        modelId: 'gpt-5.4',
        usage: const LlmUsage(inputTokens: 1),
        costUsd: 0.005,
      );
      expect(tracker.current.smartUsd, closeTo(0.005, 1e-9));
    });

    test('snapshots stream emits after each recordCompleted', () async {
      final events = <SessionCostSnapshot>[];
      final sub = tracker.snapshots.listen(events.add);
      tracker.recordCompleted(
        operationType: AiOperationType.answerGeneration,
        providerId: 'openai',
        modelId: 'gpt-5.4',
        usage: const LlmUsage(inputTokens: 1),
        costUsd: 0.01,
        modelRole: ModelRole.smart,
      );
      tracker.recordCompleted(
        operationType: AiOperationType.questionDetection,
        providerId: 'openai',
        modelId: 'gpt-5.4-nano',
        usage: const LlmUsage(inputTokens: 1),
        costUsd: 0.002,
        modelRole: ModelRole.light,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(events.length, 2);
      expect(events.last.smartUsd, closeTo(0.01, 1e-9));
      expect(events.last.lightUsd, closeTo(0.002, 1e-9));
    });

    test('reset emits zero snapshot and clears entries', () async {
      tracker.recordCompleted(
        operationType: AiOperationType.answerGeneration,
        providerId: 'openai',
        modelId: 'gpt-5.4',
        usage: const LlmUsage(inputTokens: 1),
        costUsd: 0.01,
        modelRole: ModelRole.smart,
      );
      final events = <SessionCostSnapshot>[];
      final sub = tracker.snapshots.listen(events.add);
      tracker.reset();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(tracker.current.totalUsd, 0.0);
      expect(tracker.entries, isEmpty);
      expect(events.last.totalUsd, 0.0);
    });
  });
}
