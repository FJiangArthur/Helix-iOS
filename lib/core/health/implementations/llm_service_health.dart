// ABOUTME: Health checker implementation for LLM Service
// ABOUTME: Monitors LLM service initialization, provider availability, and API connectivity

import 'dart:async';
import '../health_check_models.dart';
import '../service_health_checker.dart';
import '../../../services/implementations/llm_service_impl_v2.dart';
import '../../utils/logging_service.dart';

/// Health checker for LLM Service
class LLMServiceHealth implements ServiceHealthChecker {
  static const String _tag = 'LLMServiceHealth';

  final LLMServiceImplV2 _llmService;

  LLMServiceHealth(this._llmService);

  @override
  String get serviceName => 'LLMService';

  @override
  String get version => '2.0.0';

  @override
  List<String> get dependencies => [];

  @override
  Map<String, dynamic> get metadata => {
    'isInitialized': _llmService.isInitialized,
  };

  @override
  Future<LivenessProbe> checkLiveness() async {
    try {
      // LLM service is alive if it exists
      return LivenessProbe(
        isAlive: true,
        message: 'LLM service is alive',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      LoggingService.instance.log(
        _tag,
        'Liveness check failed: $e',
        LogLevel.error,
      );

      return LivenessProbe(
        isAlive: false,
        message: 'LLM service liveness check failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<ReadinessProbe> checkReadiness() async {
    final blockers = <String>[];

    try {
      // Check if LLM service is initialized
      if (!_llmService.isInitialized) {
        blockers.add('LLM service not initialized');
      }

      final isReady = blockers.isEmpty;

      return ReadinessProbe(
        isReady: isReady,
        message: isReady
            ? 'LLM service is ready'
            : 'LLM service not ready: ${blockers.join(", ")}',
        blockers: blockers,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      LoggingService.instance.log(
        _tag,
        'Readiness check failed: $e',
        LogLevel.error,
      );

      return ReadinessProbe(
        isReady: false,
        message: 'LLM service readiness check failed: $e',
        blockers: ['Exception during readiness check: $e'],
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<HealthCheckResult> checkHealth() async {
    final startTime = DateTime.now();

    try {
      final liveness = await checkLiveness();
      final readiness = await checkReadiness();

      // Check dependencies (API providers)
      final dependencies = <DependencyHealth>[];

      // Note: Add actual provider health checks if providers expose health endpoints

      // Determine health status
      HealthStatus status;
      String message;

      if (!liveness.isAlive) {
        status = HealthStatus.unhealthy;
        message = 'LLM service is not alive';
      } else if (!readiness.isReady) {
        status = HealthStatus.degraded;
        message = 'LLM service is alive but not ready: ${readiness.blockers.join(", ")}';
      } else {
        status = HealthStatus.healthy;
        message = 'LLM service is healthy and operational';
      }

      final responseTime = DateTime.now().difference(startTime);

      return HealthCheckResult(
        serviceName: serviceName,
        version: version,
        status: status,
        message: message,
        timestamp: DateTime.now(),
        isLive: liveness.isAlive,
        isReady: readiness.isReady,
        responseTime: responseTime,
        details: {
          'liveness': liveness.toJson(),
          'readiness': readiness.toJson(),
          'isInitialized': _llmService.isInitialized,
        },
        dependencies: dependencies,
      );
    } catch (e) {
      LoggingService.instance.log(
        _tag,
        'Health check failed: $e',
        LogLevel.error,
      );

      return HealthCheckResult(
        serviceName: serviceName,
        version: version,
        status: HealthStatus.unhealthy,
        message: 'LLM service health check failed: $e',
        timestamp: DateTime.now(),
        isLive: false,
        isReady: false,
        responseTime: DateTime.now().difference(startTime),
        details: {'error': e.toString()},
        dependencies: [],
      );
    }
  }
}
