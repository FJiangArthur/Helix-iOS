import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/models/ble_transaction.dart';
import 'package:flutter_helix/services/ble.dart';

void main() {
  group('BleTransaction', () {
    test('creates transaction with required fields', () {
      final transaction = BleTransaction(
        id: 'test-1',
        command: Uint8List.fromList([0x01, 0x02]),
        target: 'L',
      );

      expect(transaction.id, 'test-1');
      expect(transaction.command, [0x01, 0x02]);
      expect(transaction.target, 'L');
      expect(transaction.timeout, const Duration(milliseconds: 1000));
      expect(transaction.retryCount, null);
    });

    test('creates transaction with custom timeout', () {
      final transaction = BleTransaction(
        id: 'test-2',
        command: Uint8List.fromList([0x0E]),
        target: 'BOTH',
        timeout: const Duration(milliseconds: 500),
      );

      expect(transaction.timeout, const Duration(milliseconds: 500));
    });

    test('creates transaction with retry count', () {
      final transaction = BleTransaction(
        id: 'test-3',
        command: Uint8List.fromList([0xF5]),
        target: 'R',
        retryCount: 3,
      );

      expect(transaction.retryCount, 3);
    });

    test('copyWith decrements retry count', () {
      final transaction = BleTransaction(
        id: 'test-4',
        command: Uint8List.fromList([0x25]),
        target: 'L',
        retryCount: 2,
      );

      final retried = transaction.copyWith(retryCount: transaction.retryCount! - 1);
      expect(retried.retryCount, 1);
    });
  });

  group('BleTransactionResult', () {
    test('creates success result', () {
      final transaction = BleTransaction(
        id: 'success-test',
        command: Uint8List.fromList([0x01]),
        target: 'L',
      );

      final response = BleReceive();
      response.lr = 'L';
      response.data = Uint8List.fromList([0xC9]);
      response.type = 'response';

      final result = BleTransactionResult.success(
        transaction: transaction,
        response: response,
        duration: const Duration(milliseconds: 100),
      );

      expect(result.isSuccess, true);
      expect(result.isTimeout, false);
      expect(result.isError, false);
    });

    test('creates timeout result', () {
      final transaction = BleTransaction(
        id: 'timeout-test',
        command: Uint8List.fromList([0x02]),
        target: 'R',
      );

      final result = BleTransactionResult.timeout(
        transaction: transaction,
        duration: const Duration(milliseconds: 1000),
      );

      expect(result.isSuccess, false);
      expect(result.isTimeout, true);
      expect(result.isError, false);
    });

    test('creates error result', () {
      final transaction = BleTransaction(
        id: 'error-test',
        command: Uint8List.fromList([0x03]),
        target: 'BOTH',
      );

      final result = BleTransactionResult.error(
        transaction: transaction,
        error: 'Connection lost',
        duration: const Duration(milliseconds: 50),
      );

      expect(result.isSuccess, false);
      expect(result.isTimeout, false);
      expect(result.isError, true);
    });
  });
}
