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
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    return textPainter.width;
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
