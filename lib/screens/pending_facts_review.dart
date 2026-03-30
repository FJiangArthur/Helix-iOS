// ABOUTME: Standalone pending facts review widget with swipeable card stack.
// ABOUTME: Extracted from InsightsScreen for use in the Ask AI tab.

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/database/helix_database.dart';
import '../services/facts/fact_service.dart';
import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
import '../widgets/fact_card.dart';
import '../widgets/glass_card.dart';

class PendingFactsReview extends StatefulWidget {
  const PendingFactsReview({super.key});

  @override
  State<PendingFactsReview> createState() => _PendingFactsReviewState();
}

class _PendingFactsReviewState extends State<PendingFactsReview> {
  final _factService = FactService.instance;
  List<Fact> _pendingFacts = [];
  StreamSubscription<List<Fact>>? _pendingSub;

  @override
  void initState() {
    super.initState();
    _pendingSub = _factService.watchPendingFacts().listen((facts) {
      if (!mounted) return;
      setState(() => _pendingFacts = facts);
    });
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final pending = await _factService.getPendingFacts();
    if (!mounted) return;
    setState(() => _pendingFacts = pending);
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    super.dispose();
  }

  Future<void> _confirmFact(Fact fact) async {
    await _factService.confirmFact(fact.id);
  }

  Future<void> _rejectFact(Fact fact) async {
    await _factService.rejectFact(fact.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      body: SafeArea(
        child: _pendingFacts.isEmpty
            ? _buildAllCaughtUp()
            : _buildReviewContent(),
      ),
    );
  }

  Widget _buildReviewContent() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(Icons.swipe_rounded,
                  color: HelixTheme.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_pendingFacts.length} fact${_pendingFacts.length == 1 ? '' : 's'} to review',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: HelixTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        // Instruction
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            tr('Swipe right to confirm, left to reject',
                '向右滑动确认，向左滑动拒绝'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        // Card stack
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPendingCards(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingCards() {
    final fact = _pendingFacts.first;

    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          if (_pendingFacts.length > 2)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _buildGhostCard(opacity: 0.08),
            ),
          if (_pendingFacts.length > 1)
            Positioned(
              top: 6,
              left: 6,
              right: 6,
              child: _buildGhostCard(opacity: 0.14),
            ),
          Dismissible(
            key: ValueKey(fact.id),
            direction: DismissDirection.horizontal,
            onDismissed: (direction) {
              if (direction == DismissDirection.startToEnd) {
                _confirmFact(fact);
              } else {
                _rejectFact(fact);
              }
            },
            background: _buildSwipeBackground(
              alignment: Alignment.centerLeft,
              color: HelixTheme.lime,
              icon: Icons.check_rounded,
              label: tr('Confirm', '确认'),
            ),
            secondaryBackground: _buildSwipeBackground(
              alignment: Alignment.centerRight,
              color: HelixTheme.error,
              icon: Icons.close_rounded,
              label: tr('Reject', '拒绝'),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FactCard(
                category: fact.category,
                content: fact.content,
                sourceQuote: fact.sourceQuote,
                confidence: fact.confidence,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGhostCard({required double opacity}) {
    return GlassCard(
      opacity: opacity,
      padding: const EdgeInsets.all(20),
      child: const SizedBox(height: 160),
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllCaughtUp() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          opacity: 0.10,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: HelixTheme.lime.withValues(alpha: 0.6),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                tr('All caught up!', '已全部查看！'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: HelixTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('New facts will appear here after conversations.',
                    '对话后新发现的事实将出现在这里。'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
