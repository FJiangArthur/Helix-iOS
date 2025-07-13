// ABOUTME: Dependency injection service locator for all app services
// ABOUTME: Configures get_it container with singleton and factory patterns

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Service interfaces (to be created)
// import '../services/audio_service.dart';
// import '../services/transcription_service.dart';
// import '../services/llm_service.dart';
// import '../services/glasses_service.dart';
// import '../services/settings_service.dart';

// Service implementations (to be created)
// import '../core/audio/audio_service_impl.dart';
// import '../core/transcription/transcription_service_impl.dart';
// import '../core/ai/llm_service_impl.dart';
// import '../core/glasses/glasses_service_impl.dart';
// import '../services/settings_service_impl.dart';

// Providers (to be created)
// import '../ui/providers/app_provider.dart';
// import '../ui/providers/conversation_provider.dart';
// import '../ui/providers/analysis_provider.dart';
// import '../ui/providers/glasses_provider.dart';
// import '../ui/providers/settings_provider.dart';

final GetIt getIt = GetIt.instance;

/// Initialize dependency injection container
/// Call this before runApp() in main.dart
Future<void> setupServiceLocator() async {
  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  // Register core services as singletons
  // These services maintain state and should be shared across the app
  
  // TODO: Uncomment as services are implemented
  // getIt.registerLazySingleton<AudioService>(() => AudioServiceImpl());
  // getIt.registerLazySingleton<TranscriptionService>(() => TranscriptionServiceImpl());
  // getIt.registerLazySingleton<LLMService>(() => LLMServiceImpl());
  // getIt.registerLazySingleton<GlassesService>(() => GlassesServiceImpl());
  // getIt.registerLazySingleton<SettingsService>(() => SettingsServiceImpl());

  // Register providers as singletons
  // Providers manage UI state and should persist across widget rebuilds
  
  // TODO: Uncomment as providers are implemented
  // getIt.registerLazySingleton<AppProvider>(() => AppProvider());
  // getIt.registerLazySingleton<ConversationProvider>(() => ConversationProvider());
  // getIt.registerLazySingleton<AnalysisProvider>(() => AnalysisProvider());
  // getIt.registerLazySingleton<GlassesProvider>(() => GlassesProvider());
  // getIt.registerLazySingleton<SettingsProvider>(() => SettingsProvider());
}

/// Reset all registered services and providers
/// Useful for testing and app restart scenarios
Future<void> resetServiceLocator() async {
  await getIt.reset();
}