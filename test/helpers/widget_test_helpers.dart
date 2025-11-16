/// Widget Test Helpers
///
/// Utilities for testing Flutter widgets

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pump a widget with providers
Future<void> pumpWidgetWithProviders(
  WidgetTester tester,
  Widget widget, {
  List<Override>? overrides,
  NavigatorObserver? navigatorObserver,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? <Override>[],
      child: MaterialApp(
        navigatorObservers: navigatorObserver != null
            ? <NavigatorObserver>[navigatorObserver]
            : <NavigatorObserver>[],
        home: widget,
      ),
    ),
  );
}

/// Pump a widget with a custom theme
Future<void> pumpWidgetWithTheme(
  WidgetTester tester,
  Widget widget, {
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? ThemeData.light(),
      darkTheme: darkTheme ?? ThemeData.dark(),
      themeMode: themeMode,
      home: widget,
    ),
  );
}

/// Find a widget by its text content
Finder findByText(String text) => find.text(text);

/// Find a widget by its key
Finder findByKey(Key key) => find.byKey(key);

/// Find a widget by its type
Finder findByType<T>() => find.byType(T);

/// Tap a widget and settle
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Enter text into a text field
Future<void> enterTextAndSettle(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

/// Scroll until a widget is visible
Future<void> scrollUntilVisible(
  WidgetTester tester,
  Finder finder,
  Finder scrollable, {
  double delta = 100.0,
  int maxScrolls = 50,
}) async {
  int scrollCount = 0;

  while (scrollCount < maxScrolls) {
    if (tester.any(finder)) {
      break;
    }

    await tester.drag(scrollable, Offset(0.0, -delta));
    await tester.pump();
    scrollCount++;
  }

  if (scrollCount >= maxScrolls) {
    throw Exception('Widget not found after $maxScrolls scrolls');
  }
}

/// Verify a widget exists
void expectWidgetExists(Finder finder, {bool exists = true}) {
  if (exists) {
    expect(finder, findsOneWidget);
  } else {
    expect(finder, findsNothing);
  }
}

/// Verify multiple widgets exist
void expectWidgetsExist(Finder finder, {required int count}) {
  expect(finder, findsNWidgets(count));
}

/// Wait for a widget to appear
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);

  while (!tester.any(finder)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Widget not found within $timeout');
    }

    await tester.pump(interval);
  }
}

/// Wait for a widget to disappear
Future<void> waitForWidgetToDisappear(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 100),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);

  while (tester.any(finder)) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Widget still present after $timeout');
    }

    await tester.pump(interval);
  }
}

/// Get the text from a Text widget
String getTextFromWidget(WidgetTester tester, Finder finder) {
  final Text textWidget = tester.widget<Text>(finder);
  return textWidget.data ?? '';
}

/// Get the enabled state of a widget
bool isWidgetEnabled(WidgetTester tester, Finder finder) {
  final Widget widget = tester.widget(finder);
  if (widget is ElevatedButton) {
    return widget.onPressed != null;
  } else if (widget is TextButton) {
    return widget.onPressed != null;
  } else if (widget is IconButton) {
    return widget.onPressed != null;
  }
  return true;
}

/// Verify widget visibility
bool isWidgetVisible(WidgetTester tester, Finder finder) {
  if (!tester.any(finder)) {
    return false;
  }

  final RenderBox renderBox = tester.renderObject(finder);
  return renderBox.paintBounds.size.width > 0 &&
         renderBox.paintBounds.size.height > 0;
}

/// Create a mock navigator observer
class MockNavigatorObserver extends NavigatorObserver {
  MockNavigatorObserver() {
    routes = <Route<dynamic>>[];
  }

  late List<Route<dynamic>> routes;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    super.didPop(route, previousRoute);
  }
}

/// Timeout exception for widget tests
class TimeoutException implements Exception {
  TimeoutException(this.message);

  final String message;

  @override
  String toString() => 'TimeoutException: $message';
}
