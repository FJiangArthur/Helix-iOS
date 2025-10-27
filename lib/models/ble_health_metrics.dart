import 'package:freezed_annotation/freezed_annotation.dart';

part 'ble_health_metrics.freezed.dart';
part 'ble_health_metrics.g.dart';

/// BLE connection health metrics
@freezed
class BleHealthMetrics with _$BleHealthMetrics {
  const factory BleHealthMetrics({
    @Default(0) int successCount,
    @Default(0) int timeoutCount,
    @Default(0) int retryCount,
    @Default(0) int errorCount,
    @Default(Duration.zero) Duration avgLatency,
    @Default(Duration.zero) Duration totalLatency,
  }) = _BleHealthMetrics;

  const BleHealthMetrics._();

  factory BleHealthMetrics.fromJson(Map<String, dynamic> json) =>
      _$BleHealthMetricsFromJson(json);

  /// Calculate success rate (0.0 - 1.0)
  double get successRate {
    final total = successCount + timeoutCount + errorCount;
    if (total == 0) return 0.0;
    return successCount / total;
  }

  /// Calculate average latency in milliseconds
  int get avgLatencyMs {
    if (successCount == 0) return 0;
    return totalLatency.inMilliseconds ~/ successCount;
  }

  /// Record a successful transaction
  BleHealthMetrics recordSuccess(Duration latency) {
    return copyWith(
      successCount: successCount + 1,
      totalLatency: totalLatency + latency,
      avgLatency: Duration(
        milliseconds: (totalLatency + latency).inMilliseconds ~/ (successCount + 1),
      ),
    );
  }

  /// Record a timeout
  BleHealthMetrics recordTimeout() {
    return copyWith(
      timeoutCount: timeoutCount + 1,
    );
  }

  /// Record a retry attempt
  BleHealthMetrics recordRetry() {
    return copyWith(
      retryCount: retryCount + 1,
    );
  }

  /// Record an error
  BleHealthMetrics recordError() {
    return copyWith(
      errorCount: errorCount + 1,
    );
  }

  /// Reset all metrics
  BleHealthMetrics reset() {
    return const BleHealthMetrics();
  }

  /// Get metrics summary as a map
  Map<String, dynamic> toSummary() {
    return {
      'successRate': (successRate * 100).toStringAsFixed(1) + '%',
      'avgLatency': '${avgLatencyMs}ms',
      'totalTransactions': successCount + timeoutCount + errorCount,
      'successful': successCount,
      'timeouts': timeoutCount,
      'retries': retryCount,
      'errors': errorCount,
    };
  }
}
