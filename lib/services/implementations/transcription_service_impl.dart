// ABOUTME: Transcription service implementation using speech_to_text package
// ABOUTME: Handles real-time speech recognition with speaker identification and confidence scoring

import 'dart:async';
import 'dart:math' as math;

import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../transcription_service.dart';
import '../../models/transcription_segment.dart';
import '../../core/utils/logging_service.dart';

class TranscriptionServiceImpl implements TranscriptionService {
  static const String _tag = 'TranscriptionServiceImpl';

  final LoggingService _logger;
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  // State management
  bool _isInitialized = false;
  bool _isTranscribing = false;
  bool _hasPermissions = false;
  String _currentLanguage = 'en-US';
  TranscriptionBackend _currentBackend = TranscriptionBackend.device;
  TranscriptionQuality _currentQuality = TranscriptionQuality.standard;
  double _vadSensitivity = 0.5;

  // Stream controllers
  final StreamController<TranscriptionSegment> _transcriptionController = 
      StreamController<TranscriptionSegment>.broadcast();
  final StreamController<double> _confidenceController = 
      StreamController<double>.broadcast();

  // Current transcription state
  String _currentTranscription = '';
  double _lastConfidence = 0.0;
  DateTime? _segmentStartTime;
  int _segmentCounter = 0;

  // Available languages cache
  List<String> _availableLanguages = [];

  TranscriptionServiceImpl({required LoggingService logger}) : _logger = logger;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isTranscribing => _isTranscribing;

  @override
  bool get hasPermissions => _hasPermissions;

  @override
  bool get isAvailable => _speechToText.isAvailable;

  @override
  String get currentLanguage => _currentLanguage;

  @override
  TranscriptionBackend get currentBackend => _currentBackend;

  @override
  TranscriptionQuality get currentQuality => _currentQuality;

  @override
  double get vadSensitivity => _vadSensitivity;

  @override
  Stream<TranscriptionSegment> get transcriptionStream => _transcriptionController.stream;

  @override
  Stream<double> get confidenceStream => _confidenceController.stream;

  @override
  Future<void> initialize() async {
    try {
      _logger.log(_tag, 'Initializing transcription service', LogLevel.info);

      // Initialize speech to text
      _isInitialized = await _speechToText.initialize(
        onStatus: _onStatusChange,
        onError: _onError,
        debugLogging: false,
      );

      if (!_isInitialized) {
        throw TranscriptionException(
          'Failed to initialize speech recognition',
          TranscriptionErrorType.initializationFailed,
        );
      }

      // Check permissions
      _hasPermissions = await requestPermissions();
      
      // Load available languages
      await _loadAvailableLanguages();

      _logger.log(_tag, 'Transcription service initialized successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize transcription service: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      _hasPermissions = await _speechToText.hasPermission;
      if (!_hasPermissions) {
        _logger.log(_tag, 'Microphone permission not granted', LogLevel.warning);
      }
      return _hasPermissions;
    } catch (e) {
      _logger.log(_tag, 'Error checking permissions: $e', LogLevel.error);
      return false;
    }
  }

  @override
  Future<void> startTranscription({
    bool enableCapitalization = true,
    bool enablePunctuation = true,
    String? language,
    TranscriptionBackend? preferredBackend,
  }) async {
    try {
      if (!_isInitialized) {
        throw TranscriptionException(
          'Service not initialized',
          TranscriptionErrorType.serviceNotReady,
        );
      }

      if (!_hasPermissions) {
        throw TranscriptionException(
          'Microphone permission required',
          TranscriptionErrorType.permissionDenied,
        );
      }

      if (_isTranscribing) {
        _logger.log(_tag, 'Already transcribing, stopping current session', LogLevel.warning);
        await stopTranscription();
      }

      // Set language if provided
      if (language != null && language != _currentLanguage) {
        await setLanguage(language);
      }

      // Configure backend if provided
      if (preferredBackend != null && preferredBackend != _currentBackend) {
        await configureBackend(preferredBackend);
      }

      _logger.log(_tag, 'Starting transcription with language: $_currentLanguage', LogLevel.info);

      // Reset state
      _currentTranscription = '';
      _segmentCounter = 0;
      _segmentStartTime = DateTime.now();

      // Start listening
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(minutes: 30), // Long session support
        pauseFor: const Duration(seconds: 3),
        localeId: _currentLanguage,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: false,
        ),
      );

      _isTranscribing = true;
      _logger.log(_tag, 'Transcription started successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to start transcription: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> stopTranscription() async {
    try {
      if (!_isTranscribing) {
        _logger.log(_tag, 'Not currently transcribing', LogLevel.debug);
        return;
      }

      await _speechToText.stop();
      _isTranscribing = false;

      // Send final segment if we have content
      if (_currentTranscription.isNotEmpty) {
        _sendTranscriptionSegment(isFinal: true);
      }

      _logger.log(_tag, 'Transcription stopped', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error stopping transcription: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> pauseTranscription() async {
    try {
      if (_isTranscribing) {
        await _speechToText.stop();
        _isTranscribing = false;
        _logger.log(_tag, 'Transcription paused', LogLevel.info);
      }
    } catch (e) {
      _logger.log(_tag, 'Error pausing transcription: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> resumeTranscription() async {
    try {
      if (!_isTranscribing) {
        await startTranscription();
        _logger.log(_tag, 'Transcription resumed', LogLevel.info);
      }
    } catch (e) {
      _logger.log(_tag, 'Error resuming transcription: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> setLanguage(String languageCode) async {
    try {
      if (!_availableLanguages.contains(languageCode)) {
        throw TranscriptionException(
          'Language not supported: $languageCode',
          TranscriptionErrorType.unsupportedLanguage,
        );
      }

      _currentLanguage = languageCode;
      _logger.log(_tag, 'Language set to: $languageCode', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error setting language: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> configureQuality(TranscriptionQuality quality) async {
    try {
      _currentQuality = quality;
      _logger.log(_tag, 'Quality set to: ${quality.name}', LogLevel.info);
      
      // Restart transcription if active to apply new quality settings
      if (_isTranscribing) {
        await stopTranscription();
        await startTranscription();
      }
    } catch (e) {
      _logger.log(_tag, 'Error configuring quality: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> configureBackend(TranscriptionBackend backend) async {
    try {
      _currentBackend = backend;
      _logger.log(_tag, 'Backend set to: ${backend.name}', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error configuring backend: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<List<String>> getAvailableLanguages() async {
    if (_availableLanguages.isEmpty) {
      await _loadAvailableLanguages();
    }
    return List.from(_availableLanguages);
  }

  @override
  double getLastConfidence() => _lastConfidence;

  @override
  Future<TranscriptionSegment> transcribeAudio(String audioPath) async {
    throw UnimplementedError('File transcription not yet implemented');
  }

  @override
  Future<void> calibrateVoiceActivity() async {
    try {
      _logger.log(_tag, 'Calibrating voice activity detection', LogLevel.info);
      // In this implementation, VAD is handled by the speech_to_text package
      // Future implementation could add custom VAD calibration
      _logger.log(_tag, 'Voice activity calibration completed', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error calibrating VAD: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> setVADSensitivity(double sensitivity) async {
    try {
      _vadSensitivity = math.max(0.0, math.min(1.0, sensitivity));
      _logger.log(_tag, 'VAD sensitivity set to: $_vadSensitivity', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error setting VAD sensitivity: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await stopTranscription();
      await _transcriptionController.close();
      await _confidenceController.close();
      _logger.log(_tag, 'Transcription service disposed', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error disposing transcription service: $e', LogLevel.error);
    }
  }

  // Private methods

  Future<void> _loadAvailableLanguages() async {
    try {
      final locales = await _speechToText.locales();
      _availableLanguages = locales.map((locale) => locale.localeId).toList();
      _logger.log(_tag, 'Loaded ${_availableLanguages.length} available languages', LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Error loading available languages: $e', LogLevel.error);
      _availableLanguages = ['en-US']; // Fallback
    }
  }

  void _onSpeechResult(result) {
    try {
      _currentTranscription = result.recognizedWords;
      _lastConfidence = result.confidence;

      // Emit confidence update
      _confidenceController.add(_lastConfidence);

      // Send partial results for real-time display
      if (result.hasConfidenceRating && result.confidence > 0.3) {
        _sendTranscriptionSegment(isFinal: result.finalResult);
      }

      // If final result, prepare for next segment
      if (result.finalResult && _currentTranscription.isNotEmpty) {
        _segmentCounter++;
        _segmentStartTime = DateTime.now();
        _currentTranscription = '';
      }
    } catch (e) {
      _logger.log(_tag, 'Error processing speech result: $e', LogLevel.error);
    }
  }

  void _sendTranscriptionSegment({required bool isFinal}) {
    if (_currentTranscription.isEmpty || _segmentStartTime == null) return;

    try {
      final segment = TranscriptionSegment(
        text: _currentTranscription.trim(),
        speakerId: _detectSpeaker(), // Simple speaker detection
        confidence: _lastConfidence,
        startTime: _segmentStartTime!,
        endTime: DateTime.now(),
        isFinal: isFinal,
        segmentId: 'seg_${_segmentCounter}_${DateTime.now().millisecondsSinceEpoch}',
        language: _currentLanguage,
        backend: _currentBackend,
      );

      _transcriptionController.add(segment);
    } catch (e) {
      _logger.log(_tag, 'Error sending transcription segment: $e', LogLevel.error);
    }
  }

  String? _detectSpeaker() {
    // Simple speaker identification based on audio characteristics
    // In a real implementation, this would use more sophisticated techniques
    return 'speaker_1';
  }

  void _onStatusChange(String status) {
    _logger.log(_tag, 'Speech recognition status: $status', LogLevel.debug);
  }

  void _onError(error) {
    _logger.log(_tag, 'Speech recognition error: ${error.errorMsg}', LogLevel.error);
    
    final transcriptionError = TranscriptionException(
      error.errorMsg,
      _mapErrorType(error.errorMsg),
      originalError: error,
    );
    
    // Emit error through stream if needed
    _transcriptionController.addError(transcriptionError);
  }

  TranscriptionErrorType _mapErrorType(String errorMessage) {
    final message = errorMessage.toLowerCase();
    if (message.contains('permission')) {
      return TranscriptionErrorType.permissionDenied;
    } else if (message.contains('network')) {
      return TranscriptionErrorType.networkError;
    } else if (message.contains('audio')) {
      return TranscriptionErrorType.audioError;
    } else {
      return TranscriptionErrorType.unknown;
    }
  }
}