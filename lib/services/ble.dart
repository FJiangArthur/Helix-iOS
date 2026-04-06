import 'dart:typed_data';

class BleReceive {
  String lr = "";
  Uint8List data = Uint8List(0);
  String type = "";
  bool isTimeout = false;
  int? command;
  int? notifyIndex;
  int? payloadLength;
  String? hex;
  Map<String, dynamic> rawMeta = const {};

  int getCmd() {
    if (command != null) {
      return command!;
    }
    if (data.isEmpty) {
      return 0;
    }
    return data[0].toInt();
  }

  BleReceive();
  static BleReceive fromMap(Map map) {
    var ret = BleReceive();
    ret.lr = map["lr"] as String? ?? "";
    final typedData = map["data"];
    if (typedData is Uint8List) {
      ret.data = typedData;
    } else if (typedData is List<int>) {
      ret.data = Uint8List.fromList(typedData);
    }
    ret.type = map["type"] as String? ?? "";
    ret.command = (map["command"] as num?)?.toInt();
    ret.notifyIndex = (map["notifyIndex"] as num?)?.toInt();
    ret.payloadLength = (map["payloadLength"] as num?)?.toInt();
    ret.hex = map["hexString"] as String?;
    ret.rawMeta = Map<String, dynamic>.from(
      map.map((key, value) => MapEntry('$key', value)),
    );
    if (ret.data.isNotEmpty) {
      ret.command ??= ret.data[0].toInt();
      if (ret.command == 0xF5 && ret.data.length > 1) {
        ret.notifyIndex ??= ret.data[1].toInt();
      }
      ret.payloadLength ??= ret.data.length;
      ret.hex ??= ret.hexStringData();
    }
    return ret;
  }

  bool get isDeviceOrder => getCmd() == 0xF5;

  String hexStringData() {
    return data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}

class BleTransportPolicy {
  BleTransportPolicy._();

  /// Retry counts are expressed as "extra attempts after the first send".
  static int attemptsForRetryCount(int retryCount) {
    if (retryCount < 0) return 1;
    return retryCount + 1;
  }

  /// A delivery succeeds when at least one connected side succeeds.
  ///
  /// G1 glasses relay data between L and R internally, so a single-side
  /// delivery is sufficient. Requiring both sides would cause total failure
  /// when one side's write characteristic hasn't been discovered yet.
  static bool didAllConnectedTargetsSucceed({
    required bool leftConnected,
    required bool rightConnected,
    required bool leftSuccess,
    required bool rightSuccess,
  }) {
    if (!leftConnected && !rightConnected) {
      return false;
    }
    return (leftConnected && leftSuccess) || (rightConnected && rightSuccess);
  }
}

enum BleDeviceEventKind {
  exitFunc,
  pageBack,
  pageForward,
  tripleTapLeft,
  tripleTapRight,
  headUp,
  headDown,
  batteryLevel,
  chargingStatus,
  rightTouchpadHeld,
  dashboardOpened,
  dashboardClosed,
  glassesConnectSuccess,
  evenaiStart,
  evenaiRecordOver,
  unknownDeviceOrder,
}

class BleDeviceEvent {
  const BleDeviceEvent({
    required this.kind,
    required this.notifyIndex,
    required this.side,
    required this.data,
    required this.timestamp,
    required this.label,
    this.payload,
  });

  final BleDeviceEventKind kind;
  final int notifyIndex;
  final String side;
  final Uint8List data;
  final DateTime timestamp;
  final String label;
  final int? payload;

  bool get isDashboardTrigger =>
      kind == BleDeviceEventKind.headUp || kind == BleDeviceEventKind.headDown;

  bool get isKnown => kind != BleDeviceEventKind.unknownDeviceOrder;

  static BleDeviceEvent? fromReceive(
    BleReceive receive, {
    DateTime? timestamp,
  }) {
    if (receive.getCmd() == 0x22) {
      return _parseStatusMessage(receive, timestamp: timestamp);
    }

    if (!receive.isDeviceOrder || receive.notifyIndex == null) {
      return null;
    }

    final notifyIndex = receive.notifyIndex!;
    final side = receive.lr;
    final eventTimestamp = timestamp ?? DateTime.now();

    return switch (notifyIndex) {
      0 => BleDeviceEvent(
        kind: BleDeviceEventKind.exitFunc,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'exit_function',
      ),
      1 => BleDeviceEvent(
        kind: side == 'L'
            ? BleDeviceEventKind.pageBack
            : BleDeviceEventKind.pageForward,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: side == 'L' ? 'page_back' : 'page_forward',
      ),
      2 => BleDeviceEvent(
        kind: BleDeviceEventKind.headUp,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'head_up',
      ),
      3 => BleDeviceEvent(
        kind: BleDeviceEventKind.headDown,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'head_down',
      ),
      4 => BleDeviceEvent(
        kind: BleDeviceEventKind.tripleTapLeft,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'triple_tap_left',
      ),
      5 => BleDeviceEvent(
        kind: BleDeviceEventKind.tripleTapRight,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'triple_tap_right',
      ),
      0x09 => BleDeviceEvent(
        kind: BleDeviceEventKind.chargingStatus,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'charging_status',
        payload: receive.data.length > 2 ? receive.data[2] : null,
      ),
      0x0A => BleDeviceEvent(
        kind: BleDeviceEventKind.batteryLevel,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'battery_level',
        payload: receive.data.length > 2 ? receive.data[2] : null,
      ),
      0x12 => BleDeviceEvent(
        kind: BleDeviceEventKind.rightTouchpadHeld,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'right_touchpad_held',
      ),
      17 => BleDeviceEvent(
        kind: BleDeviceEventKind.glassesConnectSuccess,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'glasses_connect_success',
      ),
      0x1E => BleDeviceEvent(
        kind: BleDeviceEventKind.dashboardOpened,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'dashboard_opened',
      ),
      0x1F => BleDeviceEvent(
        kind: BleDeviceEventKind.dashboardClosed,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'dashboard_closed',
      ),
      23 => BleDeviceEvent(
        kind: BleDeviceEventKind.evenaiStart,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'evenai_start',
      ),
      24 => BleDeviceEvent(
        kind: BleDeviceEventKind.evenaiRecordOver,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'evenai_record_over',
      ),
      _ => BleDeviceEvent(
        kind: BleDeviceEventKind.unknownDeviceOrder,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'unknown_device_order_$notifyIndex',
      ),
    };
  }

  static BleDeviceEvent? _parseStatusMessage(
    BleReceive receive, {
    DateTime? timestamp,
  }) {
    final data = receive.data;
    if (data.length < 2) return null;

    final size = data[1];
    final side = receive.lr;
    final eventTimestamp = timestamp ?? DateTime.now();

    if (size == 0x0A && data.length >= 10) {
      final eventCode = data[4];
      if (eventCode == 0x01) {
        return BleDeviceEvent(
          kind: BleDeviceEventKind.headUp,
          notifyIndex: 0x22,
          side: side,
          data: data,
          timestamp: eventTimestamp,
          label: 'status_head_up',
        );
      }
    } else if (size == 0x08 && data.length >= 8) {
      final eventCode = data[4];
      if (eventCode == 0x02) {
        return BleDeviceEvent(
          kind: BleDeviceEventKind.pageForward,
          notifyIndex: 0x22,
          side: side,
          data: data,
          timestamp: eventTimestamp,
          label: 'status_right_tap',
        );
      }
    }

    return null;
  }
}

class BleStatusMessage {
  const BleStatusMessage({
    required this.side,
    required this.eventCode,
    required this.dashboardMode,
    required this.paneMode,
    required this.panePage,
    required this.timestamp,
    this.unreadCount,
    this.lowPower,
  });

  final String side;
  final int eventCode;
  final int dashboardMode;
  final int paneMode;
  final int panePage;
  final DateTime timestamp;
  final int? unreadCount;
  final int? lowPower;

  static BleStatusMessage? fromReceive(
    BleReceive receive, {
    DateTime? timestamp,
  }) {
    final data = receive.data;
    if (data.isEmpty || data[0] != 0x22 || data.length < 2) return null;

    final size = data[1];
    final eventTimestamp = timestamp ?? DateTime.now();

    if (size == 0x0A && data.length >= 10) {
      return BleStatusMessage(
        side: receive.lr,
        eventCode: data[4],
        unreadCount: data[5],
        lowPower: data[6],
        dashboardMode: data[7],
        paneMode: data[8],
        panePage: data[9],
        timestamp: eventTimestamp,
      );
    } else if (size == 0x08 && data.length >= 8) {
      return BleStatusMessage(
        side: receive.lr,
        eventCode: data[4],
        dashboardMode: data[5],
        paneMode: data[6],
        panePage: data[7],
        timestamp: eventTimestamp,
      );
    }

    return null;
  }
}

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
}
