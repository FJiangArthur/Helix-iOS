import 'dart:async';
import '../interfaces/i_glasses_display_service.dart';

/// Mock glasses display service for testing
/// Simulates HUD display without requiring physical glasses
class MockGlassesDisplayService implements IGlassesDisplayService {
  List<String> _pages = [];
  int _currentPage = 0;
  bool _isDisplaying = false;

  // Test observables
  final List<String> displayHistory = [];
  String? lastShownText;

  // Test configuration
  Duration displayDelay = const Duration(milliseconds: 50);

  @override
  int get currentPage => _currentPage;

  @override
  int get totalPages => _pages.length;

  @override
  bool get isDisplaying => _isDisplaying;

  /// Get current pages (test helper)
  List<String> get displayedPages => List.unmodifiable(_pages);

  @override
  Future<void> showText(String text) async {
    await Future.delayed(displayDelay);

    lastShownText = text;
    displayHistory.add(text);
    _pages = [text];
    _currentPage = 0;
    _isDisplaying = true;
  }

  @override
  Future<void> showPaginatedText(List<String> pages) async {
    await Future.delayed(displayDelay);

    _pages = List.from(pages);
    _currentPage = 0;
    _isDisplaying = pages.isNotEmpty;

    if (_pages.isNotEmpty) {
      lastShownText = _pages[0];
      displayHistory.add(_pages[0]);
    }
  }

  @override
  Future<void> nextPage() async {
    if (_currentPage < _pages.length - 1) {
      _currentPage++;
      await Future.delayed(displayDelay);

      lastShownText = _pages[_currentPage];
      displayHistory.add(_pages[_currentPage]);
    }
  }

  @override
  Future<void> previousPage() async {
    if (_currentPage > 0) {
      _currentPage--;
      await Future.delayed(displayDelay);

      lastShownText = _pages[_currentPage];
      displayHistory.add(_pages[_currentPage]);
    }
  }

  @override
  Future<void> clear() async {
    await Future.delayed(displayDelay);

    _pages = [];
    _currentPage = 0;
    _isDisplaying = false;
    lastShownText = null;
  }

  @override
  Future<void> updateCurrentPage(String text) async {
    await Future.delayed(displayDelay);

    if (_pages.isNotEmpty && _currentPage < _pages.length) {
      _pages[_currentPage] = text;
      lastShownText = text;
      displayHistory.add(text);
    }
  }

  @override
  void dispose() {
    _pages.clear();
    displayHistory.clear();
  }

  // Test helper methods

  /// Clear display history
  void clearHistory() {
    displayHistory.clear();
  }

  /// Get full display history as string
  String get historyString => displayHistory.join('\n');
}
