// ABOUTME: Main application state provider managing global app state
// ABOUTME: Coordinates all service states and provides unified state management

import 'package:flutter/foundation.dart';

import '../services/audio_service.dart';
import '../services/transcription_service.dart';
import '../services/llm_service.dart';
import '../services/glasses_service.dart';
import '../services/settings_service.dart';
import '../models/conversation_model.dart';
import '../models/glasses_connection_state.dart' as model;
import '../models/audio_configuration.dart';
import '../core/utils/logging_service.dart';

/// Main application state provider
class AppStateProvider extends ChangeNotifier {
  static const String _tag = 'AppStateProvider';

  final LoggingService _logger;
  final AudioService _audioService;
  final TranscriptionService _transcriptionService;
  final LLMService _llmService;
  final GlassesService _glassesService;
  final SettingsService _settingsService;

  // Current app state
  AppStatus _appStatus = AppStatus.initializing;
  String? _currentError;
  DateTime? _lastErrorTime;

  // Current conversation
  ConversationModel? _currentConversation;
  bool _isRecording = false;
  final bool _isAnalyzing = false;

  // Service states
  bool _audioServiceReady = false;
  bool _transcriptionServiceReady = false;
  bool _llmServiceReady = false;
  bool _glassesServiceReady = false;
  bool _settingsServiceReady = false;

  // Connection states
  model.GlassesConnectionState _glassesConnectionState = const model.GlassesConnectionState();
  
  // Settings
  bool _darkMode = false;
  String _currentLanguage = 'en-US';
  double _audioSensitivity = 0.5;

  AppStateProvider({
    required LoggingService logger,
    required AudioService audioService,
    required TranscriptionService transcriptionService,
    required LLMService llmService,
    required GlassesService glassesService,
    required SettingsService settingsService,
  })  : _logger = logger,
        _audioService = audioService,
        _transcriptionService = transcriptionService,
        _llmService = llmService,
        _glassesService = glassesService,
        _settingsService = settingsService;

  // Getters
  AppStatus get appStatus => _appStatus;
  String? get currentError => _currentError;
  DateTime? get lastErrorTime => _lastErrorTime;
  
  ConversationModel? get currentConversation => _currentConversation;
  bool get isRecording => _isRecording;
  bool get isAnalyzing => _isAnalyzing;
  
  bool get audioServiceReady => _audioServiceReady;
  bool get transcriptionServiceReady => _transcriptionServiceReady;
  bool get llmServiceReady => _llmServiceReady;
  bool get glassesServiceReady => _glassesServiceReady;
  bool get settingsServiceReady => _settingsServiceReady;
  
  model.GlassesConnectionState get glassesConnectionState => _glassesConnectionState;
  
  bool get darkMode => _darkMode;
  String get currentLanguage => _currentLanguage;
  double get audioSensitivity => _audioSensitivity;

  /// Whether all core services are ready
  bool get allServicesReady =>
      _audioServiceReady &&
      _transcriptionServiceReady &&
      _llmServiceReady &&
      _settingsServiceReady;

  /// Whether the app is ready for conversation
  bool get readyForConversation =>
      allServicesReady && _appStatus == AppStatus.ready;

  /// Whether glasses are connected
  bool get glassesConnected => _glassesConnectionState.isConnected;

  /// Initialize the app state and all services
  Future<void> initialize() async {
    try {
      _logger.log(_tag, 'Initializing app state provider', LogLevel.info);
      _setAppStatus(AppStatus.initializing);

      // Initialize settings service first
      await _initializeSettingsService();
      
      // Load initial settings
      await _loadSettings();

      // Initialize other services
      await _initializeAudioService();
      await _initializeTranscriptionService();
      await _initializeLLMService();
      await _initializeGlassesService();

      // Set up service listeners
      _setupServiceListeners();

      _setAppStatus(AppStatus.ready);
      _logger.log(_tag, 'App state provider initialized successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize app state: $e', LogLevel.error);
      _setError('Failed to initialize app: $e');
      _setAppStatus(AppStatus.error);
    }
  }

  /// Start a new conversation
  Future<void> startConversation({String? title}) async {
    try {
      if (!readyForConversation) {
        throw Exception('App not ready for conversation');
      }

      _logger.log(_tag, 'Starting new conversation', LogLevel.info);

      final conversationId = 'conv_${DateTime.now().millisecondsSinceEpoch}';
      final conversation = ConversationModel(
        id: conversationId,
        title: title ?? 'Conversation ${DateTime.now().toString().substring(0, 16)}',
        participants: [],
        segments: [],
        startTime: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      _currentConversation = conversation;
      
      // Start audio recording
      await _audioService.startConversationRecording(conversationId);
      _isRecording = true;

      // Start transcription
      await _transcriptionService.startTranscription();

      notifyListeners();
      _logger.log(_tag, 'Conversation started: $conversationId', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to start conversation: $e', LogLevel.error);
      _setError('Failed to start conversation: $e');
    }
  }

  /// Stop the current conversation
  Future<void> stopConversation() async {
    try {
      if (_currentConversation == null) return;

      _logger.log(_tag, 'Stopping conversation: ${_currentConversation!.id}', LogLevel.info);

      // Stop recording and transcription
      await _audioService.stopConversationRecording();
      await _transcriptionService.stopTranscription();

      _isRecording = false;

      // Update conversation end time
      _currentConversation = _currentConversation!.copyWith(
        endTime: DateTime.now(),
        status: ConversationStatus.completed,
        lastUpdated: DateTime.now(),
      );

      notifyListeners();
      _logger.log(_tag, 'Conversation stopped', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to stop conversation: $e', LogLevel.error);
      _setError('Failed to stop conversation: $e');
    }
  }

  /// Toggle conversation recording
  Future<void> toggleRecording() async {
    if (_isRecording) {
      await stopConversation();
    } else {
      await startConversation();
    }
  }

  /// Connect to glasses
  Future<void> connectToGlasses() async {
    try {
      _logger.log(_tag, 'Connecting to glasses', LogLevel.info);
      await _glassesService.startScanning();
    } catch (e) {
      _logger.log(_tag, 'Failed to connect to glasses: $e', LogLevel.error);
      _setError('Failed to connect to glasses: $e');
    }
  }

  /// Disconnect from glasses
  Future<void> disconnectFromGlasses() async {
    try {
      _logger.log(_tag, 'Disconnecting from glasses', LogLevel.info);
      await _glassesService.disconnect();
    } catch (e) {
      _logger.log(_tag, 'Failed to disconnect from glasses: $e', LogLevel.error);
      _setError('Failed to disconnect from glasses: $e');
    }
  }

  /// Update app settings
  Future<void> updateSettings({
    bool? darkMode,
    String? language,
    double? audioSensitivity,
  }) async {
    try {
      if (darkMode != null && darkMode != _darkMode) {
        await _settingsService.setThemeMode(darkMode ? ThemeMode.dark : ThemeMode.light);
        _darkMode = darkMode;
      }

      if (language != null && language != _currentLanguage) {
        await _settingsService.setLanguage(language);
        _currentLanguage = language;
      }

      if (audioSensitivity != null && audioSensitivity != _audioSensitivity) {
        await _settingsService.setVADSensitivity(audioSensitivity);
        _audioSensitivity = audioSensitivity;
      }

      notifyListeners();
      _logger.log(_tag, 'Settings updated', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to update settings: $e', LogLevel.error);
      _setError('Failed to update settings: $e');
    }
  }

  /// Clear current error
  void clearError() {
    _currentError = null;
    _lastErrorTime = null;
    notifyListeners();
  }

  /// Retry initialization
  Future<void> retryInitialization() async {
    _currentError = null;
    _lastErrorTime = null;
    await initialize();
  }

  @override
  void dispose() {
    _logger.log(_tag, 'Disposing app state provider', LogLevel.info);
    super.dispose();
  }

  // Private methods

  void _setAppStatus(AppStatus status) {
    _appStatus = status;
    notifyListeners();
    _logger.log(_tag, 'App status changed to: $status', LogLevel.debug);
  }

  void _setError(String error) {
    _currentError = error;
    _lastErrorTime = DateTime.now();
    notifyListeners();
  }

  Future<void> _initializeSettingsService() async {
    try {
      await _settingsService.initialize();
      _settingsServiceReady = true;
      _logger.log(_tag, 'Settings service initialized', LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Settings service initialization failed: $e', LogLevel.error);
      rethrow;
    }
  }

  Future<void> _loadSettings() async {
    try {
      final themeMode = await _settingsService.getThemeMode();
      _darkMode = themeMode == ThemeMode.dark;

      _currentLanguage = await _settingsService.getLanguage();
      _audioSensitivity = await _settingsService.getVADSensitivity();

      _logger.log(_tag, 'Settings loaded', LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Failed to load settings: $e', LogLevel.warning);
      // Continue with defaults
    }
  }

  Future<void> _initializeAudioService() async {
    try {
      final audioConfig = AudioConfiguration.speechRecognition().copyWith(
        vadThreshold: _audioSensitivity,
      );
      
      await _audioService.initialize(audioConfig);
      
      // Request permissions
      final hasPermission = await _audioService.requestPermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      _audioServiceReady = true;
      _logger.log(_tag, 'Audio service initialized', LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Audio service initialization failed: $e', LogLevel.error);
      rethrow;
    }
  }

  Future<void> _initializeTranscriptionService() async {
    try {
      await _transcriptionService.initialize();
      _transcriptionServiceReady = true;
      _logger.log(_tag, 'Transcription service initialized', LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Transcription service initialization failed: $e', LogLevel.error);
      rethrow;
    }
  }

  Future<void> _initializeLLMService() async {
    try {
      // Get API keys from settings
      final openAIKey = await _settingsService.getAPIKey('openai');
      final anthropicKey = await _settingsService.getAPIKey('anthropic');
      
      await _llmService.initialize(
        openAIKey: openAIKey,
        anthropicKey: anthropicKey,
      );
      
      _llmServiceReady = true;
      _logger.log(_tag, 'LLM service initialized', LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'LLM service initialization failed: $e', LogLevel.warning);
      // LLM service is optional, continue without it
      _llmServiceReady = false;
    }
  }

  Future<void> _initializeGlassesService() async {
    try {
      await _glassesService.initialize();
      _glassesServiceReady = true;
      _logger.log(_tag, 'Glasses service initialized', LogLevel.debug);
    } catch (e) {
      _logger.log(_tag, 'Glasses service initialization failed: $e', LogLevel.warning);
      // Glasses service is optional, continue without it
      _glassesServiceReady = false;
    }
  }

  void _setupServiceListeners() {
    // Listen to glasses connection state changes
    _glassesService.connectionStateStream.listen(
      (state) {
        _glassesConnectionState = _glassesConnectionState.copyWith(status: state);
        notifyListeners();
      },
      onError: (error) {
        _logger.log(_tag, 'Glasses connection error: $error', LogLevel.error);
      },
    );

    // Add other service listeners as needed
  }
}

/// Application status enumeration
enum AppStatus {
  initializing,
  ready,
  error,
  updating,
}