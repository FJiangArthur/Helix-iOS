/// Test Helpers for Helix iOS Application
///
/// This file provides common test utilities, matchers, and helper functions
/// to simplify writing tests across the application.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

/// Custom matchers for testing
class TestMatchers {
  /// Matches a DateTime within a certain tolerance
  static Matcher isDateTimeCloseTo(DateTime expected, {Duration tolerance = const Duration(milliseconds: 100)}) {
    return predicate<DateTime>(
      (DateTime actual) {
        final Duration difference = actual.difference(expected).abs();
        return difference <= tolerance;
      },
      'is within $tolerance of $expected',
    );
  }

  /// Matches a double within a certain epsilon
  static Matcher isCloseToDouble(double expected, {double epsilon = 0.001}) {
    return predicate<double>(
      (double actual) => (actual - expected).abs() <= epsilon,
      'is within $epsilon of $expected',
    );
  }

  /// Matches a list with specific length
  static Matcher hasLength(int expected) {
    return predicate<List<dynamic>>(
      (List<dynamic> actual) => actual.length == expected,
      'has length $expected',
    );
  }

  /// Matches a non-empty string
  static Matcher isNonEmptyString = predicate<String>(
    (String value) => value.isNotEmpty,
    'is a non-empty string',
  );

  /// Matches a valid audio chunk duration
  static Matcher isValidAudioDuration = predicate<int>(
    (int durationMs) => durationMs >= 0 && durationMs <= 60000, // 0-60 seconds
    'is a valid audio duration (0-60000ms)',
  );
}

/// Pump and settle helper with timeout
Future<void> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
  Duration duration = const Duration(milliseconds: 100),
}) async {
  await tester.pumpAndSettle(duration, EnginePhase.sendSemanticsUpdate, timeout);
}

/// Wait for a condition to be true
Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);

  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future<void>.delayed(interval);
  }
}

/// Execute a test with a timeout
Future<T> withTimeout<T>(
  Future<T> Function() test, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  return test().timeout(timeout);
}

/// Create a basic test widget wrapper
Widget createTestWidget({
  required Widget child,
  ThemeData? theme,
  List<NavigatorObserver>? navigatorObservers,
}) {
  return MaterialApp(
    theme: theme,
    navigatorObservers: navigatorObservers ?? <NavigatorObserver>[],
    home: Scaffold(
      body: child,
    ),
  );
}

/// Verify that a stream emits expected values in order
Future<void> expectStreamEmits<T>(
  Stream<T> stream,
  List<T> expectedValues, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final List<T> emittedValues = <T>[];
  final StreamSubscription<T> subscription = stream.listen(emittedValues.add);

  try {
    await waitForCondition(
      () => emittedValues.length >= expectedValues.length,
      timeout: timeout,
    );

    expect(emittedValues, equals(expectedValues));
  } finally {
    await subscription.cancel();
  }
}

/// Verify that a stream emits an error
Future<void> expectStreamEmitsError<T>(
  Stream<T> stream, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  bool errorEmitted = false;
  final StreamSubscription<T> subscription = stream.listen(
    (_) {},
    onError: (_) {
      errorEmitted = true;
    },
  );

  try {
    await waitForCondition(
      () => errorEmitted,
      timeout: timeout,
    );

    expect(errorEmitted, isTrue);
  } finally {
    await subscription.cancel();
  }
}

/// Test exception for timeout scenarios
class TimeoutException implements Exception {
  TimeoutException(this.message);

  final String message;

  @override
  String toString() => 'TimeoutException: $message';
}

/// Helper to create a test environment setup
class TestEnvironment {
  TestEnvironment({
    this.enableLogging = false,
    this.mockDateTime,
  });

  final bool enableLogging;
  final DateTime? mockDateTime;

  void setUp() {
    // Setup code that runs before each test
    if (enableLogging) {
      print('Test environment initialized');
    }
  }

  void tearDown() {
    // Cleanup code that runs after each test
    if (enableLogging) {
      print('Test environment cleaned up');
    }
  }
}
