// ABOUTME: Data models for AI analysis results
// ABOUTME: Includes fact-checking, summaries, action items, and sentiment analysis

/// Fact-checking result
class FactCheckResult {
  final String id;
  final String claim;
  final FactCheckStatus status;
  final double confidence;
  final List<String> sources;
  final String? explanation;
  final String? context;

  FactCheckResult({
    required this.id,
    required this.claim,
    required this.status,
    required this.confidence,
    this.sources = const [],
    this.explanation,
    this.context,
  });

  bool get isVerified => status == FactCheckStatus.verified;
  bool get isDisputed => status == FactCheckStatus.disputed;
  bool get isUncertain => status == FactCheckStatus.uncertain;
  bool get needsReview => status == FactCheckStatus.needsReview;
}

enum FactCheckStatus {
  verified,
  disputed,
  uncertain,
  needsReview,
}

/// Conversation summary result
class ConversationSummary {
  final String summary;
  final List<String> keyPoints;
  final List<String> decisions;
  final List<String> questions;
  final String? tone;
  final List<String> topics;
  final double confidence;

  const ConversationSummary({
    required this.summary,
    this.keyPoints = const [],
    this.decisions = const [],
    this.questions = const [],
    this.tone,
    this.topics = const [],
    this.confidence = 1.0,
  });
}

/// Action item extracted from conversation
class ActionItemResult {
  final String id;
  final String description;
  final String? assignee;
  final DateTime? dueDate;
  final ActionItemPriority priority;
  final String? context;
  final double confidence;

  ActionItemResult({
    required this.id,
    required this.description,
    this.assignee,
    this.dueDate,
    this.priority = ActionItemPriority.medium,
    this.context,
    this.confidence = 1.0,
  });
}

enum ActionItemPriority {
  urgent,
  high,
  medium,
  low,
}

/// Sentiment analysis result
class SentimentAnalysisResult {
  final SentimentType overallSentiment;
  final double confidence;
  final Map<String, double> emotions;
  final String? tone;
  final List<String> keyPhrases;

  const SentimentAnalysisResult({
    required this.overallSentiment,
    required this.confidence,
    this.emotions = const {},
    this.tone,
    this.keyPhrases = const [],
  });
}

enum SentimentType {
  positive,
  negative,
  neutral,
  mixed,
}

/// Analysis configuration
class AnalysisConfiguration {
  final bool enableFactChecking;
  final bool enableSentimentAnalysis;
  final bool enableActionItems;
  final double confidenceThreshold;
  final bool enableCaching;
  final Duration cacheTimeout;

  const AnalysisConfiguration({
    this.enableFactChecking = true,
    this.enableSentimentAnalysis = true,
    this.enableActionItems = true,
    this.confidenceThreshold = 0.7,
    this.enableCaching = true,
    this.cacheTimeout = const Duration(minutes: 10),
  });

  Map<String, dynamic> toJson() => {
        'enableFactChecking': enableFactChecking,
        'enableSentimentAnalysis': enableSentimentAnalysis,
        'enableActionItems': enableActionItems,
        'confidenceThreshold': confidenceThreshold,
        'enableCaching': enableCaching,
        'cacheTimeoutMs': cacheTimeout.inMilliseconds,
      };
}

/// Cached analysis result
class CachedResult {
  final dynamic result;
  final DateTime timestamp;

  CachedResult({
    required this.result,
    required this.timestamp,
  });

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}

/// LLM provider enumeration
enum LLMProvider {
  openai,
  anthropic,
  custom,
}

/// Analysis type
enum AnalysisType {
  quick,
  comprehensive,
  factCheck,
  summary,
  actionItems,
  sentiment,
}

/// Analysis priority
enum AnalysisPriority {
  low,
  normal,
  high,
  urgent,
}

/// Analysis result wrapper
class AnalysisResult {
  final String id;
  final AnalysisType type;
  final DateTime timestamp;
  final String? conversationId;
  final AnalysisStatus status;
  final DateTime startTime;
  final DateTime? completionTime;
  final String? summary;
  final List<String> actionItems;
  final List<FactCheckResult> factChecks;
  final SentimentAnalysisResult? sentiment;
  final double confidence;
  final String? error;

  AnalysisResult({
    required this.id,
    required this.type,
    required this.timestamp,
    this.conversationId,
    this.status = AnalysisStatus.completed,
    DateTime? startTime,
    this.completionTime,
    this.summary,
    this.actionItems = const [],
    this.factChecks = const [],
    this.sentiment,
    this.confidence = 1.0,
    this.error,
  }) : startTime = startTime ?? timestamp;
}

enum AnalysisStatus {
  pending,
  processing,
  completed,
  failed,
  cached,
}

/// LLM exception
class LLMException implements Exception {
  final String message;
  final LLMErrorType type;

  LLMException(this.message, this.type);

  @override
  String toString() => 'LLMException: $message (type: $type)';
}

enum LLMErrorType {
  serviceNotReady,
  networkError,
  authError,
  rateLimitError,
  invalidResponse,
  timeout,
  apiError,
  unknown,
}
