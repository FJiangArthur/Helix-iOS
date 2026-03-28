import 'dart:async';

import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/entity_memory.dart';

/// Records events from all ConversationEngine streams for test assertions.
///
/// Usage:
/// ```dart
/// final recorder = StreamRecorder(engine);
/// // ... run test scenario ...
/// expect(recorder.transcriptSnapshots.length, greaterThan(0));
/// expect(recorder.aiResponses, isNotEmpty);
/// recorder.dispose();
/// ```
class StreamRecorder {
  StreamRecorder(ConversationEngine engine) : _startTime = DateTime.now() {
    _subscriptions.addAll([
      engine.transcriptionStream.listen((e) => _record('transcription', e)),
      engine.transcriptSnapshotStream
          .listen((e) => _record('transcriptSnapshot', e)),
      engine.aiResponseStream.listen((e) => _record('aiResponse', e)),
      engine.modeStream.listen((e) => _record('mode', e)),
      engine.questionDetectedStream
          .listen((e) => _record('questionDetected', e)),
      engine.questionDetectionStream
          .listen((e) => _record('questionDetection', e)),
      engine.statusStream.listen((e) => _record('status', e)),
      engine.proactiveSuggestionStream
          .listen((e) => _record('proactiveSuggestion', e)),
      engine.coachingStream.listen((e) => _record('coaching', e)),
      engine.followUpChipsStream.listen((e) => _record('followUpChips', e)),
      engine.providerErrorStream.listen((e) => _record('providerError', e)),
      engine.postConversationAnalysisStream
          .listen((e) => _record('postConversation', e)),
      engine.factCheckAlertStream.listen((e) => _record('factCheckAlert', e)),
      engine.translationStream.listen((e) => _record('translation', e)),
      engine.sentimentStream.listen((e) => _record('sentiment', e)),
      engine.entityStream.listen((e) => _record('entity', e)),
    ]);
  }

  final DateTime _startTime;
  final List<StreamSubscription> _subscriptions = [];
  final List<RecordedEvent> _events = [];

  void _record(String stream, dynamic event) {
    _events.add(RecordedEvent(
      stream: stream,
      event: event,
      elapsed: DateTime.now().difference(_startTime),
    ));
  }

  /// All recorded events in chronological order.
  List<RecordedEvent> get events => List.unmodifiable(_events);

  /// Events for a specific stream.
  List<RecordedEvent> eventsFor(String stream) =>
      _events.where((e) => e.stream == stream).toList();

  /// Count of events for a specific stream.
  int countFor(String stream) => eventsFor(stream).length;

  /// Typed accessors for common streams.
  List<TranscriptSnapshot> get transcriptSnapshots =>
      eventsFor('transcriptSnapshot').map((e) => e.event as TranscriptSnapshot).toList();

  List<String> get aiResponses =>
      eventsFor('aiResponse').map((e) => e.event as String).toList();

  List<EngineStatus> get statuses =>
      eventsFor('status').map((e) => e.event as EngineStatus).toList();

  List<QuestionDetectionResult> get questionDetections =>
      eventsFor('questionDetection')
          .map((e) => e.event as QuestionDetectionResult)
          .toList();

  List<double> get sentiments =>
      eventsFor('sentiment').map((e) => e.event as double).toList();

  List<EntityInfo> get entities =>
      eventsFor('entity').map((e) => e.event as EntityInfo).toList();

  List<List<String>> get followUpChips =>
      eventsFor('followUpChips').map((e) => e.event as List<String>).toList();

  List<CoachingPrompt> get coachingPrompts =>
      eventsFor('coaching').map((e) => e.event as CoachingPrompt).toList();

  /// First event time for a stream (relative to start).
  Duration? firstEventTime(String stream) {
    final list = eventsFor(stream);
    return list.isEmpty ? null : list.first.elapsed;
  }

  /// Reset all recorded events.
  void clear() => _events.clear();

  /// Cancel all subscriptions.
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}

class RecordedEvent {
  const RecordedEvent({
    required this.stream,
    required this.event,
    required this.elapsed,
  });

  final String stream;
  final dynamic event;
  final Duration elapsed;

  @override
  String toString() => '[$stream @ ${elapsed.inMilliseconds}ms] $event';
}
