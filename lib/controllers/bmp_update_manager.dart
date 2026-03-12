import 'dart:typed_data';
import 'package:crclib/catalog.dart';
import '../ble_manager.dart';

/// Manages BMP image updates to G1 glasses following Even Demo protocol.
/// Fragments BMP data, sends chunks with CRC32 verification.
class BmpUpdateManager {
  static const int _chunkSize = 194;
  static const int _cmdBmpData = 0x15;
  static const int _cmdBmpCrc = 0x16;
  static const int _cmdBmpComplete = 0x20;

  /// Send BMP data to one side of the glasses.
  /// Fragments into 194-byte chunks, sends CRC32 checksum, then completion signal.
  static Future<bool> updateBmp(String lr, Uint8List bmpData) async {
    // Fragment and send chunks
    int totalChunks = (bmpData.length + _chunkSize - 1) ~/ _chunkSize;
    for (int i = 0; i < totalChunks; i++) {
      int start = i * _chunkSize;
      int end = start + _chunkSize;
      if (end > bmpData.length) end = bmpData.length;

      Uint8List chunk = bmpData.sublist(start, end);

      // Prepend command byte and chunk index (2 bytes big-endian)
      Uint8List packet = Uint8List(chunk.length + 3);
      packet[0] = _cmdBmpData;
      packet[1] = (i >> 8) & 0xff;
      packet[2] = i & 0xff;
      packet.setRange(3, 3 + chunk.length, chunk);

      var resp = await BleManager.request(packet, lr: lr, timeoutMs: 500);
      if (resp.isTimeout) {
        return false;
      }
    }

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
    var completeResp = await BleManager.request(completePacket, lr: lr, timeoutMs: 1000);
    return !completeResp.isTimeout;
  }
}
