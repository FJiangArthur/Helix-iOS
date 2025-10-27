import 'dart:typed_data';
import '../ble_manager.dart';
import '../services/proto.dart';
import '../utils/utils.dart';

class FeaturesServices {
  // Simplified BMP update without controller
  Future<bool> updateBmp(String lr, Uint8List bmpData, {int seq = 0}) async {
    // TODO: Implement actual BMP update logic
    // For now, returning success
    // This would normally send the BMP data to glasses via BLE protocol
    return true;
  }

  Future<void> sendBmp(String imageUrl) async {
    Uint8List bmpData = await Utils.loadBmpImage(imageUrl);
    int initialSeq = 0;
    bool isSuccess = await Proto.sendHeartBeat();
    print(
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
      print("${DateTime.now()} left ble success");
    } else {
      print("${DateTime.now()} left ble fail");
    }

    if (successR) {
      print("${DateTime.now()} right ble success");
    } else {
      print("${DateTime.now()} right ble fail");
    }
  }

  Future<void> exitBmp() async {
    bool isSuccess = await Proto.exit();
    print("exitBmp----isSuccess---$isSuccess--");
  }
}