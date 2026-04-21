import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/projects/project_context_formatter.dart';
import 'package:flutter_helix/services/projects/project_rag_service.dart';

void main() {
  test('prepends PROJECT CONTEXT block with numbered excerpts', () {
    const base = 'You are Helix, a helpful assistant.';
    final result = ProjectContextFormatter.prepend(base, [
      const RetrievedChunk(
        chunkId: 'c1',
        chunkText: 'Revenue was \$4.2M.',
        similarity: 0.9,
        documentId: 'd1',
        documentFilename: 'Q3.pdf',
        pageStart: 7,
        pageEnd: 7,
      ),
      const RetrievedChunk(
        chunkId: 'c2',
        chunkText: 'Margin improved.',
        similarity: 0.8,
        documentId: 'd2',
        documentFilename: 'exec-summary.txt',
      ),
    ]);
    expect(result, startsWith('PROJECT CONTEXT'));
    expect(result, contains('[1]'));
    expect(result, contains('Revenue was \$4.2M'));
    expect(result, contains('Q3.pdf p.7'));
    expect(result, contains('[2]'));
    expect(result, contains('exec-summary.txt'));
    expect(result, contains(base));
    // Instruction appears before the excerpts
    expect(result.indexOf('Prefer facts'), lessThan(result.indexOf('[1]')));
    // Base prompt appears after the excerpts block
    expect(result.indexOf(base), greaterThan(result.indexOf('[2]')));
  });

  test('returns base unchanged when chunks empty', () {
    const base = 'base';
    expect(ProjectContextFormatter.prepend(base, const []), base);
  });
}
