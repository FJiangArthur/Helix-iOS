import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'services/ble.dart';
import 'services/evenai.dart';
import 'services/proto.dart';
import 'services/app.dart';
import 'utils/app_logger.dart';
import 'models/ble_health_metrics.dart';

typedef SendResultParse = bool Function(Uint8List value);

class BleManager {
  Function()? onStatusChanged;
  BleManager._() {}

  static BleManager? _instance;
  static BleManager get() {
    if (_instance == null) {
      _instance ??= BleManager._();
    }
    return _instance!;
  }

  static const methodSend = "send";
  static const _eventBleReceive = "eventBleReceive";
  static const _channel = MethodChannel('method.bluetooth');

  final eventBleReceive = const EventChannel(_eventBleReceive)
      .receiveBroadcastStream(_eventBleReceive)
      .map((ret) => BleReceive.fromMap(ret));

  Timer? beatHeartTimer;

  final List<Map<String, String>> pairedGlasses = [];
  bool isConnected = false;
  String connectionStatus = 'Not connected';

  // Health metrics tracking
  BleHealthMetrics _healthMetrics = const BleHealthMetrics();

  // Transaction history (keep last 100 transactions)
  final List<Map<String, dynamic>> _transactionHistory = [];
  static const int _maxHistorySize = 100;

  /// Get current health metrics
  BleHealthMetrics getHealthMetrics() => _healthMetrics;

  /// Reset health metrics
  void resetHealthMetrics() {
    _healthMetrics = _healthMetrics.reset();
  }

  /// Get health metrics summary
  Map<String, dynamic> getHealthSummary() {
    return _healthMetrics.toSummary();
  }

  /// Get transaction history
  List<Map<String, dynamic>> getTransactionHistory() {
    return List.unmodifiable(_transactionHistory);
  }

  /// Clear transaction history
  void clearTransactionHistory() {
    _transactionHistory.clear();
  }

  /// Record a transaction in history
  void _recordTransaction({
    required String command,
    required String target,
    required bool isSuccess,
    Duration? latency,
    String? error,
  }) {
    final record = {
      'timestamp': DateTime.now().toIso8601String(),
      'command': command,
      'target': target,
      'isSuccess': isSuccess,
      'latency': latency?.inMilliseconds,
      'error': error,
    };

    _transactionHistory.add(record);

    // Keep only last N transactions
    if (_transactionHistory.length > _maxHistorySize) {
      _transactionHistory.removeAt(0);
    }
  }

  void startListening() {
    eventBleReceive.listen((res) {
      _handleReceivedData(res);
    });
  }

  Future<void> startScan() async {
    try {
      await _channel.invokeMethod('startScan');
    } catch (e) {
      appLogger.e('Error starting scan', error: e);
    }
  }

  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } catch (e) {
      appLogger.e('Error stopping scan', error: e);
    }
  }

  Future<void> connectToGlasses(String deviceName) async {
    try {
      await _channel.invokeMethod('connectToGlasses', {
        'deviceName': deviceName,
      });
      connectionStatus = 'Connecting...';
    } catch (e) {
      appLogger.i('Error connecting to device: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      stopSendBeatHeart();
      await _channel.invokeMethod('disconnect');
      _onGlassesDisconnected();
    } catch (e) {
      appLogger.i('Error disconnecting: $e');
    }
  }

  void setMethodCallHandler() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  Future<void> _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'glassesConnected':
        _onGlassesConnected(call.arguments);
        break;
      case 'glassesConnecting':
        _onGlassesConnecting();
        break;
      case 'glassesDisconnected':
        _onGlassesDisconnected();
        break;
      case 'foundPairedGlasses':
        _onPairedGlassesFound(Map<String, String>.from(call.arguments));
        break;
      default:
        appLogger.i('Unknown method: ${call.method}');
    }
  }

  void _onGlassesConnected(dynamic arguments) {
    appLogger.i("_onGlassesConnected----arguments----$arguments------");
    connectionStatus =
        'Connected: \n${arguments['leftDeviceName']} \n${arguments['rightDeviceName']}';
    isConnected = true;

    onStatusChanged?.call();
    startSendBeatHeart();
  }

  int tryTime = 0;
  void startSendBeatHeart() async {
    beatHeartTimer?.cancel();
    beatHeartTimer = null;

    beatHeartTimer = Timer.periodic(Duration(seconds: 8), (timer) async {
      bool isSuccess = await Proto.sendHeartBeat();
      if (!isSuccess && tryTime < 2) {
        tryTime++;
        await Proto.sendHeartBeat();
      } else {
        tryTime = 0;
      }
    });
  }

  void stopSendBeatHeart() {
    beatHeartTimer?.cancel();
    beatHeartTimer = null;
    tryTime = 0;
  }

  void _onGlassesConnecting() {
    connectionStatus = 'Connecting...';

    onStatusChanged?.call();
  }

  void _onGlassesDisconnected() {
    connectionStatus = 'Not connected';
    isConnected = false;

    onStatusChanged?.call();
  }

  void _onPairedGlassesFound(Map<String, String> deviceInfo) {
    final String channelNumber = deviceInfo['channelNumber']!;
    final isAlreadyPaired = pairedGlasses.any(
      (glasses) => glasses['channelNumber'] == channelNumber,
    );

    if (!isAlreadyPaired) {
      pairedGlasses.add(deviceInfo);
    }

    onStatusChanged?.call();
  }

  void _handleReceivedData(BleReceive res) {
    if (res.type == "VoiceChunk") {
      // Voice chunks are processed natively in iOS/Android
      // Speech recognition results come through the eventSpeechRecognize channel
      return;
    }

    String cmd = "${res.lr}${res.getCmd().toRadixString(16).padLeft(2, '0')}";
    if (res.getCmd() != 0xf1) {
      appLogger.i(
        "${DateTime.now()} BleManager receive cmd: $cmd, len: ${res.data.length}, data = ${res.data.hexString}",
      );
    }

    if (res.data[0].toInt() == 0xF5) {
      final notifyIndex = res.data[1].toInt();

      switch (notifyIndex) {
        case 0:
          App.get.exitAll();
          break;
        case 1:
          if (res.lr == 'L') {
            EvenAI.get.lastPageByTouchpad();
          } else {
            EvenAI.get.nextPageByTouchpad();
          }
          break;
        case 23: //BleEvent.evenaiStart:
          EvenAI.get.toStartEvenAIByOS();
          break;
        case 24: //BleEvent.evenaiRecordOver:
          EvenAI.get.recordOverByOS();
          break;
        default:
          appLogger.i("Unknown Ble Event: $notifyIndex");
      }
      return;
    }
    _reqListen.remove(cmd)?.complete(res);
    _reqTimeout.remove(cmd)?.cancel();
    if (_nextReceive != null) {
      _nextReceive?.complete(res);
      _nextReceive = null;
    }
  }

  String getConnectionStatus() {
    return connectionStatus;
  }

  List<Map<String, String>> getPairedGlasses() {
    return pairedGlasses;
  }

  static final _reqListen = <String, Completer<BleReceive>>{};
  static final _reqTimeout = <String, Timer>{};
  static Completer<BleReceive>? _nextReceive;

  static _checkTimeout(String cmd, int timeoutMs, Uint8List data, String lr) {
    _reqTimeout.remove(cmd);
    var cb = _reqListen.remove(cmd);
    appLogger.i(
      '${DateTime.now()} _checkTimeout-----timeoutMs----$timeoutMs-----cb----$cb-----',
    );
    if (cb != null) {
      var res = BleReceive();
      res.isTimeout = true;
      //var showData = data.length > 50 ? data.sublist(0, 50) : data;
      appLogger.i("send Timeout $cmd of $timeoutMs");
      cb.complete(res);
      // Metric recording happens in the completer.future.then() in request()
    }

    _reqTimeout[cmd]?.cancel();
    _reqTimeout.remove(cmd);
  }

  static Future<T?> invokeMethod<T>(String method, [dynamic params]) {
    return _channel.invokeMethod(method, params);
  }

  static Future<BleReceive> requestRetry(
    Uint8List data, {
    String? lr,
    Map<String, dynamic>? other,
    int timeoutMs = 200,
    bool useNext = false,
    int retry = 3,
  }) async {
    BleReceive ret;
    for (var i = 0; i <= retry; i++) {
      if (i > 0) {
        // Record retry attempts (not for first attempt)
        _instance?._healthMetrics = _instance!._healthMetrics.recordRetry();
      }

      ret = await request(
        data,
        lr: lr,
        other: other,
        timeoutMs: timeoutMs,
        useNext: useNext,
      );
      if (!ret.isTimeout) {
        return ret;
      }
      if (!BleManager.isBothConnected()) {
        break;
      }
    }
    ret = BleReceive();
    ret.isTimeout = true;
    appLogger.i("requestRetry $lr timeout of $timeoutMs");
    return ret;
  }

  static Future<bool> sendBoth(
    data, {
    int timeoutMs = 250,
    SendResultParse? isSuccess,
    int? retry,
  }) async {
    var ret = await BleManager.requestRetry(
      data,
      lr: "L",
      timeoutMs: timeoutMs,
      retry: retry ?? 0,
    );
    if (ret.isTimeout) {
      appLogger.i("sendBoth L timeout");

      return false;
    } else if (isSuccess != null) {
      final success = isSuccess.call(ret.data);
      if (!success) return false;
      var retR = await BleManager.requestRetry(
        data,
        lr: "R",
        timeoutMs: timeoutMs,
        retry: retry ?? 0,
      );
      if (retR.isTimeout) return false;
      return isSuccess.call(retR.data);
    } else if (ret.data[1].toInt() == 0xc9) {
      var ret = await BleManager.requestRetry(
        data,
        lr: "R",
        timeoutMs: timeoutMs,
        retry: retry ?? 0,
      );
      if (ret.isTimeout) return false;
    }
    return true;
  }

  static Future sendData(
    Uint8List data, {
    String? lr,
    Map<String, dynamic>? other,
    int secondDelay = 100,
  }) async {
    var params = <String, dynamic>{'data': data};
    if (other != null) {
      params.addAll(other);
    }
    dynamic ret;
    if (lr != null) {
      params["lr"] = lr;
      ret = await BleManager.invokeMethod(methodSend, params);
      return ret;
    } else {
      params["lr"] = "L"; // get().slave;
      var ret = await _channel.invokeMethod(
        methodSend,
        params,
      ); //ret is true or false or null
      if (ret == true) {
        params["lr"] = "R"; // get().master;
        ret = await BleManager.invokeMethod(methodSend, params);
        return ret;
      }
      if (secondDelay > 0) {
        await Future.delayed(Duration(milliseconds: secondDelay));
      }
      params["lr"] = "R"; // get().master;
      ret = await BleManager.invokeMethod(methodSend, params);
      return ret;
    }
  }

  static Future<BleReceive> request(
    Uint8List data, {
    String? lr,
    Map<String, dynamic>? other,
    int timeoutMs = 1000, //500,
    bool useNext = false,
  }) async {
    final startTime = DateTime.now();
    var lr0 = lr ?? Proto.lR();
    var completer = Completer<BleReceive>();
    String cmd = "$lr0${data[0].toRadixString(16).padLeft(2, '0')}";

    if (useNext) {
      _nextReceive = completer;
    } else {
      if (_reqListen.containsKey(cmd)) {
        var res = BleReceive();
        res.isTimeout = true;
        _reqListen[cmd]?.complete(res);
        appLogger.i("already exist key: $cmd");

        _reqTimeout[cmd]?.cancel();
      }
      _reqListen[cmd] = completer;
    }
    appLogger.i("request key: $cmd, ");

    if (timeoutMs > 0) {
      _reqTimeout[cmd] = Timer(Duration(milliseconds: timeoutMs), () {
        _checkTimeout(cmd, timeoutMs, data, lr0);
      });
    }

    completer.future.then((result) {
      _reqTimeout.remove(cmd)?.cancel();
      final latency = DateTime.now().difference(startTime);
      if (result.isTimeout) {
        _instance?._healthMetrics = _instance!._healthMetrics.recordTimeout();
        _instance?._recordTransaction(
          command: cmd,
          target: lr0,
          isSuccess: false,
          latency: latency,
          error: 'timeout',
        );
      } else {
        _instance?._healthMetrics = _instance!._healthMetrics.recordSuccess(latency);
        _instance?._recordTransaction(
          command: cmd,
          target: lr0,
          isSuccess: true,
          latency: latency,
        );
      }
    });

    await sendData(data, lr: lr, other: other).timeout(
      Duration(seconds: 2),
      onTimeout: () {
        _reqTimeout.remove(cmd)?.cancel();
        var ret = BleReceive();
        ret.isTimeout = true;
        _reqListen.remove(cmd)?.complete(ret);
        _instance?._healthMetrics = _instance!._healthMetrics.recordTimeout();
      },
    );

    return completer.future;
  }

  static bool isBothConnected() {
    //return isConnectedL() && isConnectedR();

    // todo
    return true;
  }

  static Future<bool> requestList(
    List<Uint8List> sendList, {
    String? lr,
    int? timeoutMs,
  }) async {
    appLogger.i(
      "requestList---sendList---${sendList.first}----lr---$lr----timeoutMs----$timeoutMs-",
    );

    if (lr != null) {
      return await _requestList(sendList, lr, timeoutMs: timeoutMs);
    } else {
      var rets = await Future.wait([
        _requestList(sendList, "L", keepLast: true, timeoutMs: timeoutMs),
        _requestList(sendList, "R", keepLast: true, timeoutMs: timeoutMs),
      ]);
      if (rets.length == 2 && rets[0] && rets[1]) {
        var lastPack = sendList[sendList.length - 1];
        return await sendBoth(lastPack, timeoutMs: timeoutMs ?? 250);
      } else {
        appLogger.i("error request lr leg");
      }
    }
    return false;
  }

  static Future<bool> _requestList(
    List sendList,
    String lr, {
    bool keepLast = false,
    int? timeoutMs,
  }) async {
    int len = sendList.length;
    if (keepLast) len = sendList.length - 1;
    for (var i = 0; i < len; i++) {
      var pack = sendList[i];
      var resp = await request(pack, lr: lr, timeoutMs: timeoutMs ?? 350);
      if (resp.isTimeout) {
        return false;
      } else if (resp.data[1].toInt() != 0xc9 && resp.data[1].toInt() != 0xcB) {
        return false;
      }
    }
    return true;
  }
}

extension Uint8ListEx on Uint8List {
  String get hexString {
    return map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}
