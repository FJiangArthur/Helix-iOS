// ABOUTME: Central registry for managing AI model versions and lifecycle
// ABOUTME: Handles registration, retrieval, activation, and deprecation of models

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'model_version.dart';
import 'model_audit_log.dart';
import '../../core/utils/logging_service.dart';

/// Central registry for AI model lifecycle management
class ModelRegistry {
  static const String _tag = 'ModelRegistry';
  static const String _storageKey = 'model_registry_v1';

  final LoggingService _logger;
  final ModelAuditLog _auditLog;

  /// All registered model versions
  final Map<String, List<ModelVersion>> _modelVersions = {};

  /// Currently active model versions by model ID
  final Map<String, ModelVersion> _activeVersions = {};

  /// Stream controller for model updates
  final _updateController = StreamController<ModelRegistryEvent>.broadcast();

  ModelRegistry({
    required LoggingService logger,
    required ModelAuditLog auditLog,
  })  : _logger = logger,
        _auditLog = auditLog;

  /// Stream of registry events
  Stream<ModelRegistryEvent> get events => _updateController.stream;

  /// Initialize the registry and load persisted state
  Future<void> initialize() async {
    try {
      _logger.log(_tag, 'Initializing model registry', LogLevel.info);
      await _loadFromStorage();
      await _registerDefaultModels();
      _logger.log(
          _tag, 'Model registry initialized successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize registry: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Register a new model version
  Future<void> registerVersion(ModelVersion version) async {
    try {
      _logger.log(_tag, 'Registering model version: ${version.modelId} ${version.version}',
          LogLevel.info);

      // Validate version format
      if (!_isValidSemanticVersion(version.version)) {
        throw ArgumentError('Invalid semantic version: ${version.version}');
      }

      // Check for duplicate versions
      final existing = _modelVersions[version.modelId] ?? [];
      if (existing.any((v) => v.version == version.version)) {
        throw StateError(
            'Version ${version.version} already exists for ${version.modelId}');
      }

      // Add to registry
      _modelVersions[version.modelId] = [...existing, version];

      // Log audit event
      await _auditLog.logEvent(
        action: AuditAction.versionRegistered,
        modelId: version.modelId,
        version: version.version,
        metadata: {
          'provider': version.provider,
          'status': version.status.name,
          'displayName': version.displayName,
        },
      );

      // Persist and notify
      await _saveToStorage();
      _updateController.add(ModelRegistryEvent.versionRegistered(version));

      _logger.log(_tag, 'Successfully registered ${version.modelId} ${version.version}',
          LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to register version: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Activate a specific model version
  Future<void> activateVersion(String modelId, String version) async {
    try {
      _logger.log(_tag, 'Activating $modelId version $version', LogLevel.info);

      final modelVersion = getVersion(modelId, version);
      if (modelVersion == null) {
        throw ArgumentError('Version not found: $modelId $version');
      }

      // Deactivate current active version
      final currentActive = _activeVersions[modelId];
      if (currentActive != null) {
        await _updateVersionStatus(
            currentActive.modelId, currentActive.version, ModelStatus.inactive);
      }

      // Activate new version
      await _updateVersionStatus(modelId, version, ModelStatus.active);
      _activeVersions[modelId] = modelVersion.copyWith(status: ModelStatus.active);

      // Log audit event
      await _auditLog.logEvent(
        action: AuditAction.versionActivated,
        modelId: modelId,
        version: version,
        metadata: {
          'previousVersion': currentActive?.version,
        },
      );

      // Persist and notify
      await _saveToStorage();
      _updateController.add(ModelRegistryEvent.versionActivated(
          _activeVersions[modelId]!));

      _logger.log(_tag, 'Successfully activated $modelId $version', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to activate version: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Rollback to a previous model version
  Future<void> rollbackToVersion(String modelId, String targetVersion) async {
    try {
      _logger.log(_tag, 'Rolling back $modelId to version $targetVersion',
          LogLevel.info);

      final targetModel = getVersion(modelId, targetVersion);
      if (targetModel == null) {
        throw ArgumentError('Target version not found: $modelId $targetVersion');
      }

      final currentActive = _activeVersions[modelId];
      if (currentActive?.version == targetVersion) {
        _logger.log(_tag, 'Already on target version $targetVersion', LogLevel.info);
        return;
      }

      // Activate target version
      await activateVersion(modelId, targetVersion);

      // Log rollback event
      await _auditLog.logEvent(
        action: AuditAction.versionRolledBack,
        modelId: modelId,
        version: targetVersion,
        metadata: {
          'fromVersion': currentActive?.version,
          'toVersion': targetVersion,
          'reason': 'Manual rollback',
        },
      );

      _logger.log(_tag, 'Successfully rolled back to $targetVersion', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to rollback: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Deprecate a model version
  Future<void> deprecateVersion(
    String modelId,
    String version, {
    required String reason,
    String? replacementVersion,
    int gracePeriodDays = 90,
  }) async {
    try {
      _logger.log(_tag, 'Deprecating $modelId version $version', LogLevel.info);

      final modelVersion = getVersion(modelId, version);
      if (modelVersion == null) {
        throw ArgumentError('Version not found: $modelId $version');
      }

      // Create deprecation info
      final deprecation = ModelDeprecationInfo(
        announcedAt: DateTime.now(),
        endOfLifeDate: DateTime.now().add(Duration(days: gracePeriodDays)),
        replacementVersion: replacementVersion,
        reason: reason,
        gracePeriodDays: gracePeriodDays,
      );

      // Update version
      await _updateVersion(
        modelId,
        version,
        modelVersion.copyWith(
          status: ModelStatus.deprecated,
          deprecation: deprecation,
          updatedAt: DateTime.now(),
        ),
      );

      // Log audit event
      await _auditLog.logEvent(
        action: AuditAction.versionDeprecated,
        modelId: modelId,
        version: version,
        metadata: {
          'reason': reason,
          'replacementVersion': replacementVersion,
          'gracePeriodDays': gracePeriodDays,
          'endOfLifeDate': deprecation.endOfLifeDate.toIso8601String(),
        },
      );

      _logger.log(_tag, 'Successfully deprecated $modelId $version', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to deprecate version: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Retire a model version (permanent removal)
  Future<void> retireVersion(String modelId, String version) async {
    try {
      _logger.log(_tag, 'Retiring $modelId version $version', LogLevel.info);

      await _updateVersionStatus(modelId, version, ModelStatus.retired);

      // Remove from active versions if present
      if (_activeVersions[modelId]?.version == version) {
        _activeVersions.remove(modelId);
      }

      // Log audit event
      await _auditLog.logEvent(
        action: AuditAction.versionRetired,
        modelId: modelId,
        version: version,
        metadata: {'retiredAt': DateTime.now().toIso8601String()},
      );

      _logger.log(_tag, 'Successfully retired $modelId $version', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to retire version: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Update model performance metrics
  Future<void> updateMetrics(
    String modelId,
    String version,
    ModelPerformanceMetrics metrics,
  ) async {
    try {
      final modelVersion = getVersion(modelId, version);
      if (modelVersion == null) {
        throw ArgumentError('Version not found: $modelId $version');
      }

      await _updateVersion(
        modelId,
        version,
        modelVersion.copyWith(
          metrics: metrics,
          updatedAt: DateTime.now(),
        ),
      );

      // Check if model still meets performance thresholds
      final updated = getVersion(modelId, version)!;
      if (!updated.meetsPerformanceThresholds) {
        _logger.log(
          _tag,
          'WARNING: $modelId $version no longer meets performance thresholds',
          LogLevel.warning,
        );

        await _auditLog.logEvent(
          action: AuditAction.performanceThresholdViolation,
          modelId: modelId,
          version: version,
          metadata: {
            'successRate': metrics.successRate,
            'threshold': modelVersion.successRateThreshold,
            'avgLatency': metrics.avgLatencyMs,
            'avgConfidence': metrics.avgConfidence,
          },
        );
      }

      await _saveToStorage();
    } catch (e) {
      _logger.log(_tag, 'Failed to update metrics: $e', LogLevel.error);
      rethrow;
    }
  }

  /// Get a specific model version
  ModelVersion? getVersion(String modelId, String version) {
    final versions = _modelVersions[modelId];
    if (versions == null) return null;

    try {
      return versions.firstWhere((v) => v.version == version);
    } catch (e) {
      return null;
    }
  }

  /// Get all versions for a model
  List<ModelVersion> getVersions(String modelId) {
    return _modelVersions[modelId] ?? [];
  }

  /// Get the currently active version for a model
  ModelVersion? getActiveVersion(String modelId) {
    return _activeVersions[modelId];
  }

  /// Get all active model versions
  Map<String, ModelVersion> getActiveVersions() {
    return Map.from(_activeVersions);
  }

  /// Get all models
  List<String> getAllModelIds() {
    return _modelVersions.keys.toList();
  }

  /// Get deprecated models that need attention
  List<ModelVersion> getDeprecatedModels() {
    final deprecated = <ModelVersion>[];
    for (final versions in _modelVersions.values) {
      deprecated.addAll(versions.where((v) => v.isDeprecated));
    }
    return deprecated;
  }

  /// Get models nearing end of life
  List<ModelVersion> getModelsNearingEol({int daysThreshold = 30}) {
    return getDeprecatedModels()
        .where((v) => v.daysUntilEol != null && v.daysUntilEol! <= daysThreshold)
        .toList();
  }

  /// Get latest version of a model
  ModelVersion? getLatestVersion(String modelId) {
    final versions = getVersions(modelId);
    if (versions.isEmpty) return null;

    return versions.reduce((a, b) =>
        _compareSemanticVersions(a.version, b.version) > 0 ? a : b);
  }

  // Private helper methods

  Future<void> _updateVersionStatus(
      String modelId, String version, ModelStatus status) async {
    final modelVersion = getVersion(modelId, version);
    if (modelVersion == null) return;

    await _updateVersion(
      modelId,
      version,
      modelVersion.copyWith(status: status, updatedAt: DateTime.now()),
    );
  }

  Future<void> _updateVersion(
      String modelId, String version, ModelVersion updated) async {
    final versions = _modelVersions[modelId] ?? [];
    final index = versions.indexWhere((v) => v.version == version);

    if (index == -1) {
      throw ArgumentError('Version not found: $modelId $version');
    }

    _modelVersions[modelId] = [
      ...versions.sublist(0, index),
      updated,
      ...versions.sublist(index + 1),
    ];

    if (_activeVersions[modelId]?.version == version) {
      _activeVersions[modelId] = updated;
    }

    await _saveToStorage();
    _updateController.add(ModelRegistryEvent.versionUpdated(updated));
  }

  bool _isValidSemanticVersion(String version) {
    final regex = RegExp(r'^(\d+)\.(\d+)\.(\d+)(-[a-zA-Z0-9.-]+)?$');
    return regex.hasMatch(version);
  }

  int _compareSemanticVersions(String a, String b) {
    final aParts = a.split('.').map(int.parse).toList();
    final bParts = b.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      if (aParts[i] > bParts[i]) return 1;
      if (aParts[i] < bParts[i]) return -1;
    }
    return 0;
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);

      if (data != null) {
        final json = jsonDecode(data) as Map<String, dynamic>;

        // Load model versions
        final versionsData = json['versions'] as Map<String, dynamic>?;
        if (versionsData != null) {
          versionsData.forEach((modelId, versionsList) {
            final versions = (versionsList as List)
                .map((v) => ModelVersion.fromJson(v as Map<String, dynamic>))
                .toList();
            _modelVersions[modelId] = versions;
          });
        }

        // Load active versions
        final activeData = json['active'] as Map<String, dynamic>?;
        if (activeData != null) {
          activeData.forEach((modelId, versionData) {
            _activeVersions[modelId] =
                ModelVersion.fromJson(versionData as Map<String, dynamic>);
          });
        }

        _logger.log(_tag, 'Loaded ${_modelVersions.length} models from storage',
            LogLevel.info);
      }
    } catch (e) {
      _logger.log(_tag, 'Failed to load from storage: $e', LogLevel.error);
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = {
        'versions': _modelVersions.map((k, v) => MapEntry(k, v.map((m) => m.toJson()).toList())),
        'active': _activeVersions.map((k, v) => MapEntry(k, v.toJson())),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      _logger.log(_tag, 'Failed to save to storage: $e', LogLevel.error);
    }
  }

  Future<void> _registerDefaultModels() async {
    // Register default OpenAI models
    await _registerDefaultOpenAIModels();
    // Register default Anthropic models
    await _registerDefaultAnthropicModels();
  }

  Future<void> _registerDefaultOpenAIModels() async {
    final models = [
      ModelVersion(
        version: '1.0.0',
        modelId: 'gpt-4-turbo-preview',
        provider: 'OpenAI',
        displayName: 'GPT-4 Turbo',
        description: 'Most capable GPT-4 model with improved performance',
        releaseDate: DateTime(2024, 1, 1),
        status: ModelStatus.active,
        capabilities: const ModelCapabilities(
          supportsStreaming: true,
          supportsFunctionCalling: true,
          supportsVision: false,
          supportsAudioTranscription: false,
          maxContextTokens: 128000,
          maxOutputTokens: 4096,
          supportedAnalysisTypes: ['factCheck', 'summary', 'sentiment', 'actionItems'],
        ),
        costInfo: const ModelCostInfo(
          inputCostPer1k: 0.01,
          outputCostPer1k: 0.03,
          tier: CostTier.premium,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: ['llm', 'openai', 'gpt-4', 'production'],
      ),
      ModelVersion(
        version: '1.0.0',
        modelId: 'gpt-3.5-turbo',
        provider: 'OpenAI',
        displayName: 'GPT-3.5 Turbo',
        description: 'Fast and cost-effective model for most tasks',
        releaseDate: DateTime(2023, 11, 1),
        status: ModelStatus.active,
        capabilities: const ModelCapabilities(
          supportsStreaming: true,
          supportsFunctionCalling: true,
          supportsVision: false,
          supportsAudioTranscription: false,
          maxContextTokens: 16384,
          maxOutputTokens: 4096,
          supportedAnalysisTypes: ['factCheck', 'summary', 'sentiment'],
        ),
        costInfo: const ModelCostInfo(
          inputCostPer1k: 0.0005,
          outputCostPer1k: 0.0015,
          tier: CostTier.economy,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: ['llm', 'openai', 'gpt-3.5', 'economy'],
      ),
    ];

    for (final model in models) {
      if (getVersion(model.modelId, model.version) == null) {
        _modelVersions[model.modelId] = [model];
        _activeVersions[model.modelId] = model;
      }
    }
  }

  Future<void> _registerDefaultAnthropicModels() async {
    final models = [
      ModelVersion(
        version: '1.0.0',
        modelId: 'claude-3-5-sonnet-20241022',
        provider: 'Anthropic',
        displayName: 'Claude 3.5 Sonnet',
        description: 'Most intelligent Claude model',
        releaseDate: DateTime(2024, 10, 22),
        status: ModelStatus.active,
        capabilities: const ModelCapabilities(
          supportsStreaming: true,
          supportsFunctionCalling: true,
          supportsVision: true,
          supportsAudioTranscription: false,
          maxContextTokens: 200000,
          maxOutputTokens: 8192,
          supportedAnalysisTypes: ['factCheck', 'summary', 'sentiment', 'actionItems', 'topics'],
        ),
        costInfo: const ModelCostInfo(
          inputCostPer1k: 0.003,
          outputCostPer1k: 0.015,
          tier: CostTier.premium,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: ['llm', 'anthropic', 'claude', 'production'],
      ),
    ];

    for (final model in models) {
      if (getVersion(model.modelId, model.version) == null) {
        _modelVersions[model.modelId] = [model];
        _activeVersions[model.modelId] = model;
      }
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _updateController.close();
  }
}

/// Registry event types
sealed class ModelRegistryEvent {
  const ModelRegistryEvent();

  factory ModelRegistryEvent.versionRegistered(ModelVersion version) =
      VersionRegisteredEvent;
  factory ModelRegistryEvent.versionActivated(ModelVersion version) =
      VersionActivatedEvent;
  factory ModelRegistryEvent.versionUpdated(ModelVersion version) =
      VersionUpdatedEvent;
}

class VersionRegisteredEvent extends ModelRegistryEvent {
  final ModelVersion version;
  const VersionRegisteredEvent(this.version);
}

class VersionActivatedEvent extends ModelRegistryEvent {
  final ModelVersion version;
  const VersionActivatedEvent(this.version);
}

class VersionUpdatedEvent extends ModelRegistryEvent {
  final ModelVersion version;
  const VersionUpdatedEvent(this.version);
}
