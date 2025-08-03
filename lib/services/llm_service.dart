// ABOUTME: LLM service interface for AI analysis and conversation intelligence
// ABOUTME: Supports multiple AI providers with fallback and load balancing

import 'dart:async';

import '../models/analysis_result.dart';
import '../models/conversation_model.dart';

/// Available AI providers
enum LLMProvider {
  openai,
  anthropic,
  local, // Future: local AI models
}

/// Analysis request priority
enum AnalysisPriority {
  low,      // Batch processing
  normal,   // Standard processing
  high,     // Real-time processing
  urgent,   // Immediate processing
}

/// Service interface for Large Language Model operations
abstract class LLMService {
  /// Whether the service is initialized
  bool get isInitialized;
  
  /// Currently active provider
  LLMProvider get currentProvider;

  /// Initialize the LLM service with API keys
  Future<void> initialize({
    String? openAIKey,
    String? anthropicKey,
    LLMProvider? preferredProvider,
  });

  /// Set the active provider
  Future<void> setProvider(LLMProvider provider);

  /// Analyze conversation text
  Future<AnalysisResult> analyzeConversation(
    String conversationText, {
    AnalysisType type = AnalysisType.comprehensive,
    AnalysisPriority priority = AnalysisPriority.normal,
    LLMProvider? provider,
    Map<String, dynamic>? context,
  });

  /// Perform fact-checking on claims
  Future<List<FactCheckResult>> checkFacts(List<String> claims);

  /// Generate conversation summary
  Future<ConversationSummary> generateSummary(
    ConversationModel conversation, {
    bool includeKeyPoints = true,
    bool includeActionItems = true,
    int maxWords = 200,
  });

  /// Extract action items from conversation
  Future<List<ActionItemResult>> extractActionItems(
    String conversationText, {
    bool includeDeadlines = true,
    bool includePriority = true,
  });

  /// Analyze conversation sentiment and tone
  Future<SentimentAnalysisResult> analyzeSentiment(String text);

  /// Ask a custom question about the conversation
  Future<String> askQuestion(
    String question,
    String context, {
    LLMProvider? provider,
  });

  /// Configure analysis settings
  Future<void> configureAnalysis(AnalysisConfiguration config);

  /// Get usage statistics
  Future<Map<String, dynamic>> getUsageStats();

  /// Clear analysis cache
  Future<void> clearCache();

  /// Clean up resources
  Future<void> dispose();
}

/// Exception types for LLM errors
enum LLMErrorType {
  serviceNotReady,
  invalidApiKey,
  apiError,
  networkError,
  quotaExceeded,
  invalidResponse,
  timeout,
  unknown,
}

/// LLM service usage statistics
class LLMUsageStats {
  final Map<LLMProvider, int> requestCounts;
  final Map<LLMProvider, Duration> totalProcessingTime;
  final Map<LLMProvider, double> averageResponseTime;
  final int totalTokensUsed;
  final double estimatedCost;

  const LLMUsageStats({
    required this.requestCounts,
    required this.totalProcessingTime,
    required this.averageResponseTime,
    required this.totalTokensUsed,
    required this.estimatedCost,
  });
}

/// Configuration for analysis behavior
class AnalysisConfiguration {
  final bool enableCaching;
  final Duration cacheTimeout;
  final int maxRetries;
  final double confidenceThreshold;
  final bool enableBatching;
  final int batchSize;

  const AnalysisConfiguration({
    this.enableCaching = true,
    this.cacheTimeout = const Duration(minutes: 10),
    this.maxRetries = 3,
    this.confidenceThreshold = 0.5,
    this.enableBatching = false,
    this.batchSize = 5,
  });

  Map<String, dynamic> toJson() => {
    'enableCaching': enableCaching,
    'cacheTimeoutMs': cacheTimeout.inMilliseconds,
    'maxRetries': maxRetries,
    'confidenceThreshold': confidenceThreshold,
    'enableBatching': enableBatching,
    'batchSize': batchSize,
  };
}

/// Exception class for LLM service errors
class LLMException implements Exception {
  final String message;
  final LLMErrorType type;
  final dynamic originalError;

  const LLMException(
    this.message,
    this.type, {
    this.originalError,
  });

  @override
  String toString() {
    return 'LLMException: $message (type: $type)';
  }
}