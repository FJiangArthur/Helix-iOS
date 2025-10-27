/// Manages text pagination for display on glasses
class TextPaginator {
  TextPaginator._();

  static TextPaginator? _instance;
  static TextPaginator get instance => _instance ??= TextPaginator._();

  static const int maxLineLength = 40; // G1 glasses max characters per line

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

  /// Split text into manageable chunks for glasses display
  List<String> _splitIntoPages(String text) {
    if (text.isEmpty) {
      return [];
    }

    final words = text.split(' ');
    final pages = <String>[];
    var currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ((currentLine + ' ' + word).length <= maxLineLength) {
        currentLine += ' ' + word;
      } else {
        pages.add(currentLine);
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      pages.add(currentLine);
    }

    return pages;
  }
}
