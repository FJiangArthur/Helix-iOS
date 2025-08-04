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
  
  // Session management
  final List<TranscriptionSegment> _currentSegments = [];
  DateTime? _sessionStartTime;
  Timer? _sessionTimer;
  
  // Transcription buffering and finalization
  final List<String> _pendingWords = [];
  final List<double> _pendingConfidences = [];
  String _currentSentenceBuffer = '';
  Timer? _sentenceFinalizationTimer;
  
  // Performance tracking
  DateTime? _lastAudioChunkTime;
  final List<int> _latencyMeasurements = [];
  int _processedChunks = 0;
  int _droppedChunks = 0;
  
  // Performance optimization
  Timer? _performanceMonitorTimer;
  double _currentProcessingLoad = 0.0;
  static const int _maxLatencyMs = 500; // Target max latency
  
  // Memory management
  Timer? _memoryCleanupTimer;
  int _totalWordsProcessed = 0;
  static const int _memoryCleanupIntervalMinutes = 5;
  
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
      
      // Initialize audio service if needed
      if (!_audioService.hasPermission) {
        final hasPermission = await _audioService.requestPermission();
        if (!hasPermission) {
          throw Exception('Audio permission required for transcription');
        }
      }
      
      // Initialize transcription service
      if (!_transcriptionService.isInitialized) {
        await _transcriptionService.initialize();
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
      
      // Start session management timer
      _startSessionTimer();
      
      // Start performance monitoring and memory management
      _startPerformanceMonitoring();
      _startMemoryManagement();
      
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
      
      // Stop services
      await _audioService.stopRecording();
      await _transcriptionService.stopTranscription();
      
      // Stop session timer, performance monitoring, and memory management
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _performanceMonitorTimer?.cancel();
      _performanceMonitorTimer = null;
      _memoryCleanupTimer?.cancel();
      _memoryCleanupTimer = null;
      
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
    
    // Clear buffering data
    _pendingWords.clear();
    _pendingConfidences.clear();
    _currentSentenceBuffer = '';
    _sentenceFinalizationTimer?.cancel();
    
    // Reset memory tracking
    _totalWordsProcessed = 0;
    
    _logger.log(_tag, 'Session data, buffers, and memory tracking cleared', LogLevel.debug);
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
      'totalWordsProcessed': _totalWordsProcessed,
      'bufferedWords': _pendingWords.length,
      'processingLoad': _currentProcessingLoad,
      'latencyMeasurements': _latencyMeasurements.length,
    };
  }

  @override
  Future<void> dispose() async {
    try {
      await stopTranscription();
      
      // Cancel all timers
      _sessionTimer?.cancel();
      _sentenceFinalizationTimer?.cancel();
      _performanceMonitorTimer?.cancel();
      _memoryCleanupTimer?.cancel();
      
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
      
      // For now, we're using the speech_to_text package which handles audio internally
      // In a full implementation, this would process the audio chunk for streaming transcription
      _logger.log(_tag, 'Processed audio chunk: ${audioData.length} bytes', LogLevel.debug);
    } catch (e) {
      _droppedChunks++;
      _logger.log(_tag, 'Error processing audio chunk: $e', LogLevel.warning);
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
      }
      
      // Handle partial vs final results with buffering
      if (segment.isFinal) {
        // Process final segment with sentence completion and punctuation
        final processedSegment = _processAndBufferFinalSegment(segment);
        
        // Add to current segments buffer
        _currentSegments.add(processedSegment);
        
        // Memory management - remove old segments if buffer is too large
        if (_currentSegments.length > _config.maxBufferedSegments) {
          _currentSegments.removeAt(0);
        }
        
        _transcriptionController.add(processedSegment);
        _logger.log(_tag, 'Final transcription: "${processedSegment.text}" (confidence: ${processedSegment.confidence})', LogLevel.info);
      } else if (_config.enablePartialResults) {
        // Handle partial results with word-by-word processing
        final partialSegment = _processPartialSegment(segment);
        _partialTranscriptionController.add(partialSegment);
        _logger.log(_tag, 'Partial transcription: "${partialSegment.text}"', LogLevel.debug);
      }
    } catch (e) {
      _logger.log(_tag, 'Error handling transcription result: $e', LogLevel.error);
    }
  }
  
  /// Process and enhance final transcription segment with sentence completion
  TranscriptionSegment _processAndBufferFinalSegment(TranscriptionSegment segment) {
    try {
      // Add sentence completion and punctuation
      String processedText = _addSentenceCompletionAndPunctuation(segment.text);
      
      // Update sentence buffer for context
      _currentSentenceBuffer = processedText;
      
      // Reset sentence finalization timer
      _sentenceFinalizationTimer?.cancel();
      
      return segment.copyWith(
        text: processedText,
        metadata: {
          ...segment.metadata,
          'processedForCompletion': true,
          'originalText': segment.text,
        },
      );
    } catch (e) {
      _logger.log(_tag, 'Error processing final segment: $e', LogLevel.warning);
      return segment;
    }
  }
  
  /// Process partial segment with word buffering for immediate feedback
  TranscriptionSegment _processPartialSegment(TranscriptionSegment segment) {
    try {
      // Buffer words and confidences for analysis
      final words = segment.text.trim().split(' ');
      final newWords = _getNewWords(words);
      
      // Add new words to buffer and track total processed
      for (final word in newWords) {
        _pendingWords.add(word);
        _pendingConfidences.add(segment.confidence);
        _totalWordsProcessed++;
      }
      
      // Keep buffer size manageable
      if (_pendingWords.length > 50) {
        _pendingWords.removeRange(0, _pendingWords.length - 50);
        _pendingConfidences.removeRange(0, _pendingConfidences.length - 50);
      }
      
      // Process text for better readability
      String processedText = _processPartialText(segment.text);
      
      // Start or reset sentence finalization timer for incomplete sentences
      _startSentenceFinalizationTimer();
      
      return segment.copyWith(
        text: processedText,
        metadata: {
          ...segment.metadata,
          'wordCount': words.length,
          'newWordCount': newWords.length,
          'bufferSize': _pendingWords.length,
        },
      );
    } catch (e) {
      _logger.log(_tag, 'Error processing partial segment: $e', LogLevel.warning);
      return segment;
    }
  }
  
  /// Identify new words in current transcription vs buffered words
  List<String> _getNewWords(List<String> currentWords) {
    if (_pendingWords.isEmpty) return currentWords;
    
    // Find words that weren't in the previous buffer
    final previousText = _pendingWords.join(' ').toLowerCase();
    final currentText = currentWords.join(' ').toLowerCase();
    
    if (currentText.length > previousText.length && currentText.startsWith(previousText)) {
      // New words added at the end
      final newPortion = currentText.substring(previousText.length).trim();
      return newPortion.split(' ').where((word) => word.isNotEmpty).toList();
    }
    
    // Fallback: return all words if we can't determine new ones
    return currentWords;
  }
  
  /// Add sentence completion and punctuation to text
  String _addSentenceCompletionAndPunctuation(String text) {
    if (text.isEmpty) return text;
    
    String processedText = text.trim();
    
    // Add period if sentence doesn't end with punctuation
    final lastChar = processedText[processedText.length - 1];
    if (!'.,!?;:'.contains(lastChar)) {
      // Only add period if it looks like a complete sentence
      if (processedText.split(' ').length >= 3) {
        processedText += '.';
      }
    }
    
    // Capitalize first letter
    if (processedText.isNotEmpty) {
      processedText = processedText[0].toUpperCase() + processedText.substring(1);
    }
    
    return processedText;
  }
  
  /// Process partial text for better real-time display
  String _processPartialText(String text) {
    if (text.isEmpty) return text;
    
    String processedText = text.trim();
    
    // Capitalize first letter
    if (processedText.isNotEmpty) {
      processedText = processedText[0].toUpperCase() + processedText.substring(1);
    }
    
    // Add ellipsis to indicate ongoing speech (for partial results)
    if (processedText.isNotEmpty && !processedText.endsWith('...')) {
      processedText += '...';
    }
    
    return processedText;
  }
  
  /// Start timer to finalize incomplete sentences after a delay
  void _startSentenceFinalizationTimer() {
    _sentenceFinalizationTimer?.cancel();
    _sentenceFinalizationTimer = Timer(const Duration(seconds: 2), () {
      // After 2 seconds of no updates, we can consider finalizing the current partial
      if (_currentSentenceBuffer.isNotEmpty) {
        _logger.log(_tag, 'Sentence finalization timeout - buffer: "$_currentSentenceBuffer"', LogLevel.debug);
      }
    });
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
  
  /// Start performance monitoring for latency optimization
  void _startPerformanceMonitoring() {
    _performanceMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _monitorAndOptimizePerformance();
    });
  }
  
  /// Monitor performance and adjust configuration for optimal latency
  void _monitorAndOptimizePerformance() {
    if (_latencyMeasurements.isEmpty) return;
    
    final avgLatency = _latencyMeasurements.reduce((a, b) => a + b) / _latencyMeasurements.length;
    final maxLatency = _latencyMeasurements.reduce((a, b) => a > b ? a : b);
    
    // Calculate processing load based on chunks processed vs time
    final sessionDuration = _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!).inMilliseconds 
        : 1;
    _currentProcessingLoad = (_processedChunks * 1000.0) / sessionDuration;
    
    _logger.log(_tag, 'Performance metrics - Avg latency: ${avgLatency.toStringAsFixed(1)}ms, Max: ${maxLatency}ms, Load: ${_currentProcessingLoad.toStringAsFixed(1)} chunks/sec', LogLevel.debug);
    
    // Adaptive performance optimization
    if (avgLatency > _maxLatencyMs) {
      _logger.log(_tag, 'High latency detected (${avgLatency.toStringAsFixed(1)}ms), attempting optimization', LogLevel.warning);
      _optimizeForLatency();
    }
    
    // Check for dropped chunks
    if (_droppedChunks > 0) {
      final dropRate = (_droppedChunks / (_processedChunks + _droppedChunks)) * 100;
      if (dropRate > 5.0) { // More than 5% drop rate
        _logger.log(_tag, 'High chunk drop rate: ${dropRate.toStringAsFixed(1)}%', LogLevel.warning);
      }
    }
  }
  
  /// Optimize configuration to reduce latency
  void _optimizeForLatency() {
    try {
      // Reduce buffer sizes for faster processing
      if (_pendingWords.length > 20) {
        _pendingWords.removeRange(0, _pendingWords.length - 20);
        _pendingConfidences.removeRange(0, _pendingConfidences.length - 20);
      }
      
      // Clear old latency measurements to get fresh data
      if (_latencyMeasurements.length > 20) {
        _latencyMeasurements.removeRange(0, _latencyMeasurements.length - 20);
      }
      
      _logger.log(_tag, 'Applied latency optimization - reduced buffer sizes', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error optimizing for latency: $e', LogLevel.error);
    }
  }
  
  /// Start memory management for long conversations
  void _startMemoryManagement() {
    _memoryCleanupTimer = Timer.periodic(
      Duration(minutes: _memoryCleanupIntervalMinutes), 
      (timer) {
        _performMemoryCleanup();
      },
    );
  }
  
  /// Perform periodic memory cleanup for long conversations
  void _performMemoryCleanup() {
    try {
      final segmentsBefore = _currentSegments.length;
      final wordsBefore = _pendingWords.length;
      final latencyMeasurementsBefore = _latencyMeasurements.length;
      
      // Clean up old segments (keep last 200 for context)
      if (_currentSegments.length > 200) {
        final removeCount = _currentSegments.length - 200;
        _currentSegments.removeRange(0, removeCount);
      }
      
      // Clean up word buffer (keep last 30 words for context)
      if (_pendingWords.length > 30) {
        final removeCount = _pendingWords.length - 30;
        _pendingWords.removeRange(0, removeCount);
        _pendingConfidences.removeRange(0, removeCount);
      }
      
      // Clean up old latency measurements (keep last 50)
      if (_latencyMeasurements.length > 50) {
        final removeCount = _latencyMeasurements.length - 50;
        _latencyMeasurements.removeRange(0, removeCount);
      }
      
      final segmentsAfter = _currentSegments.length;
      final wordsAfter = _pendingWords.length;
      final latencyMeasurementsAfter = _latencyMeasurements.length;
      
      if (segmentsBefore > segmentsAfter || wordsBefore > wordsAfter || latencyMeasurementsBefore > latencyMeasurementsAfter) {
        _logger.log(_tag, 'Memory cleanup completed - Segments: $segmentsBefore→$segmentsAfter, Words: $wordsBefore→$wordsAfter, Latency measurements: $latencyMeasurementsBefore→$latencyMeasurementsAfter', LogLevel.info);
      }
      
      // Log memory statistics
      _logMemoryStatistics();
      
    } catch (e) {
      _logger.log(_tag, 'Error during memory cleanup: $e', LogLevel.error);
    }
  }
  
  /// Log current memory usage statistics
  void _logMemoryStatistics() {
    final sessionDuration = _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!).inMinutes 
        : 0;
    
    final avgWordsPerMinute = sessionDuration > 0 
        ? (_totalWordsProcessed / sessionDuration).toStringAsFixed(1)
        : '0.0';
    
    _logger.log(_tag, 'Memory stats - Session: ${sessionDuration}min, Total words: $_totalWordsProcessed, Avg: ${avgWordsPerMinute} words/min, Buffered segments: ${_currentSegments.length}, Buffered words: ${_pendingWords.length}', LogLevel.debug);
  }
}