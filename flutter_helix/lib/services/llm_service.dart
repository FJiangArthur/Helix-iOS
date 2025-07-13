// ABOUTME: LLM service interface for AI analysis and conversation intelligence
// ABOUTME: Supports multiple AI providers with fallback and load balancing

import 'dart:async';

import '../models/analysis_result.dart';
import '../models/conversation_model.dart';
import '../core/utils/exceptions.dart';

/// Available AI providers
enum LLMProvider {
  openai,
  anthropic,
  local, // Future: local AI models
}

/// Type of AI analysis to perform
enum AnalysisType {
  factCheck,
  summary,
  actionItems,
  sentiment,
  topics,
  comprehensive, // All analysis types
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
  /// Currently active provider
  LLMProvider get currentProvider;
  
  /// Whether the service is available
  bool get isAvailable;
  
  /// Stream of analysis results
  Stream<AnalysisResult> get analysisStream;

  /// Initialize the LLM service with API keys
  Future<void> initialize({
    String? openAIKey,
    String? anthropicKey,
    LLMProvider? preferredProvider,
  });

  /// Check if a specific provider is available
  Future<bool> isProviderAvailable(LLMProvider provider);

  /// Set API key for a provider
  Future<void> setAPIKey(LLMProvider provider, String apiKey);

  /// Set preferred provider (with fallback to others)
  Future<void> setPreferredProvider(LLMProvider provider);

  /// Analyze conversation text
  Future<AnalysisResult> analyzeConversation(
    String conversationText, {
    AnalysisType type = AnalysisType.comprehensive,
    AnalysisPriority priority = AnalysisPriority.normal,
    LLMProvider? provider,
    Map<String, dynamic>? context,
  });

  /// Perform real-time fact-checking
  Future<List<FactCheck>> factCheckClaims(
    String text, {
    int maxClaims = 5,
    double confidenceThreshold = 0.7,
  });

  /// Generate conversation summary
  Future<ConversationSummary> generateSummary(
    ConversationModel conversation, {
    int maxWords = 200,
    bool includeActionItems = true,
    bool includeKeyPoints = true,
  });

  /// Extract action items from conversation
  Future<List<ActionItem>> extractActionItems(
    String conversationText, {
    bool includePriority = true,
    bool includeDeadlines = true,
  });

  /// Analyze conversation sentiment and tone
  Future<SentimentAnalysis> analyzeSentiment(String text);

  /// Identify key topics and themes
  Future<List<Topic>> identifyTopics(
    String conversationText, {
    int maxTopics = 10,
  });

  /// Ask a custom question about the conversation
  Future<String> askQuestion(
    String question,
    String conversationContext, {
    LLMProvider? provider,
  });

  /// Stream real-time analysis as conversation progresses
  Stream<AnalysisResult> streamAnalysis(
    Stream<String> conversationStream, {
    AnalysisType type = AnalysisType.comprehensive,
    Duration batchInterval = const Duration(seconds: 30),
  });

  /// Configure analysis settings
  Future<void> configureAnalysis({
    double factCheckThreshold = 0.7,
    int maxClaimsPerAnalysis = 10,
    bool enableRealTimeAnalysis = true,
    Duration analysisInterval = const Duration(seconds: 30),
  });

  /// Get usage statistics
  Future<LLMUsageStats> getUsageStats();

  /// Clear analysis cache
  Future<void> clearCache();

  /// Clean up resources
  Future<void> dispose();
}

/// Fact-check result for a specific claim
class FactCheck {
  final String claim;
  final String verification; // 'verified', 'disputed', 'uncertain'
  final double confidence;
  final List<String> sources;
  final String? explanation;

  const FactCheck({
    required this.claim,
    required this.verification,
    required this.confidence,
    required this.sources,
    this.explanation,
  });

  bool get isVerified => verification == 'verified';
  bool get isDisputed => verification == 'disputed';
  bool get isUncertain => verification == 'uncertain';
}

/// Conversation summary
class ConversationSummary {
  final String summary;
  final List<String> keyPoints;
  final List<ActionItem> actionItems;
  final String tone;
  final Duration estimatedReadTime;

  const ConversationSummary({
    required this.summary,
    required this.keyPoints,
    required this.actionItems,
    required this.tone,
    required this.estimatedReadTime,
  });
}

/// Action item extracted from conversation
class ActionItem {
  final String description;
  final String? assignee;
  final DateTime? dueDate;
  final String priority; // 'low', 'medium', 'high'
  final String? context;

  const ActionItem({
    required this.description,
    this.assignee,
    this.dueDate,
    required this.priority,
    this.context,
  });
}

/// Sentiment analysis result
class SentimentAnalysis {
  final String overallSentiment; // 'positive', 'negative', 'neutral'
  final double confidence;
  final String tone; // 'formal', 'casual', 'professional', etc.
  final Map<String, double> emotions; // 'happy', 'frustrated', 'excited', etc.

  const SentimentAnalysis({
    required this.overallSentiment,
    required this.confidence,
    required this.tone,
    required this.emotions,
  });
}

/// Topic identified in conversation
class Topic {
  final String name;
  final double relevance;
  final List<String> keywords;
  final String? category;

  const Topic({
    required this.name,
    required this.relevance,
    required this.keywords,
    this.category,
  });
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