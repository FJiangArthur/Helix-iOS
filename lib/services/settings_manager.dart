import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/assistant_profile.dart';

/// Singleton service that persists all app settings.
///
/// General settings are stored via SharedPreferences.
/// API keys are stored via FlutterSecureStorage.
/// Emits on [onSettingsChanged] whenever any setting is updated.
class SettingsManager {
  SettingsManager._();

  static SettingsManager? _instance;
  static SettingsManager get instance => _instance ??= SettingsManager._();

  SharedPreferences? _prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final StreamController<SettingsManager> _changesController =
      StreamController<SettingsManager>.broadcast();

  /// Stream that fires whenever settings are updated.
  Stream<SettingsManager> get onSettingsChanged => _changesController.stream;

  // ---------------------------------------------------------------------------
  // LLM Settings
  // ---------------------------------------------------------------------------

  /// Active LLM provider: 'openai', 'anthropic', 'deepseek', 'qwen', 'zhipu'.
  String activeProviderId = 'openai';

  /// Active model within the selected provider (null = use provider default).
  String? activeModel;

  /// Sampling temperature, 0.0 - 1.0.
  double temperature = 0.7;

  // ---------------------------------------------------------------------------
  // Conversation Settings
  // ---------------------------------------------------------------------------

  /// Whether the app automatically detects questions in speech.
  bool autoDetectQuestions = true;

  /// When true, answers detected questions automatically.
  /// When false, asks for confirmation first.
  bool autoAnswerQuestions = true;

  /// Conversation mode: 'passive', 'interview', 'general'.
  String conversationMode = 'general';

  /// Active assistant profile identifier.
  String assistantProfileId = 'general';

  /// Default quick ask preset identifier.
  String defaultQuickAskPreset = 'concise';

  /// Whether Home should auto-expand summary tools.
  bool autoShowSummary = true;

  /// Whether Home should auto-expand follow-up tools.
  bool autoShowFollowUps = true;

  /// Language code: 'en', 'zh', etc.
  String language = 'en';

  List<AssistantProfile> _assistantProfiles = AssistantProfile.defaults;

  // ---------------------------------------------------------------------------
  // Audio Settings
  // ---------------------------------------------------------------------------

  /// Whether noise reduction is enabled.
  bool noiseReduction = true;

  /// Whether voice activity detection is enabled.
  bool voiceActivityDetection = true;

  /// VAD sensitivity, 0.0 - 1.0.
  double vadSensitivity = 0.5;

  // ---------------------------------------------------------------------------
  // Transcription Settings
  // ---------------------------------------------------------------------------

  /// Transcription backend: 'openai', 'appleCloud', 'appleOnDevice'.
  String transcriptionBackend = 'openai';

  /// Model for OpenAI transcription.
  String transcriptionModel = 'gpt-4o-mini-transcribe';

  /// Preferred mic source: 'auto', 'glasses', 'phone'.
  String preferredMicSource = 'auto';

  // ---------------------------------------------------------------------------
  // Glasses Settings
  // ---------------------------------------------------------------------------

  /// Whether to automatically connect to glasses on app start.
  bool autoConnect = true;

  /// HUD brightness, 0.0 - 1.0.
  double hudBrightness = 0.7;

  /// Display mode: 'minimal', 'standard', 'detailed'.
  String displayMode = 'standard';

  // ---------------------------------------------------------------------------
  // UI Settings
  // ---------------------------------------------------------------------------

  /// Theme: 'dark' (default, for glassmorphism), 'light', 'system'.
  String theme = 'dark';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  List<AssistantProfile> get assistantProfiles =>
      List.unmodifiable(_assistantProfiles);

  AssistantProfile resolveAssistantProfile([String? id]) {
    final profileId = id ?? assistantProfileId;
    return _assistantProfiles.firstWhere(
      (profile) => profile.id == profileId,
      orElse: () => AssistantProfile.fallback(profileId),
    );
  }

  /// Load all settings from SharedPreferences, applying defaults for any
  /// values that have not been persisted yet.
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    final prefs = _prefs!;

    // LLM
    activeProviderId = prefs.getString('activeProviderId') ?? 'openai';
    activeModel = prefs.getString('activeModel');
    temperature = prefs.getDouble('temperature') ?? 0.7;

    // Conversation
    autoDetectQuestions = prefs.getBool('autoDetectQuestions') ?? true;
    autoAnswerQuestions = prefs.getBool('autoAnswerQuestions') ?? true;
    conversationMode = prefs.getString('conversationMode') ?? 'general';
    assistantProfileId = prefs.getString('assistantProfileId') ?? 'general';
    defaultQuickAskPreset =
        prefs.getString('defaultQuickAskPreset') ?? 'concise';
    autoShowSummary = prefs.getBool('autoShowSummary') ?? true;
    autoShowFollowUps = prefs.getBool('autoShowFollowUps') ?? true;
    language = prefs.getString('language') ?? 'en';
    _assistantProfiles = _restoreAssistantProfiles(
      prefs.getString('assistantProfiles'),
    );

    // Audio
    noiseReduction = prefs.getBool('noiseReduction') ?? true;
    voiceActivityDetection = prefs.getBool('voiceActivityDetection') ?? true;
    vadSensitivity = prefs.getDouble('vadSensitivity') ?? 0.5;

    // Transcription
    transcriptionBackend =
        prefs.getString('transcriptionBackend') ?? 'openai';
    transcriptionModel =
        prefs.getString('transcriptionModel') ?? 'gpt-4o-mini-transcribe';
    preferredMicSource =
        prefs.getString('preferredMicSource') ?? 'auto';

    // Glasses
    autoConnect = prefs.getBool('autoConnect') ?? true;
    hudBrightness = prefs.getDouble('hudBrightness') ?? 0.7;
    displayMode = prefs.getString('displayMode') ?? 'standard';

    // UI
    theme = prefs.getString('theme') ?? 'dark';
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Persist all current settings to SharedPreferences and notify listeners.
  ///
  /// If [initialize] has not been called yet, this will initialize first.
  Future<void> save() async {
    if (_prefs == null) {
      await initialize();
    }
    final prefs = _prefs!;
    // LLM
    await prefs.setString('activeProviderId', activeProviderId);
    if (activeModel != null) {
      await prefs.setString('activeModel', activeModel!);
    } else {
      await prefs.remove('activeModel');
    }
    await prefs.setDouble('temperature', temperature);

    // Conversation
    await prefs.setBool('autoDetectQuestions', autoDetectQuestions);
    await prefs.setBool('autoAnswerQuestions', autoAnswerQuestions);
    await prefs.setString('conversationMode', conversationMode);
    await prefs.setString('assistantProfileId', assistantProfileId);
    await prefs.setString('defaultQuickAskPreset', defaultQuickAskPreset);
    await prefs.setBool('autoShowSummary', autoShowSummary);
    await prefs.setBool('autoShowFollowUps', autoShowFollowUps);
    await prefs.setString('language', language);
    await prefs.setString(
      'assistantProfiles',
      jsonEncode(_assistantProfiles.map((profile) => profile.toMap()).toList()),
    );

    // Audio
    await prefs.setBool('noiseReduction', noiseReduction);
    await prefs.setBool('voiceActivityDetection', voiceActivityDetection);
    await prefs.setDouble('vadSensitivity', vadSensitivity);

    // Transcription
    await prefs.setString('transcriptionBackend', transcriptionBackend);
    await prefs.setString('transcriptionModel', transcriptionModel);
    await prefs.setString('preferredMicSource', preferredMicSource);

    // Glasses
    await prefs.setBool('autoConnect', autoConnect);
    await prefs.setDouble('hudBrightness', hudBrightness);
    await prefs.setString('displayMode', displayMode);

    // UI
    await prefs.setString('theme', theme);

    _changesController.add(this);
  }

  /// Update multiple settings at once and persist.
  ///
  /// The [updater] callback receives this instance so callers can set
  /// whichever fields they need before a single `save()` call.
  ///
  /// ```dart
  /// await settings.update((s) {
  ///   s.temperature = 0.9;
  ///   s.conversationMode = 'interview';
  /// });
  /// ```
  Future<void> update(void Function(SettingsManager settings) updater) async {
    updater(this);
    await save();
  }

  Future<void> saveAssistantProfile(AssistantProfile profile) async {
    final nextProfiles = [..._assistantProfiles];
    final index = nextProfiles.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      nextProfiles.add(profile);
    } else {
      nextProfiles[index] = profile;
    }
    _assistantProfiles = AssistantProfile.normalize(nextProfiles);
    await save();
  }

  List<AssistantProfile> _restoreAssistantProfiles(String? raw) {
    if (raw == null || raw.isEmpty) {
      return AssistantProfile.defaults;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final profiles = decoded
          .whereType<Map<String, dynamic>>()
          .map(AssistantProfile.fromMap)
          .toList();
      return AssistantProfile.normalize(profiles);
    } catch (_) {
      return AssistantProfile.defaults;
    }
  }

  // ---------------------------------------------------------------------------
  // Secure API Key Storage
  // ---------------------------------------------------------------------------

  static const String _apiKeyPrefix = 'helix_api_key_';

  /// Store an API key for the given [providerId].
  Future<void> setApiKey(String providerId, String apiKey) async {
    await _secureStorage.write(
      key: '$_apiKeyPrefix$providerId',
      value: apiKey,
    );
  }

  /// Retrieve the API key for [providerId], or null if not configured.
  Future<String?> getApiKey(String providerId) async {
    return _secureStorage.read(key: '$_apiKeyPrefix$providerId');
  }

  /// Delete the API key for [providerId].
  Future<void> deleteApiKey(String providerId) async {
    await _secureStorage.delete(key: '$_apiKeyPrefix$providerId');
  }

  /// Returns a map of provider IDs to whether they have an API key configured.
  Future<Map<String, bool>> getConfiguredProviders() async {
    const providerIds = [
      'openai',
      'anthropic',
      'deepseek',
      'qwen',
      'zhipu',
    ];

    final result = <String, bool>{};
    for (final id in providerIds) {
      final key = await _secureStorage.read(key: '$_apiKeyPrefix$id');
      result[id] = key != null && key.isNotEmpty;
    }
    return result;
  }

  /// Clean up resources.
  void dispose() {
    _changesController.close();
  }
}
