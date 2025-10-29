import 'dart:async';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'transcription_service.dart';
import 'transcription_models.dart';
import 'native_transcription_service.dart';
import 'whisper_transcription_service.dart';

/// Transcription coordinator with mode switching (US 3.3)
/// Manages transcription service selection and automatic fallback
class TranscriptionCoordinator {
  static TranscriptionCoordinator? _instance;
  static TranscriptionCoordinator get instance =>
      _instance ??= TranscriptionCoordinator._();

  TranscriptionCoordinator._();

  // Services
  final _nativeService = NativeTranscriptionService.instance;
  final _whisperService = WhisperTranscriptionService.instance;
  TranscriptionService? _activeService;

  // Configuration
  TranscriptionMode _preferredMode = TranscriptionMode.native;
  bool _isInitialized = false;

  // Network monitoring for auto mode
  final _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _hasNetworkConnection = false;

  // Unified streams
  final _transcriptController =
      StreamController<TranscriptSegment>.broadcast();
  final _errorController = StreamController<TranscriptionError>.broadcast();
  final _modeChangeController = StreamController<TranscriptionMode>.broadcast();

  Stream<TranscriptSegment> get transcriptStream =>
      _transcriptController.stream;
  Stream<TranscriptionError> get errorStream => _errorController.stream;
  Stream<TranscriptionMode> get modeChangeStream =>
      _modeChangeController.stream;

  TranscriptionMode get currentMode =>
      _activeService?.mode ?? TranscriptionMode.native;
  TranscriptionMode get preferredMode => _preferredMode;
  bool get isTranscribing => _activeService?.isTranscribing ?? false;

  /// Initialize coordinator with Whisper API key (optional)
  Future<void> initialize({String? whisperApiKey}) async {
    if (_isInitialized) return;

    // Initialize native service
    await _nativeService.initialize();

    // Initialize Whisper if API key provided
    if (whisperApiKey != null && whisperApiKey.isNotEmpty) {
      await _whisperService.initializeWithKey(whisperApiKey);
    }

    // Start network monitoring for auto mode
    await _initializeNetworkMonitoring();

    _isInitialized = true;
  }

  /// Set preferred transcription mode
  void setMode(TranscriptionMode mode) {
    if (_preferredMode == mode) return;

    _preferredMode = mode;

    // If transcribing, switch services
    if (isTranscribing) {
      _switchService();
    }
  }

  /// Start transcription with current mode
  Future<void> startTranscription({String? languageCode}) async {
    if (!_isInitialized) {
      _errorController.add(const TranscriptionError(
        type: TranscriptionErrorType.notAvailable,
        message: 'Transcription coordinator not initialized',
      ));
      return;
    }

    // Determine which service to use
    _activeService = _selectService();

    if (_activeService == null) {
      _errorController.add(const TranscriptionError(
        type: TranscriptionErrorType.notAvailable,
        message: 'No transcription service available',
      ));
      return;
    }

    // Emit mode change
    _modeChangeController.add(_activeService!.mode);

    // Start transcription
    await _activeService!.startTranscription(languageCode: languageCode);

    // Forward streams
    _activeService!.transcriptStream.listen(_transcriptController.add);
    _activeService!.errorStream.listen(_errorController.add);
  }

  /// Stop transcription
  Future<void> stopTranscription() async {
    if (_activeService != null) {
      await _activeService!.stopTranscription();
      _activeService = null;
    }
  }

  /// Append audio data to active service
  void appendAudioData(Uint8List pcmData) {
    _activeService?.appendAudioData(pcmData);
  }

  /// Get current transcription statistics
  TranscriptionStats? getStats() {
    return _activeService?.getStats();
  }

  /// Select appropriate service based on mode and availability
  TranscriptionService? _selectService() {
    switch (_preferredMode) {
      case TranscriptionMode.native:
        return _nativeService.isAvailable ? _nativeService : null;

      case TranscriptionMode.whisper:
        return _whisperService.isAvailable ? _whisperService : null;

      case TranscriptionMode.auto:
        // Auto mode: use Whisper if network available and API key configured
        // Otherwise fall back to native
        if (_hasNetworkConnection && _whisperService.isAvailable) {
          return _whisperService;
        }
        return _nativeService.isAvailable ? _nativeService : null;
    }
  }

  /// Switch service while transcribing (hot swap)
  Future<void> _switchService() async {
    if (!isTranscribing) return;

    final currentLanguage = 'en-US'; // TODO: Track current language

    // Stop current service
    await _activeService?.stopTranscription();

    // Select new service
    _activeService = _selectService();

    if (_activeService != null) {
      // Emit mode change
      _modeChangeController.add(_activeService!.mode);

      // Start new service
      await _activeService!.startTranscription(languageCode: currentLanguage);

      // Forward streams
      _activeService!.transcriptStream.listen(_transcriptController.add);
      _activeService!.errorStream.listen(_errorController.add);
    }
  }

  /// Initialize network connectivity monitoring
  Future<void> _initializeNetworkMonitoring() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _hasNetworkConnection = result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile);

    // Monitor connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final hadConnection = _hasNetworkConnection;
      _hasNetworkConnection = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile);

      // If in auto mode and connectivity changed, consider switching
      if (_preferredMode == TranscriptionMode.auto &&
          hadConnection != _hasNetworkConnection &&
          isTranscribing) {
        _switchService();
      }
    });
  }

  /// Get all available transcription modes
  List<TranscriptionMode> getAvailableModes() {
    final modes = <TranscriptionMode>[];

    if (_nativeService.isAvailable) {
      modes.add(TranscriptionMode.native);
    }

    if (_whisperService.isAvailable) {
      modes.add(TranscriptionMode.whisper);
    }

    // Auto is always available if at least one service is available
    if (modes.isNotEmpty) {
      modes.add(TranscriptionMode.auto);
    }

    return modes;
  }

  /// Get recommended mode based on current conditions
  TranscriptionMode getRecommendedMode() {
    // If no network, recommend native
    if (!_hasNetworkConnection) {
      return TranscriptionMode.native;
    }

    // If network and Whisper available, recommend auto
    if (_whisperService.isAvailable) {
      return TranscriptionMode.auto;
    }

    // Default to native
    return TranscriptionMode.native;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _activeService?.dispose();
    _transcriptController.close();
    _errorController.close();
    _modeChangeController.close();
  }
}
