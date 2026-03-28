// ABOUTME: Builds RAG prompts for Buzz AI by combining search results,
// ABOUTME: confirmed facts, and the user question into a structured LLM prompt.

import 'package:uuid/uuid.dart';

import 'package:flutter_helix/models/buzz_citation.dart';
import 'package:flutter_helix/services/buzz/buzz_search_service.dart';
import 'package:flutter_helix/services/database/helix_database.dart';
import 'package:flutter_helix/utils/app_logger.dart';

const _uuid = Uuid();

/// Assembles a RAG prompt with search results and known facts for the LLM.
class BuzzContextAssembler {
  static BuzzContextAssembler? _instance;
  static BuzzContextAssembler get instance =>
      _instance ??= BuzzContextAssembler._();
  BuzzContextAssembler._();

  /// Assemble a RAG prompt from search results and the user's question.
  ///
  /// Returns the system prompt, the formatted user message, and a list of
  /// [BuzzCitation] objects that can be displayed alongside the answer.
  Future<({String systemPrompt, String userMessage, List<BuzzCitation> citations})>
      assemble({
    required String question,
    required List<BuzzSearchResult> searchResults,
    int maxTokenBudget = 8000,
  }) async {
    final citations = <BuzzCitation>[];

    // ----- Known facts -----
    final confirmedFacts = await HelixDatabase.instance.factsDao
        .getConfirmedFacts(limit: 20);

    final factsBlock = StringBuffer();
    for (var i = 0; i < confirmedFacts.length; i++) {
      final f = confirmedFacts[i];
      factsBlock.writeln('[Fact #${i + 1}] (${f.category}) ${f.content}');

      citations.add(BuzzCitation(
        id: _uuid.v4(),
        sourceType: 'fact',
        sourceId: f.id,
        excerpt: f.content,
        label: 'Fact: ${f.category}',
        timestamp: DateTime.fromMillisecondsSinceEpoch(f.createdAt),
      ));
    }

    // ----- Conversation excerpts -----
    final excerptBlock = StringBuffer();
    var convIndex = 0;

    // Rough token budget tracking: ~4 chars per token.
    var estimatedTokens = factsBlock.length ~/ 4;

    for (final r in searchResults) {
      if (r.sourceType != 'segment') continue;

      final textToInclude = r.context ?? r.matchedText;
      final chunkTokens = textToInclude.length ~/ 4;
      if (estimatedTokens + chunkTokens > maxTokenBudget) break;

      convIndex++;
      final tsLabel = r.timestamp != null
          ? _formatTimestamp(r.timestamp!)
          : 'unknown date';

      excerptBlock.writeln('[Conv #$convIndex] ($tsLabel)');
      excerptBlock.writeln(textToInclude);
      excerptBlock.writeln();

      citations.add(BuzzCitation(
        id: _uuid.v4(),
        sourceType: 'conversation',
        sourceId: r.conversationId ?? r.sourceId,
        excerpt: r.matchedText,
        label: tsLabel,
        timestamp: r.timestamp,
      ));

      estimatedTokens += chunkTokens;
    }

    // ----- System prompt -----
    const systemPrompt = '''
You are Buzz, a personal memory assistant. You help the user recall and understand their past conversations and known facts.

Rules:
- Answer using ONLY the provided conversation excerpts and known facts below. Do not invent information.
- When referencing a conversation, cite it as [Conv #N]. When referencing a fact, cite it as [Fact #N].
- If the answer is not contained in the provided context, say "I don't have enough information from your conversations to answer that."
- Be conversational but precise. Keep answers concise unless the user asks for detail.
- When summarizing multiple conversations, organize by topic or chronology.''';

    // ----- User message -----
    final userMessage = StringBuffer();

    if (factsBlock.isNotEmpty) {
      userMessage.writeln('[KNOWN FACTS]');
      userMessage.writeln(factsBlock);
    }

    if (excerptBlock.isNotEmpty) {
      userMessage.writeln('[CONVERSATION EXCERPTS]');
      userMessage.writeln(excerptBlock);
    }

    userMessage.writeln('[QUESTION]');
    userMessage.writeln(question);

    appLogger.d(
      '[BuzzContext] Assembled ${confirmedFacts.length} facts, '
      '$convIndex excerpts for question',
    );

    return (
      systemPrompt: systemPrompt,
      userMessage: userMessage.toString(),
      citations: citations,
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Format a DateTime as "Mar 15, 2:34 PM" without the intl package.
  static String _formatTimestamp(DateTime dt) {
    final month = _months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month ${dt.day}, $hour:$minute $amPm';
  }
}
