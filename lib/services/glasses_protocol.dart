import 'dart:convert';
import 'dart:typed_data';

/// Encodes HUD state values for the Even Realities display protocol.
class HudDisplayState {
  HudDisplayState._();

  static const int _displayNewContent = 0x01;
  static const int _aiShowing = 0x30;
  static const int _aiComplete = 0x40;
  static const int _textShow = 0x70;

  static int aiFrame({required bool isStreaming}) =>
      (isStreaming ? _aiShowing : _aiComplete) | _displayNewContent;

  static int textPage() => _textShow | _displayNewContent;
}

/// Normalizes notification payloads to match the G1 notification schema.
class GlassesNotificationPayload {
  GlassesNotificationPayload._();

  static Map<String, dynamic> normalize(
    Map<dynamic, dynamic> raw, {
    int? fallbackMessageId,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final unixSeconds = currentTime.millisecondsSinceEpoch ~/ 1000;

    return {
      'msg_id': raw['msg_id'] is int
          ? raw['msg_id']
          : (fallbackMessageId ?? unixSeconds),
      'app_identifier': raw['app_identifier'] as String? ?? '',
      'title': raw['title'] as String? ?? '',
      'subtitle': raw['subtitle'] as String? ?? '',
      'message': raw['message'] as String? ?? '',
      'time_s': raw['time_s'] is int ? raw['time_s'] : unixSeconds,
      'display_name': raw['display_name'] as String? ?? '',
      'action': raw['action'] as String? ?? '',
      'date': raw['date'] as String? ?? '',
    };
  }
}

/// Builds chunked notification packets for the G1 BLE transport.
class GlassesNotificationPackets {
  GlassesNotificationPackets._();

  static const int command = 0x4B;
  static const int _chunkSize = 180;

  static List<Uint8List> encode(Map<dynamic, dynamic> rawPayload) {
    final payload = GlassesNotificationPayload.normalize(rawPayload);
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode({'ncs_notification': payload})),
    );
    return fromPayload(bytes);
  }

  static List<Uint8List> fromPayload(Uint8List payload) {
    if (payload.isEmpty) {
      return [
        Uint8List.fromList([command, 0x00, 1, 0]),
      ];
    }

    final chunkCount = (payload.length / _chunkSize).ceil();
    return List<Uint8List>.generate(chunkCount, (index) {
      final start = index * _chunkSize;
      final end = (start + _chunkSize).clamp(0, payload.length);
      return Uint8List.fromList([
        command,
        0x00,
        chunkCount,
        index,
        ...payload.sublist(start, end),
      ]);
    });
  }
}
