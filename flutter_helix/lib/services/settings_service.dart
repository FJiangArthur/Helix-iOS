// ABOUTME: Settings service interface for app configuration and persistence
// ABOUTME: Manages user preferences, API keys, and device settings

import 'dart:async';

import '../core/utils/exceptions.dart';

/// Theme mode options
enum ThemeMode {
  system,
  light,
  dark,
}

/// Privacy level settings
enum PrivacyLevel {
  minimal,    // Local processing only
  balanced,   // Some cloud processing
  full,       // Full cloud processing
}

/// Service interface for app settings and configuration
abstract class SettingsService {
  /// Stream of settings changes
  Stream<SettingsChangeEvent> get settingsChangeStream;

  /// Initialize the settings service
  Future<void> initialize();

  // ==========================================================================
  // General App Settings
  // ==========================================================================

  /// Get/set theme mode
  Future<ThemeMode> getThemeMode();
  Future<void> setThemeMode(ThemeMode mode);

  /// Get/set language
  Future<String> getLanguage();
  Future<void> setLanguage(String languageCode);

  /// Get/set privacy level
  Future<PrivacyLevel> getPrivacyLevel();
  Future<void> setPrivacyLevel(PrivacyLevel level);

  // ==========================================================================
  // Audio Settings
  // ==========================================================================

  /// Get/set preferred audio input device
  Future<String?> getPreferredAudioDevice();
  Future<void> setPreferredAudioDevice(String deviceId);

  /// Get/set audio quality
  Future<String> getAudioQuality(); // 'low', 'medium', 'high'
  Future<void> setAudioQuality(String quality);

  /// Get/set noise reduction enabled
  Future<bool> getNoiseReductionEnabled();
  Future<void> setNoiseReductionEnabled(bool enabled);

  /// Get/set voice activity detection sensitivity
  Future<double> getVADSensitivity(); // 0.0 to 1.0
  Future<void> setVADSensitivity(double sensitivity);

  // ==========================================================================
  // Transcription Settings
  // ==========================================================================

  /// Get/set preferred transcription backend
  Future<String> getPreferredTranscriptionBackend(); // 'local', 'whisper', 'hybrid'
  Future<void> setPreferredTranscriptionBackend(String backend);

  /// Get/set transcription language
  Future<String> getTranscriptionLanguage();
  Future<void> setTranscriptionLanguage(String languageCode);

  /// Get/set automatic backend switching
  Future<bool> getAutomaticBackendSwitching();
  Future<void> setAutomaticBackendSwitching(bool enabled);

  // ==========================================================================
  // AI Service Settings
  // ==========================================================================

  /// Get/set preferred AI provider
  Future<String> getPreferredAIProvider(); // 'openai', 'anthropic'
  Future<void> setPreferredAIProvider(String provider);

  /// Get/set API keys (stored securely)
  Future<String?> getAPIKey(String provider);
  Future<void> setAPIKey(String provider, String apiKey);
  Future<void> removeAPIKey(String provider);

  /// Get/set AI analysis settings
  Future<bool> getFactCheckingEnabled();
  Future<void> setFactCheckingEnabled(bool enabled);

  Future<bool> getRealTimeAnalysisEnabled();
  Future<void> setRealTimeAnalysisEnabled(bool enabled);

  Future<double> getFactCheckThreshold(); // 0.0 to 1.0
  Future<void> setFactCheckThreshold(double threshold);

  // ==========================================================================
  // Glasses Settings
  // ==========================================================================

  /// Get/set last connected glasses device
  Future<String?> getLastConnectedGlasses();
  Future<void> setLastConnectedGlasses(String deviceId);

  /// Get/set auto-connect to glasses
  Future<bool> getAutoConnectGlasses();
  Future<void> setAutoConnectGlasses(bool enabled);

  /// Get/set HUD brightness
  Future<double> getHUDBrightness(); // 0.0 to 1.0
  Future<void> setHUDBrightness(double brightness);

  /// Get/set gesture sensitivity
  Future<double> getGestureSensitivity(); // 0.0 to 1.0
  Future<void> setGestureSensitivity(double sensitivity);

  // ==========================================================================
  // Data & Privacy Settings
  // ==========================================================================

  /// Get/set data retention period in days
  Future<int> getDataRetentionDays();
  Future<void> setDataRetentionDays(int days);

  /// Get/set automatic data cleanup
  Future<bool> getAutomaticDataCleanup();
  Future<void> setAutomaticDataCleanup(bool enabled);

  /// Get/set analytics collection consent
  Future<bool> getAnalyticsConsent();
  Future<void> setAnalyticsConsent(bool consent);

  /// Get/set crash reporting consent
  Future<bool> getCrashReportingConsent();
  Future<void> setCrashReportingConsent(bool consent);

  // ==========================================================================
  // Backup & Sync Settings
  // ==========================================================================

  /// Get/set cloud sync enabled
  Future<bool> getCloudSyncEnabled();
  Future<void> setCloudSyncEnabled(bool enabled);

  /// Get/set backup frequency
  Future<String> getBackupFrequency(); // 'never', 'daily', 'weekly'
  Future<void> setBackupFrequency(String frequency);

  // ==========================================================================
  // Accessibility Settings
  // ==========================================================================

  /// Get/set large text enabled
  Future<bool> getLargeTextEnabled();
  Future<void> setLargeTextEnabled(bool enabled);

  /// Get/set high contrast enabled
  Future<bool> getHighContrastEnabled();
  Future<void> setHighContrastEnabled(bool enabled);

  /// Get/set reduced motion enabled
  Future<bool> getReducedMotionEnabled();
  Future<void> setReducedMotionEnabled(bool enabled);

  // ==========================================================================
  // Advanced Settings
  // ==========================================================================

  /// Get/set developer mode enabled
  Future<bool> getDeveloperModeEnabled();
  Future<void> setDeveloperModeEnabled(bool enabled);

  /// Get/set debug logging enabled
  Future<bool> getDebugLoggingEnabled();
  Future<void> setDebugLoggingEnabled(bool enabled);

  /// Get/set beta features enabled
  Future<bool> getBetaFeaturesEnabled();
  Future<void> setBetaFeaturesEnabled(bool enabled);

  // ==========================================================================
  // Utility Methods
  // ==========================================================================

  /// Export all settings to a JSON string
  Future<String> exportSettings();

  /// Import settings from a JSON string
  Future<void> importSettings(String settingsJson);

  /// Reset all settings to defaults
  Future<void> resetToDefaults();

  /// Reset specific category of settings
  Future<void> resetCategory(SettingsCategory category);

  /// Get all settings as a map
  Future<Map<String, dynamic>> getAllSettings();

  /// Clean up resources
  Future<void> dispose();
}

/// Categories of settings for organized reset
enum SettingsCategory {
  general,
  audio,
  transcription,
  ai,
  glasses,
  privacy,
  accessibility,
  advanced,
}

/// Settings change event
class SettingsChangeEvent {
  final String key;
  final dynamic oldValue;
  final dynamic newValue;
  final DateTime timestamp;

  const SettingsChangeEvent({
    required this.key,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
  });

  @override
  String toString() => 'SettingsChangeEvent($key: $oldValue -> $newValue)';
}