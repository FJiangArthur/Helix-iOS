// ABOUTME: Interface for service health checkers
// ABOUTME: Defines contract that all services must implement for health checks

import 'dart:async';
import 'health_check_models.dart';

/// Interface that all health-checkable services must implement
abstract class ServiceHealthChecker {
  /// Name of the service being checked
  String get serviceName;

  /// Version of the service
  String get version;

  /// Perform a liveness check
  /// Returns whether the service is alive (running)
  Future<LivenessProbe> checkLiveness();

  /// Perform a readiness check
  /// Returns whether the service is ready to handle requests
  Future<ReadinessProbe> checkReadiness();

  /// Perform a comprehensive health check
  /// Includes liveness, readiness, and dependency checks
  Future<HealthCheckResult> checkHealth();

  /// Get service dependencies
  List<String> get dependencies;

  /// Get service metadata
  Map<String, dynamic> get metadata => {};
}

/// Mixin for services that need health check capabilities
mixin HealthCheckMixin implements ServiceHealthChecker {
  /// Default liveness check implementation
  /// Override this method for service-specific logic
  @override
  Future<LivenessProbe> checkLiveness() async {
    try {
      // Default implementation - check if service exists
      return LivenessProbe(
        isAlive: true,
        message: '$serviceName is alive',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return LivenessProbe(
        isAlive: false,
        message: 'Liveness check failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Default readiness check implementation
  /// Override this method for service-specific logic
  @override
  Future<ReadinessProbe> checkReadiness() async {
    try {
      // Default implementation - always ready if alive
      final liveness = await checkLiveness();

      return ReadinessProbe(
        isReady: liveness.isAlive,
        message: liveness.isAlive
            ? '$serviceName is ready'
            : '$serviceName is not alive',
        blockers: liveness.isAlive ? [] : ['Service not alive'],
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return ReadinessProbe(
        isReady: false,
        message: 'Readiness check failed: $e',
        blockers: ['Exception during readiness check'],
        timestamp: DateTime.now(),
      );
    }
  }

  /// Default health check implementation
  /// Override this method for service-specific logic with dependencies
  @override
  Future<HealthCheckResult> checkHealth() async {
    final startTime = DateTime.now();

    try {
      final liveness = await checkLiveness();
      final readiness = await checkReadiness();

      final responseTime = DateTime.now().difference(startTime);

      // Determine overall health status
      HealthStatus status;
      String message;

      if (!liveness.isAlive) {
        status = HealthStatus.unhealthy;
        message = 'Service is not alive';
      } else if (!readiness.isReady) {
        status = HealthStatus.degraded;
        message = 'Service is alive but not ready: ${readiness.blockers.join(", ")}';
      } else {
        status = HealthStatus.healthy;
        message = 'Service is healthy';
      }

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
          ...metadata,
        },
        dependencies: [],
      );
    } catch (e) {
      return HealthCheckResult(
        serviceName: serviceName,
        version: version,
        status: HealthStatus.unhealthy,
        message: 'Health check failed: $e',
        timestamp: DateTime.now(),
        isLive: false,
        isReady: false,
        responseTime: DateTime.now().difference(startTime),
        details: {'error': e.toString()},
        dependencies: [],
      );
    }
  }

  /// Default dependencies list - override if service has dependencies
  @override
  List<String> get dependencies => [];
}

/// Health checker for services with async initialization
abstract class AsyncHealthChecker extends ServiceHealthChecker {
  bool _isInitialized = false;
  bool _isInitializing = false;

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;

  /// Mark service as initialized
  void markInitialized() {
    _isInitialized = true;
    _isInitializing = false;
  }

  /// Mark service as initializing
  void markInitializing() {
    _isInitializing = true;
    _isInitialized = false;
  }

  @override
  Future<LivenessProbe> checkLiveness() async {
    return LivenessProbe(
      isAlive: _isInitialized || _isInitializing,
      message: _isInitialized
          ? '$serviceName is alive and initialized'
          : _isInitializing
              ? '$serviceName is initializing'
              : '$serviceName is not initialized',
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<ReadinessProbe> checkReadiness() async {
    final blockers = <String>[];

    if (!_isInitialized) {
      if (_isInitializing) {
        blockers.add('Service is still initializing');
      } else {
        blockers.add('Service is not initialized');
      }
    }

    return ReadinessProbe(
      isReady: _isInitialized,
      message: _isInitialized
          ? '$serviceName is ready'
          : blockers.join(', '),
      blockers: blockers,
      timestamp: DateTime.now(),
    );
  }
}
