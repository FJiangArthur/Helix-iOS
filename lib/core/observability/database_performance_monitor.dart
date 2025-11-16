// ABOUTME: Database and storage performance monitoring
// ABOUTME: Tracks query execution times, cache performance, and storage metrics

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/logging_service.dart';
import 'observability_config.dart';

/// Query operation types
enum QueryOperation {
  read,
  write,
  update,
  delete,
  batch,
  transaction,
}

/// Storage type
enum StorageType {
  sharedPreferences,
  secureStorage,
  fileSystem,
  inMemoryCache,
  database,
}

/// Query timing information
class QueryTiming {
  final String queryId;
  final String queryName;
  final QueryOperation operation;
  final StorageType storageType;
  final DateTime startTime;
  DateTime? endTime;
  bool isSuccess;
  int? recordsAffected;
  int? bytesRead;
  int? bytesWritten;
  String? errorMessage;
  Map<String, dynamic>? metadata;

  QueryTiming({
    required this.queryId,
    required this.queryName,
    required this.operation,
    required this.storageType,
    required this.startTime,
    this.endTime,
    this.isSuccess = false,
    this.recordsAffected,
    this.bytesRead,
    this.bytesWritten,
    this.errorMessage,
    this.metadata,
  });

  /// Get query duration in milliseconds
  int? get durationMs {
    if (endTime == null) return null;
    return endTime!.difference(startTime).inMilliseconds;
  }

  Map<String, dynamic> toJson() => {
    'queryId': queryId,
    'queryName': queryName,
    'operation': operation.name,
    'storageType': storageType.name,
    'startTime': startTime.toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toIso8601String(),
    if (durationMs != null) 'durationMs': durationMs,
    'isSuccess': isSuccess,
    if (recordsAffected != null) 'recordsAffected': recordsAffected,
    if (bytesRead != null) 'bytesRead': bytesRead,
    if (bytesWritten != null) 'bytesWritten': bytesWritten,
    if (errorMessage != null) 'error': errorMessage,
    if (metadata != null) 'metadata': metadata,
  };
}

/// Storage layer metrics
class StorageMetrics {
  final StorageType storageType;
  final List<int> queryTimes = [];
  int totalQueries = 0;
  int successfulQueries = 0;
  int failedQueries = 0;
  int totalReads = 0;
  int totalWrites = 0;
  int totalBytesRead = 0;
  int totalBytesWritten = 0;
  DateTime? firstQueryTime;
  DateTime? lastQueryTime;

  StorageMetrics({required this.storageType});

  /// Add a query to the metrics
  void addQuery(QueryTiming timing) {
    totalQueries++;
    firstQueryTime ??= timing.startTime;
    lastQueryTime = timing.endTime ?? timing.startTime;

    if (timing.durationMs != null) {
      queryTimes.add(timing.durationMs!);
    }

    if (timing.isSuccess) {
      successfulQueries++;
    } else {
      failedQueries++;
    }

    switch (timing.operation) {
      case QueryOperation.read:
        totalReads++;
        break;
      case QueryOperation.write:
      case QueryOperation.update:
      case QueryOperation.delete:
        totalWrites++;
        break;
      case QueryOperation.batch:
      case QueryOperation.transaction:
        // Could be reads or writes, count as both
        totalReads++;
        totalWrites++;
        break;
    }

    if (timing.bytesRead != null) {
      totalBytesRead += timing.bytesRead!;
    }

    if (timing.bytesWritten != null) {
      totalBytesWritten += timing.bytesWritten!;
    }
  }

  /// Get average query time
  double get averageQueryTime {
    if (queryTimes.isEmpty) return 0;
    return queryTimes.reduce((a, b) => a + b) / queryTimes.length;
  }

  /// Get median query time
  int get medianQueryTime {
    if (queryTimes.isEmpty) return 0;
    final sorted = List<int>.from(queryTimes)..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Get P95 query time
  int get p95QueryTime {
    if (queryTimes.isEmpty) return 0;
    final sorted = List<int>.from(queryTimes)..sort();
    final index = (sorted.length * 0.95).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Get success rate percentage
  double get successRate {
    if (totalQueries == 0) return 0;
    return (successfulQueries / totalQueries) * 100;
  }

  /// Get read/write ratio
  double get readWriteRatio {
    if (totalWrites == 0) return totalReads.toDouble();
    return totalReads / totalWrites;
  }

  Map<String, dynamic> toJson() => {
    'storageType': storageType.name,
    'totalQueries': totalQueries,
    'successfulQueries': successfulQueries,
    'failedQueries': failedQueries,
    'successRate': successRate.toStringAsFixed(2),
    'totalReads': totalReads,
    'totalWrites': totalWrites,
    'readWriteRatio': readWriteRatio.toStringAsFixed(2),
    'averageQueryTime': averageQueryTime.toStringAsFixed(2),
    'medianQueryTime': medianQueryTime,
    'p95QueryTime': p95QueryTime,
    'totalBytesRead': totalBytesRead,
    'totalBytesWritten': totalBytesWritten,
    if (firstQueryTime != null) 'firstQueryTime': firstQueryTime!.toIso8601String(),
    if (lastQueryTime != null) 'lastQueryTime': lastQueryTime!.toIso8601String(),
  };
}

/// Cache performance metrics
class CacheMetrics {
  int hits = 0;
  int misses = 0;
  int evictions = 0;
  int totalSize = 0;
  final List<int> accessTimes = [];

  /// Record a cache hit
  void recordHit(int accessTimeMs) {
    hits++;
    accessTimes.add(accessTimeMs);
  }

  /// Record a cache miss
  void recordMiss(int accessTimeMs) {
    misses++;
    accessTimes.add(accessTimeMs);
  }

  /// Record a cache eviction
  void recordEviction() {
    evictions++;
  }

  /// Get cache hit rate percentage
  double get hitRate {
    final total = hits + misses;
    if (total == 0) return 0;
    return (hits / total) * 100;
  }

  /// Get cache miss rate percentage
  double get missRate {
    final total = hits + misses;
    if (total == 0) return 0;
    return (misses / total) * 100;
  }

  /// Get average access time
  double get averageAccessTime {
    if (accessTimes.isEmpty) return 0;
    return accessTimes.reduce((a, b) => a + b) / accessTimes.length;
  }

  Map<String, dynamic> toJson() => {
    'hits': hits,
    'misses': misses,
    'evictions': evictions,
    'totalAccess': hits + misses,
    'hitRate': hitRate.toStringAsFixed(2),
    'missRate': missRate.toStringAsFixed(2),
    'averageAccessTime': averageAccessTime.toStringAsFixed(2),
    'totalSize': totalSize,
  };
}

/// Database performance monitor
class DatabasePerformanceMonitor {
  static final DatabasePerformanceMonitor _instance = DatabasePerformanceMonitor._();
  static DatabasePerformanceMonitor get instance => _instance;

  DatabasePerformanceMonitor._();

  final Map<String, QueryTiming> _activeQueries = {};
  final List<QueryTiming> _completedQueries = [];
  final Map<StorageType, StorageMetrics> _storageMetrics = {};
  final Map<String, CacheMetrics> _cacheMetrics = {};

  int _queryCounter = 0;
  bool _isEnabled = true;

  /// Start tracking a query
  String startQuery({
    required String queryName,
    required QueryOperation operation,
    required StorageType storageType,
    Map<String, dynamic>? metadata,
  }) {
    if (!_isEnabled) return '';

    final queryId = 'query_${++_queryCounter}_${DateTime.now().millisecondsSinceEpoch}';
    final timing = QueryTiming(
      queryId: queryId,
      queryName: queryName,
      operation: operation,
      storageType: storageType,
      startTime: DateTime.now(),
      metadata: metadata,
    );

    _activeQueries[queryId] = timing;

    LoggingService.instance.debug(
      'DBPerformanceMonitor',
      'Started tracking query: $queryName (${operation.name})',
      {'queryId': queryId, 'storageType': storageType.name},
    );

    return queryId;
  }

  /// Complete a query with success
  void completeQuery({
    required String queryId,
    int? recordsAffected,
    int? bytesRead,
    int? bytesWritten,
    Map<String, dynamic>? metadata,
  }) {
    final timing = _activeQueries.remove(queryId);
    if (timing == null) {
      LoggingService.instance.warning(
        'DBPerformanceMonitor',
        'Attempted to complete unknown query: $queryId',
      );
      return;
    }

    timing.endTime = DateTime.now();
    timing.isSuccess = true;
    timing.recordsAffected = recordsAffected;
    timing.bytesRead = bytesRead;
    timing.bytesWritten = bytesWritten;
    if (metadata != null) {
      timing.metadata = {...?timing.metadata, ...metadata};
    }

    _recordCompletedQuery(timing);
  }

  /// Mark a query as failed
  void failQuery({
    required String queryId,
    required String errorMessage,
  }) {
    final timing = _activeQueries.remove(queryId);
    if (timing == null) return;

    timing.endTime = DateTime.now();
    timing.isSuccess = false;
    timing.errorMessage = errorMessage;

    _recordCompletedQuery(timing);
  }

  /// Record a completed query
  void _recordCompletedQuery(QueryTiming timing) {
    _completedQueries.add(timing);

    // Maintain history size (keep last 500 queries)
    if (_completedQueries.length > 500) {
      _completedQueries.removeAt(0);
    }

    // Update storage metrics
    final metrics = _storageMetrics.putIfAbsent(
      timing.storageType,
      () => StorageMetrics(storageType: timing.storageType),
    );
    metrics.addQuery(timing);

    // Log slow queries
    if (timing.durationMs != null && timing.durationMs! > 100) {
      LoggingService.instance.warning(
        'DBPerformanceMonitor',
        'Slow query detected: ${timing.queryName}',
        {
          'queryId': timing.queryId,
          'durationMs': timing.durationMs,
          'operation': timing.operation.name,
          'storageType': timing.storageType.name,
        },
      );
    }
  }

  /// Record cache hit
  void recordCacheHit({
    required String cacheName,
    int accessTimeMs = 0,
  }) {
    if (!_isEnabled) return;

    final metrics = _cacheMetrics.putIfAbsent(
      cacheName,
      () => CacheMetrics(),
    );
    metrics.recordHit(accessTimeMs);

    LoggingService.instance.debug(
      'DBPerformanceMonitor',
      'Cache hit: $cacheName',
      {'accessTimeMs': accessTimeMs},
    );
  }

  /// Record cache miss
  void recordCacheMiss({
    required String cacheName,
    int accessTimeMs = 0,
  }) {
    if (!_isEnabled) return;

    final metrics = _cacheMetrics.putIfAbsent(
      cacheName,
      () => CacheMetrics(),
    );
    metrics.recordMiss(accessTimeMs);

    LoggingService.instance.debug(
      'DBPerformanceMonitor',
      'Cache miss: $cacheName',
      {'accessTimeMs': accessTimeMs},
    );
  }

  /// Record cache eviction
  void recordCacheEviction({
    required String cacheName,
  }) {
    if (!_isEnabled) return;

    final metrics = _cacheMetrics.putIfAbsent(
      cacheName,
      () => CacheMetrics(),
    );
    metrics.recordEviction();

    LoggingService.instance.debug(
      'DBPerformanceMonitor',
      'Cache eviction: $cacheName',
    );
  }

  /// Get metrics for a specific storage type
  StorageMetrics? getStorageMetrics(StorageType storageType) {
    return _storageMetrics[storageType];
  }

  /// Get cache metrics
  CacheMetrics? getCacheMetrics(String cacheName) {
    return _cacheMetrics[cacheName];
  }

  /// Get all storage metrics
  Map<StorageType, StorageMetrics> getAllStorageMetrics() {
    return Map.from(_storageMetrics);
  }

  /// Get all cache metrics
  Map<String, CacheMetrics> getAllCacheMetrics() {
    return Map.from(_cacheMetrics);
  }

  /// Get query history
  List<QueryTiming> getQueryHistory({Duration? timeWindow}) {
    if (timeWindow == null) {
      return List.from(_completedQueries);
    }

    final cutoff = DateTime.now().subtract(timeWindow);
    return _completedQueries
        .where((q) => q.startTime.isAfter(cutoff))
        .toList();
  }

  /// Get slowest queries
  List<QueryTiming> getSlowestQueries({int limit = 10, Duration? timeWindow}) {
    final queries = getQueryHistory(timeWindow: timeWindow);
    queries.sort((a, b) => (b.durationMs ?? 0).compareTo(a.durationMs ?? 0));
    return queries.take(limit).toList();
  }

  /// Generate performance report
  Map<String, dynamic> generateReport({Duration? timeWindow}) {
    final queries = getQueryHistory(timeWindow: timeWindow);

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'timeWindow': timeWindow?.inMinutes ?? 'all',
      'activeQueries': _activeQueries.length,
      'completedQueries': queries.length,
      'totalStorageTypes': _storageMetrics.length,
      'storageMetrics': _storageMetrics.values.map((m) => m.toJson()).toList(),
      'cacheMetrics': _cacheMetrics.entries
          .map((e) => {'cacheName': e.key, ...e.value.toJson()})
          .toList(),
      'slowestQueries': getSlowestQueries(limit: 10, timeWindow: timeWindow)
          .map((q) => q.toJson())
          .toList(),
      'performanceSummary': _generatePerformanceSummary(queries),
    };
  }

  /// Generate performance summary
  Map<String, dynamic> _generatePerformanceSummary(List<QueryTiming> queries) {
    if (queries.isEmpty) {
      return {
        'totalQueries': 0,
        'message': 'No queries in time window',
      };
    }

    final queryTimes = queries
        .where((q) => q.durationMs != null)
        .map((q) => q.durationMs!)
        .toList()
      ..sort();

    final successful = queries.where((q) => q.isSuccess).length;
    final failed = queries.where((q) => !q.isSuccess).length;

    return {
      'totalQueries': queries.length,
      'successfulQueries': successful,
      'failedQueries': failed,
      'successRate': (successful / queries.length * 100).toStringAsFixed(2),
      'averageQueryTime': queryTimes.isNotEmpty
          ? (queryTimes.reduce((a, b) => a + b) / queryTimes.length).toStringAsFixed(2)
          : '0',
      'medianQueryTime': queryTimes.isNotEmpty ? queryTimes[queryTimes.length ~/ 2] : 0,
      'p95QueryTime': queryTimes.isNotEmpty
          ? queryTimes[(queryTimes.length * 0.95).floor()]
          : 0,
      'p99QueryTime': queryTimes.isNotEmpty
          ? queryTimes[(queryTimes.length * 0.99).floor()]
          : 0,
    };
  }

  /// Clear all tracking data
  void clearHistory() {
    _completedQueries.clear();
    _storageMetrics.clear();
    _cacheMetrics.clear();
    LoggingService.instance.info('DBPerformanceMonitor', 'Query history cleared');
  }

  /// Enable/disable tracking
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    LoggingService.instance.info(
      'DBPerformanceMonitor',
      'Database performance monitoring ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Get monitoring status
  bool get isEnabled => _isEnabled;
}
