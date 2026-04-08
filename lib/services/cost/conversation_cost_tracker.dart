import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../llm/llm_provider.dart';
import 'pricing_registry.dart';
import 'session_cost_snapshot.dart';

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
    this.modelRole,
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
  final ModelRole? modelRole;
}

class ConversationCostTracker {
  final List<ConversationCostEntry> _entries = [];
  final Uuid _uuid = const Uuid();
  final StreamController<SessionCostSnapshot> _snapshots =
      StreamController<SessionCostSnapshot>.broadcast();
  SessionCostSnapshot _current = SessionCostSnapshot.zero;

  List<ConversationCostEntry> get entries => List.unmodifiable(_entries);

  double get totalCostUsd => _current.totalUsd;

  Stream<SessionCostSnapshot> get snapshots => _snapshots.stream;
  SessionCostSnapshot get current => _current;

  void reset() {
    _entries.clear();
    _current = SessionCostSnapshot.zero;
    _snapshots.add(_current);
  }

  void dispose() {
    _snapshots.close();
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
    ModelRole? modelRole,
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
        modelRole: modelRole,
      ),
    );
    _current = _foldEntries();
    _snapshots.add(_current);

    // Diagnostic: capture per-call inputs + computed cost + running total
    // so the 2026-04-07 "cost seems wrong" hardware report can be mapped to
    // a specific bucket (wrong token count, wrong model lookup, wrong rate,
    // or double-counting). Remove once cost accuracy is verified.
    debugPrint(
      '[CostTracker] +${operationType.name} provider=$providerId '
      'model=$modelId role=${modelRole?.name ?? "null"} '
      'in=${usage.inputTokens} cachedIn=${usage.cachedInputTokens} '
      'out=${usage.outputTokens} audioIn=${usage.audioInputTokens} '
      'cost=${costUsd == null ? "null" : "\$${costUsd.toStringAsFixed(6)}"} '
      '→ total=\$${_current.totalUsd.toStringAsFixed(6)} '
      '(smart=\$${_current.smartUsd.toStringAsFixed(6)} '
      'light=\$${_current.lightUsd.toStringAsFixed(6)} '
      'tx=\$${_current.transcriptionUsd.toStringAsFixed(6)} '
      'unpriced=${_current.unpricedCallCount})',
    );
  }

  SessionCostSnapshot _foldEntries() {
    var smart = 0.0;
    var light = 0.0;
    var transcription = 0.0;
    var unpriced = 0;
    for (final e in _entries) {
      if (e.costUsd == null) {
        unpriced += 1;
        continue;
      }
      // null modelRole on legacy / pre-Spec-A entries is treated as smart.
      final role = e.modelRole ?? ModelRole.smart;
      switch (role) {
        case ModelRole.smart:
          smart += e.costUsd!;
          break;
        case ModelRole.light:
          light += e.costUsd!;
          break;
        case ModelRole.transcription:
          transcription += e.costUsd!;
          break;
      }
    }
    return SessionCostSnapshot(
      smartUsd: smart,
      lightUsd: light,
      transcriptionUsd: transcription,
      unpricedCallCount: unpriced,
    );
  }
}

/// Deprecated: use [PricingRegistry] instead. Kept as a thin shim until
/// downstream call sites are migrated.
@Deprecated('Use PricingRegistry.instance.calculateCostUsd instead')
class OpenAiPricingRegistry {
  static double? calculateCostUsd({
    required String modelId,
    required LlmUsage usage,
  }) {
    return PricingRegistry.instance.calculateCostUsd(
      providerId: 'openai',
      modelId: modelId,
      usage: usage,
    );
  }
}
