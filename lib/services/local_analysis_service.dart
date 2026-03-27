import 'package:flutter/services.dart';

/// A named entity extracted by NLTagger.
class NLEntity {
  final String name;

  /// One of: PersonalName, PlaceName, OrganizationName.
  final String type;
  final int start;
  final int length;

  const NLEntity({
    required this.name,
    required this.type,
    required this.start,
    required this.length,
  });

  @override
  String toString() => 'NLEntity($type: "$name" @$start+$length)';
}

/// Result of local NLTagger analysis.
class LocalAnalysisResult {
  final String language;
  final List<NLEntity> entities;
  final List<String> nouns;

  const LocalAnalysisResult({
    this.language = '',
    this.entities = const [],
    this.nouns = const [],
  });

  static const empty = LocalAnalysisResult();
}

/// On-device NLP via Apple NLTagger (NER, noun extraction, language detection).
///
/// Uses the `method.naturalLanguage` platform channel to invoke Swift-side
/// NLTagger analysis.
class LocalAnalysisService {
  static const _channel = MethodChannel('method.naturalLanguage');

  /// Analyze [text] for named entities, nouns, and dominant language.
  ///
  /// Returns [LocalAnalysisResult.empty] for blank input or on error.
  Future<LocalAnalysisResult> analyze(String text) async {
    if (text.trim().isEmpty) return LocalAnalysisResult.empty;

    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('analyzeText', {
        'text': text,
      });

      if (result == null) return LocalAnalysisResult.empty;

      final language = result['language'] as String? ?? '';
      final rawEntities = result['entities'] as List<dynamic>? ?? [];
      final rawNouns = result['nouns'] as List<dynamic>? ?? [];

      final entities = rawEntities.map((e) {
        final map = e as Map<Object?, Object?>;
        return NLEntity(
          name: map['name'] as String? ?? '',
          type: map['type'] as String? ?? '',
          start: map['start'] as int? ?? 0,
          length: map['length'] as int? ?? 0,
        );
      }).toList();

      final nouns = rawNouns.cast<String>().toList();

      return LocalAnalysisResult(
        language: language,
        entities: entities,
        nouns: nouns,
      );
    } on PlatformException {
      return LocalAnalysisResult.empty;
    }
  }
}
