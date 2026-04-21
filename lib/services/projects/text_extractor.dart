// ABOUTME: Extracts text from supported document types (PDF, TXT) for Project RAG.

import 'dart:io';

import 'package:syncfusion_flutter_pdf/pdf.dart';

class ExtractedDocument {
  const ExtractedDocument({
    required this.text,
    required this.pageCount,
    required this.pageBoundaries,
  });

  /// Concatenated full text. Pages separated by `\n\n`.
  final String text;

  /// 1-based page count. 1 for TXT, actual page count for PDFs.
  final int pageCount;

  /// For each page index (0-based), the character offset within `text` where
  /// that page starts. Length == pageCount. Used to map chunk offsets back
  /// to page numbers.
  final List<int> pageBoundaries;
}

class TextExtractor {
  static Future<ExtractedDocument> extract(File file, String contentType) async {
    switch (contentType) {
      case 'txt':
        final text = await file.readAsString();
        return ExtractedDocument(
            text: text, pageCount: 1, pageBoundaries: const [0]);
      case 'pdf':
        return _extractPdf(file);
      default:
        throw ArgumentError('Unsupported content type: $contentType');
    }
  }

  static Future<ExtractedDocument> _extractPdf(File file) async {
    final bytes = await file.readAsBytes();
    final PdfDocument doc = PdfDocument(inputBytes: bytes);
    try {
      final buffer = StringBuffer();
      final boundaries = <int>[];
      final extractor = PdfTextExtractor(doc);
      for (var i = 0; i < doc.pages.count; i++) {
        boundaries.add(buffer.length);
        final pageText =
            extractor.extractText(startPageIndex: i, endPageIndex: i);
        buffer.write(pageText);
        buffer.write('\n\n');
      }
      return ExtractedDocument(
        text: buffer.toString(),
        pageCount: doc.pages.count,
        pageBoundaries: boundaries,
      );
    } finally {
      doc.dispose();
    }
  }
}
