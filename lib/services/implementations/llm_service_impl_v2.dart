// ABOUTME: Enhanced LLM service implementation with multi-provider architecture and automatic failover
// ABOUTME: Manages OpenAI and Anthropic providers with intelligent routing and comprehensive error handling

import 'dart:async';
import 'dart:math';

import '../ai_providers/base_provider.dart';
import '../ai_providers/openai_provider.dart';
import '../ai_providers/anthropic_provider.dart';
import '../../models/analysis_result.dart';
import '../../models/conversation_model.dart';
import '../../core/utils/logging_service.dart';
import '../../core/config/app_config.dart';

class LLMServiceImplV2 {
  static const String _tag = 'LLMServiceImplV2';

  final LoggingService _logger;
  final AppConfig? _config;

  // Providers
  late final OpenAIProvider _openAIProvider;
  late final AnthropicProvider _anthropicProvider;
  final Map<LLMProvider, BaseAIProvider> _providers = {};

  // Service state
  bool _isInitialized = false;
  LLMProvider _currentProvider = LLMProvider.openai;
  LLMProvider? _preferredProvider;

  // Configuration
  AnalysisConfiguration _analysisConfig = const AnalysisConfiguration();
  final Map<String, CachedResult> _analysisCache = {};

  // Failover management
  final Map<LLMProvider, int> _failureCount = {};
  final Map<LLMProvider, DateTime> _lastFailure = {};
  static const int _maxFailures = 3;
  static const Duration _failoverCooldown = Duration(minutes: 5);

  // Performance tracking
  final Map<LLMProvider, List<Duration>> _responseTimes = {};

  LLMServiceImplV2({
    required LoggingService logger,
    AppConfig? config,
  })  : _logger = logger,
        _config = config {
    // Create OpenAI provider with custom endpoint if config provided
    _openAIProvider = OpenAIProvider(
      logger: logger,
      baseUrl: config?.llmEndpoint,
    );
    _anthropicProvider = AnthropicProvider(logger: logger);

    _providers[LLMProvider.openai] = _openAIProvider;
    _providers[LLMProvider.anthropic] = _anthropicProvider;

    // Initialize tracking
    for (final provider in LLMProvider.values) {
      _failureCount[provider] = 0;
      _responseTimes[provider] = [];
    }

    // Auto-initialize if config is provided
    if (config != null) {
      initialize(openAIKey: config.llmApiKey);
    }
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  LLMProvider get currentProvider => _currentProvider;

  @override
  Future<void> initialize({
    String? openAIKey,
    String? anthropicKey,
    LLMProvider? preferredProvider,
  }) async {
    try {
      _logger.log(_tag, 'Initializing enhanced LLM service', LogLevel.info);

      _preferredProvider = preferredProvider ?? LLMProvider.openai;
      _currentProvider = _preferredProvider!;

      // Initialize providers with their keys
      if (openAIKey != null) {
        await _openAIProvider.initialize(openAIKey);
        _logger.log(_tag, 'OpenAI provider initialized', LogLevel.info);
      }

      if (anthropicKey != null) {
        await _anthropicProvider.initialize(anthropicKey);
        _logger.log(_tag, 'Anthropic provider initialized', LogLevel.info);
      }

      // Verify at least one provider is available
      final availableProviders = _providers.entries
          .where((entry) => entry.value.isAvailable)
          .map((entry) => entry.key)
          .toList();

      if (availableProviders.isEmpty) {
        throw LLMException(
          'No AI providers available. Please check API keys.',
          LLMErrorType.serviceNotReady,
        );
      }

      // Set current provider to first available if preferred isn't available
      if (!_providers[_currentProvider]!.isAvailable) {
        _currentProvider = availableProviders.first;
        _logger.log(_tag, 'Switched to available provider: ${_currentProvider.name}', LogLevel.info);
      }

      _isInitialized = true;
      _logger.log(_tag, 'LLM service initialized with ${availableProviders.length} providers', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize LLM service: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> setProvider(LLMProvider provider) async {
    try {
      if (!_providers.containsKey(provider)) {
        throw LLMException('Provider not supported: ${provider.name}', LLMErrorType.serviceNotReady);
      }

      if (!_providers[provider]!.isAvailable) {
        throw LLMException('Provider not available: ${provider.name}', LLMErrorType.serviceNotReady);
      }

      _currentProvider = provider;
      _logger.log(_tag, 'Provider changed to: ${provider.name}', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to set provider: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<AnalysisResult> analyzeConversation(
    String conversationText, {
    AnalysisType type = AnalysisType.comprehensive,
    AnalysisPriority priority = AnalysisPriority.normal,
    LLMProvider? provider,
    Map<String, dynamic>? context,
  }) async {
    if (!_isInitialized) {
      throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
    }

    final analysisProvider = provider ?? _currentProvider;
    final cacheKey = _generateCacheKey(conversationText, type, analysisProvider);

    // Check cache
    if (_analysisConfig.enableCaching && _analysisCache.containsKey(cacheKey)) {
      final cached = _analysisCache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _analysisConfig.cacheTimeout) {
        _logger.log(_tag, 'Returning cached analysis result', LogLevel.debug);
        return cached.result;
      }
    }

    try {
      _logger.log(_tag, 'Starting ${type.name} analysis with ${analysisProvider.name}', LogLevel.info);

      final startTime = DateTime.now();
      final result = await _performAnalysisWithFailover(
        conversationText,
        type,
        analysisProvider,
        context ?? {},
      );
      final endTime = DateTime.now();

      // Track performance
      _trackResponseTime(analysisProvider, endTime.difference(startTime));

      // Cache result
      if (_analysisConfig.enableCaching) {
        _analysisCache[cacheKey] = CachedResult(
          result: result,
          timestamp: DateTime.now(),
        );
      }

      _logger.log(_tag, 'Analysis completed successfully', LogLevel.info);
      return result;
    } catch (e) {
      _recordFailure(analysisProvider);
      _logger.log(_tag, 'Analysis failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<List<FactCheckResult>> checkFacts(List<String> claims) async {
    if (!_isInitialized) {
      throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
    }

    _logger.log(_tag, 'Fact-checking ${claims.length} claims', LogLevel.info);

    final verifications = <FactCheckResult>[];
    
    for (final claim in claims) {
      try {
        final provider = await _selectBestProvider();
        final verification = await _providers[provider]!.verifyFact(claim: claim);
        verifications.add(verification);
      } catch (e) {
        _logger.log(_tag, 'Failed to verify claim: $claim - $e', LogLevel.error);
        
        // Add failed result
        verifications.add(FactCheckResult(
          id: 'fact_${DateTime.now().millisecondsSinceEpoch}',
          claim: claim,
          status: FactCheckStatus.uncertain,
          confidence: 0.0,
          explanation: 'Verification failed: $e',
        ));
      }
    }

    return verifications;
  }

  @override
  Future<ConversationSummary> generateSummary(
    ConversationModel conversation, {
    bool includeKeyPoints = true,
    bool includeActionItems = true,
    int maxWords = 200,
  }) async {
    if (!_isInitialized) {
      throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
    }

    try {
      final conversationText = conversation.messages.map((m) => m.content).join(' ');
      final provider = await _selectBestProvider();
      
      _logger.log(_tag, 'Generating summary with ${provider.name}', LogLevel.info);

      return await _providers[provider]!.generateSummary(
        text: conversationText,
        maxWords: maxWords,
        includeKeyPoints: includeKeyPoints,
        includeActionItems: includeActionItems,
      );
    } catch (e) {
      _logger.log(_tag, 'Summary generation failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<List<ActionItemResult>> extractActionItems(
    String conversationText, {
    bool includeDeadlines = true,
    bool includePriority = true,
  }) async {
    if (!_isInitialized) {
      throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
    }

    try {
      final provider = await _selectBestProvider();
      
      _logger.log(_tag, 'Extracting action items with ${provider.name}', LogLevel.info);

      return await _providers[provider]!.extractActionItems(
        text: conversationText,
        includeDeadlines: includeDeadlines,
        includePriority: includePriority,
      );
    } catch (e) {
      _logger.log(_tag, 'Action item extraction failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<SentimentAnalysisResult> analyzeSentiment(String text) async {
    if (!_isInitialized) {
      throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
    }

    try {
      final provider = await _selectBestProvider();
      
      return await _providers[provider]!.analyzeSentiment(text: text);
    } catch (e) {
      _logger.log(_tag, 'Sentiment analysis failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<String> askQuestion(
    String question,
    String context, {
    LLMProvider? provider,
  }) async {
    if (!_isInitialized) {
      throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
    }

    try {
      final selectedProvider = provider ?? await _selectBestProvider();
      
      _logger.log(_tag, 'Processing question with ${selectedProvider.name}', LogLevel.info);

      return await _providers[selectedProvider]!.sendCompletion(
        prompt: context.isNotEmpty 
          ? 'Context: $context\n\nQuestion: $question\n\nAnswer:'
          : question,
      );
    } catch (e) {
      _logger.log(_tag, 'Question processing failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> configureAnalysis(AnalysisConfiguration config) async {
    _analysisConfig = config;
    _logger.log(_tag, 'Analysis configuration updated', LogLevel.info);
  }

  @override
  Future<Map<String, dynamic>> getUsageStats() async {
    final stats = <String, dynamic>{
      'currentProvider': _currentProvider.name,
      'initialized': _isInitialized,
      'cacheSize': _analysisCache.length,
      'configuration': _analysisConfig.toJson(),
      'providers': {},
      'failureStats': {},
      'performanceStats': {},
    };

    // Get stats from each provider
    for (final entry in _providers.entries) {
      final provider = entry.key;
      final providerImpl = entry.value;
      
      if (providerImpl.isAvailable) {
        stats['providers'][provider.name] = await providerImpl.getUsageStats();
      }
      
      stats['failureStats'][provider.name] = _failureCount[provider];
      
      final responseTimes = _responseTimes[provider]!;
      if (responseTimes.isNotEmpty) {
        stats['performanceStats'][provider.name] = {
          'averageResponseTime': responseTimes
              .map((d) => d.inMilliseconds)
              .reduce((a, b) => a + b) / responseTimes.length,
          'totalRequests': responseTimes.length,
        };
      }
    }

    return stats;
  }

  @override
  Future<void> clearCache() async {
    _analysisCache.clear();
    _logger.log(_tag, 'Analysis cache cleared', LogLevel.info);
  }

  @override
  Future<void> dispose() async {
    try {
      await clearCache();
      
      for (final provider in _providers.values) {
        await provider.dispose();
      }
      
      _isInitialized = false;
      _logger.log(_tag, 'LLM service disposed', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error disposing LLM service: $e', LogLevel.error);
    }
  }

  // Private methods

  Future<AnalysisResult> _performAnalysisWithFailover(
    String conversationText,
    AnalysisType type,
    LLMProvider preferredProvider,
    Map<String, dynamic> context,
  ) async {
    final providersToTry = await _getProvidersInOrder(preferredProvider);
    
    LLMException? lastException;
    
    for (final provider in providersToTry) {
      if (!_isProviderHealthy(provider)) {
        continue;
      }
      
      try {
        return await _performSingleAnalysis(conversationText, type, provider, context);
      } catch (e) {
        lastException = e is LLMException ? e : LLMException(
          'Analysis failed: $e',
          LLMErrorType.unknown,
        );

        _recordFailure(provider);
        _logger.log(_tag, 'Provider ${provider.name} failed, trying next', LogLevel.warning);
      }
    }
    
    throw lastException ?? LLMException(
      'All providers failed',
      LLMErrorType.apiError,
    );
  }

  Future<AnalysisResult> _performSingleAnalysis(
    String conversationText,
    AnalysisType type,
    LLMProvider provider,
    Map<String, dynamic> context,
  ) async {
    final providerImpl = _providers[provider]!;
    
    switch (type) {
      case AnalysisType.comprehensive:
        final summary = await providerImpl.generateSummary(text: conversationText);
        final actionItems = await providerImpl.extractActionItems(text: conversationText);
        final sentiment = await providerImpl.analyzeSentiment(text: conversationText);
        final claims = await providerImpl.detectClaims(text: conversationText);
        final factChecks = <FactCheckResult>[];
        
        // Verify detected claims
        for (final claim in claims.take(5)) { // Limit to avoid quota issues
          try {
            final factCheck = await providerImpl.verifyFact(claim: claim);
            factChecks.add(factCheck);
          } catch (e) {
            _logger.log(_tag, 'Failed to verify claim: $claim', LogLevel.warning);
          }
        }
        
        return AnalysisResult(
          id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: context['conversationId'] ?? 'unknown',
          type: type,
          timestamp: DateTime.now(),
          status: AnalysisStatus.completed,
          startTime: DateTime.now().subtract(const Duration(seconds: 5)),
          completionTime: DateTime.now(),
          confidence: 0.85,
          summary: summary.summary,
          actionItems: actionItems.map((item) => item.description).toList(),
          sentiment: sentiment,
          factChecks: factChecks,
        );
        
      case AnalysisType.factCheck:
        final claims = await providerImpl.detectClaims(text: conversationText);
        final factChecks = <FactCheckResult>[];
        
        for (final claim in claims) {
          final factCheck = await providerImpl.verifyFact(claim: claim);
          factChecks.add(factCheck);
        }
        
        return AnalysisResult(
          id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: context['conversationId'] ?? 'unknown',
          type: type,
          timestamp: DateTime.now(),
          status: AnalysisStatus.completed,
          startTime: DateTime.now().subtract(const Duration(seconds: 3)),
          completionTime: DateTime.now(),
          confidence: 0.8,
          factChecks: factChecks,
        );
        
      case AnalysisType.summary:
        final summary = await providerImpl.generateSummary(text: conversationText);

        return AnalysisResult(
          id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: context['conversationId'] ?? 'unknown',
          type: type,
          timestamp: DateTime.now(),
          status: AnalysisStatus.completed,
          startTime: DateTime.now().subtract(const Duration(seconds: 2)),
          completionTime: DateTime.now(),
          confidence: 0.9,
          summary: summary.summary,
        );
        
      case AnalysisType.actionItems:
        final actionItems = await providerImpl.extractActionItems(text: conversationText);

        return AnalysisResult(
          id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: context['conversationId'] ?? 'unknown',
          type: type,
          timestamp: DateTime.now(),
          status: AnalysisStatus.completed,
          startTime: DateTime.now().subtract(const Duration(seconds: 2)),
          completionTime: DateTime.now(),
          confidence: 0.8,
          actionItems: actionItems.map((item) => item.description).toList(),
        );
        
      case AnalysisType.sentiment:
        final sentiment = await providerImpl.analyzeSentiment(text: conversationText);
        
        return AnalysisResult(
          id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: context['conversationId'] ?? 'unknown',
          type: type,
          timestamp: DateTime.now(),
          status: AnalysisStatus.completed,
          startTime: DateTime.now().subtract(const Duration(seconds: 1)),
          completionTime: DateTime.now(),
          confidence: 0.85,
          sentiment: sentiment,
        );
        
      case AnalysisType.quick:
        // Quick analysis: just generate summary
        final summary = await providerImpl.generateSummary(text: conversationText);

        return AnalysisResult(
          id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: context['conversationId'] ?? 'unknown',
          type: type,
          timestamp: DateTime.now(),
          status: AnalysisStatus.completed,
          startTime: DateTime.now().subtract(const Duration(seconds: 2)),
          completionTime: DateTime.now(),
          confidence: 0.7,
          summary: summary.summary,
        );
    }
  }

  Future<LLMProvider> _selectBestProvider() async {
    final availableProviders = _providers.entries
        .where((entry) => entry.value.isAvailable && _isProviderHealthy(entry.key))
        .map((entry) => entry.key)
        .toList();

    if (availableProviders.isEmpty) {
      throw LLMException('No healthy providers available', LLMErrorType.serviceNotReady);
    }

    // Prefer current provider if healthy
    if (availableProviders.contains(_currentProvider)) {
      return _currentProvider;
    }

    // Select based on performance and failure rate
    LLMProvider? bestProvider;
    double bestScore = -1;

    for (final provider in availableProviders) {
      final score = _calculateProviderScore(provider);
      if (score > bestScore) {
        bestScore = score;
        bestProvider = provider;
      }
    }

    return bestProvider ?? availableProviders.first;
  }

  Future<List<LLMProvider>> _getProvidersInOrder(LLMProvider preferred) async {
    final availableProviders = _providers.entries
        .where((entry) => entry.value.isAvailable)
        .map((entry) => entry.key)
        .toList();

    // Sort by preference and health
    availableProviders.sort((a, b) {
      if (a == preferred) return -1;
      if (b == preferred) return 1;
      
      final scoreA = _calculateProviderScore(a);
      final scoreB = _calculateProviderScore(b);
      
      return scoreB.compareTo(scoreA);
    });

    return availableProviders;
  }

  bool _isProviderHealthy(LLMProvider provider) {
    final failures = _failureCount[provider] ?? 0;
    final lastFailure = _lastFailure[provider];
    
    if (failures < _maxFailures) return true;
    
    if (lastFailure != null) {
      final timeSinceFailure = DateTime.now().difference(lastFailure);
      if (timeSinceFailure > _failoverCooldown) {
        // Reset failure count after cooldown
        _failureCount[provider] = 0;
        return true;
      }
    }
    
    return false;
  }

  double _calculateProviderScore(LLMProvider provider) {
    double score = 1.0;
    
    // Penalize for failures
    final failures = _failureCount[provider] ?? 0;
    score -= (failures / _maxFailures) * 0.5;
    
    // Factor in response time
    final responseTimes = _responseTimes[provider]!;
    if (responseTimes.isNotEmpty) {
      final avgResponseTime = responseTimes
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a + b) / responseTimes.length;
      
      // Prefer faster providers
      score += max(0, (5000 - avgResponseTime) / 5000) * 0.3;
    }
    
    return max(0, score);
  }

  void _recordFailure(LLMProvider provider) {
    _failureCount[provider] = (_failureCount[provider] ?? 0) + 1;
    _lastFailure[provider] = DateTime.now();
    
    _logger.log(_tag, 'Recorded failure for ${provider.name} (count: ${_failureCount[provider]})', LogLevel.warning);
  }

  void _trackResponseTime(LLMProvider provider, Duration responseTime) {
    final times = _responseTimes[provider]!;
    times.add(responseTime);
    
    // Keep only recent response times
    if (times.length > 100) {
      times.removeAt(0);
    }
  }

  String _generateCacheKey(String text, AnalysisType type, LLMProvider provider) {
    final hash = text.hashCode.toString();
    return '${provider.name}_${type.name}_$hash';
  }
}

/// Cached analysis result
class CachedResult {
  final AnalysisResult result;
  final DateTime timestamp;
  
  CachedResult({
    required this.result,
    required this.timestamp,
  });
}