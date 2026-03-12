import 'dart:typed_data';
import '../ble_manager.dart';
import '../controllers/bmp_update_manager.dart';
import '../services/proto.dart';
import '../utils/utils.dart';
import '../utils/app_logger.dart';

class FeaturesServices {
  Future<bool> updateBmp(String lr, Uint8List bmpData, {int seq = 0}) async {
    return await BmpUpdateManager.updateBmp(lr, bmpData);
  }

  Future<void> sendBmp(String imageUrl) async {
    Uint8List bmpData = await Utils.loadBmpImage(imageUrl);
    if (bmpData.isEmpty) {
      appLogger.e('Failed to load BMP image: $imageUrl');
      return;
    }

    bool isSuccess = await Proto.sendHeartBeat();
    appLogger.d('testBMP startSendBeatHeart isSuccess=$isSuccess');
    BleManager.get().startSendBeatHeart();

    // Send to left first, then right (sequential per Even Demo protocol)
    bool successL = await updateBmp("L", bmpData);
    if (successL) {
      appLogger.d('left BMP success');
    } else {
      appLogger.e('left BMP fail');
      return;
    }

    bool successR = await updateBmp("R", bmpData);
    if (successR) {
      appLogger.d('right BMP success');
    } else {
      appLogger.e('right BMP fail');
    }
  }

  Future<void> exitBmp() async {
    bool isSuccess = await Proto.exit();
    appLogger.d('exitBmp isSuccess=$isSuccess');
  }
}
