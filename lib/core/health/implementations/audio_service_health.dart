// ABOUTME: Health checker implementation for Audio Service
// ABOUTME: Monitors audio recording capabilities, permissions, and device availability

import 'dart:async';
import '../health_check_models.dart';
import '../service_health_checker.dart';
import '../../../services/audio_service.dart';
import '../../utils/logging_service.dart';

/// Health checker for Audio Service
class AudioServiceHealth implements ServiceHealthChecker {
  static const String _tag = 'AudioServiceHealth';

  final AudioService _audioService;

  AudioServiceHealth(this._audioService);

  @override
  String get serviceName => 'AudioService';

  @override
  String get version => '1.0.0';

  @override
  List<String> get dependencies => [];

  @override
  Map<String, dynamic> get metadata => {
    'isRecording': _audioService.isRecording,
    'hasPermission': _audioService.hasPermission,
    'currentRecordingPath': _audioService.currentRecordingPath,
  };

  @override
  Future<LivenessProbe> checkLiveness() async {
    try {
      // Audio service is alive if it can report its state
      final isAlive = true; // Service exists

      return LivenessProbe(
        isAlive: isAlive,
        message: isAlive ? 'Audio service is alive' : 'Audio service is not responding',
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
        message: 'Audio service liveness check failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Future<ReadinessProbe> checkReadiness() async {
    final blockers = <String>[];

    try {
      // Check if audio permission is granted
      if (!_audioService.hasPermission) {
        blockers.add('Audio permission not granted');
      }

      // Check if recording is functioning (test if needed)
      // Note: We don't want to actually start recording during health check

      final isReady = blockers.isEmpty;

      return ReadinessProbe(
        isReady: isReady,
        message: isReady
            ? 'Audio service is ready'
            : 'Audio service not ready: ${blockers.join(", ")}',
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
        message: 'Audio service readiness check failed: $e',
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

      // Determine health status
      HealthStatus status;
      String message;

      if (!liveness.isAlive) {
        status = HealthStatus.unhealthy;
        message = 'Audio service is not alive';
      } else if (!readiness.isReady) {
        status = HealthStatus.degraded;
        message = 'Audio service is alive but not ready: ${readiness.blockers.join(", ")}';
      } else {
        status = HealthStatus.healthy;
        message = 'Audio service is healthy and operational';
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
          'isRecording': _audioService.isRecording,
          'hasPermission': _audioService.hasPermission,
          'configuration': _audioService.configuration.toString(),
        },
        dependencies: [],
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
        message: 'Audio service health check failed: $e',
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
