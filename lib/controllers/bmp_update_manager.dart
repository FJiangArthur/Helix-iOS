import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:crclib/catalog.dart';
import '../ble_manager.dart';
import '../services/ble.dart';
import '../services/bitmap_hud/delta_encoder.dart';
import '../services/proto.dart';
import '../utils/app_logger.dart';

/// Manages BMP image updates to G1 glasses following Even Demo protocol.
/// Fragments BMP data, sends chunks with CRC32 verification.
///
/// Supports both full sends and delta (incremental) sends for efficient updates.
class BmpUpdateManager {
  static const int _chunkSize = 194;
  static const int _cmdBmpData = 0x15;
  static const int _cmdBmpCrc = 0x16;
  static const int _cmdBmpComplete = 0x20;

  /// Default timeout per chunk for dashboard transfers (ms).
  /// 500ms allows for BLE write coalescing (200ms buffer) + transmission time.
  static const int _dashboardTimeoutMs = 500;

  /// Send BMP data to one side of the glasses (full send).
  /// Fragments into 194-byte chunks, sends CRC32 checksum, then completion signal.
  static Future<bool> updateBmp(
    String lr,
    Uint8List bmpData, {
    int timeoutMs = 500,
  }) async {
    final totalChunks = (bmpData.length + _chunkSize - 1) ~/ _chunkSize;
    for (int i = 0; i < totalChunks; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize).clamp(0, bmpData.length);
      final ok = await _sendChunk(
        lr,
        i,
        bmpData.sublist(start, end),
        timeoutMs,
      );
      if (!ok) return false;
    }
    return _sendCrcAndComplete(lr, bmpData);
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
    final chunks = DeltaEncoder.extractChunks(fullBmpData, changedIndices);
    for (final chunk in chunks) {
      final ok = await _sendChunk(lr, chunk.index, chunk.data, timeoutMs);
      if (!ok) return false;
    }
    return _sendCrcAndComplete(lr, fullBmpData);
  }

  /// Build and send a single data chunk packet with one retry on timeout.
  static Future<bool> _sendChunk(
    String lr,
    int index,
    Uint8List data,
    int timeoutMs,
  ) async {
    final packet = Uint8List(data.length + 3);
    packet[0] = _cmdBmpData;
    packet[1] = (index >> 8) & 0xff;
    packet[2] = index & 0xff;
    packet.setRange(3, 3 + data.length, data);
    var resp = await BleManager.request(packet, lr: lr, timeoutMs: timeoutMs);
    if (resp.isTimeout) {
      // Retry once on timeout
      resp = await BleManager.request(packet, lr: lr, timeoutMs: timeoutMs);
    }
    return !resp.isTimeout;
  }

  /// Send CRC32 checksum and completion signal.
  static Future<bool> _sendCrcAndComplete(String lr, Uint8List bmpData) async {
    // Calculate and send CRC32 (ISO-HDLC / XZ) checksum
    final crc = Crc32();
    int checksum = crc.convert(bmpData).toBigInt().toInt();

    Uint8List crcPacket = Uint8List(5);
    crcPacket[0] = _cmdBmpCrc;
    crcPacket[1] = (checksum >> 24) & 0xff;
    crcPacket[2] = (checksum >> 16) & 0xff;
    crcPacket[3] = (checksum >> 8) & 0xff;
    crcPacket[4] = checksum & 0xff;

    var crcResp = await BleManager.request(crcPacket, lr: lr, timeoutMs: 1000);
    if (crcResp.isTimeout) {
      return false;
    }

    // Send completion signal
    Uint8List completePacket = Uint8List.fromList([_cmdBmpComplete]);
    var completeResp = await BleManager.request(
      completePacket,
      lr: lr,
      timeoutMs: 1000,
    );
    return !completeResp.isTimeout;
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
        return false;
      }
      startHeartbeat();

      var leftSuccess = false;
      if (leftConnected) {
        leftSuccess = await sendSide('L');
        if (!leftSuccess) {
          appLogger.e('Bitmap HUD $label: L send failed');
        }
      }

      var rightSuccess = false;
      if (rightConnected) {
        rightSuccess = await sendSide('R');
        if (!rightSuccess) {
          appLogger.e('Bitmap HUD $label: R send failed');
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
        return false;
      }

      appLogger.d('Bitmap HUD $label: complete');
      return true;
    } catch (e) {
      appLogger.e('Bitmap HUD $label error: $e');
      return false;
    }
  }
}
