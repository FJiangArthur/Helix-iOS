// ABOUTME: Combined Live + History screen with sub-tabs at the top.
// ABOUTME: Embeds DetailAnalysisScreen and ConversationHistoryScreen as tab children.

import 'package:flutter/material.dart';

import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
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
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
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
