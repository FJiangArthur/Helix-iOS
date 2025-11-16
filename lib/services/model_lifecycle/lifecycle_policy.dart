// ABOUTME: Model lifecycle policy definitions and enforcement
// ABOUTME: Defines rules for deployment, deprecation, and retirement

import 'dart:async';

import 'model_version.dart';
import 'model_registry.dart';
import 'model_audit_log.dart';
import 'model_evaluator.dart';
import '../../core/utils/logging_service.dart';

/// Lifecycle policy manager
class LifecyclePolicy {
  static const String _tag = 'LifecyclePolicy';

  final LoggingService _logger;
  final ModelRegistry _registry;
  final ModelAuditLog _auditLog;
  final ModelEvaluator _evaluator;

  /// Policy configuration
  PolicyConfig _config = const PolicyConfig();

  /// Scheduled tasks
  Timer? _deprecationCheckTimer;
  Timer? _retirementCheckTimer;

  LifecyclePolicy({
    required LoggingService logger,
    required ModelRegistry registry,
    required ModelAuditLog auditLog,
    required ModelEvaluator evaluator,
  })  : _logger = logger,
        _registry = registry,
        _auditLog = auditLog,
        _evaluator = evaluator;

  /// Initialize lifecycle policy enforcement
  Future<void> initialize({PolicyConfig? config}) async {
    try {
      _logger.log(_tag, 'Initializing lifecycle policy', LogLevel.info);

      if (config != null) {
        _config = config;
      }

      // Start scheduled checks
      if (_config.enableAutomaticDeprecation) {
        _startDeprecationChecks();
      }

      if (_config.enableAutomaticRetirement) {
        _startRetirementChecks();
      }

      _logger.log(_tag, 'Lifecycle policy initialized', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize policy: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Check if a model version can be deployed
  Future<DeploymentDecision> canDeploy({
    required String modelId,
    required String version,
  }) async {
    try {
      _logger.log(_tag, 'Evaluating deployment for $modelId $version', LogLevel.info);

      final modelVersion = _registry.getVersion(modelId, version);
      if (modelVersion == null) {
        return DeploymentDecision(
          approved: false,
          reason: 'Model version not found',
          severity: DecisionSeverity.error,
        );
      }

      // Check if model is retired
      if (modelVersion.isRetired) {
        return DeploymentDecision(
          approved: false,
          reason: 'Model version is retired',
          severity: DecisionSeverity.error,
        );
      }

      // Check if model is deprecated and new deployments are disallowed
      if (modelVersion.isDeprecated &&
          modelVersion.deprecation?.allowNewDeployments == false) {
        return DeploymentDecision(
          approved: false,
          reason: 'Model is deprecated and new deployments are not allowed',
          severity: DecisionSeverity.error,
          replacement: modelVersion.deprecation?.replacementVersion,
        );
      }

      // Check performance thresholds
      if (_config.enforcePerformanceThresholds) {
        final meetsThresholds = await _evaluator.canDeploy(
          modelId: modelId,
          version: version,
        );

        if (!meetsThresholds) {
          return DeploymentDecision(
            approved: false,
            reason: 'Model does not meet performance thresholds',
            severity: DecisionSeverity.error,
          );
        }
      }

      // Check cost constraints
      if (_config.maxCostPerRequest != null) {
        final estimatedCost =
            modelVersion.estimateCost(1000, 500); // Example token counts
        if (estimatedCost > _config.maxCostPerRequest!) {
          return DeploymentDecision(
            approved: false,
            reason:
                'Model cost exceeds maximum allowed (${estimatedCost.toStringAsFixed(4)} > ${_config.maxCostPerRequest})',
            severity: DecisionSeverity.warning,
          );
        }
      }

      // Warn if deprecated but allowed
      if (modelVersion.isDeprecated) {
        return DeploymentDecision(
          approved: true,
          reason:
              'Model is deprecated but deployments are still allowed. Consider migrating to ${modelVersion.deprecation?.replacementVersion ?? "a newer version"}.',
          severity: DecisionSeverity.warning,
          replacement: modelVersion.deprecation?.replacementVersion,
        );
      }

      // All checks passed
      return DeploymentDecision(
        approved: true,
        reason: 'All deployment criteria met',
        severity: DecisionSeverity.info,
      );
    } catch (e) {
      _logger.log(_tag, 'Deployment check failed: $e', LogLevel.error);
      return DeploymentDecision(
        approved: false,
        reason: 'Deployment check failed: $e',
        severity: DecisionSeverity.error,
      );
    }
  }

  /// Automatically deprecate old versions when a new version is deployed
  Future<void> handleNewVersionDeployment({
    required String modelId,
    required String newVersion,
  }) async {
    try {
      if (!_config.deprecateOldVersionsOnNewDeployment) {
        return;
      }

      _logger.log(
        _tag,
        'Handling new deployment: $modelId $newVersion',
        LogLevel.info,
      );

      final versions = _registry.getVersions(modelId);

      for (final version in versions) {
        // Skip the new version
        if (version.version == newVersion) continue;

        // Skip already deprecated/retired versions
        if (version.isDeprecated || version.isRetired) continue;

        // Deprecate old active versions
        if (version.status == ModelStatus.active) {
          await _registry.deprecateVersion(
            modelId,
            version.version,
            reason: 'Automatically deprecated due to new version deployment',
            replacementVersion: newVersion,
            gracePeriodDays: _config.defaultGracePeriodDays,
          );

          _logger.log(
            _tag,
            'Deprecated $modelId ${version.version} in favor of $newVersion',
            LogLevel.info,
          );
        }
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to handle new deployment: $e', LogLevel.error);
    }
  }

  /// Check for models that should be automatically retired
  Future<void> checkForRetirements() async {
    try {
      _logger.log(_tag, 'Checking for models to retire', LogLevel.info);

      final deprecated = _registry.getDeprecatedModels();
      final now = DateTime.now();

      for (final model in deprecated) {
        if (model.deprecation == null) continue;

        // Check if past end-of-life date
        if (now.isAfter(model.deprecation!.endOfLifeDate)) {
          await _registry.retireVersion(model.modelId, model.version);

          _logger.log(
            _tag,
            'Retired ${model.modelId} ${model.version} (past EOL)',
            LogLevel.info,
          );
        }
      }
    } catch (e) {
      _logger.log(_tag, 'Retirement check failed: $e', LogLevel.error);
    }
  }

  /// Check for models approaching end-of-life
  Future<List<DeprecationWarning>> getDeprecationWarnings() async {
    final warnings = <DeprecationWarning>[];

    try {
      final deprecated = _registry.getDeprecatedModels();

      for (final model in deprecated) {
        if (model.daysUntilEol == null) continue;

        // Warn if within warning threshold
        if (model.daysUntilEol! <= _config.eolWarningThresholdDays) {
          warnings.add(DeprecationWarning(
            modelId: model.modelId,
            version: model.version,
            daysUntilEol: model.daysUntilEol!,
            replacementVersion: model.deprecation?.replacementVersion,
            severity: model.daysUntilEol! <= 7
                ? WarningSeverity.critical
                : model.daysUntilEol! <= 30
                    ? WarningSeverity.high
                    : WarningSeverity.medium,
          ));
        }
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to get warnings: $e', LogLevel.error);
    }

    return warnings;
  }

  /// Update policy configuration
  void updateConfig(PolicyConfig config) {
    _logger.log(_tag, 'Updating policy configuration', LogLevel.info);
    _config = config;

    // Restart timers if needed
    if (config.enableAutomaticDeprecation) {
      _startDeprecationChecks();
    } else {
      _deprecationCheckTimer?.cancel();
    }

    if (config.enableAutomaticRetirement) {
      _startRetirementChecks();
    } else {
      _retirementCheckTimer?.cancel();
    }
  }

  // Private helper methods

  void _startDeprecationChecks() {
    _deprecationCheckTimer?.cancel();

    _deprecationCheckTimer = Timer.periodic(
      _config.deprecationCheckInterval,
      (_) async {
        await getDeprecationWarnings();
      },
    );

    _logger.log(_tag, 'Started deprecation checks', LogLevel.info);
  }

  void _startRetirementChecks() {
    _retirementCheckTimer?.cancel();

    _retirementCheckTimer = Timer.periodic(
      _config.retirementCheckInterval,
      (_) async {
        await checkForRetirements();
      },
    );

    _logger.log(_tag, 'Started retirement checks', LogLevel.info);
  }

  /// Dispose of resources
  Future<void> dispose() async {
    _deprecationCheckTimer?.cancel();
    _retirementCheckTimer?.cancel();
  }
}

/// Policy configuration
class PolicyConfig {
  /// Enforce performance thresholds before deployment
  final bool enforcePerformanceThresholds;

  /// Automatically deprecate old versions when new version is deployed
  final bool deprecateOldVersionsOnNewDeployment;

  /// Enable automatic retirement of models past EOL
  final bool enableAutomaticRetirement;

  /// Enable automatic deprecation checks
  final bool enableAutomaticDeprecation;

  /// Default grace period for deprecations (days)
  final int defaultGracePeriodDays;

  /// Days before EOL to start warning
  final int eolWarningThresholdDays;

  /// Maximum cost per request (USD)
  final double? maxCostPerRequest;

  /// Interval for deprecation checks
  final Duration deprecationCheckInterval;

  /// Interval for retirement checks
  final Duration retirementCheckInterval;

  const PolicyConfig({
    this.enforcePerformanceThresholds = true,
    this.deprecateOldVersionsOnNewDeployment = true,
    this.enableAutomaticRetirement = true,
    this.enableAutomaticDeprecation = true,
    this.defaultGracePeriodDays = 90,
    this.eolWarningThresholdDays = 30,
    this.maxCostPerRequest,
    this.deprecationCheckInterval = const Duration(hours: 24),
    this.retirementCheckInterval = const Duration(hours: 24),
  });
}

/// Deployment decision result
class DeploymentDecision {
  final bool approved;
  final String reason;
  final DecisionSeverity severity;
  final String? replacement;

  DeploymentDecision({
    required this.approved,
    required this.reason,
    required this.severity,
    this.replacement,
  });
}

enum DecisionSeverity {
  info,
  warning,
  error,
}

/// Deprecation warning
class DeprecationWarning {
  final String modelId;
  final String version;
  final int daysUntilEol;
  final String? replacementVersion;
  final WarningSeverity severity;

  DeprecationWarning({
    required this.modelId,
    required this.version,
    required this.daysUntilEol,
    this.replacementVersion,
    required this.severity,
  });
}

enum WarningSeverity {
  low,
  medium,
  high,
  critical,
}
