import 'dart:async';
import '../interfaces/i_glasses_display_service.dart';
import '../proto.dart';

/// Production implementation of IGlassesDisplayService using Proto
/// Wraps the existing Proto service for G1 glasses HUD display
class GlassesDisplayServiceImpl implements IGlassesDisplayService {
  List<String> _pages = [];
  int _currentPage = 0;
  bool _isDisplaying = false;

  @override
  int get currentPage => _currentPage;

  @override
  int get totalPages => _pages.length;

  @override
  bool get isDisplaying => _isDisplaying;

  @override
  Future<void> showText(String text) async {
    _pages = [text];
    _currentPage = 0;
    _isDisplaying = text.isNotEmpty;

    await _sendCurrentPage(isNewScreen: true);
  }

  @override
  Future<void> showPaginatedText(List<String> pages) async {
    _pages = List.from(pages);
    _currentPage = 0;
    _isDisplaying = pages.isNotEmpty;

    if (_pages.isNotEmpty) {
      await _sendCurrentPage(isNewScreen: true);
    }
  }

  @override
  Future<void> nextPage() async {
    if (_currentPage < _pages.length - 1) {
      _currentPage++;
      await _sendCurrentPage(isNewScreen: false);
    }
  }

  @override
  Future<void> previousPage() async {
    if (_currentPage > 0) {
      _currentPage--;
      await _sendCurrentPage(isNewScreen: false);
    }
  }

  @override
  Future<void> clear() async {
    _pages = [];
    _currentPage = 0;
    _isDisplaying = false;

    // Send empty text to clear display
    await Proto.sendEvenAIData(
      '',
      newScreen: 1,
      pos: 0,
      current_page_num: 0,
      max_page_num: 0,
    );

    // Exit EvenAI screen
    await Proto.pushScreen(0x00);
  }

  @override
  Future<void> updateCurrentPage(String text) async {
    if (_pages.isEmpty) {
      _pages = [text];
      _currentPage = 0;
    } else if (_currentPage < _pages.length) {
      _pages[_currentPage] = text;
    }

    await _sendCurrentPage(isNewScreen: false);
  }

  @override
  void dispose() {
    _pages.clear();
  }

  /// Send current page to glasses using Proto.sendEvenAIData
  Future<void> _sendCurrentPage({required bool isNewScreen}) async {
    if (_pages.isEmpty || _currentPage >= _pages.length) {
      return;
    }

    final text = _pages[_currentPage];
    final newScreen = isNewScreen ? 1 : 0;

    try {
      await Proto.sendEvenAIData(
        text,
        newScreen: newScreen,
        pos: 0, // Position (0 for text display)
        current_page_num: _currentPage + 1, // 1-indexed for display
        max_page_num: _pages.length,
        timeoutMs: 2000,
      );
    } catch (e) {
      print('Error sending page to glasses: $e');
    }
  }
}
