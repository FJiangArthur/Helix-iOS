import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/glasses_protocol.dart';

void main() {
  group('HudDisplayState', () {
    test('uses dedicated AI and text screen codes', () {
      expect(HudDisplayState.aiFrame(isStreaming: true), 0x31);
      expect(HudDisplayState.aiFrame(isStreaming: false), 0x41);
      expect(HudDisplayState.textPage(), 0x71);
    });
  });

  group('GlassesNotificationPayload', () {
    test('fills protocol defaults while preserving supplied fields', () {
      final payload = GlassesNotificationPayload.normalize(
        {
          'app_identifier': 'com.even.test',
          'title': 'Even',
          'message': 'Hello',
          'action': 'Open app',
        },
        fallbackMessageId: 42,
        now: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
      );

      expect(payload['msg_id'], 42);
      expect(payload['app_identifier'], 'com.even.test');
      expect(payload['title'], 'Even');
      expect(payload['message'], 'Hello');
      expect(payload['time_s'], 1_700_000_000);
      expect(payload['display_name'], '');
      expect(payload['action'], 'Open app');
      expect(payload['date'], '');
    });
  });

  group('GlassesNotificationPackets', () {
    test('uses notification header pad byte and chunk indices', () {
      final payload = Uint8List.fromList(utf8.encode('x' * 181));

      final packets = GlassesNotificationPackets.fromPayload(payload);

      expect(packets, hasLength(2));
      expect(packets.first.sublist(0, 4), [0x4B, 0x00, 2, 0]);
      expect(packets.last.sublist(0, 4), [0x4B, 0x00, 2, 1]);
      expect(packets.first.length, 184);
      expect(packets.last.length, 5);
    });

    test('wraps normalized notification JSON in ncs_notification', () {
      final packets = GlassesNotificationPackets.encode({
        'app_identifier': 'com.even.test',
        'title': 'Even',
        'message': 'Hello',
      });

      final payload = utf8.decode([
        for (final packet in packets) ...packet.sublist(4),
      ]);
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final notification = decoded['ncs_notification'] as Map<String, dynamic>;

      expect(notification['app_identifier'], 'com.even.test');
      expect(notification['title'], 'Even');
      expect(notification['message'], 'Hello');
      expect(notification.containsKey('time_s'), isTrue);
    });
  });
}
