import 'package:get/get.dart';
import 'audio_service.dart';
import 'implementations/audio_service_impl.dart';
import 'interfaces/i_ble_service.dart';
import 'interfaces/i_transcription_service.dart';
import 'interfaces/i_glasses_display_service.dart';
import 'implementations/ble_service_impl.dart';
import 'implementations/transcription_service_impl.dart';
import 'implementations/glasses_display_service_impl.dart';
import 'audio_recording_service.dart';
import 'evenai_coordinator.dart';
import '../controllers/recording_screen_controller.dart';
import '../controllers/evenai_screen_controller.dart';
import '../models/audio_configuration.dart';

/// Service locator for dependency injection
/// Uses GetX for service registration and retrieval
class ServiceLocator {
  static bool _initialized = false;

  /// Initialize all services and controllers
  static Future<void> initialize() async {
    if (_initialized) return;

    // Register core services as singletons
    Get.lazyPut<IBleService>(() => BleServiceImpl(), fenix: true);

    Get.lazyPut<ITranscriptionService>(
      () => TranscriptionServiceImpl(),
      fenix: true,
    );

    Get.lazyPut<IGlassesDisplayService>(
      () => GlassesDisplayServiceImpl(),
      fenix: true,
    );

    // Register AudioService
    Get.lazyPut<AudioService>(() {
      final service = AudioServiceImpl();
      service.initialize(AudioConfiguration.defaultConfig());
      return service;
    }, fenix: true);

    // Register composite services
    Get.lazyPut<AudioRecordingService>(
      () => AudioRecordingService(
        audioService: Get.find<AudioService>(),
        transcription: Get.find<ITranscriptionService>(),
      ),
      fenix: true,
    );

    Get.lazyPut<EvenAICoordinator>(
      () => EvenAICoordinator(
        transcription: Get.find<ITranscriptionService>(),
        display: Get.find<IGlassesDisplayService>(),
        ble: Get.find<IBleService>(),
      ),
      fenix: true,
    );

    // Register controllers
    Get.lazyPut<RecordingScreenController>(
      () => RecordingScreenController(
        recordingService: Get.find<AudioRecordingService>(),
        bleService: Get.find<IBleService>(),
      ),
      fenix: true,
    );

    Get.lazyPut<EvenAIScreenController>(
      () => EvenAIScreenController(
        coordinator: Get.find<EvenAICoordinator>(),
      ),
      fenix: true,
    );

    _initialized = true;
  }

  /// Get BLE service
  static IBleService get bleService => Get.find<IBleService>();

  /// Get transcription service
  static ITranscriptionService get transcriptionService =>
      Get.find<ITranscriptionService>();

  /// Get glasses display service
  static IGlassesDisplayService get glassesDisplayService =>
      Get.find<IGlassesDisplayService>();

  /// Get audio service
  static AudioService get audioService => Get.find<AudioService>();

  /// Get audio recording service
  static AudioRecordingService get audioRecordingService =>
      Get.find<AudioRecordingService>();

  /// Get EvenAI coordinator
  static EvenAICoordinator get evenAICoordinator =>
      Get.find<EvenAICoordinator>();

  /// Get recording screen controller
  static RecordingScreenController get recordingController =>
      Get.find<RecordingScreenController>();

  /// Get EvenAI screen controller
  static EvenAIScreenController get evenAIController =>
      Get.find<EvenAIScreenController>();

  /// Cleanup all services
  static void dispose() {
    if (!_initialized) return;

    // Dispose controllers
    try {
      Get.find<RecordingScreenController>().dispose();
    } catch (e) {
      // Controller may not be initialized
    }

    try {
      Get.find<EvenAIScreenController>().dispose();
    } catch (e) {
      // Controller may not be initialized
    }

    // Dispose services
    try {
      Get.find<EvenAICoordinator>().dispose();
    } catch (e) {
      // Service may not be initialized
    }

    try {
      Get.find<AudioRecordingService>().dispose();
    } catch (e) {
      // Service may not be initialized
    }

    try {
      Get.find<AudioService>().dispose();
    } catch (e) {
      // Service may not be initialized
    }

    try {
      Get.find<IBleService>().dispose();
    } catch (e) {
      // Service may not be initialized
    }

    try {
      Get.find<ITranscriptionService>().dispose();
    } catch (e) {
      // Service may not be initialized
    }

    try {
      Get.find<IGlassesDisplayService>().dispose();
    } catch (e) {
      // Service may not be initialized
    }

    // Reset GetX
    Get.reset();
    _initialized = false;
  }
}
