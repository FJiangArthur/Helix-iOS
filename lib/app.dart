import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/ask_ai_screen.dart';
import 'screens/g1_test_screen.dart';
import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/live_history_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/helix_theme.dart';
import 'utils/i18n.dart';

class HelixApp extends StatelessWidget {
  const HelixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helix',
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

  late final List<WidgetBuilder> _screenBuilders = [
    (_) => const HomeScreen(),
    (_) => const G1TestScreen(),
    (_) => const LiveHistoryScreen(),
    (_) => const AskAiScreen(),
    (_) => const InsightsScreen(),
  ];
  late final List<Widget?> _loadedScreens = List<Widget?>.filled(
    _screenBuilders.length,
    null,
  );

  @override
  void initState() {
    super.initState();
    _instance = this;
    _ensureScreenLoaded(_currentIndex);
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }

  void _switchTab(int index) {
    if (index >= 0 && index < _loadedScreens.length) {
      setState(() {
        _ensureScreenLoaded(index);
        _currentIndex = index;
      });
    }
  }

  void _ensureScreenLoaded(int index) {
    _loadedScreens[index] ??= _screenBuilders[index](context);
  }

  @override
  Widget build(BuildContext context) {
    // All tabs manage their own AppBar (Home=0 has none, tabs 1-3 have TabBars)
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(
          _loadedScreens.length,
          (index) => _loadedScreens[index] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: NavigationBar(
          key: const Key('main-navigation-bar'),
          height: 62,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _ensureScreenLoaded(index);
              _currentIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: const Icon(Icons.chat_bubble_rounded),
              label: tr('Home', '首页'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bluetooth_rounded),
              selectedIcon: const Icon(Icons.bluetooth_connected_rounded),
              label: tr('Glasses', '眼镜'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.graphic_eq_rounded),
              selectedIcon: const Icon(Icons.graphic_eq_rounded),
              label: tr('Live', '实时'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome),
              label: tr('Ask AI', '问 AI'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.lightbulb_outline_rounded),
              selectedIcon: const Icon(Icons.lightbulb_rounded),
              label: tr('Insights', '洞察'),
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
