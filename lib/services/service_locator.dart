// ABOUTME: Dependency injection service locator using get_it package
// ABOUTME: Registers and provides access to all application services

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/logging_service.dart';
import 'audio_service.dart';
import 'conversation_storage_service.dart';
import 'glasses_service.dart';
import 'llm_service.dart';
import 'settings_service.dart';
import 'transcription_service.dart';
import 'implementations/audio_service_impl.dart';
import 'implementations/glasses_service_impl.dart';
import 'implementations/llm_service_impl.dart';
import 'implementations/settings_service_impl.dart';
import 'implementations/transcription_service_impl.dart';

class ServiceLocator {
  static final GetIt _getIt = GetIt.instance;
  
  static ServiceLocator get instance => ServiceLocator._();
  ServiceLocator._();
  
  T get<T extends Object>() => _getIt.get<T>();
  
  bool isRegistered<T extends Object>() => _getIt.isRegistered<T>();
  
  Future<void> reset() async {
    await _getIt.reset();
  }
}

Future<void> setupServiceLocator() async {
  final getIt = GetIt.instance;
  
  // Core utilities - LoggingService is a singleton
  getIt.registerLazySingleton<LoggingService>(() => LoggingService.instance);
  
  // Initialize SharedPreferences for settings service
  final prefs = await SharedPreferences.getInstance();
  final logger = getIt.get<LoggingService>();
  
  // Core services with dependencies
  getIt.registerLazySingleton<SettingsService>(() => SettingsServiceImpl(
    logger: logger,
    prefs: prefs,
  ));
  
  getIt.registerLazySingleton<ConversationStorageService>(() => InMemoryConversationStorageService(
    logger: logger,
  ));
  
  // Audio and transcription services
  getIt.registerLazySingleton<AudioService>(() => AudioServiceImpl(
    logger: logger,
  ));
  
  getIt.registerLazySingleton<TranscriptionService>(() => TranscriptionServiceImpl(
    logger: logger,
  ));
  
  // AI and LLM services
  getIt.registerLazySingleton<LLMService>(() => LLMServiceImpl(
    logger: logger,
  ));
  
  // Glasses/hardware services
  getIt.registerLazySingleton<GlassesService>(() => GlassesServiceImpl(
    logger: logger,
  ));
  
  // Initialize services that need async setup
  try {
    final settingsService = getIt.get<SettingsService>();
    await settingsService.initialize();
    
    // Other services will be initialized when first accessed
    
  } catch (e) {
    // Log error but don't prevent app startup
    logger.error('ServiceLocator', 'Some services failed to initialize', e);
  }
}