// ABOUTME: Centralized health check service for monitoring all system services
// ABOUTME: Aggregates health status from all registered services and provides system-wide health reporting

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart' if (dart.library.html) 'package:package_info_plus/package_info_plus.dart';

import 'health_check_models.dart';
import 'service_health_checker.dart';
import '../utils/logging_service.dart';

/// Central health check service
class HealthCheckService {
  static const String _tag = 'HealthCheckService';

  // Singleton pattern
  static final HealthCheckService _instance = HealthCheckService._();
  static HealthCheckService get instance => _instance;

  HealthCheckService._();

  // Registered services
  final Map<String, ServiceHealthChecker> _services = {};

  // Health check configuration
  Duration _checkInterval = const Duration(minutes: 5);
  Timer? _periodicCheckTimer;
  bool _isPeriodicCheckEnabled = false;

  // Health history
  final List<SystemHealthResult> _healthHistory = [];
  final int _maxHistorySize = 100;

  // Health status stream
  final StreamController<SystemHealthResult> _healthStatusController =
      StreamController<SystemHealthResult>.broadcast();

  /// Stream of system health updates
  Stream<SystemHealthResult> get healthStatusStream =>
      _healthStatusController.stream;

  /// Latest system health result
  SystemHealthResult? _latestHealth;
  SystemHealthResult? get latestHealth => _latestHealth;

  /// Register a service for health checking
  void registerService(ServiceHealthChecker service) {
    _services[service.serviceName] = service;
    LoggingService.instance.log(
      _tag,
      'Registered service: ${service.serviceName}',
      LogLevel.info,
    );
  }

  /// Unregister a service
  void unregisterService(String serviceName) {
    _services.remove(serviceName);
    LoggingService.instance.log(
      _tag,
      'Unregistered service: $serviceName',
      LogLevel.info,
    );
  }

  /// Get registered service by name
  ServiceHealthChecker? getService(String serviceName) {
    return _services[serviceName];
  }

  /// Get all registered service names
  List<String> get registeredServices => _services.keys.toList();

  /// Check health of a specific service
  Future<HealthCheckResult> checkServiceHealth(String serviceName) async {
    final service = _services[serviceName];

    if (service == null) {
      return HealthCheckResult(
        serviceName: serviceName,
        version: 'unknown',
        status: HealthStatus.unknown,
        message: 'Service not registered',
        timestamp: DateTime.now(),
        isLive: false,
        isReady: false,
      );
    }

    try {
      return await service.checkHealth();
    } catch (e) {
      LoggingService.instance.log(
        _tag,
        'Error checking health for $serviceName: $e',
        LogLevel.error,
      );

      return HealthCheckResult(
        serviceName: serviceName,
        version: service.version,
        status: HealthStatus.unhealthy,
        message: 'Health check failed: $e',
        timestamp: DateTime.now(),
        isLive: false,
        isReady: false,
        details: {'error': e.toString()},
      );
    }
  }

  /// Check health of all registered services
  Future<SystemHealthResult> checkSystemHealth() async {
    final startTime = DateTime.now();

    LoggingService.instance.log(
      _tag,
      'Starting system health check for ${_services.length} services',
      LogLevel.debug,
    );

    // Check all services in parallel
    final healthCheckFutures = _services.keys.map((serviceName) async {
      try {
        return await checkServiceHealth(serviceName);
      } catch (e) {
        LoggingService.instance.log(
          _tag,
          'Error in health check for $serviceName: $e',
          LogLevel.error,
        );

        return HealthCheckResult(
          serviceName: serviceName,
          version: 'unknown',
          status: HealthStatus.unhealthy,
          message: 'Health check exception: $e',
          timestamp: DateTime.now(),
          isLive: false,
          isReady: false,
        );
      }
    });

    final serviceResults = await Future.wait(healthCheckFutures);

    // Determine overall system health
    final overallStatus = _calculateOverallStatus(serviceResults);

    // Get system information
    final systemInfo = await _getSystemInfo();

    final totalDuration = DateTime.now().difference(startTime);

    final result = SystemHealthResult(
      overallStatus: overallStatus,
      timestamp: DateTime.now(),
      services: serviceResults,
      systemInfo: systemInfo,
      totalCheckDuration: totalDuration,
    );

    // Store in history
    _addToHistory(result);

    // Update latest health
    _latestHealth = result;

    // Emit to stream
    _healthStatusController.add(result);

    LoggingService.instance.log(
      _tag,
      'System health check completed: ${overallStatus.name} '
      '(${result.overallHealthScore}/100) in ${totalDuration.inMilliseconds}ms',
      overallStatus == HealthStatus.healthy ? LogLevel.debug : LogLevel.warning,
    );

    return result;
  }

  /// Start periodic health checks
  void startPeriodicHealthChecks({Duration? interval}) {
    if (interval != null) {
      _checkInterval = interval;
    }

    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(_checkInterval, (_) async {
      await checkSystemHealth();
    });

    _isPeriodicCheckEnabled = true;

    LoggingService.instance.log(
      _tag,
      'Started periodic health checks (interval: ${_checkInterval.inMinutes} minutes)',
      LogLevel.info,
    );

    // Run initial check
    checkSystemHealth();
  }

  /// Stop periodic health checks
  void stopPeriodicHealthChecks() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    _isPeriodicCheckEnabled = false;

    LoggingService.instance.log(
      _tag,
      'Stopped periodic health checks',
      LogLevel.info,
    );
  }

  /// Get health check history
  List<SystemHealthResult> getHealthHistory({int? limit}) {
    if (limit == null) return List.unmodifiable(_healthHistory);

    final startIndex = _healthHistory.length > limit
        ? _healthHistory.length - limit
        : 0;

    return _healthHistory.sublist(startIndex);
  }

  /// Get health trends
  Map<String, dynamic> getHealthTrends() {
    if (_healthHistory.isEmpty) {
      return {
        'averageHealthScore': 0,
        'trend': 'stable',
        'degradationRate': 0.0,
      };
    }

    final recentHistory = _healthHistory.length > 10
        ? _healthHistory.sublist(_healthHistory.length - 10)
        : _healthHistory;

    final avgScore = recentHistory.fold<int>(
          0,
          (sum, result) => sum + result.overallHealthScore,
        ) /
        recentHistory.length;

    // Calculate trend
    String trend = 'stable';
    double degradationRate = 0.0;

    if (recentHistory.length >= 2) {
      final oldScore = recentHistory.first.overallHealthScore;
      final newScore = recentHistory.last.overallHealthScore;
      final scoreDiff = newScore - oldScore;

      degradationRate = scoreDiff / oldScore;

      if (scoreDiff > 5) {
        trend = 'improving';
      } else if (scoreDiff < -5) {
        trend = 'degrading';
      }
    }

    return {
      'averageHealthScore': avgScore.round(),
      'trend': trend,
      'degradationRate': degradationRate,
      'checkCount': _healthHistory.length,
    };
  }

  /// Clear health history
  void clearHistory() {
    _healthHistory.clear();
    LoggingService.instance.log(
      _tag,
      'Health history cleared',
      LogLevel.info,
    );
  }

  /// Dispose the service
  Future<void> dispose() async {
    stopPeriodicHealthChecks();
    await _healthStatusController.close();
    _services.clear();
    _healthHistory.clear();

    LoggingService.instance.log(
      _tag,
      'Health check service disposed',
      LogLevel.info,
    );
  }

  // Private methods

  HealthStatus _calculateOverallStatus(List<HealthCheckResult> results) {
    if (results.isEmpty) return HealthStatus.unknown;

    // If any critical service is unhealthy, system is unhealthy
    final unhealthyCount = results.where((r) => r.status == HealthStatus.unhealthy).length;
    final degradedCount = results.where((r) => r.status == HealthStatus.degraded).length;
    final unknownCount = results.where((r) => r.status == HealthStatus.unknown).length;

    if (unhealthyCount > 0) {
      return HealthStatus.unhealthy;
    } else if (degradedCount > 0 || unknownCount > 0) {
      return HealthStatus.degraded;
    } else {
      return HealthStatus.healthy;
    }
  }

  void _addToHistory(SystemHealthResult result) {
    _healthHistory.add(result);

    // Maintain max history size
    if (_healthHistory.length > _maxHistorySize) {
      _healthHistory.removeAt(0);
    }
  }

  Future<Map<String, dynamic>> _getSystemInfo() async {
    final info = <String, dynamic>{
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
      'environment': kDebugMode ? 'development' : 'production',
    };

    try {
      // Try to get package info (may not be available in all contexts)
      if (!kIsWeb) {
        info['osVersion'] = Platform.operatingSystemVersion;
        info['numberOfProcessors'] = Platform.numberOfProcessors;
        info['locale'] = Platform.localeName;
      }
    } catch (e) {
      // Ignore if not available
      LoggingService.instance.log(
        _tag,
        'Could not get full system info: $e',
        LogLevel.debug,
      );
    }

    return info;
  }

  /// Get service dependency graph
  Map<String, List<String>> getDependencyGraph() {
    final graph = <String, List<String>>{};

    for (final service in _services.values) {
      graph[service.serviceName] = service.dependencies;
    }

    return graph;
  }

  /// Validate service dependencies
  Future<Map<String, List<String>>> validateDependencies() async {
    final issues = <String, List<String>>{};

    for (final service in _services.values) {
      final serviceIssues = <String>[];

      for (final depName in service.dependencies) {
        if (!_services.containsKey(depName)) {
          serviceIssues.add('Missing dependency: $depName');
        } else {
          final depHealth = await checkServiceHealth(depName);
          if (!depHealth.isHealthy) {
            serviceIssues.add('Unhealthy dependency: $depName (${depHealth.status.name})');
          }
        }
      }

      if (serviceIssues.isNotEmpty) {
        issues[service.serviceName] = serviceIssues;
      }
    }

    return issues;
  }
}
