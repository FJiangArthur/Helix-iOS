/// Transcription Test Fixtures
///
/// Provides factory methods and fixtures for creating test transcription data

import 'package:flutter_helix/services/transcription/transcription_models.dart';

/// Factory for creating test transcription segments
class TranscriptionSegmentFactory {
  /// Create a basic transcription segment
  static TranscriptionSegment create({
    String? text,
    double? confidence,
    DateTime? timestamp,
    bool isFinal = true,
    String? language,
  }) {
    return TranscriptionSegment(
      text: text ?? 'Sample transcription text',
      confidence: confidence ?? 0.95,
      timestamp: timestamp ?? DateTime.now(),
      isFinal: isFinal,
      language: language ?? 'en-US',
    );
  }

  /// Create a list of transcription segments
  static List<TranscriptionSegment> createList({
    required int count,
    List<String>? texts,
    double baseConfidence = 0.95,
    Duration? spacing,
  }) {
    final List<TranscriptionSegment> segments = <TranscriptionSegment>[];
    DateTime baseTime = DateTime.now();

    for (int i = 0; i < count; i++) {
      if (spacing != null) {
        baseTime = baseTime.add(spacing);
      }

      segments.add(
        TranscriptionSegment(
          text: texts != null && i < texts.length ? texts[i] : 'Segment $i',
          confidence: baseConfidence - (i * 0.01), // Slightly decreasing confidence
          timestamp: baseTime,
          isFinal: true,
          language: 'en-US',
        ),
      );
    }

    return segments;
  }

  /// Create a low-confidence segment
  static TranscriptionSegment createLowConfidence({String? text}) {
    return create(
      text: text ?? 'Low confidence text',
      confidence: 0.45,
      isFinal: false,
    );
  }

  /// Create a high-confidence segment
  static TranscriptionSegment createHighConfidence({String? text}) {
    return create(
      text: text ?? 'High confidence text',
      confidence: 0.98,
      isFinal: true,
    );
  }

  /// Create an interim (non-final) segment
  static TranscriptionSegment createInterim({String? text}) {
    return create(
      text: text ?? 'Interim transcription',
      confidence: 0.75,
      isFinal: false,
    );
  }
}

/// Factory for creating test transcription statistics
class TranscriptionStatsFactory {
  /// Create basic transcription statistics
  static TranscriptionStats create({
    int segmentCount = 10,
    int totalCharacters = 500,
    TranscriptionMode? activeMode,
    double averageConfidence = 0.90,
    Duration? totalDuration,
  }) {
    return TranscriptionStats(
      segmentCount: segmentCount,
      totalCharacters: totalCharacters,
      activeMode: activeMode ?? TranscriptionMode.native,
      averageConfidence: averageConfidence,
      totalDuration: totalDuration ?? const Duration(seconds: 30),
    );
  }

  /// Create statistics for a long session
  static TranscriptionStats createLongSession() {
    return create(
      segmentCount: 1000,
      totalCharacters: 50000,
      averageConfidence: 0.88,
      totalDuration: const Duration(hours: 1),
    );
  }

  /// Create statistics for a short session
  static TranscriptionStats createShortSession() {
    return create(
      segmentCount: 5,
      totalCharacters: 50,
      averageConfidence: 0.92,
      totalDuration: const Duration(seconds: 5),
    );
  }

  /// Create empty statistics
  static TranscriptionStats createEmpty() {
    return create(
      segmentCount: 0,
      totalCharacters: 0,
      averageConfidence: 0.0,
      totalDuration: Duration.zero,
    );
  }
}

/// Common transcription test data
class TranscriptionTestData {
  // Sample texts for testing
  static const List<String> sampleTexts = <String>[
    'Hello, how are you today?',
    'The weather is beautiful outside.',
    'I am testing the transcription service.',
    'This is a sample conversation.',
    'Flutter is a great framework.',
  ];

  static const List<String> technicalTexts = <String>[
    'The API endpoint returned a 404 error.',
    'Database connection was successfully established.',
    'Implementing OAuth 2.0 authentication.',
    'The algorithm has O(n log n) complexity.',
  ];

  static const List<String> multilingualTexts = <String>[
    'Hello world',
    'Bonjour le monde',
    'Hola mundo',
    'Hallo Welt',
  ];

  // Confidence levels
  static const double highConfidence = 0.95;
  static const double mediumConfidence = 0.75;
  static const double lowConfidence = 0.50;
  static const double veryLowConfidence = 0.25;

  // Language codes
  static const String englishUS = 'en-US';
  static const String englishGB = 'en-GB';
  static const String french = 'fr-FR';
  static const String spanish = 'es-ES';
}
