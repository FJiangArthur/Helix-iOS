// ABOUTME: Dependency injection service locator for AI services
// ABOUTME: Simplified version that only registers Epic 2.2 AI analysis services

import 'package:get_it/get_it.dart';

// import 'fact_checking_service.dart';  // Temporarily disabled
// import 'ai_insights_service.dart';     // Temporarily disabled
import 'implementations/llm_service_impl_v2.dart';
import '../core/config/app_config.dart';
import '../core/config/feature_flag_service.dart';
import '../core/utils/logging_service.dart';
import 'package:flutter_helix/utils/app_logger.dart';

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

  // Initialize and register feature flag service first
  appLogger.i('Initializing feature flags...');
  final featureFlagService = FeatureFlagService.instance;
  await featureFlagService.initialize();
  getIt.registerSingleton<FeatureFlagService>(featureFlagService);
  appLogger.i('Feature flags initialized: ${featureFlagService.getEnabledFlags().length} flags enabled');

  // Load configuration first
  appLogger.i('Loading app configuration...');
  final config = await AppConfig.load();
  appLogger.i('Config loaded: $config');

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

  appLogger.i('Service locator setup complete');
}
