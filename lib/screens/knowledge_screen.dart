// ABOUTME: Consolidated Knowledge area for Ask, Facts, Memories, and Review.

import 'package:flutter/material.dart';

import '../theme/helix_assets.dart';
import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
import '../widgets/helix/helix_generated_art.dart';
import '../widgets/helix/helix_segmented_tabs.dart';
import 'buzz_screen.dart';
import 'facts_screen.dart';
import 'memories_screen.dart';
import 'pending_facts_review.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 4, vsync: this);
    _controller.addListener(() {
      if (!_controller.indexIsChanging && mounted) {
        setState(() => _index = _controller.index);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setIndex(int index) {
    setState(() => _index = index);
    _controller.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: HelixGeneratedBackdrop(
                key: const Key('knowledge-generated-hero'),
                asset: HelixAssets.knowledgeHero,
                accent: HelixTheme.purple,
                height: 104,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    children: [
                      const HelixGeneratedIcon(
                        asset: HelixAssets.navKnowledge,
                        selected: true,
                        size: 38,
                        semanticLabel: 'Knowledge',
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tr('Knowledge surface', '知识界面'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: HelixSegmentedTabs(
                labels: [
                  tr('Ask', '提问'),
                  tr('Facts', '事实'),
                  tr('Memories', '记忆'),
                  tr('Review', '审阅'),
                ],
                selectedIndex: _index,
                onChanged: _setIndex,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _controller,
                children: const [
                  BuzzScreen(showAppBar: false),
                  FactsScreen(showAppBar: false),
                  MemoriesScreen(showAppBar: false),
                  PendingFactsReview(showScaffold: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
