// ABOUTME: Riverpod provider for feature flag service
// ABOUTME: Provides easy access to feature flags in widgets

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'feature_flag_service.dart';
import 'feature_flag_models.dart';

/// Provider for the feature flag service singleton
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return GetIt.instance.get<FeatureFlagService>();
});

/// Provider for checking if a specific flag is enabled
/// Usage: ref.watch(featureFlagProvider('modelSelection'))
final featureFlagProvider = Provider.family<bool, String>((ref, flagKey) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(flagKey);
});

/// Provider for getting a specific feature flag configuration
/// Usage: ref.watch(featureFlagConfigProvider('modelSelection'))
final featureFlagConfigProvider =
    Provider.family<FeatureFlag?, String>((ref, flagKey) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.getFlag(flagKey);
});

/// Provider for getting all enabled flags
final enabledFlagsProvider = Provider<List<String>>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.getEnabledFlags();
});

/// Provider for current environment
final currentEnvironmentProvider = Provider<Environment>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.currentEnvironment;
});

/// Provider for flags by type
final flagsByTypeProvider =
    Provider.family<List<FeatureFlag>, FeatureFlagType>((ref, type) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.getFlagsByType(type);
});

/// Provider for flags by category
final flagsByCategoryProvider =
    Provider.family<List<FeatureFlag>, String>((ref, category) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.getFlagsByCategory(category);
});

/// Convenience providers for commonly used flags

/// Provider for model selection feature
final modelSelectionEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('modelSelection'));
});

/// Provider for available models
final availableModelsProvider = Provider<List<String>?>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.availableModels;
});

/// Provider for advanced AI analysis feature
final advancedAIAnalysisEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('advancedAIAnalysis'));
});

/// Provider for enhanced fact checking feature
final enhancedFactCheckingEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('enhancedFactChecking'));
});

/// Provider for Whisper transcription feature
final whisperTranscriptionEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('whisperTranscription'));
});

/// Provider for conversation insights feature
final conversationInsightsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('conversationInsights'));
});

/// Provider for offline mode feature
final offlineModeEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('offlineMode'));
});

/// Provider for voice commands feature
final voiceCommandsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('voiceCommands'));
});

/// Provider for advanced logging feature
final advancedLoggingEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('advancedLogging'));
});

/// Provider for performance monitoring feature
final performanceMonitoringEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('performanceMonitoring'));
});

/// Provider for beta features
final betaFeaturesEnabledProvider = Provider<bool>((ref) {
  return ref.watch(featureFlagProvider('betaFeatures'));
});
