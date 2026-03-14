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

enum BleDeviceEventKind {
  exitFunc,
  pageBack,
  pageForward,
  headUp,
  headDown,
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
  });

  final BleDeviceEventKind kind;
  final int notifyIndex;
  final String side;
  final Uint8List data;
  final DateTime timestamp;
  final String label;

  bool get isDashboardTrigger =>
      kind == BleDeviceEventKind.headUp || kind == BleDeviceEventKind.headDown;

  bool get isKnown => kind != BleDeviceEventKind.unknownDeviceOrder;

  static BleDeviceEvent? fromReceive(
    BleReceive receive, {
    DateTime? timestamp,
  }) {
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
      17 => BleDeviceEvent(
        kind: BleDeviceEventKind.glassesConnectSuccess,
        notifyIndex: notifyIndex,
        side: side,
        data: receive.data,
        timestamp: eventTimestamp,
        label: 'glasses_connect_success',
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
}

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  reconnecting,
}
