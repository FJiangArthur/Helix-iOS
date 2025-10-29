import 'dart:async';
import 'base_ai_provider.dart';
import 'openai_provider.dart';

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

  // Simple cache
  final Map<String, Map<String, dynamic>> _cache = {};
  static const int _maxCacheSize = 100;

  // Rate limiting
  final List<DateTime> _requestTimes = [];
  static const int _maxRequestsPerMinute = 20;

  bool get isEnabled => _isEnabled;
  bool get factCheckEnabled => _factCheckEnabled;
  bool get sentimentEnabled => _sentimentEnabled;

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
  }) {
    if (enabled != null) _isEnabled = enabled;
    if (factCheck != null) _factCheckEnabled = factCheck;
    if (sentiment != null) _sentimentEnabled = sentiment;
  }

  /// Process text with AI analysis
  /// Returns a map with factCheck and sentiment results
  Future<Map<String, dynamic>> analyzeText(String text) async {
    if (!_isEnabled || _currentProvider == null) {
      return {'error': 'AI not enabled'};
    }

    final results = <String, dynamic>{};

    try {
      // Fact-checking
      if (_factCheckEnabled) {
        final cacheKey = 'fact:$text';
        if (_cache.containsKey(cacheKey)) {
          results['factCheck'] = _cache[cacheKey];
        } else {
          if (_checkRateLimit()) {
            final factCheck = await _currentProvider!.factCheck(text);
            results['factCheck'] = factCheck;
            _addToCache(cacheKey, factCheck);
          }
        }
      }

      // Sentiment analysis
      if (_sentimentEnabled) {
        final cacheKey = 'sentiment:$text';
        if (_cache.containsKey(cacheKey)) {
          results['sentiment'] = _cache[cacheKey];
        } else {
          if (_checkRateLimit()) {
            final sentiment = await _currentProvider!.analyzeSentiment(text);
            results['sentiment'] = sentiment;
            _addToCache(cacheKey, sentiment);
          }
        }
      }

      return results;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Perform fact-checking only
  Future<Map<String, dynamic>> factCheck(String claim) async {
    if (!_isEnabled || _currentProvider == null) {
      return {'error': 'AI not enabled'};
    }

    final cacheKey = 'fact:$claim';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    if (!_checkRateLimit()) {
      return {'error': 'Rate limit exceeded'};
    }

    try {
      final result = await _currentProvider!.factCheck(claim);
      _addToCache(cacheKey, result);
      return result;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Analyze sentiment only
  Future<Map<String, dynamic>> analyzeSentiment(String text) async {
    if (!_isEnabled || _currentProvider == null) {
      return {'error': 'AI not enabled'};
    }

    final cacheKey = 'sentiment:$text';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    if (!_checkRateLimit()) {
      return {'error': 'Rate limit exceeded'};
    }

    try {
      final result = await _currentProvider!.analyzeSentiment(text);
      _addToCache(cacheKey, result);
      return result;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Extract action items
  Future<List<Map<String, dynamic>>> extractActionItems(String text) async {
    if (!_isEnabled || _currentProvider == null) {
      return [];
    }

    if (!_checkRateLimit()) {
      return [];
    }

    try {
      return await _currentProvider!.extractActionItems(text);
    } catch (e) {
      return [];
    }
  }

  /// Generate summary
  Future<Map<String, dynamic>> summarize(String text) async {
    if (!_isEnabled || _currentProvider == null) {
      return {'error': 'AI not enabled'};
    }

    if (!_checkRateLimit()) {
      return {'error': 'Rate limit exceeded'};
    }

    try {
      return await _currentProvider!.summarize(text);
    } catch (e) {
      return {'error': e.toString()};
    }
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
