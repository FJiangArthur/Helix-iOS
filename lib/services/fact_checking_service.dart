// ABOUTME: Real-time fact-checking service for live conversation analysis
// ABOUTME: Detects and verifies factual claims using AI providers with queue management

import 'dart:async';
import 'dart:collection';

import '../models/analysis_result.dart';
import '../models/transcription_segment.dart';
import 'llm_service.dart';
import '../core/utils/logging_service.dart';

/// Service for real-time fact-checking of conversation content
class FactCheckingService {
  static const String _tag = 'FactCheckingService';
  
  final LLMService _llmService;
  final LoggingService _logger;
  
  // Processing queue
  final Queue<FactCheckRequest> _pendingRequests = Queue();
  bool _isProcessing = false;
  
  // Results management
  final Map<String, FactCheckResult> _results = {};
  final StreamController<FactCheckResult> _resultsController = StreamController.broadcast();
  
  // Configuration
  bool _isEnabled = true;
  double _confidenceThreshold = 0.7;
  int _maxConcurrentChecks = 3;
  Duration _batchDelay = const Duration(seconds: 2);
  
  // Batching
  final List<String> _textBuffer = [];
  Timer? _batchTimer;
  
  // Rate limiting
  final Queue<DateTime> _requestTimes = Queue();
  int _maxRequestsPerMinute = 20;
  
  FactCheckingService({
    required LLMService llmService,
    required LoggingService logger,
  })  : _llmService = llmService,
        _logger = logger;
  
  /// Stream of fact-check results
  Stream<FactCheckResult> get results => _resultsController.stream;
  
  /// Whether fact-checking is enabled
  bool get isEnabled => _isEnabled;
  
  /// Current confidence threshold
  double get confidenceThreshold => _confidenceThreshold;
  
  /// Number of pending requests
  int get pendingRequestsCount => _pendingRequests.length;
  
  /// Initialize the service
  Future<void> initialize() async {
    _logger.log(_tag, 'Initializing fact-checking service', LogLevel.info);
    
    if (!_llmService.isInitialized) {
      throw Exception('LLM service must be initialized first');
    }
    
    _logger.log(_tag, 'Fact-checking service initialized', LogLevel.info);
  }
  
  /// Process transcription segments for fact-checking
  Future<void> processTranscription(List<TranscriptionSegment> segments) async {
    if (!_isEnabled || segments.isEmpty) return;
    
    try {
      // Extract text content
      final texts = segments.map((s) => s.text).where((t) => t.isNotEmpty).toList();
      
      if (texts.isEmpty) return;
      
      // Add to buffer for batching
      _textBuffer.addAll(texts);
      
      // Reset batch timer
      _batchTimer?.cancel();
      _batchTimer = Timer(_batchDelay, () => _processBatch());
      
    } catch (e) {
      _logger.log(_tag, 'Error processing transcription: $e', LogLevel.error);
    }
  }
  
  /// Process a single text segment immediately
  Future<void> processText(String text, {String? context}) async {
    if (!_isEnabled || text.trim().isEmpty) return;
    
    try {
      final request = FactCheckRequest(
        id: 'req_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        context: context,
        timestamp: DateTime.now(),
        priority: FactCheckPriority.normal,
      );
      
      await _queueRequest(request);
    } catch (e) {
      _logger.log(_tag, 'Error processing text: $e', LogLevel.error);
    }
  }
  
  /// Process text with high priority (immediate)
  Future<void> processHighPriorityText(String text, {String? context}) async {
    if (!_isEnabled || text.trim().isEmpty) return;
    
    try {
      final request = FactCheckRequest(
        id: 'req_high_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        context: context,
        timestamp: DateTime.now(),
        priority: FactCheckPriority.high,
      );
      
      await _queueRequest(request);
      
      // Process immediately if high priority
      if (!_isProcessing) {
        _processQueue();
      }
    } catch (e) {
      _logger.log(_tag, 'Error processing high priority text: $e', LogLevel.error);
    }
  }
  
  /// Get fact-check result by ID
  FactCheckResult? getResult(String resultId) {
    return _results[resultId];
  }
  
  /// Get all results for a text segment
  List<FactCheckResult> getResultsForText(String text) {
    return _results.values
        .where((result) => result.claim.contains(text) || text.contains(result.claim))
        .toList();
  }
  
  /// Configure the service
  void configure({
    bool? enabled,
    double? confidenceThreshold,
    int? maxConcurrentChecks,
    Duration? batchDelay,
    int? maxRequestsPerMinute,
  }) {
    if (enabled != null) _isEnabled = enabled;
    if (confidenceThreshold != null) _confidenceThreshold = confidenceThreshold;
    if (maxConcurrentChecks != null) _maxConcurrentChecks = maxConcurrentChecks;
    if (batchDelay != null) _batchDelay = batchDelay;
    if (maxRequestsPerMinute != null) _maxRequestsPerMinute = maxRequestsPerMinute;
    
    _logger.log(_tag, 'Service configured: enabled=$_isEnabled, threshold=$_confidenceThreshold', LogLevel.info);
  }
  
  /// Clear all cached results
  void clearResults() {
    _results.clear();
    _logger.log(_tag, 'Fact-check results cleared', LogLevel.info);
  }
  
  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    final now = DateTime.now();
    final recentRequests = _requestTimes
        .where((time) => now.difference(time).inMinutes < 1)
        .length;
    
    return {
      'isEnabled': _isEnabled,
      'pendingRequests': _pendingRequests.length,
      'totalResults': _results.length,
      'recentRequestsPerMinute': recentRequests,
      'isProcessing': _isProcessing,
      'confidenceThreshold': _confidenceThreshold,
      'verifiedClaims': _results.values.where((r) => r.isVerified).length,
      'disputedClaims': _results.values.where((r) => r.isDisputed).length,
      'uncertainClaims': _results.values.where((r) => r.isUncertain).length,
    };
  }
  
  /// Dispose of the service
  Future<void> dispose() async {
    _batchTimer?.cancel();
    await _resultsController.close();
    _results.clear();
    _pendingRequests.clear();
    _textBuffer.clear();
    _logger.log(_tag, 'Fact-checking service disposed', LogLevel.info);
  }
  
  // Private methods
  
  Future<void> _processBatch() async {
    if (_textBuffer.isEmpty) return;
    
    try {
      // Combine buffered text
      final combinedText = _textBuffer.join(' ');
      _textBuffer.clear();
      
      // Create batch request
      final request = FactCheckRequest(
        id: 'batch_${DateTime.now().millisecondsSinceEpoch}',
        text: combinedText,
        timestamp: DateTime.now(),
        priority: FactCheckPriority.batch,
      );
      
      await _queueRequest(request);
      
      if (!_isProcessing) {
        _processQueue();
      }
    } catch (e) {
      _logger.log(_tag, 'Error processing batch: $e', LogLevel.error);
    }
  }
  
  Future<void> _queueRequest(FactCheckRequest request) async {
    // Check rate limiting
    if (!_checkRateLimit()) {
      _logger.log(_tag, 'Rate limit exceeded, dropping request', LogLevel.warning);
      return;
    }
    
    // Add to queue based on priority
    if (request.priority == FactCheckPriority.high) {
      // Insert at front for high priority
      final highPriorityRequests = <FactCheckRequest>[];
      final normalRequests = <FactCheckRequest>[];
      
      while (_pendingRequests.isNotEmpty) {
        final req = _pendingRequests.removeFirst();
        if (req.priority == FactCheckPriority.high) {
          highPriorityRequests.add(req);
        } else {
          normalRequests.add(req);
        }
      }
      
      highPriorityRequests.add(request);
      
      for (final req in highPriorityRequests) {
        _pendingRequests.addFirst(req);
      }
      for (final req in normalRequests.reversed) {
        _pendingRequests.addFirst(req);
      }
    } else {
      _pendingRequests.add(request);
    }
    
    _requestTimes.add(DateTime.now());
  }
  
  bool _checkRateLimit() {
    final now = DateTime.now();
    
    // Remove old requests
    while (_requestTimes.isNotEmpty && 
           now.difference(_requestTimes.first).inMinutes >= 1) {
      _requestTimes.removeFirst();
    }
    
    return _requestTimes.length < _maxRequestsPerMinute;
  }
  
  Future<void> _processQueue() async {
    if (_isProcessing || _pendingRequests.isEmpty) return;
    
    _isProcessing = true;
    
    try {
      final concurrentTasks = <Future>[];
      
      while (_pendingRequests.isNotEmpty && 
             concurrentTasks.length < _maxConcurrentChecks) {
        final request = _pendingRequests.removeFirst();
        concurrentTasks.add(_processRequest(request));
      }
      
      if (concurrentTasks.isNotEmpty) {
        await Future.wait(concurrentTasks);
      }
    } catch (e) {
      _logger.log(_tag, 'Error processing queue: $e', LogLevel.error);
    } finally {
      _isProcessing = false;
      
      // Continue processing if there are more requests
      if (_pendingRequests.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), _processQueue);
      }
    }
  }
  
  Future<void> _processRequest(FactCheckRequest request) async {
    try {
      _logger.log(_tag, 'Processing fact-check request: ${request.id}', LogLevel.debug);
      
      // Detect claims in the text
      final claims = await _llmService.checkFacts([request.text]);
      
      if (claims.isEmpty) {
        _logger.log(_tag, 'No verifiable claims found in text', LogLevel.debug);
        return;
      }
      
      // Process each claim
      for (final claim in claims) {
        if (claim.confidence >= _confidenceThreshold) {
          // Store result
          _results[claim.id] = claim;
          
          // Emit result
          _resultsController.add(claim);
          
          _logger.log(_tag, 
            'Fact-check completed: ${claim.status.name} (confidence: ${claim.confidence})',
            LogLevel.info);
        }
      }
    } catch (e) {
      _logger.log(_tag, 'Error processing request ${request.id}: $e', LogLevel.error);
      
      // Create error result
      final errorResult = FactCheckResult(
        id: 'error_${request.id}',
        claim: request.text,
        status: FactCheckStatus.uncertain,
        confidence: 0.0,
        explanation: 'Processing failed: $e',
        context: request.context,
      );
      
      _results[errorResult.id] = errorResult;
      _resultsController.add(errorResult);
    }
  }
}

/// Fact-checking request
class FactCheckRequest {
  final String id;
  final String text;
  final String? context;
  final DateTime timestamp;
  final FactCheckPriority priority;
  
  FactCheckRequest({
    required this.id,
    required this.text,
    this.context,
    required this.timestamp,
    required this.priority,
  });
}

/// Priority levels for fact-checking requests
enum FactCheckPriority {
  low,
  normal,
  high,
  batch,
}