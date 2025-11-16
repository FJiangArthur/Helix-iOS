# Observability Quick Start Guide

This guide will help you quickly integrate observability into your Helix application.

## Table of Contents
1. [5-Minute Setup](#5-minute-setup)
2. [Basic Integration](#basic-integration)
3. [Common Use Cases](#common-use-cases)
4. [Viewing Metrics](#viewing-metrics)
5. [Troubleshooting](#troubleshooting)

## 5-Minute Setup

### Step 1: Initialize (1 minute)

Add to your `lib/main.dart`:

```dart
import 'package:flutter_helix/core/observability/alert_manager.dart';
import 'package:flutter_helix/core/observability/performance_monitor.dart';
import 'package:flutter_helix/core/observability/slo_monitor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize observability
  AlertManager.instance.initialize();
  PerformanceMonitor.instance.startMonitoring();
  SLOMonitor.instance.startMonitoring();

  runApp(const MyApp());
}
```

### Step 2: Add Service Instrumentation (2 minutes)

Wrap your critical operations:

```dart
// Example: Audio Recording
Future<void> startRecording() async {
  final startTime = DateTime.now();

  try {
    await _doRecording();

    // Record success
    SLOMonitor.instance.recordOperation(
      serviceName: 'audio',
      success: true,
      latencyMs: DateTime.now().difference(startTime).inMilliseconds,
    );
  } catch (e) {
    // Record failure
    SLOMonitor.instance.recordOperation(
      serviceName: 'audio',
      success: false,
      latencyMs: DateTime.now().difference(startTime).inMilliseconds,
    );
    rethrow;
  }
}
```

### Step 3: Add Metric Tracking (2 minutes)

Track important metrics:

```dart
import 'package:flutter_helix/core/observability/alert_manager.dart';
import 'package:flutter_helix/core/observability/anomaly_detector.dart';

// Track memory usage
void trackMemory(int memoryMB) {
  AnomalyDetector.instance.recordMetric(
    metricName: 'memory_usage_mb',
    value: memoryMB.toDouble(),
  );

  AlertManager.instance.evaluateMetric(
    metricName: 'memory_usage_mb',
    value: memoryMB.toDouble(),
  );
}

// Track latency
void trackLatency(String operation, Duration latency) {
  final metricName = '${operation}_latency_ms';

  AnomalyDetector.instance.recordMetric(
    metricName: metricName,
    value: latency.inMilliseconds.toDouble(),
  );

  AlertManager.instance.evaluateMetric(
    metricName: metricName,
    value: latency.inMilliseconds.toDouble(),
  );
}
```

Done! You now have:
- ✅ Automated alerting
- ✅ Performance monitoring
- ✅ Anomaly detection
- ✅ SLO tracking

## Basic Integration

### Service Instrumentation Pattern

Use this pattern for all services:

```dart
class MyService {
  Future<T> performOperation<T>({
    required String serviceName,
    required Future<T> Function() operation,
    Map<String, dynamic>? context,
  }) async {
    final startTime = DateTime.now();
    final operationId = DateTime.now().millisecondsSinceEpoch.toString();

    // Track start
    AnalyticsService.instance.track(
      AnalyticsEvent.performanceMetric,
      properties: {
        'service': serviceName,
        'operation_id': operationId,
        'status': 'started',
      },
    );

    try {
      // Execute operation
      final result = await operation();

      // Calculate latency
      final latency = DateTime.now().difference(startTime);

      // Record success
      _recordSuccess(serviceName, latency, context);

      return result;
    } catch (e, stackTrace) {
      // Calculate latency
      final latency = DateTime.now().difference(startTime);

      // Record failure
      _recordFailure(serviceName, latency, e, context);

      rethrow;
    }
  }

  void _recordSuccess(
    String serviceName,
    Duration latency,
    Map<String, dynamic>? context,
  ) {
    // Record for SLO tracking
    SLOMonitor.instance.recordOperation(
      serviceName: serviceName,
      success: true,
      latencyMs: latency.inMilliseconds,
    );

    // Track latency
    final metricName = '${serviceName}_latency_ms';
    AnomalyDetector.instance.recordMetric(
      metricName: metricName,
      value: latency.inMilliseconds.toDouble(),
    );

    AlertManager.instance.evaluateMetric(
      metricName: metricName,
      value: latency.inMilliseconds.toDouble(),
      context: context,
    );

    // Log
    LoggingService.instance.debug(
      serviceName,
      'Operation completed',
      {'latency_ms': latency.inMilliseconds, ...?context},
    );
  }

  void _recordFailure(
    String serviceName,
    Duration latency,
    Object error,
    Map<String, dynamic>? context,
  ) {
    // Record for SLO tracking
    SLOMonitor.instance.recordOperation(
      serviceName: serviceName,
      success: false,
      latencyMs: latency.inMilliseconds,
    );

    // Fire alert
    AlertManager.instance.evaluateMetric(
      metricName: 'error_rate_percent',
      value: 100.0,
      context: {
        'service': serviceName,
        'error': error.toString(),
        ...?context,
      },
    );

    // Log error
    LoggingService.instance.error(
      serviceName,
      'Operation failed',
      error,
    );
  }
}
```

### Usage Example

```dart
class AudioService extends MyService {
  Future<void> startRecording() async {
    return performOperation(
      serviceName: 'audio',
      operation: () async {
        // Your recording logic here
        await _actuallyStartRecording();
      },
      context: {'sample_rate': 16000},
    );
  }

  Future<String> transcribe(File audioFile) async {
    return performOperation(
      serviceName: 'transcription',
      operation: () async {
        // Your transcription logic here
        return await _actuallyTranscribe(audioFile);
      },
      context: {'file_size': audioFile.lengthSync()},
    );
  }
}
```

## Common Use Cases

### 1. Track API Calls

```dart
Future<T> apiCall<T>(Future<T> Function() call) async {
  final startTime = DateTime.now();

  try {
    final result = await call();

    // Track success
    AnalyticsService.instance.trackPerformance(
      metric: 'api_call_success',
      value: DateTime.now().difference(startTime).inMilliseconds.toDouble(),
    );

    return result;
  } catch (e) {
    // Track failure
    AnalyticsService.instance.trackAPIError(
      api: 'unknown',
      statusCode: 500,
      error: e.toString(),
    );

    // Evaluate error rate
    AlertManager.instance.evaluateMetric(
      metricName: 'api_error_rate_percent',
      value: 100.0,
    );

    rethrow;
  }
}
```

### 2. Monitor Memory Usage

```dart
import 'dart:io';

void monitorMemory() {
  Timer.periodic(Duration(seconds: 30), (_) async {
    // Get memory info (simplified - use proper method for iOS)
    final memoryMB = _getCurrentMemoryUsage();

    // Track metric
    AnomalyDetector.instance.recordMetric(
      metricName: 'memory_usage_mb',
      value: memoryMB.toDouble(),
    );

    AlertManager.instance.evaluateMetric(
      metricName: 'memory_usage_mb',
      value: memoryMB.toDouble(),
    );
  });
}
```

### 3. Track User Actions

```dart
void trackUserAction(String action, {Map<String, dynamic>? properties}) {
  // Track in analytics
  AnalyticsService.instance.track(
    AnalyticsEvent.screenViewed,
    properties: {
      'action': action,
      ...?properties,
    },
  );

  // Check for unusual patterns
  AnomalyDetector.instance.recordMetric(
    metricName: 'user_actions_per_minute',
    value: _calculateActionsPerMinute(),
  );
}
```

### 4. Monitor BLE Connection Health

```dart
void trackBLETransaction({
  required bool success,
  required Duration latency,
  String? error,
}) {
  // Update BLE metrics
  SLOMonitor.instance.recordOperation(
    serviceName: 'ble',
    success: success,
    latencyMs: latency.inMilliseconds,
  );

  // Track error rate
  if (!success) {
    AlertManager.instance.evaluateMetric(
      metricName: 'ble_error_rate_percent',
      value: _calculateBLEErrorRate(),
      context: {'error': error},
    );
  }
}
```

### 5. Detect Performance Degradation

```dart
void checkPerformanceHealth() {
  Timer.periodic(Duration(minutes: 5), (_) {
    // Get recommendations
    final recommendations = PerformanceMonitor.instance.getRecommendations(
      severity: AlertSeverity.warning,
    );

    for (final rec in recommendations) {
      LoggingService.instance.warning(
        'Performance',
        '${rec.action.name} recommended for ${rec.resource}',
        rec.toJson(),
      );

      // Could show user notification for critical issues
      if (rec.severity == AlertSeverity.critical) {
        _showPerformanceWarning(rec);
      }
    }
  });
}
```

## Viewing Metrics

### Console Output

All alerts and anomalies are logged to console in debug mode:

```
🚨 ALERT [CRITICAL]: Memory Usage Critical
   Description: Application memory usage is critically high
   Metric: memory_usage_mb = 450
   Threshold: 400
   Time: 2025-11-16T10:30:00.000Z
```

### Generate Reports

```dart
// Get comprehensive report
void printObservabilityReport() {
  print('\n=== OBSERVABILITY REPORT ===\n');

  // Alerts
  print('Alerts (24h):');
  final alertStats = AlertManager.instance.getStatistics(
    timeWindow: Duration(hours: 24),
  );
  print(JsonEncoder.withIndent('  ').convert(alertStats));

  // Anomalies
  print('\nAnomalies (24h):');
  final anomalyReport = AnomalyDetector.instance.generateReport(
    timeWindow: Duration(hours: 24),
  );
  print(JsonEncoder.withIndent('  ').convert(anomalyReport));

  // Performance
  print('\nPerformance (1h):');
  final perfReport = PerformanceMonitor.instance.generateReport(
    timeWindow: Duration(hours: 1),
  );
  print(JsonEncoder.withIndent('  ').convert(perfReport));

  // SLO Compliance
  print('\nSLO Compliance (24h):');
  final sloReport = SLOMonitor.instance.generateReport(
    window: SLOWindow.rolling24h,
  );
  print(JsonEncoder.withIndent('  ').convert(sloReport));
}
```

### Export Data

```dart
// Export to JSON file
Future<void> exportMetrics() async {
  final report = {
    'timestamp': DateTime.now().toIso8601String(),
    'alerts': AlertManager.instance.exportAlertsJSON(
      timeWindow: Duration(hours: 24),
    ),
    'anomalies': AnomalyDetector.instance.generateReport(
      timeWindow: Duration(hours: 24),
    ),
    'performance': PerformanceMonitor.instance.generateReport(
      timeWindow: Duration(hours: 1),
    ),
    'slo': SLOMonitor.instance.generateReport(
      window: SLOWindow.rolling24h,
    ),
  };

  final json = JsonEncoder.withIndent('  ').convert(report);

  // Save to file
  final file = File('observability_report_${DateTime.now().millisecondsSinceEpoch}.json');
  await file.writeAsString(json);

  print('Report saved to: ${file.path}');
}
```

### Build a Simple Dashboard

```dart
class ObservabilityDashboard extends StatefulWidget {
  @override
  _ObservabilityDashboardState createState() => _ObservabilityDashboardState();
}

class _ObservabilityDashboardState extends State<ObservabilityDashboard> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(Duration(seconds: 5), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = AlertManager.instance.getActiveAlerts();
    final perfRecommendations = PerformanceMonitor.instance.getRecommendations();

    return Scaffold(
      appBar: AppBar(title: Text('Observability Dashboard')),
      body: ListView(
        children: [
          // Active Alerts
          Card(
            child: ListTile(
              title: Text('Active Alerts'),
              subtitle: Text('${activeAlerts.length} active'),
              trailing: Icon(
                activeAlerts.isEmpty ? Icons.check_circle : Icons.warning,
                color: activeAlerts.isEmpty ? Colors.green : Colors.orange,
              ),
            ),
          ),

          // Performance Recommendations
          Card(
            child: ListTile(
              title: Text('Performance Recommendations'),
              subtitle: Text('${perfRecommendations.length} suggestions'),
            ),
          ),

          // SLO Compliance
          ...['audio', 'transcription', 'ai', 'ble'].map((service) {
            final status = SLOMonitor.instance.getComplianceStatus(
              serviceName: service,
              window: SLOWindow.rolling24h,
            );

            return Card(
              child: ListTile(
                title: Text('$service SLO'),
                subtitle: Text(
                  'Health: ${status.healthStatus.name}, '
                  'Error Budget: ${status.errorBudgetRemaining.toStringAsFixed(1)}%',
                ),
                trailing: Icon(
                  status.meetsAllSLOs ? Icons.check_circle : Icons.error,
                  color: status.meetsAllSLOs ? Colors.green : Colors.red,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
```

## Troubleshooting

### No Metrics Showing

**Problem**: Dashboard shows no data

**Solutions**:
1. Verify initialization in `main.dart`
2. Check that operations are being instrumented
3. Ensure monitoring is started: `PerformanceMonitor.instance.isMonitoring`
4. Wait a few minutes for data to accumulate

### Too Many Alerts

**Problem**: Alert spam in console

**Solutions**:
1. Increase thresholds in `ObservabilityConfig`
2. Disable alerts: `ObservabilityConfig.instance.alertsEnabled = false`
3. Filter by severity: Only show critical alerts
4. Adjust evaluation windows

### High Memory Usage from Observability

**Problem**: Observability consuming too much memory

**Solutions**:
1. Clear history: `PerformanceMonitor.instance.clearHistory()`
2. Reduce sampling rate: `perfConfig.productionSamplingRate = 0.05`
3. Increase collection interval: `perfConfig.metricsCollectionInterval`
4. Limit time series data retention

### False Anomalies

**Problem**: Anomalies detected that aren't real issues

**Solutions**:
1. Increase confidence threshold: `anomalyConfig.confidenceThreshold = 0.9`
2. Increase minimum data points: `anomalyConfig.minimumDataPoints = 20`
3. Tune statistical threshold: `anomalyConfig.standardDeviationThreshold = 3.0`
4. Wait for more baseline data

## Next Steps

1. **Customize Thresholds**: Adjust `ObservabilityConfig` for your app
2. **Add Custom Metrics**: Track app-specific metrics
3. **Build Dashboard**: Create visualization UI
4. **Set Up Notifications**: Integrate Slack/email alerts
5. **Review Regularly**: Check reports weekly

## Need Help?

- Read [Full Documentation](./OBSERVABILITY_STRATEGY.md)
- Check [Example Configurations](../config/observability/)
- Review [SLA Documentation](./SLA.md)
- Examine code in `lib/core/observability/`

## Quick Reference

```dart
// Initialize
AlertManager.instance.initialize();
PerformanceMonitor.instance.startMonitoring();
SLOMonitor.instance.startMonitoring();

// Track metrics
AnomalyDetector.instance.recordMetric(metricName: 'name', value: 100);
AlertManager.instance.evaluateMetric(metricName: 'name', value: 100);
SLOMonitor.instance.recordOperation(serviceName: 'service', success: true, latencyMs: 50);

// Get status
final alerts = AlertManager.instance.getActiveAlerts();
final recommendations = PerformanceMonitor.instance.getRecommendations();
final sloStatus = SLOMonitor.instance.getComplianceStatus(serviceName: 'audio');

// Generate reports
final alertStats = AlertManager.instance.getStatistics();
final perfReport = PerformanceMonitor.instance.generateReport();
final sloReport = SLOMonitor.instance.generateReport();
```
