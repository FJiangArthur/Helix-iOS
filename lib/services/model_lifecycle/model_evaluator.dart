// ABOUTME: Model evaluation and performance monitoring system
// ABOUTME: Tracks model quality, enforces thresholds, and triggers alerts

import 'dart:async';
import 'dart:math' as math;

import 'model_version.dart';
import 'model_registry.dart';
import 'model_audit_log.dart';
import '../../core/utils/logging_service.dart';

/// Model evaluator for quality assurance and performance monitoring
class ModelEvaluator {
  static const String _tag = 'ModelEvaluator';

  final LoggingService _logger;
  final ModelRegistry _registry;
  final ModelAuditLog _auditLog;

  /// Evaluation configuration
  EvaluationConfig _config = const EvaluationConfig();

  /// Performance tracking for active models
  final Map<String, PerformanceTracker> _trackers = {};

  /// Stream controller for evaluation alerts
  final _alertController = StreamController<EvaluationAlert>.broadcast();

  ModelEvaluator({
    required LoggingService logger,
    required ModelRegistry registry,
    required ModelAuditLog auditLog,
  })  : _logger = logger,
        _registry = registry,
        _auditLog = auditLog;

  /// Stream of evaluation alerts
  Stream<EvaluationAlert> get alerts => _alertController.stream;

  /// Initialize the evaluator
  Future<void> initialize({EvaluationConfig? config}) async {
    try {
      _logger.log(_tag, 'Initializing model evaluator', LogLevel.info);

      if (config != null) {
        _config = config;
      }

      // Initialize trackers for active models
      final activeVersions = _registry.getActiveVersions();
      for (final entry in activeVersions.entries) {
        _trackers[entry.key] = PerformanceTracker(
          modelId: entry.key,
          version: entry.value.version,
        );
      }

      _logger.log(_tag, 'Model evaluator initialized successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize evaluator: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Record a model inference result
  Future<void> recordInference({
    required String modelId,
    required String version,
    required InferenceResult result,
  }) async {
    try {
      // Get or create tracker
      final tracker = _trackers.putIfAbsent(
        modelId,
        () => PerformanceTracker(modelId: modelId, version: version),
      );

      // Record result
      tracker.recordResult(result);

      // Check if we should update metrics
      if (tracker.resultCount % _config.metricsUpdateInterval == 0) {
        await _updateModelMetrics(modelId, version, tracker);
      }

      // Check for threshold violations
      await _checkThresholds(modelId, version, tracker);
    } catch (e) {
      _logger.log(_tag, 'Failed to record inference: $e', LogLevel.error);
    }
  }

  /// Evaluate a model version
  Future<EvaluationReport> evaluateModel({
    required String modelId,
    required String version,
    EvaluationDataset? dataset,
  }) async {
    try {
      _logger.log(_tag, 'Evaluating $modelId version $version', LogLevel.info);

      final modelVersion = _registry.getVersion(modelId, version);
      if (modelVersion == null) {
        throw ArgumentError('Model version not found: $modelId $version');
      }

      final tracker = _trackers[modelId];
      if (tracker == null || tracker.resultCount < _config.minSamplesForEvaluation) {
        throw StateError(
            'Insufficient data for evaluation (minimum ${_config.minSamplesForEvaluation} samples required)');
      }

      // Calculate metrics
      final metrics = tracker.calculateMetrics();

      // Evaluate against thresholds
      final thresholdResults = _evaluateThresholds(modelVersion, metrics);

      // Determine overall status
      final status = _determineEvaluationStatus(thresholdResults);

      // Create report
      final report = EvaluationReport(
        modelId: modelId,
        version: version,
        timestamp: DateTime.now(),
        metrics: metrics,
        thresholdResults: thresholdResults,
        status: status,
        recommendations: _generateRecommendations(modelVersion, metrics, thresholdResults),
        sampleSize: tracker.resultCount,
      );

      // Log evaluation
      await _auditLog.logEvent(
        action: status == EvaluationStatus.passed
            ? AuditAction.metricsUpdated
            : AuditAction.qualityDegraded,
        modelId: modelId,
        version: version,
        severity: status == EvaluationStatus.failed
            ? AuditSeverity.error
            : AuditSeverity.info,
        metadata: {
          'status': status.name,
          'passedThresholds': thresholdResults.where((r) => r.passed).length,
          'failedThresholds': thresholdResults.where((r) => !r.passed).length,
          'avgLatency': metrics.avgLatencyMs,
          'successRate': metrics.successRate,
          'avgConfidence': metrics.avgConfidence,
        },
      );

      _logger.log(_tag, 'Evaluation completed: $status', LogLevel.info);
      return report;
    } catch (e) {
      _logger.log(_tag, 'Model evaluation failed: $e', LogLevel.error);

      await _auditLog.logEvent(
        action: AuditAction.evaluationFailed,
        modelId: modelId,
        version: version,
        severity: AuditSeverity.error,
        metadata: {'error': e.toString()},
      );

      rethrow;
    }
  }

  /// Check if a model meets deployment criteria
  Future<bool> canDeploy({
    required String modelId,
    required String version,
  }) async {
    try {
      final report = await evaluateModel(
        modelId: modelId,
        version: version,
      );

      return report.status == EvaluationStatus.passed;
    } catch (e) {
      _logger.log(_tag, 'Deployment check failed: $e', LogLevel.error);
      return false;
    }
  }

  /// Compare two model versions
  Future<ComparisonReport> compareVersions({
    required String modelId,
    required String versionA,
    required String versionB,
  }) async {
    try {
      final trackerA = _trackers[modelId];
      if (trackerA == null || trackerA.version != versionA) {
        throw StateError('No performance data for $modelId $versionA');
      }

      // For comparison, we'd need separate trackers for each version
      // This is a simplified implementation
      final metricsA = trackerA.calculateMetrics();

      return ComparisonReport(
        modelId: modelId,
        versionA: versionA,
        versionB: versionB,
        timestamp: DateTime.now(),
        metricsA: metricsA,
        metricsB: metricsA, // Placeholder - would need actual data
        winner: VersionComparison.equivalent,
        differences: {},
      );
    } catch (e) {
      _logger.log(_tag, 'Version comparison failed: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Update evaluation configuration
  void updateConfig(EvaluationConfig config) {
    _logger.log(_tag, 'Updating evaluation configuration', LogLevel.info);
    _config = config;
  }

  // Private helper methods

  Future<void> _updateModelMetrics(
    String modelId,
    String version,
    PerformanceTracker tracker,
  ) async {
    try {
      final metrics = tracker.calculateMetrics();

      await _registry.updateMetrics(modelId, version, metrics);

      _logger.log(
        _tag,
        'Updated metrics for $modelId $version: ${metrics.successRate.toStringAsFixed(2)} success rate',
        LogLevel.debug,
      );
    } catch (e) {
      _logger.log(_tag, 'Failed to update metrics: $e', LogLevel.error);
    }
  }

  Future<void> _checkThresholds(
    String modelId,
    String version,
    PerformanceTracker tracker,
  ) async {
    if (tracker.resultCount < _config.minSamplesForEvaluation) {
      return; // Not enough data
    }

    final modelVersion = _registry.getVersion(modelId, version);
    if (modelVersion == null) return;

    final metrics = tracker.calculateMetrics();
    final violations = <String>[];

    // Check success rate threshold
    if (metrics.successRate < modelVersion.successRateThreshold) {
      violations.add(
          'Success rate ${metrics.successRate.toStringAsFixed(2)} below threshold ${modelVersion.successRateThreshold}');
    }

    // Check latency threshold
    if (modelVersion.maxLatencyMs != null &&
        metrics.p95LatencyMs > modelVersion.maxLatencyMs!) {
      violations.add(
          'P95 latency ${metrics.p95LatencyMs.toStringAsFixed(0)}ms exceeds threshold ${modelVersion.maxLatencyMs}ms');
    }

    // Check confidence threshold
    if (metrics.avgConfidence < modelVersion.minConfidenceThreshold) {
      violations.add(
          'Average confidence ${metrics.avgConfidence.toStringAsFixed(2)} below threshold ${modelVersion.minConfidenceThreshold}');
    }

    // Emit alerts for violations
    if (violations.isNotEmpty) {
      final alert = EvaluationAlert(
        modelId: modelId,
        version: version,
        timestamp: DateTime.now(),
        severity: AlertSeverity.warning,
        message: 'Performance threshold violations detected',
        violations: violations,
        metrics: metrics,
      );

      _alertController.add(alert);

      await _auditLog.logEvent(
        action: AuditAction.performanceThresholdViolation,
        modelId: modelId,
        version: version,
        severity: AuditSeverity.warning,
        metadata: {
          'violations': violations,
          'successRate': metrics.successRate,
          'avgLatency': metrics.avgLatencyMs,
          'avgConfidence': metrics.avgConfidence,
        },
      );
    }
  }

  List<ThresholdResult> _evaluateThresholds(
    ModelVersion model,
    ModelPerformanceMetrics metrics,
  ) {
    final results = <ThresholdResult>[];

    // Success rate threshold
    results.add(ThresholdResult(
      name: 'Success Rate',
      actualValue: metrics.successRate,
      threshold: model.successRateThreshold,
      passed: metrics.successRate >= model.successRateThreshold,
      severity: ThresholdSeverity.critical,
    ));

    // Latency threshold
    if (model.maxLatencyMs != null) {
      results.add(ThresholdResult(
        name: 'P95 Latency',
        actualValue: metrics.p95LatencyMs,
        threshold: model.maxLatencyMs!.toDouble(),
        passed: metrics.p95LatencyMs <= model.maxLatencyMs!,
        severity: ThresholdSeverity.high,
      ));
    }

    // Confidence threshold
    results.add(ThresholdResult(
      name: 'Average Confidence',
      actualValue: metrics.avgConfidence,
      threshold: model.minConfidenceThreshold,
      passed: metrics.avgConfidence >= model.minConfidenceThreshold,
      severity: ThresholdSeverity.medium,
    ));

    // Error rate threshold
    results.add(ThresholdResult(
      name: 'Error Rate',
      actualValue: metrics.errorRate,
      threshold: _config.maxErrorRate,
      passed: metrics.errorRate <= _config.maxErrorRate,
      severity: ThresholdSeverity.critical,
    ));

    return results;
  }

  EvaluationStatus _determineEvaluationStatus(List<ThresholdResult> results) {
    final criticalFailed =
        results.any((r) => !r.passed && r.severity == ThresholdSeverity.critical);
    final highFailed =
        results.any((r) => !r.passed && r.severity == ThresholdSeverity.high);
    final anyFailed = results.any((r) => !r.passed);

    if (criticalFailed) {
      return EvaluationStatus.failed;
    } else if (highFailed) {
      return EvaluationStatus.warning;
    } else if (anyFailed) {
      return EvaluationStatus.warning;
    } else {
      return EvaluationStatus.passed;
    }
  }

  List<String> _generateRecommendations(
    ModelVersion model,
    ModelPerformanceMetrics metrics,
    List<ThresholdResult> thresholdResults,
  ) {
    final recommendations = <String>[];

    // Check for failed thresholds
    for (final result in thresholdResults.where((r) => !r.passed)) {
      if (result.name == 'Success Rate') {
        recommendations.add(
            'Success rate is below threshold. Consider rolling back to a previous version or investigating recent changes.');
      } else if (result.name == 'P95 Latency') {
        recommendations.add(
            'Latency is above acceptable levels. Review model complexity or infrastructure capacity.');
      } else if (result.name == 'Average Confidence') {
        recommendations.add(
            'Model confidence is low. Consider retraining or using a more capable model.');
      } else if (result.name == 'Error Rate') {
        recommendations.add(
            'Error rate is too high. Investigate error patterns and root causes.');
      }
    }

    // Check for deprecation
    if (model.isDeprecated && model.daysUntilEol != null) {
      if (model.daysUntilEol! <= 30) {
        recommendations.add(
            'Model will reach end-of-life in ${model.daysUntilEol} days. Plan migration to ${model.deprecation?.replacementVersion ?? "a newer version"}.');
      }
    }

    // Cost optimization
    if (metrics.costPer1kRequests != null &&
        model.costInfo.tier == CostTier.premium) {
      recommendations.add(
          'Consider evaluating economy tier models if performance requirements allow for cost optimization.');
    }

    return recommendations;
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _alertController.close();
  }
}

/// Performance tracker for a model
class PerformanceTracker {
  final String modelId;
  final String version;

  final List<InferenceResult> _results = [];
  final List<double> _latencies = [];
  final List<double> _confidences = [];

  int _successCount = 0;
  int _failureCount = 0;

  PerformanceTracker({
    required this.modelId,
    required this.version,
  });

  int get resultCount => _results.length;

  void recordResult(InferenceResult result) {
    _results.add(result);
    _latencies.add(result.latencyMs);

    if (result.confidence != null) {
      _confidences.add(result.confidence!);
    }

    if (result.success) {
      _successCount++;
    } else {
      _failureCount++;
    }

    // Keep only recent results to manage memory
    if (_results.length > 10000) {
      _results.removeAt(0);
      _latencies.removeAt(0);
      if (_confidences.isNotEmpty) _confidences.removeAt(0);
    }
  }

  ModelPerformanceMetrics calculateMetrics() {
    if (_results.isEmpty) {
      return ModelPerformanceMetrics(
        avgLatencyMs: 0,
        p95LatencyMs: 0,
        p99LatencyMs: 0,
        successRate: 0,
        errorRate: 0,
        avgConfidence: 0,
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        lastUpdated: DateTime.now(),
      );
    }

    final sortedLatencies = List<double>.from(_latencies)..sort();
    final p95Index = (sortedLatencies.length * 0.95).floor();
    final p99Index = (sortedLatencies.length * 0.99).floor();

    final totalRequests = _results.length;
    final successRate = _successCount / totalRequests;
    final errorRate = _failureCount / totalRequests;

    return ModelPerformanceMetrics(
      avgLatencyMs: _latencies.reduce((a, b) => a + b) / _latencies.length,
      p95LatencyMs: sortedLatencies[p95Index],
      p99LatencyMs: sortedLatencies[p99Index],
      successRate: successRate,
      errorRate: errorRate,
      avgConfidence: _confidences.isEmpty
          ? 0
          : _confidences.reduce((a, b) => a + b) / _confidences.length,
      totalRequests: totalRequests,
      successfulRequests: _successCount,
      failedRequests: _failureCount,
      lastUpdated: DateTime.now(),
    );
  }
}

/// Inference result
class InferenceResult {
  final bool success;
  final double latencyMs;
  final double? confidence;
  final String? error;
  final int? inputTokens;
  final int? outputTokens;

  InferenceResult({
    required this.success,
    required this.latencyMs,
    this.confidence,
    this.error,
    this.inputTokens,
    this.outputTokens,
  });
}

/// Evaluation configuration
class EvaluationConfig {
  final int metricsUpdateInterval;
  final int minSamplesForEvaluation;
  final double maxErrorRate;
  final double minSuccessRate;
  final int maxLatencyMs;
  final double minConfidence;

  const EvaluationConfig({
    this.metricsUpdateInterval = 100,
    this.minSamplesForEvaluation = 50,
    this.maxErrorRate = 0.05,
    this.minSuccessRate = 0.95,
    this.maxLatencyMs = 5000,
    this.minConfidence = 0.7,
  });
}

/// Evaluation report
class EvaluationReport {
  final String modelId;
  final String version;
  final DateTime timestamp;
  final ModelPerformanceMetrics metrics;
  final List<ThresholdResult> thresholdResults;
  final EvaluationStatus status;
  final List<String> recommendations;
  final int sampleSize;

  EvaluationReport({
    required this.modelId,
    required this.version,
    required this.timestamp,
    required this.metrics,
    required this.thresholdResults,
    required this.status,
    required this.recommendations,
    required this.sampleSize,
  });

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'version': version,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'sampleSize': sampleSize,
        'metrics': {
          'avgLatencyMs': metrics.avgLatencyMs,
          'p95LatencyMs': metrics.p95LatencyMs,
          'successRate': metrics.successRate,
          'errorRate': metrics.errorRate,
          'avgConfidence': metrics.avgConfidence,
        },
        'thresholdResults': thresholdResults.map((r) => r.toJson()).toList(),
        'recommendations': recommendations,
      };
}

/// Threshold evaluation result
class ThresholdResult {
  final String name;
  final double actualValue;
  final double threshold;
  final bool passed;
  final ThresholdSeverity severity;

  ThresholdResult({
    required this.name,
    required this.actualValue,
    required this.threshold,
    required this.passed,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'actualValue': actualValue,
        'threshold': threshold,
        'passed': passed,
        'severity': severity.name,
      };
}

enum ThresholdSeverity {
  low,
  medium,
  high,
  critical,
}

enum EvaluationStatus {
  passed,
  warning,
  failed,
}

/// Evaluation alert
class EvaluationAlert {
  final String modelId;
  final String version;
  final DateTime timestamp;
  final AlertSeverity severity;
  final String message;
  final List<String> violations;
  final ModelPerformanceMetrics metrics;

  EvaluationAlert({
    required this.modelId,
    required this.version,
    required this.timestamp,
    required this.severity,
    required this.message,
    required this.violations,
    required this.metrics,
  });
}

enum AlertSeverity {
  info,
  warning,
  error,
  critical,
}

/// Version comparison report
class ComparisonReport {
  final String modelId;
  final String versionA;
  final String versionB;
  final DateTime timestamp;
  final ModelPerformanceMetrics metricsA;
  final ModelPerformanceMetrics metricsB;
  final VersionComparison winner;
  final Map<String, double> differences;

  ComparisonReport({
    required this.modelId,
    required this.versionA,
    required this.versionB,
    required this.timestamp,
    required this.metricsA,
    required this.metricsB,
    required this.winner,
    required this.differences,
  });
}

enum VersionComparison {
  versionA,
  versionB,
  equivalent,
}

/// Evaluation dataset
class EvaluationDataset {
  final String name;
  final List<EvaluationSample> samples;

  EvaluationDataset({
    required this.name,
    required this.samples,
  });
}

class EvaluationSample {
  final String input;
  final String? expectedOutput;
  final Map<String, dynamic>? metadata;

  EvaluationSample({
    required this.input,
    this.expectedOutput,
    this.metadata,
  });
}
