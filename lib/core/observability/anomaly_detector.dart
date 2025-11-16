// ABOUTME: Anomaly detection system for identifying unusual patterns in metrics
// ABOUTME: Uses statistical analysis and pattern recognition to detect anomalies

import 'dart:math' as math;
import 'observability_config.dart';
import '../utils/logging_service.dart';

/// Anomaly detection result
class AnomalyDetectionResult {
  final String metricName;
  final double value;
  final bool isAnomaly;
  final double confidenceScore;
  final String reason;
  final Map<String, dynamic> statistics;
  final DateTime detectedAt;

  AnomalyDetectionResult({
    required this.metricName,
    required this.value,
    required this.isAnomaly,
    required this.confidenceScore,
    required this.reason,
    required this.statistics,
  }) : detectedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
    'metricName': metricName,
    'value': value,
    'isAnomaly': isAnomaly,
    'confidenceScore': confidenceScore,
    'reason': reason,
    'statistics': statistics,
    'detectedAt': detectedAt.toIso8601String(),
  };
}

/// Time series data point
class DataPoint {
  final DateTime timestamp;
  final double value;
  final Map<String, dynamic>? metadata;

  DataPoint({
    required this.timestamp,
    required this.value,
    this.metadata,
  });
}

/// Anomaly detector using statistical methods
class AnomalyDetector {
  static final AnomalyDetector _instance = AnomalyDetector._();
  static AnomalyDetector get instance => _instance;

  AnomalyDetector._();

  // Time series data storage
  final Map<String, List<DataPoint>> _timeSeries = {};

  // Baseline statistics
  final Map<String, Map<String, double>> _baselineStats = {};

  // Anomaly detection config
  AnomalyDetectionConfig get _config =>
      ObservabilityConfig.instance.anomalyConfig;

  /// Record metric value
  void recordMetric({
    required String metricName,
    required double value,
    Map<String, dynamic>? metadata,
  }) {
    if (!ObservabilityConfig.instance.anomalyDetectionEnabled) return;

    final dataPoint = DataPoint(
      timestamp: DateTime.now(),
      value: value,
      metadata: metadata,
    );

    if (!_timeSeries.containsKey(metricName)) {
      _timeSeries[metricName] = [];
    }

    _timeSeries[metricName]!.add(dataPoint);

    // Maintain data retention (keep last 24 hours)
    _cleanupOldData(metricName);

    // Update baseline statistics
    _updateBaseline(metricName);
  }

  /// Detect anomalies in recent data
  AnomalyDetectionResult? detectAnomaly({
    required String metricName,
    required double currentValue,
  }) {
    if (!_config.detectUsageAnomalies) return null;

    final data = _timeSeries[metricName];
    if (data == null || data.length < _config.minimumDataPoints) {
      return AnomalyDetectionResult(
        metricName: metricName,
        value: currentValue,
        isAnomaly: false,
        confidenceScore: 0.0,
        reason: 'Insufficient data for anomaly detection',
        statistics: {},
      );
    }

    // Run multiple detection algorithms
    final results = [
      _detectStatisticalAnomaly(metricName, currentValue, data),
      _detectSuddenSpike(metricName, currentValue, data),
      _detectTrendAnomaly(metricName, currentValue, data),
    ];

    // Combine results
    final anomalyResults = results.where((r) => r.isAnomaly).toList();

    if (anomalyResults.isEmpty) {
      return AnomalyDetectionResult(
        metricName: metricName,
        value: currentValue,
        isAnomaly: false,
        confidenceScore: 0.0,
        reason: 'No anomalies detected',
        statistics: _baselineStats[metricName] ?? {},
      );
    }

    // Return highest confidence anomaly
    anomalyResults.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    return anomalyResults.first;
  }

  /// Statistical anomaly detection (Z-score method)
  AnomalyDetectionResult _detectStatisticalAnomaly(
    String metricName,
    double currentValue,
    List<DataPoint> data,
  ) {
    final stats = _calculateStatistics(data);
    final mean = stats['mean']!;
    final stdDev = stats['stdDev']!;

    if (stdDev == 0) {
      return AnomalyDetectionResult(
        metricName: metricName,
        value: currentValue,
        isAnomaly: false,
        confidenceScore: 0.0,
        reason: 'Zero variance in data',
        statistics: stats,
      );
    }

    final zScore = ((currentValue - mean) / stdDev).abs();
    final isAnomaly = zScore > _config.standardDeviationThreshold;

    return AnomalyDetectionResult(
      metricName: metricName,
      value: currentValue,
      isAnomaly: isAnomaly,
      confidenceScore: isAnomaly ? math.min(zScore / 3.0, 1.0) : 0.0,
      reason: isAnomaly
          ? 'Value deviates ${zScore.toStringAsFixed(2)} standard deviations from mean'
          : 'Within normal range',
      statistics: {
        ...stats,
        'zScore': zScore,
        'threshold': _config.standardDeviationThreshold,
      },
    );
  }

  /// Detect sudden spikes
  AnomalyDetectionResult _detectSuddenSpike(
    String metricName,
    double currentValue,
    List<DataPoint> data,
  ) {
    if (data.length < 2) {
      return AnomalyDetectionResult(
        metricName: metricName,
        value: currentValue,
        isAnomaly: false,
        confidenceScore: 0.0,
        reason: 'Insufficient data for spike detection',
        statistics: {},
      );
    }

    // Get recent average (last 5 data points or all if less)
    final recentCount = math.min(5, data.length - 1);
    final recentData = data.sublist(data.length - recentCount - 1, data.length - 1);
    final recentAvg = recentData.fold<double>(0, (sum, dp) => sum + dp.value) / recentCount;

    if (recentAvg == 0) {
      return AnomalyDetectionResult(
        metricName: metricName,
        value: currentValue,
        isAnomaly: false,
        confidenceScore: 0.0,
        reason: 'Zero baseline for spike detection',
        statistics: {'recentAvg': recentAvg},
      );
    }

    final spikeRatio = currentValue / recentAvg;
    final isSpike = spikeRatio > _config.suddenSpikeThreshold;

    return AnomalyDetectionResult(
      metricName: metricName,
      value: currentValue,
      isAnomaly: isSpike,
      confidenceScore: isSpike ? math.min((spikeRatio - 1.0) / 2.0, 1.0) : 0.0,
      reason: isSpike
          ? 'Sudden spike: ${spikeRatio.toStringAsFixed(2)}x recent average'
          : 'No sudden spike detected',
      statistics: {
        'recentAvg': recentAvg,
        'spikeRatio': spikeRatio,
        'threshold': _config.suddenSpikeThreshold,
      },
    );
  }

  /// Detect trend anomalies
  AnomalyDetectionResult _detectTrendAnomaly(
    String metricName,
    double currentValue,
    List<DataPoint> data,
  ) {
    if (data.length < _config.minimumDataPoints) {
      return AnomalyDetectionResult(
        metricName: metricName,
        value: currentValue,
        isAnomaly: false,
        confidenceScore: 0.0,
        reason: 'Insufficient data for trend analysis',
        statistics: {},
      );
    }

    // Calculate linear regression trend
    final trend = _calculateTrend(data);
    final expectedValue = trend['predicted']!;
    final deviation = (currentValue - expectedValue).abs();
    final avgDeviation = trend['avgDeviation']!;

    final isAnomaly = deviation > avgDeviation * 2;

    return AnomalyDetectionResult(
      metricName: metricName,
      value: currentValue,
      isAnomaly: isAnomaly,
      confidenceScore: isAnomaly ? math.min(deviation / (avgDeviation * 3), 1.0) : 0.0,
      reason: isAnomaly
          ? 'Deviates from trend by ${deviation.toStringAsFixed(2)}'
          : 'Following expected trend',
      statistics: {
        'expectedValue': expectedValue,
        'deviation': deviation,
        'avgDeviation': avgDeviation,
        'slope': trend['slope'],
      },
    );
  }

  /// Calculate statistics for a dataset
  Map<String, double> _calculateStatistics(List<DataPoint> data) {
    if (data.isEmpty) {
      return {'mean': 0, 'stdDev': 0, 'min': 0, 'max': 0};
    }

    final values = data.map((dp) => dp.value).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;

    final variance = values
        .map((v) => math.pow(v - mean, 2))
        .reduce((a, b) => a + b) / values.length;
    final stdDev = math.sqrt(variance);

    values.sort();
    final min = values.first;
    final max = values.last;
    final median = values.length.isOdd
        ? values[values.length ~/ 2]
        : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2;

    final p95Index = (values.length * 0.95).floor();
    final p95 = values[p95Index];

    return {
      'mean': mean,
      'stdDev': stdDev,
      'min': min,
      'max': max,
      'median': median,
      'p95': p95,
    };
  }

  /// Calculate trend using simple linear regression
  Map<String, double> _calculateTrend(List<DataPoint> data) {
    final n = data.length;
    var sumX = 0.0;
    var sumY = 0.0;
    var sumXY = 0.0;
    var sumX2 = 0.0;

    for (var i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = data[i].value;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // Predict next value
    final predicted = slope * n + intercept;

    // Calculate average deviation from trend line
    var deviationSum = 0.0;
    for (var i = 0; i < n; i++) {
      final expectedY = slope * i + intercept;
      deviationSum += (data[i].value - expectedY).abs();
    }
    final avgDeviation = deviationSum / n;

    return {
      'slope': slope,
      'intercept': intercept,
      'predicted': predicted,
      'avgDeviation': avgDeviation,
    };
  }

  /// Update baseline statistics
  void _updateBaseline(String metricName) {
    final data = _timeSeries[metricName];
    if (data == null || data.isEmpty) return;

    _baselineStats[metricName] = _calculateStatistics(data);
  }

  /// Clean up old data
  void _cleanupOldData(String metricName) {
    final data = _timeSeries[metricName];
    if (data == null) return;

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    data.removeWhere((dp) => dp.timestamp.isBefore(cutoff));
  }

  /// Detect usage pattern anomalies
  List<AnomalyDetectionResult> detectUsageAnomalies({
    required Duration timeWindow,
  }) {
    final anomalies = <AnomalyDetectionResult>[];

    for (final entry in _timeSeries.entries) {
      final metricName = entry.key;
      final data = entry.value;

      if (data.isEmpty) continue;

      // Check last value against historical pattern
      final lastValue = data.last.value;
      final result = detectAnomaly(
        metricName: metricName,
        currentValue: lastValue,
      );

      if (result != null && result.isAnomaly) {
        anomalies.add(result);

        LoggingService.instance.warning(
          'AnomalyDetector',
          'Anomaly detected in $metricName',
          result.toJson(),
        );
      }
    }

    return anomalies;
  }

  /// Get baseline statistics for a metric
  Map<String, double>? getBaseline(String metricName) {
    return _baselineStats[metricName];
  }

  /// Get time series data for a metric
  List<DataPoint> getTimeSeries(String metricName, {Duration? timeWindow}) {
    final data = _timeSeries[metricName];
    if (data == null) return [];

    if (timeWindow == null) return List.from(data);

    final cutoff = DateTime.now().subtract(timeWindow);
    return data.where((dp) => dp.timestamp.isAfter(cutoff)).toList();
  }

  /// Export anomaly detection report
  Map<String, dynamic> generateReport({Duration? timeWindow}) {
    final window = timeWindow ?? const Duration(hours: 1);
    final anomalies = <String, List<Map<String, dynamic>>>{};

    for (final entry in _timeSeries.entries) {
      final metricName = entry.key;
      final recentData = getTimeSeries(metricName, timeWindow: window);

      if (recentData.isEmpty) continue;

      final metricAnomalies = <Map<String, dynamic>>[];
      for (final dp in recentData) {
        final result = detectAnomaly(
          metricName: metricName,
          currentValue: dp.value,
        );

        if (result != null && result.isAnomaly) {
          metricAnomalies.add(result.toJson());
        }
      }

      if (metricAnomalies.isNotEmpty) {
        anomalies[metricName] = metricAnomalies;
      }
    }

    return {
      'timeWindow': '${window.inHours}h',
      'generatedAt': DateTime.now().toIso8601String(),
      'totalMetrics': _timeSeries.length,
      'metricsWithAnomalies': anomalies.length,
      'anomalies': anomalies,
      'baselineStatistics': _baselineStats,
    };
  }

  /// Clear all data
  void clear() {
    _timeSeries.clear();
    _baselineStats.clear();
    LoggingService.instance.info('AnomalyDetector', 'All data cleared');
  }
}
