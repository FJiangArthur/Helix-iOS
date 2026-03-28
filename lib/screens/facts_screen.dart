import 'dart:async';

import 'package:flutter/material.dart';

import '../models/fact.dart';
import '../services/database/helix_database.dart';
import '../services/facts/fact_service.dart';
import '../theme/helix_theme.dart';
import '../widgets/fact_card.dart';
import '../widgets/glass_card.dart';

/// Full-screen Facts view with two sections:
///
/// 1. **Pending** — swipeable card stack for quick confirm/reject.
/// 2. **Confirmed** — searchable, category-grouped knowledge graph.
class FactsScreen extends StatefulWidget {
  const FactsScreen({super.key});

  @override
  State<FactsScreen> createState() => _FactsScreenState();
}

class _FactsScreenState extends State<FactsScreen> {
  final _factService = FactService.instance;

  List<Fact> _pendingFacts = [];
  List<Fact> _confirmedFacts = [];
  int _confirmedCount = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _searchExpanded = false;

  StreamSubscription<List<Fact>>? _pendingSub;
  StreamSubscription<List<Fact>>? _confirmedSub;

  // Tracks categories that the user has collapsed.
  final Set<String> _collapsedCategories = {};

  @override
  void initState() {
    super.initState();
    _pendingSub = _factService.watchPendingFacts().listen((facts) {
      if (!mounted) return;
      setState(() => _pendingFacts = facts);
    });
    _confirmedSub = _factService.watchConfirmedFacts().listen((facts) {
      if (!mounted) return;
      setState(() {
        _confirmedFacts = facts;
        _confirmedCount = facts.length;
      });
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final pending = await _factService.getPendingFacts();
    final confirmed = await _factService.getConfirmedFacts();
    final count = await _factService.getConfirmedCount();
    if (!mounted) return;
    setState(() {
      _pendingFacts = pending;
      _confirmedFacts = confirmed;
      _confirmedCount = count;
    });
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _confirmedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _confirmFact(Fact fact) async {
    await _factService.confirmFact(fact.id);
  }

  Future<void> _rejectFact(Fact fact) async {
    await _factService.rejectFact(fact.id);
  }

  Future<void> _onSearch(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      final confirmed = await _factService.getConfirmedFacts();
      if (!mounted) return;
      setState(() => _confirmedFacts = confirmed);
    } else {
      final results = await _factService.searchFacts(query);
      if (!mounted) return;
      setState(() => _confirmedFacts = results);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      appBar: AppBar(
        title: const Text('Facts'),
        actions: [
          IconButton(
            icon: Icon(
              _searchExpanded ? Icons.close : Icons.search,
              color: HelixTheme.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _searchExpanded = !_searchExpanded;
                if (!_searchExpanded) {
                  _searchController.clear();
                  _onSearch('');
                }
              });
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search bar
          if (_searchExpanded)
            SliverToBoxAdapter(child: _buildSearchBar()),

          // Pending section
          if (_pendingFacts.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildPendingHeader()),
            SliverToBoxAdapter(child: _buildPendingCards()),
          ],

          // Empty pending state
          if (_pendingFacts.isEmpty)
            SliverToBoxAdapter(child: _buildAllCaughtUp()),

          // Confirmed section header
          SliverToBoxAdapter(child: _buildConfirmedHeader()),

          // Confirmed grouped list
          if (_confirmedFacts.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyConfirmed())
          else
            ..._buildCategoryGroups(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: HelixTheme.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Search facts...',
          prefixIcon: Icon(Icons.search, color: HelixTheme.textMuted, size: 20),
        ),
        onChanged: _onSearch,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pending section
  // ---------------------------------------------------------------------------

  Widget _buildPendingHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        '${_pendingFacts.length} new fact${_pendingFacts.length == 1 ? '' : 's'} to review',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HelixTheme.textSecondary,
            ),
      ),
    );
  }

  Widget _buildPendingCards() {
    // Show the top card as a swipeable Dismissible.
    final fact = _pendingFacts.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            // Background cards (stacked look)
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

            // Top card — swipeable
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
                label: 'Confirm',
              ),
              secondaryBackground: _buildSwipeBackground(
                alignment: Alignment.centerRight,
                color: HelixTheme.error,
                icon: Icons.close_rounded,
                label: 'Reject',
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
      ),
    );
  }

  Widget _buildGhostCard({required double opacity}) {
    return GlassCard(
      opacity: opacity,
      padding: const EdgeInsets.all(20),
      child: const SizedBox(height: 140),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: GlassCard(
        opacity: 0.10,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: HelixTheme.lime.withValues(alpha: 0.6),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                'All caught up!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: HelixTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'New facts will appear here after conversations.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Confirmed section
  // ---------------------------------------------------------------------------

  Widget _buildConfirmedHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text(
            'Knowledge Graph',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          Text(
            '$_confirmedCount confirmed',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConfirmed() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Text(
          _searchQuery.isNotEmpty
              ? 'No facts match "$_searchQuery"'
              : 'Confirmed facts will appear here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  /// Group confirmed facts by category and build collapsible sections.
  List<Widget> _buildCategoryGroups() {
    final grouped = <String, List<Fact>>{};
    for (final fact in _confirmedFacts) {
      grouped.putIfAbsent(fact.category, () => []).add(fact);
    }

    // Sort categories alphabetically.
    final sortedKeys = grouped.keys.toList()..sort();

    return sortedKeys.map((category) {
      final facts = grouped[category]!;
      final color = FactCard.categoryColor(category);
      final catEnum = FactCategory.fromString(category);
      final isCollapsed = _collapsedCategories.contains(category);

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category header (tap to collapse/expand)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    if (isCollapsed) {
                      _collapsedCategories.remove(category);
                    } else {
                      _collapsedCategories.add(category);
                    }
                  });
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        catEnum.displayName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: color,
                                ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${facts.length})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Icon(
                        isCollapsed
                            ? Icons.expand_more_rounded
                            : Icons.expand_less_rounded,
                        color: HelixTheme.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Fact items
              if (!isCollapsed)
                ...facts.map((fact) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        opacity: 0.10,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fact.content,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            if (fact.sourceQuote != null &&
                                fact.sourceQuote!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                fact.sourceQuote!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      );
    }).toList();
  }
}
