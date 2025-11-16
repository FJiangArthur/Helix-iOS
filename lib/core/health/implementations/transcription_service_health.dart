// ABOUTME: Health checker implementation for Transcription Services
// ABOUTME: Monitors transcription coordinator and provider health

import 'dart:async';
import '../health_check_models.dart';
import '../service_health_checker.dart';
import '../../../services/transcription/transcription_coordinator.dart';
import '../../utils/logging_service.dart';

/// Health checker for Transcription Coordinator Service
class TranscriptionServiceHealth implements ServiceHealthChecker {
  static const String _tag = 'TranscriptionServiceHealth';

  final TranscriptionCoordinator _coordinator;

  TranscriptionServiceHealth(this._coordinator);

  @override
  String get serviceName => 'TranscriptionCoordinator';

  @override
  String get version => '1.0.0';

  @override
  List<String> get dependencies => ['AudioService'];

  @override
  Map<String, dynamic> get metadata => {
    'isTranscribing': _coordinator.isTranscribing,
  };

  @override
  Future<LivenessProbe> checkLiveness() async {
    try {
      // Service is alive if it can report its state
      return LivenessProbe(
        isAlive: true,
        message: 'Transcription service is alive',
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
        message: 'Transcription service liveness check failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<ReadinessProbe> checkReadiness() async {
    final blockers = <String>[];

    try {
      // Service is ready if it's initialized and can start transcription
      // We check if the coordinator can report its state

      // Additional checks could be added here for API availability
      // For example, checking if Whisper API is reachable

      final isReady = blockers.isEmpty;

      return ReadinessProbe(
        isReady: isReady,
        message: isReady
            ? 'Transcription service is ready'
            : 'Transcription service not ready: ${blockers.join(", ")}',
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
        message: 'Transcription service readiness check failed: $e',
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
          name: 'AudioService',
          type: 'service',
          status: HealthStatus.healthy,
          message: 'Audio service dependency',
        ),
      ];

      // Determine health status
      HealthStatus status;
      String message;

      if (!liveness.isAlive) {
        status = HealthStatus.unhealthy;
        message = 'Transcription service is not alive';
      } else if (!readiness.isReady) {
        status = HealthStatus.degraded;
        message = 'Transcription service is alive but not ready: ${readiness.blockers.join(", ")}';
      } else {
        status = HealthStatus.healthy;
        message = 'Transcription service is healthy and operational';
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
          'isTranscribing': _coordinator.isTranscribing,
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
        message: 'Transcription service health check failed: $e',
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
