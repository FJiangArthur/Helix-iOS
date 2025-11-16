import 'dart:async';
import 'base_ai_provider.dart';
import 'openai_provider.dart';
import 'package:flutter_helix/core/errors/errors.dart';

/// AI Coordinator manages AI providers and provides unified API
/// Handles provider selection, failover, and caching
class AICoordinator {
  static AICoordinator? _instance;
  static AICoordinator get instance => _instance ??= AICoordinator._();

  AICoordinator._();

  // Providers
  final _openAI = OpenAIProvider.instance;
  BaseAIProvider? _currentProvider;

  // Configuration
  bool _isEnabled = false;
  bool _factCheckEnabled = true;
  bool _sentimentEnabled = true;
  bool _claimDetectionEnabled = true;  // US 2.2: Enhanced fact-checking
  double _claimConfidenceThreshold = 0.6;  // Only check claims with >60% confidence

  // Simple cache
  final Map<String, Map<String, dynamic>> _cache = {};
  static const int _maxCacheSize = 100;

  // Rate limiting
  final List<DateTime> _requestTimes = [];
  static const int _maxRequestsPerMinute = 20;

  bool get isEnabled => _isEnabled;
  bool get factCheckEnabled => _factCheckEnabled;
  bool get sentimentEnabled => _sentimentEnabled;
  bool get claimDetectionEnabled => _claimDetectionEnabled;

  /// Initialize AI coordinator with OpenAI API key
  Future<void> initialize(String openAIApiKey) async {
    await _openAI.initialize(openAIApiKey);
    _currentProvider = _openAI;
    _isEnabled = true;
  }

  /// Configure AI features
  void configure({
    bool? enabled,
    bool? factCheck,
    bool? sentiment,
    bool? claimDetection,
    double? claimThreshold,
  }) {
    if (enabled != null) _isEnabled = enabled;
    if (factCheck != null) _factCheckEnabled = factCheck;
    if (sentiment != null) _sentimentEnabled = sentiment;
    if (claimDetection != null) _claimDetectionEnabled = claimDetection;
    if (claimThreshold != null) _claimConfidenceThreshold = claimThreshold;
  }

  /// Process text with AI analysis (US 2.2: Enhanced with claim detection)
  /// Returns a Result with factCheck and sentiment results
  Future<Result<Map<String, dynamic>, AIError>> analyzeText(String text) async {
    if (!_isEnabled || _currentProvider == null) {
      return Result.failure(AIError.notReady(service: 'AI Coordinator'));
    }

    return ErrorRecovery.tryCatchAsync(
      () async {
        final results = <String, dynamic>{};

        // US 2.2: Claim detection pipeline
        if (_factCheckEnabled && _claimDetectionEnabled) {
          // Check cache for claim detection
          final claimCacheKey = 'claim:$text';
          Map<String, dynamic>? claimResult;

          if (_cache.containsKey(claimCacheKey)) {
            claimResult = _cache[claimCacheKey];
          } else if (_checkRateLimit()) {
            claimResult = await _currentProvider!.detectClaim(text);
            _addToCache(claimCacheKey, claimResult);
          } else {
            throw ApiError.rateLimitExceeded();
          }

          // Only fact-check if it's a claim with sufficient confidence
          if (claimResult != null) {
            final isClaim = claimResult['isClaim'] as bool? ?? false;
            final confidence = claimResult['confidence'] as double? ?? 0.0;
            final extractedClaim = claimResult['extractedClaim'] as String? ?? text;

            results['claimDetection'] = claimResult;

            if (isClaim && confidence >= _claimConfidenceThreshold) {
              // Fact-check the extracted claim
              final factCacheKey = 'fact:$extractedClaim';
              if (_cache.containsKey(factCacheKey)) {
                results['factCheck'] = _cache[factCacheKey];
              } else if (_checkRateLimit()) {
                final factCheck = await _currentProvider!.factCheck(extractedClaim);
                results['factCheck'] = factCheck;
                _addToCache(factCacheKey, factCheck);
              } else {
                throw ApiError.rateLimitExceeded();
              }
            }
          }
        } else if (_factCheckEnabled && !_claimDetectionEnabled) {
          // Original behavior: fact-check everything
          final cacheKey = 'fact:$text';
          if (_cache.containsKey(cacheKey)) {
            results['factCheck'] = _cache[cacheKey];
          } else if (_checkRateLimit()) {
            final factCheck = await _currentProvider!.factCheck(text);
            results['factCheck'] = factCheck;
            _addToCache(cacheKey, factCheck);
          } else {
            throw ApiError.rateLimitExceeded();
          }
        }

        // Sentiment analysis
        if (_sentimentEnabled) {
          final cacheKey = 'sentiment:$text';
          if (_cache.containsKey(cacheKey)) {
            results['sentiment'] = _cache[cacheKey];
          } else if (_checkRateLimit()) {
            final sentiment = await _currentProvider!.analyzeSentiment(text);
            results['sentiment'] = sentiment;
            _addToCache(cacheKey, sentiment);
          } else {
            throw ApiError.rateLimitExceeded();
          }
        }

        return results;
      },
      operationName: 'AICoordinator.analyzeText',
      context: {'textLength': text.length},
    ).then((result) {
      return result.mapError((error) {
        if (error is ApiError) return error as AIError;
        return AIError(
          code: error.code,
          message: error.message,
          details: error.details,
          originalError: error.originalError,
          stackTrace: error.stackTrace,
        );
      });
    });
  }

  /// Perform fact-checking only
  Future<Result<Map<String, dynamic>, AIError>> factCheck(String claim) async {
    if (!_isEnabled || _currentProvider == null) {
      return Result.failure(AIError.notReady(service: 'AI Coordinator'));
    }

    final cacheKey = 'fact:$claim';
    if (_cache.containsKey(cacheKey)) {
      return Result.success(_cache[cacheKey]!);
    }

    if (!_checkRateLimit()) {
      return Result.failure(
        AIError(
          code: 'AI_RATE_LIMIT_EXCEEDED',
          message: 'Rate limit exceeded',
          details: 'Too many requests. Please try again later.',
          isRecoverable: true,
          recoveryAction: 'Wait a moment and try again',
        ),
      );
    }

    return ErrorRecovery.tryCatchAsync(
      () async {
        final result = await _currentProvider!.factCheck(claim);
        _addToCache(cacheKey, result);
        return result;
      },
      operationName: 'AICoordinator.factCheck',
      context: {'claimLength': claim.length},
    ).then((result) => _mapToAIError(result));
  }

  /// Analyze sentiment only
  Future<Result<Map<String, dynamic>, AIError>> analyzeSentiment(String text) async {
    if (!_isEnabled || _currentProvider == null) {
      return Result.failure(AIError.notReady(service: 'AI Coordinator'));
    }

    final cacheKey = 'sentiment:$text';
    if (_cache.containsKey(cacheKey)) {
      return Result.success(_cache[cacheKey]!);
    }

    if (!_checkRateLimit()) {
      return Result.failure(
        AIError(
          code: 'AI_RATE_LIMIT_EXCEEDED',
          message: 'Rate limit exceeded',
          details: 'Too many requests. Please try again later.',
          isRecoverable: true,
          recoveryAction: 'Wait a moment and try again',
        ),
      );
    }

    return ErrorRecovery.tryCatchAsync(
      () async {
        final result = await _currentProvider!.analyzeSentiment(text);
        _addToCache(cacheKey, result);
        return result;
      },
      operationName: 'AICoordinator.analyzeSentiment',
      context: {'textLength': text.length},
    ).then((result) => _mapToAIError(result));
  }

  /// Extract action items
  Future<Result<List<Map<String, dynamic>>, AIError>> extractActionItems(String text) async {
    if (!_isEnabled || _currentProvider == null) {
      return Result.failure(AIError.notReady(service: 'AI Coordinator'));
    }

    if (!_checkRateLimit()) {
      return Result.failure(
        AIError(
          code: 'AI_RATE_LIMIT_EXCEEDED',
          message: 'Rate limit exceeded',
          details: 'Too many requests. Please try again later.',
          isRecoverable: true,
          recoveryAction: 'Wait a moment and try again',
        ),
      );
    }

    return ErrorRecovery.tryCatchAsync(
      () async => await _currentProvider!.extractActionItems(text),
      operationName: 'AICoordinator.extractActionItems',
      context: {'textLength': text.length},
    ).then((result) => _mapToAIError(result));
  }

  /// Generate summary
  Future<Result<Map<String, dynamic>, AIError>> summarize(String text) async {
    if (!_isEnabled || _currentProvider == null) {
      return Result.failure(AIError.notReady(service: 'AI Coordinator'));
    }

    if (!_checkRateLimit()) {
      return Result.failure(
        AIError(
          code: 'AI_RATE_LIMIT_EXCEEDED',
          message: 'Rate limit exceeded',
          details: 'Too many requests. Please try again later.',
          isRecoverable: true,
          recoveryAction: 'Wait a moment and try again',
        ),
      );
    }

    return ErrorRecovery.tryCatchAsync(
      () async => await _currentProvider!.summarize(text),
      operationName: 'AICoordinator.summarize',
      context: {'textLength': text.length},
    ).then((result) => _mapToAIError(result));
  }

  /// Helper to convert AppError to AIError
  Result<T, AIError> _mapToAIError<T>(Result<T, AppError> result) {
    return result.mapError((error) {
      if (error is AIError) return error;
      if (error is ApiError) {
        return AIError(
          code: error.code,
          message: error.message,
          details: error.details,
          originalError: error.originalError,
          stackTrace: error.stackTrace,
          context: error.context,
          isRecoverable: error.isRecoverable,
          recoveryAction: error.recoveryAction,
        );
      }
      return AIError(
        code: error.code,
        message: error.message,
        details: error.details,
        originalError: error.originalError,
        stackTrace: error.stackTrace,
        context: error.context,
        isRecoverable: error.isRecoverable,
        recoveryAction: error.recoveryAction,
      );
    });
  }

  /// Check rate limit
  bool _checkRateLimit() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    // Remove old requests
    _requestTimes.removeWhere((time) => time.isBefore(oneMinuteAgo));

    if (_requestTimes.length >= _maxRequestsPerMinute) {
      return false;
    }

    _requestTimes.add(now);
    return true;
  }

  /// Add to cache
  void _addToCache(String key, Map<String, dynamic> value) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[key] = value;
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
  }

  /// Get usage statistics
  Map<String, dynamic> getStats() {
    return {
      'provider': _currentProvider?.name ?? 'none',
      'cacheSize': _cache.length,
      'requestsLastMinute': _requestTimes.length,
      'totalTokens': _openAI.totalTokens,
    };
  }

  /// Dispose resources
  void dispose() {
    _currentProvider?.dispose();
    _cache.clear();
    _requestTimes.clear();
    _isEnabled = false;
  }
}
