// ABOUTME: Feature flag service for runtime flag evaluation
// ABOUTME: Provides type-safe access to feature flags with environment-specific overrides

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'feature_flag_models.dart';

/// Service for managing and evaluating feature flags
class FeatureFlagService {
  FeatureFlagsConfig? _config;
  Environment _currentEnvironment = Environment.development;
  final Map<String, bool> _overrides = {};
  final Map<String, dynamic> _cache = {};
  DateTime? _lastCacheTime;

  /// Singleton instance
  static final FeatureFlagService instance = FeatureFlagService._internal();
  FeatureFlagService._internal();

  /// Initialize the feature flag service
  Future<void> initialize({
    String configPath = 'feature_flags.json',
    Environment? environment,
  }) async {
    try {
      // Load configuration from file
      final file = File(configPath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents);

        // Parse configuration
        _config = _parseConfig(json);

        // Set environment
        if (environment != null) {
          _currentEnvironment = environment;
        } else if (_config != null) {
          _currentEnvironment = _config!.globalConfig.defaultEnvironment;
        }

        debugPrint('FeatureFlagService initialized: environment=$_currentEnvironment');
      } else {
        debugPrint('Feature flags config file not found: $configPath');
        _config = _getDefaultConfig();
      }
    } catch (e) {
      debugPrint('Failed to load feature flags: $e');
      _config = _getDefaultConfig();
    }
  }

  /// Parse configuration from JSON
  FeatureFlagsConfig _parseConfig(Map<String, dynamic> json) {
    final flags = <String, FeatureFlag>{};
    final flagsJson = json['flags'] as Map<String, dynamic>;

    flagsJson.forEach((key, value) {
      final flagJson = value as Map<String, dynamic>;
      flags[key] = FeatureFlag.fromJson({
        'key': key,
        ...flagJson,
      });
    });

    return FeatureFlagsConfig(
      version: json['version'] as String,
      description: json['description'] as String,
      environments: (json['environments'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          EnvironmentConfig.fromJson(value as Map<String, dynamic>),
        ),
      ),
      flags: flags,
      globalConfig: GlobalConfig.fromJson(
        json['globalConfig'] as Map<String, dynamic>,
      ),
    );
  }

  /// Get default configuration if file is not found
  FeatureFlagsConfig _getDefaultConfig() {
    return const FeatureFlagsConfig(
      version: '1.0.0',
      description: 'Default feature flags configuration',
      environments: {},
      flags: {},
      globalConfig: GlobalConfig(),
    );
  }

  /// Check if a feature flag is enabled
  bool isEnabled(String flagKey) {
    // Check for manual override first
    if (_overrides.containsKey(flagKey)) {
      return _overrides[flagKey]!;
    }

    // Check cache if enabled
    if (_config?.globalConfig.cacheEnabled == true && _isCacheValid()) {
      if (_cache.containsKey(flagKey)) {
        return _cache[flagKey] as bool;
      }
    }

    final flag = _config?.flags[flagKey];
    if (flag == null) {
      debugPrint('Feature flag not found: $flagKey');
      return false;
    }

    bool result = _evaluateFlag(flag);

    // Cache the result
    if (_config?.globalConfig.cacheEnabled == true) {
      _cache[flagKey] = result;
      _lastCacheTime = DateTime.now();
    }

    return result;
  }

  /// Evaluate a feature flag based on current environment and rollout
  bool _evaluateFlag(FeatureFlag flag) {
    // Check if flag is globally enabled
    if (!flag.enabled) {
      return false;
    }

    // Check environment-specific variant
    final variantEnabled = _getVariantForEnvironment(flag.variants);
    if (!variantEnabled) {
      return false;
    }

    // Check rollout percentage if specified
    if (flag.rolloutPercentage != null) {
      final percentage = _getRolloutForEnvironment(flag.rolloutPercentage!);
      if (percentage < 100) {
        // Use a deterministic but pseudo-random check based on flag key
        return _isInRollout(flag.key, percentage);
      }
    }

    return true;
  }

  /// Get variant for current environment
  bool _getVariantForEnvironment(FeatureFlagVariants variants) {
    switch (_currentEnvironment) {
      case Environment.development:
        return variants.development;
      case Environment.staging:
        return variants.staging;
      case Environment.production:
        return variants.production;
    }
  }

  /// Get rollout percentage for current environment
  int _getRolloutForEnvironment(RolloutPercentage rollout) {
    switch (_currentEnvironment) {
      case Environment.development:
        return rollout.development;
      case Environment.staging:
        return rollout.staging;
      case Environment.production:
        return rollout.production;
    }
  }

  /// Deterministic rollout check based on flag key
  bool _isInRollout(String flagKey, int percentage) {
    if (percentage <= 0) return false;
    if (percentage >= 100) return true;

    // Use flag key hash for deterministic but distributed rollout
    final hash = flagKey.hashCode.abs();
    return (hash % 100) < percentage;
  }

  /// Check if cache is valid
  bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    final duration = _config?.globalConfig.cacheDuration ?? 300;
    return DateTime.now().difference(_lastCacheTime!).inSeconds < duration;
  }

  /// Get configuration value for a flag
  T? getConfig<T>(String flagKey, String configKey, {T? defaultValue}) {
    final flag = _config?.flags[flagKey];
    if (flag == null) return defaultValue;

    final value = flag.config[configKey];
    if (value == null) return defaultValue;

    if (value is T) {
      return value;
    }

    return defaultValue;
  }

  /// Get all configuration for a flag
  Map<String, dynamic> getAllConfig(String flagKey) {
    final flag = _config?.flags[flagKey];
    return flag?.config ?? {};
  }

  /// Get a specific feature flag
  FeatureFlag? getFlag(String flagKey) {
    return _config?.flags[flagKey];
  }

  /// Get all flags of a specific type
  List<FeatureFlag> getFlagsByType(FeatureFlagType type) {
    if (_config == null) return [];
    return _config!.flags.values.where((flag) => flag.type == type).toList();
  }

  /// Get all flags in a specific category
  List<FeatureFlag> getFlagsByCategory(String category) {
    if (_config == null) return [];
    return _config!.flags.values
        .where((flag) => flag.metadata.category == category)
        .toList();
  }

  /// Manually override a flag (useful for testing)
  void setOverride(String flagKey, bool value) {
    _overrides[flagKey] = value;
    _invalidateCache();
    debugPrint('Feature flag override set: $flagKey = $value');
  }

  /// Remove a manual override
  void removeOverride(String flagKey) {
    _overrides.remove(flagKey);
    _invalidateCache();
    debugPrint('Feature flag override removed: $flagKey');
  }

  /// Clear all overrides
  void clearOverrides() {
    _overrides.clear();
    _invalidateCache();
    debugPrint('All feature flag overrides cleared');
  }

  /// Set current environment
  void setEnvironment(Environment environment) {
    if (_currentEnvironment != environment) {
      _currentEnvironment = environment;
      _invalidateCache();
      debugPrint('Environment changed to: $environment');
    }
  }

  /// Get current environment
  Environment get currentEnvironment => _currentEnvironment;

  /// Invalidate cache
  void _invalidateCache() {
    _cache.clear();
    _lastCacheTime = null;
  }

  /// Get all enabled flags
  List<String> getEnabledFlags() {
    if (_config == null) return [];
    return _config!.flags.entries
        .where((entry) => isEnabled(entry.key))
        .map((entry) => entry.key)
        .toList();
  }

  /// Export current configuration state (useful for debugging)
  Map<String, dynamic> exportState() {
    return {
      'environment': _currentEnvironment.toString(),
      'enabledFlags': getEnabledFlags(),
      'overrides': _overrides,
      'cacheSize': _cache.length,
      'cacheValid': _isCacheValid(),
    };
  }

  /// Reload configuration from file
  Future<void> reload({String configPath = 'feature_flags.json'}) async {
    _invalidateCache();
    await initialize(
      configPath: configPath,
      environment: _currentEnvironment,
    );
  }
}

/// Extension methods for easy access to common feature flags
extension FeatureFlagExtensions on FeatureFlagService {
  // Model Selection
  bool get isModelSelectionEnabled => isEnabled('modelSelection');
  List<String>? get availableModels =>
      getConfig<List>('modelSelection', 'availableModels')
          ?.cast<String>();

  // Advanced AI Analysis
  bool get isAdvancedAIAnalysisEnabled => isEnabled('advancedAIAnalysis');

  // Enhanced Fact Checking
  bool get isEnhancedFactCheckingEnabled => isEnabled('enhancedFactChecking');
  double? get minimumConfidenceScore =>
      getConfig<double>('enhancedFactChecking', 'minimumConfidenceScore');

  // Whisper Transcription
  bool get isWhisperTranscriptionEnabled => isEnabled('whisperTranscription');
  bool? get fallbackToNative =>
      getConfig<bool>('whisperTranscription', 'fallbackToNative');

  // Conversation Insights
  bool get isConversationInsightsEnabled => isEnabled('conversationInsights');
  bool? get enableRealTimeInsights =>
      getConfig<bool>('conversationInsights', 'enableRealTime');

  // A/B Tests
  bool get isNewUITestEnabled => isEnabled('abTestNewUI');
  bool get isModelComparisonTestEnabled => isEnabled('abTestModelComparison');

  // Offline Mode
  bool get isOfflineModeEnabled => isEnabled('offlineMode');

  // Voice Commands
  bool get isVoiceCommandsEnabled => isEnabled('voiceCommands');

  // Advanced Logging
  bool get isAdvancedLoggingEnabled => isEnabled('advancedLogging');
  String? get logLevel => getConfig<String>('advancedLogging', 'logLevel');

  // Performance Monitoring
  bool get isPerformanceMonitoringEnabled =>
      isEnabled('performanceMonitoring');

  // Beta Features
  bool get areBetaFeaturesEnabled => isEnabled('betaFeatures');
}
