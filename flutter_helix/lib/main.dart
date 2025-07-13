// ABOUTME: Main entry point for the Helix Flutter app
// ABOUTME: Initializes dependency injection, error handling, and launches the app

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/service_locator.dart';
import 'core/utils/logging_service.dart';
import 'core/utils/constants.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error('Flutter', 'Unhandled Flutter error', details.exception, details.stack);
  };

  // Set up dependency injection
  try {
    await setupServiceLocator();
    logger.info('Main', 'Service locator initialized successfully');
  } catch (error, stackTrace) {
    logger.critical('Main', 'Failed to initialize service locator', error, stackTrace);
    // Continue with app launch even if some services fail
  }

  // Configure system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Launch the app
  runApp(const HelixApp());
}

class HelixApp extends StatelessWidget {
  const HelixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: UIConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const HelixHomePage(),
      builder: (context, child) {
        // Global error boundary
        return ErrorBoundary(child: child ?? const SizedBox());
      },
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3), // Helix blue
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 4,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          ),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 4,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
        ),
      ),
    );
  }
}

class HelixHomePage extends StatefulWidget {
  const HelixHomePage({super.key});

  @override
  State<HelixHomePage> createState() => _HelixHomePageState();
}

class _HelixHomePageState extends State<HelixHomePage> {
  @override
  void initState() {
    super.initState();
    logger.info('HelixHomePage', 'App launched successfully');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(UIConstants.appName),
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.headset_mic,
              size: 64,
              color: Color(0xFF2196F3),
            ),
            SizedBox(height: 24),
            Text(
              UIConstants.appName,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              UIConstants.appTagline,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 48),
            Text(
              'Flutter Architecture Foundation Ready! 🚀',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Next: Implementing core service interfaces...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Global error boundary widget to catch and handle widget errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool hasError = false;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Error'),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? 'An unexpected error occurred',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        hasError = false;
                        errorMessage = null;
                      });
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }

  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (hasError) {
      setState(() {
        hasError = false;
        errorMessage = null;
      });
    }
  }
}