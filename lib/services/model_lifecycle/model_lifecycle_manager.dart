// ABOUTME: Central manager for model lifecycle operations
// ABOUTME: Provides unified interface for versioning, registry, audit, and evaluation

import 'dart:async';

import 'model_version.dart';
import 'model_registry.dart';
import 'model_audit_log.dart';
import 'model_evaluator.dart';
import 'lifecycle_policy.dart';
import '../../core/utils/logging_service.dart';

/// Central manager for AI model lifecycle management
class ModelLifecycleManager {
  static const String _tag = 'ModelLifecycleManager';

  final LoggingService _logger;

  late final ModelAuditLog _auditLog;
  late final ModelRegistry _registry;
  late final ModelEvaluator _evaluator;
  late final LifecyclePolicy _policy;

  bool _isInitialized = false;

  ModelLifecycleManager({required LoggingService logger}) : _logger = logger;

  /// Whether the manager is initialized
  bool get isInitialized => _isInitialized;

  /// Access to the model registry
  ModelRegistry get registry => _registry;

  /// Access to the audit log
  ModelAuditLog get auditLog => _auditLog;

  /// Access to the evaluator
  ModelEvaluator get evaluator => _evaluator;

  /// Access to the lifecycle policy
  LifecyclePolicy get policy => _policy;

  /// Initialize the lifecycle management system
  Future<void> initialize({
    EvaluationConfig? evaluationConfig,
    PolicyConfig? policyConfig,
  }) async {
    try {
      _logger.log(_tag, 'Initializing model lifecycle manager', LogLevel.info);

      // Initialize components
      _auditLog = ModelAuditLog(logger: _logger);
      await _auditLog.initialize();

      _registry = ModelRegistry(logger: _logger, auditLog: _auditLog);
      await _registry.initialize();

      _evaluator = ModelEvaluator(
        logger: _logger,
        registry: _registry,
        auditLog: _auditLog,
      );
      await _evaluator.initialize(config: evaluationConfig);

      _policy = LifecyclePolicy(
        logger: _logger,
        registry: _registry,
        auditLog: _auditLog,
        evaluator: _evaluator,
      );
      await _policy.initialize(config: policyConfig);

      // Set up event handlers
      _setupEventHandlers();

      _isInitialized = true;

      _logger.log(
        _tag,
        'Model lifecycle manager initialized successfully',
        LogLevel.info,
      );

      // Log initialization
      await _auditLog.logEvent(
        action: AuditAction.registryInitialized,
        modelId: 'system',
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize: $e', LogLevel.error);
      rethrow;
    }
  }

  // --- Model Version Management ---

  /// Register a new model version
  Future<void> registerModel(ModelVersion version) async {
    _ensureInitialized();
    await _registry.registerVersion(version);
  }

  /// Activate a model version
  Future<void> activateModel(String modelId, String version) async {
    _ensureInitialized();

    // Check if deployment is allowed
    final decision = await _policy.canDeploy(
      modelId: modelId,
      version: version,
    );

    if (!decision.approved) {
      throw StateError('Deployment not approved: ${decision.reason}');
    }

    await _registry.activateVersion(modelId, version);

    // Handle old version deprecation
    await _policy.handleNewVersionDeployment(
      modelId: modelId,
      newVersion: version,
    );
  }

  /// Rollback to a previous version
  Future<void> rollbackModel(String modelId, String targetVersion) async {
    _ensureInitialized();
    await _registry.rollbackToVersion(modelId, targetVersion);
  }

  /// Deprecate a model version
  Future<void> deprecateModel(
    String modelId,
    String version, {
    required String reason,
    String? replacementVersion,
    int gracePeriodDays = 90,
  }) async {
    _ensureInitialized();
    await _registry.deprecateVersion(
      modelId,
      version,
      reason: reason,
      replacementVersion: replacementVersion,
      gracePeriodDays: gracePeriodDays,
    );
  }

  /// Retire a model version
  Future<void> retireModel(String modelId, String version) async {
    _ensureInitialized();
    await _registry.retireVersion(modelId, version);
  }

  // --- Model Evaluation ---

  /// Record an inference result for performance tracking
  Future<void> recordInference({
    required String modelId,
    required String version,
    required InferenceResult result,
  }) async {
    _ensureInitialized();
    await _evaluator.recordInference(
      modelId: modelId,
      version: version,
      result: result,
    );
  }

  /// Evaluate a model version
  Future<EvaluationReport> evaluateModel({
    required String modelId,
    required String version,
    EvaluationDataset? dataset,
  }) async {
    _ensureInitialized();
    return await _evaluator.evaluateModel(
      modelId: modelId,
      version: version,
      dataset: dataset,
    );
  }

  /// Compare two model versions
  Future<ComparisonReport> compareVersions({
    required String modelId,
    required String versionA,
    required String versionB,
  }) async {
    _ensureInitialized();
    return await _evaluator.compareVersions(
      modelId: modelId,
      versionA: versionA,
      versionB: versionB,
    );
  }

  // --- Query Methods ---

  /// Get active version of a model
  ModelVersion? getActiveModel(String modelId) {
    _ensureInitialized();
    return _registry.getActiveVersion(modelId);
  }

  /// Get a specific model version
  ModelVersion? getModel(String modelId, String version) {
    _ensureInitialized();
    return _registry.getVersion(modelId, version);
  }

  /// Get all versions of a model
  List<ModelVersion> getModelVersions(String modelId) {
    _ensureInitialized();
    return _registry.getVersions(modelId);
  }

  /// Get all active models
  Map<String, ModelVersion> getActiveModels() {
    _ensureInitialized();
    return _registry.getActiveVersions();
  }

  /// Get deprecated models
  List<ModelVersion> getDeprecatedModels() {
    _ensureInitialized();
    return _registry.getDeprecatedModels();
  }

  /// Get models nearing end-of-life
  List<ModelVersion> getModelsNearingEol({int daysThreshold = 30}) {
    _ensureInitialized();
    return _registry.getModelsNearingEol(daysThreshold: daysThreshold);
  }

  // --- Audit and Compliance ---

  /// Get audit history for a model
  List<AuditLogEntry> getModelHistory(String modelId) {
    _ensureInitialized();
    return _auditLog.getEntriesForModel(modelId);
  }

  /// Get recent audit entries
  List<AuditLogEntry> getRecentAuditEntries({int limit = 100}) {
    _ensureInitialized();
    return _auditLog.getRecentEntries(limit: limit);
  }

  /// Generate compliance report
  Future<ComplianceReport> generateComplianceReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _ensureInitialized();
    return await _auditLog.generateComplianceReport(
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Export audit log
  Future<String> exportAuditLog({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _ensureInitialized();
    return await _auditLog.exportAsJson(
      startDate: startDate,
      endDate: endDate,
    );
  }

  // --- Policy Management ---

  /// Check if model can be deployed
  Future<DeploymentDecision> canDeployModel({
    required String modelId,
    required String version,
  }) async {
    _ensureInitialized();
    return await _policy.canDeploy(modelId: modelId, version: version);
  }

  /// Get deprecation warnings
  Future<List<DeprecationWarning>> getDeprecationWarnings() async {
    _ensureInitialized();
    return await _policy.getDeprecationWarnings();
  }

  /// Update policy configuration
  void updatePolicyConfig(PolicyConfig config) {
    _ensureInitialized();
    _policy.updateConfig(config);
  }

  /// Update evaluation configuration
  void updateEvaluationConfig(EvaluationConfig config) {
    _ensureInitialized();
    _evaluator.updateConfig(config);
  }

  // --- Utility Methods ---

  /// Get system status
  Future<SystemStatus> getSystemStatus() async {
    _ensureInitialized();

    final activeModels = _registry.getActiveVersions();
    final deprecatedModels = _registry.getDeprecatedModels();
    final warnings = await _policy.getDeprecationWarnings();
    final recentAudit = _auditLog.getRecentEntries(limit: 10);

    return SystemStatus(
      isHealthy: true,
      activeModelCount: activeModels.length,
      deprecatedModelCount: deprecatedModels.length,
      pendingWarningsCount: warnings.length,
      recentAuditCount: recentAudit.length,
      timestamp: DateTime.now(),
    );
  }

  /// Create backup of registry and audit log
  Future<Map<String, String>> createBackup() async {
    _ensureInitialized();

    _logger.log(_tag, 'Creating system backup', LogLevel.info);

    final auditBackup = await _auditLog.exportAsJson();

    await _auditLog.logEvent(
      action: AuditAction.backupCreated,
      modelId: 'system',
      metadata: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    return {
      'audit_log': auditBackup,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // --- Private Methods ---

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('ModelLifecycleManager not initialized');
    }
  }

  void _setupEventHandlers() {
    // Listen to registry events
    _registry.events.listen((event) {
      _logger.log(
        _tag,
        'Registry event: ${event.runtimeType}',
        LogLevel.debug,
      );
    });

    // Listen to evaluation alerts
    _evaluator.alerts.listen((alert) {
      _logger.log(
        _tag,
        'Evaluation alert: ${alert.severity.name} - ${alert.message}',
        alert.severity == AlertSeverity.critical
            ? LogLevel.error
            : LogLevel.warning,
      );
    });

    // Listen to audit events
    _auditLog.events.listen((entry) {
      if (entry.severity == AuditSeverity.critical ||
          entry.severity == AuditSeverity.error) {
        _logger.log(
          _tag,
          'Critical audit event: ${entry.action.name}',
          LogLevel.error,
        );
      }
    });
  }

  /// Dispose of all resources
  Future<void> dispose() async {
    if (_isInitialized) {
      await _policy.dispose();
      await _evaluator.dispose();
      await _registry.dispose();
      await _auditLog.dispose();

      _isInitialized = false;
      _logger.log(_tag, 'Model lifecycle manager disposed', LogLevel.info);
    }
  }
}

/// System status
class SystemStatus {
  final bool isHealthy;
  final int activeModelCount;
  final int deprecatedModelCount;
  final int pendingWarningsCount;
  final int recentAuditCount;
  final DateTime timestamp;

  SystemStatus({
    required this.isHealthy,
    required this.activeModelCount,
    required this.deprecatedModelCount,
    required this.pendingWarningsCount,
    required this.recentAuditCount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'isHealthy': isHealthy,
        'activeModelCount': activeModelCount,
        'deprecatedModelCount': deprecatedModelCount,
        'pendingWarningsCount': pendingWarningsCount,
        'recentAuditCount': recentAuditCount,
        'timestamp': timestamp.toIso8601String(),
      };
}
