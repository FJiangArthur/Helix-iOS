// ABOUTME: Health checker implementation for AI Insights Service
// ABOUTME: Monitors AI insights generation capabilities and dependencies

import 'dart:async';
import '../health_check_models.dart';
import '../service_health_checker.dart';
import '../../../services/ai_insights_service.dart';
import '../../utils/logging_service.dart';

/// Health checker for AI Insights Service
class AIInsightsServiceHealth implements ServiceHealthChecker {
  static const String _tag = 'AIInsightsServiceHealth';

  final AIInsightsService _aiInsightsService;

  AIInsightsServiceHealth(this._aiInsightsService);

  @override
  String get serviceName => 'AIInsightsService';

  @override
  String get version => '1.0.0';

  @override
  List<String> get dependencies => ['LLMService'];

  @override
  Map<String, dynamic> get metadata {
    final stats = _aiInsightsService.getStatistics();
    return {
      'isEnabled': stats['isEnabled'],
      'totalInsights': stats['totalInsights'],
      'bufferSize': stats['bufferSize'],
      'enabledTypes': stats['enabledTypes'],
    };
  }

  @override
  Future<LivenessProbe> checkLiveness() async {
    try {
      // Service is alive if it exists and can report statistics
      final stats = _aiInsightsService.getStatistics();
      final isAlive = stats.isNotEmpty;

      return LivenessProbe(
        isAlive: isAlive,
        message: isAlive
            ? 'AI Insights service is alive'
            : 'AI Insights service is not responding',
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
        message: 'AI Insights service liveness check failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<ReadinessProbe> checkReadiness() async {
    final blockers = <String>[];

    try {
      // Check if service is enabled
      if (!_aiInsightsService.isEnabled) {
        blockers.add('AI Insights service is disabled');
      }

      // Check statistics
      final stats = _aiInsightsService.getStatistics();
      if (stats.isEmpty) {
        blockers.add('Unable to get service statistics');
      }

      final isReady = blockers.isEmpty;

      return ReadinessProbe(
        isReady: isReady,
        message: isReady
            ? 'AI Insights service is ready'
            : 'AI Insights service not ready: ${blockers.join(", ")}',
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
        message: 'AI Insights service readiness check failed: $e',
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

      // Check dependencies
      final dependencies = <DependencyHealth>[
        DependencyHealth(
          name: 'LLMService',
          type: 'service',
          status: HealthStatus.healthy, // This should be checked via HealthCheckService
          message: 'LLM service dependency',
        ),
      ];

      // Determine health status
      HealthStatus status;
      String message;

      if (!liveness.isAlive) {
        status = HealthStatus.unhealthy;
        message = 'AI Insights service is not alive';
      } else if (!readiness.isReady) {
        status = HealthStatus.degraded;
        message = 'AI Insights service is alive but not ready: ${readiness.blockers.join(", ")}';
      } else {
        status = HealthStatus.healthy;
        message = 'AI Insights service is healthy and operational';
      }

      final responseTime = DateTime.now().difference(startTime);
      final stats = _aiInsightsService.getStatistics();

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
          'statistics': stats,
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
        message: 'AI Insights service health check failed: $e',
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
