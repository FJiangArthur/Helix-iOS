import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/text_paginator.dart';

void main() {
  group('TextPaginator', () {
    late TextPaginator paginator;

    setUp(() {
      paginator = TextPaginator.instance;
      paginator.clear();
    });

    // Generate a long text string that will definitely span multiple pages
    // (needs > 5 lines at 488px width with 21pt font)
    final longText = List.generate(20, (i) => 'Word${i}longtext testing pagination across multiple lines').join(' ');

    test('splits short text into single page', () {
      final text = 'Hello world';
      final pageCount = paginator.paginateText(text);

      expect(pageCount, 1);
      expect(paginator.currentPageText, 'Hello world');
      expect(paginator.currentPage, 0);
    });

    test('splits long text into multiple pages', () {
      final pageCount = paginator.paginateText(longText);

      expect(pageCount, greaterThan(1));
      expect(paginator.currentPage, 0);
    });

    test('navigates to next page', () {
      paginator.paginateText(longText);

      final initialPage = paginator.currentPage;
      final success = paginator.nextPage();

      expect(success, true);
      expect(paginator.currentPage, initialPage + 1);
    });

    test('does not navigate beyond last page', () {
      final text = 'Short text';
      paginator.paginateText(text);

      final success = paginator.nextPage();
      expect(success, false);
      expect(paginator.currentPage, 0);
    });

    test('navigates to previous page', () {
      paginator.paginateText(longText);
      paginator.nextPage(); // Go to page 1

      final success = paginator.previousPage();
      expect(success, true);
      expect(paginator.currentPage, 0);
    });

    test('does not navigate before first page', () {
      final text = 'Hello world';
      paginator.paginateText(text);

      final success = paginator.previousPage();
      expect(success, false);
      expect(paginator.currentPage, 0);
    });

    test('goToPage sets current page correctly', () {
      paginator.paginateText(longText);

      final success = paginator.goToPage(1);
      expect(success, true);
      expect(paginator.currentPage, 1);
    });

    test('goToPage returns false for invalid page number', () {
      final text = 'Hello world';
      paginator.paginateText(text);

      expect(paginator.goToPage(-1), false);
      expect(paginator.goToPage(999), false);
    });

    test('respects lines per page limit', () {
      paginator.paginateText(longText);

      // Check that each page has at most linesPerPage lines
      for (int i = 0; i < paginator.pageCount; i++) {
        paginator.goToPage(i);
        final lineCount = paginator.currentPageText.split('\n').length;
        expect(
          lineCount,
          lessThanOrEqualTo(TextPaginator.linesPerPage),
        );
      }
    });

    test('clear resets state', () {
      paginator.paginateText(longText);
      paginator.nextPage();

      paginator.clear();

      expect(paginator.pageCount, 0);
      expect(paginator.currentPage, 0);
      expect(paginator.currentPageText, '');
    });

    test('handles empty text', () {
      final pageCount = paginator.paginateText('');

      expect(pageCount, 0);
      expect(paginator.currentPageText, '');
    });

    test('hasNextPage and hasPreviousPage work correctly', () {
      paginator.paginateText(longText);

      expect(paginator.hasPreviousPage, false);
      expect(paginator.hasNextPage, paginator.pageCount > 1);

      if (paginator.pageCount > 1) {
        paginator.nextPage();
        expect(paginator.hasPreviousPage, true);
      }
    });

    test('isLastPage returns correct value', () {
      paginator.paginateText(longText);
      expect(paginator.isLastPage, false);

      // Navigate to last page
      while (paginator.hasNextPage) {
        paginator.nextPage();
      }
      expect(paginator.isLastPage, true);
    });
  });
}
