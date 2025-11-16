// ABOUTME: Central observability configuration for monitoring, alerting, and metrics
// ABOUTME: Defines thresholds, alert rules, and SLO/SLA targets

import 'package:flutter/foundation.dart';

/// Alert severity levels
enum AlertSeverity {
  info,     // Informational - no action required
  warning,  // Warning - investigate soon
  critical, // Critical - immediate action required
  emergency // Emergency - system failure
}

/// Alert types for different system aspects
enum AlertType {
  // Performance alerts
  performanceLatency,
  performanceMemory,
  performanceCpu,
  performanceBattery,

  // Error rate alerts
  errorRate,
  apiErrorRate,
  bleErrorRate,
  transcriptionErrorRate,

  // Usage anomaly alerts
  unusualUsagePattern,
  apiQuotaWarning,
  storageWarning,

  // SLO violations
  sloViolation,
  availabilityDrop,

  // Security alerts
  securityAnomaly,
  permissionDenied,
}

/// Observability configuration class
class ObservabilityConfig {
  // Singleton pattern
  static final ObservabilityConfig _instance = ObservabilityConfig._();
  static ObservabilityConfig get instance => _instance;

  ObservabilityConfig._();

  /// Enable/disable observability features
  bool isEnabled = true;
  bool alertsEnabled = true;
  bool anomalyDetectionEnabled = true;
  bool performanceMonitoringEnabled = true;

  /// Environment-specific settings
  String environment = kDebugMode ? 'development' : 'production';

  /// Alert thresholds configuration
  final AlertThresholds thresholds = AlertThresholds();

  /// SLO/SLA targets
  final SLOTargets sloTargets = SLOTargets();

  /// Anomaly detection parameters
  final AnomalyDetectionConfig anomalyConfig = AnomalyDetectionConfig();

  /// Performance monitoring config
  final PerformanceMonitoringConfig perfConfig = PerformanceMonitoringConfig();
}

/// Alert threshold definitions
class AlertThresholds {
  // Performance thresholds
  final int audioLatencyWarningMs = 100;
  final int audioLatencyCriticalMs = 200;

  final int transcriptionLatencyWarningMs = 500;
  final int transcriptionLatencyCriticalMs = 1000;

  final int aiAnalysisLatencyWarningMs = 3000;
  final int aiAnalysisLatencyCriticalMs = 5000;

  final int memoryUsageWarningMB = 200;
  final int memoryUsageCriticalMB = 400;

  final double cpuUsageWarningPercent = 70.0;
  final double cpuUsageCriticalPercent = 90.0;

  // Error rate thresholds (percentage)
  final double errorRateWarning = 5.0;  // 5% error rate
  final double errorRateCritical = 10.0; // 10% error rate

  final double bleErrorRateWarning = 10.0;  // 10% BLE error rate
  final double bleErrorRateCritical = 25.0; // 25% BLE error rate

  // API quota thresholds (percentage of daily quota)
  final double apiQuotaWarning = 80.0;  // 80% used
  final double apiQuotaCritical = 95.0; // 95% used

  // Storage thresholds
  final int storageWarningMB = 100;
  final int storageCriticalMB = 200;

  // Response time thresholds (percentile-based)
  final int p95ResponseTimeWarningMs = 1000;
  final int p95ResponseTimeCriticalMs = 2000;

  final int p99ResponseTimeWarningMs = 2000;
  final int p99ResponseTimeCriticalMs = 3000;

  // Availability thresholds
  final double availabilityWarningPercent = 99.0;  // Below 99%
  final double availabilityCriticalPercent = 95.0; // Below 95%

  /// Get threshold for specific metric
  Map<String, dynamic> getThreshold(AlertType type) {
    switch (type) {
      case AlertType.performanceLatency:
        return {
          'warning': audioLatencyWarningMs,
          'critical': audioLatencyCriticalMs,
          'unit': 'ms',
        };
      case AlertType.performanceMemory:
        return {
          'warning': memoryUsageWarningMB,
          'critical': memoryUsageCriticalMB,
          'unit': 'MB',
        };
      case AlertType.errorRate:
        return {
          'warning': errorRateWarning,
          'critical': errorRateCritical,
          'unit': '%',
        };
      case AlertType.bleErrorRate:
        return {
          'warning': bleErrorRateWarning,
          'critical': bleErrorRateCritical,
          'unit': '%',
        };
      case AlertType.apiQuotaWarning:
        return {
          'warning': apiQuotaWarning,
          'critical': apiQuotaCritical,
          'unit': '%',
        };
      default:
        return {'warning': 0, 'critical': 0, 'unit': ''};
    }
  }
}

/// SLO/SLA target definitions
class SLOTargets {
  // Service Level Objectives (SLOs)

  // Availability targets (percentage)
  final double audioRecordingAvailability = 99.9;    // 99.9% uptime
  final double transcriptionAvailability = 99.5;     // 99.5% uptime
  final double aiAnalysisAvailability = 99.0;        // 99% uptime
  final double bleConnectionAvailability = 98.0;     // 98% uptime

  // Latency targets (milliseconds)
  final int audioLatencyP50 = 50;   // 50ms at 50th percentile
  final int audioLatencyP95 = 100;  // 100ms at 95th percentile
  final int audioLatencyP99 = 150;  // 150ms at 99th percentile

  final int transcriptionLatencyP50 = 300;   // 300ms at 50th percentile
  final int transcriptionLatencyP95 = 500;   // 500ms at 95th percentile
  final int transcriptionLatencyP99 = 1000;  // 1s at 99th percentile

  final int aiAnalysisLatencyP50 = 2000;  // 2s at 50th percentile
  final int aiAnalysisLatencyP95 = 3000;  // 3s at 95th percentile
  final int aiAnalysisLatencyP99 = 5000;  // 5s at 99th percentile

  // Error budget (allowed error rate per time window)
  final double monthlyErrorBudget = 0.1;  // 0.1% error budget per month
  final double dailyErrorBudget = 0.5;    // 0.5% error budget per day

  // Success rate targets
  final double audioRecordingSuccessRate = 99.9;
  final double transcriptionSuccessRate = 99.0;
  final double aiAnalysisSuccessRate = 98.0;
  final double bleTransactionSuccessRate = 95.0;

  // Performance targets
  final int appLaunchTimeMs = 3000;        // 3 seconds cold start
  final double uiFrameRate = 30.0;         // 30 fps minimum
  final int memoryUsageLimitMB = 200;      // 200MB max memory

  /// Check if metric meets SLO
  bool meetsAvailabilitySLO(String service, double actualAvailability) {
    final target = _getAvailabilityTarget(service);
    return actualAvailability >= target;
  }

  /// Check if latency meets SLO
  bool meetsLatencySLO(String service, int actualLatencyMs, {String percentile = 'p95'}) {
    final target = _getLatencyTarget(service, percentile);
    return actualLatencyMs <= target;
  }

  double _getAvailabilityTarget(String service) {
    switch (service.toLowerCase()) {
      case 'audio':
      case 'recording':
        return audioRecordingAvailability;
      case 'transcription':
        return transcriptionAvailability;
      case 'ai':
      case 'analysis':
        return aiAnalysisAvailability;
      case 'ble':
      case 'bluetooth':
        return bleConnectionAvailability;
      default:
        return 99.0;
    }
  }

  int _getLatencyTarget(String service, String percentile) {
    switch (service.toLowerCase()) {
      case 'audio':
      case 'recording':
        return percentile == 'p50' ? audioLatencyP50
             : percentile == 'p95' ? audioLatencyP95
             : audioLatencyP99;
      case 'transcription':
        return percentile == 'p50' ? transcriptionLatencyP50
             : percentile == 'p95' ? transcriptionLatencyP95
             : transcriptionLatencyP99;
      case 'ai':
      case 'analysis':
        return percentile == 'p50' ? aiAnalysisLatencyP50
             : percentile == 'p95' ? aiAnalysisLatencyP95
             : aiAnalysisLatencyP99;
      default:
        return 1000;
    }
  }
}

/// Anomaly detection configuration
class AnomalyDetectionConfig {
  // Time windows for anomaly detection
  final Duration shortTermWindow = const Duration(minutes: 5);
  final Duration mediumTermWindow = const Duration(hours: 1);
  final Duration longTermWindow = const Duration(hours: 24);

  // Statistical thresholds
  final double standardDeviationThreshold = 2.0;  // 2 sigma
  final double percentileThreshold = 95.0;        // 95th percentile

  // Rate of change thresholds
  final double suddenSpikeThreshold = 2.0;  // 2x normal rate
  final double gradualIncreaseThreshold = 1.5;  // 1.5x normal rate

  // Pattern detection
  final int minimumDataPoints = 10;  // Minimum data points for pattern
  final double confidenceThreshold = 0.8;  // 80% confidence

  // Anomaly types to detect
  final bool detectLatencyAnomalies = true;
  final bool detectErrorRateAnomalies = true;
  final bool detectUsageAnomalies = true;
  final bool detectMemoryAnomalies = true;
  final bool detectApiQuotaAnomalies = true;
}

/// Performance monitoring configuration
class PerformanceMonitoringConfig {
  // Monitoring intervals
  final Duration metricsCollectionInterval = const Duration(seconds: 30);
  final Duration healthCheckInterval = const Duration(minutes: 5);
  final Duration performanceReportInterval = const Duration(hours: 1);

  // Data retention
  final Duration metricsRetentionPeriod = const Duration(days: 7);
  final Duration detailedMetricsRetentionPeriod = const Duration(hours: 24);

  // Sampling rates
  final double productionSamplingRate = 0.1;  // 10% sampling in production
  final double developmentSamplingRate = 1.0; // 100% sampling in dev

  // Performance metrics to track
  final bool trackCpuUsage = true;
  final bool trackMemoryUsage = true;
  final bool trackNetworkUsage = true;
  final bool trackBatteryUsage = true;
  final bool trackDiskUsage = true;
  final bool trackFrameRate = true;

  // Auto-scaling triggers (for recommendations)
  final double scaleUpCpuThreshold = 80.0;      // 80% CPU
  final double scaleUpMemoryThreshold = 80.0;   // 80% memory
  final double scaleDownCpuThreshold = 30.0;    // 30% CPU
  final double scaleDownMemoryThreshold = 30.0; // 30% memory

  /// Get current sampling rate based on environment
  double get currentSamplingRate {
    return kDebugMode ? developmentSamplingRate : productionSamplingRate;
  }
}

/// Alert rule definition
class AlertRule {
  final String id;
  final String name;
  final String description;
  final AlertType type;
  final AlertSeverity severity;
  final String condition;
  final double threshold;
  final Duration evaluationWindow;
  final bool enabled;
  final List<String> notificationChannels;

  const AlertRule({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.severity,
    required this.condition,
    required this.threshold,
    this.evaluationWindow = const Duration(minutes: 5),
    this.enabled = true,
    this.notificationChannels = const ['console', 'analytics'],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'severity': severity.name,
    'condition': condition,
    'threshold': threshold,
    'evaluationWindow': evaluationWindow.inSeconds,
    'enabled': enabled,
    'notificationChannels': notificationChannels,
  };
}
