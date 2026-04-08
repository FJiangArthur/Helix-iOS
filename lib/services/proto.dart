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
  static const List<int> _dashboardHidePrefix = [0x26, 0x07, 0x00, 0x01, 0x02];

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

  /// Push screen command to both glasses independently.
  ///
  /// Unlike [pushScreen] which uses [BleManager.sendBoth] (short-circuits if L
  /// fails), this sends to each connected side independently so R still
  /// receives the command even when L times out.
  static Future<bool> pushScreenToConnectedSides(int screenId) {
    return _sendPushScreenToConnectedSides(
      data: Uint8List.fromList([0xf4, screenId]),
      leftConnected: BleManager.isConnectedL(),
      rightConnected: BleManager.isConnectedR(),
      requestSide: (lr, data, timeoutMs) =>
          BleManager.request(data, lr: lr, timeoutMs: timeoutMs),
    );
  }

  @visibleForTesting
  static Future<bool> pushScreenToConnectedSidesForTest({
    required int screenId,
    required bool leftConnected,
    required bool rightConnected,
    required Future<BleReceive> Function(
      String lr,
      Uint8List data,
      int timeoutMs,
    )
    requestSide,
  }) {
    return _sendPushScreenToConnectedSides(
      data: Uint8List.fromList([0xf4, screenId]),
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      requestSide: requestSide,
    );
  }

  static Future<bool> _sendPushScreenToConnectedSides({
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
      appLogger.d('pushScreenToConnectedSides skipped: no connected side');
      return false;
    }

    bool leftSuccess = false;
    if (leftConnected) {
      final retL = await requestSide("L", data, 300);
      leftSuccess = !retL.isTimeout &&
          retL.data.length > 1 &&
          retL.data[1] == 0xc9;
    }

    bool rightSuccess = false;
    if (rightConnected) {
      final retR = await requestSide("R", data, 300);
      rightSuccess = !retR.isTimeout &&
          retR.data.length > 1 &&
          retR.data[1] == 0xc9;
    }

    return BleTransportPolicy.didAllConnectedTargetsSucceed(
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      leftSuccess: leftSuccess,
      rightSuccess: rightSuccess,
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

    return _sendEvenAIDataPipeline(
      dataList: dataList,
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      timeoutMs: timeoutMs ?? 2000,
      requestSide: (packets, lr, ms) =>
          BleManager.requestList(packets, lr: lr, timeoutMs: ms),
    );
  }

  @visibleForTesting
  static const Duration evenAIInterSideDelay = Duration(milliseconds: 400);

  /// Test-visible variant of [sendEvenAIData] that lets a unit test inject a
  /// fake `requestSide` and observe the L→R ordering and inter-side delay.
  @visibleForTesting
  static Future<bool> sendEvenAIDataForTest({
    required List<Uint8List> dataList,
    required bool leftConnected,
    required bool rightConnected,
    int timeoutMs = 2000,
    required Future<bool> Function(List<Uint8List>, String, int) requestSide,
  }) {
    return _sendEvenAIDataPipeline(
      dataList: dataList,
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      timeoutMs: timeoutMs,
      requestSide: requestSide,
    );
  }

  static Future<bool> _sendEvenAIDataPipeline({
    required List<Uint8List> dataList,
    required bool leftConnected,
    required bool rightConnected,
    required int timeoutMs,
    required Future<bool> Function(List<Uint8List>, String, int) requestSide,
  }) async {
    bool isSuccessL = false;
    if (leftConnected) {
      isSuccessL = await requestSide(dataList, 'L', timeoutMs);
      if (!isSuccessL) {
        appLogger.d('sendEvenAIData failed L');
      }
    }

    if (leftConnected && rightConnected) {
      await Future<void>.delayed(evenAIInterSideDelay);
    }

    bool isSuccessR = false;
    if (rightConnected) {
      isSuccessR = await requestSide(dataList, 'R', timeoutMs);
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
        emitDeviceDiagnostic(
          'BitmapHUD',
          'heartbeat ack failed side=L timeout=${ret.isTimeout} dataLen=${ret.data.length}',
        );
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
        emitDeviceDiagnostic(
          'BitmapHUD',
          'heartbeat ack failed side=R timeout=${ret.isTimeout} dataLen=${ret.data.length}',
        );
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
    return _sendExitToConnectedSides(
      data: Uint8List.fromList([0x18]),
      leftConnected: BleManager.isConnectedL(),
      rightConnected: BleManager.isConnectedR(),
      requestSide: (lr, packet, timeoutMs) =>
          BleManager.request(packet, lr: lr, timeoutMs: timeoutMs),
    );
  }

  @visibleForTesting
  static Future<bool> exitForTest({
    required bool leftConnected,
    required bool rightConnected,
    required Future<BleReceive> Function(
      String lr,
      Uint8List data,
      int timeoutMs,
    )
    requestSide,
  }) {
    return _sendExitToConnectedSides(
      data: Uint8List.fromList([0x18]),
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      requestSide: requestSide,
    );
  }

  static Future<bool> _sendExitToConnectedSides({
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
    appLogger.d("send exit all func");

    if (!leftConnected && !rightConnected) {
      appLogger.d('${DateTime.now()} exit skipped: no connected side');
      return false;
    }

    bool leftSuccess = false;
    if (leftConnected) {
      final retL = await requestSide("L", data, 1500);
      appLogger.d('${DateTime.now()} exit----L----ret---${retL.data}--');
      leftSuccess = _isExitAck(retL);
    }

    bool rightSuccess = false;
    if (rightConnected) {
      final retR = await requestSide("R", data, 1500);
      appLogger.d('${DateTime.now()} exit----R----retR---${retR.data}--');
      rightSuccess = _isExitAck(retR);
    }

    return BleTransportPolicy.didAllConnectedTargetsSucceed(
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      leftSuccess: leftSuccess,
      rightSuccess: rightSuccess,
    );
  }

  static bool _isExitAck(BleReceive receive) {
    return !receive.isTimeout &&
        receive.data.length > 1 &&
        receive.data[1].toInt() == 0xc9;
  }

  // NOTE: Factory head-up dashboard suppression is not possible on the
  // current G1 firmware. We previously sent a 0x08 Head-Up Action / Global /
  // "Do Nothing" command on connect, per protocol research Section 11.3, but
  // device logs show the firmware ignores the write and replies with the
  // current action (0x00 = Show Dashboard) — i.e. on this firmware revision
  // 0x08/Global appears to be read-only. The factory dashboard always
  // renders briefly on head-up regardless. The only mitigation is to push
  // our bitmap fast enough to overwrite it.

  /// Clear the bitmap screen by sending 0x18 to both connected sides.
  ///
  /// Uses fire-and-forget [BleManager.sendData] instead of request/ACK to
  /// avoid the timeout that was blocking state recovery when using the
  /// request-based [exit] method.
  static Future<void> clearBitmapScreen({
    Duration interSideDelay = const Duration(milliseconds: 100),
  }) async {
    final data = Uint8List.fromList([0x18]);
    if (BleManager.isConnectedL()) {
      await BleManager.sendData(data, lr: 'L');
    }
    if (BleManager.isConnectedR()) {
      if (BleManager.isConnectedL() && interSideDelay > Duration.zero) {
        await Future<void>.delayed(interSideDelay);
      }
      await BleManager.sendData(data, lr: 'R');
    }
  }

  /// Hide the glasses dashboard overlay.
  ///
  /// This uses the dashboard visibility command observed in the community
  /// wrapper instead of the Even AI/text exit command.
  static Future<bool> hideDashboard({
    int position = 0,
    Duration interSideDelay = const Duration(milliseconds: 100),
  }) {
    return _sendDashboardVisibilityToConnectedSides(
      data: _buildDashboardVisibilityPacket(visible: false, position: position),
      leftConnected: BleManager.isConnectedL(),
      rightConnected: BleManager.isConnectedR(),
      sendSide: (lr, packet) => BleManager.sendData(packet, lr: lr),
      interSideDelay: interSideDelay,
    );
  }

  @visibleForTesting
  static Future<bool> hideDashboardForTest({
    required bool leftConnected,
    required bool rightConnected,
    required Future<void> Function(String lr, Uint8List data) sendSide,
    int position = 0,
    Duration interSideDelay = const Duration(milliseconds: 100),
  }) {
    return _sendDashboardVisibilityToConnectedSides(
      data: _buildDashboardVisibilityPacket(visible: false, position: position),
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      sendSide: sendSide,
      interSideDelay: interSideDelay,
    );
  }

  static Uint8List _buildDashboardVisibilityPacket({
    required bool visible,
    required int position,
  }) {
    return Uint8List.fromList([
      ..._dashboardHidePrefix,
      visible ? 0x01 : 0x00,
      position & 0xff,
    ]);
  }

  static Future<bool> _sendDashboardVisibilityToConnectedSides({
    required Uint8List data,
    required bool leftConnected,
    required bool rightConnected,
    required Future<void> Function(String lr, Uint8List data) sendSide,
    required Duration interSideDelay,
  }) async {
    if (!leftConnected && !rightConnected) {
      appLogger.d('${DateTime.now()} hideDashboard skipped: no connected side');
      return false;
    }

    var leftSuccess = false;
    if (leftConnected) {
      try {
        await sendSide('L', data);
        leftSuccess = true;
      } catch (e) {
        emitDeviceDiagnostic(
          'BitmapHUD',
          'dashboard hide send failed side=L exception=$e',
        );
      }
    }

    var rightSuccess = false;
    if (rightConnected) {
      if (leftConnected && interSideDelay > Duration.zero) {
        await Future<void>.delayed(interSideDelay);
      }
      try {
        await sendSide('R', data);
        rightSuccess = true;
      } catch (e) {
        emitDeviceDiagnostic(
          'BitmapHUD',
          'dashboard hide send failed side=R exception=$e',
        );
      }
    }

    return BleTransportPolicy.didAllConnectedTargetsSucceed(
      leftConnected: leftConnected,
      rightConnected: rightConnected,
      leftSuccess: leftSuccess,
      rightSuccess: rightSuccess,
    );
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
