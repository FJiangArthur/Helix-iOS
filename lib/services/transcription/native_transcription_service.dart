import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'transcription_service.dart';
import 'transcription_models.dart';

/// Native iOS Speech Recognition transcription service (US 3.1)
/// Wraps existing SpeechStreamRecognizer.swift
class NativeTranscriptionService implements TranscriptionService {
  static NativeTranscriptionService? _instance;
  static NativeTranscriptionService get instance =>
      _instance ??= NativeTranscriptionService._();

  NativeTranscriptionService._();

  @override
  TranscriptionMode get mode => TranscriptionMode.native;

  bool _isAvailable = false;
  bool _isTranscribing = false;
  String? _currentLanguageCode;

  // Statistics
  int _segmentCount = 0;
  int _totalCharacters = 0;
  DateTime? _startTime;
  final List<double> _confidenceScores = [];

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isTranscribing => _isTranscribing;

  // Streams
  final _transcriptController =
      StreamController<TranscriptSegment>.broadcast();
  final _errorController = StreamController<TranscriptionError>.broadcast();

  @override
  Stream<TranscriptSegment> get transcriptStream =>
      _transcriptController.stream;

  @override
  Stream<TranscriptionError> get errorStream => _errorController.stream;

  // EventChannel for receiving transcription from native iOS
  static const _eventChannelName = "eventSpeechRecognize";
  final _eventChannel = const EventChannel(_eventChannelName);
  StreamSubscription? _eventSubscription;

  @override
  Future<void> initialize() async {
    try {
      // Check if native speech recognition is available
      // This is implicitly checked by iOS when we start transcription
      _isAvailable = true;
    } catch (e) {
      _isAvailable = false;
      _errorController.add(TranscriptionError(
        type: TranscriptionErrorType.notAvailable,
        message: 'Native speech recognition not available',
        originalError: e,
      ));
    }
  }

  @override
  Future<void> startTranscription({String? languageCode}) async {
    if (_isTranscribing) {
      print('Native transcription already running');
      return;
    }

    _currentLanguageCode = languageCode ?? 'en-US';
    _isTranscribing = true;
    _startTime = DateTime.now();
    _segmentCount = 0;
    _totalCharacters = 0;
    _confidenceScores.clear();

    // Listen to native transcription events
    _eventSubscription = _eventChannel
        .receiveBroadcastStream(_eventChannelName)
        .listen((event) {
      try {
        final text = event['script'] as String? ?? '';
        if (text.isNotEmpty) {
          _processTranscript(text);
        }
      } catch (e) {
        _errorController.add(TranscriptionError(
          type: TranscriptionErrorType.audioProcessingError,
          message: 'Error processing transcript',
          originalError: e,
        ));
      }
    }, onError: (error) {
      _errorController.add(TranscriptionError(
        type: TranscriptionErrorType.unknown,
        message: 'Native transcription error',
        originalError: error,
      ));
    });
  }

  @override
  Future<void> stopTranscription() async {
    if (!_isTranscribing) return;

    _isTranscribing = false;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void appendAudioData(Uint8List pcmData) {
    // Audio data is handled by native iOS SpeechStreamRecognizer
    // This method is a no-op for native transcription
    // The native code receives audio directly from BluetoothManager
  }

  void _processTranscript(String text) {
    _segmentCount++;
    _totalCharacters += text.length;

    // Native iOS doesn't provide confidence scores via the current implementation
    // We use a default confidence of 0.9 for native transcription
    const double defaultConfidence = 0.9;
    _confidenceScores.add(defaultConfidence);

    final segment = TranscriptSegment(
      text: text,
      confidence: defaultConfidence,
      timestamp: DateTime.now(),
      isFinal: true,
      source: TranscriptionMode.native,
    );

    _transcriptController.add(segment);
  }

  @override
  TranscriptionStats getStats() {
    final duration = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    final avgConfidence = _confidenceScores.isEmpty
        ? 0.0
        : _confidenceScores.reduce((a, b) => a + b) / _confidenceScores.length;

    return TranscriptionStats(
      segmentCount: _segmentCount,
      totalCharacters: _totalCharacters,
      totalDuration: duration,
      averageConfidence: avgConfidence,
      activeMode: mode,
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _transcriptController.close();
    _errorController.close();
    _isTranscribing = false;
  }
}
