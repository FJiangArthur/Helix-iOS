// ABOUTME: Main orchestrator for Buzz AI chat — ties together search, RAG
// ABOUTME: context assembly, and LLM streaming into a single ask() API.

import 'package:flutter_helix/models/buzz_citation.dart';
import 'package:flutter_helix/services/buzz/buzz_context_assembler.dart';
import 'package:flutter_helix/services/buzz/buzz_search_service.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/llm_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:flutter_helix/utils/app_logger.dart';

/// A single turn in a Buzz conversation.
class BuzzChatTurn {
  final String role; // 'user' or 'assistant'
  final String content;
  const BuzzChatTurn({required this.role, required this.content});
}

/// Events emitted during a Buzz query.
sealed class BuzzResponseEvent {
  const BuzzResponseEvent();

  const factory BuzzResponseEvent.searching() = BuzzSearching;
  const factory BuzzResponseEvent.textDelta(String text) = BuzzTextDelta;
  const factory BuzzResponseEvent.citationsAvailable(
      List<BuzzCitation> citations) = BuzzCitationsAvailable;
  const factory BuzzResponseEvent.complete() = BuzzComplete;
  const factory BuzzResponseEvent.error(String message) = BuzzError;
}

class BuzzSearching extends BuzzResponseEvent {
  const BuzzSearching();
}

class BuzzTextDelta extends BuzzResponseEvent {
  final String text;
  const BuzzTextDelta(this.text);
}

class BuzzCitationsAvailable extends BuzzResponseEvent {
  final List<BuzzCitation> citations;
  const BuzzCitationsAvailable(this.citations);
}

class BuzzComplete extends BuzzResponseEvent {
  const BuzzComplete();
}

class BuzzError extends BuzzResponseEvent {
  final String message;
  const BuzzError(this.message);
}

/// Orchestrates the Buzz AI chat pipeline: search -> assemble -> stream LLM.
class BuzzService {
  static BuzzService? _instance;
  static BuzzService get instance => _instance ??= BuzzService._();
  BuzzService._();

  final List<BuzzChatTurn> _history = [];
  List<BuzzChatTurn> get history => List.unmodifiable(_history);

  /// Ask a question and get a streaming answer with citations.
  Stream<BuzzResponseEvent> ask(String question) async* {
    appLogger.i(
      '[Buzz] Question received '
      '(chars=${question.length}, history=${_history.length})',
    );

    yield const BuzzResponseEvent.searching();

    // 1. Search for relevant content.
    final searchResults = await BuzzSearchService.instance.search(question);

    // 2. Assemble RAG context.
    final assembled = await BuzzContextAssembler.instance.assemble(
      question: question,
      searchResults: searchResults,
    );

    // 3. Build message list including recent chat history for follow-ups.
    // Keep only the last 6 turns to avoid blowing the context window.
    final recentHistory = _history.length > 6
        ? _history.sublist(_history.length - 6)
        : _history;

    final messages = [
      ...recentHistory
          .map((t) => ChatMessage(role: t.role, content: t.content)),
      ChatMessage(role: 'user', content: assembled.userMessage),
    ];

    // 4. Emit citations before streaming begins.
    yield BuzzResponseEvent.citationsAvailable(assembled.citations);

    // 5. Stream LLM response.
    final buffer = StringBuffer();
    try {
      await for (final chunk in LlmService.instance.streamResponse(
        systemPrompt: assembled.systemPrompt,
        messages: messages,
        temperature: 0.3,
        model: SettingsManager.instance.resolvedSmartModel,
      )) {
        buffer.write(chunk);
        yield BuzzResponseEvent.textDelta(chunk);
      }
    } catch (e, st) {
      appLogger.e('[Buzz] LLM stream error', error: e, stackTrace: st);
      yield BuzzResponseEvent.error('Failed to generate response: $e');
      return;
    }

    // 6. Add to history.
    _history.add(BuzzChatTurn(role: 'user', content: question));
    _history.add(BuzzChatTurn(role: 'assistant', content: buffer.toString()));

    appLogger.d('[Buzz] Response complete (${buffer.length} chars)');
    yield const BuzzResponseEvent.complete();
  }

  /// Clear chat history for a fresh session.
  void clearHistory() {
    _history.clear();
    appLogger.d('[Buzz] History cleared');
  }
}
