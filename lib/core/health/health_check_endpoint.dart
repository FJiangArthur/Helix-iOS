// ABOUTME: Health check HTTP endpoint handler
// ABOUTME: Provides REST API endpoints for health checks accessible via HTTP

import 'dart:async';
import 'dart:convert';
import 'health_check_service.dart';
import 'health_check_models.dart';

/// Health check endpoint handler for HTTP requests
class HealthCheckEndpoint {
  final HealthCheckService _healthCheckService;

  HealthCheckEndpoint(this._healthCheckService);

  /// Handle GET /health - Overall system health
  Future<Map<String, dynamic>> handleHealthCheck() async {
    final result = await _healthCheckService.checkSystemHealth();

    return {
      'status': result.overallStatus.name,
      'timestamp': result.timestamp.toIso8601String(),
      'version': '1.0.0',
      'uptime': _getUptime(),
      ...result.toJson(),
    };
  }

  /// Handle GET /health/live - Liveness check
  Future<Map<String, dynamic>> handleLivenessCheck() async {
    // Simple liveness check - just returns OK if app is running
    return {
      'status': 'alive',
      'timestamp': DateTime.now().toIso8601String(),
      'message': 'Application is running',
    };
  }

  /// Handle GET /health/ready - Readiness check
  Future<Map<String, dynamic>> handleReadinessCheck() async {
    final result = await _healthCheckService.checkSystemHealth();

    final isReady = result.overallStatus == HealthStatus.healthy ||
        result.overallStatus == HealthStatus.degraded;

    return {
      'status': isReady ? 'ready' : 'not_ready',
      'timestamp': DateTime.now().toIso8601String(),
      'message': isReady
          ? 'Application is ready to serve requests'
          : 'Application is not ready',
      'details': {
        'overallStatus': result.overallStatus.name,
        'healthScore': result.overallHealthScore,
        'unhealthyServices': result.unhealthyServices
            .map((s) => {'name': s.serviceName, 'status': s.status.name})
            .toList(),
      },
    };
  }

  /// Handle GET /health/services/{serviceName} - Individual service health
  Future<Map<String, dynamic>> handleServiceHealthCheck(String serviceName) async {
    final result = await _healthCheckService.checkServiceHealth(serviceName);

    return {
      'service': serviceName,
      'timestamp': DateTime.now().toIso8601String(),
      ...result.toJson(),
    };
  }

  /// Handle GET /health/metrics - Health metrics and trends
  Future<Map<String, dynamic>> handleMetrics() async {
    final trends = _healthCheckService.getHealthTrends();
    final latestHealth = _healthCheckService.latestHealth;

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'trends': trends,
      'current': latestHealth?.toJson(),
      'dependencies': _healthCheckService.getDependencyGraph(),
    };
  }

  /// Handle GET /health/dependencies - Dependency graph and validation
  Future<Map<String, dynamic>> handleDependencies() async {
    final graph = _healthCheckService.getDependencyGraph();
    final issues = await _healthCheckService.validateDependencies();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'dependencyGraph': graph,
      'validationIssues': issues,
      'hasIssues': issues.isNotEmpty,
    };
  }

  /// Handle GET /health/version - Version information
  Future<Map<String, dynamic>> handleVersion() async {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'application': {
        'name': 'Helix',
        'version': '1.0.0',
        'buildNumber': '1',
        'environment': 'development',
      },
      'services': _healthCheckService.registeredServices
          .map((serviceName) {
            final service = _healthCheckService.getService(serviceName);
            return {
              'name': serviceName,
              'version': service?.version ?? 'unknown',
            };
          })
          .toList(),
    };
  }

  String _getUptime() {
    // This is a simplified implementation
    // In a real app, you'd track the actual start time
    return '${DateTime.now().difference(DateTime.now()).inSeconds}s';
  }
}
