/// Mock Builders for Testing
///
/// Provides builder pattern classes for creating mock objects with fluent API

import 'dart:async';
import 'package:flutter_helix/services/transcription/transcription_models.dart';

/// Builder for creating mock transcription service behavior
class MockTranscriptionServiceBuilder {
  MockTranscriptionServiceBuilder() {
    _isAvailable = true;
    _isTranscribing = false;
    _mode = TranscriptionMode.native;
    _transcriptController = StreamController<TranscriptionSegment>.broadcast();
    _errorController = StreamController<String>.broadcast();
  }

  late bool _isAvailable;
  late bool _isTranscribing;
  late TranscriptionMode _mode;
  late StreamController<TranscriptionSegment> _transcriptController;
  late StreamController<String> _errorController;
  List<TranscriptionSegment> _segments = <TranscriptionSegment>[];

  /// Set service availability
  MockTranscriptionServiceBuilder withAvailability(bool available) {
    _isAvailable = available;
    return this;
  }

  /// Set transcription state
  MockTranscriptionServiceBuilder withTranscribing(bool transcribing) {
    _isTranscribing = transcribing;
    return this;
  }

  /// Set transcription mode
  MockTranscriptionServiceBuilder withMode(TranscriptionMode mode) {
    _mode = mode;
    return this;
  }

  /// Add preset segments to emit
  MockTranscriptionServiceBuilder withSegments(List<TranscriptionSegment> segments) {
    _segments = segments;
    return this;
  }

  /// Emit a transcription segment
  void emitSegment(TranscriptionSegment segment) {
    _transcriptController.add(segment);
  }

  /// Emit an error
  void emitError(String error) {
    _errorController.add(error);
  }

  /// Get the transcript stream
  Stream<TranscriptionSegment> get transcriptStream => _transcriptController.stream;

  /// Get the error stream
  Stream<String> get errorStream => _errorController.stream;

  /// Dispose the mock
  void dispose() {
    _transcriptController.close();
    _errorController.close();
  }

  /// Simulate starting transcription
  Future<void> simulateStart() async {
    _isTranscribing = true;
    // Emit preset segments
    for (final TranscriptionSegment segment in _segments) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      emitSegment(segment);
    }
  }

  /// Simulate stopping transcription
  Future<void> simulateStop() async {
    _isTranscribing = false;
  }
}

/// Builder for creating mock AI coordinator behavior
class MockAICoordinatorBuilder {
  MockAICoordinatorBuilder() {
    _isEnabled = false;
    _factCheckEnabled = false;
    _sentimentEnabled = false;
    _claimDetectionEnabled = false;
    _responseDelay = const Duration(milliseconds: 100);
  }

  late bool _isEnabled;
  late bool _factCheckEnabled;
  late bool _sentimentEnabled;
  late bool _claimDetectionEnabled;
  late Duration _responseDelay;
  Map<String, dynamic>? _mockResponse;

  /// Enable the coordinator
  MockAICoordinatorBuilder enabled() {
    _isEnabled = true;
    return this;
  }

  /// Enable fact checking
  MockAICoordinatorBuilder withFactCheck() {
    _factCheckEnabled = true;
    return this;
  }

  /// Enable sentiment analysis
  MockAICoordinatorBuilder withSentiment() {
    _sentimentEnabled = true;
    return this;
  }

  /// Enable claim detection
  MockAICoordinatorBuilder withClaimDetection() {
    _claimDetectionEnabled = true;
    return this;
  }

  /// Set response delay
  MockAICoordinatorBuilder withDelay(Duration delay) {
    _responseDelay = delay;
    return this;
  }

  /// Set mock response
  MockAICoordinatorBuilder withResponse(Map<String, dynamic> response) {
    _mockResponse = response;
    return this;
  }

  /// Simulate analyzing text
  Future<Map<String, dynamic>> analyzeText(String text) async {
    await Future<void>.delayed(_responseDelay);

    if (!_isEnabled) {
      return <String, dynamic>{'error': 'AI coordinator not enabled'};
    }

    if (_mockResponse != null) {
      return _mockResponse!;
    }

    // Return default mock response
    return <String, dynamic>{
      'sentiment': _sentimentEnabled ? <String, dynamic>{
        'score': 0.75,
        'label': 'positive',
      } : null,
      'factCheck': _factCheckEnabled ? <String, dynamic>{
        'claims': <Map<String, dynamic>>[],
      } : null,
      'claims': _claimDetectionEnabled ? <List<dynamic>>[] : null,
    };
  }
}

/// Builder for creating mock audio service behavior
class MockAudioServiceBuilder {
  MockAudioServiceBuilder() {
    _isRecording = false;
    _isInitialized = false;
    _chunkController = StreamController<List<int>>.broadcast();
  }

  late bool _isRecording;
  late bool _isInitialized;
  late StreamController<List<int>> _chunkController;

  /// Set initialized state
  MockAudioServiceBuilder initialized() {
    _isInitialized = true;
    return this;
  }

  /// Set recording state
  MockAudioServiceBuilder recording() {
    _isRecording = true;
    return this;
  }

  /// Get audio chunk stream
  Stream<List<int>> get audioChunkStream => _chunkController.stream;

  /// Emit an audio chunk
  void emitChunk(List<int> chunk) {
    _chunkController.add(chunk);
  }

  /// Simulate starting recording
  Future<void> simulateStart() async {
    if (!_isInitialized) {
      throw Exception('Audio service not initialized');
    }
    _isRecording = true;
  }

  /// Simulate stopping recording
  Future<void> simulateStop() async {
    _isRecording = false;
  }

  /// Dispose the mock
  void dispose() {
    _chunkController.close();
  }
}

/// Helper for creating mock HTTP responses
class MockHttpResponseBuilder {
  MockHttpResponseBuilder() {
    _statusCode = 200;
    _headers = <String, String>{};
    _body = '';
  }

  late int _statusCode;
  late Map<String, String> _headers;
  late String _body;

  /// Set status code
  MockHttpResponseBuilder withStatusCode(int code) {
    _statusCode = code;
    return this;
  }

  /// Add header
  MockHttpResponseBuilder withHeader(String key, String value) {
    _headers[key] = value;
    return this;
  }

  /// Set body
  MockHttpResponseBuilder withBody(String body) {
    _body = body;
    return this;
  }

  /// Set JSON body
  MockHttpResponseBuilder withJsonBody(Map<String, dynamic> json) {
    _headers['content-type'] = 'application/json';
    // In a real implementation, you'd use jsonEncode here
    _body = json.toString();
    return this;
  }

  /// Build the response
  Map<String, dynamic> build() {
    return <String, dynamic>{
      'statusCode': _statusCode,
      'headers': _headers,
      'body': _body,
    };
  }
}
