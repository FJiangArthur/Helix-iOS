import 'dart:typed_data';
import '../ble_manager.dart';
import '../services/proto.dart';
import '../utils/utils.dart';
import 'package:flutter_helix/utils/app_logger.dart';

class FeaturesServices {
  // BMP command code for glasses protocol (0x4C is commonly used for image data)
  static const int _bmpCmdCode = 0x4C;
  static const int _bmpPacketSize = 180; // Bytes per packet (adjust based on BLE MTU)

  // Send BMP image data to glasses via BLE
  Future<bool> updateBmp(String lr, Uint8List bmpData, {int seq = 0}) async {
    try {
      appLogger.i(
        'Sending BMP to $lr: ${bmpData.length} bytes, seq=$seq',
      );

      // Split BMP data into packets for BLE transmission
      final List<Uint8List> dataList = _getBmpPackList(
        _bmpCmdCode,
        bmpData,
        seq: seq,
      );

      appLogger.i(
        'BMP split into ${dataList.length} packets for transmission',
      );

      // Send all packets to the specified lens (L/R)
      final bool isSuccess = await BleManager.requestList(
        dataList,
        lr: lr,
        timeoutMs: 300, // 300ms timeout per packet
      );

      if (isSuccess) {
        appLogger.i('BMP update successful for $lr');
      } else {
        appLogger.w('BMP update failed for $lr');
      }

      return isSuccess;
    } catch (e) {
      appLogger.e('BMP update error for $lr', error: e);
      return false;
    }
  }

  // Split BMP data into BLE-compatible packets
  List<Uint8List> _getBmpPackList(
    int cmd,
    Uint8List data, {
    int seq = 0,
  }) {
    final List<Uint8List> send = [];
    final int realCount = _bmpPacketSize - 4; // Reserve 4 bytes for header

    int maxSeq = data.length ~/ realCount;
    if (data.length % realCount > 0) {
      maxSeq++;
    }

    for (var packetSeq = 0; packetSeq < maxSeq; packetSeq++) {
      var start = packetSeq * realCount;
      var end = start + realCount;
      if (end > data.length) {
        end = data.length;
      }

      var itemData = data.sublist(start, end);

      // Protocol: [CMD, SEQ, MAX_SEQ, PACKET_SEQ, ...DATA]
      var pack = Utils.addPrefixToUint8List(
        [cmd, seq, maxSeq, packetSeq],
        itemData,
      );

      send.add(pack);
    }

    return send;
  }

  Future<void> sendBmp(String imageUrl) async {
    Uint8List bmpData = await Utils.loadBmpImage(imageUrl);
    int initialSeq = 0;
    bool isSuccess = await Proto.sendHeartBeat();
    appLogger.i(
      "${DateTime.now()} testBMP -------startSendBeatHeart----isSuccess---$isSuccess------",
    );
    BleManager.get().startSendBeatHeart();

    final results = await Future.wait([
      updateBmp("L", bmpData, seq: initialSeq),
      updateBmp("R", bmpData, seq: initialSeq),
    ]);

    bool successL = results[0];
    bool successR = results[1];

    if (successL) {
      appLogger.i("${DateTime.now()} left ble success");
    } else {
      appLogger.i("${DateTime.now()} left ble fail");
    }

    if (successR) {
      appLogger.i("${DateTime.now()} right ble success");
    } else {
      appLogger.i("${DateTime.now()} right ble fail");
    }
  }

  Future<void> exitBmp() async {
    bool isSuccess = await Proto.exit();
    appLogger.i("exitBmp----isSuccess---$isSuccess--");
  }
}