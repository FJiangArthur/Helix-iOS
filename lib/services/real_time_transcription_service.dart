// ABOUTME: Real-time transcription pipeline service that connects audio capture to speech recognition
// ABOUTME: Handles audio streaming, format conversion, buffering and provides real-time transcription results

import 'dart:async';
import 'dart:typed_data';

import '../models/transcription_segment.dart';
import '../core/utils/logging_service.dart';
import 'audio_service.dart';
import 'transcription_service.dart';

/// State of the real-time transcription pipeline
enum TranscriptionPipelineState {
  idle,
  initializing,
  active,
  paused,
  error,
}

/// Configuration for real-time transcription pipeline
class TranscriptionPipelineConfig {
  /// Audio chunk size for processing (in milliseconds)
  final int audioChunkDurationMs;
  
  /// Target latency for real-time transcription (in milliseconds)
  final int targetLatencyMs;
  
  /// Enable partial results for immediate feedback
  final bool enablePartialResults;
  
  /// Maximum transcription session duration (in minutes)
  final int maxSessionDurationMinutes;
  
  /// Memory management settings
  final int maxBufferedSegments;
  
  const TranscriptionPipelineConfig({
    this.audioChunkDurationMs = 100, // 100ms chunks for low latency
    this.targetLatencyMs = 500, // Target <500ms end-to-end latency
    this.enablePartialResults = true,
    this.maxSessionDurationMinutes = 60,
    this.maxBufferedSegments = 1000,
  });
}

/// Real-time transcription service that connects AudioService to TranscriptionService
abstract class RealTimeTranscriptionService {
  /// Current pipeline state
  TranscriptionPipelineState get state;
  
  /// Whether the pipeline is actively transcribing
  bool get isActive;
  
  /// Current configuration
  TranscriptionPipelineConfig get config;
  
  /// Stream of real-time transcription segments
  Stream<TranscriptionSegment> get transcriptionStream;
  
  /// Stream of intermediate/partial transcription results
  Stream<TranscriptionSegment> get partialTranscriptionStream;
  
  /// Stream of pipeline state changes
  Stream<TranscriptionPipelineState> get stateStream;
  
  /// Stream of processing latency metrics (in milliseconds)
  Stream<int> get latencyStream;
  
  /// Initialize the transcription pipeline
  Future<void> initialize(TranscriptionPipelineConfig config);
  
  /// Start real-time transcription with audio pipeline
  Future<void> startTranscription({
    String? language,
    TranscriptionBackend? preferredBackend,
  });
  
  /// Stop real-time transcription
  Future<void> stopTranscription();
  
  /// Pause transcription (can be resumed)
  Future<void> pauseTranscription();
  
  /// Resume paused transcription
  Future<void> resumeTranscription();
  
  /// Get current buffered segments
  List<TranscriptionSegment> getCurrentSegments();
  
  /// Clear current session data
  Future<void> clearSession();
  
  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics();
  
  /// Clean up resources
  Future<void> dispose();
}

/// Implementation of real-time transcription pipeline
class RealTimeTranscriptionServiceImpl implements RealTimeTranscriptionService {
  static const String _tag = 'RealTimeTranscriptionService';
  
  final LoggingService _logger;
  final AudioService _audioService;
  final TranscriptionService _transcriptionService;
  
  // Pipeline state
  TranscriptionPipelineState _state = TranscriptionPipelineState.idle;
  TranscriptionPipelineConfig _config = const TranscriptionPipelineConfig();
  
  // Stream controllers
  final StreamController<TranscriptionSegment> _transcriptionController = 
      StreamController<TranscriptionSegment>.broadcast();
  final StreamController<TranscriptionSegment> _partialTranscriptionController = 
      StreamController<TranscriptionSegment>.broadcast();
  final StreamController<TranscriptionPipelineState> _stateController = 
      StreamController<TranscriptionPipelineState>.broadcast();
  final StreamController<int> _latencyController = 
      StreamController<int>.broadcast();
  
  // Audio processing
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription<TranscriptionSegment>? _transcriptionSubscription;
  StreamSubscription<bool>? _voiceActivitySubscription;
  
  // Session management
  final List<TranscriptionSegment> _currentSegments = [];
  DateTime? _sessionStartTime;
  Timer? _sessionTimer;
  
  // Performance tracking
  DateTime? _lastAudioChunkTime;
  final List<int> _latencyMeasurements = [];
  int _processedChunks = 0;
  int _droppedChunks = 0;
  
  // Voice activity detection
  bool _isVoiceActive = false;
  DateTime? _voiceActivityStartTime;
  
  // Transcription buffering and sentence completion
  final List<TranscriptionSegment> _partialSegments = [];
  String _sentenceBuffer = '';
  Timer? _sentenceFinalizationTimer;
  DateTime? _lastPartialResultTime;
  
  RealTimeTranscriptionServiceImpl({
    required LoggingService logger,
    required AudioService audioService,
    required TranscriptionService transcriptionService,
  }) : _logger = logger,
       _audioService = audioService,
       _transcriptionService = transcriptionService;

  @override
  TranscriptionPipelineState get state => _state;

  @override
  bool get isActive => _state == TranscriptionPipelineState.active;

  @override
  TranscriptionPipelineConfig get config => _config;

  @override
  Stream<TranscriptionSegment> get transcriptionStream => _transcriptionController.stream;

  @override
  Stream<TranscriptionSegment> get partialTranscriptionStream => _partialTranscriptionController.stream;

  @override
  Stream<TranscriptionPipelineState> get stateStream => _stateController.stream;

  @override
  Stream<int> get latencyStream => _latencyController.stream;

  @override
  Future<void> initialize(TranscriptionPipelineConfig config) async {
    try {
      _logger.log(_tag, 'Initializing real-time transcription pipeline', LogLevel.info);
      _setState(TranscriptionPipelineState.initializing);
      
      _config = config;
      
      // Initialize transcription service
      if (!_transcriptionService.isInitialized) {
        await _transcriptionService.initialize();
      }
      
      // Request permissions if needed
      if (!_transcriptionService.hasPermissions) {
        final hasPermission = await _transcriptionService.requestPermissions();
        if (!hasPermission) {
          throw Exception('Microphone permission required for transcription');
        }
      }
      
      _setState(TranscriptionPipelineState.idle);
      _logger.log(_tag, 'Real-time transcription pipeline initialized successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize transcription pipeline: $e', LogLevel.error);
      _setState(TranscriptionPipelineState.error);
      rethrow;
    }
  }

  @override
  Future<void> startTranscription({
    String? language,
    TranscriptionBackend? preferredBackend,
  }) async {
    try {
      if (_state != TranscriptionPipelineState.idle) {
        _logger.log(_tag, 'Pipeline not in idle state, current state: $_state', LogLevel.warning);
        if (_state == TranscriptionPipelineState.active) {
          await stopTranscription();
        }
      }
      
      _logger.log(_tag, 'Starting real-time transcription pipeline', LogLevel.info);
      _setState(TranscriptionPipelineState.initializing);
      
      // Clear previous session data
      await clearSession();
      _sessionStartTime = DateTime.now();
      
      // Start transcription service
      await _transcriptionService.startTranscription(
        language: language,
        preferredBackend: preferredBackend,
        enableCapitalization: true,
        enablePunctuation: true,
      );
      
      // Set up transcription result subscription
      _transcriptionSubscription = _transcriptionService.transcriptionStream.listen(
        _handleTranscriptionResult,
        onError: _handleTranscriptionError,
      );
      
      // Start audio recording and streaming
      await _audioService.startRecording();
      
      // Set up audio stream subscription for real-time processing
      _audioStreamSubscription = _audioService.audioStream.listen(
        _handleAudioChunk,
        onError: _handleAudioError,
      );
      
      // Set up voice activity detection subscription
      _voiceActivitySubscription = _audioService.voiceActivityStream.listen(
        _handleVoiceActivity,
        onError: (error) => _logger.log(_tag, 'Voice activity error: $error', LogLevel.warning),
      );
      
      // Start session management timer
      _startSessionTimer();
      
      _setState(TranscriptionPipelineState.active);
      _logger.log(_tag, 'Real-time transcription pipeline started successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to start transcription pipeline: $e', LogLevel.error);
      _setState(TranscriptionPipelineState.error);
      rethrow;
    }
  }

  @override
  Future<void> stopTranscription() async {
    try {
      _logger.log(_tag, 'Stopping real-time transcription pipeline', LogLevel.info);
      
      // Cancel subscriptions
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      
      await _transcriptionSubscription?.cancel();
      _transcriptionSubscription = null;
      
      await _voiceActivitySubscription?.cancel();
      _voiceActivitySubscription = null;
      
      // Stop services
      await _audioService.stopRecording();
      await _transcriptionService.stopTranscription();
      
      // Stop session timer
      _sessionTimer?.cancel();
      _sessionTimer = null;
      
      _setState(TranscriptionPipelineState.idle);
      
      // Log performance metrics
      _logPerformanceMetrics();
      
      _logger.log(_tag, 'Real-time transcription pipeline stopped', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error stopping transcription pipeline: $e', LogLevel.error);
      _setState(TranscriptionPipelineState.error);
      rethrow;
    }
  }

  @override
  Future<void> pauseTranscription() async {
    try {
      if (_state != TranscriptionPipelineState.active) {
        return;
      }
      
      await _audioService.pauseRecording();
      await _transcriptionService.pauseTranscription();
      
      _setState(TranscriptionPipelineState.paused);
      _logger.log(_tag, 'Transcription pipeline paused', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error pausing transcription pipeline: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> resumeTranscription() async {
    try {
      if (_state != TranscriptionPipelineState.paused) {
        return;
      }
      
      await _audioService.resumeRecording();
      await _transcriptionService.resumeTranscription();
      
      _setState(TranscriptionPipelineState.active);
      _logger.log(_tag, 'Transcription pipeline resumed', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error resuming transcription pipeline: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  List<TranscriptionSegment> getCurrentSegments() {
    return List.from(_currentSegments);
  }

  @override
  Future<void> clearSession() async {
    _currentSegments.clear();
    _sessionStartTime = null;
    _latencyMeasurements.clear();
    _processedChunks = 0;
    _droppedChunks = 0;
    _isVoiceActive = false;
    _voiceActivityStartTime = null;
    
    // Clear transcription buffering
    _partialSegments.clear();
    _sentenceBuffer = '';
    _sentenceFinalizationTimer?.cancel();
    _sentenceFinalizationTimer = null;
    _lastPartialResultTime = null;
    
    _logger.log(_tag, 'Session data cleared', LogLevel.debug);
  }

  @override
  Map<String, dynamic> getPerformanceMetrics() {
    final now = DateTime.now();
    final sessionDuration = _sessionStartTime != null 
        ? now.difference(_sessionStartTime!).inMilliseconds 
        : 0;
    
    final avgLatency = _latencyMeasurements.isNotEmpty 
        ? _latencyMeasurements.reduce((a, b) => a + b) / _latencyMeasurements.length
        : 0.0;
    
    return {
      'sessionDurationMs': sessionDuration,
      'processedChunks': _processedChunks,
      'droppedChunks': _droppedChunks,
      'averageLatencyMs': avgLatency,
      'currentSegments': _currentSegments.length,
      'processingRate': sessionDuration > 0 ? (_processedChunks * 1000.0) / sessionDuration : 0.0,
      'targetLatencyMs': _config.targetLatencyMs,
      'isPerformingWell': avgLatency <= _config.targetLatencyMs,
    };
  }

  @override
  Future<void> dispose() async {
    try {
      await stopTranscription();
      
      await _transcriptionController.close();
      await _partialTranscriptionController.close();
      await _stateController.close();
      await _latencyController.close();
      
      _logger.log(_tag, 'Real-time transcription service disposed', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error disposing transcription service: $e', LogLevel.error);
    }
  }

  // Private methods

  void _setState(TranscriptionPipelineState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      _logger.log(_tag, 'Pipeline state changed to: ${newState.name}', LogLevel.debug);
    }
  }

  void _handleAudioChunk(Uint8List audioData) {
    try {
      final now = DateTime.now();
      _lastAudioChunkTime = now;
      _processedChunks++;
      
      // The speech_to_text package handles audio processing internally
      // This handler tracks audio flow for performance monitoring
      if (audioData.isNotEmpty) {
        _logger.log(_tag, 'Processed audio chunk: ${audioData.length} bytes', LogLevel.debug);
      }
    } catch (e) {
      _droppedChunks++;
      _logger.log(_tag, 'Error processing audio chunk: $e', LogLevel.warning);
    }
  }

  void _handleVoiceActivity(bool isActive) {
    if (_isVoiceActive != isActive) {
      _isVoiceActive = isActive;
      
      if (isActive) {
        _voiceActivityStartTime = DateTime.now();
        _logger.log(_tag, 'Voice activity detected', LogLevel.debug);
      } else {
        final duration = _voiceActivityStartTime != null 
            ? DateTime.now().difference(_voiceActivityStartTime!).inMilliseconds
            : 0;
        _logger.log(_tag, 'Voice activity ended (duration: ${duration}ms)', LogLevel.debug);
      }
    }
  }

  void _handleTranscriptionResult(TranscriptionSegment segment) {
    try {
      final now = DateTime.now();
      
      // Calculate latency if we have timing information
      if (_lastAudioChunkTime != null) {
        final latency = now.difference(_lastAudioChunkTime!).inMilliseconds;
        _latencyMeasurements.add(latency);
        _latencyController.add(latency);
        
        // Keep only recent latency measurements for accurate averages
        if (_latencyMeasurements.length > 100) {
          _latencyMeasurements.removeAt(0);
        }
        
        // Log performance warning if latency exceeds target
        if (latency > _config.targetLatencyMs) {
          _logger.log(_tag, 'High latency detected: ${latency}ms (target: ${_config.targetLatencyMs}ms)', LogLevel.warning);
        }
      }
      
      // Handle partial vs final results
      if (segment.isFinal) {
        // Add to current segments buffer
        _currentSegments.add(segment);
        
        // Memory management - remove old segments if buffer is too large
        if (_currentSegments.length > _config.maxBufferedSegments) {
          _currentSegments.removeAt(0);
        }
        
        _transcriptionController.add(segment);
        _logger.log(_tag, 'Final transcription: "${segment.text}" (confidence: ${segment.confidence.toStringAsFixed(2)})', LogLevel.info);
      } else if (_config.enablePartialResults) {
        // Send partial result for immediate feedback
        _partialTranscriptionController.add(segment);
        _logger.log(_tag, 'Partial transcription: "${segment.text}"', LogLevel.debug);
      }
    } catch (e) {
      _logger.log(_tag, 'Error handling transcription result: $e', LogLevel.error);
    }
  }

  void _handleTranscriptionError(dynamic error) {
    _logger.log(_tag, 'Transcription error: $error', LogLevel.error);
    _setState(TranscriptionPipelineState.error);
  }

  void _handleAudioError(dynamic error) {
    _logger.log(_tag, 'Audio stream error: $error', LogLevel.error);
    _setState(TranscriptionPipelineState.error);
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_sessionStartTime != null) {
        final elapsed = DateTime.now().difference(_sessionStartTime!);
        if (elapsed.inMinutes >= _config.maxSessionDurationMinutes) {
          _logger.log(_tag, 'Maximum session duration reached, stopping transcription', LogLevel.warning);
          stopTranscription();
        }
      }
    });
  }

  void _logPerformanceMetrics() {
    final metrics = getPerformanceMetrics();
    _logger.log(_tag, 'Performance metrics: $metrics', LogLevel.info);
  }
}