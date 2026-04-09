import 'dart:collection';

import 'package:flutter/painting.dart';

/// Manages text pagination for display on glasses
/// Uses TextPainter-based measurement matching Even Demo App protocol
class TextPaginator {
  TextPaginator._();

  static TextPaginator? _instance;
  static TextPaginator get instance => _instance ??= TextPaginator._();

  static const double maxLineWidth = 488.0;
  static const double fontSize = 21.0;
  static const int linesPerPage = 5;

  List<String> _pages = [];
  int _currentPage = 0;

  // H1: single reusable TextPainter for all measurements. We swap its
  // `text` property and call layout() instead of constructing a fresh
  // TextPainter + TextSpan per word test. Reduces allocation churn and
  // layout setup cost during streaming re-pagination.
  static final TextPainter _sharedPainter = TextPainter(
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  static const TextStyle _measureStyle = TextStyle(fontSize: fontSize);

  // H1: bounded LRU cache of measured widths. Streaming deltas re-measure
  // many of the same prefixes; caching short-circuits layout() entirely.
  static const int _measureCacheCapacity = 128;
  static final LinkedHashMap<String, double> _measureCache =
      LinkedHashMap<String, double>();

  // DEBUG-only counter for verifying the fix via tests/profiling.
  static int debugLayoutCallCount = 0;

  /// Get total number of pages
  int get pageCount => _pages.length;

  /// Get current page number (0-indexed)
  int get currentPage => _currentPage;

  /// Get current page text
  String get currentPageText {
    if (_pages.isEmpty || _currentPage >= _pages.length) {
      return '';
    }
    return _pages[_currentPage];
  }

  /// Check if there is a next page
  bool get hasNextPage => _currentPage < _pages.length - 1;

  /// Check if there is a previous page
  bool get hasPreviousPage => _currentPage > 0;

  /// Check if current page is the last page
  bool get isLastPage => _pages.isEmpty || _currentPage >= _pages.length - 1;

  /// Split text into pages for glasses display
  /// Returns the number of pages created
  int paginateText(String text) {
    _pages = _splitIntoPages(text);
    _currentPage = 0;
    return _pages.length;
  }

  /// Navigate to next page
  /// Returns true if navigation was successful
  bool nextPage() {
    if (hasNextPage) {
      _currentPage++;
      return true;
    }
    return false;
  }

  /// Navigate to previous page
  /// Returns true if navigation was successful
  bool previousPage() {
    if (hasPreviousPage) {
      _currentPage--;
      return true;
    }
    return false;
  }

  /// Go to specific page
  /// Returns true if the page number is valid
  bool goToPage(int pageNumber) {
    if (pageNumber >= 0 && pageNumber < _pages.length) {
      _currentPage = pageNumber;
      return true;
    }
    return false;
  }

  /// Clear all pages and reset state
  void clear() {
    _pages.clear();
    _currentPage = 0;
  }

  /// Measure text width using TextPainter (matches Even Demo App)
  double _measureTextWidth(String text) {
    // LRU cache hit: move to MRU and return.
    final cached = _measureCache.remove(text);
    if (cached != null) {
      _measureCache[text] = cached;
      return cached;
    }
    _sharedPainter.text = TextSpan(text: text, style: _measureStyle);
    _sharedPainter.layout();
    final width = _sharedPainter.width;
    debugLayoutCallCount++;

    // Insert and bound.
    _measureCache[text] = width;
    if (_measureCache.length > _measureCacheCapacity) {
      _measureCache.remove(_measureCache.keys.first);
    }
    return width;
  }

  /// Split text into lines based on pixel-accurate measurement
  List<String> splitIntoLines(String text) {
    if (text.isEmpty) return [];

    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else {
        final testLine = '$currentLine $word';
        if (_measureTextWidth(testLine) <= maxLineWidth) {
          currentLine = testLine;
        } else {
          lines.add(currentLine);
          currentLine = word;
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }

  /// Split text into pages using TextPainter measurement
  /// Groups every [linesPerPage] lines into a page
  List<String> _splitIntoPages(String text) {
    if (text.isEmpty) return [];

    final lines = splitIntoLines(text);
    final pages = <String>[];

    for (var i = 0; i < lines.length; i += linesPerPage) {
      final end = (i + linesPerPage > lines.length)
          ? lines.length
          : i + linesPerPage;
      final pageLines = lines.sublist(i, end);
      pages.add(pageLines.join('\n'));
    }

    return pages;
  }
}
