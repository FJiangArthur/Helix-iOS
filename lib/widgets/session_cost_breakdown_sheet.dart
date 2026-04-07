import 'package:flutter/material.dart';

import '../services/cost/session_cost_snapshot.dart';

/// Bottom sheet showing per-role session cost breakdown.
///
/// Reused by both the live recording-bar pill and the history list cell.
class SessionCostBreakdownSheet extends StatelessWidget {
  const SessionCostBreakdownSheet({
    super.key,
    required this.snapshot,
    this.smartModelLabel,
    this.lightModelLabel,
    this.transcriptionModelLabel,
  });

  final SessionCostSnapshot snapshot;
  final String? smartModelLabel;
  final String? lightModelLabel;
  final String? transcriptionModelLabel;

  String _format(double usd) {
    if (usd == 0) return 'Free';
    return '\$${usd.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <_BreakdownRow>[
      _BreakdownRow('Smart', smartModelLabel ?? '—', snapshot.smartUsd),
      _BreakdownRow('Light', lightModelLabel ?? '—', snapshot.lightUsd),
      _BreakdownRow(
        'Transcription',
        transcriptionModelLabel ?? '—',
        snapshot.transcriptionUsd,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Session cost',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        r.role,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.model,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    Text(_format(r.cost)),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              children: [
                const SizedBox(
                  width: 110,
                  child: Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _format(snapshot.totalUsd),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (snapshot.unpricedCallCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${snapshot.unpricedCallCount} call(s) had no pricing data.',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow {
  const _BreakdownRow(this.role, this.model, this.cost);
  final String role;
  final String model;
  final double cost;
}
