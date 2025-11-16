// ABOUTME: Request/Response timing tracker for API calls and network operations
// ABOUTME: Tracks latency, success rates, and provides detailed endpoint metrics

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/logging_service.dart';
import 'observability_config.dart';
import 'performance_monitor.dart';

/// HTTP Method types
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,
  head,
  options,
}

/// Request status
enum RequestStatus {
  pending,
  success,
  error,
  timeout,
  cancelled,
}

/// Request timing information
class RequestTiming {
  final String requestId;
  final String endpoint;
  final HttpMethod method;
  final DateTime startTime;
  DateTime? endTime;
  RequestStatus status;
  int? statusCode;
  int? responseSize;
  String? errorMessage;
  Map<String, dynamic>? metadata;

  RequestTiming({
    required this.requestId,
    required this.endpoint,
    required this.method,
    required this.startTime,
    this.endTime,
    this.status = RequestStatus.pending,
    this.statusCode,
    this.responseSize,
    this.errorMessage,
    this.metadata,
  });

  /// Get request duration in milliseconds
  int? get durationMs {
    if (endTime == null) return null;
    return endTime!.difference(startTime).inMilliseconds;
  }

  /// Check if request was successful
  bool get isSuccess => status == RequestStatus.success && statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// Check if request failed
  bool get isError => status == RequestStatus.error || status == RequestStatus.timeout;

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'endpoint': endpoint,
    'method': method.name,
    'startTime': startTime.toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toIso8601String(),
    'status': status.name,
    if (statusCode != null) 'statusCode': statusCode,
    if (durationMs != null) 'durationMs': durationMs,
    if (responseSize != null) 'responseSize': responseSize,
    if (errorMessage != null) 'error': errorMessage,
    if (metadata != null) 'metadata': metadata,
  };
}

/// Endpoint metrics aggregation
class EndpointMetrics {
  final String endpoint;
  final List<int> responseTimes = [];
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  int timeoutRequests = 0;
  int totalResponseSize = 0;
  DateTime? firstRequestTime;
  DateTime? lastRequestTime;

  EndpointMetrics({required this.endpoint});

  /// Add a request timing to the metrics
  void addRequest(RequestTiming timing) {
    totalRequests++;
    firstRequestTime ??= timing.startTime;
    lastRequestTime = timing.endTime ?? timing.startTime;

    if (timing.durationMs != null) {
      responseTimes.add(timing.durationMs!);
    }

    if (timing.responseSize != null) {
      totalResponseSize += timing.responseSize!;
    }

    switch (timing.status) {
      case RequestStatus.success:
        successfulRequests++;
        break;
      case RequestStatus.error:
        failedRequests++;
        break;
      case RequestStatus.timeout:
        timeoutRequests++;
        failedRequests++;
        break;
      default:
        break;
    }
  }

  /// Get average response time
  double get averageResponseTime {
    if (responseTimes.isEmpty) return 0;
    return responseTimes.reduce((a, b) => a + b) / responseTimes.length;
  }

  /// Get median response time
  int get medianResponseTime {
    if (responseTimes.isEmpty) return 0;
    final sorted = List<int>.from(responseTimes)..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Get P95 response time
  int get p95ResponseTime {
    if (responseTimes.isEmpty) return 0;
    final sorted = List<int>.from(responseTimes)..sort();
    final index = (sorted.length * 0.95).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Get P99 response time
  int get p99ResponseTime {
    if (responseTimes.isEmpty) return 0;
    final sorted = List<int>.from(responseTimes)..sort();
    final index = (sorted.length * 0.99).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Get success rate percentage
  double get successRate {
    if (totalRequests == 0) return 0;
    return (successfulRequests / totalRequests) * 100;
  }

  /// Get error rate percentage
  double get errorRate {
    if (totalRequests == 0) return 0;
    return (failedRequests / totalRequests) * 100;
  }

  /// Get average response size
  double get averageResponseSize {
    if (successfulRequests == 0) return 0;
    return totalResponseSize / successfulRequests;
  }

  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'totalRequests': totalRequests,
    'successfulRequests': successfulRequests,
    'failedRequests': failedRequests,
    'timeoutRequests': timeoutRequests,
    'successRate': successRate.toStringAsFixed(2),
    'errorRate': errorRate.toStringAsFixed(2),
    'averageResponseTime': averageResponseTime.toStringAsFixed(2),
    'medianResponseTime': medianResponseTime,
    'p95ResponseTime': p95ResponseTime,
    'p99ResponseTime': p99ResponseTime,
    'averageResponseSize': averageResponseSize.toStringAsFixed(2),
    'totalResponseSize': totalResponseSize,
    if (firstRequestTime != null) 'firstRequestTime': firstRequestTime!.toIso8601String(),
    if (lastRequestTime != null) 'lastRequestTime': lastRequestTime!.toIso8601String(),
  };
}

/// Request/Response tracker for monitoring API performance
class RequestResponseTracker {
  static final RequestResponseTracker _instance = RequestResponseTracker._();
  static RequestResponseTracker get instance => _instance;

  RequestResponseTracker._();

  final Map<String, RequestTiming> _activeRequests = {};
  final List<RequestTiming> _completedRequests = [];
  final Map<String, EndpointMetrics> _endpointMetrics = {};

  int _requestCounter = 0;
  bool _isEnabled = true;

  /// Start tracking a new request
  String startRequest({
    required String endpoint,
    required HttpMethod method,
    Map<String, dynamic>? metadata,
  }) {
    if (!_isEnabled) return '';

    final requestId = 'req_${++_requestCounter}_${DateTime.now().millisecondsSinceEpoch}';
    final timing = RequestTiming(
      requestId: requestId,
      endpoint: endpoint,
      method: method,
      startTime: DateTime.now(),
      metadata: metadata,
    );

    _activeRequests[requestId] = timing;

    LoggingService.instance.debug(
      'RequestTracker',
      'Started tracking request: ${method.name.toUpperCase()} $endpoint',
      {'requestId': requestId},
    );

    return requestId;
  }

  /// Complete a request with success
  void completeRequest({
    required String requestId,
    required int statusCode,
    int? responseSize,
    Map<String, dynamic>? metadata,
  }) {
    final timing = _activeRequests.remove(requestId);
    if (timing == null) {
      LoggingService.instance.warning(
        'RequestTracker',
        'Attempted to complete unknown request: $requestId',
      );
      return;
    }

    timing.endTime = DateTime.now();
    timing.status = RequestStatus.success;
    timing.statusCode = statusCode;
    timing.responseSize = responseSize;
    if (metadata != null) {
      timing.metadata = {...?timing.metadata, ...metadata};
    }

    _recordCompletedRequest(timing);
  }

  /// Mark a request as failed
  void failRequest({
    required String requestId,
    required String errorMessage,
    int? statusCode,
  }) {
    final timing = _activeRequests.remove(requestId);
    if (timing == null) return;

    timing.endTime = DateTime.now();
    timing.status = RequestStatus.error;
    timing.statusCode = statusCode;
    timing.errorMessage = errorMessage;

    _recordCompletedRequest(timing);
  }

  /// Mark a request as timed out
  void timeoutRequest({
    required String requestId,
  }) {
    final timing = _activeRequests.remove(requestId);
    if (timing == null) return;

    timing.endTime = DateTime.now();
    timing.status = RequestStatus.timeout;
    timing.errorMessage = 'Request timed out';

    _recordCompletedRequest(timing);
  }

  /// Record a completed request
  void _recordCompletedRequest(RequestTiming timing) {
    _completedRequests.add(timing);

    // Maintain history size (keep last 1000 requests)
    if (_completedRequests.length > 1000) {
      _completedRequests.removeAt(0);
    }

    // Update endpoint metrics
    final metrics = _endpointMetrics.putIfAbsent(
      timing.endpoint,
      () => EndpointMetrics(endpoint: timing.endpoint),
    );
    metrics.addRequest(timing);

    // Log performance metric
    if (timing.durationMs != null) {
      LoggingService.instance.debug(
        'RequestTracker',
        'Request completed: ${timing.method.name.toUpperCase()} ${timing.endpoint}',
        {
          'requestId': timing.requestId,
          'durationMs': timing.durationMs,
          'status': timing.status.name,
          'statusCode': timing.statusCode,
        },
      );

      // Check against performance budgets
      _checkPerformanceBudget(timing);
    }
  }

  /// Check if request violates performance budget
  void _checkPerformanceBudget(RequestTiming timing) {
    final thresholds = ObservabilityConfig.instance.thresholds;

    if (timing.durationMs == null) return;

    // Check against general API response time budgets
    if (timing.durationMs! > thresholds.p95ResponseTimeCriticalMs) {
      LoggingService.instance.warning(
        'RequestTracker',
        'Request exceeded critical performance budget',
        {
          'endpoint': timing.endpoint,
          'durationMs': timing.durationMs,
          'budgetMs': thresholds.p95ResponseTimeCriticalMs,
        },
      );
    } else if (timing.durationMs! > thresholds.p95ResponseTimeWarningMs) {
      LoggingService.instance.warning(
        'RequestTracker',
        'Request exceeded warning performance budget',
        {
          'endpoint': timing.endpoint,
          'durationMs': timing.durationMs,
          'budgetMs': thresholds.p95ResponseTimeWarningMs,
        },
      );
    }
  }

  /// Get metrics for a specific endpoint
  EndpointMetrics? getEndpointMetrics(String endpoint) {
    return _endpointMetrics[endpoint];
  }

  /// Get all endpoint metrics
  Map<String, EndpointMetrics> getAllEndpointMetrics() {
    return Map.from(_endpointMetrics);
  }

  /// Get completed requests within a time window
  List<RequestTiming> getRequestHistory({Duration? timeWindow}) {
    if (timeWindow == null) {
      return List.from(_completedRequests);
    }

    final cutoff = DateTime.now().subtract(timeWindow);
    return _completedRequests
        .where((r) => r.startTime.isAfter(cutoff))
        .toList();
  }

  /// Get overall performance summary
  Map<String, dynamic> getPerformanceSummary({Duration? timeWindow}) {
    final requests = getRequestHistory(timeWindow: timeWindow);

    if (requests.isEmpty) {
      return {
        'totalRequests': 0,
        'message': 'No requests in time window',
      };
    }

    final responseTimes = requests
        .where((r) => r.durationMs != null)
        .map((r) => r.durationMs!)
        .toList()
      ..sort();

    final successful = requests.where((r) => r.isSuccess).length;
    final failed = requests.where((r) => r.isError).length;

    return {
      'timeWindow': timeWindow?.inMinutes ?? 'all',
      'totalRequests': requests.length,
      'successfulRequests': successful,
      'failedRequests': failed,
      'successRate': requests.isNotEmpty ? (successful / requests.length * 100).toStringAsFixed(2) : '0',
      'errorRate': requests.isNotEmpty ? (failed / requests.length * 100).toStringAsFixed(2) : '0',
      'averageResponseTime': responseTimes.isNotEmpty
          ? (responseTimes.reduce((a, b) => a + b) / responseTimes.length).toStringAsFixed(2)
          : '0',
      'medianResponseTime': responseTimes.isNotEmpty ? responseTimes[responseTimes.length ~/ 2] : 0,
      'p95ResponseTime': responseTimes.isNotEmpty
          ? responseTimes[(responseTimes.length * 0.95).floor()]
          : 0,
      'p99ResponseTime': responseTimes.isNotEmpty
          ? responseTimes[(responseTimes.length * 0.99).floor()]
          : 0,
      'endpointBreakdown': _endpointMetrics.values.map((m) => m.toJson()).toList(),
    };
  }

  /// Generate detailed performance report
  Map<String, dynamic> generateReport() {
    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'activeRequests': _activeRequests.length,
      'completedRequests': _completedRequests.length,
      'totalEndpoints': _endpointMetrics.length,
      'summary': getPerformanceSummary(timeWindow: const Duration(hours: 1)),
      'endpointMetrics': _endpointMetrics.values.map((m) => m.toJson()).toList(),
      'slowestEndpoints': _getTopSlowestEndpoints(5),
      'mostUsedEndpoints': _getTopUsedEndpoints(5),
      'highestErrorRateEndpoints': _getHighestErrorRateEndpoints(5),
    };
  }

  /// Get top slowest endpoints
  List<Map<String, dynamic>> _getTopSlowestEndpoints(int count) {
    final endpoints = _endpointMetrics.values.toList()
      ..sort((a, b) => b.p95ResponseTime.compareTo(a.p95ResponseTime));

    return endpoints
        .take(count)
        .map((e) => {
          'endpoint': e.endpoint,
          'p95ResponseTime': e.p95ResponseTime,
          'totalRequests': e.totalRequests,
        })
        .toList();
  }

  /// Get top most used endpoints
  List<Map<String, dynamic>> _getTopUsedEndpoints(int count) {
    final endpoints = _endpointMetrics.values.toList()
      ..sort((a, b) => b.totalRequests.compareTo(a.totalRequests));

    return endpoints
        .take(count)
        .map((e) => {
          'endpoint': e.endpoint,
          'totalRequests': e.totalRequests,
          'successRate': e.successRate.toStringAsFixed(2),
        })
        .toList();
  }

  /// Get endpoints with highest error rates
  List<Map<String, dynamic>> _getHighestErrorRateEndpoints(int count) {
    final endpoints = _endpointMetrics.values
        .where((e) => e.totalRequests > 0)
        .toList()
      ..sort((a, b) => b.errorRate.compareTo(a.errorRate));

    return endpoints
        .take(count)
        .map((e) => {
          'endpoint': e.endpoint,
          'errorRate': e.errorRate.toStringAsFixed(2),
          'failedRequests': e.failedRequests,
          'totalRequests': e.totalRequests,
        })
        .toList();
  }

  /// Clear all tracking data
  void clearHistory() {
    _completedRequests.clear();
    _endpointMetrics.clear();
    LoggingService.instance.info('RequestTracker', 'Request history cleared');
  }

  /// Enable/disable tracking
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    LoggingService.instance.info(
      'RequestTracker',
      'Request tracking ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Get tracking status
  bool get isEnabled => _isEnabled;
}
