// ABOUTME: LLM Service interface
// ABOUTME: Abstract interface for LLM service implementations

import 'dart:async';
import '../models/analysis_result.dart';
import '../models/conversation_model.dart';
import '../models/transcription_segment.dart';

/// Abstract interface for LLM services
abstract class LLMService {
  /// Whether the service is initialized and ready
  bool get isInitialized;

  /// Current active provider
  LLMProvider get currentProvider;

  /// Initialize the service with API keys
  Future<void> initialize({
    String? openAIKey,
    String? anthropicKey,
    LLMProvider? preferredProvider,
  });

  /// Analyze conversation text
  Future<AnalysisResult> analyzeConversation(
    String conversationText, {
    AnalysisType type = AnalysisType.comprehensive,
    AnalysisPriority priority = AnalysisPriority.normal,
    LLMProvider? provider,
    Map<String, dynamic>? context,
  });

  /// Generate conversation summary
  Future<ConversationSummary> generateSummary(
    String text, {
    int maxWords = 200,
    bool includeKeyPoints = true,
    bool includeActionItems = true,
  });

  /// Extract action items
  Future<List<ActionItemResult>> extractActionItems(
    String text, {
    bool includeDeadlines = true,
    bool includePriority = true,
  });

  /// Verify fact
  Future<FactCheckResult> verifyFact(
    String claim, {
    String? context,
    List<String>? additionalContext,
  });

  /// Analyze sentiment
  Future<SentimentAnalysisResult> analyzeSentiment(
    String text, {
    bool includeEmotions = true,
  });

  /// Configure the service
  void configure(AnalysisConfiguration config);

  /// Dispose resources
  Future<void> dispose();
}
