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
import 'conversation_storage_service.dart';

// Service implementations
import 'implementations/audio_service_impl.dart';
import 'implementations/transcription_service_impl.dart';
import 'implementations/llm_service_impl.dart';
import 'implementations/glasses_service_impl.dart';
import 'implementations/settings_service_impl.dart';

// Providers
import '../providers/app_state_provider.dart';

// Models
import '../models/transcription_segment.dart';
import '../models/analysis_result.dart';
import '../models/conversation_model.dart';
import '../models/glasses_connection_state.dart';

// Utils
import '../core/utils/logging_service.dart';

// Flutter imports
import 'package:flutter/material.dart';

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
    
    // Transcription Service
    _getIt.registerLazySingleton<TranscriptionService>(() => TranscriptionServiceImpl(logger: logger));
    
    // LLM Service
    _getIt.registerLazySingleton<LLMService>(() => LLMServiceImpl(logger: logger));
    
    // Glasses Service
    _getIt.registerLazySingleton<GlassesService>(() => GlassesServiceImpl(logger: logger));
    
    // Settings Service
    _getIt.registerLazySingleton<SettingsService>(() => SettingsServiceImpl(
      logger: logger,
      prefs: _getIt<SharedPreferences>(),
    ));
    
    // Conversation Storage Service
    _getIt.registerLazySingleton<ConversationStorageService>(() => InMemoryConversationStorageService(logger: logger));
  }
  
  /// Register providers
  Future<void> _registerProviders() async {
    // For now, skip AppStateProvider registration until all services are implemented
    // This allows the app to build without complex mock implementations
    logger.info('ServiceLocator', 'Skipping AppStateProvider registration - services not yet implemented');
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

// Mock services will be implemented in Phase 2