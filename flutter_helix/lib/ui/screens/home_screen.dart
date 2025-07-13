// ABOUTME: Main home screen with bottom navigation and tab management
// ABOUTME: Provides access to conversation, analysis, glasses, history, and settings

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../core/utils/constants.dart';
import '../widgets/conversation_tab.dart';
import '../widgets/analysis_tab.dart';
import '../widgets/glasses_tab.dart';
import '../widgets/history_tab.dart';
import '../widgets/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const ConversationTab(),
    const AnalysisTab(),
    const GlassesTab(),
    const HistoryTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: _buildTabIcon(Icons.mic, 0, appState.isRecording),
                label: UIConstants.tabLabels[0],
              ),
              BottomNavigationBarItem(
                icon: _buildTabIcon(Icons.analytics, 1, appState.isAnalyzing),
                label: UIConstants.tabLabels[1],
              ),
              BottomNavigationBarItem(
                icon: _buildTabIcon(Icons.glasses, 2, appState.glassesConnected),
                label: UIConstants.tabLabels[2],
              ),
              BottomNavigationBarItem(
                icon: _buildTabIcon(Icons.history, 3, false),
                label: UIConstants.tabLabels[3],
              ),
              BottomNavigationBarItem(
                icon: _buildTabIcon(Icons.settings, 4, false),
                label: UIConstants.tabLabels[4],
              ),
            ],
          );
        },
      ),
      floatingActionButton: _currentIndex == 0 ? _buildRecordingFab() : null,
    );
  }

  Widget _buildTabIcon(IconData icon, int tabIndex, bool isActive) {
    if (isActive && tabIndex != _currentIndex) {
      return Stack(
        children: [
          Icon(icon),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: tabIndex == 0 ? Colors.red : Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }
    return Icon(icon);
  }

  Widget _buildRecordingFab() {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return FloatingActionButton(
          onPressed: appState.readyForConversation
              ? () => appState.toggleRecording()
              : null,
          backgroundColor: appState.isRecording
              ? Colors.red
              : Theme.of(context).colorScheme.primary,
          child: Icon(
            appState.isRecording ? Icons.stop : Icons.mic,
            color: Colors.white,
          ),
        );
      },
    );
  }
}