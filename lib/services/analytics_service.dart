// ABOUTME: Analytics service for tracking all user interactions and feature usage
// ABOUTME: Provides detailed logging and metrics for debugging and monitoring

import 'dart:convert';
import 'package:flutter_helix/utils/app_logger.dart';

/// Event types for analytics tracking
enum AnalyticsEvent {
  // Recording events
  recordingStarted,
  recordingStopped,
  recordingError,

  // Transcription events
  transcriptionStarted,
  transcriptionCompleted,
  transcriptionError,
  transcriptionModeChanged,

  // AI analysis events
  aiAnalysisStarted,
  aiAnalysisCompleted,
  aiAnalysisError,
  factCheckPerformed,
  insightsGenerated,
  sentimentAnalyzed,

  // UI events
  screenViewed,
  personaSelected,
  featureToggled,
  settingsChanged,

  // Error events
  apiError,
  networkError,
  permissionDenied,

  // Performance events
  performanceMetric,
}

/// Analytics event data structure
class AnalyticsEventData {
  final AnalyticsEvent event;
  final DateTime timestamp;
  final Map<String, dynamic> properties;
  final String? userId;
  final String? sessionId;

  AnalyticsEventData({
    required this.event,
    required this.properties,
    this.userId,
    this.sessionId,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'event': event.name,
        'timestamp': timestamp.toIso8601String(),
        'properties': properties,
        if (userId != null) 'userId': userId,
        if (sessionId != null) 'sessionId': sessionId,
      };

  @override
  String toString() => jsonEncode(toJson());
}

/// Analytics service for tracking events and metrics
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;

  AnalyticsService._();

  final List<AnalyticsEventData> _eventLog = [];
  String? _sessionId;
  bool _isEnabled = true;

  /// Initialize analytics session
  void initialize({String? userId}) {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    appLogger.i('[Analytics] Session started: $_sessionId');

    track(AnalyticsEvent.screenViewed, properties: {
      'screen': 'app_launch',
      'session_id': _sessionId,
    });
  }

  /// Track an analytics event
  void track(
    AnalyticsEvent event, {
    Map<String, dynamic>? properties,
    String? userId,
  }) {
    if (!_isEnabled) return;

    final eventData = AnalyticsEventData(
      event: event,
      properties: properties ?? {},
      userId: userId,
      sessionId: _sessionId,
    );

    _eventLog.add(eventData);
    _printEvent(eventData);
  }

  /// Track recording started
  void trackRecordingStarted({String? recordingId}) {
    track(AnalyticsEvent.recordingStarted, properties: {
      'recording_id': recordingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track recording stopped
  void trackRecordingStopped({
    required String recordingId,
    required Duration duration,
    required String filePath,
    int? fileSize,
  }) {
    track(AnalyticsEvent.recordingStopped, properties: {
      'recording_id': recordingId,
      'duration_seconds': duration.inSeconds,
      'duration_ms': duration.inMilliseconds,
      'file_path': filePath,
      'file_size_bytes': fileSize,
    });
  }

  /// Track recording error
  void trackRecordingError({
    required String error,
    String? stackTrace,
  }) {
    track(AnalyticsEvent.recordingError, properties: {
      'error': error,
      'stack_trace': stackTrace,
    });
  }

  /// Track transcription started
  void trackTranscriptionStarted({
    required String recordingId,
    required String mode,
  }) {
    track(AnalyticsEvent.transcriptionStarted, properties: {
      'recording_id': recordingId,
      'mode': mode,
      'start_time': DateTime.now().toIso8601String(),
    });
  }

  /// Track transcription completed
  void trackTranscriptionCompleted({
    required String recordingId,
    required String mode,
    required Duration processingTime,
    required int textLength,
    String? text,
  }) {
    track(AnalyticsEvent.transcriptionCompleted, properties: {
      'recording_id': recordingId,
      'mode': mode,
      'processing_time_ms': processingTime.inMilliseconds,
      'text_length': textLength,
      'text_preview': text != null && text.length > 100
          ? '${text.substring(0, 100)}...'
          : text,
    });
  }

  /// Track transcription error
  void trackTranscriptionError({
    required String recordingId,
    required String mode,
    required String error,
  }) {
    track(AnalyticsEvent.transcriptionError, properties: {
      'recording_id': recordingId,
      'mode': mode,
      'error': error,
    });
  }

  /// Track AI analysis started
  void trackAIAnalysisStarted({
    required String sessionId,
    required String analysisType,
  }) {
    track(AnalyticsEvent.aiAnalysisStarted, properties: {
      'session_id': sessionId,
      'analysis_type': analysisType,
      'start_time': DateTime.now().toIso8601String(),
    });
  }

  /// Track AI analysis completed
  void trackAIAnalysisCompleted({
    required String sessionId,
    required String analysisType,
    required Duration processingTime,
    Map<String, dynamic>? results,
  }) {
    track(AnalyticsEvent.aiAnalysisCompleted, properties: {
      'session_id': sessionId,
      'analysis_type': analysisType,
      'processing_time_ms': processingTime.inMilliseconds,
      'results': results,
    });
  }

  /// Track AI analysis error
  void trackAIAnalysisError({
    required String sessionId,
    required String analysisType,
    required String error,
  }) {
    track(AnalyticsEvent.aiAnalysisError, properties: {
      'session_id': sessionId,
      'analysis_type': analysisType,
      'error': error,
    });
  }

  /// Track fact check performed
  void trackFactCheckPerformed({
    required int claimsChecked,
    required int verified,
    required int disputed,
    required int uncertain,
  }) {
    track(AnalyticsEvent.factCheckPerformed, properties: {
      'claims_checked': claimsChecked,
      'verified': verified,
      'disputed': disputed,
      'uncertain': uncertain,
    });
  }

  /// Track insights generated
  void trackInsightsGenerated({
    required bool hasSummary,
    required int keyPoints,
    required int actionItems,
    required bool hasSentiment,
  }) {
    track(AnalyticsEvent.insightsGenerated, properties: {
      'has_summary': hasSummary,
      'key_points_count': keyPoints,
      'action_items_count': actionItems,
      'has_sentiment': hasSentiment,
    });
  }

  /// Track screen view
  void trackScreenView(String screenName) {
    track(AnalyticsEvent.screenViewed, properties: {
      'screen_name': screenName,
    });
  }

  /// Track persona selection
  void trackPersonaSelected(String personaName) {
    track(AnalyticsEvent.personaSelected, properties: {
      'persona_name': personaName,
    });
  }

  /// Track API error
  void trackAPIError({
    required String api,
    required int statusCode,
    required String error,
  }) {
    track(AnalyticsEvent.apiError, properties: {
      'api': api,
      'status_code': statusCode,
      'error': error,
    });
  }

  /// Track performance metric
  void trackPerformance({
    required String metric,
    required double value,
    String? unit,
  }) {
    track(AnalyticsEvent.performanceMetric, properties: {
      'metric': metric,
      'value': value,
      'unit': unit ?? 'ms',
    });
  }

  /// Get all events
  List<AnalyticsEventData> getEvents() => List.unmodifiable(_eventLog);

  /// Get events by type
  List<AnalyticsEventData> getEventsByType(AnalyticsEvent event) {
    return _eventLog.where((e) => e.event == event).toList();
  }

  /// Get event summary
  Map<String, dynamic> getSummary() {
    final eventCounts = <String, int>{};
    for (final event in _eventLog) {
      eventCounts[event.event.name] = (eventCounts[event.event.name] ?? 0) + 1;
    }

    return {
      'session_id': _sessionId,
      'total_events': _eventLog.length,
      'event_counts': eventCounts,
      'session_duration_minutes': _sessionId != null
          ? (DateTime.now().millisecondsSinceEpoch -
             int.parse(_sessionId!)) / 1000 / 60
          : 0,
    };
  }

  /// Export events as JSON
  String exportEventsJSON() {
    return jsonEncode({
      'session_id': _sessionId,
      'export_time': DateTime.now().toIso8601String(),
      'events': _eventLog.map((e) => e.toJson()).toList(),
      'summary': getSummary(),
    });
  }

  /// Clear all events
  void clearEvents() {
    _eventLog.clear();
    appLogger.i('[Analytics] Event log cleared');
  }

  /// Enable/disable analytics
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    appLogger.i('[Analytics] Analytics ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Print event to console
  void _printEvent(AnalyticsEventData event) {
    final props = event.properties.entries
        .map((e) => '${e.key}=${e.value}')
        .join(', ');
    appLogger.i('[Analytics] ${event.event.name}${props.isNotEmpty ? ' | $props' : ''}');
  }
}
