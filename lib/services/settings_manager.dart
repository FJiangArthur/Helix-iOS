import 'dart:convert';
import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/assistant_profile.dart';
import '../models/hud_widget_config.dart';

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

  /// Active LLM provider: 'openai', 'openrouter', 'anthropic', 'deepseek', 'qwen', 'zhipu'.
  String activeProviderId = 'openai';

  /// Active model within the selected provider (null = use provider default).
  String? activeModel;

  /// Sampling temperature, 0.0 - 1.0.
  double temperature = 0.7;

  /// Model for background tasks (detection, analysis). Null = use provider default.
  String? lightModel;

  /// Model for user-facing responses. Null = use provider default.
  String? smartModel;

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

  /// Maximum sentences in AI responses sent to glasses (1-10).
  int maxResponseSentences = 3;

  /// Whether Home should auto-expand summary tools.
  bool autoShowSummary = true;

  /// Whether Home should auto-expand follow-up tools.
  bool autoShowFollowUps = true;

  /// Transcription language code: 'en', 'zh', etc.
  String language = 'en';

  /// UI display language code (separate from transcription language).
  String uiLanguage = 'en';

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

  /// Transcription backend: 'openai', 'appleCloud', 'appleOnDevice', 'whisper'.
  String transcriptionBackend = 'openai';

  /// Whether speaker diarization is enabled (Whisper and Apple Speech backends).
  bool enableDiarization = false;

  /// Chunk duration for Whisper batch transcription in seconds (3, 5, or 10).
  int whisperChunkDurationSec = 5;

  /// OpenAI session mode: 'transcription' or 'realtime'.
  String openAISessionMode = 'transcription';

  /// Model for OpenAI transcription.
  String transcriptionModel = 'gpt-4o-mini-transcribe';

  /// Optional prompt override for OpenAI realtime conversation mode.
  String? openAIRealtimePrompt;

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

  /// Whether tilt gestures can open the dashboard overlay on the glasses.
  bool dashboardTiltEnabled = true;

  /// HUD render path: 'text' (fallback), 'bitmap', or 'enhanced'.
  String hudRenderPath = 'bitmap';

  /// Active bitmap layout preset ID: 'classic', 'minimal', 'dense', 'conversation'.
  String bitmapLayoutPreset = 'classic';

  /// Active enhanced layout preset ID: 'command_center', 'cockpit', 'focus'.
  String enhancedLayoutPreset = 'command_center';

  /// Stock ticker symbol for the bitmap HUD stock widget.
  String stockTicker = '^DJI';

  // ---------------------------------------------------------------------------
  // HUD Widget Settings
  // ---------------------------------------------------------------------------

  /// Ordered list of widget configurations for the HUD dashboard.
  List<HudWidgetConfig> hudWidgetConfigs = HudWidgetConfig.defaults;

  /// Whether real-time sentiment monitoring is enabled.
  bool sentimentMonitorEnabled = false;

  /// Whether entity memory cards are enabled.
  bool entityMemoryEnabled = false;

  /// Whether AI responses can use web search for fact-checking.
  bool webSearchEnabled = true;

  /// Whether live translation is enabled for foreign-language transcripts.
  bool translationEnabled = false;

  /// ISO language code for translation target (e.g. 'en', 'zh', 'ja').
  String translationTargetLanguage = 'en';

  /// Whether voice responses are enabled (OpenAI Realtime audio output).
  bool voiceResponseEnabled = false;

  /// Voice for OpenAI Realtime audio output.
  String voiceAssistantVoice = 'alloy';

  // ---------------------------------------------------------------------------
  // V2.2 Offline Assistant Settings
  // ---------------------------------------------------------------------------

  /// Silence timeout in minutes before auto-stopping recording (5-30).
  int silenceTimeoutMinutes = 15;

  /// Double press action: 'bookmark' or 'force_process'.
  String doublePressAction = 'bookmark';

  /// Long press mode: 'voice_note' or 'walkie_talkie'.
  String longPressMode = 'voice_note';

  /// Whether cloud processing pipeline runs automatically after each conversation.
  bool cloudProcessingEnabled = true;

  /// Whether daily memory generation is enabled.
  bool dailyMemoryEnabled = true;

  /// Whether facts extraction is enabled.
  bool factsExtractionEnabled = true;

  // ---------------------------------------------------------------------------
  // All-Day Mode & Knowledge Base
  // ---------------------------------------------------------------------------

  /// Whether all-day continuous recording mode is enabled.
  bool allDayModeEnabled = false;

  /// Analysis backend: 'cloud', 'llama', or 'foundation'.
  String analysisBackend = 'cloud';

  /// Cloud provider for analysis when backend is 'cloud'.
  String analysisCloudProvider = 'openai';

  /// Local LLaMA model identifier for on-device analysis.
  String llamaModelId = 'qwen2.5-1.5b-q4km';

  /// Voice activity detection energy threshold in dB.
  double vadThreshold = -40.0;

  /// Interval in minutes between batch analysis passes.
  int batchAnalysisIntervalMinutes = 5;

  /// Whether the user profile auto-updates from conversations.
  bool profileAutoUpdateEnabled = true;

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

  String? get resolvedLightModel {
    final explicit = lightModel?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    switch (activeProviderId) {
      case 'openai':
        return 'gpt-5.4-mini';
      default:
        return null;
    }
  }

  String? get resolvedSmartModel {
    final explicit = smartModel?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    switch (activeProviderId) {
      case 'openai':
        return 'gpt-5.4';
      default:
        return null;
    }
  }

  bool get usesOpenAIRealtimeSession =>
      transcriptionBackend == 'openai' && openAISessionMode == 'realtime';

  /// Load all settings from SharedPreferences, applying defaults for any
  /// values that have not been persisted yet.
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    final prefs = _prefs!;

    // LLM
    activeProviderId = prefs.getString('activeProviderId') ?? 'openai';
    activeModel = prefs.getString('activeModel');
    lightModel = prefs.getString('lightModel');
    smartModel = prefs.getString('smartModel');
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
    maxResponseSentences = prefs.getInt('maxResponseSentences') ?? 3;
    language = prefs.getString('language') ?? 'en';
    uiLanguage = prefs.getString('uiLanguage') ?? 'en';
    _assistantProfiles = _restoreAssistantProfiles(
      prefs.getString('assistantProfiles'),
    );

    // Audio
    noiseReduction = prefs.getBool('noiseReduction') ?? true;
    voiceActivityDetection = prefs.getBool('voiceActivityDetection') ?? true;
    vadSensitivity = prefs.getDouble('vadSensitivity') ?? 0.5;

    // Transcription
    transcriptionBackend = prefs.getString('transcriptionBackend') ?? 'openai';
    if (transcriptionBackend == 'openaiRealtime') {
      transcriptionBackend = 'openai';
      openAISessionMode = 'realtime';
    } else {
      openAISessionMode =
          prefs.getString('openAISessionMode') ?? 'transcription';
    }
    transcriptionModel =
        prefs.getString('transcriptionModel') ?? 'gpt-4o-mini-transcribe';
    openAIRealtimePrompt = prefs.getString('openAIRealtimePrompt');
    preferredMicSource = prefs.getString('preferredMicSource') ?? 'auto';
    enableDiarization = prefs.getBool('enableDiarization') ?? false;
    whisperChunkDurationSec = prefs.getInt('whisperChunkDurationSec') ?? 5;

    // Glasses
    autoConnect = prefs.getBool('autoConnect') ?? true;
    hudBrightness = prefs.getDouble('hudBrightness') ?? 0.7;
    displayMode = prefs.getString('displayMode') ?? 'standard';
    dashboardTiltEnabled = prefs.getBool('dashboardTiltEnabled') ?? true;
    hudRenderPath = prefs.getString('hudRenderPath') ?? 'bitmap';
    bitmapLayoutPreset = prefs.getString('bitmapLayoutPreset') ?? 'classic';
    enhancedLayoutPreset =
        prefs.getString('enhancedLayoutPreset') ?? 'command_center';
    stockTicker = prefs.getString('stockTicker') ?? '^DJI';

    // HUD Widgets
    hudWidgetConfigs = _restoreWidgetConfigs(
      prefs.getString('hudWidgetConfigs'),
    );
    sentimentMonitorEnabled = prefs.getBool('sentimentMonitorEnabled') ?? false;
    entityMemoryEnabled = prefs.getBool('entityMemoryEnabled') ?? false;
    webSearchEnabled = prefs.getBool('webSearchEnabled') ?? true;
    translationEnabled = prefs.getBool('translationEnabled') ?? false;
    translationTargetLanguage =
        prefs.getString('translationTargetLanguage') ?? 'en';
    voiceResponseEnabled = prefs.getBool('voiceResponseEnabled') ?? false;
    voiceAssistantVoice = prefs.getString('voiceAssistantVoice') ?? 'alloy';

    // V2.2 Offline Assistant
    silenceTimeoutMinutes = prefs.getInt('silenceTimeoutMinutes') ?? 15;
    doublePressAction = prefs.getString('doublePressAction') ?? 'bookmark';
    longPressMode = prefs.getString('longPressMode') ?? 'voice_note';
    cloudProcessingEnabled = prefs.getBool('cloudProcessingEnabled') ?? true;
    dailyMemoryEnabled = prefs.getBool('dailyMemoryEnabled') ?? true;
    factsExtractionEnabled = prefs.getBool('factsExtractionEnabled') ?? true;

    // All-Day Mode & Knowledge Base
    allDayModeEnabled = prefs.getBool('allDayModeEnabled') ?? false;
    analysisBackend = prefs.getString('analysisBackend') ?? 'cloud';
    analysisCloudProvider =
        prefs.getString('analysisCloudProvider') ?? 'openai';
    llamaModelId = prefs.getString('llamaModelId') ?? 'qwen2.5-1.5b-q4km';
    vadThreshold = prefs.getDouble('vadThreshold') ?? -40.0;
    batchAnalysisIntervalMinutes =
        prefs.getInt('batchAnalysisIntervalMinutes') ?? 5;
    profileAutoUpdateEnabled =
        prefs.getBool('profileAutoUpdateEnabled') ?? true;

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
    if (lightModel != null) {
      await prefs.setString('lightModel', lightModel!);
    } else {
      await prefs.remove('lightModel');
    }
    if (smartModel != null) {
      await prefs.setString('smartModel', smartModel!);
    } else {
      await prefs.remove('smartModel');
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
    await prefs.setInt('maxResponseSentences', maxResponseSentences);
    await prefs.setString('language', language);
    await prefs.setString('uiLanguage', uiLanguage);
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
    await prefs.setString('openAISessionMode', openAISessionMode);
    await prefs.setString('transcriptionModel', transcriptionModel);
    if (openAIRealtimePrompt != null &&
        openAIRealtimePrompt!.trim().isNotEmpty) {
      await prefs.setString(
        'openAIRealtimePrompt',
        openAIRealtimePrompt!.trim(),
      );
    } else {
      await prefs.remove('openAIRealtimePrompt');
    }
    await prefs.setString('preferredMicSource', preferredMicSource);
    await prefs.setBool('enableDiarization', enableDiarization);
    await prefs.setInt('whisperChunkDurationSec', whisperChunkDurationSec);

    // Glasses
    await prefs.setBool('autoConnect', autoConnect);
    await prefs.setDouble('hudBrightness', hudBrightness);
    await prefs.setString('displayMode', displayMode);
    await prefs.setBool('dashboardTiltEnabled', dashboardTiltEnabled);
    await prefs.setString('hudRenderPath', hudRenderPath);
    await prefs.setString('bitmapLayoutPreset', bitmapLayoutPreset);
    await prefs.setString('enhancedLayoutPreset', enhancedLayoutPreset);
    await prefs.setString('stockTicker', stockTicker);

    // HUD Widgets
    await prefs.setString(
      'hudWidgetConfigs',
      jsonEncode(hudWidgetConfigs.map((c) => c.toMap()).toList()),
    );
    await prefs.setBool('sentimentMonitorEnabled', sentimentMonitorEnabled);
    await prefs.setBool('entityMemoryEnabled', entityMemoryEnabled);
    await prefs.setBool('webSearchEnabled', webSearchEnabled);
    await prefs.setBool('translationEnabled', translationEnabled);
    await prefs.setString(
      'translationTargetLanguage',
      translationTargetLanguage,
    );
    await prefs.setBool('voiceResponseEnabled', voiceResponseEnabled);
    await prefs.setString('voiceAssistantVoice', voiceAssistantVoice);

    // V2.2 Offline Assistant
    await prefs.setInt('silenceTimeoutMinutes', silenceTimeoutMinutes);
    await prefs.setString('doublePressAction', doublePressAction);
    await prefs.setString('longPressMode', longPressMode);
    await prefs.setBool('cloudProcessingEnabled', cloudProcessingEnabled);
    await prefs.setBool('dailyMemoryEnabled', dailyMemoryEnabled);
    await prefs.setBool('factsExtractionEnabled', factsExtractionEnabled);

    // All-Day Mode & Knowledge Base
    await prefs.setBool('allDayModeEnabled', allDayModeEnabled);
    await prefs.setString('analysisBackend', analysisBackend);
    await prefs.setString('analysisCloudProvider', analysisCloudProvider);
    await prefs.setString('llamaModelId', llamaModelId);
    await prefs.setDouble('vadThreshold', vadThreshold);
    await prefs.setInt(
      'batchAnalysisIntervalMinutes',
      batchAnalysisIntervalMinutes,
    );
    await prefs.setBool('profileAutoUpdateEnabled', profileAutoUpdateEnabled);

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

  List<HudWidgetConfig> _restoreWidgetConfigs(String? raw) {
    if (raw == null || raw.isEmpty) return HudWidgetConfig.defaults;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final configs = decoded
          .whereType<Map<String, dynamic>>()
          .map(HudWidgetConfig.fromMap)
          .toList();
      return configs.isEmpty ? HudWidgetConfig.defaults : configs;
    } catch (_) {
      return HudWidgetConfig.defaults;
    }
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
    await _secureStorage.write(key: '$_apiKeyPrefix$providerId', value: apiKey);
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
      'openrouter',
      'anthropic',
      'deepseek',
      'qwen',
      'zhipu',
      'siliconflow',
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
