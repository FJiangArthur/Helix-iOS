// ABOUTME: Example integration of observability system
// ABOUTME: Demonstrates best practices for instrumenting services

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'alert_manager.dart';
import 'anomaly_detector.dart';
import 'performance_monitor.dart';
import 'slo_monitor.dart';
import 'observability_config.dart';
import '../utils/logging_service.dart';
import '../../services/analytics_service.dart';

/// Example: Complete service instrumentation
class ObservableService {
  final String serviceName;

  ObservableService(this.serviceName);

  /// Wrap any operation with full observability
  Future<T> performOperation<T>({
    required Future<T> Function() operation,
    String? operationName,
    Map<String, dynamic>? context,
  }) async {
    final opName = operationName ?? 'operation';
    final startTime = DateTime.now();
    final operationId = '${serviceName}_${startTime.millisecondsSinceEpoch}';

    // Log start
    LoggingService.instance.debug(
      serviceName,
      'Starting $opName',
      {'operation_id': operationId, ...?context},
    );

    try {
      // Execute operation
      final result = await operation();

      // Calculate metrics
      final latency = DateTime.now().difference(startTime);

      // Record success
      _recordSuccess(opName, latency, context);

      return result;
    } catch (e, stackTrace) {
      // Calculate metrics
      final latency = DateTime.now().difference(startTime);

      // Record failure
      _recordFailure(opName, latency, e, stackTrace, context);

      rethrow;
    }
  }

  void _recordSuccess(
    String operation,
    Duration latency,
    Map<String, dynamic>? context,
  ) {
    // 1. Record for SLO tracking
    SLOMonitor.instance.recordOperation(
      serviceName: serviceName,
      success: true,
      latencyMs: latency.inMilliseconds,
    );

    // 2. Track latency metric
    final latencyMetric = '${serviceName}_latency_ms';
    AnomalyDetector.instance.recordMetric(
      metricName: latencyMetric,
      value: latency.inMilliseconds.toDouble(),
      metadata: context,
    );

    // 3. Evaluate against alert rules
    AlertManager.instance.evaluateMetric(
      metricName: latencyMetric,
      value: latency.inMilliseconds.toDouble(),
      context: {
        'service': serviceName,
        'operation': operation,
        ...?context,
      },
    );

    // 4. Track in analytics
    AnalyticsService.instance.trackPerformance(
      metric: '$serviceName.$operation.latency',
      value: latency.inMilliseconds.toDouble(),
      unit: 'ms',
    );

    // 5. Log success
    LoggingService.instance.info(
      serviceName,
      'Operation completed: $operation',
      {'latency_ms': latency.inMilliseconds, ...?context},
    );
  }

  void _recordFailure(
    String operation,
    Duration latency,
    Object error,
    StackTrace stackTrace,
    Map<String, dynamic>? context,
  ) {
    // 1. Record for SLO tracking
    SLOMonitor.instance.recordOperation(
      serviceName: serviceName,
      success: false,
      latencyMs: latency.inMilliseconds,
    );

    // 2. Fire error rate alert
    AlertManager.instance.evaluateMetric(
      metricName: 'error_rate_percent',
      value: 100.0,
      context: {
        'service': serviceName,
        'operation': operation,
        'error': error.toString(),
        ...?context,
      },
    );

    // 3. Track error in analytics
    AnalyticsService.instance.track(
      AnalyticsEvent.apiError,
      properties: {
        'service': serviceName,
        'operation': operation,
        'error': error.toString(),
        'latency_ms': latency.inMilliseconds,
        ...?context,
      },
    );

    // 4. Log error
    LoggingService.instance.error(
      serviceName,
      'Operation failed: $operation',
      error,
      stackTrace,
    );
  }
}

/// Example: Audio Service with Observability
class ObservableAudioService extends ObservableService {
  ObservableAudioService() : super('audio');

  Future<void> startRecording({int sampleRate = 16000}) async {
    return performOperation(
      operationName: 'startRecording',
      operation: () async {
        // Simulate recording start
        await Future.delayed(Duration(milliseconds: 50));

        // Your actual recording logic here
        // await _actuallyStartRecording();
      },
      context: {'sample_rate': sampleRate},
    );
  }

  Future<void> stopRecording() async {
    return performOperation(
      operationName: 'stopRecording',
      operation: () async {
        // Simulate recording stop
        await Future.delayed(Duration(milliseconds: 30));

        // Your actual stop logic here
        // await _actuallyStopRecording();
      },
    );
  }
}

/// Example: Transcription Service with Observability
class ObservableTranscriptionService extends ObservableService {
  ObservableTranscriptionService() : super('transcription');

  Future<String> transcribe(String audioPath) async {
    return performOperation<String>(
      operationName: 'transcribe',
      operation: () async {
        // Simulate transcription
        await Future.delayed(Duration(milliseconds: 450));

        // Your actual transcription logic here
        // return await _actuallyTranscribe(audioPath);

        return 'Transcribed text from $audioPath';
      },
      context: {'audio_path': audioPath},
    );
  }
}

/// Example: AI Analysis Service with Observability
class ObservableAIService extends ObservableService {
  ObservableAIService() : super('ai');

  Future<Map<String, dynamic>> analyzeText(String text) async {
    return performOperation<Map<String, dynamic>>(
      operationName: 'analyzeText',
      operation: () async {
        // Simulate AI analysis
        await Future.delayed(Duration(milliseconds: 2500));

        // Your actual AI logic here
        // return await _actuallyAnalyze(text);

        return {
          'sentiment': 'positive',
          'summary': 'Analysis complete',
          'confidence': 0.85,
        };
      },
      context: {'text_length': text.length},
    );
  }
}

/// Example: BLE Service with Observability
class ObservableBLEService extends ObservableService {
  ObservableBLEService() : super('ble');

  Future<void> connect(String deviceId) async {
    return performOperation(
      operationName: 'connect',
      operation: () async {
        // Simulate BLE connection
        await Future.delayed(Duration(milliseconds: 150));

        // Your actual BLE logic here
        // await _actuallyConnect(deviceId);
      },
      context: {'device_id': deviceId},
    );
  }

  Future<void> sendData(List<int> data) async {
    return performOperation(
      operationName: 'sendData',
      operation: () async {
        // Simulate data send
        await Future.delayed(Duration(milliseconds: 100));

        // Your actual send logic here
        // await _actuallySendData(data);
      },
      context: {'data_size': data.length},
    );
  }
}

/// Example: Observability Dashboard Widget
class ObservabilityDashboard extends StatefulWidget {
  const ObservabilityDashboard({Key? key}) : super(key: key);

  @override
  _ObservabilityDashboardState createState() => _ObservabilityDashboardState();
}

class _ObservabilityDashboardState extends State<ObservabilityDashboard> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Observability Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAlertsCard(),
          const SizedBox(height: 16),
          _buildPerformanceCard(),
          const SizedBox(height: 16),
          _buildSLOCard(),
          const SizedBox(height: 16),
          _buildAnomaliesCard(),
        ],
      ),
    );
  }

  Widget _buildAlertsCard() {
    final activeAlerts = AlertManager.instance.getActiveAlerts();
    final criticalAlerts = activeAlerts
        .where((a) => a.rule.severity == AlertSeverity.critical)
        .length;
    final warningAlerts = activeAlerts
        .where((a) => a.rule.severity == AlertSeverity.warning)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  activeAlerts.isEmpty ? Icons.check_circle : Icons.warning,
                  color: activeAlerts.isEmpty ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Active Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Critical: $criticalAlerts'),
            Text('Warning: $warningAlerts'),
            Text('Total: ${activeAlerts.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final recommendations = PerformanceMonitor.instance.getRecommendations();
    final criticalRecs = recommendations
        .where((r) => r.severity == AlertSeverity.critical)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed),
                const SizedBox(width: 8),
                const Text(
                  'Performance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Recommendations: ${recommendations.length}'),
            Text('Critical: $criticalRecs'),
            if (recommendations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                recommendations.first.suggestion,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSLOCard() {
    final services = ['audio', 'transcription', 'ai', 'ble'];
    final compliance = <String, SLOComplianceStatus>{};

    for (final service in services) {
      compliance[service] = SLOMonitor.instance.getComplianceStatus(
        serviceName: service,
        window: SLOWindow.rolling24h,
      );
    }

    final compliantCount = compliance.values
        .where((s) => s.meetsAllSLOs)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  compliantCount == services.length
                      ? Icons.check_circle
                      : Icons.error,
                  color: compliantCount == services.length
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  'SLO Compliance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Compliant: $compliantCount/${services.length}'),
            ...compliance.entries.map((entry) {
              final status = entry.value;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Row(
                      children: [
                        Text(
                          '${status.errorBudgetRemaining.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: status.errorBudgetRemaining > 50
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          status.meetsAllSLOs
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          size: 16,
                          color: status.meetsAllSLOs
                              ? Colors.green
                              : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesCard() {
    final anomalies = AnomalyDetector.instance.detectUsageAnomalies(
      timeWindow: Duration(hours: 1),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  anomalies.isEmpty ? Icons.trending_up : Icons.show_chart,
                  color: anomalies.isEmpty ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Anomalies',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Detected (1h): ${anomalies.length}'),
            if (anomalies.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...anomalies.take(3).map((anomaly) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${anomaly.metricName}: ${anomaly.reason}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  void _exportReport() {
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'alerts': AlertManager.instance.getStatistics(
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

    // In a real app, save to file or share
    debugPrint('=== OBSERVABILITY REPORT ===\n$json');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report exported to console')),
    );
  }
}

/// Example: Initialize observability in main()
class ObservabilityExample {
  static void initializeObservability() {
    // Initialize all observability components
    AlertManager.instance.initialize();
    PerformanceMonitor.instance.startMonitoring();
    SLOMonitor.instance.startMonitoring();

    LoggingService.instance.info(
      'Observability',
      'All observability systems initialized',
    );
  }

  static Future<void> demonstrateUsage() async {
    // Create observable services
    final audioService = ObservableAudioService();
    final transcriptionService = ObservableTranscriptionService();
    final aiService = ObservableAIService();
    final bleService = ObservableBLEService();

    // Use services - all operations automatically tracked
    await audioService.startRecording(sampleRate: 16000);
    await Future.delayed(Duration(seconds: 2));
    await audioService.stopRecording();

    final transcript = await transcriptionService.transcribe('audio.wav');
    final analysis = await aiService.analyzeText(transcript);

    await bleService.connect('device-123');
    await bleService.sendData([1, 2, 3, 4, 5]);

    // Check observability status
    printObservabilityStatus();
  }

  static void printObservabilityStatus() {
    print('\n=== OBSERVABILITY STATUS ===\n');

    // Alerts
    final alerts = AlertManager.instance.getActiveAlerts();
    print('Active Alerts: ${alerts.length}');

    // Performance
    final recommendations = PerformanceMonitor.instance.getRecommendations();
    print('Performance Recommendations: ${recommendations.length}');

    // SLO
    for (final service in ['audio', 'transcription', 'ai', 'ble']) {
      final status = SLOMonitor.instance.getComplianceStatus(
        serviceName: service,
        window: SLOWindow.rolling24h,
      );
      print('$service SLO: ${status.meetsAllSLOs ? "✓" : "✗"} '
          '(${status.errorBudgetRemaining.toStringAsFixed(1)}% budget)');
    }

    print('\n===========================\n');
  }
}
