// ABOUTME: Dependency injection service locator for AI services
// ABOUTME: Simplified version that only registers Epic 2.2 AI analysis services

import 'package:get_it/get_it.dart';

// import 'fact_checking_service.dart';  // Temporarily disabled
// import 'ai_insights_service.dart';     // Temporarily disabled
import 'implementations/llm_service_impl_v2.dart';
import '../core/config/app_config.dart';
import '../core/utils/logging_service.dart';

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

  // Load configuration first
  print('Loading app configuration...');
  final config = await AppConfig.load();
  print('Config loaded: $config');

  // Register config as singleton
  getIt.registerSingleton<AppConfig>(config);

  // Register logging service
  getIt.registerLazySingleton<LoggingService>(() => LoggingService.instance);

  // AI and LLM services with config
  getIt.registerLazySingleton<LLMServiceImplV2>(() => LLMServiceImplV2(
    logger: getIt.get<LoggingService>(),
    config: config,
  ));

  // Temporarily disabled - need interface updates
  // Fact-checking service
  // getIt.registerLazySingleton<FactCheckingService>(() => FactCheckingService(
  //   llmService: getIt.get<LLMServiceImplV2>(),
  // ));

  // AI insights service
  // getIt.registerLazySingleton<AIInsightsService>(() => AIInsightsService(
  //   llmService: getIt.get<LLMServiceImplV2>(),
  // ));

  print('Service locator setup complete');
}
