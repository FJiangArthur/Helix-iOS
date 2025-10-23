import 'dart:async';

/// Abstract interface for displaying content on G1 glasses HUD
abstract class IGlassesDisplayService {
  /// Current page index (for paginated content)
  int get currentPage;

  /// Total number of pages
  int get totalPages;

  /// Whether display is currently active
  bool get isDisplaying;

  /// Show simple text on glasses
  Future<void> showText(String text);

  /// Show paginated text (automatically split into pages)
  Future<void> showPaginatedText(List<String> pages);

  /// Navigate to next page
  Future<void> nextPage();

  /// Navigate to previous page
  Future<void> previousPage();

  /// Clear display
  Future<void> clear();

  /// Update currently displayed page without changing page number
  Future<void> updateCurrentPage(String text);

  /// Dispose resources
  void dispose();
}
