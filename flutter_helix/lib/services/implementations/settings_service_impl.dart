// ABOUTME: Settings service implementation using SharedPreferences for persistence
// ABOUTME: Manages app configuration, user preferences, and secure API key storage

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../settings_service.dart';
import '../../core/utils/logging_service.dart';

class SettingsServiceImpl implements SettingsService {
  static const String _tag = 'SettingsServiceImpl';

  final LoggingService _logger;
  final SharedPreferences _prefs;

  // Stream controller for settings changes
  final StreamController<SettingsChangeEvent> _settingsChangeController = 
      StreamController<SettingsChangeEvent>.broadcast();

  // Settings keys
  static const String _themeKey = 'theme_mode';
  static const String _languageKey = 'language';
  static const String _privacyLevelKey = 'privacy_level';
  
  // Audio settings keys
  static const String _audioDeviceKey = 'audio_device';
  static const String _audioQualityKey = 'audio_quality';
  static const String _noiseReductionKey = 'noise_reduction';
  static const String _vadSensitivityKey = 'vad_sensitivity';
  
  // Transcription settings keys
  static const String _transcriptionBackendKey = 'transcription_backend';
  static const String _transcriptionLanguageKey = 'transcription_language';
  static const String _autoBackendSwitchKey = 'auto_backend_switch';
  
  // AI settings keys
  static const String _aiProviderKey = 'ai_provider';
  static const String _apiKeysKey = 'api_keys';
  static const String _factCheckingKey = 'fact_checking';
  static const String _realTimeAnalysisKey = 'real_time_analysis';
  static const String _factCheckThresholdKey = 'fact_check_threshold';
  
  // Glasses settings keys
  static const String _lastGlassesKey = 'last_glasses';
  static const String _autoConnectGlassesKey = 'auto_connect_glasses';
  static const String _hudBrightnessKey = 'hud_brightness';
  static const String _gestureSensitivityKey = 'gesture_sensitivity';
  
  // Privacy settings keys
  static const String _dataRetentionKey = 'data_retention_days';
  static const String _autoCleanupKey = 'auto_cleanup';
  static const String _analyticsConsentKey = 'analytics_consent';
  static const String _crashReportingKey = 'crash_reporting';
  
  // Backup settings keys
  static const String _cloudSyncKey = 'cloud_sync';
  static const String _backupFrequencyKey = 'backup_frequency';
  
  // Accessibility settings keys
  static const String _largeTextKey = 'large_text';
  static const String _highContrastKey = 'high_contrast';
  static const String _reducedMotionKey = 'reduced_motion';
  
  // Advanced settings keys
  static const String _developerModeKey = 'developer_mode';
  static const String _debugLoggingKey = 'debug_logging';
  static const String _betaFeaturesKey = 'beta_features';

  SettingsServiceImpl({
    required LoggingService logger,
    required SharedPreferences prefs,
  }) : _logger = logger, _prefs = prefs;

  @override
  Stream<SettingsChangeEvent> get settingsChangeStream => _settingsChangeController.stream;

  @override
  Future<void> initialize() async {
    try {
      _logger.log(_tag, 'Initializing settings service', LogLevel.info);
      
      // Initialize default values if not set
      await _initializeDefaults();
      
      _logger.log(_tag, 'Settings service initialized successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize settings service: $e', LogLevel.error);
      rethrow;
    }
  }

  // ==========================================================================
  // General App Settings
  // ==========================================================================

  @override
  Future<ThemeMode> getThemeMode() async {
    final mode = _prefs.getString(_themeKey) ?? 'system';
    return ThemeMode.values.firstWhere(
      (e) => e.name == mode,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    await _setSetting(_themeKey, mode.name);
  }

  @override
  Future<String> getLanguage() async {
    return _prefs.getString(_languageKey) ?? 'en-US';
  }

  @override
  Future<void> setLanguage(String languageCode) async {
    await _setSetting(_languageKey, languageCode);
  }

  @override
  Future<PrivacyLevel> getPrivacyLevel() async {
    final level = _prefs.getString(_privacyLevelKey) ?? 'balanced';
    return PrivacyLevel.values.firstWhere(
      (e) => e.name == level,
      orElse: () => PrivacyLevel.balanced,
    );
  }

  @override
  Future<void> setPrivacyLevel(PrivacyLevel level) async {
    await _setSetting(_privacyLevelKey, level.name);
  }

  // ==========================================================================
  // Audio Settings
  // ==========================================================================

  @override
  Future<String?> getPreferredAudioDevice() async {
    return _prefs.getString(_audioDeviceKey);
  }

  @override
  Future<void> setPreferredAudioDevice(String deviceId) async {
    await _setSetting(_audioDeviceKey, deviceId);
  }

  @override
  Future<String> getAudioQuality() async {
    return _prefs.getString(_audioQualityKey) ?? 'medium';
  }

  @override
  Future<void> setAudioQuality(String quality) async {
    await _setSetting(_audioQualityKey, quality);
  }

  @override
  Future<bool> getNoiseReductionEnabled() async {
    return _prefs.getBool(_noiseReductionKey) ?? true;
  }

  @override
  Future<void> setNoiseReductionEnabled(bool enabled) async {
    await _setSetting(_noiseReductionKey, enabled);
  }

  @override
  Future<double> getVADSensitivity() async {
    return _prefs.getDouble(_vadSensitivityKey) ?? 0.5;
  }

  @override
  Future<void> setVADSensitivity(double sensitivity) async {
    await _setSetting(_vadSensitivityKey, sensitivity.clamp(0.0, 1.0));
  }

  // ==========================================================================
  // Transcription Settings
  // ==========================================================================

  @override
  Future<String> getPreferredTranscriptionBackend() async {
    return _prefs.getString(_transcriptionBackendKey) ?? 'local';
  }

  @override
  Future<void> setPreferredTranscriptionBackend(String backend) async {
    await _setSetting(_transcriptionBackendKey, backend);
  }

  @override
  Future<String> getTranscriptionLanguage() async {
    return _prefs.getString(_transcriptionLanguageKey) ?? 'en-US';
  }

  @override
  Future<void> setTranscriptionLanguage(String languageCode) async {
    await _setSetting(_transcriptionLanguageKey, languageCode);
  }

  @override
  Future<bool> getAutomaticBackendSwitching() async {
    return _prefs.getBool(_autoBackendSwitchKey) ?? true;
  }

  @override
  Future<void> setAutomaticBackendSwitching(bool enabled) async {
    await _setSetting(_autoBackendSwitchKey, enabled);
  }

  // ==========================================================================
  // AI Service Settings
  // ==========================================================================

  @override
  Future<String> getPreferredAIProvider() async {
    return _prefs.getString(_aiProviderKey) ?? 'openai';
  }

  @override
  Future<void> setPreferredAIProvider(String provider) async {
    await _setSetting(_aiProviderKey, provider);
  }

  @override
  Future<String?> getAPIKey(String provider) async {
    final apiKeys = _getAPIKeysMap();
    return apiKeys[provider];
  }

  @override
  Future<void> setAPIKey(String provider, String apiKey) async {
    final apiKeys = _getAPIKeysMap();
    apiKeys[provider] = apiKey;
    await _setSetting(_apiKeysKey, jsonEncode(apiKeys));
  }

  @override
  Future<void> removeAPIKey(String provider) async {
    final apiKeys = _getAPIKeysMap();
    apiKeys.remove(provider);
    await _setSetting(_apiKeysKey, jsonEncode(apiKeys));
  }

  @override
  Future<bool> getFactCheckingEnabled() async {
    return _prefs.getBool(_factCheckingKey) ?? true;
  }

  @override
  Future<void> setFactCheckingEnabled(bool enabled) async {
    await _setSetting(_factCheckingKey, enabled);
  }

  @override
  Future<bool> getRealTimeAnalysisEnabled() async {
    return _prefs.getBool(_realTimeAnalysisKey) ?? false;
  }

  @override
  Future<void> setRealTimeAnalysisEnabled(bool enabled) async {
    await _setSetting(_realTimeAnalysisKey, enabled);
  }

  @override
  Future<double> getFactCheckThreshold() async {
    return _prefs.getDouble(_factCheckThresholdKey) ?? 0.7;
  }

  @override
  Future<void> setFactCheckThreshold(double threshold) async {
    await _setSetting(_factCheckThresholdKey, threshold.clamp(0.0, 1.0));
  }

  // ==========================================================================
  // Glasses Settings
  // ==========================================================================

  @override
  Future<String?> getLastConnectedGlasses() async {
    return _prefs.getString(_lastGlassesKey);
  }

  @override
  Future<void> setLastConnectedGlasses(String deviceId) async {
    await _setSetting(_lastGlassesKey, deviceId);
  }

  @override
  Future<bool> getAutoConnectGlasses() async {
    return _prefs.getBool(_autoConnectGlassesKey) ?? true;
  }

  @override
  Future<void> setAutoConnectGlasses(bool enabled) async {
    await _setSetting(_autoConnectGlassesKey, enabled);
  }

  @override
  Future<double> getHUDBrightness() async {
    return _prefs.getDouble(_hudBrightnessKey) ?? 0.8;
  }

  @override
  Future<void> setHUDBrightness(double brightness) async {
    await _setSetting(_hudBrightnessKey, brightness.clamp(0.0, 1.0));
  }

  @override
  Future<double> getGestureSensitivity() async {
    return _prefs.getDouble(_gestureSensitivityKey) ?? 0.5;
  }

  @override
  Future<void> setGestureSensitivity(double sensitivity) async {
    await _setSetting(_gestureSensitivityKey, sensitivity.clamp(0.0, 1.0));
  }

  // ==========================================================================
  // Data & Privacy Settings
  // ==========================================================================

  @override
  Future<int> getDataRetentionDays() async {
    return _prefs.getInt(_dataRetentionKey) ?? 30;
  }

  @override
  Future<void> setDataRetentionDays(int days) async {
    await _setSetting(_dataRetentionKey, days);
  }

  @override
  Future<bool> getAutomaticDataCleanup() async {
    return _prefs.getBool(_autoCleanupKey) ?? true;
  }

  @override
  Future<void> setAutomaticDataCleanup(bool enabled) async {
    await _setSetting(_autoCleanupKey, enabled);
  }

  @override
  Future<bool> getAnalyticsConsent() async {
    return _prefs.getBool(_analyticsConsentKey) ?? false;
  }

  @override
  Future<void> setAnalyticsConsent(bool consent) async {
    await _setSetting(_analyticsConsentKey, consent);
  }

  @override
  Future<bool> getCrashReportingConsent() async {
    return _prefs.getBool(_crashReportingKey) ?? false;
  }

  @override
  Future<void> setCrashReportingConsent(bool consent) async {
    await _setSetting(_crashReportingKey, consent);
  }

  // ==========================================================================
  // Backup & Sync Settings
  // ==========================================================================

  @override
  Future<bool> getCloudSyncEnabled() async {
    return _prefs.getBool(_cloudSyncKey) ?? false;
  }

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    await _setSetting(_cloudSyncKey, enabled);
  }

  @override
  Future<String> getBackupFrequency() async {
    return _prefs.getString(_backupFrequencyKey) ?? 'weekly';
  }

  @override
  Future<void> setBackupFrequency(String frequency) async {
    await _setSetting(_backupFrequencyKey, frequency);
  }

  // ==========================================================================
  // Accessibility Settings
  // ==========================================================================

  @override
  Future<bool> getLargeTextEnabled() async {
    return _prefs.getBool(_largeTextKey) ?? false;
  }

  @override
  Future<void> setLargeTextEnabled(bool enabled) async {
    await _setSetting(_largeTextKey, enabled);
  }

  @override
  Future<bool> getHighContrastEnabled() async {
    return _prefs.getBool(_highContrastKey) ?? false;
  }

  @override
  Future<void> setHighContrastEnabled(bool enabled) async {
    await _setSetting(_highContrastKey, enabled);
  }

  @override
  Future<bool> getReducedMotionEnabled() async {
    return _prefs.getBool(_reducedMotionKey) ?? false;
  }

  @override
  Future<void> setReducedMotionEnabled(bool enabled) async {
    await _setSetting(_reducedMotionKey, enabled);
  }

  // ==========================================================================
  // Advanced Settings
  // ==========================================================================

  @override
  Future<bool> getDeveloperModeEnabled() async {
    return _prefs.getBool(_developerModeKey) ?? false;
  }

  @override
  Future<void> setDeveloperModeEnabled(bool enabled) async {
    await _setSetting(_developerModeKey, enabled);
  }

  @override
  Future<bool> getDebugLoggingEnabled() async {
    return _prefs.getBool(_debugLoggingKey) ?? false;
  }

  @override
  Future<void> setDebugLoggingEnabled(bool enabled) async {
    await _setSetting(_debugLoggingKey, enabled);
  }

  @override
  Future<bool> getBetaFeaturesEnabled() async {
    return _prefs.getBool(_betaFeaturesKey) ?? false;
  }

  @override
  Future<void> setBetaFeaturesEnabled(bool enabled) async {
    await _setSetting(_betaFeaturesKey, enabled);
  }

  // ==========================================================================
  // Utility Methods
  // ==========================================================================

  @override
  Future<String> exportSettings() async {
    try {
      final allSettings = await getAllSettings();
      return jsonEncode(allSettings);
    } catch (e) {
      _logger.log(_tag, 'Failed to export settings: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> importSettings(String settingsJson) async {
    try {
      final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
      
      for (final entry in settings.entries) {
        final key = entry.key;
        final value = entry.value;
        
        // Skip API keys for security
        if (key == _apiKeysKey) continue;
        
        // Set the value based on type
        if (value is bool) {
          await _prefs.setBool(key, value);
        } else if (value is int) {
          await _prefs.setInt(key, value);
        } else if (value is double) {
          await _prefs.setDouble(key, value);
        } else if (value is String) {
          await _prefs.setString(key, value);
        }
      }
      
      _logger.log(_tag, 'Settings imported successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to import settings: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> resetToDefaults() async {
    try {
      // Clear all preferences
      await _prefs.clear();
      
      // Reinitialize defaults
      await _initializeDefaults();
      
      _logger.log(_tag, 'All settings reset to defaults', LogLevel.info);
      
      // Notify listeners
      _settingsChangeController.add(SettingsChangeEvent(
        key: 'all',
        oldValue: 'various',
        newValue: 'defaults',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      _logger.log(_tag, 'Failed to reset settings: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> resetCategory(SettingsCategory category) async {
    try {
      final keysToReset = _getCategoryKeys(category);
      
      for (final key in keysToReset) {
        await _prefs.remove(key);
      }
      
      // Reinitialize defaults for this category
      await _initializeDefaults();
      
      _logger.log(_tag, 'Settings category ${category.name} reset to defaults', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to reset category: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getAllSettings() async {
    try {
      final allKeys = _prefs.getKeys();
      final settings = <String, dynamic>{};
      
      for (final key in allKeys) {
        final value = _prefs.get(key);
        if (value != null) {
          // Don't export API keys for security
          if (key != _apiKeysKey) {
            settings[key] = value;
          }
        }
      }
      
      return settings;
    } catch (e) {
      _logger.log(_tag, 'Failed to get all settings: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _settingsChangeController.close();
      _logger.log(_tag, 'Settings service disposed', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error disposing settings service: $e', LogLevel.error);
    }
  }

  // Private methods

  Future<void> _initializeDefaults() async {
    // General defaults
    if (!_prefs.containsKey(_themeKey)) {
      await _prefs.setString(_themeKey, ThemeMode.system.name);
    }
    if (!_prefs.containsKey(_languageKey)) {
      await _prefs.setString(_languageKey, 'en-US');
    }
    if (!_prefs.containsKey(_privacyLevelKey)) {
      await _prefs.setString(_privacyLevelKey, PrivacyLevel.balanced.name);
    }
    
    // Audio defaults
    if (!_prefs.containsKey(_audioQualityKey)) {
      await _prefs.setString(_audioQualityKey, 'medium');
    }
    if (!_prefs.containsKey(_noiseReductionKey)) {
      await _prefs.setBool(_noiseReductionKey, true);
    }
    if (!_prefs.containsKey(_vadSensitivityKey)) {
      await _prefs.setDouble(_vadSensitivityKey, 0.5);
    }
    
    // Transcription defaults
    if (!_prefs.containsKey(_transcriptionBackendKey)) {
      await _prefs.setString(_transcriptionBackendKey, 'local');
    }
    if (!_prefs.containsKey(_transcriptionLanguageKey)) {
      await _prefs.setString(_transcriptionLanguageKey, 'en-US');
    }
    if (!_prefs.containsKey(_autoBackendSwitchKey)) {
      await _prefs.setBool(_autoBackendSwitchKey, true);
    }
    
    // AI defaults
    if (!_prefs.containsKey(_aiProviderKey)) {
      await _prefs.setString(_aiProviderKey, 'openai');
    }
    if (!_prefs.containsKey(_factCheckingKey)) {
      await _prefs.setBool(_factCheckingKey, true);
    }
    if (!_prefs.containsKey(_realTimeAnalysisKey)) {
      await _prefs.setBool(_realTimeAnalysisKey, false);
    }
    if (!_prefs.containsKey(_factCheckThresholdKey)) {
      await _prefs.setDouble(_factCheckThresholdKey, 0.7);
    }
    
    // Glasses defaults
    if (!_prefs.containsKey(_autoConnectGlassesKey)) {
      await _prefs.setBool(_autoConnectGlassesKey, true);
    }
    if (!_prefs.containsKey(_hudBrightnessKey)) {
      await _prefs.setDouble(_hudBrightnessKey, 0.8);
    }
    if (!_prefs.containsKey(_gestureSensitivityKey)) {
      await _prefs.setDouble(_gestureSensitivityKey, 0.5);
    }
    
    // Privacy defaults
    if (!_prefs.containsKey(_dataRetentionKey)) {
      await _prefs.setInt(_dataRetentionKey, 30);
    }
    if (!_prefs.containsKey(_autoCleanupKey)) {
      await _prefs.setBool(_autoCleanupKey, true);
    }
    if (!_prefs.containsKey(_analyticsConsentKey)) {
      await _prefs.setBool(_analyticsConsentKey, false);
    }
    if (!_prefs.containsKey(_crashReportingKey)) {
      await _prefs.setBool(_crashReportingKey, false);
    }
    
    // Backup defaults
    if (!_prefs.containsKey(_cloudSyncKey)) {
      await _prefs.setBool(_cloudSyncKey, false);
    }
    if (!_prefs.containsKey(_backupFrequencyKey)) {
      await _prefs.setString(_backupFrequencyKey, 'weekly');
    }
    
    // Accessibility defaults
    if (!_prefs.containsKey(_largeTextKey)) {
      await _prefs.setBool(_largeTextKey, false);
    }
    if (!_prefs.containsKey(_highContrastKey)) {
      await _prefs.setBool(_highContrastKey, false);
    }
    if (!_prefs.containsKey(_reducedMotionKey)) {
      await _prefs.setBool(_reducedMotionKey, false);
    }
    
    // Advanced defaults
    if (!_prefs.containsKey(_developerModeKey)) {
      await _prefs.setBool(_developerModeKey, false);
    }
    if (!_prefs.containsKey(_debugLoggingKey)) {
      await _prefs.setBool(_debugLoggingKey, false);
    }
    if (!_prefs.containsKey(_betaFeaturesKey)) {
      await _prefs.setBool(_betaFeaturesKey, false);
    }
  }

  Map<String, String> _getAPIKeysMap() {
    final apiKeysJson = _prefs.getString(_apiKeysKey);
    if (apiKeysJson == null) return {};
    
    try {
      final decoded = jsonDecode(apiKeysJson) as Map<String, dynamic>;
      return decoded.cast<String, String>();
    } catch (e) {
      _logger.log(_tag, 'Error parsing API keys: $e', LogLevel.warning);
      return {};
    }
  }

  Future<void> _setSetting(String key, dynamic value) async {
    final oldValue = _prefs.get(key);
    
    // Set the value based on type
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else {
      throw ArgumentError('Unsupported setting type: ${value.runtimeType}');
    }
    
    // Notify listeners of the change
    _settingsChangeController.add(SettingsChangeEvent(
      key: key,
      oldValue: oldValue,
      newValue: value,
      timestamp: DateTime.now(),
    ));
    
    _logger.log(_tag, 'Setting changed: $key = $value', LogLevel.debug);
  }

  List<String> _getCategoryKeys(SettingsCategory category) {
    switch (category) {
      case SettingsCategory.general:
        return [_themeKey, _languageKey, _privacyLevelKey];
      case SettingsCategory.audio:
        return [_audioDeviceKey, _audioQualityKey, _noiseReductionKey, _vadSensitivityKey];
      case SettingsCategory.transcription:
        return [_transcriptionBackendKey, _transcriptionLanguageKey, _autoBackendSwitchKey];
      case SettingsCategory.ai:
        return [_aiProviderKey, _apiKeysKey, _factCheckingKey, _realTimeAnalysisKey, _factCheckThresholdKey];
      case SettingsCategory.glasses:
        return [_lastGlassesKey, _autoConnectGlassesKey, _hudBrightnessKey, _gestureSensitivityKey];
      case SettingsCategory.privacy:
        return [_dataRetentionKey, _autoCleanupKey, _analyticsConsentKey, _crashReportingKey, _cloudSyncKey, _backupFrequencyKey];
      case SettingsCategory.accessibility:
        return [_largeTextKey, _highContrastKey, _reducedMotionKey];
      case SettingsCategory.advanced:
        return [_developerModeKey, _debugLoggingKey, _betaFeaturesKey];
    }
  }
}