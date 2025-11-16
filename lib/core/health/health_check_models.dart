// ABOUTME: Health check models and data structures
// ABOUTME: Defines health status, check results, and dependency information

import 'package:flutter/foundation.dart';

/// Health status enumeration
enum HealthStatus {
  healthy,    // Service is fully operational
  degraded,   // Service is operational but with reduced performance
  unhealthy,  // Service is not operational
  unknown,    // Health status cannot be determined
}

/// Health check result for a single service or component
class HealthCheckResult {
  final String serviceName;
  final String version;
  final HealthStatus status;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> details;
  final Duration responseTime;

  // Component-specific checks
  final bool isLive;      // Liveness: Is the service running?
  final bool isReady;     // Readiness: Can the service handle requests?
  final List<DependencyHealth> dependencies;

  const HealthCheckResult({
    required this.serviceName,
    required this.version,
    required this.status,
    required this.message,
    required this.timestamp,
    required this.isLive,
    required this.isReady,
    this.details = const {},
    this.responseTime = const Duration(milliseconds: 0),
    this.dependencies = const [],
  });

  /// Whether the service is healthy
  bool get isHealthy => status == HealthStatus.healthy;

  /// Whether the service is operational (healthy or degraded)
  bool get isOperational =>
      status == HealthStatus.healthy || status == HealthStatus.degraded;

  /// Whether all dependencies are healthy
  bool get allDependenciesHealthy =>
      dependencies.every((dep) => dep.isHealthy);

  /// Get health score (0-100)
  int get healthScore {
    switch (status) {
      case HealthStatus.healthy:
        return 100;
      case HealthStatus.degraded:
        return 50;
      case HealthStatus.unhealthy:
        return 0;
      case HealthStatus.unknown:
        return 25;
    }
  }

  Map<String, dynamic> toJson() => {
    'serviceName': serviceName,
    'version': version,
    'status': status.name,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'isLive': isLive,
    'isReady': isReady,
    'responseTime': responseTime.inMilliseconds,
    'details': details,
    'dependencies': dependencies.map((d) => d.toJson()).toList(),
    'healthScore': healthScore,
  };

  @override
  String toString() =>
      'HealthCheckResult($serviceName: ${status.name}, live: $isLive, ready: $isReady)';
}

/// Dependency health information
class DependencyHealth {
  final String name;
  final String type; // 'service', 'database', 'api', 'cache', etc.
  final HealthStatus status;
  final String message;
  final Duration responseTime;
  final Map<String, dynamic> metadata;

  const DependencyHealth({
    required this.name,
    required this.type,
    required this.status,
    required this.message,
    this.responseTime = const Duration(milliseconds: 0),
    this.metadata = const {},
  });

  bool get isHealthy => status == HealthStatus.healthy;

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'status': status.name,
    'message': message,
    'responseTime': responseTime.inMilliseconds,
    'metadata': metadata,
  };
}

/// Aggregated health check result for the entire system
class SystemHealthResult {
  final HealthStatus overallStatus;
  final DateTime timestamp;
  final List<HealthCheckResult> services;
  final Map<String, dynamic> systemInfo;
  final Duration totalCheckDuration;

  const SystemHealthResult({
    required this.overallStatus,
    required this.timestamp,
    required this.services,
    required this.systemInfo,
    required this.totalCheckDuration,
  });

  /// Get overall health score (0-100)
  int get overallHealthScore {
    if (services.isEmpty) return 0;

    final sum = services.fold<int>(0, (sum, service) => sum + service.healthScore);
    return (sum / services.length).round();
  }

  /// Count services by status
  Map<HealthStatus, int> get serviceCountByStatus {
    final counts = <HealthStatus, int>{};
    for (final service in services) {
      counts[service.status] = (counts[service.status] ?? 0) + 1;
    }
    return counts;
  }

  /// Get list of unhealthy services
  List<HealthCheckResult> get unhealthyServices =>
      services.where((s) => !s.isHealthy).toList();

  /// Get list of degraded services
  List<HealthCheckResult> get degradedServices =>
      services.where((s) => s.status == HealthStatus.degraded).toList();

  /// Whether the system is operational
  bool get isOperational =>
      overallStatus == HealthStatus.healthy ||
      overallStatus == HealthStatus.degraded;

  Map<String, dynamic> toJson() => {
    'overallStatus': overallStatus.name,
    'timestamp': timestamp.toIso8601String(),
    'overallHealthScore': overallHealthScore,
    'totalCheckDuration': totalCheckDuration.inMilliseconds,
    'systemInfo': systemInfo,
    'services': services.map((s) => s.toJson()).toList(),
    'summary': {
      'total': services.length,
      'healthy': serviceCountByStatus[HealthStatus.healthy] ?? 0,
      'degraded': serviceCountByStatus[HealthStatus.degraded] ?? 0,
      'unhealthy': serviceCountByStatus[HealthStatus.unhealthy] ?? 0,
      'unknown': serviceCountByStatus[HealthStatus.unknown] ?? 0,
    },
  };

  @override
  String toString() =>
      'SystemHealth(${overallStatus.name}, score: $overallHealthScore, services: ${services.length})';
}

/// Liveness probe result
class LivenessProbe {
  final bool isAlive;
  final String message;
  final DateTime timestamp;

  const LivenessProbe({
    required this.isAlive,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'isAlive': isAlive,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Readiness probe result
class ReadinessProbe {
  final bool isReady;
  final String message;
  final List<String> blockers;
  final DateTime timestamp;

  const ReadinessProbe({
    required this.isReady,
    required this.message,
    this.blockers = const [],
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'isReady': isReady,
    'message': message,
    'blockers': blockers,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Service version information
class ServiceVersion {
  final String version;
  final String buildNumber;
  final String buildDate;
  final String gitCommit;
  final Map<String, String> metadata;

  const ServiceVersion({
    required this.version,
    required this.buildNumber,
    required this.buildDate,
    this.gitCommit = 'unknown',
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'buildNumber': buildNumber,
    'buildDate': buildDate,
    'gitCommit': gitCommit,
    'metadata': metadata,
  };
}
