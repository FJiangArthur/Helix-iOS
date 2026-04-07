import 'package:flutter/material.dart';

import '../services/conversation_engine.dart';
import '../services/cost/session_cost_snapshot.dart';
import 'session_cost_breakdown_sheet.dart';

/// Compact pill that displays the running session cost. Subscribes to
/// [ConversationEngine.costSnapshots] and updates as new LLM calls land.
/// Tap to open the per-role [SessionCostBreakdownSheet].
class SessionCostBadge extends StatelessWidget {
  SessionCostBadge({super.key, Stream<SessionCostSnapshot>? stream, this.initial})
    : stream = stream ?? ConversationEngine.instance.costSnapshots;

  final Stream<SessionCostSnapshot> stream;
  final SessionCostSnapshot? initial;

  String _label(SessionCostSnapshot snap) {
    if (snap.totalUsd == 0 && snap.unpricedCallCount == 0) {
      return 'Free';
    }
    if (snap.totalUsd == 0 && snap.unpricedCallCount > 0) {
      return '—';
    }
    return '\$${snap.totalUsd.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SessionCostSnapshot>(
      stream: stream,
      initialData: initial ?? ConversationEngine.instance.currentCostSnapshot,
      builder: (context, snapshot) {
        final snap = snapshot.data ?? SessionCostSnapshot.zero;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: const Color(0xFF1A1A24),
              builder: (_) => SessionCostBreakdownSheet(snapshot: snap),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              _label(snap),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
