// ABOUTME: Combined Live + History screen with sub-tabs at the top.
// ABOUTME: Embeds DetailAnalysisScreen and ConversationHistoryScreen as tab children.

import 'package:flutter/material.dart';

import '../theme/helix_assets.dart';
import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
import '../widgets/helix/helix_generated_art.dart';
import '../widgets/helix/helix_segmented_tabs.dart';
import 'conversation_history_screen.dart';
import 'detail_analysis_screen.dart';
import 'projects/projects_list_screen.dart';
import 'settings_screen.dart';

class LiveHistoryScreen extends StatefulWidget {
  const LiveHistoryScreen({super.key});

  @override
  State<LiveHistoryScreen> createState() => _LiveHistoryScreenState();
}

class _LiveHistoryScreenState extends State<LiveHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
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
                key: const Key('sessions-generated-hero'),
                asset: HelixAssets.sessionsHero,
                accent: HelixTheme.lime,
                height: 104,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    children: [
                      const HelixGeneratedIcon(
                        asset: HelixAssets.navSessions,
                        selected: true,
                        size: 38,
                        semanticLabel: 'Sessions',
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tr('Sessions cockpit', '会话座舱'),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: HelixSegmentedTabs(
                      labels: [
                        tr('Monitor', '监控'),
                        tr('Archive', '归档'),
                        tr('Projects', '项目'),
                      ],
                      selectedIndex: _index,
                      onChanged: _setIndex,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: HelixTheme.textSecondary,
                    ),
                    tooltip: tr('Settings', '设置'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _controller,
                children: const [
                  DetailAnalysisScreen(),
                  ConversationHistoryScreen(),
                  ProjectsListScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
