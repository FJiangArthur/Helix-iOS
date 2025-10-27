import 'dart:async';
import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../ble_manager.dart';
import '../services/ble.dart';

part 'ble_transaction.freezed.dart';

/// BLE transaction model for managing request/response/timeout
/// Note: JSON serialization disabled due to complex types (Uint8List, BleReceive)
@Freezed(toJson: false, fromJson: false)
class BleTransaction with _$BleTransaction {
  const factory BleTransaction({
    required String id,
    required Uint8List command,
    required String target, // 'L', 'R', or 'BOTH'
    @Default(Duration(milliseconds: 1000)) Duration timeout,
    int? retryCount,
  }) = _BleTransaction;

  const BleTransaction._();

  /// Execute the transaction with retry logic
  Future<BleTransactionResult> execute() async {
    final startTime = DateTime.now();

    try {
      final response = await _sendWithTimeout();

      return BleTransactionResult.success(
        transaction: this,
        response: response,
        duration: DateTime.now().difference(startTime),
      );
    } on TimeoutException {
      if (retryCount != null && retryCount! > 0) {
        // Retry with decremented retry count
        return copyWith(retryCount: retryCount! - 1).execute();
      }

      return BleTransactionResult.timeout(
        transaction: this,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return BleTransactionResult.error(
        transaction: this,
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Send command with timeout
  Future<BleReceive> _sendWithTimeout() async {
    return await BleManager.request(
      command,
      lr: target == 'BOTH' ? null : target,
      timeoutMs: timeout.inMilliseconds,
    );
  }
}

/// Result of a BLE transaction
@Freezed(toJson: false, fromJson: false)
class BleTransactionResult with _$BleTransactionResult {
  const factory BleTransactionResult.success({
    required BleTransaction transaction,
    required BleReceive response,
    required Duration duration,
  }) = BleTransactionSuccess;

  const factory BleTransactionResult.timeout({
    required BleTransaction transaction,
    required Duration duration,
  }) = BleTransactionTimeout;

  const factory BleTransactionResult.error({
    required BleTransaction transaction,
    required String error,
    required Duration duration,
  }) = BleTransactionError;

  const BleTransactionResult._();

  /// Check if transaction was successful
  bool get isSuccess => this is BleTransactionSuccess;

  /// Check if transaction timed out
  bool get isTimeout => this is BleTransactionTimeout;

  /// Check if transaction had an error
  bool get isError => this is BleTransactionError;
}
