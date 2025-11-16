// ABOUTME: Feature flag models for type-safe configuration
// ABOUTME: Uses freezed for immutable data classes and JSON serialization

import 'package:freezed_annotation/freezed_annotation.dart';

part 'feature_flag_models.freezed.dart';
part 'feature_flag_models.g.dart';

/// Feature flag type
enum FeatureFlagType {
  @JsonValue('feature')
  feature,
  @JsonValue('experiment')
  experiment,
  @JsonValue('debug')
  debug,
  @JsonValue('monitoring')
  monitoring,
}

/// Environment type
enum Environment {
  @JsonValue('development')
  development,
  @JsonValue('staging')
  staging,
  @JsonValue('production')
  production,
}

/// Feature flag metadata
@freezed
class FeatureFlagMetadata with _$FeatureFlagMetadata {
  const factory FeatureFlagMetadata({
    required String category,
    @Default(false) bool requiresRestart,
    String? addedDate,
    String? experimentEndDate,
  }) = _FeatureFlagMetadata;

  factory FeatureFlagMetadata.fromJson(Map<String, dynamic> json) =>
      _$FeatureFlagMetadataFromJson(json);
}

/// Environment-specific variants for a feature flag
@freezed
class FeatureFlagVariants with _$FeatureFlagVariants {
  const factory FeatureFlagVariants({
    @Default(false) bool development,
    @Default(false) bool staging,
    @Default(false) bool production,
  }) = _FeatureFlagVariants;

  factory FeatureFlagVariants.fromJson(Map<String, dynamic> json) =>
      _$FeatureFlagVariantsFromJson(json);
}

/// Rollout percentage by environment
@freezed
class RolloutPercentage with _$RolloutPercentage {
  const factory RolloutPercentage({
    @Default(0) int development,
    @Default(0) int staging,
    @Default(0) int production,
  }) = _RolloutPercentage;

  factory RolloutPercentage.fromJson(Map<String, dynamic> json) =>
      _$RolloutPercentageFromJson(json);
}

/// Individual feature flag configuration
@freezed
class FeatureFlag with _$FeatureFlag {
  const factory FeatureFlag({
    required String key,
    required bool enabled,
    required String description,
    required FeatureFlagType type,
    required FeatureFlagMetadata metadata,
    required FeatureFlagVariants variants,
    RolloutPercentage? rolloutPercentage,
    @Default({}) Map<String, dynamic> config,
  }) = _FeatureFlag;

  factory FeatureFlag.fromJson(Map<String, dynamic> json) =>
      _$FeatureFlagFromJson(json);
}

/// Environment configuration
@freezed
class EnvironmentConfig with _$EnvironmentConfig {
  const factory EnvironmentConfig({
    required bool enabled,
    required String description,
  }) = _EnvironmentConfig;

  factory EnvironmentConfig.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentConfigFromJson(json);
}

/// Global configuration for feature flags
@freezed
class GlobalConfig with _$GlobalConfig {
  const factory GlobalConfig({
    @Default(Environment.development) Environment defaultEnvironment,
    @Default(true) bool allowEnvironmentOverride,
    @Default(true) bool cacheEnabled,
    @Default(300) int cacheDuration,
  }) = _GlobalConfig;

  factory GlobalConfig.fromJson(Map<String, dynamic> json) =>
      _$GlobalConfigFromJson(json);
}

/// Root feature flags configuration
@freezed
class FeatureFlagsConfig with _$FeatureFlagsConfig {
  const factory FeatureFlagsConfig({
    required String version,
    required String description,
    required Map<String, EnvironmentConfig> environments,
    required Map<String, FeatureFlag> flags,
    required GlobalConfig globalConfig,
  }) = _FeatureFlagsConfig;

  factory FeatureFlagsConfig.fromJson(Map<String, dynamic> json) =>
      _$FeatureFlagsConfigFromJson(json);
}
