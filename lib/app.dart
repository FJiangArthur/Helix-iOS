import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/conversation_history_screen.dart';
import 'screens/detail_analysis_screen.dart';
import 'screens/g1_test_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/helix_theme.dart';

class HelixApp extends StatelessWidget {
  const HelixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Even Companion',
      theme: HelixTheme.darkTheme,
      home: const AppEntry(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_complete') ?? false;
    if (mounted) setState(() => _showOnboarding = !seen);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
        ),
      );
    }

    if (_showOnboarding!) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }

    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// Switch to a specific tab by index (used by child widgets)
  static void switchToTab(int index) {
    _MainScreenState._instance?._switchTab(index);
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static _MainScreenState? _instance;
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const G1TestScreen(),
    const ConversationHistoryScreen(),
    const DetailAnalysisScreen(),
    const InsightsScreen(),
  ];

  final List<String> _titles = [
    'Home',
    'Glasses',
    'History',
    'Live',
    'Insights',
  ];

  @override
  void initState() {
    super.initState();
    _instance = this;
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }

  void _switchTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide AppBar for Home (0) and Insights (4) — Insights has its own with TabBar
    final showAppBar = _currentIndex != 0 && _currentIndex != 4;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(_titles[_currentIndex]),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: NavigationBar(
          key: const Key('main-navigation-bar'),
          height: 56,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.bluetooth_rounded),
              selectedIcon: Icon(Icons.bluetooth_connected_rounded),
              label: 'Glasses',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.radio_button_checked_rounded),
              selectedIcon: Icon(Icons.radio_button_checked_rounded),
              label: 'Live',
            ),
            NavigationDestination(
              icon: Icon(Icons.lightbulb_outline_rounded),
              selectedIcon: Icon(Icons.lightbulb_rounded),
              label: 'Insights',
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final void Function(Object error) onError;

  const ErrorBoundary({super.key, required this.child, required this.onError});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  void Function(FlutterErrorDetails details)? _previousOnError;
  late final void Function(FlutterErrorDetails details) _errorHandler;

  @override
  void initState() {
    super.initState();
    _previousOnError = FlutterError.onError;
    _errorHandler = (FlutterErrorDetails details) {
      widget.onError(details.exception);
      _previousOnError?.call(details);
    };
    FlutterError.onError = _errorHandler;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    if (identical(FlutterError.onError, _errorHandler)) {
      FlutterError.onError = _previousOnError;
    }
    super.dispose();
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const ErrorScreen({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Oops! Something went wrong',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
