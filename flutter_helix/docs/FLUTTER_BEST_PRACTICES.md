# Flutter Development Best Practices
# Production-Ready Mobile App Development Guide

## Overview

This document outlines comprehensive best practices for Flutter development, covering architecture, performance, security, and maintainability. These guidelines are based on industry standards and lessons learned from building production Flutter applications.

## Table of Contents

1. [Project Architecture](#project-architecture)
2. [Code Organization](#code-organization)
3. [State Management](#state-management)
4. [Performance Optimization](#performance-optimization)
5. [Security Best Practices](#security-best-practices)
6. [UI/UX Guidelines](#uiux-guidelines)
7. [Error Handling](#error-handling)
8. [Testing Strategy](#testing-strategy)
9. [Build & Deployment](#build--deployment)
10. [Monitoring & Analytics](#monitoring--analytics)

## Project Architecture

### Clean Architecture Principles

```
lib/
├── core/                    # Core business logic
│   ├── entities/           # Business entities
│   ├── usecases/          # Business use cases
│   ├── errors/            # Error handling
│   └── utils/             # Utilities and extensions
├── data/                   # Data layer
│   ├── models/            # Data models
│   ├── repositories/      # Repository implementations
│   ├── datasources/       # Local and remote data sources
│   └── mappers/           # Data mapping logic
├── domain/                 # Domain layer
│   ├── entities/          # Domain entities
│   ├── repositories/      # Repository interfaces
│   └── usecases/          # Use case interfaces
├── presentation/           # Presentation layer
│   ├── pages/             # Screen widgets
│   ├── widgets/           # Reusable UI components
│   ├── providers/         # State management
│   └── utils/             # UI utilities
└── injection/              # Dependency injection
```

### Dependency Injection Pattern

```dart
// injection/injection_container.dart
import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  // External dependencies
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => SharedPreferences.getInstance());
  
  // Data sources
  sl.registerLazySingleton<RemoteDataSource>(
    () => RemoteDataSourceImpl(client: sl()),
  );
  
  // Repositories
  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(remoteDataSource: sl()),
  );
  
  // Use cases
  sl.registerLazySingleton(() => GetUserUseCase(sl()));
  
  // Providers
  sl.registerFactory(() => UserProvider(getUserUseCase: sl()));
}
```

## Code Organization

### File Naming Conventions

```
// Good examples
user_repository.dart
conversation_card.dart
audio_service_impl.dart
transcription_model.g.dart

// Avoid
UserRepository.dart
conversationCard.dart
audioServiceImplementation.dart
```

### Import Organization

```dart
// 1. Dart imports
import 'dart:async';
import 'dart:io';

// 2. Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. Package imports (alphabetical)
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

// 4. Local imports (alphabetical)
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'widgets/custom_button.dart';
```

### Documentation Standards

```dart
/// Service responsible for managing user authentication
/// 
/// Handles login, logout, token refresh, and session management.
/// Integrates with Firebase Auth and custom backend APIs.
/// 
/// Example usage:
/// ```dart
/// final authService = AuthService();
/// final user = await authService.signInWithEmail(email, password);
/// ```
class AuthService {
  /// Signs in user with email and password
  /// 
  /// Returns [User] on success, throws [AuthException] on failure.
  /// Automatically handles token storage and session initialization.
  /// 
  /// Throws:
  /// * [InvalidCredentialsException] - Invalid email/password
  /// * [NetworkException] - Network connectivity issues
  /// * [ServerException] - Server-side errors
  Future<User> signInWithEmail(String email, String password) async {
    // Implementation
  }
}
```

## State Management

### Provider Pattern Best Practices

```dart
// Use ChangeNotifier for complex state
class ConversationProvider extends ChangeNotifier {
  final List<TranscriptionSegment> _segments = [];
  bool _isRecording = false;
  
  // Expose immutable views
  List<TranscriptionSegment> get segments => List.unmodifiable(_segments);
  bool get isRecording => _isRecording;
  
  // Single responsibility methods
  void startRecording() {
    _isRecording = true;
    notifyListeners();
  }
  
  void addSegment(TranscriptionSegment segment) {
    _segments.add(segment);
    notifyListeners();
  }
  
  // Dispose resources properly
  @override
  void dispose() {
    _segments.clear();
    super.dispose();
  }
}

// Use MultiProvider for complex dependencies
class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => sl<ConversationProvider>()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => sl<UserProvider>(),
          update: (_, auth, previous) => previous!..updateAuth(auth),
        ),
      ],
      child: MaterialApp(
        home: const HomeScreen(),
      ),
    );
  }
}
```

### Riverpod Alternative (Recommended for Large Apps)

```dart
// Define providers
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioServiceImpl();
});

final conversationProvider = StateNotifierProvider<ConversationNotifier, ConversationState>((ref) {
  final audioService = ref.watch(audioServiceProvider);
  return ConversationNotifier(audioService);
});

// Use in widgets
class ConversationPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationState = ref.watch(conversationProvider);
    
    return Scaffold(
      body: conversationState.when(
        loading: () => const CircularProgressIndicator(),
        error: (error, stack) => ErrorWidget(error.toString()),
        data: (conversation) => ConversationView(conversation),
      ),
    );
  }
}
```

## Performance Optimization

### Widget Performance

```dart
// Use const constructors whenever possible
class CustomCard extends StatelessWidget {
  const CustomCard({
    super.key,
    required this.title,
    required this.content,
  });
  
  final String title;
  final String content;
  
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title),
            Text(content),
          ],
        ),
      ),
    );
  }
}

// Use Builder widgets to limit rebuild scope
class OptimizedWidget extends StatefulWidget {
  @override
  State<OptimizedWidget> createState() => _OptimizedWidgetState();
}

class _OptimizedWidgetState extends State<OptimizedWidget> {
  int _counter = 0;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // This part doesn't rebuild when counter changes
        const ExpensiveWidget(),
        
        // Only this Builder rebuilds
        Builder(
          builder: (context) => Text('Counter: $_counter'),
        ),
        
        ElevatedButton(
          onPressed: () => setState(() => _counter++),
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

### Memory Management

```dart
// Dispose resources properly
class AudioPlayerWidget extends StatefulWidget {
  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> 
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late StreamSubscription _audioSubscription;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _audioSubscription = audioService.stream.listen(_onAudioUpdate);
    _timer = Timer.periodic(const Duration(seconds: 1), _updateUI);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _audioSubscription.cancel();
    _timer?.cancel();
    super.dispose();
  }
  
  // Implementation...
}
```

### List Performance

```dart
// Use ListView.builder for large lists
class ConversationList extends StatelessWidget {
  final List<TranscriptionSegment> segments;
  
  const ConversationList({super.key, required this.segments});
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        return ConversationTile(
          key: ValueKey(segment.id), // Important for performance
          segment: segment,
        );
      },
    );
  }
}

// Use RepaintBoundary for expensive widgets
class ExpensiveVisualization extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: ComplexVisualizationPainter(),
        size: const Size(300, 200),
      ),
    );
  }
}
```

## Security Best Practices

### API Key Management

```dart
// Use environment variables and secure storage
class ConfigService {
  static const String _openaiKeyKey = 'openai_api_key';
  static const String _anthropicKeyKey = 'anthropic_api_key';
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: IOSAccessibility.first_unlock_this_device,
    ),
  );
  
  Future<void> setOpenAIKey(String key) async {
    await _secureStorage.write(key: _openaiKeyKey, value: key);
  }
  
  Future<String?> getOpenAIKey() async {
    return await _secureStorage.read(key: _openaiKeyKey);
  }
  
  // Validate keys before storage
  bool isValidAPIKey(String key, APIProvider provider) {
    switch (provider) {
      case APIProvider.openai:
        return key.startsWith('sk-') && key.length > 20;
      case APIProvider.anthropic:
        return key.startsWith('sk-ant-') && key.length > 30;
    }
  }
}
```

### Network Security

```dart
// Use certificate pinning for sensitive APIs
class SecureHttpClient {
  static Dio createSecureClient() {
    final dio = Dio();
    
    // Add certificate pinning
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      client.badCertificateCallback = (cert, host, port) {
        // Implement certificate validation
        return validateCertificate(cert, host);
      };
      return client;
    };
    
    // Add request/response interceptors
    dio.interceptors.addAll([
      AuthInterceptor(),
      LoggingInterceptor(),
      ErrorInterceptor(),
    ]);
    
    return dio;
  }
}

// Sanitize user inputs
class InputValidator {
  static String sanitizeText(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'[^\w\s\.,!?-]'), '') // Allow only safe characters
        .trim();
  }
  
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
```

### Data Protection

```dart
// Encrypt sensitive data before storage
class SecureDataService {
  final _encryption = Encrypt(AES(Key.fromSecureRandom(32)));
  final _iv = IV.fromSecureRandom(16);
  
  Future<void> storeSecureData(String key, String data) async {
    final encrypted = _encryption.encrypt(data, iv: _iv);
    await _secureStorage.write(key: key, value: encrypted.base64);
  }
  
  Future<String?> getSecureData(String key) async {
    final encryptedData = await _secureStorage.read(key: key);
    if (encryptedData == null) return null;
    
    final encrypted = Encrypted.fromBase64(encryptedData);
    return _encryption.decrypt(encrypted, iv: _iv);
  }
}
```

## UI/UX Guidelines

### Responsive Design

```dart
// Use responsive design patterns
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;
  
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return mobile;
        } else if (constraints.maxWidth < 1200) {
          return tablet;
        } else {
          return desktop;
        }
      },
    );
  }
}

// Use MediaQuery for dynamic sizing
class AdaptiveButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  
  const AdaptiveButton({
    super.key,
    required this.text,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth < 600 ? screenWidth * 0.8 : 300.0;
    
    return SizedBox(
      width: buttonWidth,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }
}
```

### Accessibility

```dart
// Implement proper accessibility
class AccessibleWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Start recording conversation',
      hint: 'Double tap to begin audio recording',
      button: true,
      child: GestureDetector(
        onTap: _startRecording,
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
          ),
          child: const Icon(
            Icons.mic,
            color: Colors.white,
            size: 32,
            semanticLabel: 'Microphone',
          ),
        ),
      ),
    );
  }
}

// Support platform conventions
class PlatformAwareWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Platform.isIOS 
      ? CupertinoButton(
          onPressed: _onPressed,
          child: const Text('iOS Style Button'),
        )
      : ElevatedButton(
          onPressed: _onPressed,
          child: const Text('Material Style Button'),
        );
  }
}
```

### Animation Best Practices

```dart
// Use implicit animations when possible
class AnimatedCard extends StatefulWidget {
  final bool isExpanded;
  
  const AnimatedCard({super.key, required this.isExpanded});
  
  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: widget.isExpanded ? 200 : 100,
      child: Card(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: widget.isExpanded ? 1.0 : 0.5,
          child: const Center(child: Text('Content')),
        ),
      ),
    );
  }
}

// Use explicit animations for complex sequences
class ComplexAnimation extends StatefulWidget {
  @override
  State<ComplexAnimation> createState() => _ComplexAnimationState();
}

class _ComplexAnimationState extends State<ComplexAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    ));
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: child,
          ),
        );
      },
      child: const Icon(Icons.star, size: 50),
    );
  }
}
```

## Error Handling

### Custom Exception Classes

```dart
// Define specific exception types
abstract class AppException implements Exception {
  const AppException(this.message);
  final String message;
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class AuthenticationException extends AppException {
  const AuthenticationException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

// Handle exceptions consistently
class ApiService {
  Future<T> handleApiCall<T>(Future<Response> apiCall) async {
    try {
      final response = await apiCall;
      
      if (response.statusCode == 200) {
        return response.data as T;
      } else if (response.statusCode == 401) {
        throw const AuthenticationException('Authentication failed');
      } else if (response.statusCode >= 500) {
        throw const NetworkException('Server error occurred');
      } else {
        throw NetworkException('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
          throw const NetworkException('Connection timeout');
        case DioExceptionType.connectionError:
          throw const NetworkException('No internet connection');
        default:
          throw NetworkException('Network error: ${e.message}');
      }
    } catch (e) {
      throw AppException('Unexpected error: $e');
    }
  }
}
```

### Global Error Handling

```dart
// Implement global error boundary
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  
  const ErrorBoundary({super.key, required this.child});
  
  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? error;
  StackTrace? stackTrace;
  
  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ErrorScreen(
        error: error!,
        onRetry: () => setState(() {
          error = null;
          stackTrace = null;
        }),
      );
    }
    
    return ErrorWidget.builder = (FlutterErrorDetails details) {
      return ErrorScreen(
        error: details.exception,
        onRetry: () => setState(() {
          error = null;
          stackTrace = null;
        }),
      );
    };
    
    return widget.child;
  }
}

// Centralized error logging
class ErrorReportingService {
  static void reportError(Object error, StackTrace? stackTrace) {
    // Log to console in debug mode
    if (kDebugMode) {
      print('Error: $error');
      print('Stack trace: $stackTrace');
    }
    
    // Report to crash analytics in production
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: false,
      );
    }
  }
}
```

## Build & Deployment

### Environment Configuration

```dart
// config/environment.dart
enum Environment { development, staging, production }

class Config {
  static Environment _environment = Environment.development;
  
  static String get apiBaseUrl {
    switch (_environment) {
      case Environment.development:
        return 'https://dev-api.helix.com';
      case Environment.staging:
        return 'https://staging-api.helix.com';
      case Environment.production:
        return 'https://api.helix.com';
    }
  }
  
  static bool get enableLogging => _environment != Environment.production;
  
  static void setEnvironment(Environment environment) {
    _environment = environment;
  }
}

// main_development.dart
import 'config/environment.dart';

void main() {
  Config.setEnvironment(Environment.development);
  runApp(const HelixApp());
}
```

### Build Scripts

```yaml
# scripts/build.yml
name: Build and Deploy

on:
  push:
    branches: [main, develop]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.19.0'
        channel: 'stable'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Run tests
      run: flutter test --coverage
    
    - name: Build iOS
      run: |
        flutter build ios --release --no-codesign
        cd ios
        xcodebuild -workspace Runner.xcworkspace \
                   -scheme Runner \
                   -configuration Release \
                   -archivePath build/Runner.xcarchive \
                   archive
    
    - name: Build Android
      run: |
        flutter build appbundle --release
        flutter build apk --release
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: app-bundles
        path: |
          build/app/outputs/bundle/release/
          build/app/outputs/apk/release/
```

### Code Signing

```bash
# iOS code signing setup
security create-keychain -p "" build.keychain
security import certificate.p12 -t agg -k build.keychain -P $CERT_PASSWORD -A
security list-keychains -s build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "" build.keychain

# Android signing
echo $ANDROID_KEYSTORE | base64 -d > android/app/key.jks
echo "storeFile=key.jks" >> android/key.properties
echo "storePassword=$KEYSTORE_PASSWORD" >> android/key.properties
echo "keyAlias=$KEY_ALIAS" >> android/key.properties
echo "keyPassword=$KEY_PASSWORD" >> android/key.properties
```

## Monitoring & Analytics

### Performance Monitoring

```dart
// Performance tracking
class PerformanceMonitor {
  static void trackPageLoad(String pageName) {
    final stopwatch = Stopwatch()..start();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      stopwatch.stop();
      FirebasePerformance.instance
          .newTrace('page_load_$pageName')
          .start()
          .stop();
    });
  }
  
  static Future<T> trackAsyncOperation<T>(
    String operationName,
    Future<T> operation,
  ) async {
    final trace = FirebasePerformance.instance.newTrace(operationName);
    trace.start();
    
    try {
      final result = await operation;
      trace.putAttribute('success', 'true');
      return result;
    } catch (e) {
      trace.putAttribute('success', 'false');
      trace.putAttribute('error', e.toString());
      rethrow;
    } finally {
      trace.stop();
    }
  }
}

// Usage tracking
class AnalyticsService {
  static void trackEvent(String eventName, Map<String, dynamic> parameters) {
    FirebaseAnalytics.instance.logEvent(
      name: eventName,
      parameters: parameters,
    );
  }
  
  static void trackUserAction(UserAction action, {Map<String, dynamic>? metadata}) {
    trackEvent('user_action', {
      'action_type': action.name,
      'timestamp': DateTime.now().toIso8601String(),
      ...?metadata,
    });
  }
}
```

### Crash Reporting

```dart
// main.dart crash handling
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Handle Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  
  // Handle async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  runApp(const HelixApp());
}
```

## Summary

These best practices provide a solid foundation for building production-ready Flutter applications. Key takeaways:

1. **Architecture**: Use clean architecture with proper separation of concerns
2. **Performance**: Optimize widgets, manage memory, and monitor performance
3. **Security**: Protect sensitive data and validate all inputs
4. **Testing**: Implement comprehensive testing at all levels
5. **Deployment**: Automate builds and use proper CI/CD practices
6. **Monitoring**: Track performance and user behavior

Regular review and updates of these practices will help maintain code quality and adapt to new Flutter features and community standards.