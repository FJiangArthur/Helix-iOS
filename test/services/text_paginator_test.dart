import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/text_paginator.dart';

void main() {
  group('TextPaginator', () {
    late TextPaginator paginator;

    setUp(() {
      paginator = TextPaginator.instance;
      paginator.clear();
    });

    test('splits short text into single page', () {
      final text = 'Hello world';
      final pageCount = paginator.paginateText(text);

      expect(pageCount, 1);
      expect(paginator.currentPageText, 'Hello world');
      expect(paginator.currentPage, 0);
    });

    test('splits long text into multiple pages', () {
      // Create text longer than 40 characters
      final text =
          'This is a very long sentence that should be split into multiple pages';
      final pageCount = paginator.paginateText(text);

      expect(pageCount, greaterThan(1));
      expect(paginator.currentPage, 0);
    });

    test('navigates to next page', () {
      final text =
          'This is a very long sentence that should be split into multiple pages';
      paginator.paginateText(text);

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
      final text =
          'This is a very long sentence that should be split into multiple pages';
      paginator.paginateText(text);
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
      final text =
          'This is a very long sentence that should be split into multiple pages and even more text to create several pages';
      paginator.paginateText(text);

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

    test('respects max line length', () {
      final text =
          'This is a very long sentence that should be split into multiple pages';
      paginator.paginateText(text);

      // Check that each page is within max length
      for (int i = 0; i < paginator.pageCount; i++) {
        paginator.goToPage(i);
        expect(
          paginator.currentPageText.length,
          lessThanOrEqualTo(TextPaginator.maxLineLength),
        );
      }
    });

    test('clear resets state', () {
      final text =
          'This is a very long sentence that should be split into multiple pages';
      paginator.paginateText(text);
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
      final text =
          'This is a very long sentence that should be split into multiple pages';
      paginator.paginateText(text);

      expect(paginator.hasPreviousPage, false);
      expect(paginator.hasNextPage, paginator.pageCount > 1);

      if (paginator.pageCount > 1) {
        paginator.nextPage();
        expect(paginator.hasPreviousPage, true);
      }
    });
  });
}
