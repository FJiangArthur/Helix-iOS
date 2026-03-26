import 'dart:async';

import '../utils/app_logger.dart';
import 'llm/llm_service.dart';
import 'llm/llm_provider.dart';

/// Singleton service that translates text using the active LLM provider.
///
/// Designed for live translation of finalized transcript segments.
/// Skips translation when the text already appears to be in the target language.
class TranslationService {
  TranslationService._();

  static TranslationService? _instance;
  static TranslationService get instance => _instance ??= TranslationService._();

  static const Map<String, String> languageNames = {
    'en': 'English',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
  };

  /// Translate [text] to the given [targetLang] ISO code.
  ///
  /// Returns a stream of incremental translation chunks (streamed from the LLM).
  /// Returns an empty stream if the text appears to already be in the target language.
  Stream<String> translate(String text, String targetLang) {
    if (text.trim().isEmpty) return const Stream.empty();

    if (_appearsToBeTargetLanguage(text, targetLang)) {
      appLogger.d('[TranslationService] Text appears to be in target language ($targetLang), skipping');
      return const Stream.empty();
    }

    final langName = languageNames[targetLang] ?? targetLang;
    final systemPrompt =
        'Translate the following text to $langName. Output only the translation, nothing else.';

    final messages = [
      ChatMessage(role: 'user', content: text),
    ];

    try {
      final llm = LlmService.instance;
      return llm.streamResponse(
        systemPrompt: systemPrompt,
        messages: messages,
        temperature: 0.3,
      ).handleError((Object e) {
        // Log and re-throw so the caller's onError handler also fires.
        appLogger.e('[TranslationService] Stream error: $e');
        // ignore: only_throw_errors
        throw e;
      });
    } on StateError catch (e) {
      // Expected: no LLM provider configured.
      appLogger.w('[TranslationService] LLM not configured: ${e.message}');
      return const Stream.empty();
    } catch (e) {
      appLogger.e('[TranslationService] Failed to start translation: $e');
      return Stream.value('[Translation unavailable]');
    }
  }

  /// Simple language detection heuristic.
  ///
  /// - If target is 'en' and >50% ASCII letters: likely already English, skip.
  /// - If target is 'zh'/'ja'/'ko' and >30% CJK characters: likely already CJK, skip.
  /// - Otherwise: translate.
  bool _appearsToBeTargetLanguage(String text, String targetLang) {
    if (text.trim().isEmpty) return true;

    final chars = text.runes.toList();
    final total = chars.length;
    if (total == 0) return true;

    if (targetLang == 'en') {
      final asciiLetters = chars.where((c) =>
          (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)).length;
      return asciiLetters / total > 0.50;
    }

    if (targetLang == 'zh' || targetLang == 'ja' || targetLang == 'ko') {
      final cjkCount = chars.where((c) =>
          (c >= 0x4E00 && c <= 0x9FFF) ||   // CJK Unified
          (c >= 0x3040 && c <= 0x30FF) ||   // Hiragana + Katakana
          (c >= 0xAC00 && c <= 0xD7AF)      // Hangul Syllables
      ).length;
      return cjkCount / total > 0.30;
    }

    // For other target languages (es, fr, de), always translate.
    return false;
  }
}
