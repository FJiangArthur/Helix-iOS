// ABOUTME: Performance monitoring integration example and helper utilities
// ABOUTME: Demonstrates how to use the performance monitoring system

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'performance_monitor.dart';
import 'request_response_tracker.dart';
import 'database_performance_monitor.dart';
import 'performance_budgets.dart';
import '../utils/logging_service.dart';

/// Performance monitoring service integrator
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance = PerformanceMonitoringService._();
  static PerformanceMonitoringService get instance => _instance;

  PerformanceMonitoringService._();

  bool _isInitialized = false;

  /// Initialize all performance monitoring components
  void initialize() {
    if (_isInitialized) {
      LoggingService.instance.warning(
        'PerformanceMonitoringService',
        'Performance monitoring already initialized',
      );
      return;
    }

    LoggingService.instance.info(
      'PerformanceMonitoringService',
      'Initializing performance monitoring system',
    );

    // Start performance monitor
    PerformanceMonitor.instance.startMonitoring();

    // Enable request tracking
    RequestResponseTracker.instance.setEnabled(true);

    // Enable database monitoring
    DatabasePerformanceMonitor.instance.setEnabled(true);

    // Enable performance budgets
    PerformanceBudgets.instance.setEnabled(true);

    _isInitialized = true;

    LoggingService.instance.info(
      'PerformanceMonitoringService',
      'Performance monitoring system initialized successfully',
    );
  }

  /// Shutdown performance monitoring
  void shutdown() {
    if (!_isInitialized) return;

    LoggingService.instance.info(
      'PerformanceMonitoringService',
      'Shutting down performance monitoring system',
    );

    PerformanceMonitor.instance.stopMonitoring();
    _isInitialized = false;
  }

  /// Track an API call with automatic performance monitoring
  Future<T> trackApiCall<T>({
    required Future<T> Function() apiCall,
    required String endpoint,
    required HttpMethod method,
    Map<String, dynamic>? metadata,
  }) async {
    final requestId = RequestResponseTracker.instance.startRequest(
      endpoint: endpoint,
      method: method,
      metadata: metadata,
    );

    final stopwatch = Stopwatch()..start();

    try {
      final result = await apiCall();

      stopwatch.stop();

      // Assume successful response (adjust based on your response type)
      RequestResponseTracker.instance.completeRequest(
        requestId: requestId,
        statusCode: 200,
        responseSize: result.toString().length,
        metadata: {
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );

      // Check against budget
      PerformanceBudgets.instance.checkBudget(
        budgetId: 'api_response_time',
        value: stopwatch.elapsedMilliseconds.toDouble(),
        context: '$method $endpoint',
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      RequestResponseTracker.instance.failRequest(
        requestId: requestId,
        errorMessage: e.toString(),
        statusCode: e is Exception ? 500 : null,
      );

      rethrow;
    }
  }

  /// Track a database query with automatic performance monitoring
  Future<T> trackDatabaseQuery<T>({
    required Future<T> Function() query,
    required String queryName,
    required QueryOperation operation,
    required StorageType storageType,
  }) async {
    final queryId = DatabasePerformanceMonitor.instance.startQuery(
      queryName: queryName,
      operation: operation,
      storageType: storageType,
    );

    final stopwatch = Stopwatch()..start();

    try {
      final result = await query();

      stopwatch.stop();

      DatabasePerformanceMonitor.instance.completeQuery(
        queryId: queryId,
        recordsAffected: 1,
        metadata: {
          'durationMs': stopwatch.elapsedMilliseconds,
        },
      );

      // Check against budget
      PerformanceBudgets.instance.checkBudget(
        budgetId: 'db_query_time',
        value: stopwatch.elapsedMilliseconds.toDouble(),
        context: '$queryName (${operation.name})',
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      DatabasePerformanceMonitor.instance.failQuery(
        queryId: queryId,
        errorMessage: e.toString(),
      );

      rethrow;
    }
  }

  /// Track a synchronous operation with performance monitoring
  T trackOperation<T>({
    required T Function() operation,
    required String operationName,
    required String budgetId,
  }) {
    final stopwatch = Stopwatch()..start();

    try {
      final result = operation();

      stopwatch.stop();

      PerformanceBudgets.instance.checkBudget(
        budgetId: budgetId,
        value: stopwatch.elapsedMilliseconds.toDouble(),
        context: operationName,
      );

      return result;
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }
  }

  /// Generate comprehensive performance report
  Map<String, dynamic> generateComprehensiveReport({
    Duration timeWindow = const Duration(hours: 24),
  }) {
    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'timeWindow': '${timeWindow.inHours}h',
      'system': PerformanceMonitor.instance.generateReport(
        timeWindow: timeWindow,
      ),
      'requests': RequestResponseTracker.instance.generateReport(),
      'database': DatabasePerformanceMonitor.instance.generateReport(
        timeWindow: timeWindow,
      ),
      'budgets': PerformanceBudgets.instance.generateReport(),
      'summary': _generateSummary(timeWindow),
    };
  }

  /// Generate performance summary
  Map<String, dynamic> _generateSummary(Duration timeWindow) {
    final requestSummary = RequestResponseTracker.instance.getPerformanceSummary(
      timeWindow: timeWindow,
    );
    final budgetCompliance = PerformanceBudgets.instance.getComplianceReport();

    return {
      'overallHealth': _calculateOverallHealth(requestSummary, budgetCompliance),
      'totalRequests': requestSummary['totalRequests'],
      'successRate': requestSummary['successRate'],
      'budgetCompliance': budgetCompliance['complianceRate'],
      'criticalIssues': _identifyCriticalIssues(),
    };
  }

  /// Calculate overall system health score (0-100)
  int _calculateOverallHealth(
    Map<String, dynamic> requestSummary,
    Map<String, dynamic> budgetCompliance,
  ) {
    var health = 100.0;

    // Factor in error rate
    final errorRate = double.tryParse(requestSummary['errorRate']?.toString() ?? '0') ?? 0;
    health -= errorRate * 2; // -2 points per 1% error rate

    // Factor in budget compliance
    final compliance = double.tryParse(budgetCompliance['complianceRate']?.toString() ?? '100') ?? 100;
    health -= (100 - compliance); // -1 point per 1% non-compliance

    // Factor in violations
    final violations = budgetCompliance['violationSummary']['totalViolations'] ?? 0;
    health -= (violations * 0.5); // -0.5 points per violation

    return health.clamp(0, 100).round();
  }

  /// Identify critical performance issues
  List<Map<String, dynamic>> _identifyCriticalIssues() {
    final issues = <Map<String, dynamic>>[];

    // Check for critical budget violations
    final criticalViolations = PerformanceBudgets.instance.getViolations(
      timeWindow: const Duration(hours: 24),
      severity: ViolationSeverity.critical,
    );

    for (final violation in criticalViolations) {
      issues.add({
        'type': 'budget_violation',
        'severity': 'critical',
        'budget': violation.budgetName,
        'value': violation.value,
        'threshold': violation.threshold,
        'timestamp': violation.timestamp.toIso8601String(),
      });
    }

    // Check for slow endpoints
    final endpointMetrics = RequestResponseTracker.instance.getAllEndpointMetrics();
    for (final entry in endpointMetrics.entries) {
      if (entry.value.p95ResponseTime > 2000) {
        issues.add({
          'type': 'slow_endpoint',
          'severity': 'warning',
          'endpoint': entry.key,
          'p95ResponseTime': entry.value.p95ResponseTime,
          'threshold': 2000,
        });
      }

      if (entry.value.errorRate > 10) {
        issues.add({
          'type': 'high_error_rate',
          'severity': 'critical',
          'endpoint': entry.key,
          'errorRate': entry.value.errorRate,
          'threshold': 10,
        });
      }
    }

    // Sort by severity
    issues.sort((a, b) {
      final severityOrder = {'critical': 0, 'warning': 1, 'info': 2};
      return (severityOrder[a['severity']] ?? 99)
          .compareTo(severityOrder[b['severity']] ?? 99);
    });

    return issues;
  }

  /// Get current system status
  Map<String, dynamic> getSystemStatus() {
    return {
      'initialized': _isInitialized,
      'monitoring': PerformanceMonitor.instance.isMonitoring,
      'requestTracking': RequestResponseTracker.instance.isEnabled,
      'databaseMonitoring': DatabasePerformanceMonitor.instance.isEnabled,
      'budgetsEnabled': PerformanceBudgets.instance.isEnabled,
      'activeRequests': RequestResponseTracker.instance._activeRequests.length,
      'activeQueries': DatabasePerformanceMonitor.instance._activeQueries.length,
    };
  }

  /// Clear all performance data
  void clearAllData() {
    PerformanceMonitor.instance.clearHistory();
    RequestResponseTracker.instance.clearHistory();
    DatabasePerformanceMonitor.instance.clearHistory();
    PerformanceBudgets.instance.clearViolations();

    LoggingService.instance.info(
      'PerformanceMonitoringService',
      'All performance monitoring data cleared',
    );
  }
}

/// Example usage class
class PerformanceMonitoringExamples {
  /// Example: Track an API call
  static Future<void> exampleApiCall() async {
    final result = await PerformanceMonitoringService.instance.trackApiCall(
      apiCall: () async {
        // Your API call here
        await Future.delayed(const Duration(milliseconds: 500));
        return {'data': 'example'};
      },
      endpoint: '/api/transcribe',
      method: HttpMethod.post,
      metadata: {'contentType': 'audio/wav'},
    );

    print('API call result: $result');
  }

  /// Example: Track a database query
  static Future<void> exampleDatabaseQuery() async {
    final result = await PerformanceMonitoringService.instance.trackDatabaseQuery(
      query: () async {
        // Your database query here
        await Future.delayed(const Duration(milliseconds: 20));
        return {'user': 'example'};
      },
      queryName: 'getUserPreferences',
      operation: QueryOperation.read,
      storageType: StorageType.sharedPreferences,
    );

    print('Query result: $result');
  }

  /// Example: Track a synchronous operation
  static void exampleSyncOperation() {
    final result = PerformanceMonitoringService.instance.trackOperation(
      operation: () {
        // Your synchronous operation here
        var sum = 0;
        for (var i = 0; i < 1000000; i++) {
          sum += i;
        }
        return sum;
      },
      operationName: 'Heavy calculation',
      budgetId: 'cpu_usage',
    );

    print('Operation result: $result');
  }

  /// Example: Generate and print performance report
  static void exampleGenerateReport() {
    final report = PerformanceMonitoringService.instance.generateComprehensiveReport(
      timeWindow: const Duration(hours: 24),
    );

    print('Performance Report:');
    print('Overall Health: ${report['summary']['overallHealth']}%');
    print('Total Requests: ${report['summary']['totalRequests']}');
    print('Success Rate: ${report['summary']['successRate']}%');
    print('Budget Compliance: ${report['summary']['budgetCompliance']}%');
    print('Critical Issues: ${report['summary']['criticalIssues'].length}');
  }
}
