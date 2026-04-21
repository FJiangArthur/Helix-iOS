import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/projects/document_chunker.dart';

void main() {
  group('DocumentChunker', () {
    const opts = ChunkOptions(targetTokens: 20, overlapTokens: 4);

    test('empty input produces no chunks', () {
      expect(DocumentChunker.chunk('', opts), isEmpty);
    });

    test('whitespace-only input produces no chunks', () {
      expect(DocumentChunker.chunk('   \n\n  ', opts), isEmpty);
    });

    test('short input fits in one chunk', () {
      final out = DocumentChunker.chunk('Hello world.', opts);
      expect(out, hasLength(1));
      expect(out.single.text, 'Hello world.');
      expect(out.single.chunkIndex, 0);
    });

    test('paragraph longer than target splits by sentence', () {
      final text =
          'Sentence one is here. Sentence two is also here. Sentence three closes.';
      final out = DocumentChunker.chunk(
          text, const ChunkOptions(targetTokens: 6, overlapTokens: 0));
      expect(out.length, greaterThan(1));
      final joined = out.map((c) => c.text).join(' ');
      expect(joined, contains('Sentence one'));
      expect(joined, contains('Sentence three closes'));
    });

    test('overlap copies trailing tokens from previous chunk', () {
      final text = List.generate(40, (i) => 'word$i').join(' ');
      final out = DocumentChunker.chunk(
          text, const ChunkOptions(targetTokens: 10, overlapTokens: 3));
      expect(out.length, greaterThan(1));
      // The last 3 space-separated tokens of chunk 0 should be the first 3
      // space-separated tokens of chunk 1.
      final firstWords = out[0].text.split(RegExp(r'\s+'));
      final secondWords = out[1].text.split(RegExp(r'\s+'));
      final tail = firstWords.sublist(firstWords.length - 3);
      final head = secondWords.sublist(0, 3);
      expect(head, tail);
    });

    test('multi-paragraph input preserves paragraph boundaries when possible',
        () {
      final text = 'Paragraph one line.\n\nParagraph two line.';
      final out = DocumentChunker.chunk(
          text, const ChunkOptions(targetTokens: 100, overlapTokens: 0));
      // Two paragraphs, each small, fit in one chunk (joined with blank line).
      expect(out, hasLength(1));
    });

    test('approximate token count uses 4-chars-per-token rule', () {
      expect(DocumentChunker.approximateTokenCount(''), 0);
      expect(DocumentChunker.approximateTokenCount('a'), 1);
      expect(DocumentChunker.approximateTokenCount('abcd'), 1);
      expect(DocumentChunker.approximateTokenCount('abcde'), 2);
      expect(DocumentChunker.approximateTokenCount('a' * 400), 100);
    });

    test('chunkIndex is monotonically increasing from zero', () {
      final text = List.generate(200, (i) => 'w$i').join(' ');
      final out = DocumentChunker.chunk(
          text, const ChunkOptions(targetTokens: 20, overlapTokens: 2));
      for (var i = 0; i < out.length; i++) {
        expect(out[i].chunkIndex, i);
      }
    });

    test('word-level fallback splits a giant sentence with no punctuation', () {
      // 200 words, no paragraph/sentence boundaries, target=8 tokens.
      // Paragraph splitter returns 1 unit; sentence splitter returns 1 unit.
      // Word-level fallback must kick in and produce multiple chunks.
      final text = List.generate(200, (i) => 'tok$i').join(' ');
      final out = DocumentChunker.chunk(
          text, const ChunkOptions(targetTokens: 8, overlapTokens: 0));
      expect(out.length, greaterThan(5));
      for (final c in out) {
        // Each chunk should have approximately target-sized token count
        // (some slop OK because the word-level greedy packer rounds).
        expect(c.tokenCount, lessThanOrEqualTo(20));
      }
    });

    test('word-level fallback emits a single over-target word as its own chunk',
        () {
      // A single 200-char word longer than target=5 tokens.
      final word = 'a' * 200;
      final out = DocumentChunker.chunk(
          word, const ChunkOptions(targetTokens: 5, overlapTokens: 0));
      // Should not infinite loop, should emit at least one chunk containing
      // the word.
      expect(out, isNotEmpty);
      expect(out.any((c) => c.text.contains(word)), isTrue);
    });
  });
}
