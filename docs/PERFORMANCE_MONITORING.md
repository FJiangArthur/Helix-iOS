# Performance Monitoring Infrastructure

**Version:** 1.0.0
**Last Updated:** 2025-11-16
**Status:** Active

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Metrics Tracked](#metrics-tracked)
5. [Configuration](#configuration)
6. [Usage Guide](#usage-guide)
7. [Performance Budgets](#performance-budgets)
8. [Dashboard](#dashboard)
9. [Alerts and Notifications](#alerts-and-notifications)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)

---

## Overview

The Helix iOS app includes a comprehensive performance monitoring infrastructure designed to track, analyze, and optimize application performance in real-time. The system monitors:

- **Request/Response Timing**: Track API call latencies and endpoint performance
- **Database Query Performance**: Monitor local storage and query execution times
- **API Endpoint Metrics**: Detailed metrics for each API endpoint
- **Memory/CPU Tracking**: System resource utilization monitoring
- **Performance Budgets**: Define and enforce performance thresholds
- **SLO Compliance**: Service Level Objective monitoring and reporting

### Key Features

- Real-time performance metrics collection
- Automated anomaly detection
- Performance budget enforcement
- SLO/SLA compliance monitoring
- Detailed performance reports
- Auto-scaling recommendations
- Comprehensive alerting system

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  API Calls       │  │  Database Ops    │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                      │                           │
│           ▼                      ▼                           │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Request/Response │  │  Database Perf   │                │
│  │     Tracker      │  │    Monitor       │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                      │                           │
│           └──────────┬───────────┘                           │
│                      ▼                                       │
│           ┌──────────────────────┐                          │
│           │ Performance Monitor  │                          │
│           └──────────┬───────────┘                          │
│                      │                                       │
│           ┌──────────┴───────────┐                          │
│           │                      │                           │
│           ▼                      ▼                           │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Performance      │  │  Anomaly         │                │
│  │   Budgets        │  │  Detector        │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                      │                           │
│           └──────────┬───────────┘                           │
│                      ▼                                       │
│           ┌──────────────────────┐                          │
│           │   Alert Manager      │                          │
│           └──────────────────────┘                          │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Collection**: Metrics collected from various app components
2. **Aggregation**: Data aggregated and stored in memory
3. **Analysis**: Anomaly detection and trend analysis
4. **Alerting**: Violations trigger alerts based on severity
5. **Reporting**: Generate performance reports and dashboards

---

## Components

### 1. Request/Response Tracker

**Location**: `/lib/core/observability/request_response_tracker.dart`

Tracks API request/response cycles, measuring latency, success rates, and payload sizes.

**Key Classes**:
- `RequestTiming`: Individual request timing data
- `EndpointMetrics`: Aggregated endpoint statistics
- `RequestResponseTracker`: Main tracking service

**Usage**:
```dart
// Start tracking a request
final requestId = RequestResponseTracker.instance.startRequest(
  endpoint: '/api/transcribe',
  method: HttpMethod.post,
  metadata: {'contentType': 'audio/wav'},
);

// Complete the request
RequestResponseTracker.instance.completeRequest(
  requestId: requestId,
  statusCode: 200,
  responseSize: 1024,
);

// Get endpoint metrics
final metrics = RequestResponseTracker.instance.getEndpointMetrics('/api/transcribe');
print('P95 Latency: ${metrics?.p95ResponseTime}ms');
```

### 2. Database Performance Monitor

**Location**: `/lib/core/observability/database_performance_monitor.dart`

Monitors database queries, cache performance, and storage operations.

**Key Classes**:
- `QueryTiming`: Individual query timing data
- `StorageMetrics`: Storage layer statistics
- `CacheMetrics`: Cache hit/miss rates
- `DatabasePerformanceMonitor`: Main monitoring service

**Usage**:
```dart
// Track a database query
final queryId = DatabasePerformanceMonitor.instance.startQuery(
  queryName: 'getUserPreferences',
  operation: QueryOperation.read,
  storageType: StorageType.sharedPreferences,
);

// Complete the query
DatabasePerformanceMonitor.instance.completeQuery(
  queryId: queryId,
  recordsAffected: 1,
  bytesRead: 256,
);

// Track cache hit
DatabasePerformanceMonitor.instance.recordCacheHit(
  cacheName: 'userPrefsCache',
  accessTimeMs: 5,
);
```

### 3. Performance Budgets

**Location**: `/lib/core/observability/performance_budgets.dart`

Defines and enforces performance thresholds with violation tracking.

**Key Classes**:
- `PerformanceBudget`: Budget definition
- `BudgetViolation`: Violation record
- `PerformanceBudgets`: Budget management service

**Usage**:
```dart
// Check against budget
final severity = PerformanceBudgets.instance.checkBudget(
  budgetId: 'api_response_time',
  value: 1500,
  context: 'POST /api/transcribe',
);

// Get compliance report
final report = PerformanceBudgets.instance.getComplianceReport();
print('Compliance Rate: ${report['complianceRate']}%');
```

### 4. Performance Monitor

**Location**: `/lib/core/observability/performance_monitor.dart`

Main performance monitoring service tracking CPU, memory, and system metrics.

**Usage**:
```dart
// Start monitoring
PerformanceMonitor.instance.startMonitoring();

// Get performance report
final report = PerformanceMonitor.instance.generateReport(
  timeWindow: Duration(hours: 1),
);

// Get recommendations
final recommendations = PerformanceMonitor.instance.getRecommendations();
```

---

## Metrics Tracked

### Latency Metrics

| Metric | Description | Budget | Unit |
|--------|-------------|--------|------|
| API Response Time | Time from request to response | 1000ms (warn), 2000ms (crit) | ms |
| Audio Latency | Audio processing delay | 100ms (warn), 200ms (crit) | ms |
| Transcription Latency | Transcription processing time | 500ms (warn), 1000ms (crit) | ms |
| AI Analysis Latency | AI analysis processing time | 3000ms (warn), 5000ms (crit) | ms |
| Database Query Time | Query execution time | 50ms (warn), 100ms (crit) | ms |

### Resource Metrics

| Metric | Description | Budget | Unit |
|--------|-------------|--------|------|
| Memory Usage | App memory consumption | 200MB (warn), 400MB (crit) | MB |
| CPU Usage | CPU utilization | 70% (warn), 90% (crit) | % |
| Storage Usage | Local storage size | 100MB (warn), 200MB (crit) | MB |
| Cache Hit Rate | Cache effectiveness | 80% target | % |

### Network Metrics

| Metric | Description | Budget | Unit |
|--------|-------------|--------|------|
| Request Payload Size | Outbound payload size | 1MB (warn), 5MB (crit) | KB |
| Response Payload Size | Inbound payload size | 2MB (warn), 10MB (crit) | KB |
| Network Bandwidth | Data transfer rate | 10MB/s (warn), 50MB/s (crit) | KB/s |

### Quality Metrics

| Metric | Description | Target | Unit |
|--------|-------------|--------|------|
| Success Rate | Request success percentage | 99% | % |
| Error Rate | Request error percentage | <5% | % |
| Availability | Service uptime | 99.9% | % |

---

## Configuration

### Main Configuration File

**Location**: `/config/performance_monitoring.json`

Contains all performance monitoring settings including:
- Monitoring intervals
- Retention policies
- Thresholds and budgets
- SLO targets
- Alert rules
- Anomaly detection parameters

### Key Configuration Sections

#### Monitoring Settings
```json
{
  "monitoring": {
    "enabled": true,
    "environment": "production",
    "samplingRate": {
      "development": 1.0,
      "production": 0.1
    }
  }
}
```

#### Performance Budgets
```json
{
  "budgets": {
    "enabled": true,
    "enforceMode": "warn",
    "categories": [...]
  }
}
```

#### SLO Targets
```json
{
  "slo": {
    "enabled": true,
    "targets": {
      "availability": {...},
      "latency": {...}
    }
  }
}
```

---

## Usage Guide

### Basic Setup

1. **Initialize Performance Monitoring**

```dart
import 'package:flutter_helix/core/observability/performance_monitor.dart';
import 'package:flutter_helix/core/observability/request_response_tracker.dart';
import 'package:flutter_helix/core/observability/database_performance_monitor.dart';
import 'package:flutter_helix/core/observability/performance_budgets.dart';

void initializePerformanceMonitoring() {
  // Start performance monitoring
  PerformanceMonitor.instance.startMonitoring();

  // Enable request tracking
  RequestResponseTracker.instance.setEnabled(true);

  // Enable database monitoring
  DatabasePerformanceMonitor.instance.setEnabled(true);

  // Enable performance budgets
  PerformanceBudgets.instance.setEnabled(true);
}
```

2. **Track API Requests**

```dart
Future<Response> trackApiCall(Future<Response> Function() apiCall, String endpoint) async {
  final requestId = RequestResponseTracker.instance.startRequest(
    endpoint: endpoint,
    method: HttpMethod.post,
  );

  try {
    final response = await apiCall();

    RequestResponseTracker.instance.completeRequest(
      requestId: requestId,
      statusCode: response.statusCode,
      responseSize: response.data?.toString().length ?? 0,
    );

    return response;
  } catch (e) {
    RequestResponseTracker.instance.failRequest(
      requestId: requestId,
      errorMessage: e.toString(),
    );
    rethrow;
  }
}
```

3. **Track Database Queries**

```dart
Future<T> trackDatabaseQuery<T>(
  Future<T> Function() query,
  String queryName,
  QueryOperation operation,
) async {
  final queryId = DatabasePerformanceMonitor.instance.startQuery(
    queryName: queryName,
    operation: operation,
    storageType: StorageType.sharedPreferences,
  );

  try {
    final result = await query();

    DatabasePerformanceMonitor.instance.completeQuery(
      queryId: queryId,
      recordsAffected: 1,
    );

    return result;
  } catch (e) {
    DatabasePerformanceMonitor.instance.failQuery(
      queryId: queryId,
      errorMessage: e.toString(),
    );
    rethrow;
  }
}
```

### Advanced Usage

#### Custom Performance Budgets

```dart
// Add a custom budget
PerformanceBudgets.instance.addBudget(
  PerformanceBudget(
    id: 'custom_metric',
    name: 'Custom Operation Time',
    description: 'Time for custom operation',
    category: BudgetCategory.latency,
    warningThreshold: 200,
    criticalThreshold: 500,
    unit: 'ms',
  ),
);

// Check against budget
final severity = PerformanceBudgets.instance.checkBudget(
  budgetId: 'custom_metric',
  value: 350,
  context: 'Custom operation execution',
);
```

#### Generate Performance Reports

```dart
// Get comprehensive performance report
final report = PerformanceMonitor.instance.generateReport(
  timeWindow: Duration(hours: 24),
);

// Export as JSON
final json = jsonEncode(report);

// Get request performance summary
final requestSummary = RequestResponseTracker.instance.getPerformanceSummary(
  timeWindow: Duration(hours: 1),
);

// Get database performance report
final dbReport = DatabasePerformanceMonitor.instance.generateReport(
  timeWindow: Duration(hours: 1),
);
```

---

## Performance Budgets

### Predefined Budgets

The system includes the following predefined performance budgets:

1. **API Response Time**
   - Warning: 1000ms
   - Critical: 2000ms

2. **Audio Processing Latency**
   - Warning: 100ms
   - Critical: 200ms

3. **Transcription Latency**
   - Warning: 500ms
   - Critical: 1000ms

4. **AI Analysis Latency**
   - Warning: 3000ms
   - Critical: 5000ms

5. **Database Query Time**
   - Warning: 50ms
   - Critical: 100ms

6. **App Memory Usage**
   - Warning: 200MB
   - Critical: 400MB

7. **CPU Usage**
   - Warning: 70%
   - Critical: 90%

### Budget Violation Handling

When a metric exceeds a budget threshold:

1. **Warning Level**: Log warning and record violation
2. **Critical Level**: Log error, record violation, create alert
3. **Emergency Level**: Immediate notification and potential circuit breaking

### Compliance Reporting

```dart
// Get 24-hour compliance report
final compliance = PerformanceBudgets.instance.getComplianceReport();

print('Compliance Rate: ${compliance['complianceRate']}%');
print('Compliant Budgets: ${compliance['compliantBudgets']}/${compliance['totalBudgets']}');
```

---

## Dashboard

### Dashboard Configuration

**Location**: `/config/performance_dashboard.json`

The dashboard configuration defines:
- Panel layouts
- Metrics visualization
- Time windows
- Filters and exports

### Key Dashboard Panels

1. **Performance Overview**: System health summary
2. **Latency Metrics**: Time-series latency charts
3. **Resource Usage**: CPU and memory usage
4. **API Endpoint Performance**: Endpoint metrics table
5. **Database Performance**: Query performance table
6. **Error Rates**: Error rate trends
7. **Cache Performance**: Cache hit/miss metrics
8. **Budget Compliance**: Budget status bars
9. **SLO Compliance**: SLO status grid
10. **Recent Alerts**: Alert history
11. **Budget Violations**: Violation history
12. **Recommendations**: Performance suggestions

### Accessing Dashboard Data

```dart
// Get dashboard metrics
Map<String, dynamic> getDashboardMetrics() {
  return {
    'overview': {
      'systemHealth': _calculateSystemHealth(),
      'activeRequests': RequestResponseTracker.instance._activeRequests.length,
      'budgetViolations24h': PerformanceBudgets.instance.getViolations(
        timeWindow: Duration(hours: 24),
      ).length,
      'sloCompliance': SLOMonitor.instance.getComplianceRate(),
    },
    'latency': RequestResponseTracker.instance.getPerformanceSummary(),
    'resources': PerformanceMonitor.instance.generateReport(),
    'database': DatabasePerformanceMonitor.instance.generateReport(),
    'budgets': PerformanceBudgets.instance.getComplianceReport(),
  };
}
```

---

## Alerts and Notifications

### Alert Types

- **Performance Latency**: High response times
- **Performance Memory**: Excessive memory usage
- **Performance CPU**: High CPU utilization
- **Error Rate**: High error rates
- **SLO Violation**: SLO target breaches
- **Budget Violation**: Performance budget exceeded

### Alert Severity Levels

1. **Info**: Informational, no action required
2. **Warning**: Investigate soon
3. **Critical**: Immediate attention required
4. **Emergency**: System failure, immediate action

### Configuring Alerts

Alerts are configured in `/config/performance_monitoring.json`:

```json
{
  "alerts": {
    "enabled": true,
    "channels": ["console", "analytics", "logging"],
    "rules": [
      {
        "id": "high_api_latency",
        "name": "High API Latency",
        "type": "performanceLatency",
        "condition": "p95 > threshold",
        "threshold": 1000,
        "window": 300,
        "severity": "warning"
      }
    ]
  }
}
```

---

## Best Practices

### 1. Monitoring Strategy

- **Always monitor in production**: Use appropriate sampling rates
- **Track critical paths**: Focus on user-facing operations
- **Set realistic budgets**: Based on user experience requirements
- **Review metrics regularly**: Weekly performance reviews

### 2. Performance Optimization

- **Identify bottlenecks**: Use P95/P99 metrics to find slowest operations
- **Optimize hot paths**: Focus on frequently-called operations
- **Cache effectively**: Monitor cache hit rates
- **Batch operations**: Reduce individual request overhead

### 3. Budget Management

- **Start conservative**: Set tight budgets initially
- **Adjust based on data**: Review and adjust after collecting baseline
- **Monitor violations**: Investigate all critical violations
- **Track trends**: Look for degradation over time

### 4. Alert Configuration

- **Avoid alert fatigue**: Set appropriate thresholds
- **Actionable alerts**: Only alert on items that require action
- **Clear escalation**: Define severity levels clearly
- **Test alerts**: Verify alert delivery

### 5. Reporting

- **Regular reports**: Generate daily/weekly reports
- **Share with team**: Keep stakeholders informed
- **Track SLOs**: Monitor SLO compliance continuously
- **Document incidents**: Learn from performance incidents

---

## Troubleshooting

### High Memory Usage

**Symptoms**: Memory warnings, app crashes, slow performance

**Investigation**:
```dart
// Get memory metrics
final report = PerformanceMonitor.instance.generateReport();
final memoryStats = report['memory'];

// Check for memory leaks
final recommendations = PerformanceMonitor.instance.getRecommendations(
  action: ScalingAction.optimize,
);
```

**Solutions**:
- Clear unused caches
- Dispose resources properly
- Implement lazy loading
- Review memory leaks

### High API Latency

**Symptoms**: Slow API responses, timeout errors

**Investigation**:
```dart
// Get slowest endpoints
final report = RequestResponseTracker.instance.generateReport();
final slowestEndpoints = report['slowestEndpoints'];

// Check endpoint metrics
final metrics = RequestResponseTracker.instance.getEndpointMetrics('/api/endpoint');
```

**Solutions**:
- Optimize API calls
- Implement caching
- Use request batching
- Check network conditions

### Slow Database Queries

**Symptoms**: UI lag, slow data access

**Investigation**:
```dart
// Get slowest queries
final slowQueries = DatabasePerformanceMonitor.instance.getSlowestQueries(limit: 10);

// Check storage metrics
final storageMetrics = DatabasePerformanceMonitor.instance.getAllStorageMetrics();
```

**Solutions**:
- Optimize query logic
- Add appropriate indexes
- Implement query caching
- Use lazy loading

### Budget Violations

**Symptoms**: Frequent budget violation alerts

**Investigation**:
```dart
// Get violation summary
final violations = PerformanceBudgets.instance.getViolationSummary(
  timeWindow: Duration(hours: 24),
);

// Get compliance report
final compliance = PerformanceBudgets.instance.getComplianceReport();
```

**Solutions**:
- Review budget thresholds
- Optimize violating operations
- Investigate root causes
- Adjust budgets if needed

---

## API Reference

### RequestResponseTracker

```dart
// Start request tracking
String startRequest({
  required String endpoint,
  required HttpMethod method,
  Map<String, dynamic>? metadata,
});

// Complete request
void completeRequest({
  required String requestId,
  required int statusCode,
  int? responseSize,
  Map<String, dynamic>? metadata,
});

// Get metrics
EndpointMetrics? getEndpointMetrics(String endpoint);
Map<String, dynamic> getPerformanceSummary({Duration? timeWindow});
Map<String, dynamic> generateReport();
```

### DatabasePerformanceMonitor

```dart
// Start query tracking
String startQuery({
  required String queryName,
  required QueryOperation operation,
  required StorageType storageType,
  Map<String, dynamic>? metadata,
});

// Complete query
void completeQuery({
  required String queryId,
  int? recordsAffected,
  int? bytesRead,
  int? bytesWritten,
});

// Cache tracking
void recordCacheHit({required String cacheName, int accessTimeMs});
void recordCacheMiss({required String cacheName, int accessTimeMs});

// Get metrics
StorageMetrics? getStorageMetrics(StorageType storageType);
Map<String, dynamic> generateReport({Duration? timeWindow});
```

### PerformanceBudgets

```dart
// Budget management
void addBudget(PerformanceBudget budget);
PerformanceBudget? getBudget(String budgetId);
List<PerformanceBudget> getAllBudgets();

// Violation checking
ViolationSeverity checkBudget({
  required String budgetId,
  required double value,
  String? context,
});

// Reporting
List<BudgetViolation> getViolations({Duration? timeWindow});
Map<String, dynamic> getComplianceReport();
Map<String, dynamic> generateReport();
```

### PerformanceMonitor

```dart
// Monitoring control
void startMonitoring();
void stopMonitoring();

// Metrics
List<PerformanceMetrics> getMetricsHistory({Duration? timeWindow});
List<PerformanceRecommendation> getRecommendations();

// Reporting
Map<String, dynamic> generateReport({Duration? timeWindow});
```

---

## Changelog

### Version 1.0.0 (2025-11-16)
- Initial implementation
- Request/Response tracking
- Database performance monitoring
- Performance budgets
- Dashboard configuration
- Comprehensive documentation

---

## Support

For questions or issues with performance monitoring:

1. Review this documentation
2. Check troubleshooting section
3. Review performance reports
4. Contact development team

---

## License

Copyright (c) 2025 Helix iOS Team. All rights reserved.
