// ABOUTME: Dependency injection service locator for all app services
// ABOUTME: Configures get_it container with singleton and factory patterns

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Service interfaces
import 'audio_service.dart';
import 'transcription_service.dart';
import 'llm_service.dart';
import 'glasses_service.dart';
import 'settings_service.dart';

// Service implementations
import 'implementations/audio_service_impl.dart';
// TODO: Implement other service implementations
// import 'implementations/transcription_service_impl.dart';
// import 'implementations/llm_service_impl.dart';
// import 'implementations/glasses_service_impl.dart';
// import 'implementations/settings_service_impl.dart';

// Providers
import '../providers/app_state_provider.dart';

// Utils
import '../core/utils/logging_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  static ServiceLocator get instance => _instance;
  
  ServiceLocator._internal();
  
  final GetIt _getIt = GetIt.instance;
  
  T get<T extends Object>() => _getIt.get<T>();
  
  bool isRegistered<T extends Object>() => _getIt.isRegistered<T>();

  /// Initialize all services and dependencies
  Future<void> initialize() async {
    try {
      logger.info('ServiceLocator', 'Initializing dependency injection...');
      
      // Initialize SharedPreferences
      final sharedPreferences = await SharedPreferences.getInstance();
      _getIt.registerSingleton<SharedPreferences>(sharedPreferences);
      
      // Register core services
      await _registerServices();
      
      // Register providers
      await _registerProviders();
      
      logger.info('ServiceLocator', 'Dependency injection initialized successfully');
    } catch (e, stackTrace) {
      logger.error('ServiceLocator', 'Failed to initialize dependency injection', e, stackTrace);
      rethrow;
    }
  }
  
  /// Register core services
  Future<void> _registerServices() async {
    // Audio Service
    _getIt.registerLazySingleton<AudioService>(() => AudioServiceImpl(logger: logger));
    
    // TODO: Register other services as they are implemented
    // _getIt.registerLazySingleton<TranscriptionService>(() => TranscriptionServiceImpl());
    // _getIt.registerLazySingleton<LLMService>(() => LLMServiceImpl());
    // _getIt.registerLazySingleton<GlassesService>(() => GlassesServiceImpl());
    // _getIt.registerLazySingleton<SettingsService>(() => SettingsServiceImpl());
  }
  
  /// Register providers
  Future<void> _registerProviders() async {
    // Create AppStateProvider with required dependencies
    _getIt.registerLazySingleton<AppStateProvider>(
      () => AppStateProvider(
        logger: logger,
        audioService: _getIt<AudioService>(),
        transcriptionService: _MockTranscriptionService(),
        llmService: _MockLLMService(),
        glassesService: _MockGlassesService(),
        settingsService: _MockSettingsService(),
      ),
    );
    
    // Initialize the app state
    final appState = _getIt<AppStateProvider>();
    await appState.initialize();
  }
}

/// Initialize dependency injection container - backward compatibility
Future<void> setupServiceLocator() async {
  await ServiceLocator.instance.initialize();
}

/// Reset all registered services and providers
/// Useful for testing and app restart scenarios
Future<void> resetServiceLocator() async {
  await ServiceLocator.instance._getIt.reset();
}

// Temporary mock implementations for services not yet implemented

class _MockTranscriptionService implements TranscriptionService {
  @override
  bool get isInitialized => true;

  @override
  bool get isTranscribing => false;

  @override
  String get currentLanguage => 'en-US';

  @override
  Stream<TranscriptionSegment> get transcriptionStream => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startTranscription() async {}

  @override
  Future<void> stopTranscription() async {}

  @override
  Future<void> pauseTranscription() async {}

  @override
  Future<void> resumeTranscription() async {}

  @override
  Future<void> setLanguage(String languageCode) async {}

  @override
  Future<void> dispose() async {}
}

class _MockLLMService implements LLMService {
  @override
  bool get isInitialized => false;

  @override
  String get currentProvider => 'none';

  @override
  Future<void> initialize({String? openAIKey, String? anthropicKey}) async {}

  @override
  Future<AnalysisResult> analyzeConversation(ConversationModel conversation) async {
    return AnalysisResult(
      conversationId: conversation.id,
      claims: [],
      summary: 'Mock analysis not available',
      actionItems: [],
      sentiment: 'neutral',
      confidence: 0.0,
      analysisTime: DateTime.now(),
    );
  }

  @override
  Future<List<ClaimVerification>> checkFacts(List<String> claims) async {
    return [];
  }

  @override
  Future<String> generateSummary(ConversationModel conversation) async {
    return 'Mock summary';
  }

  @override
  Future<List<String>> extractActionItems(ConversationModel conversation) async {
    return [];
  }

  @override
  Future<void> setProvider(String provider) async {}

  @override
  Future<void> dispose() async {}
}

class _MockGlassesService implements GlassesService {
  @override
  ConnectionStatus get connectionState => ConnectionStatus.disconnected;

  @override
  GlassesDevice? get connectedDevice => null;

  @override
  bool get isConnected => false;

  @override
  Stream<ConnectionStatus> get connectionStateStream => Stream.value(ConnectionStatus.disconnected);

  @override
  Stream<List<GlassesDevice>> get discoveredDevicesStream => const Stream.empty();

  @override
  Stream<TouchGesture> get gestureStream => const Stream.empty();

  @override
  Stream<GlassesDeviceStatus> get deviceStatusStream => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isBluetoothAvailable() async => false;

  @override
  Future<bool> requestBluetoothPermission() async => false;

  @override
  Future<void> startScanning({Duration timeout = const Duration(seconds: 30)}) async {}

  @override
  Future<void> stopScanning() async {}

  @override
  Future<void> connectToDevice(String deviceId) async {}

  @override
  Future<void> connectToLastDevice() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> displayText(String text, {HUDPosition position = HUDPosition.center, Duration? duration, HUDStyle? style}) async {}

  @override
  Future<void> displayNotification(String title, String message, {NotificationPriority priority = NotificationPriority.normal, Duration duration = const Duration(seconds: 5)}) async {}

  @override
  Future<void> clearDisplay() async {}

  @override
  Future<void> setBrightness(double brightness) async {}

  @override
  Future<void> configureGestures({bool enableTap = true, bool enableSwipe = true, bool enableLongPress = true, double sensitivity = 0.5}) async {}

  @override
  Future<void> sendCommand(String command, {Map<String, dynamic>? parameters}) async {}

  @override
  Future<GlassesDeviceInfo> getDeviceInfo() async {
    throw UnimplementedError('Mock glasses service');
  }

  @override
  Future<double> getBatteryLevel() async => 0.0;

  @override
  Future<GlassesHealthStatus> checkDeviceHealth() async {
    throw UnimplementedError('Mock glasses service');
  }

  @override
  Future<void> updateFirmware() async {}

  @override
  Future<void> dispose() async {}
}

class _MockSettingsService implements SettingsService {
  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<ThemeMode> getThemeMode() async => ThemeMode.system;

  @override
  Future<void> setThemeMode(ThemeMode mode) async {}

  @override
  Future<String> getLanguage() async => 'en-US';

  @override
  Future<void> setLanguage(String languageCode) async {}

  @override
  Future<double> getVADSensitivity() async => 0.5;

  @override
  Future<void> setVADSensitivity(double sensitivity) async {}

  @override
  Future<String?> getAPIKey(String provider) async => null;

  @override
  Future<void> setAPIKey(String provider, String key) async {}

  @override
  Future<Map<String, dynamic>> getAllSettings() async => {};

  @override
  Future<void> resetToDefaults() async {}

  @override
  Future<void> dispose() async {}
}