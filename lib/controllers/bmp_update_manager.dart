import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:crclib/catalog.dart';
import '../ble_manager.dart';
import '../services/ble.dart';
import '../services/bitmap_hud/delta_encoder.dart';
import '../services/proto.dart';
import '../utils/app_logger.dart';

typedef _BmpRequestSide =
    Future<BleReceive> Function(String lr, Uint8List packet, int timeoutMs);
typedef _BmpSendSide = Future<void> Function(String lr, Uint8List packet);

/// Manages BMP image updates to G1 glasses following Even Demo protocol.
/// Fragments BMP data, sends chunks with CRC32 verification.
///
/// Supports both full sends and delta (incremental) sends for efficient updates.
class BmpUpdateManager {
  static const int _chunkSize = 194;
  static const int _cmdBmpData = 0x15;
  static const int _cmdBmpCrc = 0x16;
  static const int _cmdBmpComplete = 0x20;
  static const List<int> _bmpStorageAddress = [0x00, 0x1c, 0x00, 0x00];
  static const List<int> _bmpCompletePayload = [0x20, 0x0d, 0x0e];
  static const int _iosChunkDelayMs = 8;
  static const int _defaultChunkDelayMs = 5;

  /// Default timeout per chunk for dashboard transfers (ms).
  /// 500ms allows for BLE write coalescing (200ms buffer) + transmission time.
  static const int _dashboardTimeoutMs = 500;

  /// Send BMP data to one side of the glasses (full send).
  /// Fragments into 194-byte chunks, streams them, then sends completion and CRC.
  static Future<bool> updateBmp(
    String lr,
    Uint8List bmpData, {
    int timeoutMs = 500,
  }) async {
    return _updateBmpTransfer(
      lr,
      bmpData,
      List<int>.generate(
        (bmpData.length + _chunkSize - 1) ~/ _chunkSize,
        (i) => i,
      ),
      timeoutMs: timeoutMs,
      sendSide: _sendBleSide,
      requestSide: _requestBleSide,
    );
  }

  /// Send only the changed chunks to one side of the glasses (delta send).
  ///
  /// [fullBmpData] is the complete new BMP (needed for CRC calculation).
  /// [changedIndices] are the chunk indices that differ from the previous frame.
  static Future<bool> updateBmpDelta(
    String lr,
    Uint8List fullBmpData,
    List<int> changedIndices, {
    int timeoutMs = _dashboardTimeoutMs,
  }) async {
    final sortedIndices = [...changedIndices]..sort();
    return _updateBmpTransfer(
      lr,
      fullBmpData,
      sortedIndices,
      timeoutMs: timeoutMs,
      sendSide: _sendBleSide,
      requestSide: _requestBleSide,
    );
  }

  @visibleForTesting
  static Future<bool> updateBmpForTest(
    String lr,
    Uint8List bmpData, {
    required _BmpSendSide sendSide,
    required _BmpRequestSide requestSide,
    int timeoutMs = 500,
  }) {
    return _updateBmpTransfer(
      lr,
      bmpData,
      List<int>.generate(
        (bmpData.length + _chunkSize - 1) ~/ _chunkSize,
        (i) => i,
      ),
      timeoutMs: timeoutMs,
      sendSide: sendSide,
      requestSide: requestSide,
    );
  }

  static Future<bool> _updateBmpTransfer(
    String lr,
    Uint8List fullBmpData,
    List<int> chunkIndices, {
    required int timeoutMs,
    required _BmpSendSide sendSide,
    required _BmpRequestSide requestSide,
  }) async {
    for (int sentIndex = 0; sentIndex < chunkIndices.length; sentIndex++) {
      final chunkIndex = chunkIndices[sentIndex];
      final start = chunkIndex * _chunkSize;
      final end = (start + _chunkSize).clamp(0, fullBmpData.length);
      final ok = await _streamChunk(
        lr,
        chunkIndex,
        fullBmpData.sublist(start, end),
        includeStorageAddress: sentIndex == 0,
        sendSide: sendSide,
      );
      if (!ok) return false;
    }
    return _sendCompleteAndCrc(
      lr,
      fullBmpData,
      timeoutMs: timeoutMs,
      requestSide: requestSide,
    );
  }

  /// Stream a single BMP data packet without waiting for a response.
  static Future<bool> _streamChunk(
    String lr,
    int index,
    Uint8List data, {
    required bool includeStorageAddress,
    required _BmpSendSide sendSide,
  }) async {
    final packet = _buildChunkPacket(
      index: index,
      data: data,
      includeStorageAddress: includeStorageAddress,
    );
    try {
      await sendSide(lr, packet);
      await Future.delayed(
        Duration(
          milliseconds: defaultTargetPlatform == TargetPlatform.iOS
              ? _iosChunkDelayMs
              : _defaultChunkDelayMs,
        ),
      );
      return true;
    } catch (e) {
      emitDeviceDiagnostic(
        'BitmapHUD',
        'chunk stream failed side=$lr index=$index bytes=${data.length} '
            'exception=$e',
      );
      return false;
    }
  }

  /// Send transfer-complete signal, then CRC32 checksum.
  static Future<bool> _sendCompleteAndCrc(
    String lr,
    Uint8List bmpData, {
    required int timeoutMs,
    required _BmpRequestSide requestSide,
  }) async {
    final completePacket = Uint8List.fromList(_bmpCompletePayload);
    final requestTimeoutMs = timeoutMs < 1000 ? 1000 : timeoutMs;
    final completeResp = await requestSide(
      lr,
      completePacket,
      requestTimeoutMs,
    );
    if (completeResp.isTimeout) {
      emitDeviceDiagnostic(
        'BitmapHUD',
        'complete timeout side=$lr bmpBytes=${bmpData.length}',
      );
      return false;
    }
    if (!_isCompleteAckSuccess(completeResp)) {
      emitDeviceDiagnostic(
        'BitmapHUD',
        'complete ack failed side=$lr bmpBytes=${bmpData.length} '
            'response=${completeResp.hexStringData()}',
      );
      return false;
    }

    final crcPacket = _buildCrcPacket(bmpData);
    final crcResp = await requestSide(lr, crcPacket, requestTimeoutMs);
    if (crcResp.isTimeout) {
      emitDeviceDiagnostic(
        'BitmapHUD',
        'crc timeout side=$lr bmpBytes=${bmpData.length}',
      );
      return false;
    }
    if (!_isCrcAckSuccess(crcResp)) {
      emitDeviceDiagnostic(
        'BitmapHUD',
        'crc ack failed side=$lr bmpBytes=${bmpData.length} '
            'response=${crcResp.hexStringData()}',
      );
      return false;
    }
    return true;
  }

  static Uint8List _buildChunkPacket({
    required int index,
    required Uint8List data,
    required bool includeStorageAddress,
  }) {
    final header = includeStorageAddress ? 6 : 2;
    final packet = Uint8List(data.length + header);
    packet[0] = _cmdBmpData;
    packet[1] = index & 0xff;
    var offset = 2;
    if (includeStorageAddress) {
      packet.setRange(
        offset,
        offset + _bmpStorageAddress.length,
        _bmpStorageAddress,
      );
      offset += _bmpStorageAddress.length;
    }
    packet.setRange(offset, offset + data.length, data);
    return packet;
  }

  static Uint8List _buildCrcPacket(Uint8List bmpData) {
    final crc = Crc32Xz();
    final crcInput = Uint8List.fromList([..._bmpStorageAddress, ...bmpData]);
    final checksum = crc.convert(crcInput).toBigInt().toInt();
    return Uint8List.fromList([
      _cmdBmpCrc,
      (checksum >> 24) & 0xff,
      (checksum >> 16) & 0xff,
      (checksum >> 8) & 0xff,
      checksum & 0xff,
    ]);
  }

  static bool _isCompleteAckSuccess(BleReceive receive) {
    return !receive.isTimeout &&
        receive.data.length >= 2 &&
        (receive.data[1] == 0xc9 || receive.data[1] == 0xcb);
  }

  static bool _isCrcAckSuccess(BleReceive receive) {
    if (receive.isTimeout) {
      return false;
    }
    if (receive.data.length >= 6) {
      return receive.data[5] == 0xc9 || receive.data[5] == 0xcb;
    }
    return receive.data.length >= 2 &&
        (receive.data[1] == 0xc9 || receive.data[1] == 0xcb);
  }

  static Future<BleReceive> _requestBleSide(
    String lr,
    Uint8List packet,
    int timeoutMs,
  ) {
    return BleManager.request(packet, lr: lr, timeoutMs: timeoutMs);
  }

  static Future<void> _sendBleSide(String lr, Uint8List packet) async {
    await BleManager.sendData(packet, lr: lr);
  }

  // --- High-level helpers for bitmap HUD ---

  /// Full BMP send to both glasses: heartbeat -> L -> R.
  static Future<bool> sendBitmapHud(Uint8List bmpData) {
    return _sendConnectedSides(
      label: 'full send',
      sendSide: (lr) => updateBmp(lr, bmpData, timeoutMs: _dashboardTimeoutMs),
      leftConnected: BleManager.isConnectedL(),
      rightConnected: BleManager.isConnectedR(),
      heartbeatSender: Proto.sendHeartBeat,
      startHeartbeat: BleManager.get().startSendBeatHeart,
    );
  }

  /// Delta BMP send to both glasses: only changed chunks.
  ///
  /// If delta fails on either side, returns false (caller should fall back to full send).
  static Future<bool> sendBitmapHudDelta(
    Uint8List newBmpData,
    List<int> changedIndices,
  ) {
    if (changedIndices.isEmpty) return Future.value(true);

    appLogger.d(
      'Bitmap HUD delta: sending ${changedIndices.length} changed chunks',
    );
    return _sendConnectedSides(
      label: 'delta',
      sendSide: (lr) => updateBmpDelta(lr, newBmpData, changedIndices),
      leftConnected: BleManager.isConnectedL(),
      rightConnected: BleManager.isConnectedR(),
      heartbeatSender: Proto.sendHeartBeat,
      startHeartbeat: BleManager.get().startSendBeatHeart,
    );
  }

  @visibleForTesting
  static Future<bool> sendConnectedSidesForTest({
    required String label,
    required bool leftConnected,
    required bool rightConnected,
    required Future<bool> Function() heartbeatSender,
    required void Function() startHeartbeat,
    required Future<bool> Function(String lr) sendSide,
  }) {
    return _sendConnectedSides(
      label: label,
      sendSide: sendSide,
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      heartbeatSender: heartbeatSender,
      startHeartbeat: startHeartbeat,
    );
  }

  /// Send a heartbeat, then transmit to whichever sides are currently connected.
  static Future<bool> _sendConnectedSides({
    required String label,
    required Future<bool> Function(String lr) sendSide,
    required bool leftConnected,
    required bool rightConnected,
    required Future<bool> Function() heartbeatSender,
    required void Function() startHeartbeat,
  }) async {
    try {
      if (!leftConnected && !rightConnected) {
        appLogger.d('Bitmap HUD $label skipped: no connected glasses side');
        return false;
      }

      final heartbeatOk = await heartbeatSender();
      if (!heartbeatOk) {
        appLogger.e('Bitmap HUD $label: heartbeat failed');
        emitDeviceDiagnostic('BitmapHUD', '$label heartbeat failed');
        return false;
      }
      startHeartbeat();

      var leftSuccess = false;
      if (leftConnected) {
        leftSuccess = await sendSide('L');
        if (!leftSuccess) {
          appLogger.e('Bitmap HUD $label: L send failed');
          emitDeviceDiagnostic('BitmapHUD', '$label left side send failed');
        }
      }

      var rightSuccess = false;
      if (rightConnected) {
        rightSuccess = await sendSide('R');
        if (!rightSuccess) {
          appLogger.e('Bitmap HUD $label: R send failed');
          emitDeviceDiagnostic('BitmapHUD', '$label right side send failed');
        }
      }

      final success = BleTransportPolicy.didAllConnectedTargetsSucceed(
        leftConnected: leftConnected,
        rightConnected: rightConnected,
        leftSuccess: leftSuccess,
        rightSuccess: rightSuccess,
      );
      if (!success) {
        appLogger.e(
          'Bitmap HUD $label failed required targets '
          '(leftConnected=$leftConnected leftSuccess=$leftSuccess '
          'rightConnected=$rightConnected rightSuccess=$rightSuccess)',
        );
        emitDeviceDiagnostic(
          'BitmapHUD',
          '$label required-target failure '
              'leftConnected=$leftConnected leftSuccess=$leftSuccess '
              'rightConnected=$rightConnected rightSuccess=$rightSuccess',
        );
        return false;
      }

      appLogger.d('Bitmap HUD $label: complete');
      return true;
    } catch (e) {
      appLogger.e('Bitmap HUD $label error: $e');
      emitDeviceDiagnostic('BitmapHUD', '$label exception=$e');
      return false;
    }
  }
}
