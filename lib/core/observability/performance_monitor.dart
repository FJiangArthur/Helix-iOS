// ABOUTME: Performance monitoring system with automated scaling recommendations
// ABOUTME: Tracks resource usage and provides optimization suggestions

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'observability_config.dart';
import 'alert_manager.dart';
import 'anomaly_detector.dart';
import '../utils/logging_service.dart';

/// Performance metric snapshot
class PerformanceMetrics {
  final DateTime timestamp;
  final double? cpuUsagePercent;
  final int? memoryUsageMB;
  final int? networkBytesReceived;
  final int? networkBytesSent;
  final double? batteryLevel;
  final double? frameRate;
  final int? activeConnections;

  PerformanceMetrics({
    required this.timestamp,
    this.cpuUsagePercent,
    this.memoryUsageMB,
    this.networkBytesReceived,
    this.networkBytesSent,
    this.batteryLevel,
    this.frameRate,
    this.activeConnections,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    if (cpuUsagePercent != null) 'cpuUsagePercent': cpuUsagePercent,
    if (memoryUsageMB != null) 'memoryUsageMB': memoryUsageMB,
    if (networkBytesReceived != null) 'networkBytesReceived': networkBytesReceived,
    if (networkBytesSent != null) 'networkBytesSent': networkBytesSent,
    if (batteryLevel != null) 'batteryLevel': batteryLevel,
    if (frameRate != null) 'frameRate': frameRate,
    if (activeConnections != null) 'activeConnections': activeConnections,
  };
}

/// Scaling recommendation
enum ScalingAction {
  scaleUp,
  scaleDown,
  optimize,
  noAction,
}

/// Performance recommendation
class PerformanceRecommendation {
  final ScalingAction action;
  final String resource;
  final String reason;
  final double currentValue;
  final double threshold;
  final String suggestion;
  final AlertSeverity severity;

  PerformanceRecommendation({
    required this.action,
    required this.resource,
    required this.reason,
    required this.currentValue,
    required this.threshold,
    required this.suggestion,
    this.severity = AlertSeverity.info,
  });

  Map<String, dynamic> toJson() => {
    'action': action.name,
    'resource': resource,
    'reason': reason,
    'currentValue': currentValue,
    'threshold': threshold,
    'suggestion': suggestion,
    'severity': severity.name,
  };
}

/// Performance monitor with auto-scaling recommendations
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._();
  static PerformanceMonitor get instance => _instance;

  PerformanceMonitor._();

  Timer? _monitoringTimer;
  final List<PerformanceMetrics> _metricsHistory = [];
  final List<PerformanceRecommendation> _recommendations = [];

  bool _isMonitoring = false;
  int _metricsCollectionCount = 0;

  PerformanceMonitoringConfig get _config =>
      ObservabilityConfig.instance.perfConfig;

  /// Start performance monitoring
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(
      _config.metricsCollectionInterval,
      (_) => _collectMetrics(),
    );

    LoggingService.instance.info(
      'PerformanceMonitor',
      'Performance monitoring started (interval: ${_config.metricsCollectionInterval.inSeconds}s)',
    );
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;

    LoggingService.instance.info(
      'PerformanceMonitor',
      'Performance monitoring stopped',
    );
  }

  /// Collect performance metrics
  void _collectMetrics() {
    try {
      final metrics = PerformanceMetrics(
        timestamp: DateTime.now(),
        memoryUsageMB: _estimateMemoryUsage(),
        cpuUsagePercent: _estimateCpuUsage(),
        // Note: Network and battery metrics would require platform channels
        // or additional packages. These are placeholders.
      );

      _metricsHistory.add(metrics);
      _metricsCollectionCount++;

      // Maintain history (keep last 1000 data points)
      if (_metricsHistory.length > 1000) {
        _metricsHistory.removeAt(0);
      }

      // Record metrics for anomaly detection
      if (metrics.memoryUsageMB != null) {
        AnomalyDetector.instance.recordMetric(
          metricName: 'memory_usage_mb',
          value: metrics.memoryUsageMB!.toDouble(),
        );

        // Evaluate against alert rules
        AlertManager.instance.evaluateMetric(
          metricName: 'memory_usage_mb',
          value: metrics.memoryUsageMB!.toDouble(),
        );
      }

      if (metrics.cpuUsagePercent != null) {
        AnomalyDetector.instance.recordMetric(
          metricName: 'cpu_usage_percent',
          value: metrics.cpuUsagePercent!,
        );
      }

      // Generate recommendations periodically
      if (_metricsCollectionCount % 10 == 0) {
        _generateRecommendations();
      }

      // Log metrics in debug mode
      if (kDebugMode && _metricsCollectionCount % 20 == 0) {
        LoggingService.instance.debug(
          'PerformanceMonitor',
          'Metrics snapshot',
          metrics.toJson(),
        );
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'PerformanceMonitor',
        'Error collecting metrics',
        e,
        stackTrace,
      );
    }
  }

  /// Estimate memory usage (simplified)
  int _estimateMemoryUsage() {
    // This is a simplified estimation
    // In production, you would use platform channels or packages like
    // flutter_performance_monitor or memory_info

    // For now, return a simulated value based on metrics history size
    final baseMemory = 50; // Base memory usage in MB
    final historyMemory = _metricsHistory.length * 0.001; // Rough estimate

    return (baseMemory + historyMemory).round();
  }

  /// Estimate CPU usage (simplified)
  double _estimateCpuUsage() {
    // This is a placeholder. Real CPU monitoring would require
    // platform-specific implementation via method channels

    // Return simulated value
    return 25.0 + (DateTime.now().millisecond % 30);
  }

  /// Generate performance recommendations
  void _generateRecommendations() {
    _recommendations.clear();

    if (_metricsHistory.isEmpty) return;

    final recentMetrics = _getRecentMetrics(const Duration(minutes: 5));
    if (recentMetrics.isEmpty) return;

    // Analyze memory usage
    _analyzeMemoryUsage(recentMetrics);

    // Analyze CPU usage
    _analyzeCpuUsage(recentMetrics);

    // Analyze response times
    _analyzeResponseTimes();

    // Log recommendations
    if (_recommendations.isNotEmpty) {
      LoggingService.instance.info(
        'PerformanceMonitor',
        'Generated ${_recommendations.length} performance recommendations',
      );

      for (final rec in _recommendations) {
        if (rec.severity == AlertSeverity.critical ||
            rec.severity == AlertSeverity.warning) {
          LoggingService.instance.warning(
            'PerformanceMonitor',
            rec.reason,
            rec.toJson(),
          );
        }
      }
    }
  }

  /// Analyze memory usage patterns
  void _analyzeMemoryUsage(List<PerformanceMetrics> metrics) {
    final memoryValues = metrics
        .where((m) => m.memoryUsageMB != null)
        .map((m) => m.memoryUsageMB!.toDouble())
        .toList();

    if (memoryValues.isEmpty) return;

    final avgMemory = memoryValues.reduce((a, b) => a + b) / memoryValues.length;
    final maxMemory = memoryValues.reduce((a, b) => a > b ? a : b);

    // Check against thresholds
    if (avgMemory > _config.scaleUpMemoryThreshold) {
      _recommendations.add(PerformanceRecommendation(
        action: ScalingAction.optimize,
        resource: 'memory',
        reason: 'High average memory usage detected',
        currentValue: avgMemory,
        threshold: _config.scaleUpMemoryThreshold,
        suggestion: 'Consider implementing memory optimization:\n'
            '- Clear unused caches\n'
            '- Dispose unused resources\n'
            '- Implement lazy loading\n'
            '- Review memory leaks',
        severity: maxMemory > ObservabilityConfig.instance.thresholds.memoryUsageCriticalMB
            ? AlertSeverity.critical
            : AlertSeverity.warning,
      ));
    } else if (avgMemory < _config.scaleDownMemoryThreshold) {
      _recommendations.add(PerformanceRecommendation(
        action: ScalingAction.noAction,
        resource: 'memory',
        reason: 'Memory usage is optimal',
        currentValue: avgMemory,
        threshold: _config.scaleDownMemoryThreshold,
        suggestion: 'Memory usage is within normal range',
        severity: AlertSeverity.info,
      ));
    }

    // Check for memory growth trend
    if (memoryValues.length >= 3) {
      final firstHalf = memoryValues.sublist(0, memoryValues.length ~/ 2);
      final secondHalf = memoryValues.sublist(memoryValues.length ~/ 2);

      final firstHalfAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondHalfAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

      if (secondHalfAvg > firstHalfAvg * 1.3) {
        _recommendations.add(PerformanceRecommendation(
          action: ScalingAction.optimize,
          resource: 'memory',
          reason: 'Memory usage trending upward',
          currentValue: secondHalfAvg,
          threshold: firstHalfAvg,
          suggestion: 'Memory usage increasing over time. Check for memory leaks:\n'
              '- Review event listeners\n'
              '- Check stream subscriptions\n'
              '- Verify proper disposal in StatefulWidgets',
          severity: AlertSeverity.warning,
        ));
      }
    }
  }

  /// Analyze CPU usage patterns
  void _analyzeCpuUsage(List<PerformanceMetrics> metrics) {
    final cpuValues = metrics
        .where((m) => m.cpuUsagePercent != null)
        .map((m) => m.cpuUsagePercent!)
        .toList();

    if (cpuValues.isEmpty) return;

    final avgCpu = cpuValues.reduce((a, b) => a + b) / cpuValues.length;
    final maxCpu = cpuValues.reduce((a, b) => a > b ? a : b);

    if (avgCpu > _config.scaleUpCpuThreshold) {
      _recommendations.add(PerformanceRecommendation(
        action: ScalingAction.optimize,
        resource: 'cpu',
        reason: 'High CPU usage detected',
        currentValue: avgCpu,
        threshold: _config.scaleUpCpuThreshold,
        suggestion: 'Consider CPU optimization:\n'
            '- Move heavy operations off main thread\n'
            '- Use Isolates for parallel processing\n'
            '- Optimize rendering and rebuilds\n'
            '- Review computational complexity',
        severity: maxCpu > ObservabilityConfig.instance.thresholds.cpuUsageCriticalPercent
            ? AlertSeverity.critical
            : AlertSeverity.warning,
      ));
    }
  }

  /// Analyze response times and latencies
  void _analyzeResponseTimes() {
    // Get latency metrics from anomaly detector
    final audioLatency = AnomalyDetector.instance.getBaseline('audio_latency_ms');
    final transcriptionLatency = AnomalyDetector.instance.getBaseline('transcription_latency_ms');

    if (audioLatency != null) {
      final p95 = audioLatency['p95'] ?? 0;
      final sloTarget = ObservabilityConfig.instance.sloTargets.audioLatencyP95;

      if (p95 > sloTarget) {
        _recommendations.add(PerformanceRecommendation(
          action: ScalingAction.optimize,
          resource: 'audio_latency',
          reason: 'Audio latency exceeds SLO target',
          currentValue: p95,
          threshold: sloTarget.toDouble(),
          suggestion: 'Optimize audio processing:\n'
              '- Review buffer sizes\n'
              '- Check audio processing pipeline\n'
              '- Verify sampling rates\n'
              '- Consider hardware acceleration',
          severity: AlertSeverity.warning,
        ));
      }
    }

    if (transcriptionLatency != null) {
      final p95 = transcriptionLatency['p95'] ?? 0;
      final sloTarget = ObservabilityConfig.instance.sloTargets.transcriptionLatencyP95;

      if (p95 > sloTarget) {
        _recommendations.add(PerformanceRecommendation(
          action: ScalingAction.optimize,
          resource: 'transcription_latency',
          reason: 'Transcription latency exceeds SLO target',
          currentValue: p95,
          threshold: sloTarget.toDouble(),
          suggestion: 'Optimize transcription:\n'
              '- Review network connectivity\n'
              '- Consider local processing fallback\n'
              '- Implement request batching\n'
              '- Check API response times',
          severity: AlertSeverity.warning,
        ));
      }
    }
  }

  /// Get recent metrics
  List<PerformanceMetrics> _getRecentMetrics(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return _metricsHistory
        .where((m) => m.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Get current performance recommendations
  List<PerformanceRecommendation> getRecommendations({
    ScalingAction? action,
    AlertSeverity? severity,
  }) {
    var filtered = _recommendations.toList();

    if (action != null) {
      filtered = filtered.where((r) => r.action == action).toList();
    }

    if (severity != null) {
      filtered = filtered.where((r) => r.severity == severity).toList();
    }

    return filtered;
  }

  /// Get metrics history
  List<PerformanceMetrics> getMetricsHistory({Duration? timeWindow}) {
    if (timeWindow == null) {
      return List.from(_metricsHistory);
    }

    final cutoff = DateTime.now().subtract(timeWindow);
    return _metricsHistory
        .where((m) => m.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Generate performance report
  Map<String, dynamic> generateReport({Duration? timeWindow}) {
    final window = timeWindow ?? const Duration(hours: 1);
    final metrics = getMetricsHistory(timeWindow: window);

    if (metrics.isEmpty) {
      return {
        'timeWindow': '${window.inHours}h',
        'error': 'No metrics available',
      };
    }

    final memoryValues = metrics
        .where((m) => m.memoryUsageMB != null)
        .map((m) => m.memoryUsageMB!.toDouble())
        .toList();

    final cpuValues = metrics
        .where((m) => m.cpuUsagePercent != null)
        .map((m) => m.cpuUsagePercent!)
        .toList();

    return {
      'timeWindow': '${window.inHours}h',
      'generatedAt': DateTime.now().toIso8601String(),
      'totalDataPoints': metrics.length,
      'memory': _generateResourceStats('Memory (MB)', memoryValues),
      'cpu': _generateResourceStats('CPU (%)', cpuValues),
      'recommendations': _recommendations.map((r) => r.toJson()).toList(),
      'sloCompliance': _checkSLOCompliance(),
    };
  }

  /// Generate statistics for a resource
  Map<String, dynamic> _generateResourceStats(String name, List<double> values) {
    if (values.isEmpty) {
      return {'name': name, 'available': false};
    }

    values.sort();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.first;
    final max = values.last;
    final p50 = values[values.length ~/ 2];
    final p95 = values[(values.length * 0.95).floor()];
    final p99 = values[(values.length * 0.99).floor()];

    return {
      'name': name,
      'available': true,
      'avg': avg.toStringAsFixed(2),
      'min': min.toStringAsFixed(2),
      'max': max.toStringAsFixed(2),
      'p50': p50.toStringAsFixed(2),
      'p95': p95.toStringAsFixed(2),
      'p99': p99.toStringAsFixed(2),
    };
  }

  /// Check SLO compliance
  Map<String, dynamic> _checkSLOCompliance() {
    final sloTargets = ObservabilityConfig.instance.sloTargets;
    final compliance = <String, bool>{};

    // Check latency SLOs
    final audioLatency = AnomalyDetector.instance.getBaseline('audio_latency_ms');
    if (audioLatency != null) {
      final p95 = audioLatency['p95'] ?? 0;
      compliance['audio_latency_p95'] = p95 <= sloTargets.audioLatencyP95;
    }

    final transcriptionLatency = AnomalyDetector.instance.getBaseline('transcription_latency_ms');
    if (transcriptionLatency != null) {
      final p95 = transcriptionLatency['p95'] ?? 0;
      compliance['transcription_latency_p95'] = p95 <= sloTargets.transcriptionLatencyP95;
    }

    return {
      'checks': compliance,
      'overallCompliance': compliance.values.every((v) => v),
      'complianceRate': compliance.values.where((v) => v).length / compliance.length,
    };
  }

  /// Clear metrics history
  void clearHistory() {
    _metricsHistory.clear();
    _recommendations.clear();
    _metricsCollectionCount = 0;
    LoggingService.instance.info('PerformanceMonitor', 'Metrics history cleared');
  }

  /// Get monitoring status
  bool get isMonitoring => _isMonitoring;
}
