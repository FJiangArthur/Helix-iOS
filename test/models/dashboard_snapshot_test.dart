import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/models/dashboard_snapshot.dart';
import 'package:flutter_helix/services/ble.dart';
import 'package:flutter_helix/services/conversation_engine.dart';

void main() {
  group('DashboardSnapshot', () {
    test('formats the five-line HUD layout and truncates long context', () {
      final snapshot = DashboardSnapshot(
        timestamp: DateTime(2026, 3, 12, 9, 41),
        connectionState: BleConnectionState.connected,
        mode: ConversationMode.interview,
        engineStatus: EngineStatus.responding,
        contextLine:
            'This is a long assistant preview that should be truncated to fit the compact dashboard card.',
      );

      expect(snapshot.lines, hasLength(5));
      expect(snapshot.lines[0], '09:41');
      expect(snapshot.lines[1], 'Thu Mar 12');
      expect(snapshot.lines[2], 'GLASSES ONLINE');
      expect(snapshot.lines[3], 'INTERVIEW RESPONDING');
      expect(snapshot.lines[4], endsWith('...'));
      expect(snapshot.lines[4].length, lessThanOrEqualTo(24));
      expect(snapshot.hudText.split('\n'), hasLength(5));
    });
  });
}
