// ABOUTME: AI analysis result data model for conversation insights and intelligence
// ABOUTME: Comprehensive model for fact-checking, summaries, and extracted insights

import 'package:freezed_annotation/freezed_annotation.dart';

part 'analysis_result.freezed.dart';
part 'analysis_result.g.dart';

/// Type of analysis performed
enum AnalysisType {
  factCheck,
  summary,
  actionItems,
  sentiment,
  topics,
  comprehensive,
}

/// Confidence level for analysis results
enum ConfidenceLevel {
  low,      // < 0.5
  medium,   // 0.5 - 0.8
  high,     // > 0.8
}

/// Status of an analysis
enum AnalysisStatus {
  pending,
  processing,
  completed,
  failed,
  partial,
}

/// Main analysis result container
@freezed
class AnalysisResult with _$AnalysisResult {
  const factory AnalysisResult({
    /// Unique identifier for this analysis
    required String id,
    
    /// ID of the conversation being analyzed
    required String conversationId,
    
    /// Type of analysis performed
    required AnalysisType type,
    
    /// Current status of the analysis
    required AnalysisStatus status,
    
    /// When the analysis started
    required DateTime startTime,
    
    /// When the analysis completed
    DateTime? completionTime,
    
    /// AI provider used for analysis
    String? provider,
    
    /// Overall confidence score
    @Default(0.0) double confidence,
    
    /// Fact-checking results
    List<FactCheckResult>? factChecks,
    
    /// Conversation summary
    ConversationSummary? summary,
    
    /// Extracted action items
    List<ActionItemResult>? actionItems,
    
    /// Sentiment analysis
    SentimentAnalysisResult? sentiment,
    
    /// Identified topics
    List<TopicResult>? topics,
    
    /// Key insights and findings
    @Default([]) List<String> insights,
    
    /// Processing errors or warnings
    @Default([]) List<String> errors,
    
    /// Processing time in milliseconds
    int? processingTimeMs,
    
    /// Token usage for AI processing
    Map<String, int>? tokenUsage,
    
    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _AnalysisResult;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$AnalysisResultFromJson(json);

  const AnalysisResult._();

  /// Whether the analysis completed successfully
  bool get isCompleted => status == AnalysisStatus.completed;

  /// Whether the analysis failed
  bool get isFailed => status == AnalysisStatus.failed;

  /// Whether the analysis is still in progress
  bool get isInProgress => status == AnalysisStatus.processing || status == AnalysisStatus.pending;

  /// Get confidence level category
  ConfidenceLevel get confidenceLevel {
    if (confidence < 0.5) return ConfidenceLevel.low;
    if (confidence < 0.8) return ConfidenceLevel.medium;
    return ConfidenceLevel.high;
  }

  /// Processing duration
  Duration? get processingDuration {
    if (completionTime != null) {
      return completionTime!.difference(startTime);
    }
    return null;
  }

  /// Count of verified facts
  int get verifiedFactsCount {
    return factChecks?.where((f) => f.isVerified).length ?? 0;
  }

  /// Count of disputed facts
  int get disputedFactsCount {
    return factChecks?.where((f) => f.isDisputed).length ?? 0;
  }

  /// Count of high-priority action items
  int get highPriorityActionItemsCount {
    return actionItems?.where((a) => a.priority == ActionItemPriority.high).length ?? 0;
  }

  /// Whether the analysis has any critical findings
  bool get hasCriticalFindings {
    return disputedFactsCount > 0 || 
           highPriorityActionItemsCount > 0 ||
           (sentiment?.overallSentiment == SentimentType.negative && sentiment!.confidence > 0.8);
  }
}

/// Fact-checking result for individual claims
@freezed
class FactCheckResult with _$FactCheckResult {
  const factory FactCheckResult({
    /// Unique identifier
    required String id,
    
    /// The claim being fact-checked
    required String claim,
    
    /// Verification result
    required FactCheckStatus status,
    
    /// Confidence in the verification
    required double confidence,
    
    /// Supporting sources
    @Default([]) List<String> sources,
    
    /// Detailed explanation
    String? explanation,
    
    /// Context within the conversation
    String? context,
    
    /// Timestamp range where claim appears
    int? startTimeMs,
    int? endTimeMs,
    
    /// Speaker who made the claim
    String? speakerId,
    
    /// Category of the claim
    String? category,
    
    /// Related claims
    @Default([]) List<String> relatedClaims,
  }) = _FactCheckResult;

  factory FactCheckResult.fromJson(Map<String, dynamic> json) =>
      _$FactCheckResultFromJson(json);

  const FactCheckResult._();

  bool get isVerified => status == FactCheckStatus.verified;
  bool get isDisputed => status == FactCheckStatus.disputed;
  bool get isUncertain => status == FactCheckStatus.uncertain;
  bool get needsReview => status == FactCheckStatus.needsReview;
}

/// Status of fact-check verification
enum FactCheckStatus {
  verified,     // Confirmed as accurate
  disputed,     // Found to be inaccurate
  uncertain,    // Cannot be verified
  needsReview,  // Requires human review
}

/// Conversation summary with key points
@freezed
class ConversationSummary with _$ConversationSummary {
  const factory ConversationSummary({
    /// Main summary text
    required String summary,
    
    /// Key discussion points
    @Default([]) List<String> keyPoints,
    
    /// Important decisions made
    @Default([]) List<String> decisions,
    
    /// Questions raised
    @Default([]) List<String> questions,
    
    /// Overall tone of conversation
    String? tone,
    
    /// Main topics discussed
    @Default([]) List<String> topics,
    
    /// Summary length category
    @Default(SummaryLength.medium) SummaryLength length,
    
    /// Estimated reading time
    Duration? estimatedReadTime,
    
    /// Confidence in summary accuracy
    @Default(0.0) double confidence,
  }) = _ConversationSummary;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      _$ConversationSummaryFromJson(json);

  const ConversationSummary._();

  /// Word count of the summary
  int get wordCount => summary.split(' ').where((w) => w.isNotEmpty).length;

  /// Whether the summary is comprehensive
  bool get isComprehensive => keyPoints.length >= 3 && decisions.isNotEmpty;
}

/// Length categories for summaries
enum SummaryLength {
  brief,    // < 100 words
  medium,   // 100-300 words
  detailed, // > 300 words
}

/// Action item extracted from conversation
@freezed
class ActionItemResult with _$ActionItemResult {
  const factory ActionItemResult({
    /// Unique identifier
    required String id,
    
    /// Description of the action
    required String description,
    
    /// Assigned person (if mentioned)
    String? assignee,
    
    /// Due date (if mentioned)
    DateTime? dueDate,
    
    /// Priority level
    @Default(ActionItemPriority.medium) ActionItemPriority priority,
    
    /// Context where it was mentioned
    String? context,
    
    /// Confidence in extraction accuracy
    @Default(0.0) double confidence,
    
    /// Status of the action item
    @Default(ActionItemStatus.pending) ActionItemStatus status,
    
    /// Timestamp where mentioned
    int? mentionedAtMs,
    
    /// Speaker who mentioned it
    String? speakerId,
    
    /// Related action items
    @Default([]) List<String> relatedItems,
    
    /// Categories or tags
    @Default([]) List<String> tags,
  }) = _ActionItemResult;

  factory ActionItemResult.fromJson(Map<String, dynamic> json) =>
      _$ActionItemResultFromJson(json);

  const ActionItemResult._();

  /// Whether this is a high-priority item
  bool get isHighPriority => priority == ActionItemPriority.high;

  /// Whether the item is overdue
  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now());

  /// Days until due date
  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }
}

/// Priority levels for action items
enum ActionItemPriority {
  low,
  medium,
  high,
  urgent,
}

/// Status of action items
enum ActionItemStatus {
  pending,
  inProgress,
  completed,
  cancelled,
  deferred,
}

/// Sentiment analysis result
@freezed
class SentimentAnalysisResult with _$SentimentAnalysisResult {
  const factory SentimentAnalysisResult({
    /// Overall sentiment
    required SentimentType overallSentiment,
    
    /// Confidence in sentiment analysis
    required double confidence,
    
    /// Detailed emotion breakdown
    required Map<String, double> emotions,
    
    /// Conversation tone
    String? tone,
    
    /// Sentiment progression over time
    @Default([]) List<SentimentTimePoint> progression,
    
    /// Participant-specific sentiment
    @Default({}) Map<String, SentimentType> participantSentiments,
    
    /// Key phrases that influenced sentiment
    @Default([]) List<String> keyPhrases,
  }) = _SentimentAnalysisResult;

  factory SentimentAnalysisResult.fromJson(Map<String, dynamic> json) =>
      _$SentimentAnalysisResultFromJson(json);

  const SentimentAnalysisResult._();

  /// Whether the overall sentiment is positive
  bool get isPositive => overallSentiment == SentimentType.positive;

  /// Whether the overall sentiment is negative
  bool get isNegative => overallSentiment == SentimentType.negative;

  /// Get the dominant emotion
  String? get dominantEmotion {
    if (emotions.isEmpty) return null;
    
    double maxValue = 0.0;
    String? dominant;
    
    emotions.forEach((emotion, value) {
      if (value > maxValue) {
        maxValue = value;
        dominant = emotion;
      }
    });
    
    return dominant;
  }
}

/// Sentiment types
enum SentimentType {
  positive,
  negative,
  neutral,
  mixed,
}

/// Sentiment at a specific point in time
@freezed
class SentimentTimePoint with _$SentimentTimePoint {
  const factory SentimentTimePoint({
    required int timeMs,
    required SentimentType sentiment,
    required double confidence,
  }) = _SentimentTimePoint;

  factory SentimentTimePoint.fromJson(Map<String, dynamic> json) =>
      _$SentimentTimePointFromJson(json);
}

/// Topic identified in conversation
@freezed
class TopicResult with _$TopicResult {
  const factory TopicResult({
    /// Topic name or title
    required String name,
    
    /// Relevance score (0.0 to 1.0)
    required double relevance,
    
    /// Keywords associated with topic
    @Default([]) List<String> keywords,
    
    /// Category of the topic
    String? category,
    
    /// Description of the topic
    String? description,
    
    /// Time ranges where topic was discussed
    @Default([]) List<TimeRange> timeRanges,
    
    /// Participants who discussed this topic
    @Default([]) List<String> participants,
    
    /// Related topics
    @Default([]) List<String> relatedTopics,
    
    /// Confidence in topic identification
    @Default(0.0) double confidence,
  }) = _TopicResult;

  factory TopicResult.fromJson(Map<String, dynamic> json) =>
      _$TopicResultFromJson(json);

  const TopicResult._();

  /// Total time spent discussing this topic
  Duration get totalDiscussionTime {
    return timeRanges.fold(
      Duration.zero,
      (total, range) => total + range.duration,
    );
  }

  /// Whether this is a major topic (high relevance)
  bool get isMajorTopic => relevance > 0.7;
}

/// Time range for topic discussion
@freezed
class TimeRange with _$TimeRange {
  const factory TimeRange({
    required int startMs,
    required int endMs,
  }) = _TimeRange;

  factory TimeRange.fromJson(Map<String, dynamic> json) =>
      _$TimeRangeFromJson(json);

  const TimeRange._();

  /// Duration of this time range
  Duration get duration => Duration(milliseconds: endMs - startMs);

  /// Whether this range contains a specific time
  bool contains(int timeMs) => timeMs >= startMs && timeMs <= endMs;
}