// ABOUTME: Dependency injection service locator for AI services
// ABOUTME: Simplified version that only registers Epic 2.2 AI analysis services

import 'package:get_it/get_it.dart';

import 'fact_checking_service.dart';
import 'ai_insights_service.dart';
import 'implementations/llm_service_impl_v2.dart';

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

  // AI and LLM services
  getIt.registerLazySingleton<LLMServiceImplV2>(() => LLMServiceImplV2());

  // Fact-checking service
  getIt.registerLazySingleton<FactCheckingService>(() => FactCheckingService(
    llmService: getIt.get<LLMServiceImplV2>(),
  ));

  // AI insights service
  getIt.registerLazySingleton<AIInsightsService>(() => AIInsightsService(
    llmService: getIt.get<LLMServiceImplV2>(),
  ));
}
