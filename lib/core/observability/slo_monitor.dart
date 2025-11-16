// ABOUTME: SLO/SLA monitoring system for tracking service level objectives
// ABOUTME: Monitors availability, latency, and error budgets

import 'dart:async';
import 'observability_config.dart';
import 'alert_manager.dart';
import '../utils/logging_service.dart';

/// Service health status
enum ServiceHealth {
  healthy,
  degraded,
  unhealthy,
  unknown,
}

/// SLO measurement window
enum SLOWindow {
  rolling1h,    // Rolling 1 hour
  rolling24h,   // Rolling 24 hours
  rolling7d,    // Rolling 7 days
  rolling30d,   // Rolling 30 days
}

/// Service metrics for SLO tracking
class ServiceMetrics {
  final String serviceName;
  final DateTime timestamp;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final List<int> latencies; // in milliseconds
  final Duration uptime;
  final Duration downtime;

  ServiceMetrics({
    required this.serviceName,
    required this.timestamp,
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.latencies = const [],
    this.uptime = Duration.zero,
    this.downtime = Duration.zero,
  });

  double get successRate {
    if (totalRequests == 0) return 100.0;
    return (successfulRequests / totalRequests) * 100;
  }

  double get errorRate {
    if (totalRequests == 0) return 0.0;
    return (failedRequests / totalRequests) * 100;
  }

  double get availability {
    final total = uptime + downtime;
    if (total == Duration.zero) return 100.0;
    return (uptime.inMilliseconds / total.inMilliseconds) * 100;
  }

  int? get p50Latency => _getPercentile(50);
  int? get p95Latency => _getPercentile(95);
  int? get p99Latency => _getPercentile(99);

  int? _getPercentile(int percentile) {
    if (latencies.isEmpty) return null;
    final sorted = List<int>.from(latencies)..sort();
    final index = ((percentile / 100) * sorted.length).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  Map<String, dynamic> toJson() => {
    'serviceName': serviceName,
    'timestamp': timestamp.toIso8601String(),
    'totalRequests': totalRequests,
    'successfulRequests': successfulRequests,
    'failedRequests': failedRequests,
    'successRate': successRate.toStringAsFixed(2) + '%',
    'errorRate': errorRate.toStringAsFixed(2) + '%',
    'availability': availability.toStringAsFixed(2) + '%',
    'latencyP50': p50Latency,
    'latencyP95': p95Latency,
    'latencyP99': p99Latency,
    'uptime': uptime.inSeconds,
    'downtime': downtime.inSeconds,
  };
}

/// SLO compliance status
class SLOComplianceStatus {
  final String serviceName;
  final SLOWindow window;
  final bool meetsAvailabilitySLO;
  final bool meetsLatencySLO;
  final bool meetsErrorRateSLO;
  final double errorBudgetRemaining; // Percentage
  final Map<String, dynamic> details;
  final DateTime evaluatedAt;

  SLOComplianceStatus({
    required this.serviceName,
    required this.window,
    required this.meetsAvailabilitySLO,
    required this.meetsLatencySLO,
    required this.meetsErrorRateSLO,
    required this.errorBudgetRemaining,
    required this.details,
  }) : evaluatedAt = DateTime.now();

  bool get meetsAllSLOs =>
      meetsAvailabilitySLO && meetsLatencySLO && meetsErrorRateSLO;

  ServiceHealth get healthStatus {
    if (meetsAllSLOs && errorBudgetRemaining > 50) {
      return ServiceHealth.healthy;
    } else if (meetsAllSLOs && errorBudgetRemaining > 20) {
      return ServiceHealth.degraded;
    } else if (!meetsAllSLOs) {
      return ServiceHealth.unhealthy;
    }
    return ServiceHealth.unknown;
  }

  Map<String, dynamic> toJson() => {
    'serviceName': serviceName,
    'window': window.name,
    'meetsAvailabilitySLO': meetsAvailabilitySLO,
    'meetsLatencySLO': meetsLatencySLO,
    'meetsErrorRateSLO': meetsErrorRateSLO,
    'meetsAllSLOs': meetsAllSLOs,
    'errorBudgetRemaining': errorBudgetRemaining.toStringAsFixed(2) + '%',
    'healthStatus': healthStatus.name,
    'details': details,
    'evaluatedAt': evaluatedAt.toIso8601String(),
  };
}

/// SLO Monitor - tracks and reports on SLO compliance
class SLOMonitor {
  static final SLOMonitor _instance = SLOMonitor._();
  static SLOMonitor get instance => _instance;

  SLOMonitor._();

  final Map<String, List<ServiceMetrics>> _serviceMetrics = {};
  final Map<String, DateTime> _serviceStartTime = {};
  final Map<String, Duration> _serviceTotalDowntime = {};

  Timer? _reportingTimer;
  bool _isMonitoring = false;

  /// Start SLO monitoring
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _reportingTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _generateSLOReports(),
    );

    LoggingService.instance.info(
      'SLOMonitor',
      'SLO monitoring started',
    );
  }

  /// Stop SLO monitoring
  void stopMonitoring() {
    _reportingTimer?.cancel();
    _reportingTimer = null;
    _isMonitoring = false;

    LoggingService.instance.info(
      'SLOMonitor',
      'SLO monitoring stopped',
    );
  }

  /// Record service operation
  void recordOperation({
    required String serviceName,
    required bool success,
    required int latencyMs,
    Map<String, dynamic>? metadata,
  }) {
    // Initialize service if needed
    if (!_serviceStartTime.containsKey(serviceName)) {
      _serviceStartTime[serviceName] = DateTime.now();
      _serviceTotalDowntime[serviceName] = Duration.zero;
    }

    if (!_serviceMetrics.containsKey(serviceName)) {
      _serviceMetrics[serviceName] = [];
    }

    // Find or create current metrics bucket (5-minute buckets)
    final now = DateTime.now();
    final bucketTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ 5) * 5,
    );

    var currentMetrics = _serviceMetrics[serviceName]!.firstWhere(
      (m) => m.timestamp == bucketTime,
      orElse: () {
        final newMetrics = ServiceMetrics(
          serviceName: serviceName,
          timestamp: bucketTime,
          uptime: Duration.zero,
          downtime: Duration.zero,
        );
        _serviceMetrics[serviceName]!.add(newMetrics);
        return newMetrics;
      },
    );

    // Update metrics
    final updatedMetrics = ServiceMetrics(
      serviceName: serviceName,
      timestamp: currentMetrics.timestamp,
      totalRequests: currentMetrics.totalRequests + 1,
      successfulRequests: success
          ? currentMetrics.successfulRequests + 1
          : currentMetrics.successfulRequests,
      failedRequests: !success
          ? currentMetrics.failedRequests + 1
          : currentMetrics.failedRequests,
      latencies: [...currentMetrics.latencies, latencyMs],
      uptime: currentMetrics.uptime,
      downtime: currentMetrics.downtime,
    );

    // Replace old metrics with updated
    final index = _serviceMetrics[serviceName]!
        .indexWhere((m) => m.timestamp == bucketTime);
    if (index != -1) {
      _serviceMetrics[serviceName]![index] = updatedMetrics;
    }

    // Evaluate SLO compliance for latency
    _evaluateLatencySLO(serviceName, latencyMs);

    // Clean up old metrics (keep last 30 days)
    _cleanupOldMetrics(serviceName);
  }

  /// Record service downtime
  void recordDowntime({
    required String serviceName,
    required Duration duration,
  }) {
    _serviceTotalDowntime[serviceName] =
        (_serviceTotalDowntime[serviceName] ?? Duration.zero) + duration;

    LoggingService.instance.warning(
      'SLOMonitor',
      'Downtime recorded for $serviceName',
      {'duration': duration.inSeconds},
    );
  }

  /// Evaluate latency SLO
  void _evaluateLatencySLO(String serviceName, int latencyMs) {
    final sloTargets = ObservabilityConfig.instance.sloTargets;

    int p95Target;
    switch (serviceName.toLowerCase()) {
      case 'audio':
      case 'recording':
        p95Target = sloTargets.audioLatencyP95;
        break;
      case 'transcription':
        p95Target = sloTargets.transcriptionLatencyP95;
        break;
      case 'ai':
      case 'analysis':
        p95Target = sloTargets.aiAnalysisLatencyP95;
        break;
      default:
        return;
    }

    // Fire alert if significantly over SLO
    if (latencyMs > p95Target * 1.5) {
      AlertManager.instance.evaluateMetric(
        metricName: '${serviceName}_latency_ms',
        value: latencyMs.toDouble(),
        context: {
          'service': serviceName,
          'slo_target': p95Target,
          'violation_ratio': latencyMs / p95Target,
        },
      );
    }
  }

  /// Get SLO compliance status
  SLOComplianceStatus getComplianceStatus({
    required String serviceName,
    SLOWindow window = SLOWindow.rolling24h,
  }) {
    final windowDuration = _getWindowDuration(window);
    final metrics = _getMetricsForWindow(serviceName, windowDuration);

    if (metrics.isEmpty) {
      return SLOComplianceStatus(
        serviceName: serviceName,
        window: window,
        meetsAvailabilitySLO: true,
        meetsLatencySLO: true,
        meetsErrorRateSLO: true,
        errorBudgetRemaining: 100.0,
        details: {'error': 'No metrics available'},
      );
    }

    final sloTargets = ObservabilityConfig.instance.sloTargets;

    // Calculate aggregated metrics
    final totalRequests = metrics.fold<int>(0, (sum, m) => sum + m.totalRequests);
    final successfulRequests = metrics.fold<int>(0, (sum, m) => sum + m.successfulRequests);
    final failedRequests = metrics.fold<int>(0, (sum, m) => sum + m.failedRequests);
    final allLatencies = metrics.expand((m) => m.latencies).toList()..sort();

    final successRate = totalRequests > 0
        ? (successfulRequests / totalRequests) * 100
        : 100.0;

    final errorRate = totalRequests > 0
        ? (failedRequests / totalRequests) * 100
        : 0.0;

    final p95Latency = allLatencies.isNotEmpty
        ? allLatencies[(allLatencies.length * 0.95).floor()]
        : 0;

    // Get service-specific targets
    final availabilityTarget = _getAvailabilityTarget(serviceName);
    final successRateTarget = _getSuccessRateTarget(serviceName);
    final latencyTarget = _getLatencyTarget(serviceName);

    // Check SLO compliance
    final meetsAvailabilitySLO = successRate >= availabilityTarget;
    final meetsLatencySLO = p95Latency <= latencyTarget;
    final meetsErrorRateSLO = errorRate <= (100 - successRateTarget);

    // Calculate error budget
    final errorBudget = window == SLOWindow.rolling24h
        ? sloTargets.dailyErrorBudget
        : sloTargets.monthlyErrorBudget;
    final errorBudgetUsed = errorRate;
    final errorBudgetRemaining = ((1 - errorBudgetUsed / errorBudget) * 100)
        .clamp(0, 100);

    return SLOComplianceStatus(
      serviceName: serviceName,
      window: window,
      meetsAvailabilitySLO: meetsAvailabilitySLO,
      meetsLatencySLO: meetsLatencySLO,
      meetsErrorRateSLO: meetsErrorRateSLO,
      errorBudgetRemaining: errorBudgetRemaining,
      details: {
        'totalRequests': totalRequests,
        'successRate': successRate.toStringAsFixed(2) + '%',
        'errorRate': errorRate.toStringAsFixed(2) + '%',
        'p95Latency': '${p95Latency}ms',
        'targets': {
          'availability': availabilityTarget,
          'successRate': successRateTarget,
          'p95Latency': latencyTarget,
        },
      },
    );
  }

  /// Generate SLO reports for all services
  void _generateSLOReports() {
    LoggingService.instance.info('SLOMonitor', 'Generating SLO reports');

    for (final serviceName in _serviceMetrics.keys) {
      final status = getComplianceStatus(
        serviceName: serviceName,
        window: SLOWindow.rolling24h,
      );

      // Log compliance status
      LoggingService.instance.log(
        'SLOMonitor',
        'SLO compliance for $serviceName: ${status.healthStatus.name}',
        status.meetsAllSLOs ? LogLevel.info : LogLevel.warning,
        status.toJson(),
      );

      // Fire alert if SLO violated
      if (!status.meetsAllSLOs) {
        AlertManager.instance.evaluateMetric(
          metricName: 'slo_compliance',
          value: 0.0,
          context: status.toJson(),
        );
      }
    }
  }

  /// Get metrics for time window
  List<ServiceMetrics> _getMetricsForWindow(String serviceName, Duration window) {
    final metrics = _serviceMetrics[serviceName];
    if (metrics == null) return [];

    final cutoff = DateTime.now().subtract(window);
    return metrics.where((m) => m.timestamp.isAfter(cutoff)).toList();
  }

  /// Get window duration
  Duration _getWindowDuration(SLOWindow window) {
    switch (window) {
      case SLOWindow.rolling1h:
        return const Duration(hours: 1);
      case SLOWindow.rolling24h:
        return const Duration(hours: 24);
      case SLOWindow.rolling7d:
        return const Duration(days: 7);
      case SLOWindow.rolling30d:
        return const Duration(days: 30);
    }
  }

  /// Get service-specific availability target
  double _getAvailabilityTarget(String serviceName) {
    final sloTargets = ObservabilityConfig.instance.sloTargets;
    switch (serviceName.toLowerCase()) {
      case 'audio':
      case 'recording':
        return sloTargets.audioRecordingAvailability;
      case 'transcription':
        return sloTargets.transcriptionAvailability;
      case 'ai':
      case 'analysis':
        return sloTargets.aiAnalysisAvailability;
      case 'ble':
      case 'bluetooth':
        return sloTargets.bleConnectionAvailability;
      default:
        return 99.0;
    }
  }

  /// Get service-specific success rate target
  double _getSuccessRateTarget(String serviceName) {
    final sloTargets = ObservabilityConfig.instance.sloTargets;
    switch (serviceName.toLowerCase()) {
      case 'audio':
      case 'recording':
        return sloTargets.audioRecordingSuccessRate;
      case 'transcription':
        return sloTargets.transcriptionSuccessRate;
      case 'ai':
      case 'analysis':
        return sloTargets.aiAnalysisSuccessRate;
      case 'ble':
      case 'bluetooth':
        return sloTargets.bleTransactionSuccessRate;
      default:
        return 99.0;
    }
  }

  /// Get service-specific latency target (P95)
  int _getLatencyTarget(String serviceName) {
    final sloTargets = ObservabilityConfig.instance.sloTargets;
    switch (serviceName.toLowerCase()) {
      case 'audio':
      case 'recording':
        return sloTargets.audioLatencyP95;
      case 'transcription':
        return sloTargets.transcriptionLatencyP95;
      case 'ai':
      case 'analysis':
        return sloTargets.aiAnalysisLatencyP95;
      default:
        return 1000;
    }
  }

  /// Clean up old metrics
  void _cleanupOldMetrics(String serviceName) {
    final metrics = _serviceMetrics[serviceName];
    if (metrics == null) return;

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    metrics.removeWhere((m) => m.timestamp.isBefore(cutoff));
  }

  /// Generate comprehensive SLO report
  Map<String, dynamic> generateReport({SLOWindow window = SLOWindow.rolling24h}) {
    final services = <String, Map<String, dynamic>>{};

    for (final serviceName in _serviceMetrics.keys) {
      final status = getComplianceStatus(
        serviceName: serviceName,
        window: window,
      );
      services[serviceName] = status.toJson();
    }

    final overallCompliance = services.values
        .every((s) => s['meetsAllSLOs'] == true);

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'window': window.name,
      'overallCompliance': overallCompliance,
      'totalServices': services.length,
      'compliantServices': services.values
          .where((s) => s['meetsAllSLOs'] == true)
          .length,
      'services': services,
    };
  }

  /// Clear all metrics
  void clearMetrics() {
    _serviceMetrics.clear();
    _serviceStartTime.clear();
    _serviceTotalDowntime.clear();
    LoggingService.instance.info('SLOMonitor', 'All metrics cleared');
  }

  /// Get monitoring status
  bool get isMonitoring => _isMonitoring;
}
