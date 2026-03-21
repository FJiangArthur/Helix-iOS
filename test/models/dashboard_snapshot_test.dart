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

    test('isInConversation returns true when recordingDuration is set', () {
      final snapshot = DashboardSnapshot(
        timestamp: DateTime(2026, 3, 12, 9, 41),
        connectionState: BleConnectionState.connected,
        mode: ConversationMode.general,
        engineStatus: EngineStatus.listening,
        contextLine: 'test',
        recordingDuration: const Duration(minutes: 5, seconds: 23),
      );

      expect(snapshot.isInConversation, isTrue);
    });

    test('isInConversation returns false when recordingDuration is null', () {
      final snapshot = DashboardSnapshot(
        timestamp: DateTime(2026, 3, 12, 9, 41),
        connectionState: BleConnectionState.connected,
        mode: ConversationMode.general,
        engineStatus: EngineStatus.idle,
        contextLine: 'test',
      );

      expect(snapshot.isInConversation, isFalse);
    });

    group('conversationStatsLine', () {
      test('formats stats within 24 chars', () {
        final snapshot = DashboardSnapshot(
          timestamp: DateTime(2026, 3, 12, 9, 41),
          connectionState: BleConnectionState.connected,
          mode: ConversationMode.general,
          engineStatus: EngineStatus.listening,
          contextLine: 'test',
          recordingDuration: const Duration(minutes: 5),
          questionCount: 3,
          answerCount: 3,
          wordCount: 450,
        );

        final line = snapshot.conversationStatsLine();
        expect(line, 'Q:3 A:3  ~450w');
        expect(line.length, lessThanOrEqualTo(24));
      });

      test('truncates when stats are too long', () {
        final snapshot = DashboardSnapshot(
          timestamp: DateTime(2026, 3, 12, 9, 41),
          connectionState: BleConnectionState.connected,
          mode: ConversationMode.general,
          engineStatus: EngineStatus.listening,
          contextLine: 'test',
          recordingDuration: const Duration(minutes: 5),
          questionCount: 100,
          answerCount: 100,
          wordCount: 99999,
        );

        final line = snapshot.conversationStatsLine();
        expect(line.length, lessThanOrEqualTo(24));
      });

      test('handles zero counts', () {
        final snapshot = DashboardSnapshot(
          timestamp: DateTime(2026, 3, 12, 9, 41),
          connectionState: BleConnectionState.connected,
          mode: ConversationMode.general,
          engineStatus: EngineStatus.listening,
          contextLine: 'test',
          recordingDuration: const Duration(seconds: 10),
          questionCount: 0,
          answerCount: 0,
          wordCount: 0,
        );

        final line = snapshot.conversationStatsLine();
        expect(line, 'Q:0 A:0  ~0w');
        expect(line.length, lessThanOrEqualTo(24));
      });
    });

    group('timeWithRecording', () {
      test('shows time only when not recording', () {
        final snapshot = DashboardSnapshot(
          timestamp: DateTime(2026, 3, 12, 9, 41),
          connectionState: BleConnectionState.connected,
          mode: ConversationMode.general,
          engineStatus: EngineStatus.idle,
          contextLine: 'test',
        );

        expect(snapshot.timeWithRecording(), '09:41');
      });

      test('shows time with REC and duration when recording', () {
        final snapshot = DashboardSnapshot(
          timestamp: DateTime(2026, 3, 12, 9, 41),
          connectionState: BleConnectionState.connected,
          mode: ConversationMode.general,
          engineStatus: EngineStatus.listening,
          contextLine: 'test',
          recordingDuration: const Duration(minutes: 5, seconds: 23),
        );

        final line = snapshot.timeWithRecording();
        expect(line, '09:41  REC 05:23');
        expect(line.length, lessThanOrEqualTo(24));
      });

      test('pads short durations with zeros', () {
        final snapshot = DashboardSnapshot(
          timestamp: DateTime(2026, 3, 12, 9, 41),
          connectionState: BleConnectionState.connected,
          mode: ConversationMode.general,
          engineStatus: EngineStatus.listening,
          contextLine: 'test',
          recordingDuration: const Duration(seconds: 7),
        );

        expect(snapshot.timeWithRecording(), '09:41  REC 00:07');
      });
    });

    group('in-conversation layout', () {
      test('uses enriched layout when in conversation', () {
        final snapshot = DashboardSnapshot(
          timestamp: DateTime(2026, 3, 12, 9, 41),
          connectionState: BleConnectionState.connected,
          mode: ConversationMode.interview,
          engineStatus: EngineStatus.listening,
          contextLine: 'THINKING...',
          recordingDuration: const Duration(minutes: 2, seconds: 15),
          questionCount: 3,
          answerCount: 3,
          wordCount: 450,
        );

        final lines = snapshot.lines;
        expect(lines, hasLength(5));

        // Line 1: time with recording
        expect(lines[0], '09:41  REC 02:15');

        // Line 2: date
        expect(lines[1], 'Thu Mar 12');

        // Line 3: connection + mode combined
        expect(lines[2], 'ONLINE | INTERVIEW');

        // Line 4: conversation stats
        expect(lines[3], 'Q:3 A:3  ~450w');

        // Line 5: contextual status
        expect(lines[4], 'THINKING...');

        // All lines must fit in 24 chars
        for (final line in lines) {
          expect(line.length, lessThanOrEqualTo(24),
              reason: 'Line "$line" exceeds 24 chars');
        }
      });

      test('uses standard layout when not in conversation', () {
        final snapshot = DashboardSnapshot(
          timestamp: DateTime(2026, 3, 12, 9, 41),
          connectionState: BleConnectionState.connected,
          mode: ConversationMode.general,
          engineStatus: EngineStatus.idle,
          contextLine: 'Ready',
        );

        final lines = snapshot.lines;
        expect(lines, hasLength(5));
        expect(lines[0], '09:41');
        expect(lines[1], 'Thu Mar 12');
        expect(lines[2], 'GLASSES ONLINE');
        expect(lines[3], 'Tap mic to start');
        expect(lines[4], 'Ready');
      });
    });

    group('all lines respect 24-char limit', () {
      test('disconnected interview in-conversation', () {
        final snapshot = DashboardSnapshot(
          timestamp: DateTime(2026, 3, 12, 23, 59),
          connectionState: BleConnectionState.reconnecting,
          mode: ConversationMode.interview,
          engineStatus: EngineStatus.responding,
          contextLine: 'RESPONDING...',
          recordingDuration: const Duration(hours: 1, minutes: 30),
          questionCount: 50,
          answerCount: 48,
          wordCount: 12345,
        );

        for (final line in snapshot.lines) {
          expect(line.length, lessThanOrEqualTo(24),
              reason: 'Line "$line" exceeds 24 chars');
        }
      });
    });
  });
}
