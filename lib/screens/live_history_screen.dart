// ABOUTME: Combined Live + History screen with sub-tabs at the top.
// ABOUTME: Embeds DetailAnalysisScreen and ConversationHistoryScreen as tab children.

import 'package:flutter/material.dart';

import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
import 'conversation_history_screen.dart';
import 'detail_analysis_screen.dart';
import 'settings_screen.dart';

class LiveHistoryScreen extends StatelessWidget {
  const LiveHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: HelixTheme.background,
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight + 8),
            child: SizedBox(
              height: kTextTabBarHeight + 8,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      indicatorColor: HelixTheme.cyan,
                      indicatorWeight: 2.5,
                      labelColor: HelixTheme.textPrimary,
                      unselectedLabelColor: HelixTheme.textMuted,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: tr('Live', '实时')),
                        Tab(text: tr('History', '历史')),
                      ],
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
          ),
        ),
        body: const TabBarView(
          children: [DetailAnalysisScreen(), ConversationHistoryScreen()],
        ),
      ),
    );
  }
}
