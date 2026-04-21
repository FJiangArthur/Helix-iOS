// ABOUTME: Recursive paragraph/sentence text splitter with configurable
// ABOUTME: target token size and overlap. Uses 4-chars-per-token approximation.

class ChunkOptions {
  const ChunkOptions({required this.targetTokens, required this.overlapTokens});
  final int targetTokens;
  final int overlapTokens;
}

class ChunkResult {
  const ChunkResult({
    required this.chunkIndex,
    required this.text,
    required this.tokenCount,
    this.pageStart,
    this.pageEnd,
  });
  final int chunkIndex;
  final String text;
  final int tokenCount;
  final int? pageStart;
  final int? pageEnd;
}

class DocumentChunker {
  /// Approximate OpenAI tiktoken count: 1 token ~= 4 chars.
  /// Always rounds up for a non-empty string so "a" counts as 1 token.
  static int approximateTokenCount(String s) {
    if (s.isEmpty) return 0;
    return ((s.length + 3) ~/ 4);
  }

  /// Split [text] into chunks. Preserves paragraphs (`\n\n`) as primary
  /// boundaries; falls back to sentence boundaries (`. ` / `! ` / `? `) when
  /// a paragraph exceeds the target size.
  static List<ChunkResult> chunk(String text, ChunkOptions opts) {
    if (text.trim().isEmpty) return [];
    final paragraphs = _splitParagraphs(text);

    // Expand paragraphs that exceed target into their sentences. If a
    // sentence still exceeds target, fall back to splitting by words.
    final units = <String>[];
    for (final p in paragraphs) {
      if (approximateTokenCount(p) <= opts.targetTokens) {
        units.add(p);
      } else {
        for (final sentence in _splitSentences(p)) {
          if (approximateTokenCount(sentence) <= opts.targetTokens) {
            units.add(sentence);
          } else {
            units.addAll(_splitWords(sentence, opts.targetTokens));
          }
        }
      }
    }

    // Greedy pack: append units into a chunk until adding the next would
    // exceed target. Then emit, carry last [overlapTokens] worth of words
    // forward into the next chunk.
    final out = <ChunkResult>[];
    final buffer = StringBuffer();
    int bufferTokens = 0;
    int idx = 0;

    void flush() {
      final trimmed = buffer.toString().trim();
      if (trimmed.isNotEmpty) {
        out.add(ChunkResult(
          chunkIndex: idx++,
          text: trimmed,
          tokenCount: approximateTokenCount(trimmed),
        ));
      }
      buffer.clear();
      bufferTokens = 0;
    }

    String overlapTail() {
      if (opts.overlapTokens <= 0) return '';
      final words = buffer.toString().trim().split(RegExp(r'\s+'));
      final tailWordCount = opts.overlapTokens; // tokens ~= words, good enough
      if (tailWordCount >= words.length) return buffer.toString().trim();
      return words.sublist(words.length - tailWordCount).join(' ');
    }

    for (final unit in units) {
      final unitTokens = approximateTokenCount(unit);
      if (bufferTokens == 0) {
        buffer.write(unit);
        bufferTokens = unitTokens;
        continue;
      }
      if (bufferTokens + unitTokens <= opts.targetTokens) {
        buffer.write('\n\n');
        buffer.write(unit);
        bufferTokens += unitTokens;
      } else {
        final tail = overlapTail();
        flush();
        if (tail.isNotEmpty) {
          buffer.write(tail);
          buffer.write(' ');
          bufferTokens += approximateTokenCount(tail);
        }
        buffer.write(unit);
        bufferTokens += unitTokens;
      }
    }
    flush();
    return out;
  }

  static List<String> _splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  static List<String> _splitSentences(String text) {
    // Split on sentence-terminating punctuation followed by whitespace.
    // Keep the terminator with the preceding sentence.
    final parts = <String>[];
    final pattern = RegExp(r'(?<=[.!?])\s+');
    for (final piece in text.split(pattern)) {
      final t = piece.trim();
      if (t.isNotEmpty) parts.add(t);
    }
    return parts;
  }

  /// Word-level fallback when a sentence still exceeds target tokens.
  /// Packs words into groups of ~[targetTokens] approximate tokens each.
  static List<String> _splitWords(String text, int targetTokens) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final groups = <String>[];
    final buffer = StringBuffer();
    int bufferTokens = 0;
    for (final word in words) {
      final wordTokens = approximateTokenCount(word);
      if (bufferTokens == 0) {
        buffer.write(word);
        bufferTokens = wordTokens;
      } else if (bufferTokens + wordTokens + 1 <= targetTokens) {
        buffer.write(' ');
        buffer.write(word);
        bufferTokens += wordTokens;
      } else {
        groups.add(buffer.toString());
        buffer.clear();
        buffer.write(word);
        bufferTokens = wordTokens;
      }
    }
    if (buffer.isNotEmpty) groups.add(buffer.toString());
    return groups;
  }
}
