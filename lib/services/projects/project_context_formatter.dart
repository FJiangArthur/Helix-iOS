// ABOUTME: Formats retrieved chunks as a PROJECT CONTEXT preamble for the system prompt.

import 'project_rag_service.dart';

class ProjectContextFormatter {
  /// Prepends a numbered PROJECT CONTEXT block to [baseSystemPrompt].
  /// Returns [baseSystemPrompt] unchanged when [chunks] is empty.
  static String prepend(String baseSystemPrompt, List<RetrievedChunk> chunks) {
    if (chunks.isEmpty) return baseSystemPrompt;
    final b = StringBuffer();
    b.writeln('PROJECT CONTEXT');
    b.writeln(
        'The following excerpts are from the user\'s project documents. '
        'Prefer facts from these excerpts over your general knowledge. '
        'Cite with [N] markers matching the numbered excerpts below. '
        'If the excerpts do not contain the answer, answer from general '
        'knowledge without citations.');
    b.writeln();
    for (var i = 0; i < chunks.length; i++) {
      final c = chunks[i];
      final source = _sourceLabel(c);
      b.writeln('[${i + 1}] $source');
      b.writeln(c.chunkText);
      b.writeln();
    }
    b.writeln('---');
    b.writeln();
    b.write(baseSystemPrompt);
    return b.toString();
  }

  static String _sourceLabel(RetrievedChunk c) {
    if (c.pageStart != null && c.pageEnd != null) {
      if (c.pageStart == c.pageEnd) {
        return '${c.documentFilename} p.${c.pageStart}';
      }
      return '${c.documentFilename} p.${c.pageStart}-${c.pageEnd}';
    }
    return c.documentFilename;
  }
}
