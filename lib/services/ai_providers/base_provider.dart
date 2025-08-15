// ABOUTME: Base abstract class for AI provider implementations
// ABOUTME: Defines common interface for OpenAI, Anthropic, and other LLM providers

import 'dart:async';

import '../../models/analysis_result.dart';

/// Base class for all AI providers
abstract class BaseAIProvider {
  /// Provider name for identification
  String get name;
  
  /// Whether the provider is available and configured
  bool get isAvailable;
  
  /// Initialize the provider with API key
  Future<void> initialize(String apiKey);
  
  /// Send a completion request with retry logic
  Future<String> sendCompletion({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1000,
    Map<String, dynamic>? additionalParams,
  });
  
  /// Stream completion responses for real-time updates
  Stream<String> streamCompletion({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1000,
    Map<String, dynamic>? additionalParams,
  });
  
  /// Perform fact-checking on a claim
  Future<FactCheckResult> verifyFact({
    required String claim,
    String? context,
    List<String>? additionalContext,
  });
  
  /// Generate a structured summary
  Future<ConversationSummary> generateSummary({
    required String text,
    int maxWords = 200,
    bool includeKeyPoints = true,
    bool includeActionItems = true,
  });
  
  /// Extract action items from text
  Future<List<ActionItemResult>> extractActionItems({
    required String text,
    bool includeDeadlines = true,
    bool includePriority = true,
  });
  
  /// Analyze sentiment of text
  Future<SentimentAnalysisResult> analyzeSentiment({
    required String text,
    bool includeEmotions = true,
  });
  
  /// Detect factual claims in text
  Future<List<String>> detectClaims({
    required String text,
    double confidenceThreshold = 0.7,
  });
  
  /// Get provider-specific usage statistics
  Future<Map<String, dynamic>> getUsageStats();
  
  /// Validate the API key
  Future<bool> validateApiKey(String apiKey);
  
  /// Get estimated cost for a request
  double estimateCost(int inputTokens, int outputTokens);
  
  /// Clean up resources
  Future<void> dispose();
}

/// Provider response with metadata
class ProviderResponse {
  final String content;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double estimatedCost;
  final Duration processingTime;
  final Map<String, dynamic>? metadata;
  
  const ProviderResponse({
    required this.content,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.estimatedCost,
    required this.processingTime,
    this.metadata,
  });
}

/// Provider capabilities
class ProviderCapabilities {
  final bool supportsStreaming;
  final bool supportsFunctionCalling;
  final bool supportsVision;
  final bool supportsAudioTranscription;
  final int maxContextTokens;
  final int maxOutputTokens;
  final List<String> supportedModels;
  
  const ProviderCapabilities({
    required this.supportsStreaming,
    required this.supportsFunctionCalling,
    required this.supportsVision,
    required this.supportsAudioTranscription,
    required this.maxContextTokens,
    required this.maxOutputTokens,
    required this.supportedModels,
  });
}