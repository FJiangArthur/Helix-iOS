// ABOUTME: Model versioning system for AI model lifecycle management
// ABOUTME: Tracks model versions, metadata, performance metrics, and deployment status

import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_version.freezed.dart';
part 'model_version.g.dart';

/// Represents a specific version of an AI model
@freezed
class ModelVersion with _$ModelVersion {
  const factory ModelVersion({
    /// Unique version identifier (semantic versioning: major.minor.patch)
    required String version,

    /// Model identifier (e.g., 'gpt-4-turbo', 'claude-3-opus')
    required String modelId,

    /// Provider name (OpenAI, Anthropic, etc.)
    required String provider,

    /// Model display name
    required String displayName,

    /// Model description
    String? description,

    /// Release date
    required DateTime releaseDate,

    /// Current deployment status
    @Default(ModelStatus.inactive) ModelStatus status,

    /// Model capabilities
    required ModelCapabilities capabilities,

    /// Performance metrics
    ModelPerformanceMetrics? metrics,

    /// Cost information
    required ModelCostInfo costInfo,

    /// Deprecation information
    ModelDeprecationInfo? deprecation,

    /// Configuration overrides
    @Default({}) Map<String, dynamic> configuration,

    /// Tags for categorization
    @Default([]) List<String> tags,

    /// Created timestamp
    required DateTime createdAt,

    /// Last updated timestamp
    required DateTime updatedAt,

    /// Version notes/changelog
    String? releaseNotes,

    /// Minimum required confidence threshold
    @Default(0.7) double minConfidenceThreshold,

    /// Maximum allowed latency (milliseconds)
    int? maxLatencyMs,

    /// Success rate threshold (0.0-1.0)
    @Default(0.95) double successRateThreshold,
  }) = _ModelVersion;

  factory ModelVersion.fromJson(Map<String, dynamic> json) =>
      _$ModelVersionFromJson(json);
}

/// Model deployment status
enum ModelStatus {
  /// Model is inactive and not available for use
  inactive,

  /// Model is in testing/staging environment
  testing,

  /// Model is deployed in canary mode (limited traffic)
  canary,

  /// Model is active and serving production traffic
  active,

  /// Model is being phased out but still available
  deprecated,

  /// Model is retired and no longer available
  retired,
}

/// Model capabilities
@freezed
class ModelCapabilities with _$ModelCapabilities {
  const factory ModelCapabilities({
    /// Supports streaming responses
    @Default(false) bool supportsStreaming,

    /// Supports function/tool calling
    @Default(false) bool supportsFunctionCalling,

    /// Supports vision/image inputs
    @Default(false) bool supportsVision,

    /// Supports audio transcription
    @Default(false) bool supportsAudioTranscription,

    /// Maximum context window (tokens)
    required int maxContextTokens,

    /// Maximum output tokens
    required int maxOutputTokens,

    /// Supported languages
    @Default(['en']) List<String> supportedLanguages,

    /// Supported analysis types
    @Default([]) List<String> supportedAnalysisTypes,
  }) = _ModelCapabilities;

  factory ModelCapabilities.fromJson(Map<String, dynamic> json) =>
      _$ModelCapabilitiesFromJson(json);
}

/// Model performance metrics
@freezed
class ModelPerformanceMetrics with _$ModelPerformanceMetrics {
  const factory ModelPerformanceMetrics({
    /// Average response latency (milliseconds)
    required double avgLatencyMs,

    /// P95 latency (milliseconds)
    required double p95LatencyMs,

    /// P99 latency (milliseconds)
    required double p99LatencyMs,

    /// Success rate (0.0-1.0)
    required double successRate,

    /// Error rate (0.0-1.0)
    required double errorRate,

    /// Average confidence score
    required double avgConfidence,

    /// Total requests processed
    @Default(0) int totalRequests,

    /// Total successful requests
    @Default(0) int successfulRequests,

    /// Total failed requests
    @Default(0) int failedRequests,

    /// Average tokens per request
    double? avgTokensPerRequest,

    /// Cost per 1000 requests
    double? costPer1kRequests,

    /// Last updated timestamp
    required DateTime lastUpdated,

    /// Evaluation scores by category
    @Default({}) Map<String, double> evaluationScores,
  }) = _ModelPerformanceMetrics;

  factory ModelPerformanceMetrics.fromJson(Map<String, dynamic> json) =>
      _$ModelPerformanceMetricsFromJson(json);
}

/// Model cost information
@freezed
class ModelCostInfo with _$ModelCostInfo {
  const factory ModelCostInfo({
    /// Cost per 1K input tokens (USD)
    required double inputCostPer1k,

    /// Cost per 1K output tokens (USD)
    required double outputCostPer1k,

    /// Cost tier (economy, standard, premium)
    @Default(CostTier.standard) CostTier tier,

    /// Estimated monthly cost at current usage
    double? estimatedMonthlyCost,

    /// Currency code
    @Default('USD') String currency,
  }) = _ModelCostInfo;

  factory ModelCostInfo.fromJson(Map<String, dynamic> json) =>
      _$ModelCostInfoFromJson(json);
}

/// Cost tier classification
enum CostTier {
  economy,
  standard,
  premium,
  enterprise,
}

/// Model deprecation information
@freezed
class ModelDeprecationInfo with _$ModelDeprecationInfo {
  const factory ModelDeprecationInfo({
    /// Deprecation announcement date
    required DateTime announcedAt,

    /// Planned end-of-life date
    required DateTime endOfLifeDate,

    /// Recommended replacement model version
    String? replacementVersion,

    /// Deprecation reason
    required String reason,

    /// Migration guide URL
    String? migrationGuideUrl,

    /// Grace period (days)
    @Default(90) int gracePeriodDays,

    /// Whether to allow new deployments
    @Default(false) bool allowNewDeployments,
  }) = _ModelDeprecationInfo;

  factory ModelDeprecationInfo.fromJson(Map<String, dynamic> json) =>
      _$ModelDeprecationInfoFromJson(json);
}

/// Extension methods for ModelVersion
extension ModelVersionX on ModelVersion {
  /// Whether the model is currently usable
  bool get isUsable =>
      status == ModelStatus.active ||
      status == ModelStatus.canary ||
      status == ModelStatus.testing;

  /// Whether the model is deprecated
  bool get isDeprecated => status == ModelStatus.deprecated;

  /// Whether the model is retired
  bool get isRetired => status == ModelStatus.retired;

  /// Days until end of life (if deprecated)
  int? get daysUntilEol {
    if (deprecation == null) return null;
    return deprecation!.endOfLifeDate.difference(DateTime.now()).inDays;
  }

  /// Whether the model meets performance thresholds
  bool get meetsPerformanceThresholds {
    if (metrics == null) return true;

    return metrics!.successRate >= successRateThreshold &&
        (maxLatencyMs == null || metrics!.p95LatencyMs <= maxLatencyMs!) &&
        metrics!.avgConfidence >= minConfidenceThreshold;
  }

  /// Estimated cost for given token counts
  double estimateCost(int inputTokens, int outputTokens) {
    final inputCost = (inputTokens / 1000) * costInfo.inputCostPer1k;
    final outputCost = (outputTokens / 1000) * costInfo.outputCostPer1k;
    return inputCost + outputCost;
  }
}
