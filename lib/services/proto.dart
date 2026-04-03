import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../ble_manager.dart';
import 'ble.dart';
import '../services/evenai_proto.dart';
import '../services/glasses_protocol.dart';
import '../utils/app_logger.dart';
import '../utils/utils.dart';

class Proto {
  static String lR() {
    if (BleManager.isConnectedR()) return "R";
    if (BleManager.isConnectedL()) return "L";
    return "L"; // default
  }

  static Future<bool> pushScreen(int screenId) async {
    return await BleManager.sendBoth(
      Uint8List.fromList([0xf4, screenId]),
      timeoutMs: 300,
      isSuccess: (res) => res[1] == 0xc9,
    );
  }

  /// Returns the time consumed by the command and whether it is successful
  static Future<(int, bool)> micOn({String? lr}) async {
    var begin = Utils.getTimestampMs();
    var data = Uint8List.fromList([0x0E, 0x01]);
    var receive = await BleManager.request(data, lr: lr);

    var end = Utils.getTimestampMs();
    var startMic = (begin + ((end - begin) ~/ 2));

    appLogger.d("Proto---micOn---startMic---$startMic-------");
    return (startMic, (!receive.isTimeout && receive.data[1] == 0xc9));
  }

  /// Even AI
  static int _evenaiSeq = 0;
  // AI result transmission (also compatible with AI startup and Q&A status synchronization)
  static Future<bool> sendEvenAIData(
    String text, {
    int? timeoutMs,
    required int newScreen,
    required int pos,
    required int current_page_num,
    required int max_page_num,
  }) async {
    var data = utf8.encode(text);
    var syncSeq = _evenaiSeq & 0xff;

    List<Uint8List> dataList = EvenaiProto.evenaiMultiPackListV2(
      0x4E,
      data: data,
      syncSeq: syncSeq,
      newScreen: newScreen,
      pos: pos,
      current_page_num: current_page_num,
      max_page_num: max_page_num,
    );
    _evenaiSeq++;

    final leftConnected = BleManager.isConnectedL();
    final rightConnected = BleManager.isConnectedR();
    if (!leftConnected && !rightConnected) {
      appLogger.d('sendEvenAIData skipped: no connected glasses side');
      return false;
    }

    appLogger.d(
      'proto--sendEvenAIData seq=$_evenaiSeq newScreen=$newScreen page=$current_page_num/$max_page_num textLen=${text.length}',
    );

    bool isSuccessL = false;
    if (leftConnected) {
      isSuccessL = await BleManager.requestList(
        dataList,
        lr: "L",
        timeoutMs: timeoutMs ?? 2000,
      );
      if (!isSuccessL) {
        appLogger.d('sendEvenAIData failed L');
      }
    }

    bool isSuccessR = false;
    if (rightConnected) {
      isSuccessR = await BleManager.requestList(
        dataList,
        lr: "R",
        timeoutMs: timeoutMs ?? 2000,
      );
      if (!isSuccessR) {
        appLogger.d('sendEvenAIData failed R');
      }
    }

    final success = BleTransportPolicy.didAllConnectedTargetsSucceed(
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      leftSuccess: isSuccessL,
      rightSuccess: isSuccessR,
    );
    if (!success) {
      appLogger.d(
        'sendEvenAIData failed required targets '
        '(leftConnected=$leftConnected leftSuccess=$isSuccessL '
        'rightConnected=$rightConnected rightSuccess=$isSuccessR)',
      );
    }
    return success;
  }

  static int _beatHeartSeq = 0;
  static Future<bool> sendHeartBeat() async {
    final data = _buildHeartBeatPacket();
    appLogger.d('${DateTime.now()} sendHeartBeat--------data---$data--');

    return _sendHeartBeatToConnectedSides(
      data: data,
      leftConnected: BleManager.isConnectedL(),
      rightConnected: BleManager.isConnectedR(),
      requestSide: (lr, packet, timeoutMs) =>
          BleManager.request(packet, lr: lr, timeoutMs: timeoutMs),
    );
  }

  @visibleForTesting
  static Future<bool> sendHeartBeatForTest({
    required bool leftConnected,
    required bool rightConnected,
    required Future<BleReceive> Function(
      String lr,
      Uint8List data,
      int timeoutMs,
    )
    requestSide,
  }) {
    return _sendHeartBeatToConnectedSides(
      data: _buildHeartBeatPacket(),
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      requestSide: requestSide,
    );
  }

  static Uint8List _buildHeartBeatPacket() {
    const length = 6;
    final data = Uint8List.fromList([
      0x25,
      length & 0xff,
      (length >> 8) & 0xff,
      _beatHeartSeq & 0xff,
      0x04,
      _beatHeartSeq & 0xff,
    ]);
    _beatHeartSeq++;
    return data;
  }

  static Future<bool> _sendHeartBeatToConnectedSides({
    required Uint8List data,
    required bool leftConnected,
    required bool rightConnected,
    required Future<BleReceive> Function(
      String lr,
      Uint8List data,
      int timeoutMs,
    )
    requestSide,
  }) async {
    if (!leftConnected && !rightConnected) {
      appLogger.d('${DateTime.now()} sendHeartBeat skipped: no connected side');
      return false;
    }

    bool leftSuccess = false;
    if (leftConnected) {
      final ret = await requestSide('L', data, 1500);
      appLogger.d(
        '${DateTime.now()} sendHeartBeat----L----ret---${ret.data}--',
      );
      leftSuccess = _isHeartbeatAck(ret);
      if (!leftSuccess) {
        appLogger.d('${DateTime.now()} sendHeartBeat----L----failed--');
      }
    }

    bool rightSuccess = false;
    if (rightConnected) {
      final ret = await requestSide('R', data, 1500);
      appLogger.d(
        '${DateTime.now()} sendHeartBeat----R----ret---${ret.data}--',
      );
      rightSuccess = _isHeartbeatAck(ret);
      if (!rightSuccess) {
        appLogger.d('${DateTime.now()} sendHeartBeat----R----failed--');
      }
    }

    return BleTransportPolicy.didAllConnectedTargetsSucceed(
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      leftSuccess: leftSuccess,
      rightSuccess: rightSuccess,
    );
  }

  static bool _isHeartbeatAck(BleReceive receive) {
    return !receive.isTimeout &&
        receive.data.length > 5 &&
        receive.data[0].toInt() == 0x25 &&
        receive.data[4].toInt() == 0x04;
  }

  static Future<String> getLegSn(String lr) async {
    var cmd = Uint8List.fromList([0x34]);
    var resp = await BleManager.request(cmd, lr: lr);
    if (resp.isTimeout || resp.data.length < 18) return '';
    var sn = String.fromCharCodes(resp.data.sublist(2, 18).toList());
    return sn;
  }

  // tell the glasses to exit function to dashboard
  static Future<bool> exit() async {
    appLogger.d("send exit all func");
    var data = Uint8List.fromList([0x18]);

    var retL = await BleManager.request(data, lr: "L", timeoutMs: 1500);
    appLogger.d('${DateTime.now()} exit----L----ret---${retL.data}--');
    if (retL.isTimeout) {
      return false;
    } else if (retL.data.isNotEmpty && retL.data[1].toInt() == 0xc9) {
      var retR = await BleManager.request(data, lr: "R", timeoutMs: 1500);
      appLogger.d('${DateTime.now()} exit----R----retR---${retR.data}--');
      if (retR.isTimeout) {
        return false;
      } else if (retR.data.isNotEmpty && retR.data[1].toInt() == 0xc9) {
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }

  static List<Uint8List> _getPackList(
    int cmd,
    Uint8List data, {
    int count = 20,
  }) {
    final realCount = count - 3;
    List<Uint8List> send = [];
    int maxSeq = data.length ~/ realCount;
    if (data.length % realCount > 0) {
      maxSeq++;
    }
    for (var seq = 0; seq < maxSeq; seq++) {
      var start = seq * realCount;
      var end = start + realCount;
      if (end > data.length) {
        end = data.length;
      }
      var itemData = data.sublist(start, end);
      var pack = Utils.addPrefixToUint8List([cmd, maxSeq, seq], itemData);
      send.add(pack);
    }
    return send;
  }

  static Future<void> sendNewAppWhiteListJson(String whitelistJson) async {
    appLogger.d("proto -> sendNewAppWhiteListJson: whitelist = $whitelistJson");
    final whitelistData = utf8.encode(whitelistJson);
    //  2、转换为接口格式
    final dataList = _getPackList(0x04, whitelistData, count: 180);
    appLogger.d(
      "proto -> sendNewAppWhiteListJson: length = ${dataList.length}, dataList = $dataList",
    );
    for (var i = 0; i < 3; i++) {
      final isSuccess = await BleManager.requestList(
        dataList,
        timeoutMs: 300,
        lr: "L",
      );
      if (isSuccess) {
        return;
      }
    }
  }

  /// 发送通知
  ///
  /// - app [Map] 通知消息数据
  static Future<void> sendNotify(Map appData, {int retry = 6}) async {
    final normalizedPayload = GlassesNotificationPayload.normalize(appData);
    final notifyJson = jsonEncode({"ncs_notification": normalizedPayload});
    final dataList = GlassesNotificationPackets.fromPayload(
      Uint8List.fromList(utf8.encode(notifyJson)),
    );
    appLogger.d(
      "proto -> sendNotify: data length = ${dataList.length}, data = $dataList, app = $notifyJson",
    );
    for (var i = 0; i < retry; i++) {
      final isSuccess = await BleManager.requestList(
        dataList,
        timeoutMs: 1000,
        lr: "L",
      );
      if (isSuccess) {
        return;
      }
    }
  }
}
