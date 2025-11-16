// ABOUTME: Example usage of the Model Lifecycle Management system
// ABOUTME: Demonstrates integration with existing AI services

import 'package:flutter/foundation.dart';

import 'model_version.dart';
import 'model_lifecycle_manager.dart';
import 'model_evaluator.dart';
import '../ai_providers/base_provider.dart';
import '../../core/utils/logging_service.dart';

/// Example: Integrating Model Lifecycle Management with AI Providers
class ModelLifecycleExample {
  final ModelLifecycleManager lifecycleManager;
  final LoggingService logger;

  ModelLifecycleExample({
    required this.lifecycleManager,
    required this.logger,
  });

  /// Initialize the lifecycle management system
  Future<void> initialize() async {
    await lifecycleManager.initialize(
      evaluationConfig: EvaluationConfig(
        metricsUpdateInterval: 100,
        minSamplesForEvaluation: 50,
        maxErrorRate: 0.05,
        minSuccessRate: 0.95,
        maxLatencyMs: 5000,
        minConfidence: 0.7,
      ),
      policyConfig: PolicyConfig(
        enforcePerformanceThresholds: true,
        deprecateOldVersionsOnNewDeployment: true,
        enableAutomaticRetirement: true,
        defaultGracePeriodDays: 90,
        eolWarningThresholdDays: 30,
        maxCostPerRequest: 0.10,
      ),
    );

    logger.log('Example', 'Lifecycle manager initialized', LogLevel.info);
  }

  /// Example 1: Register and deploy a new model
  Future<void> deployNewModel() async {
    // Create model version
    final newModel = ModelVersion(
      version: '2.0.0',
      modelId: 'gpt-4-turbo-preview',
      provider: 'OpenAI',
      displayName: 'GPT-4 Turbo (Preview)',
      description: 'Latest GPT-4 model with improved performance',
      releaseDate: DateTime.now(),
      status: ModelStatus.testing,
      capabilities: const ModelCapabilities(
        supportsStreaming: true,
        supportsFunctionCalling: true,
        supportsVision: false,
        supportsAudioTranscription: false,
        maxContextTokens: 128000,
        maxOutputTokens: 4096,
        supportedAnalysisTypes: [
          'factCheck',
          'summary',
          'sentiment',
          'actionItems',
        ],
      ),
      costInfo: const ModelCostInfo(
        inputCostPer1k: 0.01,
        outputCostPer1k: 0.03,
        tier: CostTier.premium,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      releaseNotes: 'Improved reasoning, faster responses, better accuracy',
      tags: ['llm', 'openai', 'gpt-4', 'production'],
      minConfidenceThreshold: 0.75,
      maxLatencyMs: 3000,
      successRateThreshold: 0.97,
    );

    // Register the model
    await lifecycleManager.registerModel(newModel);
    logger.log('Example', 'Registered new model: ${newModel.modelId} ${newModel.version}',
        LogLevel.info);

    // Check deployment approval
    final decision = await lifecycleManager.canDeployModel(
      modelId: newModel.modelId,
      version: newModel.version,
    );

    if (!decision.approved) {
      logger.log('Example', 'Deployment rejected: ${decision.reason}', LogLevel.error);
      return;
    }

    // Activate the model
    await lifecycleManager.activateModel(newModel.modelId, newModel.version);
    logger.log('Example', 'Activated model: ${newModel.modelId} ${newModel.version}',
        LogLevel.info);
  }

  /// Example 2: Track inference performance
  Future<void> trackInferencePerformance({
    required String modelId,
    required String version,
    required String prompt,
    required String response,
    required int inputTokens,
    required int outputTokens,
    required Duration duration,
    double? confidence,
    bool success = true,
  }) async {
    // Record the inference result
    await lifecycleManager.recordInference(
      modelId: modelId,
      version: version,
      result: InferenceResult(
        success: success,
        latencyMs: duration.inMilliseconds.toDouble(),
        confidence: confidence,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      ),
    );

    logger.log(
      'Example',
      'Recorded inference: $modelId $version - ${duration.inMilliseconds}ms',
      LogLevel.debug,
    );
  }

  /// Example 3: Evaluate model and check thresholds
  Future<void> evaluateModelPerformance(String modelId, String version) async {
    final report = await lifecycleManager.evaluateModel(
      modelId: modelId,
      version: version,
    );

    logger.log('Example', 'Evaluation status: ${report.status.name}', LogLevel.info);
    logger.log('Example', 'Sample size: ${report.sampleSize}', LogLevel.info);
    logger.log(
      'Example',
      'Success rate: ${(report.metrics.successRate * 100).toStringAsFixed(2)}%',
      LogLevel.info,
    );
    logger.log(
      'Example',
      'Avg latency: ${report.metrics.avgLatencyMs.toStringAsFixed(0)}ms',
      LogLevel.info,
    );

    if (report.status != EvaluationStatus.passed) {
      logger.log('Example', 'Evaluation warnings:', LogLevel.warning);

      for (final recommendation in report.recommendations) {
        logger.log('Example', '  - $recommendation', LogLevel.warning);
      }
    }

    // Check failed thresholds
    final failedThresholds =
        report.thresholdResults.where((r) => !r.passed).toList();

    if (failedThresholds.isNotEmpty) {
      logger.log('Example', 'Failed thresholds:', LogLevel.error);

      for (final threshold in failedThresholds) {
        logger.log(
          'Example',
          '  - ${threshold.name}: ${threshold.actualValue.toStringAsFixed(2)} (threshold: ${threshold.threshold})',
          LogLevel.error,
        );
      }
    }
  }

  /// Example 4: Rollback to previous version
  Future<void> performRollback(String modelId) async {
    // Get current active version
    final currentVersion = lifecycleManager.getActiveModel(modelId);

    if (currentVersion == null) {
      logger.log('Example', 'No active version found for $modelId', LogLevel.error);
      return;
    }

    logger.log(
      'Example',
      'Current version: ${currentVersion.version}',
      LogLevel.info,
    );

    // Get all versions
    final versions = lifecycleManager.getModelVersions(modelId);

    // Find previous stable version
    final previousVersions = versions
        .where((v) =>
            v.version != currentVersion.version &&
            v.meetsPerformanceThresholds)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (previousVersions.isEmpty) {
      logger.log('Example', 'No previous stable version available', LogLevel.error);
      return;
    }

    final rollbackTarget = previousVersions.first;

    logger.log(
      'Example',
      'Rolling back to version: ${rollbackTarget.version}',
      LogLevel.warning,
    );

    // Perform rollback
    await lifecycleManager.rollbackModel(modelId, rollbackTarget.version);

    logger.log(
      'Example',
      'Rollback completed: $modelId ${rollbackTarget.version}',
      LogLevel.info,
    );
  }

  /// Example 5: Monitor deprecation warnings
  Future<void> checkDeprecationWarnings() async {
    final warnings = await lifecycleManager.getDeprecationWarnings();

    if (warnings.isEmpty) {
      logger.log('Example', 'No deprecation warnings', LogLevel.info);
      return;
    }

    logger.log('Example', 'Found ${warnings.length} deprecation warnings:', LogLevel.warning);

    for (final warning in warnings) {
      final severity = warning.severity.name.toUpperCase();
      final daysLeft = warning.daysUntilEol;
      final replacement = warning.replacementVersion ?? 'TBD';

      logger.log(
        'Example',
        '[$severity] ${warning.modelId} ${warning.version} - EOL in $daysLeft days (replace with: $replacement)',
        LogLevel.warning,
      );

      // Take action based on severity
      if (warning.severity == WarningSeverity.critical) {
        // Less than 7 days - urgent action required
        await _sendUrgentNotification(warning);
      } else if (warning.severity == WarningSeverity.high) {
        // Less than 30 days - plan migration
        await _planMigration(warning);
      }
    }
  }

  /// Example 6: Generate compliance report
  Future<void> generateMonthlyReport() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final report = await lifecycleManager.generateComplianceReport(
      startDate: startOfMonth,
      endDate: endOfMonth,
    );

    logger.log('Example', '=== Monthly Compliance Report ===', LogLevel.info);
    logger.log('Example', 'Period: ${startOfMonth.toIso8601String()} to ${endOfMonth.toIso8601String()}',
        LogLevel.info);
    logger.log('Example', 'Total events: ${report.totalEvents}', LogLevel.info);
    logger.log('Example', 'Critical events: ${report.criticalEvents}', LogLevel.info);
    logger.log('Example', 'Errors: ${report.errors}', LogLevel.info);

    logger.log('Example', '\nModel activity:', LogLevel.info);
    report.modelActivity.forEach((modelId, count) {
      logger.log('Example', '  $modelId: $count events', LogLevel.info);
    });

    logger.log('Example', '\nAction breakdown:', LogLevel.info);
    report.actionCounts.forEach((action, count) {
      logger.log('Example', '  ${action.name}: $count', LogLevel.info);
    });
  }

  /// Example 7: Compare two model versions
  Future<void> compareModelVersions(
    String modelId,
    String versionA,
    String versionB,
  ) async {
    final comparison = await lifecycleManager.compareVersions(
      modelId: modelId,
      versionA: versionA,
      versionB: versionB,
    );

    logger.log('Example', '=== Version Comparison ===', LogLevel.info);
    logger.log('Example', 'Model: $modelId', LogLevel.info);
    logger.log('Example', 'Version A: $versionA', LogLevel.info);
    logger.log('Example', 'Version B: $versionB', LogLevel.info);
    logger.log('Example', 'Winner: ${comparison.winner.name}', LogLevel.info);

    logger.log('Example', '\nVersion A metrics:', LogLevel.info);
    _logMetrics(comparison.metricsA);

    logger.log('Example', '\nVersion B metrics:', LogLevel.info);
    _logMetrics(comparison.metricsB);
  }

  /// Example 8: Export audit log
  Future<void> exportAuditHistory(String outputPath) async {
    final jsonExport = await lifecycleManager.exportAuditLog(
      startDate: DateTime(2024, 1, 1),
      endDate: DateTime.now(),
    );

    logger.log('Example', 'Exported audit log to: $outputPath', LogLevel.info);
    logger.log('Example', 'Size: ${jsonExport.length} bytes', LogLevel.info);

    // In production, save to file:
    // await File(outputPath).writeAsString(jsonExport);
  }

  /// Example 9: Listen to real-time alerts
  void setupAlertMonitoring() {
    lifecycleManager.evaluator.alerts.listen((alert) {
      final severity = alert.severity.name.toUpperCase();

      logger.log(
        'Example',
        '[$severity] ${alert.modelId} ${alert.version}: ${alert.message}',
        _alertSeverityToLogLevel(alert.severity),
      );

      if (alert.violations.isNotEmpty) {
        logger.log('Example', 'Violations:', LogLevel.warning);
        for (final violation in alert.violations) {
          logger.log('Example', '  - $violation', LogLevel.warning);
        }
      }

      // Take automated action on critical alerts
      if (alert.severity == AlertSeverity.critical) {
        _handleCriticalAlert(alert);
      }
    });

    logger.log('Example', 'Alert monitoring enabled', LogLevel.info);
  }

  /// Example 10: Get system status
  Future<void> checkSystemStatus() async {
    final status = await lifecycleManager.getSystemStatus();

    logger.log('Example', '=== System Status ===', LogLevel.info);
    logger.log('Example', 'Health: ${status.isHealthy ? "✅ Healthy" : "❌ Unhealthy"}',
        LogLevel.info);
    logger.log('Example', 'Active models: ${status.activeModelCount}', LogLevel.info);
    logger.log('Example', 'Deprecated models: ${status.deprecatedModelCount}', LogLevel.info);
    logger.log('Example', 'Pending warnings: ${status.pendingWarningsCount}', LogLevel.info);
    logger.log('Example', 'Recent audit entries: ${status.recentAuditCount}', LogLevel.info);
  }

  // Helper methods

  void _logMetrics(ModelPerformanceMetrics metrics) {
    logger.log('Example', '  Avg latency: ${metrics.avgLatencyMs.toStringAsFixed(0)}ms',
        LogLevel.info);
    logger.log('Example', '  P95 latency: ${metrics.p95LatencyMs.toStringAsFixed(0)}ms',
        LogLevel.info);
    logger.log(
      'Example',
      '  Success rate: ${(metrics.successRate * 100).toStringAsFixed(2)}%',
      LogLevel.info,
    );
    logger.log(
      'Example',
      '  Avg confidence: ${metrics.avgConfidence.toStringAsFixed(2)}',
      LogLevel.info,
    );
  }

  LogLevel _alertSeverityToLogLevel(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return LogLevel.info;
      case AlertSeverity.warning:
        return LogLevel.warning;
      case AlertSeverity.error:
      case AlertSeverity.critical:
        return LogLevel.error;
    }
  }

  Future<void> _sendUrgentNotification(DeprecationWarning warning) async {
    // Implementation: Send notification to ops team
    logger.log(
      'Example',
      'URGENT: ${warning.modelId} ${warning.version} EOL in ${warning.daysUntilEol} days!',
      LogLevel.error,
    );
  }

  Future<void> _planMigration(DeprecationWarning warning) async {
    // Implementation: Create migration plan
    logger.log(
      'Example',
      'Planning migration: ${warning.modelId} ${warning.version} → ${warning.replacementVersion}',
      LogLevel.warning,
    );
  }

  Future<void> _handleCriticalAlert(EvaluationAlert alert) async {
    // Implementation: Automated response to critical alerts
    logger.log(
      'Example',
      'Handling critical alert for ${alert.modelId} ${alert.version}',
      LogLevel.error,
    );

    // Could trigger automatic rollback here
    // await performRollback(alert.modelId);
  }
}

/// Main example runner
Future<void> runExamples() async {
  final logger = LoggingService();
  final lifecycleManager = ModelLifecycleManager(logger: logger);

  final example = ModelLifecycleExample(
    lifecycleManager: lifecycleManager,
    logger: logger,
  );

  try {
    // Initialize
    await example.initialize();

    // Run examples
    await example.deployNewModel();
    await example.checkSystemStatus();
    await example.checkDeprecationWarnings();
    example.setupAlertMonitoring();

    // Simulate some inferences
    for (var i = 0; i < 100; i++) {
      await example.trackInferencePerformance(
        modelId: 'gpt-4-turbo-preview',
        version: '2.0.0',
        prompt: 'Test prompt',
        response: 'Test response',
        inputTokens: 100,
        outputTokens: 50,
        duration: Duration(milliseconds: 1000 + (i * 10)),
        confidence: 0.85 + (i % 10) * 0.01,
      );
    }

    // Evaluate performance
    await example.evaluateModelPerformance('gpt-4-turbo-preview', '2.0.0');

    // Generate reports
    await example.generateMonthlyReport();

    // Export audit log
    await example.exportAuditHistory('/tmp/audit_log.json');
  } catch (e) {
    logger.log('Example', 'Error running examples: $e', LogLevel.error);
  } finally {
    await lifecycleManager.dispose();
  }
}
