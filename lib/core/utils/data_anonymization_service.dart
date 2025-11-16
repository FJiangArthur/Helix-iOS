// ABOUTME: Data anonymization service
// ABOUTME: Provides utilities for anonymizing user data for privacy compliance

import 'dart:math';
import 'package:helix/models/conversation_model.dart';
import 'package:helix/models/transcription_segment.dart';
import 'package:helix/models/analysis_result.dart';
import 'package:helix/services/analytics_service.dart';
import 'package:helix/core/config/privacy_config.dart';
import 'package:helix/core/utils/logging_service.dart';

/// Service for anonymizing user data
class DataAnonymizationService {
  static final DataAnonymizationService _instance = DataAnonymizationService._();
  static DataAnonymizationService get instance => _instance;

  DataAnonymizationService._();

  final _logger = LoggingService.instance;
  final _random = Random.secure();
  final Map<String, String> _idMap = {}; // Maps real IDs to anonymized IDs

  /// Generate a random anonymized ID
  String _generateAnonymousId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(12, (index) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Get or create an anonymized ID for a given real ID
  String _getAnonymizedId(String? realId, String prefix) {
    if (realId == null || realId.isEmpty) {
      return '${prefix}_UNKNOWN';
    }

    if (!_idMap.containsKey(realId)) {
      _idMap[realId] = '${prefix}_${_generateAnonymousId()}';
    }

    return _idMap[realId]!;
  }

  /// Clear the ID mapping cache
  void clearIdMapping() {
    _idMap.clear();
    _logger.info('DataAnonymization', 'ID mapping cleared');
  }

  /// Anonymize a conversation
  Conversation anonymizeConversation(
    Conversation conversation,
    PrivacyConfig config,
  ) {
    return Conversation(
      id: config.removeSpeakerIds ? _getAnonymizedId(conversation.id, 'CONV') : conversation.id,
      startTime: _anonymizeTimestamp(conversation.startTime),
      endTime: conversation.endTime != null ? _anonymizeTimestamp(conversation.endTime!) : null,
      messages: conversation.messages
          .map((msg) => anonymizeConversationMessage(msg, config))
          .toList(),
      metadata: _anonymizeMetadata(conversation.metadata),
    );
  }

  /// Anonymize a conversation message
  ConversationMessage anonymizeConversationMessage(
    ConversationMessage message,
    PrivacyConfig config,
  ) {
    return ConversationMessage(
      id: _getAnonymizedId(message.id, 'MSG'),
      content: config.removeSpeakerIds
          ? _removePersonalInfo(message.content)
          : message.content,
      timestamp: _anonymizeTimestamp(message.timestamp),
      speakerId: config.removeSpeakerIds
          ? _getAnonymizedId(message.speakerId, 'SPEAKER')
          : message.speakerId,
      type: message.type,
    );
  }

  /// Anonymize a transcription segment
  TranscriptionSegment anonymizeTranscriptionSegment(
    TranscriptionSegment segment,
    PrivacyConfig config,
  ) {
    return TranscriptionSegment(
      id: _getAnonymizedId(segment.id, 'SEG'),
      text: config.removeSpeakerIds
          ? _removePersonalInfo(segment.text)
          : segment.text,
      startTimeMs: segment.startTimeMs,
      endTimeMs: segment.endTimeMs,
      confidence: segment.confidence,
      speakerId: config.removeSpeakerIds
          ? _getAnonymizedId(segment.speakerId, 'SPEAKER')
          : segment.speakerId,
      isFinal: segment.isFinal,
    );
  }

  /// Anonymize a transcription result
  TranscriptionResult anonymizeTranscriptionResult(
    TranscriptionResult result,
    PrivacyConfig config,
  ) {
    return TranscriptionResult(
      id: _getAnonymizedId(result.id, 'TRANS'),
      text: config.removeSpeakerIds
          ? _removePersonalInfo(result.text)
          : result.text,
      segments: result.segments
          .map((seg) => anonymizeTranscriptionSegment(seg, config))
          .toList(),
      confidence: result.confidence,
      timestamp: _anonymizeTimestamp(result.timestamp),
      language: result.language,
    );
  }

  /// Anonymize an analysis result
  AnalysisResult anonymizeAnalysisResult(
    AnalysisResult result,
    PrivacyConfig config,
  ) {
    return AnalysisResult(
      id: _getAnonymizedId(result.id, 'ANALYSIS'),
      type: result.type,
      timestamp: _anonymizeTimestamp(result.timestamp),
      conversationId: config.removeSpeakerIds
          ? _getAnonymizedId(result.conversationId, 'CONV')
          : result.conversationId,
      status: result.status,
      startTime: _anonymizeTimestamp(result.startTime),
      completionTime: result.completionTime != null
          ? _anonymizeTimestamp(result.completionTime!)
          : null,
      summary: result.summary,
      actionItems: result.actionItems
          .map((item) => config.removeSpeakerIds
              ? _removePersonalInfo(item)
              : item)
          .toList(),
      factChecks: result.factChecks
          .map((fc) => anonymizeFactCheckResult(fc, config))
          .toList(),
      sentiment: result.sentiment,
      confidence: result.confidence,
      error: result.error,
    );
  }

  /// Anonymize a fact check result
  FactCheckResult anonymizeFactCheckResult(
    FactCheckResult result,
    PrivacyConfig config,
  ) {
    return FactCheckResult(
      id: _getAnonymizedId(result.id, 'FACT'),
      claim: config.removeSpeakerIds
          ? _removePersonalInfo(result.claim)
          : result.claim,
      status: result.status,
      confidence: result.confidence,
      sources: result.sources, // URLs are generally okay
      explanation: result.explanation != null && config.removeSpeakerIds
          ? _removePersonalInfo(result.explanation!)
          : result.explanation,
      context: result.context != null && config.removeSpeakerIds
          ? _removePersonalInfo(result.context!)
          : result.context,
    );
  }

  /// Anonymize analytics event data
  AnalyticsEventData anonymizeAnalyticsEvent(
    AnalyticsEventData event,
    PrivacyConfig config,
  ) {
    final anonymizedProperties = <String, dynamic>{};

    // Anonymize properties
    event.properties.forEach((key, value) {
      if (_isSensitiveProperty(key)) {
        if (value is String) {
          anonymizedProperties[key] = _anonymizeValue(value);
        } else {
          anonymizedProperties[key] = '[REDACTED]';
        }
      } else {
        anonymizedProperties[key] = value;
      }
    });

    return AnalyticsEventData(
      event: event.event,
      properties: anonymizedProperties,
      userId: config.removeSpeakerIds
          ? _getAnonymizedId(event.userId, 'USER')
          : event.userId,
      sessionId: config.removeSpeakerIds
          ? _getAnonymizedId(event.sessionId, 'SESSION')
          : event.sessionId,
    );
  }

  /// Anonymize a list of analytics events
  List<AnalyticsEventData> anonymizeAnalyticsEvents(
    List<AnalyticsEventData> events,
    PrivacyConfig config,
  ) {
    return events.map((event) => anonymizeAnalyticsEvent(event, config)).toList();
  }

  /// Anonymize timestamp (round to nearest hour)
  DateTime _anonymizeTimestamp(DateTime timestamp) {
    return DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
      timestamp.hour,
      0, // Zero out minutes
      0, // Zero out seconds
      0, // Zero out milliseconds
    );
  }

  /// Anonymize metadata
  Map<String, dynamic>? _anonymizeMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;

    final anonymized = <String, dynamic>{};
    metadata.forEach((key, value) {
      if (_isSensitiveProperty(key)) {
        anonymized[key] = '[REDACTED]';
      } else if (value is String) {
        anonymized[key] = _anonymizeValue(value);
      } else {
        anonymized[key] = value;
      }
    });

    return anonymized;
  }

  /// Remove personal information from text
  String _removePersonalInfo(String text) {
    String result = text;

    // Remove email addresses
    result = result.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
      '[EMAIL]',
    );

    // Remove phone numbers (various formats)
    result = result.replaceAll(
      RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'),
      '[PHONE]',
    );

    // Remove credit card numbers
    result = result.replaceAll(
      RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'),
      '[CARD]',
    );

    // Remove social security numbers (US format)
    result = result.replaceAll(
      RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
      '[SSN]',
    );

    // Remove IP addresses
    result = result.replaceAll(
      RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'),
      '[IP]',
    );

    // Remove common name patterns (Mr., Mrs., Ms., Dr. followed by capital letters)
    result = result.replaceAll(
      RegExp(r'\b(Mr\.|Mrs\.|Ms\.|Dr\.)\s+[A-Z][a-z]+\b'),
      '[NAME]',
    );

    return result;
  }

  /// Check if a property key is sensitive
  bool _isSensitiveProperty(String key) {
    const sensitiveKeys = [
      'userId',
      'user_id',
      'speakerId',
      'speaker_id',
      'email',
      'phone',
      'address',
      'name',
      'firstName',
      'first_name',
      'lastName',
      'last_name',
      'ssn',
      'creditCard',
      'credit_card',
      'password',
      'token',
      'api_key',
      'apiKey',
      'secret',
      'file_path',
      'filePath',
    ];

    return sensitiveKeys.any((sensitive) =>
        key.toLowerCase().contains(sensitive.toLowerCase()));
  }

  /// Anonymize a value based on its type
  String _anonymizeValue(String value) {
    // Check if it's a file path
    if (value.contains('/') || value.contains('\\')) {
      return '[PATH]';
    }

    // Check if it's a URL
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return '[URL]';
    }

    // Check if it looks like an ID (alphanumeric with hyphens)
    if (RegExp(r'^[a-zA-Z0-9-_]+$').hasMatch(value) && value.length > 10) {
      return '[ID]';
    }

    // Default: redact
    return '[REDACTED]';
  }

  /// Export anonymized analytics data
  Map<String, dynamic> exportAnonymizedAnalytics(
    List<AnalyticsEventData> events,
    PrivacyConfig config,
  ) {
    final anonymizedEvents = anonymizeAnalyticsEvents(events, config);

    // Aggregate statistics
    final eventCounts = <String, int>{};
    for (final event in anonymizedEvents) {
      eventCounts[event.event.name] = (eventCounts[event.event.name] ?? 0) + 1;
    }

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'totalEvents': anonymizedEvents.length,
      'eventCounts': eventCounts,
      'events': anonymizedEvents.map((e) => e.toJson()).toList(),
      'anonymized': true,
      'privacyConfig': {
        'removeSpeakerIds': config.removeSpeakerIds,
        'anonymizeAnalytics': config.anonymizeAnalytics,
      },
    };
  }

  /// Create a pseudonymized speaker map
  Map<String, String> createSpeakerMap(List<String?> speakerIds) {
    final map = <String, String>{};
    final uniqueSpeakers = speakerIds.whereType<String>().toSet();

    int index = 0;
    for (final speakerId in uniqueSpeakers) {
      map[speakerId] = 'Speaker ${String.fromCharCode(65 + index)}'; // A, B, C, etc.
      index++;
    }

    return map;
  }

  /// Get anonymization statistics
  Map<String, dynamic> getAnonymizationStats() {
    return {
      'totalMappedIds': _idMap.length,
      'idTypes': _getIdTypeBreakdown(),
    };
  }

  /// Get breakdown of ID types in the mapping
  Map<String, int> _getIdTypeBreakdown() {
    final breakdown = <String, int>{};

    for (final anonymizedId in _idMap.values) {
      final prefix = anonymizedId.split('_').first;
      breakdown[prefix] = (breakdown[prefix] ?? 0) + 1;
    }

    return breakdown;
  }

  /// Log anonymization activity
  void logAnonymization(String operation, int itemsProcessed) {
    _logger.info(
      'DataAnonymization',
      '$operation: Anonymized $itemsProcessed items',
      getAnonymizationStats(),
    );
  }
}
