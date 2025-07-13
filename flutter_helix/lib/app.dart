// ABOUTME: Main Flutter app widget with provider setup and routing
// ABOUTME: Configures theme, navigation, and dependency injection for the Helix app

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state_provider.dart';
import 'services/service_locator.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/loading_screen.dart';
import 'ui/theme/app_theme.dart';

class HelixApp extends StatelessWidget {
  const HelixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>(
          create: (context) => ServiceLocator.instance.get<AppStateProvider>(),
        ),
      ],
      child: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Helix',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appState.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: _buildHome(appState),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  Widget _buildHome(AppStateProvider appState) {
    switch (appState.appStatus) {
      case AppStatus.initializing:
        return const LoadingScreen();
      case AppStatus.ready:
        return const HomeScreen();
      case AppStatus.error:
        return ErrorScreen(
          error: appState.currentError ?? 'Unknown error occurred',
          onRetry: () => appState.retryInitialization(),
        );
      case AppStatus.updating:
        return const LoadingScreen(message: 'Updating...');
    }
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
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