// ABOUTME: Alert management system for monitoring critical metrics and triggering alerts
// ABOUTME: Handles alert evaluation, firing, and notification routing

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'observability_config.dart';
import '../utils/logging_service.dart';

/// Alert status
enum AlertStatus {
  active,    // Alert is currently firing
  resolved,  // Alert has been resolved
  silenced,  // Alert is silenced
  acknowledged // Alert has been acknowledged
}

/// Alert instance
class Alert {
  final String id;
  final AlertRule rule;
  final DateTime triggeredAt;
  final Map<String, dynamic> context;
  AlertStatus status;
  DateTime? resolvedAt;
  DateTime? acknowledgedAt;
  String? acknowledgedBy;

  Alert({
    required this.id,
    required this.rule,
    required this.triggeredAt,
    required this.context,
    this.status = AlertStatus.active,
    this.resolvedAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  Duration get duration {
    final endTime = resolvedAt ?? DateTime.now();
    return endTime.difference(triggeredAt);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'rule': rule.toJson(),
    'triggeredAt': triggeredAt.toIso8601String(),
    'status': status.name,
    'context': context,
    'duration': duration.inSeconds,
    if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
    if (acknowledgedAt != null) 'acknowledgedAt': acknowledgedAt!.toIso8601String(),
    if (acknowledgedBy != null) 'acknowledgedBy': acknowledgedBy,
  };
}

/// Alert manager - evaluates rules and manages alerts
class AlertManager {
  static final AlertManager _instance = AlertManager._();
  static AlertManager get instance => _instance;

  AlertManager._();

  final List<AlertRule> _rules = [];
  final List<Alert> _activeAlerts = [];
  final List<Alert> _alertHistory = [];
  final Map<String, List<double>> _metricBuffer = {};

  bool _isInitialized = false;

  /// Initialize alert manager with default rules
  void initialize() {
    if (_isInitialized) return;

    _loadDefaultAlertRules();
    _isInitialized = true;

    LoggingService.instance.info(
      'AlertManager',
      'Initialized with ${_rules.length} alert rules',
    );
  }

  /// Load default alert rules
  void _loadDefaultAlertRules() {
    _rules.addAll([
      // Audio latency alerts
      AlertRule(
        id: 'audio_latency_warning',
        name: 'Audio Latency Warning',
        description: 'Audio recording latency exceeds warning threshold',
        type: AlertType.performanceLatency,
        severity: AlertSeverity.warning,
        condition: 'audio_latency_ms > threshold',
        threshold: ObservabilityConfig.instance.thresholds.audioLatencyWarningMs.toDouble(),
      ),
      AlertRule(
        id: 'audio_latency_critical',
        name: 'Audio Latency Critical',
        description: 'Audio recording latency exceeds critical threshold',
        type: AlertType.performanceLatency,
        severity: AlertSeverity.critical,
        condition: 'audio_latency_ms > threshold',
        threshold: ObservabilityConfig.instance.thresholds.audioLatencyCriticalMs.toDouble(),
      ),

      // Transcription latency alerts
      AlertRule(
        id: 'transcription_latency_warning',
        name: 'Transcription Latency Warning',
        description: 'Transcription latency exceeds warning threshold',
        type: AlertType.performanceLatency,
        severity: AlertSeverity.warning,
        condition: 'transcription_latency_ms > threshold',
        threshold: ObservabilityConfig.instance.thresholds.transcriptionLatencyWarningMs.toDouble(),
      ),

      // Memory usage alerts
      AlertRule(
        id: 'memory_usage_warning',
        name: 'Memory Usage Warning',
        description: 'Application memory usage is high',
        type: AlertType.performanceMemory,
        severity: AlertSeverity.warning,
        condition: 'memory_usage_mb > threshold',
        threshold: ObservabilityConfig.instance.thresholds.memoryUsageWarningMB.toDouble(),
      ),
      AlertRule(
        id: 'memory_usage_critical',
        name: 'Memory Usage Critical',
        description: 'Application memory usage is critically high',
        type: AlertType.performanceMemory,
        severity: AlertSeverity.critical,
        condition: 'memory_usage_mb > threshold',
        threshold: ObservabilityConfig.instance.thresholds.memoryUsageCriticalMB.toDouble(),
      ),

      // Error rate alerts
      AlertRule(
        id: 'error_rate_warning',
        name: 'Error Rate Warning',
        description: 'Overall error rate is elevated',
        type: AlertType.errorRate,
        severity: AlertSeverity.warning,
        condition: 'error_rate_percent > threshold',
        threshold: ObservabilityConfig.instance.thresholds.errorRateWarning,
        evaluationWindow: const Duration(minutes: 15),
      ),
      AlertRule(
        id: 'error_rate_critical',
        name: 'Error Rate Critical',
        description: 'Overall error rate is critically high',
        type: AlertType.errorRate,
        severity: AlertSeverity.critical,
        condition: 'error_rate_percent > threshold',
        threshold: ObservabilityConfig.instance.thresholds.errorRateCritical,
        evaluationWindow: const Duration(minutes: 15),
      ),

      // BLE error rate alerts
      AlertRule(
        id: 'ble_error_rate_warning',
        name: 'BLE Error Rate Warning',
        description: 'BLE connection error rate is elevated',
        type: AlertType.bleErrorRate,
        severity: AlertSeverity.warning,
        condition: 'ble_error_rate_percent > threshold',
        threshold: ObservabilityConfig.instance.thresholds.bleErrorRateWarning,
      ),
      AlertRule(
        id: 'ble_error_rate_critical',
        name: 'BLE Error Rate Critical',
        description: 'BLE connection error rate is critically high',
        type: AlertType.bleErrorRate,
        severity: AlertSeverity.critical,
        condition: 'ble_error_rate_percent > threshold',
        threshold: ObservabilityConfig.instance.thresholds.bleErrorRateCritical,
      ),

      // API quota alerts
      AlertRule(
        id: 'api_quota_warning',
        name: 'API Quota Warning',
        description: 'API quota usage approaching limit',
        type: AlertType.apiQuotaWarning,
        severity: AlertSeverity.warning,
        condition: 'api_quota_percent > threshold',
        threshold: ObservabilityConfig.instance.thresholds.apiQuotaWarning,
        evaluationWindow: const Duration(hours: 1),
      ),
      AlertRule(
        id: 'api_quota_critical',
        name: 'API Quota Critical',
        description: 'API quota usage critically high',
        type: AlertType.apiQuotaWarning,
        severity: AlertSeverity.critical,
        condition: 'api_quota_percent > threshold',
        threshold: ObservabilityConfig.instance.thresholds.apiQuotaCritical,
        evaluationWindow: const Duration(hours: 1),
      ),

      // SLO violation alerts
      AlertRule(
        id: 'slo_violation_availability',
        name: 'SLO Violation - Availability',
        description: 'Service availability below SLO target',
        type: AlertType.sloViolation,
        severity: AlertSeverity.critical,
        condition: 'availability_percent < threshold',
        threshold: 99.0,
        evaluationWindow: const Duration(hours: 1),
      ),

      // Storage alerts
      AlertRule(
        id: 'storage_warning',
        name: 'Storage Warning',
        description: 'Local storage usage is high',
        type: AlertType.storageWarning,
        severity: AlertSeverity.warning,
        condition: 'storage_usage_mb > threshold',
        threshold: ObservabilityConfig.instance.thresholds.storageWarningMB.toDouble(),
      ),
    ]);
  }

  /// Evaluate metric against alert rules
  void evaluateMetric({
    required String metricName,
    required double value,
    Map<String, dynamic>? context,
  }) {
    if (!ObservabilityConfig.instance.alertsEnabled) return;

    // Buffer the metric for time-window evaluations
    _bufferMetric(metricName, value);

    // Find applicable rules
    final applicableRules = _rules.where((rule) {
      return rule.enabled && _isRuleApplicable(rule, metricName);
    });

    for (final rule in applicableRules) {
      _evaluateRule(rule, metricName, value, context ?? {});
    }
  }

  /// Buffer metric for time-window analysis
  void _bufferMetric(String metricName, double value) {
    if (!_metricBuffer.containsKey(metricName)) {
      _metricBuffer[metricName] = [];
    }

    _metricBuffer[metricName]!.add(value);

    // Keep only recent values (last 1000 data points)
    if (_metricBuffer[metricName]!.length > 1000) {
      _metricBuffer[metricName]!.removeAt(0);
    }
  }

  /// Check if rule is applicable to metric
  bool _isRuleApplicable(AlertRule rule, String metricName) {
    final condition = rule.condition.toLowerCase();
    final metric = metricName.toLowerCase();
    return condition.contains(metric.replaceAll('_', ' '));
  }

  /// Evaluate specific rule
  void _evaluateRule(
    AlertRule rule,
    String metricName,
    double value,
    Map<String, dynamic> context,
  ) {
    bool shouldFire = false;

    // Simple threshold-based evaluation
    if (rule.condition.contains('>')) {
      shouldFire = value > rule.threshold;
    } else if (rule.condition.contains('<')) {
      shouldFire = value < rule.threshold;
    }

    if (shouldFire) {
      // Check if alert is already active
      final existingAlert = _activeAlerts.firstWhere(
        (a) => a.rule.id == rule.id,
        orElse: () => Alert(
          id: '',
          rule: rule,
          triggeredAt: DateTime.now(),
          context: {},
        ),
      );

      if (existingAlert.id.isEmpty) {
        // Fire new alert
        _fireAlert(rule, metricName, value, context);
      }
    } else {
      // Check if we should resolve any active alerts
      _resolveAlerts(rule);
    }
  }

  /// Fire a new alert
  void _fireAlert(
    AlertRule rule,
    String metricName,
    double value,
    Map<String, dynamic> context,
  ) {
    final alert = Alert(
      id: '${rule.id}_${DateTime.now().millisecondsSinceEpoch}',
      rule: rule,
      triggeredAt: DateTime.now(),
      context: {
        'metric': metricName,
        'value': value,
        'threshold': rule.threshold,
        ...context,
      },
    );

    _activeAlerts.add(alert);
    _alertHistory.add(alert);

    _notifyAlert(alert);

    LoggingService.instance.log(
      'AlertManager',
      'Alert fired: ${rule.name}',
      rule.severity == AlertSeverity.critical ? LogLevel.error : LogLevel.warning,
      alert.toJson(),
    );
  }

  /// Resolve alerts for a rule
  void _resolveAlerts(AlertRule rule) {
    final alertsToResolve = _activeAlerts
        .where((a) => a.rule.id == rule.id && a.status == AlertStatus.active)
        .toList();

    for (final alert in alertsToResolve) {
      alert.status = AlertStatus.resolved;
      alert.resolvedAt = DateTime.now();
      _activeAlerts.remove(alert);

      LoggingService.instance.info(
        'AlertManager',
        'Alert resolved: ${rule.name} (duration: ${alert.duration.inSeconds}s)',
      );
    }
  }

  /// Send alert notifications
  void _notifyAlert(Alert alert) {
    for (final channel in alert.rule.notificationChannels) {
      switch (channel) {
        case 'console':
          _notifyConsole(alert);
          break;
        case 'analytics':
          _notifyAnalytics(alert);
          break;
        // Add more notification channels as needed
        default:
          break;
      }
    }
  }

  /// Console notification
  void _notifyConsole(Alert alert) {
    final severity = alert.rule.severity;
    final icon = severity == AlertSeverity.critical ? '🚨'
                : severity == AlertSeverity.warning ? '⚠️'
                : 'ℹ️';

    if (kDebugMode) {
      print('\n$icon ALERT [${severity.name.toUpperCase()}]: ${alert.rule.name}');
      print('   Description: ${alert.rule.description}');
      print('   Metric: ${alert.context['metric']} = ${alert.context['value']}');
      print('   Threshold: ${alert.rule.threshold}');
      print('   Time: ${alert.triggeredAt.toIso8601String()}\n');
    }
  }

  /// Analytics notification
  void _notifyAnalytics(Alert alert) {
    // This would integrate with AnalyticsService
    // For now, just log to analytics stream
    LoggingService.instance.log(
      'Analytics',
      'Alert triggered',
      LogLevel.warning,
      {
        'alert_id': alert.id,
        'alert_name': alert.rule.name,
        'severity': alert.rule.severity.name,
        'type': alert.rule.type.name,
        'context': alert.context,
      },
    );
  }

  /// Add custom alert rule
  void addRule(AlertRule rule) {
    _rules.add(rule);
    LoggingService.instance.info('AlertManager', 'Added alert rule: ${rule.name}');
  }

  /// Remove alert rule
  void removeRule(String ruleId) {
    _rules.removeWhere((r) => r.id == ruleId);
    LoggingService.instance.info('AlertManager', 'Removed alert rule: $ruleId');
  }

  /// Get all active alerts
  List<Alert> getActiveAlerts({AlertSeverity? severity}) {
    if (severity == null) {
      return List.unmodifiable(_activeAlerts);
    }
    return _activeAlerts.where((a) => a.rule.severity == severity).toList();
  }

  /// Get alert history
  List<Alert> getAlertHistory({
    Duration? timeWindow,
    AlertSeverity? severity,
    AlertType? type,
  }) {
    var filtered = _alertHistory.toList();

    if (timeWindow != null) {
      final cutoff = DateTime.now().subtract(timeWindow);
      filtered = filtered.where((a) => a.triggeredAt.isAfter(cutoff)).toList();
    }

    if (severity != null) {
      filtered = filtered.where((a) => a.rule.severity == severity).toList();
    }

    if (type != null) {
      filtered = filtered.where((a) => a.rule.type == type).toList();
    }

    return filtered;
  }

  /// Get alert statistics
  Map<String, dynamic> getStatistics({Duration? timeWindow}) {
    final window = timeWindow ?? const Duration(hours: 24);
    final cutoff = DateTime.now().subtract(window);
    final recentAlerts = _alertHistory
        .where((a) => a.triggeredAt.isAfter(cutoff))
        .toList();

    final bySeverity = <String, int>{};
    final byType = <String, int>{};
    final byStatus = <String, int>{};

    for (final alert in recentAlerts) {
      bySeverity[alert.rule.severity.name] =
          (bySeverity[alert.rule.severity.name] ?? 0) + 1;
      byType[alert.rule.type.name] =
          (byType[alert.rule.type.name] ?? 0) + 1;
      byStatus[alert.status.name] =
          (byStatus[alert.status.name] ?? 0) + 1;
    }

    return {
      'timeWindow': '${window.inHours}h',
      'totalAlerts': recentAlerts.length,
      'activeAlerts': _activeAlerts.length,
      'bySeverity': bySeverity,
      'byType': byType,
      'byStatus': byStatus,
      'meanTimeToResolve': _calculateMeanTimeToResolve(recentAlerts),
    };
  }

  /// Calculate mean time to resolve
  String _calculateMeanTimeToResolve(List<Alert> alerts) {
    final resolved = alerts.where((a) => a.status == AlertStatus.resolved);
    if (resolved.isEmpty) return 'N/A';

    final totalSeconds = resolved.fold<int>(
      0,
      (sum, a) => sum + a.duration.inSeconds,
    );
    final avgSeconds = totalSeconds / resolved.length;

    return '${avgSeconds.toStringAsFixed(1)}s';
  }

  /// Export alerts as JSON
  String exportAlertsJSON({Duration? timeWindow}) {
    final alerts = getAlertHistory(timeWindow: timeWindow);
    return jsonEncode({
      'exportTime': DateTime.now().toIso8601String(),
      'timeWindow': timeWindow?.inHours ?? 'all',
      'alertCount': alerts.length,
      'alerts': alerts.map((a) => a.toJson()).toList(),
      'statistics': getStatistics(timeWindow: timeWindow),
    });
  }

  /// Clear alert history
  void clearHistory() {
    _alertHistory.clear();
    LoggingService.instance.info('AlertManager', 'Alert history cleared');
  }
}
